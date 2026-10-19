import Foundation

/// `TensorTycoon --ventures [year]`: headless checks for agent swarms, alien architectures, chip sales,
/// licensing, compute leasing and the money systems, starting from a frontier-level lab in `year`.
extension BalanceHarness {
    /// A frontier-level lab: core research of the year, a datacenter full of the best chips, and a flagship model.
    static func frontierLab(year: Double, chips: Int, seed: UInt64 = 11) -> (GameState, UUID) {
        let era = year < 2020 ? "2017" : (year < 2022 ? "2020" : (year < 2026 ? "2022" : "2026"))
        var s = NewGame.create(NewGameSettings(companyName: "Probe Labs", founderName: "Bot", eraID: era, difficulty: .normal), seed: seed)
        while s.year < year { Sim.advanceDay(&s); s.decisions.removeAll(); s.gameOver = nil; ScenarioHarness.fund(&s, atLeast: 1e8) }
        s.researched.formUnion(ResearchCatalog.core.filter { $0.year <= year && $0.category != .frontier }.map(\.id))
        ScenarioHarness.fund(&s, atLeast: 5e10)
        ScenarioHarness.setStage(&s, .frontierLab)   // what the lab this sets up would be
        s.valuation = Macro.frontierValuation(year) * 0.3
        let site = Site(name: "Probe Campus", kind: .datacenter, locationID: "texas", capacityKW: 3_000_000, cooling: .liquid, powerDeal: .grid,
                        opened: s.date, ready: s.date, capex: 0, monthlyFee: 0)
        s.sites.append(site)
        let ref = Silicon.reference(s)
        s.owned.append(OwnedBatch(accelID: ref.id, count: chips, siteID: site.id, purchased: s.date, unitCost: ref.price ?? 30_000))
        var d = ModelDesign()
        d.name = "Probe-1"
        d.paramsB = 1_000
        d.activeFraction = s.bonuses.has(.moe) ? 1.0 / 16 : 1
        d.tokensT = 30
        d.reasoning = s.bonuses.has(.reasoning)
        d.toolUse = s.bonuses.has(.toolUse)
        d.agentRL = s.bonuses.has(.agents)
        d.rlhf = s.bonuses.has(.rlhf)
        d.instruct = s.bonuses.has(.chat)
        d.accelID = ref.id
        let fc = ForecastEngine.forecast(d, state: s, dataSources: s.dataSources.sorted())
        let c = Macro.frontier(year)
        var m = AIModel(name: d.name, design: d, created: s.date, c: c, reasoning: d.reasoning, reasoningBoost: fc.reasoning, codeBoost: fc.code,
                        arenaBonus: 75 * fc.chat, scores: [:], index: 0)
        m.agentBoost = fc.agent
        m.chatSkill = fc.chat
        m.safety = fc.safety
        m.released = true
        m.api = true
        m.autoPrice = true
        m.apiPrice = Treasury.targetPrice(m, s)
        m.servingPrecision = s.bonuses.has(.int8Serving) ? .fp8 : .bf16
        m.index = BenchmarkCatalog.index(Leaderboard.profile(m), set: Leaderboard.indexSet(s))
        s.models.append(m)
        return (s, m.id)
    }

