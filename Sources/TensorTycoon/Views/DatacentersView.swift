import SwiftUI

struct DatacentersView: View {
    @Environment(GameStore.self) private var store
    @State private var building = false

    var body: some View {
        let s = store.game
        let online = s.sites.filter { $0.isReady(s.date) }.reduce(0) { $0 + $1.capacityKW }
        let usedKW = s.sites.reduce(0.0) { $0 + Economy.siteLoadKW(s, $1.id) }
        let underway = s.sites.reduce(0.0) { $0 + $1.expanding + ($1.isReady(s.date) ? 0 : $1.capacityKW) }
        let planned = s.sites.reduce(0.0) { $0 + $1.plannedKW }
        Page(title: "Datacenters & Power", subtitle: "Owned hardware needs a home: power, cooling and space. Grid sites are limited by the local grid; on-site gas, reactors and later fusion take one campus to tens of gigawatts. Big campuses come online a phase at a time.") {
            HStack(spacing: 12) {
                StatTile(title: "IT capacity online", value: Fmt.watts(online * 1000), detail: "\(Fmt.watts(usedKW * 1000)) committed to chips", symbol: "bolt.fill", tint: .yellow)
                StatTile(title: "Being built", value: Fmt.watts(underway * 1000),
                         detail: planned > 0 ? "+\(Fmt.watts(planned * 1000)) in later phases" : "\(s.sites.filter { !$0.isReady(s.date) }.count) new sites",
                         symbol: "hammer.fill", tint: .orange)
                StatTile(title: "Power bill (month)", value: Fmt.money(s.month.costPower), detail: "So far this month", symbol: "powerplug.fill", tint: .red)
                StatTile(title: "Sites", value: "\(s.sites.count)", detail: "\(Fmt.money(Economy.siteValue(s))) in campus value", symbol: "building.2.fill", tint: .indigo)
            }
            PowerOptionsCard(state: s)
            HStack {
                Text("Your sites").font(.title3.weight(.semibold))
                Spacer()
                Button("Build or lease a site", systemImage: "plus") { building = true }
                    .buttonStyle(.borderedProminent)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 440), spacing: 14)], spacing: 14) {
                ForEach(s.sites) { site in SiteCard(site: site, state: s) }
            }
        }
        .sheet(isPresented: $building) { BuildSiteSheet() }
    }
}

/// How big one campus can get on each kind of power, at the best location for it.
private struct PowerOptionsCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("How big can one campus get?", symbol: "bolt.horizontal.fill",
                       subtitle: "Largest single site on each kind of power this year (best location)")
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
                    .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))
                    .opacity(open ? 1 : 0.6)
                }
            }
        }
    }
}

private struct SiteCard: View {
    @Environment(GameStore.self) private var store
    let site: Site
    let state: GameState
    @State private var expandKW = 1000.0
    @State private var confirmSell = false
    @State private var moving: OwnedBatch?

