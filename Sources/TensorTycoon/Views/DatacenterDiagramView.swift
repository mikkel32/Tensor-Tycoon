import SwiftUI

/// One site's infrastructure as a schematic: power in → substation → batteries → halls & racks, with the heat going to
/// the cooling loop and the data to the network spine. Every number comes from the site's own state; where the game
/// doesn't model something (a UPS, say) the box says so rather than inventing a figure.
struct DatacenterDiagramSection: View {
    let state: GameState
    @State private var siteID: UUID? = nil

    var body: some View {
        let s = state
        if let site = s.sites.first(where: { $0.id == siteID }) ?? s.sites.first(where: { $0.kind == .datacenter }) ?? s.sites.first {
            Card {
                CardHeader(title: "Site infrastructure", symbol: "bolt.horizontal.circle",
                           subtitle: "How power reaches your chips at one site, and where the heat and the data go. Every number is this site's own.") {
                    Picker("Site", selection: Binding(get: { site.id }, set: { siteID = $0 })) {
                        ForEach(s.sites) { st in Text(st.name).tag(st.id) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                }
                InfraDiagram(m: InfraFacts(site: site, s))
            }
        }
    }
}

// MARK: - Facts

/// Everything the diagram shows, read from the game state once per redraw.
struct InfraFacts {
    let site: Site
    let ready: Bool
    let status: String
    let loadKW: Double
    let chipKW: Double
    let chips: Int
    let onOrder: Int
    let topChips: [(name: String, count: Int)]
    let fabric: String?
    let contracts: [PowerContract]
    let outages: Int
    let lastOutage: Date?
    let water: Double?

    init(site: Site, _ s: GameState) {
        self.site = site
        ready = site.isReady(s.date)
        status = DCText.status(site, s)
        loadKW = Economy.siteLoadKW(s, site.id)
        chipKW = max(0, loadKW - site.subleasedKW)
        let batches = s.owned.filter { $0.siteID == site.id }
        chips = batches.reduce(0) { $0 + $1.count }
        onOrder = s.orders.filter { $0.siteID == site.id }.reduce(0) { $0 + $1.count }
        var byChip: [String: Int] = [:]
        for b in batches { byChip[b.accelID, default: 0] += b.count }
        let ranked = byChip.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        topChips = ranked.prefix(3).map { (HardwareCatalog.get($0.key)?.name ?? $0.key, $0.value) }
        fabric = ranked.first.flatMap { HardwareCatalog.get($0.key) }.map { a in
            "\(a.interconnect) · \(Fmt.trim(a.interconnectGBs, 0)) GB/s · \(Fmt.int(a.scaleUp))-chip domains"
        }
        contracts = s.powerContracts.filter { $0.siteID == site.id || ($0.siteID == nil && $0.locationID == site.locationID) }
        let outageNews = s.news.filter { $0.title == "Power outage at \(site.name)" }
        outages = outageNews.count
        lastOutage = outageNews.map(\.date).max()
        water = site.kind == .colo || site.kind == .datacenter ? DCMarket.waterLPerKWh(site) : nil
    }

    var facilityKW: Double { loadKW * site.pue }
    var coolingKW: Double { loadKW * max(0, site.pue - 1) }
}

// MARK: - Diagram

private struct InfraDiagram: View {
    let m: InfraFacts

    private static let boxHeight: CGFloat = 132
    private static let gap: CGFloat = 40
    private static let rowGap: CGFloat = 52

    var body: some View {
        let site = m.site
        GeometryReader { geo in
            let w = geo.size.width
            let bw = max(120, (w - 3 * Self.gap) / 4)
            let bh = Self.boxHeight
            let x: [CGFloat] = (0..<4).map { CGFloat($0) * (bw + Self.gap) }
            let y2 = bh + Self.rowGap
            ZStack(alignment: .topLeading) {
                InfraWires(boxWidth: bw, boxHeight: bh, gap: Self.gap, rowGap: Self.rowGap)
                    .frame(width: w, height: 2 * bh + Self.rowGap)
                    .accessibilityHidden(true)
                box(powerIn(site), at: CGPoint(x: x[0], y: 0), width: bw)
                box(substation(site), at: CGPoint(x: x[1], y: 0), width: bw)
                box(backup(site), at: CGPoint(x: x[2], y: 0), width: bw)
                box(halls(site), at: CGPoint(x: x[3], y: 0), width: bw)
                box(operations(site), at: CGPoint(x: x[0], y: y2), width: 2 * bw + Self.gap)
                box(network(site), at: CGPoint(x: x[2], y: y2), width: bw)
                box(cooling(site), at: CGPoint(x: x[3], y: y2), width: bw)
                wireLabel("power", color: .orange, at: CGPoint(x: x[1] - Self.gap / 2, y: bh / 2 - 12))
                wireLabel("power", color: .orange, at: CGPoint(x: x[2] - Self.gap / 2, y: bh / 2 - 12))
                wireLabel("power", color: .orange, at: CGPoint(x: x[3] - Self.gap / 2, y: bh / 2 - 12))
                wireLabel("heat", color: Theme.info, at: CGPoint(x: x[3] + bw / 2 + 22, y: bh + Self.rowGap / 2))
                wireLabel("data", color: .purple, at: CGPoint(x: x[3] - Self.gap / 2 + 14, y: bh + Self.rowGap / 2))
            }
        }
        .frame(height: 2 * Self.boxHeight + Self.rowGap)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Infrastructure diagram for \(site.name)")
    }

    private func box(_ spec: InfraBoxSpec, at p: CGPoint, width: CGFloat) -> some View {
        InfraBox(spec: spec)
            .frame(width: width, height: Self.boxHeight)
            .position(x: p.x + width / 2, y: p.y + Self.boxHeight / 2)
    }

    private func wireLabel(_ text: String, color: Color, at p: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .fixedSize()
            .position(x: p.x, y: p.y)
            .accessibilityHidden(true)
    }

    // MARK: Boxes

    private func powerIn(_ site: Site) -> InfraBoxSpec {
        var lines: [(String, String)] = [("Deal", site.powerDeal.rawValue), ("Price", "\(Fmt.price(site.powerPrice))/kWh")]
        if site.gridExtraKW > 0 { lines.append(("Extra grid", "+\(Fmt.watts(site.gridExtraKW * 1000))")) }
        if site.onsiteKW > 0 { lines.append(("On-site gen", Fmt.watts(site.onsiteKW * 1000))) }
        let ppa = m.contracts.filter { $0.kind.suppliesEnergy }
        if !ppa.isEmpty {
            lines.append(("Contracts", "\(ppa.count) · \(Fmt.watts(ppa.reduce(0) { $0 + $1.mw } * 1e6))"))
        } else {
            lines.append(("Contracts", "none here"))
        }
        let queued = m.contracts.filter { $0.kind == .interconnect && !$0.live }
        if !queued.isEmpty { lines.append(("Grid queue", Fmt.watts(queued.reduce(0) { $0 + $1.mw } * 1e6))) }
        return InfraBoxSpec(title: site.kind == .garage || site.kind == .office ? "Building supply" : "Grid feed",
                            symbol: "powerplug.fill", tint: .orange, lines: lines)
    }

    private func substation(_ site: Site) -> InfraBoxSpec {
        var lines: [(String, String)] = [("IT capacity", Fmt.watts(site.capacityKW * 1000))]
        lines.append(("Facility draw", Fmt.watts(m.facilityKW * 1000)))
        if site.expanding > 0 { lines.append(("Building", "+\(Fmt.watts(site.expanding * 1000))\(site.expansionReady.map { " · \($0.gameShort)" } ?? "")")) }
        if site.plannedKW > 0 { lines.append(("Later phases", Fmt.watts(site.plannedKW * 1000))) }
        if site.rampKW > 0 { lines.append(("To hand over", Fmt.watts(site.rampKW * 1000))) }
        if site.kind == .datacenter { lines.append(("Electrical", "Gen \(site.generation + 1)")) }
        return InfraBoxSpec(title: "Substation", symbol: "bolt.fill", tint: .orange, lines: lines)
    }

    private func backup(_ site: Site) -> InfraBoxSpec {
        let batteries = m.contracts.filter { $0.kind == .battery }
        var lines: [(String, String)] = []
        if site.batteryMWh > 0 {
            lines.append(("Storage", "\(Fmt.trim(site.batteryMWh, site.batteryMWh < 10 ? 1 : 0)) MWh"))
            if m.facilityKW > 0 {
                lines.append(("Covers today", "\(Fmt.trim(site.batteryMWh * 1000 / m.facilityKW, 1)) h"))
            }
        } else {
            lines.append(("Storage", "none"))
        }
        let pending = batteries.filter { !$0.live }
        if !pending.isEmpty { lines.append(("Coming", "\(Fmt.trim(pending.reduce(0) { $0 + $1.mw } * 4, 0)) MWh")) }
        return InfraBoxSpec(title: "Batteries", symbol: "battery.100percent.bolt", tint: .orange, lines: lines,
                            note: site.batteryMWh > 0 ? nil : "Sign battery storage on the Power tab to ride out grid faults.")
    }

    private func halls(_ site: Site) -> InfraBoxSpec {
        let used = m.loadKW / max(site.capacityKW, 0.001)
        var lines: [(String, String)] = [("In use", "\(Fmt.watts(m.loadKW * 1000)) · \(Int((used * 100).rounded()))%")]
        lines.append(("Chips", m.chips > 0 ? Fmt.int(m.chips) : "none"))
        if m.onOrder > 0 { lines.append(("On order", Fmt.int(m.onOrder))) }
        if site.subleasedKW > 0 { lines.append(("Sublet", Fmt.watts(site.subleasedKW * 1000))) }
        for c in m.topChips.prefix(site.subleasedKW > 0 || m.onOrder > 0 ? 1 : 2) {
            lines.append((c.name, Fmt.int(c.count)))
        }
        return InfraBoxSpec(title: "Halls & racks", symbol: "server.rack", tint: used > 0.9 ? Theme.warning : Theme.good, lines: lines,
                            meter: used)
    }

    private func cooling(_ site: Site) -> InfraBoxSpec {
        var lines: [(String, String)] = [("Type", site.cooling.rawValue), ("PUE", Fmt.trim(site.pue, 2))]
        lines.append(("Overhead", Fmt.watts(m.coolingKW * 1000)))
        if let w = m.water { lines.append(("Water", "\(Fmt.trim(w, 2)) L/kWh")) }
        if let to = site.coolingTo { lines.append(("Retrofit", "→ \(to.rawValue)\(site.upgradeReady.map { " · \($0.gameShort)" } ?? "")")) }
        let symbol = switch site.cooling {
        case .air: "wind"
        case .liquid: "drop.fill"
        case .immersion: "drop.circle.fill"
        }
        return InfraBoxSpec(title: "Cooling loop", symbol: symbol, tint: Theme.info, lines: lines)
    }

    private func network(_ site: Site) -> InfraBoxSpec {
        var lines: [(String, String)] = []
        if site.kind == .colo || site.kind == .datacenter {
            lines.append(("Serves", site.location.region))
        } else {
            lines.append(("Serves", "Home base"))
        }
        if let f = m.fabric {
            lines.append(("Fabric", f))
        } else {
            lines.append(("Fabric", "no chips yet"))
        }
        return InfraBoxSpec(title: "Network spine", symbol: "network", tint: .purple, lines: lines)
    }

    private func operations(_ site: Site) -> InfraBoxSpec {
        var lines: [(String, String)] = [("Status", m.ready ? (site.kind == .colo ? "Handed over" : "Online") : m.status),
                                         ("Kind", "\(DCText.kind(site)) · \(site.kind == .garage || site.kind == .office ? "Home base" : site.location.name)")]
        lines.append(("Outages", m.outages == 0 ? "none on record" : "\(m.outages)\(m.lastOutage.map { " · last \($0.gameShort)" } ?? "")"))
        if !site.partner.isEmpty { lines.append(("Run by", site.partner)) }
        if site.monthlyFee > 0 { lines.append(("Rent", "\(Fmt.money(site.monthlyFee))/mo")) }
        return InfraBoxSpec(title: "Operations", symbol: "gauge.with.dots.needle.67percent", tint: Theme.neutral, lines: lines,
                            note: "Outages counted from your news log.")
    }
}

// MARK: - Pieces

struct InfraBoxSpec {
    let title: String
    let symbol: String
    let tint: Color
    let lines: [(String, String)]
    var note: String? = nil
    var meter: Double? = nil
}

private struct InfraBox: View {
    let spec: InfraBoxSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(spec.title, systemImage: spec.symbol)
                .font(TypeRamp.caption.weight(.semibold))
                .foregroundStyle(spec.tint)
                .lineLimit(1)
            if let meter = spec.meter {
                Meter(value: min(1, meter), tint: spec.tint, height: 4)
            }
            ForEach(Array(spec.lines.prefix(6).enumerated()), id: \.offset) { _, line in
                HStack(spacing: 4) {
                    Text(line.0).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(line.1).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                }
                .font(TypeRamp.micro)
            }
            if let note = spec.note {
                Text(note).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(spec.tint.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spec.title + ": " + spec.lines.map { "\($0.0) \($0.1)" }.joined(separator: ", "))
    }
}

/// The wiring between the boxes, drawn once in a Canvas: power along the top row, heat down to the cooling loop, data
/// across to the network spine.
private struct InfraWires: View {
    let boxWidth: CGFloat
    let boxHeight: CGFloat
    let gap: CGFloat
    let rowGap: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            let bw = boxWidth, bh = boxHeight
            func x(_ i: Int) -> CGFloat { CGFloat(i) * (bw + gap) }
            func arrow(_ path: inout Path, at p: CGPoint, dx: CGFloat, dy: CGFloat) {
                // A small head pointing along (dx, dy).
                let s: CGFloat = 6
                path.move(to: CGPoint(x: p.x - dx * s - dy * s * 0.6, y: p.y - dy * s + dx * s * 0.6))
                path.addLine(to: p)
                path.addLine(to: CGPoint(x: p.x - dx * s + dy * s * 0.6, y: p.y - dy * s - dx * s * 0.6))
            }
            var power = Path()
            for i in 0..<3 {
                let a = CGPoint(x: x(i) + bw, y: bh / 2)
                let b = CGPoint(x: x(i + 1), y: bh / 2)
                power.move(to: a)
                power.addLine(to: b)
                arrow(&power, at: b, dx: 1, dy: 0)
            }
            ctx.stroke(power, with: .color(.orange), lineWidth: 2)

            var heat = Path()
            let hx = x(3) + bw / 2
            heat.move(to: CGPoint(x: hx, y: bh))
            heat.addLine(to: CGPoint(x: hx, y: bh + rowGap))
            arrow(&heat, at: CGPoint(x: hx, y: bh + rowGap), dx: 0, dy: 1)
            ctx.stroke(heat, with: .color(Theme.info), lineWidth: 2)

            // Out of the halls' lower left, down the gap between the columns, into the network spine.
            var data = Path()
            let lane = x(3) - gap / 2
            let start = CGPoint(x: x(3), y: bh * 0.8)
            let end = CGPoint(x: x(2) + bw, y: bh + rowGap + bh / 2)
            data.move(to: start)
            data.addLine(to: CGPoint(x: lane, y: start.y))
            data.addLine(to: CGPoint(x: lane, y: end.y))
            data.addLine(to: end)
            arrow(&data, at: end, dx: -1, dy: 0)
            ctx.stroke(data, with: .color(.purple), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
    }
}
