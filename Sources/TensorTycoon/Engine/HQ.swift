import Foundation

/// 3.5: what the company's home does to it. Everything here is neutral for the default (United States / San Francisco):
/// factors are exactly 1, bonuses 0, and nothing draws from the game's random numbers, so US games play as before.
struct HQState: Codable, DefaultValue {
    static var defaultValue: HQState { HQState() }
    /// When the last grant, partnership or contract offer arrived (offers are spaced out).
    @D var lastOffer: Date? = nil
    /// No longer used (3.4 overhaul): the home build incentive is now taken off each phase's price when it's built.
    @D var settled: [String: Double] = [:]
    /// Offers already made once (partnership products, contract years).
    @D var offered: Set<String> = []
    /// Running totals, for the Team page and the harness. `rebates` counts the home build incentive.
    @D var grants: Double = 0
    @D var computeGrants: Double = 0
    @D var rdCredits: Double = 0
    @D var rebates: Double = 0
    @D var contracts: Int = 0
    @D var partnerships: Int = 0

    // 3.4 overhaul
    /// Offices outside headquarters, each hiring locally at local pay.
    @D var satellites: [SatelliteOffice] = []
    /// National compute centres and university chairs you've co-funded.
    @D var partners: [NationalPartnership] = []
    /// R&D relief earned but not yet used (schemes that only count against profit, and France's CIR for larger firms).
    @D var rdCarry: Double = 0
    /// Minimum-turnover-tax top-ups paid (Romania, from 2024).
    @D var minimumTax: Double = 0
    /// Grant and compute-allocation offers received (for the observed rate).
    @D var grantOffers: Int = 0
    /// National contracts you host in your own datacenter (deal IDs), and months each has been out of its terms.
    @D var ownHosted: Set<String> = []
    @D var strikes: [String: Int] = [:]
    /// Home income from national contracts so far.
    @D var contractRevenue: Double = 0
    /// Priority GPU hours paid out by compute centres you co-fund, so far.
    @D var partnerCredits: Double = 0
    /// The last monthly tax settlement as the tax code saw it: pre-tax profit, the taxable profit after losses carried
    /// forward, the tax charged (after relief and any minimum-tax top-up) and the R&D relief (harness and scenario
    /// checks; the books close more after it).
    @D var taxProfit: Double = 0
    @D var taxBase: Double = 0
    @D var taxCharged: Double = 0
    @D var taxRelief: Double = 0
}

/// 3.4 overhaul: an office in another city (at home or abroad). It hires from that city's pool at that city's pay and
/// employer on-costs, and pays that city's rent.
struct SatelliteOffice: Codable, Identifiable, Hashable {
    var id = StableID.next()
    /// CountryCatalog IDs.
    var country: String
    var city: String
    var seats: Int
    var opened: Date
}

/// 3.4 overhaul: what you can co-fund in a country.
enum PartnershipKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case computeCentre, universityChair

    var id: String { rawValue }

    var title: String {
        switch self {
        case .computeCentre: "Co-invest in a national compute centre"
        case .universityChair: "Endow a university chair"
        }
    }

    var symbol: String { self == .computeCentre ? "cpu.fill" : "graduationcap.fill" }

    /// How long it runs, in months.
    var months: Int { self == .computeCentre ? 36 : 60 }

    var effect: String {
        switch self {
        case .computeCentre: "Priority GPU hours worth 40% of the stake over three years, standing +4 with that government, grant offers ×1.3 if it's home, and the country's compute subsidies and sovereign programme pushed up at the next January review."
        case .universityChair: "That city's candidate pool +30% and its researchers +3 skill for five years, researchers' respect +2, standing +2, and the country's talent visas pushed up at the next January review."
        }
    }
}

