import SwiftUI

/// 3.9: what each price would earn, worked out with the sim's own market formulas (MarketForecast), with one-click
/// "set this price", plus the two switches that decide how a chip shortage and the subscription prices behave.
struct PriceLabCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var chat: [MarketForecast.Point] = []
    @State private var agent: [MarketForecast.Point] = []
    @State private var api: [(name: String, id: UUID, current: Double, points: [MarketForecast.Point])] = []

    /// Recompute weekly, or when a price or product changes.
    private var key: String {
        let s = state
        return "\(Int(s.date.timeIntervalSince1970 / 86400 / 7))|\(s.chatPrice)|\(s.agentPrice)|\(s.freeTier)|\(s.chatModelID?.uuidString ?? "")|\(s.agentModelID?.uuidString ?? "")|\(s.models.map { $0.apiPrice }.reduce(0, +))|\(s.evenShortage)"
    }

    var body: some View {
        let s = state
        Card {
            CardHeader("Price lab", symbol: "dollarsign.arrow.circlepath", subtitle: "What each price would earn a month, on today's users, rivals and chips. Revenue peaks where buyers think the product is worth.")
            Toggle("Keep chat and agent prices near what users would pay (weekly, at most 8% a step)", isOn: Binding(get: { s.autoSubPrice }, set: { v in store.mutate { $0.autoSubPrice = v } }))
                .toggleStyle(.switch)
                .help("Targets 90% of the worth shown for each product. Raising a price this way still costs a little goodwill with the public, as a manual raise does.")
            Toggle("When chips run short, make everyone wait equally (off: paying customers are served first)", isOn: Binding(get: { s.evenShortage }, set: { v in store.mutate { $0.evenShortage = v } }))
                .toggleStyle(.switch)
                .help("Off: API traffic, agent seats, contracts and subscribers are served first and free-tier users wait. A token served to a free user earns nothing.")
            if s.freeTierStarved > 0.05 {
                Text("Free-tier users are being turned away for \(Fmt.pct(s.freeTierStarved, decimals: 0)) of their requests to keep paying customers served.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if s.chatModelID != nil { table("Chat subscription (per month)", chat, current: s.chatPrice, worth: Market.chatWTP(s), unit: "paying", money: { "$\(Int($0))" }) { p in
                store.mutate { $0.chatPrice = clamp(p, 5, 200) } } }
            if s.agentModelID != nil, !agent.isEmpty { table("Agent seat (per month)", agent, current: s.agentPrice, worth: Market.agentWTP(s) ?? 0, unit: "seats", money: { "$\(Int($0))" }) { p in
                store.mutate { $0.agentPrice = clamp(p, 20, 2000) } } }
            ForEach(api, id: \.id) { a in
                table("API: \(a.name) (per 1M tokens)", a.points, current: a.current, worth: Treasury.marketPrice(s.models.first { $0.id == a.id } ?? s.models[0], s), unit: "tokens/day", money: { Fmt.price($0) }) { p in
                    store.act { $0.setAPIPrice(a.id, p) } }
            }
            Text("Forecasts assume rivals hold still. API demand is elastic: a lower price wins share, but only chips you have can serve it.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task(id: key) { refresh() }
    }

    private func refresh() {
        let s = state
        let snap = Market.snapshot(s)
        if s.chatModelID != nil {
            let wtp = Market.chatWTP(s)
            let prices = MarketForecast.ladder(current: s.chatPrice, around: [wtp * 0.9, wtp], step: { clamp($0.rounded(), 5, 200) })
            chat = prices.map { MarketForecast.chat(s, price: $0, snap: snap) }
        }
        if s.agentModelID != nil {
            let wtp = Market.agentWTP(s) ?? 100
            let prices = MarketForecast.ladder(current: s.agentPrice, around: [wtp * 0.9, wtp], step: { clamp(($0 / 5).rounded() * 5, 20, 2000) })
            agent = prices.compactMap { MarketForecast.agents(s, price: $0) }
        }
        api = s.models.filter { $0.released && !$0.retired && $0.api }.map { m in
            let floor = Treasury.minPrice(m, s)
            let prices = MarketForecast.ladder(current: m.apiPrice, around: [Treasury.marketPrice(m, s) * 0.85], step: { max(floor, Treasury.tidy($0)) })
            return (m.name, m.id, m.apiPrice, prices.compactMap { MarketForecast.api(s, model: m.id, price: $0) })
        }
    }

    @ViewBuilder
    private func table(_ title: String, _ pts: [MarketForecast.Point], current: Double, worth: Double, unit: String,
                       money: @escaping (Double) -> String, set: @escaping (Double) -> Void) -> some View {
        let best = pts.max { $0.revenueMonth < $1.revenueMonth }
        let now = pts.min { abs($0.price - current) < abs($1.price - current) }
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            HStack {
                Text(title).font(.callout.weight(.semibold))
                Spacer()
                if worth > 0 { Text("\(unit == "tokens/day" ? "going rate" : "worth") ≈ \(money(worth))").font(.caption).foregroundStyle(.secondary) }
            }
            Grid(alignment: .trailing, horizontalSpacing: 18, verticalSpacing: 3) {
                GridRow {
                    Text("Price").gridColumnAlignment(.leading)
                    Text(unit == "tokens/day" ? "Share" : (unit == "seats" ? "Seat share" : "Pay"))
                    Text(unit == "tokens/day" ? "Tokens/day" : (unit == "seats" ? "Seats" : "Paying"))
                    Text("Revenue/mo")
                    Text("vs now")
                    Text("")
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(pts) { p in
                    let isNow = p.price == now?.price
                    GridRow {
                        Text(money(p.price) + (isNow ? " (now)" : "")).gridColumnAlignment(.leading)
                        Text(Fmt.pct(p.share))
                        Text(Fmt.count(p.units))
                        Text(Fmt.money(p.revenueMonth)).foregroundStyle(p.price == best?.price ? .green : .primary)
                        Text(isNow || (now?.revenueMonth ?? 0) <= 0 ? "" : (p.revenueMonth >= now!.revenueMonth ? "+" : "−") + Fmt.pct(abs(p.revenueMonth / now!.revenueMonth - 1), decimals: 0))
                            .foregroundStyle(p.revenueMonth >= (now?.revenueMonth ?? 0) ? .green : .red)
                        if isNow { Text("") } else { Button("Set") { set(p.price) }.controlSize(.small) }
                    }
                }
            }
            .font(.callout.monospacedDigit())
        }
    }
}
