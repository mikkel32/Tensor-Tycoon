import Foundation

/// 3.9: replay hooks for hype (`--replay-save <save> <days> hype:…`, report lines with REPLAY_HYPE=1).
///  hype:tease · hype:booth · hype:rehearse · hype:meter:<n> · hype:pricing:<premium|match|undercut>
///  hype:event:<launch|devDay>:<livestream|pressEvent|arena>:<days>[:<segment>,<segment>…]
enum HypeHarness {
    nonisolated(unsafe) private static var seen = Set<String>()

    nonisolated(unsafe) private static var later: [(Int, String)] = []

    /// Arguments with "@<day>" run on that day of the replay.
    static func tick(_ s: inout GameState, day: Int) {
        for (d, t) in later where d == day { print("day \(day): \(t)"); arg(&s, t) }
    }

    static func arg(_ s: inout GameState, _ t: String) {
        if let at = t.lastIndex(of: "@"), let day = Int(t[t.index(after: at)...]) {
            later.append((day, String(t[..<at])))
            return
        }
        let p = t.split(separator: ":").map(String.init)
        switch p.count > 1 ? p[1] : "" {
        case "tease": print("hype tease: \(s.postTeaser() ?? "ok") → meter \(Fmt.trim(s.hype.meter, 1))")
        case "booth": print("hype booth: \(s.bookRecruitingBooth() ?? "ok") (\(s.hype.booth))")
        case "rehearse": print("hype rehearse: \(s.rehearseStage() ?? "ok")")
        case "meter" where p.count == 3: s.hype.ready = true; s.hype.meter = Double(p[2]) ?? s.hype.meter; print("hype meter set to \(Fmt.trim(s.hype.meter, 1))")
        case "pricing" where p.count == 3: if let x = PricingStance(rawValue: p[2]) { s.setStagePricing(x); print("hype pricing \(x.rawValue)") }
        case "event" where p.count >= 5:
            guard let k = StageKind(rawValue: p[2]), let f = StageFormat(rawValue: p[3]) else { print("hype event: unknown kind or format"); return }
            print("hype event: \(s.announceStageEvent(k, format: f, days: Int(p[4]) ?? 30) ?? "ok")")
            if p.count >= 6 {
                let segs = p[5].split(separator: ",").compactMap { StageSegment(rawValue: String($0)) }
                print("hype segments \(segs.map(\.rawValue)): \(s.setStageSegments(segs) ?? "ok")")
            }
            if let e = s.hype.event { print("hype event on \(e.date.gameShort): \(e.kind.rawValue) \(e.format.rawValue) [\(e.segments.map(\.rawValue).joined(separator: ", "))] cost \(Fmt.money(e.cost))") }
        case "launch":
            // The best unreleased model, launched as the Models screen does (default plan).
            guard let m = s.models.filter({ !$0.released && !$0.retired }).max(by: { $0.index < $1.index }) else { print("hype launch: nothing unreleased"); return }
            print("hype launch \(m.name): \(s.launch(m.id, plan: LaunchPlan()) ?? "ok") (hype was \(Fmt.trim(s.hype.launches.first?.hype ?? s.hype.meter, 1)))")
        default: print("unknown \(t)")
        }
    }

    /// One line a week, plus every new show, viral moment and hype launch as it happens.
    static func report(_ s: GameState) {
        let (_, _, d) = GameCalendar.components(s.date)
        if d % 7 == 2 {
            let e = s.hype.event.map { " · \($0.kind.rawValue) \($0.format.rawValue) in \(GameCalendar.daysBetween(s.date, $0.date))d [\($0.segments.map(\.rawValue).joined(separator: ","))] rehearsals \($0.rehearsals)" } ?? ""
            print("    HYPE viral odds this week \(Fmt.pct(Viral.odds(s))) · HYPE \(Fmt.trim(s.hype.meter, 1)) (\(Hype.mood(s.hype.meter)), rest \(Fmt.trim(Hype.rest(s), 1))) · launch boost now +\(Int((Hype.boostNow(s) * 100).rounded()))% · prestige \(Fmt.trim(s.hype.prestige, 1)) · brand \(Fmt.trim(s.brand, 1)) · users \(Fmt.count(s.consumerUsers))\(e)")
        }
        for dr in s.hype.drivers where dr.date == s.date && !seen.contains("d|\(dr.date.timeIntervalSince1970)|\(dr.text)") {
            seen.insert("d|\(dr.date.timeIntervalSince1970)|\(dr.text)")
            print("    HYPE \(dr.amount >= 0 ? "+" : "")\(Fmt.trim(dr.amount, 1)): \(dr.text)")
        }
        for sh in s.hype.shows where !seen.contains(sh.id.uuidString) {
            seen.insert(sh.id.uuidString)
            print("    SHOW \(sh.headline) · \(Fmt.count(sh.viewers)) viewers · hype \(Fmt.trim(sh.hypeBefore, 1)) → \(Fmt.trim(sh.hypeAfter, 1))")
            for b in sh.beats { print("      \(b.clock) [\(b.tone >= 0 ? "+" : "")\(Fmt.trim(b.tone, 2))] \(b.text)") }
        }
        for v in s.hype.viral where !seen.contains(v.id.uuidString) {
            seen.insert(v.id.uuidString)
            print("    VIRAL \(v.positive ? "+" : "-") \(v.title) \(v.hashtag) · \(Fmt.count(v.views)) views · hype \(Fmt.trim(v.hypeDelta, 1)) brand \(Fmt.trim(v.brandDelta, 1))")
        }
        for l in s.hype.launches where !seen.contains("l|\(l.modelID.uuidString)") {
            seen.insert("l|\(l.modelID.uuidString)")
            print("    HYPE LAUNCH \(l.model): hype \(Fmt.trim(l.hype, 1)) delivered \(Fmt.trim(l.delivered, 0)) → day-one boost +\(Int((l.boost * 100).rounded()))% \(l.verdict) show \(Int(l.showScore))")
        }
        for n in s.news where n.date == s.date && (n.title.contains("applicants") || n.title.contains("booth") || n.title.contains("Launch report") || n.title.hasPrefix("Backlash") || n.title.contains("Best paper") || n.title.contains("accepts")) {
            guard !seen.contains("n|\(n.id.uuidString)") else { continue }
            seen.insert("n|\(n.id.uuidString)")
            print("    NEWS \(n.title) — \(n.body)")
        }
    }

    static func summary(_ s: GameState) {
        print("HYPE SUMMARY: meter \(Fmt.trim(s.hype.meter, 1)) · prestige \(Fmt.trim(s.hype.prestige, 1)) · shows \(s.hype.shows.count) · viral \(s.hype.viral.count) (\(s.hype.viral.filter(\.positive).count) good) · launches \(s.hype.launches.count) · candidates drawn \(s.hype.hires) · booths \(s.hype.boothsRun)")
        let mine = s.pulse.filter { $0.labs.contains("player") }.prefix(6)
        for p in mine { print("  FEED \(p.date.gameShort) \(p.handle): \(p.text) (♥ \(Fmt.count(Double(p.likes))))") }
        for l in s.launches.suffix(3) {
            if let r = l.report { print("  LAUNCH REPORT \(l.modelName): sign-ups \(Fmt.count(r.signUps)) · press tone \(Fmt.trim(r.pressTone, 2)) · verdict \(r.verdict)") }
        }
    }
}
