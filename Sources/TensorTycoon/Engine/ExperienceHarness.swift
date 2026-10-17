import Foundation

/// `--experience [year]`: the layer between the simulation and the player. A hands-off lab with and without
/// its delegates, the alerts and inbox over a played game, the monthly briefings, and whether every
/// Chief of Staff fix works when clicked.
extension BalanceHarness {
    static func experience(era: String) {
        let year = Double(era) ?? 2024
        delegatesCheck(year: year)
        let s = alertsCheck(year: year)
        briefingsCheck(s)
        fixesCheck(year: year)
    }

    /// A lab with chores waiting: a model to launch, too few servers, leads, an empty bench.
    static func choresLab(year: Double, seed: UInt64) -> (GameState, UUID) {
        var (s, id) = frontierLab(year: year, chips: 30_000, seed: seed)
        let ref = Silicon.reference(s).id
        _ = s.deploy(id, accelID: ref, chips: 64)
        s.chatModelID = id
        if let i = s.models.firstIndex(where: { $0.id == id }) {
            var next = s.models[i]
            next.id = UUID()
            next.name = "Probe-2"
            next.c += 0.4
            next.released = false
            next.api = false
            next.deployments = []
            next.index = BenchmarkCatalog.index(Leaderboard.profile(next), set: Leaderboard.indexSet(s))
            s.models.append(next)
        }
        return (s, id)
    }

    static func delegatesCheck(year: Double) {
        print("== Who runs operations: a frontier lab's best model by year ==")
        for y in [2023.0, 2024.5, 2025.5, 2026.5, 2027.5, 2029.0] {
            let (s, _) = frontierLab(year: y, chips: 1_000, seed: 20)
            let c = Operations.competence(s)
            print("  \(Fmt.trim(y, 1)): \(c.tier) · every \(c.everyDays) day(s) · precision \(Fmt.trim(c.precision, 2))")
        }
        print("\n== Delegates: a year of a hands-off lab with chores waiting (\(Fmt.trim(year, 1))) ==")
        for delegates in [false, true] {
            var (s, _) = choresLab(year: year, seed: 21)
            if delegates {
                s.updateOps {
                    $0.autoscale = true; $0.autoLaunch = true; $0.autoRenew = true; $0.leaseIdle = true
                    $0.autoHire = true; $0.autoRaises = true; $0.autoLeads = true; $0.autoTrain = true
                }
            }
            let comp = Operations.competence(s)
            let cash0 = s.cash
            var pauses = 0
            for _ in 0..<365 {
                Sim.advanceDay(&s)
                if s.pauseRequested { pauses += 1; s.pauseRequested = false }
                for d in s.decisions where Alerts.isUrgent(d) { s.resolveDecision(d.id, option: 0) }
                s.gameOver = nil
            }
            let last = s.history.suffix(3)
            let rev = last.map(\.revenue).reduce(0, +) / Double(max(1, last.count))
            let served = last.map(\.served).reduce(0, +) / Double(max(1, last.count))
            let live = s.models.filter { $0.released && !$0.retired }
            let trained = s.models.filter { !["Probe-1", "Probe-2"].contains($0.name) }.map { "\($0.name) c\(Fmt.trim($0.c, 2))" }
            if delegates { print("  models the training delegate made: " + (trained.isEmpty ? "none" : trained.joined(separator: ", "))) }
            print("  \(delegates ? "delegates on " : "delegates off"): revenue \(Fmt.money(rev))/mo · served \(Fmt.pct(served, decimals: 0)) · cash \(Fmt.money(s.cash - cash0)) · "
                  + "staff \(s.employees.count) · contracts \(s.deals.filter(\.active).count) · live models \(live.map(\.name).joined(separator: ", ")) · pauses \(pauses)")
            if delegates {
                print("  COO: \(comp.tier), every \(comp.everyDays) day(s), precision \(Fmt.trim(comp.precision, 2)) — \(comp.summary)")
                for line in s.opsLog.suffix(8).reversed() { print("    \(line)") }
                print("    … \(s.opsLog.count) actions logged")
            }
        }
    }

