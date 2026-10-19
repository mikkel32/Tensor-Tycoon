import SwiftUI

/// Datacenters & Power (3.5): a company-wide gigawatt view, your sites, the market for campuses and leased space,
/// and power deals — every action with a quote.
struct DatacentersView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: DCTab = .overview
    @State private var building = false

    enum DCTab: String, CaseIterable, Identifiable {
        case overview = "Overview", sites = "Sites", market = "Buy & lease", power = "Power"
        var id: String { rawValue }
    }

    var body: some View {
        let s = store.game
        let p = Power.summary(s)
        Page(title: "Datacenters & Power", subtitle: "Every chip you own needs power, cooling and space. Build campuses, buy them from neoclouds, miners and labs in trouble, lease space by the megawatt, and sign the power deals behind it all.", screen: .datacenters) {
            PowerDashboard(state: s, p: p)
            HStack {
                SectionTabs(selection: $tab, options: DCTab.allCases)
                Button("Build a campus", systemImage: "hammer.fill") { building = true }
                    .buttonStyle(.borderedProminent)
            }
            switch tab {
            case .overview:
                AddCapacityCard(state: s)
                SitesTable(state: s) { tab = .sites }
                DatacenterDiagramSection(state: s)
            case .sites:
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 440), spacing: 14)], spacing: 14) {
                    ForEach(s.sites) { site in SiteCard(site: site, state: s) }
                }
            case .market:
                ListingsCard(state: s)
                LeaseCard(state: s)
                LeasingOutCard(state: s)
            case .power:
                PowerDealCard(state: s)
                ContractsCard(state: s)
                QueueCard(state: s)
                PowerOptionsCard(state: s)
            }
        }
        .sheet(isPresented: $building) { BuildSiteSheet() }
    }
}

// MARK: - Company GW dashboard

private struct PowerDashboard: View {
    let state: GameState
    let p: PowerSummary

    var body: some View {
        let s = state
        let rent = s.sites.reduce(0) { $0 + $1.monthlyFee }
        let sublease = s.sites.reduce(0) { $0 + $1.subleasedKW * $1.subleaseRate }
        VStack(alignment: .leading, spacing: 12) {
            KPIRow {
                StatTile(title: "Online", value: Fmt.watts(p.onlineKW * 1000),
                         detail: "\(Fmt.watts(p.chipKW * 1000)) chips · \(Fmt.watts(p.freeKW * 1000)) free", symbol: "bolt.fill", tint: .yellow)
                StatTile(title: "On the way", value: Fmt.watts(p.pipelineKW * 1000),
                         detail: "\(Fmt.watts(p.buildingKW * 1000)) building · \(Fmt.watts(p.leasePendingKW * 1000)) leased", symbol: "hammer.fill", tint: .orange)
                StatTile(title: "Power contracts", value: Fmt.watts((p.ppaOnlineMW + p.onsiteOnlineMW) * 1e6),
                         detail: "+\(Fmt.watts((p.ppaPendingMW + p.onsitePendingMW) * 1e6)) coming · \(Fmt.watts(p.queuedMW * 1e6)) queued", symbol: "powerplug.fill", tint: .green)
                StatTile(title: "Power & space (month)", value: Fmt.money(s.month.costPower + s.month.costSites),
                         detail: "rent \(Fmt.money(rent))/mo\(sublease > 0 ? " · sublets +\(Fmt.money(sublease))/mo" : "")", symbol: "dollarsign.circle.fill", tint: .red)
            }
            Card {
                CardHeader("Company power", symbol: "bolt.horizontal.fill",
                           subtitle: "IT capacity: what your chips use, what you sublet, what's free, and what's coming. Facility draw today ≈ \(Fmt.watts(p.facilityMW * 1e6)) with cooling.\(Power.gridMultiplier(s) > 1.005 ? " Strained grids: grid power costs \(Fmt.trim(Power.gridMultiplier(s), 2))× — power deals are the hedge." : "")")
                GWBar(segments: [
                    (p.chipKW, Color.blue, "Your chips"), (p.subleasedKW, Color.purple, "Sublet"), (p.freeKW, Color.green, "Free"),
                    (p.buildingKW, Color.orange, "Building"), (p.leasePendingKW, Color.yellow, "Leased, not handed over"), (p.plannedKW, Color.gray, "Later phases"),
                ])
            }
        }
    }
}

private struct GWBar: View {
    let segments: [(Double, Color, String)]

    var body: some View {
        let total = max(1, segments.reduce(0) { $0 + $1.0 })
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        if seg.0 > 0 {
                            Rectangle().fill(seg.1.gradient).frame(width: max(2, geo.size.width * seg.0 / total))
                        }
                    }
                }
            }
            .frame(height: 14)
            .clipShape(.capsule)
            // The legend wraps on narrow windows instead of running off the card.
            LazyVGrid(columns: Theme.columns(min: 200, spacing: 10), alignment: .leading, spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    if seg.0 > 0 {
                        LegendItem(color: seg.1, label: seg.2, value: Fmt.watts(seg.0 * 1000))
                    }
                }
            }
        }
    }
}

// MARK: - One-click capacity

