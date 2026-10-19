import SwiftUI

struct PartnersView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let active = Partners.active(s)
        Page(title: "Compute Partners", subtitle: "Every frontier lab is married to a chip or cloud giant. Strategic deals trade equity and loyalty for money, discounts and early access to the next generation.", screen: .partners) {
            HeroBanner(image: "nvidia_hq", height: 150) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick your side").font(.title.weight(.bold))
                    Text("Exclusive deals pay far more — but you may only buy or rent that partner's hardware until the deal ends.")
                        .font(.callout).opacity(0.9)
                }
            }
            if !active.isEmpty {
                Text("Your partnerships").font(.title3.weight(.semibold))
                ForEach(active) { p in ActivePartnerCard(p: p, state: s) }
            }
            Text(active.isEmpty ? "Who wants to work with you" : "Other partners").font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 440), spacing: 14, alignment: .top)], spacing: 14) {
                ForEach(PartnerCatalog.all.filter { def in !active.contains { $0.partner == def.id } }) { def in
                    PartnerOfferCard(def: def, state: s)
                }
            }
            Text("Terms scale with your valuation. Investments come as cash or cloud credits in exchange for equity. Commitments are take-or-pay: spend less than promised and you pay half the shortfall.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }
}

private struct PartnerOfferCard: View {
    @Environment(GameStore.self) private var store
    let def: PartnerDef
    let state: GameState
    @State private var exclusive = true
    @State private var years = 4
    @State private var confirm = false

    var body: some View {
        let s = state
        let t = PartnerCatalog.terms(def, exclusive: exclusive, years: years, state: s)
        let blocker = PartnerCatalog.blocker(def, exclusive: exclusive, state: s)
        let color = Theme.competitorColor(def.color)
        Card(padding: 0) {
            ZStack(alignment: .bottomLeading) {
                Photo(key: def.image)
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                HStack(spacing: 10) {
                    Image(systemName: def.symbol).font(.title2.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(color.gradient, in: .rect(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(def.name).font(.title3.weight(.bold)).foregroundStyle(.white)
                        Text(def.kind).font(.caption).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(12)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(def.pitch).font(.callout)
                Text(def.precedent).font(.caption).foregroundStyle(.secondary)
                Picker("Deal", selection: $exclusive) {
                    Text("Exclusive").tag(true)
                    Text("Preferred").tag(false)
                }
                .pickerStyle(.segmented)
                Picker("Length", selection: $years) {
                    ForEach([2, 3, 4, 5], id: \.self) { Text("\($0) years").tag($0) }
                }
                .pickerStyle(.segmented)
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                    term("Investment", "\(Fmt.money(t.investment)) for \(Fmt.pct(t.equity, decimals: 1)) equity")
                    if t.credits > 0 { term("Paid as credits", Fmt.money(t.credits)) }
                    term("Discount", "\(Int(t.discount * 100))% off \(def.vendors.map(\.rawValue).sorted().joined(separator: "/")) hardware")
                    if t.earlyMonths > 0 { term("Early access", "New \(def.earlyVendors.map(\.rawValue).sorted().joined(separator: "/")) chips \(t.earlyMonths) months early") }
                    term("Allocation", "\(Fmt.trim(t.allocationMult, 1))× bigger orders, faster delivery")
                    term("Co-engineering", "+\(Int(t.mfuBonus * 100)) pts MFU on their chips")
                    term("You commit", "\(Fmt.money(t.annualCommit))/yr spend (take-or-pay)")
                    if exclusive { term("Exclusivity", "Only \(def.vendors.map(\.rawValue).sorted().joined(separator: " / ")) hardware for \(years) years") }
                    if def.rebate > 0 { term("Warrants", "\(Int(def.rebate * 100))% of purchases come back as stock gains") }
                }
                HStack {
                    if let blocker {
                        Label(blocker, systemImage: "lock.fill").font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                    Button(exclusive ? "Sign exclusive deal" : "Sign preferred deal") { confirm = true }
                        .buttonStyle(.borderedProminent)
                        .tint(color)
                        .disabled(blocker != nil)
                }
            }
            .padding(14)
        }
        .confirmationDialog("Sign \(exclusive ? "an exclusive" : "a preferred") \(years)-year deal with \(def.name)?", isPresented: $confirm) {
            Button("Sign") { store.act("Partnership signed") { $0.signPartnership(def.id, exclusive: exclusive, years: years) } }
        } message: {
            Text(exclusive ? "You won't be able to buy or rent other vendors' accelerators until the deal ends (hardware you already have keeps working)." : "No exclusivity — but a spending commitment.")
        }
    }

    private func term(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(v).font(.caption.weight(.semibold))
        }
    }
}

private struct ActivePartnerCard: View {
    @Environment(GameStore.self) private var store
    let p: Partnership
    let state: GameState
    @State private var confirm = false

    var body: some View {
        let def = p.def
        let color = Theme.competitorColor(def.color)
        let total = Double(max(1, GameCalendar.daysBetween(p.start, p.end)))
        let elapsed = Double(GameCalendar.daysBetween(p.start, state.date))
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: def.symbol).font(.title.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(color.gradient, in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(def.name).font(.title2.weight(.bold))
                        Pill(text: p.exclusive ? "Exclusive" : "Preferred", color: p.exclusive ? .orange : .blue, symbol: p.exclusive ? "lock.fill" : nil)
                    }
                    Text("Signed \(p.start.gameMonth) · ends \(p.end.gameMonth) · \(Fmt.money(p.invested)) invested for \(Fmt.pct(p.equity, decimals: 1))")
                        .font(.callout).foregroundStyle(.secondary)
                    Meter(value: elapsed / total, tint: color, height: 6)
                }
                Spacer()
                Button("Break deal…", role: .destructive) { confirm = true }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), alignment: .leading, spacing: 10) {
                stat("Discount", "\(Int(p.discount * 100))%")
                stat("Early access", p.earlyMonths > 0 ? "\(p.earlyMonths) months" : "—")
                stat("Allocation", "\(Fmt.trim(p.allocationMult, 1))×")
                stat("MFU bonus", "+\(Int(p.mfuBonus * 100)) pts")
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Commitment this year").font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(Fmt.money(p.spentThisYear)) of \(Fmt.money(p.annualCommit)) · settles \(p.nextSettlement.gameShort)").font(.caption.monospacedDigit())
                }
                Meter(value: p.spentThisYear / max(1, p.annualCommit), tint: p.spentThisYear >= p.annualCommit ? .green : .orange, height: 6)
            }
        }
        .confirmationDialog("Break the \(def.name) deal?", isPresented: $confirm) {
            Button("Break it", role: .destructive) { store.act("Partnership ended") { $0.terminatePartnership(p.id) } }
        } message: {
            Text("Penalty: 25% of the investment plus half of this year's unspent commitment. \(def.name) keeps its equity.")
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.headline.monospacedDigit())
            Text(k).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