    /// Two played years: what alerts fire, what pauses the game, what the inbox resolves on its own.
    static func alertsCheck(year: Double) -> GameState {
        print("\n== Alerts and inbox: two played years (\(Fmt.trim(year, 1))), inbox ignored ==")
        var (s, id) = choresLab(year: year, seed: 23)
        _ = s.launch(s.models.first { $0.name == "Probe-2" }?.id ?? id)
        var pauses: [String: Int] = [:]
        var urgent = 0
        var created: [String: Int] = [:]
        var seen = Set<UUID>()
        var runN = 2
        for day in 0..<(365 * 2) {
            let before = Set(s.alerts.map(\.id))
            Sim.advanceDay(&s)
            if s.pauseRequested {
                s.pauseRequested = false
                for a in s.alerts where !before.contains(a.id) && s.pauseKinds.contains(a.kind) { pauses[a.kind, default: 0] += 1 }
            }
            for d in s.decisions where !seen.contains(d.id) {
                seen.insert(d.id)
                created[Alerts.isUrgent(d) ? "urgent" : "inbox", default: 0] += 1
            }
            for d in s.decisions where Alerts.isUrgent(d) {
                urgent += 1
                s.resolveDecision(d.id, option: 0)
            }
            s.gameOver = nil
            s.cash = max(s.cash, 1e9)
            // Keep training: a new model every ~5 months on a third of the fleet.
            if day % 150 == 20, let base = s.models.max(by: { $0.c < $1.c }) {
                runN += 1
                var d = base.design
                d.name = "Probe-\(runN)"
                d.chips = 10_000
                if let est = Physics.estimate(d, state: s), est.days > 0 { d.tokensT *= 75 / est.days }
                if let e = s.startTraining(d) { print("  start error: \(e)") }
            }
        }
        let kinds = Dictionary(grouping: s.alerts, by: \.kind).mapValues(\.count)
        print("  alerts kept: " + kinds.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))
        print("  pauses: " + (pauses.isEmpty ? "none" : pauses.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · ")))
        print("  decisions: \(created["urgent"] ?? 0) urgent (stop the clock), \(created["inbox"] ?? 0) to the inbox, "
              + "\(s.news.filter { $0.title.hasPrefix("Inbox:") }.count) resolved themselves, \(s.decisions.count) still waiting")
        for a in s.alerts.prefix(10) {
            print("    \(a.date.gameShort) [\(a.kind)\(a.critical ? "!" : "")] \(a.title) — \(a.body)")
        }
        return s
    }

    static func briefingsCheck(_ s: GameState) {
        print("\n== Monthly briefings (newest three of \(s.briefings.count)) ==")
        for b in s.briefings.prefix(3) {
            print("  \(b.month.gameMonth): \(b.headline)")
            print("    revenue \(Fmt.money(b.revenue)) (\(b.revenueChange >= 0 ? "+" : "")\(Fmt.pct(b.revenueChange, decimals: 1)) per day) · profit \(Fmt.money(b.profit)) · cash \(Fmt.money(b.cash))"
                  + (b.runway.map { " · runway \(Fmt.trim($0, 1)) mo" } ?? ""))
            for (label, lines) in [("why", b.drivers), ("rivals", b.rivals), ("risks", b.risks), ("do", b.actions)] where !lines.isEmpty {
                for l in lines { print("    \(label): \(l.good.map { $0 ? "▲" : "▼" } ?? "·") \(l.text)") }
            }
        }
    }

    /// Every fix the Chief of Staff offers, clicked on a copy of the game: does it work, and does the problem go away?
    static func fixesCheck(year: Double) {
        print("\n== Chief of Staff fixes, clicked ==")
        var tally: [String: (ok: Int, failed: Int, cleared: Int)] = [:]
        var errors: [String] = []
        for seed in [31, 32, 33] as [UInt64] {
            var (s, _) = choresLab(year: year, seed: seed)
            for day in 0..<400 {
                Sim.advanceDay(&s)
                for d in s.decisions where Alerts.isUrgent(d) { s.resolveDecision(d.id, option: 0) }
                s.gameOver = nil
                guard day % 40 == 0 else { continue }
                let pools = Economy.pools(s)
                for item in Advisor.items(s, pools: pools) {
                    guard let fix = item.fix else { continue }
                    if case .openDecision = fix { continue }
                    let kind = String(describing: fix).components(separatedBy: "(").first ?? "?"
                    var t = s
                    var row = tally[kind] ?? (0, 0, 0)
                    if let e = Advisor.apply(&t, fix) {
                        row.failed += 1
                        if errors.count < 8 { errors.append("\(kind) on \"\(item.title)\": \(e)") }
                    } else {
                        row.ok += 1
                        Sim.advanceDay(&t)
                        if !Advisor.items(t, pools: Economy.pools(t)).contains(where: { $0.id == item.id }) { row.cleared += 1 }
                    }
                    tally[kind] = row
                }
            }
        }
        for (k, v) in tally.sorted(by: { $0.key < $1.key }) {
            print("  \(k): applied \(v.ok), failed \(v.failed), problem gone next day \(v.cleared)/\(v.ok)")
        }
        for e in errors { print("    error: \(e)") }
    }
}
