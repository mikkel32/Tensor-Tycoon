import Foundation

/// 3.10: how a government AI branch asks for money. Every 90 days the director can put a funding request to the
/// committee; it is judged on a case built from what the programme delivered since its last approved request (research,
/// models, capability, missions, agency models) and how it is run (safety, security, oversight, reserves). The outcome
/// is shown before you ask, so a request is never a gamble.
enum PublicFunding {
    static let cooldownDays = 90
    /// A case this many points short of an ask's bar gets nothing; in between, a share of it.
    static let partialBand = 25.0

    struct CaseLine: Identifiable {
        var id: String { title }
        var title: String
        var symbol: String
        var detail: String
        var points: Double
        var max: Double
    }

    static func builtModels(_ s: GameState) -> [AIModel] { s.models.filter { !$0.preview } }
    static func bestC(_ s: GameState) -> Double { builtModels(s).map(\.c).max() ?? -10 }

    static func snapshot(_ s: GameState) -> ProgressSnapshot {
        ProgressSnapshot(date: s.date, researched: s.researched.count, models: builtModels(s).count, bestC: bestC(s),
                         missions: s.publicProgram.completedMissions, missed: s.publicProgram.failedMissions,
                         commissions: s.publicProgram.commissionsDelivered, security: s.securityRaw)
    }

    /// The evidence the committee weighs, line by line.
    static func lines(_ s: GameState) -> [CaseLine] {
        let p = s.publicProgram
        let base = p.evidence ?? snapshot(s)
        let since = base.date.gameShort
        var out: [CaseLine] = []

        let research = max(0, s.researched.count - base.researched)
        out.append(CaseLine(title: "Research delivered", symbol: "lightbulb.fill",
                            detail: research == 0 ? "Nothing finished since \(since). Keep the research queue full." : "\(research) project\(research == 1 ? "" : "s") finished since \(since).",
                            points: min(25, 4 * Double(research)), max: 25))

        let models = max(0, builtModels(s).count - base.models)
        out.append(CaseLine(title: "Models trained", symbol: "cpu.fill",
                            detail: models == 0 ? "No new model since \(since)." : "\(models) new model\(models == 1 ? "" : "s") since \(since).",
                            points: min(15, 6 * Double(models)), max: 15))

        let best = bestC(s)
        let gain = base.bestC <= -10 ? (best > -10 ? 1.0 : 0) : best - base.bestC
        out.append(CaseLine(title: "Capability gained", symbol: "chart.line.uptrend.xyaxis",
                            detail: best <= -10 ? "No model yet." : base.bestC <= -10 ? "First model at capability \(Fmt.trim(best, 2))." : "Best model \(Fmt.trim(base.bestC, 2)) → \(Fmt.trim(best, 2)).",
                            points: clamp(gain * 15, 0, 15), max: 15))

        let gap = Macro.frontier(s.year) - best
        out.append(CaseLine(title: "Against the frontier", symbol: "flag.checkered",
                            detail: best <= -10 ? "Nothing to compare yet." : gap <= 0 ? "Your best model is at the frontier." : "Your best model is \(Fmt.trim(gap, 1)) behind the world's best.",
                            points: gap <= 0.5 ? 10 : gap <= 1.5 ? 6 : gap <= 2.5 ? 3 : 0, max: 10))

        let done = max(0, p.completedMissions - base.missions)
        let missed = max(0, p.failedMissions - base.missed)
        out.append(CaseLine(title: "Public missions", symbol: "target",
                            detail: done + missed == 0 ? "No mission closed since \(since)." : "\(done) delivered, \(missed) missed since \(since).",
                            points: clamp(8 * Double(done) - 6 * Double(missed), -12, 24), max: 24))

        let delivered = max(0, p.commissionsDelivered - base.commissions)
        out.append(CaseLine(title: "Agency models delivered", symbol: "building.2.fill",
                            detail: delivered == 0 ? "No agency model handed over since \(since)." : "\(delivered) agency model\(delivered == 1 ? "" : "s") in service since \(since).",
                            points: min(20, 10 * Double(delivered)), max: 20))

        let levels = max(0, s.securityRaw - base.security)
        out.append(CaseLine(title: "Safety and security", symbol: "checkmark.shield.fill",
                            detail: "Safety \(Int(s.safetyScore))/100" + (levels > 0 ? ", security up \(levels) level\(levels == 1 ? "" : "s")." : ", security SL\(s.security.rawValue)."),
                            points: min(10, clamp((s.safetyScore - 40) / 5, 0, 6) + 3 * Double(levels)), max: 10))

        let reserves = max(0, s.cash) > PublicProgram.authorisedBudget(s)
        let stewardship = clamp((p.oversight - 50) / 4, -10, 8) - (p.probation ? 8 : 0) - (reserves ? 5 : 0)
        out.append(CaseLine(title: "Stewardship", symbol: "building.columns.fill",
                            detail: "Oversight \(Int(p.oversight))/100" + (p.probation ? ", on probation" : "") + (reserves ? ", and over a year's budget unspent" : "") + ".",
                            points: stewardship, max: 8))
        return out
    }

