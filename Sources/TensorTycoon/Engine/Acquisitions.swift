import Foundation

/// Buying a rival lab: pay cash or stock at a control premium, survive the antitrust review, and inherit its
/// secret techniques, top researchers, compute, users and flagship model.
enum Acquisitions {
    static let premium = 1.35

    /// What it costs to buy the part of the lab you don't already own.
    static func price(_ c: CompetitorState, _ s: GameState) -> Double { max(c.valuation, 2e8) * premium * (1 - (s.rivalStakes[c.id] ?? 0)) }

    static func blocker(_ c: CompetitorState, _ s: GameState) -> String? {
        if c.acquired { return "\(c.def.name) has already been acquired." }
        if s.year < c.def.founded.decimal { return "\(c.def.name) doesn't exist yet." }
        if let last = s.lastAntitrustBlock, GameCalendar.daysBetween(last, s.date) < 365 {
            return "Regulators blocked your last deal. Try again after \(GameCalendar.addDays(last, 365).gameShort)."
        }
        let giant = c.id == "prometheus" || c.id == "deepgrove"
        let need = c.valuation * (giant ? 3 : 1.5)
        if s.valuation < need {
            return "You need to be worth \(Fmt.money(need)) (\(giant ? "3" : "1.5")× \(c.def.name)) to buy it — you're at \(Fmt.money(s.valuation))."
        }
        return nil
    }

    /// Chance regulators block the deal.
    static func antitrustRisk(_ c: CompetitorState, _ s: GameState) -> Double {
        let snap = Market.snapshot(s)
        let mineAPI = snap.api.filter(\.isPlayer).reduce(0) { $0 + $1.share }
        let mineChat = snap.consumer.filter(\.isPlayer).reduce(0) { $0 + $1.share }
        let combined = max(mineAPI + c.apiShare, mineChat + c.consumerShare, s.agentShare + c.agentShare)
        var r = (combined - 0.2) * 2.5
        if c.valuation > s.valuation * 0.5 { r += 0.15 }
        r -= s.traits.fines * 0.2
        r *= 1 - s.politicalCapital / 200
        return clamp(r, 0.02, 0.85)
    }

    struct Haul {
        var techs: [String]
        var researchers: Int
        var chips: Int
        var chipName: String
        var users: Double
        var seats: Double
        var model: String?
    }

    static func haul(_ c: CompetitorState, _ s: GameState) -> Haul {
        let techs = (s.rivalTech[c.id] ?? []).filter { !s.researched.contains($0) }
        let room = max(0, Economy.officeCapacity(s) - s.employees.count)
        let researchers = min(room, min(8, 2 + Int(3 * log10(max(c.valuation, 1e9) / 1e9))))
        let ref = Silicon.reference(s)
        let chips = Int(min(500_000, c.computeH100e * 0.25 * HardwareCatalog.h100.bf16 / max(ref.bf16, 1)))
        let snap = Market.snapshot(s)
        return Haul(techs: techs, researchers: researchers, chips: chips, chipName: ref.name,
                    users: snap.consumerUsersPool * c.consumerShare * 0.4, seats: snap.agentSeatsPool * c.agentShare * 0.4,
                    model: c.latest?.name)
    }

    static func inheritModel(_ s: inout GameState, _ c: CompetitorState) {
        guard let m = c.latest else { return }
        let def = c.def
        let b = s.bonuses
        let p = Leaderboard.profile(m, def: def, boost: Competitors.boost(s, def.id, at: m.date.decimalYear))
        var d = ModelDesign()
        d.name = m.name
        d.paramsB = max(1, m.paramsB)
        d.activeFraction = m.paramsB > 300 && b.has(.moe) ? 1.0 / 16 : 1
        d.tokensT = max(0.01, 20 * d.activeParamsB / 1000)
        d.reasoning = m.reasoning
        d.instruct = true
        d.rlhf = true
        d.toolUse = p.agent > 0.05
        d.vision = p.vision
        d.contextK = p.contextK
        d.accelID = Silicon.reference(s).id
        var model = AIModel(name: m.name, design: d, created: s.date, c: m.c, reasoning: m.reasoning, reasoningBoost: p.reasoning,
                            codeBoost: p.code, arenaBonus: 75 * p.chat, scores: [:], index: 0)
        model.agentBoost = p.agent
        model.chatSkill = p.chat
        model.langSkill = p.lang
        model.longctxSkill = p.longctx
        model.visSkill = p.vis
        model.safety = p.safety
        model.released = true
        model.releaseDate = s.date
        model.api = true
        model.autoPrice = true
        model.servingPrecision = b.has(.int8Serving) ? .fp8 : .bf16
        model.apiPrice = Treasury.targetPrice(model, s)
        model.keyTech = ["Acquired from \(def.name)"]
        model.index = BenchmarkCatalog.index(Leaderboard.profile(model), set: Leaderboard.indexSet(s))
        s.models.append(model)
    }
}

