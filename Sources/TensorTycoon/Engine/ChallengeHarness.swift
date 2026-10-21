import Foundation

/// 3.9: `--challenges calibrate [era] [until]`: play the world forward with an idle player and print, twice a year,
/// what the best rival lab and outside team would score on each grand challenge against its bar, and every edition's
/// result: for setting bars so they fall near their real dates. `--challenges history [era] [until]`: just the results.
enum ChallengeHarness {
    static func main(_ args: [String]) -> Int32 {
        let mode = args.first ?? "calibrate"
        let era = args.count > 1 ? args[1] : "2017"
        let until = args.count > 2 ? Double(args[2]) ?? 2033 : 2033
        var s = NewGame.create(NewGameSettings(companyName: "Idle Labs", founderName: "Idle", eraID: era, difficulty: .normal), seed: 7)
        print("== Grand challenges, idle player, \(era) start → \(Int(until)) ==")
        var lastHalf = -1
        var seen = Set<String>()
        while s.year < until && s.gameOver == nil {
            s.cash = max(s.cash, 1e12)
            for d in s.decisions { s.resolveDecision(d.id, option: Alerts.inboxDefault(d, s)) }
            Sim.advanceDay(&s)
            let half = Int(s.year * 2)
            if mode == "calibrate" && half != lastHalf {
                lastHalf = half
                var line = String(format: "%.1f frontier c %.2f |", s.year, Macro.frontier(s.year))
                for d in ChallengeCatalog.all {
                    let f = GrandChallenges.field(d, s)
                    let lab = f.first { !$0.lab.hasPrefix("outside:") }
                    let out = f.first { $0.lab.hasPrefix("outside:") }
                    line += " \(d.id) \(lab.map { "\(Int($0.score))" } ?? "-")/\(out.map { "\(Int($0.score))" } ?? "-") (bar \(Int(GrandChallenges.currentBar(d, s))))"
                }
                print(line)
            }
            for e in s.challenges.editions where e.status == .done && !seen.contains(e.id) {
                seen.insert(e.id)
                guard let d = e.def else { continue }
                let top = e.standings.prefix(3).map { "\($0.team) \(Fmt.trim($0.score, 1)) (\(d.metricText($0.score, bar: GrandChallenges.barFor(e))))" }.joined(separator: ", ")
                print("  RESULT \(GrandChallenges.label(e)) on \(e.results.gameShort): \(top)\(e.grandBy.isEmpty ? "" : " · GRAND PRIZE: \(GrandChallenges.teamName(e.grandBy, s))")")
            }
        }
        print("claimed: " + s.challenges.claimed.sorted { $0.key < $1.key }.map { "\($0.key) by \($0.value)" }.joined(separator: ", "))
        return 0
    }
}