    /// The strength of the case, 0–100.
    static func score(_ s: GameState) -> Double { clamp(lines(s).reduce(0) { $0 + $1.points }, 0, 100) }

    /// Share of an ask the committee approves at this score.
    static func fraction(_ ask: FundingAsk, score: Double) -> Double { clamp(1 - (ask.bar - score) / partialBand, 0, 1) }

    /// What an ask would bring today: the one-off payment and the rise in the base budget (as a share).
    static func outcome(_ ask: FundingAsk, _ s: GameState) -> (fraction: Double, amount: Double, raise: Double) {
        let f = fraction(ask, score: score(s))
        return (f, PublicProgram.authorisedBudget(s) * ask.oneOff * f, ask.raise * f)
    }

    /// When the committee will next hear a request (nil if it would today).
    static func readyOn(_ s: GameState) -> Date? {
        guard let last = s.publicProgram.lastRequest else { return nil }
        let ready = GameCalendar.addDays(last, cooldownDays)
        return ready > s.date ? ready : nil
    }
}

// MARK: - Agency commissions

/// 3.10: agencies order models built for them. An offer waits 45 days; once accepted, you train a model that meets
/// its bar and hand it over for 80% of the contract (20% comes up front), then a service fee for two years.
enum Commissions {
    struct Agency {
        var name: String
        var symbol: String
        var title: String
        var detail: String
        var domain: CapDomain
        var mandate: PublicMandate
        var evaluated = false
        var safety: Double = 0
        var internalOnly = false
        var openWeights = false
        var security = 0
    }

