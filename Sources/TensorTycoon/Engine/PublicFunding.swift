import Foundation

/// 3.10: what a government AI branch asks the state for. Funding, GPUs or more facility power is granted on request; the
/// committee attaches tasks scaled to the size, due by a deadline. Deliver them all and oversight rises; miss the
/// deadline and oversight falls, and for money 30% is withheld from the next quarterly budgets (for GPUs, half of them
/// are reassigned to other agencies). Tasks are fixed when you
/// ask (no dice), so the page shows exactly what a request will cost you in work before you make it.
enum GovRequests {
    static let maxOpen = 3
    static let clawbackShare = 0.3
    static let chipDays = 60
    static let powerDays = 150
    static let powerSteps: [Double] = [100_000, 250_000, 500_000]
    /// The facility a government branch starts with.
    static let facilityKW = 100_000.0

    static func open(_ s: GameState) -> [GovRequest] { s.publicProgram.grants.filter { $0.status == .active } }

    static func bestC(_ s: GameState) -> Double { s.models.filter { !$0.preview }.map(\.c).max() ?? -10 }

    // MARK: Sizes

    static func fundingRange(_ s: GameState) -> ClosedRange<Double> {
        let b = PublicProgram.authorisedBudget(s)
        return (b * 0.1).rounded(.up)...(b * 2).rounded(.down)
    }

    /// 1–4: how much work a request of this size carries.
    static func tier(share: Double) -> Int { share <= 0.3 ? 1 : share <= 0.6 ? 2 : share <= 1.2 ? 3 : 4 }
    static func fundingTier(_ amount: Double, _ s: GameState) -> Int { tier(share: amount / max(1, PublicProgram.authorisedBudget(s))) }

    static func facility(_ s: GameState) -> Site? {
        s.sites.first { $0.id == s.publicProgram.facilityID } ?? s.sites.first(where: \.stateFunded)
    }

    /// The newest datacenter GPU the state can procure today.
    static func chipChoice(_ s: GameState) -> Accelerator? {
        HardwareCatalog.all.filter { $0.cls == .datacenter && $0.vendor != .custom && Economy.canBuy($0, s) && Economy.price($0, s) != nil && Partners.blocker($0, s) == nil }
            .max { ($0.bf16, $0.id) < ($1.bf16, $1.id) }
    }

    static func fleet(_ s: GameState) -> Int {
        guard let f = facility(s) else { return 0 }
        return s.owned.filter { $0.siteID == f.id }.reduce(0) { $0 + $1.count }
    }

    /// Power the facility's chips draw (at full load), with GPUs already granted but not yet delivered.
    static func committedKW(_ s: GameState) -> Double {
        guard let f = facility(s) else { return 0 }
        let pending = open(s).filter { $0.kind == .chips && !$0.arrived }.reduce(0.0) { acc, r in acc + (HardwareCatalog.get(r.accelID).map { Economy.chipKW($0) } ?? 0) * Double(r.chips) }
        return Economy.siteLoadKW(s, f.id) + pending
    }

    static func capacityKW(_ s: GameState) -> Double { facility(s)?.capacityKW ?? 0 }
    static func pendingPowerKW(_ s: GameState) -> Double { open(s).filter { $0.kind == .power && !$0.arrived }.reduce(0) { $0 + $1.powerKW } }

    /// GPUs a request can bring: up to twice today's fleet, and what the facility can power once everything granted arrives.
    static func chipRange(_ s: GameState) -> ClosedRange<Int> {
        guard let a = chipChoice(s) else { return 0...0 }
        let step = max(1, a.minOrder)
        let room = Int(max(0, capacityKW(s) - committedKW(s)) / max(0.001, Economy.chipKW(a))) / step * step
        let top = min(room, max(1_024, 2 * fleet(s)) / step * step)
        let low = min(top, max(step, 128 / step * step))
        return low...max(low, top)
    }

