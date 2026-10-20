import Foundation

/// The board of directors: it sets goals, pays milestone tranches when you hit them and loses faith when you don't.
/// Below 50% ownership a board that has lost confidence can move to replace you.
enum Board {
    static let activeTarget = 3
    /// 3.4: from this year goals scale with the lab's share of its market, so a 2030s giant isn't asked to double
    /// a market it already dominates. Earlier goals are exactly as before.
    static let lateYear = 2027.0

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

    // MARK: Objectives

    static func value(_ k: ObjectiveKind, _ s: GameState) -> Double {
        switch k {
        case .revenue: return Economy.runRate(s)
        case .index: return s.releasedModels.map(\.index).max() ?? 0
        case .rank:
            let board = Leaderboard.entries(s, includeUnreleased: false)
            guard let me = board.filter(\.isPlayer).max(by: { $0.index < $1.index }) else { return 99 }
            return Double(Leaderboard.labRank(index: me.index, board: board, gone: Leaderboard.goneLabs(s)))
        case .users: return s.consumerUsers
        case .valuation: return s.valuation
        case .profit: return s.history.last?.profit ?? -1
        case .compute: return Economy.h100e(s)
        case .safety: return s.safetyScore
        case .research: return Double(s.researched.count + s.programLevelsTotal)
        case .agents: return s.swarms.filter { !$0.paused }.reduce(0) { $0 + $1.active }
        // Your best released model's Intelligence Index: a release goal asks you to beat it.
        case .release: return s.models.filter(\.released).map(\.index).max() ?? 0
        case .chipSales: return s.chipLines.reduce(0) { $0 + $1.revenue } + s.history.suffix(1200).reduce(0) { $0 + $1.revCloud }
        }
    }

    static func lowerIsBetter(_ k: ObjectiveKind) -> Bool { k == .rank }

    /// Release goals from older saves (no bar) still count releases.
    static func isLegacyRelease(_ o: Objective) -> Bool { o.kind == .release && o.bar <= 0 }

    static func met(_ o: Objective, _ s: GameState) -> Bool {
        if isLegacyRelease(o) { return Double(s.models.filter(\.released).count) >= o.target }
        let v = value(o.kind, s)
        return lowerIsBetter(o.kind) ? v <= o.target : v >= o.target
    }

    static func progress(_ o: Objective, _ s: GameState) -> Double {
        if isLegacyRelease(o) { return met(o, s) ? 1 : 0 }
        let v = value(o.kind, s)
        if lowerIsBetter(o.kind) {
            guard o.start > o.target else { return 1 }
            return clamp((o.start - v) / (o.start - o.target), 0, 1)
        }
        if o.kind == .profit { return v >= 0 ? 1 : clamp(1 - v / min(-1, o.start), 0, 1) }
        guard o.target > o.start else { return 1 }
        return clamp((v - o.start) / (o.target - o.start), 0, 1)
    }

    static func tranche(_ s: GameState) -> Double {
        let last = s.rounds.last(where: { $0.name != "IPO" })?.amount ?? 1e6
        // 3.8: a tranche follows the company too (0.05% of valuation), or a $3T lab was paid $200K for a goal worth billions.
        return clamp(max(last * 0.08, s.valuation * 0.0005), 1e5, 6e9)
    }

    /// How hard a goal is (0.25–1.5): how far it asks you to move against a typical ask of its kind.
    /// Tranches scale with it, so goals you'd hit anyway pay less.
    static func difficulty(_ k: ObjectiveKind, start: Double, target: Double) -> Double {
        // Growth goals: how many "typical" multiples the target is above where you are.
        func growth(_ typical: Double) -> Double {
            log(max(target, 1e-9) / max(start, target / 20, 1e-9)) / log(typical)
        }
        let d: Double
        switch k {
        case .revenue: d = growth(1.9)
        case .users, .valuation: d = growth(2.1)
        case .compute: d = 0.7 * growth(2.8)            // money buys it
        case .agents: d = 0.6 * growth(5)
        case .index: d = (target - start) / 6.5
        case .safety: d = 0.8 * (target - start) / 11
        case .research: d = 0.5 * (target - start) / 5.5
        case .release: d = 0.5 * (target - start) / 2
        case .rank: d = target <= 3 ? 1.3 : 1.0
        case .profit: d = 1
        case .chipSales: d = 0.8
        }
        return clamp(d, 0.25, 1.5)
    }

