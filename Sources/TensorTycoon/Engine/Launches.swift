import Foundation

// MARK: - 3.7: launch strategies and how the world reacts

/// How you put a model into the world, and what happens next. A launch plan is a strategy (blog post, stealth drop,
/// staged rollout, keynote, open weights, enterprise-first, government-first, benchmark-first), a pricing stance and a
/// safety posture. Each moves brand on the day, shapes the model's demand for its first months (a day-one spike that
/// decays, or a slow ramp), sets the press's tone, moves the public, researchers, developers, investors and
/// governments, and queues rivals' answers — with a lag, rolled when they fall due. A week after launch the
/// launch-day report compares what happened with what the plan was for.
///
/// The default plan (blog post, market price, standard system card) is the release the game always had: it changes
/// nothing beyond writing the history and the report.
enum Launches {
    /// Days a launch shapes its model's demand, and its price stance lasts.
    static let window = 150.0
    static let priceDays = 120.0
    static let decisionKind = "launch_followup"
    static let reportTitle = "Launch report: "

    // MARK: Availability and cost

    /// The company stage a strategy needs (Progression unlocks it).
    static func requiredStage(_ st: LaunchStyle) -> CompanyStage? {
        switch st {
        case .enterprise: .startup
        case .government: .frontierLab
        default: nil
        }
    }

    static func available(_ st: LaunchStyle, _ s: GameState) -> Bool {
        requiredStage(st).map { s.progression.current >= $0 } ?? true
    }

    /// An external red team and a full system card.
    static func redTeamCost(_ s: GameState) -> Double { clamp(s.valuation * 0.0002, 100_000, 20_000_000) }

    static func cost(_ p: LaunchPlan, _ s: GameState) -> Double {
        (p.strategy == .keynote ? GameState.keynoteCost(s) : 0) + (p.safety == .thorough ? redTeamCost(s) : 0)
    }

    /// Why this plan can't be used now (nil when it can).
    static func blocker(_ p: LaunchPlan, _ s: GameState) -> String? {
        if let need = requiredStage(p.strategy), s.progression.current < need {
            return "\(p.strategy.title) launches unlock when you become a \(need.title) (Progression)."
        }
        let c = cost(p, s)
        if c > s.cash { return "This launch costs \(Fmt.money(c)) (\(p.strategy == .keynote ? "keynote" : "red team")); you have \(Fmt.money(s.cash))." }
        return nil
    }

    // MARK: Explained effects

    struct Effect: Hashable {
        let label: String
        let text: String
        /// true good for you, false bad, nil mixed.
        let good: Bool?
    }