extension GameState {
    /// Buy a rival lab. `stockShare` of the price is paid in new shares, the rest in cash.
    mutating func acquireRival(_ id: String, stockShare: Double, priceOverride: Double? = nil) -> String? {
        guard let i = competitors.firstIndex(where: { $0.id == id }) else { return "Unknown lab." }
        let c = competitors[i]
        if let why = Acquisitions.blocker(c, self) { return why }
        let price = priceOverride ?? Acquisitions.price(c, self)
        let stock = clamp(stockShare, 0, 0.8) * price
        let cashPart = price - stock
        if cashPart > cash { return "The cash part is \(Fmt.money(cashPart)); you have \(Fmt.money(cash)). Pay more in stock or raise money." }
        let risk = Acquisitions.antitrustRisk(c, self)
        if rng.chance(risk) {
            let fee = price * 0.02
            cash -= fee
            month.costOther += fee
            lastAntitrustBlock = date
            Sim.news(&self, "Regulators block your bid for \(c.def.name)",
                     "Competition authorities ruled the deal would concentrate the AI market. You pay a \(Fmt.money(fee)) break fee and can't try another deal for a year.",
                     .policy, image: "stock_exchange", important: true, good: false)
            return nil
        }
        let haul = Acquisitions.haul(c, self)
        cash -= cashPart
        month.capex += cashPart
        if stock > 0 {
            let perShare = isPublic ? sharePrice : valuation / max(1, totalShares)
            holdings.append(Holding(name: "Former \(c.def.name) shareholders", shares: stock / max(perShare, 0.01)))
        }
        competitors[i].acquired = true
        competitors[i].exitNote = "Acquired by \(companyName)"
        competitors[i].acquiredBy = "player"
        competitors[i].exitDate = date
        // Not everyone stays after a takeover: some of its people may found something new.
        competitors[i].turmoil = max(competitors[i].turmoil, 0.6)
        competitors[i].project = nil
        pendingDeals.removeAll { $0.targetID == id }
        acquiredLabs.append(id)
        rivalStakes[id] = nil
        rivalStakeCost[id] = nil
        // Their secret techniques: you get the code and the people who wrote it.
        for tech in haul.techs {
            researched.insert(tech)
            researchResults[tech] = 1.0
            if !exoticOwned.contains(tech) { exoticOwned.append(tech) }
            researchQueue.removeAll { $0 == tech }
        }
        for _ in 0..<haul.researchers {
            let skill = rng.range(74, 93)
            let salary = (Macro.salary(.researcher, year) * pow(skill / 50, 1.6) * 1.2 / 1000).rounded() * 1000
            employees.append(Employee(name: "\(rng.pick(NameBank.first)) \(rng.pick(NameBank.last))", role: .researcher, skill: skill.rounded(),
                                      salary: salary, morale: 65, hired: date, star: skill > 88, equity: 0.05))
        }
        if haul.chips > 0 {
            let ref = Silicon.reference(self)
            let kw = Economy.chipKW(ref) * Double(haul.chips) * 1.15
            let site = Site(name: "\(c.def.name) campus", kind: .datacenter, locationID: "oregon", capacityKW: max(kw, 1_000),
                            cooling: .liquid, powerDeal: .grid, opened: date, ready: date, capex: kw / 1000 * Cooling.liquid.capexPerMW * 0.5, monthlyFee: 0)
            sites.append(site)
            owned.append(OwnedBatch(accelID: ref.id, count: haul.chips, siteID: site.id, purchased: date, unitCost: (ref.price ?? 30_000) * 0.6))
        }
        consumerUsers += haul.users
        agentSeats += haul.seats
        brand = min(100, brand + c.brand * 0.15)
        Acquisitions.inheritModel(&self, c)
        valuation = Economy.valuation(self)
        Achievements.unlock(&self, "consolidator")
        Cast.labClosed(&self, id)   // 3.4: its people join you or move on
        let body = "\(Fmt.money(cashPart)) in cash\(stock > 0 ? " and \(Fmt.money(stock)) in stock" : ""). You inherit \(haul.techs.count) secret technique\(haul.techs.count == 1 ? "" : "s"), \(haul.researchers) researchers, \(Fmt.int(haul.chips))× \(haul.chipName), \(Fmt.count(haul.users)) chat users\(haul.model.map { " and \($0)" } ?? "")."
        Sim.news(&self, "\(companyName) acquires \(c.def.name) for \(Fmt.money(price))", body, .competitor, image: "nvidia_hq", important: true, good: true)
        RivalLifecycle.record(&self, .bought, lab: id, other: "player", title: "Bought by \(companyName)", body: body, amount: price)
        return nil
    }
}
