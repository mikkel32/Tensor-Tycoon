import Foundation

// MARK: - 3.9: the anchor contract, inbox decisions and player actions for the government marketplace

extension GovMarket {
    // MARK: Anchor offer

    /// The offer's annual value for this lab today: the year's public budgets and the lab's size (a lab with real
    /// revenue is offered a bigger agreement; no more than ten times the starter size).
    static func anchorScale(_ s: GameState) -> Double {
        let size = clamp(pow(max(1, Economy.runRate(s) / 5e6), 0.3), 1, 10)
        return era(s.year) * max(size, AdvancedProjects.companyScale(s))
    }

    /// The team the agreement needs: bigger for a bigger lab's bigger agreement; a garage-sized lab can't spare more
    /// than a third of its people, and is offered a correspondingly smaller agreement.
    static func anchorStaff(_ o: GovMarketCatalog.AnchorOffer, scale: Double, cap: Int = 99) -> [String: Int] {
        let mult = clamp(scale, 1, 4)
        var out: [String: Int] = [:]
        var left = max(1, cap)
        for (r, n) in o.staff where left > 0 {
            let take = min(left, max(1, Int((Double(n) * mult).rounded())))
            out[r.rawValue, default: 0] += take
            left -= take
        }
        return out
    }

    /// Headcount a lab can put on it: a third of its staff when that's fewer than the offer asks.
    static func anchorCap(_ s: GameState) -> Int { s.employees.count < 9 ? max(1, s.employees.count / 3) : 99 }

    /// Annual value: the offer's rate per person (the year's prices) times the team it needs, so a bigger lab gets a
    /// bigger agreement with more people on it rather than a richer one.
    static func anchorAnnual(_ o: GovMarketCatalog.AnchorOffer, scale: Double, cap: Int, year: Double) -> Double {
        let base = Double(o.staff.reduce(0) { $0 + $1.1 })
        let got = Double(anchorStaff(o, scale: scale, cap: cap).values.reduce(0, +))
        return (o.annual * era(year) * got / max(1, base) / 10_000).rounded() * 10_000
    }

    static func staffText(_ staff: [String: Int]) -> String {
        staff.sorted { $0.key < $1.key }.map { "\($0.value) \($0.value == 1 ? (Role(rawValue: $0.key)?.title.lowercased() ?? $0.key) : (Role(rawValue: $0.key)?.plural.lowercased() ?? $0.key))" }.joined(separator: ", ")
    }

