import Foundation

// MARK: - Shared steps for the headquarters scenarios (A–D)

extension ScenarioHarness {
    /// World rank of your best released model (0: none on the board).
    static func hqRank(_ s: GameState) -> Int {
        let board = Leaderboard.entries(s, set: Leaderboard.indexSet(s), includeUnreleased: false)
        guard let me = board.filter(\.isPlayer).max(by: { $0.index < $1.index }) else { return 0 }
        return board.filter { !$0.isPlayer && $0.index > me.index }.count + 1
    }

    /// One month-end sample of a headquarters game.
    struct HQMonth {
        var date: Date
        var rank: Int
        var staff: Int
        var opProfit: Double
        /// Pre-tax profit as the tax code saw it at the month's settlement (the books close more after it), and the
        /// taxable profit left after losses carried forward.
        var pre: Double
        var taxable: Double
        var rdCredits: Double
        var rdCarry: Double
        /// Tax charged at the settlement (after relief and any minimum-tax top-up), and the R&D relief in it.
        var taxes: Double
        var relief: Double
    }

    /// Plays `months` months with the playtest bot, calling `step` at the start of each month with its index, and
    /// samples the company at each month end.
    static func hqPlay(_ s: inout GameState, _ bot: inout PTBot, months: Int, step: (inout GameState, Int) -> Void) -> [HQMonth] {
        var out: [HQMonth] = []
        for m in 0..<months {
            step(&s, m)
            let start = s.date.ym
            var guardDays = 0
            while s.date.ym == start && guardDays < 40 && s.gameOver == nil {
                play(&s, &bot, days: 1)
                guardDays += 1
            }
            let h = s.history.last
            out.append(HQMonth(date: s.date, rank: hqRank(s), staff: s.employees.count, opProfit: (h?.revenue ?? 0) - (h?.opex ?? 0), pre: s.hq.taxProfit, taxable: s.hq.taxBase,
                               rdCredits: s.hq.rdCredits, rdCarry: s.hq.rdCarry, taxes: s.hq.taxCharged, relief: s.hq.taxRelief))
            if s.gameOver != nil { break }
        }
        return out
    }

    /// The newest datacenter chip you can buy and house at `site`, and how many fit (allocation, power, cash share).
    static func hqChipsFor(_ s: GameState, site: Site, budget: Double) -> (Accelerator, Int)? {
        let options = HardwareCatalog.all.filter { a in
            (a.cls == .datacenter || a.cls == .tpu) && Economy.canBuy(a, s) && Economy.price(a, s) != nil && Partners.blocker(a, s) == nil
                && a.tdpW <= site.maxChipTDP && (!a.liquid || site.cooling.supportsLiquidChips) && a.vendor != .custom
        }
        guard let a = options.max(by: { ($0.bf16, $0.id) < ($1.bf16, $1.id) }), let unit = Economy.price(a, s) else { return nil }
        let freeKW = max(0, site.capacityKW - Economy.siteLoadKW(s, site.id))
        var n = min(Double(Economy.allocationLimit(a, s)), budget / unit, freeKW / max(0.001, Economy.chipKW(a)))
        let step = Double(max(1, a.minOrder))
        n = (n / step).rounded(.down) * step
        return n >= step ? (a, Int(n)) : nil
    }

    /// Sends a share of cash on chips for a site that's ready (the step a player takes after a campus is energised).
    @discardableResult
    static func hqFillSite(_ s: inout GameState, _ siteID: UUID, share: Double) -> Int {
        guard let site = s.sites.first(where: { $0.id == siteID }), site.isReady(s.date),
              let (a, n) = hqChipsFor(s, site: site, budget: max(0, s.cash) * share) else { return 0 }
        return s.buyHardware(a.id, count: n, siteID: siteID) == nil ? n : 0
    }

    /// Chips actually housed (delivered) at a site.
    static func hqChipsAt(_ s: GameState, _ siteID: UUID) -> Int {
        s.owned.filter { $0.siteID == siteID }.reduce(0) { $0 + $1.count }
    }

    /// The same company under US rules, for side-by-side checks of what headquarters changes.
    static func hqAsIfUS(_ s: GameState) -> GameState {
        var us = s
        us.hqCountry = "us"
        us.hqCity = "sf"
        return us
    }

