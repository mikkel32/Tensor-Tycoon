import Charts
import SwiftUI

struct ComputeView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let d = store.derived
        let pools = d.pools
        let peakPF = pools.reduce(0.0) { $0 + Double($1.total) * $1.accel.best } / 1000
        let rentMonth = s.rentals.reduce(0.0) { $0 + $1.hourly * 24 * 30.4 * Double($1.count) }
        let powerKW = s.owned.reduce(0.0) { acc, b in acc + (HardwareCatalog.get(b.accelID).map(Economy.chipKW) ?? 0) * Double(b.count) }
        let waiting = Economy.waitingChips(s)
        let waitingCount = waiting.reduce(0) { $0 + $1.count }
        Page(title: "Compute Fleet", subtitle: "Every accelerator you own or rent, and what it's doing right now.", screen: .compute) {
            ScreenHint(.compute)
            KPIRow(minWidth: 200) {
                StatTile(title: "Accelerators", value: Fmt.int(d.totalChips), detail: "\(Fmt.int(s.owned.reduce(0) { $0 + $1.count })) owned · \(Fmt.int(s.rentals.reduce(0) { $0 + $1.count })) rented"
                         + (waitingCount > 0 ? " · \(Fmt.int(waitingCount)) waiting for a site" : ""), symbol: "cpu.fill", tint: .green)
                StatTile(title: "H100-equivalents", value: Fmt.count(d.h100e), detail: "BF16 dense", symbol: "equal.square.fill", tint: .blue, help: .h100e)
                StatTile(title: "Peak low-precision", value: Fmt.tflops(peakPF * 1000), detail: "Best format per chip", symbol: "bolt.fill", tint: .orange)
                StatTile(title: "Rental bill", value: "\(Fmt.money(rentMonth))/mo", detail: s.cloudCredits > 0 ? "\(Fmt.money(s.cloudCredits)) credits left" : "Billed daily", symbol: "cloud.fill", tint: .teal)
                StatTile(title: "Owned IT load", value: Fmt.watts(powerKW * 1000), detail: "Before PUE overhead", symbol: "powerplug.fill", tint: .yellow)
            }

            if !waiting.isEmpty {
                // Chips at a site still being built count for nothing; say so plainly instead of leaving them
                // out of the pools without a word.
                Card {
                    CardHeader("Waiting for a site", symbol: "hourglass", subtitle: "Owned, but they can't train, serve or research until their site opens")
                    // Soonest site first (waitingChips is already in that order).
                    let siteIDs = waiting.map(\.site.id).reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }
                    ForEach(siteIDs, id: \.self) { siteID in
                        let rows = waiting.filter { $0.site.id == siteID }
                        if let site = rows.first?.site {
                            Label {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(site.name) opens \(site.ready.gameShort) (in \(Fmt.days(site.ready.timeIntervalSince(s.date) / 86_400)))")
                                        .font(.callout.weight(.semibold))
                                    Text(rows.map { "\(Fmt.int($0.count))× \(HardwareCatalog.get($0.accelID)?.name ?? $0.accelID)" }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "hourglass").foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            if pools.isEmpty {
                Card {
                    EmptyStateView(symbol: "cpu", title: "No compute", message: "Buy hardware or rent cloud capacity in the Hardware Store.",
                                   actionTitle: "Hardware Store") { store.open(.hardware) }
                }
            } else {
                Card {
                    CardHeader("Allocation", symbol: "rectangle.split.3x1.fill", subtitle: "Training · Inference · Research · Self-improvement · Agent swarms · Leased out · Idle")
                    ForEach(pools) { p in PoolRow(pool: p).equatable() }
                    LazyVGrid(columns: Theme.columns(min: 130, spacing: 10), alignment: .leading, spacing: 4) {
                        LegendDot(color: .blue, label: "Training")
                        LegendDot(color: .green, label: "Inference")
                        LegendDot(color: .purple, label: "Research")
                        LegendDot(color: .pink, label: "Self-improvement")
                        LegendDot(color: .indigo, label: "Agent swarms")
                        LegendDot(color: .orange, label: "Leased out")
                        LegendDot(color: .gray.opacity(0.4), label: "Idle")
                    }
                    .font(.caption)
                }
            }

            CardGrid(minWidth: 340, maxColumns: 2) {
                Card {
                    CardHeader("Cloud rentals", symbol: "cloud")
                    if s.rentals.isEmpty { NextStep("Nothing rented. Rent cloud chips by the hour, or reserve them for a year or three at a discount.", action: "Hardware Store", screen: .hardware) }
                    ForEach(s.rentals) { r in RentalRow(rental: r, state: s) }
                }
                Card {
                    CardHeader("Owned hardware", symbol: "shippingbox")
                    if s.owned.isEmpty && s.orders.isEmpty { NextStep("You don't own any accelerators. Bought chips need a site with power; renting is the quick start.", action: "Hardware Store", screen: .hardware) }
                    ForEach(s.orders) { o in
                        if let a = HardwareCatalog.get(o.accelID) {
                            HStack {
                                Image(systemName: "shippingbox.and.arrow.backward").foregroundStyle(.orange).frame(width: 44)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(Fmt.int(o.count))× \(a.name)").font(.callout.weight(.semibold))
                                    if o.made != nil {
                                        Text("From your fab line · \(Fmt.int(o.delivered ?? 0)) delivered so far, next chips \(AlienFab.nextShipment(o, s).gameShort), the rest by \(o.arrives.gameShort)")
                                            .font(.caption).foregroundStyle(.orange)
                                    } else {
                                        Text("In transit · arrives \(o.arrives.gameShort)").font(.caption).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                if o.made != nil {
                                    Button("Cancel rest…") { store.act("Order cut short") { $0.cancelOwnChipOrder(o.id) } }
                                        .help("Ship what's already made and refund \(Fmt.money(AlienFab.toMake(o) * o.unitCost)) for the chips not made yet.")
                                }
                            }
                        }
                    }
                    ForEach(s.owned) { bt in OwnedRow(batch: bt, state: s) }
                }
            }
        }
    }
}

private struct PoolRow: View, Equatable {
    static func == (a: PoolRow, b: PoolRow) -> Bool {
        a.pool.accel.id == b.pool.accel.id && a.pool.owned == b.pool.owned && a.pool.rented == b.pool.rented && a.pool.training == b.pool.training
            && a.pool.inference == b.pool.inference && a.pool.research == b.pool.research && a.pool.rsi == b.pool.rsi
            && a.pool.swarm == b.pool.swarm && a.pool.leased == b.pool.leased
    }

    let pool: ComputePool

    var body: some View {
        let p = pool
        let total = max(1, Double(p.total))
        HStack(spacing: 12) {
            Photo(key: p.accel.image).frame(width: 54, height: 36).clipShape(.rect(cornerRadius: 7)).acceleratorPhotoLabel(p.accel)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(p.accel.name).font(.callout.weight(.semibold))
                    Text("\(Fmt.int(p.total)) chips · \(Fmt.int(p.owned)) owned · \(Fmt.int(p.rented)) rented").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Fmt.int(p.free)) idle").font(.caption.monospacedDigit()).foregroundStyle(p.free > 0 ? .orange : .secondary)
                }
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        Rectangle().fill(.blue).frame(width: geo.size.width * Double(p.training) / total)
                        Rectangle().fill(.green).frame(width: geo.size.width * Double(p.inference) / total)
                        Rectangle().fill(.purple).frame(width: geo.size.width * Double(p.research) / total)
                        Rectangle().fill(.pink).frame(width: geo.size.width * Double(p.rsi) / total)
                        Rectangle().fill(.indigo).frame(width: geo.size.width * Double(p.swarm) / total)
                        Rectangle().fill(.orange).frame(width: geo.size.width * Double(p.leased) / total)
                        Rectangle().fill(.gray.opacity(0.25))
                    }
                    .clipShape(.capsule)
                }
                .frame(height: 10)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One cloud rental. 3.9: breaking a reservation shows its penalty and asks first (it used to charge in one click).
private struct RentalRow: View {
    @Environment(GameStore.self) private var store
    let rental: Rental
    let state: GameState
    @State private var confirmBreak = false

    var body: some View {
        let r = rental
        if let a = HardwareCatalog.get(r.accelID) {
            let penalty = Economy.breakPenalty(r, state)
            HStack {
                Photo(key: a.image).frame(width: 44, height: 30).clipShape(.rect(cornerRadius: 6)).acceleratorPhotoLabel(a)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Fmt.int(r.count))× \(a.name)").font(.callout.weight(.semibold))
                    Text("\(r.term.rawValue) · \(Fmt.price(r.hourly))/hr · \(Fmt.money(r.hourly * 24 * 30.4 * Double(r.count)))/mo\(r.end.map { " · ends \($0.gameShort)" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if r.end == nil {
                    Button("Release") { store.act("Rental cancelled") { $0.cancelRental(r.id) } }
                        .help("Stop paying for these chips")
                } else {
                    Button("Break lease…") { confirmBreak = true }
                        .help("Costs \(Fmt.money(penalty)): half the rent left on the contract")
                }
            }
            .confirmationDialog("Break the \(a.name) reservation?", isPresented: $confirmBreak, titleVisibility: .visible) {
                Button("Break it and pay \(Fmt.money(penalty))", role: .destructive) { store.act("Rental cancelled") { $0.cancelRental(r.id) } }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("\(Fmt.int(r.count)) chips reserved until \(r.end?.gameShort ?? "—"). Breaking it now costs half the rent left: \(Fmt.money(penalty)), paid at once\(penalty > state.cash ? " (you have \(Fmt.money(state.cash)))" : ""). Letting it run out costs nothing extra.")
            }
        }
    }
}

private struct OwnedRow: View {
    @Environment(GameStore.self) private var store
    let batch: OwnedBatch
    let state: GameState
    @State private var sellQty = 1
    @State private var confirming = false

    /// Chips of this batch that can be sold now: all of them at a site not open yet, otherwise the type's idle chips.
    private var sellable: Int {
        let waiting = !(state.sites.first { $0.id == batch.siteID }?.isReady(state.date) ?? true)
        return waiting ? batch.count : min(batch.count, Economy.pool(state, batch.accelID)?.free ?? 0)
    }

    var body: some View {
        if let a = HardwareCatalog.get(batch.accelID) {
            let site = state.sites.first { $0.id == batch.siteID }
            let unit = Economy.resaleValue(a, state, unitCost: batch.unitCost, purchased: batch.purchased)
            HStack {
                Photo(key: a.image).frame(width: 44, height: 30).clipShape(.rect(cornerRadius: 6)).acceleratorPhotoLabel(a)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Fmt.int(batch.count))× \(a.name)").font(.callout.weight(.semibold))
                    Text("\(site?.name ?? "?") · bought \(batch.purchased.gameShort) at \(Fmt.money(batch.unitCost)) · resale \(Fmt.money(unit))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let site, !site.isReady(state.date) {
                        Text("Not in use: waiting for \(site.name) to open \(site.ready.gameShort)")
                            .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Button("Sell…") { sellQty = min(max(1, sellQty), max(1, sellable)); confirming = true }
            }
            .popover(isPresented: $confirming) {
                // 3.9: only idle chips can be sold (sellHardware), so the picker stops there and says so.
                let n = min(sellQty, sellable)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sell \(a.name)").font(.headline)
                    Text(sellable >= batch.count ? "All \(Fmt.int(batch.count)) are idle and can be sold."
                         : "\(Fmt.int(sellable)) of these \(Fmt.int(batch.count)) are idle. Busy chips can't be sold: free them up on the Compute page first.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if sellable > 0 {
                        QuantityPicker(value: $sellQty, range: 1...max(1, sellable))
                        Text("You'd get \(Fmt.money(unit * Double(n)))").font(.callout)
                        Button("Sell \(Fmt.int(n))") {
                            store.act("Sold") { $0.sellHardware(batchID: batch.id, count: n) }
                            confirming = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(width: 320)
            }
        }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        LegendItem(color: color, label: label)
    }
}