    static func chipTier(_ n: Int, _ s: GameState) -> Int { tier(share: Double(n) / Double(max(512, fleet(s)))) }
    static func powerTier(_ kw: Double) -> Int { kw <= 100_000 ? 2 : kw <= 250_000 ? 3 : 4 }

    /// Why the committee won't fund more power yet (nil when it will).
    static func powerBlocker(_ s: GameState) -> String? {
        let cap = capacityKW(s)
        guard cap > 0 else { return "There is no state facility to expand." }
        if pendingPowerKW(s) > 0 { return "An expansion is already being built." }
        let used = committedKW(s) / cap
        return used < 0.5 ? "The facility uses \(Fmt.pct(used, decimals: 0)) of its \(Fmt.watts(cap * 1000)). More power is granted once it's half full." : nil
    }

    static func blocker(_ s: GameState) -> String? {
        guard s.isPublicProgram else { return "Only a government AI branch can ask the state." }
        return open(s).count >= maxOpen ? "You have \(maxOpen) requests with tasks open. Deliver one first." : nil
    }

    // MARK: Tasks

    static func days(_ tier: Int) -> Int { 120 + 60 * tier }

    /// The tasks a request of this tier would carry today, the same ones `request` attaches.
    static func tasks(_ s: GameState, tier t: Int) -> [GrantTask] {
        let p = s.publicProgram
        let frontier = Macro.frontier(s.year)
        let best = bestC(s)
        let cap = clamp(best > -10 ? best + 0.15 * Double(t) : frontier - 2.2, frontier - 2.2, frontier + 0.1)
        let order: [GrantTaskKind]
        switch p.mandate {
        case .digitalServices: order = [.train, .hire, .research, .release, .missions, .agency, .safety, .security]
        case .openScience: order = [.research, .release, .train, .safety, .missions, .agency, .hire, .security]
        case .nationalSecurity: order = [.train, .security, .research, .safety, .hire, .missions, .agency, .release]
        }
        let next = s.securityRaw + 1
        let feasible = order.filter { k in
            switch k {
            case .release: t >= 2
            case .agency: t >= 3
            case .security: t >= 3 && next <= 5 && (next < 5 || s.year >= 2026)
            default: true
            }
        }
        var out: [GrantTask] = []
        let seq = p.grantSequence + 1
        for k in feasible.prefix(1 + t) {
            let id = "grant-\(seq)-\(k.rawValue)"
            switch k {
            case .research:
                let n = 1 + 2 * t
                out.append(GrantTask(id: id, kind: k, title: "Finish \(n) research projects", target: Double(n), baseline: Double(s.researched.count)))
            case .train:
                out.append(GrantTask(id: id, kind: k, title: "Train a model at capability \(Fmt.trim(cap, 2))+", target: 1, capabilityMin: cap))
            case .hire:
                let n = 2 + 2 * t
                out.append(GrantTask(id: id, kind: k, title: "Grow the team by \(n) people", target: Double(n), baseline: Double(s.employees.count)))
            case .safety:
                let target = min(95, (s.safetyScore + 2 + 2 * Double(t)).rounded())
                out.append(GrantTask(id: id, kind: k, title: "Raise the safety score to \(Int(target))", target: target))
            case .release:
                out.append(GrantTask(id: id, kind: k, title: "Put a model at capability \(Fmt.trim(cap - 0.1, 2))+ into public service", target: 1, capabilityMin: cap - 0.1))
            case .missions:
                let n = max(1, t - 1)
                out.append(GrantTask(id: id, kind: k, title: n == 1 ? "Deliver a public mission" : "Deliver \(n) public missions", target: Double(n), baseline: Double(p.completedMissions)))
            case .agency:
                out.append(GrantTask(id: id, kind: k, title: "Deliver a model to an agency", target: 1, baseline: Double(p.commissionsDelivered)))
            case .security:
                out.append(GrantTask(id: id, kind: k, title: "Raise security to SL\(next)", target: Double(next)))
            }
        }
        return out
    }