    static let agencies: [Agency] = [
        Agency(name: "Tax Agency", symbol: "doc.text.fill", title: "Casework assistant",
               detail: "Reads returns and drafts caseworker summaries. Taxpayer data never leaves the agency, so the model stays internal.",
               domain: .knowledge, mandate: .digitalServices, internalOnly: true),
        Agency(name: "National Health Service", symbol: "cross.case.fill", title: "Clinical triage assistant",
               detail: "Helps nurses triage calls. It must be independently evaluated and safety-tuned before it touches a patient.",
               domain: .science, mandate: .digitalServices, evaluated: true, safety: 60),
        Agency(name: "Citizen Services", symbol: "person.2.wave.2.fill", title: "Multilingual helpline",
               detail: "Answers residents in every official language, day and night.",
               domain: .multilingual, mandate: .digitalServices),
        Agency(name: "Courts Service", symbol: "scale.3d", title: "Case-law summariser",
               detail: "Summarises filings and precedent for judges' clerks, on the courts' own systems.",
               domain: .reasoning, mandate: .digitalServices, internalOnly: true),
        Agency(name: "Employment Agency", symbol: "briefcase.fill", title: "Job-matching agent",
               detail: "Matches job seekers to openings and books the interviews itself.",
               domain: .agents, mandate: .digitalServices),
        Agency(name: "Research Council", symbol: "atom", title: "Open lab assistant",
               detail: "A model every university lab can download, inspect and fine-tune: released with open weights.",
               domain: .science, mandate: .openScience, openWeights: true),
        Agency(name: "National Library", symbol: "books.vertical.fill", title: "Open archive model",
               detail: "Reads and translates centuries of the national archive, published with open weights.",
               domain: .multilingual, mandate: .openScience, openWeights: true),
        Agency(name: "Met Office", symbol: "cloud.sun.rain.fill", title: "Climate analyst",
               detail: "Works through model ensembles and writes the forecasters' briefings.",
               domain: .math, mandate: .openScience),
        Agency(name: "University Network", symbol: "graduationcap.fill", title: "Open coding tutor",
               detail: "Teaches programming to every student in the country, with open weights so campuses can host it.",
               domain: .coding, mandate: .openScience, openWeights: true),
        Agency(name: "Statistics Office", symbol: "chart.bar.xaxis", title: "Survey analyst",
               detail: "Cleans survey returns and drafts the monthly releases.",
               domain: .math, mandate: .openScience),
        Agency(name: "Defence Ministry", symbol: "shield.lefthalf.filled", title: "Secure intelligence analyst",
               detail: "Fuses reports for analysts on classified networks: internal only, under security level 3.",
               domain: .reasoning, mandate: .nationalSecurity, internalOnly: true, security: 3),
        Agency(name: "Cyber Command", symbol: "lock.shield.fill", title: "Vulnerability hunter",
               detail: "Finds holes in national infrastructure before anyone else does. Evaluated, internal, SL3.",
               domain: .coding, mandate: .nationalSecurity, evaluated: true, internalOnly: true, security: 3),
        Agency(name: "Border Agency", symbol: "globe.europe.africa.fill", title: "Document screening",
               detail: "Reads travel documents in any language, on the agency's own systems.",
               domain: .multilingual, mandate: .nationalSecurity, internalOnly: true, security: 2),
        Agency(name: "Emergency Management", symbol: "light.beacon.max.fill", title: "Crisis coordinator",
               detail: "Coordinates shelters, supplies and responders when a disaster strikes.",
               domain: .agents, mandate: .nationalSecurity),
        Agency(name: "Signals Agency", symbol: "antenna.radiowaves.left.and.right", title: "Translation and signals analyst",
               detail: "Translates and triages intercepted traffic: internal only, under security level 4.",
               domain: .multilingual, mandate: .nationalSecurity, internalOnly: true, security: 4),
    ]

    static let offerEveryDays = 45
    static let offerDays = 45
    static let maxOffers = 2
    static let maxActive = 3
    static let maxRecord = 16
    static let upfront = 0.2

    static func open(_ s: GameState) -> [AgencyCommission] { s.publicProgram.commissions.filter { $0.status == .offered } }
    static func active(_ s: GameState) -> [AgencyCommission] { s.publicProgram.commissions.filter { $0.status == .active } }
    static func inService(_ s: GameState) -> [AgencyCommission] { s.publicProgram.commissions.filter { $0.status == .inService } }

    /// Agencies that can ask today: not already waiting on you, evaluations researched if they want one, and a security
    /// level the programme can reach.
    static func candidates(_ s: GameState) -> [Agency] {
        let busy = Set(s.publicProgram.commissions.filter { [.offered, .active, .inService].contains($0.status) }.map(\.agency))
        return agencies.filter {
            !busy.contains($0.name) && (!$0.evaluated || s.researched.contains("evals_rsp")) && $0.security <= s.securityRaw + 1
        }
    }

    static func offer(_ s: inout GameState) {
        let pool = candidates(s)
        guard !pool.isEmpty else { return }
        let own = pool.filter { $0.mandate == s.publicProgram.mandate }
        let preferOwn = !own.isEmpty && s.rng.chance(0.7)
        let a = s.rng.pick(preferOwn ? own : pool)
        let level = Double(clamp(s.publicProgram.level, 1, 4))
        let frontier = Macro.frontier(s.year)
        let capability = frontier - 2 + 0.15 * level
        let extras = Double([a.evaluated, a.internalOnly, a.openWeights, a.security > 0, a.safety > 0].filter { $0 }.count)
        let value = max(2_000_000, PublicProgram.authorisedBudget(s) * (0.18 + 0.04 * extras + 0.02 * level)).rounded(to: 100_000)
        s.publicProgram.commissionSequence += 1
        let c = AgencyCommission(id: "commission-\(s.publicProgram.commissionSequence)", agency: a.name, symbol: a.symbol, title: a.title,
                                 detail: a.detail, domain: a.domain, capabilityMin: capability, domainEdgeMin: ((capability - frontier) * 10 - 8).rounded(),
                                 safetyMin: a.safety, needsEvaluation: a.evaluated, securityMin: a.security, openWeights: a.openWeights,
                                 internalOnly: a.internalOnly, value: value, serviceYearly: (value * 0.3).rounded(to: 10_000),
                                 deliveryDays: 300 + (a.security > 0 ? 60 : 0), offered: s.date, expires: GameCalendar.addDays(s.date, offerDays))
        s.publicProgram.commissions.append(c)
        s.publicProgram.lastCommissionOffer = s.date
        Sim.news(&s, "\(a.name) wants a model: \(a.title)",
                 "\(Fmt.money(value)) to build it, then \(Fmt.money(c.serviceYearly)) a year to run it. Accept or decline on Funding & Commissions within \(offerDays) days.",
                 .policy, image: "gov_capitol", important: true, good: true)
    }