    /// What a plan will do, line by line, for the model you're about to launch (`rank` is where it would land).
    static func effects(_ p: LaunchPlan, _ s: GameState, rank: Int) -> [Effect] {
        var out: [Effect] = []
        func add(_ l: String, _ t: String, _ g: Bool?) { out.append(Effect(label: l, text: t, good: g)) }
        let top3 = rank <= 3
        let strategyOdds = responseOdds(LaunchPlan(strategy: p.strategy), rank: rank)
        switch p.strategy {
        case .standard:
            add("Demand", "Normal: traffic follows quality, price and brand.", nil)
            add("Brand", "The usual gain for a better model.", nil)
        case .stealth:
            add("Demand", "Starts at 60% and builds to normal over a month.", false)
            add("Brand", "30% of the usual gain. No keynote, no headlines.", false)
            add("Rivals", "Barely notice (5% chance of an answer).", true)
            add("Regulators", "No attention.", true)
        case .staged:
            add("Demand", "Waitlist (45%) for two weeks, paid users (80%) to week five, then a pent-up +25% that fades.", nil)
            add("Safety", "+4 model safety, +2 lab safety; public +1, concern eases.", true)
            add("Brand", "Half the usual gain.", false)
        case .keynote:
            add("Cost", Fmt.money(GameState.keynoteCost(s)), false)
            add("Demand", "Day-one spike of +\(Int(60 * spikeQuality(rank)))% that halves every 18 days.", true)
            add("Brand", "1.6× the usual gain\(top3 ? "; a top-3 model lifts the whole market's hype" : "").", true)
            add("Press", top3 ? "Loud and mostly warm." : "Loud — and harsh if the model disappoints.", top3 ? true : nil)
            add("Rivals", "~\(Int(strategyOdds * 100))% chance the leading rival answers within weeks.", false)
            if top3 { add("Regulators", "Frontier showmanship raises concern and US/EU attention a little.", false) }
        case .openWeights:
            add("Weights", "Published on day one alongside the API.", nil)
            add("Demand", "Developer adoption: +30% API demand that halves every month.", true)
            add("Standing", "Developers +1 and researchers +1 on top of the open-weights effect.", true)
            add("Rivals", "~\(Int(strategyOdds * 100))% chance a rival answers.", false)
            if top3 { add("Regulators", "Security hawks in Washington take note.", false) }
        case .enterprise:
            add("Demand", "Public API at 75% for a month while design partners onboard.", false)
            add("Enterprise", "Enterprise leads 1.8× as likely for 90 days.", true)
            add("Standing", "Investors +3; developers −0.5 (they're waitlisted).", nil)
            add("Brand", "60% of the usual gain.", false)
        case .government:
            add("Demand", "85% for a month while officials get briefed.", false)
            add("Governments", "Home government +4, every other +1.5; your home rules ease slightly.", true)
            add("Sovereign deals", "Offers twice as likely for six months.", true)
            add("Standing", "Researchers −1.5, public −1: critics call it cosy.", false)
            add("Brand", "70% of the usual gain.", false)
        case .blitz:
            add("Brand", top3 ? (rank == 1 ? "+8 on top of the usual gain." : "+2 on top of the usual gain.") : "−7: backlash for charts that don't top the board.", top3)
            add("Demand", top3 ? "A +\(Int(35 * spikeQuality(rank)))% spike from the charts, halving every two weeks." : "A small dip while people pick the evals apart.", top3)
            add("Researchers", top3 ? "+1 for publishing everything." : "−1: contamination doubts.", top3)
            add("Rivals", "~\(Int(strategyOdds * 100))% chance of an answer.", nil)
        }
        switch p.pricing {
        case .match: break
        case .premium:
            add("Price", "List +25% for 120 days: more per token, fewer tokens.", nil)
            add("Standing", "Developers −1, investors +1\(top3 ? "; +1 brand for a premium top-3 model" : "").", nil)
        case .undercut:
            add("Price", "List −25% for 120 days, plus a developer rush (+15% demand, fading over six weeks).", true)
            add("Standing", "Developers +2, investors −1.", nil)
            add("Price war", "The leading rival is ~\(Int(min(0.95, responseOdds(p, rank: rank)) * 100))% likely to cut prices within six weeks.", false)
        }
        switch p.safety {
        case .standard: break
        case .light:
            add("Safety posture", "A short card: +5% buzz, but researchers and the public mark you down\(top3 ? ", concern rises and the EU takes note" : "").", false)
        case .thorough:
            add("Safety posture", "\(Fmt.money(redTeamCost(s))): +3 model safety, public +1.5, researchers +1.5, every government +1\(top3 ? ", concern eases" : "").", true)
        }
        return out
    }

    /// How hot a launch can run for a model at this rank (1 = new #1).
    static func spikeQuality(_ rank: Int) -> Double { rank == 1 ? 1 : (rank <= 3 ? 0.8 : (rank <= 5 ? 0.6 : 0.4)) }

    /// Chance the leading rival answers the launch.
    static func responseOdds(_ p: LaunchPlan, rank: Int) -> Double {
        var o: Double
        switch p.strategy {
        case .standard: o = 0
        case .stealth: o = 0.05
        case .staged: o = 0.1
        case .keynote: o = 0.45
        case .openWeights: o = 0.3
        case .enterprise: o = 0.2
        case .government: o = 0.15
        case .blitz: o = rank <= 3 ? 0.4 : 0.15
        }
        if p.pricing == .undercut { o += 0.35 }
        if p.pricing == .premium { o = max(0, o - 0.05) }
        let r = rank == 1 ? 1.2 : (rank <= 3 ? 1 : (rank <= 5 ? 0.7 : 0.4))
        return clamp(o * r, 0, 0.9)
    }

    /// −1 (hostile) … +1 (glowing): how the press reads the launch.
    static func pressTone(_ p: LaunchPlan, rank: Int, frontier: Bool) -> Double {
        var t = rank == 1 ? 0.6 : (rank <= 3 ? 0.35 : (rank <= 5 ? 0.1 : -0.1))
        switch p.strategy {
        case .keynote: t *= 1.4
        case .blitz: t += rank == 1 ? 0.3 : (rank > 3 ? -0.4 : 0)
        case .stealth: t = 0.15 + t * 0.3
        case .openWeights: t += 0.2
        case .government: t -= 0.15
        case .staged: t += 0.05
        default: break
        }
        if p.pricing == .undercut { t += 0.1 }
        if p.pricing == .premium && rank > 1 { t -= 0.1 }
        if p.safety == .light && frontier { t -= 0.2 }
        if p.safety == .thorough { t += 0.15 }
        return clamp(t, -1, 1)
    }

    // MARK: Demand, price, deals

    /// The launch's demand multiplier `today` (1 outside the window). `consumer` is the chat app's curve.
    static func curve(_ r: LaunchRecord, today: Date, consumer: Bool) -> Double {
        let t = Double(GameCalendar.daysBetween(r.date, today))
        guard t >= 0, t < window else { return 1 }
        let q = spikeQuality(r.rank)
        var f = 1.0
        var spike = 0.0
        var half = 14.0
        switch r.plan.strategy {
        case .standard: break
        case .stealth: f *= 0.6 + 0.4 * min(1, t / 30)
        case .staged: f *= t < 14 ? 0.45 : (t < 35 ? 0.8 : 1 + 0.25 * exp(-(t - 35) / 30))
        case .keynote:
            spike = 0.6 * q
            half = 18
        case .openWeights:
            if !consumer {
                spike = 0.3
                half = 30
            }
        case .enterprise: f *= t < 30 ? (consumer ? 0.85 : 0.75) : (consumer ? 1 : 1 + 0.1 * exp(-(t - 30) / 45))
        case .government: f *= t < 30 ? 0.85 : 1
        case .blitz: spike = r.rank <= 3 ? 0.35 * q : (r.rank > 5 ? -0.1 : 0)
        }
        if let up = r.upstaged, up <= today { spike *= 0.4 }
        f *= 1 + spike * pow(0.5, t / half)
        if r.plan.pricing == .undercut && !consumer { f *= 1 + 0.15 * exp(-t / 45) }
        if r.plan.safety == .light { f *= 1 + 0.05 * exp(-t / 14) }
        if let w = r.secondWave, w <= today {
            f *= 1 + 0.3 * q * pow(0.5, Double(GameCalendar.daysBetween(w, today)) / 14)
        }
        return max(0.2, f)
    }

    /// Launch-driven demand for a model today: 1 for a plain launch, outside the window, or with no launch at all.
    static func demandFactor(_ s: GameState, _ modelID: UUID?, consumer: Bool = false) -> Double {
        guard let modelID, !s.launches.isEmpty else { return 1 }
        for r in s.launches.reversed() {
            if Double(GameCalendar.daysBetween(r.date, s.date)) >= window { break }
            guard r.modelID == modelID else { continue }
            if r.plan.isDefault && r.secondWave == nil { return 1 }
            return curve(r, today: s.date, consumer: consumer)
        }
        return 1
    }

    /// The pricing stance's multiplier on a model's list price during its launch window (1 otherwise).
    static func priceFactor(_ s: GameState, _ modelID: UUID) -> Double {
        guard !s.launches.isEmpty else { return 1 }
        for r in s.launches.reversed() {
            if Double(GameCalendar.daysBetween(r.date, s.date)) >= window { break }
            guard r.modelID == modelID else { continue }
            return Double(GameCalendar.daysBetween(r.date, s.date)) < priceDays ? r.plan.pricing.priceFactor : 1
        }
        return 1
    }

    /// Enterprise leads: an enterprise-first launch in the last 90 days, and the Startup stage's sales desk.
    static func dealFactor(_ s: GameState) -> Double {
        var f = Progression.has(s, .startup) ? 1.15 : 1
        if s.launches.contains(where: { $0.plan.strategy == .enterprise && GameCalendar.daysBetween($0.date, s.date) < 90 }) { f *= 1.8 }
        return f
    }

    /// Sovereign offers: a government-first launch in the last 180 days, and the Frontier Lab stage's sovereign desk.
    static func sovereignBoost(_ s: GameState) -> Double {
        var f = Progression.has(s, .frontierLab) ? 1.4 : 1
        if s.launches.contains(where: { $0.plan.strategy == .government && GameCalendar.daysBetween($0.date, s.date) < 180 }) { f *= 2 }
        return f
    }

    // MARK: On the day

    /// Brand gain after the plan's pricing and safety posture (the strategy is applied by `release`).
    static func adjustGain(_ gain: Double, _ p: LaunchPlan, rank: Int) -> Double {
        var g = gain
        if p.pricing == .premium && rank <= 3 && g > 0 { g += 1 }
        if p.safety == .light && g > 0 { g *= 1.1 }
        return g
    }

    /// Called by `release` once the model is out: records the launch, applies the plan's day-one effects (price,
    /// standing, world) and queues rivals' answers. A default plan only records.
    static func launched(_ s: inout GameState, _ i: Int, plan p: LaunchPlan, rank: Int, previousBest: Double?, gain: Double,
                         cost: Double, by: String) {
        let m = s.models[i]
        var r = LaunchRecord(modelID: m.id, modelName: m.name, date: s.date, plan: p, rank: rank, index: m.index,
                             previousBest: previousBest, brandGain: gain, cost: cost, usersBefore: s.consumerUsers,
                             tokensBefore: s.models.filter { $0.released && !$0.retired && $0.id != m.id }.reduce(0) { $0 + $1.demandTokensDay },
                             leadsBefore: s.deals.count)
        r.by = by
        if !p.isDefault {
            if p.pricing != .match {
                let floor = m.deployments.isEmpty ? 0 : Treasury.minPrice(m, s)
                s.models[i].apiPrice = max(0.001, max(floor, Treasury.tidy(m.apiPrice * p.pricing.priceFactor)))
            }
            reactions(&s, m, p, rank: rank)
            r.responses = queueResponses(s, m, p, rank: rank)
        }
        s.launches.append(r)
        if s.launches.count > 80 { s.launches.removeFirst(s.launches.count - 80) }
    }

    /// The plan's effect on the people who matter, with the plan named as the cause.
    static func reactions(_ s: inout GameState, _ m: AIModel, _ p: LaunchPlan, rank: Int) {
        let frontier = rank <= 3 || m.c >= Macro.frontier(s.year) - 0.3
        var d: [String: Double] = [:]
        var concern = 0.0
        var rules: [Region: Double] = [:]
        let home = HQ.region(s)
        switch p.strategy {
        case .standard: break
        case .stealth:
            d["developers", default: 0] += 0.5
            if frontier { d["researchers", default: 0] -= 0.5 }
        case .staged:
            d["public", default: 0] += 1
            d["researchers", default: 0] += 0.5
            concern -= 0.3
        case .keynote:
            d["public", default: 0] += rank <= 3 ? 1 : 0.5
            d["investors", default: 0] += 2
            if frontier {
                concern += 0.6
                rules[.us, default: 0] += 0.6
                rules[.eu, default: 0] += 0.6
            }
        case .openWeights:
            d["developers", default: 0] += 1
            d["researchers", default: 0] += 1
            if frontier { rules[.us, default: 0] += 0.5 }
        case .enterprise:
            d["investors", default: 0] += 3
            d["developers", default: 0] -= 0.5
        case .government:
            for r in Region.allCases { d[r.rawValue, default: 0] += r == home ? 4 : 1.5 }
            d["public", default: 0] -= 1
            d["researchers", default: 0] -= 1.5
            rules[home, default: 0] -= 1
        case .blitz:
            d["researchers", default: 0] += rank <= 3 ? 1 : -1
            d["developers", default: 0] += 0.5
        }
        switch p.pricing {
        case .match: break
        case .premium:
            d["developers", default: 0] -= 1
            d["investors", default: 0] += 1
        case .undercut:
            d["developers", default: 0] += 2
            d["investors", default: 0] -= 1
        }
        switch p.safety {
        case .standard: break
        case .light:
            d["researchers", default: 0] -= 1.5
            d["public", default: 0] -= frontier ? 1 : 0.5
            if frontier {
                concern += 0.4
                rules[.eu, default: 0] += 0.5
            }
        case .thorough:
            d["public", default: 0] += 1.5
            d["researchers", default: 0] += 1.5
            for r in Region.allCases { d[r.rawValue, default: 0] += 1 }
            if frontier { concern -= 0.4 }
        }
        Stakeholders.move(&s, d, "Launched \(m.name): \(p.summary.lowercased())")
        if concern != 0 || !rules.isEmpty {
            World.shock(&s, concern: concern, regions: rules, "\(s.companyName)'s \(p.strategy.title.lowercased()) of \(m.name)")
        }
    }

    /// The strongest rival with a model on the market: the one with most to lose.
    static func leadingRival(_ s: GameState) -> Int? {
        s.competitors.indices.filter { s.competitors[$0].alive && !s.competitors[$0].models.isEmpty }
            .max { (s.competitors[$0].models.map(\.index).max() ?? 0) < (s.competitors[$1].models.map(\.index).max() ?? 0) }
    }

    static func queueResponses(_ s: GameState, _ m: AIModel, _ p: LaunchPlan, rank: Int) -> [LaunchResponse] {
        let odds = responseOdds(p, rank: rank)
        guard odds >= 0.08, let ci = leadingRival(s) else { return [] }
        let key = "launch|\(s.lifecycleSalt)|\(m.name)|\(RivalIntel.dayIndex(s.date))"
        let days = 14 + Int(RivalIntel.unit(key + "|due") * 26)
        return [LaunchResponse(lab: s.competitors[ci].id, kind: p.pricing == .undercut ? "price" : "counter", odds: odds,
                               due: GameCalendar.addDays(s.date, days))]
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        guard !s.launches.isEmpty else { return }
        let today = s.date
        for k in s.launches.indices.reversed() {
            let age = GameCalendar.daysBetween(s.launches[k].date, today)
            if age > 60 { break }
            if s.launches[k].report == nil && age >= 7 { writeReport(&s, k) }
            for j in s.launches[k].responses.indices where s.launches[k].responses[j].happened == nil && s.launches[k].responses[j].due <= today {
                respond(&s, k, j)
            }
        }
    }

    /// A queued rival answer falls due: it happens or it doesn't (hashed against its odds).
    static func respond(_ s: inout GameState, _ k: Int, _ j: Int) {
        let r = s.launches[k]
        let resp = r.responses[j]
        let key = "launch|\(s.lifecycleSalt)|\(r.modelName)|\(RivalIntel.dayIndex(r.date))|resp|\(j)"
        guard let ci = s.competitors.firstIndex(where: { $0.id == resp.lab && $0.alive }) else {
            s.launches[k].responses[j].happened = false
            s.launches[k].responses[j].note = "\(CompetitorCatalog.byID[resp.lab]?.name ?? resp.lab) is no longer in the race."
            return
        }
        let name = s.competitors[ci].def.name
        let hit = RivalIntel.unit(key) < resp.odds
        s.launches[k].responses[j].happened = hit
        guard hit else {
            s.launches[k].responses[j].note = "\(name) held fire."
            return
        }
        if resp.kind == "price" {
            let before = max(0, s.competitors[ci].priceCut)
            s.competitors[ci].priceCut = min(0.45, before + 0.06)
            let cut = s.competitors[ci].priceCut
            s.launches[k].responses[j].note = "\(name) cut API prices to \(Int(cut * 100))% below list."
            Voices.priceWar(&s, ci, title: "\(name) cuts prices after \(r.modelName)",
                            body: "Your undercut on \(r.modelName) drew an answer: \(name) lowered its API prices to \(Int(cut * 100))% below list.",
                            monthly: false, cut: cut)
        } else {
            s.competitors[ci].brand = min(100, s.competitors[ci].brand + 2)
            s.launches[k].upstaged = s.date
            s.launches[k].responses[j].note = "\(name) answered with its own event and took the spotlight."
            Sim.news(&s, "\(name) steals the spotlight from \(r.modelName)",
                     "\(name) answered your launch with a demo day of its own. The buzz around \(r.modelName) fades faster from here.",
                     .competitor, good: false)
        }
    }

    // MARK: The launch-day report

    /// What the plan was for, and the traffic it should reach in a week relative to what your API sold the day before.
    static func goal(_ p: LaunchStyle) -> (text: String, traffic: Double) {
        switch p {
        case .standard: ("a clean launch that holds your traffic", 1.0)
        case .stealth: ("a quiet start that builds by word of mouth", 0.7)
        case .staged: ("a safe, orderly rollout", 0.5)
        case .keynote: ("a headline launch with a day-one rush", 1.3)
        case .openWeights: ("developer adoption", 1.0)
        case .enterprise: ("enterprise leads and investor confidence", 0.8)
        case .government: ("goodwill with governments", 0.8)
        case .blitz: ("winning the benchmark conversation", 1.1)
        }
    }

    static func writeReport(_ s: inout GameState, _ k: Int) {
        let r = s.launches[k]
        let m = s.models.first { $0.id == r.modelID }
        let rank = m.map { Leaderboard.rank(of: $0.id, in: s) } ?? r.rank
        let frontier = rank <= 3 || (m.map { $0.c >= Macro.frontier(s.year) - 0.3 } ?? false)
        let tone = pressTone(r.plan, rank: r.rank, frontier: frontier)
        let tokens = m?.demandTokensDay ?? 0
        let served = m.map { $0.demandTokensDay > 0 ? min(1, $0.servedTokensDay / $0.demandTokensDay) : 1 } ?? 1
        let apiTokens = m.map { $0.apiPrice > 0 ? $0.revenueDay / $0.apiPrice * 1e6 : 0 } ?? 0
        let leads = max(0, s.deals.count - r.leadsBefore)
        var rep = LaunchReport(date: s.date, signUps: s.consumerUsers - r.usersBefore, chatUsers: s.consumerUsers, apiTokensDay: apiTokens,
                               tokensDay: tokens, tokensBefore: r.tokensBefore, servedShare: served, revenueDay: m?.revenueDay ?? 0,
                               rank: rank, index: m?.index ?? r.index, pressTone: tone, verdict: "on", verdictText: "")
        rep.leads = leads
        rep.quotes = pressQuotes(&s, r, rank: rank, tone: tone, frontier: frontier)
        rep.benchmarks = benchmarkLines(s, r, m, rank: rank)
        rep.rivals = rivalLines(s, r)
        rep.stakeholders = stakeholderLines(s, r)
        let v = verdict(r, rep, frontier: frontier)
        rep.verdict = v.key
        rep.verdictText = v.text
        s.launches[k].report = rep
        guard r.by != "family" else { return }
        let head = v.key == "beat" ? "beat the plan" : (v.key == "on" ? "on plan" : "below plan")
        Sim.news(&s, "\(reportTitle)\(r.modelName) — \(head)", v.text, .company, good: v.key == "below" ? false : (v.key == "beat" ? true : nil))
        Alerts.raise(&s, .milestone, key: "launchreport|\(r.id.uuidString)", title: "\(reportTitle)\(r.modelName)",
                     body: "A week in: \(head). \(v.text)", screen: .progression, cooldown: 0)
        if v.key == "below" && !r.plan.isDefault && r.plan.strategy != .stealth && r.plan.strategy != .staged && r.by.isEmpty,
           !s.decisions.contains(where: { $0.kind == decisionKind }) {
            let cost = GameState.keynoteCost(s) * 0.5
            Events.addDecision(&s, kind: decisionKind, title: "\(r.modelName)'s launch is underperforming",
                               body: "A week in, \(r.modelName) is behind its \(r.plan.strategy.title.lowercased()) plan. A second marketing wave would bring a fresh, smaller rush.",
                               image: "sf_skyline",
                               options: [DecisionOption(label: "Second wave (\(Fmt.money(cost)))", detail: "Ads, a developer event and a press tour: a new spike that fades over a few weeks."),
                                         DecisionOption(label: "Let it ride", detail: "Save the money; the model finds its level.")],
                               amount: cost, ref: r.id.uuidString)
        }
    }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard option == 0, let id = UUID(uuidString: d.ref), let k = s.launches.firstIndex(where: { $0.id == id }) else { return }
        guard s.cash >= d.amount else {
            Sim.news(&s, "No second wave for \(s.launches[k].modelName)", "There wasn't \(Fmt.money(d.amount)) in the bank for it.", .company, good: false)
            return
        }
        s.cash -= d.amount
        s.month.costMarketing += d.amount
        s.launches[k].secondWave = s.date
        Sim.news(&s, "Second wave for \(s.launches[k].modelName)", "Ads, a developer event and a press tour put \(s.launches[k].modelName) back in front of buyers.", .company)
    }

