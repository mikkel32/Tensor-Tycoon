import Foundation

/// 3.5: what the company's home does to it. Everything here is neutral for the default (United States / San Francisco):
/// factors are exactly 1, bonuses 0, and nothing draws from the game's random numbers, so US games play as before.
struct HQState: Codable, DefaultValue {
    static var defaultValue: HQState { HQState() }
    /// When the last grant, partnership or contract offer arrived (offers are spaced out).
    @D var lastOffer: Date? = nil
    /// Site ID → capex already settled against the home build-cost factor.
    @D var settled: [String: Double] = [:]
    /// Offers already made once (partnership products, contract years).
    @D var offered: Set<String> = []
    /// Running totals, for the Team page and the harness.
    @D var grants: Double = 0
    @D var computeGrants: Double = 0
    @D var rdCredits: Double = 0
    @D var rebates: Double = 0
    @D var contracts: Int = 0
    @D var partnerships: Int = 0
}

enum HQ {
    // MARK: Who and where

    static func country(_ s: GameState) -> HQCountry { CountryCatalog.get(s.hqCountry) }
    static func city(_ s: GameState) -> HQCity { country(s).city(s.hqCity) }
    /// The default home: no effects at all.
    static func isDefault(_ s: GameState) -> Bool { CountryCatalog.byID[s.hqCountry] == nil || s.hqCountry == "us" }
    static func region(_ s: GameState) -> Region { country(s).region }
    static func place(_ s: GameState) -> String { "\(city(s).name), \(country(s).name)" }

    /// The seed round's size: thinner local VC raises a little less at the start (international funds come in later).
    static func seedCash(_ settings: NewGameSettings) -> Double {
        let c = CountryCatalog.get(settings.hqCountry)
        return c.id == "us" ? 1 : (1 + c.investorDepth) / 2
    }

    /// Where the garage goes for a new game.
    static func garageLocation(_ settings: NewGameSettings) -> String {
        let c = CountryCatalog.get(settings.hqCountry)
        return c.id == "us" ? settings.locationID : c.homeLocation
    }

    // MARK: Money

    /// Corporate tax on a month's profit.
    static func taxRate(_ s: GameState) -> Double { isDefault(s) ? 0.21 : country(s).corporateTax }

    /// Pay for talent here relative to San Francisco. Stars sell into a global market, so they cost more of the
    /// San Francisco rate than everyone else.
    static func salaryFactor(_ s: GameState, star: Bool = false) -> Double {
        guard !isDefault(s) else { return 1 }
        let local = country(s).salary * city(s).salary
        return star ? (1 + local) / 2 : local
    }

    /// Employer on-costs (social contributions) on top of salaries, relative to the US.
    static func payrollFactor(_ s: GameState) -> Double { isDefault(s) ? 1 : 1 + country(s).employerCost }

    static func officeFactor(_ s: GameState) -> Double { isDefault(s) ? 1 : city(s).office }

    /// Local early-stage investors price rounds a little lower until the company is big enough for global funds.
    static func investorFactor(_ s: GameState, value: Double) -> Double {
        guard !isDefault(s) else { return 1 }
        let depth = country(s).investorDepth
        // Full effect below $50M, none above $5B (log-linear in between).
        let fade = clamp((log10(max(value, 1)) - log10(5e7)) / 2, 0, 1)
        return depth + (1 - depth) * fade
    }

    /// Research and engineering payroll this month (what an R&D tax credit applies to), including on-costs.
    static func rdPayrollMonth(_ s: GameState) -> Double {
        s.employees.filter { $0.role != .sales }.reduce(0) { $0 + $1.salary } / 12 * payrollFactor(s) * max(0.5, 1 + s.traits.payroll)
    }

    /// The month's tax: corporate tax on profit after losses carried forward, less any R&D tax credit. A refundable
    /// credit is paid out in cash even with no tax to set it against; a non-refundable one waits in the credit pool
    /// until there is. Added to the month's taxes (a transfer-pricing audit settled earlier in the month stays booked).
    static func settleTaxes(_ s: inout GameState, pre: Double) {
        let split = taxableAfterLosses(pre, pool: s.corp.lossPool)
        s.corp.lossPool = split.pool
        let tax = split.taxable * taxRate(s)
        var net = tax
        if !isDefault(s) {
            let c = country(s)
            let credit = c.rdCredit * rdPayrollMonth(s)
            if c.rdRefundable {
                net = tax - credit
            } else {
                let available = credit + s.corp.creditPool
                let offset = min(available, tax)
                s.corp.creditPool = available - offset
                net = tax - offset
            }
            s.hq.rdCredits += tax - net
        }
        guard net != 0 else { return }
        s.month.taxes += net
        s.cash -= net
    }

