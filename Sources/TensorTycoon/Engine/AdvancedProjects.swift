import Foundation

/// 3.5: the Advanced Projects division. Government agencies post AI contracts on a marketplace; you bid against rival
/// labs, win, staff the programme with cleared people, give it cleared compute in accredited facilities and take it
/// through feasibility, research, experiments, a prototype, independent testing and validation. Payment depends on the
/// contract type (fixed-price, cost-plus, milestone grant, prize). Finished programmes leave standing, a track record
/// with the agency, follow-on work, research items and permanent research effects — when secrecy allows you to use them.
///
/// 3.8: agencies spend from a yearly budget that awards (yours and rivals') draw down; rival labs carry out the work
/// they win, and can default; clearances need upkeep and periodic reinvestigation; facilities draw real power from
/// their site and stop without cleared security officers; classified work restricts publication; and a mobilisation
/// planner shows what it takes to start a classified programme before you bid.
///
/// Every roll is hashed (`roll`), never drawn from the game's RNG, and the division never sends news, alerts or decisions
/// about your own work until you engage with it.
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

    /// How far an agency trusts you with classified work (−10…+10).
    static func trust(_ s: GameState, _ agency: String) -> Double { s.advanced.trust[agency] ?? 0 }

    static func addTrust(_ s: inout GameState, _ agency: String, _ v: Double) {
        guard v != 0 else { return }
        s.advanced.trust[agency] = clamp(trust(s, agency) + v, -10, 10)
    }

    /// A rival lab's record with an agency.
    static func rivalRating(_ s: GameState, agency: String, lab: String) -> Double { s.advanced.rivalRatings["\(agency)|\(lab)"] ?? 0 }

    static func rivalName(_ lab: String) -> String { lab.isEmpty ? "An outside team" : CompetitorCatalog.def(lab).name }

    // MARK: Jurisdiction (where classified facilities may be)

    /// The country of a datacenter location ("" when unknown).
    static func locationCountry(_ id: String) -> String {
        switch id {
        case "nova", "texas", "iowa", "oregon", "arizona": "us"
        case "quebec": "ca"
        case "iceland": "is"
        case "uae": "ae"
        case "dk_jutland": "dk"
        case "fr_rhone": "fr"
        case "it_milan": "it"
        case "ro_bucharest": "ro"
        default: ""
        }
    }

    /// Allied jurisdictions for controlled work: the US, UK, EU (and the EEA), Japan/Korea and Canada.
    static func alliedLocation(_ id: String) -> Bool { ["us", "ca", "is", "dk", "fr", "it", "ro"].contains(locationCountry(id)) }

    /// Why a site can't host a facility accredited at `level` (nil if it can). Secret and Top Secret facilities must be
    /// in your home country, on a site you run yourself; controlled ones anywhere among allies (for an allied lab).
    static func sitingBlocker(_ site: Site, level: Int, _ s: GameState) -> String? {
        let country = locationCountry(site.locationID)
        let home = homeCountry(s)
        if level >= Classification.secret.rawValue {
            if country != home { return "Secret facilities must be in \(HQ.country(s).name) (\(site.name) is in \(site.location.name))" }
            if !site.partner.isEmpty { return "\(site.partner) runs \(site.name): classified work needs a site you run yourself" }
            return nil
        }
        let alliedHome = [Region.us, .uk, .eu, .japanKorea].contains(homeRegion(s))
        if country == home || (alliedHome && alliedLocation(site.locationID)) { return nil }
        return "\(site.location.name) is outside your allies' jurisdiction: controlled work can't be hosted there"
    }

    // MARK: Money scales

    /// Dollars a year behind one unit of agency budget (≈ a large research agency's AI spending).
    static func budgetScale(_ y: Double) -> Double {
        interpolateLog([(2016, 2.5e8), (2020, 5e8), (2023, 1.2e9), (2026, 4e9), (2030, 2e10), (2036, 8e10)], at: y)
    }

    /// An agency's annual AI-programme budget: its size, the year, public concern (defence, cyber, safety), how strict
    /// its region's rules are (safety institutes and research councils), and its economy.
    static func agencyBudget(_ a: AgencyDef, _ s: GameState) -> Double {
        let w = s.world
        let strict = w.strictness.indices.contains(a.region.index) ? w.strictness[a.region.index] : 30
        let concernMult = 1 + a.kind.concernSensitivity * (w.concern - 25) / 50
        let rulesMult = 1 + a.kind.rulesSensitivity * (strict - 40) / 60
        return budgetScale(s.year) * a.budget * clamp(concernMult * rulesMult, 0.5, 2.2) * Nations.agencyFactor(s, a.region)   // 3.7: sovereign-AI programmes
            * leverFactor(a, s) * recessionFactor(s, a.region)
    }

    /// National agencies' budgets also follow one strategy dial of their region (energy funds follow energy policy, research
    /// councils compute subsidies): ×0.75 at 0, ×1 at 50, ×1.25 at 100.
    static func leverFactor(_ a: AgencyDef, _ s: GameState) -> Double {
        guard let l = a.lever, s.nations.ready else { return 1 }
        return clamp(1 + 0.25 * (s.nations.level(a.region, l) - 50) / 50, 0.75, 1.25)
    }

    /// Public budgets shrink when the economy does: each point of growth below trend in the agency's region cuts its AI
    /// budget by 6% (25% at most). Hook: when Nations keeps an explicit regional recession state, read it here.
    static func recessionFactor(_ s: GameState, _ r: Region) -> Double {
        guard s.nations.ready else { return 1 }
        let gap = s.nations.economy(r).gdpGrowth - Nations.baseGrowth(r, s.year)
        return clamp(1 + 0.06 * min(0, gap), 0.75, 1)
    }

    /// What an agency has committed this year: the annual run-rate of the active contracts it pays, yours and rivals'.
    static func obligations(_ a: AgencyDef, _ s: GameState) -> Double {
        var v = 0.0
        for p in s.advanced.programmes where p.status == .active && p.sol.agency == a.id {
            v += p.value / Double(max(1, p.sol.months)) * 12
        }
        for r in s.advanced.rivalProgrammes where r.active && r.agency == a.id { v += r.monthly * 12 }
        return v
    }

    /// Share of this year's budget an agency hasn't committed (0–1): it posts less, and smaller lots, as it fills.
    static func headroom(_ a: AgencyDef, _ s: GameState) -> Double {
        let b = agencyBudget(a, s)
        return b > 0 ? clamp(1 - obligations(a, s) / b, 0, 1) : 0
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

    /// What a bid is likely to turn into, for the proposal sheet: expected trial failures and the rework and cost growth
    /// they bring, and the margins on plan and at the expected overrun — by contract type, who carries it.
    struct Outlook {
        var failures = 0.0
        /// Expected cost growth over plan (0.12 = +12%): what the work turns out to need, plus rework.
        var growth = 0.0
        var reworkMonths = 0.0
        var revenue = 0.0
        var cashCost = 0.0
        var fullCost = 0.0
        var cashMargin: Double { revenue - cashCost }
        var fullMargin: Double { revenue - fullCost }
        /// Your share of the cost (grants: the co-funding).
        var costShare = 0.0
    }

    static func outlook(_ sol: Solicitation, _ s: GameState, price raw: Double) -> Outlook {
        var o = Outlook()
        let price = clampPrice(sol.type, raw)
        let e = estimate(sol)
        let m = margin(sol, playerScores(s))
        // Expected failures per trial stage: the first attempt fails with p, each retry with 0.7× the odds.
        var failures = 0.0
        for _ in ProgrammeStage.working.filter(\.hasTrial) {
            var p = clamp(sol.risk * clamp(1.15 - 0.03 * m, 0.5, 1.6), 0.02, 0.7), reach = 1.0
            for _ in 0..<6 {
                reach *= p
                failures += reach
                p *= 0.7
            }
        }
        o.failures = failures
        let found = sol.risk * (0.15 + 0.75 * 0.5) - 0.008 * clamp(m, 0, 15)
        let rework = failures * (0.03 + 0.05 * 0.5) * sol.risk / 0.2
        o.growth = found + rework
        // Each failure redoes 60% of a trial stage (about 18% of the programme's work on average).
        o.reworkMonths = failures * 0.6 * 0.177 * Double(sol.months)
        let extraWork = failures * 0.6 * 0.177
        o.cashCost = e.cash * (1 + o.growth) * (1 + 0.75 * extraWork) + e.proposal
        o.fullCost = o.cashCost + e.labour * (1 + extraWork) + (e.classified ? e.compute : 0)
        switch sol.type {
        case .fixedPrice, .grant: o.revenue = sol.ceiling * price
        case .costPlus: o.revenue = min(sol.estCost * 1.25, (o.fullCost - e.proposal) * 0.97) + sol.estCost * price
        case .prize: o.revenue = sol.ceiling
        }
        o.costShare = o.fullCost > 0 ? max(0, 1 - o.revenue / o.fullCost) : 0
        return o
    }

    // MARK: Marketplace

    /// First of the month: decide bids that closed, then agencies post new solicitations, programmes run (yours and
    /// rivals'), clearances and facilities are kept up, and royalties come in.
    static func monthly(_ s: inout GameState) {
        if s.advanced.salt.isEmpty { s.advanced.salt = String(s.rng.state ^ 0xAD5A_17, radix: 36) }
        closeBids(&s)
        post(&s)
        for i in s.advanced.programmes.indices where s.advanced.programmes[i].status == .active { step(&s, i) }
        rivalWork(&s)
        afterProgrammes(&s)
        clearanceUpkeep(&s)
        checkFacilities(&s)
        payFacilities(&s)
        auditCertified(&s)
        payRoyalties(&s)
        payPatents(&s)
        reviewPapers(&s)
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
            // An agency that has committed most of this year's budget posts less.
            let room = headroom(a, s)
            let p = clamp(0.05 + 0.13 * rel, 0.04, 0.32) * (0.25 + 0.75 * room)
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
            // What's left of the year's budget may be too little for a real lot.
            guard sol.ceiling >= 1e5 else { continue }
            // Work you can't bid on is listed too (it shows the market), but it never crowds out work you can.
            if openToYou(sol, s) ? mine >= maxOpen : open.count - mine >= maxForeign { continue }
            s.advanced.solicitations.append(sol)
            s.advanced.counter += 1
        }
    }

    static func roman(_ n: Int) -> String { ["", "I", "II", "III", "IV", "V", "VI"][clamp(n, 0, 6)] }

    /// Size a solicitation to the agency's budget (what's left of it this year) and the year; set the bars a little below
    /// the state of the art. A seedling scouts one of the agency's full programmes (its bars are in that programme's
    /// domains); follow-ons carry a phase number and a classification at most one level above the work before.
    static func make(_ t: ProgrammeTemplate, _ a: AgencyDef, _ s: GameState, key: String, followOn: Bool, scale: Double = 1,
                     level: Int? = nil, phase: Int = 0) -> Solicitation {
        let y = s.year
        let k = "sol|\(key)|\(t.id)"
        func r(_ tag: String) -> Double { roll(s, "\(k)|\(tag)") }
        let seed = t.id == "seedling"
        var target: ProgrammeTemplate? = nil
        if seed {
            let subjects = AgencyCatalog.templates.filter { $0.agencies.contains(a.id) && $0.id != "seedling" && $0.year <= y + 1 }
            if !subjects.isEmpty { target = subjects[min(subjects.count - 1, Int(r("target") * Double(subjects.count)))] }
        }
        let type = t.types[min(t.types.count - 1, Int(r("type") * Double(t.types.count)))]
        let ip = t.ip[min(t.ip.count - 1, Int(r("ip") * Double(t.ip.count)))]
        let months = max(4, Int((Double(t.months) * (0.85 + 0.3 * r("months"))).rounded()))
        let budget = agencyBudget(a, s)
        let size = companyScale(s)
        // The year sets the agency's budget; the lab's size sets how ambitious a lot it offers; no single award takes more
        // than 40% of the agency's annual AI budget, nor more than what's left of this year's.
        var value = min(budget * 0.4, budget * t.size * (0.7 + 0.6 * r("value")) * scale * size)
        // Seedlings stay small whatever the agency's budget.
        if seed { value = min(value, 2.5e7 * (0.6 + 0.4 * r("seedcap"))) }
        value = min(value, max(0, budget - obligations(a, s)) * Double(months) / 12)
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
        for d in (target ?? t).domains {
            let bar = stateOfArt(s, d) - t.gap + followGap - 3 + 6 * r("bar|\(d.rawValue)")
            domains[d.rawValue] = (bar * 2).rounded() / 2
        }
        var title = t.title
        if seed, let target { title = "Phase I feasibility: \(target.title.prefix(1).lowercased() + target.title.dropFirst())" }
        else if phase >= 2 { title = "\(t.title) — Phase \(roman(phase))" }
        var sol = Solicitation(id: "ap\(s.advanced.counter)-\(a.id)-\(t.id)", agency: a.id, template: t.id, title: title, type: type, ip: ip,
                               classification: clamp(level ?? t.classification, 0, 3), ceiling: (value / 1e4).rounded() * 1e4,
                               estCost: (estCost / 1e4).rounded() * 1e4, months: months, domains: domains, research: t.research,
                               computeH100e: compute, staff: staff, risk: t.risk * (0.8 + 0.4 * r("risk")), basis: t.basis, posted: s.date,
                               closes: GameCalendar.addMonths(s.date, followOn ? 2 : 2 + (r("close") < 0.4 ? 1 : 0)))
        sol.followOn = followOn
        sol.phase = seed ? 1 : phase
        sol.target = target?.id ?? ""
        sol.bidders = rivalBids(sol, s, limit: followOn ? 1 : 3)
        return sol
    }

    /// Rival labs that bid: those whose models come near the bars, who may do work of this classification for this
    /// agency, and whose strategy fits the work. (Their technical scores are re-evaluated at the close: `effectiveBidders`.)
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

    /// The rival bids as the agency evaluates them today: each lab's current best model against the bars (models released
    /// since it bid count), and labs that went under — or into distress and can't staff the work — drop out.
    static func effectiveBidders(_ sol: Solicitation, _ s: GameState) -> [RivalBid] {
        guard let a = sol.agencyDef else { return sol.bidders }
        var out: [RivalBid] = []
        for b in sol.bidders {
            guard let c = s.competitors.first(where: { $0.id == b.lab }), c.alive else { continue }
            if c.distressMonths > 0 && roll(s, "withdraw|\(sol.id)|\(b.lab)") < 0.5 { continue }
            let focus = Nations.bidBoost(s, lab: c.id, agency: a)
            out.append(RivalBid(lab: b.lab, tech: margin(sol, s.labDomains[c.id]) + (c.brand - 40) / 15 + focus.tech, price: b.price))
        }
        return out
    }

    /// Each rival's evaluation score: technical, price and its own record with the agency.
    static func rivalScores(_ sol: Solicitation, _ s: GameState) -> [(lab: String, score: Double)] {
        let w = sol.basis.weights
        return effectiveBidders(sol, s).map { b in
            (b.lab, w.tech * b.tech + w.price * priceScore(sol.type, rivalPrice(sol.type, b.price)) + w.past * rivalRating(s, agency: sol.agency, lab: b.lab))
        }
    }

    /// A rival's bid as a price share, or its fee rate on cost-plus work.
    static func rivalPrice(_ type: ContractType, _ price: Double) -> Double { type == .costPlus ? 0.06 + 0.06 * (price - 0.84) / 0.14 : price }

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
        var plan = MobPlan()
    }

    static func priceScore(_ type: ContractType, _ price: Double) -> Double {
        switch type {
        case .fixedPrice, .grant: (1 - price) * 50
        case .costPlus: (0.09 - price) * 100
        case .prize: 0
        }
    }

    /// The price range a bid may take: a share of the ceiling, or the fee rate on cost-plus work.
    static func clampPrice(_ type: ContractType, _ price: Double) -> Double {
        type == .costPlus ? clamp(price, 0.02, 0.15) : clamp(price, 0.6, 1.0)
    }

    /// Top Secret/SCI work goes only to labs an agency of the same government already trusts with classified work.
    static func topSecretBlocker(_ sol: Solicitation, _ s: GameState) -> String? {
        guard sol.level == .topSecret, let a = sol.agencyDef else { return nil }
        if trust(s, a.id) >= 1 { return nil }
        let peers = AgencyCatalog.all.filter { $0.region == a.region && $0.country == a.country && $0.id != a.id }
        if peers.contains(where: { trust(s, $0.id) >= 2 }) { return nil }
        return "Top Secret/SCI work goes to labs \(a.short) already trusts with classified work: deliver Secret work for it (or for another \(a.homeShort) agency) first (trust \(Fmt.trim(trust(s, a.id), 1)) of 1)"
    }

    /// Classified evaluations weigh what you did with the agency's discoveries: its trust, and a mark-down for a few
    /// years after you commercialised one.
    static func secrecyRecord(_ sol: Solicitation, _ s: GameState) -> Double {
        guard sol.level >= .secret else { return 0 }
        let penalty = (s.advanced.commercialised[sol.agency].map { $0 > s.date } ?? false) ? 4.0 : 0
        return 0.5 * trust(s, sol.agency) - penalty
    }

    /// Things that stop you bidding at all (and, at the close, an award).
    static func blockers(_ sol: Solicitation, _ s: GameState, plan: MobPlan? = nil) -> [String] {
        var out: [String] = []
        if let a = sol.agencyDef, !openToYou(sol, s) {
            out.append(sol.level == .unclassified ? "\(a.short) doesn't contract with labs from your country" : "\(sol.level.title) work for \(a.homeName) is open to its own labs only")
        }
        for id in missingResearch(sol, s) { out.append("Research \(ResearchCatalog.byID[id]?.name ?? id)") }
        if margin(sol, playerScores(s)) < -5 { out.append("Your best model is more than 5 points under the bars on average") }
        if let b = topSecretBlocker(sol, s) { out.append(b) }
        let plan = plan ?? mobilisationPlan(sol, s)
        if !plan.feasible {
            out.append("Can't mobilise in time: about \(Fmt.trim(plan.months, 1)) months to get the team, compute and facilities ready, and \(sol.agencyDef?.short ?? "the agency") allows \(Fmt.trim(max(0, plan.deadline), 1))")
        }
        return out
    }

    /// Your chance of winning at `price` (share of ceiling, or the fee rate for cost-plus), against the rivals who bid.
    static func odds(_ sol: Solicitation, _ s: GameState, price raw: Double) -> Odds {
        let price = clampPrice(sol.type, raw)
        var o = Odds()
        o.plan = mobilisationPlan(sol, s)
        o.blockers = blockers(sol, s, plan: o.plan)
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
        let secrecy = secrecyRecord(sol, s)
        if secrecy != 0 { o.parts.append(("Secrecy record", secrecy)) }
        let pref = homePreference(sol, s)
        if pref != 0 { o.parts.append(("Home-country preference", pref)) }
        o.score = o.parts.reduce(0) { $0 + $1.1 }
        o.rivals = rivalScores(sol, s).map { (CompetitorCatalog.def($0.lab).name, $0.score) }
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

    /// A rival picked by the agency's evaluation (weighted by exp(score ÷ 5), as your odds are).
    static func pickRival(_ scores: [(lab: String, score: Double)], _ u: Double) -> String? {
        guard !scores.isEmpty else { return nil }
        let w = scores.map { exp($0.score / 5) }
        var x = u * w.reduce(0, +)
        for (r, wi) in zip(scores, w) {
            if x < wi { return r.lab }
            x -= wi
        }
        return scores.last?.lab
    }

    /// Bids decided on the solicitation's closing date. Work you didn't bid on goes to a rival that did (if any).
    static func closeBids(_ s: inout GameState) {
        let today = s.date
        let due = s.advanced.solicitations.filter { $0.closes <= today }
        s.advanced.solicitations.removeAll { $0.closes <= today && $0.bid != nil }
        for sol in due {
            guard let bid = sol.bid else {
                if let lab = pickRival(rivalScores(sol, s), roll(s, "rivalaward|\(sol.id)")) { awardRival(&s, sol, lab: lab) }
                continue
            }
            let o = odds(sol, s, price: bid.price)
            let r = roll(s, "award|\(sol.id)")
            let agency = sol.agencyDef?.short ?? sol.agency
            let won = r < o.p
            let lab = won ? nil : pickRival(rivalScores(sol, s), roll(s, "winner|\(sol.id)"))
            let winner = won ? s.companyName : (lab.map { CompetitorCatalog.def($0).name } ?? "No award (the agency cancelled)")
            s.advanced.bids.insert(BidRecord(date: s.date, title: sol.title, agency: sol.agency, winner: winner, odds: o.p, won: won, price: bid.price), at: 0)
            if s.advanced.bids.count > 40 { s.advanced.bids.removeLast(s.advanced.bids.count - 40) }
            if won {
                award(&s, sol, bid: bid, margin: margin(sol, playerScores(s)))
                continue
            }
            if let lab { awardRival(&s, sol, lab: lab) }
            // A serious bid (20% odds or better) earns a little record with the agency, a point at most from lost bids.
            let credit = o.p >= 0.2 ? min(0.25, max(0, 1 - (s.advanced.lossCredit[sol.agency] ?? 0))) : 0
            if credit > 0 {
                s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) + credit, -10, 10)
                s.advanced.lossCredit[sol.agency, default: 0] += credit
            }
            let why = o.acceptable ? "your odds at the close were \(Fmt.pct(o.p, decimals: 0)); the roll was \(Fmt.trim(r, 2))" : "at the close: \(o.blockers.first ?? "not eligible")"
            Sim.news(&s, "\(agency) awards \(sol.title) to \(winner)",
                     "Your proposal lost (\(why)). The \(Fmt.money(bid.proposalCost)) bid cost is gone\(credit > 0 ? ", but \(agency) remembers a serious bid (record +\(Fmt.trim(credit, 2)))" : "").",
                     .company, good: false)
        }
    }

    /// A rival lab takes on a contract: it's paid as it works, and it can deliver late or default.
    static func awardRival(_ s: inout GameState, _ sol: Solicitation, lab: String) {
        guard let b = effectiveBidders(sol, s).first(where: { $0.lab == lab }) else { return }
        let value: Double
        switch sol.type {
        case .fixedPrice, .grant: value = sol.ceiling * b.price
        case .costPlus: value = sol.estCost * (1 + rivalPrice(.costPlus, b.price))
        case .prize: value = sol.ceiling
        }
        // A lab whose models clear the bars comfortably works faster.
        let fit = clamp(b.tech, -5, 10)
        let months = max(3, Int((Double(sol.months) * (0.95 + 0.5 * roll(s, "rivalpace|\(sol.id)") - 0.02 * fit)).rounded()))
        s.advanced.rivalProgrammes.append(RivalProgramme(lab: lab, agency: sol.agency, template: sol.template, title: sol.title, type: sol.type,
                                                         level: sol.classification, value: value, start: s.date, planned: months))
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
        if sol.type == .prize {
            // The fastest rival team, or — with no rival in the race — an outside team of universities and startups.
            if let best = effectiveBidders(sol, s).max(by: { $0.tech < $1.tech }) {
                let months = Double(sol.months) * (0.95 + 0.6 * roll(s, "rivalfinish|\(sol.id)")) - 0.03 * best.tech
                p.rivalFinish = GameCalendar.addDays(s.date, Int(max(4, months) * 30.4))
                p.rivalLab = best.lab
            } else {
                let months = Double(sol.months) * (1.3 + 0.6 * roll(s, "rivalfinish|\(sol.id)"))
                p.rivalFinish = GameCalendar.addDays(s.date, Int(months * 30.4))
                p.rivalLab = ""
            }
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
        for (k, n) in sol.staff.sorted(by: { $0.key < $1.key }) {
            guard let role = Role(rawValue: k) else { continue }
            let pool = s.employees.filter { $0.role == role && !s.advanced.seconded.contains($0.id) && clearanceLevel(s, $0.id) >= sol.classification }.count
            have += min(n, pool)
            need += n
        }
        return need > 0 ? Double(have) / Double(need) : 1
    }

    /// Usable cleared compute accredited at `level` or higher (suspended facilities don't count).
    static func computeCapacity(_ s: GameState, atLeast level: Int) -> Double {
        s.advanced.facilities.filter { $0.kind.isCompute && $0.level >= level && $0.isUsable(s.date) }.reduce(0) { $0 + $1.capacity }
    }

    // MARK: Programme spaces (engineering bays, confidential lab benches, certified enclaves)

    /// The accreditation a programme needs from its facility: its classification, CUI at least.
    static func spaceLevel(_ level: Classification) -> Int { max(1, level.rawValue) }

    /// Usable units of a kind accredited at `level` or higher (suspended ones don't count).
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
        s.advanced.facilities.filter { $0.kind == .secureLab && $0.level >= level && $0.isUsable(s.date) }.reduce(0) { $0 + $1.capacity }
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

    /// After a facility closes or is suspended: programmes keep only the cleared compute that's still there (oldest first).
    static func clampCompute(_ s: inout GameState) {
        for i in s.advanced.programmes.indices where s.advanced.programmes[i].status == .active && s.advanced.programmes[i].sol.level > .unclassified {
            let free = freeCompute(s, s.advanced.programmes[i].sol.level, excluding: s.advanced.programmes[i].id)
            s.advanced.programmes[i].compute = min(s.advanced.programmes[i].compute, free)
        }
    }

    // MARK: Mobilisation planner

    /// One thing that has to be in place before a programme can start, with how long it takes from today and its cost.
    struct MobStep: Hashable {
        var title: String
        var months: Double = 0
        var cost: Double = 0
        var done = false
    }

    /// The earliest a programme could mobilise if you started everything today, against the agency's deadline.
    struct MobPlan {
        var steps: [MobStep] = []
        /// Expected months from today until it can start (the slowest track).
        var months = 0.0
        /// If background investigations run slow (they take 75–125% of the usual time).
        var worst = 0.0
        /// Months from today the agency allows (to the close, then the mobilisation grace).
        var deadline = 99.0
        var feasible: Bool { months <= deadline + 0.05 }
        /// Feasible on the usual timings, but slow investigations would miss the deadline.
        var tight: Bool { feasible && worst > deadline + 0.05 }
        var cost: Double { steps.filter { !$0.done }.reduce(0) { $0 + $1.cost } }
    }

    /// Everything a solicitation (or an awarded programme still mobilising) needs before work can start: weight security,
    /// a cleared team role by role, desks in a secure lab, cleared compute, and the bay, bench or enclave its work needs
    /// (with the security officers that facility needs first). Tracks run in parallel; steps already under way count
    /// from where they are.
    static func mobilisationPlan(_ sol: Solicitation, _ s: GameState, programme: Programme? = nil) -> MobPlan {
        var plan = MobPlan()
        let today = s.date
        let L = sol.classification
        let level = sol.level
        func until(_ d: Date) -> Double { max(0, Double(GameCalendar.daysBetween(today, d)) / 30.4) }
        if let p = programme { plan.deadline = Double(mobilisationGrace(sol) - p.mobilisingMonths) }
        else { plan.deadline = until(sol.closes) + Double(mobilisationGrace(sol)) }
        var months = 0.0, worst = 0.0
        func add(_ step: MobStep, worst w: Double? = nil) {
            plan.steps.append(step)
            months = max(months, step.months)
            worst = max(worst, w ?? step.months)
        }
        let clearanceTime = clearanceMonths(L)
        // Weight security, one level at a time.
        if level > .unclassified {
            let need = level.requiredSL
            if s.security.rawValue >= need {
                add(MobStep(title: "Weight security SL\(need) (you have SL\(s.security.rawValue))", done: true))
            } else {
                var m = 0.0, cost = 0.0, cur = s.security.rawValue
                if s.securityTarget > cur { m += s.securityDaysLeft / 30.4; cur = s.securityTarget }
                while cur < need, let next = SecurityLevel(rawValue: cur + 1) {
                    m += Double(next.upgradeMonths)
                    cost += SecurityOps.upgradeCost(next, s)
                    cur += 1
                }
                add(MobStep(title: "Raise weight security to SL\(need) (SL\(s.security.rawValue) now\(s.securityTarget > s.security.rawValue ? ", an upgrade under way" : ""))", months: m, cost: cost))
            }
        }
        // The team: everyone it needs, cleared to the level (60% of them, every role covered, lets it start).
        let assigned = Set(programme?.staff ?? [])
        for (k, n) in sol.staff.sorted(by: { $0.key < $1.key }) {
            guard let role = Role(rawValue: k), n > 0 else { continue }
            let people = s.employees.filter { $0.role == role && (!s.advanced.seconded.contains($0.id) || assigned.contains($0.id)) }
            let ready = people.filter { clearanceLevel(s, $0.id) >= L }.count
            let name = n == 1 ? role.title.lowercased() : role.plural.lowercased()
            if ready >= n {
                add(MobStep(title: L == 0 ? "\(n) \(name) free" : "\(n) \(name) cleared \(level.clearance)", done: true))
                continue
            }
            var need = n - ready
            var m = 0.0, w = 0.0, cost = 0.0
            let records = people.compactMap { e in s.advanced.clearances.first { $0.employee == e.id } }
            let pending = records.filter { $0.ready != nil && $0.target >= L && !$0.renewal }.compactMap(\.ready).sorted()
            let fromPending = min(need, pending.count)
            if fromPending > 0 {
                m = until(pending[fromPending - 1])
                w = m
            }
            need -= fromPending
            let blocked = Set(records.filter { $0.ready != nil || ($0.deniedAt > 0 && $0.deniedAt <= L) }.map(\.employee))
            let candidates = people.filter { clearanceLevel(s, $0.id) < L && !blocked.contains($0.id) }.count
            let start = min(need, candidates)
            if start > 0 {
                m = max(m, clearanceTime)
                w = max(w, clearanceTime * 1.25)
                cost += Double(start) * clearanceCost(L, s.year)
            }
            let hire = need - start
            if hire > 0 {
                m = max(m, 1 + clearanceTime)
                w = max(w, 1 + clearanceTime * 1.25)
                cost += Double(hire) * clearanceCost(L, s.year)
            }
            var parts: [String] = []
            if ready > 0 { parts.append("\(ready) ready") }
            if fromPending > 0 { parts.append("\(fromPending) under investigation") }
            if start > 0 { parts.append("\(start) to put forward") }
            if hire > 0 { parts.append("\(hire) to hire\(L > 0 ? " and clear" : "")") }
            add(MobStep(title: "\(n) \(name)\(L > 0 ? " cleared \(level.clearance)" : ""): " + parts.joined(separator: ", "), months: m, cost: cost), worst: w)
        }
        if level > .unclassified {
            // Desks in a secure lab accredited at the level.
            let desks = freeSeats(s, level, excluding: programme?.id) + Double(programme?.staff.count ?? 0)
            let need = Double(sol.staffTotal)
            if desks >= need {
                add(MobStep(title: "\(Int(need)) desks in a secure lab (\(Fmt.int(Int(desks))) free)", done: true))
            } else if let f = pending(.secureLab, L, s, capacity: need - desks) {
                add(MobStep(title: "\(Int(need)) desks: \(f.name) is accredited \(f.ready.gameShort)", months: until(f.ready)))
            } else {
                let size = sizes(.secureLab, s.year).first { $0 >= need - desks } ?? sizes(.secureLab, s.year).last ?? 12
                let q = quote(.secureLab, level: L, capacity: size, s.year)
                add(MobStep(title: "Build a \(Fmt.int(Int(size)))-desk secure lab (\(facilityLevelName(L)))", months: q.months, cost: q.capex))
            }
            // Cleared compute (half of it lets the work start; all of it for full pace).
            let free = freeCompute(s, level, excluding: programme?.id) + (programme?.compute ?? 0)
            if free >= sol.computeH100e {
                add(MobStep(title: "\(Fmt.int(Int(sol.computeH100e))) H100e of cleared compute (\(Fmt.int(Int(free))) free)", done: true))
            } else if let f = pending(.restrictedCompute, L, s, capacity: sol.computeH100e - free) ?? pending(.clearedHall, L, s, capacity: sol.computeH100e - free) {
                add(MobStep(title: "\(Fmt.int(Int(sol.computeH100e))) H100e: \(f.name) is accredited \(f.ready.gameShort)", months: until(f.ready)))
            } else {
                let shortfall = sol.computeH100e - free
                let size = sizes(.restrictedCompute, s.year).first { $0 >= shortfall } ?? sizes(.restrictedCompute, s.year).last ?? 32
                let hall = quote(.clearedHall, level: L, capacity: size, s.year)
                let centre = quote(.restrictedCompute, level: L, capacity: size, s.year)
                let hallSite = sitesFor(.clearedHall, s, level: L).first { $0.capacityKW - Economy.siteLoadKW(s, $0.id) >= hall.kw }
                let centreSite = sitesFor(.restrictedCompute, s, level: L).first { $0.capacityKW - Economy.siteLoadKW(s, $0.id) >= centre.kw }
                if let site = hallSite {
                    add(MobStep(title: "Build a \(Fmt.int(Int(size))) H100e cleared hall at \(site.name)", months: hall.months, cost: hall.capex))
                } else if let site = centreSite {
                    add(MobStep(title: "Build a \(Fmt.int(Int(size))) H100e restricted compute centre at \(site.name)", months: centre.months, cost: centre.capex))
                } else {
                    add(MobStep(title: "Lease \(Fmt.watts(centre.kw * 1000)) of colocation in \(HQ.country(s).name) and build a \(Fmt.int(Int(size))) H100e restricted compute centre there",
                                months: 1 + centre.months, cost: centre.capex))
                }
            }
        }
        // The bay, bench or enclave the work needs, and the security officers that come first.
        if let kind = sol.templateDef?.facility {
            let sl = spaceLevel(level)
            let have = programme.map { hasSpace(s, $0) } ?? (facilityFree(s, kind, level: level) >= 1)
            if have {
                add(MobStep(title: "A \(kind.short) accredited \(facilityLevelName(sl))", done: true))
            } else if let f = pending(kind, sl, s, capacity: 1) {
                add(MobStep(title: "A \(kind.short): \(f.name) is accredited \(f.ready.gameShort)", months: until(f.ready)))
            } else {
                let q = quote(kind, level: sl, capacity: 1, s.year)
                let officers = officersNeeded(kind, level: sl)
                let cleared = s.employees.filter { clearanceLevel(s, $0.id) >= sl }.count
                let pendingOfficers = s.advanced.clearances.filter { $0.ready != nil && $0.target >= sl && !$0.renewal }.compactMap(\.ready).sorted()
                var lead = 0.0, leadWorst = 0.0
                if cleared < officers {
                    let short = officers - cleared
                    if pendingOfficers.count >= short {
                        lead = until(pendingOfficers[short - 1])
                        leadWorst = lead
                    } else {
                        lead = clearanceMonths(sl)
                        leadWorst = lead * 1.25
                    }
                }
                var labLead = 0.0
                if kind == .confidentialScience && labsFor(s, level: sl).isEmpty {
                    labLead = Double(ScienceCatalog.labs.map(\.buildDays).min() ?? 150) / 30.4
                }
                let start = max(lead, labLead)
                let what = kind == .confidentialScience && labLead > 0 ? " (after building a science lab)" : (lead > 0 ? " (after clearing \(officers) security officers to \(Classification(rawValue: sl)?.clearance ?? ""))" : "")
                add(MobStep(title: "Build a \(kind.short) (\(facilityLevelName(sl)))\(what)", months: start + q.months, cost: q.capex), worst: max(leadWorst, labLead) + q.months)
            }
        }
        plan.months = months
        plan.worst = worst
        return plan
    }

    /// A facility of `kind` at `level` or higher still being built, with room for `capacity` (the soonest).
    static func pending(_ kind: FacilityKind, _ level: Int, _ s: GameState, capacity: Double) -> SecureFacility? {
        s.advanced.facilities.filter { $0.kind == kind && $0.level >= max(1, level) && !$0.isReady(s.date) && $0.capacity >= capacity }
            .min { ($0.ready, $0.id.uuidString) < ($1.ready, $1.id.uuidString) }
    }

    // MARK: Pace

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
            // The team needs desks: a secure lab that's suspended or too small slows it.
            let desks = seatCapacity(s, atLeast: sol.classification)
            let seated = seatsAssigned(s, atLeast: sol.classification)
            if seated > desks {
                f.staffing *= max(0, desks) / max(1, seated)
                f.missing.append("Desks for \(Fmt.int(Int(seated - desks))) more cleared staff in a usable secure lab")
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

    /// Months of schedule used against the plan (the schedule runs from mobilisation), as a share of the planned length.
    static func scheduleRatio(_ p: Programme) -> Double { Double(p.months - p.mobilisingMonths) / Double(max(1, p.sol.months)) }

    /// How far behind plan the work is: schedule used minus work done (positive = behind). The engine's cure notices and
    /// the programme card both read this.
    static func slip(_ p: Programme) -> Double { p.stage == .award ? 0 : scheduleRatio(p) - p.completion }

    /// Planned months of a working stage.
    static func stageLength(_ sol: Solicitation, _ st: ProgrammeStage) -> Double { max(0.5, Double(sol.months) * st.workShare) }

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

    /// Fee paid so far on a cost-plus contract (milestones in stage order: fixed order for the float sum).
    static func feePaid(_ p: Programme) -> Double {
        p.paid.sorted().reduce(0.0) { acc, st in acc + p.fee * (milestones(.costPlus).first { $0.0.rawValue == st }?.1 ?? 0) }
    }

    /// Contract payments: booked as contract revenue.
    static func income(_ s: inout GameState, _ i: Int, _ amount: Double) {
        guard amount > 0 else { return }
        s.cash += amount
        s.month.revContracts += amount
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
        // A prize is over the day a competitor delivers.
        if sol.type == .prize, let r = p.rivalFinish, r <= s.date {
            terminate(&s, i, .lost, "\(rivalName(p.rivalLab)) delivered first")
            return
        }
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
                    let plan = mobilisationPlan(sol, s, programme: p)
                    alert(&s, "mobilise|\(p.id)", "\(sol.title) can't start",
                          "\(agency) expects work to begin. Missing: \(f.missing.prefix(3).joined(separator: ", ")). Earliest start about \(Fmt.trim(plan.months, 1)) months away; \(Fmt.trim(max(0, plan.deadline), 1)) left before termination.")
                }
            }
        }
        // Work.
        if p.stage >= .feasibility && p.stage <= .completion {
            p.stopWork = !f.security
            let rate = f.total
            workRate = rate
            let before = p.completion
            p.progress += rate / stageLength(sol, p.stage)
            while p.progress >= 1 && p.status == .active && p.stage <= .completion {
                s.advanced.programmes[i] = p
                if !finishStage(&s, i) { p = s.advanced.programmes[i]; break }
                p = s.advanced.programmes[i]
            }
            progressMonth = p.completion - before
        }
        revenueBefore = min(revenueBefore, p.revenue)

        // Costs: direct cash (materials, tests, compliance, cloud compute when unclassified) and allocated costs (your
        // staff's salaries, with the clearance premium, and facility running costs, already paid elsewhere but charged to
        // the contract). A quarter of direct spending is the standing team's overhead (it runs every month, so slips cost
        // money), three quarters follow the work actually done — rework included — at the stage it started in.
        let workDone = startStage >= .feasibility && startStage <= .completion ? workRate * startStage.intensity : 0
        let overhead = startStage == .award ? 0.05 : 0.25
        let direct = est.cash / Double(sol.months) * (overhead + 0.75 * workDone) * p.growth
        let team = s.employees.filter { p.staff.contains($0.id) }
        let salaries = team.reduce(0) { $0 + $1.salary * (1 + premiumRate(clearanceLevel(s, $1.id))) } / 12
        // Contracts reimburse pay only up to the allowable-compensation cap (about 1.5× the going salary for the role).
        let allowable = team.reduce(0) { $0 + min($1.salary * (1 + premiumRate(clearanceLevel(s, $1.id))), Macro.salary($1.role, s.year) * 1.5) } / 12
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
            let already = p.contractRevenue - feePaid(p)
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

        // Schedule (it runs from mobilisation; classified work gets longer to mobilise: clearances, accreditation).
        p = s.advanced.programmes[i]
        if p.status == .active {
            let ratio = scheduleRatio(p)
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
                else if let r = p.rivalFinish, r <= s.date { terminate(&s, i, .lost, "\(rivalName(p.rivalLab)) delivered first") }
                else if ratio > 2 { terminate(&s, i, .lapsed, "the challenge closed at twice its planned length") }
            }
        }
        // Budget cuts: an agency may end a programme for its own convenience — likelier when its government cools on you,
        // and much likelier when its budget has fallen below what it has committed.
        p = s.advanced.programmes[i]
        if p.status == .active && p.stage >= .feasibility && p.stage <= .testing, let a = sol.agencyDef {
            let over = max(0, obligations(a, s) / max(1, agencyBudget(a, s)) - 1)
            let chance = 0.002 * (1 + max(0, 45 - standing(s, a.region)) / 8) + 0.05 * min(1, over)
            if roll(s, "convenience|\(p.sol.id)|\(p.months)") < chance {
                terminate(&s, i, .cancelled, over > 0.02 ? "budget cuts at \(a.short) (its commitments run \(Fmt.pct(over, decimals: 0)) over this year's budget)" : "budget cuts at \(a.short)")
            }
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
                // Rework: back to 40% of the stage, and the fixes cost more than planned (more on riskier work).
                let growth = (0.03 + 0.05 * roll(s, "trialgrowth|\(p.sol.id)|\(stage.rawValue)|\(attempt)")) * p.sol.risk / 0.2
                p.trialGrowth += growth
                p.progress = 0.4
                let months = 0.6 * stageLength(p.sol, stage) / max(0.2, factors(p, s).total)
                let who: String
                switch p.sol.type {
                case .fixedPrice: who = "out of your margin"
                case .costPlus: who = "reimbursed up to the cost ceiling"
                case .grant, .prize: who = "yours to fund"
                }
                log(&p, s.date, "\(stage.title) failed (roll \(Fmt.trim(r, 2)) under \(Fmt.pct(odds, decimals: 0)) failure odds): back to rework. About \(Fmt.trim(months, 1)) months of extra work and +\(Fmt.pct(growth, decimals: 1)) cost growth (\(who)).", -1)
                s.advanced.programmes[i] = p
                return false
            }
            log(&p, s.date, "\(stage.title) passed (roll \(Fmt.trim(r, 2)) over \(Fmt.pct(odds, decimals: 0)) failure odds).", 1)
        } else {
            log(&p, s.date, "\(stage.title) complete.", 1)
        }
        if stage == .completion, p.sol.type == .prize, let rf = p.rivalFinish, rf <= s.date {
            s.advanced.programmes[i] = p
            terminate(&s, i, .lost, "\(rivalName(p.rivalLab)) delivered first")
            return false
        }
        let carry = max(0, p.progress - 1)
        p.progress = 0
        s.advanced.programmes[i] = p
        payMilestone(&s, i, stage)
        if stage == .completion {
            complete(&s, i)
            return false
        }
        let next = ProgrammeStage(rawValue: stage.rawValue + 1) ?? .completion
        s.advanced.programmes[i].stage = next
        // Work done past the end of a stage carries into the next, converted to the next stage's length.
        s.advanced.programmes[i].progress = carry * stageLength(p.sol, stage) / stageLength(p.sol, next)
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
        if sol.level >= .controlled { addTrust(&s, sol.agency, sol.level >= .secret ? (onTime ? 2 : 1.5) : 0.5) }
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
        // The research item and the moonshot results go over now — or, for classified work, once you've decided what
        // you may do with the discovery.
        if p.secrecy != .pending { handOver(&s, i) }
        offerFollowOn(&s, i)
        Sim.news(&s, "Programme delivered: \(sol.title)",
                 "\(a?.name ?? sol.agency) accepts the final deliverables. Contract P&L: \(signed(p.profit)) on \(Fmt.money(p.value))\(p.secrecy == .pending ? ". The work produced a discovery with commercial value — what you may do with it (and the research it hands over) is waiting in your inbox." : ".")",
                 .company, image: t?.image, important: true, good: true)
        alert(&s, "done|\(p.id)", "Delivered: \(sol.title)", "Contract P&L \(signed(p.profit)). Your record with \(a?.short ?? sol.agency) improves.", celebrate: true)
        if p.secrecy == .pending { askSecrecy(&s, i) }
    }

    /// The research item a programme hands over and the push it gives moonshots in its field. Classified work waits for
    /// the secrecy decision (only commercial use or retaining it internally releases them); government-owned IP, or
    /// internal-only use, never opens a product line, and government IP credits only 40% of the research.
    static func handOver(_ s: inout GameState, _ i: Int) {
        let p = s.advanced.programmes[i]
        guard !p.handedOver, let t = p.template else { return }
        s.advanced.programmes[i].handedOver = true
        let internalOnly = p.secrecy == .retained
        let govIP = p.sol.ip == .government
        if let u = t.unlock, !s.researched.contains(u), let item = ResearchCatalog.byID[u] {
            let product = item.effects.contains { if case .product = $0 { true } else { false } }
            let share: Double = product && (govIP || internalOnly) ? 0 : (govIP || internalOnly ? 0.4 : 1)
            if share >= 1 {
                s.researchProgress[u] = max(s.researchProgress[u] ?? 0, Sim.researchCost(item, year: s.year))
                s.researchQueue.removeAll { $0 == u }
                s.researchQueue.insert(u, at: 0)
                log(&s.advanced.programmes[i], s.date, "Hands you \(item.name): fully credited and first in your research queue.", 1)
            } else if share > 0 {
                s.researchProgress[u] = max(s.researchProgress[u] ?? 0, Sim.researchCost(item, year: s.year) * share)
                log(&s.advanced.programmes[i], s.date, "\(govIP ? "Government-owned IP" : "Internal use only"): \(Fmt.pct(share, decimals: 0)) of \(item.name) credited to your research.", 1)
            } else {
                log(&s.advanced.programmes[i], s.date, "\(item.name) stays with the government: \(govIP ? "it owns the IP" : "internal-only use"), and it would open a product line.", 0)
            }
        }
        // Moonshots in the same field get a push from what the team learned (once: older saves may have had it already).
        if let field = t.field, !p.history.contains(where: { $0.text.hasPrefix("Shared results with your") }) {
            let push = internalOnly ? 0.06 : 0.12
            for j in s.moonshots.indices where s.moonshots[j].status == .running && s.moonshots[j].def?.field == field {
                s.moonshots[j].rpInvested += push * s.moonshots[j].rpTarget
                log(&s.advanced.programmes[i], s.date, "Shared results with your \(s.moonshots[j].def?.name ?? "moonshot") team (+\(Int(push * 100))% of its research plan).", 1)
            }
        }
    }

    /// Follow-on work for a good performer: a seedling leads to Phase II of the programme it scouted; a programme to its
    /// next phase. The classification rises one level at most, and classified agencies weigh their trust in you.
    static func offerFollowOn(_ s: inout GameState, _ i: Int) {
        let p = s.advanced.programmes[i]
        let sol = p.sol
        guard let a = sol.agencyDef, let t = sol.templateDef, rating(s, a.id) >= 1 else { return }
        var next = t
        if t.id == "seedling" {
            if let target = AgencyCatalog.templateByID[sol.target] {
                next = target
            } else {
                // Older seedlings without a subject: one of the agency's programmes no more than one level up.
                let options = AgencyCatalog.templates.filter { $0.agencies.contains(a.id) && $0.id != "seedling" && $0.year <= s.year && $0.classification <= sol.classification + 1 }
                guard !options.isEmpty else { return }
                next = options[min(options.count - 1, Int(roll(s, "followpick|\(sol.id)") * Double(options.count)))]
            }
        }
        let level = min(next.classification, sol.classification + 1)
        let odds = clamp(0.5 + 0.04 * rating(s, a.id) + (level >= Classification.secret.rawValue ? 0.06 * trust(s, a.id) : 0), 0.15, 0.9)
        let r = roll(s, "followon|\(sol.id)")
        guard r < odds else {
            log(&s.advanced.programmes[i], s.date, "No follow-on from \(a.short) this time (roll \(Fmt.trim(r, 2)) over \(Fmt.pct(odds, decimals: 0)) odds).")
            return
        }
        let phase = max(sol.phase, 1) + 1
        let f = make(next, a, s, key: "follow|\(p.id)", followOn: true, scale: t.id == "seedling" ? 1 : 1.2, level: level, phase: phase)
        guard f.ceiling >= 1e5 else {
            log(&s.advanced.programmes[i], s.date, "\(a.short) would follow on, but it has no budget left this year.")
            return
        }
        s.advanced.counter += 1
        s.advanced.solicitations.append(f)
        s.advanced.programmes[i].sol.phase = max(1, sol.phase)
        log(&s.advanced.programmes[i], s.date, "\(a.short) invites you to bid on follow-on work: \(f.title) (\(f.level.title)).", 1)
    }

    /// Excess re-procurement costs the agency charges on a termination for default: 3% of the contract.
    static func reprocurement(_ p: Programme) -> Double { ((p.sol.type == .costPlus ? p.sol.estCost : p.value) * 0.03 / 1000).rounded() * 1000 }

    /// What walking away would cost today under the contract's terms: progress payments or unearned fee back plus
    /// re-procurement costs (contracts), unspent money returned (grants), nothing but the work (prizes).
    static func walkAwayCost(_ p: Programme) -> Double {
        switch p.sol.type {
        case .fixedPrice: return p.contractRevenue * 0.2 + reprocurement(p)
        case .costPlus: return max(0, feePaid(p) - p.fee * p.completion) + reprocurement(p)
        case .grant: return max(0, min(p.contractRevenue, p.contractRevenue - p.direct - p.allocated))
        case .prize: return 0
        }
    }

    static func terminate(_ s: inout GameState, _ i: Int, _ status: ProgrammeStatus, _ why: String) {
        var p = s.advanced.programmes[i]
        let sol = p.sol
        let agency = sol.agencyDef?.short ?? sol.agency
        p.status = status
        p.ended = s.date
        // Partial know-how from unfinished work, in proportion to what was done — none at all from classified work.
        let share = sol.level >= .secret ? 0 : sol.ip.commercialShare * p.completion
        switch status {
        case .terminated:
            // The agency recovers unliquidated progress payments (fixed-price) or fee not yet earned (cost-plus), and
            // charges the excess cost of re-procuring the work (3% of the contract).
            let reprocure = reprocurement(p)
            let recovered = sol.type == .costPlus ? max(0, feePaid(p) - p.fee * p.completion) : p.contractRevenue * 0.2
            let back = recovered + reprocure
            s.cash -= back
            s.month.costOther += back
            p.disallowed += back
            s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) - 4, -10, 10)
            if sol.level >= .controlled { addTrust(&s, sol.agency, sol.level >= .secret ? -2 : -1) }
            if let r = sol.agencyDef?.region { Stakeholders.move(&s, [r.rawValue: -3], "\(agency) terminated \(sol.title) for default") }
            let what = sol.type == .costPlus ? "unearned fee" : "progress payments"
            log(&p, s.date, "Terminated for default: \(why). \(Fmt.money(back)) repaid (\(Fmt.money(recovered)) of \(what), \(Fmt.money(reprocure)) of re-procurement costs).", -1)
            p.effectScale = 0.15 * share
        case .cancelled:
            // Termination for convenience: costs to date plus a settlement.
            let settle = sol.type == .fixedPrice ? max(0, p.direct * 1.1 - p.contractRevenue) : (sol.type == .costPlus ? p.fee * 0.3 : 0)
            s.advanced.programmes[i] = p
            income(&s, i, settle)
            p = s.advanced.programmes[i]
            log(&p, s.date, "Terminated for convenience: \(why). Settlement \(Fmt.money(settle)).", -1)
            p.effectScale = 0.3 * share
        case .lapsed:
            // Grant money not yet spent on the work goes back.
            let back = sol.type == .grant ? max(0, min(p.contractRevenue, p.contractRevenue - p.direct - p.allocated)) : 0
            s.cash -= back
            s.month.costOther += back
            p.disallowed += back
            s.advanced.ratings[sol.agency] = clamp(rating(s, sol.agency) - 1.5, -10, 10)
            log(&p, s.date, "Lapsed: \(why).\(back > 0 ? " \(Fmt.money(back)) of unspent grant money returned." : "")", -1)
            p.effectScale = 0
        case .lost:
            let consolation = p.value * 0.1 * (p.completion >= 0.6 ? 1 : 0)
            s.advanced.programmes[i] = p
            income(&s, i, consolation)
            p = s.advanced.programmes[i]
            p.effectScale = 0.5 * share
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

    /// Estimate at completion for a running programme: cost to date plus the remaining work at the cost rate seen so far
    /// (blended with the plan early on), the revenue the contract will bring, and the margin that leaves.
    struct EAC {
        var costToDate = 0.0
        var atCompletion = 0.0
        var revenue = 0.0
        var margin: Double { revenue - atCompletion }
        /// Cost growth found so far (what the work turned out to need, as it's discovered, plus rework).
        var growthSoFar = 0.0
    }

    static func eac(_ p: Programme, _ s: GameState) -> EAC {
        var e = EAC()
        let est = estimate(p.sol)
        e.costToDate = p.direct + p.allocated + p.proposalCost + p.disallowed
        let done = p.completion
        let plan = est.total * p.growth
        let rate = done > 0.02 ? (p.direct + p.allocated) / done : plan
        let w = min(1, done / 0.3)
        let perUnit = w * rate + (1 - w) * plan
        e.atCompletion = e.costToDate + (1 - done) * perUnit
        switch p.sol.type {
        case .fixedPrice, .grant, .prize: e.revenue = p.value + p.royalties
        case .costPlus:
            let billable = min(p.sol.estCost * 1.25, (p.contractRevenue - feePaid(p)) + (1 - done) * perUnit * 0.95)
            e.revenue = billable + p.fee + p.royalties
        }
        e.growthSoFar = (p.costGrowth - 1) * min(1, 2 * done) + p.trialGrowth
        return e
    }

    // MARK: Facilities: power, officers, running costs

    /// Power a facility draws at full use (kW): fixed when it was built (worked out from its kind and size for older saves).
    static func facilityKW(_ f: SecureFacility) -> Double {
        if f.kw > 0 { return f.kw }
        return quote(f.kind, level: f.level, capacity: f.capacity, GameCalendar.decimalYear(f.started)).kw
    }

    /// Facilities inside a site's power envelope: compute halls and centres always, workshops, benches and enclaves when
    /// the site is a datacenter or colocation site. `Economy.siteLoadKW` counts these (from the start of construction, as
    /// it does ordered chips), so their kW can't also be filled with GPUs.
    static func siteFacilityKW(_ s: GameState, site: UUID) -> Double {
        guard !s.advanced.facilities.isEmpty, let st = s.sites.first(where: { $0.id == site }) else { return 0 }
        let dc = st.kind == .datacenter || st.kind == .colo
        return s.advanced.facilities.filter { $0.siteID == site && ($0.kind.isCompute || dc) }.reduce(0) { $0 + facilityKW($1) }
    }

    /// Share of a ready facility in use (compute assigned, bays or benches taken), which sets its power draw.
    static func utilisation(_ f: SecureFacility, _ s: GameState) -> Double {
        if f.kind.isCompute {
            let cap = computeCapacity(s, atLeast: 1)
            return cap > 0 ? min(1, computeAssigned(s, atLeast: 1) / cap) : 0
        }
        if f.kind.isProgrammeSpace {
            let cap = spaceCapacity(s, f.kind, atLeast: 1)
            return cap > 0 ? min(1, Double(spaceUsers(s, f.kind, atLeast: 1).count) / cap) : 0
        }
        return 0
    }

    /// Facility draw at each datacenter or colocation site (kW at the meter, PUE included), for purchase agreements.
    static func facilityDraw(_ s: GameState) -> [UUID: Double] {
        var out: [UUID: Double] = [:]
        for f in s.advanced.facilities where f.isReady(s.date) {
            guard let id = f.siteID, let site = s.sites.first(where: { $0.id == id }), site.isReady(s.date),
                  site.kind == .datacenter || site.kind == .colo else { continue }
            out[id, default: 0] += facilityKW(f) * (0.35 + 0.65 * utilisation(f, s)) * site.pue
        }
        return out
    }

    /// The day's power bill for your facilities (Sim.dailyCosts adds it to the power line): each draws at its site's
    /// price, PUE and grid premium; a confidential lab annex at its city's industrial price.
    static func facilityPowerDay(_ s: GameState) -> Double {
        guard !s.advanced.facilities.isEmpty else { return 0 }
        let grid = Power.gridMultiplier(s)
        var total = 0.0
        for f in s.advanced.facilities where f.isReady(s.date) {
            let draw = facilityKW(f) * (0.35 + 0.65 * utilisation(f, s))
            guard draw > 0 else { continue }
            if let id = f.siteID, let site = s.sites.first(where: { $0.id == id }) {
                total += draw * site.pue * 24 * site.powerPrice * (site.kind == .colo || site.kind == .datacenter ? grid : 1)
                    * Nations.powerFactor(s, location: site.locationID)
            } else if !f.labSite.isEmpty {
                total += draw * 1.3 * 24 * CountryCatalog.get(Science.site(f.labSite).country).power
            }
        }
        return total
    }

    /// Cleared people a ready facility needs as security officers: one for a lab or compute facility, more for bays,
    /// benches and enclaves.
    static func officersRequired(_ kind: FacilityKind, level: Int) -> Int { kind.isProgrammeSpace ? officersNeeded(kind, level: level) : 1 }

    /// Monthly: a facility without enough cleared security officers, or a lab annex whose science lab closed, is
    /// suspended until that's fixed (officers are counted across facilities, highest accreditation first).
    static func checkFacilities(_ s: inout GameState) {
        guard !s.advanced.facilities.isEmpty else { return }
        var pool = [0, 0, 0, 0]
        for e in s.employees {
            let l = clamp(clearanceLevel(s, e.id), 0, 3)
            if l > 0 { pool[l] += 1 }
        }
        let labSites = Set(s.science.labs.filter { $0.isReady(s.date) }.map(\.site))
        let order = s.advanced.facilities.indices.filter { s.advanced.facilities[$0].isReady(s.date) }.sorted {
            let a = s.advanced.facilities[$0], b = s.advanced.facilities[$1]
            return (-a.level, a.started, a.id.uuidString) < (-b.level, b.started, b.id.uuidString)
        }
        var changed = false
        for i in order {
            let f = s.advanced.facilities[i]
            var why = ""
            if f.kind == .confidentialScience {
                let tied = f.labSite.isEmpty ? !labSites.isEmpty : labSites.contains(f.labSite)
                if !tied { why = "The science lab it annexes has closed" }
            }
            var need = officersRequired(f.kind, level: f.level)
            var take = pool
            var l = clamp(f.level, 1, 3)
            while need > 0 && l <= 3 {
                let k = min(need, take[l])
                take[l] -= k
                need -= k
                l += 1
            }
            if need > 0 {
                if why.isEmpty { why = "No cleared security officer: it needs \(officersRequired(f.kind, level: f.level)) staff cleared \(Classification(rawValue: f.level)?.clearance ?? "") or higher" }
            } else {
                pool = take
            }
            guard why != f.suspension else { continue }
            s.advanced.facilities[i].suspension = why
            changed = true
            if why.isEmpty {
                Sim.news(&s, "\(f.name) back in use", "Its accreditation is restored.", .company, image: f.kind.image, good: true)
            } else {
                Sim.news(&s, "\(f.name) suspended", "\(why). Programmes that need it lose its desks, compute or bay until that's fixed.", .company, image: f.kind.image, good: false)
                alert(&s, "suspended|\(f.id)", "\(f.name) suspended", why + ".")
            }
        }
        if changed { clampCompute(&s) }
    }

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
            s.advanced.programmes[i].royalties += r
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
            addTrust(&s, p.sol.agency, -1)
            if let r = p.sol.agencyDef?.region { Stakeholders.move(&s, [r.rawValue: -2], "A paper from your lab touched classified work") }
            log(&s.advanced.programmes[i], s.date, "Security review: a paper under your open-science policy came too close to classified results. Record −2, trust −1.", -1)
            alert(&s, "leak|\(p.id)", "Disclosure finding on \(p.sol.title)", "Open-science publishing and Secret work don't mix: consider a selective publication policy.")
        }
    }

    /// Keep the set of seconded employees (who don't work for the rest of the company) in step with the programmes; drop
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
            if let sw = s.advanced.programmes[i].swarm, !s.swarms.contains(where: { $0.id == sw }) { s.advanced.programmes[i].swarm = nil }
            on.formUnion(s.advanced.programmes[i].staff)
        }
        s.advanced.seconded = on
        s.advanced.clearances.removeAll { !ids.contains($0.employee) }
    }

    /// Whether a swarm is seconded to a running programme (it works for the programme, not its own mission).
    static func swarmSeconded(_ s: GameState, _ id: UUID) -> Bool {
        s.advanced.programmes.contains { $0.status == .active && $0.swarm == id }
    }

    /// Old finished programmes drop out of the active list after a while (their effects stay).
    static func afterProgrammes(_ s: inout GameState) {
        let cutoff = GameCalendar.addMonths(s.date, -60)
        let today = s.date
        s.advanced.programmes.removeAll { $0.status != .active && $0.effectScale <= 0 && $0.royaltyMonthsLeft <= 0 && $0.secrecy != .pending && $0.secrecy != .denied && ($0.ended ?? today) < cutoff }
        // Secrecy processes that finish this month.
        for i in s.advanced.programmes.indices {
            guard let until = s.advanced.programmes[i].secrecyUntil, until <= s.date else { continue }
            finishSecrecy(&s, i)
        }
    }

    // MARK: Rival labs' contracts

    /// Monthly: rival labs work on the contracts they won. The agency pays as the work goes; the lab keeps its margin (12%,
    /// into its cash and so its compute); a lab in distress, in turmoil or out of business can default; delivered work
    /// builds its record with the agency and a little domain know-how (Capabilities.rivalDomains).
    static func rivalWork(_ s: inout GameState) {
        guard !s.advanced.rivalProgrammes.isEmpty else { return }
        let ym = s.date.ym
        for i in s.advanced.rivalProgrammes.indices where s.advanced.rivalProgrammes[i].active {
            var r = s.advanced.rivalProgrammes[i]
            let key = "\(r.agency)|\(r.lab)"
            let agency = AgencyCatalog.byID[r.agency]?.short ?? r.agency
            r.months += 1
            guard let ci = s.competitors.firstIndex(where: { $0.id == r.lab }), s.competitors[ci].alive else {
                r.status = "terminated"
                r.ended = s.date
                s.advanced.rivalRatings[key] = clamp((s.advanced.rivalRatings[key] ?? 0) - 4, -10, 10)
                s.advanced.rivalProgrammes[i] = r
                continue
            }
            let c = s.competitors[ci]
            let prize = r.type == .prize
            if !prize {
                r.paid += r.monthly
                if RivalEconomy.parent(c, s) == nil { s.competitors[ci].cash += r.monthly * 0.12 }
            }
            let risk = AgencyCatalog.templateByID[r.template]?.risk ?? 0.2
            let over = AgencyCatalog.byID[r.agency].map { max(0, obligations($0, s) / max(1, agencyBudget($0, s)) - 1) } ?? 0
            let hazard = 0.002 + 0.01 * risk + (c.distressMonths > 0 ? 0.03 : 0) + 0.01 * min(1, c.turmoil / 50) + 0.05 * min(1, over)
            if roll(s, "rivaldefault|\(r.id.uuidString)|\(ym.year)-\(ym.month)") < hazard {
                r.status = "terminated"
                r.ended = s.date
                s.advanced.rivalRatings[key] = clamp((s.advanced.rivalRatings[key] ?? 0) - 4, -10, 10)
                if s.advanced.engaged {
                    Sim.news(&s, "\(agency) ends \(c.def.name)'s contract", "\(r.title) is terminated\(over > 0.02 ? " in a round of budget cuts" : " for default") after \(r.months) months.", .competitor, good: true)
                }
            } else if r.months >= r.planned {
                r.status = "completed"
                r.ended = s.date
                if prize {
                    r.paid = r.value
                    if RivalEconomy.parent(c, s) == nil { s.competitors[ci].cash += r.value * 0.5 }
                }
                s.advanced.rivalRatings[key] = clamp((s.advanced.rivalRatings[key] ?? 0) + 2.5, -10, 10)
                if s.advanced.engaged {
                    Sim.news(&s, "\(c.def.name) delivers \(r.title)", "\(agency) accepts the work (\(Fmt.money(r.value))). Its record with \(agency) improves.", .competitor)
                }
            }
            s.advanced.rivalProgrammes[i] = r
        }
        // Keep what's running and the last eight years of finished contracts (their know-how stays with the labs).
        let cutoff = GameCalendar.addMonths(s.date, -96)
        let today = s.date
        s.advanced.rivalProgrammes.removeAll { !$0.active && ($0.ended ?? today) < cutoff }
    }

    /// Domain know-how a rival lab carries from contracts it delivered (half a programme's domain effects, once per kind
    /// of programme): Capabilities.rivalDomains adds it to the lab's next models.
    static func rivalDomainEffects(_ s: GameState, lab: String) -> [(CapDomain, Double)] {
        guard !s.advanced.rivalProgrammes.isEmpty else { return [] }
        let kinds = Set(s.advanced.rivalProgrammes.filter { $0.lab == lab && $0.status == "completed" }.map(\.template))
        var out: [(CapDomain, Double)] = []
        for id in kinds.sorted() {
            guard let t = AgencyCatalog.templateByID[id] else { continue }
            for e in t.effects { if case .domain(let d, let v) = e { out.append((d, v * 0.5)) } }
        }
        return out
    }

    // MARK: Daily

    /// Facilities finishing construction and clearances finishing investigation (only when there are any).
    static func daily(_ s: inout GameState) {
        guard !s.advanced.facilities.isEmpty || !s.advanced.clearances.isEmpty else { return }
        let today = s.date
        let yesterday = GameCalendar.addDays(today, -1)
        for f in s.advanced.facilities where f.ready > yesterday && f.ready <= today {
            Sim.news(&s, "\(f.name) accredited", "Your \(f.kind.title.lowercased()) (\(facilityLevelName(f.level))) is ready: \(Fmt.int(Int(f.capacity))) \(f.kind.unit). It needs \(officersRequired(f.kind, level: f.level)) cleared security officer\(officersRequired(f.kind, level: f.level) == 1 ? "" : "s") to stay in use.",
                     .company, image: f.kind.image, good: true)
        }
        for i in s.advanced.clearances.indices {
            guard let ready = s.advanced.clearances[i].ready, ready <= today else { continue }
            var c = s.advanced.clearances[i]
            let name = s.employees.first { $0.id == c.employee }?.name ?? "An employee"
            c.ready = nil
            c.started = nil
            if c.renewal {
                // Periodic reinvestigation: almost always renewed; now and then something has changed.
                c.renewal = false
                let year = GameCalendar.components(today).year
                if roll(s, "renew|\(c.employee.uuidString)|\(year)") < [0, 0.02, 0.04, 0.06][clamp(c.level, 0, 3)] {
                    let lost = c.level
                    c.deniedAt = lost
                    c.level = lost - 1
                    c.target = c.level
                    c.granted = c.level > 0 ? today : nil
                    Sim.news(&s, "Clearance withdrawn: \(name)", "The five-yearly reinvestigation turned up something new. \(name) no longer holds a \(Classification(rawValue: lost)?.clearance ?? "") clearance.", .company, good: false)
                } else {
                    c.granted = today
                }
            } else if !clearable(s, c.employee, c.target) {
                c.deniedAt = c.target
                c.target = c.level
                Sim.news(&s, "Clearance denied: \(name)", "The background investigation turned up something (foreign ties, finances or past conduct). \(name) can't be cleared to \(Classification(rawValue: c.deniedAt)?.clearance ?? "that level").", .company, good: false)
            } else {
                c.level = c.target
                c.granted = today
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

    /// Pay premium cleared staff command (public trust 3%, Secret 8%, TS/SCI 12%): defence contractors bid for them.
    static func premiumRate(_ level: Int) -> Double { [0, 0.03, 0.08, 0.12][clamp(level, 0, 3)] }

    /// How much likelier a cleared employee is to be poached (People.monthly multiplies their risk).
    static func poachFactor(_ s: GameState, _ id: UUID) -> Double {
        guard !s.advanced.clearances.isEmpty else { return 1 }
        return [1, 1.15, 1.3, 1.45][clamp(clearanceLevel(s, id), 0, 3)]
    }

    /// Some people can't be cleared: a hashed trait of the person, worse at higher levels.
    static func clearable(_ s: GameState, _ id: UUID, _ level: Int) -> Bool {
        roll(s, "clearable|\(id.uuidString)") >= [0, 0.03, 0.08, 0.15][clamp(level, 0, 3)]
    }

    /// Monthly: cleared staff are paid their premium, and every clearance is reinvestigated five years after it was granted
    /// (40% of the first investigation's cost, about half its time; the clearance stays valid meanwhile).
    static func clearanceUpkeep(_ s: inout GameState) {
        guard !s.advanced.clearances.isEmpty else {
            s.advanced.lastPremium = 0
            return
        }
        let pay = Dictionary(uniqueKeysWithValues: s.employees.map { ($0.id, $0.salary) })
        var premium = 0.0
        for i in s.advanced.clearances.indices {
            var c = s.advanced.clearances[i]
            guard c.level > 0 else { continue }
            if c.granted == nil { c.granted = s.date }   // older saves: the five-year clock starts now
            premium += (pay[c.employee] ?? 0) * premiumRate(c.level) / 12
            if c.ready == nil, let g = c.granted, GameCalendar.addMonths(g, 60) <= s.date {
                let cost = clearanceCost(c.level, s.year) * 0.4
                s.cash -= cost
                s.month.costOther += cost
                c.cost += cost
                c.target = c.level
                c.renewal = true
                c.started = s.date
                let months = clearanceMonths(c.level) * 0.5 * (0.75 + 0.5 * roll(s, "renewtime|\(c.employee.uuidString)|\(s.date.ym.year)"))
                c.ready = GameCalendar.addDays(s.date, Int(months * 30.4))
            }
            s.advanced.clearances[i] = c
        }
        if premium > 0 {
            s.cash -= premium
            s.month.costPayroll += premium
        }
        s.advanced.lastPremium = premium
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

    /// Build cost, upkeep (without power: that's on the power bill, at the site's price), accreditation time and power draw.
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
            q.opex = q.capex * 0.012 * levelPremium[l]
            q.months = [5, 8, 12][l]
        case .confidentialScience:
            q.capex = capacity * [4e6, 9e6, 18e6][l] * era
            q.kw = capacity * 250
            q.opex = q.capex * 0.015 * levelPremium[l]
            q.months = [4, 7, 11][l]
        case .certified:
            // Certified networks, enclaves and key management, plus the yearly audit.
            q.capex = capacity * [2.5e6, 6e6, 14e6][l] * era
            q.kw = capacity * 60
            q.opex = q.capex * 0.02 * levelPremium[l]
            q.months = [6, 9, 14][l]
        }
        q.months /= Campus.speedup(y)
        return q
    }

    /// Running-cost premium by accreditation level for the programme spaces (guards, inspections, separate networks).
    static let levelPremium = [1.0, 1.3, 1.7]

    /// People who must hold a clearance at the facility's level before you build a bay, bench or enclave (facility
    /// security officers). Every facility needs at least one cleared officer once it's accredited (`officersRequired`).
    static func officersNeeded(_ kind: FacilityKind, level: Int) -> Int { kind.isProgrammeSpace ? clamp(level, 1, 3) + 1 : 0 }

    /// What stops you building a facility kind (other than money and a site).
    static func facilityBlockers(_ kind: FacilityKind, level: Int, _ s: GameState) -> [String] {
        var out: [String] = []
        let need = officersNeeded(kind, level: level)
        let have = s.employees.filter { clearanceLevel(s, $0.id) >= level }.count
        if have < need { out.append("\(need) staff cleared \(Classification(rawValue: level)?.clearance ?? "") to run it (you have \(have))") }
        switch kind {
        case .confidentialScience:
            if labsFor(s, level: level).isEmpty {
                out.append(s.science.labs.isEmpty ? "A science lab to annex it to" : "A science lab in \(level >= 2 ? HQ.country(s).name : "an allied country") to annex it to")
            }
        case .certified:
            if seatCapacity(s, atLeast: level) < 1 && !s.advanced.facilities.contains(where: { $0.kind == .secureLab && $0.level >= level }) {
                out.append("A secure lab accredited \(facilityLevelName(level)) or higher")
            }
        default: break
        }
        return out
    }

    /// Sites a facility kind can go on at this accreditation (ready, the right kind, and in a jurisdiction that allows it).
    static func sitesFor(_ kind: FacilityKind, _ s: GameState, level: Int = 1) -> [Site] {
        s.sites.filter { site in
            guard site.isReady(s.date), sitingBlocker(site, level: level, s) == nil else { return false }
            switch kind {
            case .secureLab: return site.kind != .garage
            case .restrictedCompute: return site.kind == .colo || site.kind == .datacenter
            case .clearedHall: return site.kind == .datacenter
            case .engineering, .certified: return site.kind != .garage
            case .confidentialScience: return false
            }
        }
    }

    /// Science labs a confidential annex can be added to at this accreditation (Secret and up: labs in your home country).
    static func labsFor(_ s: GameState, level: Int) -> [SciLab] {
        let home = homeCountry(s)
        let allied = ["us", "ca", "is", "dk", "fr", "it", "ro", "gb", "uk", "de", "nl", "se", "jp", "kr"]
        return s.science.labs.filter { lab in
            guard lab.isReady(s.date) else { return false }
            let country = Science.site(lab.site).country
            return level >= 2 ? country == home : (country == home || allied.contains(country))
        }
    }

    // MARK: Restrictions on publication

    /// Secret or Top Secret work running in a science field: your labs may not publish in it (nil if they may).
    static func publicationBlock(_ s: GameState, _ field: SciField) -> String? {
        guard let p = s.advanced.programmes.first(where: { $0.status == .active && $0.sol.level >= .secret && $0.template?.sciField == field }) else { return nil }
        return "\(p.sol.title) (\(p.sol.level.title)) is running in this field: nothing in it can be published until it ends"
    }

    /// Whether a science paper must wait (Science.publish asks before it submits): blocked while Secret work runs in its
    /// field, or held 3–6 months for pre-publication review while controlled work does (the review starts the first time
    /// it's asked, and once cleared the paper goes).
    static func paperHeld(_ s: inout GameState, key: String, field: SciField) -> Bool {
        if publicationBlock(s, field) != nil { return true }
        if let until = s.advanced.reviews[key] { return until > s.date }
        guard let p = s.advanced.programmes.first(where: { $0.status == .active && $0.sol.level == .controlled && $0.template?.sciField == field }) else { return false }
        let until = GameCalendar.addMonths(s.date, 3 + Int(roll(s, "prepub|\(key)") * 4))
        s.advanced.reviews[key] = until
        Sim.news(&s, "Paper held for pre-publication review", "Because \(p.sol.title) (controlled) runs in the same field, \(p.sol.agencyDef?.short ?? "the agency") reviews the paper before it goes out: cleared by \(until.gameShort).", .research)
        return true
    }

    /// Monthly: papers from controlled programmes that finished pre-publication review are published.
    static func reviewPapers(_ s: inout GameState) {
        for k in s.advanced.discoveries.indices {
            guard let until = s.advanced.discoveries[k].reviewUntil, until <= s.date, !s.advanced.discoveries[k].published else { continue }
            s.advanced.discoveries[k].published = true
            s.advanced.discoveries[k].reviewUntil = nil
            let d = s.advanced.discoveries[k]
            if let t = AgencyCatalog.templateByID[d.template], let f = t.sciField { Science.bumpMomentum(&s, f, 0.01) }
            if let i = s.advanced.programmes.firstIndex(where: { $0.id == d.programme }) {
                log(&s.advanced.programmes[i], s.date, "Pre-publication review cleared: the paper on \(d.title) is published.", 1)
            }
        }
    }

    // MARK: Secrecy

    /// The six answers to a classified discovery (codes), and what each says.
    static func secrecyOption(_ code: Int, _ s: GameState, _ p: Programme, afterDenial: Bool) -> DecisionOption {
        let agency = p.sol.agencyDef?.short ?? "The agency"
        switch code {
        case 1: return DecisionOption(label: "Seek civilian-use approval", detail: "4–9 months of review. \(Fmt.pct(approvalOdds(s, p), decimals: 0)) odds at your standing; if approved you use it in full. If denied, you can still retain it or license the permitted parts.")
        case 2: return DecisionOption(label: "Rebuild it clean-room", detail: "\(Fmt.money(cleanRoomCost(p))) and 6–10 months for an independent team: 70% of the effect, small risk of a taint finding. \(agency) trust −1, and its classified evaluations mark you down for 4 years.")
        case 3: return DecisionOption(label: "License the permitted parts", detail: "About \(Fmt.money(royaltyMonthly(p) * 36)) in royalties over three years; a fifth of the effect. \(agency) trust −0.5; its classified evaluations mark you down for 3 years.")
        case 4: return DecisionOption(label: "Partner with an authorised organisation", detail: "\(Fmt.money(p.value * 0.08)) now from a cleared partner, 45% of the effect, record +0.5, trust +0.5; classified evaluations mark you down for 2 years.")
        case 5: return DecisionOption(label: "Retain it for internal use only", detail: "Use it inside your own company (half the internal effect: costs, infrastructure, chips — no products, no licences, no papers). Record +1, trust +1, standing +1, political capital +1.")
        default:
            return DecisionOption(label: "Keep it classified", detail: afterDenial ? "No commercial use. \(agency) trust +1, record +0.5." : "No commercial use. \(agency) trusts you more (record +1.5, trust +2, standing +2, political capital +2).")
        }
    }

    static func askSecrecy(_ s: inout GameState, _ i: Int, codes: [Int] = [0, 1, 2, 3, 4, 5]) {
        let p = s.advanced.programmes[i]
        let sol = p.sol
        let what = sol.templateDef?.discovery ?? "a discovery"
        let after = p.secrecy == .denied
        Events.addDecision(&s, kind: secrecyKind, title: after ? "Civilian use denied: \(what)" : "Classified discovery: \(what)",
                           body: after ? "The review board won't clear \(what) from \(sol.title) for civilian use. It stays sealed unless you use it inside the company or license the parts that are permitted."
                                       : "\(sol.title) for \(sol.agencyDef?.short ?? sol.agency) produced \(what) — valuable to your commercial models, but it's \(sol.level.title) and \(sol.ip.title.lowercased()). What do you do with it? The research it hands over, and its results for your moonshots, wait for this decision.",
                           image: sol.templateDef?.image,
                           options: codes.map { secrecyOption($0, s, p, afterDenial: after) },
                           amount: p.value, ref: "\(p.id.uuidString)|\(codes.map(String.init).joined(separator: ","))")
    }

    static func approvalOdds(_ s: GameState, _ p: Programme) -> Double {
        let st = standing(s, p.sol.agencyDef?.region ?? .us)
        return clamp(0.3 + (st - 50) / 100 + 0.02 * rating(s, p.sol.agency) - 0.12 * Double(p.sol.classification - 2) + (p.sol.ip == .government ? -0.08 : 0), 0.08, 0.8)
    }

    static func cleanRoomCost(_ p: Programme) -> Double { max(2e5, (p.value * 0.18 / 1e4).rounded() * 1e4) }

    static func royaltyMonthly(_ p: Programme) -> Double { p.value * 0.006 * (p.sol.ip == .government ? 0.5 : 1) }

    /// Commercialising a classified result marks you down in the agency's classified evaluations for `years`.
    static func markCommercialised(_ s: inout GameState, _ agency: String, years: Int) {
        let until = GameCalendar.addMonths(s.date, 12 * years)
        if (s.advanced.commercialised[agency] ?? .distantPast) < until { s.advanced.commercialised[agency] = until }
    }

    static func resolveSecrecy(_ s: inout GameState, _ d: Decision, option: Int) {
        let parts = d.ref.split(separator: "|").map(String.init)
        guard let first = parts.first, let id = UUID(uuidString: first), let i = s.advanced.programmes.firstIndex(where: { $0.id == id }),
              s.advanced.programmes[i].secrecy == .pending || s.advanced.programmes[i].secrecy == .denied else { return }
        let codes = parts.count > 1 ? parts[1].split(separator: ",").compactMap { Int($0) } : [0, 1, 2, 3, 4, 5]
        let code = codes.indices.contains(option) ? codes[option] : 0
        var p = s.advanced.programmes[i]
        let after = p.secrecy == .denied
        let agency = p.sol.agencyDef
        let today = s.date
        let u = roll(s, "secrecytime|\(p.sol.id)")
        let months = { (lo: Int, hi: Int) -> Date in GameCalendar.addMonths(today, lo + Int(u * Double(hi - lo + 1))) }
        var release = false
        switch code {
        case 1 where !after:
            p.secrecy = .review
            p.secrecyUntil = months(4, 9)
            log(&p, s.date, "Requested civilian-use review (odds about \(Fmt.pct(approvalOdds(s, p), decimals: 0))).")
        case 2 where !after:
            let cost = cleanRoomCost(p)
            if s.cash >= cost {
                s.cash -= cost
                s.month.costOther += cost
                p.direct += cost
                p.secrecy = .cleanRoom
                p.secrecyUntil = months(6, 10)
                addTrust(&s, p.sol.agency, -1)
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
            addTrust(&s, p.sol.agency, -0.5)
            markCommercialised(&s, p.sol.agency, years: 3)
            release = true
            log(&p, s.date, "Licensed the permitted parts: \(Fmt.money(p.royaltyMonthly))/month for three years.", 1)
        case 4 where !after:
            p.secrecy = .partnered
            p.effectScale = 0.45
            p.stage = .commercialisation
            s.advanced.programmes[i] = p
            income(&s, i, p.value * 0.08)
            p = s.advanced.programmes[i]
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) + 0.5, -10, 10)
            addTrust(&s, p.sol.agency, 0.5)
            markCommercialised(&s, p.sol.agency, years: 2)
            release = true
            log(&p, s.date, "Partnered with an authorised organisation: \(Fmt.money(p.value * 0.08)) up front.", 1)
        case 5:
            // Retained internally: it stays classified (no products, licences or papers) but your own teams use it.
            p.secrecy = .retained
            p.effectScale = retainedScale
            p.stage = .commercialisation
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) + 1, -10, 10)
            addTrust(&s, p.sol.agency, 1)
            s.politicalCapital = min(100, s.politicalCapital + 1)
            if let agency { Stakeholders.move(&s, [agency.region.rawValue: 1], "Kept a classified discovery from \(p.sol.title) inside the company") }
            release = true
            log(&p, s.date, "Retained for internal use only: your own teams use it; nothing leaves the company.", 1)
        default:
            p.secrecy = .classified
            s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) + (after ? 0.5 : 1.5), -10, 10)
            addTrust(&s, p.sol.agency, after ? 1 : 2)
            if !after {
                s.politicalCapital = min(100, s.politicalCapital + 2)
                if let agency { Stakeholders.move(&s, [agency.region.rawValue: 2], "Kept a classified discovery from \(p.sol.title) under wraps") }
            }
            log(&p, s.date, "Kept the discovery classified.", 1)
        }
        s.advanced.programmes[i] = p
        syncDiscovery(&s, i)
        if release { handOver(&s, i) }
    }

    static func finishSecrecy(_ s: inout GameState, _ i: Int) {
        var p = s.advanced.programmes[i]
        p.secrecyUntil = nil
        var release = false, denied = false
        switch p.secrecy {
        case .review:
            let odds = approvalOdds(s, p)
            let r = roll(s, "approval|\(p.sol.id)")
            if r < odds {
                p.secrecy = .approved
                p.effectScale = 1
                p.stage = .commercialisation
                s.brand = min(100, s.brand + 2)
                release = true
                log(&p, s.date, "Civilian use approved (roll \(Fmt.trim(r, 2)) under \(Fmt.pct(odds, decimals: 0))).", 1)
                Sim.news(&s, "Cleared for civilian use", "The review board approves commercial use of what \(p.sol.title) discovered. It goes into your models.", .research, good: true)
            } else {
                p.secrecy = .denied
                denied = true
                log(&p, s.date, "Civilian use denied (roll \(Fmt.trim(r, 2)) over \(Fmt.pct(odds, decimals: 0))). It stays classified unless you retain it internally or license the permitted parts.", -1)
                Sim.news(&s, "Civilian use denied", "The review board keeps what \(p.sol.title) discovered classified. You can still use it inside the company or license the permitted parts.", .research, good: false)
            }
        case .cleanRoom:
            let r = roll(s, "taint|\(p.sol.id)")
            if r < 0.1 {
                p.secrecy = .tainted
                p.effectScale = 0
                if let a = p.sol.agencyDef { Stakeholders.move(&s, [a.region.rawValue: -4], "A clean-room rebuild of classified work was found tainted") }
                s.advanced.ratings[p.sol.agency] = clamp(rating(s, p.sol.agency) - 2, -10, 10)
                addTrust(&s, p.sol.agency, -3)
                log(&p, s.date, "Taint finding (roll \(Fmt.trim(r, 2)) under 10%): the clean-room version is withdrawn.", -1)
                Sim.news(&s, "Clean-room rebuild withdrawn", "Investigators found classified material in the 'independent' rebuild. Standing −4.", .policy, important: true, good: false)
            } else {
                p.secrecy = .cleanRoomDone
                p.effectScale = 0.7
                p.stage = .commercialisation
                markCommercialised(&s, p.sol.agency, years: 4)
                release = true
                log(&p, s.date, "Clean-room version finished and in use (taint roll \(Fmt.trim(r, 2)) over 10%).", 1)
                Sim.news(&s, "Clean-room rebuild done", "An independent team rebuilt the capability from public knowledge. It goes into your models.", .research, good: true)
            }
        default: break
        }
        s.advanced.programmes[i] = p
        syncDiscovery(&s, i)
        if release { handOver(&s, i) }
        if denied { askSecrecy(&s, i, codes: [0, 5, 3]) }
    }

    // MARK: Discoveries and patents

    /// Share of a result's internal effects you keep when it's retained for internal use only.
    static let retainedScale = 0.5

    /// A delivered programme's discovery joins your discoveries and patents: open work is published and patented at once;
    /// controlled work is patented and its paper waits 3–6 months for pre-publication review; classified work is
    /// patented under a secrecy order and can't be published until it's cleared.
    static func recordDiscovery(_ s: inout GameState, _ i: Int) {
        let p = s.advanced.programmes[i]
        guard let t = p.template, let what = t.discovery, !s.advanced.discoveries.contains(where: { $0.programme == p.id }) else { return }
        let classified = p.sol.level >= .secret
        var d = ProgrammeDiscovery(programme: p.id, template: t.id, title: what, agency: p.sol.agency, level: p.sol.classification, date: s.date,
                                   patentFiled: s.date, secrecyOrder: classified)
        if !classified {
            d.cleared = s.date
            d.published = p.sol.level == .unclassified
            if p.sol.level == .controlled { d.reviewUntil = GameCalendar.addMonths(s.date, 3 + Int(roll(s, "review|\(p.sol.id)") * 4)) }
            d.licensees = p.sol.ip == .government ? 0 : 2 + Int(roll(s, "licensees|\(p.sol.id)") * 3)
        }
        s.advanced.discoveries.append(d)
        log(&s.advanced.programmes[i], s.date, classified ? "Discovery recorded: \(what). Patent filed under a secrecy order; no publication."
            : "Discovery recorded: \(what). Patent filed\(d.published ? " and the paper published" : " (paper in pre-publication review until \(d.reviewUntil?.gameShort ?? ""))")\(d.licensees > 0 ? "; \(d.licensees) licensees" : "").", 1)
        if d.published, let f = t.sciField { Science.bumpMomentum(&s, f, 0.01) }
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

    /// Entries for the company history timeline (contracts, deliveries, discoveries, clearances for civilian use);
    /// `Science.companyHistory` appends them.
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

    /// "+12%" / "−3%" from a fraction.
    static func signedPct(_ v: Double) -> String { (v >= 0 ? "+" : "−") + Fmt.pct(abs(v), decimals: 0) }

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
            out.append("Cure notice at \(Int(Double(sol.months) * 1.25)) months; termination for default at \(Int(Double(sol.months) * 1.6)) months: 20% of payments repaid, plus 3% of the price in re-procurement costs")
        case .costPlus:
            out.append("Costs reimbursed up to \(Fmt.money(sol.estCost * 1.25)) (pay above the allowable-compensation cap isn't); audits every 6 months; termination for default at \(Int(Double(sol.months) * 1.9)) months: fee not yet earned is repaid, plus 3% of the target cost in re-procurement costs")
        case .grant:
            out.append("Lapses if not finished in \(sol.months * 2) months; unspent grant money is returned")
        case .prize:
            out.append("Ends when a competitor delivers first (10% runner-up award if you're 60% done); the challenge closes at \(sol.months * 2) months")
        }
        out.append("Must be mobilised within \(mobilisationGrace(sol)) months of award; the schedule runs from mobilisation")
        out.append("May be terminated for convenience if the agency's budget is cut (settlement paid); likelier when its commitments outrun its budget")
        if sol.level >= .secret { out.append("Stop-work order if your weight security falls below SL\(sol.level.requiredSL); nothing from the work can be used, and no effects are kept, if it ends early") }
        if sol.level >= .controlled { out.append(sol.level.publication) }
        return out
    }
}
