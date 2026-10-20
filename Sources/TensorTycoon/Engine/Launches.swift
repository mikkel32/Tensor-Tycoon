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
    /// 3.8: a research preview's cheap, rate-limited phase, and limited-access testing's tester-only phase.
    static let previewDays = 45.0
    static let testingDays = 30.0
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
            add("Rivals", "Barely notice (5% chance of an answer; a tenth of the usual chance of a code red).", true)
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
        case .researchPreview:
            add("Price", "A quarter of the going rate (never below serving cost) for \(Int(previewDays)) days.", nil)
            add("Demand", "Rate-limited: API demand capped at 40% for \(Int(previewDays)) days.", false)
            add("Feedback", "Researchers' reports make the model's next post-training pass 30% cheaper.", true)
            add("Standing", "Researchers +2, developers +1.", true)
            add("Brand", "40% of the usual gain.", false)
            add("Rivals", "Rivals study it closely: for nine months they copy more of your lead by distilling it.", false)
        case .limitedAccess:
            add("Revenue", "Trusted testers only: no API sales for \(Int(testingDays)) days, and your chat app, agents and contracts stay on the models they're on until general release.", false)
            add("Safety", "+6 model safety, +2 lab safety; while it's live, safety incidents are rarer (testers found the worst failure modes first).", true)
            add("Standing", "Public +1, researchers +1, every government +0.5.", true)
            add("Brand", "Half the usual gain.", false)
            add("Rivals", "Barely notice until it's on sale.", true)
        }
        if rank == 1 && p.strategy != .limitedAccess {
            add("Enterprise", "A new #1: clients of rival labs with weaker models ask for proposals (extra enterprise leads).", true)
        }
        switch p.pricing {
        case .match: break
        case .premium:
            add("Price", "List +25% over the going rate for 120 days (auto-pricing holds it there; a hand-set price goes back afterwards): more per token, fewer tokens.", nil)
            add("Standing", "Developers −1, investors +1\(top3 ? "; +1 brand for a premium top-3 model" : "").", nil)
        case .undercut:
            add("Price", "List −25% under the going rate for 120 days (held by auto-pricing; a hand-set price goes back afterwards), plus a developer rush (+15% demand, fading over six weeks).", true)
            add("Standing", "Developers +2, investors −1.", nil)
            add("Price war", "The leading rival is ~\(Int(min(0.95, responseOdds(p, rank: rank)) * 100))% likely to cut prices within six weeks.", false)
        }
        switch p.safety {
        case .standard: break
        case .light:
            add("Safety posture", "A short card: +5% buzz, but researchers and the public mark you down\(top3 ? ", concern rises and the EU takes note" : "").", false)
        case .thorough:
            add("Safety posture", thoroughText(s, top3: top3), true)
        }
        return out
    }

    private static func thoroughText(_ s: GameState, top3: Bool) -> String {
        let evals = s.researched.contains("evals_rsp") ? " It counts as the model's dangerous-capability evaluation (EU AI Act)." : ""
        return "\(Fmt.money(redTeamCost(s))): +3 model safety, public +1.5, researchers +1.5, every government +1\(top3 ? ", concern eases" : "")." + evals
    }

    /// How hot a launch can run for a model at this rank (1 = new #1).
    static func spikeQuality(_ rank: Int) -> Double { rank == 1 ? 1 : (rank <= 3 ? 0.8 : (rank <= 5 ? 0.6 : 0.4)) }

    /// 3.8: whether a launch registers with rival labs whose next model it beats (`notice`), and how much likelier it
    /// makes a rushed answer (`rush`, on each lab's own odds). A stealth drop is noticed a tenth as often; a keynote
    /// always lands and makes a rush 30% likelier.
    static func rivalHeat(_ st: LaunchStyle) -> (notice: Double, rush: Double) {
        switch st {
        case .stealth: (0.1, 0.5)
        case .limitedAccess: (0.2, 0.6)
        case .researchPreview: (0.6, 0.8)
        case .staged: (0.6, 0.8)
        case .government: (0.7, 0.8)
        case .enterprise: (0.8, 0.9)
        case .standard: (1, 1)
        case .openWeights: (1, 1.1)
        case .blitz: (1, 1.2)
        case .keynote: (1, 1.3)
        }
    }

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
        case .researchPreview: o = 0.1
        case .limitedAccess: o = 0.03
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
        case .researchPreview: t = 0.2 + t * 0.5
        case .limitedAccess: t = 0.15 + t * 0.4
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
        case .researchPreview: if !consumer && t < previewDays { f *= 0.4 }
        case .limitedAccess:
            // Trusted testers only: nothing on sale until general release.
            if !consumer && t < testingDays { return 0 }
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
            let t = Double(GameCalendar.daysBetween(r.date, s.date))
            if r.plan.strategy == .researchPreview && t < previewDays { return 0.25 }   // 3.8: nearly free
            return t < priceDays ? r.plan.pricing.priceFactor : 1
        }
        return 1
    }

    /// 3.8: where auto-pricing holds a model while its launch's pricing stance lasts (nil when no stance applies): within
    /// 10% of the going rate's auto-price anchor (0.85×) times the stance, so the stance isn't priced away in a week.
    static func stanceBand(_ s: GameState, _ m: AIModel) -> ClosedRange<Double>? {
        let f = priceFactor(s, m.id)
        guard abs(f - 1) > 0.001 else { return nil }
        let anchor = Treasury.marketPrice(m, s) * 0.85 * f
        return (anchor * 0.9)...(anchor * 1.1)
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
    static func adjustGain(_ gain: Double, _ p: LaunchPlan, rank: Int, lift: Double = 1) -> Double {
        var g = gain
        if p.pricing == .premium && rank <= 3 && g > 0 { g += 1 }
        if p.safety == .light && g > 0 { g *= 1.1 }
        if g > 0 { g *= lift }   // 3.8: a later generation of a known family (Families.generationLift)
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
        r.apiShareBefore = s.apiShareNow
        r.passesAtLaunch = m.passes.count
        if !p.isDefault {
            let f = p.strategy == .researchPreview ? 0.25 : p.pricing.priceFactor
            if abs(f - 1) > 0.001 {
                // 3.8: auto-pricing holds the stance around the going rate (stanceBand); a hand-set price is scaled
                // and restored when the stance ends.
                let floor = m.deployments.isEmpty ? 0 : Treasury.minPrice(m, s)
                let price = m.autoPrice ? Treasury.marketPrice(m, s) * 0.85 * f : m.apiPrice * f
                if !m.autoPrice { r.priorPrice = m.apiPrice }
                s.models[i].apiPrice = max(0.001, max(floor, Treasury.tidy(price)))
                r.stancePrice = s.models[i].apiPrice
            }
            reactions(&s, m, p, rank: rank)
            r.responses = queueResponses(s, m, p, rank: rank)
        }
        s.launches.append(r)
        if s.launches.count > 80 { s.launches.removeFirst(s.launches.count - 80) }
        if by != "family" { marketReactions(&s, s.models[i], p, rank: rank) }
    }

    // MARK: 3.8: the market after a launch

    /// What any launch of yours does beyond the plan's own effects: a new #1 pulls rivals' enterprise clients and
    /// governments' attention; climbing the board moves investors.
    static func marketReactions(_ s: inout GameState, _ m: AIModel, _ p: LaunchPlan, rank: Int) {
        let last = s.marketMoves.lastRank
        if last > 0 && rank < last {
            s.marketMoves.rankMomentum = clamp(s.marketMoves.rankMomentum + 0.1 * Double(min(3, last - rank)), -1, 1)
            s.marketMoves.lastRank = rank
            note(&s, "\(m.name) took your lab from #\(last) to #\(rank): investors mark up their expectations.")
        }
        guard rank == 1, p.strategy != .limitedAccess else { return }
        let won = winLeads(&s, m)
        if won > 0 { note(&s, "\(m.name) topped the board: \(won) enterprise client\(won == 1 ? "" : "s") of weaker rival labs asked for proposals.") }
        // Governments want a briefing from the lab at the top (and sovereign buyers take note).
        Stakeholders.move(&s, [HQ.region(s).rawValue: 1], "\(m.name) tops the leaderboard: officials ask for briefings")
    }

    static func note(_ s: inout GameState, _ text: String) {
        s.marketMoves.log.insert("\(s.date.gameShort): \(text)", at: 0)
        if s.marketMoves.log.count > 12 { s.marketMoves.log.removeLast(s.marketMoves.log.count - 12) }
    }

    /// The kinds of enterprise work clients buy (as Business.generateDeals names them).
    static func dealTitles(_ y: Double) -> [String] {
        y < 2022 ? ["custom NLP model", "document classification", "translation pipeline", "search ranking", "chatbot pilot"]
            : ["customer-support agents", "coding assistant rollout", "document intelligence", "internal copilot",
               "research assistant", "claims automation", "contract review", "voice agents"]
    }

    /// A new #1 makes clients of weaker rival labs ask for proposals: the enterprise money held by labs whose best model
    /// is now beaten (it follows their API share, as in RivalEconomy) turns into up to three leads, for the kinds of
    /// work this model is best at. Never more than six open leads.
    @discardableResult
    static func winLeads(_ s: inout GameState, _ m: AIModel) -> Int {
        let room = max(0, 6 - s.deals.filter { !$0.active }.count)
        guard room > 0, s.year >= 2019 else { return 0 }
        var held = 0.0
        var biggest: (lab: String, share: Double, index: Double)? = nil
        for c in s.competitors where c.alive {
            guard let best = (c.models + c.openModels).map(\.index).max(), best < m.index, c.apiShare > 0 else { continue }
            held += c.apiShare
            if c.apiShare > (biggest?.share ?? 0) { biggest = (c.id, c.apiShare, best) }
        }
        guard held > 0.02, let from = biggest else { return 0 }
        let n = min(room, held > 0.3 ? 3 : (held > 0.12 ? 2 : 1))
        let size = Macro.marketSize(s.year) * Macro.segmentSplit(s.year, chatMoment: s.chatMoment != nil).enterprise
        let titles = dealTitles(s.year).sorted { Capabilities.dealFitPoints(m, title: $0, s) > Capabilities.dealFitPoints(m, title: $1, s) }
        let price = max(0.05, Macro.referencePrice(c: Macro.frontier(s.year) - 0.3, y: s.year) * s.market.apiPricePressure)
        let rival = CompetitorCatalog.def(from.lab).name
        for k in 0..<n {
            let key = "leads|\(s.lifecycleSalt)|\(m.id.uuidString)|\(k)"
            let monthly = max(8_000, size / 12 * (0.0001 + 0.0003 * RivalIntel.unit(key + "|size")))
            let months = [12, 24, 36][Int(RivalIntel.unit(key + "|months") * 3) % 3]
            let client = NameBank.clients[Int(RivalIntel.unit(key + "|client") * Double(NameBank.clients.count)) % NameBank.clients.count]
            let deal = EnterpriseDeal(client: client, title: titles[k % titles.count], monthly: monthly,
                                      tokensPerDay: monthly / 30.4 / price * 1e6 * 0.6, months: months, monthsLeft: months,
                                      minIndex: from.index, minSafety: 20 + 40 * RivalIntel.unit(key + "|safety"),
                                      expires: GameCalendar.addDays(s.date, 30))
            s.deals.append(deal)
            Sim.news(&s, "Enterprise lead: \(client) looks beyond \(rival)", "\(Fmt.money(monthly))/month for \(deal.title), \(months) months — they want what \(m.name) does better. Review it in Market.",
                     .market, important: false, good: true)
        }
        s.marketMoves.leadsWon += n
        return n
    }

    /// The developer ecosystem's lift on your API demand: up to +15% when it's at 100.
    static func ecosystemFactor(_ s: GameState) -> Double { 1 + 0.15 * clamp(s.marketMoves.devEcosystem, 0, 100) / 100 }

    /// Hook for the valuation (Economy.valuation): what investors make of your recent rank changes, 0.88–1.12.
    static func valuationFactor(_ s: GameState) -> Double { 1 + 0.12 * clamp(s.marketMoves.rankMomentum, -1, 1) }

    /// How much more of your lead rivals copy by distilling your outputs when they plan a release on `date`: 1.5×
    /// within nine months of a research preview of yours (one month in, so they've had time to collect outputs).
    static func previewExposure(_ s: GameState, before date: Date) -> Double {
        guard !s.launches.isEmpty else { return 1 }
        let open = s.launches.contains { r in
            r.plan.strategy == .researchPreview && GameCalendar.daysBetween(r.date, date) >= 30 && GameCalendar.daysBetween(r.date, date) <= 270
        }
        return open ? 1.5 : 1
    }

    /// First of the month (from Competitors.monthly): the developer ecosystem, rank momentum and contract renewals.
    static func monthly(_ s: inout GameState) {
        ecosystem(&s)
        momentum(&s)
        renewals(&s)
    }

    /// Developers building on your models: near-frontier open weights, your API share and how developers see you feed
    /// it; it grows a tenth of the way to that each month and fades only 3% of the way when you stop feeding it.
    static func ecosystem(_ s: inout GameState) {
        let frontier = Macro.frontier(s.year)
        let open = s.models.filter { $0.released && !$0.retired && $0.openWeights }.map(\.c).max().map { 40 * clamp(1 + $0 - frontier, 0, 1) } ?? 0
        let devs = s.world.ready ? s.world.developers : 50
        let target = clamp(open + 150 * s.apiShareNow + 0.4 * (devs - 50), 0, 100)
        let e = s.marketMoves.devEcosystem
        s.marketMoves.devEcosystem = e + (target - e) * (target > e ? 0.1 : 0.03)
    }

    /// Investors read rank: momentum jumps when your lab climbs or falls and fades by 15% a month.
    static func momentum(_ s: inout GameState) {
        let set = Leaderboard.indexSet(s)
        guard let best = RivalIntel.playerBest(s, set: set) else { return }
        let rank = Leaderboard.labRank(index: best.index, board: Leaderboard.entries(s, set: set, includeUnreleased: false), gone: Leaderboard.goneLabs(s))
        let last = s.marketMoves.lastRank
        var m = s.marketMoves.rankMomentum * 0.85
        if last > 0 && rank != last {
            m += 0.1 * Double(clamp(last - rank, -3, 3))
            if rank > last { note(&s, "Your lab slipped from #\(last) to #\(rank): investors trim their expectations.") }
        }
        s.marketMoves.rankMomentum = clamp(m, -1, 1)
        s.marketMoves.lastRank = rank
    }

    /// Points a rival must lead your contract's model by, on the contract's kind of work, before the client looks around
    /// at renewal.
    static let churnGap = 5.0

    /// Each contract comes up for renewal every 12 months. If a live rival now beats the model serving it by more than
    /// `churnGap` points on that kind of work, the client may move (15–70% likely as the gap grows; hashed per renewal).
    static func renewals(_ s: inout GameState) {
        var lost: [UUID] = []
        for d in s.deals where d.active && d.months >= 12 && d.monthsLeft > 0 {
            let elapsed = d.months - d.monthsLeft
            guard elapsed > 0, elapsed % 12 == 0, let mid = d.modelID, let m = s.models.first(where: { $0.id == mid }),
                  let v = s.domainScores[mid.uuidString], let rival = Capabilities.bestRivalFor(s, title: d.title) else { continue }
            let gap = rival.score - v.mix(Capabilities.dealDomains(d.title))
            guard gap > churnGap else { continue }
            let odds = clamp(0.15 + (gap - churnGap) / 10, 0.15, 0.7)
            guard RivalIntel.unit("renew|\(s.lifecycleSalt)|\(d.id.uuidString)|\(elapsed)") < odds else { continue }
            lost.append(d.id)
            let name = CompetitorCatalog.def(rival.lab).name
            Sim.news(&s, "\(d.client) moves to \(name) at renewal",
                     "Its \(d.title) contract was up for renewal, and \(name)'s models now beat \(m.name) by \(Int(gap.rounded())) points on that kind of work. \(Fmt.money(d.monthly))/month walks.",
                     .market, important: d.monthly > 1e6, good: false)
            note(&s, "\(d.client) took its \(d.title) to \(name) (\(Int(gap.rounded())) points better at it).")
            s.marketMoves.churned += 1
        }
        if !lost.isEmpty { s.deals.removeAll { lost.contains($0.id) } }
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
        case .researchPreview:
            d["researchers", default: 0] += 2
            d["developers", default: 0] += 1
        case .limitedAccess:
            d["public", default: 0] += 1
            d["researchers", default: 0] += 1
            for r in Region.allCases { d[r.rawValue, default: 0] += 0.5 }
            if frontier { concern -= 0.2 }
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
            if Double(age) > priceDays + 5 { break }
            if s.launches[k].report == nil && age >= 7 { writeReport(&s, k) }
            for j in s.launches[k].responses.indices where s.launches[k].responses[j].happened == nil && s.launches[k].responses[j].due <= today {
                respond(&s, k, j)
            }
            if s.launches[k].plan.strategy == .limitedAccess && s.launches[k].generalRelease == nil { testing(&s, k, age: age) }   // 3.8
            if !s.launches[k].priceSettled { settlePrice(&s, k, age: age) }
        }
    }

    /// 3.8: a hand-set price the stance changed goes back when the stance ends (unless you've set another since). A
    /// research preview's give-away phase ends first: then the plan's pricing stance takes over.
    static func settlePrice(_ s: inout GameState, _ k: Int, age: Int) {
        let r = s.launches[k]
        let t = Double(age)
        guard r.priorPrice > 0 else {
            if t >= priceDays { s.launches[k].priceSettled = true }
            return
        }
        guard let i = s.models.firstIndex(where: { $0.id == r.modelID }), !s.models[i].autoPrice, abs(s.models[i].apiPrice - r.stancePrice) < 1e-9 else {
            s.launches[k].priceSettled = true   // you've priced it yourself since
            return
        }
        let floor = s.models[i].deployments.isEmpty ? 0 : Treasury.minPrice(s.models[i], s)
        if r.plan.strategy == .researchPreview && t >= previewDays && t < priceDays && r.plan.pricing != .match {
            let next = max(floor, Treasury.tidy(r.priorPrice * r.plan.pricing.priceFactor))
            if abs(next - r.stancePrice) > 1e-9 {
                s.models[i].apiPrice = next
                s.launches[k].stancePrice = next
            }
            return
        }
        let ends = r.plan.strategy == .researchPreview && r.plan.pricing == .match ? previewDays : priceDays
        guard t >= ends else { return }
        s.models[i].apiPrice = max(floor, r.priorPrice)
        s.launches[k].priceSettled = true
        Sim.news(&s, "\(s.models[i].name)'s launch pricing ends", "Back to the \(Fmt.price(s.models[i].apiPrice))/1M you had set before launch.", .company)
    }

    /// 3.8: limited-access testing. Until general release your chat app, agents and contracts stay on the models they
    /// were on; then the tested model takes over wherever it's better, as on any launch.
    /// 3.9: when a model in limited-access testing goes on general release (nil when it isn't in testing). Chat,
    /// agents and contracts can't move onto it until then.
    static func testingUntil(_ s: GameState, _ modelID: UUID) -> Date? {
        guard let r = s.launches.last(where: { $0.modelID == modelID }), r.plan.strategy == .limitedAccess, r.generalRelease == nil else { return nil }
        let end = GameCalendar.addDays(r.date, Int(testingDays))
        return end > s.date ? end : nil
    }

    static func testing(_ s: inout GameState, _ k: Int, age: Int) {
        let id = s.launches[k].modelID
        guard let m = s.models.first(where: { $0.id == id && !$0.retired }) else {
            s.launches[k].generalRelease = s.date
            return
        }
        let others = s.models.filter { $0.released && !$0.retired && $0.id != id }
        if Double(age) < testingDays {
            if s.chatModelID == id, let alt = others.filter(\.design.instruct).max(by: { $0.index < $1.index }) { s.chatModelID = alt.id }
            if s.agentModelID == id, let alt = others.filter(\.design.toolUse).max(by: { $0.index < $1.index }) { s.agentModelID = alt.id }
            for d in s.deals.indices where s.deals[d].active && s.deals[d].modelID == id {
                if let alt = others.filter({ $0.index + 0.01 >= s.deals[d].minIndex }).max(by: { $0.index < $1.index }) { s.deals[d].modelID = alt.id }
            }
            return
        }
        s.launches[k].generalRelease = s.date
        // 3.9: with no API sales during testing it may have lost its servers; give it some before products move onto it.
        if !m.deployments.contains(where: { Physics.capacity(m, deployment: $0, bonuses: s.bonuses) > 0 }) { s.provisionServers(id) }
        func better(than other: UUID?) -> Bool {
            guard let other, let o = s.models.first(where: { $0.id == other && !$0.retired }) else { return true }
            return m.index > o.index
        }
        if m.design.instruct && better(than: s.chatModelID) { s.chatModelID = id }
        if s.agentModelID != nil && m.design.toolUse && better(than: s.agentModelID) { s.agentModelID = id }
        for d in s.deals.indices where s.deals[d].active && s.deals[d].modelID != id && m.index + 0.01 >= s.deals[d].minIndex && better(than: s.deals[d].modelID) {
            s.deals[d].modelID = id
        }
        Sim.news(&s, "\(m.name) is generally available", "Thirty days with trusted testers are over: it's on sale, and your products move to it where it's the better model.",
                 .company, good: true)
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
        case .researchPreview: ("feedback from researchers", 0.3)
        case .limitedAccess: ("a safe, tested release", 0)
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
        // 3.8: the model as the market met it.
        let snap = Market.snapshot(s)
        rep.apiShareBefore = r.apiShareBefore
        rep.apiShare = snap.api.filter(\.isPlayer).reduce(0) { $0 + $1.share }
        if let m {
            rep.architecture = architecture(m)
            rep.pricePerM = m.api ? m.apiPrice : 0
            rep.servingPerM = Economy.servingCostPerM(m, s)
            rep.tokensPerSec = m.tps
            rep.powers = powers(s, m)
            rep.segments = Market.segments(of: m.id, snap).prefix(3).map { "\($0.segment.label) \(Fmt.pct($0.share, decimals: 0))" }
        }
        rep.moves = s.marketMoves.log.filter { line in m.map { line.contains($0.name) } ?? false }
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
        case .researchPreview: options.append(("lreport.preview", Voices.academic(s, key)))
        case .limitedAccess: options.append(("lreport.limited", Voices.critic(s, key)))
        }
        if r.plan.pricing == .undercut, let ci = leadingRival(s) { options.append(("lreport.undercut", Cast.voice(s, s.competitors[ci].id))) }
        if r.plan.safety == .light && frontier { options.append(("lreport.safety.light", Voices.critic(s, key))) }
        if r.plan.safety == .thorough { options.append(("lreport.safety.thorough", Voices.critic(s, key))) }
        if !options.isEmpty { out += Voices.quotes(&s, options, vars: v, key: key + "|plan", second: 0.8) }
        return out
    }

    /// "1.2T MoE (120B active) · 128K context · reasoning · vision".
    static func architecture(_ m: AIModel) -> String {
        let d = m.design
        var parts = [d.isMoE ? "\(Fmt.params(d.paramsB)) MoE (\(Fmt.params(d.activeParamsB)) active)" : "\(Fmt.params(d.paramsB)) dense"]
        parts.append(d.contextK >= 1000 ? "1M context" : "\(d.contextK)K context")
        if m.reasoning { parts.append("reasoning (\(m.effort.label.lowercased()) effort)") }
        if d.vision { parts.append("vision") }
        if d.audio { parts.append("voice") }
        if d.toolUse { parts.append("tool use") }
        return parts.joined(separator: " · ")
    }

    /// What a model powers today: the products it serves and the product lines its scores carry.
    static func powers(_ s: GameState, _ m: AIModel) -> [String] {
        var out = Families.segments(s, m)
        if let v = s.domainScores[m.id.uuidString], let best = s.labDomains["player"] {
            for p in s.productLines {
                guard let def = ProductLines.byID[p.id] else { continue }
                if v.mix(def.mix) + 0.05 >= best.mix(def.mix) { out.append(def.name) }
            }
        }
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
        case .staged, .government, .stealth, .researchPreview, .limitedAccess:
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
