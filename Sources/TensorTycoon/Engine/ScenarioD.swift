import Foundation

extension ScenarioHarness {
    /// Grenoble, from 2022: a scientific lab funded by grants and the research tax credit, bidding for French and EU
    /// agency programmes and serving the state. Checks grants and public compute, the CIR (cash while small, its €100M
    /// cap), sovereign revenue, science output, the nuclear contract on offer, and that US federal rules stay out.
    static func scenarioD() -> Report {
        var r = Report(id: "D", title: all.first { $0.id == "D" }?.title ?? "D")
        var s = newGame(era: "2022", hq: "fr", city: "grenoble", seed: hqSeed(24), name: "Alpes Recherche")
        var bot = PTBot()
        bot.flags = ["advproj", "science", "fillroles"]
        var smeRelief = 0.0, smeLossMonths = 0
        var reported = false
        var partnered: Date? = nil
        var grantFactorBefore = 0.0, grantFactorAfter = 0.0
        let months = hqPlay(&s, &bot, months: 78) { s, m in
            // The US executive-order reporting fee (late 2023 to early 2025) would show up as this headline.
            if s.news.contains(where: { $0.title == "Training run reported to the US government" && GameCalendar.daysBetween($0.date, s.date) <= 40 }) { reported = true }
            // A sovereign partnership: co-fund the national compute centre once the company can easily afford it.
            if partnered == nil, m >= 6, s.cash > 30 * Nations.partnershipCost(.computeCentre, s) {
                grantFactorBefore = Nations.grantFactor(s)
                if s.signNationalPartnership(.computeCentre, country: "fr", city: "paris") == nil {
                    partnered = s.date
                    grantFactorAfter = Nations.grantFactor(s)
                }
            }
        }
        for (i, mo) in months.enumerated() where i > 0 && mo.pre <= 0 && mo.staff < 250 {
            smeLossMonths += 1
            smeRelief += mo.relief
        }
        r.note("ended \(s.date.gameShort): staff \(s.employees.count), valuation \(hqMoney(s.valuation)), \(s.science.labs.count) science labs, \(s.advanced.programmes.count) agency programmes")

        // Research funding: grants, public compute, the CIR.
        let h = s.hq
        let years = Double(months.count) / 12
        r.expect("co-funding the national compute centre lifts grant offers", partnered != nil && grantFactorAfter >= grantFactorBefore * 1.29,
                 "signed \(partnered?.gameShort ?? "never"): grant offers ×\(Fmt.trim(grantFactorBefore, 2)) → ×\(Fmt.trim(grantFactorAfter, 2)); GPU hours so far \(hqMoney(h.partnerCredits))")
        r.expect("grants and public compute received", h.grants + h.computeGrants > 0 && h.grantOffers >= 2,
                 "\(h.grantOffers) offers in \(Fmt.trim(years, 1)) years (\(Fmt.trim(Double(h.grantOffers) / years, 2))/yr; selection screen expects ≈\(Fmt.trim(HQ.country(s).expectedGrantsAtStart(2022.7), 1))/yr): \(hqMoney(h.grants)) in grants, \(hqMoney(h.computeGrants)) in compute")
        r.expect("the CIR pays cash while small and loss-making", smeLossMonths == 0 || smeRelief > 0,
                 "\(smeLossMonths) loss-making months under 250 staff: \(hqMoney(smeRelief)) paid; \(hqMoney(h.rdCredits)) of relief in all")
        // The CIR cap, on the company as it ends: what the relief would be at ten times the payroll.
        var big = s
        for i in big.employees.indices { big.employees[i].salary *= 10 }
        let spend = HQ.rdSpendMonth(big)
        let cap = 108_000_000.0 / 12
        big.hq.rdCarry = 0
        let relief = HQ.rdRelief(&big, tax: 0, pre: 1)
        let expected = 0.30 * min(spend, cap) + 0.05 * max(0, spend - cap)
        let afterTax = big.hq.rdCarry
        r.expect("CIR: 30% up to €100M of R&D a year, 5% above", spend > cap && abs((relief + afterTax) - expected) < 1 && expected < 0.3 * spend * 0.9,
                 "monthly R&D spend \(hqMoney(spend)) (cap \(hqMoney(cap))): credit \(hqMoney(relief + afterTax)) = 30% of \(hqMoney(min(spend, cap))) + 5% of \(hqMoney(max(0, spend - cap))), against an uncapped \(hqMoney(0.3 * spend))")
        // Sovereign and government work.
        let french = s.advanced.programmes.filter { p in (p.agency?.country == "fr") || (p.agency?.region == .eu && (p.agency?.country.isEmpty ?? false)) }
        let agencyRevenue = french.reduce(0) { $0 + $1.revenue }
        r.expect("sovereign and government revenue", h.contractRevenue + agencyRevenue > 0,
                 "national contracts \(h.contracts) (\(hqMoney(h.contractRevenue))); French and EU agency programmes \(french.count) (\(hqMoney(agencyRevenue)))")
        // Science.
        let done = s.science.projects.filter { $0.status == .done }.count
        r.expect("science lab output", done >= 1 || !s.science.discoveries.isEmpty,
                 "\(s.science.labs.map(\.name).joined(separator: ", ")): \(done) projects done, \(s.science.discoveries.count) discoveries, licences \(hqMoney(s.science.licensing))")
        // Power and rules.
        let nuclear = Power.quote(.nuclearContract, locationID: "fr_rhone", siteID: nil, mw: 100, s)
        r.expect("long-term nuclear contracts in the Rhône valley", (nuclear.error == nil || nuclear.error?.contains("costs") == true) && nuclear.priceMWh >= 55 && nuclear.priceMWh <= 70,
                 "\(hqMoney(nuclear.priceMWh))/MWh vs the Rhône grid at \(hqMoney((LocationCatalog.byID["fr_rhone"]?.powerPrice ?? 0) * 1000))/MWh; Power.quote error: \(nuclear.error ?? "none")")
        let window = s.runs.filter { $0.flopsTotal >= 1e26 && $0.started.decimalYear >= 2023.83 && $0.started.decimalYear < 2025.06 }.count
        r.expect("US federal rules stay out of a French lab training at home", !Policy.usPresence(s) && !reported,
                 "\(window) runs above 10^26 FLOP started while the 2023 executive order stood; US reporting fee charged: \(reported); US presence: \(Policy.usPresence(s))")
        r.expect("French tax", HQ.taxRate(s) == 0.258, "corporate tax \(Fmt.pct(HQ.taxRate(s), decimals: 1))")
        let best = months.map(\.rank).filter { $0 > 0 }.min() ?? 99
        r.expect("a contender", best <= 3, "best rank #\(best), \(months.filter { $0.rank == 1 }.count) months at #1")
        sanity(s, &r)
        return r
    }
}
