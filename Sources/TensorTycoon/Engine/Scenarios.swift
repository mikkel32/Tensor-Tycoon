import Foundation

/// 3.5: challenge mode. A scenario is an ordinary game with a goal, a deadline and a score: it starts from a curated
/// setup (era, doctrine, founder, a twist), checks its goal every day (rankings on the first of the month) and ends with
/// a summary — after which the game simply carries on as a sandbox.
enum Scenarios {
    /// What "Survive the 2027 Crash" asks you to be worth when it ends.
    static let crashTarget = 500e9

    static func def(_ s: GameState) -> ScenarioDef? { FunCatalog.scenarioByID[s.fun.scenarioID] }

    /// New-game settings for a scenario, keeping the player's names and logo.
    static func settings(_ d: ScenarioDef, from base: NewGameSettings) -> NewGameSettings {
        var g = base
        g.eraID = d.era
        g.doctrine = d.doctrine
        g.background = d.background
        g.difficulty = d.difficulty
        g.locationID = d.location
        return g
    }

    /// Turns a freshly created game into the scenario.
    static func apply(_ s: inout GameState, _ d: ScenarioDef) {
        s.fun.scenarioID = d.id
        s.fun.scenarioStartValue = s.valuation
        if d.cash > 1 {
            let grant = s.cash * (d.cash - 1)
            s.cash += grant
            Sim.news(&s, "A sovereign fund backs \(s.companyName)", "\(Fmt.money(grant)) of national money on top of your seed round. The condition: the weights stay at home.",
                     .finance, image: "stock_exchange", important: true, good: true)
        }
        if d.doctrine == .open { s.publication = .open }
        Sim.news(&s, "Challenge: \(d.title)", "\(d.goal) Deadline: \(d.deadline.gameShort). You lose if: \(Cast.lowerFirst(d.lose))",
                 .company, image: d.image, important: true, good: true)
    }

    // MARK: Daily

    static func daily(_ s: inout GameState, firstOfMonth: Bool) {
        guard let d = def(s) else { return }
        scripted(&s, d)
        if let why = lost(s, d) {
            finish(&s, d, won: false, why: why)
        } else if won(s, d, rankings: firstOfMonth) {
            finish(&s, d, won: true, why: d.goal)
        } else if s.date >= d.deadline {
            finish(&s, d, won: false, why: d.id == "crash" ? "Worth \(Fmt.money(s.valuation)) on \(d.deadline.gameShort), short of \(Fmt.money(crashTarget))."
                                                          : "Time ran out on \(d.deadline.gameShort).")
        }
    }

    /// Scripted moments some scenarios promise.
    static func scripted(_ s: inout GameState, _ d: ScenarioDef) {
        guard d.id == "crash", !s.fun.scripted.contains("crash"), s.date >= GameCalendar.date(2027, 4, 1) else { return }
        s.fun.scripted.insert("crash")
        let before = s.competitors.filter { !$0.acquired }.reduce(0) { $0 + $1.valuation }
        s.market.hype *= 0.65
        s.correctionUntil = GameCalendar.addDays(s.date, 300)
        s.lastCorrection = s.date
        s.market.hardwarePrice = max(0.5, s.market.hardwarePrice - 0.08)
        s.market.rentPrice = max(0.5, s.market.rentPrice - 0.08)
        for i in s.competitors.indices where !s.competitors[i].acquired { s.competitors[i].valuation *= 0.65 }
        Voices.correction(&s, wiped: before * 0.35, title: "The crash of 2027: \(Fmt.money(before * 0.35)) wiped off AI valuations",
                          body: "It came all at once: a big lab missed its revenue numbers, a datacenter lender froze and every fund tried to sell on the same morning. Rounds are smaller and some labs won't make it — but chips and cloud just got cheaper.")
    }

    static func won(_ s: GameState, _ d: ScenarioDef, rankings: Bool) -> Bool {
        switch d.id {
        case "garage_gpt": return s.achievements.contains("chat_moment")
        case "speedrun": return s.monthsAtTop >= 12
        case "safety_frontier": return s.monthsAtTop >= 6 && s.safetyScore >= 75
        case "open_insurgent": return rankings && Fun.playerRank(s, openOnly: true) <= 3
        case "bootstrapped": return Economy.runRate(s) >= 10e9 && s.history.count >= 2
        case "crash": return s.date >= d.deadline && s.valuation >= crashTarget
        case "sovereign": return s.monthsAtTop >= 3
        case "alien_race": return !s.alienArchs.isEmpty
        default: return false
        }
    }

