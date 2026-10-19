import Foundation

extension ScenarioHarness {
    /// Cluj-Napoca, from 2022: lean, specialist coding models, profit early, then international rounds, an office in
    /// Bucharest, a university chair at home and later an office in Paris to keep hiring, and a fight with
    /// the big labs. Checks that the home talent pool stops binding as the company grows, that the R&D relief only
    /// counts against profit (and carries forward), Romania's 2024 minimum turnover tax and the 2025 US chip rule.
    static func scenarioB() -> Report {
        var r = Report(id: "B", title: all.first { $0.id == "B" }?.title ?? "B")
        var s = newGame(era: "2022", hq: "ro", city: "cluj", seed: hqSeed(22), name: "Carpathia AI")
        var bot = PTBot()
        bot.flags = ["lean", "coding", "advproj", "fillroles"]
        let start = s.date
        let base = 8 + min(8, s.employees.count / 20)
        let poolStart = HQ.candidateTargets(s, base)
        var poolLater: (local: Int, total: Int)? = nil
        var capFeb2025 = 1.0, capJun2025 = 1.0, chipsFeb2025 = 1.0, chipsJun2025 = 1.0
        var reliefWhileLossMaking = 0.0, carryWhileLossMaking = 0.0
        var firstProfit: Date? = nil
        var lossMonths = 0
        var lastCredits = 0.0
        var office: UUID? = nil, abroad: UUID? = nil, chair: Date? = nil
        var localBeforeChair = 0, localAfterChair = 0
        let months = hqPlay(&s, &bot, months: 78) { s, m in
            if m == 36 { poolLater = HQ.candidateTargets(s, 8 + min(8, HQ.staffCount(s, office: "") / 20)) }
            // Growing past the home city: an office in Bucharest (a second Romanian pool at Romanian pay), then a
            // university chair in Cluj for a deeper local pool.
            if office == nil, m >= 12, s.employees.count >= 30, s.cash > 50 * HQ.satelliteOpenCost(s, country: "ro", city: "bucharest"),
               s.openSatellite(country: "ro", city: "bucharest") == nil {
                office = s.hq.satellites.last?.id
            }
            if chair == nil, m >= 18, s.cash > 30 * Nations.partnershipCost(.universityChair, s) {
                let base = 8 + min(8, HQ.staffCount(s, office: "") / 20)
                localBeforeChair = HQ.candidateTargets(s, base).local
                if s.signNationalPartnership(.universityChair, country: "ro", city: "cluj") == nil {
                    chair = s.date
                    localAfterChair = HQ.candidateTargets(s, base).local
                }
            }
            // Abroad once the company is international: an office in Paris for Europe's deepest research pool.
            if office != nil, abroad == nil, m >= 30, s.cash > 50 * HQ.satelliteOpenCost(s, country: "fr", city: "paris"),
               s.openSatellite(country: "fr", city: "paris") == nil {
                abroad = s.hq.satellites.last?.id
            }
            for o in s.hq.satellites where HQ.staffCount(s, office: o.id.uuidString) >= o.seats - 5 && s.cash > 100 * HQ.satelliteExpandCost(o) {
                _ = s.expandSatellite(o.id)
            }
            let ym = s.date.ym
            if ym.year == 2025 && ym.month == 2 { capFeb2025 = Nations.exportCapFactor(s); chipsFeb2025 = Nations.chipFactor(s) }
            if ym.year == 2025 && ym.month == 6 { capJun2025 = Nations.exportCapFactor(s); chipsJun2025 = Nations.chipFactor(s) }
        }
        // Walk the books: relief and carry while making losses, and when profit first came.
        for (i, mo) in months.enumerated() {
            if mo.pre <= 0 {
                lossMonths += 1
                reliefWhileLossMaking += mo.relief
                carryWhileLossMaking = max(carryWhileLossMaking, mo.rdCarry)
            }
            if firstProfit == nil && mo.opProfit > 0 && mo.taxes > 0 { firstProfit = mo.date }
            lastCredits = mo.rdCredits
        }
        r.note("ended \(s.date.gameShort): staff \(s.employees.count), valuation \(hqMoney(s.valuation)), rounds \(s.rounds.count - 1), satellites \(s.hq.satellites.map { HQ.officeName(s, $0.id.uuidString) })")

        // Lean and profitable.
        let years = firstProfit.map { Double(GameCalendar.daysBetween(start, $0)) / 365 } ?? 99
        r.expect("profitable within three years", years <= 3, firstProfit.map { "first taxed profitable month \($0.gameShort), \(Fmt.trim(years, 1)) years in" } ?? "never")
        // International capital: rounds priced by global funds once the company is big.
        let late = s.rounds.dropFirst().filter { HQ.investorFactor(s, value: $0.preMoney) / max(0.0001, Nations.recessionInvestorFactor(s)) > 0.999 }
        r.expect("raises international rounds at global prices", !late.isEmpty && HQ.investorFactor(s, value: 0) < 0.85,
                 "seed priced ×\(Fmt.trim(HQ.investorFactor(s, value: 0) / max(0.0001, Nations.recessionInvestorFactor(s)), 2)) by local investors; \(late.count) later rounds at ×1 (largest \(hqMoney(late.map(\.amount).max() ?? 0)) at \(hqMoney(late.map(\.preMoney).max() ?? 0)) pre)")
        // No HQ-driven cap on hiring.
        let atFive = months.indices.contains(59) ? months[59].staff : months.last?.staff ?? 0
        r.expect("hiring keeps up: past 100 staff by year five", atFive > 100, "\(atFive) staff after 60 months (\(s.employees.count) at the end)")
        if let later = poolLater {
            r.expect("the home talent pool widens as the company becomes known", later.total > poolStart.total && later.total >= base,
                     "candidates at once: \(poolStart.local) local of \(poolStart.total) at the start → \(later.local) local of \(later.total) after three years (San Francisco: \(base)+)")
        }
        if let id = office {
            let key = id.uuidString
            let pay = hqLocalPay(s, office: key)
            r.expect("a satellite office in Bucharest hires at Bucharest pay", HQ.staffCount(s, office: key) > 0 && abs(pay - 0.34) < 0.03,
                     "\(HQ.staffCount(s, office: key)) people there of \(s.hq.satellites.first { $0.id == id }?.seats ?? 0) desks; local candidates ×\(Fmt.trim(pay, 3)) of San Francisco pay (Bucharest ×0.34); rent \(hqMoney(HQ.satelliteRent(s)))/month")
        } else {
            r.expect("a satellite office opened", false)
        }
        if let id = abroad {
            let key = id.uuidString
            let staff = s.employees.filter { $0.office == key }
            let cost = staff.reduce(0) { $0 + $1.salary * HQ.payrollFactor(s, office: key) } / max(1, staff.reduce(0) { $0 + $1.salary })
            r.expect("the Paris office pays French on-costs, outside the Romanian R&D relief", staff.isEmpty || abs(cost - 1.35) < 1e-9,
                     "\(staff.count) people in Paris at French employer on-costs ×\(Fmt.trim(staff.isEmpty ? 1.35 : cost, 2)); Romanian R&D spend this month \(hqMoney(HQ.rdSpendMonth(s))) excludes them")
        }
        r.expect("a university chair deepens the home pool", chair != nil && localAfterChair > localBeforeChair,
                 "signed \(chair?.gameShort ?? "never"): local candidates at once \(localBeforeChair) → \(localAfterChair)")
        let best = months.map(\.rank).filter { $0 > 0 }.min() ?? 99
        r.expect("competes with the big labs", best <= 3, "best rank #\(best); \(months.filter { $0.rank == 1 }.count) months at #1, \(months.filter { $0.rank > 0 && $0.rank <= 3 }.count) in the top three")
        // R&D relief only against profit, carried forward meanwhile.
        r.expect("R&D relief pays nothing while loss-making, and carries forward", lossMonths == 0 || (reliefWhileLossMaking < 1 && carryWhileLossMaking > 0),
                 "\(lossMonths) loss-making months: relief \(hqMoney(reliefWhileLossMaking)) paid, up to \(hqMoney(carryWhileLossMaking)) carried; \(hqMoney(lastCredits)) used against profit in all")
        // Romania's 1% minimum turnover tax (from 2024).
        let y24 = s.history.filter { $0.month.ym.year == 2024 }
        let turnover = y24.reduce(0) { $0 + $1.revenue }
        let taxed = y24.reduce(0) { $0 + $1.taxes }
        r.expect("2024 profit tax at least 1% of turnover", turnover <= 54e6 || taxed >= 0.01 * turnover - 1,
                 "2024 turnover \(hqMoney(turnover)), profit tax \(hqMoney(taxed)) (floor \(hqMoney(0.01 * turnover))); top-ups paid \(hqMoney(s.hq.minimumTax))")
        // The 2025 US AI Diffusion Rule: Romania was Tier 2.
        r.expect("US diffusion rule rations Tier 2 chips, then lifts", capFeb2025 == 0.6 && capJun2025 == 1 && chipsFeb2025 > chipsJun2025 + 0.02,
                 "February 2025: allocation ×\(Fmt.trim(capFeb2025, 2)), chip prices ×\(Fmt.trim(chipsFeb2025, 3)); June 2025: allocation ×\(Fmt.trim(capJun2025, 2)), chip prices ×\(Fmt.trim(chipsJun2025, 3))")
        sanity(s, &r)
        return r
    }
}
