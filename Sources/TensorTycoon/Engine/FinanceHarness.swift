import Foundation

/// `tt --finance-check`: gameplay checks for corporate finance (3.8). Each check plays the real actions on a game the
/// playtest bot has run for a while and compares what moved: the books reconcile after every kind of cash movement,
/// the valuation counts cash and debt (so borrowing to sit on cash or parking it in a subsidiary creates nothing),
/// loan limits are net of what's owed, payouts move the share price as they should, losses carry forward, programme
/// milestones stay out of the run rate, assets depreciate, bookings ramp, crises hit and pass, and stages gate what
/// they should while older saves keep what they built. Exits 1 when any check fails.
enum FinanceHarness {
    struct Check {
        let name: String
        let ok: Bool
        let detail: String
    }

    nonisolated(unsafe) static var checks: [Check] = []

    static func expect(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        checks.append(Check(name: name, ok: ok, detail: detail()))
    }

    /// Runs `act` and checks it left no cash the books can't explain.
    static func booked(_ name: String, _ s: inout GameState, _ act: (inout GameState) -> String?) {
        let before = Books.openResidual(s) ?? 0
        let err = act(&s)
        let after = Books.openResidual(s) ?? 0
        expect("books: \(name)", err == nil && abs(after - before) <= Books.tolerance(s.cash),
               err ?? "\(Fmt.money(after - before)) of cash unexplained")
    }

    /// Plays `days` with nobody acting and checks every day and every month close reconcile.
    static func idleBooked(_ name: String, _ s: inout GameState, days: Int) {
        var worst = 0.0
        for _ in 0..<days {
            let before = Books.openResidual(s) ?? 0
            let closed = s.history.count
            ScenarioHarness.idle(&s, days: 1)
            if s.history.count > closed, let r = Books.residual(s) { worst = max(worst, abs(r)) }
            worst = max(worst, abs((Books.openResidual(s) ?? 0) - (s.history.count > closed ? 0 : before)))
        }
        expect("books: \(name) (\(days) days)", worst <= Books.tolerance(s.cash), "worst \(Fmt.money(worst))")
    }

    static func main() -> Int32 {
        checks = []
        let start = Date()
        // A company two and a half years in, played by the bot: models, revenue, rounds, hardware.
        var base = ScenarioHarness.newGame(era: "2026", seed: 7)
        var bot = PTBot()
        ScenarioHarness.play(&base, &bot, days: 900)
        expect("the played game reconciles every month", (Books.worstResidual(base).map { abs($0.amount) } ?? 0) <= Books.tolerance(base.cash),
               Books.worstResidual(base).map { "\(Fmt.money($0.amount)) in \($0.month.gameMonth)" } ?? "")
        books(base)
        valuation(base)
        payouts(base)
        taxes()
        revenue(base)
        saves()
        ramp(base)
        crises(base)
        stages(base)
        arms(base)
        let bad = checks.filter { !$0.ok }
        for c in checks { print("\(c.ok ? "✓" : "✗") \(c.name)\(c.detail.isEmpty ? "" : ": \(c.detail)")") }
        print(bad.isEmpty ? "OK: \(checks.count) finance checks passed (\(Fmt.trim(Date().timeIntervalSince(start), 1)) s)" : "FAILED: \(bad.count) of \(checks.count) finance checks")
        return bad.isEmpty ? 0 : 1
    }

    /// Gives the test company money it started the month with (so the books stay balanced) and every stage.
    static func funded(_ s: GameState, _ amount: Double) -> GameState {
        var t = s
        t.cash += amount
        t.month.opening = (t.month.opening ?? t.cash - amount) + amount
        t.progression.stage = CompanyStage.civilisational.rawValue
        return t
    }

    // MARK: Books