    /// How far a task has come (value against its target).
    static func measure(_ task: GrantTask, _ r: GovRequest, _ s: GameState) -> Double {
        switch task.kind {
        case .research: Double(s.researched.count) - task.baseline
        case .train: Double(s.models.filter { !$0.preview && $0.created >= r.issued && $0.c >= task.capabilityMin }.count)
        case .hire: Double(s.employees.count) - task.baseline
        case .safety: s.safetyScore
        case .release: Double(s.releasedModels.filter { ($0.releaseDate ?? $0.created) >= r.issued && $0.c >= task.capabilityMin }.count)
        case .missions: Double(s.publicProgram.completedMissions) - task.baseline
        case .agency: Double(s.publicProgram.commissionsDelivered) - task.baseline
        case .security: Double(s.securityRaw)
        }
    }

    static func progress(_ task: GrantTask, _ r: GovRequest, _ s: GameState) -> Double {
        task.done ? 1 : clamp(measure(task, r, s) / max(0.0001, task.target), 0, 1)
    }

    // MARK: Granting

    @discardableResult
    static func grant(_ s: inout GameState, kind: GovRequestKind, title: String, tier: Int, amount: Double = 0, chips: Int = 0,
                      accelID: String = "", powerKW: Double = 0, arrivesIn: Int? = nil) -> GovRequest {
        let tasks = tasks(s, tier: tier)
        s.publicProgram.grantSequence += 1
        let r = GovRequest(id: "grant-\(s.publicProgram.grantSequence)", kind: kind, title: title, issued: s.date,
                           due: GameCalendar.addDays(s.date, days(tier)), amount: amount, chips: chips, accelID: accelID, powerKW: powerKW,
                           arrives: arrivesIn.map { GameCalendar.addDays(s.date, $0) }, tasks: tasks)
        s.publicProgram.grants.insert(r, at: 0)
        let done = s.publicProgram.grants.filter { $0.status != .active }
        if done.count > 12, let last = done.last { s.publicProgram.grants.removeAll { $0.id == last.id } }
        return r
    }

    /// The opening fleet: the newest datacenter GPU, a few thousand of them (more in later eras).
    static func starterFleet(_ s: GameState) -> (Accelerator, Int)? {
        guard let a = chipChoice(s) else { return nil }
        let y = s.year
        let step = max(1, a.minOrder)
        return (a, (y < 2019 ? 2_048 : y < 2021.5 ? 4_096 : y < 2024 ? 8_192 : 16_384) / step * step)
    }

    static func facilitySite(_ name: String, location: String, date: Date) -> Site {
        var site = Site(name: "\(name) National Compute Facility", kind: .datacenter, locationID: location, capacityKW: facilityKW,
                        cooling: .liquid, powerDeal: .grid, opened: date, ready: date, capex: 0, monthlyFee: 0)
        site.stateFunded = true
        return site
    }

    /// The state's national compute facility: 100 MW with the newest GPUs it can buy. Government games start with it;
    /// older public saves get it the first day they run.
    static func buildFacility(_ s: inout GameState) {
        guard s.isPublicProgram, s.publicProgram.facilityID == nil || facility(s) == nil else { return }
        if let existing = s.sites.first(where: \.stateFunded) {
            s.publicProgram.facilityID = existing.id
            return
        }
        let site = facilitySite(s.companyName, location: s.sites.first?.locationID ?? LocationCatalog.all[0].id, date: s.date)
        s.sites.append(site)
        s.publicProgram.facilityID = site.id
        guard let (a, count) = starterFleet(s) else { return }
        s.owned.append(OwnedBatch(accelID: a.id, count: count, siteID: site.id, purchased: s.date, unitCost: 0))
        Sim.mergeOwned(&s)
    }

