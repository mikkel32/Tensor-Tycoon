import Foundation

/// `--watch <era>`: the rumour mill's calls against what the rival labs actually ship, with and without
/// an intel budget, plus the code-red reaction when you leapfrog them.
extension BalanceHarness {
    static func watch(era: String) {
        print("== Rival Watch from \(era) ==")
        for budget in [0.0, 2e7] {
            var s = NewGame.create(NewGameSettings(companyName: "Probe Labs", founderName: "Bot", eraID: era, difficulty: .normal), seed: 70)
            s.intelBudget = budget
            let end = s.year + 3
            var printed = false
            while s.year < end {
                Sim.advanceDay(&s)
                s.decisions.removeAll()
                s.gameOver = nil
                s.cash = max(s.cash, 1e9)
                if !printed && s.year >= end - 1.5 {
                    printed = true
                    printOutlooks(s)
                }
            }
            let calls = s.watchRecord
            let hits = calls.filter(\.hit).count
            let idxErr = calls.map { abs($0.actual - $0.forecast) }.reduce(0, +) / Double(max(1, calls.count))
            let dateErr = calls.map { Double(abs($0.dateError)) }.reduce(0, +) / Double(max(1, calls.count))
            print("  intel \(Fmt.money(budget))/mo (quality \(Fmt.pct(RivalIntel.quality(s), decimals: 0))): \(calls.count) releases called, "
                  + "\(hits) inside the 80% band, mean index error \(Fmt.trim(idxErr, 1)) pts, mean date error \(Fmt.trim(dateErr, 0)) days")
            let kinds = Dictionary(grouping: s.rumors, by: \.kind).mapValues(\.count).sorted { $0.key < $1.key }
            print("  rumours: " + kinds.map { "\($0.key) \($0.value)" }.joined(separator: " · ") + " · false \(s.rumors.filter(\.wrong).count)")
            for r in s.rumors.prefix(6) {
                print("    \(r.date.gameShort) [\(r.reliability.rawValue)] \(r.title) — \(r.body)")
            }
        }
        codeRedCheck()
    }

    static func printOutlooks(_ s: GameState) {
        let set = Leaderboard.indexSet(s)
        let mine = RivalIntel.playerBest(s, set: set)
        print("  \(s.date.gameShort) · intel quality \(Fmt.pct(RivalIntel.quality(s), decimals: 0)) · your best \(mine.map { "\($0.name) \(Fmt.score($0.index))" } ?? "none")")
        for i in s.competitors.indices {
            guard let p = s.competitors[i].project, let o = RivalIntel.outlook(s, i, set: set) else { continue }
            print(String(format: "    %-18@ %-14@ %-11@ %-18@ chips %-7@ %-8@ rumoured %@–%@ (true %@) · index %@ (%@–%@)",
                         s.competitors[i].def.name as NSString, p.name as NSString, p.codename as NSString, o.phase.rawValue as NSString,
                         Fmt.count(p.chips) as NSString, Fmt.flops(p.flops) as NSString, o.low.gameShort as NSString, o.high.gameShort as NSString,
                         p.release.gameShort as NSString, Fmt.score(o.index) as NSString, Fmt.score(o.indexLow) as NSString, Fmt.score(o.indexHigh) as NSString))
        }
    }

    /// Leapfrog the field in 2027 and see who rushes and who holds back.
    static func codeRedCheck() {
        print("\n== Code red: a lab that leapfrogs everyone in 2027 ==")
        var (s, id) = frontierLab(year: 2027.3, chips: 100_000, seed: 71)
        // Let the projects form, then ship a model well above the frontier.
        for _ in 0..<5 { Sim.advanceDay(&s) }
        guard let i = s.models.firstIndex(where: { $0.id == id }) else { return }
        var m = s.models[i]
        m.id = UUID()
        m.name = "Probe-2"
        m.c += 0.5
        m.released = false
        m.index = BenchmarkCatalog.index(Leaderboard.profile(m), set: Leaderboard.indexSet(s))
        s.models.append(m)
        printOutlooks(s)
        _ = s.release(m.id, api: true, openWeights: false)
        let reactions = s.rumors.filter { $0.kind == "codered" || $0.kind == "hold" }
        print("  reactions to Probe-2 (index \(Fmt.score(m.index))): \(reactions.count)")
        for r in reactions { print("    [\(r.kind)] \(r.title) — \(r.body)") }
        printOutlooks(s)
    }
}