    /// The founding offer: two funded agreements to choose from (or neither), in the first days of the game.
    static func offerAnchor(_ s: inout GameState) {
        s.govMarket.anchorOffered = true
        let offers = GovMarketCatalog.anchorOffers(HQ.country(s).id, region: HQ.region(s))
        guard offers.count >= 2 else { return }
        let scale = anchorScale(s)
        let cap = anchorCap(s)
        // The neutral answer comes first (and is what an unanswered inbox item takes).
        var opts: [DecisionOption] = [DecisionOption(label: "Not now", detail: "Keep everyone on your own research. The marketplace stays open.")]
        var amounts: [String] = []
        for o in offers.prefix(2) {
            let annual = anchorAnnual(o, scale: scale, cap: cap, year: s.year)
            amounts.append(String(Int(annual)))
            let a = AgencyCatalog.byID[o.agency]
            let years = o.options + 1
            let pay = o.payment == .invoice ? "invoiced monthly" : "35% pre-financing, then yearly instalments"
            opts.append(DecisionOption(label: "Sign with \(a?.short ?? o.agency): \(Fmt.money(annual))/yr",
                                       detail: "\(o.title). Up to \(years) years (\(o.payment == .invoice ? "a base period and \(o.options) option\(o.options == 1 ? "" : "s"), renewed each budget year" : "\(years) yearly reporting periods")), \(pay). Needs \(staffText(anchorStaff(o, scale: scale, cap: cap))) on it\(o.defence ? "; defence work" : "")."))
        }
        let c = HQ.country(s)
        Events.addDecision(&s, kind: anchorKind, title: s.founding.current == nil ? "Your first government contract" : "A multi-year government contract",
                           body: "Two \(c.adjective) public buyers want to work with \(s.companyName). \(offers[0].pitch) Or: \(offers[1].pitch.prefix(1).lowercased() + offers[1].pitch.dropFirst()) A contract like this gives you a budget you can count on, a past-performance record for bigger bids, and a customer who will call when year-end money turns up — at the cost of the people you put on it.",
                           image: homeImage(s), options: opts, amount: 0, ref: (amounts + [String(cap)]).joined(separator: "|"))
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch d.kind {
        case anchorKind:
            guard option > 0 else {
                s.govMarket.anchorDeclined = true
                Sim.news(&s, "No government contract for now", "The marketplace stays open on the Gov Contracts page: small-business awards, grants and compute allocations.", .company)
                return
            }
            let offers = GovMarketCatalog.anchorOffers(HQ.country(s).id, region: HQ.region(s))
            let amounts = d.ref.split(separator: "|").compactMap { Double($0) }
            let pick = option - 1
            guard offers.indices.contains(pick) else { return }
            let cap = amounts.count >= 3 ? Int(amounts[2]) : anchorCap(s)
            signAnchor(&s, offers[pick], annual: amounts.indices.contains(pick) ? amounts[pick] : anchorAnnual(offers[pick], scale: anchorScale(s), cap: cap, year: s.year), cap: cap)
        case yearEndKind:
            guard option == 1 else { return }
            let parts = d.ref.split(separator: "|", maxSplits: 2).map(String.init)
            guard parts.count == 3, let a = AgencyCatalog.byID[parts[0]] else { return }
            let k = GovMarketCatalog.kind(a.kind == .defence ? "cso" : "task") ?? GovMarketCatalog.kinds[0]
            var o = make(k, a, &s, key: "yearend|\(d.id.uuidString)", invited: true, valueOverride: d.amount, customer: "")
            o.sol.title = parts[2]
            o.sol.template = a.kind == .defence ? "gm_proto" : "gm_task"
            o.sol.months = Int(parts[1]) ?? 6
            o.sol.staff = [Role.mlEngineer.rawValue: 1, Role.data.rawValue: 1]
            o.sol.followOn = true
            o.effort = CaptureEffort.light.rawValue
            o.price = 1
            o.submitted = s.date
            o.oddsAtSubmit = 1
            o.finalOdds = 1
            o.decided = s.date
            o.winner = s.companyName
            o.debrief = ["Sole-source year-end order: no competition."]
            s.govMarket.engaged = true
            s.govMarket.opps.append(o)
            award(&s, s.govMarket.opps.count - 1)
        case protestKind:
            guard option == 1, let i = s.govMarket.opps.firstIndex(where: { $0.id == d.ref }), s.govMarket.opps[i].status == .lost else { return }
            let o = s.govMarket.opps[i]
            let cost = protestCost(o)
            guard s.cash >= cost else {
                Sim.news(&s, "No protest filed", "You couldn't pay the \(Fmt.money(cost)) in legal fees.", .company, good: false)
                return
            }
            s.cash -= cost
            s.month.costOther += cost
            s.govMarket.protestsFiled += 1
            s.govMarket.opps[i].status = .protesting
            s.govMarket.opps[i].protestFiled = s.date
            s.govMarket.opps[i].protestCost = cost
            let review = o.def?.challenge == "review"
            s.govMarket.opps[i].protestDue = GameCalendar.addDays(s.date, review ? 60 : (o.def?.challenge == "complaint" ? 75 : 100))
            s.govMarket.losses = max(0, s.govMarket.losses - 1)
            Sim.news(&s, review ? "Evaluation review requested: \(o.sol.title)" : "Protest filed: \(o.sol.title)",
                     review ? "The review committee will report within about two months." : "\(Fmt.money(cost)) in legal fees. A decision is due by \(s.govMarket.opps[i].protestDue!.gameShort).", .company)
        default:
            break
        }
    }