private struct AddCapacityCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var mw = 100.0
    @State private var template: CampusTemplate = .training

    static let amounts: [Double] = [1, 5, 20, 50, 100, 250, 500, 1_000, 2_000, 5_000, 10_000, 25_000, 50_000]

    var body: some View {
        let s = state
        let quotes = DCMarket.quotes(s, mw: mw, template: template)
        Card {
            CardHeader("Add capacity", symbol: "plus.circle.fill", subtitle: "Pick how much and what for. Your chief of staff prices the best way to build it, lease it and buy it.")
            HStack(spacing: 12) {
                Picker("Amount", selection: $mw) {
                    ForEach(Self.amounts, id: \.self) { a in Text(Fmt.watts(a * 1e6)).tag(a) }
                }
                .frame(width: 200)
                Picker("For", selection: $template) {
                    ForEach(CampusTemplate.allCases) { t in Label(t.rawValue, systemImage: t.symbol).tag(t) }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                Spacer()
            }
            Text(template.blurb).font(.caption).foregroundStyle(.secondary)
            if quotes.isEmpty {
                Text("Nobody can deliver \(Fmt.watts(mw * 1e6)) yet. Try a smaller block or come back as grids and power sources grow.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(quotes) { q in QuoteTile(quote: q, state: s) }
            }
        }
    }
}

private struct QuoteTile: View {
    @Environment(GameStore.self) private var store
    let quote: CapacityQuote
    let state: GameState

    var body: some View {
        let q = quote
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(q.kind.rawValue, systemImage: q.kind == .build ? "hammer.fill" : (q.kind == .lease ? "doc.text.fill" : "cart.fill"))
                    .font(.headline)
                Spacer()
                Text(q.location.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            SpecRow(label: "Capacity", value: Fmt.watts(q.mw * 1e6))
            SpecRow(label: "Up front", value: Fmt.money(q.upfront))
            SpecRow(label: q.kind == .lease ? "Rent + power" : "Power + upkeep", value: "\(Fmt.money(q.monthly))/mo")
            SpecRow(label: "First power", value: q.monthsToFirst < 0.5 ? "Now" : "\(Fmt.trim(q.monthsToFirst, 1)) months")
            if q.monthsToFull > q.monthsToFirst + 0.5 { SpecRow(label: "Fully online", value: "\(Fmt.trim(q.monthsToFull, 0)) months") }
            Text(q.note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button {
                store.act(q.kind == .build ? "Construction started" : (q.kind == .lease ? "Lease signed" : "Site bought")) { $0.addCapacity(q) }
            } label: {
                Text(q.kind == .build ? "Break ground" : (q.kind == .lease ? "Sign the lease" : "Buy it")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(q.upfront > state.cash)
        }
        .padding(12)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

// MARK: - Sites table

private struct SitesTable: View {
    let state: GameState
    var open: () -> Void

    var body: some View {
        let s = state
        Card {
            CardHeader(title: "Your sites", symbol: "building.2.fill", subtitle: "\(s.sites.count) sites · \(Fmt.money(Economy.siteValue(s))) in campus value") {
                Button("Manage sites") { open() }.buttonStyle(.borderless)
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Site").font(.caption.weight(.semibold))
                    Text("Kind").font(.caption.weight(.semibold))
                    Text("Where").font(.caption.weight(.semibold))
                    Text("Used / capacity").font(.caption.weight(.semibold))
                    Text("Status").font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                ForEach(s.sites) { site in
                    let load = Economy.siteLoadKW(s, site.id)
                    GridRow {
                        Text(site.name).font(.callout).lineLimit(1)
                        Text(DCText.kind(site)).font(.caption)
                        Text(site.kind == .garage || site.kind == .office ? "Home" : site.location.region).font(.caption)
                        Text("\(Fmt.watts(load * 1000)) / \(Fmt.watts(site.capacityKW * 1000))").font(.caption.monospacedDigit())
                        Text(DCText.status(site, s)).font(.caption).foregroundStyle(site.isReady(s.date) ? Color.secondary : Color.orange)
                    }
                }
            }
        }
    }
}

enum DCText {
    static func kind(_ site: Site) -> String {
        switch site.kind {
        case .colo: site.isTermLease ? (site.leaseToOwn ? "Lease-to-own" : "Wholesale lease") : "Colo cage"
        case .datacenter: site.stake > 0 ? "\(Int((site.stake * 100).rounded()))% stake" : "Owned"
        default: site.kind.rawValue
        }
    }

    static func status(_ site: Site, _ s: GameState) -> String {
        if !site.isReady(s.date) { return "\(site.kind == .colo ? "Handed over" : "Online") \(site.ready.gameShort)" }
        if site.expanding > 0, let r = site.expansionReady { return "+\(Fmt.watts(site.expanding * 1000)) \(r.gameShort)" }
        if site.rampKW > 0, let r = site.nextRamp { return "+\(Fmt.watts(min(site.rampKW, site.rampStepKW) * 1000)) \(r.gameShort)" }
        if site.upgradeReady != nil { return "Upgrading" }
        if site.subleasedKW > 0 { return "Sublet \(Fmt.watts(site.subleasedKW * 1000))" }
        return "Online"
    }
}

// MARK: - Site cards

private struct SiteCard: View {
    @Environment(GameStore.self) private var store
    let site: Site
    let state: GameState
    @State private var expandKW = 1000.0
    @State private var confirmSell = false
    @State private var moving: OwnedBatch?
    @State private var subletShare = 0.5

    var body: some View {
        let s = state
        let load = Economy.siteLoadKW(s, site.id)
        let ready = site.isReady(s.date)
        let batches = s.owned.filter { $0.siteID == site.id }
        VStack(alignment: .leading, spacing: 0) {
            Photo(key: ready ? (site.kind == .datacenter ? ImagePicker.sitePhoto(location: site.location.image, seed: site.name) : site.kind.image)
                             : ImagePicker.pick(.construction, seed: site.name))
                .frame(height: 130).frame(maxWidth: .infinity).clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.name).font(.title3.weight(.bold))
                        Text("\(DCText.kind(site)) · \(site.kind == .garage || site.kind == .office ? "Home base" : site.location.name)").font(.caption)
                    }
                    .foregroundStyle(.white).padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if !ready {
                        PhotoPill(text: "\(site.kind == .colo ? "Handed over" : "Online") \(site.ready.gameShort)", color: .orange, symbol: "hammer.fill").padding(10)
                    } else {
                        // Your garage too: the photo is somebody else's converted garage.
                        PhotoPill(text: "Illustrative photo", symbol: "photo").padding(10)
                    }
                }
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(site.subleasedKW > 0 ? "Power used (incl. \(Fmt.watts(site.subleasedKW * 1000)) sublet)" : "Power used").font(.caption)
                        Spacer()
                        Text("\(Fmt.watts(load * 1000)) / \(Fmt.watts(site.capacityKW * 1000))").font(.caption.monospacedDigit())
                    }
                    Meter(value: load / max(site.capacityKW, 0.001), tint: load / max(site.capacityKW, 0.001) > 0.9 ? .orange : .green)
                }
                if site.kind == .datacenter && (site.expanding > 0 || site.plannedKW > 0 || !ready) {
                    PhaseRow(site: site, state: s)
                }
                if site.isTermLease { LeaseInfo(site: site, state: s) }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Label(site.cooling.rawValue, systemImage: "thermometer.snowflake").font(.caption)
                        Label("PUE \(Fmt.trim(site.pue, 2))", systemImage: "gauge.medium").font(.caption)
                    }
                    GridRow {
                        Label("\(Fmt.price(site.powerPrice))/kWh", systemImage: "bolt").font(.caption)
                        Label(site.monthlyFee > 0 ? "\(Fmt.money(site.monthlyFee))/mo rent" : (site.capex > 0 ? "\(Fmt.money(site.capex)) invested" : "No rent"), systemImage: "dollarsign.circle").font(.caption)
                    }
                    if site.kind == .colo || site.kind == .datacenter {
                        GridRow {
                            Label("Serves \(site.location.region)", systemImage: "network").font(.caption)
                            Label("Water \(Fmt.trim(DCMarket.waterLPerKWh(site), 2)) L/kWh", systemImage: "drop").font(.caption)
                        }
                        if site.gridExtraKW > 0 || site.onsiteKW > 0 || site.batteryMWh > 0 || site.generation > 0 {
                            GridRow {
                                Label("Gen \(site.generation + 1) racks", systemImage: "square.stack.3d.up").font(.caption)
                                Label(powerExtras, systemImage: "powerplug").font(.caption)
                            }
                        }
                        if !site.partner.isEmpty {
                            GridRow {
                                Label("Run by \(site.partner)", systemImage: "person.2").font(.caption)
                                Text("")
                            }
                        }
                    }
                }
                .foregroundStyle(.secondary)
                if !batches.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Housed here").font(.caption.weight(.semibold))
                        ForEach(batches) { b in
                            HStack {
                                Text("\(Fmt.int(b.count))× \(HardwareCatalog.get(b.accelID)?.name ?? b.accelID)").font(.caption)
                                Text("· \(b.purchased.gameMonth)").font(.caption2).foregroundStyle(.tertiary)
                                Spacer()
                                Button("Move…") { moving = b }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    .disabled(s.sites.count < 2)
                            }
                        }
                    }
                }
                if site.kind == .colo || site.kind == .datacenter {
                    Picker("Power", selection: Binding(get: { site.powerDeal }, set: { d in store.act("Power: \(d.rawValue)") { $0.setPowerDeal(site.id, d) } })) {
                        ForEach(PowerDeal.allCases.filter { $0.available(s) && (site.kind == .datacenter || $0.siteCapMW == 0 || $0 == .nuclear) }) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    if !site.isTermLease { ExpandRow(site: site, state: s, expandKW: $expandKW) }
                    if site.kind == .datacenter && ready { UpgradeRow(site: site, state: s) }
                    SubleaseRow(site: site, state: s)
                    HStack {
                        if site.plannedKW > 0 {
                            Button("Cancel later phases") { store.act("Later phases cancelled") { $0.cancelPlannedPhases(site.id) } }
                                .buttonStyle(.borderless).font(.caption)
                        }
                        if site.leaseToOwn && site.isTermLease {
                            Button("Buy out (\(Fmt.money(DCMarket.buyoutPrice(site, s))))") { store.act("Site bought out") { $0.buyOutLease(site.id) } }
                                .buttonStyle(.borderless).font(.caption)
                        }
                        Spacer()
                        Button(site.kind == .colo ? "End lease…" : "Sell site…", role: .destructive) { confirmSell = true }
                            .buttonStyle(.borderless).font(.caption)
                    }
                } else {
                    Text(site.kind == .garage ? "Consumer & workstation cards only (≤600 W each). For datacenter GPUs, lease space or buy a datacenter." : "Up to 1,000 W per chip, air-cooled.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .background(.background.secondary, in: .rect(cornerRadius: Theme.corner))
        .clipShape(.rect(cornerRadius: Theme.corner))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
        .confirmationDialog(site.kind == .colo ? "End the lease on \(site.name)?" : "Sell \(site.name)?", isPresented: $confirmSell) {
            Button(site.kind == .colo ? "End lease (\(Fmt.money(DCMarket.exitFee(site, s))) fee)" : "Sell for \(Fmt.money(Campus.salePrice(site, s)))", role: .destructive) {
                store.act(site.kind == .colo ? "Lease ended" : "Site sold") { $0.sellSite(site.id) }
            }
        } message: {
            Text(batches.isEmpty ? "This can't be undone." : "Move or sell the chips housed here first.")
        }
        .popover(item: $moving) { b in MoveChipsPanel(batch: b, state: s) }
    }

    private var powerExtras: String {
        var parts: [String] = []
        if site.gridExtraKW > 0 { parts.append("+\(Fmt.watts(site.gridExtraKW * 1000)) grid") }
        if site.onsiteKW > 0 { parts.append("\(Fmt.watts(site.onsiteKW * 1000)) on-site") }
        if site.batteryMWh > 0 { parts.append("\(Fmt.trim(site.batteryMWh, 0)) MWh batteries") }
        return parts.isEmpty ? "Grid" : parts.joined(separator: " · ")
    }
}

private struct LeaseInfo: View {
    let site: Site
    let state: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(Fmt.money(site.leaseRate))/kW-month").font(.caption.weight(.semibold))
                Spacer()
                if let end = site.leaseEnd { Text("Term ends \(end.gameShort)").font(.caption).foregroundStyle(.secondary) }
            }
            if site.rampKW > 0, let next = site.nextRamp {
                Label("\(Fmt.watts(site.rampKW * 1000)) still to come · next +\(Fmt.watts(min(site.rampKW, site.rampStepKW) * 1000)) \(next.gameShort)", systemImage: "calendar")
                    .font(.caption).foregroundStyle(.orange)
            }
            if site.leaseToOwn { Label("Yours at the end of the term", systemImage: "key.fill").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// Online, building and planned capacity of a phased campus, with each phase's date and cost.
private struct PhaseRow: View {
    let site: Site
    let state: GameState

    var body: some View {
        let total = Campus.plannedTotalKW(site)
        let online = site.isReady(state.date) ? site.capacityKW : 0
        let phases = Campus.schedule(site, state)
        let remaining = phases.reduce(0) { $0 + $1.cost }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Campus build-out").font(.caption)
                Spacer()
                Text("\(Fmt.watts(online * 1000)) of \(Fmt.watts(total * 1000)) online").font(.caption.monospacedDigit())
            }
            GeometryReader { geo in
                let w = geo.size.width
                let a = online / max(total, 1)
                let b = (site.expanding + (site.isReady(state.date) ? 0 : site.capacityKW)) / max(total, 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.orange.opacity(0.5)).frame(width: max(0, (a + b) * w))
                    Capsule().fill(Color.green.gradient).frame(width: max(0, a * w))
                }
            }
            .frame(height: 8)
            ForEach(Array(phases.prefix(4).enumerated()), id: \.offset) { _, ph in
                HStack {
                    Image(systemName: ph.building ? "hammer.fill" : "calendar").foregroundStyle(ph.building ? .orange : .secondary)
                    Text("+\(Fmt.watts(ph.kw * 1000))").monospacedDigit()
                    Spacer()
                    Text(ph.building ? "ready \(ph.ready.gameShort)" : "starts \(ph.start.gameShort) · \(Fmt.money(ph.cost)) · ready ~\(ph.ready.gameShort)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            if phases.count > 4 { Text("…and \(phases.count - 4) more phases").font(.caption2).foregroundStyle(.tertiary) }
            HStack {
                Text("Spent \(Fmt.money(site.capex))").font(.caption2)
                Spacer()
                Text("Still to pay \(Fmt.money(remaining))\(site.phaseBlocked ? " · waiting for cash" : "")").font(.caption2)
                    .foregroundStyle(site.phaseBlocked ? .red : .secondary)
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct ExpandRow: View {
    @Environment(GameStore.self) private var store
    let site: Site
    let state: GameState
    @Binding var expandKW: Double

    static let steps: [(String, Double)] = [("100 kW", 100), ("1 MW", 1_000), ("10 MW", 10_000), ("100 MW", 100_000), ("500 MW", 500_000),
                                            ("1 GW", 1_000_000), ("5 GW", 5_000_000), ("10 GW", 10_000_000), ("25 GW", 25_000_000),
                                            ("50 GW", 50_000_000), ("100 GW", 100_000_000)]

    var body: some View {
        let s = state
        let capKW = site.kind == .colo ? Campus.coloCapMW * 1000 : Campus.siteLimitMW(site, nil, s) * 1000
        let headroom = max(0, capKW - Campus.plannedTotalKW(site))
        let options = Self.steps.filter { $0.1 <= headroom + 0.01 }
        VStack(alignment: .leading, spacing: 4) {
            if options.isEmpty {
                Text("At the limit for \(site.powerDeal.rawValue.lowercased()) here (\(Fmt.watts(capKW * 1000))). Join the grid queue, build on-site power, or add another site.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Expand by").font(.caption)
                    Picker("", selection: $expandKW) {
                        ForEach(options, id: \.1) { o in Text(o.0).tag(o.1) }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    Button("Expand") { store.act(site.kind == .colo ? "Lease extended" : "Expansion queued") { $0.expandSite(site.id, addKW: expandKW) } }
                        .disabled(expandKW > headroom + 0.01)
                    Spacer()
                    Text(cost(s)).font(.caption).foregroundStyle(.secondary)
                }
                Text("Room for \(Fmt.watts(headroom * 1000)) more\(site.kind == .datacenter && Campus.phases(mw: expandKW / 1000) > 1 ? " · built in \(Campus.phases(mw: expandKW / 1000)) phases" : "")")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func cost(_ s: GameState) -> String {
        switch site.kind {
        case .colo: return "+\(Fmt.money(site.location.coloFee * expandKW * (site.cooling == .air ? 1 : 1.35)))/mo"
        case .datacenter:
            let months = s.buildMonths(mw: expandKW / 1000 / Double(Campus.phases(mw: expandKW / 1000)), loc: site.location, power: site.powerDeal) * 0.6
            return "\(Fmt.money(expandKW / 1000 * Campus.capexPerMW(site.cooling, s, location: site.locationID))) · first power ~\(Fmt.trim(months, 0)) mo"
        default: return ""
        }
    }
}

private struct UpgradeRow: View {
    @Environment(GameStore.self) private var store
    let site: Site
    let state: GameState

    var body: some View {
        let s = state
        let next: Cooling? = site.cooling == .air ? .liquid : (site.cooling == .liquid && s.bonuses.has(.immersion) ? .immersion : nil)
        HStack(spacing: 10) {
            if let ready = site.upgradeReady {
                Label("\(site.coolingTo.map { "\($0.rawValue) retrofit" } ?? "Re-racking") done \(ready.gameShort)", systemImage: "wrench.and.screwdriver.fill")
                    .font(.caption).foregroundStyle(.orange)
            } else {
                if let next {
                    Button("\(next == .liquid ? "Liquid" : "Immersion") retrofit (\(Fmt.money(Campus.coolingRetrofitCost(site, to: next, s))))") {
                        store.act("Retrofit started") { $0.upgradeCooling(site.id, to: next) }
                    }
                    .font(.caption)
                }
                if site.generation < 3 {
                    Button("Re-rack: +10% (\(Fmt.money(Campus.generationCost(site, s))))") { store.act("Re-racking") { $0.upgradeGeneration(site.id) } }
                        .font(.caption)
                }
            }
            Spacer()
        }
    }
}

private struct SubleaseRow: View {
    @Environment(GameStore.self) private var store
    let site: Site
    let state: GameState
    @State private var share = 0.5
    @State private var years = 3

    var body: some View {
        let s = state
        let free = max(0, site.capacityKW - Economy.siteLoadKW(s, site.id))
        if site.subleasedKW > 0 {
            HStack {
                Label("\(site.subleaseTenant) rents \(Fmt.watts(site.subleasedKW * 1000)) at \(Fmt.money(site.subleaseRate))/kW-mo (+\(Fmt.money(site.subleasedKW * site.subleaseRate))/mo) until \(site.subleaseEnd?.gameShort ?? "—")",
                      systemImage: "person.2.badge.key.fill")
                    .font(.caption).foregroundStyle(.purple)
                Spacer()
                Button("Buy out tenant") { store.act("Sublease ended") { $0.endSublease(site.id) } }.font(.caption).buttonStyle(.borderless)
            }
        } else if site.isReady(s.date) && free >= 100 {
            let kw = max(100, free * share)
            HStack {
                Text("Sublet").font(.caption)
                Picker("", selection: $share) {
                    Text("25%").tag(0.25); Text("50%").tag(0.5); Text("All free").tag(1.0)
                }
                .labelsHidden().frame(width: 90)
                Picker("", selection: $years) {
                    Text("1 yr").tag(1); Text("3 yrs").tag(3); Text("5 yrs").tag(5); Text("10 yrs").tag(10)
                }
                .labelsHidden().frame(width: 80)
                Button("Sublet \(Fmt.watts(kw * 1000))") { store.act("Space sublet") { $0.sublease(site.id, kw: kw, years: years) } }
                    .font(.caption)
                Spacer()
                Text("+\(Fmt.money(DCMarket.subleaseRate(site, kw: kw, years: years, s) * kw))/mo").font(.caption).foregroundStyle(.secondary)
            }
            if site.kind == .datacenter && site.stake == 0 && load(s) == 0 {
                Button("Lease the whole campus to a hyperscaler (10 yrs, +\(Fmt.money(DCMarket.subleaseRate(site, kw: site.capacityKW, years: 10, s) * 1.05 * site.capacityKW))/mo)") {
                    store.act("Campus leased out") { $0.leaseOutCampus(site.id, years: 10) }
                }
                .font(.caption).buttonStyle(.borderless)
            }
        }
    }

    private func load(_ s: GameState) -> Int {
        s.owned.filter { $0.siteID == site.id }.reduce(0) { $0 + $1.count } + s.orders.filter { $0.siteID == site.id }.reduce(0) { $0 + $1.count }
    }
}

/// Truck chips from one site to another.
private struct MoveChipsPanel: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let batch: OwnedBatch
    let state: GameState
    @State private var destID: UUID?
    @State private var qty = 0

    var body: some View {
        let s = state
        let a = HardwareCatalog.get(batch.accelID)
        let targets = s.sites.filter { $0.id != batch.siteID && $0.kind != .garage }
        VStack(alignment: .leading, spacing: 10) {
            Text("Move \(a?.name ?? batch.accelID)").font(.title3.weight(.bold))
            Picker("To", selection: $destID) {
                Text("Choose a site…").tag(UUID?.none)
                ForEach(targets) { t in
                    let free = t.capacityKW - Economy.siteLoadKW(s, t.id)
                    Text("\(t.name) — \(Fmt.watts(max(0, free) * 1000)) free\(t.isReady(s.date) ? "" : " (being built)")").tag(UUID?.some(t.id))
                }
            }
            HStack {
                Text("Chips")
                Spacer()
                QuantityPicker(value: $qty, range: 1...max(1, batch.count), presets: [1, 64, 512, 4096, 32_768, 262_144])
            }
            if let a {
                Text("Logistics \(Fmt.money(Double(max(qty, 0)) * Campus.moveCostPerChip(a))) · needs \(Fmt.watts(Economy.chipKW(a) * Double(max(qty, 0)) * 1000)) at the destination")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                guard let destID else { return }
                if store.act("Chips moved", { $0.moveHardware(batchID: batch.id, count: qty, to: destID) }) { dismiss() }
            } label: {
                Label("Move", systemImage: "box.truck.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(destID == nil || qty < 1)
        }
        .padding(16)
        .frame(width: 400)
        .onAppear { qty = batch.count }
    }
}

// MARK: - Market: for sale

private struct ListingsCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("For sale", symbol: "cart.fill", subtitle: "Finished halls and campuses, powered shells and stakes. New listings every month; buy as many as you like.")
            if s.dcListings.isEmpty {
                Text("Nothing listed right now. Check back next month.").font(.callout).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                ForEach(s.dcListings) { l in ListingTile(listing: l, state: s) }
            }
        }
    }
}

private struct ListingTile: View {
    @Environment(GameStore.self) private var store
    let listing: DCListing
    let state: GameState
    @State private var share = 1.0

    var body: some View {
        let l = listing
        let f = clamp(share, l.minStake, 1)
        VStack(alignment: .leading, spacing: 6) {
            IllustrativeBanner(key: l.image, height: 76)
            HStack {
                Image(systemName: l.seller.symbol).foregroundStyle(.secondary)
                Text(l.name).font(.headline).lineLimit(1)
                Spacer()
                Pill(text: l.readyDays == 0 ? "Ready now" : "Ready \(GameCalendar.addDays(state.date, l.readyDays).gameShort)", color: l.readyDays == 0 ? .green : .orange)
            }
            Text("\(l.seller.rawValue) · \(l.sellerName) · \(l.location.name)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            SpecRow(label: "Capacity", value: Fmt.watts(l.mw * 1e6))
            SpecRow(label: "Cooling · PUE", value: "\(l.cooling.rawValue) · \(Fmt.trim(max(1.03, l.cooling.basePUE + l.location.pueDelta - l.pueGain), 2))")
            SpecRow(label: "Price", value: "\(Fmt.money(l.price)) (\(Fmt.money(l.perMW))/MW)")
            Text(l.seller.blurb).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            if l.minStake < 1 {
                HStack {
                    Text("Stake \(Fmt.pct(f, decimals: 0))").font(.caption).frame(width: 80, alignment: .leading)
                    Slider(value: $share, in: l.minStake...1, step: 0.05)
                }
            }
            Button {
                store.act(f < 1 ? "Stake bought" : "Site bought") { $0.buyListing(l.id, share: f) }
            } label: {
                Text(f < 1 ? "Buy \(Fmt.pct(f, decimals: 0)) for \(Fmt.money(l.price * f))" : "Buy for \(Fmt.money(l.price))").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(l.price * f > state.cash)
        }
        .padding(12)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

// MARK: - Market: lease

private struct LeaseCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var locationID = "texas"
    @State private var mw = 10.0
    @State private var years = 5
    @State private var cooling: Cooling = .liquid
    @State private var ramp = true
    @State private var toOwn = false

    static let amounts: [Double] = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1_000, 2_000, 5_000, 10_000, 25_000]

    var body: some View {
        let s = state
        let loc = LocationCatalog.byID[locationID] ?? LocationCatalog.all[0]
        let rate = DCMarket.leaseRate(loc, mw: mw, years: years, cooling: cooling, toOwn: toOwn, s)
        let days = DCMarket.leaseLeadDays(mw: mw, loc, s)
        let ramped = ramp && mw > 100
        let maxMW = DCMarket.maxLeaseMW(loc, s)
        Card {
            CardHeader("Lease space by the megawatt", symbol: "doc.text.fill",
                       subtitle: "Wholesale colocation: 1 MW to multi-GW, 1–15 years. Rent starts when space is handed over; big blocks are built to suit.")
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Region", selection: $locationID) {
                        ForEach(LocationCatalog.all) { l in Text("\(l.name) · \(l.region)").tag(l.id) }
                    }
                    Picker("Capacity", selection: $mw) {
                        ForEach(Self.amounts, id: \.self) { a in Text(Fmt.watts(a * 1e6)).tag(a) }
                    }
                    Picker("Term", selection: $years) {
                        ForEach([1, 2, 3, 5, 7, 10, 15], id: \.self) { y in Text("\(y) year\(y == 1 ? "" : "s")").tag(y) }
                    }
                    Picker("Cooling", selection: $cooling) {
                        ForEach(Cooling.allCases) { c in Text(c.rawValue).tag(c).disabled(c == .immersion && !s.bonuses.has(.immersion)) }
                    }
                    Toggle("Hand over in quarterly tranches (blocks over 100 MW)", isOn: $ramp)
                    Toggle("Lease-to-own (5+ years, +25% rent, yours at the end)", isOn: $toOwn)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    SpecRow(label: "Rent", value: "\(Fmt.money(rate))/kW-month")
                    SpecRow(label: "At full size", value: "\(Fmt.money(rate * mw * 1000))/mo")
                    SpecRow(label: "Deposit now", value: Fmt.money(rate * mw * 1000))
                    SpecRow(label: ramped ? "First 25%" : "Handed over", value: GameCalendar.addDays(s.date, ramped ? Int(Double(days) * 0.6) : days).gameShort)
                    if ramped { SpecRow(label: "Fully handed over", value: "~\(GameCalendar.addDays(s.date, Int(Double(days) * 0.6) + 273).gameShort)") }
                    SpecRow(label: "PUE · power", value: "\(Fmt.trim(cooling.basePUE + 0.07 + loc.pueDelta * 0.5, 2)) · \(Fmt.price(loc.powerPrice * 1.1))/kWh")
                    if mw > maxMW { Text("Providers here can deliver at most \(Fmt.watts(maxMW * 1e6)) in one lease this year.").font(.caption).foregroundStyle(.red) }
                    Button {
                        store.act("Lease signed") { $0.leaseCapacity(locationID: locationID, mw: mw, years: years, cooling: cooling, ramp: ramp, toOwn: toOwn) }
                    } label: {
                        Label("Sign the lease", systemImage: "signature").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(mw > maxMW || (toOwn && years < 5))
                }
                .frame(width: 320)
            }
            Text(loc.blurb).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Market: leasing out

private struct LeasingOutCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let sublets = s.sites.filter { $0.subleasedKW > 0 }
        let chips = s.leases.values.reduce(0, +)
        Card {
            CardHeader("Leasing out", symbol: "arrow.up.right.square.fill",
                       subtitle: "Two ways to earn from spare capacity: rent idle chips as a GPU cloud, or sublet empty space (tenants bring their own chips and pay their own power).")
            KPIRow {
                StatTile(title: "Chips leased out", value: Fmt.int(chips), detail: "+\(Fmt.money(s.leaseRevenueToday * 30.4))/mo", symbol: "cpu", tint: .orange)
                StatTile(title: "Space sublet", value: Fmt.watts(sublets.reduce(0) { $0 + $1.subleasedKW } * 1000),
                         detail: "+\(Fmt.money(s.subleaseRevenueToday * 30.4))/mo", symbol: "person.2.badge.key.fill", tint: .purple)
            }
            ForEach(sublets) { site in
                HStack {
                    Text(site.name).font(.callout)
                    Spacer()
                    Text("\(site.subleaseTenant) · \(Fmt.watts(site.subleasedKW * 1000)) · \(Fmt.money(site.subleaseRate))/kW-mo · until \(site.subleaseEnd?.gameShort ?? "—")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Sublet space from each site's card. Lease idle chips on the Chip sales page, or let the leasing delegate do it.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Open Chip sales") { store.open(.chipSales) }.buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - Power

private struct PowerDealCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var kind: PowerKind = .solar
    @State private var locationID = "texas"
    @State private var siteID: UUID?
    @State private var mw = 100.0
    @State private var years = 15

    static let amounts: [Double] = [10, 25, 50, 100, 250, 500, 1_000, 2_000, 5_000, 10_000, 25_000]

    var body: some View {
        let s = state
        let campuses = s.sites.filter { $0.kind == .datacenter }
        let site = campuses.first { $0.id == siteID }
        let loc = kind.onSite ? (site?.locationID ?? locationID) : locationID
        let q = Power.quote(kind, locationID: loc, siteID: kind.onSite ? site?.id : nil, mw: mw, s)
        Card {
            CardHeader("Sign a power deal", symbol: "powerplug.fill",
                       subtitle: "Purchase agreements lock in cheap, clean power for your sites in a region. On-site generation and grid upgrades raise how big a campus can grow.")
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Kind", selection: $kind) {
                        ForEach(PowerKind.allCases) { k in
                            Text(k.available(s) ? k.rawValue : "\(k.rawValue) (from \(Int(k.availableFrom)))").tag(k)
                        }
                    }
                    .onChange(of: kind) { _, k in
                        if let l = k.locations, !l.contains(locationID), let first = l.first { locationID = first }
                    }
                    IllustrativeBanner(key: kind.image, height: 90)
                    Text(kind.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if kind.onSite {
                        Picker("Campus", selection: $siteID) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(campuses) { c in Text("\(c.name) · \(c.location.name)").tag(UUID?.some(c.id)) }
                        }
                        if campuses.isEmpty { Text("You need a campus you own first.").font(.caption).foregroundStyle(.orange) }
                    } else {
                        Picker("Region", selection: $locationID) {
                            ForEach(LocationCatalog.all.filter { kind.locations?.contains($0.id) ?? true }) { l in Text(l.name).tag(l.id) }
                        }
                    }
                    Picker(kind == .battery ? "Storage (4-hour)" : "Size (average MW)", selection: $mw) {
                        ForEach(Self.amounts, id: \.self) { a in Text(Fmt.watts(a * 1e6)).tag(a) }
                    }
                    if !kind.onSite {
                        Picker("Term", selection: $years) {
                            ForEach([5, 10, 15, 20], id: \.self) { y in Text("\(y) years").tag(y) }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    if kind.suppliesEnergy { SpecRow(label: "Energy price", value: "\(Fmt.money(q.priceMWh))/MWh") }
                    if kind.suppliesEnergy && kind.capacityFactor < 0.8 { SpecRow(label: "Nameplate", value: Fmt.watts(mw / kind.capacityFactor * 1e6)) }
                    SpecRow(label: "Up front", value: Fmt.money(q.upfront))
                    SpecRow(label: kind == .interconnect ? "Queue wait" : "First power", value: "\(Fmt.trim(q.months, 0)) months · \(GameCalendar.addDays(s.date, Int(q.months * 30.4)).gameShort)")
                    if kind.suppliesEnergy, let l = LocationCatalog.byID[loc] {
                        SpecRow(label: "Local grid", value: "\(Fmt.money(l.powerPrice * 1000))/MWh")
                    }
                    if let e = q.error { Text(e).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                    Button {
                        store.act("Power deal signed") { $0.signPower(kind, locationID: loc, siteID: kind.onSite ? site?.id : nil, mw: mw, years: years) }
                    } label: {
                        Label("Sign", systemImage: "signature").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(q.error != nil)
                }
                .frame(width: 320)
            }
        }
    }
}

private struct ContractsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let list = s.powerContracts.filter { $0.kind != .interconnect }
        Card {
            CardHeader("Power contracts", symbol: "list.bullet.rectangle.fill", subtitle: "Energy from contracts replaces grid power at the contract price; anything your sites don't use is sold back at a discount.")
            if list.isEmpty { Text("No power deals yet. Your sites buy from the grid at the local rate.").font(.callout).foregroundStyle(.secondary) }
            ForEach(list) { c in
                HStack {
                    Image(systemName: c.kind.symbol).foregroundStyle(c.kind.green ? .green : .secondary).frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(Fmt.watts(c.mw * 1e6)) \(c.kind.rawValue.lowercased())").font(.callout)
                        Text("\(c.siteID.flatMap { id in s.sites.first { $0.id == id }?.name } ?? c.location.name)\(c.kind.suppliesEnergy ? " · \(Fmt.money(c.priceMWh))/MWh" : "")\(c.end.map { " · until \($0.gameShort)" } ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if c.isOnline(s.date) {
                        Pill("Online", tone: .good)
                    } else {
                        Pill(text: "Online \(c.online.gameShort)", color: .orange)
                    }
                    if !(c.isOnline(s.date) && c.kind.onSite) {
                        Button(c.isOnline(s.date) ? "Break…" : "Cancel") { store.act("Contract cancelled") { $0.cancelPower(c.id) } }
                            .buttonStyle(.borderless).font(.caption)
                    }
                }
            }
        }
    }
}

private struct QueueCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let queued = s.powerContracts.filter { $0.kind == .interconnect }
        Card {
            CardHeader("Grid interconnection queue", symbol: "point.3.connected.trianglepath.dotted",
                       subtitle: "How long the utilities make you wait for a bigger connection this year (for 500 MW). Join from the power-deal form with a campus picked.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(LocationCatalog.all) { l in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.name).font(.caption.weight(.semibold)).lineLimit(1)
                        Text("\(Fmt.trim(Power.queueMonths(l, mw: 500, s), 0)) months").font(.title3.weight(.bold).monospacedDigit())
                        Text("grid ≤\(Fmt.watts(l.gridCap(s.year) * 1e6)) a site").font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
                }
            }
            ForEach(queued) { c in
                HStack {
                    Text("\(Fmt.watts(c.mw * 1e6)) for \(c.siteID.flatMap { id in s.sites.first { $0.id == id }?.name } ?? c.location.name)").font(.callout)
                    Spacer()
                    Text(c.isOnline(s.date) ? "Connected" : "Connects \(c.online.gameShort)").font(.caption).foregroundStyle(.secondary)
                    if !c.isOnline(s.date) {
                        Button("Leave queue") { store.act("Left the queue") { $0.cancelPower(c.id) } }.buttonStyle(.borderless).font(.caption)
                    }
                }
            }
        }
    }
}

/// How big one campus can get on each kind of power, at the best location for it.
private struct PowerOptionsCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("How big can one new campus get?", symbol: "bolt.horizontal.fill",
                       subtitle: "Largest new site on each kind of power this year (best location). The grid queue and on-site generation push a site past these.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(PowerDeal.allCases) { deal in
                    let cap = LocationCatalog.all.map { Campus.siteCapMW($0, deal, s) }.max() ?? 0
                    let open = deal.available(s)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deal.rawValue).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(open ? Fmt.watts(cap * 1e6) : "From \(Int(deal.availableFrom))").font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(open ? .primary : .secondary)
                        Text("\(Fmt.trim(deal.priceMultiplier, 2))× grid price").font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
                    .opacity(open ? 1 : 0.6)
                }
            }
        }
    }
}

// MARK: - Build sheet

struct BuildSiteSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: SiteKind = .datacenter
    @State private var template: CampusTemplate = .training
    @State private var locationID = "texas"
    @State private var capacityMW = 50.0
    @State private var cooling: Cooling = .liquid
    @State private var power: PowerDeal = .grid
    @State private var name = ""

    var body: some View {
        let s = store.game
        let loc = LocationCatalog.byID[locationID]!
        let capMW = kind == .colo ? Campus.coloCapMW : Campus.siteCapMW(loc, power, s)
        let mw = min(capacityMW, capMW)
        let kw = mw * 1000
        let deals = PowerDeal.allCases.filter { $0.available(s) && (kind == .datacenter || $0.siteCapMW == 0 || $0 == .nuclear) }
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("New site").font(.title2.weight(.bold))
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Picker("Type", selection: $kind) {
                Text("Build your own campus").tag(SiteKind.datacenter)
                Text("Month-to-month colo cage").tag(SiteKind.colo)
            }
            .pickerStyle(.segmented)
            .onChange(of: kind) { _, k in
                capacityMW = k == .colo ? 1 : 50
                if k == .colo && (power == .gas || power == .smr || power == .fusion) { power = .grid }
            }
            if kind == .datacenter {
                HStack {
                    Text("Template").font(.headline)
                    Picker("", selection: $template) {
                        ForEach(CampusTemplate.allCases) { t in Label(t.rawValue, systemImage: t.symbol).tag(t) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 340)
                    .onChange(of: template) { _, t in
                        cooling = s.year >= 2023 ? .liquid : .air
                        capacityMW = t == .training ? max(50, min(capMW, DCMarket.typicalMW(s.year) * 2)) : 20
                        if t == .inference && !CampusTemplate.edgeLocations.contains(locationID) { locationID = "nova" }
                    }
                }
                Text(template.blurb).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("A cage in a shared hall, month to month, up to \(Int(Campus.coloCapMW)) MW. For bigger blocks and lower rent, sign a wholesale lease on the Buy & lease tab.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text("Location").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                ForEach(LocationCatalog.all) { l in
                    Button { locationID = l.id } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Photo(key: l.image).frame(height: 60).frame(maxWidth: .infinity).clipped()
                                .illustrativePhoto(!l.photoShowsPlace, key: l.image)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(l.name).font(.callout.weight(.semibold)).lineLimit(1)
                                    if template == .inference && CampusTemplate.edgeLocations.contains(l.id) && kind == .datacenter {
                                        Image(systemName: "network").font(.caption).foregroundStyle(.blue)
                                    }
                                }
                                Text("\(Fmt.price(l.powerPrice))/kWh · PUE \(l.pueDelta >= 0 ? "+" : "")\(Fmt.trim(l.pueDelta, 2)) · grid ≤\(Fmt.watts(l.gridCap(s.year) * 1e6)) · queue \(Fmt.trim(Power.queueMonths(l, mw: 500, s), 0)) mo")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(8)
                        }
                        .background(.background.secondary, in: .rect(cornerRadius: 10))
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(locationID == l.id ? Color.accentColor : .clear, lineWidth: 2.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(loc.blurb).font(.caption).foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Power", selection: $power) {
                        ForEach(deals) { p in Text(p.rawValue).tag(p) }
                    }
                    Text(power.blurb).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("Capacity")
                        Spacer()
                        Text(Fmt.watts(kw * 1000)).font(.body.monospacedDigit().weight(.semibold))
                    }
                    LogSlider(value: $capacityMW, range: kind == .colo ? 0.05...Campus.coloCapMW : 5...max(6, capMW))
                    Text("Up to \(Fmt.watts(capMW * 1e6)) here on \(power.rawValue.lowercased()) · ≈ \(Fmt.count(kw / Economy.chipKW(HardwareCatalog.h100))) H100s or \(Fmt.count(kw / Economy.chipKW(HardwareCatalog.get("gb200")!))) GB200s")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Cooling", selection: $cooling) {
                        ForEach(Cooling.allCases) { c in Text(c.rawValue).tag(c).disabled(c == .immersion && !s.bonuses.has(.immersion)) }
                    }
                    TextField("Site name", text: $name).textFieldStyle(.roundedBorder)
                }
                .frame(maxWidth: .infinity)

                Card {
                    CardHeader("Quote", symbol: "doc.text.magnifyingglass")
                    if kind == .colo {
                        let fee = loc.coloFee * kw * (cooling == .air ? 1 : 1.35)
                        SpecRow(label: "Monthly lease", value: Fmt.money(fee))
                        SpecRow(label: "Ready in", value: "30 days")
                    } else {
                        let n = Campus.phases(mw: mw)
                        let phaseMW = mw / Double(n)
                        let first = s.buildMonths(mw: phaseMW, loc: loc, power: power)
                        let totalMonths = first + Double(n - 1) * first * 0.35
                        // 3.4 overhaul: the home build incentive comes off each phase's price.
                        let perMW = Campus.capexPerMW(cooling, s, location: locationID)
                        let incentive = 1 - HQ.buildCost(s, location: locationID)
                        let saved = mw * Campus.capexPerMW(cooling, s) * incentive
                        SpecRow(label: "Construction cost", value: Fmt.money(mw * perMW))
                        if incentive > 0 {
                            SpecRow(label: HQ.country(s).adjective + " build incentive", value: "−" + Fmt.money(saved) + " (−" + Fmt.pct(incentive, decimals: 0) + ")", tone: .good)
                        }
                        SpecRow(label: "Per MW", value: Fmt.money(perMW))
                        if n > 1 {
                            SpecRow(label: "Phases", value: "\(n) × \(Fmt.watts(phaseMW * 1e6))")
                            SpecRow(label: "First phase", value: "\(Fmt.money(phaseMW * perMW)) · \(Fmt.trim(first, 1)) months")
                            SpecRow(label: "Fully built", value: "~\(Fmt.trim(totalMonths, 0)) months")
                        } else {
                            SpecRow(label: "Build time", value: "\(Fmt.trim(first, 1)) months")
                        }
                        SpecRow(label: "Maintenance", value: "\(Fmt.money(mw * perMW * 0.015))/yr")
                    }
                    let pue = kind == .colo ? cooling.basePUE + 0.07 + loc.pueDelta * 0.5 : cooling.basePUE + loc.pueDelta
                    let price = loc.powerPrice * power.priceMultiplier * (kind == .colo ? 1.1 : 1)
                    SpecRow(label: "PUE", value: Fmt.trim(pue, 2))
                    SpecRow(label: "Power price", value: "\(Fmt.price(price))/kWh")
                    SpecRow(label: "Full-load power bill", value: "\(Fmt.money(kw * pue * 24 * 30.4 * price))/mo")
                    SpecRow(label: "Serves", value: loc.region)
                    Button {
                        let n = name.isEmpty ? "\(loc.name.split(separator: ",").first ?? "Site") \(kind == .colo ? "Colo" : (template == .inference ? "Edge" : "Campus"))" : name
                        if store.act(kind == .colo ? "Lease signed" : "Construction started", { $0.buildSite(kind: kind, locationID: locationID, capacityKW: kw, cooling: cooling, power: power, name: n) }) {
                            dismiss()
                        }
                    } label: {
                        Label(kind == .colo ? "Sign lease" : "Break ground", systemImage: "hammer.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(width: 340)
            }
        }
        .padding(22)
        .frame(width: 920)
    }
}
