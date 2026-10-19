import Foundation

struct MarketProduct: Identifiable {
    var id: String
    var lab: String
    var labName: String
    var name: String
    var c: Double
    var price: Double
    var tps: Double
    var brand: Double
    var open: Bool
    var reasoning: Bool
    var isPlayer: Bool
    var modelID: UUID?
    var attraction: Double = 0
    var share: Double = 0
}

struct MarketSnapshot {
    var api: [MarketProduct] = []
    var consumer: [MarketProduct] = []
    var agents: [MarketProduct] = []
    var agentSeatsPool: Double = 0
    var apiTokenPool: Double = 0
    var apiRevenuePool: Double = 0
    var consumerUsersPool: Double = 0
    var enterprisePool: Double = 0
    var marketSize: Double = 0
    /// What consumers spend on AI subscriptions per day (all apps).
    var consumerRevenuePool: Double = 0
    /// What a seat is budgeted at per month, and what all agent seats are budgeted at per day.
    var agentSeatBudget: Double = 100
    var agentRevenuePool: Double = 0
    /// How much of the API token demand today's prices can afford (below 1 when they'd overspend the API budget).
    var apiBudgetScale: Double = 1
}

enum Market {
    /// Below this fraction of the market price, cutting your price wins no more customers (nobody believes you
    /// can sustain it, and next to quality it hardly matters), so a give-away price can't buy the market.
    /// Rival labs' list prices are calibrated (the open-weights labs sell at ~0.12–0.15×) and never chase share.
    static let priceFloorFactor = 0.3

    static func attraction(c: Double, price: Double, refPrice: Double, tps: Double, brand: Double,
                           frontier: Double, elasticity: Double, floor: Double = 0) -> Double {
        let quality = exp(1.5 * (c - frontier))
        let ref = max(refPrice, 0.0001)
        let priceFactor = pow(max(price, ref * floor, 0.0001) / ref, -elasticity)
        let speed = pow(max(tps, 1) / 60, 0.15)
        let brandF = pow(max(brand, 3) / 50, 0.7)
        return quality * priceFactor * speed * brandF
    }

