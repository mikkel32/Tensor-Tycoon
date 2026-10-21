import Foundation

/// Things that need the player now: they show as banners with a link to the right screen, and the ones the player
/// chose can pause the game. Also the decision inbox: low-stakes offers wait there instead of stopping the clock,
/// and resolve themselves with their default answer when they expire.
enum AlertKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case cashNegative, bankruptcySoon, termSheet, offerExpiring, runPaused, rivalPassed, rivalLaunch
    case boardGoalDue, billVote, slaBreach, overCapacity, swarmAlignment, priceWar, rentalExpiring
    case inbox, milestone, briefing
    case world   // 3.4: world and stakeholders
    case advanced   // 3.5: advanced projects
    case corporate   // 3.5: corporate
    case noServing, swarmStopped   // 3.8: nothing serves your products; a swarm has no model

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cashNegative: "Cash goes negative"
        case .bankruptcySoon: "Bankruptcy, or under 90 days of cash"
        case .termSheet: "A term sheet arrives"
        case .offerExpiring: "An offer is about to expire"
        case .runPaused: "A training run stalls"
        case .rivalPassed: "A rival takes #1 from you"
        case .rivalLaunch: "A rival release beats your best model"
        case .boardGoalDue: "A board goal is due and behind"
        case .billVote: "A bill vote is coming and you haven't picked a side"
        case .slaBreach: "An enterprise contract is breaching its SLA"
        case .overCapacity: "A model is badly over capacity"
        case .swarmAlignment: "A swarm's alignment is slipping"
        case .priceWar: "A rival starts a price war"
        case .rentalExpiring: "Reserved cloud capacity is about to end"
        case .inbox: "A new offer lands in your inbox"
        case .milestone: "Milestones and achievements"
        case .briefing: "The monthly briefing is ready"
        case .world: "The world reacts: protests, regulators, grid emergencies"
        case .advanced: "Government contracts: awards, deliveries and trouble"
        case .corporate: "Corporate: covenant breaches, rating changes, subsidiaries"
        case .noServing: "No model is serving your chat app, agents or API"
        case .swarmStopped: "A swarm has no model to run on"
        }
    }

    var symbol: String {
        switch self {
        case .cashNegative, .bankruptcySoon: "exclamationmark.octagon.fill"
        case .termSheet, .offerExpiring: "banknote.fill"
        case .runPaused: "pause.circle.fill"
        case .rivalPassed, .rivalLaunch: "binoculars.fill"
        case .boardGoalDue: "person.3.fill"
        case .billVote: "building.columns.fill"
        case .slaBreach: "briefcase.fill"
        case .overCapacity: "flame.fill"
        case .swarmAlignment: "shield.lefthalf.filled"
        case .priceWar: "tag.slash.fill"
        case .rentalExpiring: "clock.badge.exclamationmark"
        case .inbox: "tray.full.fill"
        case .milestone: "star.circle.fill"
        case .briefing: "doc.text.fill"
        case .world: "globe.americas.fill"
        case .advanced: "building.columns.fill"
        case .corporate: "building.2.crop.circle.fill"
        case .noServing: "bolt.slash.fill"
        case .swarmStopped: "ant.fill"
        }
    }

    /// Whether the game pauses for it unless the player changes it.
    var pausesByDefault: Bool {
        switch self {
        case .cashNegative, .bankruptcySoon, .termSheet, .offerExpiring, .runPaused, .rivalPassed, .slaBreach, .swarmAlignment, .noServing:
            true
        default:
            false
        }
    }
}

struct GameAlert: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var date: Date
    var kind: String
    var title: String
    var body: String
    /// Screen raw value for the "Go" link.
    var screen: String
    var critical = false
    var celebrate = false
    var seen = false

    var alertKind: AlertKind { AlertKind(rawValue: kind) ?? .milestone }
    var target: Screen? { Screen(rawValue: screen) }
}

