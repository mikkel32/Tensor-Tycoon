import Foundation

/// 3.5: records across every game this player has played, kept in the app's preferences (never in a save).
/// The app notes the game in progress whenever it saves; the Events & Records page shows the table.
struct HallRecord: Codable, Hashable {
    var value: Double
    var company: String
    /// What the number means ("$1.2T in Sep 2031", "14 months").
    var detail: String
    /// Which game set it (company + start date), so the same game improving its own record isn't news.
    var game: String
}

struct HallOfFame: Codable {
    /// Record ID → the best so far.
    var records: [String: HallRecord] = [:]
    /// Scenario ID → best score.
    var scenarios: [String: HallRecord] = [:]
    /// Games seen (keys), newest last, capped.
    var games: [String] = []

    static let key = "hallOfFame.v1"

    struct Kind: Identifiable {
        let id: String
        let title: String
        let symbol: String
        /// Lower is better (e.g. days to #1).
        var lowerIsBetter = false
    }

    static let kinds: [Kind] = [
        Kind(id: "valuation", title: "Highest valuation", symbol: "chart.line.uptrend.xyaxis"),
        Kind(id: "revenue", title: "Best year of revenue", symbol: "dollarsign.circle.fill"),
        Kind(id: "fastestNo1", title: "Fastest to #1", symbol: "stopwatch.fill", lowerIsBetter: true),
        Kind(id: "monthsTop", title: "Longest reign at #1", symbol: "crown.fill"),
        Kind(id: "milestones", title: "AI milestones claimed", symbol: "signpost.right.fill"),
        Kind(id: "papers", title: "Papers accepted", symbol: "doc.text.magnifyingglass"),
        Kind(id: "bestPapers", title: "Best-paper awards", symbol: "rosette"),
        Kind(id: "contests", title: "Challenges won", symbol: "trophy.circle.fill"),
        Kind(id: "achievements", title: "Achievements in one game", symbol: "medal.fill"),
    ]

    static func gameKey(_ s: GameState) -> String { "\(s.companyName)|\(Int(s.startDate.timeIntervalSince1970))" }

    /// This game's numbers for each record (nil: nothing to show yet).
    static func values(_ s: GameState) -> [String: (Double, String)] {
        var v: [String: (Double, String)] = [:]
        if s.valuation > 0 { v["valuation"] = (s.valuation, "\(Fmt.money(s.valuation)) in \(s.date.gameMonth)") }
        if let best = s.history.suffix(12).count == 12 ? s.history.suffix(12).reduce(0, { $0 + $1.revenue }) : nil, best > 0 {
            v["revenue"] = (best, "\(Fmt.money(best)) in the year to \(s.date.gameMonth)")
        }
        if let first = s.fun.firstNo1 {
            let days = Double(GameCalendar.daysBetween(s.startDate, first))
            v["fastestNo1"] = (days, "\(Int(days / 30.44)) months (\(first.gameMonth), from \(s.startDate.ym.year))")
        }
        if s.monthsAtTop > 0 { v["monthsTop"] = (Double(s.monthsAtTop), "\(s.monthsAtTop) months in a row") }
        let claimed = s.milestoneWins.filter { $0.labID == "player" }.count
        if claimed > 0 { v["milestones"] = (Double(claimed), "\(claimed) milestones") }
        let accepted = s.fun.papers.filter { $0.outcome == .poster || $0.outcome == .oral || $0.outcome == .best }.count
        if accepted > 0 { v["papers"] = (Double(accepted), "\(accepted) papers") }
        let best = s.fun.papers.filter { $0.outcome == .best }.count
        if best > 0 { v["bestPapers"] = (Double(best), "\(best) awards") }
        let wins = s.fun.contests.filter { $0.standings.first?.lab == "player" }.count
        if wins > 0 { v["contests"] = (Double(wins), "\(wins) wins") }
        if !s.achievements.isEmpty { v["achievements"] = (Double(s.achievements.count), "\(s.achievements.count) of \(AchievementCatalog.all.count)") }
        return v
    }

    /// Folds this game in. Returns the titles of records this game has just taken from another game.
    mutating func note(_ s: GameState) -> [String] {
        let game = Self.gameKey(s)
        if !games.contains(game) {
            games.append(game)
            if games.count > 300 { games.removeFirst(games.count - 300) }
        }
        var broken: [String] = []
        let vals = Self.values(s)
        for k in Self.kinds {
            guard let (value, detail) = vals[k.id] else { continue }
            let old = records[k.id]
            let better = old.map { k.lowerIsBetter ? value < $0.value : value > $0.value } ?? true
            // A record only ever improves (a valuation that falls back keeps its best).
            guard better else { continue }
            if let old, old.game != game { broken.append(k.title) }
            records[k.id] = HallRecord(value: value, company: s.companyName, detail: detail, game: game)
        }
        if let o = s.fun.scenarioOutcome, let d = FunCatalog.scenarioByID[s.fun.scenarioID] {
            let old = scenarios[d.id]
            if old.map({ Double(o.score) > $0.value }) ?? true {
                if let old, old.game != game { broken.append("\(d.title) high score") }
                scenarios[d.id] = HallRecord(value: Double(o.score), company: s.companyName,
                                             detail: "\(o.won ? "Won" : "Lost") in \(o.date.gameMonth)", game: game)
            }
        }
        return broken
    }

    // MARK: Storage (the app only; harnesses never touch it)

    static func load(_ defaults: UserDefaults = .standard) -> HallOfFame {
        guard let data = defaults.data(forKey: key), let h = try? JSONDecoder().decode(HallOfFame.self, from: data) else { return HallOfFame() }
        return h
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    /// Notes the game and saves. Returns a toast for records just broken, or nil.
    static func record(_ s: GameState) -> String? {
        var h = load()
        let broken = h.note(s)
        h.save()
        guard !broken.isEmpty else { return nil }
        return "🏆 New personal record: \(broken.prefix(2).joined(separator: ", "))\(broken.count > 2 ? " and more" : "")"
    }
}
