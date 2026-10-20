import Foundation

/// The dashboard's view of today: what needs the player now, what's coming up and where the race stands, built from
/// state the game already keeps. Read-only: nothing here changes the game, and nothing here is expensive.
enum Agenda {
    // MARK: Needs you

    enum NeedKind {
        case advice(AdvisorItem)
        case decision(Decision)
        case alert(GameAlert)
    }

    struct Need: Identifiable {
        var id: String
        var kind: NeedKind
        /// Higher comes first: urgent advice, critical alerts and offers about to expire lead.
        var priority: Int
    }

    /// Advice items that already cover an alert kind, by ID prefix (Advisor.items).
    static let coveredBy: [AlertKind: String] = [
        .cashNegative: "cash", .bankruptcySoon: "cash", .termSheet: "offers", .offerExpiring: "offers", .runPaused: "run-",
        .boardGoalDue: "goal", .slaBreach: "sla-", .overCapacity: "capacity-", .swarmAlignment: "swarm-align",
        .priceWar: "pricewar-", .rentalExpiring: "rental-",
    ]

    /// The Chief of Staff's advice, inbox decisions and unread alerts in one list, most pressing first. Inbox offers are
    /// listed as decisions (with their deadline) instead of as advice, and alerts that repeat an advice item, the briefing
    /// (shown on its own card) and celebrations are left out.
    static func needs(_ s: GameState, advice: [AdvisorItem]) -> [Need] {
        let today = s.date
        var out: [(need: Need, key: Double)] = []
        for a in advice where !a.id.hasPrefix("inbox-") {
            let p = a.level == .urgent ? 100 : (a.level == .warning ? 70 : 40)
            out.append((Need(id: "advice-\(a.id)", kind: .advice(a), priority: p), 0))
        }
        for d in s.decisions where !Alerts.isUrgent(d) {
            // Hidden from the Chief of Staff with the bell: respect it here too, until the last three days (3.9).
            let left = daysLeft(d, today: today)
            if left > 3, let until = s.snoozed["inbox-\(d.id)"], until > today { continue }
            let p = left <= 3 ? 90 : (left <= 7 ? 72 : 45)
            out.append((Need(id: "decision-\(d.id)", kind: .decision(d), priority: p), Double(left)))
        }
        let ids = advice.map(\.id)
        for a in s.alerts where !a.seen && (a.critical || GameCalendar.daysBetween(a.date, today) <= 45) {
            guard let p = priority(a, adviceIDs: ids) else { continue }
            // Newest first among alerts.
            out.append((Need(id: "alert-\(a.id)", kind: .alert(a), priority: p), -a.date.timeIntervalSince1970))
        }
        return out.enumerated().sorted { x, y in
            if x.element.need.priority != y.element.need.priority { return x.element.need.priority > y.element.need.priority }
            if x.element.key != y.element.key { return x.element.key < y.element.key }
            return x.offset < y.offset
        }.map { $0.element.need }
    }

    /// Where an unread alert ranks, or nil when something else on the dashboard already covers it.
    static func priority(_ a: GameAlert, adviceIDs: [String]) -> Int? {
        switch a.alertKind {
        case .inbox, .briefing, .milestone: return nil
        default: break
        }
        // 3.9: "offer expiring" also warns about inbox offers and lease step-ups; only a term sheet's is covered by the
        // term-sheet advice (a waiting term sheet used to hide the others).
        if a.alertKind == .offerExpiring && !a.title.hasPrefix("A term sheet") { return a.critical ? 95 : 60 }
        if let prefix = coveredBy[a.alertKind], adviceIDs.contains(where: { $0.hasPrefix(prefix) }) { return nil }
        return a.critical ? 95 : 60
    }

    /// Days until an inbox decision resolves on its own.
    static func daysLeft(_ d: Decision, today: Date) -> Int {
        d.deadline.map { max(0, GameCalendar.daysBetween(today, $0)) } ?? Alerts.inboxDays(d.kind)
    }

    /// The answer an inbox decision takes if it expires.
    static func defaultAnswer(_ d: Decision, _ s: GameState) -> String? {
        guard !d.options.isEmpty else { return nil }
        return d.options[Alerts.inboxDefault(d, s)].label
    }

    // MARK: Coming up

