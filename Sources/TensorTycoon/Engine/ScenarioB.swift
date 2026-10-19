import Foundation

extension ScenarioHarness {
    /// Cluj-Napoca, from 2022: lean, specialist coding models, profit early, then international rounds and a fight with
    /// the big labs. Checks that the home talent pool stops binding as the company grows, that the R&D relief only
    /// counts against profit (and carries forward), Romania's 2024 minimum turnover tax and the 2025 US chip rule.
    static func scenarioB() -> Report {
        var r = Report(id: "B", title: all.first { $0.id == "B" }?.title ?? "B")
        var s = newGame(era: "2022", hq: "ro", city: "cluj", seed: 22, name: "Carpathia AI")
        var bot = PTBot()
        bot.flags = ["lean", "coding", "advproj"]
        let start = s.date
        let base = 8 + min(8, s.employees.count / 20)
        let poolStart = HQ.candidateTargets(s, base)
        var poolLater: (local: Int, total: Int)? = nil
        var capFeb2025 = 1.0, capJun2025 = 1.0, chipsFeb2025 = 1.0, chipsJun2025 = 1.0
        var reliefWhileLossMaking = 0.0, carryWhileLossMaking = 0.0
        var firstProfit: Date? = nil
        var lossMonths = 0
        var lastCredits = 0.0
        let months = hqPlay(&s, &bot, months: 78) { s, m in
            if m == 36 { poolLater = HQ.candidateTargets(s, 8 + min(8, HQ.staffCount(s, office: "") / 20)) }
            let ym = s.date.ym
            if ym.year == 2025 && ym.month == 2 { capFeb2025 = Nations.exportCapFactor(s); chipsFeb2025 = Nations.chipFactor(s) }
            if ym.year == 2025 && ym.month == 6 { capJun2025 = Nations.exportCapFactor(s); chipsJun2025 = Nations.chipFactor(s) }
        }
        // Walk the books: relief and carry while making losses, and when profit first came.
        for (i, mo) in months.enumerated() {
            let prev = i > 0 ? months[i - 1].rdCredits : 0
            if mo.pre <= 0 {
                lossMonths += 1
                reliefWhileLossMaking += mo.rdCredits - prev
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
