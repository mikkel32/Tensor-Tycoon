import Foundation

/// 3.9: the founding government contract. Every new lab is offered one realistic first award, matched to its
/// headquarters, era and size (FoundingCatalog): a fixed budget, a period of performance, a statement of work whose
/// milestones are checked against what really happens in the game (staff hired, research finished, a model trained,
/// a paper accepted, a release, an evaluation), payment terms (milestones, monthly cost vouchers with an indirect rate
/// and a fee, or a grant's advance, interim claims and retention), quarterly reports, a mid-term review, a closeout
/// audit, one no-cost extension, and a follow-on (Phase II or option period, then a sole-source programme on the
/// Advanced Projects marketplace) when performance is good — or a cure notice, a stop-work order and termination for
/// default when milestones slip. The agency's rating feeds your Advanced Projects record.
///
/// Rolls are hashed from a salt taken from the RNG's state (never drawn from it), so a seed plays the same game.
enum FoundingContracts {
    static let offerKind = "founding_offer"
    static let phaseKind = "founding_phase"
    static let extensionKind = "founding_extension"
    static let kinds: Set<String> = [offerKind, phaseKind, extensionKind]

    // MARK: Basics

    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("fc|\(s.founding.salt)|\(key)") }

    static func ensureSalt(_ s: inout GameState) {
        if s.founding.salt.isEmpty { s.founding.salt = String(s.rng.state ^ 0xF0C7_2017, radix: 36) }
    }

    /// 0 a start-up, 1 a growing lab, 2 a major one: sets which scheme fits and how big the award is.
    static func tier(_ s: GameState) -> Int {
        if s.valuation < 5e8 && s.employees.count < 40 { return 0 }
        return s.valuation < 1.5e10 ? 1 : 2
    }

    static func scheme(_ c: FoundingContract) -> FoundingCatalog.Scheme? { FoundingCatalog.byID[c.scheme] }

    static func phaseDef(_ c: FoundingContract) -> FoundingCatalog.Phase? {
        guard let sc = scheme(c), sc.phases.indices.contains(c.phase - 1) else { return nil }
        return sc.phases[c.phase - 1]
    }

    static func technicalStaff(_ s: GameState) -> Int {
        s.employees.filter { $0.role == .researcher || $0.role == .mlEngineer || $0.role == .data || $0.role == .safety || $0.role == .infra }.count
    }

    static func acceptedPapers(_ s: GameState) -> Int {
        s.fun.papers.filter { $0.outcome == .poster || $0.outcome == .oral || $0.outcome == .best }.count
    }

    static func roundMoney(_ v: Double) -> Double {
        let step: Double = v >= 2e7 ? 1e6 : (v >= 2e6 ? 1e5 : (v >= 2e5 ? 5e3 : 1e3))
        return (v / step).rounded() * step
    }

    static func pickName(_ s: GameState, _ key: String) -> String {
        let f = NameBank.first, l = NameBank.last
        return "\(f[Int(roll(s, key + "f") * Double(f.count)) % f.count]) \(l[Int(roll(s, key + "l") * Double(l.count)) % l.count])"
    }

    static func log(_ s: inout GameState, _ i: Int, _ text: String, _ tone: Int = 0) {
        s.founding.contracts[i].history.insert(ProgrammeEvent(date: s.date, text: text, tone: tone), at: 0)
        if s.founding.contracts[i].history.count > 60 { s.founding.contracts[i].history.removeLast() }
    }

    // MARK: The model bar

    /// The capability the model milestone asks for: a fresh lab is asked for a model a set distance below the frontier at
    /// the due date; a lab with models, for a step past its best.
    static func modelTarget(_ s: GameState, _ ph: FoundingCatalog.Phase, due: Date, stretch: Bool) -> Double {
        let floor = Macro.frontier(due.decimalYear) - ph.gap
        var t: Double
        if let best = s.models.map(\.c).max() {
            // A step past your best, pulled toward the agency's bar but never more than a second step.
            t = max(best + ph.lift, min(floor, best + 2 * ph.lift))
        } else if let rig = RunPlanner.proposals(s).first?.est.forecast.c {
            // A garage lab is asked for a little more than its first obvious run: a second run, rented chips or a technique.
            t = min(rig + ph.lift, Macro.frontier(due.decimalYear) - 0.3)
        } else {
            t = floor
        }
        if stretch { t += 0.35 }
        return (t * 20).rounded() / 20
    }

    /// The bar as an Intelligence Index on today's suite (a frontier-style model at that capability).
    static func targetIndex(_ s: GameState, _ c: Double, set: [Benchmark]? = nil) -> Double {
        let set = set ?? Leaderboard.indexSet(s)
        return BenchmarkCatalog.index(Leaderboard.frontierProfile(s.year, key: "founding-bar", c: c, reasoningModel: s.year >= 2024.7), set: set)
    }

    /// "capability 2.70 (≈ index 41 on today's suite)"; small specialised models sit below the index's range.
    static func barText(_ s: GameState, _ c: Double, set: [Benchmark]? = nil) -> String {
        let idx = targetIndex(s, c, set: set)
        return "capability \(Fmt.trim(c, 2))" + (idx >= 5 ? " (≈ index \(Fmt.score(idx)) on today's suite)" : " (a specialised model, below today's index range)")
    }

    /// Models that count for the work: trained after the award.
    static func newModels(_ s: GameState, _ c: FoundingContract) -> [AIModel] { s.models.filter { $0.created >= c.start } }

    /// A model meets the bar on capability, or (checked weekly, on the live suite) on index.
    static func meetsBar(_ s: GameState, _ m: AIModel, target: Double, set: [Benchmark]?) -> Bool {
        if m.c >= target { return true }
        guard let set, m.c >= target - 0.8 else { return false }
        return BenchmarkCatalog.index(Leaderboard.profile(m), set: set) >= targetIndex(s, target, set: set)
    }

    // MARK: Offers

    /// A scheme and topic for this lab: its home country, its size and the year.
    static func pick(_ s: GameState) -> (FoundingCatalog.Scheme, FoundingCatalog.Topic)? {
        let country = HQ.country(s).id
        let t = tier(s)
        let options = FoundingCatalog.schemes.filter { $0.countries.contains(country) && $0.tiers.contains(t) }
        guard !options.isEmpty else { return nil }
        let sc = options[min(options.count - 1, Int(roll(s, "scheme") * Double(options.count)))]
        let y = s.year
        let open = sc.topics.filter { $0.year <= y + 0.25 }
        let recent = open.filter { $0.year >= y - 4 }
        let pool = recent.isEmpty ? open : recent
        guard !pool.isEmpty else { return nil }
        return (sc, pool[min(pool.count - 1, Int(roll(s, "topic") * Double(pool.count)))])
    }

    /// New games: the founding award arrives with the welcome news.
    static func found(_ s: inout GameState) {
        ensureSalt(&s)
        s.founding.offered = true
        offer(&s, intro: "Your proposal went in before the company was even incorporated, and it won.")
    }

    /// Older saves: one offer, once, sized to the lab as it stands.
    static func migrate(_ s: inout GameState) {
        guard !s.founding.offered, s.gameOver == nil else { return }
        ensureSalt(&s)
        s.founding.offered = true
        offer(&s, intro: "A programme manager who has followed your work invited a proposal, and the agency has now selected it.")
    }

    /// Draft the award and send the notice of award to the inbox.
    static func offer(_ s: inout GameState, intro: String) {
        guard let picked = pick(s), let ph = picked.0.phases.first, let a = AgencyCatalog.byID[picked.1.agency] else { return }
        let (sc, topic) = picked
        let t = tier(s)
        let yy = String(format: "%02d", GameCalendar.components(s.date).year % 100)
        var c = FoundingContract()
        c.id = "fc\(s.founding.contracts.count + 1)-\(sc.id)"
        c.scheme = sc.id
        c.phase = 1
        c.agency = a.id
        c.programme = "\(sc.programme) — \(ph.name)"
        c.number = "\(a.short)-\(yy)-\(sc.instrument)-\(1000 + Int(roll(s, "number") * 8999))"
        c.title = topic.title
        c.objective = topic.objective
        c.officer = pickName(s, "officer")
        c.manager = pickName(s, "manager")
        c.chargeShare = [0.8, 0.5, 0.15][clamp(t, 0, 2)]
        configure(&c, ph, sc, tier: t, s, stretch: false)
        c.status = .offered
        c.offerExpires = GameCalendar.addDays(s.date, Alerts.inboxDays(offerKind))
        c.history = [ProgrammeEvent(date: s.date, text: "Notice of award from \(a.short): \(c.programme), \(Fmt.money(c.budget)) over \(c.months) months.", tone: 1)]
        s.founding.contracts.insert(c, at: 0)
        sendOffer(&s, 0, intro: intro, kind: offerKind)
    }

    /// Budget, rates and period for a phase (milestones are laid out at signature, when the clock starts).
    static func configure(_ c: inout FoundingContract, _ ph: FoundingCatalog.Phase, _ sc: FoundingCatalog.Scheme, tier: Int, _ s: GameState, stretch: Bool) {
        c.terms = ph.terms
        c.budget = roundMoney(interpolate(ph.budget, at: s.year, extrapolate: false) * sc.tierScale[clamp(tier, 0, 2)] * (stretch ? 1.4 : 1))
        c.indirectRate = ph.indirect
        c.feeRate = ph.fee
        c.fundingRate = ph.funding
        c.advanceShare = ph.advance
        c.retention = ph.retention
        c.months = ph.months
    }

    static func plan(_ ph: FoundingCatalog.Phase, stretch: Bool) -> [FCMilestoneKind] {
        var p = ph.plan
        if stretch {
            // A stretch scope promises one more deliverable: a paper, else a live demonstration.
            let extra: FCMilestoneKind = p.contains(.paper) ? .release : .paper
            if !p.contains(extra) { p.insert(extra, at: max(0, p.count - 1)) }
        }
        return p
    }

    /// What the offer card says about the work, the money and the bar.
    static func termsLine(_ c: FoundingContract) -> String {
        switch c.terms {
        case .fixedPrice: return "Firm-fixed-price: the \(Fmt.money(c.budget)) price is paid in slices as each milestone is accepted, whatever the work costs you."
        case .costPlus: return "Cost-plus-fixed-fee: costs you charge to the work are reimbursed monthly with a \(Fmt.pct(c.indirectRate, decimals: 0)) indirect rate, up to \(Fmt.money(c.costCeiling)); the \(Fmt.money(c.fee)) fee is paid as milestones are accepted. An audit checks the costs at closeout."
        case .grant: return "Grant: \(Fmt.money(c.budget)), " + (c.fundingRate >= 0.999 ? "the full planned cost (overheads at a \(Fmt.pct(c.indirectRate, decimals: 0)) flat rate)." : "covering \(Fmt.pct(c.fundingRate, decimals: 0)) of the planned \(Fmt.money(c.budget / max(0.1, c.fundingRate))) cost (you co-fund the rest; overheads at a \(Fmt.pct(c.indirectRate, decimals: 0)) flat rate).") + " \(Fmt.pct(c.advanceShare, decimals: 0)) is advanced at signature; each accepted milestone earns its share, \(Fmt.pct(c.retention, decimals: 0)) is held until the final report, and an advance the accepted work doesn't cover is recovered if the grant fails."
        }
    }

    static func sendOffer(_ s: inout GameState, _ i: Int, intro: String, kind: String) {
        let c = s.founding.contracts[i]
        guard let sc = scheme(c), let ph = phaseDef(c), let a = c.agencyDef else { return }
        let due = GameCalendar.addDays(s.date, Int(Double(c.months) * FCMilestoneKind.model.dueShare * 30.4))
        let bar = modelTarget(s, ph, due: due, stretch: false)
        let hard = modelTarget(s, ph, due: due, stretch: true)
        let set = Leaderboard.indexSet(s)
        let steps = plan(ph, stretch: false).map { title($0) }.joined(separator: ", ")
        var stretched = c
        stretched.budget = roundMoney(c.budget * 1.4)
        let extra = plan(ph, stretch: true).first { !ph.plan.contains($0) }.map { title($0).lowercased() } ?? "one more deliverable"
        let body = "\(intro) \(a.name) (\(a.short)) selected \"\(c.title)\" under its \(sc.programme.replacingOccurrences(of: "\(a.short) ", with: "")) scheme (\(c.number)). \(c.objective)\n\n"
            + "\(c.programme): \(Fmt.money(c.budget)) over \(c.months) months. \(termsLine(c))\n\nStatement of work: \(steps). The model bar is \(barText(s, bar, set: set)). "
            + "\(c.manager) is the programme manager; \(c.officer) the \(c.terms == .grant ? "grant" : "contracting") officer. A mid-term review at month \(c.months / 2) rates your progress: slip and you get a cure notice, then a stop-work order. Deliver and \(sc.phases.count > c.phase ? "\(sc.phases[c.phase].name) follows" : "a sole-source follow-on is likely")."
        Events.addDecision(&s, kind: kind, title: kind == offerKind ? "Notice of award: \(sc.short), \(a.short)" : "Follow-on award: \(c.programme)",
                           body: body, image: HQ.city(s).image,
                           options: [DecisionOption(label: "Sign the statement of work",
                                                    detail: "\(Fmt.money(c.budget)) over \(c.months) months, \(c.terms.short.lowercased()). Model bar: capability \(Fmt.trim(bar, 2)). Your first goal."),
                                     DecisionOption(label: "Negotiate a stretch scope",
                                                    detail: "\(Fmt.money(stretched.budget)) instead; the model bar rises to capability \(Fmt.trim(hard, 2)) and \(extra) is added. Exceptional ratings come easier."),
                                     DecisionOption(label: "Decline the award", detail: "No strings and no money. \(a.short) won't hold the offer open.")],
                           amount: c.budget, ref: c.id)
    }

    static func title(_ k: FCMilestoneKind) -> String {
        switch k {
        case .kickoff: "Kick-off and work plan"
        case .staffing: "Key personnel"
        case .research: "Research result"
        case .model: "Deliver the model"
        case .paper: "Peer-reviewed paper"
        case .release: "Live demonstration"
        case .safety: "Test and evaluation"
        case .report: "Interim report"
        case .final: "Final report"
        }
    }

    // MARK: Signature

    /// A research item for the statement of work: one already in your queue if it fits, else a cheap one you can
    /// start now.
    static func researchPick(_ s: GameState, days: Int) -> ResearchItem? {
        let y = s.year
        let rp = max(5, s.rpToday)
        func fits(_ r: ResearchItem) -> Bool {
            !s.researched.contains(r.id) && !r.isExotic && r.category != .frontier && r.year <= y + 0.5
                && r.prereqs.allSatisfy { s.researched.contains($0) } && ResearchLab.blockReason(s, r.id) == nil
        }
        for id in s.researchQueue {
            if let r = ResearchCatalog.byID[id], fits(r), Sim.researchCost(r, year: y) <= rp * Double(days) * 0.6 { return r }
        }
        let options = ResearchCatalog.all.filter(fits).sorted { (Sim.researchCost($0, year: y), $0.id) < (Sim.researchCost($1, year: y), $1.id) }
        let affordable = options.filter { Sim.researchCost($0, year: y) <= rp * Double(days) * 0.5 }
        let pool = Array((affordable.isEmpty ? options : affordable).prefix(3))
        guard !pool.isEmpty else { return nil }
        return pool[min(pool.count - 1, Int(roll(s, "research|\(s.date.ym.year)") * Double(pool.count)))]
    }

    static func sign(_ s: inout GameState, _ i: Int, stretch: Bool) {
        var c = s.founding.contracts[i]
        guard let sc = scheme(c), let ph = phaseDef(c) else { return }
        let t = tier(s)
        let offered = c.budget   // the price in the offer holds (a follow-on may carry a bonus)
        configure(&c, ph, sc, tier: t, s, stretch: false)
        c.budget = stretch ? roundMoney(offered * 1.4) : offered
        c.stretch = stretch
        c.start = s.date
        c.end = GameCalendar.addMonths(s.date, c.months)
        c.midterm = GameCalendar.addDays(s.date, Int(Double(c.months) * 30.4 / 2))
        c.papersAtStart = acceptedPapers(s)
        c.publishedAtStart = s.publishedTech.count
        c.offerExpires = nil
        let days = Double(GameCalendar.daysBetween(c.start, c.end))
        var ms: [FCMilestone] = []
        let kinds = plan(ph, stretch: stretch)
        let modelDue = GameCalendar.addDays(c.start, Int(days * FCMilestoneKind.model.dueShare))
        let bar = modelTarget(s, ph, due: modelDue, stretch: stretch)
        c.cAtStart = s.models.map(\.c).max() ?? (bar - 2)
        for k in kinds {
            var m = FCMilestone()
            m.id = "m\(ms.count + 1)"
            m.kind = k
            m.due = k == .kickoff ? GameCalendar.addDays(c.start, 30) : GameCalendar.addDays(c.start, Int(days * k.dueShare))
            m.title = title(k)
            switch k {
            case .kickoff:
                m.detail = "Your principal investigator presents the work plan to \(c.manager). Accepted about two weeks after signature."
            case .staffing:
                let have = technicalStaff(s)
                m.target = Double(max(have + [1, 3, 5][clamp(t, 0, 2)], 3))
                m.title = "Key personnel: \(Int(m.target)) technical staff"
                m.detail = "At least \(Int(m.target)) researchers and engineers on the payroll (you have \(have)). The proposal named them; the agency checks."
            case .research:
                guard let r = researchPick(s, days: Int(days * k.dueShare)) else { continue }
                m.ref = r.id
                m.title = "Research: \(r.name)"
                m.detail = "Finish \(r.name), the method the proposal promised. Queue it on the Research page if the director hasn't."
            case .model:
                m.target = bar
                m.title = "Deliver a model at capability \(Fmt.trim(bar, 2))"
                m.detail = "A model trained after the award at capability \(Fmt.trim(bar, 2)) or better (or the same Intelligence Index on today's suite). The core technical result."
            case .paper:
                m.detail = "A paper from the work accepted at a major conference, or a result published openly."
            case .release:
                m.target = bar
                m.detail = "Release a model that meets the bar (API or app), so the agency's evaluators can test it live."
            case .safety:
                if s.year >= 2023.5 {
                    m.title = "Test and evaluation report"
                    m.detail = "Put a model trained under the award through a dangerous-capability evaluation (commission it in the Model Lab)."
                } else {
                    m.target = (clamp(s.safetyScore + 10, 45, 80)).rounded()
                    m.title = "Safety and red-team report: safety score \(Int(m.target))"
                    m.detail = "The agency wants a red-team report showing a safety score of \(Int(m.target)) or more (you have \(Int(s.safetyScore)))."
                }
            case .report:
                m.detail = "A progress report at the half-way point. Filed on schedule unless the work is stopped\(c.terms == .grant ? "; its approval releases an interim payment" : "")."
            case .final:
                m.detail = "Written in three weeks once every other milestone is met. Closes the award: the last payment\(c.terms == .fixedPrice ? "" : " after the audit") and your performance rating."
            }
            ms.append(m)
        }
        let total = ms.reduce(0) { $0 + $1.kind.weight }
        for j in ms.indices { ms[j].share = ms[j].kind.weight / max(0.01, total) }
        ms.sort { ($0.due, $0.id) < ($1.due, $1.id) }
        c.milestones = ms
        c.status = .active
        s.founding.contracts[i] = c
        if let r = ms.first(where: { $0.kind == .research }), !s.researchQueue.contains(r.ref), s.queueResearch(r.ref) == nil {
            log(&s, i, "The work plan puts \(ResearchCatalog.byID[r.ref]?.name ?? r.ref) in your research queue.")
        }
        log(&s, i, "Signed\(stretch ? " with a stretch scope" : ""): \(Fmt.money(c.budget)), \(c.terms.short.lowercased()), period of performance \(c.start.gameShort) – \(c.end.gameShort).", 1)
        let a = c.agencyShort
        s.advanced.bids.insert(BidRecord(date: s.date, title: c.title, agency: c.agency, winner: s.companyName, odds: 1, won: true, price: 1), at: 0)
        if s.advanced.bids.count > 40 { s.advanced.bids.removeLast(s.advanced.bids.count - 40) }
        s.advanced.engaged = true
        if c.terms == .grant {
            let advance = roundMoney(c.budget * c.advanceShare)
            pay(&s, i, advance)
            log(&s, i, "Pre-financing received: \(Fmt.money(advance)) (\(Fmt.pct(c.advanceShare, decimals: 0)) of the grant).", 1)
        }
        Sim.news(&s, "\(c.phase == 1 ? "First government award" : "Follow-on award") signed with \(a)",
                 "\(c.programme): \"\(c.title)\", \(Fmt.money(c.budget)) over \(c.months) months. First deadline: \(c.milestones.first.map { "\($0.title.lowercased()) by \($0.due.gameShort)" } ?? "the kick-off"). Track it on the dashboard and the Advanced Projects page.",
                 .company, image: HQ.city(s).image, important: true, good: true)
        Alerts.raise(&s, .advanced, key: "fc-signed|\(c.id)", title: "Award signed: \(c.title)",
                     body: "\(Fmt.money(c.budget)) over \(c.months) months. \(c.milestones.count) milestones; the first is due \(c.milestones.first?.due.gameShort ?? "soon").",
                     screen: .advancedProjects, celebrate: true, cooldown: 0)
    }

    static func decline(_ s: inout GameState, _ i: Int) {
        s.founding.contracts[i].status = .declined
        s.founding.contracts[i].ended = s.date
        s.founding.contracts[i].offerExpires = nil
        log(&s, i, "You declined the award.", -1)
        Sim.news(&s, "Award declined", "You turned down \(s.founding.contracts[i].agencyShort)'s \(s.founding.contracts[i].programme) award for \"\(s.founding.contracts[i].title)\".", .company)
    }

    // MARK: Money

    static func pay(_ s: inout GameState, _ i: Int, _ amount: Double) {
        guard amount > 0.5 else { return }
        s.cash += amount
        s.month.revContracts += amount   // lumpy, kept out of the recurring run rate (as Advanced Projects does)
        s.lifetimeRevenue += amount
        s.founding.contracts[i].paid += amount
        s.founding.lifetimePaid += amount
    }

    /// A recovery order or an audit adjustment: money goes back to the agency.
    static func recover(_ s: inout GameState, _ i: Int, _ amount: Double) {
        guard amount > 0.5 else { return }
        s.cash -= amount
        s.month.revContracts -= amount
        s.lifetimeRevenue -= amount
        s.founding.contracts[i].paid -= amount
        s.founding.lifetimePaid -= amount
    }

    /// What the agency owes for an accepted milestone (grants: the claims, capped before the final report).
    static func milestonePayment(_ c: FoundingContract, _ m: FCMilestone) -> Double {
        switch c.terms {
        case .fixedPrice: return c.budget * m.share
        case .costPlus: return c.fee * m.share
        case .grant:
            // Lump sums: each accepted work package earns its share; the advance is cleared against them first and the
            // retention waits for the final report.
            guard m.kind != .final else { return 0 }
            return max(0, grantEarned(c, including: m) * c.budget * (1 - c.retention) - c.paid)
        }
    }

    /// Share of a grant earned by accepted milestones (plus one being accepted now).
    static func grantEarned(_ c: FoundingContract, including m: FCMilestone? = nil) -> Double {
        c.milestones.filter { $0.met != nil || $0.id == m?.id }.reduce(0) { $0 + $1.share }
    }

    /// Pay every accepted milestone not yet paid (held while a stop-work order runs). The final one pays at closeout.
    static func settle(_ s: inout GameState, _ i: Int) {
        guard s.founding.contracts[i].status == .active else { return }
        for j in s.founding.contracts[i].milestones.indices {
            let c = s.founding.contracts[i]
            let m = c.milestones[j]
            guard m.met != nil, m.paid <= 0, m.kind != .final else { continue }
            let amount = milestonePayment(c, m)
            s.founding.contracts[i].milestones[j].paid = max(0.01, amount)
            if c.terms == .costPlus { s.founding.contracts[i].feePaid += amount }
            pay(&s, i, amount)
            if amount > 0.5 { log(&s, i, "\(m.title) accepted: \(Fmt.money(amount)) paid.", 1) }
        }
    }

    // MARK: Monthly: charging, vouchers and reports

    /// Month end: costs are charged to the work (a share of the month's payroll and compute, up to the plan), cost-plus
    /// vouchers from last month are paid and this month's raised, and a quarterly report goes in.
    static func monthly(_ s: inout GameState) {
        guard let c = s.founding.contracts.first, c.status.live else { return }
        let i = 0
        let stopped = c.status == .stopWork
        let pool = s.month.costPayroll + s.month.costRent + s.month.costPower
        let planDirect: Double
        let cap: Double
        switch c.terms {
        case .fixedPrice: planDirect = c.budget / 1.12 / Double(c.months); cap = planDirect * Double(c.months) * 1.3
        case .costPlus: planDirect = c.costCeiling / (1 + c.indirectRate) / Double(c.months); cap = c.costCeiling / (1 + c.indirectRate)
        case .grant: planDirect = c.budget / max(0.1, c.fundingRate) / (1 + c.indirectRate) / Double(c.months); cap = c.budget / max(0.1, c.fundingRate) / (1 + c.indirectRate)
        }
        // Work stopped: nothing may be charged.
        let direct = stopped ? 0 : max(0, min(planDirect * 1.15, pool * c.chargeShare, cap - c.direct))
        s.founding.contracts[i].direct += direct
        s.founding.contracts[i].charged += direct * (1 + c.indirectRate)
        if c.terms == .costPlus && !stopped {
            // Net-30: last month's voucher is paid now; this month's is raised (until the cost ceiling is reached).
            let due = s.founding.contracts[i].voucher
            pay(&s, i, due)
            let cur = s.founding.contracts[i]
            let reimbursed = cur.paid - cur.feePaid
            let next = min(direct * (1 + c.indirectRate), max(0, c.costCeiling - reimbursed))
            s.founding.contracts[i].voucher = next
            if next < direct * (1 + c.indirectRate) - 1, !cur.history.contains(where: { $0.text.hasPrefix("Limitation of funds") }) {
                log(&s, i, "Limitation of funds: the \(Fmt.money(c.costCeiling)) cost ceiling is reached. Further costs are yours.", -1)
                Sim.news(&s, "\(c.agencyShort) award: cost ceiling reached", "Costs on \"\(c.title)\" have used the whole \(Fmt.money(c.costCeiling)). The fee still pays at milestones; anything more the work costs is yours.", .finance, good: false)
            }
        }
        let monthsIn = Int((Double(GameCalendar.daysBetween(c.start, s.date)) / 30.4).rounded())
        if monthsIn > 0 && monthsIn % 3 == 0 && monthsIn > s.founding.contracts[i].reports * 3 {
            s.founding.contracts[i].reports += 1
            let cur = s.founding.contracts[i]
            log(&s, i, "Quarterly report \(cur.reports) filed: \(cur.metCount) of \(cur.milestones.count) milestones met, \(Fmt.money(cur.charged)) charged, \(Fmt.money(cur.paid)) received\(stopped ? " (work stopped)" : "").")
        }
    }

    // MARK: Daily: milestones, reviews and enforcement

    static func daily(_ s: inout GameState) {
        guard let c = s.founding.contracts.first, c.status.live else { return }
        checkMilestones(&s, weekly: GameCalendar.components(s.date).day % 7 == 2)
        review(&s)
        enforce(&s)
        offerExtension(&s)
        guard let now = s.founding.contracts.first, now.status.live else { return }
        if now.milestones.contains(where: { $0.kind == .final && $0.met != nil }) {
            closeOut(&s)
        } else if s.date >= now.end {
            lapse(&s)
        }
    }

    static func isMet(_ s: GameState, _ c: FoundingContract, _ m: FCMilestone, set: [Benchmark]?) -> Bool {
        let today = s.date
        switch m.kind {
        case .kickoff: return GameCalendar.daysBetween(c.start, today) >= 10 + Int(roll(s, "kickoff|\(c.id)") * 8)
        case .staffing: return Double(technicalStaff(s)) >= m.target
        case .research: return s.researched.contains(m.ref)
        case .model: return newModels(s, c).contains { meetsBar(s, $0, target: m.target, set: set) }
        case .paper: return acceptedPapers(s) > c.papersAtStart || s.publishedTech.count > c.publishedAtStart
        case .release: return newModels(s, c).contains { $0.released && meetsBar(s, $0, target: m.target, set: set) }
        case .safety: return m.target > 0 ? s.safetyScore >= m.target : newModels(s, c).contains { $0.evaluated }
        case .report: return GameCalendar.daysBetween(today, m.due) <= 5 && c.status == .active
        case .final:
            let others = c.milestones.filter { $0.kind != .final }
            guard others.allSatisfy({ $0.met != nil }) else { return false }
            let last = others.compactMap(\.met).max() ?? c.start
            return GameCalendar.daysBetween(last, today) >= 21
        }
    }

    static func checkMilestones(_ s: inout GameState, weekly: Bool) {
        let set = weekly ? Leaderboard.indexSet(s) : nil
        let i = 0
        for j in s.founding.contracts[i].milestones.indices {
            let c = s.founding.contracts[i]
            let m = c.milestones[j]
            guard m.met == nil, isMet(s, c, m, set: set) else { continue }
            s.founding.contracts[i].milestones[j].met = s.date
            let late = s.date > m.due
            log(&s, i, "\(m.title): met\(late ? " (\(GameCalendar.daysBetween(m.due, s.date)) days late)" : " on time").", late ? 0 : 1)
            if m.kind == .final { continue }
            settle(&s, i)
            if m.kind == .model || m.kind == .release || m.kind == .research {
                let paid = s.founding.contracts[i].milestones[j].paid
                Sim.news(&s, "\(c.agencyShort) milestone met: \(m.title)",
                         "\"\(c.title)\" — \(late ? "late, but accepted" : "on time")\(paid > 0.5 ? "; \(Fmt.money(paid)) paid" : ""). \(s.founding.contracts[i].metCount) of \(c.milestones.count) milestones done.",
                         .company, good: true)
            }
        }
    }

    /// Overdue milestones (the final report isn't one until the period ends).
    static func overdue(_ c: FoundingContract, _ today: Date) -> [FCMilestone] {
        c.milestones.filter { $0.met == nil && $0.kind != .final && $0.due < today }
    }

    /// How the work stands half-way: milestones due so far met on time, and the model's progress toward its bar
    /// (a run in training whose forecast clears it counts as on track).
    static func progressScore(_ s: GameState, _ c: FoundingContract) -> Double {
        let today = s.date
        let due = c.milestones.filter { $0.kind != .final && $0.due <= today }
        let onTime = due.filter { m in m.met.map { $0 <= m.due } ?? false }.count
        let ratio = due.isEmpty ? 1 : Double(onTime) / Double(due.count)
        let early = c.milestones.filter { m in m.kind != .final && m.due > today && m.met != nil }.count
        var p = 1.0
        if let m = c.milestones.first(where: { $0.kind == .model }), m.met == nil {
            let best = newModels(s, c).map(\.c).max() ?? c.cAtStart
            p = clamp((best - c.cAtStart) / max(0.1, m.target - c.cAtStart), 0, 1)
            for r in s.runs where (r.status == .running || r.status == .postTraining) {
                if let f = r.forecast { p = max(p, f.c >= m.target ? 0.75 : 0.6 * clamp((f.c - c.cAtStart) / max(0.1, m.target - c.cAtStart), 0, 1)) }
            }
        }
        return 0.55 * ratio + 0.45 * p + min(0.1, 0.05 * Double(early))
    }

    static func rating(_ score: Double) -> Int { score >= 0.85 ? 4 : (score >= 0.65 ? 3 : (score >= 0.45 ? 2 : (score >= 0.25 ? 1 : 0))) }

    static func review(_ s: inout GameState) {
        let i = 0
        let c = s.founding.contracts[i]
        guard c.reviewRating == nil, s.date >= c.midterm else { return }
        let r = rating(progressScore(s, c))
        s.founding.contracts[i].reviewRating = r
        let a = c.agencyShort
        let region = HQ.region(s).rawValue
        log(&s, i, "Mid-term review by \(c.manager): \(FCRating.title(r)).", r >= 2 ? 1 : -1)
        switch r {
        case 3...:
            Stakeholders.move(&s, [region: 1], "A glowing mid-term review from \(a)")
            Sim.news(&s, "Mid-term review: \(FCRating.title(r))", "\(c.manager) at \(a) calls \"\(c.title)\" one of the strongest efforts in the portfolio\(scheme(c).map { $0.phases.count > c.phase ? " and wants to talk about \($0.phases[c.phase].name)" : "" } ?? "").", .company, good: true)
        case 2:
            Sim.news(&s, "Mid-term review: Satisfactory", "\(a) is content with \"\(c.title)\". Keep the remaining milestones on schedule.", .company)
        case 1:
            let due = GameCalendar.addDays(s.date, 60)
            s.founding.contracts[i].cureUntil = due
            let late = overdue(s.founding.contracts[i], s.date).map(\.title)
            log(&s, i, "Cure notice: fix \(late.isEmpty ? "the slipping work" : late.joined(separator: ", ")) by \(due.gameShort), or work stops.", -1)
            Sim.news(&s, "Cure notice from \(a)", "The mid-term review rated \"\(c.title)\" Marginal. \(c.officer) gives you until \(due.gameShort) to \(late.isEmpty ? "get the model on track" : "deliver \(late.joined(separator: ", ").lowercased())"); after that, a stop-work order.", .company, important: true, good: false)
            Alerts.raise(&s, .advanced, key: "fc-cure|\(c.id)", title: "Cure notice: \(c.title)", body: "Rated Marginal at mid-term. Deliver the overdue milestones by \(due.gameShort).", screen: .advancedProjects, cooldown: 0)
        default:
            stopWork(&s, i, days: 90, why: "The mid-term review rated the work Unsatisfactory.")
        }
    }

    static func stopWork(_ s: inout GameState, _ i: Int, days: Int, why: String) {
        let c = s.founding.contracts[i]
        let until = GameCalendar.addDays(s.date, days)
        s.founding.contracts[i].status = .stopWork
        s.founding.contracts[i].stopUntil = until
        s.founding.contracts[i].cureUntil = nil
        log(&s, i, "Stop-work order: \(why) Payments are held; deliver the overdue work by \(until.gameShort) or the award is terminated.", -1)
        Sim.news(&s, "Stop-work order on \"\(c.title)\"", "\(why) \(c.agencyShort) has stopped the work and holds all payments. Deliver \(overdue(c, s.date).map { $0.title.lowercased() }.joined(separator: ", ")) by \(until.gameShort), or the award is terminated for default.",
                 .company, important: true, good: false)
        Alerts.raise(&s, .advanced, key: "fc-stop|\(c.id)", title: "Stop-work order: \(c.title)", body: "Payments held. Deliver the overdue milestones by \(until.gameShort) or it is terminated.", screen: .advancedProjects, cooldown: 0)
    }

    /// Cure notices and stop-work orders run out; badly overdue work draws a cure notice on its own.
    static func enforce(_ s: inout GameState) {
        let i = 0
        let c = s.founding.contracts[i]
        let today = s.date
        let late = overdue(c, today)
        if let cure = c.cureUntil {
            if late.isEmpty {
                s.founding.contracts[i].cureUntil = nil
                log(&s, i, "Cure notice lifted: the overdue work is in.", 1)
                Sim.news(&s, "\(c.agencyShort) lifts its cure notice", "The overdue work on \"\(c.title)\" is in.", .company, good: true)
            } else if today >= cure {
                stopWork(&s, i, days: 60, why: "The cure period ended with work still overdue.")
            }
            return
        }
        if c.status == .stopWork, let until = c.stopUntil {
            if late.isEmpty {
                // The schedule moves by the time the work was stopped.
                let held = max(0, GameCalendar.daysBetween(c.history.first { $0.text.hasPrefix("Stop-work order:") }?.date ?? today, today))
                s.founding.contracts[i].status = .active
                s.founding.contracts[i].stopUntil = nil
                s.founding.contracts[i].end = GameCalendar.addDays(c.end, held)
                for j in c.milestones.indices where c.milestones[j].met == nil {
                    s.founding.contracts[i].milestones[j].due = GameCalendar.addDays(c.milestones[j].due, held)
                }
                log(&s, i, "Stop-work order lifted; the schedule moves \(held) days.", 1)
                Sim.news(&s, "\(c.agencyShort) lifts its stop-work order", "Work on \"\(c.title)\" resumes and held payments are released. The period of performance now ends \(s.founding.contracts[i].end.gameShort).", .company, good: true)
                settle(&s, i)
            } else if today >= until {
                terminate(&s, i)
            }
            return
        }
        // Work more than three months overdue draws a cure notice without waiting for a review, when the work as a whole
        // is going badly too.
        if c.status == .active, let worst = late.min(by: { $0.due < $1.due }), GameCalendar.daysBetween(worst.due, today) > 90,
           rating(progressScore(s, c)) <= 1 {
            let due = GameCalendar.addDays(today, 45)
            s.founding.contracts[i].cureUntil = due
            log(&s, i, "Cure notice: \(worst.title) is over three months late. Deliver by \(due.gameShort).", -1)
            Sim.news(&s, "Cure notice from \(c.agencyShort)", "\(worst.title) on \"\(c.title)\" is over three months late. \(c.officer) gives you until \(due.gameShort).", .company, important: true, good: false)
            Alerts.raise(&s, .advanced, key: "fc-cure2|\(c.id)", title: "Cure notice: \(c.title)", body: "\(worst.title) is over three months late. Deliver by \(due.gameShort).", screen: .advancedProjects, cooldown: 0)
        }
    }

    // MARK: No-cost extension

    /// Work left that the final report can't cover in the time remaining.
    static func needsMoreTime(_ c: FoundingContract) -> Bool {
        c.milestones.contains { $0.met == nil && $0.kind != .final }
    }

    static func extensionMonths(_ c: FoundingContract) -> Int { c.months <= 12 ? 3 : 6 }

    static func offerExtension(_ s: inout GameState) {
        let i = 0
        let c = s.founding.contracts[i]
        guard c.status == .active, !c.extensionAsked, needsMoreTime(c), GameCalendar.daysBetween(s.date, c.end) <= 45 else { return }
        s.founding.contracts[i].extensionAsked = true
        let n = extensionMonths(c)
        let left = c.milestones.filter { $0.met == nil && $0.kind != .final }.map { $0.title.lowercased() }
        Events.addDecision(&s, kind: extensionKind, title: "No-cost extension: \(c.title)",
                           body: "The period of performance on \(c.number) ends \(c.end.gameShort) with \(left.joined(separator: ", ")) still to deliver. \(c.officer) can extend it by \(n) months at no cost to the government: no new money, but time to finish. Agencies grant one; it caps your final rating at Very good.",
                           image: "server_room",
                           options: [DecisionOption(label: "Request a \(n)-month no-cost extension", detail: "The period ends \(GameCalendar.addMonths(c.end, n).gameShort). Final rating at most Very good."),
                                     DecisionOption(label: "Let the period end", detail: "Unmet milestones are forfeited when it closes on \(c.end.gameShort).")],
                           ref: c.id)
    }

    static func extend(_ s: inout GameState, _ i: Int) -> String? {
        let c = s.founding.contracts[i]
        guard c.status.live else { return "The award isn't running." }
        guard c.extensionMonths == 0 else { return "The agency has already extended this award once." }
        let n = extensionMonths(c)
        s.founding.contracts[i].extensionAsked = true
        s.founding.contracts[i].extensionMonths = n
        s.founding.contracts[i].end = GameCalendar.addMonths(c.end, n)
        let newEnd = s.founding.contracts[i].end
        for j in c.milestones.indices where c.milestones[j].met == nil {
            let late = c.milestones[j].due < s.date
            if c.milestones[j].kind == .final { s.founding.contracts[i].milestones[j].due = newEnd }
            else if late || GameCalendar.daysBetween(s.date, c.milestones[j].due) < 30 {
                s.founding.contracts[i].milestones[j].due = min(newEnd, GameCalendar.addMonths(max(s.date, c.milestones[j].due), n))
            }
        }
        if c.cureUntil != nil { s.founding.contracts[i].cureUntil = nil }
        log(&s, i, "No-cost extension granted: the period now ends \(newEnd.gameShort)\(c.cureUntil != nil ? "; the cure notice is withdrawn with the new schedule" : "").")
        Sim.news(&s, "\(c.agencyShort) grants a no-cost extension", "\"\(c.title)\" now runs to \(newEnd.gameShort). No new money; the final rating is capped at Very good.", .company)
        return nil
    }

    // MARK: Closeout

    static func finalRating(_ c: FoundingContract) -> Int {
        let work = c.milestones.filter { $0.kind != .final }
        let onTime = work.filter { m in m.met.map { $0 <= m.due } ?? false }.count
        let ratio = work.isEmpty ? 1 : Double(onTime) / Double(work.count)
        // A stretch scope earns Exceptional more easily.
        var r = ratio >= (c.stretch ? 0.75 : 0.9) ? 4 : (ratio >= (c.stretch ? 0.5 : 0.65) ? 3 : 2)
        if c.extensionMonths > 0 || (c.reviewRating ?? 4) <= 1 { r = min(r, 3) }
        return r
    }

    /// The final report is in: audit (cost-plus always, grants sometimes), last payments, the rating and the follow-on.
    static func closeOut(_ s: inout GameState) {
        let i = 0
        var c = s.founding.contracts[i]
        if c.terms != .fixedPrice && (c.terms == .costPlus || roll(s, "audit|\(c.id)") < 0.4) {
            let share = 0.004 + 0.04 * roll(s, "auditshare|\(c.id)")
            let base = c.terms == .grant ? min(c.budget, c.charged * c.fundingRate) : c.charged
            let cut = roundMoney(base * share)
            s.founding.contracts[i].audited = true
            s.founding.contracts[i].disallowed = cut
            log(&s, i, cut > 0 ? "Closeout audit: \(Fmt.money(cut)) of claimed costs disallowed (timesheets that didn't match the work plan, travel without approval)." : "Closeout audit: clean.", cut > 0 ? -1 : 1)
            c = s.founding.contracts[i]
        }
        var due: Double = 0
        switch c.terms {
        case .fixedPrice, .costPlus:
            for j in c.milestones.indices where c.milestones[j].paid <= 0 {
                let amount = milestonePayment(c, c.milestones[j])
                s.founding.contracts[i].milestones[j].paid = max(0.01, amount)
                if c.terms == .costPlus { s.founding.contracts[i].feePaid += amount }
                due += amount
            }
            due += c.voucher - c.disallowed
            s.founding.contracts[i].voucher = 0
        case .grant:
            due = c.budget - c.paid - c.disallowed
        }
        if due >= 0 { pay(&s, i, due) } else { recover(&s, i, -due) }
        let r = finalRating(s.founding.contracts[i])
        s.founding.contracts[i].finalRating = r
        s.founding.contracts[i].status = .completed
        s.founding.contracts[i].ended = s.date
        record(&s, i, r)
        c = s.founding.contracts[i]
        log(&s, i, "Completed. Final payment \(due >= 0 ? Fmt.money(due) : "−" + Fmt.money(-due)); \(Fmt.money(c.paid)) received in all. Rated \(FCRating.title(r)).", 1)
        if r >= 3 { s.brand = min(100, s.brand + 1) }
        Sim.news(&s, "\(c.agencyShort) award completed: rated \(FCRating.title(r))",
                 "\"\(c.title)\" is closed out: \(Fmt.money(c.paid)) received against a \(Fmt.money(c.budget)) budget\(c.disallowed > 0 ? ", \(Fmt.money(c.disallowed)) disallowed at audit" : ""). Your record with \(c.agencyShort) is now \(Fmt.trim(AdvancedProjects.rating(s, c.agency), 1)).",
                 .company, image: HQ.city(s).image, important: true, good: true)
        Alerts.raise(&s, .milestone, key: "fc-done|\(c.id)", title: "Government award completed", body: "\(c.title): rated \(FCRating.title(r)).", screen: .advancedProjects, celebrate: true, cooldown: 0)
        followOn(&s, i, rating: r)
    }

    /// The agency's rating goes into your Advanced Projects record with it.
    static func record(_ s: inout GameState, _ i: Int, _ r: Int) {
        let c = s.founding.contracts[i]
        let delta = FCRating.record[clamp(r, 0, 4)]
        s.advanced.ratings[c.agency] = clamp(AdvancedProjects.rating(s, c.agency) + delta, -10, 10)
        Stakeholders.move(&s, [HQ.region(s).rawValue: r >= 3 ? 2 : (r >= 2 ? 1 : (r == 1 ? -1 : -2))], "\(c.agencyShort) rated your \(c.programme) award \(FCRating.title(r))")
    }

    /// The period ran out with work undelivered: closed out incomplete.
    static func lapse(_ s: inout GameState) {
        let i = 0
        let c = s.founding.contracts[i]
        let modelMet = c.milestones.first { $0.kind == .model }?.met != nil
        let r = modelMet ? 1 : 0
        var due: Double = 0
        switch c.terms {
        case .fixedPrice: due = 0
        case .costPlus: due = c.status == .active ? c.voucher : 0
        case .grant: due = grantEarned(c) * c.budget * (1 - c.retention) - c.paid
        }
        if due >= 0 { pay(&s, i, due) } else { recover(&s, i, -due) }
        s.founding.contracts[i].voucher = 0
        s.founding.contracts[i].status = .lapsed
        s.founding.contracts[i].ended = s.date
        s.founding.contracts[i].finalRating = r
        record(&s, i, r)
        let left = c.milestones.filter { $0.met == nil && $0.kind != .final }.map { $0.title.lowercased() }
        log(&s, i, "Period of performance ended with \(left.joined(separator: ", ")) undelivered. Closed out incomplete; rated \(FCRating.title(r)).", -1)
        Sim.news(&s, "\(c.agencyShort) award closed out incomplete", "\"\(c.title)\" ran out of time with \(left.joined(separator: ", ")) undelivered\(due < 0 ? "; \(Fmt.money(-due)) of unspent advance goes back" : ""). Rated \(FCRating.title(r)); no follow-on.",
                 .company, important: true, good: false)
    }

    static func terminate(_ s: inout GameState, _ i: Int) {
        let c = s.founding.contracts[i]
        // A grant's advance beyond the costs you can justify is recovered; a contract pays nothing more.
        let back = c.terms == .grant ? max(0, c.paid - grantEarned(c) * c.budget * (1 - c.retention)) : 0
        recover(&s, i, back)
        s.founding.contracts[i].voucher = 0
        s.founding.contracts[i].status = .terminated
        s.founding.contracts[i].ended = s.date
        s.founding.contracts[i].stopUntil = nil
        s.founding.contracts[i].finalRating = 0
        record(&s, i, 0)
        s.brand = max(0, s.brand - 1)
        log(&s, i, "Terminated for default\(back > 0 ? "; \(Fmt.money(back)) of the advance recovered" : "").", -1)
        Sim.news(&s, "\(c.agencyShort) terminates \"\(c.title)\" for default", "The stop-work order ran out with work still overdue. \(c.agencyShort) rates the award Unsatisfactory\(back > 0 ? " and recovers \(Fmt.money(back)) of unspent advance" : ""); that record follows you to its future solicitations.",
                 .company, important: true, good: false)
        Alerts.raise(&s, .advanced, key: "fc-term|\(c.id)", title: "Award terminated: \(c.title)", body: "Terminated for default. Record with \(c.agencyShort) −3.", screen: .advancedProjects, cooldown: 0)
    }

    // MARK: Follow-on

    static func followOn(_ s: inout GameState, _ i: Int, rating r: Int) {
        let c = s.founding.contracts[i]
        guard r >= 2, let sc = scheme(c) else { return }
        if sc.phases.count > c.phase {
            // Phase II / the option period: offered to the incumbent.
            let ph = sc.phases[c.phase]
            var n = FoundingContract()
            n.id = "fc\(s.founding.contracts.count + 1)-\(sc.id)"
            n.scheme = sc.id
            n.phase = c.phase + 1
            n.agency = c.agency
            n.programme = "\(sc.programme) — \(ph.name)"
            n.number = "\(c.number.split(separator: "-").prefix(2).joined(separator: "-"))-\(sc.instrument)-\(1000 + Int(roll(s, "number|\(n.id)") * 8999))"
            n.title = c.title
            n.objective = "Take \"\(c.title)\" from feasibility to a working prototype the agency can put in front of users."
            n.officer = c.officer
            n.manager = c.manager
            n.chargeShare = c.chargeShare
            configure(&n, ph, sc, tier: tier(s), s, stretch: false)
            if r >= 4 { n.budget = roundMoney(n.budget * 1.15) }   // an Exceptional Phase I earns the full ask
            n.status = .offered
            n.offerExpires = GameCalendar.addDays(s.date, Alerts.inboxDays(phaseKind))
            n.history = [ProgrammeEvent(date: s.date, text: "\(c.agencyShort) offers \(ph.name): \(Fmt.money(n.budget)) over \(n.months) months.", tone: 1)]
            s.founding.contracts.insert(n, at: 0)
            sendOffer(&s, 0, intro: "On the strength of a \(FCRating.title(r)) rating, \(c.manager) offers the follow-on without competition.", kind: phaseKind)
            return
        }
        guard r >= 3 else { return }
        transition(&s, i)
    }

    /// The last phase delivered well: the agency invites a sole-source bid on a full programme (Advanced Projects).
    static func transition(_ s: inout GameState, _ i: Int) {
        let c = s.founding.contracts[i]
        guard let a = c.agencyDef, s.founding.transition.isEmpty else { return }
        let y = s.year
        let options = AgencyCatalog.templates.filter { $0.agencies.contains(a.id) && $0.id != "seedling" && $0.year <= y && $0.classification <= 1 }
        guard !options.isEmpty else {
            log(&s, i, "\(a.short) has no open programme to follow on with this year; your record will count in its next solicitations.")
            return
        }
        let t = options[min(options.count - 1, Int(roll(s, "transition|\(c.id)") * Double(options.count)))]
        let sol = AdvancedProjects.make(t, a, s, key: "founding|\(c.id)", followOn: true, scale: 1, level: min(t.classification, 1), phase: 2)
        guard sol.ceiling >= 1e4 else { return }
        s.advanced.counter += 1
        s.advanced.solicitations.append(sol)
        s.founding.transition = sol.id
        log(&s, i, "\(a.short) invites a sole-source bid on \(sol.title) (\(Fmt.money(sol.ceiling))).", 1)
        Sim.news(&s, "\(a.short) invites a follow-on bid", "After \"\(c.title)\", \(a.name) invites you to bid on \(sol.title): up to \(Fmt.money(sol.ceiling)) over \(sol.months) months, with few or no competitors. It's on the Advanced Projects marketplace until \(sol.closes.gameShort).",
                 .company, image: t.image, important: true, good: true)
        Alerts.raise(&s, .advanced, key: "fc-transition|\(c.id)", title: "Follow-on bid invited: \(sol.title)", body: "Up to \(Fmt.money(sol.ceiling)); bid on the Advanced Projects marketplace by \(sol.closes.gameShort).", screen: .advancedProjects, cooldown: 0)
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let i = s.founding.contracts.firstIndex(where: { $0.id == d.ref }), i == 0 else { return }
        switch d.kind {
        case offerKind, phaseKind:
            guard s.founding.contracts[i].status == .offered else { return }
            switch option {
            case 0: sign(&s, i, stretch: false)
            case 1: sign(&s, i, stretch: true)
            default: decline(&s, i)
            }
        case extensionKind:
            if option == 0 { _ = extend(&s, i) } else { log(&s, i, "You let the period run out without an extension.") }
        default:
            break
        }
    }

    // MARK: Read-only views

    /// Dated things for the dashboard's Coming up card.
    static func upcoming(_ s: GameState) -> [Agenda.Upcoming] {
        guard let c = s.founding.current else { return [] }
        var out: [Agenda.Upcoming] = []
        if c.status == .offered, let e = c.offerExpires {
            out.append(Agenda.Upcoming(id: "fc-offer", date: e, title: "Sign or decline: \(c.agencyShort) award", detail: "\(Fmt.money(c.budget)) over \(c.months) months · signs the standard scope if you don't answer",
                                       symbol: "signature", tone: .warning, screen: .dashboard))
        }
        guard c.status.live else { return out }
        if let m = c.next(s.date) {
            let soon = GameCalendar.daysBetween(s.date, m.due) < 30
            let pays = milestonePayment(c, m)
            out.append(Agenda.Upcoming(id: "fc-\(m.id)", date: max(s.date, m.due), title: "\(c.agencyShort) milestone: \(m.title)",
                                       detail: (m.due < s.date ? "Overdue since \(m.due.gameShort)" : "Due") + (pays > 0.5 ? " · pays \(Fmt.money(pays))" : ""),
                                       symbol: m.kind.symbol, tone: m.due < s.date ? .bad : (soon ? .warning : .neutral), screen: .advancedProjects))
        }
        if c.reviewRating == nil {
            out.append(Agenda.Upcoming(id: "fc-review", date: c.midterm, title: "Mid-term review: \(c.title)", detail: "\(c.manager) rates progress; slipping draws a cure notice",
                                       symbol: "checklist", tone: rating(progressScore(s, c)) <= 1 ? .warning : .neutral, screen: .advancedProjects))
        }
        out.append(Agenda.Upcoming(id: "fc-end", date: c.end, title: "\(c.agencyShort) award period ends", detail: "\(c.metCount) of \(c.milestones.count) milestones met",
                                   symbol: "flag.checkered", screen: .advancedProjects))
        return out
    }

    /// One-line status for harnesses.
    static func statusLine(_ s: GameState, _ c: FoundingContract) -> String {
        let next = c.next(s.date).map { " · next \($0.title) due \($0.due.gameShort)\($0.due < s.date ? " (OVERDUE)" : "")" } ?? ""
        return "FOUNDING [\(c.status.title)] \(c.agencyShort) \(c.programme) · \(c.terms.short) \(Fmt.money(c.budget)) · paid \(Fmt.money(c.paid)) · charged \(Fmt.money(c.charged)) · \(c.metCount)/\(c.milestones.count) met"
            + (c.reviewRating.map { " · mid-term \(FCRating.title($0))" } ?? "") + (c.finalRating.map { " · final \(FCRating.title($0))" } ?? "") + next
    }

    nonisolated(unsafe) private static var replaySeen: [String: Int] = [:]

    /// `REPLAY_CONTRACT=1`: contract events since the last call, and a status line at each month start.
    static func replayLines(_ s: GameState) -> [String] {
        var out: [String] = []
        for c in s.founding.contracts.reversed() {
            let n = c.history.count, k = replaySeen[c.id] ?? 0
            if n > k {
                for e in c.history.prefix(n - k).reversed() { out.append("    FOUNDING \(e.date.gameShort) \(c.agencyShort) P\(c.phase): \(e.text)") }
                if c.history.prefix(n - k).contains(where: { $0.text.hasPrefix("Signed") }) { out += describe(s, c).map { "    " + $0 } }
            }
            replaySeen[c.id] = n
        }
        if GameCalendar.components(s.date).day == 1, let c = s.founding.current { out.append("    " + statusLine(s, c)) }
        return out
    }

    /// `REPLAY_CONTRACT=play`: a player working the statement of work — hires for key personnel, trains when a model is
    /// owed (renting chips if none are free) and releases a model that meets the bar. Harness only.
    static func assist(_ s: inout GameState) {
        guard let c = s.founding.current, c.status.live else { return }
        let open = c.milestones.filter { $0.met == nil }
        if open.contains(where: { $0.kind == .staffing }), GameCalendar.components(s.date).day % 10 == 0,
           let cand = s.candidates.filter({ $0.role == .researcher || $0.role == .mlEngineer }).max(by: { $0.skill < $1.skill }) {
            print("    ASSIST hire \(cand.name): \(s.hire(cand.id) ?? "ok")")
        }
        if let m = open.first(where: { $0.kind == .model || $0.kind == .release }) {
            if let best = newModels(s, c).filter({ !$0.released && $0.c >= m.target }).first { print("    ASSIST release \(best.name): \(s.release(best.id, api: true, openWeights: false) ?? "ok")") }
            if !s.runs.contains(where: { $0.status == .running || $0.status == .postTraining || $0.status == .paused }) {
                if RunPlanner.proposals(s).isEmpty, !s.rentals.contains(where: { $0.end == nil }), let a = HardwareCatalog.all.filter({ Economy.canRent($0, s) && $0.cls == .datacenter }).max(by: { $0.trainTFLOPS(.bf16) < $1.trainTFLOPS(.bf16) }) {
                    let n = max(8, min(Economy.rentalLimit(a, s), Int(s.cash * 0.05 / max(1, (Economy.rent(a, s) ?? 2) * 24 * 120))))
                    print("    ASSIST rent \(n)× \(a.name): \(s.rentHardware(a.id, count: n, term: .onDemand) ?? "ok")")
                }
                if let p = RunPlanner.proposals(s).first { print("    ASSIST train \(p.design.name) forecast capability \(Fmt.trim(p.est.forecast.c, 2)) vs bar \(Fmt.trim(m.target, 2)): \(RunPlanner.start(p, &s) ?? "started")") }
            }
        }
    }

    /// The offer as text (harness).
    static func describe(_ s: GameState, _ c: FoundingContract) -> [String] {
        var out = ["  \(c.programme) — \(c.agencyDef?.name ?? c.agency) (\(c.number))", "    \"\(c.title)\": \(c.objective)",
                   "    \(Fmt.money(c.budget)) over \(c.months) months · \(termsLine(c))"]
        if let ph = phaseDef(c) {
            let due = GameCalendar.addDays(c.status == .offered ? s.date : c.start, Int(Double(c.months) * FCMilestoneKind.model.dueShare * 30.4))
            let bar = c.milestones.first { $0.kind == .model }?.target ?? modelTarget(s, ph, due: due, stretch: false)
            out.append("    model bar \(barText(s, bar)), frontier now \(Fmt.trim(Macro.frontier(s.year), 2)), your best \(s.models.map(\.c).max().map { Fmt.trim($0, 2) } ?? "none")")
        }
        for m in c.milestones { out.append("    · \(m.title) due \(m.due.gameShort)\(m.share > 0 ? " (\(Fmt.pct(m.share, decimals: 0)))" : "")\(m.met.map { " — met \($0.gameShort)" } ?? "")") }
        return out
    }
}

// MARK: - Player actions

extension GameState {
    /// Ask the agency for the one no-cost extension it grants (from the award card).
    mutating func requestFoundingExtension() -> String? {
        guard let c = founding.current, c.status.live else { return "No award is running." }
        guard FoundingContracts.needsMoreTime(c) else { return "Every deliverable is in; there's nothing to extend for." }
        guard date >= c.midterm else { return "Agencies consider extensions after the mid-term review." }
        return FoundingContracts.extend(&self, 0)
    }

    /// Put the statement of work's research item in the queue (from the award card).
    mutating func queueFoundingResearch() -> String? {
        guard let c = founding.current, let m = c.milestones.first(where: { $0.kind == .research && $0.met == nil }) else { return "Nothing to queue." }
        return queueResearch(m.ref)
    }
}