    // MARK: Anchor contract

    /// The end of the budget year an anchor period runs to: 30 September for US agencies, 31 December in Europe; a
    /// period shorter than five months runs on to the next year end. Grant-style contracts report every 12 months.
    static func periodEnd(_ s: GameState, agency: String, from start: Date, payment: AnchorPayment) -> Date {
        if payment == .tranche { return GameCalendar.addMonths(start, 12) }
        let us = AgencyCatalog.byID[agency]?.region == .us
        let c = GameCalendar.components(start)
        var end = us ? GameCalendar.date(c.month >= 10 ? c.year + 1 : c.year, 9, 30) : GameCalendar.date(c.year, 12, 31)
        if GameCalendar.daysBetween(start, end) < 150 { end = GameCalendar.addMonths(end, 12) }
        return end
    }

    static func signAnchor(_ s: inout GameState, _ o: GovMarketCatalog.AnchorOffer, annual: Double, cap: Int) {
        let scale = anchorScale(s)
        var c = AnchorContract(agency: o.agency, title: o.title, scope: o.scope, defence: o.defence, start: s.date,
                               periodEnd: periodEnd(s, agency: o.agency, from: s.date, payment: o.payment), optionsLeft: o.options, optionsTotal: o.options,
                               annual: annual, staff: anchorStaff(o, scale: scale, cap: cap), payment: o.payment)
        let a = AgencyCatalog.byID[o.agency]
        if o.payment == .tranche {
            c.total = annual * Double(o.options + 1)
            let pre = (c.total * 0.35 / 1_000).rounded() * 1_000
            c.paid = pre
            pay(&s, pre)
            c.history.append(ProgrammeEvent(date: s.date, text: "Signed. Pre-financing of \(Fmt.money(pre)) paid (35% of \(Fmt.money(c.total))).", tone: 1))
        } else {
            c.history.append(ProgrammeEvent(date: s.date, text: "Signed: \(Fmt.money(annual))/yr, base period to \(c.periodEnd.gameShort), \(o.options) option\(o.options == 1 ? "" : "s").", tone: 1))
        }
        s.govMarket.anchor = c
        s.govMarket.engaged = true
        _ = s.autoStaffAnchor()
        if o.defence {
            // Some of the safety team mind defence work, a little.
            for i in s.employees.indices where s.employees[i].role == .safety { s.employees[i].morale = max(0, s.employees[i].morale - 4) }
        }
        if let a { Stakeholders.move(&s, [a.region.rawValue: 1], "Signed a government contract with \(a.short)") }
        Sim.news(&s, "Contract signed with \(a?.short ?? o.agency): \(o.title)",
                 "\(Fmt.money(annual)) a year\(o.payment == .tranche ? ", paid in instalments" : ", invoiced monthly"). \(o.scope) The team: \(staffText(c.staff)). Delivery is rated every year; a good rating means the options get exercised.",
                 .company, image: homeImage(s), important: true, good: true)
    }

    static func pay(_ s: inout GameState, _ amount: Double) {
        guard amount > 0 else { return }
        s.cash += amount
        s.month.revContracts += amount
        s.lifetimeRevenue += amount
    }

    /// How fully the assigned team covers what the agency expects (0–1.1), as Advanced Projects scores programme teams.
    static func delivery(_ c: AnchorContract, _ s: GameState) -> Double {
        let team = s.employees.filter { c.assigned.contains($0.id) }
        var parts: [Double] = []
        var covered = true
        for (k, n) in c.staff.sorted(by: { $0.key < $1.key }) {
            guard let role = Role(rawValue: k), n > 0 else { continue }
            let mine = team.filter { $0.role == role }
            let have = mine.reduce(0.0) { $0 + $1.skill / 60 * $1.traitMultiplier * (0.7 + $1.morale / 250) }
            parts.append(min(1.2, have / Double(n)))
            if mine.isEmpty { covered = false }
        }
        guard !parts.isEmpty else { return 1 }
        return min(1.1, parts.reduce(0, +) / Double(parts.count) * (covered ? 1 : 0.45))
    }

