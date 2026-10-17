import SwiftUI

struct ChipSalesView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let d = store.derived
        let owned = d.pools.filter { $0.owned > 0 }
        let leased = s.leases.values.reduce(0, +)
        let chipRevenueDay = s.chipLines.reduce(0) { acc, l in acc + l.unitsToday * l.price }
        Page(title: "Chip & Cloud Sales", subtitle: "Sell compute two ways: lease idle accelerators to the market like a neocloud, or manufacture your own chips for hyperscalers, sovereign funds — and, if you dare, rival labs.") {
            HeroBanner(image: "hyperscale_campus", height: 150) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sell the shovels").font(.title.weight(.bold))
                    Text("The industry will spend \(Fmt.money(ChipBusiness.acceleratorSpend(s.year)))/yr on accelerators this year.")
                        .font(.callout).opacity(0.9)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                StatTile(title: "Cloud leasing", value: "\(Fmt.money(s.leaseRevenueToday * 365))/yr", detail: "\(Fmt.int(leased)) chips leased out", symbol: "cloud.fill", tint: .teal)
                StatTile(title: "Chip sales", value: "\(Fmt.money(chipRevenueDay * 365))/yr", detail: "This month \(Fmt.money(s.month.revChips))", symbol: "shippingbox.fill", tint: .green)
                StatTile(title: "Vendor reputation", value: "\(Int(ChipBusiness.reputation(s) * 100))/100", detail: "Grows with chips shipped", symbol: "star.fill", tint: .orange)
                StatTile(title: "Chips shipped", value: Fmt.count(ChipBusiness.shippedTotal(s)), detail: "Lifetime \(Fmt.money(s.chipLines.reduce(0) { $0 + $1.revenue }))", symbol: "shippingbox.and.arrow.backward.fill", tint: .indigo)
            }

            Card {
                CardHeader(title: "Lease idle compute", symbol: "cloud.fill",
                           subtitle: "Owned chips only. Occupancy falls as you flood the market; the platform takes \(Int(ChipBusiness.platformFee * 100))%.") { HelpButton(term: .leasing) }
                if owned.isEmpty {
                    NextStep("You don't own any accelerators. Buy some in the Hardware Store — rented ones can't be sublet.", action: "Hardware Store", screen: .hardware)
                } else {
                    ForEach(owned) { p in LeaseRow(pool: p, leased: s.leases[p.accel.id] ?? 0, state: s) }
                    Text("Today's occupancy \(Fmt.pct(ChipBusiness.occupancy(s, leasedH100e: ChipBusiness.leasedH100e(s)), decimals: 0)). Leased chips draw full power and can be recalled any time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Text("Merchant silicon").font(.title3.weight(.semibold))
            if s.customChips.isEmpty {
                Card {
                    EmptyStateView(symbol: "memorychip", title: "Nothing to sell yet",
                                   message: "Design a chip in Custom Silicon, or tape out an alien chip in Alien Tech. Only chips you designed can be sold.",
                                   actionTitle: "Custom Silicon") { store.open(.silicon) }
                }
            } else {
                ForEach(s.customChips.reversed()) { c in
                    if let line = s.chipLines.first(where: { $0.chipID == c.id }) {
                        ChipLineCard(line: line, chip: c, state: s)
                    } else {
                        Card {
                            HStack {
                                Image(systemName: c.alien ? "atom" : "memorychip").foregroundStyle(c.alien ? .purple : .indigo).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(.headline)
                                    Text("\(Fmt.money(c.unitCost)) to make · \(c.alien ? "alien architecture" : "\(c.focus.rawValue.lowercased()) chip, gen \(c.generation)")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(c.alien ? "Selling it ends exclusivity for this architecture." : "Only you can buy it today.").font(.caption).foregroundStyle(.secondary)
                                Button("Start selling") { store.act("Sales line opened") { $0.openChipLine(c.id) } }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct LeaseRow: View {
    @Environment(GameStore.self) private var store
    let pool: ComputePool
    let leased: Int
    let state: GameState
    @State private var count = 0

    var body: some View {
        let p = pool
        let s = state
        let rate = ChipBusiness.listRate(p.accel, s)
        let maxLease = min(p.owned, p.free + leased)
        HStack(spacing: 12) {
            Photo(key: p.accel.image).frame(width: 54, height: 36).clipShape(.rect(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(p.accel.name).font(.callout.weight(.semibold))
                Text("\(Fmt.int(p.owned)) owned · \(Fmt.int(p.free)) idle · \(Fmt.int(leased)) leased · market \(Fmt.price(rate))/chip-hour")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if leased > 0 {
                Text("\(Fmt.money(ChipBusiness.leaseIncomePerDay(p.accel, count: leased, s) * 30.4))/mo").font(.callout.monospacedDigit()).foregroundStyle(.green)
            }
            QuantityPicker(value: $count, range: 0...max(0, maxLease), presets: [0, 64, 512, 4096, 32768])
            Button(count == 0 && leased > 0 ? "Recall all" : "Set lease") {
                store.act(count == 0 ? "Leases recalled" : "Leasing \(Fmt.int(count)) chips") { $0.setLease(p.accel.id, chips: count) }
            }
        }
        .onAppear { count = leased > 0 ? leased : max(0, p.free) }
    }
}

private struct ChipLineCard: View {
    @Environment(GameStore.self) private var store
    let line: ChipLine
    let chip: CustomChip
    let state: GameState
    @State private var priceLog = 4.5
    @State private var capacityLog = 4.0
    @State private var loaded = false

    var body: some View {
        let s = state
        let l = line
        let accel = HardwareCatalog.get(l.chipID)
        let price = pow(10, priceLog)
        let capacity = (pow(10, capacityLog) / 1000).rounded() * 1000
        let value = accel.map { ChipBusiness.valueRatio(chip: $0, price: price, s) } ?? 0
        let demandAtPrice = accel.map { ChipBusiness.demand(chip: $0, price: price, sellToRivals: l.sellToRivals, s) } ?? 0
        let ref = Silicon.reference(s)
        let buyers = l.buyerUnits.sorted { $0.value > $1.value }.prefix(8)
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: chip.alien ? "atom" : "memorychip").font(.title2).foregroundStyle(chip.alien ? .purple : .indigo)
                        Text(chip.name).font(.title2.weight(.bold))
                        Pill(text: l.active ? "On sale" : "Paused", color: l.active ? .green : .orange)
                        if chip.alien { Pill(text: "Alien", color: .purple, symbol: "atom") }
                    }
                    Text("\(Fmt.money(chip.unitCost)) to make · selling at \(Fmt.money(l.price)) · \(Fmt.count(l.capacityMonth))/month capacity\(l.pendingCapacity > 0 ? " (+\(Fmt.count(l.pendingCapacity)) from \(l.pendingReady?.gameShort ?? ""))" : "")")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Sell to rival labs", isOn: Binding(get: { l.sellToRivals }, set: { v in store.act { $0.setChipLine(l.chipID, sellToRivals: v) } }))
                    .help("Rival labs are half the market. Every chip they buy makes their next models stronger.")
                Toggle("On sale", isOn: Binding(get: { l.active }, set: { v in store.act { $0.setChipLine(l.chipID, active: v) } }))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                LineStat(label: "Shipping", value: "\(Fmt.count(l.unitsToday * 30.4))/mo", tint: .blue)
                LineStat(label: "Demand", value: "\(Fmt.count(l.demandToday * 30.4))/mo", tint: l.demandToday > l.capacityMonth / 30.4 ? .orange : .secondary)
                LineStat(label: "Shipped", value: Fmt.count(l.shipped), tint: .indigo)
                LineStat(label: "Revenue", value: Fmt.money(l.revenue), tint: .green)
                LineStat(label: "Gross profit", value: Fmt.money(l.profit), tint: .green)
            }
            if l.demandToday > l.capacityMonth / 30.4 + 0.5 {
                Label("Buyers want \(Fmt.count(l.demandToday * 30.4)) a month — reserve more foundry capacity.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Price").font(.headline)
                    HStack {
                        Slider(value: $priceLog, in: log10(max(chip.unitCost * 1.05, 100))...log10(max(chip.unitCost * 2, ChipBusiness.listPrice(ref, s) * 12)))
                        Text(Fmt.money(price)).font(.callout.monospacedDigit().weight(.semibold)).frame(width: 90, alignment: .trailing)
                    }
                    Text("\(Fmt.trim(value, 2))× the performance per dollar of a \(ref.name) at \(Fmt.money(ChipBusiness.listPrice(ref, s))) · buyers would take \(Fmt.count(demandAtPrice * 30.4))/month · margin \(Fmt.pct(max(0, 1 - chip.unitCost / max(price, 1)), decimals: 0))")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Set price") { store.act("Price updated") { $0.setChipLine(l.chipID, price: price) } }
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Foundry capacity").font(.headline)
                    HStack {
                        Slider(value: $capacityLog, in: 3...6.3)
                        Text("+\(Fmt.count(capacity))/mo").font(.callout.monospacedDigit().weight(.semibold)).frame(width: 90, alignment: .trailing)
                    }
                    if let accel {
                        Text("Costs \(Fmt.money(ChipBusiness.capacityCost(accel, units: capacity, s))) up front (tooling, packaging slots, HBM prepayments). Ramps in \(chip.alien ? 3 : 4) months.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Reserve capacity") { store.act("Capacity reserved") { $0.addFabCapacity(l.chipID, units: capacity) } }
                        .disabled(l.pendingCapacity > 0)
                }
                .frame(maxWidth: .infinity)
            }
            if !buyers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Who's buying").font(.headline)
                    ForEach(Array(buyers), id: \.key) { kv in
                        HStack {
                            Image(systemName: BigPlayerCatalog.isRival(kv.key) ? "flag.2.crossed.fill" : "building.2.fill")
                                .foregroundStyle(BigPlayerCatalog.isRival(kv.key) ? .orange : .teal)
                                .frame(width: 20)
                            Text(BigPlayerCatalog.name(kv.key)).font(.callout)
                            Spacer()
                            Text("\(Fmt.count(kv.value)) chips").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            priceLog = log10(max(l.price, 1))
            capacityLog = l.capacityMonth > 0 ? log10(max(1_000, l.capacityMonth * 0.5)) : 4
        }
    }
}

private struct LineStat: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))
    }
}