    static func deliver(_ s: inout GameState, _ i: Int) {
        let r = s.publicProgram.grants[i]
        s.publicProgram.grants[i].arrived = true
        guard let f = facility(s), let fi = s.sites.firstIndex(where: { $0.id == f.id }) else { return }
        switch r.kind {
        case .chips:
            s.owned.append(OwnedBatch(accelID: r.accelID, count: r.chips, siteID: f.id, purchased: s.date, unitCost: 0))
            Sim.mergeOwned(&s)
            let name = HardwareCatalog.get(r.accelID)?.name ?? r.accelID
            PublicProgram.note(&s, "\(Fmt.int(r.chips)) \(name) delivered to the national facility.", good: true)
            Sim.news(&s, "\(Fmt.int(r.chips)) \(name) arrive", "The state's GPUs are racked and running at \(f.name).", .hardware, image: "dc_corridor", good: true)
        case .power:
            s.sites[fi].capacityKW += r.powerKW
            PublicProgram.note(&s, "The national facility grows by \(Fmt.watts(r.powerKW * 1000)).", good: true)
            Sim.news(&s, "\(f.name) grows to \(Fmt.watts(s.sites[fi].capacityKW * 1000))", "New halls and grid capacity are commissioned; the ministry pays the power.", .hardware, image: "hyperscale_campus", good: true)
        case .funding:
            break
        }
    }

    /// Half of a missed GPU request goes to other agencies: only chips nothing is using, written off at book value.
    static func reclaim(_ s: inout GameState, _ r: GovRequest) -> Int {
        guard let f = facility(s), let i = s.owned.firstIndex(where: { $0.siteID == f.id && $0.accelID == r.accelID }) else { return 0 }
        let n = min(r.chips / 2, Economy.pool(s, r.accelID)?.free ?? 0, s.owned[i].count)
        guard n > 0 else { return 0 }
        Books.disposed(&s, proceeds: 0, book: Books.book(s.owned[i], chips: n, at: s.date))
        s.owned[i].count -= n
        s.owned.removeAll { $0.count <= 0 }
        return n
    }