    static func pressQuotes(_ s: inout GameState, _ r: LaunchRecord, rank: Int, tone: Double, frontier: Bool) -> [String] {
        let key = "lreport|\(r.modelName)|\(RivalIntel.dayIndex(r.date))"
        var v = Voices.base(s)
        v["model"] = r.modelName
        v["rank"] = "\(rank)"
        v["index"] = Fmt.score(r.index)
        v["plan"] = r.plan.strategy.title.lowercased()
        if let lab = leadingRival(s) { v["rivallab"] = Cast.short(s.competitors[lab].id) }
        let press = tone >= 0.3 ? "lreport.press.good" : (tone <= -0.1 ? "lreport.press.bad" : "lreport.press.mixed")
        var out = Voices.quotes(&s, [(press, Voices.analyst(s, key))], vars: v, key: key + "|press", second: 0)
        var options: [(bank: String, speaker: CastMember?)] = []
        switch r.plan.strategy {
        case .standard: break
        case .stealth: options.append(("lreport.stealth", Voices.analyst(s, key + "|2", avoid: [])))
        case .staged: options.append(("lreport.staged", Voices.academic(s, key)))
        case .keynote: options.append(("lreport.keynote", Voices.skeptic(s, key, not: [])))
        case .openWeights: options.append(("lreport.open", Voices.academic(s, key)))
        case .enterprise: options.append(("lreport.enterprise", Voices.anyInvestor(s, key)))
        case .government: options.append(("lreport.government", Voices.official(s, key)))
        case .blitz: options.append((rank <= 3 ? "lreport.blitz.top" : "lreport.blitz.doubt", Voices.academic(s, key)))
        }
        if r.plan.pricing == .undercut, let ci = leadingRival(s) { options.append(("lreport.undercut", Cast.voice(s, s.competitors[ci].id))) }
        if r.plan.safety == .light && frontier { options.append(("lreport.safety.light", Voices.critic(s, key))) }
        if r.plan.safety == .thorough { options.append(("lreport.safety.thorough", Voices.critic(s, key))) }
        if !options.isEmpty { out += Voices.quotes(&s, options, vars: v, key: key + "|plan", second: 0.8) }
        return out
    }