    struct Upcoming: Identifiable {
        enum Tone: Sendable { case good, bad, warning, neutral }
        var id: String
        var date: Date
        var title: String
        var detail: String
        var symbol: String
        var tone: Tone = .neutral
        var screen: Screen
        /// Rival launches: the rumoured window ("3–20 Mar", "Q3 2028"), shown instead of one date.
        var window: String? = nil
        /// Rival launches: the lab, so a click can open its profile.
        var labID: String? = nil
    }

    /// Dated things in the next `horizon` days, soonest first: training runs finishing, the next few rival launches,
    /// board-goal deadlines, bill votes, reservations ending, term sheets and enterprise leads expiring, hardware
    /// deliveries and datacenters coming online.
    static func upcoming(_ s: GameState, watch: [RivalIntel.Row], bonuses b: ResearchBonuses, horizon: Int = 182, rivals: Int = 3) -> [Upcoming] {
        let today = s.date
        let end = GameCalendar.addDays(today, horizon)
        var out: [Upcoming] = []
        func add(_ u: Upcoming) { if u.date >= today && u.date <= end { out.append(u) } }

        for run in s.runs where run.status == .running || run.status == .postTraining {
            guard let eta = runETA(run, s, bonuses: b) else { continue }
            if run.kind == .proxy {
                add(Upcoming(id: "run-\(run.id)", date: eta, title: "Scaling ladder for \(run.design.name) finishes",
                             detail: "Checks the recipe before the full run", symbol: "chart.line.uptrend.xyaxis", tone: .good, screen: .training))
            } else {
                let stage = run.status == .postTraining ? "Post-training: \(Training.currentStageName(run))" : "\(Fmt.pct(run.progress, decimals: 0)) of pre-training done"
                add(Upcoming(id: "run-\(run.id)", date: eta, title: "\(run.design.name) finishes training",
                             detail: stage + (run.forecast.map { " · forecast index \(Fmt.score($0.index))" } ?? ""),
                             symbol: "flask.fill", tone: .good, screen: .training))
            }
        }

        for r in watch.filter({ $0.outlook.center >= today && $0.outlook.center <= end }).prefix(rivals) {
            let o = r.outlook
            let tone: Upcoming.Tone
            let versus: String
            switch r.threat {
            case .passYou: tone = .bad; versus = "likely to pass you"
            case .close: tone = .warning; versus = "neck and neck with you"
            case .behind: tone = .neutral; versus = "behind your best"
            case .unknown: tone = .neutral; versus = "you have no model out yet"
            }
            add(Upcoming(id: "rival-\(r.id)", date: o.center, title: "\(r.project.name) from \(r.lab)",
                         detail: "Rumoured launch · forecast index \(Fmt.score(o.index)) (\(Fmt.score(o.indexLow))–\(Fmt.score(o.indexHigh))), \(versus)",
                         symbol: "binoculars.fill", tone: tone, screen: .rivalWatch, window: RivalIntel.windowText(o), labID: r.id))
        }

        for o in s.objectives where !o.done && !o.failed {
            let behind = o.progress < 0.7 && GameCalendar.daysBetween(today, o.deadline) < 60
            add(Upcoming(id: "goal-\(o.id)", date: o.deadline, title: "Board goal: \(o.title)",
                         detail: "\(Int((o.progress * 100).rounded()))% done" + (o.rewardCash > 0 ? " · pays \(Fmt.money(Board.reward(o, s)))" : ""),
                         symbol: o.kind.symbol, tone: behind ? .warning : .neutral, screen: .strategy))
        }

        for bill in s.bills {
            guard let def = PolicyCatalog.byID[bill.id] else { continue }
            let side = bill.stance == 0 ? "You haven't taken a side" : (bill.stance > 0 ? "You back it" : "You oppose it")
            add(Upcoming(id: "bill-\(bill.id)", date: bill.vote, title: "Vote on the \(def.title)",
                         detail: "\(side) · \(Fmt.pct(Policy.passChance(def, stance: bill.stance, s), decimals: 0)) likely to pass",
                         symbol: "building.columns.fill", tone: bill.stance == 0 ? .warning : .neutral, screen: .security))
        }

        for r in s.rentals {
            guard let e = r.end else { continue }
            let name = HardwareCatalog.get(r.accelID)?.name ?? r.accelID
            add(Upcoming(id: "rental-\(r.id)", date: e, title: "\(Fmt.int(r.count))× \(name) reservation ends",
                         detail: s.ops.autoRenew ? "The renewals delegate renews it just before it ends if its chips are in use; if they sit idle it lets it lapse" : "Renew it, or those chips leave your fleet",
                         symbol: "clock.badge.exclamationmark", tone: s.ops.autoRenew ? .neutral : .warning, screen: .compute))
        }

        for o in s.raiseOffers {
            add(Upcoming(id: "offer-\(o.id)", date: o.expires, title: "Term sheet from \(o.investor) expires",
                         detail: "\(Fmt.money(o.amount)) at \(Fmt.money(o.preMoney)) pre-money, \(Fmt.pct(o.amount / max(1, o.preMoney + o.amount), decimals: 1)) dilution",
                         symbol: "banknote.fill", tone: .warning, screen: .funding))
        }

        for d in s.deals where !d.active {
            add(Upcoming(id: "lead-\(d.id)", date: d.expires, title: "Lead from \(d.client) expires",
                         detail: "\(Fmt.money(d.monthly))/mo for \(d.months) months · needs index \(Fmt.score(d.minIndex))",
                         symbol: "briefcase.fill", screen: .market))
        }

        for o in s.orders {
            let name = HardwareCatalog.get(o.accelID)?.name ?? o.accelID
            add(Upcoming(id: "order-\(o.id)", date: o.made != nil ? AlienFab.nextShipment(o, s) : o.arrives,
                         title: o.made != nil ? "First of \(Fmt.int(o.count))× \(name) arrive" : "\(Fmt.int(o.count))× \(name) arrive",
                         detail: s.sites.first { $0.id == o.siteID }.map { "Delivered to \($0.name)" } ?? "Hardware order",
                         symbol: "shippingbox.fill", tone: .good, screen: .compute))
        }

        for site in s.sites {
            if site.ready > today {
                add(Upcoming(id: "site-\(site.id)", date: site.ready, title: "\(site.name) comes online",
                             detail: "\(Fmt.watts(site.capacityKW * 1000)) for your own chips", symbol: "building.columns.fill", tone: .good, screen: .datacenters))
            } else if let x = site.expansionReady, site.expanding > 0 {
                add(Upcoming(id: "expand-\(site.id)", date: x, title: "\(site.name) expansion comes online",
                             detail: "+\(Fmt.watts(site.expanding * 1000)) of power", symbol: "bolt.fill", tone: .good, screen: .datacenters))
            } else if let r = site.nextRamp, site.rampKW > 0 {
                add(Upcoming(id: "ramp-\(site.id)", date: r, title: "\(site.name): next leased tranche",
                             detail: "+\(Fmt.watts(min(site.rampKW, site.rampStepKW) * 1000)) handed over", symbol: "bolt.fill", tone: .good, screen: .datacenters))
            }
            if let end = site.leaseEnd, site.isTermLease, GameCalendar.daysBetween(today, end) <= 90 {
                add(Upcoming(id: "leaseend-\(site.id)", date: end, title: "\(site.name): lease term ends",
                             detail: site.leaseToOwn ? "The site becomes yours" : "It rolls over for a year at the market rate", symbol: "doc.text.fill", screen: .datacenters))
            }
        }
        for u in FoundingContracts.upcoming(s) { add(u) }   // 3.9: the founding award's deadlines
        // 3.5: power deals coming online.
        for c in s.powerContracts where c.online > today {
            add(Upcoming(id: "power-\(c.id)", date: c.online, title: "\(c.kind.rawValue): \(Fmt.watts(c.mw * 1e6)) online",
                         detail: c.location.name, symbol: c.kind.symbol, tone: .good, screen: .datacenters))
        }

        return out.sorted { $0.date != $1.date ? $0.date < $1.date : $0.id < $1.id }
    }