    static func daily(_ s: inout GameState) {
        if s.publicProgram.facilityID == nil { buildFacility(&s) }
        for i in s.publicProgram.grants.indices where s.publicProgram.grants[i].status == .active {
            let r = s.publicProgram.grants[i]
            if !r.arrived, let at = r.arrives, s.date >= at { deliver(&s, i) }
            for j in r.tasks.indices where !r.tasks[j].done && measure(r.tasks[j], r, s) >= r.tasks[j].target {
                s.publicProgram.grants[i].tasks[j].done = true
            }
            let all = s.publicProgram.grants[i].tasks.allSatisfy(\.done)
            if all && (r.arrived || r.arrives == nil) {
                s.publicProgram.grants[i].status = .completed
                s.publicProgram.grants[i].closed = s.date
                s.publicProgram.grantsCompleted += 1
                s.publicProgram.oversight = clamp(s.publicProgram.oversight + 5, 0, 100)
                s.culturePoints += 1
                PublicProgram.note(&s, "Every task for “\(r.title)” delivered: oversight +5, +1 culture point.", good: true)
                Sim.news(&s, "Commitments met: \(r.title)", "The committee signs off every task attached to it. Oversight confidence rises and the programme earns a culture point.",
                         .policy, image: "gov_capitol", important: true, good: true)
            } else if s.date > r.due {
                s.publicProgram.grants[i].status = .failed
                s.publicProgram.grants[i].closed = s.date
                s.publicProgram.grantsFailed += 1
                let withheld = r.kind == .funding ? r.amount * clawbackShare : 0
                s.publicProgram.clawback += withheld
                let taken = r.kind == .chips ? reclaim(&s, r) : 0
                s.publicProgram.oversight = clamp(s.publicProgram.oversight - 8, 0, 100)
                let left = r.tasks.filter { !$0.done }.count
                let cost = withheld > 0 ? ", \(Fmt.money(withheld)) withheld from coming budgets" : taken > 0 ? ", \(Fmt.int(taken)) GPUs reassigned to other agencies" : ""
                PublicProgram.note(&s, "Missed \(left) task\(left == 1 ? "" : "s") for “\(r.title)”: oversight −8\(cost).", good: false)
                Sim.news(&s, "Commitments missed: \(r.title)", "\(left) task\(left == 1 ? " was" : "s were") not delivered by \(r.due.gameShort). Oversight confidence falls\(cost).",
                         .policy, important: true, good: false)
            }
        }
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
    /// Ask for money: paid today, with tasks attached.
    mutating func requestGovernmentFunding(_ amount: Double) -> String? {
        if let why = GovRequests.blocker(self) { return why }
        let range = GovRequests.fundingRange(self)
        let a = (clamp(amount, range.lowerBound, range.upperBound) / 100_000).rounded() * 100_000
        guard a > 0 else { return "Pick an amount." }
        let tier = GovRequests.fundingTier(a, self)
        cash += a
        month.revContracts += a
        publicProgram.totalReceived += a
        let r = GovRequests.grant(&self, kind: .funding, title: "\(Fmt.money(a)) in funding", tier: tier, amount: a)
        PublicProgram.note(&self, "\(Fmt.money(a)) granted, with \(r.tasks.count) tasks due \(r.due.gameShort).", good: true)
        Sim.news(&self, "Funding granted: \(Fmt.money(a))", "The money is in the programme's account today. In return the committee wants \(r.tasks.count) things delivered by \(r.due.gameShort): " + r.tasks.map(\.title).joined(separator: "; ") + ".",
                 .policy, image: "gov_capitol", important: true, good: true)
        return nil
    }

    /// Ask for GPUs: the newest the state can procure, racked at the national facility in 60 days.
    mutating func requestGovernmentChips(_ count: Int) -> String? {
        if let why = GovRequests.blocker(self) { return why }
        guard GovRequests.facility(self) != nil, let a = GovRequests.chipChoice(self) else { return "No GPUs can be procured right now." }
        let range = GovRequests.chipRange(self)
        guard range.upperBound > 0 else { return "The facility has no power left for more GPUs. Ask for more power first." }
        let step = max(1, a.minOrder)
        let n = clamp(count, range.lowerBound, range.upperBound) / step * step
        guard n > 0 else { return "Pick how many GPUs." }
        let r = GovRequests.grant(&self, kind: .chips, title: "\(Fmt.int(n)) \(a.name)", tier: GovRequests.chipTier(n, self), chips: n, accelID: a.id, arrivesIn: GovRequests.chipDays)
        PublicProgram.note(&self, "\(Fmt.int(n)) \(a.name) granted, arriving \(r.arrives?.gameShort ?? "soon"), with \(r.tasks.count) tasks due \(r.due.gameShort).", good: true)
        Sim.news(&self, "GPUs granted: \(Fmt.int(n)) \(a.name)", "They arrive at the national facility on \(r.arrives?.gameShort ?? "soon"). The committee wants \(r.tasks.count) things delivered by \(r.due.gameShort): " + r.tasks.map(\.title).joined(separator: "; ") + ".",
                 .policy, image: "dc_corridor", important: true, good: true)
        return nil
    }

    /// Ask for a bigger facility: new halls and grid capacity, commissioned in 150 days.
    mutating func requestGovernmentPower(_ kw: Double) -> String? {
        if let why = GovRequests.blocker(self) { return why }
        if let why = GovRequests.powerBlocker(self) { return why }
        let r = GovRequests.grant(&self, kind: .power, title: "+\(Fmt.watts(kw * 1000)) of facility power", tier: GovRequests.powerTier(kw), powerKW: kw, arrivesIn: GovRequests.powerDays)
        PublicProgram.note(&self, "+\(Fmt.watts(kw * 1000)) granted, commissioned \(r.arrives?.gameShort ?? "soon"), with \(r.tasks.count) tasks due \(r.due.gameShort).", good: true)
        Sim.news(&self, "Facility expansion granted: +\(Fmt.watts(kw * 1000))", "Commissioned by \(r.arrives?.gameShort ?? "soon"). The committee wants \(r.tasks.count) things delivered by \(r.due.gameShort): " + r.tasks.map(\.title).joined(separator: "; ") + ".",
                 .policy, image: "hyperscale_campus", important: true, good: true)
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