    static func benchmarkLines(_ s: GameState, _ r: LaunchRecord, _ m: AIModel?, rank: Int) -> [String] {
        var out = ["#\(rank) on the leaderboard with an Intelligence Index of \(Fmt.score(m?.index ?? r.index))"
                   + (rank != r.rank ? " (launched at #\(r.rank))." : ".")]
        if let p = r.previousBest, let m { out.append(m.index >= p ? "\(Fmt.score(m.index - p)) points above your previous best." : "Below your previous best by \(Fmt.score(p - m.index)) — a cheaper option, not a new flagship.") }
        if let m, let mine = s.domainScores[m.id.uuidString] {
            var leads: [String] = []
            var worst: (CapDomain, String, Double)? = nil
            for d in CapDomain.allCases where mine[d] > 0 {
                var best: (String, Double)? = nil
                for c in s.competitors where c.alive {
                    if let sc = s.labDomains[c.id]?[d], sc > (best?.1 ?? -1) { best = (c.def.name, sc) }
                }
                guard let b = best else { continue }
                if mine[d] > b.1 { leads.append(d.label) }
                else if b.1 - mine[d] > (worst?.2 ?? 0) { worst = (d, b.0, b.1 - mine[d]) }
            }
            if !leads.isEmpty { out.append("Leads the field in \(leads.prefix(3).joined(separator: ", "))\(leads.count > 3 ? " and \(leads.count - 3) more" : "").") }
            if let w = worst, w.2 >= 3 { out.append("Biggest gap: \(w.0.label), \(Int(w.2.rounded())) points behind \(w.1).") }
        }
        if r.plan.strategy == .blitz {
            out.append(rank <= 3 ? "The published evals held up: outside groups reproduced the headline numbers." : "Outside groups questioned the published evals; some suspect contamination.")
        }
        return out
    }

