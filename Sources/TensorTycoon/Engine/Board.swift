import Foundation

/// The board of directors: its confidence follows growth, your place against the frontier and runway, and prices your
/// rounds. 3.10: it no longer sets goals to chase. Below 50% ownership a board that has lost confidence can move to
/// replace you.
enum Board {
    // MARK: Confidence

    /// Fundraising price multiplier from board and investor confidence (0.85–1.15).
    static func valuationFactor(_ s: GameState) -> Double {
        0.85 + 0.3 * clamp(s.boardConfidence, 0, 100) / 100
    }

    static func mood(_ c: Double) -> String {
        switch c {
        case 80...: "Euphoric"
        case 60..<80: "Confident"
        case 40..<60: "Watchful"
        case 20..<40: "Restless"
        default: "Mutinous"
        }
    }

    /// Where confidence drifts on its own: growth, leadership and runway.
    static func confidenceTarget(_ s: GameState) -> Double {
        var t = 50.0
        if s.history.count >= 4 {
            let now = s.history.last!.revenue
            let then = s.history[s.history.count - 4].revenue
            if then > 0 { t += clamp((now / then - 1) * 40, -15, 20) }
        }
        let best = s.releasedModels.map(\.c).max() ?? -10
        t += clamp((best - Macro.frontier(s.year) + 0.6) * 15, -12, 15)
        if let months = Treasury.runwayMonths(s) {
            if months < 3 { t -= 15 } else if months < 6 { t -= 6 }
        } else if !s.history.isEmpty {
            t += 6
        }
        if s.cash < 0 { t -= 15 }
        return clamp(t, 5, 95)
    }

    // MARK: Milestone tranche

    /// A milestone payment at the company's size (Arena prizes pay from it).
    static func tranche(_ s: GameState) -> Double {
        let last = s.rounds.last(where: { $0.name != "IPO" })?.amount ?? 1e6
        // 3.8: a tranche follows the company too (0.05% of valuation), or a $3T lab was paid $200K for a goal worth billions.
        return clamp(max(last * 0.08, s.valuation * 0.0005), 1e5, 6e9)
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        let t = s.traits
        // Founding anniversary: a culture point a year.
        let start = GameCalendar.components(s.startDate)
        let today = GameCalendar.components(s.date)
        if today.month == start.month && today.year > start.year {
            s.culturePoints += 1
            Sim.news(&s, "\(today.year - start.year) years of \(s.companyName)", "The team celebrates another year. +1 culture point to spend on Strategy & Traits.",
                     .company, image: "sf_skyline", good: true)
        }
        if s.isPublicProgram {
            PublicProgram.monthly(&s)
            return
        }
        let target = confidenceTarget(s)
        s.boardConfidence = clamp(s.boardConfidence + (target - s.boardConfidence) * 0.08 + t.confidence, 0, 100)
        if s.boardConfidence >= 80 { Achievements.unlock(&s, "board_favorite") }
        ousterCheck(&s)
    }

    static func ousterCheck(_ s: inout GameState) {
        guard s.boardConfidence < 20, !s.founderControls, s.gameOver == nil else { return }
        if let last = s.lastBoardThreat, GameCalendar.daysBetween(last, s.date) < 180 { return }
        guard s.rng.chance(0.35) else { return }
        s.lastBoardThreat = s.date
        Events.addDecision(&s, kind: "board_ouster", title: "⚠️ The board is moving to replace you",
                           body: "With confidence at \(Int(s.boardConfidence))/100 and only \(Fmt.pct(s.founderStake)) of the shares, the directors have called an emergency meeting about the CEO role.",
                           image: "stock_exchange",
                           options: [DecisionOption(label: "Give up board seats", detail: "Hand 15% of your shares to investors as a settlement. Confidence resets to 45."),
                                     DecisionOption(label: "Make your case", detail: "\(Int(ousterSurvival(s) * 100))% chance they back you (confidence → 55). Otherwise you're out."),
                                     DecisionOption(label: "Step down", detail: "Leave on your own terms and keep your shares.")])
    }

    static func ousterSurvival(_ s: GameState) -> Double {
        clamp(0.35 + s.boardConfidence / 100 + s.brand / 400 + Double(s.objectivesCompleted) * 0.02, 0.2, 0.85)
    }
}

// MARK: - Player actions

extension GameState {
    mutating func adoptPerk(_ id: String) -> String? {
        guard let p = CultureCatalog.byID[id] else { return "Unknown perk." }
        if perks.contains(id) { return "Already part of your culture." }
        if p.tier > 1, let prev = CultureCatalog.all.first(where: { $0.branch == p.branch && $0.tier == p.tier - 1 }), !perks.contains(prev.id) {
            return "Adopt \(prev.name) first."
        }
        if culturePoints < p.cost { return "\(p.name) costs \(p.cost) culture point\(p.cost == 1 ? "" : "s"); you have \(culturePoints)." }
        culturePoints -= p.cost
        perks.insert(id)
        if p.tier == 4 { Achievements.unlock(&self, "culture") }
        Sim.news(&self, "New culture: \(p.name)", "\(p.effect). It's how things are done at \(companyName) now.", .company, good: true)
        return nil
    }
}