    /// Builds the product landscape and market shares for today.
    static func snapshot(_ s: GameState) -> MarketSnapshot {
        let y = s.year
        let b = s.bonuses
        let frontier = Macro.frontier(y)
        let chatOn = s.chatMoment != nil
        var snap = MarketSnapshot()
        let size = Macro.marketSize(y) * s.market.hype * s.difficulty.demandMultiplier
        let split = Macro.segmentSplit(y, chatMoment: chatOn)
        snap.marketSize = size
        snap.apiRevenuePool = size * split.api / 365
        let avgPrice = Macro.frontierPrice(y) * 0.35 * s.market.apiPricePressure
        snap.apiTokenPool = snap.apiRevenuePool / avgPrice * 1e6
        snap.consumerUsersPool = chatOn ? Macro.chatUsers(y, chatMoment: s.chatMoment) * sqrt(s.market.hype) * s.difficulty.demandMultiplier : 0
        snap.enterprisePool = size * split.enterprise
        snap.consumerRevenuePool = size * split.consumer / 365
        snap.agentSeatsPool = Macro.agentSeats(y) * sqrt(s.market.hype) * s.difficulty.demandMultiplier
        snap.agentSeatBudget = 100 * max(1, agentPriceLevel(y))
        snap.agentRevenuePool = snap.agentSeatsPool * snap.agentSeatBudget / 30.4
        let agentFrontier = frontier + 0.87

        for comp in s.competitors where !comp.acquired {
            guard let m = comp.latest else { continue }
            let def = comp.def
            let price = m.price * (1 - comp.priceCut)
            snap.api.append(MarketProduct(id: "\(comp.id)-flag", lab: comp.id, labName: def.name, name: m.name, c: m.c, price: price,
                                          tps: m.tps, brand: comp.brand, open: m.open, reasoning: m.reasoning, isPlayer: false))
            if comp.models.count >= 2 && y >= 2023 {
                snap.api.append(MarketProduct(id: "\(comp.id)-mini", lab: comp.id, labName: def.name, name: "\(m.name) Mini", c: m.c - 0.55,
                                              price: price * 0.12, tps: m.tps * 1.8, brand: comp.brand, open: m.open,
                                              reasoning: false, isPlayer: false))
            }
            if y >= 2025.0 && m.reasoning && !m.open {
                let x = Leaderboard.profile(m, def: def).agenticX
                snap.agents.append(MarketProduct(id: "\(comp.id)-agent", lab: comp.id, labName: def.name, name: "\(def.chatProduct) Agent", c: x,
                                                 price: def.id == "halcyon" ? 120 : 100, tps: m.tps, brand: comp.brand * (1 + def.codeBonus * 2) * RivalStrategy.agentBoost(comp),
                                                 open: false, reasoning: true, isPlayer: false))
            }
            // Open-weights side releases stay on the market for two years.
            if let o = comp.openModels.last, GameCalendar.daysBetween(o.date, s.date) < 730 {
                snap.api.append(MarketProduct(id: "\(comp.id)-open", lab: comp.id, labName: def.name, name: o.name, c: o.c, price: o.price,
                                              tps: o.tps, brand: comp.brand, open: true, reasoning: o.reasoning, isPlayer: false))
            }
            let launched = comp.id == "prometheus" ? chatOn : (chatOn && y >= def.firstModel.decimal + 0.2 && y >= 2023.0)
            if launched {
                snap.consumer.append(MarketProduct(id: "\(comp.id)-chat", lab: comp.id, labName: def.name, name: def.chatProduct, c: m.c,
                                                   price: 20, tps: m.tps, brand: comp.brand * (comp.id == "prometheus" ? 1.4 : 1),
                                                   open: false, reasoning: m.reasoning, isPlayer: false))
            }
        }

        for m in s.models where m.released && !m.retired && m.api && (m.capacityTokensDay > 0 || Families.servesToday(s, m)) {
            snap.api.append(MarketProduct(id: m.id.uuidString, lab: "player", labName: s.companyName, name: m.name,
                                          c: m.c - Physics.servingPenalty(m.servingPrecision), price: m.apiPrice,
                                          tps: max(m.tps, 1), brand: s.brand * (0.7 + 0.3 * s.reliability) * (m.design.mode == .finetune ? 0.8 : 1) * Families.brandMult(s, m.id), open: m.openWeights,
                                          reasoning: m.reasoning, isPlayer: true, modelID: m.id))
        }
        if chatOn || (s.year < 2022.91 && s.chatModelID != nil),
           let id = s.chatModelID, let m = s.models.first(where: { $0.id == id && $0.released && !$0.retired }) {
            snap.consumer.append(MarketProduct(id: "player-chat", lab: "player", labName: s.companyName, name: "\(s.companyName) Chat",
                                               c: Families.chatQuality(s, m), price: s.chatPrice, tps: max(m.tps, 1),
                                               brand: s.brand * (0.6 + 0.4 * s.reliability) * (1 + b.consumerDemand),
                                               open: false, reasoning: m.reasoning, isPlayer: true, modelID: m.id))
        }

        if let id = s.agentModelID, let m = s.models.first(where: { $0.id == id && $0.released && !$0.retired }), b.has(.toolUse) {
            snap.agents.append(MarketProduct(id: "player-agent", lab: "player", labName: s.companyName, name: "\(s.companyName) Agent",
                                             c: Leaderboard.profile(m).agenticX, price: max(1, s.agentPrice), tps: max(m.tps, 1),
                                             brand: s.brand * (0.6 + 0.4 * s.reliability) * (1 + b.enterpriseDemand * 0.5),
                                             open: false, reasoning: m.reasoning, isPlayer: true, modelID: m.id))
        }

        // API shares
        var totalA = 0.0
        for i in snap.api.indices {
            var p = snap.api[i]
            let ref = Macro.referencePrice(c: p.c, y: y) * s.market.apiPricePressure
            p.attraction = attraction(c: p.c, price: p.price, refPrice: ref, tps: p.tps, brand: p.brand, frontier: frontier, elasticity: 1.4,
                                      floor: p.isPlayer ? priceFloorFactor : 0)
            if p.isPlayer { p.attraction *= (1 + b.apiDemand) * s.reliability * max(0.3, 1 + s.traits.api) * Stakeholders.demandFactor(s, .api) * Launches.demandFactor(s, p.modelID) }   // 3.7: launch curve
            if p.open { p.attraction *= 1.15 }
            snap.api[i] = p
            totalA += p.attraction
        }
        let otherA = max(totalA * 0.18, 1e-9)
        for i in snap.api.indices { snap.api[i].share = snap.api[i].attraction / (totalA + otherA) }
        // API buyers have a fixed budget (the API pool). If today's prices and shares would bill more than that,
        // they buy fewer tokens from everyone, so the API market never earns more than its pool.
        let shareTotal = snap.api.reduce(0) { $0 + $1.share }
        let billed = snap.api.reduce(0) { $0 + $1.share * $1.price } + max(0, 1 - shareTotal) * avgPrice
        if billed > avgPrice {
            snap.apiBudgetScale = avgPrice / billed
            snap.apiTokenPool *= snap.apiBudgetScale
        }

        var totalC = 0.0
        for i in snap.consumer.indices {
            var p = snap.consumer[i]
            // People pick a chat app for its quality and name; the subscription price decides how many of them
            // pay (paidConversion), not how many use it.
            p.attraction = attraction(c: p.c, price: p.price, refPrice: 20, tps: p.tps, brand: p.brand, frontier: frontier, elasticity: 0)
            if p.isPlayer && !s.freeTier { p.attraction *= 0.3 }
            if p.isPlayer { p.attraction *= max(0.3, 1 + s.traits.consumer) * Stakeholders.demandFactor(s, .consumer) * Launches.demandFactor(s, p.modelID, consumer: true) }   // 3.7
            snap.consumer[i] = p
            totalC += p.attraction
        }
        let otherC = max(totalC * 0.12, 1e-9)
        for i in snap.consumer.indices { snap.consumer[i].share = snap.consumer[i].attraction / (totalC + otherC) }

        var totalG = 0.0
        let frontierSeat = 100 * agentPriceLevel(y)
        for i in snap.agents.indices {
            var p = snap.agents[i]
            let quality = exp(1.8 * (p.c - agentFrontier))
            // Buyers weigh a seat's price against what the agent is worth: yours by its own agentic skill
            // (agentWTP), rivals' fixed list prices against a frontier agent's worth (their skill is in `quality`).
            let worth = p.isPlayer ? agentWTP(x: p.c, y: y) : frontierSeat
            p.attraction = quality * wtpDemand(p.price / worth) * pow(max(p.tps, 1) / 60, 0.2) * pow(max(p.brand, 3) / 50, 0.6)
            if p.isPlayer { p.attraction *= s.reliability * max(0.3, 1 + s.traits.agentSeats) * Stakeholders.demandFactor(s, .agents) }
            snap.agents[i] = p
            totalG += p.attraction
        }
        let otherG = max(totalG * 0.1, 1e-9)
        for i in snap.agents.indices { snap.agents[i].share = snap.agents[i].attraction / (totalG + otherG) }
        return snap
    }

