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
        Page(title: "Compute Fleet", subtitle: "Every accelerator you own or rent, and what it's doing right now.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                StatTile(title: "Accelerators", value: Fmt.int(d.totalChips), detail: "\(Fmt.int(s.owned.reduce(0) { $0 + $1.count })) owned · \(Fmt.int(s.rentals.reduce(0) { $0 + $1.count })) rented", symbol: "cpu.fill", tint: .green)
                StatTile(title: "H100-equivalents", value: Fmt.count(d.h100e), detail: "BF16 dense", symbol: "equal.square.fill", tint: .blue)
                StatTile(title: "Peak low-precision", value: Fmt.tflops(peakPF * 1000), detail: "Best format per chip", symbol: "bolt.fill", tint: .orange)
                StatTile(title: "Rental bill", value: "\(Fmt.money(rentMonth))/mo", detail: s.cloudCredits > 0 ? "\(Fmt.money(s.cloudCredits)) credits left" : "Billed daily", symbol: "cloud.fill", tint: .teal)
                StatTile(title: "Owned IT load", value: Fmt.watts(powerKW * 1000), detail: "Before PUE overhead", symbol: "powerplug.fill", tint: .yellow)
            }

            if pools.isEmpty {
                Card {
                    EmptyStateView(symbol: "cpu", title: "No compute", message: "Buy hardware or rent cloud capacity in the Hardware Store.",
                                   actionTitle: "Hardware Store") { store.open(.hardware) }
                }
            } else {
                Card {
                    CardHeader("Allocation", symbol: "rectangle.split.3x1.fill", subtitle: "Training · Inference · Research · Self-improvement · Idle")
                    ForEach(pools) { p in PoolRow(pool: p).equatable() }
                    HStack(spacing: 14) {
                        LegendDot(color: .blue, label: "Training")
                        LegendDot(color: .green, label: "Inference")
                        LegendDot(color: .purple, label: "Research")
                        LegendDot(color: .pink, label: "Self-improvement")
                        LegendDot(color: .gray.opacity(0.4), label: "Idle")
                    }
                    .font(.caption)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                Card {
                    CardHeader("Cloud rentals", symbol: "cloud")
                    if s.rentals.isEmpty { Text("Nothing rented.").font(.callout).foregroundStyle(.secondary) }
                    ForEach(s.rentals) { r in
                        if let a = HardwareCatalog.get(r.accelID) {
                            HStack {
                                Photo(key: a.image).frame(width: 44, height: 30).clipShape(.rect(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(Fmt.int(r.count))× \(a.name)").font(.callout.weight(.semibold))
                                    Text("\(r.term.rawValue) · \(Fmt.price(r.hourly))/hr · \(Fmt.money(r.hourly * 24 * 30.4 * Double(r.count)))/mo\(r.end.map { " · ends \($0.gameShort)" } ?? "")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(r.end == nil ? "Release" : "Break lease") {
                                    store.act("Rental cancelled") { $0.cancelRental(r.id) }
                                }
                                .help(r.end == nil ? "Stop paying for these chips" : "Costs 50% of the remaining contract")
                            }
                        }
                    }
                }
                Card {
                    CardHeader("Owned hardware", symbol: "shippingbox")
                    if s.owned.isEmpty && s.orders.isEmpty { Text("You don't own any accelerators.").font(.callout).foregroundStyle(.secondary) }
                    ForEach(s.orders) { o in
                        if let a = HardwareCatalog.get(o.accelID) {
                            HStack {
                                Image(systemName: "shippingbox.and.arrow.backward").foregroundStyle(.orange).frame(width: 44)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(Fmt.int(o.count))× \(a.name)").font(.callout.weight(.semibold))
                                    Text("In transit · arrives \(o.arrives.gameShort)").font(.caption).foregroundStyle(.orange)
                                }
                                Spacer()
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
    }

    let pool: ComputePool

    var body: some View {
        let p = pool
        let total = max(1, Double(p.total))
        HStack(spacing: 12) {
            Photo(key: p.accel.image).frame(width: 54, height: 36).clipShape(.rect(cornerRadius: 7))
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

private struct OwnedRow: View {
    @Environment(GameStore.self) private var store
    let batch: OwnedBatch
    let state: GameState
    @State private var sellQty = 1
    @State private var confirming = false

    var body: some View {
        if let a = HardwareCatalog.get(batch.accelID) {
            let site = state.sites.first { $0.id == batch.siteID }
            let unit = Economy.resaleValue(a, state, unitCost: batch.unitCost, purchased: batch.purchased)
            HStack {
                Photo(key: a.image).frame(width: 44, height: 30).clipShape(.rect(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Fmt.int(batch.count))× \(a.name)").font(.callout.weight(.semibold))
                    Text("\(site?.name ?? "?") · bought \(batch.purchased.gameShort) at \(Fmt.money(batch.unitCost)) · resale \(Fmt.money(unit))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sell…") { confirming = true }
            }
            .popover(isPresented: $confirming) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sell \(a.name)").font(.headline)
                    QuantityPicker(value: $sellQty, range: 1...batch.count)
                    Text("You'd get \(Fmt.money(unit * Double(sellQty)))").font(.callout)
                    Button("Sell \(sellQty)") {
                        store.act("Sold") { $0.sellHardware(batchID: batch.id, count: sellQty) }
                        confirming = false
                    }
                    .buttonStyle(.borderedProminent)
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
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
        }
    }
}
