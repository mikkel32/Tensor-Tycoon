import Foundation

/// Things that need the player now: they show as banners with a link to the right screen, and the ones the player
/// chose can pause the game. Also the decision inbox: low-stakes offers wait there instead of stopping the clock,
/// and resolve themselves with their default answer when they expire.
enum AlertKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case cashNegative, bankruptcySoon, termSheet, offerExpiring, runPaused, rivalPassed, rivalLaunch
    case boardGoalDue, billVote, slaBreach, overCapacity, swarmAlignment, priceWar, rentalExpiring
    case inbox, milestone, briefing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cashNegative: "Cash goes negative"
        case .bankruptcySoon: "30 days from bankruptcy"
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
        }
    }

    /// Whether the game pauses for it unless the player changes it.
    var pausesByDefault: Bool {
        switch self {
        case .cashNegative, .bankruptcySoon, .termSheet, .offerExpiring, .runPaused, .rivalPassed, .slaBreach, .swarmAlignment:
            true
        default:
            false
        }
    }
}

struct GameAlert: Codable, Identifiable, Hashable {
    var id = UUID()
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
        for r in s.rentals where r.end.map({ GameCalendar.daysBetween(today, $0) == 7 }) ?? false {
            let name = HardwareCatalog.get(r.accelID)?.name ?? r.accelID
            raise(&s, .rentalExpiring, key: r.id.uuidString, title: "\(Fmt.int(r.count))× \(name) reservation ends in a week",
                  body: "When it ends those chips leave your fleet: serving and training on them get cut back. Renew it or buy hardware.", screen: .compute, cooldown: 30)
        }
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
            let fix = s.ops.autoscale ? "The capacity delegate has run out of free chips: buy or rent hardware, or take chips from training."
                                      : "Give its model more serving chips, or turn on the capacity delegate."
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

    // MARK: Decision inbox

    /// Decisions that wait in the inbox instead of pausing the game, with the option taken if they expire.
    static let inboxDefaults: [String: Int] = [
        "rival_round": 2, "partner_offer": 2, "policy_bill": 2, "sovereign_deal": 1, "exclusive_supply": 1,
        "spinoff": 2, "poach": 1, "merger_offer": 1, "defense": 1, "moonshot": 2, "fire_sale": 1,
    ]

    static func isUrgent(_ d: Decision) -> Bool { inboxDefaults[d.kind] == nil }

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
    ]

    /// Answer decisions the player has a standing answer for (end of day, before the clock checks for urgent ones).
    static func applyStandingAnswers(_ s: inout GameState) {
        guard !s.standingAnswers.isEmpty else { return }
        let due = s.decisions.filter { s.standingAnswers[$0.kind] != nil }
        for d in due {
            guard let option = s.standingAnswers[d.kind], d.options.indices.contains(option) else { continue }
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
            let option = min(d.options.count - 1, inboxDefaults[d.kind] ?? d.options.count - 1)
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
