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
}

enum Market {
    static func attraction(c: Double, price: Double, refPrice: Double, tps: Double, brand: Double,
                           frontier: Double, elasticity: Double) -> Double {
        let quality = exp(1.5 * (c - frontier))
        let priceFactor = pow(max(price, 0.0001) / max(refPrice, 0.0001), -elasticity)
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
        snap.agentSeatsPool = Macro.agentSeats(y) * sqrt(s.market.hype) * s.difficulty.demandMultiplier
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
                                                 price: def.id == "halcyon" ? 120 : 100, tps: m.tps, brand: comp.brand * (1 + def.codeBonus * 2),
                                                 open: false, reasoning: true, isPlayer: false))
            }
            let launched = comp.id == "prometheus" ? chatOn : (chatOn && y >= def.firstModel.decimal + 0.2 && y >= 2023.0)
            if launched {
                snap.consumer.append(MarketProduct(id: "\(comp.id)-chat", lab: comp.id, labName: def.name, name: def.chatProduct, c: m.c,
                                                   price: 20, tps: m.tps, brand: comp.brand * (comp.id == "prometheus" ? 1.4 : 1),
                                                   open: false, reasoning: m.reasoning, isPlayer: false))
            }
        }

        for m in s.models where m.released && !m.retired && m.api && m.capacityTokensDay > 0 {
            snap.api.append(MarketProduct(id: m.id.uuidString, lab: "player", labName: s.companyName, name: m.name,
                                          c: m.c - Physics.servingPenalty(m.servingPrecision), price: m.apiPrice,
                                          tps: max(m.tps, 1), brand: s.brand * (0.7 + 0.3 * s.reliability) * (m.design.mode == .finetune ? 0.8 : 1), open: m.openWeights,
                                          reasoning: m.reasoning, isPlayer: true, modelID: m.id))
        }
        if chatOn || (s.year < 2022.91 && s.chatModelID != nil),
           let id = s.chatModelID, let m = s.models.first(where: { $0.id == id && $0.released && !$0.retired }) {
            snap.consumer.append(MarketProduct(id: "player-chat", lab: "player", labName: s.companyName, name: "\(s.companyName) Chat",
                                               c: m.c, price: s.chatPrice, tps: max(m.tps, 1),
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
            p.attraction = attraction(c: p.c, price: p.price, refPrice: ref, tps: p.tps, brand: p.brand, frontier: frontier, elasticity: 1.4)
            if p.isPlayer { p.attraction *= (1 + b.apiDemand) * s.reliability }
            if p.open { p.attraction *= 1.15 }
            snap.api[i] = p
            totalA += p.attraction
        }
        let otherA = max(totalA * 0.18, 1e-9)
        for i in snap.api.indices { snap.api[i].share = snap.api[i].attraction / (totalA + otherA) }

        var totalC = 0.0
        for i in snap.consumer.indices {
            var p = snap.consumer[i]
            p.attraction = attraction(c: p.c, price: p.price, refPrice: 20, tps: p.tps, brand: p.brand, frontier: frontier, elasticity: 0.7)
            if p.isPlayer && !s.freeTier { p.attraction *= 0.3 }
            snap.consumer[i] = p
            totalC += p.attraction
        }
        let otherC = max(totalC * 0.12, 1e-9)
        for i in snap.consumer.indices { snap.consumer[i].share = snap.consumer[i].attraction / (totalC + otherC) }

        var totalG = 0.0
        for i in snap.agents.indices {
            var p = snap.agents[i]
            let quality = exp(1.8 * (p.c - agentFrontier))
            p.attraction = quality * pow(p.price / 100, -0.8) * pow(max(p.tps, 1) / 60, 0.2) * pow(max(p.brand, 3) / 50, 0.6)
            if p.isPlayer { p.attraction *= s.reliability }
            snap.agents[i] = p
            totalG += p.attraction
        }
        let otherG = max(totalG * 0.1, 1e-9)
        for i in snap.agents.indices { snap.agents[i].share = snap.agents[i].attraction / (totalG + otherG) }
        return snap
    }

    static func paidConversion(price: Double, freeTier: Bool) -> Double {
        let base = clamp(0.05 * pow(20 / max(price, 1), 1.0), 0.003, 0.3)
        return freeTier ? base : 1.0
    }
}