    static func rating(_ score: Double) -> String {
        score >= 1.0 ? "Exceptional" : (score >= 0.9 ? "Very good" : (score >= 0.75 ? "Satisfactory" : (score >= 0.5 ? "Marginal" : "Unsatisfactory")))
    }

    static func log(_ c: inout AnchorContract, _ d: Date, _ text: String, _ tone: Int = 0) {
        c.history.append(ProgrammeEvent(date: d, text: text, tone: tone))
        if c.history.count > 60 { c.history.removeFirst(c.history.count - 60) }
    }

    /// First of the month: the team works (or a lapse stops it), the month is billed, and a period that has ended is
    /// rated and its option exercised — or not.
    static func anchorMonth(_ s: inout GameState) {
        guard var c = s.govMarket.anchor, c.status == .active, let a = AgencyCatalog.byID[c.agency] else { return }
        let ids = Set(s.employees.map(\.id))
        c.assigned.removeAll { !ids.contains($0) }
        let f = fiscal(s, agency: a)
        if f.phase == .lapse {
            if !c.stopped { log(&c, s.date, "Stop-work order: \(a.short)'s appropriations lapsed. No billing until it reopens.", -1) }
            c.stopped = true
            c.stoppedDays += 30
            s.govMarket.anchor = c
            alert(&s, "anchorstop|\(c.id)", "Stop-work on \(c.title)", "\(a.short) is shut down: the team can't bill until funding is restored (\(untilText(f, s))).", critical: true)
            return
        }
        if c.stopped { log(&c, s.date, "Stop-work lifted: funding restored.", 1); c.stopped = false }
        if c.awaitingOption {
            c.awaitingOption = false
            exercise(&s, &c, a, f)
            if c.status != .active { finish(&s, c); return }
        }
        let d = delivery(c, s)
        let earned = c.annual / 12 * min(1, d)
        c.earned += earned
        c.periodEarned += earned
        c.periodDelivery.append(d)
        if c.payment == .invoice {
            c.paid += earned
            pay(&s, earned)
        }
        // Cloud, travel and reporting: about a sixth of what the month earns.
        let direct = earned * 0.16
        s.cash -= direct
        s.month.costOther += direct
        if d < 0.6 {
            c.underStaffedMonths += 1
            if c.underStaffedMonths == 2 && !c.cureNotice {
                c.cureNotice = true
                log(&c, s.date, "Cure notice: \(a.short) says the team is too thin to deliver. Two more months like this and it terminates for default.", -1)
                alert(&s, "anchorcure|\(c.id)", "Cure notice on \(c.title)", "Put \(staffText(c.staff)) on it, or \(a.short) terminates for default.", critical: true)
            } else if c.underStaffedMonths >= 4 {
                c.status = .terminated
                log(&c, s.date, "Terminated for default: four months without the team the contract requires.", -1)
                s.advanced.ratings[c.agency] = clamp(AdvancedProjects.rating(s, c.agency) - 3, -10, 10)
                s.govMarket.assessments.insert(GovAssessment(date: s.date, agency: c.agency, contract: c.title, score: 0.3, rating: "Unsatisfactory (default)"), at: 0)
                Sim.news(&s, "\(a.short) terminates \(c.title) for default", "Months without the agreed team. Your record with \(a.short) takes a heavy hit (−3), and future evaluators will see it.", .company, important: true, good: false)
                finish(&s, c)
                return
            }
        } else {
            c.underStaffedMonths = 0
        }
        if s.date >= c.periodEnd { closePeriod(&s, &c, a, f) }
        if c.status != .active { finish(&s, c); return }
        s.govMarket.anchor = c
    }