    struct Check: Identifiable {
        var id: String { label }
        var label: String
        var met: Bool
        var detail: String
    }

    /// Everything the agency checks before it signs a model off, with how this model does.
    static func checks(_ c: AgencyCommission, _ m: AIModel, _ s: GameState) -> [Check] {
        var out: [Check] = []
        if let accepted = c.accepted {
            out.append(Check(label: "Built for this order", met: m.created >= accepted, detail: m.created >= accepted ? "Trained \(m.created.gameShort)" : "Trained before you accepted (\(m.created.gameShort))"))
        }
        out.append(Check(label: "Capability \(Fmt.trim(c.capabilityMin, 2))+", met: m.c >= c.capabilityMin, detail: Fmt.trim(m.c, 2)))
        let edge = Capabilities.edge(m, c.domain, s)
        out.append(Check(label: "\(c.domain.label) \(signed(c.domainEdgeMin))+ vs frontier", met: edge >= c.domainEdgeMin, detail: signed(edge.rounded())))
        if c.safetyMin > 0 { out.append(Check(label: "Model safety \(Int(c.safetyMin))+", met: m.safety >= c.safetyMin, detail: "\(Int(m.safety))")) }
        if c.needsEvaluation { out.append(Check(label: "Independently evaluated", met: m.evaluated, detail: m.evaluated ? "Done" : (m.evalDue.map { "Reports \($0.gameShort)" } ?? "Not yet"))) }
        if c.internalOnly { out.append(Check(label: "Never released publicly", met: !m.released, detail: m.released ? "Released" : "Internal")) }
        if c.openWeights { out.append(Check(label: "Released with open weights", met: m.released && m.openWeights, detail: m.openWeights ? "Open" : (m.released ? "Released closed" : "Not released"))) }
        if c.securityMin > 0 { out.append(Check(label: "Programme at SL\(c.securityMin)+", met: s.securityRaw >= c.securityMin, detail: "SL\(s.security.rawValue)")) }
        return out
    }

    static func qualifies(_ c: AgencyCommission, _ m: AIModel, _ s: GameState) -> Bool {
        !m.retired && !m.preview && checks(c, m, s).allSatisfy(\.met)
    }

    /// Models worth showing against an order: built since it was accepted, best first.
    static func candidatesModels(_ c: AgencyCommission, _ s: GameState) -> [AIModel] {
        s.models.filter { !$0.retired && !$0.preview && $0.created >= (c.accepted ?? c.offered) }
            .sorted { (qualifies(c, $0, s) ? 1 : 0, $0.c) > (qualifies(c, $1, s) ? 1 : 0, $1.c) }
    }

    static func signed(_ x: Double) -> String { x >= 0 ? "+\(Fmt.trim(x, 0))" : Fmt.trim(x, 0) }

    static func pay(_ s: inout GameState, _ i: Int, _ amount: Double) {
        s.cash += amount
        s.month.revContracts += amount
        s.publicProgram.totalReceived += amount
        s.publicProgram.commissions[i].paid += amount
    }

    static func close(_ s: inout GameState, _ i: Int, _ status: CommissionStatus) {
        s.publicProgram.commissions[i].status = status
        s.publicProgram.commissions[i].closed = s.date
    }