    var body: some View {
        let s = state
        let load = Economy.siteLoadKW(s, site.id)
        let ready = site.isReady(s.date)
        let batches = s.owned.filter { $0.siteID == site.id }
        VStack(alignment: .leading, spacing: 0) {
            Photo(key: ready ? (site.kind == .datacenter ? site.location.image : site.kind.image) : "dc_construction")
                .frame(height: 140).frame(maxWidth: .infinity).clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.name).font(.title3.weight(.bold))
                        Text("\(site.kind.rawValue) · \(site.kind == .garage || site.kind == .office ? "Home base" : site.location.name)").font(.caption)
                    }
                    .foregroundStyle(.white).padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if !ready {
                        PhotoPill(text: "Online \(site.ready.gameShort)", color: .orange, symbol: "hammer.fill").padding(10)
                    }
                }
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Power used").font(.caption)
                        Spacer()
                        Text("\(Fmt.watts(load * 1000)) / \(Fmt.watts(site.capacityKW * 1000))").font(.caption.monospacedDigit())
                    }
                    Meter(value: load / max(site.capacityKW, 0.001), tint: load / max(site.capacityKW, 0.001) > 0.9 ? .orange : .green)
                }
                if site.kind == .datacenter && (site.expanding > 0 || site.plannedKW > 0) {
                    PhaseRow(site: site, state: s)
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Label(site.cooling.rawValue, systemImage: "thermometer.snowflake").font(.caption)
                        Label("PUE \(Fmt.trim(site.pue, 2))", systemImage: "gauge.medium").font(.caption)
                    }
                    GridRow {
                        Label("\(Fmt.price(site.powerPrice))/kWh", systemImage: "bolt").font(.caption)
                        Label(site.monthlyFee > 0 ? "\(Fmt.money(site.monthlyFee))/mo lease" : (site.capex > 0 ? "\(Fmt.money(site.capex)) invested" : "No rent"), systemImage: "dollarsign.circle").font(.caption)
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
                    ExpandRow(site: site, state: s, expandKW: $expandKW)
                    HStack {
                        if site.plannedKW > 0 {
                            Button("Cancel later phases") { store.act("Later phases cancelled") { $0.cancelPlannedPhases(site.id) } }
                                .buttonStyle(.borderless).font(.caption)
                        }
                        Spacer()
                        Button(site.kind == .colo ? "End lease…" : "Sell site…", role: .destructive) { confirmSell = true }
                            .buttonStyle(.borderless).font(.caption)
                    }
                } else {
                    Text(site.kind == .garage ? "Consumer & workstation cards only (≤600 W each). For datacenter GPUs, lease a colocation cage." : "Up to 1,000 W per chip, air-cooled.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .background(.background.secondary, in: .rect(cornerRadius: Theme.corner))
        .clipShape(.rect(cornerRadius: Theme.corner))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
        .confirmationDialog(site.kind == .colo ? "End the lease on \(site.name)?" : "Sell \(site.name)?", isPresented: $confirmSell) {
            Button(site.kind == .colo ? "End lease (\(Fmt.money(site.monthlyFee)) fee)" : "Sell for \(Fmt.money(Campus.salePrice(site, s)))", role: .destructive) {
                store.act(site.kind == .colo ? "Lease ended" : "Site sold") { $0.sellSite(site.id) }
            }
        } message: {
            Text(batches.isEmpty ? "This can't be undone." : "Move or sell the chips housed here first.")
        }
        .popover(item: $moving) { b in MoveChipsPanel(batch: b, state: s) }
    }
}

/// Online, building and planned capacity of a phased campus.
private struct PhaseRow: View {
    let site: Site
    let state: GameState

