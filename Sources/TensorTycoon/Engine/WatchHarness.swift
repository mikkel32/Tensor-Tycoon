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
        strategyCheck()
    }

    /// You lead the world in 2027 with a strong research team: how do the rivals play against you?
    static func strategyCheck() {
        print("\n== Rival strategies against a leading lab (2027–2029) ==")
        var (s, id) = frontierLab(year: 2027.0, chips: 150_000, seed: 72)
        for k in 0..<10 {
            s.employees.append(Employee(name: "Researcher \(k)", role: .researcher, skill: 80, salary: 900_000, hired: s.date))
        }
        if let i = s.models.firstIndex(where: { $0.id == id }) {
            s.models[i].c += 0.45
            s.models[i].index = BenchmarkCatalog.index(Leaderboard.profile(s.models[i]), set: Leaderboard.indexSet(s))
            _ = s.deploy(id, accelID: Silicon.reference(s).id, chips: 60_000)
        }
        var kinds: [String: Int] = [:]
        var sponsored = 0
        var shares: [String] = []
        for day in 0..<(365 * 2) {
            Sim.advanceDay(&s)
            for d in s.decisions {
                kinds[d.kind, default: 0] += 1
                if d.kind == "policy_bill", s.bills.contains(where: { $0.id == d.ref && !$0.sponsor.isEmpty }) { sponsored += 1 }
                s.resolveDecision(d.id, option: d.kind == "talent_raid" ? 1 : (d.options.count - 1))
            }
            s.decisions.removeAll()
            s.gameOver = nil
            s.cash = max(s.cash, 1e10)
            if day % 120 == 0 {
                let snap = Market.snapshot(s)
                let mine = snap.api.filter(\.isPlayer).reduce(0) { $0 + $1.share }
                shares.append("\(s.date.gameMonth) \(Fmt.pct(mine, decimals: 0))")
                if day % 240 == 0 {
                    let top = snap.api.sorted { $0.share > $1.share }.prefix(5)
                    print("    \(s.date.gameMonth) top API: " + top.map { "\($0.name) \(Fmt.pct($0.share, decimals: 0)) $\(Fmt.trim($0.price, 2)) c\(Fmt.trim($0.c - Macro.frontier(s.year), 2))" }.joined(separator: " · "))
                }
            }
        }
        print("  your API share: " + shares.joined(separator: " · ") + " · price pressure \(Fmt.trim(s.market.apiPricePressure, 2))")
        print("  decisions: " + kinds.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · ") + " · sponsored bills \(sponsored)")
        for c in s.competitors where !c.playLog.isEmpty {
            print("  \(c.def.name): " + c.playLog.prefix(4).reversed().joined(separator: " → "))
        }
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
        // Clearly ahead of every lab's next model (rivals' skills grow after 2025, so beat their capability by a margin).
        let rivalBest = s.competitors.indices.map { Competitors.plannedC(s, compIndex: $0, date: s.date) }.max() ?? m.c
        m.c = max(m.c, rivalBest) + 1.2
        m.released = false
        // A complete frontier model (vision, long context, strong skills), so no benchmark kind caps its index.
        m.design.vision = true
        m.design.contextK = max(m.design.contextK, 1_000)
        m.reasoningBoost += 0.5
        m.agentBoost += 0.5
        m.codeBoost += 0.3
        m.visSkill = max(m.visSkill, 0.3)
        // The index compresses near the top, so raise it until it clears every in-flight forecast by 3 points.
        let set = Leaderboard.indexSet(s)
        let bar = (s.competitors.indices.compactMap { RivalIntel.outlook(s, $0, set: set)?.index }.max() ?? 0) + 3
        var steps = 0
        while BenchmarkCatalog.index(Leaderboard.profile(m), set: set) < bar && steps < 30 {
            m.c += 0.2
            m.id = UUID()   // scores are cached by profile key (the model id): a new id re-scores
            steps += 1
        }
        m.index = BenchmarkCatalog.index(Leaderboard.profile(m), set: set)
        s.models.append(m)
        printOutlooks(s)
        _ = s.release(m.id, api: true, openWeights: false)
        let reactions = s.rumors.filter { $0.kind == "codered" || $0.kind == "hold" }
        print("  reactions to Probe-2 (index \(Fmt.score(m.index))): \(reactions.count)")
        for r in reactions { print("    [\(r.kind)] \(r.title) — \(r.body)") }
        printOutlooks(s)
    }
}