    static func rivalLines(_ s: GameState, _ r: LaunchRecord) -> [String] {
        var out: [String] = []
        for q in s.rumors where q.date >= r.date && (q.kind == "codered" || q.kind == "hold") { out.append(q.title + ".") }
        for resp in r.responses {
            let name = CompetitorCatalog.byID[resp.lab]?.name ?? resp.lab
            if let h = resp.happened {
                out.append(resp.note.isEmpty ? (h ? "\(name) answered." : "\(name) held fire.") : resp.note)
            } else {
                let what = resp.kind == "price" ? "cut its API prices" : "answer with its own launch event"
                out.append("Expected: \(name) may \(what) — about \(Int(resp.odds * 100))% likely, around \(resp.due.gameShort).")
            }
        }
        if out.isEmpty { out.append(r.plan.isDefault ? "No rival has reacted yet; their next releases are on Rival Watch." : "No rival answer expected.") }
        return out
    }

    static func stakeholderLines(_ s: GameState, _ r: LaunchRecord) -> [String] {
        let end = GameCalendar.addDays(r.date, 8)
        var out: [String] = []
        let names = ["public": "public", "researchers": "researchers", "developers": "developers", "investors": "investors"]
        for n in s.world.notes.reversed() where n.date >= r.date && n.date <= end {
            let parts = n.deltas.sorted { abs($0.value) != abs($1.value) ? abs($0.value) > abs($1.value) : $0.key < $1.key }.prefix(4).map { k, v in
                "\(names[k] ?? Region(rawValue: k)?.short ?? k) \(v >= 0 ? "+" : "")\(Fmt.trim(v, 1))"
            }
            out.append("\(n.text): \(parts.joined(separator: ", ")).")
        }
        for n in s.world.log.reversed() where n.date >= r.date && n.date <= end && n.text.contains(r.modelName) {
            if let c = n.deltas["concern"] { out.append("Safety concern \(c >= 0 ? "+" : "")\(Fmt.trim(c, 1)): \(n.text).") }
        }
        return Array(out.suffix(5))
    }