    /// A fresh goal the board would plausibly set right now.
    static func make(_ k: ObjectiveKind, _ s: inout GameState) -> Objective? {
        let y = s.year
        let now = value(k, s)
        let months: Int
        let target: Double
        let title: String
        let detail: String
        var points = 1
        switch k {
        case .revenue:
            // Scale the floor to the company: a seed-stage lab isn't asked for a frontier lab's revenue.
            let stage = clamp(s.valuation / Macro.frontierValuation(y) * 10, 0.05, 1)
            var mult = s.rng.range(1.6, 2.2)
            if y >= lateYear { mult = 1 + (mult - 1) * clamp((0.5 - now / max(1, Macro.marketSize(y))) / 0.4, 0.2, 1) }
            target = max(now * mult, Macro.marketSize(y) * 0.0008 * stage)
            months = 12
            title = "Reach a \(Fmt.money(target)) revenue run-rate"
            detail = "Investors want proof of a business. API, chat, agents, enterprise, chips and labor all count."
            points = 2
        case .index:
            // Near the top of the index a few more points may not exist: ask for something else.
            guard !s.models.isEmpty, now < 85 else { return nil }
            target = min(99, now + s.rng.range(4, 9))
            months = 12
            title = "Release a model scoring \(Fmt.score(target)) on the Intelligence Index"
            detail = "The board wants you closer to the frontier."
        case .rank:
            guard !s.releasedModels.isEmpty, now > 3 else { return nil }
            target = now > 5 ? 5 : 3
            months = 15
            title = target <= 3 ? "Be a top-3 lab on the leaderboard" : "Break into the top 5 labs"
            detail = "Rank among labs, by each lab's best released model."
            points = 2
        case .users:
            guard s.chatModelID != nil, now > 10_000 else { return nil }
            var mult = s.rng.range(1.8, 2.5)
            if y >= lateYear { mult = 1 + (mult - 1) * clamp((0.6 - now / max(1, Macro.chatUsers(y, chatMoment: s.chatMoment))) / 0.5, 0.15, 1) }
            target = now * mult
            months = 12
            title = "Grow chat to \(Fmt.count(target)) users"
            detail = "Consumer momentum drives the next round."
        case .valuation:
            guard s.valuation > 0 else { return nil }
            var mult = s.rng.range(1.8, 2.4)
            if y >= lateYear { mult = 1 + (mult - 1) * clamp(2 * Macro.frontierValuation(y) / s.valuation, 0.25, 1) }
            target = s.valuation * mult
            months = 18
            title = "Be worth \(Fmt.money(target))"
            detail = "Double the company's value."
            points = 2
        case .profit:
            guard (s.history.last?.profit ?? 1) < 0, s.history.count >= 6 else { return nil }
            target = 0
            months = 10
            title = "Post a profitable month"
            detail = "Show the board the model works without fresh capital."
            points = 2
        case .compute:
            var mult = s.rng.range(2.2, 3.5)
            if y >= lateYear { mult = 1 + (mult - 1) * clamp((0.3 - now / max(1, CompetitorCatalog.industryCompute(y))) / 0.25, 0.15, 1) }
            target = max(now * mult, 50)
            months = 12
            title = "Control \(Fmt.count(target)) H100-equivalents"
            detail = "Owned or rented. Compute is the moat."
        case .safety:
            guard now < 88 else { return nil }
            target = min(95, now + s.rng.range(8, 14))
            months = 9
            title = "Raise your safety score to \(Int(target))"
            detail = "Enterprise buyers and regulators are asking questions."
        case .research:
            target = now + Double(s.rng.int(4, 7))
            months = 8
            title = "Complete \(Int(target - now)) more research projects"
            detail = y >= lateYear ? "Keep the research engine running. New techniques and frontier-programme levels both count." : "Keep the research engine running."
        case .agents:
            guard s.bonuses.has(.toolUse), !s.models.isEmpty else { return nil }
            target = max(1_000, now * (y >= lateYear && now > 1e6 ? 2.5 : 5))
            months = 9
            title = "Run \(Fmt.count(target)) agents at once"
            detail = "Agent swarms are the story investors want to hear."
        case .release:
            // A real step forward: beat your best released model by 2+ index points (as scored today).
            target = now + 2
            months = 6
            title = now > 0 ? "Ship a model scoring \(Fmt.score(target)) on the Intelligence Index" : "Ship your first model"
            detail = now > 0 ? "Beat your best released model by at least 2 points — a preview or a small fine-tune won't do."
                             : "Put a model in front of customers."
        case .chipSales:
            guard !s.customChips.isEmpty || s.owned.reduce(0, { $0 + $1.count }) > 500 else { return nil }
            target = now + max(5e6, y >= lateYear ? max(Economy.hardwareRunRate(s) * 1.5, Economy.runRate(s) * 0.08) : Economy.runRate(s) * 0.3)
            months = 12
            title = "Earn \(Fmt.money(target - now)) selling compute"
            detail = "Lease idle chips or sell your own silicon."
        }
        var o = Objective(kind: k, title: title, detail: detail, start: now, target: target, issued: s.date,
                          deadline: GameCalendar.addMonths(s.date, months),
                          rewardCash: min(6e9, tranche(s) * difficulty(k, start: now, target: target)), rewardPoints: points,
                          rewardConfidence: 8 + Double(points) * 3)
        if k == .release { o.bar = target }
        return o
    }

