import Foundation

/// 3.9: headless checks for endings and legacy. `--endings-check [save…]` exercises every arc on copies of the saves;
/// `--replay-save <save> <days> endings [retire]` prints the arcs as a real save plays (see ReplayHarness).
enum EndingsHarness {
    nonisolated(unsafe) private static var shown = Set<String>()

    /// Every day of a replay: new endings decisions, with their options and inbox default.
    static func watch(_ s: GameState) {
        for d in s.decisions where d.kind.hasPrefix(Endings.prefix) && !shown.contains(d.id.uuidString) {
            shown.insert(d.id.uuidString)
            print("    ENDINGS DECISION \(s.date.gameShort) [\(d.kind)] \(d.title)\n      \(d.body)")
            for (i, o) in d.options.enumerated() { print("      \(i)\(i == Alerts.inboxDefault(d, s) ? "*" : " ") \(o.label) — \(o.detail)") }
        }
    }

    /// Every 30 days of a replay.
    static func line(_ s: GameState) -> String {
        let t = s.endings.treaty
        return "    ENDINGS: compact stage \(t.stage) stance \(t.stance) share \(Fmt.pct(t.share, decimals: 0)) · concern \(Int(s.world.concern)) · friction \(Int(s.endings.friction)) (target \(Int(Endings.frictionTarget(s)))) stage \(s.endings.stateStage)\(s.endings.goldenShare ? " golden" : "")"
            + " · out of race \(s.endings.irrelevant) · near misses \(s.endings.nearMisses.count) · rank \(s.progression.rank) lead \(Fmt.trim(Endings.frontierLead(s), 2)) · chronicle \(s.endings.chronicle.count) · score \(Endings.score(s, nil).total) · retire now → \(Endings.retirement(s).title)"
    }

    /// End of a replay: the chronicle, the endings in reach and (with `retire`) the epilogue.
    static func summary(_ s: inout GameState, retire: Bool) {
        print("ENDINGS chronicle (\(s.endings.chronicle.count) entries):")
        for c in s.endings.chronicle { print("  \(c.date.gameShort) [\(c.kind)] \(c.title)\(c.detail.isEmpty ? "" : " — \(c.detail)")") }
        print("ENDINGS in reach:")
        for r in Endings.reach(s) { print("  \(r.kind.title): \(r.progress.map { Fmt.pct($0, decimals: 0) } ?? "-") · \(r.status)") }
        if retire && s.gameOver == nil { print("retire: \(Endings.retire(&s) ?? "ok")") }
        guard s.gameOver != nil else { return }
        epilogue(s)
    }

    static func epilogue(_ s: GameState) {
        let k = Endings.classify(s)
        let sc = Endings.score(s, k)
        print("EPILOGUE: \(k.title) — \(k.tagline)")
        print("  game over: \(s.gameOver ?? "")")
        for p in Endings.story(s, k) { print("  \(p)") }
        print("  people: " + Endings.people(s, k).map { "\($0.name) (\($0.role)) \($0.fate)" }.joined(separator: "; "))
        let tl = Endings.timeline(s)
        print("  timeline: \(tl.count) moments; first \(tl.prefix(3).map { "\($0.date.gameShort) \($0.title)" }.joined(separator: " | ")); last \(tl.suffix(3).map { "\($0.date.gameShort) \($0.title)" }.joined(separator: " | "))")
        print("  score: " + sc.lines.map { "\($0.label) \($0.points)" }.joined(separator: ", ") + " = \(sc.total) (\(Endings.grade(sc.total).title)); stamped \(s.endings.finalScore)")
        var v = LegacyVault()
        print("  unlocks: \(v.note(s).map(\.title)) · slots now \(v.slots)")
    }

    // MARK: --endings-check

