import Foundation

extension ScenarioHarness {
    /// Turin, from 2022: industrial AI. A robotics science lab next to the automation suppliers, the industrial
    /// partnership offers that come with them, a Robotics Brain product line, and Italy's R&D credit (offset against
    /// payroll taxes, capped) and power.
    static func scenarioC() -> Report {
        var r = Report(id: "C", title: all.first { $0.id == "C" }?.title ?? "C")
        var s = newGame(era: "2022", hq: "it", city: "turin", seed: 23, name: "Officina AI")
        var bot = PTBot()
        bot.flags = ["advproj", "science"]
        var lab: UUID? = nil
        // The research behind the Robotics Brain, sampled each month to catch the partners' contribution.
        let research = ProductLines.byID["robotics"]?.research ?? ""
        let cost = ResearchCatalog.byID[research]?.cost ?? 1
        var lastProgress = 0.0, lastPartnerships = 0
        var jump: (before: Double, after: Double, date: Date)? = nil
        let months = hqPlay(&s, &bot, months: 84) { s, _ in
            // A robotics lab in Turin as soon as it's affordable (the bot's science step then runs its projects).
            if lab == nil, s.science.labs.isEmpty, s.cash > 20 * Science.capex(.robotics, site: "turin", s) {
                if s.buildLab(.robotics, site: "turin", staff: 8) == nil { lab = s.science.labs.last?.id }
            }
            let now = s.researched.contains(research) ? cost : (s.researchProgress[research] ?? 0)
            if s.hq.partnerships > lastPartnerships && s.hq.offered.contains("partner|robotics") && jump == nil {
                jump = (lastProgress, now, s.date)
            }
            lastPartnerships = s.hq.partnerships
            lastProgress = now
        }
        r.note("ended \(s.date.gameShort): staff \(s.employees.count), valuation \(hqMoney(s.valuation)), product lines \(s.productLines.map(\.id).joined(separator: ", "))")

        // Local industry: robotics relief and pull.
        let robo = ProductLines.byID["robotics"]
        r.expect("Italian automation partners lower the Robotics Brain bars", robo.map { HQ.productRelief($0, s) } == 6 && robo.map { HQ.productPull($0, s) } == 1.25,
                 "relief \(robo.map { Fmt.trim(HQ.productRelief($0, s), 0) } ?? "?") domain points, pull ×\(robo.map { Fmt.trim(HQ.productPull($0, s), 2) } ?? "?")")
        r.expect("industrial partnership offered and signed", s.hq.partnerships >= 1 && s.hq.offered.contains("partner|robotics"),
                 "\(s.hq.partnerships) partnerships signed; robotics offer made: \(s.hq.offered.contains("partner|robotics"))")
        if let j = jump {
            r.expect("the partners do research for you", j.after - j.before >= cost * 0.4,
                     "\(ResearchCatalog.byID[research]?.name ?? research): \(Fmt.trim(j.before / cost * 100, 0))% → \(Fmt.trim(j.after / cost * 100, 0))% done in the month they joined (\(j.date.gameShort))")
        }
        // The product line.
        let line = s.productLines.first { $0.id == "robotics" }
        r.expect("Robotics Brain launched and earning", (line?.lifetime ?? 0) > 0,
                 line.map { "launched \($0.launched.gameShort), \(hqMoney($0.lifetime)) so far, \(hqMoney($0.lastRevenue))/month, share \(Fmt.pct($0.share))" } ?? "not launched")
        // The science lab: robotics research next to industry.
        if let id = lab, let l = s.science.labs.first(where: { $0.id == id }) {
            let mine = s.science.projects.filter { $0.lab == id }
            let done = mine.filter { $0.status == .done }.count
            let finds = s.science.discoveries.count
            r.expect("robotics lab produces results", done >= 1 || finds >= 1,
                     "\(l.name): \(mine.count) projects, \(done) done, \(finds) discoveries, licences \(hqMoney(s.science.licensing))")
        } else {
            r.expect("robotics lab built", false)
        }
        // Italian money rules.
        let lossMonths = months.filter { $0.pre <= 0 }
        let reliefInLosses = zip(months.dropFirst(), months).filter { $0.0.pre <= 0 }.reduce(0) { $0 + ($1.0.rdCredits - $1.1.rdCredits) }
        let yearsPlayed = Double(months.count) / 12
        r.expect("R&D credit offsets payroll taxes, so it pays while loss-making", lossMonths.isEmpty || reliefInLosses > 0,
                 "\(lossMonths.count) loss-making months, \(hqMoney(reliefInLosses)) of relief in them")
        r.expect("R&D credit capped at €5M a year", s.hq.rdCredits <= 5_400_000 * (yearsPlayed + 1) + 1,
                 "\(hqMoney(s.hq.rdCredits)) over \(Fmt.trim(yearsPlayed, 1)) years (cap \(hqMoney(5_400_000))/yr)")
        let solar = Power.quote(.solar, locationID: "it_milan", siteID: nil, mw: 10, s)
        r.expect("solar PPAs offered in Milan at Italian prices", solar.error == nil || solar.error?.contains("costs") == true,
                 "\(hqMoney(solar.priceMWh))/MWh against \(hqMoney(PowerKind.solar.priceMWh(s.year)))/MWh on the curve; Milan grid \(hqMoney(0.14 * 1000))/MWh; queue \(Int(Power.queueBase("it_milan"))) months base")
        r.expect("Italian tax and pay", HQ.taxRate(s) == 0.279 && abs(HQ.salaryFactor(s) - 0.42 * 0.92) < 1e-9,
                 "tax \(Fmt.pct(HQ.taxRate(s), decimals: 1)), Turin pay ×\(Fmt.trim(HQ.salaryFactor(s), 3)), on-costs ×\(Fmt.trim(HQ.payrollFactor(s), 2))")
        let best = months.map(\.rank).filter { $0 > 0 }.min() ?? 99
        r.expect("stays a contender", best <= 3, "best rank #\(best), \(months.filter { $0.rank == 1 }.count) months at #1")
        sanity(s, &r)
        return r
    }
}