enum Alerts {
    /// Raise an alert. The same kind + key is raised at most once per `cooldown` days. A kind the player pauses on stops
    /// the clock at most once per `pauseCooldown` days: a problem that keeps coming back shows as a banner, not a stop.
    static func raise(_ s: inout GameState, _ kind: AlertKind, key: String = "", title: String, body: String, screen: Screen,
                      critical: Bool = false, celebrate: Bool = false, cooldown: Int = 30, pauseCooldown: Int = 0) {
        let k = "\(kind.rawValue)|\(key)"
        if let last = s.alertKeys[k], GameCalendar.daysBetween(last, s.date) < cooldown { return }
        s.alertKeys[k] = s.date
        s.alerts.insert(GameAlert(date: s.date, kind: kind.rawValue, title: title, body: body, screen: screen.rawValue,
                                  critical: critical, celebrate: celebrate), at: 0)
        if s.alerts.count > 40 { s.alerts.removeLast(s.alerts.count - 40) }
        if s.alertKeys.count > 400 {
            let cutoff = GameCalendar.addDays(s.date, -365)
            s.alertKeys = s.alertKeys.filter { $0.value > cutoff }
        }
        if s.pauseKinds.contains(kind.rawValue) {
            let pk = "pause|\(kind.rawValue)"
            if pauseCooldown <= 0 || (s.alertKeys[pk].map { GameCalendar.daysBetween($0, s.date) >= pauseCooldown } ?? true) {
                s.pauseRequested = true
                s.alertKeys[pk] = s.date
            }
        }
    }

    static let defaultPauseKinds: Set<String> = Set(AlertKind.allCases.filter(\.pausesByDefault).map(\.rawValue))
    /// Kinds added in 3.8, after saves first chose their pauses (SaveMigration gives them their default once).
    static let kinds38: Set<String> = [AlertKind.noServing.rawValue, AlertKind.swarmStopped.rawValue]