    static func books(_ base: GameState) {
        var s = funded(base, 80e9)
        let home = Corporate.homeID(s)
        // Hardware: a colocation cage, chips bought, delivered, depreciated and some sold back.
        let loc = s.sites.first?.locationID ?? "nova"
        booked("colocation lease (first month's fee)", &s) { $0.buildSite(kind: .colo, locationID: loc, capacityKW: 4_000, cooling: .air, power: .grid, name: "Finance test cage") }
        let site = s.sites.last!.id
        if let a = HardwareCatalog.all.first(where: { Economy.canBuy($0, s) && $0.cls == .datacenter && Partners.blocker($0, s) == nil && $0.tdpW < 1_500 && !$0.liquid }) {
            let n = max(a.minOrder, 64 / max(1, a.minOrder) * max(1, a.minOrder))
            booked("buy \(n)× \(a.name)", &s) { $0.buyHardware(a.id, count: n, siteID: site) }
            idleBooked("delivery and the first depreciation", &s, days: Economy.leadTimeDays(a, s) + 35)
            expect("depreciation is charged on owned chips", (s.history.last?.costDepreciation ?? 0) > 0, "\(Fmt.money(s.history.last?.costDepreciation ?? 0)) last month")
            if let b = s.owned.first(where: { $0.accelID == a.id && $0.siteID == site }) {
                let cost = b.unitCost * Double(b.count)
                expect("owned chips are carried below cost once in use", Books.book(b, at: s.date) < cost, "\(Fmt.money(Books.book(b, at: s.date))) of \(Fmt.money(cost))")
                let gainsBefore = s.month.assetGains
                booked("sell \(b.count / 2) chips back", &s) { $0.sellHardware(batchID: b.id, count: b.count / 2) }
                expect("a hardware sale books its gain or loss against book value", s.month.assetGains != gainsBefore)
            }
        } else {
            expect("a datacenter chip is for sale to test with", false)
        }
        // Loans.
        for kind in [LoanKind.gpuBacked, .venture, .bank] {
            guard let q = Economy.loanQuotes(s).first(where: { $0.kind == kind }), q.available else { continue }
            booked("take a \(kind.rawValue.lowercased())", &s) { $0.takeLoan(kind, amount: q.max / 2, months: q.term) }
            if let l = s.loans.last { booked("repay it early", &s) { $0.repayLoan(l.id) } }
        }
        // Corporate debt.
        if let q = Corporate.quotes(s).first(where: { $0.available }) {
            booked("borrow on a \(q.kind.title.lowercased())", &s) { $0.borrowCorporate(q.kind, amount: q.max / 2) }
            if let d = s.corp.debts.last { booked("repay it", &s) { $0.repayCorporateDebt(d.id) } }
        }
        // People.
        if let c = s.candidates.first { booked("hire (signing bonus)", &s) { $0.hire(c.id) } }
        if let e = s.employees.last { booked("let someone go (severance)", &s) { $0.fire(e.id); return nil } }
        // Subsidiaries: start, fund, sell down, fold in; buy one; wind one down.
        let seed = Corporate.minSeed(.consulting, s, country: home) * 1.5
        booked("start a subsidiary", &s) { $0.startSubsidiary(.consulting, country: home, seed: seed) }
        let sub = s.corp.subs.last!.id
        booked("put more money in", &s) { $0.injectSubsidiary(sub, amount: 2e6) }
        idleBooked("subsidiary trading", &s, days: 70)
        booked("sell 20% of it", &s) { $0.sellSubsidiaryStake(sub, fraction: 0.2) }
        booked("fold it back in", &s) { $0.foldInSubsidiary(sub) }
        booked("wind the division down", &s) { $0.windDownSubsidiary(sub) }
        if let t = Corporate.targets(s).first(where: { s.subsidiaryBlocker($0.kind, country: $0.country) == nil && $0.price < s.cash }) {
            booked("buy a startup", &s) { $0.acquireSubsidiary(t.id) }
            if let bought = s.corp.subs.last {
                expect("a bought company can't be folded in for a year", s.foldInSubsidiary(bought.id)?.contains("for a year") == true, s.foldInSubsidiary(bought.id) ?? "allowed")
            }
        }
        idleBooked("a quiet stretch", &s, days: 40)
        // Going public, raising, paying out.
        if Economy.ipoEligible(s).0 {
            booked("IPO", &s) { $0.ipo() }
            booked("secondary offering", &s) { $0.secondaryOffering(fraction: min(0.02, $0.maxOfferingFraction)) }
            booked("declare a dividend", &s) { $0.setDividend(quarterly: max(1e6, $0.cash * 0.01)) }
            idleBooked("a quarter with a dividend", &s, days: 95)
            expect("the dividend was paid", s.corp.dividendsPaid > 0, Fmt.money(s.corp.dividendsPaid))
            booked("buy back shares", &s) { $0.buyback(amount: $0.cash * 0.05) }
        } else {
            expect("the test company can list", false, Economy.ipoEligible(s).1)
        }
        idleBooked("months closing after all that", &s, days: 70)
    }

    // MARK: Valuation