    static func closePeriod(_ s: inout GameState, _ c: inout AnchorContract, _ a: AgencyDef, _ f: Fiscal) {
        let score = c.periodDelivery.isEmpty ? 1 : c.periodDelivery.reduce(0, +) / Double(c.periodDelivery.count)
        let r = rating(score)
        s.govMarket.assessments.insert(GovAssessment(date: s.date, agency: c.agency, contract: c.title, score: score, rating: r), at: 0)
        if s.govMarket.assessments.count > 30 { s.govMarket.assessments.removeLast(s.govMarket.assessments.count - 30) }
        let delta = score >= 1 ? 2.0 : (score >= 0.9 ? 1.4 : (score >= 0.75 ? 0.7 : (score >= 0.5 ? -0.5 : -1.5)))
        s.advanced.ratings[c.agency] = clamp(AdvancedProjects.rating(s, c.agency) + delta, -10, 10)
        log(&c, s.date, "\(a.region == .us ? "Annual performance assessment" : "Periodic review"): \(r) (delivery \(Fmt.pct(score, decimals: 0))). Record with \(a.short) \(delta >= 0 ? "+" : "")\(Fmt.trim(delta, 1)).", score >= 0.75 ? 1 : -1)
        if c.payment == .tranche {
            // Interim payment for the period's accepted work, less a 5% retention held to the end.
            let due = max(0, c.earned * 0.95 - c.paid)
            if c.optionsLeft > 0 && due > 0 { c.paid += due; pay(&s, due); log(&c, s.date, "Interim payment: \(Fmt.money(due)).", 1) }
        }
        c.periodDelivery = []
        c.periodEarned = 0
        Sim.news(&s, "\(a.short) rates your work \(r.lowercased())", "\(c.title): \(Fmt.pct(score, decimals: 0)) of the planned delivery this period.", .company, good: score >= 0.75)
        guard c.optionsLeft > 0 else {
            if c.payment == .tranche { let due = max(0, c.earned - c.paid); c.paid += due; pay(&s, due); log(&c, s.date, "Final payment: \(Fmt.money(due)) (retention released).", 1) }
            c.status = .completed
            log(&c, s.date, "Completed: \(Fmt.money(c.paid)) paid over \(GameCalendar.daysBetween(c.start, s.date) / 30) months.", 1)
            Sim.news(&s, "Contract completed: \(c.title)", "\(a.name) closes it out with \(Fmt.money(c.paid)) paid. It stays on your record for every future bid.", .company, important: true, good: true)
            return
        }
        if score < 0.75 {
            c.status = .expired
            if c.payment == .tranche { let due = max(0, c.earned - c.paid); c.paid += due; pay(&s, due) }
            log(&c, s.date, "\(a.short) doesn't continue: the rating was below satisfactory.", -1)
            Sim.news(&s, "\(a.short) lets \(c.title) lapse", "The \(r.lowercased()) rating means the next \(c.payment == .invoice ? "option isn't exercised" : "period isn't approved").", .company, important: true, good: false)
            return
        }
        if f.phase == .lapse {
            c.awaitingOption = true
            log(&c, s.date, "The option can't be exercised: \(a.short) has no appropriations. Work stops until funding is restored.", -1)
            return
        }
        exercise(&s, &c, a, f)
    }