    /// Profit left to tax once losses carried forward are used, and the pool afterwards: a loss adds to the pool,
    /// a profit uses it up first.
    static func taxableAfterLosses(_ pre: Double, pool: Double) -> (taxable: Double, pool: Double) {
        if pre <= 0 { return (0, pool - pre) }
        let used = min(pool, pre)
        return (pre - used, pool - used)
    }

    // MARK: People

    /// Candidates on the market at once.
    static func candidateTarget(_ s: GameState, _ base: Int) -> Int {
        guard !isDefault(s) else { return base }
        return max(4, Int((Double(base) * country(s).talentPool * city(s).talent).rounded()))
    }

    /// Extra entries in the role draw: the roles the local ecosystem produces more of.
    static func extraRoles(_ s: GameState) -> [Role] {
        guard !isDefault(s) else { return [] }
        var roles = country(s).specialties + city(s).specialties
        // Chip designers are only on the market once you do silicon, except in a semiconductor town.
        if !s.bonuses.has(.customSilicon) || s.year <= 2018 { roles.removeAll { $0 == .chipDesigner } }
        if city(s).specialties.contains(.chipDesigner) && s.year > 2018 { roles.append(.chipDesigner) }
        return roles
    }

    /// Skill points local specialists bring.
    static func skillBonus(_ s: GameState, _ r: Role) -> Double {
        guard !isDefault(s) else { return 0 }
        return (country(s).specialties.contains(r) ? 2 : 0) + (city(s).specialties.contains(r) ? 2 : 0)
    }

    /// How readily big foreign labs poach your people.
    static func poachFactor(_ s: GameState) -> Double { isDefault(s) ? 1 : country(s).brainDrain }

    // MARK: Government

    /// Standing points with a region's government from where you're based.
    static func standingBonus(_ s: GameState, _ r: Region) -> Double {
        guard !isDefault(s) else { return 0 }
        let c = country(s)
        if r == c.region { return c.homeStanding }
        if r == .us { return c.usStanding }
        return 0
    }

    // MARK: Industry

    static func affinities(_ s: GameState) -> [HQAffinity] {
        guard !isDefault(s) else { return [] }
        return country(s).affinities + city(s).affinities
    }

    /// Domain points a product's bars drop by, thanks to local partners.
    static func productRelief(_ p: ProductDef, _ s: GameState) -> Double {
        affinities(s).filter { $0.product == p.id }.map(\.relief).max() ?? 0
    }

    /// Extra pull a product has with local buyers and partners.
    static func productPull(_ p: ProductDef, _ s: GameState) -> Double {
        affinities(s).filter { $0.product == p.id }.map(\.pull).max() ?? 1
    }

    // MARK: Infrastructure

    /// Capex factor for datacenters you build at home (1 elsewhere).
    static func buildCost(_ s: GameState, location: String) -> Double {
        guard !isDefault(s), location == country(s).homeLocation else { return 1 }
        return country(s).buildCost
    }

    // MARK: Monthly