    var body: some View {
        let total = Campus.plannedTotalKW(site)
        let online = site.isReady(state.date) ? site.capacityKW : 0
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Campus build-out").font(.caption)
                Spacer()
                Text("\(Fmt.watts(online * 1000)) of \(Fmt.watts(total * 1000)) online").font(.caption.monospacedDigit())
            }
            GeometryReader { geo in
                let w = geo.size.width
                let a = online / max(total, 1)
                let b = site.expanding / max(total, 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.orange.opacity(0.5)).frame(width: max(0, (a + b) * w))
                    Capsule().fill(Color.green.gradient).frame(width: max(0, a * w))
                }
            }
            .frame(height: 8)
            if site.expanding > 0 {
                Label("Building +\(Fmt.watts(site.expanding * 1000)), ready \(site.expansionReady?.gameShort ?? "")", systemImage: "hammer.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            if site.plannedKW > 0 {
                Label(site.phaseBlocked ? "Next phase waits for \(Fmt.money(min(site.plannedKW, max(site.phaseKW, 1_000)) / 1000 * Campus.capexPerMW(site.cooling, state)))"
                                        : "\(Fmt.watts(site.plannedKW * 1000)) planned in later phases",
                      systemImage: site.phaseBlocked ? "exclamationmark.triangle.fill" : "calendar")
                    .font(.caption).foregroundStyle(site.phaseBlocked ? .red : .secondary)
            }
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
        let capKW = site.kind == .colo ? Campus.coloCapMW * 1000 : Campus.siteCapMW(site.location, site.powerDeal, s) * 1000
        let headroom = max(0, capKW - Campus.plannedTotalKW(site))
        let options = Self.steps.filter { $0.1 <= headroom + 0.01 }
        VStack(alignment: .leading, spacing: 4) {
            if options.isEmpty {
                Text("At the limit for \(site.powerDeal.rawValue.lowercased()) here (\(Fmt.watts(capKW * 1000))). Switch power source or build another site.")
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
                Text("Room for \(Fmt.watts(headroom * 1000)) more on \(site.powerDeal.rawValue.lowercased())\(site.kind == .datacenter && Campus.phases(mw: expandKW / 1000) > 1 ? " · built in \(Campus.phases(mw: expandKW / 1000)) phases" : "")")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func cost(_ s: GameState) -> String {
        switch site.kind {
        case .colo: return "+\(Fmt.money(site.location.coloFee * expandKW * (site.cooling == .air ? 1 : 1.35)))/mo"
        case .datacenter: return Fmt.money(expandKW / 1000 * Campus.capexPerMW(site.cooling, s))
        default: return ""
        }
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

struct BuildSiteSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: SiteKind = .colo
    @State private var locationID = "texas"
    @State private var capacityMW = 1.0
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
                Text("Colocation cage (lease)").tag(SiteKind.colo)
                Text("Build your own datacenter").tag(SiteKind.datacenter)
            }
            .pickerStyle(.segmented)
            .onChange(of: kind) { _, k in
                capacityMW = k == .colo ? 1 : 50
                if k == .colo && (power == .gas || power == .smr || power == .fusion) { power = .grid }
            }

            Text("Location").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                ForEach(LocationCatalog.all) { l in
                    Button { locationID = l.id } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Photo(key: l.image).frame(height: 70).frame(maxWidth: .infinity).clipped()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.name).font(.callout.weight(.semibold)).lineLimit(1)
                                Text("\(Fmt.price(l.powerPrice))/kWh · PUE \(l.pueDelta >= 0 ? "+" : "")\(Fmt.trim(l.pueDelta, 2)) · grid ≤\(Fmt.watts(l.gridCap(s.year) * 1e6))")
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
                    CardHeader("Estimate", symbol: "doc.text.magnifyingglass")
                    if kind == .colo {
                        let fee = loc.coloFee * kw * (cooling == .air ? 1 : 1.35)
                        SpecRow(label: "Monthly lease", value: Fmt.money(fee))
                        SpecRow(label: "Ready in", value: "30 days")
                    } else {
                        let n = Campus.phases(mw: mw)
                        let phaseMW = mw / Double(n)
                        let first = s.buildMonths(mw: phaseMW, loc: loc, power: power)
                        let totalMonths = first + Double(n - 1) * first * 0.35
                        SpecRow(label: "Construction cost", value: Fmt.money(mw * Campus.capexPerMW(cooling, s)))
                        if n > 1 {
                            SpecRow(label: "Phases", value: "\(n) × \(Fmt.watts(phaseMW * 1e6))")
                            SpecRow(label: "First phase", value: "\(Fmt.money(phaseMW * Campus.capexPerMW(cooling, s))) · \(Fmt.trim(first, 1)) months")
                            SpecRow(label: "Fully built", value: "~\(Fmt.trim(totalMonths, 0)) months")
                        } else {
                            SpecRow(label: "Build time", value: "\(Fmt.trim(first, 1)) months")
                        }
                        SpecRow(label: "Maintenance", value: "\(Fmt.money(mw * Campus.capexPerMW(cooling, s) * 0.015))/yr")
                    }
                    let pue = kind == .colo ? cooling.basePUE + 0.07 + loc.pueDelta * 0.5 : cooling.basePUE + loc.pueDelta
                    let price = loc.powerPrice * power.priceMultiplier * (kind == .colo ? 1.1 : 1)
                    SpecRow(label: "PUE", value: Fmt.trim(pue, 2))
                    SpecRow(label: "Power price", value: "\(Fmt.price(price))/kWh")
                    SpecRow(label: "Full-load power bill", value: "\(Fmt.money(kw * pue * 24 * 30.4 * price))/mo")
                    Button {
                        let n = name.isEmpty ? "\(loc.name.split(separator: ",").first ?? "Site") \(kind == .colo ? "Colo" : "Campus")" : name
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
