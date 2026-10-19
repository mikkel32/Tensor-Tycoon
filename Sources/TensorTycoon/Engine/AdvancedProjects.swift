import Foundation

/// 3.5: the Advanced Projects division. Government agencies post AI contracts on a marketplace; you bid against rival
/// labs, win, staff the programme with cleared people, give it cleared compute in accredited facilities and take it
/// through feasibility, research, experiments, a prototype, independent testing and validation. Payment depends on the
/// contract type (fixed-price, cost-plus, milestone grant, prize). Finished programmes leave standing, a track record
/// with the agency, follow-on work, research items and permanent research effects — when secrecy allows you to use them.
///
/// Every roll is hashed (`roll`), never drawn from the game's RNG, and the division never sends news, alerts or decisions
/// until you engage with it: a lab that ignores it plays exactly as before.
enum AdvancedProjects {
    static let secrecyKind = "adv_secrecy"
    static let bonusPrefix = "adv:"
    static let maxOpen = 9

    // MARK: Basics

    /// A hashed roll in 0..<1 for this game (no RNG draw).
    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("adv|\(s.advanced.salt)|\(key)") }

    /// Your headquarters' region. Until labs can choose their home country, every lab is American.
    static func homeRegion(_ s: GameState) -> Region { HQ.region(s) }

    /// The region a rival lab is based in, from its headquarters.
    static func labRegion(_ id: String) -> Region {
        let hq = CompetitorCatalog.def(id).hq.lowercased()
        let table: [(String, Region)] = [
            ("hangzhou", .china), ("beijing", .china), ("shanghai", .china), ("shenzhen", .china),
            ("paris", .eu), ("berlin", .eu), ("munich", .eu), ("amsterdam", .eu), ("stockholm", .eu), ("zurich", .eu),
            ("abu dhabi", .gulf), ("riyadh", .gulf), ("dubai", .gulf), ("doha", .gulf),
            ("tokyo", .japanKorea), ("seoul", .japanKorea), ("bangalore", .india), ("bengaluru", .india), ("mumbai", .india),
        ]
        if let hit = table.first(where: { hq.contains($0.0) }) { return hit.1 }
        if hq.hasPrefix("london") || hq.hasPrefix("cambridge, uk") { return .uk }
        return .us
    }

    /// Whether a lab based in `home` may perform work at this classification for an agency in `agency`.
    static func eligible(home: Region, agency: Region, level: Classification) -> Bool {
        if home == agency { return true }
        switch level {
        case .unclassified: return true
        case .controlled: return [Region.us, .uk, .eu, .japanKorea].contains(home) && [Region.us, .uk, .eu, .japanKorea].contains(agency)
        case .secret: return Set([home, agency]) == Set([Region.us, .uk])
        case .topSecret: return false
        }
    }

    static func standing(_ s: GameState, _ r: Region) -> Double {
        s.world.governments.indices.contains(r.index) ? s.world.governments[r.index] : 50
    }

    static func rating(_ s: GameState, _ agency: String) -> Double { s.advanced.ratings[agency] ?? 0 }

    // MARK: Money scales

    /// Dollars a year behind one unit of agency budget (≈ a large research agency's AI spending).
    static func budgetScale(_ y: Double) -> Double {
        interpolateLog([(2016, 2.5e8), (2020, 5e8), (2023, 1.2e9), (2026, 4e9), (2030, 2e10), (2036, 8e10)], at: y)
    }

    /// An agency's annual AI-programme budget: its size, the year, public concern (defence, cyber, safety) and how strict
    /// its region's rules are (safety institutes and research councils).
    static func agencyBudget(_ a: AgencyDef, _ s: GameState) -> Double {
        let w = s.world
        let strict = w.strictness.indices.contains(a.region.index) ? w.strictness[a.region.index] : 30
        let concernMult = 1 + a.kind.concernSensitivity * (w.concern - 25) / 50
        let rulesMult = 1 + a.kind.rulesSensitivity * (strict - 40) / 60
        return budgetScale(s.year) * a.budget * clamp(concernMult * rulesMult, 0.5, 2.2)
    }

    /// Cloud price of one H100-equivalent for a month.
    static func h100eMonthly(_ y: Double) -> Double {
        interpolate([(2016, 900), (2020, 1_400), (2023, 2_900), (2025, 1_700), (2028, 1_100), (2032, 600), (2040, 300)], at: y)
    }

    /// Building cost per H100-equivalent of accelerators with servers, network and cooling (before accreditation).
    static func capexPerH100e(_ y: Double) -> Double {
        interpolate([(2016, 12_000), (2020, 20_000), (2023, 42_000), (2026, 36_000), (2030, 22_000), (2035, 12_000), (2040, 8_000)], at: y)
    }

    /// The size of a typical programme's compute need, for facility sizing.
    static func typicalCompute(_ y: Double) -> Double {
        interpolateLog([(2016, 48), (2020, 96), (2023, 256), (2026, 1_024), (2030, 6_144), (2036, 32_768)], at: y)
    }

    // MARK: Capability

    /// The best score any lab (you included) has released in a domain.
    static func stateOfArt(_ s: GameState, _ d: CapDomain) -> Double {
        var best = 0.0
        for v in s.labDomains.values { best = max(best, v[d]) }
        return best > 0 ? best : 100
    }

    /// Your best model (released or not: agencies test internal models under NDA).
    static func playerScores(_ s: GameState) -> DomainScores? { Capabilities.playerBest(s, releasedOnly: false) }

    /// Margin over the bar in each required domain, clipped to −15…+20 and averaged (domain points).
    static func margin(_ sol: Solicitation, _ v: DomainScores?) -> Double {
        guard !sol.domains.isEmpty else { return 10 }
        guard let v else { return -15 }
        var sum = 0.0
        for (k, bar) in sol.domains.sorted(by: { $0.key < $1.key }) {   // 3.7: fixed order (float sums)
            guard let d = CapDomain(rawValue: k) else { continue }
            sum += clamp(v[d] - bar, -15, 20)
        }
        return sum / Double(sol.domains.count)
    }

    static func missingResearch(_ sol: Solicitation, _ s: GameState) -> [String] {
        sol.research.filter { !s.researched.contains($0) }
    }

    // MARK: Cost estimate

    struct Estimate {
        var labour = 0.0
        var compute = 0.0
        var materials = 0.0
        var compliance = 0.0
        var proposal = 0.0
        var total: Double { labour + compute + materials + compliance }
        /// What you pay in cash beyond your existing payroll (classified compute runs in your own facility).
        var cash: Double { (classified ? 0 : compute) + materials + compliance }
        var classified = false
    }

    /// The cost structure behind a solicitation: people (already on your payroll), compute (cloud if unclassified, your
    /// facility if not), materials and test campaigns, compliance and security overhead.
    static func estimate(_ sol: Solicitation) -> Estimate {
        var e = Estimate()
        e.classified = sol.level > .unclassified
        let total = sol.estCost
        e.labour = total * 0.25
        e.compute = total * (sol.templateDef?.computeShare ?? 0.3)
        e.compliance = total * ((sol.type == .costPlus ? 0.06 : 0.03) + 0.025 * Double(sol.classification))
        e.materials = max(0, total - e.labour - e.compute - e.compliance)
        e.proposal = proposalCost(sol)
        return e
    }

    static func proposalCost(_ sol: Solicitation) -> Double {
        let share = sol.type == .prize ? 0.005 : (sol.followOn ? 0.006 : 0.012)
        return max(20_000, (sol.ceiling * share / 1000).rounded() * 1000)
    }

    // MARK: Marketplace

    /// First of the month: decide bids that closed, then agencies post new solicitations.
    static func monthly(_ s: inout GameState) {
        if s.advanced.salt.isEmpty { s.advanced.salt = String(s.rng.state ^ 0xAD5A_17, radix: 36) }
        closeBids(&s)
        post(&s)
        for i in s.advanced.programmes.indices where s.advanced.programmes[i].status == .active { step(&s, i) }
        afterProgrammes(&s)
        payFacilities(&s)
        payRoyalties(&s)
        publicationRisk(&s)
        syncSeconded(&s)
    }

    static func post(_ s: inout GameState) {
        let today = s.date
        s.advanced.solicitations.removeAll { $0.closes <= today && $0.bid == nil }
        let ym = s.date.ym
        let y = s.year
        for a in AgencyCatalog.all {
            guard s.advanced.solicitations.filter({ $0.bid == nil }).count < maxOpen else { break }
            let rel = agencyBudget(a, s) / budgetScale(y)
            let p = clamp(0.05 + 0.13 * rel, 0.04, 0.32)
            guard roll(s, "post|\(a.id)|\(ym.year)-\(ym.month)") < p else { continue }
            let options = AgencyCatalog.templates.filter { $0.agencies.contains(a.id) && $0.year <= y }
            guard !options.isEmpty else { continue }
            // Seedlings are most of what's posted before the AI boom, and a steady trickle after.
            let seedWeight = y < 2021 ? 3.0 : (y < 2024 ? 1.2 : 0.6)
            let weights = options.map { $0.id == "seedling" ? seedWeight : 1.0 }
            let u = roll(s, "tmpl|\(a.id)|\(ym.year)-\(ym.month)") * weights.reduce(0, +)
            var acc = 0.0, pick = options[0]
            for (t, w) in zip(options, weights) {
                acc += w
                if u < acc { pick = t; break }
            }
            // An agency doesn't post the same programme twice at once.
            guard !s.advanced.solicitations.contains(where: { $0.agency == a.id && $0.template == pick.id }) else { continue }
            s.advanced.solicitations.append(make(pick, a, s, key: "\(a.id)|\(ym.year)-\(ym.month)", followOn: false))
            s.advanced.counter += 1
        }
    }

    /// Size a solicitation to the agency's budget and the year; set the bars a little below the state of the art.
    static func make(_ t: ProgrammeTemplate, _ a: AgencyDef, _ s: GameState, key: String, followOn: Bool, scale: Double = 1) -> Solicitation {
        let y = s.year
        let k = "sol|\(key)|\(t.id)"
        func r(_ tag: String) -> Double { roll(s, "\(k)|\(tag)") }
        let type = t.types[min(t.types.count - 1, Int(r("type") * Double(t.types.count)))]
        let ip = t.ip[min(t.ip.count - 1, Int(r("ip") * Double(t.ip.count)))]
        let months = max(4, Int((Double(t.months) * (0.85 + 0.3 * r("months"))).rounded()))
        var value = agencyBudget(a, s) * t.size * (0.7 + 0.6 * r("value")) * scale
        // Seedlings stay small whatever the agency's budget.
        if t.id == "seedling" { value = min(value, 2.5e7 * (0.6 + 0.4 * r("seedcap"))) }
        let markup: Double
        switch type {
        case .fixedPrice: markup = 1.14 + 0.12 * r("markup")
        case .costPlus: markup = 1.0
        case .grant: markup = 0.85   // you co-fund: the grant covers most of the cost, and you keep more of the IP
        case .prize: markup = 1.5
        }
        let estCost = value / markup
        // People: a quarter of the cost, at today's salaries, split by the template's mix.
        let totalW = t.staff.reduce(0) { $0 + $1.1 }
        let avgSalary = t.staff.reduce(0) { $0 + Macro.salary($1.0, y) * $1.1 } / max(0.01, totalW)
        let seed = t.id == "seedling"
        var n = Int((estCost * 0.25 / (avgSalary / 12 * Double(months))).rounded())
        n = seed ? clamp(n, 1, 3) : clamp(n, 2, 10)
        var staff: [String: Int] = [:]
        var left = n
        for (i, (role, w)) in t.staff.enumerated() {
            let c = i == t.staff.count - 1 ? left : max(w >= 0.2 ? 1 : 0, Int((Double(n) * w / totalW).rounded()))
            let take = min(left, c)
            if take > 0 { staff[role.rawValue] = take }
            left -= take
            if left <= 0 { break }
        }
        let compute = max(8, (estCost * t.computeShare / (h100eMonthly(y) * Double(months)) / 8).rounded() * 8)
        var domains: [String: Double] = [:]
        let followGap = followOn ? 3.0 : 0
        for d in t.domains {
            let bar = stateOfArt(s, d) - t.gap + followGap - 3 + 6 * r("bar|\(d.rawValue)")
            domains[d.rawValue] = (bar * 2).rounded() / 2
        }
        let title = followOn ? (seed ? t.title : "\(t.title) — Phase II") : t.title
        var sol = Solicitation(id: "ap\(s.advanced.counter)-\(a.id)-\(t.id)", agency: a.id, template: t.id, title: title, type: type, ip: ip,
                               classification: t.classification, ceiling: (value / 1e4).rounded() * 1e4, estCost: (estCost / 1e4).rounded() * 1e4,
                               months: months, domains: domains, research: t.research, computeH100e: compute, staff: staff,
                               risk: t.risk * (0.8 + 0.4 * r("risk")), basis: t.basis, posted: s.date,
                               closes: GameCalendar.addMonths(s.date, followOn ? 2 : 2 + (r("close") < 0.4 ? 1 : 0)))
        sol.followOn = followOn
        sol.bidders = rivalBids(sol, s, limit: followOn ? 1 : 3)
        return sol
    }

    /// Rival labs that bid: those whose models come near the bars, who may do work of this classification for this
    /// agency, and whose strategy fits the work.
    static func rivalBids(_ sol: Solicitation, _ s: GameState, limit: Int) -> [RivalBid] {
        guard let a = sol.agencyDef else { return [] }
        var bids: [RivalBid] = []
        for c in s.competitors where c.alive {
            guard let v = s.labDomains[c.id], eligible(home: labRegion(c.id), agency: a.region, level: sol.level) else { continue }
            let tech = margin(sol, v)
            guard tech > -6 else { continue }
            var interest = 0.42
            switch c.id {
            case "halcyon": interest += (a.kind == .defence || a.kind == .intelligence) ? -0.45 : (a.kind == .safety || a.kind == .health ? 0.3 : 0)
            case "openweights": interest += sol.level >= .secret ? -0.4 : 0.05
            case "xenon": interest += (a.kind == .defence || a.kind == .intelligence) ? 0.35 : 0
            case "deepgrove": interest += (a.kind == .energy || a.kind == .nationalLab || a.kind == .health || a.kind == .research) ? 0.3 : 0
            case "aletheia": interest -= 0.3
            case "sirocco": interest += a.region == .eu ? 0.4 : -0.1
            default: break
            }
            if sol.template == "seedling" { interest *= 0.35 }   // big labs rarely chase seedlings
            guard roll(s, "rival|\(sol.id)|\(c.id)") < clamp(interest, 0.02, 0.95) else { continue }
            let aggressive = c.def.priceMult < 0.8 ? 0.05 : 0
            let price = 0.84 + 0.14 * roll(s, "rivalprice|\(sol.id)|\(c.id)") - aggressive
            bids.append(RivalBid(lab: c.id, tech: tech + (c.brand - 40) / 15, price: price))
        }
        return Array(bids.sorted { $0.tech > $1.tech }.prefix(limit))
    }

    // MARK: Bidding

    struct Odds {
        var p: Double = 0
        var acceptable = false
        var score = 0.0
        /// Your score's parts.
        var parts: [(String, Double)] = []
        /// Each rival's score.
        var rivals: [(String, Double)] = []
        var blockers: [String] = []
    }

    static func priceScore(_ type: ContractType, _ price: Double) -> Double {
        switch type {
        case .fixedPrice, .grant: (1 - price) * 50
        case .costPlus: (0.09 - price) * 100
        case .prize: 0
        }
    }

    /// Things that stop you bidding at all.
    static func blockers(_ sol: Solicitation, _ s: GameState) -> [String] {
        var out: [String] = []
        if let a = sol.agencyDef, !eligible(home: homeRegion(s), agency: a.region, level: sol.level) {
            out.append(sol.level == .unclassified ? "\(a.short) doesn't contract with labs from your country" : "\(sol.level.title) work for \(a.region.title) is open to its own labs only")
        }
        for id in missingResearch(sol, s) { out.append("Research \(ResearchCatalog.byID[id]?.name ?? id)") }
        if margin(sol, playerScores(s)) < -5 { out.append("Your best model is more than 5 points under the bars on average") }
        return out
    }

    /// Your chance of winning at `price` (share of ceiling, or the fee rate for cost-plus), against the rivals who bid.
    static func odds(_ sol: Solicitation, _ s: GameState, price: Double) -> Odds {
        var o = Odds()
        o.blockers = blockers(sol, s)
        let w = sol.basis.weights
        let tech = margin(sol, playerScores(s))
        var ready = sol.followOn ? 3.0 : 0   // the incumbent knows the work
        if staffReadiness(sol, s) >= 1 { ready += 2 }
        if sol.level > .unclassified {
            if freeCompute(s, sol.level) >= sol.computeH100e { ready += 2 }
            if s.security.rawValue < sol.level.requiredSL { ready -= 3 }
            if sol.level >= .secret && s.publication == .open { ready -= 3 }
        }
        let past = rating(s, sol.agency) + (standing(s, sol.agencyDef?.region ?? .us) - 50) / 5
        let pScore = priceScore(sol.type, price)
        o.parts = [("Technical margin", w.tech * tech), ("Readiness", w.tech * ready), ("Price", w.price * pScore), ("Record & standing", w.past * past)]
        o.score = o.parts.reduce(0) { $0 + $1.1 }
        o.rivals = sol.bidders.map { b in
            let name = CompetitorCatalog.def(b.lab).name
            return (name, w.tech * b.tech + w.price * priceScore(sol.type, sol.type == .costPlus ? 0.06 + 0.06 * (b.price - 0.84) / 0.14 : b.price))
        }
        let t = 5.0
        let mine = exp(o.score / t)
        let total = mine + o.rivals.reduce(0) { $0 + exp($1.1 / t) }
        let accept = sigmoid((tech + 5) / 2.5)
        o.acceptable = o.blockers.isEmpty
        o.p = o.acceptable ? clamp((sol.type == .prize ? 1 : mine / total) * accept * 0.95, 0, 0.95) : 0
        return o
    }

    /// Bids decided on the solicitation's closing date.
    static func closeBids(_ s: inout GameState) {
        let today = s.date
        let due = s.advanced.solicitations.filter { $0.closes <= today && $0.bid != nil }
        s.advanced.solicitations.removeAll { $0.closes <= today && $0.bid != nil }
        for sol in due {
            guard let bid = sol.bid else { continue }
            let o = odds(sol, s, price: bid.price)
            let r = roll(s, "award|\(sol.id)")
            let agency = sol.agencyDef?.short ?? sol.agency
            let won = r < o.p
            let winner = won ? s.companyName : (o.rivals.max { $0.1 < $1.1 }?.0 ?? "No award (the agency cancelled)")
            s.advanced.bids.insert(BidRecord(date: s.date, title: sol.title, agency: sol.agency, winner: winner, odds: o.p, won: won, price: bid.price), at: 0)
            if s.advanced.bids.count > 40 { s.advanced.bids.removeLast(s.advanced.bids.count - 40) }
            if won {
                award(&s, sol, bid: bid, margin: margin(sol, playerScores(s)))
            } else {
                Sim.news(&s, "\(agency) awards \(sol.title) to \(winner)",
                         "Your proposal lost (your odds at the close were \(Fmt.pct(o.p, decimals: 0)); the roll was \(Fmt.trim(r, 2))). The \(Fmt.money(bid.proposalCost)) bid cost is gone, but agencies remember a serious bid.",
                         .company, good: false)
                s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) + 0.25, -10, 10)
            }
        }
    }

    static func award(_ s: inout GameState, _ sol: Solicitation, bid: ProposalBid, margin m: Double) {
        var p = Programme(sol: sol, value: 0, awarded: s.date)
        switch sol.type {
        case .fixedPrice, .grant: p.value = sol.ceiling * bid.price
        case .costPlus:
            p.fee = sol.estCost * bid.price
            p.value = sol.estCost + p.fee
        case .prize: p.value = sol.ceiling
        }
        p.proposalCost = bid.proposalCost
        p.costGrowth = 1 + sol.risk * (0.15 + 0.75 * roll(s, "growth|\(sol.id)")) - 0.008 * clamp(m, 0, 15)
        if sol.type == .prize, let best = sol.bidders.max(by: { $0.tech < $1.tech }) {
            let months = Double(sol.months) * (0.95 + 0.6 * roll(s, "rivalfinish|\(sol.id)")) - 0.03 * best.tech
            p.rivalFinish = GameCalendar.addDays(s.date, Int(max(4, months) * 30.4))
            p.rivalLab = best.lab
        }
        let agency = sol.agencyDef?.short ?? sol.agency
        p.history.append(ProgrammeEvent(date: s.date, text: "Awarded by \(agency): \(sol.type.title), \(Fmt.money(p.value))\(sol.type == .costPlus ? " (fee \(Fmt.money(p.fee)))" : ""), \(sol.months) months.", tone: 1))
        s.advanced.programmes.append(p)
        let i = s.advanced.programmes.count - 1
        if sol.type == .grant { payMilestone(&s, i, .award) }
        Sim.news(&s, "Contract won: \(sol.title)",
                 "\(sol.agencyDef?.name ?? agency) picked your proposal (odds were \(Fmt.pct(bid.odds, decimals: 0)) when you bid). Next: assign \(sol.staffTotal) \(sol.level > .unclassified ? "cleared " : "")staff\(sol.level > .unclassified ? " and \(Fmt.int(Int(sol.computeH100e))) H100e of cleared compute" : "") on the Advanced Projects page so the work can start.",
                 .company, image: sol.templateDef?.image, important: true, good: true)
        Alerts.raise(&s, .advanced, key: "won|\(sol.id)", title: "Contract won: \(sol.title)",
                     body: "Staff it on the Advanced Projects page within \(mobilisationGrace(sol)) months or it is terminated.", screen: .advancedProjects, celebrate: true, cooldown: 0)
    }

    // MARK: Requirements

    /// Employees cleared to at least `level` (everyone counts for unclassified work).
    static func clearanceLevel(_ s: GameState, _ id: UUID) -> Int { s.advanced.clearances.first { $0.employee == id }?.level ?? 0 }

    /// Share (0–1) of the required staff you have available with the right clearance and not on another programme.
    static func staffReadiness(_ sol: Solicitation, _ s: GameState) -> Double {
        var have = 0, need = 0
        for (k, n) in sol.staff {
            guard let role = Role(rawValue: k) else { continue }
            let pool = s.employees.filter { $0.role == role && !s.advanced.seconded.contains($0.id) && clearanceLevel(s, $0.id) >= sol.classification }.count
            have += min(n, pool)
            need += n
        }
        return need > 0 ? Double(have) / Double(need) : 1
    }

    static func computeCapacity(_ s: GameState, atLeast level: Int) -> Double {
        s.advanced.facilities.filter { $0.kind != .secureLab && $0.level >= level && $0.isReady(s.date) }.reduce(0) { $0 + $1.capacity }
    }

    static func seatCapacity(_ s: GameState, atLeast level: Int) -> Double {
        s.advanced.facilities.filter { $0.kind == .secureLab && $0.level >= level && $0.isReady(s.date) }.reduce(0) { $0 + $1.capacity }
    }

    static func computeAssigned(_ s: GameState, atLeast level: Int, excluding: UUID? = nil) -> Double {
        s.advanced.programmes.filter { $0.status == .active && $0.sol.classification >= level && $0.id != excluding }.reduce(0) { $0 + $1.compute }
    }

    static func seatsAssigned(_ s: GameState, atLeast level: Int, excluding: UUID? = nil) -> Double {
        s.advanced.programmes.filter { $0.status == .active && $0.sol.classification >= level && $0.id != excluding }.reduce(0) { $0 + Double($1.staff.count) }
    }

    /// Cleared compute free for a programme at this classification (facilities accredited at or above it).
    static func freeCompute(_ s: GameState, _ level: Classification, excluding: UUID? = nil) -> Double {
        guard level > .unclassified else { return .infinity }
        var free = Double.infinity
        for l in 1...level.rawValue { free = min(free, computeCapacity(s, atLeast: l) - computeAssigned(s, atLeast: l, excluding: excluding)) }
        return max(0, free)
    }

    static func freeSeats(_ s: GameState, _ level: Classification, excluding: UUID? = nil) -> Double {
        guard level > .unclassified else { return .infinity }
        var free = Double.infinity
        for l in 1...level.rawValue { free = min(free, seatCapacity(s, atLeast: l) - seatsAssigned(s, atLeast: l, excluding: excluding)) }
        return max(0, free)
    }

    struct Factors {
        var staffing = 0.0
        var compute = 1.0
        var capability = 1.0
        var agents = 1.0
        var security = true
        var mobilised = false
        var missing: [String] = []
        /// Pace against plan (1 = on schedule). Test campaigns and reviews keep even a great team from finishing much early.
        var total: Double { security ? min(1.15, staffing * compute * capability * agents) : 0 }
    }

    /// What drives a programme's pace this month, and what's missing.
    static func factors(_ p: Programme, _ s: GameState) -> Factors {
        var f = Factors()
        let sol = p.sol
        let team = s.employees.filter { p.staff.contains($0.id) && clearanceLevel(s, $0.id) >= sol.classification }
        var parts: [Double] = []
        var rolesCovered = true
        for (k, n) in sol.staff.sorted(by: { $0.key < $1.key }) {
            guard let role = Role(rawValue: k), n > 0 else { continue }
            let mine = team.filter { $0.role == role }
            let have = mine.reduce(0.0) { $0 + $1.skill / 60 * $1.traitMultiplier * (0.7 + $1.morale / 250) }
            parts.append(min(1.2, have / Double(n)))
            if mine.count < n { f.missing.append("\(n - mine.count) more \(role.title.lowercased())\(n - mine.count > 1 ? "s" : "")\(sol.level > .unclassified ? " (cleared \(sol.level.clearance))" : "")") }
            if mine.isEmpty { rolesCovered = false }
        }
        f.staffing = parts.isEmpty ? 0 : parts.reduce(0, +) / Double(parts.count) * (rolesCovered ? 1 : 0.45)
        if sol.level > .unclassified {
            let ratio = p.compute / max(1, sol.computeH100e)
            f.compute = ratio <= 0 ? 0.15 : sqrt(min(1.5, ratio))
            if ratio < 1 { f.missing.append("\(Fmt.int(Int(sol.computeH100e - p.compute))) H100e more cleared compute") }
            if s.security.rawValue < sol.level.requiredSL {
                f.security = false
                f.missing.append("Weight security SL\(sol.level.requiredSL) (you have SL\(s.security.rawValue)) — stop-work order")
            }
        }
        f.capability = clamp(1 + 0.02 * margin(sol, playerScores(s)), 0.6, 1.25)
        if sol.level.agentsAllowed, let id = p.swarm, let sw = s.swarms.first(where: { $0.id == id }), !sw.paused {
            f.agents = 1 + min(0.3, 0.07 * log10(1 + sw.active))
        }
        let total = sol.staffTotal
        f.mobilised = rolesCovered && Double(team.count) >= 0.6 * Double(total) && f.security && (sol.level == .unclassified || p.compute >= 0.5 * sol.computeH100e)
        return f
    }

    /// Months a programme may spend mobilising before the agency gives up: 4, plus 3 per classification level.
    static func mobilisationGrace(_ sol: Solicitation) -> Int { 4 + 3 * sol.classification }

    /// Odds that a trial (experiment, prototype, test campaign) fails, for the next attempt.
    static func failChance(_ p: Programme, _ s: GameState) -> Double {
        let m = margin(p.sol, playerScores(s))
        let attempts = p.trials[String(p.stage.rawValue)] ?? 0
        return clamp(p.sol.risk * clamp(1.15 - 0.03 * m, 0.5, 1.6) * pow(0.7, Double(attempts)), 0.02, 0.7)
    }

    // MARK: Execution

    static func log(_ p: inout Programme, _ date: Date, _ text: String, _ tone: Int = 0) {
        p.history.append(ProgrammeEvent(date: date, text: text, tone: tone))
        if p.history.count > 80 { p.history.removeFirst(p.history.count - 80) }
    }

    /// Payment schedule: stage → share of the contract value (fixed-price, grant, prize) or of the fee (cost-plus).
    static func milestones(_ type: ContractType) -> [(ProgrammeStage, Double)] {
        switch type {
        case .fixedPrice: [(.feasibility, 0.10), (.research, 0.15), (.prototype, 0.25), (.testing, 0.20), (.completion, 0.30)]
        case .costPlus: [(.research, 0.25), (.prototype, 0.25), (.completion, 0.50)]
        case .grant: [(.award, 0.20), (.research, 0.20), (.prototype, 0.20), (.testing, 0.20), (.completion, 0.20)]
        case .prize: [(.completion, 1.0)]
        }
    }

    static func income(_ s: inout GameState, _ i: Int, _ amount: Double) {
        guard amount > 0 else { return }
        s.cash += amount
        s.month.revOther += amount
        s.lifetimeRevenue += amount
        s.advanced.programmes[i].revenue += amount
    }

    static func payMilestone(_ s: inout GameState, _ i: Int, _ stage: ProgrammeStage) {
        let p = s.advanced.programmes[i]
        guard !p.paid.contains(stage.rawValue), let share = milestones(p.sol.type).first(where: { $0.0 == stage })?.1 else { return }
        if p.sol.type == .prize, let rival = p.rivalFinish, rival <= s.date { return }
        let amount = (p.sol.type == .costPlus ? p.fee : p.value) * share
        s.advanced.programmes[i].paid.insert(stage.rawValue)
        income(&s, i, amount)
        log(&s.advanced.programmes[i], s.date, "Milestone \(stage.title): \(Fmt.money(amount)) paid.", 1)
    }

    /// One month of a programme: mobilise, work, spend, bill, test, pay, and check the schedule.
    static func step(_ s: inout GameState, _ i: Int) {
        var p = s.advanced.programmes[i]
        let sol = p.sol
        let est = estimate(sol)
        let f = factors(p, s)
        let agency = sol.agencyDef?.short ?? sol.agency
        p.months += 1
        var revenueBefore = p.revenue
        let startStage = p.stage
        var workRate = 0.0
        var progressMonth = 0.0

        if p.stage == .award {
            if f.mobilised {
                p.stage = .feasibility
                log(&p, s.date, "Mobilised: team, compute and accreditation in place. Feasibility begins.", 1)
            } else {
                p.mobilisingMonths += 1
                log(&p, s.date, "Still mobilising: missing " + (f.missing.isEmpty ? "a full team" : f.missing.prefix(3).joined(separator: ", ")) + ".", -1)
                if p.mobilisingMonths == 2 {
                    alert(&s, "mobilise|\(p.id)", "\(sol.title) can't start", "\(agency) expects work to begin. Missing: \(f.missing.prefix(3).joined(separator: ", ")).")
                }
            }
        }
        // Work.
        if p.stage >= .feasibility && p.stage <= .completion {
            p.stopWork = !f.security
            let rate = f.total
            workRate = rate
            let before = p.completion
            p.progress += rate / max(0.5, Double(sol.months) * p.stage.workShare)
            while p.progress >= 1 && p.status == .active && p.stage <= .completion {
                s.advanced.programmes[i] = p
                if !finishStage(&s, i) { p = s.advanced.programmes[i]; break }
                p = s.advanced.programmes[i]
            }
            progressMonth = p.completion - before
        }
        revenueBefore = min(revenueBefore, p.revenue)

        // Costs: direct cash (materials, tests, compliance, cloud compute when unclassified) and allocated costs (your
        // staff's salaries and facility running costs, already paid elsewhere but charged to the contract).
        // Direct spending: a quarter is the standing team's overhead (it runs every month, so slips cost money), three
        // quarters follow the work actually done — rework included — at the stage it started in.
        let workDone = startStage >= .feasibility && startStage <= .completion ? workRate * startStage.intensity : 0
        let overhead = startStage == .award ? 0.05 : 0.25
        let direct = est.cash / Double(sol.months) * (overhead + 0.75 * workDone) * p.costGrowth
        let team = s.employees.filter { p.staff.contains($0.id) }
        let salaries = team.reduce(0) { $0 + $1.salary } / 12
        // Contracts reimburse pay only up to the allowable-compensation cap (about 1.5× the going salary for the role).
        let allowable = team.reduce(0) { $0 + min($1.salary, Macro.salary($1.role, s.year) * 1.5) } / 12
        let facility = facilityShare(s, p)
        let allocated = salaries + facility
        s.cash -= direct
        s.month.costOther += direct
        p.direct += direct
        p.allocated += allocated
        s.advanced.programmes[i] = p

        // Cost-plus: the government reimburses costs every month, up to the ceiling (target cost + 25%).
        if sol.type == .costPlus && p.stage >= .award {
            let reimbursable = sol.estCost * 1.25
            let already = p.revenue - p.paid.reduce(0.0) { acc, st in
                acc + p.fee * (milestones(.costPlus).first { $0.0.rawValue == st }?.1 ?? 0)
            }
            let billable = direct + allowable + facility
            let claim = max(0, min(billable, reimbursable - already))
            income(&s, i, claim)
            if claim < billable - 1, !p.history.contains(where: { $0.text.hasPrefix("Over the cost ceiling") }) {
                log(&s.advanced.programmes[i], s.date, "Over the cost ceiling: further costs are yours.", -1)
            }
            p = s.advanced.programmes[i]
            // Audits twice a year: findings disallow part of what was billed since the last one.
            if p.status == .active && p.months % 6 == 0 {
                p.audits += 1
                let chance = 0.22 + 0.04 * Double(p.reworks) - (s.safetyScore > 70 ? 0.05 : 0)
                let r = roll(s, "audit|\(p.sol.id)|\(p.months)")
                if r < chance {
                    let billed = p.books.suffix(5).reduce(0) { $0 + $1.revenue } + claim
                    let claw = (billed * (0.03 + 0.04 * roll(s, "auditsize|\(p.sol.id)|\(p.months)")) / 1000).rounded() * 1000
                    p.findings += 1
                    p.disallowed += claw
                    s.cash -= claw
                    s.month.costOther += claw
                    s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) - 0.5, -10, 10)
                    log(&p, s.date, "Audit finding: \(Fmt.money(claw)) of billed costs disallowed (roll \(Fmt.trim(r, 2)) under \(Fmt.pct(chance, decimals: 0)) finding odds).", -1)
                } else {
                    log(&p, s.date, "Audit clean (roll \(Fmt.trim(r, 2)) over \(Fmt.pct(chance, decimals: 0)) finding odds).", 1)
                    s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) + 0.2, -10, 10)
                }
            }
            s.advanced.programmes[i] = p
        }

        // Schedule.
        p = s.advanced.programmes[i]
        if p.status == .active {
            // The schedule runs from mobilisation; classified work gets longer to mobilise (clearances, accreditation).
            let ratio = Double(p.months - p.mobilisingMonths) / Double(max(1, sol.months))
            let grace = mobilisationGrace(sol)
            switch sol.type {
            case .fixedPrice, .costPlus:
                let cure = 1.25, kill = sol.type == .costPlus ? 1.9 : 1.6
                if p.stage == .award && p.mobilisingMonths >= grace {
                    terminate(&s, i, .terminated, "never mobilised: \(grace) months without a team in place")
                } else if ratio > kill {
                    terminate(&s, i, .terminated, "\(Int(((ratio - 1) * 100).rounded()))% over schedule")
                } else if ratio > cure && !p.cureNotice {
                    s.advanced.programmes[i].cureNotice = true
                    log(&s.advanced.programmes[i], s.date, "Cure notice: \(agency) says the programme is badly behind and will be terminated for default past \(Int(kill * Double(sol.months))) months.", -1)
                    s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) - 1, -10, 10)
                    alert(&s, "cure|\(p.id)", "Cure notice on \(sol.title)", "\(agency) threatens termination for default. Add staff or compute, or accept the loss.", critical: true)
                }
            case .grant:
                if p.stage == .award && p.mobilisingMonths >= grace { terminate(&s, i, .lapsed, "never started") }
                else if ratio > 2 { terminate(&s, i, .lapsed, "twice its planned length") }
            case .prize:
                if p.stage == .award && p.mobilisingMonths >= grace + 2 { terminate(&s, i, .lapsed, "never started") }
                else if let r = p.rivalFinish, r <= s.date { terminate(&s, i, .lost, "\(CompetitorCatalog.def(p.rivalLab).name) delivered first") }
            }
        }
        // Budget cuts: an agency may end a programme for its own convenience (likelier when its government cools on you).
        p = s.advanced.programmes[i]
        if p.status == .active && p.stage >= .feasibility && p.stage <= .testing, let a = sol.agencyDef {
            let chance = 0.002 * (1 + max(0, 45 - standing(s, a.region)) / 8)
            if roll(s, "convenience|\(p.sol.id)|\(p.months)") < chance { terminate(&s, i, .cancelled, "budget cuts at \(a.short)") }
        }
        p = s.advanced.programmes[i]
        p.books.append(ProgrammeMonth(date: s.date, revenue: p.revenue - revenueBefore, direct: direct, allocated: allocated, progress: progressMonth))
        if p.books.count > 60 { p.books.removeFirst(p.books.count - 60) }
        s.advanced.programmes[i] = p
    }

    /// Finishing the current stage: run its trial (if it has one), pay its milestone and move on. False if a trial failed.
    @discardableResult
    static func finishStage(_ s: inout GameState, _ i: Int) -> Bool {
        var p = s.advanced.programmes[i]
        let stage = p.stage
        if stage.hasTrial {
            let attempt = p.trials[String(stage.rawValue)] ?? 0
            let odds = failChance(p, s)
            let r = roll(s, "trial|\(p.sol.id)|\(stage.rawValue)|\(attempt)")
            if r < odds {
                p.trials[String(stage.rawValue)] = attempt + 1
                p.reworks += 1
                p.progress = 0.4
                log(&p, s.date, "\(stage.title) failed (roll \(Fmt.trim(r, 2)) under \(Fmt.pct(odds, decimals: 0)) failure odds): back to rework.", -1)
                s.advanced.programmes[i] = p
                return false
            }
            log(&p, s.date, "\(stage.title) passed (roll \(Fmt.trim(r, 2)) over \(Fmt.pct(odds, decimals: 0)) failure odds).", 1)
        } else {
            log(&p, s.date, "\(stage.title) complete.", 1)
        }
        p.progress -= 1
        s.advanced.programmes[i] = p
        payMilestone(&s, i, stage)
        if stage == .completion {
            complete(&s, i)
            return false
        }
        s.advanced.programmes[i].stage = ProgrammeStage(rawValue: stage.rawValue + 1) ?? .completion
        return true
    }

    /// A delivered programme: standing, track record, research, follow-ons, and — for classified discoveries — a choice.
    static func complete(_ s: inout GameState, _ i: Int) {
        var p = s.advanced.programmes[i]
        let sol = p.sol
        let t = sol.templateDef
        let a = sol.agencyDef
        p.status = .completed
        p.ended = s.date
        p.progress = 1
        let onTime = p.months - p.mobilisingMonths <= Int(Double(sol.months) * 1.1)
        s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) + (onTime ? 2.5 : 1.2), -10, 10)
        if let a { Stakeholders.move(&s, [a.region.rawValue: 1.5 + Double(sol.classification)], "Delivered \(sol.title) for \(a.short)") }
        s.politicalCapital = min(100, s.politicalCapital + 1 + Double(sol.classification))
        // How much of the know-how you may use commercially.
        if sol.level >= .secret, t?.discovery != nil {
            p.secrecy = .pending
            p.effectScale = 0
        } else {
            p.effectScale = sol.ip.commercialShare * (sol.level == .controlled ? 0.85 : 1)
            p.stage = .commercialisation
        }
        log(&p, s.date, "Delivered \(onTime ? "on time" : "late") after \(p.months) months. Contract P&L \(signed(p.profit)) (cash \(signed(p.cashProfit))).", 1)
        s.advanced.programmes[i] = p
        // A research item handed over with the deliverables.
        if let u = t?.unlock, !s.researched.contains(u), let item = ResearchCatalog.byID[u] {
            s.researchProgress[u] = max(s.researchProgress[u] ?? 0, Sim.researchCost(item, year: s.year))
            s.researchQueue.removeAll { $0 == u }
            s.researchQueue.insert(u, at: 0)
            log(&s.advanced.programmes[i], s.date, "Hands you \(item.name): fully credited and first in your research queue.", 1)
        }
        // Moonshots in the same field get a push from what the team learned.
        if let field = t?.field {
            for j in s.moonshots.indices where s.moonshots[j].status == .running && s.moonshots[j].def?.field == field {
                s.moonshots[j].rpInvested += 0.12 * s.moonshots[j].rpTarget
                log(&s.advanced.programmes[i], s.date, "Shared results with your \(s.moonshots[j].def?.name ?? "moonshot") team (+12% of its research plan).", 1)
            }
        }
        // Follow-on work for a good performer.
        if let a, let t, rating(s, a.id) >= 1, roll(s, "followon|\(p.sol.id)") < 0.7 {
            let next: ProgrammeTemplate
            if t.id == "seedling" {
                next = AgencyCatalog.templates.filter { $0.agencies.contains(a.id) && $0.id != "seedling" && $0.year <= s.year }.first ?? t
            } else { next = t }
            if next.id != "seedling" || t.id == "seedling" {
                s.advanced.counter += 1
                s.advanced.solicitations.append(make(next, a, s, key: "follow|\(p.id)", followOn: true, scale: t.id == "seedling" ? 1 : 1.2))
                log(&s.advanced.programmes[i], s.date, "\(a.short) invites you to bid on follow-on work (\(next.title)).", 1)
            }
        }
        Sim.news(&s, "Programme delivered: \(sol.title)",
                 "\(a?.name ?? sol.agency) accepts the final deliverables. Contract P&L: \(signed(p.profit)) on \(Fmt.money(p.value))\(p.secrecy == .pending ? ". The work produced a discovery with commercial value — what you may do with it is waiting in your inbox." : ".")",
                 .company, image: t?.image, important: true, good: true)
        alert(&s, "done|\(p.id)", "Delivered: \(sol.title)", "Contract P&L \(signed(p.profit)). Your record with \(a?.short ?? sol.agency) improves.", celebrate: true)
        if p.secrecy == .pending { askSecrecy(&s, i) }
    }

    static func terminate(_ s: inout GameState, _ i: Int, _ status: ProgrammeStatus, _ why: String) {
        var p = s.advanced.programmes[i]
        let sol = p.sol
        let agency = sol.agencyDef?.short ?? sol.agency
        p.status = status
        p.ended = s.date
        switch status {
        case .terminated:
            // Unliquidated progress payments come back; the agency remembers.
            let back = sol.type == .costPlus ? 0 : p.revenue * 0.2
            s.cash -= back
            s.month.costOther += back
            p.disallowed += back
            s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) - 4, -10, 10)
            if let r = sol.agencyDef?.region { Stakeholders.move(&s, [r.rawValue: -3], "\(agency) terminated \(sol.title) for default") }
            log(&p, s.date, "Terminated for default: \(why).\(back > 0 ? " \(Fmt.money(back)) of progress payments repaid." : "")", -1)
            p.effectScale = 0.15 * sol.ip.commercialShare
        case .cancelled:
            // Termination for convenience: costs to date plus a settlement.
            let settle = sol.type == .fixedPrice ? max(0, p.direct * 1.1 - p.revenue) : (sol.type == .costPlus ? p.fee * 0.3 : 0)
            s.advanced.programmes[i] = p
            income(&s, i, settle)
            p = s.advanced.programmes[i]
            log(&p, s.date, "Terminated for convenience: \(why). Settlement \(Fmt.money(settle)).", -1)
            p.effectScale = 0.3 * sol.ip.commercialShare
        case .lapsed:
            // Grant money not yet spent on the work goes back.
            let back = sol.type == .grant ? max(0, min(p.revenue, p.revenue - p.direct - p.allocated)) : 0
            s.cash -= back
            s.month.costOther += back
            p.disallowed += back
            s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) - 1.5, -10, 10)
            log(&p, s.date, "Lapsed: \(why).\(back > 0 ? " \(Fmt.money(back)) of unspent grant money returned." : "")", -1)
        case .lost:
            let consolation = p.value * 0.1 * (p.completion >= 0.6 ? 1 : 0)
            s.advanced.programmes[i] = p
            income(&s, i, consolation)
            p = s.advanced.programmes[i]
            p.effectScale = 0.5 * sol.ip.commercialShare * p.completion
            log(&p, s.date, "\(why).\(consolation > 0 ? " Runner-up award \(Fmt.money(consolation))." : "")", -1)
        default: break
        }
        s.advanced.programmes[i] = p
        Sim.news(&s, "\(sol.title): \(status.title.lowercased())", "\(why.prefix(1).uppercased() + why.dropFirst()). Contract P&L \(signed(p.profit)).",
                 .company, important: status == .terminated, good: false)
        alert(&s, "end|\(p.id)", "\(sol.title): \(status.title.lowercased())", "Contract P&L \(signed(p.profit)).", critical: status == .terminated)
    }

    /// Facility running costs charged to a classified programme (its share of compute and desks in use).
    static func facilityShare(_ s: GameState, _ p: Programme) -> Double {
        guard p.sol.level > .unclassified, p.status == .active else { return 0 }
        var share = 0.0
        let usedCompute = computeAssigned(s, atLeast: 1)
        let usedSeats = seatsAssigned(s, atLeast: 1)
        for f in s.advanced.facilities where f.isReady(s.date) {
            if f.kind == .secureLab {
                if usedSeats > 0 { share += f.opex * Double(p.staff.count) / max(usedSeats, f.capacity) }
            } else if usedCompute > 0 {
                share += f.opex * p.compute / max(usedCompute, computeCapacity(s, atLeast: 1))
            }
        }
        return share
    }

    // MARK: Facilities, royalties, publication

    static func payFacilities(_ s: inout GameState) {
        // A facility goes with its site when the site is sold or closed.
        let siteIDs = Set(s.sites.map(\.id))
        let orphaned = s.advanced.facilities.filter { f in f.siteID.map { !siteIDs.contains($0) } ?? false }
        if !orphaned.isEmpty {
            for f in orphaned { s.closeFacility(f.id) }
            Sim.news(&s, "Classified facilities closed", orphaned.map(\.name).joined(separator: ", ") + " closed with the site they were in.", .company, good: false)
        }
        var total = 0.0
        for f in s.advanced.facilities where f.isReady(s.date) { total += f.opex }
        s.advanced.lastOpex = total
        guard total > 0 else { return }
        s.cash -= total
        s.month.costOther += total
    }

    static func payRoyalties(_ s: inout GameState) {
        for i in s.advanced.programmes.indices where s.advanced.programmes[i].royaltyMonthsLeft > 0 {
            let r = s.advanced.programmes[i].royaltyMonthly
            s.cash += r
            s.month.revLicensing += r
            s.lifetimeRevenue += r
            s.advanced.programmes[i].revenue += r
            s.advanced.programmes[i].royaltyMonthsLeft -= 1
        }
    }

    /// An open-science lab running Secret work risks an inadvertent disclosure in a paper.
    static func publicationRisk(_ s: inout GameState) {
        guard s.publication == .open else { return }
        let ym = s.date.ym
        for i in s.advanced.programmes.indices where s.advanced.programmes[i].status == .active && s.advanced.programmes[i].sol.level >= .secret
            && s.advanced.programmes[i].stage >= .feasibility {
            let p = s.advanced.programmes[i]
            guard roll(s, "leak|\(p.sol.id)|\(ym.year)-\(ym.month)") < 0.04 else { continue }
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) - 2, -10, 10)
            if let r = p.sol.agencyDef?.region { Stakeholders.move(&s, [r.rawValue: -2], "A paper from your lab touched classified work") }
            log(&s.advanced.programmes[i], s.date, "Security review: a paper under your open-science policy came too close to classified results. Rating −2.", -1)
            alert(&s, "leak|\(p.id)", "Disclosure finding on \(p.sol.title)", "Open-science publishing and Secret work don't mix: consider a selective publication policy.")
        }
    }

    /// Keep the set of seconded employees (who don't produce research points) in step with the programmes; drop
    /// people who left the company.
    static func syncSeconded(_ s: inout GameState) {
        let ids = Set(s.employees.map(\.id))
        var on = Set<UUID>()
        for i in s.advanced.programmes.indices {
            if s.advanced.programmes[i].status != .active {
                s.advanced.programmes[i].staff = []
                s.advanced.programmes[i].compute = 0
                s.advanced.programmes[i].swarm = nil
                continue
            }
            s.advanced.programmes[i].staff.removeAll { !ids.contains($0) }
            on.formUnion(s.advanced.programmes[i].staff)
        }
        s.advanced.seconded = on
        s.advanced.clearances.removeAll { !ids.contains($0.employee) }
    }

    /// Old finished programmes drop out of the active list after a while (their effects stay).
    static func afterProgrammes(_ s: inout GameState) {
        let cutoff = GameCalendar.addMonths(s.date, -60)
        let today = s.date
        s.advanced.programmes.removeAll { $0.status != .active && $0.effectScale <= 0 && $0.royaltyMonthsLeft <= 0 && $0.secrecy != .pending && ($0.ended ?? today) < cutoff }
        // Secrecy processes that finish this month.
        for i in s.advanced.programmes.indices {
            guard let until = s.advanced.programmes[i].secrecyUntil, until <= s.date else { continue }
            finishSecrecy(&s, i)
        }
    }

    // MARK: Daily

    /// Facilities finishing construction and clearances finishing investigation (only when there are any).
    static func daily(_ s: inout GameState) {
        guard !s.advanced.facilities.isEmpty || !s.advanced.clearances.isEmpty else { return }
        let today = s.date
        let yesterday = GameCalendar.addDays(today, -1)
        for f in s.advanced.facilities where f.ready > yesterday && f.ready <= today {
            Sim.news(&s, "\(f.name) accredited", "Your \(f.kind.title.lowercased()) (\(facilityLevelName(f.level))) is ready: \(Fmt.int(Int(f.capacity))) \(f.kind.unit).",
                     .company, image: f.kind.image, good: true)
        }
        for i in s.advanced.clearances.indices {
            guard let ready = s.advanced.clearances[i].ready, ready <= today else { continue }
            var c = s.advanced.clearances[i]
            let name = s.employees.first { $0.id == c.employee }?.name ?? "An employee"
            c.ready = nil
            c.started = nil
            if !clearable(s, c.employee, c.target) {
                c.deniedAt = c.target
                c.target = c.level
                Sim.news(&s, "Clearance denied: \(name)", "The background investigation turned up something (foreign ties, finances or past conduct). \(name) can't be cleared to \(Classification(rawValue: c.deniedAt)?.clearance ?? "that level").", .company, good: false)
            } else {
                c.level = c.target
                Sim.news(&s, "Clearance granted: \(name)", "\(name) now holds a \(Classification(rawValue: c.level)?.clearance ?? "") clearance.", .company, good: true)
            }
            s.advanced.clearances[i] = c
        }
    }

    // MARK: Clearances and facilities (rules)

    static func clearanceCost(_ level: Int, _ y: Double) -> Double {
        [0, 6_000, 20_000, 55_000][clamp(level, 0, 3)] * (1 + 0.04 * max(0, y - 2016))
    }

    static func clearanceMonths(_ level: Int) -> Double { [0, 2, 5, 9][clamp(level, 0, 3)] }

    /// Some people can't be cleared: a hashed trait of the person, worse at higher levels.
    static func clearable(_ s: GameState, _ id: UUID, _ level: Int) -> Bool {
        roll(s, "clearable|\(id.uuidString)") >= [0, 0.03, 0.08, 0.15][clamp(level, 0, 3)]
    }

    static func facilityLevelName(_ level: Int) -> String {
        switch level {
        case 1: "CUI enclave"
        case 2: "Secret-accredited"
        default: "TS/SCI (SCIF)"
        }
    }

    /// Sizes on offer for a facility kind this year.
    static func sizes(_ kind: FacilityKind, _ y: Double) -> [Double] {
        if kind == .secureLab { return [12, 40, 120] }
        let base = typicalCompute(y)
        return [0.5, 2, 6].map { max(32, (base * $0 / 32).rounded() * 32) }
    }

    struct Quote {
        var capex = 0.0
        var opex = 0.0
        var months = 0.0
        var kw = 0.0
    }

    static func quote(_ kind: FacilityKind, level: Int, capacity: Double, _ y: Double) -> Quote {
        var q = Quote()
        let l = clamp(level, 1, 3) - 1
        switch kind {
        case .secureLab:
            q.capex = capacity * [90_000, 300_000, 750_000][l] * (1 + 0.03 * max(0, y - 2016))
            q.opex = q.capex * 0.012 + capacity * Double(l + 1) * 2_500
            q.months = [3, 6, 11][l]
        case .restrictedCompute:
            q.capex = capacity * capexPerH100e(y) * [1.45, 1.65, 1.95][l]
            q.opex = q.capex * 0.018
            q.months = [6, 9, 14][l]
            q.kw = capacity * World.kwPerH100e(y)
        case .clearedHall:
            q.capex = capacity * capexPerH100e(y) * [1.2, 1.35, 1.6][l]
            q.opex = q.capex * 0.015
            q.months = [3, 5, 9][l]
            q.kw = capacity * World.kwPerH100e(y)
        }
        q.months /= Campus.speedup(y)
        return q
    }

    /// Sites a facility kind can go on.
    static func sitesFor(_ kind: FacilityKind, _ s: GameState) -> [Site] {
        s.sites.filter { site in
            guard site.isReady(s.date) else { return false }
            switch kind {
            case .secureLab: return site.kind != .garage
            case .restrictedCompute: return site.kind == .colo || site.kind == .datacenter
            case .clearedHall: return site.kind == .datacenter
            }
        }
    }

    /// Small hook for the datacenter screens: power (kW) cleared halls take at a site.
    static func facilityKW(_ s: GameState, site: UUID) -> Double {
        s.advanced.facilities.filter { $0.siteID == site && $0.kind == .clearedHall }.reduce(0) { $0 + $1.capacity * World.kwPerH100e(s.year) }
    }

    // MARK: Secrecy

    static func askSecrecy(_ s: inout GameState, _ i: Int) {
        let p = s.advanced.programmes[i]
        let sol = p.sol
        let what = sol.templateDef?.discovery ?? "a discovery"
        let approval = approvalOdds(s, p)
        let clean = cleanRoomCost(p)
        let royalty = royaltyMonthly(p)
        Events.addDecision(&s, kind: secrecyKind, title: "Classified discovery: \(what)",
                           body: "\(sol.title) for \(sol.agencyDef?.short ?? sol.agency) produced \(what) — valuable to your commercial models, but it's \(sol.level.title) and \(sol.ip.title.lowercased()). What do you do with it?",
                           image: sol.templateDef?.image,
                           options: [DecisionOption(label: "Keep it classified", detail: "No commercial use. \(sol.agencyDef?.short ?? "The agency") trusts you more (record +1.5, standing +2, political capital +2)."),
                                     DecisionOption(label: "Seek civilian-use approval", detail: "4–9 months of review. \(Fmt.pct(approval, decimals: 0)) odds at your standing; if approved you use it in full."),
                                     DecisionOption(label: "Rebuild it clean-room", detail: "\(Fmt.money(clean)) and 6–10 months for an independent team: 70% of the effect, small risk of a taint finding."),
                                     DecisionOption(label: "License the permitted parts", detail: "About \(Fmt.money(royalty * 36)) in royalties over three years; a fifth of the effect."),
                                     DecisionOption(label: "Partner with an authorised organisation", detail: "\(Fmt.money(p.value * 0.08)) now from a cleared partner, 45% of the effect, record +0.5.")],
                           amount: p.value, ref: p.id.uuidString)
    }

    static func approvalOdds(_ s: GameState, _ p: Programme) -> Double {
        let st = standing(s, p.sol.agencyDef?.region ?? .us)
        return clamp(0.3 + (st - 50) / 100 + 0.02 * rating(s, p.sol.agency) - 0.12 * Double(p.sol.classification - 2) + (p.sol.ip == .government ? -0.08 : 0), 0.08, 0.8)
    }

    static func cleanRoomCost(_ p: Programme) -> Double { max(2e5, (p.value * 0.18 / 1e4).rounded() * 1e4) }

    static func royaltyMonthly(_ p: Programme) -> Double { p.value * 0.006 * (p.sol.ip == .government ? 0.5 : 1) }

    static func resolveSecrecy(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let id = UUID(uuidString: d.ref), let i = s.advanced.programmes.firstIndex(where: { $0.id == id }),
              s.advanced.programmes[i].secrecy == .pending else { return }
        var p = s.advanced.programmes[i]
        let agency = p.sol.agencyDef
        let today = s.date
        let u = roll(s, "secrecytime|\(p.sol.id)")
        let months = { (lo: Int, hi: Int) -> Date in GameCalendar.addMonths(today, lo + Int(u * Double(hi - lo + 1))) }
        switch option {
        case 1:
            p.secrecy = .review
            p.secrecyUntil = months(4, 9)
            log(&p, s.date, "Requested civilian-use review (odds about \(Fmt.pct(approvalOdds(s, p), decimals: 0))).")
        case 2:
            let cost = cleanRoomCost(p)
            if s.cash >= cost {
                s.cash -= cost
                s.month.costOther += cost
                p.direct += cost
                p.secrecy = .cleanRoom
                p.secrecyUntil = months(6, 10)
                log(&p, s.date, "Clean-room rebuild started (\(Fmt.money(cost))).")
            } else {
                p.secrecy = .classified
                log(&p, s.date, "Couldn't fund a clean-room rebuild; the discovery stays classified.", -1)
            }
        case 3:
            p.secrecy = .licensed
            p.royaltyMonthly = royaltyMonthly(p)
            p.royaltyMonthsLeft = 36
            p.effectScale = 0.2
            p.stage = .commercialisation
            log(&p, s.date, "Licensed the permitted parts: \(Fmt.money(p.royaltyMonthly))/month for three years.", 1)
        case 4:
            p.secrecy = .partnered
            p.effectScale = 0.45
            p.stage = .commercialisation
            s.advanced.programmes[i] = p
            income(&s, i, p.value * 0.08)
            p = s.advanced.programmes[i]
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) + 0.5, -10, 10)
            log(&p, s.date, "Partnered with an authorised organisation: \(Fmt.money(p.value * 0.08)) up front.", 1)
        default:
            p.secrecy = .classified
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) + 1.5, -10, 10)
            s.politicalCapital = min(100, s.politicalCapital + 2)
            if let agency { Stakeholders.move(&s, [agency.region.rawValue: 2], "Kept a classified discovery from \(p.sol.title) under wraps") }
            log(&p, s.date, "Kept the discovery classified.", 1)
        }
        s.advanced.programmes[i] = p
    }

    static func finishSecrecy(_ s: inout GameState, _ i: Int) {
        var p = s.advanced.programmes[i]
        p.secrecyUntil = nil
        switch p.secrecy {
        case .review:
            let odds = approvalOdds(s, p)
            let r = roll(s, "approval|\(p.sol.id)")
            if r < odds {
                p.secrecy = .approved
                p.effectScale = 1
                p.stage = .commercialisation
                s.brand = min(100, s.brand + 2)
                log(&p, s.date, "Civilian use approved (roll \(Fmt.trim(r, 2)) under \(Fmt.pct(odds, decimals: 0))).", 1)
                Sim.news(&s, "Cleared for civilian use", "The review board approves commercial use of what \(p.sol.title) discovered. It goes into your models.", .research, good: true)
            } else {
                p.secrecy = .denied
                log(&p, s.date, "Civilian use denied (roll \(Fmt.trim(r, 2)) over \(Fmt.pct(odds, decimals: 0))). It stays classified.", -1)
                Sim.news(&s, "Civilian use denied", "The review board keeps what \(p.sol.title) discovered classified.", .research, good: false)
            }
        case .cleanRoom:
            let r = roll(s, "taint|\(p.sol.id)")
            if r < 0.1 {
                p.secrecy = .tainted
                p.effectScale = 0
                if let a = p.sol.agencyDef { Stakeholders.move(&s, [a.region.rawValue: -4], "A clean-room rebuild of classified work was found tainted") }
                s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) - 2, -10, 10)
                log(&p, s.date, "Taint finding (roll \(Fmt.trim(r, 2)) under 10%): the clean-room version is withdrawn.", -1)
                Sim.news(&s, "Clean-room rebuild withdrawn", "Investigators found classified material in the 'independent' rebuild. Standing −4.", .policy, important: true, good: false)
            } else {
                p.secrecy = .cleanRoomDone
                p.effectScale = 0.7
                p.stage = .commercialisation
                log(&p, s.date, "Clean-room version finished and in use (taint roll \(Fmt.trim(r, 2)) over 10%).", 1)
                Sim.news(&s, "Clean-room rebuild done", "An independent team rebuilt the capability from public knowledge. It goes into your models.", .research, good: true)
            }
        default: break
        }
        s.advanced.programmes[i] = p
    }

    // MARK: Effects

    static var virtualItems: [ResearchItem] {
        AgencyCatalog.templates.map {
            ResearchItem(id: bonusPrefix + $0.id, name: $0.title, category: .science, year: 0, cost: 0, prereqs: [], effects: $0.effects, blurb: $0.reward)
        }
    }

    /// Effects of finished programmes (strongest result per kind of programme).
    static func bonusSources(_ s: GameState) -> [(String, Double)] {
        guard !s.advanced.programmes.isEmpty else { return [] }
        var best: [String: Double] = [:]
        for p in s.advanced.programmes where p.status != .active && p.effectScale > 0 {
            best[p.sol.template] = max(best[p.sol.template] ?? 0, p.effectScale)
        }
        return best.sorted { $0.key < $1.key }.map { (bonusPrefix + $0.key, $0.value) }
    }

    /// Domain know-how from finished programmes (Capabilities adds it to new models).
    static func domainEffects(_ s: GameState) -> [(CapDomain, Double)] {
        var out: [(CapDomain, Double)] = []
        for (id, scale) in bonusSources(s) {
            guard let t = AgencyCatalog.templateByID[String(id.dropFirst(bonusPrefix.count))] else { continue }
            for e in t.effects { if case .domain(let d, let v) = e { out.append((d, v * scale)) } }
        }
        return out
    }

    /// Standing a government gives you for programmes delivered (or failed) for its agencies.
    static func standingBonus(_ s: GameState, _ r: Region) -> Double {
        guard !s.advanced.ratings.isEmpty else { return 0 }
        var v = 0.0
        for a in AgencyCatalog.all where a.region == r {
            let x = rating(s, a.id)
            v += x > 0 ? 0.4 * x : x
        }
        return clamp(v, -8, 6)
    }

    // MARK: Helpers

    static func signed(_ v: Double) -> String { (v >= 0 ? "+" : "−") + Fmt.money(abs(v)) }

    /// Alerts only once you've engaged with the division.
    static func alert(_ s: inout GameState, _ key: String, _ title: String, _ body: String, critical: Bool = false, celebrate: Bool = false) {
        guard s.advanced.engaged else { return }
        Alerts.raise(&s, .advanced, key: key, title: title, body: body, screen: .advancedProjects, critical: critical, celebrate: celebrate, cooldown: 0)
    }

    /// Plain-English cancellation and default conditions for a solicitation.
    static func conditions(_ sol: Solicitation) -> [String] {
        var out: [String] = []
        switch sol.type {
        case .fixedPrice:
            out.append("Cure notice at \(Int(Double(sol.months) * 1.25)) months; termination for default at \(Int(Double(sol.months) * 1.6)) months (20% of payments repaid)")
        case .costPlus:
            out.append("Costs reimbursed up to \(Fmt.money(sol.estCost * 1.25)) (pay above the allowable-compensation cap isn't); audits every 6 months; termination for default at \(Int(Double(sol.months) * 1.9)) months")
        case .grant:
            out.append("Lapses if not finished in \(sol.months * 2) months; unspent grant money is returned")
        case .prize:
            out.append("Ends when a competitor delivers first (10% runner-up award if you're 60% done)")
        }
        out.append("Must be mobilised within \(mobilisationGrace(sol)) months of award; the schedule runs from mobilisation")
        out.append("May be terminated for convenience if the agency's budget is cut (settlement paid)")
        if sol.level >= .secret { out.append("Stop-work order if your weight security falls below SL\(sol.level.requiredSL)") }
        return out
    }
}