    static func valuation(_ base: GameState) {
        var s = funded(base, 5e9)
        s.isPublic = false
        let v0 = Economy.breakdown(s).equity
        if let q = Economy.loanQuotes(s).first(where: { $0.kind == .gpuBacked && $0.available }) ?? Economy.loanQuotes(s).first(where: { $0.available && $0.kind != .friends }) {
            var t = s
            _ = t.takeLoan(q.kind, amount: q.max, months: q.term)
            let v1 = Economy.breakdown(t).equity
            expect("borrowing to sit on cash creates no value", abs(v1 - v0) <= 1e-6 * v0 + 1, "\(Fmt.money(v0)) → \(Fmt.money(v1)) after borrowing \(Fmt.money(q.max))")
            let qAfter = Economy.loanQuotes(t).first { $0.kind == q.kind }?.max ?? 0
            expect("a loan limit is net of what you owe on it", qAfter < q.max * 0.01 + 1, "\(Fmt.money(q.max)) before, \(Fmt.money(qAfter)) after drawing it all")
        }
        var t = s
        let seed = 2e9
        _ = t.startSubsidiary(.consulting, country: Corporate.homeID(t), seed: seed)
        let v2 = Economy.breakdown(t).equity
        expect("moving cash into a subsidiary doesn't raise the valuation", v2 < v0, "\(Fmt.money(v0)) → \(Fmt.money(v2)) after moving \(Fmt.money(seed))")
        // Cash counts.
        var u = s
        u.cash += 1e9
        expect("cash counts in the valuation", abs(Economy.breakdown(u).equity - v0 - 1e9) < 1e3, Fmt.money(Economy.breakdown(u).equity - v0))
        // A private mark moves at most +60% a month between rounds.
        expect("a private mark moves at most +60% a month", Economy.smoothedMark(old: 1e8, new: 5e10, floor: 0) <= 1.6e8 + 1)
        // Folded-in divisions are valued at their own kind's multiple, not the lab's.
        var f = s
        if f.startSubsidiary(.consulting, country: Corporate.homeID(f), seed: 5e8) == nil, let i = f.corp.subs.indices.last {
            f.corp.subs[i].revenue = 1e8
            f.corp.subs[i].status = .folded
            f.history[f.history.count - 1].revGroup = 1e8
            let div = Corporate.divisionValue(f)
            let atLab = 1.2e9 * Macro.revenueMultiple(f.year)
            expect("a folded-in division is valued at its own multiple", div > 0 && div < atLab * 0.5, "\(Fmt.money(div)) vs \(Fmt.money(atLab)) at the lab's multiple")
        }
    }

    // MARK: Payouts

    static func payouts(_ base: GameState) {
        var s = funded(base, 20e9)
        guard Economy.ipoEligible(s).0, s.ipo() == nil else {
            expect("the test company can list for the payout checks", false, Economy.ipoEligible(s).1)
            return
        }
        let mcap = s.sharePrice * s.totalShares
        let p0 = s.sharePrice
        _ = s.setDividend(quarterly: mcap * 0.005)
        let p1 = s.sharePrice
        _ = s.setDividend(quarterly: mcap * 0.01)
        let p2 = s.sharePrice
        expect("a dividend raise moves the price once a quarter", p1 > p0 && p2 == p1, "\(Fmt.price(p0)) → \(Fmt.price(p1)) → \(Fmt.price(p2))")
        expect("the move is scaled by the yield it adds (at most 2%)", p1 / p0 - 1 <= 0.02 + 1e-9, Fmt.pct(p1 / p0 - 1, decimals: 2))
        // Ex-dividend.
        var t = s
        t.month.month = GameCalendar.date(t.date.ym.year, 3, 1)
        let before = t.sharePrice
        Corporate.payDividend(&t)
        let perShare = t.corp.dividendQuarterly / max(1, t.totalShares)
        expect("the price goes ex-dividend", abs(before - t.sharePrice - perShare) < 1e-6 * before + 1e-9, "\(Fmt.price(before)) → \(Fmt.price(t.sharePrice)), \(Fmt.price(perShare)) paid")
        // Spin-off: taxed, and the price falls by what left.
        var u = s
        _ = u.startSubsidiary(.consulting, country: Corporate.homeID(u), seed: 1e9)
        if let i = u.corp.subs.indices.last {
            u.corp.subs[i].founded = GameCalendar.addDays(u.date, -400)
            u.corp.subs[i].valuation = 3e9
            let value = u.corp.subs[i].stake * u.corp.subs[i].valuation
            let cash0 = u.founderCash, price0 = u.sharePrice, stake = u.founderStake
            let err = u.spinOffSubsidiary(u.corp.subs[i].id)
            expect("a spin-off pays your slice after capital-gains tax", err == nil && abs(u.founderCash - cash0 - value * stake * (1 - Treasury.capitalGainsTax)) < 1,
                   err ?? Fmt.money(u.founderCash - cash0))
            expect("a spin-off lowers the share price by the value per share", abs(price0 - u.sharePrice - value / u.totalShares) < 1e-6 * price0,
                   "\(Fmt.price(price0)) → \(Fmt.price(u.sharePrice))")
        }
    }