    static func exercise(_ s: inout GameState, _ c: inout AnchorContract, _ a: AgencyDef, _ f: Fiscal) {
        c.optionsLeft -= 1
        c.periodEnd = GameCalendar.addMonths(c.periodEnd, 12)
        var text = c.payment == .invoice ? "Option exercised: funded to \(c.periodEnd.gameShort)" : "Next period approved: to \(c.periodEnd.gameShort)"
        if f.phase == .continuing || f.phase == .provisional || f.fullYearCR {
            text += f.phase == .continuing ? ", month to month under the continuing resolution at last year's rate (no scope growth until appropriations pass)" : " at last year's rate"
        } else if let last = s.govMarket.assessments.first, last.score >= 0.9, c.growthGiven < 2, c.payment == .invoice {
            c.annual = (c.annual * 1.12 / 1_000).rounded() * 1_000
            c.growthGiven += 1
            text += ", with a 12% scope increase for very good work (\(Fmt.money(c.annual))/yr)"
        }
        log(&c, s.date, text + ".", 1)
    }

    static func finish(_ s: inout GameState, _ c: AnchorContract) {
        var c = c
        c.ended = s.date
        for id in c.assigned { s.advanced.seconded.remove(id) }
        c.assigned = []
        s.govMarket.pastAnchors.insert(c, at: 0)
        s.govMarket.anchor = nil
    }
}

// MARK: - Player actions

extension GameState {
    /// Answer a sources-sought notice: a short capability statement that gets you into the agency's market research.
    mutating func answerGovNotice(_ id: String) -> String? {
        guard let i = govMarket.opps.firstIndex(where: { $0.id == id }) else { return "That notice has closed." }
        guard !govMarket.opps[i].answeredNotice else { return "You've already answered it." }
        let cost = (1_500 * GovMarket.era(year) / 100).rounded() * 100
        guard cash >= cost else { return "A capability statement costs \(Fmt.money(cost))." }
        cash -= cost
        month.costOther += cost
        govMarket.bpSpent += cost
        govMarket.opps[i].answeredNotice = true
        govMarket.engaged = true
        return nil
    }