    /// When a training run should finish at its current speed: the same expectation its run card shows (cluster FLOPs
    /// times MFU, goodput and checkpoint overhead). Nil for paused runs and runs that won't finish.
    static func runETA(_ run: TrainingRun, _ s: GameState, bonuses b: ResearchBonuses) -> Date? {
        guard run.status == .running || run.status == .postTraining, let a = HardwareCatalog.get(run.design.accelID) else { return nil }
        let mfu = Physics.mfu(accel: a, chips: run.design.chips, state: s, bonuses: b)
        let good = Physics.goodput(chips: run.design.chips, state: s, bonuses: b, coverage: run.opsCoverage) * Sim.checkpointOverhead(run.interval)
        let perDay = Double(run.design.chips) * a.trainTFLOPS(run.design.precision) * 1e12 * mfu * good * run.schedule.speed * 86_400
        let remaining = max(0, run.flopsTotal - run.flopsDone) + max(0, run.postTrainFlops - run.postTrainDone)
        guard perDay > 0 else { return nil }
        let days = remaining / perDay
        guard days.isFinite, days < 3_650 else { return nil }
        return GameCalendar.addDays(s.date, Int(days.rounded(.up)))
    }

    /// "today", "tomorrow", "in 12 days", "in 3 months".
    static func daysText(_ days: Int) -> String {
        switch days {
        case ..<1: "today"
        case 1: "tomorrow"
        case 2..<60: "in \(days) days"
        default: "in \(Int((Double(days) / 30.44).rounded())) months"
        }
    }

