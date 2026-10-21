import Foundation

/// 3.9: headless checks for dramatic events.
///
///   TensorTycoon --drama [years]            bot games in 2017, 2022 and 2026 (three seeds each): events a year, kinds,
///                                           answers; then every event fired and every answer taken on the 2026 game.
///   --replay-save <save> <days> drama       print each dramatic event as it fires and resolves (with the replay).
///   --replay-save <save> 0 drama:all        fire every event the save allows and take every answer, on copies.
///   --replay-save <save> <days> drama:fire:<id>   fire one event now (ignores cooldowns), then play on.
enum DramaHarness {
    nonisolated(unsafe) static var on = false
    nonisolated(unsafe) private static var shown: [UUID: String] = [:]

    /// Replay arguments; true when `t` was one of ours.
    static func arg(_ t: String, _ s: inout GameState) -> Bool {
        guard t.hasPrefix("drama") else { return false }
        on = true
        if t == "drama:all" { _ = probe(s, label: "save") }
        if t == "drama:list" { list(s) }
        if t.hasPrefix("drama:fire:") {
            let id = String(t.dropFirst("drama:fire:".count))
            let fired = StableID.drawing { Drama.fireOne(&s, only: id) }
            print(fired.map { "DRAMA fired \($0) by hand" } ?? "DRAMA could not fire \(id) (not eligible in this save)")
        }
        return true
    }

    static func list(_ s: GameState) {
        print("DRAMA eligible now (weight · cooldown left):")
        for d in Drama.catalog {
            let w = d.weight(s)
            let cool = s.drama.fired[d.id].map { max(0, d.cooldownDays - GameCalendar.daysBetween($0, s.date)) } ?? 0
            print("  \(d.id.padding(toLength: 14, withPad: " ", startingAt: 0)) \(w > 0 ? Fmt.trim(w, 2) : "–")\(cool > 0 ? " · \(cool)d" : "")")
        }
    }

    /// Prints records that are new or changed since the last call (one line when an event fires, one when it resolves).
    static func report(_ s: GameState) {
        guard on else { return }
        for r in s.drama.log.reversed() {
            let key = "\(r.choice)|\(r.outcome)"
            guard shown[r.id] != key else { continue }
            if shown[r.id] == nil {
                print("    DRAMA \(s.date.gameShort) FIRED [\(r.event)] \(r.title) — \(r.summary)")
                if let d = s.decisions.first(where: { $0.id == r.decision }) {
                    for (i, o) in d.options.enumerated() {
                        print("      option \(i)\(i == Alerts.inboxDefault(d, s) ? " (inbox default)" : ""): \(o.label) — \(o.detail)\(Drama.blocker(d, i, s).map { " [blocked: \($0)]" } ?? "")")
                    }
                }
            }
            if !r.choice.isEmpty {
                print("    DRAMA \(s.date.gameShort) \(r.defaulted ? "DEFAULTED" : "ANSWERED") [\(r.event)] \"\(r.choice)\" → \(r.tone) · \(r.outcome)")
            }
            shown[r.id] = key
        }
    }

    /// Fires every event `s` allows on a copy and takes every answer on copies of that. Checks the inbox default exists,
    /// costs nothing and is never blocked, and that every answer resolves. Returns the number of problems.
    static func probe(_ s: GameState, label: String) -> Int {
        var problems = 0, fired = 0
        print("DRAMA probe on \(label) (\(s.date.gameShort), cash \(Fmt.money(s.cash)), \(s.employees.count) staff, \(s.sites.count) sites):")
        for def in Drama.catalog {
            var t = s
            t.decisions.removeAll()
            guard def.weight(t) > 0 else { print("  \(def.id): not eligible here"); continue }
            let before = (cash: t.cash, chips: t.owned.reduce(0) { $0 + $1.count }, brand: t.brand)
            StableID.drawing { _ = Drama.fireOne(&t, only: def.id) }
            guard let d = t.decisions.first(where: { $0.kind == Drama.prefix + def.id }) else {
                print("  \(def.id): eligible but posted nothing"); problems += 1; continue
            }
            fired += 1
            let safe = Alerts.inboxDefault(d, t)
            if Alerts.isUrgent(d) { print("  PROBLEM \(def.id): would pause the game (not an inbox decision)"); problems += 1 }
            if safe != def.safe || Drama.cost(d, safe) != nil { print("  PROBLEM \(def.id): the inbox default (\(safe)) spends cash"); problems += 1 }
            if !d.options.indices.contains(def.safe) { print("  PROBLEM \(def.id): no option \(def.safe)"); problems += 1 }
            if ImageCredits.byID[def.image] == nil { print("  PROBLEM \(def.id): photo \(def.image) has no credit"); problems += 1 }
            let chips = t.owned.reduce(0) { $0 + $1.count }
            print("  \(def.id): \"\(d.title)\" · on fire: cash \(Fmt.money(t.cash - before.cash)), chips \(chips - before.chips), brand \(Fmt.trim(t.brand - before.brand, 1))")
            for o in d.options.indices {
                var u = t
                StableID.drawing { u.resolveDecision(d.id, option: o) }
                let rec = u.drama.log.first { $0.decision == d.id }
                let blocked = Drama.blocker(d, o, t).map { " [blocked: \($0)]" } ?? ""
                print("      \(o)\(o == safe ? "*" : " ") \(d.options[o].label)\(blocked) → \(rec?.tone ?? .mixed): \(rec?.outcome ?? "?") (cash \(Fmt.money(u.cash - t.cash)))")
                if u.decisions.contains(where: { $0.id == d.id }) { print("  PROBLEM \(def.id): option \(o) left the decision open"); problems += 1 }
            }
        }
        print("DRAMA probe: \(fired) events fired, \(problems) problem\(problems == 1 ? "" : "s")")
        return problems
    }

    /// `--drama [years]`: pacing across eras and seeds, then the full probe on the last 2026 game.
    static func main(_ a: [String]) -> Int32 {
        let years = a.first.flatMap(Double.init) ?? 4
        StableID.alwaysDraw = true
        print("== Dramatic events: \(Fmt.trim(years, 1)) years per game, playtest bot ==")
        var last: GameState? = nil
        var problems = 0
        for era in ["2017", "2022", "2026"] {
            var counts: [String: Int] = [:]
            var total = 0, answered = 0
            for seed: UInt64 in [1, 2, 3] {
                _ = PTPlay.play(era: era, seed: seed, years: years, mode: "silent", flags: [])
                guard let s = PTPlay.lastState else { continue }
                total += s.drama.count
                answered += s.drama.answered
                for r in s.drama.log { counts[r.event, default: 0] += 1 }
                let gaps = zip(s.drama.log.dropFirst(), s.drama.log).map { GameCalendar.daysBetween($0.date, $1.date) }
                if let g = gaps.min(), g < Drama.gapDays { print("  PROBLEM: two events \(g) days apart"); problems += 1 }
                last = s
            }
            let perYear = Double(total) / 3 / years
            print("  \(era): \(total) events in 3 games (\(Fmt.trim(perYear, 1)) a year per game), \(answered) answered · "
                  + counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
            if perYear > 5 { print("  PROBLEM: too many events a year"); problems += 1 }
        }
        if let s = last { problems += probe(s, label: "the last 2026 bot game") }
        print(problems == 0 ? "  OK" : "  FAILED: \(problems) problem\(problems == 1 ? "" : "s")")
        return problems == 0 ? 0 : 1
    }
}