    /// Start writing a proposal: pay the bid-and-proposal cost, put a lead on it, and it goes in when it's done.
    mutating func startGovProposal(_ id: String, effort: CaptureEffort, lead: UUID?, price: Double) -> String? {
        guard let i = govMarket.opps.firstIndex(where: { $0.id == id }), let k = govMarket.opps[i].def, let a = govMarket.opps[i].agencyDef else { return "That opportunity has closed." }
        let o = govMarket.opps[i]
        guard o.status == .open else { return o.status == .notice ? "The solicitation isn't out yet (sources-sought notice)." : "You're already on it." }
        if let why = GovMarket.blocker(k, a, self) { return why + "." }
        let days = k.days[effort.rawValue - 1]
        let left = GameCalendar.daysBetween(date, o.sol.closes)
        guard days < left else { return "A \(effort.title.lowercased()) proposal takes \(days) days; it closes in \(left). Pick a lighter effort." }
        guard GovMarket.slots(self) > govMarket.opps.filter({ $0.status == .writing }).count else {
            return "Every writing slot is busy (\(GovMarket.slots(self))). Hire business-development staff for more (one slot per two)."
        }
        if effort != .light && lead == nil { return "Pick a technical lead (light proposals are founder-written)." }
        if let lead {
            guard GovMarket.leads(self).contains(where: { $0.id == lead }) else { return "That person is busy on a programme or another proposal." }
        }
        let cost = GovMarket.bpCost(k, effort, year)
        guard cash >= cost else { return "Writing it costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.costOther += cost
        govMarket.bpSpent += cost
        govMarket.engaged = true
        advanced.engaged = true
        govMarket.opps[i].status = .writing
        govMarket.opps[i].effort = effort.rawValue
        govMarket.opps[i].lead = effort == .light ? nil : lead
        govMarket.opps[i].price = o.sol.type == .grant ? clamp(price, 0.75, 1) : clamp(price, 0.75, 1)
        govMarket.opps[i].bpCost = cost
        govMarket.opps[i].writeStart = date
        govMarket.opps[i].writeDone = GameCalendar.addDays(date, days)
        if let l = govMarket.opps[i].lead { advanced.seconded.insert(l) }
        return nil
    }

    /// Send a proposal in before it's finished (unfinished sections cost points).
    mutating func submitGovProposalNow(_ id: String) -> String? {
        guard let i = govMarket.opps.firstIndex(where: { $0.id == id }), govMarket.opps[i].status == .writing,
              let start = govMarket.opps[i].writeStart, let done = govMarket.opps[i].writeDone else { return "Nothing being written." }
        let total = max(1, GameCalendar.daysBetween(start, done))
        let written = Double(GameCalendar.daysBetween(start, date)) / Double(total)
        GovMarket.submit(&self, i, written: written)
        return nil
    }

    /// Stop writing (the effort spent is gone).
    mutating func abandonGovProposal(_ id: String) -> String? {
        guard let i = govMarket.opps.firstIndex(where: { $0.id == id }), govMarket.opps[i].status == .writing else { return "Nothing being written." }
        let lead = govMarket.opps[i].lead
        govMarket.opps[i].status = .open
        govMarket.opps[i].effort = 0
        govMarket.opps[i].lead = nil
        govMarket.opps[i].writeStart = nil
        govMarket.opps[i].writeDone = nil
        GovMarket.release(&self, lead)
        return nil
    }

    /// Put an employee on (or take them off) the anchor contract.
    mutating func assignAnchor(_ employee: UUID, on: Bool) -> String? {
        guard var c = govMarket.anchor, c.status == .active else { return "No active anchor contract." }
        if !on {
            c.assigned.removeAll { $0 == employee }
            govMarket.anchor = c
            advanced.seconded.remove(employee)
            return nil
        }
        guard let e = employees.first(where: { $0.id == employee }) else { return "They've left the company." }
        guard !advanced.seconded.contains(employee) && !GovMarket.committed(self).contains(employee) else { return "\(e.name) is already on a programme or proposal." }
        c.assigned.append(employee)
        govMarket.anchor = c
        advanced.seconded.insert(employee)
        return nil
    }

    /// Fill the anchor team with the best free people, role by role.
    mutating func autoStaffAnchor() -> String? {
        guard let c = govMarket.anchor, c.status == .active else { return "No active anchor contract." }
        var short: [String] = []
        for (k, n) in c.staff.sorted(by: { $0.key < $1.key }) {
            guard let role = Role(rawValue: k) else { continue }
            var have = employees.filter { (govMarket.anchor?.assigned ?? []).contains($0.id) && $0.role == role }.count
            let busy = advanced.seconded.union(GovMarket.committed(self))
            let pool = employees.filter { $0.role == role && !busy.contains($0.id) }
                .sorted { ($0.star ? 1 : 0, -$0.skill, $0.id.uuidString) < ($1.star ? 1 : 0, -$1.skill, $1.id.uuidString) }   // stars stay on your own work
            for e in pool.prefix(max(0, n - have)) where assignAnchor(e.id, on: true) == nil { have += 1 }
            if have < n { short.append("\(n - have) \(n - have == 1 ? role.title.lowercased() : role.plural.lowercased())") }
        }
        return short.isEmpty ? nil : "Still short of \(short.joined(separator: ", ")): nobody else in those roles is free. Hire, or take someone off a programme."
    }

    /// End the anchor contract early by agreement (the agency notes it).
    mutating func walkAwayAnchor() {
        guard var c = govMarket.anchor, c.status == .active else { return }
        c.status = .walkedAway
        GovMarket.log(&c, date, "Ended early at your request.", -1)
        advanced.ratings[c.agency] = clamp(AdvancedProjects.rating(self, c.agency) - 1, -10, 10)
        if c.payment == .tranche {
            // Unearned pre-financing goes back.
            let back = max(0, c.paid - c.earned)
            cash -= back
            month.costOther += back
        }
        GovMarket.finish(&self, c)
        Sim.news(&self, "Contract ended early: \(c.title)", "By agreement. \(AgencyCatalog.byID[c.agency]?.short ?? c.agency) notes it on your record (−1).", .company, good: false)
    }
}
