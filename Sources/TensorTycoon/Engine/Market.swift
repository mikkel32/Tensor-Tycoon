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
    /// 3.8: the model's domain scores as buyers see them (nil before it has been scored: then only `c` counts).
    var scores: DomainScores? = nil
    /// 3.8: share of each API segment (APISegment order); `share` is their weighted sum.
    var segShares: [Double] = []
    /// 3.8: the family it's sold under (yours only), for routing between members.
    var familyID: UUID? = nil
}

/// 3.8: API buyers come for different work, and each kind picks models on the domains that work needs. A coding
/// specialist wins the coding segment from a stronger generalist; a model that can't see gets almost none of the
/// vision and voice segment. General chat and knowledge work still goes by overall capability (the leaderboard's `c`).
enum APISegment: Int, CaseIterable, Identifiable, Sendable {
    case coding, general, agents, languages, media

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .coding: "Coding"
        case .general: "General & chat"
        case .agents: "Agents & tools"
        case .languages: "Multilingual"
        case .media: "Vision & voice"
        }
    }

    var symbol: String {
        switch self {
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .general: "text.bubble.fill"
        case .agents: "figure.walk.motion"
        case .languages: "globe"
        case .media: "eye.fill"
        }
    }

    /// The domains buyers in this segment judge a model on (general uses `c`).
    var mix: [(CapDomain, Double)] {
        switch self {
        case .coding: [(.coding, 0.7), (.reasoning, 0.15), (.agents, 0.15)]
        case .general: [(.knowledge, 0.4), (.reasoning, 0.3), (.social, 0.3)]
        case .agents: [(.agents, 0.6), (.reliability, 0.25), (.coding, 0.15)]
        case .languages: [(.multilingual, 0.7), (.knowledge, 0.3)]
        case .media: [(.vision, 0.6), (.voice, 0.4)]
        }
    }

    /// Share of API spending in this segment. Coding grows to about a third by 2025, agent traffic from 2023, and the
    /// multilingual share follows where the world's AI money is (Capabilities.multilingualShare).
    static func weights(_ s: GameState) -> [Double] {
        let y = s.year
        var w = [Double](repeating: 0, count: allCases.count)
        w[APISegment.coding.rawValue] = interpolate([(2017, 0.1), (2021, 0.18), (2023, 0.27), (2025, 0.34), (2030, 0.35)], at: y)
        w[APISegment.agents.rawValue] = interpolate([(2022, 0.01), (2024, 0.05), (2026, 0.13), (2030, 0.2)], at: y)
        w[APISegment.languages.rawValue] = Capabilities.multilingualShare(s)
        w[APISegment.media.rawValue] = interpolate([(2017, 0.03), (2023, 0.07), (2026, 0.11), (2030, 0.13)], at: y)
        w[APISegment.general.rawValue] = max(0.15, 1 - w.reduce(0, +))
        let total = w.reduce(0, +)
        return w.map { $0 / total }
    }

    /// How strongly a domain lead pulls buyers: exp(0.15 × points), the same as a capability lead (1.5 per decade of
    /// effective compute): a 10-point specialist edge is 4.5× the attraction.
    static let premium = 0.15
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
        let size = Macro.marketSize(y) * s.market.hype * s.difficulty.demandMultiplier * Nations.demandFactor(s)   // 3.4 overhaul: regional recessions
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
        let ref = Capabilities.reference(y)
        let fieldAgents = Capabilities.field(.agents, at: y)

        for comp in s.competitors where !comp.acquired {
            guard let m = comp.latest else { continue }
            let def = comp.def
            // 3.8: specialisations that change what a lab sells: smaller, cheaper models; its own (cheaper) chips.
            let lean = specialistRamp(s, comp.id, .efficient, years: 1)
            let silicon = specialistRamp(s, comp.id, .hardware, years: 2)
            let price = m.price * (1 - comp.priceCut) * (1 - 0.35 * lean) * (1 - 0.12 * silicon)
            let dc = -0.1 * lean
            let scores = s.domainScores[m.id.uuidString]
            snap.api.append(MarketProduct(id: "\(comp.id)-flag", lab: comp.id, labName: def.name, name: m.name, c: m.c + dc, price: price,
                                          tps: m.tps * (1 + 0.3 * lean), brand: comp.brand, open: m.open, reasoning: m.reasoning, isPlayer: false,
                                          scores: shifted(scores, dc)))
            if (comp.models.count >= 2 && y >= 2023) || (lean > 0 && y >= 2021) {
                let miniGap = 0.55 - 0.1 * lean
                snap.api.append(MarketProduct(id: "\(comp.id)-mini", lab: comp.id, labName: def.name, name: "\(m.name) Mini", c: m.c - miniGap,
                                              price: price * (0.12 - 0.04 * lean), tps: m.tps * 1.8, brand: comp.brand, open: m.open,
                                              reasoning: false, isPlayer: false, scores: shifted(scores, -miniGap)))
            }
            if y >= 2025.0 && m.reasoning && !m.open {
                let x = seatX(Leaderboard.profile(m, def: def).agenticX, scores: scores, ref: ref, fieldAgents: fieldAgents)
                snap.agents.append(MarketProduct(id: "\(comp.id)-agent", lab: comp.id, labName: def.name, name: "\(def.chatProduct) Agent", c: x,
                                                 price: def.id == "halcyon" ? 120 : 100, tps: m.tps, brand: comp.brand * (1 + def.codeBonus * 2) * RivalStrategy.agentBoost(comp),
                                                 open: false, reasoning: true, isPlayer: false))
            }
            // Open-weights side releases stay on the market for two years.
            if let o = comp.openModels.last, GameCalendar.daysBetween(o.date, s.date) < 730 {
                snap.api.append(MarketProduct(id: "\(comp.id)-open", lab: comp.id, labName: def.name, name: o.name, c: o.c, price: o.price,
                                              tps: o.tps, brand: comp.brand, open: true, reasoning: o.reasoning, isPlayer: false,
                                              scores: s.domainScores[o.id.uuidString]))
            }
            let launched = comp.id == "prometheus" ? chatOn : (chatOn && y >= def.firstModel.decimal + 0.2 && y >= 2023.0)
            if launched {
                snap.consumer.append(MarketProduct(id: "\(comp.id)-chat", lab: comp.id, labName: def.name, name: def.chatProduct, c: m.c,
                                                   price: 20, tps: m.tps, brand: comp.brand * (comp.id == "prometheus" ? 1.4 : 1),
                                                   open: false, reasoning: m.reasoning, isPlayer: false))
            }
        }

        for m in s.models where m.released && !m.retired && m.api && (m.capacityTokensDay > 0 || Families.servesToday(s, m)) {
            let penalty = Physics.servingPenalty(m)   // 3.4: QAT-trained models lose less
            snap.api.append(MarketProduct(id: m.id.uuidString, lab: "player", labName: s.companyName, name: m.name,
                                          c: m.c - penalty, price: m.apiPrice,
                                          tps: max(m.tps, 1), brand: s.brand * (0.7 + 0.3 * s.reliability) * (m.design.mode == .finetune ? 0.8 : 1) * Families.brandMult(s, m.id) * Arena.pull(s, m.id), open: m.openWeights,
                                          reasoning: m.reasoning, isPlayer: true, modelID: m.id,
                                          scores: shifted(s.domainScores[m.id.uuidString], -penalty), familyID: Families.family(of: m.id, s)?.id))
        }
        if chatOn || (s.year < 2022.91 && s.chatModelID != nil),
           let id = s.chatModelID, let m = s.models.first(where: { $0.id == id && $0.released && !$0.retired }) {
            snap.consumer.append(MarketProduct(id: "player-chat", lab: "player", labName: s.companyName, name: "\(s.companyName) Chat",
                                               c: Families.chatQuality(s, m), price: s.chatPrice, tps: max(m.tps, 1),
                                               brand: s.brand * (0.6 + 0.4 * s.reliability) * (1 + b.consumerDemand) * Arena.pull(s, m.id),   // 3.9: arena rank
                                               open: false, reasoning: m.reasoning, isPlayer: true, modelID: m.id))
        }

        if let id = s.agentModelID, let m = s.models.first(where: { $0.id == id && $0.released && !$0.retired }), b.has(.toolUse) {
            // 3.8: agent seats go by the agents domain (agentic skill plus agents know-how) and reliability.
            let x = seatX(Leaderboard.profile(m).agenticX, scores: s.domainScores[m.id.uuidString], ref: ref, fieldAgents: fieldAgents)
            snap.agents.append(MarketProduct(id: "player-agent", lab: "player", labName: s.companyName, name: "\(s.companyName) Agent",
                                             c: x, price: max(1, s.agentPrice), tps: max(m.tps, 1),
                                             brand: s.brand * (0.6 + 0.4 * s.reliability) * (1 + b.enterpriseDemand * 0.5),
                                             open: false, reasoning: m.reasoning, isPlayer: true, modelID: m.id))
        }

        // API shares, segment by segment (3.8). Each product's pull is its price, speed and brand (as before) times its
        // quality for the segment's work; the shares are summed by segment weight.
        let weights = APISegment.weights(s)
        let segs = APISegment.allCases
        var seg = [[Double]](repeating: [Double](repeating: 0, count: segs.count), count: snap.api.count)
        let eco = Launches.ecosystemFactor(s)
        for i in snap.api.indices {
            let p = snap.api[i]
            let refPrice = Macro.referencePrice(c: p.c, y: y) * s.market.apiPricePressure
            var pull = attraction(c: frontier, price: p.price, refPrice: refPrice, tps: p.tps, brand: p.brand, frontier: frontier, elasticity: 1.4,
                                  floor: p.isPlayer ? priceFloorFactor : 0)
            if p.isPlayer { pull *= (1 + b.apiDemand) * s.reliability * max(0.3, 1 + s.traits.api) * Stakeholders.demandFactor(s, .api) * Launches.demandFactor(s, p.modelID) * eco }   // 3.7: launch curve; 3.8: developer ecosystem
            if p.open { pull *= 1.15 }
            for k in segs.indices { seg[i][k] = pull * segmentQuality(p, segs[k], frontier: frontier, ref: ref) }
        }
        // 3.8: Model Routing research — a family sells through one router endpoint: each request goes to the member that
        // suits it (the best fit gets most of a segment's traffic) and buyers like the single endpoint (+12%).
        if b.has(.modelRouting) {
            let families = Set(snap.api.compactMap(\.familyID))
            for f in families.sorted(by: { $0.uuidString < $1.uuidString }) {
                let members = snap.api.indices.filter { snap.api[$0].familyID == f }
                guard members.count >= 2 else { continue }
                for k in segs.indices {
                    let total = members.reduce(0) { $0 + seg[$1][k] }
                    let sq = members.reduce(0) { $0 + seg[$1][k] * seg[$1][k] }
                    guard total > 0, sq > 0 else { continue }
                    let routed = members.map { seg[$0][k] * seg[$0][k] / sq * total * routingPremium }
                    for (j, i) in members.enumerated() { seg[i][k] = routed[j] }
                }
            }
        }
        var segTotals = [Double](repeating: 0, count: segs.count)
        for i in snap.api.indices { for k in segs.indices { segTotals[k] += seg[i][k] } }
        for i in snap.api.indices {
            var shares = [Double](repeating: 0, count: segs.count)
            var share = 0.0, pull = 0.0
            for k in segs.indices {
                let other = max(segTotals[k] * 0.18, 1e-9)
                shares[k] = seg[i][k] / (segTotals[k] + other)
                share += weights[k] * shares[k]
                pull += weights[k] * seg[i][k]
            }
            snap.api[i].segShares = shares
            snap.api[i].share = share
            snap.api[i].attraction = pull
        }
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

    /// 3.8: what a router endpoint adds to a family's pull in each segment.
    static let routingPremium = 1.12

    /// Scores moved by `dc` log-compute (a smaller variant, quantised serving): 10 points per unit.
    static func shifted(_ v: DomainScores?, _ dc: Double) -> DomainScores? {
        guard let v else { return nil }
        guard abs(dc) > 1e-9 else { return v }
        return DomainScores(v.v.map { max(0, $0 + 10 * dc) })
    }

    /// 3.8: a product's quality for one segment's buyers. General work goes half by capability (`c`, the leaderboard's
    /// measure) and half by its domain mix; every other segment by its domain mix against a frontier model with the
    /// field's published know-how. A product not scored yet is judged on `c` alone.
    static func segmentQuality(_ p: MarketProduct, _ seg: APISegment, frontier: Double, ref: DomainScores) -> Double {
        let general = 1.5 * (p.c - frontier)
        guard let v = p.scores else { return exp(general) }
        let domain = APISegment.premium * (v.mix(seg.mix) - ref.mix(seg.mix))
        return exp(seg == .general ? 0.5 * general + 0.5 * domain : domain)
    }

    /// 3.8: an agent seat's effective capability: its agentic skill (as before), plus the agents know-how it has beyond
    /// what a typical lab has adopted (85% of what the field has published), tilted by how its reliability compares
    /// with a frontier model's.
    static func seatX(_ agenticX: Double, scores: DomainScores?, ref: DomainScores, fieldAgents: Double) -> Double {
        guard let v = scores, v[.agents] > 0 else { return agenticX }
        let knowHow = Capabilities.capability(fromScore: v[.agents]) - agenticX
        let tilt = 0.025 * ((v[.reliability] - v[.agents]) - (ref[.reliability] - ref[.agents]))
        return agenticX + (knowHow - 0.85 * fieldAgents) + clamp(tilt, -0.3, 0.3)
    }

    /// 3.8: how far a rival's specialisation has gone (0–1 over `years`): smaller models for an efficiency specialist,
    /// own silicon for a hardware one.
    static func specialistRamp(_ s: GameState, _ lab: String, _ f: RivalFocus, years: Double) -> Double {
        guard let st = s.nations.focus[lab], st.rivalFocus == f, let since = st.since else { return 0 }
        return clamp(Double(GameCalendar.daysBetween(since, s.date)) / (365 * years), 0, 1)
    }

    /// 3.8: your models' share of each API segment today (summed over your products).
    static func playerSegments(_ snap: MarketSnapshot) -> [Double] {
        var out = [Double](repeating: 0, count: APISegment.allCases.count)
        for p in snap.api where p.isPlayer {
            for (k, v) in p.segShares.enumerated() where k < out.count { out[k] += v }
        }
        return out
    }

    /// 3.8: the segments a model sells most of (its share of each, best first).
    static func segments(of id: UUID, _ snap: MarketSnapshot) -> [(segment: APISegment, share: Double)] {
        guard let p = snap.api.first(where: { $0.modelID == id }) else { return [] }
        return APISegment.allCases.compactMap { k in
            k.rawValue < p.segShares.count && p.segShares[k.rawValue] > 0.001 ? (k, p.segShares[k.rawValue]) : nil
        }.sorted { $0.share > $1.share }
    }

    /// Fixed budgets: the factor that keeps your spending share of a market within its pool. `natural` is what you'd
    /// bill at today's prices, `others` what everyone else bills (per day). 1 while the market has room; otherwise you
    /// get your share of the pool, `pool × natural ÷ (natural + others)`, and never more than the pool.
    static func budgetFactor(_ natural: Double, pool: Double, others: Double) -> Double {
        guard natural > 0, natural + others > pool else { return 1 }
        return max(0, pool) / (natural + others)
    }

    /// Seats your agent product settles at for `price`: your share of the seat pool, squeezed to your slice of the seat budget.
    static func agentSeatTarget(_ snap: MarketSnapshot, ag: MarketProduct, price: Double) -> Double {
        let othersSpend = (snap.agents.filter { !$0.isPlayer }.reduce(0) { $0 + $1.share * $1.price }
                           + max(0, 1 - snap.agents.reduce(0) { $0 + $1.share }) * snap.agentSeatBudget) * snap.agentSeatsPool / 30.4
        let natural = ag.share * snap.agentSeatsPool * max(1, price) / 30.4
        return ag.share * snap.agentSeatsPool * budgetFactor(natural, pool: snap.agentRevenuePool, others: othersSpend)
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
        let x = seatX(Leaderboard.profile(m).agenticX, scores: s.domainScores[m.id.uuidString], ref: Capabilities.reference(s.year),
                      fieldAgents: Capabilities.field(.agents, at: s.year))
        return agentWTP(x: x, y: s.year)
    }

    /// Share of weekly users who pay at `price` when they'd pay up to `wtp` (5% at the WTP). Without a free
    /// tier everyone who stays pays. No floor: at a silly price almost nobody pays.
    static func paidConversion(price: Double, freeTier: Bool, wtp: Double = 20) -> Double {
        guard freeTier else { return 1.0 }
        return min(0.3, 0.05 * wtpDemand(price / max(wtp, 1)))
    }
}