    /// Grants, compute allocations, partnership and contract offers (inbox only), and the home build-cost rebate.
    static func monthly(_ s: inout GameState) {
        guard !isDefault(s) else { return }
        settleBuildCosts(&s)
        let y = s.year
        let c = country(s)
        let ym = s.date.ym
        if let last = s.hq.lastOffer, GameCalendar.daysBetween(last, s.date) < 100 { return }
        if s.decisions.contains(where: { $0.kind.hasPrefix("hq_") }) { return }
        func roll(_ tag: String) -> Double { RivalIntel.unit("hq|\(s.lifecycleSalt)|\(tag)|\(ym.year)-\(ym.month)") }

        // A national contract: the home government buys from its own lab.
        let best = s.releasedModels.max(by: { $0.c < $1.c })
        if y >= 2023.5, let best, best.c > Macro.frontier(y) - 2.0, !s.hq.offered.contains("contract|\(Int(y))"),
           roll("contract") < 0.03 * c.contractAffinity * clamp(s.world.ready ? s.world.government(c.region) / 60 : 1, 0.5, 1.5) {
            s.hq.offered.insert("contract|\(Int(y))")
            s.hq.lastOffer = s.date
            let programme = c.programmes.first { $0.kind == .contract }
            let monthly = max(3e6 * scale(y), Economy.runRate(s) * 0.02)
            Events.addDecision(&s, kind: "hq_contract", title: "\(c.adjective) government contract: \(programme?.name ?? "public-sector AI")",
                               body: "\(programme?.pitch ?? "The government wants a national model.") \(Fmt.money(monthly))/month for 2 years on \(best.name), hosted in \(c.name), with public-sector safety terms.",
                               image: city(s).image,
                               options: [DecisionOption(label: "Sign it", detail: "+\(Fmt.money(monthly * 24)) over 2 years. Standing at home +3, brand +1."),
                                         DecisionOption(label: "Decline", detail: "Keep your capacity for the market.")],
                               amount: monthly, ref: best.id.uuidString)
            return
        }

        // An industrial partnership: local industry co-funds the research behind a product line it wants.
        for a in affinities(s) where !s.hq.offered.contains("partner|\(a.product)") {
            guard let p = ProductLines.byID[a.product], let r = ResearchCatalog.byID[p.research],
                  !s.researched.contains(r.id), y >= r.year - 0.4, r.prereqs.allSatisfy({ s.researched.contains($0) }) else { continue }
            guard roll("partner|\(a.product)") < 0.25 else { continue }
            s.hq.offered.insert("partner|\(a.product)")
            s.hq.lastOffer = s.date
            let share = min(ProductLines.launchCost(p, y) * 0.15, max(250_000, s.cash * 0.04))
            Events.addDecision(&s, kind: "hq_partner", title: "Partnership offer: \(p.name) with \(a.partner)",
                               body: "\(a.partner.prefix(1).uppercased() + a.partner.dropFirst()) want to co-develop \(r.name) with you and pilot the result. You put in \(Fmt.money(share)); they bring engineers, data and test sites.",
                               image: city(s).image,
                               options: [DecisionOption(label: "Partner", detail: "−\(Fmt.money(share)). \(r.name) gets 45% of its research done; \(p.name) unlocks sooner."),
                                         DecisionOption(label: "Not now", detail: "Do it yourself later.")],
                               amount: share, ref: r.id)
            return
        }

        // Grants and compute allocations.
        let grants = c.programmes.filter { $0.kind != .contract }
        guard !grants.isEmpty, roll("grant") < c.grantRate else { return }
        let g = grants[Int(roll("which") * Double(grants.count)) % grants.count]
        let amount = (g.base * scale(y) / 50_000).rounded() * 50_000
        s.hq.lastOffer = s.date
        let compute = g.kind == .compute
        Events.addDecision(&s, kind: "hq_grant", title: compute ? "Compute grant: \(g.name)" : "Grant offer: \(g.name)",
                           body: "\(g.pitch) \(compute ? "\(Fmt.money(amount)) in GPU hours, spent automatically on your rentals." : "\(Fmt.money(amount)), paid as the project starts.") You publish a summary of the results.",
                           image: city(s).image,
                           options: [DecisionOption(label: "Accept", detail: compute ? "+\(Fmt.money(amount)) cloud credits. Researchers' respect +1." : "+\(Fmt.money(amount)). Researchers' respect +1, standing at home +1."),
                                     DecisionOption(label: "Decline", detail: "Skip the paperwork.")],
                           amount: amount, ref: compute ? "compute" : "grant")
    }

    /// Grants and allocations grow with the era (public AI budgets did).
    static func scale(_ y: Double) -> Double {
        interpolate([(2016, 0.5), (2020, 0.8), (2022, 1), (2024, 1.6), (2026, 2.5), (2030, 4), (2035, 6)], at: y, extrapolate: false)
    }