    /// Why the scenario is lost now, or nil.
    static func lost(_ s: GameState, _ d: ScenarioDef) -> String? {
        switch d.id {
        case "garage_gpt":
            if s.chatMoment != nil && !s.achievements.contains("chat_moment") { return "Another lab's chatbot started the boom first." }
        case "safety_frontier", "sovereign":
            if s.thefts > 0 { return "A model's weights were stolen." }
        case "open_insurgent":
            if s.publication == .secret { return "You went Secretive." }
        case "bootstrapped":
            if s.rounds.count > 1 || s.isPublic { return "You took outside money." }
        case "crash":
            if s.daysNegativeCash >= 55 { return "The money ran out." }
        case "alien_race":
            if s.alienArchs.isEmpty, let first = s.rivalXeno.min(by: { $0.value < $1.value }) {
                return "\(CompetitorCatalog.def(first.key).name) found an alien architecture first."
            }
        default: break
        }
        return nil
    }

    /// How close you are, 0–1, for the progress bar (nil where there's nothing sensible to show).
    static func progress(_ s: GameState, rank: Int? = nil) -> Double? {
        guard let d = def(s) else { return nil }
        if let o = s.fun.scenarioOutcome { return o.won ? 1 : nil }
        switch d.id {
        case "garage_gpt": return clamp((s.releasedModels.map(\.c).max() ?? 0) / 4.1, 0, 0.99)
        case "speedrun", "safety_frontier", "sovereign":
            // Halfway for reaching #1, the rest for holding it.
            let need = d.id == "speedrun" ? 12.0 : (d.id == "sovereign" ? 3.0 : 6.0)
            let r = rank ?? Fun.playerRank(s)
            let byRank = s.monthsAtTop > 0 ? 0.5 + 0.5 * min(1, Double(s.monthsAtTop) / need) : (r >= 99 ? 0 : 0.5 / Double(r))
            return d.id == "safety_frontier" ? min(byRank, clamp(s.safetyScore / 75, 0, 1)) : byRank
        case "open_insurgent":
            let r = Fun.playerRank(s, openOnly: true)
            return r >= 99 ? 0 : min(1, 3 / Double(r))
        case "bootstrapped": return clamp(Economy.runRate(s) / 10e9, 0, 1)
        case "crash": return clamp(s.valuation / crashTarget, 0, 1)
        default: return nil
        }
    }

    static func score(_ s: GameState, _ d: ScenarioDef, won: Bool) -> Int {
        let left = max(0, GameCalendar.daysBetween(s.date, d.deadline))
        let value = max(1, s.valuation)
        let growth = s.fun.scenarioStartValue > 0 ? log10(max(1, value / s.fun.scenarioStartValue)) : 0
        if won { return 1000 + 2 * left + Int(150 * growth) + Int(s.brand * 2) }
        return Int(400 * (progress(s) ?? 0)) + Int(60 * growth)
    }

    static func finish(_ s: inout GameState, _ d: ScenarioDef, won: Bool, why: String) {
        let score = score(s, d, won: won)
        let days = GameCalendar.daysBetween(s.startDate, s.date)
        let summary = won
            ? "\(d.goal) Done in \(days / 365) years and \(days % 365 / 30) months, \(max(0, GameCalendar.daysBetween(s.date, d.deadline))) days before the deadline."
            : why
        s.fun.scenarioOutcome = ScenarioOutcome(won: won, date: s.date, score: score, summary: summary)
        if won {
            Achievements.unlock(&s, "scenario_win")
            Sim.news(&s, "🏁 Challenge complete: \(d.title)", "\(summary) Score: \(score). Play on as long as you like.",
                     .company, image: d.image, important: true, good: true)
            Fun.post(&s, "fun.scenario", labs: ["player"], vars: ["goal": d.goal], key: "scenario|\(d.id)", importance: 0.6, count: 2)
        } else {
            Sim.news(&s, "Challenge over: \(d.title)", "\(why) Score: \(score). The company carries on; the challenge doesn't.",
                     .company, image: d.image, important: true, good: false)
        }
        Alerts.raise(&s, .milestone, key: "scenario|\(d.id)", title: won ? "Challenge complete: \(d.title)" : "Challenge failed: \(d.title)",
                     body: "Score \(score). See the summary on the Events & Records page.", screen: .events, celebrate: won, cooldown: 0)
    }
}