    static func ventures(era: String) {
        let year = Double(era) ?? 2026
        print("== Agent swarms (\(Fmt.trim(year, 1)) frontier model) ==")
        let (base, modelID) = frontierLab(year: year, chips: 400_000)
        let m = base.models.first { $0.id == modelID }!
        let ref = Silicon.reference(base)
        print("model c=\(Fmt.trim(m.c, 2)) agenticX=\(Fmt.trim(Swarms.agenticX(m), 2)) researcher-eq/agent=\(Fmt.trim(Swarms.quality(m), 3)) xeno gate=\(Fmt.trim(Swarms.xenoGate(m), 2)) tokens/agent-day=\(Fmt.count(Swarms.tokensPerAgentDay(base.year)))")
        print("agents     chips(\(ref.name))  workforce  RP/day   insight/day  days-to-alien  labor $/yr")
        for agents in [100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000] {
            let b = base.bonuses
            let chips = Swarms.chipsNeeded(m, accelID: ref.id, agents: agents, base, b)
            let f = Swarms.forecast(model: m, accelID: ref.id, chips: chips, agents: agents, mission: .xeno, autonomy: 1, oversight: 0.1, base, b)
            let w = f.workforce
            let insight = b.has(.agents) ? Swarms.insight(w * Swarms.xenoGate(m)) : 0
            let labor = min(Swarms.laborCap(base), w * Swarms.wage(base.year)) * 365
            print(String(format: "%-10@ %-18@ %-10@ %-8@ %-12@ %-14@ %@",
                         Fmt.int(agents) as NSString, Fmt.int(chips) as NSString, Fmt.count(w) as NSString, Fmt.count(Swarms.researchRP(w)) as NSString,
                         Fmt.trim(insight, 1) as NSString, (insight > 0 ? Fmt.days(Xeno.insightNeeded(base) / insight) : "never") as NSString,
                         Fmt.money(labor) as NSString))
        }

        // Run a 100k-agent alien search until the first discovery.
        var s = base
        let chips = Swarms.chipsNeeded(m, accelID: ref.id, agents: 100_000, s, s.bonuses)
        if let e = s.startSwarm(name: "Xeno", modelID: modelID, agents: 100_000, mission: .xeno, accelID: ref.id, chips: chips, autonomy: 1, oversight: 0.1) {
            print("swarm start error: \(e)")
            return
        }
        var day = 0
        while s.alienArchs.isEmpty && day < 1_500 {
            Sim.advanceDay(&s)
            s.decisions.removeAll()
            s.gameOver = nil
            day += 1
        }
        guard let arch = s.alienArchs.first else { print("no alien architecture after \(day) days (insight \(Fmt.count(s.xenoInsight)))"); return }
        let sw = s.swarms[0]
        print(String(format: "\n100k-agent search: %@ found after %d days · gain ×%.2f · chip %.1f× · cost %.0f%% · legibility %.0f%% · swarm alignment %.0f (measured %.0f), %d incidents",
                     arch.name as NSString, day, arch.multiplier, arch.chipPerf, arch.costFactor * 100, arch.legibility * 100, sw.alignment, sw.alignmentMeasured, sw.incidents))
        print("valuation moat: \(Fmt.money(Xeno.moatValue(s)))")

        // Alien model vs transformer forecast
        var d = m.design
        d.mixer = .transformer
        let plain = ForecastEngine.forecast(d, state: s, dataSources: s.dataSources.sorted())
        d.mixer = .alien
        let alien = ForecastEngine.forecast(d, state: s, dataSources: s.dataSources.sorted())
        print("forecast c: transformer \(Fmt.trim(plain.c, 2)) → alien \(Fmt.trim(alien.c, 2)); safety \(Int(plain.safety)) → \(Int(alien.safety))")

        // Tape out the chip
        if let e = s.fabAlienChip(arch.id) { print("fab error: \(e)"); return }
        day = 0
        while s.alienArchs[0].chipID == nil && day < 600 {
            Sim.advanceDay(&s)
            s.decisions.removeAll()
            s.gameOver = nil
            day += 1
        }
        guard let chipID = s.alienArchs[0].chipID, let chip = HardwareCatalog.get(chipID) else { print("no chip"); return }
        print(String(format: "alien chip after %d days: %@ bf16 %.0f fp8 %.0f fp4 %.0f · %.0f GB · %.0f W · $%.0f/unit (ref %@ $%.0f)",
                     day, chip.name as NSString, chip.bf16, chip.fp8, chip.fp4, chip.memoryGB, chip.tdpW, chip.price ?? 0,
                     ref.name as NSString, ChipBusiness.listPrice(ref, s)))

        // Three futures: exclusive, sell chips, license
        let start = s
        for policy in XenoPolicy.allCases {
            var t = start
            _ = t.setXenoPolicy(arch.id, policy)
            if policy == .sellChips {
                _ = t.addFabCapacity(chipID, units: 50_000)
                if let line = t.chipLines.first {
                    print(String(format: "  sell: price $%.0f · value ×%.2f vs ref · demand %.0f/day at reputation %.2f",
                                 line.price, ChipBusiness.valueRatio(chip: chip, price: line.price, t),
                                 ChipBusiness.demand(chip: chip, price: line.price, sellToRivals: true, t), ChipBusiness.reputation(t)))
                }
            }
            if policy == .exclusive {
                // Use it yourself: buy 20,000 at cost.
                if let site = t.sites.last { _ = t.buyHardware(chipID, count: 20_000, siteID: site.id) }
            }
            let cash0 = t.cash
            for _ in 0..<365 {
                Sim.advanceDay(&t)
                t.decisions.removeAll()
                t.gameOver = nil
                for i in t.alienArchs.indices { for o in t.alienArchs[i].offers { _ = t.acceptLicense(t.alienArchs[i].id, offer: o.id) } }
            }
            ledger(policy.rawValue, t)
            let rev = t.history.suffix(12).reduce(0) { $0 + $1.revChips + $1.revLicensing + $1.oneOffIncome }
            let rivals = t.competitors.map { "\($0.def.name.split(separator: " ").first ?? "") +\(Fmt.trim(Xeno.rivalC(t, $0.id, at: t.date), 2))" }.joined(separator: " ")
            print(String(format: "  %-18@ 1y: chip+license revenue %@ · cash Δ %@ · valuation %@ · rivals: %@",
                         policy.rawValue as NSString, Fmt.money(rev) as NSString, Fmt.money(t.cash - cash0) as NSString,
                         Fmt.money(t.valuation) as NSString, rivals as NSString))
            if policy == .sellChips, let line = t.chipLines.first {
                print(String(format: "     shipped %@ chips, revenue %@, profit %@, reputation %.2f", Fmt.count(line.shipped) as NSString,
                             Fmt.money(line.revenue) as NSString, Fmt.money(line.profit) as NSString, ChipBusiness.reputation(t)))
            }
        }

        // Leasing, labor and treasury
        print("\n== Compute leasing & money ==")
        var t = base
        let leaseN = 50_000
        _ = t.setLease(ref.id, chips: leaseN)
        print("lease \(Fmt.int(leaseN))× \(ref.name): list \(Fmt.price(ChipBusiness.listRate(ref, t)))/hr, occupancy \(Fmt.pct(ChipBusiness.occupancy(t, leasedH100e: ChipBusiness.leasedH100e(t)))), income \(Fmt.money(ChipBusiness.leaseIncomePerDay(ref, count: leaseN, t) * 365))/yr, owning cost \(Fmt.money(Economy.chipDailyCost(ref, count: leaseN, state: t) * 365))/yr")
        let laborChips = Swarms.chipsNeeded(m, accelID: ref.id, agents: 200_000, t, t.bonuses)
        _ = t.startSwarm(name: "Workforce", modelID: modelID, agents: 200_000, mission: .workforce, accelID: ref.id, chips: laborChips, autonomy: 1, oversight: 0.2)
        let cash0 = t.cash
        for _ in 0..<90 { Sim.advanceDay(&t); t.decisions.removeAll(); t.gameOver = nil }
        let h = t.history.suffix(2)
        print("90 days: labor \(Fmt.money(h.reduce(0) { $0 + $1.revLabor })) (2 months), cloud \(Fmt.money(h.reduce(0) { $0 + $1.revCloud })), interest \(Fmt.money(h.reduce(0) { $0 + $1.interestIncome })), cash Δ \(Fmt.money(t.cash - cash0))")
        print("labor cap \(Fmt.money(Swarms.laborCap(t) * 365))/yr; workforce swarm \(Fmt.count(t.swarms.first?.active ?? 0)) active agents on \(Fmt.int(laborChips)) chips")
        if let e = t.sellFounderShares(fraction: 0.05) { print("founder sale: \(e)") } else {
            print("founder sold 5%: cash \(Fmt.money(t.founderCash)), stake \(Fmt.pct(t.founderStake)), net worth \(Fmt.money(t.founderNetWorth))")
        }
    }
}

extension BalanceHarness {
    static func ledger(_ label: String, _ s: GameState) {
        guard let h = s.history.last else { return }
        print(String(format: "  [%@] %@ rev %@ opex %@ (rent %@ power %@ sites %@ payroll %@ data %@ mkt %@ other %@ chips %@) int %@ tax %@ capex %@ profit %@",
                     label as NSString, h.month.gameMonth as NSString, Fmt.money(h.revenue) as NSString, Fmt.money(h.opex) as NSString,
                     Fmt.money(h.costRent) as NSString, Fmt.money(h.costPower) as NSString, Fmt.money(h.costSites) as NSString,
                     Fmt.money(h.costPayroll) as NSString, Fmt.money(h.costData) as NSString, Fmt.money(h.costMarketing) as NSString,
                     Fmt.money(h.costOther) as NSString, Fmt.money(h.costChips) as NSString, Fmt.money(h.costInterest) as NSString,
                     Fmt.money(h.taxes) as NSString, Fmt.money(h.capex) as NSString, Fmt.money(h.profit) as NSString))
    }
}