    /// Datacenters at home cost the country's build-cost factor: the difference is settled monthly as an incentive.
    static func settleBuildCosts(_ s: inout GameState) {
        let c = country(s)
        guard c.buildCost != 1 else { return }
        var refund = 0.0
        for site in s.sites where site.kind == .datacenter && site.locationID == c.homeLocation {
            let key = site.id.uuidString
            let delta = site.capex - (s.hq.settled[key] ?? 0)
            guard delta > 0 else { continue }
            s.hq.settled[key] = site.capex
            refund += delta * (1 - c.buildCost)
        }
        guard refund > 0 else { return }
        s.cash += refund
        s.month.oneOffIncome += refund
        s.hq.rebates += refund
        Sim.news(&s, "\(c.adjective) infrastructure incentive: \(Fmt.money(refund))",
                 "Local incentives and contractors brought your home datacenter construction in \(Fmt.pct(1 - c.buildCost, decimals: 0)) under the usual cost.",
                 .finance, image: LocationCatalog.byID[c.homeLocation]?.image, good: true)
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        let c = country(s)
        switch (d.kind, option) {
        case ("hq_grant", 0):
            if d.ref == "compute" {
                s.cloudCredits += d.amount
                s.hq.computeGrants += d.amount
            } else {
                s.cash += d.amount
                s.month.oneOffIncome += d.amount
                s.hq.grants += d.amount
            }
            Stakeholders.move(&s, d.ref == "compute" ? ["researchers": 1] : ["researchers": 1, c.region.rawValue: 1], "Accepted a \(c.adjective) public research award")
            Sim.news(&s, d.ref == "compute" ? "Compute grant awarded" : "Grant awarded", "\(d.title.replacingOccurrences(of: "Grant offer: ", with: "").replacingOccurrences(of: "Compute grant: ", with: "")): \(Fmt.money(d.amount)).",
                     .finance, good: true)
        case ("hq_partner", 0):
            guard s.cash >= d.amount, let r = ResearchCatalog.byID[d.ref] else {
                Sim.news(&s, "Partnership fell through", "You couldn't fund your share.", .company, good: false)
                return
            }
            s.cash -= d.amount
            s.month.costOther += d.amount
            let done = s.researchProgress[r.id] ?? 0
            s.researchProgress[r.id] = min(r.cost * 0.95, done + r.cost * 0.45)
            s.hq.partnerships += 1
            s.brand = min(100, s.brand + 1)
            Sim.news(&s, "Partnership signed: \(r.name)", "Engineers from your partners joined the project. 45% of the research is done.", .research, good: true)
        case ("hq_contract", 0):
            s.deals.append(EnterpriseDeal(client: "\(c.adjective) government", title: "national AI programme", monthly: d.amount, tokensPerDay: 0,
                                          months: 24, monthsLeft: 24, minIndex: 0, minSafety: 0, expires: s.date, active: true))
            s.hq.contracts += 1
            s.brand = min(100, s.brand + 1)
            Stakeholders.move(&s, [c.region.rawValue: 3], "Signed a national AI contract with the \(c.adjective) government")
            Sim.news(&s, "\(c.adjective) government contract signed", "\(Fmt.money(d.amount))/month for 2 years.", .company, important: true, good: true)
        default:
            break
        }
    }

    // MARK: New game

    static func found(_ s: inout GameState) {
        guard !isDefault(s) else { return }
        let c = country(s)
        let city = city(s)
        Sim.news(&s, "\(c.flag) Headquartered in \(city.name)",
                 "\(city.blurb) \(Fmt.pct(c.corporateTax, decimals: 1)) corporate tax\(c.rdCredit > 0 ? ", an R&D tax credit on research payroll" : ""), and \(c.adjective) public programmes will come knocking. International capital, cloud and datacenters are open to you as to anyone.",
                 .company, image: city.image, important: true, good: true)
    }
}

// MARK: - Offices

extension Economy {
    /// An office level as it is in your city: the same room, local rent and a local name.
    static func office(_ s: GameState, _ level: Int) -> (name: String, capacity: Int, monthly: Double, image: String) {
        let o = officeLevels[min(max(0, level), officeLevels.count - 1)]
        guard !HQ.isDefault(s) else { return o }
        let city = HQ.city(s)
        let name = o.name.replacingOccurrences(of: " in SF", with: " in \(city.name)")
        return (name, o.capacity, o.monthly * city.office, level >= 2 ? city.image : o.image)
    }
}
