import Foundation

/// `TensorTycoon --scenarios [A,B,…|all]`: the expansion's representative playthroughs (goal part 26) as scripted
/// games with checks. Each scenario starts a game, plays it with the playtest bot plus the scripted steps a player
/// would take for that strategy, and checks what should have happened in the simulation (not merely that the code
/// ran): money moved where it should, systems produced their effects, nothing went NaN or negative, and the books add
/// up. Exits 1 when any check fails.
///
/// One file per scenario (ScenarioA.swift …) so each can grow on its own.
enum ScenarioHarness {
    struct Check {
        let name: String
        let ok: Bool
        let detail: String
    }

    struct Report {
        var id: String
        var title: String
        var checks: [Check] = []
        var notes: [String] = []
        /// Not written yet: reported, but neither a pass nor a failure.
        var pending = false

        mutating func expect(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
            checks.append(Check(name: name, ok: ok, detail: detail()))
        }

        mutating func note(_ text: String) { notes.append(text) }

        var failed: [Check] { checks.filter { !$0.ok } }
    }

    static let all: [(id: String, title: String, run: () -> Report)] = [
        ("A", "Denmark: research business, datacenters, partnerships, abroad", scenarioA),
        ("B", "Romania: efficient specialists, profit, international capital", scenarioB),
        ("C", "Italy: industrial AI, robotics, manufacturing partners", scenarioC),
        ("D", "France: scientific lab, research funding, sovereign work", scenarioD),
        ("E", "Frontier breakthrough: giant cluster, major run, launch, reactions", scenarioE),
        ("F", "Classified research: programme lifecycle and permitted uses", scenarioF),
        ("G", "Custom semiconductor: design, prototype, scale, deploy, sell", scenarioG),
        ("H", "Technology empire: subsidiaries, families, orgs, silicon at scale", scenarioH),
    ]

    static func main(_ args: [String]) -> Int32 {
        let want = Set((args.first ?? "all").uppercased().split(separator: ",").map(String.init))
        let picked = all.filter { want.contains("ALL") || want.contains($0.id) }
        var failures = 0, pending = 0
        for sc in picked {
            let start = Date()
            let r = sc.run()
            let secs = Date().timeIntervalSince(start)
            if r.pending {
                pending += 1
                print("PENDING \(sc.id) · \(sc.title)")
                continue
            }
            let bad = r.failed
            failures += bad.count
            print("\(bad.isEmpty ? "PASS" : "FAIL") \(sc.id) · \(sc.title) · \(r.checks.count - bad.count)/\(r.checks.count) checks · \(Fmt.trim(secs, 1)) s")
            for n in r.notes { print("    · \(n)") }
            for c in r.checks { print("    \(c.ok ? "✓" : "✗") \(c.name)\(c.detail.isEmpty ? "" : ": \(c.detail)")") }
        }
        print(failures == 0 ? "OK: \(picked.count - pending) scenarios passed\(pending > 0 ? ", \(pending) pending" : "")" : "FAILED: \(failures) checks")
        return failures == 0 ? 0 : 1
    }

    // MARK: Shared steps

    /// A new game as the menu would create it.
    static func newGame(era: String, hq: String = "us", city: String = "", seed: UInt64, name: String = "Scenario Labs") -> GameState {
        var settings = NewGameSettings()
        settings.companyName = name
        settings.founderName = "Scenario"
        settings.eraID = era
        settings.hqCountry = hq
        settings.hqCity = city
        return NewGame.create(settings, seed: seed)
    }

    /// Plays `days` with the playtest bot making the everyday calls (training, releases, serving, hiring, money).
    static func play(_ s: inout GameState, _ bot: inout PTBot, days: Int) {
        for _ in 0..<days {
            Sim.advanceDay(&s)
            PTPlay.resolve(&s, &bot)
            if s.gameOver != nil { return }
            PTPlay.act(&s, &bot)
        }
    }

    /// Simulates `days` with nobody acting, answering decisions with their default (first) option.
    static func idle(_ s: inout GameState, days: Int) {
        for _ in 0..<days where s.gameOver == nil {
            for _ in 0..<10 {
                guard let d = s.decisions.first else { break }
                s.resolveDecision(d.id, option: d.kind == "acquisition" ? d.options.count - 1 : 0)
            }
            Sim.advanceDay(&s)
        }
    }

    /// Puts a synthetic harness company at `stage`: its setup skipped the years of play that would have earned it.
    static func setStage(_ s: inout GameState, _ stage: CompanyStage) {
        Progression.bootstrap(&s)
        guard s.progression.current < stage else { return }
        for v in (s.progression.stage + 1)...stage.rawValue {
            s.progression.reached[v] = s.date
            s.progression.credited.insert(v)
        }
        s.progression.stage = stage.rawValue
    }

    /// Tops cash up to `floor` as new equity, so a scenario can keep playing without leaving the books unexplained.
    static func fund(_ s: inout GameState, atLeast floor: Double) {
        let add = floor - s.cash
        guard add > 0 else { return }
        s.cash += add
        Books.post(&s, .equity, add)
    }

    /// Checks every scenario makes: the game is still running and its numbers are finite.
    static func sanity(_ s: GameState, _ r: inout Report) {
        r.expect("game still running", s.gameOver == nil, s.gameOver ?? "")
        r.expect("cash and valuation finite", s.cash.isFinite && s.valuation.isFinite, "cash \(s.cash), valuation \(s.valuation)")
        r.expect("models finite", s.models.allSatisfy { $0.c.isFinite && $0.index.isFinite })
        r.expect("rival books finite", s.competitors.allSatisfy { $0.cash.isFinite && $0.valuation.isFinite })
        // 3.8: the last closed month's cash is fully explained by its income statement, capex and categorised flows.
        if let last = s.history.last, let res = Books.residual(s) {
            r.expect("books reconcile", abs(res) <= Books.tolerance(last.cashEnd), "\(Fmt.money(res)) of cash unexplained in \(last.month.gameMonth)")
        }
    }

    static func pending(_ id: String) -> Report {
        var r = Report(id: id, title: all.first { $0.id == id }?.title ?? id)
        r.pending = true
        return r
    }
}
