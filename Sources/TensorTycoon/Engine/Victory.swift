import Foundation

/// Long-term ways to win. Reaching one lets you retire as a legend — or keep going for more.
enum VictoryPath: String, CaseIterable, Identifiable, Sendable {
    case superintelligence, empire, dominance, guardian, xeno, publicService
    var id: String { rawValue }

    var title: String {
        switch self {
        case .superintelligence: "Aligned Superintelligence"
        case .empire: "Trillion-Dollar Empire"
        case .dominance: "Market Dominance"
        case .guardian: "Guardian of the Transition"
        case .xeno: "Alien Tech Mastery"
        case .publicService: "Public AI Service"
        }
    }

    var symbol: String {
        switch self {
        case .superintelligence: "infinity"
        case .empire: "crown.fill"
        case .dominance: "trophy.fill"
        case .guardian: "checkmark.shield.fill"
        case .xeno: "atom"
        case .publicService: "building.columns.fill"
        }
    }

    var goal: String {
        switch self {
        case .superintelligence: "Release a model 1.5 capability beyond the frontier with safety 80+."
        case .empire: "Reach a $10T valuation, or $1T of personal net worth (after 2030 the bar rises with what frontier labs are worth)."
        case .dominance: "Hold the #1 model for 24 months in a row while taking 40% of the API market."
        case .guardian: "Keep a safety score of 95+ with a top-3 model for 12 months in a row."
        case .xeno: "Discover three alien architectures and ship a million alien chips."
        case .publicService: "Build a level-4 National AI Service with 12 delivered missions, oversight 75+ and safety 70+."
        }
    }
}

enum Victory {
    /// 3.4: after 2030 the empire bar grows with frontier-lab valuations, so it stays an achievement rather than
    /// something any surviving lab reaches. 1 until 2030.
    static func empireScale(_ y: Double) -> Double { max(1, Macro.frontierValuation(y) / Macro.frontierValuation(2030)) }

    static func available(_ s: GameState) -> [VictoryPath] {
        VictoryPath.allCases.filter { s.isPublicProgram ? $0 != .empire : $0 != .publicService }
    }

    static func progress(_ v: VictoryPath, _ s: GameState) -> Double {
        switch v {
        case .superintelligence:
            guard let m = s.releasedModels.max(by: { $0.c < $1.c }) else { return 0 }
            let lead = clamp((m.c - Macro.frontier(s.year) + 0.5) / 2.0, 0, 1)
            return lead * (m.safety >= 80 ? 1 : 0.7)
        case .empire:
            guard !s.isPublicProgram else { return 0 }
            let k = empireScale(s.year)
            return clamp(max(s.valuation / (1e13 * k), s.founderNetWorth / (1e12 * k)), 0, 1)
        case .dominance:
            return clamp(Double(s.monthsAtTop) / 24, 0, 1) * (s.month.revAPI > 0 ? 1 : 0.5)
        case .guardian:
            return clamp(Double(s.monthsGuardian) / 12, 0, 1)
        case .xeno:
            // Alien Tech Mastery: discoveries, and either flooding the world with alien chips or completing Contact.
            let alienShipped = s.chipLines.filter { ChipBusiness.isAlien($0.chipID, s) }.reduce(0) { $0 + $1.shipped }
            let reach = XenoScience.megaDone(s, "contact") ? 1 : clamp(alienShipped / 1e6, 0, 1)
            return clamp(Double(XenoScience.discoveries(s)) / 4, 0, 1) * 0.5 + reach * 0.5
        case .publicService:
            guard s.isPublicProgram else { return 0 }
            let p = s.publicProgram
            return clamp(Double(p.level) / 4, 0, 1) * 0.25
                + clamp(Double(p.completedMissions) / 12, 0, 1) * 0.35
                + clamp(p.oversight / 75, 0, 1) * 0.2
                + clamp(s.safetyScore / 70, 0, 1) * 0.2
        }
    }

