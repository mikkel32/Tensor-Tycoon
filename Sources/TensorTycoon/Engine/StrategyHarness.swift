import Foundation

/// `TensorTycoon --strategy [era]`: what each doctrine changes, how board goals play out, and rival acquisitions.
extension BalanceHarness {
    static func strategy(era: String) {
        print("== Doctrines (\(era) start, Star Researcher founder) ==")
        print("doctrine                     RP/day  H100 $   forecast c  safety  API attr  cons attr  chip spd")
        var design = ModelDesign()
        design.paramsB = 7
        design.tokensT = 0.3
        design.instruct = true
        for d in LabDoctrine.allCases {
            var settings = NewGameSettings(companyName: "Probe", founderName: "Bot", eraID: era, difficulty: .normal)
            settings.doctrine = d
            let s = NewGame.create(settings, seed: 5)
            let f = ForecastEngine.forecast(design, state: s, dataSources: s.dataSources.sorted())
            let t = s.traits
            let h100 = Economy.price(HardwareCatalog.h100, s) ?? 0
            print(String(format: "%-28@ %6.2f  %7.0f  %10.2f  %6.0f  %8.2f  %9.2f  %8.2f",
                         d.title as NSString, Sim.researchRate(s, s.bonuses), h100, f.c, f.safety,
                         1 + t.api, 1 + t.consumer, max(0.4, 1 - t.chipDesign)))
        }

        print("\n== Founder backgrounds ==")
        for bg in FounderBackground.choosable {
            var settings = NewGameSettings(companyName: "Probe", founderName: "Bot", eraID: era, difficulty: .normal)
            settings.background = bg
            let s = NewGame.create(settings, seed: 5)
            print(String(format: "%-24@ cash %@  RP/day %.2f  payroll %@/yr  brand %.0f  loans from %.2f%%",
                         bg.title as NSString, Fmt.money(s.cash) as NSString, Sim.researchRate(s, s.bonuses),
                         Fmt.money(Economy.payrollYear(s)) as NSString, s.brand, Economy.loanQuotes(s).map(\.rate).min() ?? 0))
        }

        print("\n== Board goals over 3 years (idle frontier lab, 2026) ==")
        var (s, _) = frontierLab(year: 2026, chips: 20_000)
        s.boardConfidence = 60
        s.objectives = []
        Board.refill(&s)
        for o in s.objectives { print("  new: \(o.title) by \(o.deadline.gameShort) · reward \(Fmt.money(o.rewardCash)) + \(o.rewardPoints) CP") }
        for _ in 0..<(365 * 3) { Sim.advanceDay(&s); s.decisions.removeAll(); s.gameOver = nil }
        print("  completed \(s.objectivesCompleted), failed \(s.objectivesFailed), confidence \(Int(s.boardConfidence)) (\(Board.mood(s.boardConfidence))), culture points \(s.culturePoints)")
        for o in s.objectives.suffix(6) { print("  \(o.done ? "✓" : (o.failed ? "✗" : "…")) \(o.title) (\(Int(o.progress * 100))%)") }

        print("\n== Acquisitions (2026 frontier lab worth ~\(Fmt.money(frontierLab(year: 2026, chips: 1).0.valuation))) ==")
        var (lab, _) = frontierLab(year: 2026, chips: 50_000)
        lab.valuation = 2e12
        lab.cash = 5e11
        for c in lab.competitors {
            let h = Acquisitions.haul(c, lab)
            print(String(format: "  %-16@ worth %@ · price %@ · antitrust %.0f%% · %d techs, %d researchers, %@ chips, %@ users · %@",
                         c.def.name as NSString, Fmt.money(c.valuation) as NSString, Fmt.money(Acquisitions.price(c, lab)) as NSString,
                         Acquisitions.antitrustRisk(c, lab) * 100, h.techs.count, h.researchers, Fmt.int(h.chips) as NSString,
                         Fmt.count(h.users) as NSString, (Acquisitions.blocker(c, lab) ?? "OK") as NSString))
        }
        var t = lab
        let models0 = t.models.count
        if let e = t.acquireRival("xenon", stockShare: 0.5) { print("  acquire error (expected, not enough cash): \(e)") }
        if let e = t.acquireRival("xenon", stockShare: 0.8) { print("  acquire error: \(e)") }
        print("  bought Xenon: acquired=\(t.competitors.first { $0.id == "xenon" }?.acquired ?? false) models \(models0)→\(t.models.count) chips \(Economy.totalChips(t)) employees \(t.employees.count) cash \(Fmt.money(t.cash)) stake \(Fmt.pct(t.founderStake))")
        for n in t.news.prefix(2) { print("  news: \(n.title) — \(n.body)") }
        securityAndPolicy()
    }

