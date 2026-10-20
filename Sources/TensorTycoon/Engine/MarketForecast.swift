import Foundation

/// 3.9: price tools. What a price would earn, worked out with the same market formulas the sim runs
/// (`Market.snapshot`, WTP demand, fixed budgets), so the numbers on the Market page match what then happens.
enum MarketForecast {
    struct Point: Identifiable {
        var id: Double { price }
        var price: Double
        /// Paying users, seats, or tokens/day (by product).
        var units: Double
        /// Share of the segment (API and agents; chat: share of weekly users who pay).
        var share: Double
        var revenueMonth: Double
    }

    /// Chat app at `price`: weekly users stay (free tier) or fall to the payers (no free tier); the price sets
    /// how many of them pay (`paidConversion`) and the consumer budget caps what all subscribers spend.
    static func chat(_ s: GameState, price: Double, snap: MarketSnapshot) -> Point {
        let wtp = Market.chatWTP(s)
        // 3.9: users follow your bookings room (Commercial); at another price the room covers a different share of demand.
        var s2 = s
        s2.chatPrice = price
        let reachNow = Commercial.reachValue(s, snap), reach = Commercial.reachValue(s2, snap)
        var users = reachNow > 0 ? s.consumerUsers * reach / reachNow : s.consumerUsers
        let chat = snap.consumer.first(where: \.isPlayer)
        if reach > reachNow, let chat { users = min(users, max(s.consumerUsers, chat.share * snap.consumerUsersPool * reach)) }
        if !s.freeTier, let chat { users = min(users, chat.share * snap.consumerUsersPool * reach * 0.06 * Market.wtpDemand(price / wtp)) }
        let conv = Market.paidConversion(price: price, freeTier: s.freeTier, wtp: wtp)
        let rivalARPU = Market.paidConversion(price: 20, freeTier: true) * 20
        let others = (1 - (chat?.share ?? 0)) * snap.consumerUsersPool * rivalARPU / 30.4
        let paid = users * conv * Market.budgetFactor(users * conv * price / 30.4, pool: snap.consumerRevenuePool, others: others)
        let served = s.evenShortage ? s.consumerServedFraction : 1 - s.lostChatFrac
        return Point(price: price, units: paid, share: conv, revenueMonth: paid * price * (0.5 + 0.5 * served))
    }

    /// Agent seats at `price`: your share of seats moves with the price (via the snapshot), then the seat budget caps spend.
    static func agents(_ s: GameState, price: Double) -> Point? {
        var s2 = s
        s2.agentPrice = price
        let snap = Market.snapshot(s2)
        guard let ag = snap.agents.first(where: \.isPlayer) else { return nil }
        // 3.9: the sim scales seats by what bookings can take on (Commercial.reach); the forecast does too.
        let target = Market.agentSeatTarget(snap, ag: ag, price: price) * Commercial.reachValue(s2, snap)
        // Seats converge over weeks; show where they settle.
        return Point(price: price, units: target, share: ag.share, revenueMonth: target * price * (0.4 + 0.6 * (1 - s.lostAgentFrac)))
    }

    /// API for one model at `price`: its share of API tokens at that price, limited by the chips it has for API traffic.
    static func api(_ s: GameState, model id: UUID, price: Double) -> Point? {
        guard let i = s.models.firstIndex(where: { $0.id == id }), s.models[i].released else { return nil }
        let m = s.models[i]
        var s2 = s
        s2.models[i].apiPrice = price
        let snap = Market.snapshot(s2)
        guard let p = snap.api.first(where: { $0.modelID == id }) else { return nil }
        // 3.9: only what bookings can take on reaches you (Commercial.reach), as in the sim.
        let tokens = p.share * snap.apiTokenPool * Commercial.reachValue(s2, snap)
        // Chips left for API traffic: capacity minus what the model's other customers use (free-tier chat waits last).
        let base = Market.snapshot(s)
        let now = base.api.first(where: { $0.modelID == id }).map { $0.share * base.apiTokenPool * Commercial.reachValue(s, base) } ?? 0
        var others = max(0, m.demandTokensDay - now)
        if !s.evenShortage, s.chatModelID == id, s.consumerUsers > 0 {
            let freeFrac = 1 - min(1, s.paidUsers / s.consumerUsers)
            others -= min(others, s.consumerUsers * Macro.tokensPerUserDay(s.year) * (m.reasoning ? 2.2 : 1) * freeFrac)
        }
        let cap = m.capacityTokensDay > 0 ? m.capacityTokensDay : tokens
        let served = min(tokens, max(0, cap - others))
        return Point(price: price, units: served, share: p.share, revenueMonth: served / 1e6 * price * 30.4)
    }

    /// Prices worth trying around `current`: ×0.5 … ×2 plus the model's going rate or WTP when given.
    static func ladder(current: Double, around extra: [Double] = [], step: (Double) -> Double = { $0 }) -> [Double] {
        var out = Set<Double>()
        for k in [0.5, 0.7, 0.85, 1, 1.2, 1.5, 2] { out.insert(step(current * k)) }
        for e in extra where e > 0 { out.insert(step(e)) }
        return out.filter { $0 > 0 }.sorted()
    }

    /// Weekly: nudge chat and agent prices toward 90% of what buyers think they're worth (the revenue peak is at 100%;
    /// a little under is kinder to users). Steps of at most 8% so a price never jumps. Only when the player has turned it on.
    static func autoSubscriptionPrices(_ s: inout GameState) {
        guard s.autoSubPrice, Int(s.date.timeIntervalSince1970 / 86400) % 7 == 0 else { return }
        if s.chatModelID != nil {
            let target = max(5, (Market.chatWTP(s) * 0.9).rounded())
            let next = (s.chatPrice * clamp(target / max(s.chatPrice, 1), 0.92, 1.08)).rounded()
            if abs(next - s.chatPrice) >= 1 { s.chatPrice = clamp(next, 5, 200) }
        }
        if let w = Market.agentWTP(s) {
            let target = max(20, (w * 0.9 / 5).rounded() * 5)
            let next = (s.agentPrice * clamp(target / max(s.agentPrice, 1), 0.92, 1.08) / 5).rounded() * 5
            if abs(next - s.agentPrice) >= 5 { s.agentPrice = clamp(next, 20, 2000) }
        }
    }
}