    // MARK: The header

    struct Race {
        /// Your place among labs still in the race (nil until you release a model).
        var rank: Int?
        /// Labs in the race, you included.
        var labs: Int
        /// The gap to #1 (or your lead) in capability points and effective compute.
        var gap: String
    }

    /// Where you stand, from the lab rows the caller already has (`Leaderboard.labs`): the same rank and gap the
    /// leaderboard's standing card uses.
    static func race(_ labs: [Leaderboard.LabRow]) -> Race {
        let racing = labs.filter { $0.rank > 0 }
        let rivals = racing.filter { !$0.isPlayer }
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.flagship.capability > $1.flagship.capability }
        guard let me = racing.first(where: \.isPlayer), let mine = me.models.filter(\.released).max(by: { $0.index < $1.index }) else {
            let gap = rivals.first.map { "\($0.lab) leads with \($0.flagship.model). Release a model to enter the race." }
                ?? "No lab has released a model yet."
            return Race(rank: nil, labs: rivals.count + 1, gap: gap)
        }
        guard let first = rivals.first else { return Race(rank: me.rank, labs: racing.count, gap: "No rival has a model out yet.") }
        func compute(_ g: Double) -> String { BenchmarkCatalog.formatMultiple(BenchmarkCatalog.computeMultiple(capabilityGap: g)) }
        if me.rank == 1 {
            let lead = mine.capability - first.flagship.capability
            if lead >= 0.5 { return Race(rank: 1, labs: racing.count, gap: "\(Leaderboard.capabilityText(lead)) ahead of \(first.lab), about \(compute(lead)) the effective compute") }
            if lead > -0.5 { return Race(rank: 1, labs: racing.count, gap: "Level with \(first.lab) on capability; you edge it on the index") }
            return Race(rank: 1, labs: racing.count, gap: "You top the index, but \(first.lab) is \(Leaderboard.capabilityText(-lead)) ahead on capability")
        }
        let leader = racing.filter { $0.rank == 1 }.max { $0.flagship.capability < $1.flagship.capability } ?? first
        let gap = leader.flagship.capability - mine.capability
        if gap >= 0.5 {
            return Race(rank: me.rank, labs: racing.count, gap: "\(Leaderboard.capabilityText(gap)) behind \(leader.lab), about \(compute(gap)) the effective compute")
        }
        return Race(rank: me.rank, labs: racing.count, gap: "About as capable as \(leader.lab); it edges you on the index")
    }

    /// Last month's revenue per day against the month before (a fraction), counted the way the monthly briefing does.
    /// Nil until two months have closed or while there's no revenue.
    static func revenueChange(_ s: GameState) -> Double? {
        guard s.history.count >= 2 else { return nil }
        let cur = s.history[s.history.count - 1], prev = s.history[s.history.count - 2]
        let a = cur.revenue / Double(GameCalendar.daysInMonth(cur.month))
        let b = prev.revenue / Double(GameCalendar.daysInMonth(prev.month))
        guard b > 0 else { return nil }
        return a / b - 1
    }

    /// "Runway 7.5 months", "Cash-flow positive", or how long until bankruptcy when cash is negative.
    static func runwayText(_ s: GameState) -> String {
        if s.cash < 0 { return "Out of cash: bankrupt in \(max(0, 60 - s.daysNegativeCash)) days" }
        guard let m = Treasury.runwayMonths(s) else { return s.history.isEmpty ? "First month: no burn yet" : "Cash-flow positive" }
        return m > 48 ? "Runway 4+ years" : "Runway \(Fmt.trim(m, 1)) months"
    }
}