    // MARK: Taxes

    static func taxes() {
        var s = ScenarioHarness.newGame(era: "2022", seed: 3)
        s.month.taxes = 4e6   // an audit settled earlier in the month
        HQ.settleTaxes(&s, pre: 1e7)
        expect("an audit paid earlier in the month stays booked", abs(s.month.taxes - (4e6 + 2.1e6)) < 1, Fmt.money(s.month.taxes))
        var t = ScenarioHarness.newGame(era: "2022", seed: 3)
        HQ.settleTaxes(&t, pre: -1e7)
        expect("a loss goes into the pool", t.corp.lossPool == 1e7 && t.month.taxes == 0, Fmt.money(t.corp.lossPool))
        t.month.taxes = 0
        HQ.settleTaxes(&t, pre: 4e6)
        expect("profit uses the pool before it's taxed", t.month.taxes == 0 && abs(t.corp.lossPool - 6e6) < 1, "tax \(Fmt.money(t.month.taxes)), pool \(Fmt.money(t.corp.lossPool))")
        t.month.taxes = 0
        HQ.settleTaxes(&t, pre: 1e7)
        expect("only profit beyond the pool is taxed", abs(t.month.taxes - 4e6 * 0.21) < 1, Fmt.money(t.month.taxes))
        // A credit only set against profit (Romania) waits for tax to set it against.
        var ro = ScenarioHarness.newGame(era: "2022", hq: "ro", seed: 3)
        HQ.settleTaxes(&ro, pre: -1e6)
        let pool = ro.hq.rdCarry
        expect("an unusable Romanian R&D credit is carried forward", pool > 0, Fmt.money(pool))
        ro.month.taxes = 0
        HQ.settleTaxes(&ro, pre: 1e8)
        expect("and used against later tax", ro.hq.rdCarry < pool && ro.month.taxes < (1e8 - 1e6) * HQ.taxRate(ro), "carried \(Fmt.money(ro.hq.rdCarry)), tax \(Fmt.money(ro.month.taxes))")
        // Denmark pays out the tax value of an R&D loss, and that part of the loss isn't carried forward too.
        var dk = ScenarioHarness.newGame(era: "2022", hq: "dk", seed: 3)
        let cash0 = dk.cash
        HQ.settleTaxes(&dk, pre: -1e6)
        expect("a Danish R&D loss is partly paid out and the rest carried forward",
               dk.cash > cash0 && dk.corp.lossPool < 1e6 && abs(dk.corp.lossPool + (dk.cash - cash0) / HQ.taxRate(dk) - 1e6) < 1,
               "paid \(Fmt.money(dk.cash - cash0)), carried \(Fmt.money(dk.corp.lossPool))")
    }

    // MARK: Revenue lines

    static func revenue(_ base: GameState) {
        var s = base
        let rr = Economy.runRate(s)
        s.month.revContracts += 5e9
        s.history[s.history.count - 1].revContracts += 5e9
        expect("programme milestones stay out of the run rate", abs(Economy.runRate(s) - rr) <= 1e-6 * rr + 1, "\(Fmt.money(rr)) → \(Fmt.money(Economy.runRate(s)))")
        expect("but they are revenue", s.month.revenue >= 5e9)
    }

    // MARK: Saves