    /// Fixed budgets: the factor that keeps your spending share of a market within its pool. `natural` is what you'd
    /// bill at today's prices, `others` what everyone else bills (per day). 1 while the market has room; otherwise you
    /// get your share of the pool, `pool × natural ÷ (natural + others)`, and never more than the pool.
    static func budgetFactor(_ natural: Double, pool: Double, others: Double) -> Double {
        guard natural > 0, natural + others > pool else { return 1 }
        return max(0, pool) / (natural + others)
    }

    // MARK: Willingness to pay

    /// How fast demand falls once a price passes what buyers think the product is worth.
    static let wtpElasticity = 1.6

    /// Demand at `x` = price ÷ willingness to pay, relative to pricing exactly at it: 1 at the WTP, at most
    /// 1 + 1/(e−1) for a give-away, falling like x^−e above it. Revenue (price × demand) peaks at the WTP.
    static func wtpDemand(_ x: Double) -> Double {
        let e = wtpElasticity
        let a = 1 / (e - 1)
        return (1 + a) / (1 + a * pow(max(0, x), e))
    }

    /// What a typical user would pay a month for your chat app: $20 for a frontier model, less the further
    /// behind it is (more if it's ahead), $5–60.
    static func chatWTP(_ s: GameState) -> Double {
        let m = s.chatModelID.flatMap { id in s.models.first { $0.id == id && $0.released && !$0.retired } }
            ?? s.releasedModels.max { $0.c < $1.c }
        guard let m else { return 20 }
        return clamp(20 * exp(0.5 * (m.c - Macro.frontier(s.year))), 5, 60)
    }

    /// Seat prices follow what agent labor earns (Swarms.wage): 1 in 2026, when a frontier agent seat lists at $100.
    static func agentPriceLevel(_ y: Double) -> Double { Swarms.wage(y) / Swarms.wage(2026) }

    /// What a month of an agent seat with agentic capability `x` is worth to a buyer: the wage of the work it
    /// does (Swarms.wage × its researcher-equivalents, Swarms.quality). A frontier agent seat is worth what the
    /// market charges ($100 × the wage level). A seat is one person's agent, so a stronger or weaker agent is worth
    /// more or less with the square root of the work it does, not in proportion (0.25–4×).
    static func agentWTP(x: Double, y: Double) -> Double {
        let frontierX = Macro.frontier(y) + 0.87
        let workRatio = exp(1.1 * (x - frontierX))   // Swarms.quality(x) ÷ Swarms.quality(frontier agent)
        return 100 * agentPriceLevel(y) * clamp(workRatio.squareRoot(), 0.25, 4)
    }

    /// Your agent's worth per seat today (nil if it isn't on sale).
    static func agentWTP(_ s: GameState) -> Double? {
        guard let id = s.agentModelID, let m = s.models.first(where: { $0.id == id && $0.released && !$0.retired }) else { return nil }
        return agentWTP(x: Leaderboard.profile(m).agenticX, y: s.year)
    }

    /// Share of weekly users who pay at `price` when they'd pay up to `wtp` (5% at the WTP). Without a free
    /// tier everyone who stays pays. No floor: at a silly price almost nobody pays.
    static func paidConversion(price: Double, freeTier: Bool, wtp: Double = 20) -> Double {
        guard freeTier else { return 1.0 }
        return min(0.3, 0.05 * wtpDemand(price / max(wtp, 1)))
    }
}