    /// Daily checks for situations nobody announces.
    static func daily(_ s: inout GameState) {
        let today = s.date
        // Money
        if s.cash < 0 && s.daysNegativeCash == 1 {
            raise(&s, .cashNegative, title: "You're out of cash", body: "Raise money, borrow, sell hardware or cut costs. Bankruptcy in 60 days if cash stays negative.",
                  screen: .funding, critical: true, cooldown: 20)
        }
        if s.cash < 0 && s.daysNegativeCash == 30 {
            raise(&s, .bankruptcySoon, title: "30 days to bankruptcy", body: "Cash has been negative for a month. Creditors take everything in 30 days.",
                  screen: .funding, critical: true, cooldown: 20)
        }
        for o in s.raiseOffers where GameCalendar.daysBetween(today, o.expires) == 3 {
            raise(&s, .offerExpiring, key: o.id.uuidString, title: "A term sheet expires in 3 days", body: "\(o.investor) offers \(Fmt.money(o.amount)) at \(Fmt.money(o.preMoney)) pre-money.",
                  screen: .funding, cooldown: 30)
        }
        // Reserved capacity that ends soon (shortage rebalancing will pull chips from your models and runs).
        // 3.8: two weeks' notice, naming what runs on those chips.
        for r in s.rentals where r.end.map({ (1...14).contains(GameCalendar.daysBetween(today, $0)) }) ?? false {
            let name = HardwareCatalog.get(r.accelID)?.name ?? r.accelID
            let users = chipUsers(s, r.accelID)
            let pool = Economy.pool(s, r.accelID)
            let short = (pool?.allocated ?? 0) > (pool?.total ?? 0) - r.count
            raise(&s, .rentalExpiring, key: r.id.uuidString, title: "\(Fmt.int(r.count))× \(name) reservation ends in \(GameCalendar.daysBetween(today, r.end ?? today)) days",
                  body: short && s.ops.autoRenew ? "Those chips are in use (\(users.isEmpty ? "your work runs on them" : users)), so the renewals delegate renews it just before it ends at that day's rate."
                      : short ? "When it ends those chips leave your fleet and \(users.isEmpty ? "what runs on them" : users) get cut back. Renew it on the Compute page, turn on the renewals delegate or buy hardware."
                              : "You have enough other \(name) to cover it, so nothing is cut back. Renew it only if you need the extra chips.",
                  screen: .compute, cooldown: 30)
        }
        // 3.8: decisions with real money in them that are about to resolve on their own.
        for d in s.decisions where !isUrgent(d) && moneyKinds.contains(d.kind) && d.amount >= max(5e6, max(0, s.cash) * 0.002) {
            guard let dl = d.deadline, (1...3).contains(GameCalendar.daysBetween(today, dl)), !d.options.isEmpty else { continue }
            raise(&s, .offerExpiring, key: "inbox|\(d.id.uuidString)", title: "Expires in \(GameCalendar.daysBetween(today, dl)) days: \(d.title)",
                  body: "About \(Fmt.money(d.amount)) is at stake. If you don't answer it resolves as \"\(d.options[inboxDefault(d, s)].label)\". Open the inbox on the Dashboard.",
                  screen: .dashboard, critical: true, cooldown: 365)
        }
        // 3.8: a leased block's next tranche steps the rent up on its own: say so a month ahead, while it can still be deferred.
        for site in s.sites where site.isTermLease && site.rampKW > 0 {
            guard let next = site.nextRamp, (1...30).contains(GameCalendar.daysBetween(today, next)) else { continue }
            let rent = DCMarket.trancheRent(site)
            guard rent >= 2e6 else { continue }
            let rev = s.history.suffix(3).reduce(0) { $0 + $1.revenue } / Double(max(1, s.history.suffix(3).count))
            raise(&s, .offerExpiring, key: "tranche|\(site.id.uuidString)|\(next.timeIntervalSince1970)", title: "\(site.name): rent steps up \(Fmt.money(rent))/month on \(next.gameShort)",
                  body: "The next \(Fmt.watts(min(site.rampKW, site.rampStepKW) * 1000)) is handed over then and its rent starts. Your revenue is about \(Fmt.money(rev))/month. Defer it a quarter or decline what's left on the Datacenters page.",
                  screen: .datacenters, critical: rent > rev * 0.5, cooldown: 365)
        }
        runway(&s)
        // Board goals
        for o in s.objectives where !o.done && !o.failed && GameCalendar.daysBetween(today, o.deadline) == 30 && o.progress < 0.7 {
            raise(&s, .boardGoalDue, key: o.id.uuidString, title: "Board goal due in 30 days", body: "\(o.title) — \(Int(o.progress * 100))% done.", screen: .strategy, cooldown: 60)
        }
        // Bills you haven't taken a side on
        for b in s.bills where b.stance == 0 && GameCalendar.daysBetween(today, b.vote) == 14 {
            let title = PolicyCatalog.byID[b.id]?.title ?? b.id
            raise(&s, .billVote, key: b.id, title: "Vote on the \(title) in two weeks", body: "You haven't picked a side. Back it, oppose it or stay out on the Security & Policy page.",
                  screen: .security, cooldown: 60)
        }
        // Enterprise SLAs: one alert for every contract in trouble (they usually share a model, so they breach together).
        // It stops the clock at most every 60 days; in between it's a banner.
        let breaching = s.deals.filter { $0.active && $0.breaches >= 2 }.sorted { $0.breaches > $1.breaches }
        if let worst = breaching.first {
            let more = breaching.count > 1 ? " \(breaching.count - 1) more contract\(breaching.count > 2 ? "s are" : " is") breaching too." : ""
            // 3.9: a contract with no model that meets its bar can't be fixed with chips.
            let fix = worst.modelID == nil
                ? "No released model meets \(worst.client)'s Intelligence Index of \(Fmt.score(worst.minIndex)): release a better model, or they cancel at month end."
                : (s.ops.autoscale ? "The capacity delegate has run out of free chips: buy or rent hardware, or take chips from training."
                                   : "Give its model more serving chips, or turn on the capacity delegate.")
            if worst.breaches >= 5 {
                raise(&s, .slaBreach, key: "cancel", title: "\(worst.client) is about to cancel",
                      body: "\(worst.breaches) SLA breaches this month; one more bad day or two and they walk.\(more) \(fix)",
                      screen: .market, critical: true, cooldown: 25, pauseCooldown: 60)
            } else {
                raise(&s, .slaBreach, key: "breach",
                      title: breaching.count > 1 ? "\(breaching.count) enterprise contracts are breaching their SLAs" : "\(worst.client) contract is breaching its SLA",
                      body: "\(worst.client): \(worst.breaches) breaches this month (more than six and they cancel).\(more) \(fix)",
                      screen: .market, cooldown: 21, pauseCooldown: 60)
            }
        }
        noServingCheck(&s)
        // Weekly: capacity, swarms
        guard GameCalendar.components(today).day % 7 == 1 else { return }
        if let m = s.models.filter({ $0.released && !$0.retired && $0.capacityTokensDay > 0 && $0.demandTokensDay > $0.capacityTokensDay * 1.3 })
            .max(by: { $0.demandTokensDay < $1.demandTokensDay }) {
            let load = Int(m.demandTokensDay / m.capacityTokensDay * 100)
            raise(&s, .overCapacity, key: m.id.uuidString, title: "\(m.name) is turning users away",
                  body: s.ops.autoscale
                      ? "Demand is \(load)% of capacity and the capacity delegate has no free chips left\(s.ops.rentBudget > 0 ? " or cloud budget" : "")."
                        + " Buy or rent hardware, \(s.ops.rentBudget > 0 ? "raise" : "give it") a cloud budget, or take chips from training."
                      : "Demand is \(load)% of capacity. Users churn and reliability falls. Add inference chips or let the capacity delegate handle it.",
                  screen: .models, cooldown: 30)
        }
        if let sw = s.swarms.filter({ !$0.paused && $0.alignmentMeasured < 40 }).min(by: { $0.alignmentMeasured < $1.alignmentMeasured }) {
            raise(&s, .swarmAlignment, key: sw.id.uuidString, title: "\(sw.name) alignment at \(Int(sw.alignmentMeasured))",
                  body: "Collusion and escapes get likely below 30. Raise oversight, audit or purge.", screen: .swarms, critical: sw.alignmentMeasured < 25, cooldown: 30)
        }
    }