    static func verdict(_ r: LaunchRecord, _ rep: LaunchReport, frontier: Bool) -> (key: String, text: String) {
        let g = goal(r.plan.strategy)
        let ratio = rep.tokensBefore > 1 ? rep.tokensDay / rep.tokensBefore : (rep.tokensDay > 0 ? g.traffic : 0)
        var score = 0
        var notes: [String] = []
        if ratio >= g.traffic {
            score += 1
            notes.append(rep.tokensBefore > 1 ? "traffic is \(Fmt.trim(ratio, 1))× what your models drew the day before" : "traffic is flowing")
        } else if ratio < g.traffic * 0.6 {
            score -= 1
            notes.append(rep.tokensBefore > 1 ? "traffic is only \(Fmt.trim(ratio, 1))× what your models drew before" : "almost no traffic yet")
        }
        if rep.pressTone >= 0.3 { score += 1; notes.append("the press is warm") }
        else if rep.pressTone <= -0.1 { score -= 1; notes.append("the press is cool") }
        switch r.plan.strategy {
        case .enterprise:
            if rep.leads > 0 { score += 1; notes.append("\(rep.leads) new enterprise lead\(rep.leads == 1 ? "" : "s")") } else { notes.append("no enterprise leads yet") }
        case .blitz:
            if rep.rank <= 3 { score += 1 } else { score -= 1; notes.append("the charts didn't top the board") }
        case .staged, .government, .stealth:
            score += 1
        case .openWeights:
            if r.rank <= 5 { score += 1 }
        case .keynote, .standard:
            break
        }
        if rep.servedShare < 0.8 {
            score -= 1
            notes.append("only \(Fmt.pct(rep.servedShare, decimals: 0)) of demand is being served — add chips")
        }
        let key = score >= 2 ? "beat" : (score >= 0 ? "on" : "below")
        let lead = key == "beat" ? "Beat the plan" : (key == "on" ? "On plan" : "Below plan")
        let body = notes.isEmpty ? "" : ": " + notes.joined(separator: "; ")
        return (key, "\(lead) for \(g.text)\(body).")
    }

    // MARK: Automation

    /// What the playtest bot launches with: the plain release, so its balance runs stay comparable.
    static func botPlan(_ s: GameState, _ m: AIModel) -> LaunchPlan { LaunchPlan() }

    /// The default plan, unless the delegate can't use it today (cost, stage): then the plain release.
    static func delegatePlan(_ s: GameState) -> LaunchPlan {
        blocker(s.launchDefault, s) == nil ? s.launchDefault : LaunchPlan()
    }
}

extension GameState {
    mutating func setLaunchDefault(_ p: LaunchPlan) { launchDefault = p }
}