    static func daily(_ s: inout GameState) {
        for i in s.publicProgram.commissions.indices {
            let c = s.publicProgram.commissions[i]
            switch c.status {
            case .offered where s.date > c.expires:
                close(&s, i, .expired)
            case .active where c.due.map({ s.date > $0 }) ?? false:
                close(&s, i, .failed)
                s.publicProgram.commissionsFailed += 1
                s.publicProgram.oversight = clamp(s.publicProgram.oversight - 4, 0, 100)
                PublicProgram.note(&s, "Missed the \(c.agency) order (\(c.title)): oversight −4. The up-front payment is kept.", good: false)
                Sim.news(&s, "\(c.agency) cancels its model order", "The deadline for the \(c.title.lowercased()) passed without a model that met the bar. Oversight confidence falls 4 points.",
                         .policy, important: true, good: false)
            case .inService:
                let m = s.models.first { $0.id == c.modelID }
                if c.internalOnly, m?.released == true {
                    close(&s, i, .cancelled)
                    s.publicProgram.oversight = clamp(s.publicProgram.oversight - 10, 0, 100)
                    PublicProgram.note(&s, "\(c.modelName) was released publicly against the \(c.agency)'s terms: contract ended, oversight −10.", good: false)
                    Sim.news(&s, "\(c.agency) pulls \(c.modelName)", "The model it paid for was meant to stay internal. The service contract ends and oversight falls 10 points.",
                             .policy, important: true, good: false)
                } else if m == nil || m?.retired == true || c.serviceUntil.map({ s.date >= $0 }) ?? true {
                    close(&s, i, .completed)
                    PublicProgram.note(&s, "\(c.agency)'s \(c.title.lowercased()) completed its service term (\(Fmt.money(c.paid)) received in all).", good: true)
                }
            default:
                break
            }
        }
        let due = s.publicProgram.lastCommissionOffer.map { GameCalendar.daysBetween($0, s.date) >= offerEveryDays } ?? true
        if due && open(s).count < maxOffers && active(s).count < maxActive { offer(&s) }
        trim(&s)
    }

    /// Service fees, once a month.
    static func monthly(_ s: inout GameState) {
        for i in s.publicProgram.commissions.indices where s.publicProgram.commissions[i].status == .inService {
            pay(&s, i, s.publicProgram.commissions[i].serviceYearly / 12)
        }
    }

    static func trim(_ s: inout GameState) {
        let closed = s.publicProgram.commissions.filter { ![.offered, .active, .inService].contains($0.status) }
        guard closed.count > maxRecord else { return }
        let drop = Set(closed.prefix(closed.count - maxRecord).map(\.id))
        s.publicProgram.commissions.removeAll { drop.contains($0.id) }
    }
}

private extension Double {
    func rounded(to step: Double) -> Double { (self / step).rounded() * step }
}

// MARK: - Player actions

extension GameState {
    mutating func requestPublicFunding(_ ask: FundingAsk) -> String? {
        guard isPublicProgram else { return "Only a government AI branch asks the committee for funding." }
        if let ready = PublicFunding.readyOn(self) { return "The committee hears one request a quarter. The next can go in on \(ready.gameShort)." }
        let score = PublicFunding.score(self)
        let o = PublicFunding.outcome(ask, self)
        guard o.fraction > 0 else {
            return "A \(ask.title.lowercased()) needs a case of at least \(Int(ask.bar - PublicFunding.partialBand)) (yours is \(Int(score))). Deliver more first."
        }
        cash += o.amount
        month.revContracts += o.amount
        publicProgram.totalReceived += o.amount
        publicProgram.annualBudget *= 1 + o.raise
        let full = o.fraction >= 1
        if full { publicProgram.oversight = clamp(publicProgram.oversight + 2, 0, 100) }
        boardConfidence = publicProgram.oversight
        publicProgram.requests.insert(FundingRequest(id: "request-\(publicProgram.requests.count + 1)-\(Int(date.timeIntervalSince1970))", date: date, ask: ask,
                                                     score: score, fraction: o.fraction, amount: o.amount, raise: o.raise), at: 0)
        if publicProgram.requests.count > 12 { publicProgram.requests.removeLast(publicProgram.requests.count - 12) }
        publicProgram.lastRequest = date
        publicProgram.evidence = PublicFunding.snapshot(self)
        let raiseText = o.raise > 0 ? " and the base budget rises \(Fmt.pct(o.raise, decimals: 0))" : ""
        PublicProgram.note(&self, "\(ask.title) request \(full ? "approved" : "\(Fmt.pct(o.fraction, decimals: 0)) approved") on a case of \(Int(score)): \(Fmt.money(o.amount))\(raiseText).", good: true)
        Sim.news(&self, "Funding \(full ? "approved" : "partly approved"): \(Fmt.money(o.amount))",
                 "The committee weighed \(companyName)'s record (a case of \(Int(score))/100) and released \(Fmt.money(o.amount))\(raiseText). The next request can go in on \(GameCalendar.addDays(date, PublicFunding.cooldownDays).gameShort).",
                 .policy, image: "gov_capitol", important: true, good: true)
        return nil
    }