    /// Implied pay factor of ordinary local candidates (no star, no trait), against the San Francisco formula: forty
    /// candidates drawn on a copy of the game, so the game itself is untouched.
    static func hqLocalPay(_ s: GameState, office: String = "", relocated: Bool = false) -> Double {
        var t = s
        var ratios: [Double] = []
        for _ in 0..<40 {
            let c = People.makeCandidate(&t, star: false, office: office, relocated: relocated)
            guard c.trait.isEmpty else { continue }
            ratios.append(c.salary / max(1, Macro.salary(c.role, t.year) * pow(c.skill / 50, 1.6)))
        }
        return ratios.reduce(0, +) / Double(max(1, ratios.count))
    }

    /// Tax charged plus R&D relief over the last `n` months with taxable profit, against the taxable profit the tax
    /// code settled on (after losses carried forward): the statutory rate the game actually applied.
    static func hqEffectiveRate(_ months: [HQMonth], last n: Int = 12) -> (rate: Double, taxable: Double, pre: Double)? {
        var taxable = 0.0, pre = 0.0, charged = 0.0, used = 0
        for m in months.reversed() where used < n && m.taxable > 0 {
            taxable += m.taxable
            pre += m.pre
            charged += m.taxes + m.relief
            used += 1
        }
        return taxable > 0 ? (charged / taxable, taxable, pre) : nil
    }

    /// What the tax code charges on `pre` of taxable profit for this company, and for the same company under US rules
    /// (on copies with no losses carried forward, so the whole of `pre` is taxable).
    static func hqTaxOn(_ s: GameState, pre: Double) -> (home: Double, us: Double) {
        var home = s
        home.month = MonthRecord(month: s.month.month)
        home.corp.lossPool = 0
        HQ.settleTaxes(&home, pre: pre)
        var us = hqAsIfUS(s)
        us.month = MonthRecord(month: s.month.month)
        us.corp.lossPool = 0
        HQ.settleTaxes(&us, pre: pre)
        return (home.hq.taxCharged + home.hq.taxRelief, us.hq.taxCharged + us.hq.taxRelief)
    }

    static func hqMoney(_ v: Double) -> String { Fmt.money(v) }

    /// The scenario's seed, shifted by HQ_SCENARIO_SEED when set (to try the same checks on other paths).
    static func hqSeed(_ base: UInt64) -> UInt64 {
        base &+ (ProcessInfo.processInfo.environment["HQ_SCENARIO_SEED"].flatMap { UInt64($0) } ?? 0)
    }
}

// MARK: - A: Denmark