    /// Keep three goals on the table.
    static func refill(_ s: inout GameState) {
        var tries = 0
        while s.objectives.filter({ !$0.done && !$0.failed }).count < activeTarget && tries < 24 {
            tries += 1
            let active = Set(s.objectives.filter { !$0.done && !$0.failed }.map(\.kind))
            let options = ObjectiveKind.allCases.filter { !active.contains($0) }
            guard !options.isEmpty else { break }
            let k = s.rng.pick(options)
            if let o = make(k, &s), !met(o, s) { s.objectives.append(o) }
        }
        // Keep the history short.
        let closed = s.objectives.filter { $0.done || $0.failed }
        if closed.count > 12 {
            let drop = Set(closed.prefix(closed.count - 12).map(\.id))
            s.objectives.removeAll { drop.contains($0.id) }
        }
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
        for i in s.objectives.indices where !s.objectives[i].done && !s.objectives[i].failed {
            let o = s.objectives[i]
            s.objectives[i].progress = progress(o, s)
            if met(o, s) {
                s.objectives[i].done = true
                s.objectivesCompleted += 1
                if s.objectivesCompleted >= 5 { Achievements.unlock(&s, "board_favorite") }
                s.cash += o.rewardCash
                s.month.oneOffIncome += o.rewardCash
                s.culturePoints += o.rewardPoints
                s.boardConfidence = clamp(s.boardConfidence + o.rewardConfidence, 0, 100)
                Sim.news(&s, "Board goal met: \(o.title)", "Investors release a \(Fmt.money(o.rewardCash)) milestone tranche. +\(o.rewardPoints) culture point\(o.rewardPoints == 1 ? "" : "s"), board confidence up.",
                         .finance, image: "sf_skyline", important: true, good: true)
            } else if s.date > o.deadline {
                s.objectives[i].failed = true
                s.objectivesFailed += 1
                // 3.8: a goal set long ago was set for a smaller company, and a near miss isn't a failure.
                let span = GameCalendar.daysBetween(o.issued, o.deadline)
                let hit = (span > 300 ? 5.0 : span > 240 ? 7.0 : 10.0) * (o.progress >= 0.7 ? 0.6 : 1)
                s.boardConfidence = clamp(s.boardConfidence - hit, 0, 100)
                Sim.news(&s, "Missed a board goal: \(o.title)", "The deadline passed. Board confidence falls \(Int(hit.rounded())) points.", .finance, important: true, good: false)
            }
        }
        refill(&s)
        let target = confidenceTarget(s)
        s.boardConfidence = clamp(s.boardConfidence + (target - s.boardConfidence) * 0.08 + t.confidence, 0, 100)
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

    static let rerollCooldownDays = 60

    /// When the board will next agree to swap a goal (nil if it would today).
    var rerollReadyOn: Date? {
        guard let last = lastObjectiveReroll else { return nil }
        let ready = GameCalendar.addDays(last, GameState.rerollCooldownDays)
        return ready > date ? ready : nil
    }

    /// Ask the board for a different goal. Costs a little confidence, and the board agrees once every 60 days.
    mutating func rerollObjective(_ id: UUID) -> String? {
        guard let i = objectives.firstIndex(where: { $0.id == id && !$0.done && !$0.failed }) else { return "Not found." }
        if let ready = rerollReadyOn { return "The board just rewrote a goal for you — ask again after \(ready.gameShort)." }
        if boardConfidence < 10 { return "The board won't renegotiate right now." }
        objectives.remove(at: i)
        boardConfidence = max(0, boardConfidence - 4)
        lastObjectiveReroll = date
        Board.refill(&self)
        return nil
    }
}
