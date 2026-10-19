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
    /// Open solicitations you could bid on, and others (work for other countries' labs), at most.
    static let maxOpen = 9
    static let maxForeign = 4

    // MARK: Basics

    /// A hashed roll in 0..<1 for this game (no RNG draw).
    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("adv|\(s.advanced.salt)|\(key)") }

    /// Your headquarters' region (from the HQ country you chose).
    static func homeRegion(_ s: GameState) -> Region { HQ.region(s) }

    /// Your headquarters' country code ("us", "fr", …).
    static func homeCountry(_ s: GameState) -> String { HQ.country(s).id }

    /// The HQ country of a rival lab, for national agencies' classified work ("" when it isn't one of the playable countries).
    static func labCountry(_ id: String) -> String {
        let hq = CompetitorCatalog.def(id).hq.lowercased()
        let table: [(String, String)] = [
            ("paris", "fr"), ("lyon", "fr"), ("grenoble", "fr"), ("toulouse", "fr"), ("milan", "it"), ("rome", "it"), ("turin", "it"),
            ("copenhagen", "dk"), ("aarhus", "dk"), ("bucharest", "ro"), ("cluj", "ro"),
        ]
        if let hit = table.first(where: { hq.contains($0.0) }) { return hit.1 }
        return labRegion(id) == .us ? "us" : ""
    }

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

    /// The same for a specific agency: a national agency keeps its Secret and Top Secret work for labs headquartered in
    /// its own country; its unclassified and controlled work follows the region's rules.
    static func eligible(home: Region, country: String, agency a: AgencyDef, level: Classification) -> Bool {
        if !a.country.isEmpty && level >= .secret { return country == a.country }
        return eligible(home: home, agency: a.region, level: level)
    }

    /// Whether you may bid on a solicitation at all (headquarters rules only).
    static func openToYou(_ sol: Solicitation, _ s: GameState) -> Bool {
        guard let a = sol.agencyDef else { return true }
        return eligible(home: homeRegion(s), country: homeCountry(s), agency: a, level: sol.level)
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
        return budgetScale(s.year) * a.budget * clamp(concernMult * rulesMult, 0.5, 2.2) * Nations.agencyFactor(s, a.region)   // 3.7: sovereign-AI programmes
            * leverFactor(a, s)
    }

    /// National agencies' budgets also follow one strategy dial of their region (energy funds follow energy policy, research
    /// councils compute subsidies): ×0.75 at 0, ×1 at 50, ×1.25 at 100.
    static func leverFactor(_ a: AgencyDef, _ s: GameState) -> Double {
        guard let l = a.lever, s.nations.ready else { return 1 }
        return clamp(1 + 0.25 * (s.nations.level(a.region, l) - 50) / 50, 0.75, 1.25)
    }

    /// Agencies size what they offer to the lab they're talking to: a ten-person startup sees smaller lots, a lab with
    /// thousands of staff sees larger, more ambitious programmes (×0.6 … ×2).
    static func companyScale(_ s: GameState) -> Double {
        clamp(pow(Double(max(5, s.employees.count)) / 60, 0.3), 0.6, 2.0)
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
        auditCertified(&s)
        payRoyalties(&s)
        payPatents(&s)
        publicationRisk(&s)
        syncSeconded(&s)
    }

    static func post(_ s: inout GameState) {
        let today = s.date
        s.advanced.solicitations.removeAll { $0.closes <= today && $0.bid == nil }
        let ym = s.date.ym
        let y = s.year
        for a in AgencyCatalog.all {
            let open = s.advanced.solicitations.filter { $0.bid == nil }
            let mine = open.filter { openToYou($0, s) }.count
            guard mine < maxOpen || open.count - mine < maxForeign else { break }
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
            let sol = make(pick, a, s, key: "\(a.id)|\(ym.year)-\(ym.month)", followOn: false)
            // Work you can't bid on is listed too (it shows the market), but it never crowds out work you can.
            if openToYou(sol, s) ? mine >= maxOpen : open.count - mine >= maxForeign { continue }
            s.advanced.solicitations.append(sol)
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
        let budget = agencyBudget(a, s)
        let size = companyScale(s)
        // The year sets the agency's budget; the lab's size sets how ambitious a lot it offers; no single award takes more
        // than 40% of the agency's annual AI budget.
        var value = min(budget * 0.4, budget * t.size * (0.7 + 0.6 * r("value")) * scale * size)
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
        n = seed ? clamp(n, 1, 3) : clamp(n, 2, Int((10 * max(1, size)).rounded()))
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
            guard let v = s.labDomains[c.id], eligible(home: labRegion(c.id), country: labCountry(c.id), agency: a, level: sol.level) else { continue }
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
            let focus = Nations.bidBoost(s, lab: c.id, agency: a)   // 3.7: specialists bid for the work they specialise in
            interest += focus.interest
            if sol.template == "seedling" { interest *= 0.35 }   // big labs rarely chase seedlings
            guard roll(s, "rival|\(sol.id)|\(c.id)") < clamp(interest, 0.02, 0.95) else { continue }
            let aggressive = c.def.priceMult < 0.8 ? 0.05 : 0
            let price = 0.84 + 0.14 * roll(s, "rivalprice|\(sol.id)|\(c.id)") - aggressive
            bids.append(RivalBid(lab: c.id, tech: tech + (c.brand - 40) / 15 + focus.tech, price: price))
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
        if let a = sol.agencyDef, !openToYou(sol, s) {
            out.append(sol.level == .unclassified ? "\(a.short) doesn't contract with labs from your country" : "\(sol.level.title) work for \(a.homeName) is open to its own labs only")
        }
        if sol.level > .unclassified, let why = Progression.blocker(s, .classified) { out.append(String(why.dropLast())) }   // 3.8: Frontier Lab
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
        if let k = sol.templateDef?.facility, facilityFree(s, k, level: sol.level) >= 1 { ready += 1 }
        let past = rating(s, sol.agency) + (standing(s, sol.agencyDef?.region ?? .us) - 50) / 5
        let pScore = priceScore(sol.type, price)
        o.parts = [("Technical margin", w.tech * tech), ("Readiness", w.tech * ready), ("Price", w.price * pScore), ("Record & standing", w.past * past)]
        let pref = homePreference(sol, s)
        if pref != 0 { o.parts.append(("Home-country preference", pref)) }
        let arm = Corporate.bidBoost(s, region: sol.agencyDef?.region ?? .us)   // 3.8: a government-research subsidiary there
        if arm > 0 { o.parts.append(("Your government research arm", arm)) }
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

    /// National agencies favour labs headquartered at home (more when the sovereign-AI dial is high); region-wide bodies
    /// favour labs from their region a little.
    static func homePreference(_ sol: Solicitation, _ s: GameState) -> Double {
        guard let a = sol.agencyDef else { return 0 }
        let sovereign = s.nations.ready ? clamp((s.nations.level(a.region, .sovereign) - 40) / 60, 0, 1) : 0
        if !a.country.isEmpty { return homeCountry(s) == a.country ? 3 + 2 * sovereign : 0 }
        return homeRegion(s) == a.region && a.region != .us ? 1 + sovereign : 0
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
        s.advanced.facilities.filter { $0.kind.isCompute && $0.level >= level && $0.isReady(s.date) }.reduce(0) { $0 + $1.capacity }
    }

    // MARK: Programme spaces (engineering bays, confidential lab benches, certified enclaves)

    /// The accreditation a programme needs from its facility: its classification, CUI at least.
    static func spaceLevel(_ level: Classification) -> Int { max(1, level.rawValue) }

    /// Usable units of a kind accredited at `level` or higher (suspended certified environments don't count).
    static func spaceCapacity(_ s: GameState, _ kind: FacilityKind, atLeast level: Int) -> Double {
        s.advanced.facilities.filter { $0.kind == kind && $0.level >= level && $0.isUsable(s.date) }.reduce(0) { $0 + $1.capacity }
    }

    /// Active programmes that need this kind of space at `level` or higher, oldest award first.
    static func spaceUsers(_ s: GameState, _ kind: FacilityKind, atLeast level: Int) -> [Programme] {
        s.advanced.programmes.filter { $0.status == .active && $0.template?.facility == kind && spaceLevel($0.sol.level) >= level }
    }

    /// Free units for a new programme at this classification.
    static func facilityFree(_ s: GameState, _ kind: FacilityKind, level: Classification) -> Double {
        let l = spaceLevel(level)
        var free = Double.infinity
        for k in 1...l { free = min(free, spaceCapacity(s, kind, atLeast: k) - Double(spaceUsers(s, kind, atLeast: k).count)) }
        return max(0, free)
    }

    /// Whether a running programme has its space: programmes take units in award order.
    static func hasSpace(_ s: GameState, _ p: Programme) -> Bool {
        guard let kind = p.template?.facility else { return true }
        let l = spaceLevel(p.sol.level)
        let before = spaceUsers(s, kind, atLeast: l).filter { ($0.awarded, $0.id.uuidString) < (p.awarded, p.id.uuidString) }.count
        return Double(before) < spaceCapacity(s, kind, atLeast: l)
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
        /// The bay, bench or enclave the work needs (×0.5 without it once mobilised).
        var space = 1.0
        var missing: [String] = []
        /// Pace against plan (1 = on schedule). Test campaigns and reviews keep even a great team from finishing much early.
        var total: Double { security ? min(1.15, staffing * compute * capability * agents * space) : 0 }
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
        var spaceOK = true
        if let kind = p.template?.facility, !hasSpace(s, p) {
            spaceOK = false
            f.space = 0.5
            f.missing.append("A \(kind.short) accredited \(facilityLevelName(spaceLevel(sol.level))) or higher")
        }
        f.capability = clamp(1 + 0.02 * margin(sol, playerScores(s)), 0.6, 1.25)
        if sol.level.agentsAllowed, let id = p.swarm, let sw = s.swarms.first(where: { $0.id == id }), !sw.paused {
            f.agents = 1 + min(0.3, 0.07 * log10(1 + sw.active))
        }
        let total = sol.staffTotal
        f.mobilised = rolesCovered && Double(team.count) >= 0.6 * Double(total) && f.security && (sol.level == .unclassified || p.compute >= 0.5 * sol.computeH100e) && spaceOK
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
        s.month.revContracts += amount   // 3.8: milestone income, kept out of the recurring run rate
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
        recordDiscovery(&s, i)
        // Public-facing work (disaster response, emissions data) earns trust the day it's delivered, if you may talk about it.
        if p.secrecy != .pending, let t {
            for case .publicTrust(let v) in t.legacy { Stakeholders.move(&s, ["public": v * p.effectScale], "Delivered \(sol.title) for \(a?.short ?? sol.agency)") }
        }
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
        guard p.sol.level > .unclassified || p.template?.facility != nil, p.status == .active else { return 0 }
        var share = 0.0
        let usedCompute = computeAssigned(s, atLeast: 1)
        let usedSeats = seatsAssigned(s, atLeast: 1)
        for f in s.advanced.facilities where f.isReady(s.date) {
            if f.kind == .secureLab {
                if usedSeats > 0 { share += f.opex * Double(p.staff.count) / max(usedSeats, f.capacity) }
            } else if f.kind.isCompute {
                if usedCompute > 0 { share += f.opex * p.compute / max(usedCompute, computeCapacity(s, atLeast: 1)) }
            } else if p.template?.facility == f.kind && f.level >= spaceLevel(p.sol.level) {
                let users = Double(spaceUsers(s, f.kind, atLeast: 1).count)
                share += f.opex / max(users, f.capacity)
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

    /// Certified environments are audited once a year after accreditation. A finding suspends the certification for two
    /// months (programmes that need it slow to half pace) and costs record with every agency in your home region.
    static func auditCertified(_ s: inout GameState) {
        for i in s.advanced.facilities.indices where s.advanced.facilities[i].kind == .certified && s.advanced.facilities[i].isReady(s.date) {
            let f = s.advanced.facilities[i]
            let years = GameCalendar.daysBetween(f.ready, s.date) / 365
            guard years > f.audits else { continue }
            s.advanced.facilities[i].audits += 1
            let chance = 0.12 + 0.03 * Double(f.level) - (s.safetyScore > 70 ? 0.04 : 0) + (s.security.rawValue < f.level + 1 ? 0.1 : 0)
            let r = roll(s, "certaudit|\(f.id.uuidString)|\(f.audits)")
            if r < chance {
                s.advanced.facilities[i].auditFindings += 1
                s.advanced.facilities[i].suspendedUntil = GameCalendar.addMonths(s.date, 2)
                for a in AgencyCatalog.all where a.region == homeRegion(s) && s.advanced.ratings[a.id] != nil {
                    s.advanced.ratings[a.id] = clamp(rating(s, a.id) - 0.3, -10, 10)
                }
                Sim.news(&s, "\(f.name): certification suspended", "The annual audit found gaps in key management and access logs (roll \(Fmt.trim(r, 2)) under \(Fmt.pct(chance, decimals: 0))). Two months to fix them; programmes that need it run at half pace.",
                         .company, image: f.kind.image, good: false)
                alert(&s, "certaudit|\(f.id)", "\(f.name) suspended", "A failed certification audit: programmes in it slow down for two months.")
            } else if s.advanced.engaged {
                Sim.news(&s, "\(f.name) recertified", "The annual audit is clean (roll \(Fmt.trim(r, 2)) over \(Fmt.pct(chance, decimals: 0)) finding odds).", .company, image: f.kind.image, good: true)
            }
        }
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
        if kind.isProgrammeSpace { return [1, 3, 8] }
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
        let era = 1 + 0.03 * max(0, y - 2016)
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
        case .engineering:
            // Clean workshops and test bays (environmental chambers, antenna ranges, a small fab line for process trials).
            q.capex = capacity * [6e6, 12e6, 22e6][l] * era
            q.kw = capacity * 900
            q.opex = q.capex * 0.012 * levelPremium[l] + q.kw * 24 * 30.4 * 0.09
            q.months = [5, 8, 12][l]
        case .confidentialScience:
            q.capex = capacity * [4e6, 9e6, 18e6][l] * era
            q.kw = capacity * 250
            q.opex = q.capex * 0.015 * levelPremium[l] + q.kw * 24 * 30.4 * 0.09
            q.months = [4, 7, 11][l]
        case .certified:
            // Certified networks, enclaves and key management, plus the yearly audit.
            q.capex = capacity * [2.5e6, 6e6, 14e6][l] * era
            q.kw = capacity * 60
            q.opex = q.capex * 0.02 * levelPremium[l] + q.kw * 24 * 30.4 * 0.09
            q.months = [6, 9, 14][l]
        }
        q.months /= Campus.speedup(y)
        return q
    }

    /// Running-cost premium by accreditation level for the programme spaces (guards, inspections, separate networks).
    static let levelPremium = [1.0, 1.3, 1.7]

    /// People who must hold a clearance at the facility's level before you build one (facility security officers).
    static func officersNeeded(_ kind: FacilityKind, level: Int) -> Int { kind.isProgrammeSpace ? clamp(level, 1, 3) + 1 : 0 }

    /// What stops you building a facility kind (other than money and a site).
    static func facilityBlockers(_ kind: FacilityKind, level: Int, _ s: GameState) -> [String] {
        var out: [String] = []
        let need = officersNeeded(kind, level: level)
        let have = s.employees.filter { clearanceLevel(s, $0.id) >= level }.count
        if have < need { out.append("\(need) staff cleared \(Classification(rawValue: level)?.clearance ?? "") to run it (you have \(have))") }
        switch kind {
        case .confidentialScience:
            if s.science.labs.isEmpty { out.append("A science lab to annex it to") }
        case .certified:
            if seatCapacity(s, atLeast: level) < 1 && !s.advanced.facilities.contains(where: { $0.kind == .secureLab && $0.level >= level }) {
                out.append("A secure lab accredited \(facilityLevelName(level)) or higher")
            }
        default: break
        }
        return out
    }

    /// Sites a facility kind can go on.
    static func sitesFor(_ kind: FacilityKind, _ s: GameState) -> [Site] {
        s.sites.filter { site in
            guard site.isReady(s.date) else { return false }
            switch kind {
            case .secureLab: return site.kind != .garage
            case .restrictedCompute: return site.kind == .colo || site.kind == .datacenter
            case .clearedHall: return site.kind == .datacenter
            case .engineering, .confidentialScience, .certified: return site.kind != .garage
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
                                     DecisionOption(label: "Partner with an authorised organisation", detail: "\(Fmt.money(p.value * 0.08)) now from a cleared partner, 45% of the effect, record +0.5."),
                                     DecisionOption(label: "Retain it for internal use only", detail: "Use it inside your own company (half the internal effect: costs, infrastructure, chips — no products, no licences, no papers). Record +1, standing +1, political capital +1.")],
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
        case 5:
            // Retained internally: it stays classified (no products, licences or papers) but your own teams use it.
            p.secrecy = .retained
            p.effectScale = retainedScale
            p.stage = .commercialisation
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) + 1, -10, 10)
            s.politicalCapital = min(100, s.politicalCapital + 1)
            if let agency { Stakeholders.move(&s, [agency.region.rawValue: 1], "Kept a classified discovery from \(p.sol.title) inside the company") }
            log(&p, s.date, "Retained for internal use only: your own teams use it; nothing leaves the company.", 1)
        default:
            p.secrecy = .classified
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) + 1.5, -10, 10)
            s.politicalCapital = min(100, s.politicalCapital + 2)
            if let agency { Stakeholders.move(&s, [agency.region.rawValue: 2], "Kept a classified discovery from \(p.sol.title) under wraps") }
            log(&p, s.date, "Kept the discovery classified.", 1)
        }
        s.advanced.programmes[i] = p
        syncDiscovery(&s, i)
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
        syncDiscovery(&s, i)
    }

    // MARK: Discoveries and patents

    /// Share of a result's internal effects you keep when it's retained for internal use only.
    static let retainedScale = 0.5

    /// A delivered programme's discovery joins your discoveries and patents: open work is published and patented at once;
    /// classified work is patented under a secrecy order and can't be published until it's cleared.
    static func recordDiscovery(_ s: inout GameState, _ i: Int) {
        let p = s.advanced.programmes[i]
        guard let t = p.template, let what = t.discovery, !s.advanced.discoveries.contains(where: { $0.programme == p.id }) else { return }
        let classified = p.sol.level >= .secret
        var d = ProgrammeDiscovery(programme: p.id, template: t.id, title: what, agency: p.sol.agency, level: p.sol.classification, date: s.date,
                                   patentFiled: s.date, secrecyOrder: classified)
        if !classified {
            d.cleared = s.date
            d.published = p.sol.level == .unclassified
            d.licensees = p.sol.ip == .government ? 0 : 2 + Int(roll(s, "licensees|\(p.sol.id)") * 3)
        }
        s.advanced.discoveries.append(d)
        log(&s.advanced.programmes[i], s.date, classified ? "Discovery recorded: \(what). Patent filed under a secrecy order; no publication."
            : "Discovery recorded: \(what). Patent filed\(d.published ? " and the paper published" : " (pre-publication review)")\(d.licensees > 0 ? "; \(d.licensees) licensees" : "").", 1)
        if classified { return }
        if let f = t.sciField { Science.bumpMomentum(&s, f, 0.01) }
    }

    /// Keep a programme's discovery in step with the secrecy decision: cleared for commercial use lifts the secrecy order
    /// and opens the patent to licensees; anything else keeps it sealed.
    static func syncDiscovery(_ s: inout GameState, _ i: Int) {
        let p = s.advanced.programmes[i]
        guard let k = s.advanced.discoveries.firstIndex(where: { $0.programme == p.id }), s.advanced.discoveries[k].secrecyOrder else { return }
        guard p.secrecy.commercial else { return }
        s.advanced.discoveries[k].secrecyOrder = false
        s.advanced.discoveries[k].cleared = s.date
        // A licence deal pays its own royalties; otherwise licensees take the newly unsealed patent.
        s.advanced.discoveries[k].licensees = p.secrecy == .licensed ? 0 : 1 + Int(roll(s, "licensees|\(p.sol.id)") * 3)
        s.advanced.discoveries[k].published = p.secrecy == .approved
        if let f = p.template?.sciField { Science.bumpMomentum(&s, f, 0.01) }
        log(&s.advanced.programmes[i], s.date, "Secrecy order lifted on the patent for \(s.advanced.discoveries[k].title).", 1)
    }

    /// What one licensee pays a month for a programme patent (era-scaled, smaller for government-owned IP).
    static func patentRoyalty(_ d: ProgrammeDiscovery, _ s: GameState) -> Double {
        guard let p = s.advanced.programmes.first(where: { $0.id == d.programme }) else { return 25_000 * Science.eraScale(s.year) }
        return p.value * 0.0006 * (p.sol.ip == .government ? 0.5 : 1)
    }

    /// Patent royalties for cleared discoveries (twenty years from filing; nothing while under a secrecy order).
    static func payPatents(_ s: inout GameState) {
        guard !s.advanced.discoveries.isEmpty else { return }
        for k in s.advanced.discoveries.indices {
            let d = s.advanced.discoveries[k]
            guard !d.secrecyOrder, d.licensees > 0, s.date < GameCalendar.addMonths(d.patentFiled, 240) else {
                s.advanced.discoveries[k].lastMonth = 0
                continue
            }
            let r = patentRoyalty(d, s) * Double(d.licensees)
            s.advanced.discoveries[k].lastMonth = r
            s.advanced.discoveries[k].lifetime += r
            s.cash += r
            s.month.revLicensing += r
            s.lifetimeRevenue += r
        }
    }

    /// Entries for the company history timeline (contracts, deliveries, discoveries, clearances for civilian use).
    /// Hook: `Science.companyHistory` can append these (`out += AdvancedProjects.historyEntries(s)`).
    static func historyEntries(_ s: GameState) -> [Science.HistoryEntry] {
        var out: [Science.HistoryEntry] = []
        for p in s.advanced.programmes {
            let agency = p.sol.agencyDef?.short ?? p.sol.agency
            out.append(Science.HistoryEntry(id: "ap|\(p.id)", date: p.awarded, title: "Contract won: \(p.sol.title)", detail: "\(agency) · \(p.sol.level.title)",
                                            symbol: "building.columns.fill", kind: "programme"))
            if p.status == .completed, let e = p.ended {
                out.append(Science.HistoryEntry(id: "apd|\(p.id)", date: e, title: "Programme delivered: \(p.sol.title)", detail: agency,
                                                symbol: "checkmark.seal.fill", kind: "programme"))
            }
        }
        for d in s.advanced.discoveries {
            let restricted = d.classified && d.secrecyOrder
            out.append(Science.HistoryEntry(id: "apx|\(d.id)", date: d.date, title: restricted ? "Classified discovery: \(d.title)" : "Discovery: \(d.title)",
                                            detail: "\(AgencyCatalog.byID[d.agency]?.short ?? d.agency) programme\(restricted ? " · patent under secrecy order" : "")",
                                            symbol: restricted ? "lock.doc.fill" : "atom", kind: restricted ? "classified" : "discovery"))
            if d.classified, let c = d.cleared {
                out.append(Science.HistoryEntry(id: "apc|\(d.id)", date: c, title: "Cleared for civilian use: \(d.title)", detail: "Secrecy order lifted",
                                                symbol: "lock.open.fill", kind: "commercial"))
            }
        }
        return out.filter { $0.date <= s.date }.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    // MARK: Effects

    static let internalPrefix = "adv:i:"

    /// Effects a result retained for internal use still gives: what your own operations use (costs, efficiency,
    /// infrastructure, security), not what goes into products or sales (demand, model skills and domains).
    static func internalEffects(_ t: ProgrammeTemplate) -> [ResearchEffect] {
        t.effects.filter { e in
            switch e {
            case .consumerDemand, .apiDemand, .enterpriseDemand, .domain, .skill, .product, .unlock: false
            default: true
            }
        }
    }

    static var virtualItems: [ResearchItem] {
        AgencyCatalog.templates.map {
            ResearchItem(id: bonusPrefix + $0.id, name: $0.title, category: .science, year: 0, cost: 0, prereqs: [], effects: $0.effects, blurb: $0.reward)
        } + AgencyCatalog.templates.map {
            ResearchItem(id: internalPrefix + $0.id, name: "\($0.title) (internal use)", category: .science, year: 0, cost: 0, prereqs: [],
                         effects: internalEffects($0), blurb: "Retained for internal use: \($0.reward)")
        }
    }

    /// The strongest usable result per kind of programme, split into commercial use and internal-only use.
    static func strongest(_ s: GameState) -> (commercial: [String: Double], internal: [String: Double]) {
        var best: [String: Double] = [:], inside: [String: Double] = [:]
        for p in s.advanced.programmes where p.status != .active && p.effectScale > 0 {
            if p.secrecy == .retained {
                inside[p.sol.template] = max(inside[p.sol.template] ?? 0, p.effectScale)
            } else {
                best[p.sol.template] = max(best[p.sol.template] ?? 0, p.effectScale)
            }
        }
        // A commercial result of the same kind covers the internal one.
        for (k, v) in best where (inside[k] ?? 0) <= v { inside[k] = nil }
        return (best, inside)
    }

    /// Effects of finished programmes (strongest result per kind of programme).
    static func bonusSources(_ s: GameState) -> [(String, Double)] {
        guard !s.advanced.programmes.isEmpty else { return [] }
        let (best, inside) = strongest(s)
        return best.sorted { $0.key < $1.key }.map { (bonusPrefix + $0.key, $0.value) }
            + inside.sorted { $0.key < $1.key }.map { (internalPrefix + $0.key, $0.value) }
    }

    /// Domain know-how from finished programmes (Capabilities adds it to new models). Retained results don't count:
    /// they never go into a product.
    static func domainEffects(_ s: GameState) -> [(CapDomain, Double)] {
        guard !s.advanced.programmes.isEmpty else { return [] }
        var out: [(CapDomain, Double)] = []
        for (id, scale) in strongest(s).commercial.sorted(by: { $0.key < $1.key }) {
            guard let t = AgencyCatalog.templateByID[id] else { continue }
            for e in t.effects { if case .domain(let d, let v) = e { out.append((d, v * scale)) } }
        }
        return out
    }

    // MARK: Legacies (hooks elsewhere; each exactly neutral with no finished programmes)
    //
    //   power bill      Sim.dailyCosts and Power.settle multiply by `powerFactor`       (advanced cooling, grids, materials)
    //   grid stress     Power.gridMultiplier scales its premium by `gridFactor`          (energy infrastructure)
    //   chip yields     Semis.productYield / fabYield multiply D0 by `defectFactor`      (semiconductor manufacturing, materials)
    //   edge chips      Semis.makeChips multiplies inference parts' TDP by `edgeChipPower` (edge AI hardware)
    //   government line ProductLines multiplies the Government line's pull by `productPull` (satellite comms, secure comms, aerospace)
    //   public trust    Stakeholders.target adds `publicTrustBonus`                     (disaster response, emissions data)

    /// Total of one legacy kind across finished programmes (strongest result per programme kind × its value).
    static func legacy(_ s: GameState, _ pick: (ProgrammeLegacy) -> Double?) -> Double {
        guard !s.advanced.programmes.isEmpty else { return 0 }
        let (best, inside) = strongest(s)
        var total = 0.0
        for (id, scale) in best.sorted(by: { $0.key < $1.key }) {
            guard let t = AgencyCatalog.templateByID[id] else { continue }
            for l in t.legacy { if let v = pick(l) { total += v * scale } }
        }
        for (id, scale) in inside.sorted(by: { $0.key < $1.key }) {
            guard let t = AgencyCatalog.templateByID[id] else { continue }
            for l in t.legacy where l.internalUse { if let v = pick(l) { total += v * scale } }
        }
        return total
    }

    static func powerFactor(_ s: GameState) -> Double {
        let v = legacy(s) { if case .powerBill(let x) = $0 { x } else { nil } }
        return v > 0 ? 1 - min(0.12, v) : 1
    }

    static func gridFactor(_ s: GameState) -> Double {
        let v = legacy(s) { if case .gridRelief(let x) = $0 { x } else { nil } }
        return v > 0 ? 1 - min(0.6, v) : 1
    }

    static func defectFactor(_ s: GameState) -> Double {
        let v = legacy(s) { if case .defects(let x) = $0 { x } else { nil } }
        return v > 0 ? 1 - min(0.25, v) : 1
    }

    static func edgeChipPower(_ s: GameState) -> Double {
        let v = legacy(s) { if case .edgeChips(let x) = $0 { x } else { nil } }
        return v > 0 ? 1 - min(0.2, v) : 1
    }

    /// Extra pull for the Government & Defence product line.
    static func productPull(_ p: ProductDef, _ s: GameState) -> Double {
        guard p.id == "government" else { return 1 }
        let v = legacy(s) { if case .governmentPull(let x) = $0 { x } else { nil } }
        return 1 + min(0.3, v)
    }

    /// Lasting public trust from public-facing programmes.
    static func publicTrustBonus(_ s: GameState) -> Double {
        min(6, legacy(s) { if case .publicTrust(let x) = $0 { x } else { nil } })
    }

    /// The legacies in use right now, in words (for the Agencies & Record page).
    static func legacyLines(_ s: GameState) -> [String] {
        var out: [String] = []
        func pct(_ f: Double) -> String { "\(Fmt.trim((1 - f) * 100, 1))%" }
        if powerFactor(s) < 1 { out.append("Datacenter power bill −\(pct(powerFactor(s)))") }
        if gridFactor(s) < 1 { out.append("Grid-stress premium −\(pct(gridFactor(s)))") }
        if defectFactor(s) < 1 { out.append("Chip defect density −\(pct(defectFactor(s)))") }
        if edgeChipPower(s) < 1 { out.append("Inference-chip board power −\(pct(edgeChipPower(s)))") }
        if let g = ProductLines.byID["government"], productPull(g, s) > 1 { out.append("Government & Defence pull +\(Fmt.trim((productPull(g, s) - 1) * 100, 1))%") }
        if publicTrustBonus(s) >= 0.5 { out.append("Public trust +\(Fmt.trim(publicTrustBonus(s), 1))") }
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