/// A partnership you've signed.
struct NationalPartnership: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var kind: PartnershipKind
    var country: String
    var city: String
    var cost: Double
    var signed: Date
    var until: Date
    /// A January review has pushed its country's dials.
    @D var counted: Bool = false

    func active(_ d: Date) -> Bool { d < until }
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

    /// Where the garage goes for a new game: your US site of choice, or the home site of any other country (the
    /// new-game screen only offers US sites, and only for a US headquarters).
    static func garageLocation(_ settings: NewGameSettings) -> String {
        let c = CountryCatalog.get(settings.hqCountry)
        guard c.id == "us" else { return c.homeLocation }
        return Region.us.locations.contains(settings.locationID) ? settings.locationID : c.homeLocation
    }

    // MARK: Money

    /// Corporate tax on a month's profit (the US: the 21% federal rate; state taxes aren't modelled).
    static func taxRate(_ s: GameState) -> Double { isDefault(s) ? 0.21 : country(s).corporateTax }

    /// Pay for talent here relative to San Francisco. Stars sell into a global market, so they cost more of the
    /// San Francisco rate than everyone else.
    static func salaryFactor(_ s: GameState, star: Bool = false) -> Double {
        guard !isDefault(s) else { return 1 }
        let local = country(s).salary * city(s).salary
        return star ? (1 + local) / 2 : local
    }

    /// Pay relative to San Francisco for someone working in `office` ("" = headquarters). People who relocate from
    /// abroad to headquarters are on the international rate (halfway to San Francisco's), like stars.
    static func payFactor(_ s: GameState, office: String, star: Bool, relocated: Bool) -> Double {
        if let o = satellite(s, office) {
            let c = CountryCatalog.get(o.country)
            let local = c.pay(c.city(o.city))
            return star ? (1 + local) / 2 : local
        }
        guard !isDefault(s) else { return 1 }
        return relocated ? salaryFactor(s, star: true) : salaryFactor(s, star: star)
    }

    /// Employer on-costs (social contributions) on top of salaries, relative to the US.
    static func payrollFactor(_ s: GameState) -> Double { isDefault(s) ? 1 : 1 + country(s).employerCost }

    /// On-costs for someone working in `office`: each office pays its own country's contributions.
    static func payrollFactor(_ s: GameState, office: String) -> Double {
        guard let o = satellite(s, office) else { return payrollFactor(s) }
        return 1 + CountryCatalog.get(o.country).employerCost
    }

    /// Local early-stage investors price rounds a little lower until the company is big enough for global funds; a
    /// recession at home takes a little more off every round (3.4 overhaul).
    static func investorFactor(_ s: GameState, value: Double) -> Double {
        let dip = Nations.recessionInvestorFactor(s)
        guard !isDefault(s) else { return dip }
        let depth = country(s).investorDepth
        // Full effect below $50M, none above $5B (log-linear in between).
        let fade = clamp((log10(max(value, 1)) - log10(5e7)) / 2, 0, 1)
        return (depth + (1 - depth) * fade) * dip
    }

    /// Research and engineering payroll this month (what an R&D tax credit applies to), including on-costs.
    static func rdPayrollMonth(_ s: GameState) -> Double {
        s.employees.filter { $0.role != .sales }.reduce(0) { $0 + $1.salary } / 12 * payrollFactor(s) * max(0.5, 1 + s.traits.payroll)
    }

    /// The month's tax: corporate tax on profit after losses carried forward, less the R&D relief the home country's
    /// scheme allows this month, plus any minimum-tax top-up. Added to the month's taxes (a transfer-pricing audit
    /// settled earlier in the month stays booked).
    static func settleTaxes(_ s: inout GameState, pre: Double) {
        let split = taxableAfterLosses(pre, pool: s.corp.lossPool)
        s.corp.lossPool = split.pool
        let tax = split.taxable * taxRate(s)
        var net = tax
        var relief = 0.0
        if !isDefault(s) {
            let c = country(s)
            relief = rdRelief(&s, tax: tax, pre: pre)   // 3.4 overhaul: the real scheme, its caps and carry-forward
            net = tax - relief + minimumTaxDue(&s, tax: tax - relief)   // 3.4 overhaul: Romania's minimum turnover tax
            s.hq.rdCredits += relief
            // A loss surrendered for Denmark's tax credit is paid out, so it isn't carried forward as well.
            if pre < 0 && c.rdScheme == .lossRefund && relief > 0 {
                s.corp.lossPool = max(0, s.corp.lossPool - relief / c.corporateTax)
            }
        }
        s.hq.taxProfit = pre
        s.hq.taxBase = split.taxable
        s.hq.taxCharged = net
        s.hq.taxRelief = relief
        guard net != 0 else { return }
        s.month.taxes += net
        s.cash -= net
    }

    // MARK: R&D relief (3.4 overhaul)

    /// Eligible R&D spend this month: research and engineering payroll with on-costs, for people working in the home
    /// country (the headquarters and any satellite there). A satellite abroad doesn't qualify for the home scheme.
    static func rdSpendMonth(_ s: GameState) -> Double {
        let home = s.hqCountry
        return s.employees.filter { e in
            e.role != .sales && (satellite(s, e.office).map { $0.country == home } ?? true)
        }.reduce(0) { $0 + $1.salary * payrollFactor(s, office: $1.office) } / 12 * max(0.5, 1 + s.traits.payroll)
    }

    /// Small and medium-sized company for France's CIR (under 250 staff).
    static func isSME(_ s: GameState) -> Bool { s.employees.count < 250 }

    /// How much this month's R&D relief takes off the tax bill under the home country's real scheme [RD]. More than
    /// the bill means cash paid out (refundable, payroll-offset and loss-refund schemes). Relief that only counts against
    /// profit and isn't used now is carried forward in `hq.rdCarry`.
    static func rdRelief(_ s: inout GameState, tax: Double, pre: Double) -> Double {
        let c = country(s)
        guard c.rdCredit > 0, c.rdScheme != .none else { return 0 }
        let spend = rdSpendMonth(s)
        var credit = c.rdCredit * spend
        if c.rdCapYear > 0 {
            let cap = c.rdCapYear / 12
            credit = c.rdCredit * min(spend, cap) + c.rdAbove * max(0, spend - cap)
        }
        if c.rdCreditCapYear > 0 { credit = min(credit, c.rdCreditCapYear / 12) }
        switch c.rdScheme {
        case .none:
            return 0
        case .againstProfit:
            let avail = s.hq.rdCarry + credit
            let used = min(avail, tax)
            s.hq.rdCarry = avail - used
            return used
        case .payrollOffset:
            // Set against taxes and employer contributions on the home payroll (F24 compensation).
            let contributions = spend / (1 + c.employerCost) * c.socialContributions
            let avail = s.hq.rdCarry + credit
            let used = min(avail, tax + contributions)
            s.hq.rdCarry = avail - used
            return used
        case .lossRefund:
            if pre > 0 {
                let avail = s.hq.rdCarry + credit
                let used = min(avail, tax)
                s.hq.rdCarry = avail - used
                return used
            }
            // Skattekredit: the tax value of losses that come from R&D, paid in cash up to the yearly cap.
            let cap = c.rdRefundCapYear > 0 ? c.rdRefundCapYear / 12 : .infinity
            return min(c.corporateTax * min(spend, -pre), cap)
        case .refundable:
            if isSME(s) { return credit + releaseCarry(&s, months: 1) }
            // Larger firms: set against tax now; what's left is refunded over about three years.
            let avail = s.hq.rdCarry + credit
            let used = min(avail, tax)
            s.hq.rdCarry = avail - used
            return used + releaseCarry(&s, months: 36)
        }
    }

    /// Pays out a slice of the carried-forward credit (France refunds unused CIR after three years).
    private static func releaseCarry(_ s: inout GameState, months: Double) -> Double {
        let out = s.hq.rdCarry / months
        s.hq.rdCarry -= out
        return out
    }

    /// Romania, from 2024: companies with more than €50M of turnover pay at least 1% of it in profit tax (Law
    /// 296/2023). Settled in the books that close December, for the calendar year.
    static func minimumTaxDue(_ s: inout GameState, tax: Double) -> Double {
        guard s.hqCountry == "ro", s.month.month.ym.month == 12 else { return 0 }
        let year = s.month.month.ym.year
        guard year >= 2024 else { return 0 }
        let months = s.history.filter { $0.month.ym.year == year }
        let turnover = months.reduce(s.month.revenue) { $0 + $1.revenue }
        guard turnover > 54_000_000 else { return 0 }
        let paid = months.reduce(max(0, tax)) { $0 + $1.taxes }
        let due = max(0, 0.01 * turnover - paid)
        guard due > 0 else { return 0 }
        s.hq.minimumTax += due
        Sim.news(&s, "Romanian minimum turnover tax: \(Fmt.money(due))",
                 "Turnover of \(Fmt.money(turnover)) in \(year) is over €50M, so the profit tax can't be less than 1% of it. Profit tax paid for the year: \(Fmt.money(paid)).",
                 .finance, good: false)
        return due
    }

    /// Profit left to tax once losses carried forward are used, and the pool afterwards: a loss adds to the pool,
    /// a profit uses it up first.
    static func taxableAfterLosses(_ pre: Double, pool: Double) -> (taxable: Double, pool: Double) {
        if pre <= 0 { return (0, pool - pre) }
        let used = min(pool, pre)
        return (pre - used, pool - used)
    }

    // MARK: People

    /// How far beyond the local job market your name carries (0–1). An unknown startup hires locally; a well-funded,
    /// well-known lab gets candidates willing to relocate from anywhere (talent visas then widen or narrow the whole
    /// pool). Fades in between $100M and $30B of valuation, or brand 35 to 80.
    static func talentReach(_ s: GameState) -> Double {
        guard !isDefault(s) else { return 1 }
        let byValue = clamp((log10(max(s.valuation, 1)) - 8) / 2.5, 0, 1)
        let byBrand = clamp((s.brand - 35) / 45, 0, 1)
        return max(byValue, byBrand)
    }

    /// Candidates on the market at once at headquarters: local hires (the city's pool, plus any university chairs you've
    /// endowed there), and the total once relocating hires are added (the gap to a San Francisco-sized pool, closing as
    /// your name carries). The US default is `base` exactly.
    static func candidateTargets(_ s: GameState, _ base: Int) -> (local: Int, total: Int) {
        let chairs = chairBoost(s, country: s.hqCountry, city: s.hqCity)
        guard !isDefault(s) else {
            let n = chairs == 1 ? base : Int((Double(base) * chairs).rounded())
            return (n, n)
        }
        let local = country(s).talentPool * city(s).talent * chairs
        let localN = max(4, Int((Double(base) * local).rounded()))
        let total = Int((Double(base) * (local + max(0, 1 - local) * talentReach(s))).rounded())
        return (localN, max(localN, total))
    }

    /// Extra entries in the role draw: the roles the local ecosystem produces more of.
    static func extraRoles(_ s: GameState) -> [Role] {
        guard !isDefault(s) else { return [] }
        return extraRoles(s, country: country(s), city: city(s))
    }

    static func extraRoles(_ s: GameState, office: String) -> [Role] {
        guard let o = satellite(s, office) else { return extraRoles(s) }
        let c = CountryCatalog.get(o.country)
        return c.id == "us" ? [] : extraRoles(s, country: c, city: c.city(o.city))
    }

    private static func extraRoles(_ s: GameState, country c: HQCountry, city: HQCity) -> [Role] {
        var roles = c.specialties + city.specialties
        // Chip designers are only on the market once you do silicon, except in a semiconductor town.
        if !s.bonuses.has(.customSilicon) || s.year <= 2018 { roles.removeAll { $0 == .chipDesigner } }
        if city.specialties.contains(.chipDesigner) && s.year > 2018 { roles.append(.chipDesigner) }
        return roles
    }

    /// Skill points local specialists bring.
    static func skillBonus(_ s: GameState, _ r: Role) -> Double {
        guard !isDefault(s) else { return chairSkill(s, r, country: s.hqCountry, city: s.hqCity) }
        return (country(s).specialties.contains(r) ? 2 : 0) + (city(s).specialties.contains(r) ? 2 : 0) + chairSkill(s, r, country: s.hqCountry, city: s.hqCity)
    }

    static func skillBonus(_ s: GameState, _ r: Role, office: String) -> Double {
        guard let o = satellite(s, office) else { return skillBonus(s, r) }
        let c = CountryCatalog.get(o.country)
        let city = c.city(o.city)
        let local: Double = c.id == "us" ? 0 : (c.specialties.contains(r) ? 2 : 0) + (city.specialties.contains(r) ? 2 : 0)
        return local + chairSkill(s, r, country: o.country, city: o.city)
    }

    /// How readily big foreign labs poach your people (1 = SF baseline).
    static func poachFactor(_ s: GameState) -> Double { isDefault(s) ? 1 : country(s).brainDrain }

    static func poachFactor(_ s: GameState, office: String) -> Double {
        guard let o = satellite(s, office) else { return poachFactor(s) }
        return CountryCatalog.get(o.country).brainDrain
    }

    // MARK: Offices (3.4 overhaul)

    static func satellite(_ s: GameState, _ office: String) -> SatelliteOffice? {
        office.isEmpty ? nil : s.hq.satellites.first { $0.id.uuidString == office }
    }

    static func officeName(_ s: GameState, _ office: String) -> String {
        guard let o = satellite(s, office) else { return city(s).name }
        return CountryCatalog.get(o.country).city(o.city).name
    }

    /// People working in `office` ("" = headquarters).
    static func staffCount(_ s: GameState, office: String) -> Int {
        office.isEmpty ? s.employees.filter { satellite(s, $0.office) == nil }.count : s.employees.filter { $0.office == office }.count
    }

    static func satelliteSeats(_ s: GameState) -> Int { s.hq.satellites.reduce(0) { $0 + $1.seats } }

    /// Rent per seat-month in a city (SF: $1,800, the same as a floor in SF).
    static func seatRent(country: String, city: String) -> Double {
        let c = CountryCatalog.get(country)
        return 1_800 * (c.id == "us" ? 1 : c.city(city).office)
    }

    static func satelliteRent(_ s: GameState) -> Double {
        s.hq.satellites.reduce(0) { $0 + Double($1.seats) * seatRent(country: $1.country, city: $1.city) }
    }

    static let satelliteStartSeats = 50
    static let satelliteStep = 100
    static let satelliteMaxSeats = 1_000

    /// Opening an office: legal entity and recruiting (more abroad), plus three months' rent as fit-out.
    static func satelliteOpenCost(_ s: GameState, country: String, city: String) -> Double {
        let setup = country == s.hqCountry ? 250_000.0 : 600_000.0
        return setup + 3 * Double(satelliteStartSeats) * seatRent(country: country, city: city)
    }

    static func satelliteExpandCost(_ o: SatelliteOffice) -> Double {
        3 * Double(satelliteStep) * seatRent(country: o.country, city: o.city)
    }

    /// Candidates a satellite has on the market at once: a smaller recruiting reach than headquarters, from that city's
    /// pool (San Francisco: the deepest).
    static func satelliteTarget(_ s: GameState, _ o: SatelliteOffice) -> Int {
        let staff = staffCount(s, office: o.id.uuidString)
        let base = 3 + min(6, staff / 15)
        let c = CountryCatalog.get(o.country)
        let pool = (c.id == "us" ? 1 : c.talentPool * c.city(o.city).talent) * chairBoost(s, country: o.country, city: o.city)
        return max(2, Int((Double(base) * pool * Nations.candidateFactor(s, country: o.country)).rounded()))
    }

    /// Why this candidate can't be hired right now for want of a desk, or nil.
    static func seatError(_ s: GameState, _ c: Candidate) -> String? {
        guard !c.office.isEmpty else {
            return staffCount(s, office: "") >= Economy.office(s, s.officeLevel).capacity ? "Your office is full. Upgrade it on the Team page." : nil
        }
        guard let o = satellite(s, c.office) else { return "That office has closed." }
        return staffCount(s, office: c.office) >= o.seats ? "Your \(officeName(s, c.office)) office is full. Expand it on the Team page." : nil
    }

    static func hasSeat(_ s: GameState, _ c: Candidate) -> Bool { seatError(s, c) == nil }

    // MARK: Government

    /// Standing points with a region's government from where you're based.
    static func standingBonus(_ s: GameState, _ r: Region) -> Double {
        guard !isDefault(s) else { return 0 }
        let c = country(s)
        if r == c.region { return c.homeStanding }
        if r == .us { return c.usStanding }
        return 0
    }

    /// Standing from national partnerships you're funding in a region's countries (3.4 overhaul).
    static func partnershipStanding(_ s: GameState, _ r: Region) -> Double {
        let mine = s.hq.partners.filter { $0.active(s.date) && CountryCatalog.get($0.country).region == r }
        return min(8, mine.reduce(0) { $0 + ($1.kind == .computeCentre ? 4 : 2) })
    }

    /// University chairs you fund in a city: its candidate pool ×1.3 each (at most two count).
    static func chairBoost(_ s: GameState, country: String, city: String) -> Double {
        let n = s.hq.partners.filter { $0.kind == .universityChair && $0.active(s.date) && $0.country == country && $0.city == city }.count
        return 1 + 0.3 * Double(min(2, n))
    }

    static func chairSkill(_ s: GameState, _ r: Role, country: String, city: String) -> Double {
        guard r == .researcher, chairBoost(s, country: country, city: city) > 1 else { return 0 }
        return 3
    }

    /// Whether a national compute centre you co-fund at home is active (grant offers ×1.3).
    static func homeComputePartner(_ s: GameState) -> Bool {
        s.hq.partners.contains { $0.kind == .computeCentre && $0.country == s.hqCountry && $0.active(s.date) }
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

    /// Construction-cost factor for datacenters you build at home (1 elsewhere, and on anything you buy).
    static func buildCost(_ s: GameState, location: String) -> Double {
        guard !isDefault(s), location == country(s).homeLocation else { return 1 }
        return country(s).buildCost
    }

    /// Records the home incentive on a phase you just paid for.
    static func noteIncentive(_ s: inout GameState, gross: Double, net: Double) {
        guard gross > net else { return }
        s.hq.rebates += gross - net
    }

    /// Whether you serve from a datacenter in your home country: a ready site there with chips in it.
    static func hostedAtHome(_ s: GameState) -> Bool {
        let loc = country(s).homeLocation
        return s.sites.contains { site in
            (site.kind == .datacenter || site.kind == .colo) && site.locationID == loc && site.isReady(s.date)
                && s.owned.contains { $0.siteID == site.id && $0.count > 0 }
        }
    }

    // MARK: Monthly

    /// The safety score the public sector asks of a national contract.
    static let contractSafety = 40.0

    /// Partnerships pay out, national contracts are checked against their terms, then grants, compute allocations,
    /// partnership and contract offers (inbox only).
    static func monthly(_ s: inout GameState) {
        partnershipsMonthly(&s)
        guard !isDefault(s) else { return }
        enforceContracts(&s)
        let y = s.year
        let c = country(s)
        let ym = s.date.ym
        if let last = s.hq.lastOffer, GameCalendar.daysBetween(last, s.date) < 100 { return }
        if s.decisions.contains(where: { $0.kind.hasPrefix("hq_") }) { return }
        func roll(_ tag: String) -> Double { RivalIntel.unit("hq|\(s.lifecycleSalt)|\(tag)|\(ym.year)-\(ym.month)") }

        // A national contract: the home government buys from its own lab, sized by the home market.
        let best = s.releasedModels.max(by: { $0.c < $1.c })
        if y >= 2023.5, let best, best.c > Macro.frontier(y) - 2.0, !s.hq.offered.contains("contract|\(Int(y))"),
           roll("contract") < c.contractAffinity / 12 * clamp(s.world.ready ? s.world.government(c.region) / 60 : 1, 0.5, 1.5) * Nations.contractFactor(s) {
            s.hq.offered.insert("contract|\(Int(y))")
            s.hq.lastOffer = s.date
            let programme = c.programmes.first { $0.kind == .contract }
            let monthly = contractMonthly(s)
            let hosted = hostedAtHome(s)
            let loc = c.location?.name ?? c.name
            Events.addDecision(&s, kind: "hq_contract", title: "\(c.adjective) government contract: \(programme?.name ?? "public-sector AI")",
                               body: "\(programme?.pitch ?? "The government wants a national model.") \(Fmt.money(monthly))/month for 2 years on \(best.name), sized to \(c.name)'s public sector. Its terms: the model is hosted in \(c.name), and you keep a safety score of \(Int(contractSafety)) or more. Break either for two months running and it's cancelled.",
                               image: city(s).image,
                               options: [DecisionOption(label: "Sign: host on a \(c.adjective) sovereign cloud",
                                                        detail: "+\(Fmt.money(monthly * 0.85 * 24)) over 2 years after the provider's 15%. Standing at home +3, brand +1."),
                                         DecisionOption(label: "Decline", detail: "Keep your capacity for the market."),
                                         DecisionOption(label: "Sign: host it in your own datacenter",
                                                        detail: hosted ? "+\(Fmt.money(monthly * 24)) over 2 years, served from your site in \(loc). Standing at home +3, brand +1."
                                                                       : "+\(Fmt.money(monthly * 24)) over 2 years. You have no site in \(loc) with chips in it yet: build or lease one within two months, or the contract is cancelled.")],
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

        // Grants and compute allocations, from the programmes that exist this year.
        let grants = c.programmes.filter { $0.kind != .contract && y >= $0.from }
        guard !grants.isEmpty, roll("grant") < c.grantRate * Nations.grantFactor(s) else { return }
        let g = grants[Int(roll("which") * Double(grants.count)) % grants.count]
        let amount = (g.base * scale(y) / 50_000).rounded() * 50_000
        s.hq.lastOffer = s.date
        s.hq.grantOffers += 1
        let compute = g.kind == .compute
        Events.addDecision(&s, kind: "hq_grant", title: compute ? "Compute grant: \(g.name)" : "Grant offer: \(g.name)",
                           body: "\(g.pitch) \(compute ? "\(Fmt.money(amount)) in GPU hours, spent automatically on your rentals." : "\(Fmt.money(amount)), paid as the project starts.") You publish a summary of the results.",
                           image: city(s).image,
                           options: [DecisionOption(label: "Accept", detail: compute ? "+\(Fmt.money(amount)) cloud credits. Researchers' respect +1." : "+\(Fmt.money(amount)). Researchers' respect +1, standing at home +1."),
                                     DecisionOption(label: "Decline", detail: "Skip the paperwork.")],
                           amount: amount, ref: compute ? "compute" : "grant")
    }

    /// What a national contract pays a month: sized to the business and to the home market (France = 1; a market a
    /// sixth of the size pays about a quarter as much), and never more than a slice of what that state spends on AI
    /// (about 3% of the country's AI market a year, game estimate).
    static func contractMonthly(_ s: GameState) -> Double {
        let c = country(s)
        let market = pow(c.homeMarket / 0.03, 0.75)
        let state = 0.03 * c.homeMarket * Macro.marketSize(s.year) / 12
        let sized = max(3e6 * scale(s.year) * market, min(Economy.runRate(s) * 0.02 * market, state))
        return (sized / 1_000).rounded() * 1_000
    }

    /// Grants and allocations grow with the era (public AI budgets did).
    static func scale(_ y: Double) -> Double {
        interpolate([(2016, 0.5), (2020, 0.8), (2022, 1), (2024, 1.6), (2026, 2.5), (2030, 4), (2035, 6)], at: y, extrapolate: false)
    }

    /// National contracts in force: their terms are checked at each month end. Out of terms one month is a warning; two
    /// in a row and the government cancels.
    static func enforceContracts(_ s: inout GameState) {
        let c = country(s)
        let client = "\(c.adjective) government"
        for i in s.deals.indices where s.deals[i].active && s.deals[i].client == client && s.deals[i].title.hasPrefix("national AI programme") {
            let id = s.deals[i].id.uuidString
            s.hq.contractRevenue += s.deals[i].monthly
            var why: [String] = []
            if s.safetyScore < s.deals[i].minSafety { why.append("your safety score is \(Int(s.safetyScore)), below the \(Int(s.deals[i].minSafety)) its terms require") }
            if s.hq.ownHosted.contains(id) && !hostedAtHome(s) { why.append("it isn't served from a datacenter in \(c.name) with chips in it") }
            guard !why.isEmpty else { s.hq.strikes[id] = nil; continue }
            let n = (s.hq.strikes[id] ?? 0) + 1
            if n >= 2 {
                s.deals[i].active = false
                s.deals[i].monthsLeft = 0
                s.hq.strikes[id] = nil
                s.hq.ownHosted.remove(id)
                Stakeholders.move(&s, [c.region.rawValue: -4], "The \(client) cancelled its national AI contract")
                Sim.news(&s, "The \(client) cancels its national AI contract", "For a second month, \(why.joined(separator: " and ")). Standing at home −4.",
                         .company, important: true, good: false)
            } else {
                s.hq.strikes[id] = n
                Sim.news(&s, "National contract at risk", "The \(client) warns that \(why.joined(separator: " and ")). Fix it by next month or the contract is cancelled.",
                         .company, important: true, good: false)
            }
        }
    }

    /// Compute centres you co-fund deliver their priority GPU hours (40% of the stake over three years).
    static func partnershipsMonthly(_ s: inout GameState) {
        for p in s.hq.partners where p.kind == .computeCentre && p.active(s.date) {
            let hours = p.cost * 0.4 / Double(p.kind.months)
            s.cloudCredits += hours
            s.hq.partnerCredits += hours
        }
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
        case ("hq_contract", 0), ("hq_contract", 2):
            // Older saves offered two options (sign, decline): signing then meant the sovereign-cloud terms.
            let own = option == 2 && d.options.count == 3
            let monthly = own ? d.amount : d.amount * 0.85
            let model = UUID(uuidString: d.ref).flatMap { id in s.releasedModels.first { $0.id == id } } ?? s.releasedModels.max { $0.c < $1.c }
            let price = max(0.05, Macro.referencePrice(c: Macro.frontier(s.year) - 0.3, y: s.year) * s.market.apiPricePressure)
            var deal = EnterpriseDeal(client: "\(c.adjective) government", title: own ? "national AI programme (own datacenter)" : "national AI programme (sovereign cloud)",
                                      monthly: monthly, tokensPerDay: monthly / 30.4 / price * 1e6 * 0.5,
                                      months: 24, monthsLeft: 24, minIndex: 0, minSafety: contractSafety, expires: s.date, active: true)
            deal.modelID = model?.id
            if own { s.hq.ownHosted.insert(deal.id.uuidString) }
            s.deals.append(deal)
            s.hq.contracts += 1
            s.brand = min(100, s.brand + 1)
            Stakeholders.move(&s, [c.region.rawValue: 3], "Signed a national AI contract with the \(c.adjective) government")
            Sim.news(&s, "\(c.adjective) government contract signed",
                     "\(Fmt.money(monthly))/month for 2 years, \(own ? "served from your own datacenter in \(c.name)" : "hosted on a \(c.adjective) sovereign cloud (the provider keeps 15%)"). Keep a safety score of \(Int(contractSafety))+.",
                     .company, important: true, good: true)
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
                 "\(city.blurb) \(Fmt.pct(c.corporateTax, decimals: 1)) corporate tax\(c.rdCredit > 0 ? ", an R&D relief (\(c.rdScheme.short.lowercased()))" : ""), and \(c.adjective) public programmes will come knocking. International capital, cloud and datacenters are open to you as to anyone, and you can open offices abroad once you're growing.",
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

// MARK: - Player actions (3.4 overhaul)

extension GameState {
    /// Open an office in another city, at home or abroad: it hires from that city's pool at its pay and on-costs.
    mutating func openSatellite(country: String, city: String) -> String? {
        guard let c = CountryCatalog.byID[country], c.cities.contains(where: { $0.id == city }) else { return "Pick a city." }
        if country == hqCountry && city == hqCity { return "That's your headquarters." }
        if officeLevel < 1 { return "Move out of the garage first: a satellite needs a real company behind it." }
        if hq.satellites.contains(where: { $0.country == country && $0.city == city }) { return "You already have an office in \(c.city(city).name)." }
        if hq.satellites.count >= 6 { return "Six satellite offices is the most one company can run well." }
        let cost = HQ.satelliteOpenCost(self, country: country, city: city)
        if cost > cash { return "Opening it costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.capex += cost
        hq.satellites.append(SatelliteOffice(country: country, city: city, seats: HQ.satelliteStartSeats, opened: date))
        let name = c.city(city).name
        Sim.news(&self, "Office opened in \(name)",
                 "\(HQ.satelliteStartSeats) desks in \(name), \(c.name): local hiring at \(Fmt.pct(c.pay(c.city(city)), decimals: 0)) of San Francisco pay plus \(c.name)'s employer contributions, rent \(Fmt.money(Double(HQ.satelliteStartSeats) * HQ.seatRent(country: country, city: city)))/month. Set-up \(Fmt.money(cost)).\(country == hqCountry ? "" : " Staff there don't count for the home R&D relief.")",
                 .company, image: c.city(city).image, good: true)
        People.refreshCandidates(&self)
        return nil
    }

    /// Add 100 desks to a satellite office (three months' rent for them as fit-out).
    mutating func expandSatellite(_ id: UUID) -> String? {
        guard let i = hq.satellites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let o = hq.satellites[i]
        if o.seats >= HQ.satelliteMaxSeats { return "\(Int(HQ.satelliteMaxSeats)) desks is as big as a satellite gets. Open another office." }
        let cost = HQ.satelliteExpandCost(o)
        if cost > cash { return "Expanding costs \(Fmt.money(cost))." }
        cash -= cost
        month.capex += cost
        hq.satellites[i].seats += HQ.satelliteStep
        return nil
    }

    /// Close a satellite office: everyone there is let go with severance.
    mutating func closeSatellite(_ id: UUID) -> String? {
        guard let i = hq.satellites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let key = id.uuidString
        let staff = employees.filter { $0.office == key }
        let severance = staff.reduce(0) { $0 + $1.salary * 0.25 }
        if severance > cash { return "Letting the \(staff.count) people there go costs \(Fmt.money(severance)) in severance." }
        for e in staff { fire(e.id) }
        candidates.removeAll { $0.office == key }
        let name = HQ.officeName(self, key)
        hq.satellites.remove(at: i)
        Sim.news(&self, "Office closed: \(name)", staff.isEmpty ? "The desks are handed back." : "\(staff.count) people let go, \(Fmt.money(severance)) in severance.", .company, good: staff.isEmpty ? nil : false)
        return nil
    }

    /// Co-fund a national compute centre or endow a university chair in a country's city.
    mutating func signNationalPartnership(_ kind: PartnershipKind, country: String, city: String) -> String? {
        guard let c = CountryCatalog.byID[country], c.cities.contains(where: { $0.id == city }) else { return "Pick a city." }
        if hq.partners.contains(where: { $0.kind == kind && $0.country == country && $0.active(date) }) {
            return kind == .computeCentre ? "You already co-fund \(c.name)'s compute centre." : "You already fund a chair in \(c.name)."
        }
        let cost = Nations.partnershipCost(kind, self)
        if cost > cash { return "That costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.costOther += cost
        hq.partners.append(NationalPartnership(kind: kind, country: country, city: city, cost: cost, signed: date, until: GameCalendar.addMonths(date, kind.months)))
        let place = "\(c.city(city).name), \(c.name)"
        switch kind {
        case .computeCentre:
            brand = min(100, brand + 1)
            Stakeholders.move(&self, ["researchers": 1, c.region.rawValue: 2], "Co-invested in \(c.name)'s national compute centre")
            Sim.news(&self, "\(companyName) co-invests in \(c.name)'s national compute centre",
                     "\(Fmt.money(cost)) towards public AI compute near \(place). You get priority GPU hours worth \(Fmt.money(cost * 0.4)) over three years; \(c.adjective) policymakers take note at their January review.",
                     .finance, image: c.city(city).image, important: true, good: true)
        case .universityChair:
            Stakeholders.move(&self, ["researchers": 2, c.region.rawValue: 1], "Endowed a university chair in \(place)")
            Sim.news(&self, "\(companyName) endows a chair in \(c.city(city).name)",
                     "\(Fmt.money(cost)) for five years of AI research and teaching in \(place): more graduates and stronger researchers on that city's job market.",
                     .research, image: c.city(city).image, good: true)
        }
        return nil
    }
}