    static func securityAndPolicy() {
        print("\n== Weight security: 3 years as a frontier lab (2026) ==")
        for level in SecurityLevel.allCases {
            var (s, _) = frontierLab(year: 2026, chips: 20_000, seed: UInt64(30 + level.rawValue))
            s.securityRaw = level.rawValue
            let threats = SecurityOps.threats(s).map { "T\($0.tier) \(Int($0.monthlyChance * 100))%" }.joined(separator: " ")
            let upkeep = SecurityOps.upkeep(level, s)
            for day in 0..<(365 * 3) {
                Sim.advanceDay(&s)
                s.decisions.removeAll()
                s.gameOver = nil
                // Keep the flagship at the frontier, like a lab that keeps training.
                if day % 30 == 0, let i = s.models.indices.first { s.models[i].c = Macro.frontier(s.year) }
            }
            print(String(format: "  %@: upkeep %@/mo, research −%.0f%% · threats/mo %@ · thefts %d, foiled %d · rivals holding stolen weights: %@",
                         level.title as NSString, Fmt.money(upkeep) as NSString, level.friction * 100, threats as NSString, s.thefts, s.attacksFoiled,
                         (s.stolenC.keys.sorted().joined(separator: ", ").isEmpty ? "none" : s.stolenC.keys.sorted().joined(separator: ", ")) as NSString))
        }
        var (u, _) = frontierLab(year: 2026, chips: 1)
        print("  upgrade costs at this size: " + SecurityLevel.allCases.dropFirst().map { "\($0.title) \(Fmt.money(SecurityOps.upgradeCost($0, u))) / \($0.upgradeMonths) mo" }.joined(separator: " · "))
        if let e = u.upgradeSecurity() { print("  upgrade error: \(e)") }
        for _ in 0..<70 { Sim.advanceDay(&u); u.decisions.removeAll() }
        print("  after 70 days: \(u.security.title) (target SL\(u.securityTarget))")

        print("\n== Policy: 4 years, backing every bill, by lobbying budget (2026) ==")
        for budget in [0.0, 1e6, 2e7] {
            var (s, _) = frontierLab(year: 2026, chips: 1_000, seed: 77)
            s.setLobbyBudget(budget)
            for _ in 0..<(365 * 4) {
                Sim.advanceDay(&s)
                for d in s.decisions {
                    if d.kind == "policy_bill" { s.resolveDecision(d.id, option: 0) }
                }
                s.decisions.removeAll()
                s.gameOver = nil
            }
            print("  \(Fmt.money(budget))/mo: capital \(Int(s.politicalCapital)), passed \(s.lawsPassed.sorted()), failed \(s.lawsFailed.sorted()), fine factor ×\(Fmt.trim(Policy.fineFactor(s), 2))")
        }
        incidents()
    }

    /// The 2026-style incidents: distillation campaigns, sandbox escapes and insiders, resolved with every option.
    static func incidents() {
        print("\n== Incidents: 3 years as a frontier lab at SL2 (2026), cycling through every option ==")
        let kinds = ["distill_campaign", "eval_escape", "insider_caught"]
        var fired: [String: Int] = [:]
        var samples: [String] = []
        var pick = 0
        for seed in 0..<6 {
            var (s, _) = frontierLab(year: 2026, chips: 20_000, seed: UInt64(90 + seed))
            s.securityRaw = 2
            // A real frontier lab has hundreds of staff: enough for insider risk.
            if let e = s.employees.first {
                for _ in 0..<60 { var c = e; c.id = StableID.next(); s.employees.append(c) }
            }
            for day in 0..<(365 * 3) {
                Sim.advanceDay(&s)
                for d in s.decisions where kinds.contains(d.kind) {
                    fired[d.kind, default: 0] += 1
                    let before = s.news.count
                    s.resolveDecision(d.id, option: pick % d.options.count)
                    if s.news.count > before, let n = s.news.first, samples.count < 6 { samples.append("\(d.kind) → option \(pick % d.options.count): \(n.title)") }
                    pick += 1
                }
                s.decisions.removeAll()
                s.gameOver = nil
                if day % 30 == 0, let i = s.models.indices.first { s.models[i].c = Macro.frontier(s.year) }
            }
        }
        print("  fired over 18 lab-years: " + kinds.map { "\($0) \(fired[$0] ?? 0)" }.joined(separator: " · "))
        for line in samples { print("  \(line)") }
    }
}
