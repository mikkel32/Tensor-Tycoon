import SwiftUI

struct DatacentersView: View {
    @Environment(GameStore.self) private var store
    @State private var building = false

    var body: some View {
        let s = store.game
        let totalKW = s.sites.filter { $0.isReady(s.date) }.reduce(0) { $0 + $1.capacityKW }
        let usedKW = s.sites.reduce(0.0) { $0 + Economy.siteLoadKW(s, $1.id) }
        Page(title: "Datacenters & Power", subtitle: "Owned hardware needs a home: power, cooling and space. Liquid-cooled sites are required for GB200-class racks and TPUs.") {
            HStack(spacing: 12) {
                StatTile(title: "IT capacity", value: Fmt.watts(totalKW * 1000), detail: "\(Fmt.watts(usedKW * 1000)) committed", symbol: "bolt.fill", tint: .yellow)
                StatTile(title: "Sites", value: "\(s.sites.count)", detail: "\(s.sites.filter { !$0.isReady(s.date) }.count) under construction", symbol: "building.2.fill", tint: .indigo)
                StatTile(title: "Power bill (month)", value: Fmt.money(s.month.costPower), detail: "So far this month", symbol: "powerplug.fill", tint: .orange)
                StatTile(title: "Site & office costs", value: Fmt.money(s.month.costSites), detail: "So far this month", symbol: "building.columns.fill", tint: .gray)
            }
            HStack {
                Text("Your sites").font(.title3.weight(.semibold))
                Spacer()
                Button("Build or lease a site", systemImage: "plus") { building = true }
                    .buttonStyle(.borderedProminent)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 14)], spacing: 14) {
                ForEach(s.sites) { site in SiteCard(site: site, state: s) }
            }
        }
        .sheet(isPresented: $building) { BuildSiteSheet() }
    }
}

private struct SiteCard: View {
    @Environment(GameStore.self) private var store
    let site: Site
    let state: GameState
    @State private var expandKW = 1000.0

    var body: some View {
        let s = state
        let load = Economy.siteLoadKW(s, site.id)
        let ready = site.isReady(s.date)
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
                if site.kind == .colo || site.kind == .datacenter {
                    Picker("Power", selection: Binding(get: { site.powerDeal }, set: { d in store.act("Power deal: \(d.rawValue)") { $0.setPowerDeal(site.id, d) } })) {
                        ForEach(PowerDeal.allCases.filter { s.year >= $0.availableFrom }) { d in Text(d.rawValue).tag(d) }
                    }
                    if site.expanding > 0 {
                        Label("Expanding +\(Fmt.watts(site.expanding * 1000)), ready \(site.expansionReady?.gameShort ?? "")", systemImage: "hammer.fill").font(.caption).foregroundStyle(.orange)
                    } else {
                        HStack {
                            Text("Expand by").font(.caption)
                            Picker("", selection: $expandKW) {
                                Text("100 kW").tag(100.0)
                                Text("1 MW").tag(1000.0)
                                Text("10 MW").tag(10_000.0)
                                Text("100 MW").tag(100_000.0)
                                Text("500 MW").tag(500_000.0)
                            }
                            .labelsHidden()
                            .frame(width: 110)
                            Button("Expand") { store.act("Expansion started") { $0.expandSite(site.id, addKW: expandKW) } }
                            Spacer()
                            Text(expansionCost(site)).font(.caption).foregroundStyle(.secondary)
                        }
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
    }

    private func expansionCost(_ site: Site) -> String {
        switch site.kind {
        case .colo: return "+\(Fmt.money(site.location.coloFee * expandKW * (site.cooling == .air ? 1 : 1.35)))/mo"
        case .datacenter: return Fmt.money(expandKW / 1000 * site.cooling.capexPerMW * 1.15)
        default: return ""
        }
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
        let kw = capacityMW * 1000
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
            .onChange(of: kind) { _, k in capacityMW = k == .colo ? 1 : 50 }

            Text("Location").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                ForEach(LocationCatalog.all) { l in
                    Button { locationID = l.id } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Photo(key: l.image).frame(height: 70).frame(maxWidth: .infinity).clipped()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.name).font(.callout.weight(.semibold)).lineLimit(1)
                                Text("\(Fmt.price(l.powerPrice))/kWh · PUE \(l.pueDelta >= 0 ? "+" : "")\(Fmt.trim(l.pueDelta, 2)) · ≤\(Fmt.int(Int(l.gridCapMW))) MW")
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
                    HStack {
                        Text("Capacity")
                        Spacer()
                        Text(Fmt.watts(kw * 1000)).font(.body.monospacedDigit().weight(.semibold))
                    }
                    LogSlider(value: $capacityMW, range: kind == .colo ? 0.05...30 : 5...min(2000, loc.gridCapMW))
                    Text("≈ \(Fmt.int(Int(kw / Economy.chipKW(HardwareCatalog.h100)))) H100s or \(Fmt.int(Int(kw / Economy.chipKW(HardwareCatalog.get("gb200")!)))) GB200s")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Cooling", selection: $cooling) {
                        ForEach(Cooling.allCases) { c in Text(c.rawValue).tag(c).disabled(c == .immersion && !s.bonuses.has(.immersion)) }
                    }
                    Picker("Power", selection: $power) {
                        ForEach(PowerDeal.allCases.filter { s.year >= $0.availableFrom }) { p in Text(p.rawValue).tag(p) }
                    }
                    Text(power.blurb).font(.caption).foregroundStyle(.secondary)
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
                        let capex = capacityMW * cooling.capexPerMW * (s.year > 2024 ? 1.15 : 1)
                        let months = s.buildMonths(mw: capacityMW, loc: loc, power: power)
                        SpecRow(label: "Construction cost", value: Fmt.money(capex))
                        SpecRow(label: "Build time", value: "\(Fmt.trim(months, 1)) months")
                        SpecRow(label: "Maintenance", value: "\(Fmt.money(capex * 0.015))/yr")
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
                .frame(width: 330)
            }
        }
        .padding(22)
        .frame(width: 900)
    }
}