    static func achieved(_ v: VictoryPath, _ s: GameState) -> Bool {
        switch v {
        case .superintelligence:
            return s.releasedModels.contains { $0.c >= Macro.frontier(s.year) + 1.5 && $0.safety >= 80 }
        case .empire:
            guard !s.isPublicProgram else { return false }
            // Held for three month-ends, not a one-month spike.
            let recent = s.history.suffix(3).map(\.valuation)
            guard recent.count == 3, let low = recent.min() else { return false }
            let k = empireScale(s.year)
            return min(low, s.valuation) >= 1e13 * k || s.founderStake * min(low, s.valuation) + s.founderCash >= 1e12 * k
        case .dominance:
            return s.monthsAtTop >= 24 && s.apiShareNow >= 0.4
        case .guardian:
            return s.monthsGuardian >= 12
        case .xeno:
            return progress(.xeno, s) >= 0.999
        case .publicService:
            let p = s.publicProgram
            return s.isPublicProgram && p.level >= 4 && p.completedMissions >= 12 && p.oversight >= 75 && s.safetyScore >= 70
        }
    }

    /// A single number for how well you did.
    static func legacyScore(_ s: GameState) -> Int {
        var score = 0.0
        if s.isPublicProgram {
            score += Double(s.publicProgram.completedMissions) * 140
            score += Double(s.publicProgram.level) * 400
            score += s.publicProgram.oversight * 5
            score += s.world.publicTrust * 2
            score -= Double(s.publicProgram.failedMissions) * 40
        } else {
            score += 10 * log10(1 + max(0, s.founderNetWorth) / 1e6) * 10
        }
        score += Double(s.achievements.count) * 40
        score += Double(s.victories.count) * 1_000
        score += (s.models.map(\.index).max() ?? 0) * 8
        score += Double(s.objectivesCompleted) * 25
        // 3.4: late-game legacy — moonshots achieved and frontier research pushed further.
        score += Double(Moonshots.succeeded(s)) * 150
        score += Double(min(s.programLevelsTotal, 250)) * 4
        score += s.safetyScore * 3
        score -= Double(s.thefts) * 60
        if s.gameOver != nil && s.exitValue == nil && !s.keptStake { score *= 0.6 }
        return max(0, Int(score))
    }

    static func monthly(_ s: inout GameState) {
        // Streaks
        let board = Leaderboard.entries(s, includeUnreleased: false)
        let top = board.max { $0.index < $1.index }
        s.monthsAtTop = top?.isPlayer == true ? s.monthsAtTop + 1 : 0
        s.apiShareNow = Market.snapshot(s).api.filter(\.isPlayer).reduce(0) { $0 + $1.share }
        let myBest = board.filter(\.isPlayer).max { $0.index < $1.index }
        let rank = myBest.map { Leaderboard.labRank(index: $0.index, board: board, gone: Leaderboard.goneLabs(s)) } ?? 99
        s.monthsGuardian = (s.safetyScore >= 95 && rank <= 3) ? s.monthsGuardian + 1 : 0

        for v in available(s) where !s.victories.contains(v.rawValue) && achieved(v, s) {
            s.victories.insert(v.rawValue)
            s.culturePoints += 3
            Achievements.unlock(&s, "victory")
            Events.addDecision(&s, kind: "victory", title: "🏆 Victory: \(v.title)",
                               body: "\(v.goal) You did it. History will remember \(s.companyName). Legacy score so far: \(legacyScore(s)).",
                               image: "sf_skyline",
                               options: [DecisionOption(label: "Keep building", detail: "Play on for the other victories. +3 culture points."),
                                         DecisionOption(label: "Retire as a legend", detail: "End the game here with your legacy score.")],
                               ref: v.rawValue)
        }
    }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard option == 1, let v = VictoryPath(rawValue: d.ref) else { return }
        s.keptStake = true
        s.gameOver = "You retired on \(s.date.gameShort) after achieving \(v.title). Legacy score \(legacyScore(s))."
        Sim.news(&s, "\(s.founderName) retires a legend", s.gameOver!, .company, image: "sf_skyline", important: true, good: true)
    }
}