    mutating func acceptCommission(_ id: String) -> String? {
        guard isPublicProgram, let i = publicProgram.commissions.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let c = publicProgram.commissions[i]
        guard c.status == .offered else { return "That order is no longer open." }
        if Commissions.active(self).count >= Commissions.maxActive { return "You can build for \(Commissions.maxActive) agencies at once. Deliver one first." }
        publicProgram.commissions[i].status = .active
        publicProgram.commissions[i].accepted = date
        publicProgram.commissions[i].due = GameCalendar.addDays(date, c.deliveryDays)
        Commissions.pay(&self, i, c.value * Commissions.upfront)
        PublicProgram.note(&self, "Accepted the \(c.agency)'s order for a \(c.title.lowercased()): \(Fmt.money(c.value * Commissions.upfront)) up front.", good: true)
        Sim.news(&self, "Building for the \(c.agency)", "\(Fmt.money(c.value * Commissions.upfront)) up front; \(Fmt.money(c.value * (1 - Commissions.upfront))) more when a model built for it meets the bar by \(GameCalendar.addDays(date, c.deliveryDays).gameShort).",
                 .policy, image: "gov_capitol", good: true)
        return nil
    }

    mutating func declineCommission(_ id: String) {
        guard let i = publicProgram.commissions.firstIndex(where: { $0.id == id && $0.status == .offered }) else { return }
        Commissions.close(&self, i, .declined)
    }

    mutating func deliverCommission(_ id: String, modelID: UUID) -> String? {
        guard isPublicProgram, let i = publicProgram.commissions.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let c = publicProgram.commissions[i]
        guard c.status == .active else { return "That order isn't waiting for a model." }
        guard let m = models.first(where: { $0.id == modelID }) else { return "Model not found." }
        if let miss = Commissions.checks(c, m, self).first(where: { !$0.met }) { return "\(m.name) doesn't meet the bar yet: \(miss.label.lowercased()) (\(miss.detail))." }
        publicProgram.commissions[i].status = .inService
        publicProgram.commissions[i].modelID = m.id
        publicProgram.commissions[i].modelName = m.name
        publicProgram.commissions[i].delivered = date
        publicProgram.commissions[i].serviceUntil = GameCalendar.addMonths(date, c.serviceMonths)
        Commissions.pay(&self, i, c.value * (1 - Commissions.upfront))
        publicProgram.commissionsDelivered += 1
        publicProgram.oversight = clamp(publicProgram.oversight + 4, 0, 100)
        boardConfidence = publicProgram.oversight
        culturePoints += 1
        Stakeholders.move(&self, ["public": 1], "\(m.name) delivered to the \(c.agency)")
        PublicProgram.note(&self, "Delivered \(m.name) to the \(c.agency): \(Fmt.money(c.value * (1 - Commissions.upfront))) now, \(Fmt.money(c.serviceYearly)) a year for \(c.serviceMonths / 12) years. Oversight +4.", good: true)
        Sim.news(&self, "\(m.name) goes to work at the \(c.agency)", "The \(c.title.lowercased()) passed every check. \(Fmt.money(c.value * (1 - Commissions.upfront))) on delivery, then \(Fmt.money(c.serviceYearly)) a year to run it; oversight confidence rises.",
                 .policy, image: "gov_capitol", important: true, good: true)
        return nil
    }
}