extension ScenarioHarness {
    /// Copenhagen, from 2022: a wind-powered home campus, a national compute-centre partnership, a datacenter abroad
    /// in Texas, and a race to the top three — with Danish tax, pay and power rules checked against US ones.
    static func scenarioA() -> Report {
        var r = Report(id: "A", title: all.first { $0.id == "A" }?.title ?? "A")
        var s = newGame(era: "2022", hq: "dk", city: "copenhagen", seed: hqSeed(21), name: "Fjord Labs")
        var bot = PTBot()
        bot.flags = ["advproj", "science", "fillroles"]
        let start = s.date
        let payStart = hqLocalPay(s)
        let payAbroad = hqLocalPay(s, relocated: true)
        var home: UUID? = nil, abroad: UUID? = nil
        var homeGross = 0.0, homeNet = 0.0, rebatesBefore = 0.0, abroadGross = 0.0
        var ppa: UUID? = nil
        var partnerSigned: Date? = nil
        var standingWhileActive = 0.0, grantFactorWhileActive = 0.0
        var subsidyBefore = 0.0, subsidyAfter = 0.0, boostBefore = 0.0, boostAfter = 0.0
        var countedAt: Date? = nil
        var usPresenceBefore = false
        let months = hqPlay(&s, &bot, months: 84) { s, m in
            // Year one: a 20 MW liquid-cooled campus at home on wind power, and a wind PPA to match.
            if home == nil, s.cash > 300e6 {
                let gross = 20 * Campus.capexPerMW(.liquid, s)
                rebatesBefore = s.hq.rebates
                if s.buildSite(kind: .datacenter, locationID: "dk_jutland", capacityKW: 20_000, cooling: .liquid, power: .wind, name: "Fredericia Campus") == nil {
                    home = s.sites.last?.id
                    homeGross = gross
                    homeNet = s.sites.last?.capex ?? 0
                }
            }
            if home != nil, ppa == nil, s.signPower(.wind, locationID: "dk_jutland", mw: 20, years: 15) == nil { ppa = s.powerContracts.last?.id }
            if let id = home, hqChipsAt(s, id) == 0, !s.orders.contains(where: { $0.siteID == id }) { hqFillSite(&s, id, share: 0.25) }
            // A research partnership: co-invest in Denmark's national compute centre.
            if partnerSigned == nil, m >= 14, s.cash > 30 * Nations.partnershipCost(.computeCentre, s) {
                subsidyBefore = Nations.level(s, country: "dk", .subsidy)
                boostBefore = s.nations.countries["dk"]?.boost[NationLever.subsidy.index] ?? 0
                if s.signNationalPartnership(.computeCentre, country: "dk", city: "copenhagen") == nil { partnerSigned = s.date }
            }
            if let p = partnerSigned, (60..<100).contains(GameCalendar.daysBetween(p, s.date)) {
                standingWhileActive = Stakeholders.governmentTarget(s, .eu).parts.first { $0.label == "National partnerships" }?.value ?? 0
                grantFactorWhileActive = Nations.grantFactor(s)
            }
            if partnerSigned != nil, countedAt == nil, s.hq.partners.first?.counted == true {
                countedAt = s.date
                subsidyAfter = Nations.level(s, country: "dk", .subsidy)
                boostAfter = s.nations.countries["dk"]?.boost[NationLever.subsidy.index] ?? 0
            }
            // Abroad: a campus in Texas once the company is big.
            if abroad == nil, m >= 30, s.cash > 2e9 {
                usPresenceBefore = Policy.usPresence(s)
                let gross = 50 * Campus.capexPerMW(.liquid, s)
                if s.buildSite(kind: .datacenter, locationID: "texas", capacityKW: 50_000, cooling: .liquid, power: .grid, name: "Abilene Campus") == nil {
                    abroad = s.sites.last?.id
                    abroadGross = gross
                }
            }
            if let id = abroad, hqChipsAt(s, id) == 0, !s.orders.contains(where: { $0.siteID == id }) { hqFillSite(&s, id, share: 0.1) }
        }
        let us = hqAsIfUS(s)
        r.note("ended \(s.date.gameShort): staff \(s.employees.count), valuation \(hqMoney(s.valuation)), best rank #\(months.map(\.rank).filter { $0 > 0 }.min() ?? 0), \(s.hq.satellites.count) satellite offices")

        // Danish rules against US ones.
        let probe = hqTaxOn(s, pre: 1e9)
        let probeOK = abs(probe.home - 0.22e9) < 1 && abs(probe.us - 0.21e9) < 1
        let probeText = "on $1B of taxable profit today: \(hqMoney(probe.home)) here vs \(hqMoney(probe.us)) under US rules (federal only)"
        if let t = hqEffectiveRate(months) {
            r.expect("Danish corporate tax charged on profit", abs(t.rate - 0.22) < 0.002 && probeOK,
                     "tax + R&D relief = \(Fmt.pct(t.rate, decimals: 2)) of \(hqMoney(t.taxable)) taxable profit (\(hqMoney(t.pre)) before losses carried forward) over the last 12 taxed months; \(probeText); losses still carried \(hqMoney(s.corp.lossPool))")
        } else {
            // Every profit so far went against losses carried forward: no tax may be charged on it, and the rate shows
            // on the probe alone.
            let profitable = months.filter { $0.pre > 0 }
            let untaxed = profitable.allSatisfy { $0.taxable == 0 && abs($0.taxes + $0.relief) < 1 }
            r.expect("Danish corporate tax charged on profit", untaxed && s.corp.lossPool > 0 && probeOK,
                     "\(profitable.count) profitable months, all set against losses carried forward (\(hqMoney(s.corp.lossPool)) still carried), none taxed; \(probeText)")
        }
        r.expect("Danish frontier-lab pay on local hires", abs(payStart - 0.651) < 0.03 && abs(payAbroad - 0.8255) < 0.03 && HQ.salaryFactor(us) == 1,
                 "local candidates ×\(Fmt.trim(payStart, 3)) of the San Francisco formula (Copenhagen ×0.651), relocating hires ×\(Fmt.trim(payAbroad, 3)) (×0.826) vs ×1 under US rules")
        r.expect("Danish employer on-costs", abs(HQ.payrollFactor(s) - 0.94) < 1e-9 && HQ.payrollFactor(us) == 1,
                 "payroll ×\(Fmt.trim(HQ.payrollFactor(s), 2)) vs ×\(Fmt.trim(HQ.payrollFactor(us), 2))")
        if let id = home, let site = s.sites.first(where: { $0.id == id }) {
            r.expect("home campus priced on Danish power", site.location.powerPrice < LocationCatalog.byID["nova"]!.powerPrice && site.powerDeal == .wind,
                     "\(site.location.name) grid $\(Fmt.trim(site.location.powerPrice, 3))/kWh vs Ashburn $0.085; deal \(site.powerDeal.rawValue)")
            r.expect("build incentive taken off at construction, net capex stored", abs(homeNet - homeGross * 0.93) < homeGross * 0.001 && s.hq.settled.isEmpty,
                     "first phase \(hqMoney(homeNet)) of \(hqMoney(homeGross)) gross (×0.93); incentive booked \(hqMoney(s.hq.rebates - rebatesBefore)); no monthly refunds")
            r.expect("home campus runs", site.isReady(s.date) && hqChipsAt(s, id) > 0, "\(Fmt.int(hqChipsAt(s, id))) chips housed")
        } else {
            r.expect("home campus built", false, "never had $300M")
        }
        if let id = ppa, let c = s.powerContracts.first(where: { $0.id == id }) {
            let curve = PowerKind.wind.priceMWh(c.signed.decimalYear)
            r.expect("wind PPA at the Nordic price", abs(c.priceMWh - curve * 0.72) < 0.01 && c.isOnline(s.date),
                     "\(hqMoney(c.priceMWh))/MWh vs \(hqMoney(curve))/MWh for US wind (×0.72), online \(c.online.gameShort); grid there \(hqMoney(c.location.powerPrice * 1000))/MWh")
        } else {
            r.expect("wind PPA signed", false)
        }
        // The partnership.
        if let p = partnerSigned {
            let cost = s.hq.partners.first?.cost ?? 0
            let paidMonths = Double(min(36, max(0, GameCalendar.daysBetween(p, s.date) / 30)))
            r.expect("partnership: priority GPU hours paid", s.hq.partnerCredits > 0 && abs(s.hq.partnerCredits - cost * 0.4 * paidMonths / 36) <= cost * 0.4 / 36 * 1.5,
                     "\(hqMoney(s.hq.partnerCredits)) of GPU hours from a \(hqMoney(cost)) stake signed \(p.gameShort) (40% over 36 months)")
            r.expect("partnership: Danish dials pushed at the next January review", countedAt != nil && boostAfter >= boostBefore * 0.7 + 2.7,
                     "signed \(p.gameShort), counted \(countedAt?.gameShort ?? "never"): subsidy boost \(Fmt.trim(boostBefore, 1)) → \(Fmt.trim(boostAfter, 1)), compute subsidies \(Int(subsidyBefore.rounded())) → \(Int(subsidyAfter.rounded()))")
            let policyOnly = 0.6 + 0.8 * Nations.level(s, country: "dk", .subsidy) / 100
            r.expect("partnership: standing and grant offers while it runs", standingWhileActive >= 4 && grantFactorWhileActive > 1.2,
                     "EU standing part +\(Fmt.trim(standingWhileActive, 0)) and grant offers ×\(Fmt.trim(grantFactorWhileActive, 2)) two months in (×\(Fmt.trim(policyOnly, 2)) on policy alone today)")
        } else {
            r.expect("partnership signed", false)
        }
        // Abroad.
        if let id = abroad, let site = s.sites.first(where: { $0.id == id }) {
            r.expect("datacenter abroad exists and runs", site.isReady(s.date) && hqChipsAt(s, id) > 0,
                     "\(site.name) in \(site.location.name): ready \(site.ready.gameShort), \(Fmt.int(hqChipsAt(s, id))) chips")
            r.expect("no home incentive abroad", abs(site.capex - abroadGross) < abroadGross * 0.001 || site.capex > abroadGross,
                     "Texas first phase \(hqMoney(abroadGross)) gross, stored \(hqMoney(site.capex))")
            r.expect("US federal rules reach the Texas site only", !usPresenceBefore && Policy.usPresence(s),
                     "US presence before \(usPresenceBefore), after \(Policy.usPresence(s))")
        } else {
            r.expect("datacenter abroad built", false)
        }
        let best = months.map(\.rank).filter { $0 > 0 }.min() ?? 99
        let top3 = months.filter { $0.rank > 0 && $0.rank <= 3 }.count
        r.expect("reaches the top three", best <= 3, "best rank #\(best), \(top3) of \(months.count) months in the top three, \(months.filter { $0.rank == 1 }.count) at #1")
        r.expect("hiring keeps growing", s.employees.count >= 80, "\(s.employees.count) staff after \(GameCalendar.daysBetween(start, s.date) / 365) years")
        sanity(s, &r)
        return r
    }
}