    /// 3.8: nothing serves your products. Chat has no model while people still use it, or every live released model
    /// has no servers: chat, agents and the API are dark and revenue falls toward zero.
    static func noServingCheck(_ s: inout GameState) {
        let live = s.models.filter { $0.released && !$0.retired }
        let noChat = s.chatModelID == nil && s.consumerUsers >= 1
        let dark = !live.isEmpty && (s.consumerUsers >= 1 || s.lastLiveDemand > 0) && !live.contains { $0.capacityTokensDay > 0 || $0.deployments.contains { $0.chips > 0 } }
        let noneLive = live.isEmpty && s.models.contains { $0.released } && (s.consumerUsers >= 1 || s.lastLiveDemand > 0)
        guard noChat || dark || noneLive else { return }
        let why: String, fix: String
        if noneLive {
            why = "Every released model is retired, so chat, agents and the API are dark."
            fix = "Open Models, tick \"Show retired\" and press \"Bring back\" on your best model (or release a new one)."
        } else if dark {
            why = "None of your live models has servers, so no request is answered."
            fix = "Give a model serving chips on Models, or turn on the capacity delegate."
        } else {
            why = "No model powers the chat app, so its users get nothing."
            fix = "Pick a model for chat on Models, or bring a retired one back."
        }
        raise(&s, .noServing, title: "Nothing is serving your customers",
              body: "\(why) Users leave and revenue falls toward $0 until this is fixed. \(fix)", screen: .models, critical: true, cooldown: 14, pauseCooldown: 30)
    }

    /// Names of the models, runs and swarms using `accelID` chips.
    static func chipUsers(_ s: GameState, _ accelID: String) -> String {
        var names: [String] = s.models.filter { !$0.retired && $0.deployments.contains { $0.accelID == accelID } }.map(\.name)
        names += s.runs.filter { ($0.status == .running || $0.status == .postTraining) && $0.design.accelID == accelID }.map { "the \($0.design.name) run" }
        names += s.swarms.filter { !$0.paused && $0.accelID == accelID }.map(\.name)
        let shown = names.prefix(4).joined(separator: ", ")
        return names.count > 4 ? shown + " and \(names.count - 4) more" : shown
    }