    static func saves() {
        let dec = SaveCoding.decoder()
        let old = try? dec.decode([CorpDebtKind].self, from: Data(#"["Covenanted term loan","Convertible note","Green bond"]"#.utf8))
        expect("debt kinds saved under their old display names still load", old == [.termLoan, .convertible, .greenBond])
        let new = (try? SaveCoding.encoder().encode([CorpDebtKind.greenBond])).flatMap { String(data: $0, encoding: .utf8) }
        expect("debt kinds are saved under stable codes", new == #"["greenBond"]"#, new ?? "")
        SaveRepairs.reset()
        let month = try? dec.decode(CorpMonth.self, from: Data(#"{"month": 0}"#.utf8))
        expect("a month of the books with fields missing still loads", month != nil && SaveRepairs.taken().isEmpty && month?.notch == -1)
        let corp = try? dec.decode(CorporateState.self, from: Data(#"{"engaged": true}"#.utf8))
        expect("a missing rating reads as not rated, not AAA", corp?.notch == -1, "\(corp?.notch ?? 99)")
        let legacy = try? dec.decode(CorporateState.self, from: Data(#"{"rating": -1}"#.utf8))
        expect("an older save's −1 rating still reads as not rated", legacy?.notch == -1)
    }

    // MARK: Booking ramp

    static func ramp(_ base: GameState) {
        var worst = 0.0, label = ""
        let h = base.history
        for i in 1..<h.count {
            let best = h[max(0, i - 3)..<i].map { $0.commercialRevenue / Double(GameCalendar.daysInMonth($0.month)) }.max() ?? 0
            let y = h[i].month.decimalYear + 1.0 / 12
            let allowed = Commercial.ramp(base: best * 30.44, market: Macro.marketSize(y) / 12, year: y) * 1.05
            let r = h[i].commercialRevenue / Double(GameCalendar.daysInMonth(h[i].month)) * 30.44 / max(1, allowed)
            if r > worst { worst = r; label = h[i].month.gameMonth }
        }
        expect("bookings never grow faster than the ramp allows", worst <= 1, "worst \(Fmt.pct(worst, decimals: 0)) of the allowance (\(label))")
        expect("demand beyond it is recorded as unbooked", h.contains { $0.revUnbooked > 0 && !$0.bookingLimit.isEmpty })
        var small = base
        small.employees = Array(small.employees.prefix(4))
        small.employees.removeAll { $0.role == .sales }
        var big = small
        if let e = small.employees.first {
            for _ in 0..<5 {
                var x = e
                x.id = UUID()
                x.role = .sales
                big.employees.append(x)
            }
        }
        expect("salespeople raise what the team can book", Commercial.capacity(big).team > Commercial.capacity(small).team * 2,
               "\(Fmt.money(Commercial.capacity(small).team)) → \(Fmt.money(Commercial.capacity(big).team))")
    }

    // MARK: Crises

    static func crises(_ base: GameState) {
        var s = base
        s.corp.cycle.active = []
        expect("no crisis, no effect", Crises.multipleFactor(s) == 1 && Crises.spreadAdd(s) == 0 && Crises.rateAdd(s) == 0 && Crises.roundFactor(s) == 1)
        let v0 = Economy.breakdown(s).equity
        let bank0 = Economy.loanQuotes(s).first { $0.kind == .bank }
        var c = s
        Crises.begin(&c, Crisis(kind: .correction, start: c.date, end: GameCalendar.addMonths(c.date, 10), severity: 0.8, cause: "Test."), headline: "Test", body: nil)
        expect("a correction cuts the valuation", Economy.breakdown(c).equity < v0, "\(Fmt.money(v0)) → \(Fmt.money(Economy.breakdown(c).equity))")
        expect("and hype (demand) with it", c.market.hype < s.market.hype)
        var k = s
        k.creditScore = 650
        Crises.begin(&k, Crisis(kind: .crunch, start: k.date, end: GameCalendar.addMonths(k.date, 6), severity: 0.8, cause: "Test."), headline: "Test", body: nil)
        let bank = Economy.loanQuotes(k).first { $0.kind == .bank }
        expect("a credit crunch closes bank loans to weaker credits", bank?.available == false, bank?.reason ?? "")
        expect("and widens spreads", Crises.spreadAdd(k) > 2, Fmt.trim(Crises.spreadAdd(k), 1))
        _ = bank0
        var r = s
        Crises.begin(&r, Crisis(kind: .rateShock, start: r.date, end: GameCalendar.addMonths(r.date, 18), severity: 0.6, cause: "Test."), headline: "Test", body: nil)
        r.date = GameCalendar.addMonths(r.date, 4)
        expect("a rate shock raises the policy rate", Crises.rateAdd(r) > 1.5, Fmt.trim(Crises.rateAdd(r), 2))
        // History plays on its dates; then the crisis passes.
        var h = ScenarioHarness.newGame(era: "2017", seed: 5)
        h.date = GameCalendar.date(2020, 3, 1)
        Crises.monthly(&h)
        expect("the March 2020 freeze is played", Crises.crunchSeverity(h) > 0)
        h.date = GameCalendar.date(2020, 8, 1)
        Crises.monthly(&h)
        expect("and it passes", Crises.crunchSeverity(h) == 0 && h.corp.cycle.past.contains { $0.kind == .crunch })
        // Rolled crises after the real timeline: odds scale with the bubble meter.
        expect("a frothy market is likelier to correct", Crises.correctionOdds(90) > 5 * Crises.correctionOdds(20))
    }

    // MARK: Subsidiaries that work on your own business

    static func arms(_ base: GameState) {
        var s = funded(base, 20e9)
        expect("without arms nothing changes", Corporate.powerFactor(s) == 1 && Corporate.attackFactor(s) == 1 && Corporate.bidBoost(s, region: HQ.region(s)) == 0)
        let home = Corporate.homeID(s)
        for k in [SubsidiaryKind.energy, .securitySoftware, .govResearch] {
            let err = s.startSubsidiary(k, country: home, seed: Corporate.minSeed(k, s, country: home) * 2)
            expect("start an arm: \(k.title.lowercased())", err == nil, err ?? "")
        }
        ScenarioHarness.idle(&s, days: 95)
        if (s.history.last?.costPower ?? 0) > 0 {
            expect("an energy arm cuts your power bill", Corporate.powerFactor(s) < 1, Fmt.pct(1 - Corporate.powerFactor(s), decimals: 2))
        }
        expect("a security arm makes attacks less likely to succeed", Corporate.attackFactor(s) < 1, Fmt.pct(1 - Corporate.attackFactor(s), decimals: 1))
        expect("a government research arm adds to bids at home", Corporate.bidBoost(s, region: HQ.region(s)) > 0, Fmt.trim(Corporate.bidBoost(s, region: HQ.region(s)), 2))
    }

    // MARK: Stages

    static func stages(_ base: GameState) {
        var s = base
        s.progression.stage = CompanyStage.startup.rawValue
        s.progression.grandfathered = []
        s.progression.grandfatheredSlots = 0
        s.corp.subs = []
        let why = s.subsidiaryBlocker(.consulting, country: Corporate.homeID(s)) ?? ""
        expect("a startup can't run subsidiaries", why.contains("Scale-up"), why)
        s.progression.stage = CompanyStage.scaleUp.rawValue
        expect("a scale-up can", s.subsidiaryBlocker(.consulting, country: Corporate.homeID(s)) == nil)
        let abroad = Corporate.jurisdictions.first { $0.id != Corporate.homeID(s) }!.id
        let reg = s.subsidiaryBlocker(.regional, country: abroad) ?? ""
        expect("regional entities need Frontier Lab", reg.contains("Frontier Lab"), reg)
        expect("classified work needs Frontier Lab", Progression.blocker(s, .classified)?.contains("Frontier Lab") == true)
        if let e = s.employees.first {
            let r = s.requestClearance(e.id, level: 1) ?? ""
            expect("clearances say which stage they need", r.contains("Frontier Lab"), r)
        }
        expect("fabs need Hyperscaler", Progression.blocker(s, .fabs)?.contains("Hyperscaler") == true)
        s.progression.stage = CompanyStage.hyperscaler.rawValue
        expect("a hyperscaler can build fabs and run big organisations", Progression.allows(s, .fabs) && Progression.allows(s, .bigOrgs) && !Progression.allows(s, .lateMoonshots))
        // An older save keeps what it already ran.
        var old = base
        old.progression.stage = CompanyStage.startup.rawValue
        old.progression.gatesChecked = false
        old.corp.subs = [Subsidiary(id: "x1", name: "Old Regional", kind: .regional, country: abroad, founded: old.date, ceo: "A", ceoSkill: 50),
                         Subsidiary(id: "x2", name: "Old Apps", kind: .consumerApps, country: Corporate.homeID(old), founded: old.date, ceo: "B", ceoSkill: 50),
                         Subsidiary(id: "x3", name: "Old Bio", kind: .bio, country: Corporate.homeID(old), founded: old.date, ceo: "C", ceoSkill: 50)]
        Progression.bootstrap(&old)
        expect("a save already running a regional entity keeps that door open", Progression.allows(old, .regional))
        expect("and keeps its subsidiaries", Progression.subsidiarySlots(old) >= 3, "\(Progression.subsidiarySlots(old)) slots")
    }
}
