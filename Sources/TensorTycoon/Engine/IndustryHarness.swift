import Foundation

/// `--industry <era>`: the rival labs' businesses over the years, and a player who invests in them.
extension BalanceHarness {
    static func industry(era: String) {
        print("== The AI industry from \(era) to 2033 (passive player) ==")
        var s = NewGame.create(NewGameSettings(companyName: "Probe Labs", founderName: "Bot", eraID: era, difficulty: .normal), seed: 50)
        var year = Int(s.year)
        while s.year < 2033 {
            Sim.advanceDay(&s)
            s.decisions.removeAll()
            s.gameOver = nil
            s.cash = max(s.cash, 1e7)
            if Int(s.year) != year {
                year = Int(s.year)
                printIndustry(s)
            }
        }
        let after = s.competitors.flatMap { c in c.rounds.filter { $0.date.decimalYear >= RivalHistory.end }.map { (c.def.name, $0) } }
        print("  procedural rounds after Oct 2026: \(after.count) · IPOs: \(after.filter { $0.1.kind == .ipo }.map(\.0).joined(separator: ", ")) · down/rescue rounds: \(after.filter { $0.1.label == "Down round" || $0.1.kind == .rescue }.count)")
        print("  exits: " + (s.competitors.filter { !$0.exitNote.isEmpty }.map { "\($0.def.name): \($0.exitNote)" }.joined(separator: " · ").isEmpty ? "none" : s.competitors.filter { !$0.exitNote.isEmpty }.map { "\($0.def.name): \($0.exitNote)" }.joined(separator: " · ")))
        print("  corrections: \(s.lastCorrection.map { "last \($0.gameShort)" } ?? "none")")
        print("\n== Rival strategies 2017–2033 ==")
        for c in s.competitors where !c.playLog.isEmpty {
            print("  \(c.def.name): now \(RivalStrategy.play(c)?.title ?? "—")\(c.exitNote.isEmpty ? "" : " (\(c.exitNote))")")
            for line in c.playLog.reversed() { print("      \(line)") }
        }
        let opens = s.competitors.flatMap(\.openModels)
        print("  open-weights side releases: \(opens.count) · sponsored bills passed or failed: \(s.lawsPassed.count + s.lawsFailed.count) · API price pressure \(Fmt.trim(s.market.apiPricePressure, 2))")
        investorCheck()
    }

    static func printIndustry(_ s: GameState) {
        print("\(Int(s.year)) · hype \(Fmt.trim(s.market.hype, 2)) · industry multiple \(Int(s.industryMultiple))×\(RivalEconomy.inCorrection(s) ? " · CORRECTION" : "")")
        for c in s.competitors where s.year >= c.def.founded.decimal {
            let runway = RivalEconomy.runwayMonths(c).map { "\(Int($0)) mo" } ?? "∞"
            let mult = c.revenueRun > 1e6 ? "\(Int(c.valuation / c.revenueRun))×" : "—"
            print(String(format: "  %-22@ rev %-9@ val %-9@ %-6@ cash %-9@ runway %-6@ staff %-6d H100e %-8@ %@",
                         c.def.name as NSString, Fmt.money(c.revenueRun) as NSString, Fmt.money(c.valuation) as NSString, mult as NSString,
                         Fmt.money(c.cash) as NSString, runway as NSString, c.headcount, Fmt.count(c.computeH100e) as NSString,
                         RivalEconomy.status(c, s) as NSString))
        }
    }

    /// A rich lab that joins every round it's offered and buys every fire sale.
    static func investorCheck() {
        print("\n== Investor: a frontier lab joining rivals' rounds, 2026–2031 ==")
        var (s, _) = frontierLab(year: 2026, chips: 50_000, seed: 51)
        s.cash = 2e11
        // Lease some chips out, so rivals can commit to buying your compute.
        _ = s.setLease(Silicon.reference(s).id, chips: 1_000)
        var offers = 0, fireSales = 0
        for _ in 0..<(365 * 5) {
            Sim.advanceDay(&s)
            for d in s.decisions {
                if d.kind == "rival_round" { offers += 1; s.resolveDecision(d.id, option: 1) }
                if d.kind == "fire_sale" { fireSales += 1; s.resolveDecision(d.id, option: 0) }
            }
            s.decisions.removeAll()
            s.gameOver = nil
            s.cash = max(s.cash, 5e10)
        }
        print("  round offers \(offers), fire sales \(fireSales), acquired labs \(s.acquiredLabs.count)")
        for (id, f) in s.rivalStakes.sorted(by: { $0.key < $1.key }) {
            let name = CompetitorCatalog.byID[id]?.name ?? id
            print("  stake in \(name): \(Fmt.pct(f)) worth \(Fmt.money(RivalEconomy.stakeValue(s, id))) (cost \(Fmt.money(s.rivalStakeCost[id] ?? 0)))")
        }
        print("  stakes add \(Fmt.money(RivalEconomy.stakesValue(s) * 0.9)) to your valuation of \(Fmt.money(s.valuation))")
        if let id = s.rivalStakes.keys.sorted().first, let err = s.sellRivalStake(id) { print("  sell error: \(err)") }
        else if let n = s.news.first { print("  \(n.title) — \(n.body)") }
    }
}