    /// 3.8: cash ÷ the last three months' net burn (recurring cash out less recurring cash in, capex included) with the
    /// lease tranches due within 90 days added. Under 90 days stops the clock once a month and names the biggest lines.
    /// 3.9: the burn is `Treasury.netBurn`, the same number the Cash tile, board and briefing use.
    static func runway(_ s: inout GameState) {
        guard s.cash > 0, s.history.count >= 2 else { return }
        let burn = Treasury.netBurn(s)
        guard burn > 0 else { return }
        let days = s.cash / burn * 30.4
        guard days < 90 else { return }
        let h = Array(s.history.suffix(3))
        let n = Double(h.count)
        func avg(_ f: (MonthRecord) -> Double) -> Double { h.reduce(0) { $0 + f($1) } / n }
        var lines: [(String, Double)] = [("rent", avg(\.costRent)), ("power", avg(\.costPower)), ("datacenter leases", avg(\.costSites)), ("payroll", avg(\.costPayroll)),
                                         ("data", avg(\.costData)), ("marketing", avg(\.costMarketing)), ("interest", avg(\.costInterest)), ("taxes", avg(\.taxes)),
                                         ("hardware and construction", avg(\.capex)), ("chip design", avg(\.costChipDesign)), ("agent organisations", avg(\.costAgentOrgs)),
                                         ("other costs", avg { $0.costOther + $0.costChips + $0.costGroup })]
        let tranche = Treasury.trancheRentDue(s)
        if tranche > 0 { lines.append(("lease tranches due soon", tranche)) }
        let top = lines.sorted { $0.1 > $1.1 }.prefix(3).filter { $0.1 > 0 }.map { "\($0.0) \(Fmt.money($0.1))/mo" }.joined(separator: ", ")
        raise(&s, .bankruptcySoon, key: "runway", title: "About \(Int(days)) days of cash left",
              body: "You lose about \(Fmt.money(burn)) a month net and hold \(Fmt.money(s.cash)). Biggest costs: \(top). Raise money, cut costs or defer lease tranches.",
              screen: .funding, critical: true, cooldown: 30, pauseCooldown: 30)
    }

    // MARK: Decision inbox

    /// Decisions that wait in the inbox instead of pausing the game, with the option taken if they expire.
    static let inboxDefaults: [String: Int] = [
        "rival_round": 2, "partner_offer": 2, "policy_bill": 2, "sovereign_deal": 1, "exclusive_supply": 1,
        "spinoff": 0, "poach": 1, "merger_offer": 1, "defense": 1, "moonshot": 2, "fire_sale": 1,
        "world_summons": 1, "world_inquiry": 1, "world_partnership": 1,   // 3.4: world and stakeholders
        "fun_cfp": 0, "fun_keynote": 1,   // 3.5: fun systems
        "hq_grant": 0, "hq_partner": 1, "hq_contract": 1,   // 3.5: headquarters
        AdvancedProjects.secrecyKind: 0,   // 3.5: keep a classified discovery classified
        "alien_errata": 0,   // 3.5: alien fab
        "data_auction": 2, "data_collection": 1, "data_lawsuit": 1,   // 3.6: data economy
        "corp_funding": 1, "corp_covenant": 2, "corp_downgrade": 2, "corp_audit": 0,   // 3.5: corporate
        Semis.bugKind: 0, Semis.shockKind: 0, Semis.orderKind: 2, Semis.rivalKind: 1,   // 3.5: semiconductors
        "sci_report": 0,   // 3.6: science labs (patent and license)
        Families.decisionKind: 0,   // 3.5: model families — route free chat users to a cheaper tier
        Nations.poachKind: 0,   // 3.7: match a rival's offer to one of your researchers
        Stars.offerKind: 3, Stars.burnoutKind: 1, Stars.boomerangKind: 1, Stars.raidKind: 1,   // 3.9: talk, lighten the load, pass, walk away
        Launches.decisionKind: 1,   // 3.7: a weak launch — let it ride
    ]

    static func isUrgent(_ d: Decision) -> Bool { inboxDefaults[d.kind] == nil }

    /// 3.8: the answer an expired inbox decision takes. Never the one that spends cash or destroys an asset when a cheaper
    /// one exists: a covenant breach takes the no-cash penalty rate (not a $500M waiver), a data lawsuit the cheaper settlement,
    /// a spin-off request keeps the star, a subsidiary out of cash raises outside (or is funded when that's small change)
    /// instead of being wound down. 3.9: a spin-off request keeps the star with a raise when the 0.5% grant is worth more
    /// than five years of it (at a $3T valuation the grant was $15B).
    static func inboxDefault(_ d: Decision, _ s: GameState) -> Int {
        var pick = inboxDefaults[d.kind] ?? d.options.count - 1
        if d.kind == "spinoff", let star = s.employees.first(where: { $0.id.uuidString == d.ref }),
           s.valuation * 0.005 > star.salary * 0.5 * 5 {
            pick = 1
        }
        if d.kind == "corp_funding" {
            let sub = s.corp.subs.first { $0.id == d.ref }
            if let sub, sub.valuation >= d.amount * 1.5 { pick = 1 }
            else if d.amount <= max(0, s.cash) * 0.01 { pick = 0 }
            else { pick = 2 }
        }
        return max(0, min(d.options.count - 1, pick))
    }