    static func load(_ path: String) -> GameState? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), var s = try? SaveCoding.decoder().decode(GameState.self, from: data) else { return nil }
        StableID.resume(s)
        SaveMigration.migrate(&s)
        BenchmarkCatalog.resetCache()
        HardwareCatalog.register(s.customChips)
        return s
    }

    /// Plays days, answering endings decisions with `pick` (by kind) and everything else with the inbox default or the
    /// first option, as the save check does. Returns the endings decisions seen.
    @discardableResult
    static func play(_ s: inout GameState, days: Int, pick: [String: Int] = [:], log: Bool = true) -> [String] {
        var seen: [String] = []
        for _ in 0..<days where s.gameOver == nil {
            for _ in 0..<10 {
                guard let d = s.decisions.first else { break }
                var o = Alerts.isUrgent(d) ? 0 : Alerts.inboxDefault(d, s)
                if d.kind == "acquisition" { o = d.options.count - 1 }   // turn takeovers down, as the save check does
                if d.kind == "victory" { o = 0 }   // keep building
                if d.kind.hasPrefix(Endings.prefix) {
                    seen.append(d.kind)
                    if log { print("    \(s.date.gameShort) decision \(d.kind): \(d.title) → \(d.options[pick[d.kind] ?? o].label)") }
                    o = pick[d.kind] ?? o
                }
                s.resolveDecision(d.id, option: o)
            }
            Sim.advanceDay(&s)
        }
        return seen
    }

    static func main(_ args: [String]) -> Int32 {
        var failures = 0
        func expect(_ what: String, _ ok: Bool, _ detail: String = "") {
            print("\(ok ? "ok  " : "FAIL") \(what)\(detail.isEmpty ? "" : " — \(detail)")")
            if !ok { failures += 1 }
        }

        // 1. Classification of every game over the game already had.
        var g = NewGame.create(NewGameSettings(), seed: 7)
        let causes: [(String, EndingKind)] = [
            ("Bankrupt on 1 Jan 2025. Creditors seized the hardware.", .bankrupt),
            ("Loss of control on 1 Jan 2025. X copied itself out.", .lossOfControl),
            ("The board voted you out as CEO on 1 Jan 2025.", .ousted),
            ("You stepped down as CEO on 1 Jan 2025, keeping your 30% stake.", .steppedDown),
            ("Acquired for $4B on 1 Jan 2025. Your stake: $1B.", .acquired),
            ("You retired on 1 Jan 2025 after achieving Aligned Superintelligence. Legacy score 9000.", .alignedAGI),
            ("You retired on 1 Jan 2025 after achieving Guardian of the Transition. Legacy score 9000.", .guardian),
            ("You retired on 1 Jan 2025 after achieving Trillion-Dollar Empire. Legacy score 9000.", .empire),
            ("You retired on 1 Jan 2025 after achieving Alien Tech Mastery. Legacy score 9000.", .xeno),
        ]
        for (text, want) in causes {
            var t = g
            t.gameOver = text
            expect("classify \"\(text.prefix(40))…\"", Endings.classify(t) == want, Endings.classify(t).title)
        }
        expect("legacy lines add up to Victory.legacyScore (new game)", Endings.score(g, nil).legacy == Victory.legacyScore(g), "\(Endings.score(g, nil).legacy) vs \(Victory.legacyScore(g))")

        // 2. Perks: one-off grants that leave the world untouched.
        var withPerks = NewGameSettings()
        withPerks.legacyPerks = LegacyPerk.allCases.map(\.rawValue)
        let p = NewGame.create(withPerks, seed: 7)
        expect("perks recorded on the save", p.endings.perks.count == LegacyPerk.allCases.count)
        expect("perks: veteran hires", p.employees.count == g.employees.count + 2, "\(g.employees.count) → \(p.employees.count)")
        expect("perks: old money +25% cash", abs(p.cash - g.cash * 1.25) < 1, "\(Fmt.money(g.cash)) → \(Fmt.money(p.cash))")
        expect("perks: political capital", p.politicalCapital >= 25, "\(Int(p.politicalCapital))")
        expect("perks: security level 2", p.security == .sl2)
        expect("perks: notebooks", p.researchQueue.prefix(2).allSatisfy { (p.researchProgress[$0] ?? 0) > 0 })
        expect("perks don't change the world", p.competitors.map(\.valuation) == g.competitors.map(\.valuation) && p.rng.state == g.rng.state,
               "rivals \(p.competitors.count)")
        expect("slots", Legacy.slots(endings: 1) == 1 && Legacy.slots(endings: 3) == 2 && Legacy.slots(endings: 7) == 3)

        // 3. Retiring too early is refused; a new game never ends on its own in its first two years with inbox defaults.
        expect("retire refused in year one", Endings.retire(&g) != nil && g.gameOver == nil)

        for path in args {
            guard let base = load(path) else { print("FAILED to load \(path)"); failures += 1; continue }
            print("== \(path.split(separator: "/").last ?? "") · \(base.companyName) \(base.date.gameShort) · stage \(base.progression.stage) rank \(base.progression.rank) · concern \(Int(base.world.concern)) · safety \(Int(base.safetyScore)) · PC \(Int(base.politicalCapital))")
            expect("legacy lines add up (save)", Endings.score(base, nil).legacy == Victory.legacyScore(base))

            // a. A year on inbox defaults: no ending of this system's fires on its own.
            var a = base
            let seen = play(&a, days: 365, log: true)
            expect("a year on inbox defaults keeps the game going", a.gameOver == nil || a.endings.pending.isEmpty, a.gameOver ?? "running")
            print("    after a year: \(line(a)) · decisions seen \(seen)")
            print("    chronicle: " + a.endings.chronicle.map { "\($0.date.gameShort) \($0.title)" }.joined(separator: " | "))

            // b. Retire after a month: the epilogue.
            var b = base
            play(&b, days: 31, log: false)
            if GameCalendar.daysBetween(b.startDate, b.date) >= Endings.minDaysToRetire {
                expect("retire", Endings.retire(&b) == nil && b.gameOver != nil && !b.endings.ending.isEmpty, b.endings.ending)
                epilogue(b)
            }

            // c. A near miss with a good safety record: the step-back offer, then the averted ending.
            var c = base
            c.safetyScore = max(c.safetyScore, 70)
            let fake = Decision(kind: "rsi_exfil", title: "", body: "", image: nil, options: [], date: c.date)
            Endings.decided(&c, fake, option: 0)
            expect("near miss recorded", c.endings.nearMisses.count == base.endings.nearMisses.count + 1 && c.endings.avertedDue != nil)
            play(&c, days: 22, pick: ["end_averted": 1])
            expect("averted ending when chosen", c.endings.ending == EndingKind.averted.rawValue, c.gameOver ?? "running")

            // d. The Compact, joined with the safety coalition (needs 2026.5+ and a top-ten model).
            if base.year >= 2026.5 {
                var d = base
                d.world.concern = max(d.world.concern, 60)
                let ds = play(&d, days: 520, pick: ["end_treaty_invite": 0, "end_treaty_draft": 0, "end_treaty": 1], log: true)
                let t = d.endings.treaty
                print("    compact: stage \(t.stage) invited \(t.invited) stance \(t.stance) share \(Fmt.pct(t.share, decimals: 1)) shaped \(t.shaped) · decisions \(ds)")
                expect("compact talks open and conclude", t.stage >= 1)
                if t.shaped && t.stance > 0 { expect("treaty ending when chosen", d.endings.ending == EndingKind.treaty.rawValue, d.gameOver ?? "running") }
            }

            // e. State pressure on a frontier lab: the natural target, then the chain held at high pressure — refuse, fight, hand over.
            if Progression.has(base, .frontierLab) && base.year >= 2025 {
                var e = base
                print("    state: natural pressure target \(Int(Endings.frictionTarget(e))) (concern \(Int(e.world.concern)), home standing \(Int(Endings.homeStanding(e))), lead \(Fmt.trim(Endings.frontierLead(e), 2)), thefts \(e.thefts), safety \(Int(e.safetyScore)))")
                var es: [String] = []
                for _ in 0..<14 where e.gameOver == nil {
                    e.endings.friction = max(e.endings.friction, 95)
                    ScenarioHarness.fund(&e, atLeast: 1e9)
                    es += play(&e, days: 31, pick: ["end_state_golden": 2, "end_state_emergency": 0, "end_state_ultimatum": 1], log: true)
                }
                print("    state: friction \(Int(e.endings.friction)) stage \(e.endings.stateStage) golden \(e.endings.goldenShare) · decisions \(es) · \(e.gameOver ?? "running")")
                expect("golden share asked under pressure", es.contains("end_state_golden"))
                expect("emergency powers after six months of refusal", es.contains("end_state_emergency"))
                if e.gameOver != nil, !e.endings.pending.isEmpty { expect("nationalised only by choice", e.endings.ending == EndingKind.nationalised.rawValue && e.exitValue != nil, e.gameOver ?? "") }
            }
        }

        // f. Out of the race: a lab that never shipped, four years in, with 17 months logged; one more month brings the offer.
        var f = NewGame.create(NewGameSettings(), seed: 11)
        f.startDate = GameCalendar.addMonths(f.date, -48)
        play(&f, days: 40, log: false)
        f.endings.irrelevant = 17
        let fs = play(&f, days: 40, pick: ["end_outcompeted": 1], log: true)
        expect("outcompeted offer arrives", fs.contains("end_outcompeted"), "out \(f.endings.irrelevant) rank \(f.progression.rank) api \(Fmt.pct(f.apiShareNow))")
        expect("outcompeted ending when chosen", f.endings.ending == EndingKind.outcompeted.rawValue && f.exitValue != nil, f.gameOver ?? "")
        if f.gameOver != nil { epilogue(f) }
        print(failures == 0 ? "ENDINGS CHECK OK" : "ENDINGS CHECK: \(failures) failure(s)")
        return failures == 0 ? 0 : 1
    }
}