    /// Decisions whose default answer can cost real money: their `amount` is the cost, and one alert warns before they expire.
    static let moneyKinds: Set<String> = ["corp_covenant", "corp_funding", "corp_audit", "data_lawsuit", "spinoff"]

    /// How long an inbox decision waits for an answer.
    static func inboxDays(_ kind: String) -> Int { kind == "policy_bill" ? 30 : 21 }

    // MARK: Standing answers

    /// Decisions that repeat with the same choices, so "always answer this way" makes sense — and their names.
    static let rememberable: [String: String] = [
        "talent_raid": "Talent raids", "rival_round": "Invitations to rival funding rounds", "partner_offer": "Partner offers",
        "sovereign_deal": "Sovereign AI deals", "poach": "Rival researchers asking to join", "spinoff": "Spin-off requests",
        "distill_campaign": "Distillation campaigns against your API", "jailbreak": "Viral jailbreaks", "policy_bill": "New bills",
        "loss_spike": "Loss spikes in training", "contamination": "Benchmark contamination", "fault_storm": "Hardware fault storms",
        "train_bug": "Bugs found mid-run", "sycophancy": "Sycophancy after RLHF", "reward_hack": "Reward hacking in RL",
        "trade_secret": "Trade-secret suits over researchers you hired",
        Nations.poachKind: "Rival offers to one of your researchers",   // 3.7
        AdvancedProjects.secrecyKind: "Classified discoveries from government programmes",
    ]

    /// Answer decisions the player has a standing answer for (end of day, before the clock checks for urgent ones).
    static func applyStandingAnswers(_ s: inout GameState) {
        guard !s.standingAnswers.isEmpty else { return }
        let due = s.decisions.filter { s.standingAnswers[$0.kind] != nil }
        for d in due {
            guard let option = s.standingAnswers[d.kind], d.options.indices.contains(option),
                  Events.optionBlocker(d, option, s) == nil else { continue }   // 3.9: can't afford it today: leave it for you
            let label = d.options[option].label
            s.resolveDecision(d.id, option: option)
            Sim.news(&s, "Standing answer: \(d.title)", "You'd said to always answer these \"\(label)\". Change it on the Operations page.", .company)
        }
    }

    /// Expired inbox items resolve with their default answer.
    static func expireInbox(_ s: inout GameState) {
        let today = s.date
        let expired = s.decisions.filter { !isUrgent($0) && $0.deadline.map { $0 <= today } ?? false }
        for d in expired {
            var option = inboxDefault(d, s)
            // 3.9: never expire into an answer that can only fail (an investment you can't pay for): take one that works.
            if Events.optionBlocker(d, option, s) != nil, let ok = d.options.indices.last(where: { Events.optionBlocker(d, $0, s) == nil }) { option = ok }
            let label = d.options.indices.contains(option) ? d.options[option].label : "the default"
            s.resolveDecision(d.id, option: option)
            Sim.news(&s, "Inbox: \(d.title)", "You didn't answer in time, so it resolved as \"\(label)\".", .company)
        }
    }
}

// MARK: - Player actions

extension GameState {
    mutating func setPauseOn(_ kind: AlertKind, _ on: Bool) {
        if on { pauseKinds.insert(kind.rawValue) } else { pauseKinds.remove(kind.rawValue) }
    }

    mutating func markAlertsSeen() {
        for i in alerts.indices { alerts[i].seen = true }
    }

    mutating func dismissAlert(_ id: UUID) {
        if let i = alerts.firstIndex(where: { $0.id == id }) { alerts[i].seen = true }
    }

    mutating func setBillStance(_ id: String, _ stance: Int) -> String? { Policy.setStance(&self, id, stance) }

    /// Always answer this kind of decision with `option` (nil forgets it).
    mutating func setStandingAnswer(_ kind: String, _ option: Int?, label: String = "") {
        standingAnswers[kind] = option
        standingLabels[kind] = option == nil ? nil : label
    }

    /// Hide a Chief of Staff item for a while.
    mutating func snoozeAdvice(_ id: String, days: Int) {
        snoozed[id] = GameCalendar.addDays(date, days)
    }
}
