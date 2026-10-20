import Foundation

/// 3.5: corporate. Subsidiaries with their own P&L, CEO, headcount, strategy and valuation; corporate debt with
/// covenants; a credit rating that moves with leverage and coverage; dividends, buybacks and tender offers; and the
/// books (income statement, balance-sheet approximation, cash flow, taxes, runway scenarios).
///
/// Nothing here runs for a company that never uses it: until `corp.engaged` the monthly pass only takes a read-only
/// snapshot for the statements, and every roll is hashed (no draws from the game's random numbers).
enum Corporate {
    // MARK: Ratings

    static let ratings = ["AAA", "AA", "A", "BBB", "BB", "B", "CCC", "D"]
    /// Credit spread over the policy rate for each notch (percentage points).
    static let spreads = [0.5, 0.75, 1.1, 1.6, 2.8, 4.5, 8.0, 14.0]
    /// Lowest score for each notch above D.
    static let bands: [Double] = [88, 78, 66, 54, 42, 30, 0]
    /// Licence fees (transfer prices) tax authorities accept without asking questions.
    static let armsLength: ClosedRange<Double> = 0.10...0.30
    static let maxSubsidiaries = 8

    static func ratingName(_ notch: Int) -> String { notch < 0 ? "Not rated" : ratings[min(notch, ratings.count - 1)] }
    static func investmentGrade(_ notch: Int) -> Bool { notch >= 0 && notch <= 3 }

    // MARK: Hashed randomness

    static func unit(_ s: GameState, _ tag: String) -> Double { RivalIntel.unit("corp|\(s.lifecycleSalt)|\(tag)") }
    static func monthKey(_ d: Date) -> String { "\(d.ym.year)-\(d.ym.month)" }

    // MARK: Jurisdictions

    /// Share of the world AI market each home country buys (regional entities sell into it).
    static let marketWeights: [String: Double] = ["us": 0.40, "fr": 0.03, "it": 0.025, "dk": 0.008, "ro": 0.005]

    static let extraJurisdictions: [Jurisdiction] = [
        Jurisdiction(id: "uk", name: "United Kingdom", flag: "🇬🇧", tax: 0.25, salary: 0.8, employerCost: 0.14, market: 0.045),
        Jurisdiction(id: "de", name: "Germany", flag: "🇩🇪", tax: 0.30, salary: 0.75, employerCost: 0.2, market: 0.045),
        Jurisdiction(id: "ie", name: "Ireland", flag: "🇮🇪", tax: 0.125, salary: 0.75, employerCost: 0.11, market: 0.01),
        Jurisdiction(id: "jp", name: "Japan", flag: "🇯🇵", tax: 0.30, salary: 0.6, employerCost: 0.15, market: 0.05),
        Jurisdiction(id: "sg", name: "Singapore", flag: "🇸🇬", tax: 0.17, salary: 0.7, employerCost: 0.17, market: 0.015),
        Jurisdiction(id: "in", name: "India", flag: "🇮🇳", tax: 0.25, salary: 0.2, employerCost: 0.12, market: 0.03),
        Jurisdiction(id: "ca", name: "Canada", flag: "🇨🇦", tax: 0.265, salary: 0.75, employerCost: 0.08, market: 0.025),
    ]

    static let jurisdictions: [Jurisdiction] = CountryCatalog.all.map {
        Jurisdiction(id: $0.id, name: $0.name, flag: $0.flag, tax: $0.corporateTax, salary: $0.salary, employerCost: $0.employerCost,
                     market: marketWeights[$0.id] ?? 0.02)
    } + extraJurisdictions

    static func jurisdiction(_ id: String) -> Jurisdiction { jurisdictions.first { $0.id == id } ?? jurisdictions[0] }

    static func homeID(_ s: GameState) -> String { CountryCatalog.byID[s.hqCountry] == nil ? "us" : s.hqCountry }

    // MARK: Economics

    /// How pay (and revenue per head) for a kind of business has moved since 2022.
    static func payScale(_ k: SubsidiaryKind, _ y: Double) -> Double { Macro.salary(k.payRole, y) / Macro.salary(k.payRole, 2022) }

    static func payPerHeadMonth(_ sub: Subsidiary, _ y: Double) -> Double {
        let j = jurisdiction(sub.country)
        return sub.kind.payPerHead * payScale(sub.kind, y) * j.salary * (1 + j.employerCost) / 12
    }

    static func revenuePerHeadMonth(_ k: SubsidiaryKind, _ y: Double) -> Double { k.revenuePerHead * payScale(k, y) / 12 }

    /// The most revenue a month this subsidiary's market allows.
    static func revenueCap(_ sub: Subsidiary, _ y: Double) -> Double {
        sub.kind.market(y) / 12 * (sub.kind == .regional ? jurisdiction(sub.country).market : 1) * sub.kind.maxShare
    }

    /// How good your models are against the frontier (0.25–1.3): subsidiaries built on them sell more.
    static func modelQuality(_ s: GameState) -> Double {
        guard let c = s.releasedModels.map(\.c).max() else { return 0.25 }
        return clamp(exp(1.2 * (c - Macro.frontier(s.year))), 0.25, 1.3)
    }

    /// Smallest seed a new subsidiary of this kind needs: 18 months of its first team plus set-up.
    static func minSeed(_ k: SubsidiaryKind, _ s: GameState, country: String) -> Double {
        let j = jurisdiction(country)
        let scale = payScale(k, s.year)
        let team = Double(k.baseTeam) * k.payPerHead * scale * j.salary * (1 + j.employerCost) * 1.5
        return ((team + k.setupCost * scale) / 100_000).rounded(.up) * 100_000
    }

    /// One month of a subsidiary's business: revenue, hiring, costs, the licence fee to you and its own tax.
    static func step(_ sub: inout Subsidiary, _ s: GameState) -> (revenue: Double, costs: Double, license: Double, tax: Double) {
        let y = s.year
        let k = sub.kind
        let q = 1 - k.modelDependence + k.modelDependence * modelQuality(s)
        let ceo = 0.7 + 0.6 * sub.ceoSkill / 100
        let cap = max(1, revenueCap(sub, y))
        let rph = revenuePerHeadMonth(k, y)
        let capacity = Double(sub.headcount) * rph * 1.1
        let room = clamp(1 - sub.revenue / cap, 0, 1)
        let noise = (unit(s, "noise|\(sub.id)|\(monthKey(s.month.month))") - 0.5) * 0.04
        var g = k.growth * (0.4 + 1.2 * sub.strategy) * q * ceo * room + noise
        let starved = sub.status == .active && sub.cash < 0
        if starved { g = min(g, 0.005) }
        let ramp = capacity * 0.04 * q * room
        var revenue = max(0, sub.revenue * (1 + g) + ramp)
        revenue = min(revenue, capacity, cap)
        revenue *= 1 - sub.shake
        sub.shake = 0

        // Hiring follows revenue: a growth strategy hires ahead of it, a cash strategy just behind it.
        var target = max(k.baseTeam, Int(revenue / rph * (1.05 + 0.6 * sub.strategy)))
        if starved { target = min(target, sub.headcount) }
        let diff = target - sub.headcount
        var move = Int((Double(diff) * 0.2).rounded())
        if move == 0 { move = diff.signum() }
        sub.headcount = max(3, sub.headcount + move)

        let pay = Double(sub.headcount) * payPerHeadMonth(sub, y)
        let cogs = revenue * (1 - k.grossMargin)
        let marketing = revenue * 0.25 * sub.strategy
        let scale = payScale(k, y)
        let overhead = Double(sub.headcount) * 15_000 * scale / 12 + (sub.isPublic ? 3e6 * scale / 12 : 0)
        let costs = pay + cogs + marketing + overhead
        let folded = sub.status == .folded
        let license = folded ? 0 : revenue * sub.transferRate
        let pre = revenue - costs - license
        let tax = folded ? 0 : max(0, pre) * jurisdiction(sub.country).tax
        sub.revenue = revenue
        return (revenue, costs, license, tax)
    }

    /// Annualised revenue growth (from the last quarter) and operating margin after the licence fee (last three months).
    static func growthAndMargin(_ sub: Subsidiary) -> (growth: Double, margin: Double) {
        let h = sub.history.suffix(3)
        let back = sub.history.count >= 4 ? sub.history[sub.history.count - 4].revenue : 0
        let growth = back > 0 ? clamp(pow(max(sub.revenue, 0) / back, 4) - 1, -0.5, 3) : (sub.revenue > 0 ? 0.4 : 0)
        let rev = h.reduce(0) { $0 + $1.revenue }
        // Bought startups arrive with revenue but no cost history: assume break-even until their own months come in.
        let known = h.contains { $0.costs > 0 }
        let margin = rev > 0 && known ? clamp((rev - h.reduce(0) { $0 + $1.costs + $1.license }) / rev, -1.5, 0.6) : 0
        return (growth, margin)
    }

    /// 3.8: the multiple follows growth and margin together (a "rule of 40" score: half the growth, capped at 100% a
    /// year, plus the margin after the licence fee — losses count double). 80% growth at break-even earns the kind's
    /// typical multiple; a fast grower burning cash, or a profitable one that has stopped growing, earns less; strong
    /// on both, up to 1.6× it.
    static func multipleFactor(growth: Double, margin: Double) -> Double {
        let score = 0.5 * min(growth, 1) + (margin < 0 ? 2 * margin : margin)
        return clamp(0.45 + 1.4 * score, 0.2, 1.6)
    }

    /// The kind's typical multiple in this era, adjusted for the CEO.
    static func baseMultiple(_ sub: Subsidiary, _ s: GameState) -> Double {
        sub.kind.multiple * (Macro.revenueMultiple(s.year) / 25).squareRoot() * (0.85 + 0.3 * sub.ceoSkill / 100)
    }

    /// What a subsidiary is worth on its numbers: revenue × its kind's multiple, moved by growth and margin.
    /// The licence fee it pays you is a cost here (it lowers the margin) and is valued once, on your side (`feeValue`).
    static func fundamental(_ sub: Subsidiary, _ s: GameState) -> Double {
        let gm = growthAndMargin(sub)
        var factor = multipleFactor(growth: gm.growth, margin: gm.margin)
        // 3.8: a loss-maker never earns more than 0.6× the typical multiple however fast it grows, and one that will run out of
        // cash within a year is worth less the sooner (it has to raise on whatever terms it can get).
        if gm.margin < 0 { factor = min(factor, 0.6) }
        let burn = max(0, -(sub.history.suffix(3).reduce(0) { $0 + $1.profit } / Double(max(1, sub.history.suffix(3).count))))
        if burn > 0 {
            let runway = max(0, sub.cash) / burn
            if runway < 12 { factor *= 0.6 + 0.4 * runway / 12 }
        }
        let m = baseMultiple(sub, s) * factor
        let floor = max(0, sub.cash) + Double(sub.headcount) * sub.kind.payPerHead * payScale(sub.kind, s.year) * 0.8
        // Three months' average revenue, so one lumpy month doesn't reprice the company.
        let h = sub.history.suffix(3)
        let rev = h.count >= 2 ? h.reduce(0) { $0 + $1.revenue } / Double(h.count) : sub.revenue
        return max(rev * 12 * m, floor)
    }

    /// The licence fees separate subsidiaries pay you, a year at the current rate (intercompany revenue).
    static func feeRunRate(_ s: GameState) -> Double {
        s.corp.subs.reduce(0) { $0 + ($1.separate ? ($1.last?.license ?? 0) * 12 : 0) }
    }

    /// What the fee streams are worth to you: each at the margin it takes from its subsidiary (the same multiple the
    /// subsidiary would earn on that margin), never at your lab's own revenue multiple — so a fee moves value between
    /// you and the subsidiary's other holders instead of creating it.
    static func feeValue(_ s: GameState) -> Double {
        s.corp.subs.reduce(0) { $0 + ($1.separate ? ($1.last?.license ?? 0) * 12 * baseMultiple($1, s) * 1.4 : 0) }
    }

    static func revalue(_ sub: inout Subsidiary, _ s: GameState) {
        let f = fundamental(sub, s)
        if sub.isPublic {
            let shock = (unit(s, "px|\(sub.id)|\(monthKey(s.month.month))") - 0.5) * 0.16
            let v = max(sub.valuation, 1)
            sub.valuation = max(1e6, v * exp(0.35 * log(max(f, 1) / v) + shock))
        } else {
            sub.valuation = sub.valuation > 0 ? (sub.valuation * f).squareRoot() : f
        }
    }

    /// Your stakes in subsidiaries that still run separately, at their marks (their fees to you are in `feeValue`).
    static func stakesValue(_ s: GameState) -> Double {
        s.corp.subs.reduce(0) { $0 + ($1.separate ? $1.stake * $1.valuation : 0) }
    }

    /// Consulting arms bring enterprise leads (exactly 1 without one).
    static func dealFactor(_ s: GameState) -> Double {
        let heads = s.corp.subs.filter { $0.kind == .consulting && $0.live }.reduce(0) { $0 + $1.headcount }
        guard heads > 0 else { return 1 }
        return 1 + min(0.3, Double(heads) / 1_000)
    }

    static func pricePerShare(_ s: GameState) -> Double {
        s.isPublic ? s.sharePrice : s.valuation / max(1, s.totalShares)
    }

    // MARK: Debt metrics

    /// EBITDA over the last twelve months (LTM, as banks test it), annualised when there's less history.
    /// Including the month being closed when `closing`. A year's window keeps one big training run from breaking covenants.
    static func ebitdaAnnual(_ s: GameState, closing: Bool = false) -> Double {
        var months = Array(s.history.suffix(closing ? 11 : 12))
        if closing { months.append(s.month) }
        guard !months.isEmpty else { return 0 }
        return months.reduce(0) { $0 + $1.revenue - $1.opex } / Double(months.count) * 12
    }

    static func revenueAnnual(_ s: GameState, closing: Bool = false) -> Double {
        var months = Array(s.history.suffix(closing ? 2 : 3))
        if closing { months.append(s.month) }
        guard !months.isEmpty else { return 0 }
        return months.reduce(0) { $0 + $1.revenue } / Double(months.count) * 12
    }

    /// Interest a year on everything you owe.
    static func annualInterest(_ s: GameState) -> Double {
        s.loans.reduce(0) { $0 + $1.balance * $1.rate / 100 } + s.corp.debts.reduce(0) { $0 + $1.balance * ($1.rate + $1.penalty) / 100 }
    }

    /// Interest plus scheduled principal a year.
    static func annualService(_ s: GameState) -> Double {
        s.loans.reduce(0) { $0 + $1.payment * 12 }
            + s.corp.debts.reduce(0) { $0 + $1.balance * ($1.rate + $1.penalty) / 100 + ($1.amortizing ? $1.balance / Double(max(1, $1.monthsLeft)) * 12 : 0) }
    }

    struct Metrics {
        var ebitda: Double
        var debt: Double
        var netDebt: Double
        var interest: Double
        var leverage: Double?
        var coverage: Double?
        var score: Double
        var notch: Int
    }

    static func metrics(_ s: GameState, closing: Bool = false) -> Metrics {
        let e = ebitdaAnnual(s, closing: closing)
        let debt = Economy.debt(s)
        let interest = annualInterest(s)
        let rev = revenueAnnual(s, closing: closing)
        var score = 0.0
        if debt <= max(0, s.cash) {
            score += 40
        } else if e > 0 {
            let l = (debt - max(0, s.cash) * 0.5) / e
            score += l <= 1 ? 36 : l <= 2 ? 30 : l <= 3 ? 23 : l <= 4 ? 16 : l <= 6 ? 8 : 0
        }
        if interest <= 0 {
            score += 25
        } else if e > 0 {
            let c = e / interest
            score += c >= 12 ? 25 : c >= 6 ? 20 : c >= 3 ? 14 : c >= 1.5 ? 7 : 2
        }
        score += clamp(log10(max(rev, 1) / 1e6) * 6, 0, 25)
        score += clamp(max(0, s.cash) / max(1, annualService(s)) * 2.5, 0, 10)
        if s.cash < 0 { score = min(score, 14) }
        var notch = bands.firstIndex { score >= $0 } ?? 6
        if s.cash < 0 && debt > 0 { notch = 7 }
        return Metrics(ebitda: e, debt: debt, netDebt: debt - s.cash, interest: interest, leverage: e > 0 ? debt / e : nil,
                       coverage: interest > 0 ? (e > 0 ? e / interest : 0) : nil, score: score, notch: notch)
    }

    /// The notch, with a little hysteresis around the current one so a rating doesn't flicker month to month.
    static func settledNotch(_ m: Metrics, current: Int) -> Int {
        guard current >= 0, current < 7, m.notch != 7 else { return m.notch }
        let lo = bands[current]
        let hi = current == 0 ? Double.infinity : bands[current - 1]
        if m.score >= lo - 2 && m.score < hi + 2 { return current }
        return m.notch
    }

    /// 3.8: saves stuck in the breach cycle (a term loan sized on trailing EBITDA, then a bad month): a year's waiver, the penalty
    /// rate off and the pending breach notices withdrawn, once.
    static func migrate(_ s: inout GameState) {
        guard !s.corp.fixes.contains("covenants38") else { return }
        s.corp.fixes.insert("covenants38")
        guard s.corp.engaged, !s.corp.debts.isEmpty else { return }
        let m = metrics(s)
        for i in s.corp.debts.indices where breaches(s.corp.debts[i], s, m, ignoreWaiver: true).isEmpty == false || s.corp.debts[i].breaches > 0 {
            guard s.corp.debts[i].covenanted else { continue }
            s.corp.debts[i].waiverUntil = GameCalendar.addMonths(s.date, 12)
            s.corp.debts[i].penalty = 0
            let ref = s.corp.debts[i].id.uuidString
            s.decisions.removeAll { $0.kind == "corp_covenant" && $0.ref == ref }
        }
    }

    // MARK: Debt offers

    struct Quote {
        var kind: CorpDebtKind
        var max: Double
        var rate: Double
        var term: Int
        var available: Bool
        var reason: String
        var covenants: String
        /// 3.8: how much more debt the covenant leaves room for (3× the lower of last-twelve-months and recent EBITDA, less all debt).
        var room: Double = 0
    }

    /// 3.8: EBITDA a lender can rely on: the lower of the last twelve months and the last three annualised. Sizing debt on LTM alone
    /// let a lab borrow to the limit just as a bad quarter pulled the LTM figure under it.
    static func safeEbitda(_ s: GameState) -> Double {
        let ltm = ebitdaAnnual(s)
        let recent = Array(s.history.suffix(3))
        guard !recent.isEmpty else { return ltm }
        return min(ltm, recent.reduce(0) { $0 + $1.revenue - $1.opex } / Double(recent.count) * 12)
    }

    /// Debt room under the 3× sizing rule: all debt (loans, notes, bonds) counts.
    static func debtRoom(_ s: GameState) -> Double { max(0, 3 * safeEbitda(s) - Economy.debt(s)) }

    /// What borrowing `amount` more does to the covenant (limit 4× last-twelve-months EBITDA): text, and whether it would breach.
    static func covenantNote(_ s: GameState, adding amount: Double) -> (text: String, breach: Bool) {
        let ltm = ebitdaAnnual(s)
        let after = Economy.debt(s) + amount
        guard ltm > 0 else { return ("No EBITDA to measure the covenant against.", true) }
        let lev = after / ltm
        let breach = after > 4 * min(ltm, safeEbitda(s) > 0 ? safeEbitda(s) : ltm)
        return ("Debt would be \(Fmt.trim(lev, 1))× EBITDA (covenant limit 4×); \(Fmt.money(max(0, 4 * ltm - after))) of headroom left."
                + (breach ? " Would breach the covenant." : (lev > 3.4 ? " Close to the limit." : "")), breach)
    }

    static func quotes(_ s: GameState) -> [Quote] {
        let m = metrics(s)
        let notch = m.notch == 7 ? 7 : (s.corp.rating >= 0 ? s.corp.rating : m.notch)
        let fed = max(0.25, Economy.fedRate(s) - s.traits.loanRate)
        let spread = spreads[notch]
        var out: [Quote] = []
        // Term loan: banks lend against cash flow.
        // 3.8: all debt counts (notes too) and EBITDA is the lower of the last twelve months and the last three annualised.
        let room = debtRoom(s)
        let termMax = m.ebitda > 0 ? room : 0
        out.append(Quote(kind: .termLoan, max: termMax, rate: fed + spread, term: 60, available: termMax > 1e6 && notch <= 5,
                         reason: m.ebitda <= 0 ? "Banks lend against EBITDA — you need to be making money first."
                             : (notch > 5 ? "Your rating is too low for a bank to lend." : "Up to 3× recent EBITDA less everything you owe, convertibles included. Cheaper than venture debt, but it comes with covenants."),
                         covenants: "Debt ≤ 4× last-twelve-months EBITDA, EBITDA ≥ 2× interest, tested monthly", room: room))
        // Convertible note: cheap coupon, converts into shares if the company does well.
        let raised = !s.rounds.isEmpty || s.isPublic
        let notes = s.corp.debts.filter { $0.kind == .convertible }.reduce(0) { $0 + $1.balance }
        // 3.8: notes count as debt under a term loan's covenant, so with one outstanding they share its room.
        var convMax = raised ? max(0, min(s.valuation * 0.15, Finance.maxRaise(s.year) * 0.5) - notes) : 0
        if s.corp.debts.contains(where: \.covenanted) { convMax = min(convMax, room) }
        let price = pricePerShare(s)
        out.append(Quote(kind: .convertible, max: convMax, rate: max(0.5, fed - 1), term: 48, available: convMax > 1e6,
                         reason: raised ? "A low coupon, repaid in 4 years — or turned into shares at \(Fmt.price(price * 1.25)) (25% above today's \(Fmt.price(price))) if they're worth more by then."
                                        : "Needs a priced equity round first.",
                         covenants: "None. Dilutes you if it converts", room: room))
        // Green bond: long, cheap money against datacenters, cheaper still on clean power.
        let dcs = s.sites.filter { $0.kind == .datacenter }
        let green = dcs.filter { [.solar, .wind, .nuclear, .smr, .fusion].contains($0.powerDeal) }
        let capex = dcs.reduce(0) { $0 + $1.capex }
        let issued = s.corp.debts.filter { $0.kind == .greenBond }.reduce(0) { $0 + $1.balance }
        let gMax = max(0, capex * 0.8 - issued)
        let cleanShare = capex > 0 ? green.reduce(0) { $0 + $1.capex } / capex : 0
        out.append(Quote(kind: .greenBond, max: gMax, rate: fed + spread - (cleanShare >= 0.5 ? 0.7 : 0.35), term: 120,
                         available: gMax > 5e6 && notch <= 5 && s.year >= 2017,
                         reason: dcs.isEmpty ? "Needs datacenters of your own to finance."
                             : (notch > 5 ? "Your rating is too low for bond investors." : "Ten-year bond against your datacenters (80% of their cost). \(cleanShare >= 0.5 ? "Mostly clean power: the full green discount." : "Put datacenters on clean power for a bigger discount.")"),
                         covenants: "Keep 6 months of its interest in cash"))
        return out
    }

    // MARK: Monthly

    /// Subsidiaries trade, debt is serviced and dividends are paid (before the month's taxes are settled).
    static func monthly(_ s: inout GameState) {
        guard s.corp.engaged else { return }
        runSubsidiaries(&s)
        serviceDebt(&s)
        payDividend(&s)
    }

    /// The month's books are closed: the snapshot behind the statements, then the rating, covenants and tax audits.
    static func closeBooks(_ s: inout GameState) {
        if s.corp.engaged {
            rate(&s)
            testCovenants(&s)
            auditCheck(&s)
        }
        snapshot(&s)
    }

    static func runSubsidiaries(_ s: inout GameState) {
        for i in s.corp.subs.indices where s.corp.subs[i].live {
            var sub = s.corp.subs[i]
            let r = step(&sub, s)
            let net = r.revenue - r.costs - r.license - r.tax
            if sub.status == .folded {
                s.month.revGroup += r.revenue
                s.month.costGroup += r.costs
                s.cash += r.revenue - r.costs
            } else {
                sub.cash += net
                if r.license > 0 {
                    s.month.revLicensing += r.license
                    s.cash += r.license
                }
                revalue(&sub, s)
            }
            sub.history.append(SubMonth(month: s.month.month, revenue: r.revenue, costs: r.costs, license: r.license, tax: r.tax,
                                        cash: sub.cash, headcount: sub.headcount, valuation: sub.separate ? sub.valuation : 0))
            if sub.history.count > 60 { sub.history.removeFirst(sub.history.count - 60) }
            s.corp.subs[i] = sub
            if sub.separate && sub.cash < 0 { askForFunding(&s, i) }
        }
    }

    static func serviceDebt(_ s: inout GameState) {
        guard !s.corp.debts.isEmpty else { return }
        var done: [String] = []
        for i in s.corp.debts.indices {
            var d = s.corp.debts[i]
            let rate = d.rate + d.penalty
            let interest = d.balance * rate / 1200
            s.cash -= interest
            s.month.costInterest += interest
            s.corp.interestPaid += interest
            var principal = 0.0
            if d.amortizing {
                let pay = Economy.monthlyPayment(principal: d.balance, annualRate: rate, months: max(1, d.monthsLeft))
                principal = min(d.balance, max(0, pay - interest))
            }
            d.monthsLeft -= 1
            if d.monthsLeft <= 0 {
                if d.kind == .convertible && pricePerShare(s) >= d.conversionPrice && d.conversionPrice > 0 {
                    convert(&s, &d)
                    done.append("\(d.kind.rawValue) converted into shares")
                } else {
                    principal = d.balance
                    done.append("\(d.kind.rawValue) repaid at maturity (\(Fmt.money(d.balance)))")
                }
            }
            principal = min(principal, d.balance)
            s.cash -= principal
            d.balance -= principal
            s.corp.flow.debtRepaid += principal
            s.corp.debts[i] = d
        }
        s.corp.debts.removeAll { $0.balance <= 1 }
        for line in done {
            Sim.news(&s, line.capitalizedFirst, "Your corporate debt schedule moved on.", .finance)
            record(&s, line.capitalizedFirst)
        }
    }

    static func convert(_ s: inout GameState, _ d: inout CorpDebt) {
        let shares = d.balance / max(d.conversionPrice, 0.01)
        if let i = s.holdings.firstIndex(where: { $0.name == "Noteholders (converted)" }) {
            s.holdings[i].shares += shares
        } else {
            s.holdings.append(Holding(name: "Noteholders (converted)", shares: shares))
        }
        if s.isPublic { s.valuation = s.sharePrice * s.totalShares }
        s.corp.flow.converted += d.balance
        Sim.news(&s, "Convertible note converts: \(Fmt.count(shares)) new shares",
                 "\(Fmt.money(d.balance)) of notes became \(Fmt.pct(shares / max(1, s.totalShares))) of the company at \(Fmt.price(d.conversionPrice)) a share. No cash left the company; everyone else was diluted.",
                 .finance)
        d.balance = 0
    }

    static func payDividend(_ s: inout GameState) {
        let q = s.corp.dividendQuarterly
        guard q > 0, s.month.month.ym.month % 3 == 0 else { return }
        guard s.isPublic else { s.corp.dividendQuarterly = 0; return }
        if s.cash < q * 2 {
            s.corp.dividendQuarterly = 0
            s.sharePrice *= 0.93
            s.valuation = s.sharePrice * s.totalShares
            Sim.news(&s, "Dividend suspended", "Cash is too thin to pay the \(Fmt.money(q)) quarterly dividend. The stock fell 7% on the news.",
                     .finance, image: "stock_exchange", important: true, good: false)
            Alerts.raise(&s, .corporate, key: "dividend", title: "Dividend suspended", body: "You didn't have twice the payout in cash, so the board skipped it.",
                         screen: .corporate, cooldown: 0)
            record(&s, "Dividend suspended: not enough cash")
            return
        }
        s.cash -= q
        s.corp.flow.dividends += q
        s.corp.dividendsPaid += q
        let mine = q * s.founderStake * (1 - Treasury.capitalGainsTax)
        s.founderCash += mine
        Sim.news(&s, "Quarterly dividend paid: \(Fmt.money(q))", "\(Fmt.price(q / max(1, s.totalShares))) a share. Your own shares earned you \(Fmt.money(mine)) after tax.", .finance, good: true)
    }

    static func rate(_ s: inout GameState) {
        let m = metrics(s, closing: true)
        let old = s.corp.rating
        let notch = settledNotch(m, current: old)
        s.corp.rating = notch
        guard old >= 0, notch != old else { return }
        let move = notch - old
        for i in s.corp.debts.indices where s.corp.debts[i].kind == .termLoan {
            s.corp.debts[i].rate = max(0.25, s.corp.debts[i].rate + 0.25 * Double(move))
        }
        if move > 0 {
            let fallen = investmentGrade(old) && !investmentGrade(notch)
            Sim.news(&s, "Downgraded to \(ratingName(notch))", "Rating agencies cut \(s.companyName) from \(ratingName(old)) to \(ratingName(notch))\(fallen ? ": below investment grade" : "")."
                     + " Leverage \(m.leverage.map { Fmt.trim($0, 1) + "×" } ?? "n/a"), interest cover \(m.coverage.map { Fmt.trim($0, 1) + "×" } ?? "n/a"). New debt costs more, and term loans re-price.",
                     .finance, image: "stock_exchange", important: true, good: false)
            Alerts.raise(&s, .corporate, key: "rating", title: "Credit rating cut to \(ratingName(notch))",
                         body: "From \(ratingName(old)). Term loans now cost \(Fmt.trim(0.25 * Double(move), 2)) points more.", screen: .corporate, cooldown: 0)
            // 3.8: a covenant breach this month already costs the board's trust once; the cut itself is capped.
            let inBreach = s.corp.debts.contains { !breaches($0, s, m).isEmpty }
            if !inBreach { s.boardConfidence = clamp(s.boardConfidence - min(6, 3 * Double(move)), 0, 100) }
            if s.isPublic { s.sharePrice *= fallen ? 0.95 : 0.98; s.valuation = s.sharePrice * s.totalShares }
            record(&s, "Rating cut \(ratingName(old)) → \(ratingName(notch))")
            if !s.corp.debts.isEmpty && !s.decisions.contains(where: { $0.kind == "corp_downgrade" }) {
                let debt = s.corp.debts.reduce(0) { $0 + $1.balance }
                let repay = min(max(0, s.cash) * 0.3, debt * 0.25)
                Events.addDecision(&s, kind: "corp_downgrade", title: "Credit rating cut to \(ratingName(notch)): how do you respond?",
                                   body: "Agencies moved you from \(ratingName(old)) to \(ratingName(notch)). Lenders and the board want to see a plan.",
                                   image: "stock_exchange",
                                   options: [DecisionOption(label: "Pay down debt", detail: repay > 1e5 ? "Repay \(Fmt.money(repay)) of corporate debt now. Board confidence +3." : "You don't have the cash to make a dent."),
                                             DecisionOption(label: "Suspend payouts", detail: "Stop the dividend and buybacks until things improve. Board confidence +2\(s.corp.dividendQuarterly > 0 ? "; the stock dips" : "")."),
                                             DecisionOption(label: "Ride it out", detail: "Do nothing; the rating follows your numbers.")],
                                   amount: repay)
            }
        } else {
            Sim.news(&s, "Upgraded to \(ratingName(notch))", "Rating agencies raised \(s.companyName) from \(ratingName(old)) to \(ratingName(notch)). Borrowing just got cheaper.",
                     .finance, image: "stock_exchange", good: true)
            record(&s, "Rating raised \(ratingName(old)) → \(ratingName(notch))")
        }
    }

    /// Which covenants a debt is breaking right now (empty when none, or while a waiver lasts).
    static func breaches(_ d: CorpDebt, _ s: GameState, _ m: Metrics, ignoreWaiver: Bool = false) -> [String] {
        guard d.covenanted else { return [] }
        if !ignoreWaiver, let w = d.waiverUntil, w > s.date { return [] }
        var out: [String] = []
        if d.maxLeverage > 0 && (m.ebitda <= 0 || m.debt / m.ebitda > d.maxLeverage) {
            out.append("debt is \(m.ebitda > 0 ? Fmt.trim(m.debt / m.ebitda, 1) + "×" : "more than any multiple of") EBITDA (limit \(Fmt.trim(d.maxLeverage, 1))×)")
        }
        if d.minCoverage > 0 && m.interest > 0 && m.ebitda / m.interest < d.minCoverage {
            out.append("EBITDA covers interest \(Fmt.trim(max(0, m.ebitda / m.interest), 1))× (minimum \(Fmt.trim(d.minCoverage, 1))×)")
        }
        if d.minCash > 0 && s.cash < d.minCash {
            out.append("cash is \(Fmt.money(s.cash)) (minimum \(Fmt.money(d.minCash)))")
        }
        return out
    }

    static func testCovenants(_ s: inout GameState) {
        guard !s.corp.debts.isEmpty else { return }
        let m = metrics(s, closing: true)
        for i in s.corp.debts.indices {
            let d = s.corp.debts[i]
            let why = breaches(d, s, m)
            // 3.8: a penalty rate lifts after six months in which the covenants held (a waiver doesn't count as holding).
            if breaches(d, s, m, ignoreWaiver: true).isEmpty {
                if d.covenanted { s.corp.debts[i].cleanMonths += 1 }
                if d.penalty > 0 && s.corp.debts[i].cleanMonths >= 6 {
                    s.corp.debts[i].penalty = 0
                    Sim.news(&s, "Penalty rate lifted on your \(d.kind.rawValue.lowercased())", "Six months inside the covenants: the lenders took the extra interest off.", .finance, good: true)
                    record(&s, "Penalty rate lifted on the \(d.kind.rawValue.lowercased())")
                }
            } else {
                s.corp.debts[i].cleanMonths = 0
            }
            guard !why.isEmpty, !s.decisions.contains(where: { $0.kind == "corp_covenant" && $0.ref == d.id.uuidString }) else { continue }
            s.corp.debts[i].breaches += 1
            let fee = (d.balance * 0.01 / 1_000).rounded(.up) * 1_000
            s.boardConfidence = clamp(s.boardConfidence - 3, 0, 100)
            Events.addDecision(&s, kind: "corp_covenant", title: "Covenant breach on your \(d.kind.rawValue.lowercased())",
                               body: "The \(Fmt.money(d.balance)) \(d.kind.rawValue.lowercased()) is in breach: \(why.joined(separator: "; ")). The lenders want a fix.",
                               image: "stock_exchange",
                               options: [DecisionOption(label: "Pay for a waiver", detail: "\(Fmt.money(fee)) (1% of the balance); covenants aren't tested for 6 months."),
                                         DecisionOption(label: "Repay it now", detail: "\(Fmt.money(d.balance)) from cash (a waiver if you can't)."),
                                         DecisionOption(label: "Accept a penalty rate", detail: "+2 points of interest (no cash now) and 6 months' grace. Lifted after six clean months.")],
                               amount: fee, ref: d.id.uuidString)
            Alerts.raise(&s, .corporate, key: "covenant|\(d.id.uuidString)", title: "Covenant breach: \(d.kind.rawValue)",
                         body: why.joined(separator: "; ").capitalizedFirst + ". A decision is waiting in your inbox.", screen: .corporate, cooldown: 60)
            record(&s, "Covenant breach on the \(d.kind.rawValue.lowercased())")
        }
    }

    /// Licence fees outside the arm's-length range invite a transfer-pricing audit when the tax rates differ.
    static func auditRisk(_ sub: Subsidiary, _ s: GameState) -> Double {
        guard sub.separate, sub.country != homeID(s), sub.revenue > 0 else { return 0 }
        let gap = abs(jurisdiction(sub.country).tax - jurisdiction(homeID(s)).tax)
        guard gap > 0.01 else { return 0 }
        let dev = max(0, armsLength.lowerBound - sub.transferRate) + max(0, sub.transferRate - armsLength.upperBound)
        guard dev > 0 else { return 0 }
        return min(0.2, 0.015 + dev * 0.5)
    }

    static func auditCheck(_ s: inout GameState) {
        for sub in s.corp.subs where auditRisk(sub, s) > 0 {
            guard !s.decisions.contains(where: { $0.kind == "corp_audit" && $0.ref == sub.id }),
                  unit(s, "audit|\(sub.id)|\(monthKey(s.month.month))") < auditRisk(sub, s) else { continue }
            let dev = max(0, armsLength.lowerBound - sub.transferRate) + max(0, sub.transferRate - armsLength.upperBound)
            let gap = abs(jurisdiction(sub.country).tax - jurisdiction(homeID(s)).tax)
            let years = clamp(Double(GameCalendar.daysBetween(sub.founded, s.date)) / 365, 0.5, 3)
            let amount = ((sub.revenue * 12 * dev * gap * years * 1.5 + 250_000) / 10_000).rounded(.up) * 10_000
            Events.addDecision(&s, kind: "corp_audit", title: "Tax authorities question \(sub.name)'s licence fee",
                               body: "\(sub.name) pays you \(Fmt.pct(sub.transferRate, decimals: 0)) of its revenue for your models; the arm's-length range is \(Fmt.pct(armsLength.lowerBound, decimals: 0))–\(Fmt.pct(armsLength.upperBound, decimals: 0)). They claim profit was shifted between \(jurisdiction(homeID(s)).name) and \(jurisdiction(sub.country).name) and want \(Fmt.money(amount)) in back taxes and penalties.",
                               image: "stock_exchange",
                               options: [DecisionOption(label: "Settle", detail: "Pay \(Fmt.money(amount)) and move the fee into the accepted range."),
                                         DecisionOption(label: "Fight it in court", detail: "Even odds: win and pay only legal fees (10%), lose and pay double plus brand −2.")],
                               amount: amount, ref: sub.id)
            Alerts.raise(&s, .corporate, key: "audit|\(sub.id)", title: "Transfer-pricing audit: \(sub.name)", body: "\(Fmt.money(amount)) claimed. A decision is waiting in your inbox.",
                         screen: .corporate, cooldown: 90)
        }
    }

    static func askForFunding(_ s: inout GameState, _ i: Int) {
        let sub = s.corp.subs[i]
        guard !s.decisions.contains(where: { $0.kind == "corp_funding" && $0.ref == sub.id }) else { return }
        let burn = max(0, -(sub.last?.profit ?? 0))
        let need = ((max(-sub.cash + burn * 9, 1e6 * payScale(sub.kind, s.year))) / 100_000).rounded(.up) * 100_000
        let outside = sub.valuation >= need * 1.5
        Events.addDecision(&s, kind: "corp_funding", title: "\(sub.name) is out of cash",
                           body: "\(sub.name) (\(sub.kind.title.lowercased()), \(sub.headcount) people) has \(Fmt.money(sub.cash)) and burns \(Fmt.money(burn)) a month. CEO \(sub.ceo) asks for \(Fmt.money(need)).",
                           image: nil,
                           options: [DecisionOption(label: "Fund it", detail: "Put in \(Fmt.money(need)) of your cash\(sub.holders.isEmpty ? "" : "; your stake rises")."),
                                     DecisionOption(label: "Let it raise outside", detail: outside ? "Investors put in \(Fmt.money(need)) at about \(Fmt.money(sub.valuation * 0.8)) pre-money; your stake falls." : "Its numbers won't attract investors: it would be wound down."),
                                     DecisionOption(label: "Wind it down", detail: "Close it and recover what's left.")],
                           amount: need, ref: sub.id)
        Alerts.raise(&s, .corporate, key: "funding|\(sub.id)", title: "\(sub.name) needs funding", body: "Asking for \(Fmt.money(need)). Waiting in your inbox.",
                     screen: .corporate, cooldown: 60)
    }

    static func snapshot(_ s: inout GameState) {
        var m = CorpMonth(month: s.month.month)
        m.cash = s.cash
        m.credits = s.cloudCredits
        m.hardware = Economy.hardwareValue(s)
        m.sites = Economy.siteValue(s)
        m.investments = RivalEconomy.stakesValue(s)
        m.debt = Economy.debt(s)
        let start = s.month.month
        m.equityRaised = s.rounds.filter { $0.date >= start && $0.date < s.date }.reduce(0) { $0 + $1.amount }
            + s.shareIssues.filter { $0.date >= start && $0.date < s.date }.reduce(0) { $0 + $1.shares } * s.sharePrice * 0.95
        m.flow = s.corp.flow
        m.capex = s.month.capex
        m.rating = s.corp.engaged ? s.corp.rating : -1
        for sub in s.corp.subs where sub.separate {
            let last = sub.last.flatMap { $0.month == start ? $0 : nil }
            if sub.stake > 0.5 {
                m.subsCash += sub.cash
                m.minorityInterest += (1 - sub.stake) * max(0, sub.cash)
                if let l = last {
                    m.subRevenue += l.revenue
                    m.subCosts += l.costs
                    m.subTax += l.tax
                    m.intercompany += l.license
                    m.minority += (1 - sub.stake) * l.profit
                }
            } else {
                m.investments += sub.stake * sub.valuation
                if let l = last { m.associates += sub.stake * l.profit }
            }
        }
        s.corp.months.append(m)
        if s.corp.months.count > 60 { s.corp.months.removeFirst(s.corp.months.count - 60) }
        s.corp.flow = CorpFlow()
    }

    static func record(_ s: inout GameState, _ line: String) {
        s.corp.log.insert("\(s.date.gameShort): \(line)", at: 0)
        if s.corp.log.count > 60 { s.corp.log.removeLast(s.corp.log.count - 60) }
    }

    // MARK: Briefing

    static func briefingLines(_ s: GameState) -> [BriefingLine] {
        guard s.corp.engaged, let cur = s.corp.months.last else { return [] }
        var out: [BriefingLine] = []
        let prev = s.corp.months.dropLast().last
        if let p = prev, p.rating >= 0, cur.rating >= 0, p.rating != cur.rating {
            out.append(BriefingLine(text: "Credit rating \(ratingName(p.rating)) → \(ratingName(cur.rating)).", good: cur.rating < p.rating, screen: Screen.corporate.rawValue))
        }
        let live = s.corp.subs.filter(\.separate)
        if !live.isEmpty {
            let rev = live.reduce(0) { $0 + (($1.last?.month == cur.month) ? $1.last!.revenue : 0) }
            let profit = live.reduce(0) { $0 + (($1.last?.month == cur.month) ? $1.last!.profit : 0) }
            out.append(BriefingLine(text: "Subsidiaries: \(Fmt.money(rev)) revenue, \(profit >= 0 ? "+" : "−")\(Fmt.money(abs(profit))) net; your stakes are worth \(Fmt.money(stakesValue(s))).",
                                    good: profit >= 0, screen: Screen.corporate.rawValue))
        }
        return Array(out.prefix(2))
    }

    // MARK: Statements

    /// One closed month as three statements. Subsidiaries you control (over 50%) are consolidated line by line, with the
    /// licence fees they pay you eliminated and the outside holders' share taken out; smaller stakes count as associates.
    struct Statement: Identifiable {
        var id: Date { month }
        var month: Date
        // Income statement
        var revenue: Double
        var groupRevenue: Double
        var computeCosts: Double
        var peopleCosts: Double
        var otherCosts: Double
        var ebitda: Double
        var interestIncome: Double
        var oneOff: Double
        var interest: Double
        var taxes: Double
        var netCompany: Double
        var subRevenue: Double
        var subCosts: Double
        var subTax: Double
        var intercompany: Double
        var minority: Double
        var associates: Double
        var consolidatedRevenue: Double { revenue - intercompany + subRevenue }
        var consolidatedNet: Double { netCompany - intercompany + subRevenue - subCosts - subTax - minority + associates }
        // Balance sheet (nil before the corporate books existed)
        var balance: CorpMonth?
        var assets: Double { balance.map { $0.cash + $0.credits + $0.hardware + $0.sites + $0.investments + $0.subsCash } ?? 0 }
        var liabilities: Double { balance?.debt ?? 0 }
        var equity: Double { assets - liabilities - (balance?.minorityInterest ?? 0) }
        // Cash flow
        var cashChange: Double
        var operating: Double
        var investing: Double
        var financing: Double
    }

    static func statements(_ s: GameState, count: Int = 12) -> [Statement] {
        let n = s.history.count
        guard n > 0 else { return [] }
        let byMonth = Dictionary(s.corp.months.map { ($0.month, $0) }, uniquingKeysWith: { _, b in b })
        var out: [Statement] = []
        for i in max(0, n - count)..<n {
            let h = s.history[i]
            let c = byMonth[h.month]
            let prev = i > 0 ? s.history[i - 1] : nil
            let prevC = prev.flatMap { byMonth[$0.month] }
            let change = prev.map { h.cashEnd - $0.cashEnd } ?? 0
            var financing = 0.0, investing = -h.capex
            if let c {
                financing = (prevC.map { c.debt - $0.debt + c.flow.converted } ?? (c.flow.debtIn - c.flow.debtRepaid)) + c.equityRaised - c.flow.dividends - c.flow.buybacks
                investing = -h.capex + c.flow.subProceeds
            } else {
                financing = s.rounds.filter { $0.date >= h.month && $0.date < GameCalendar.addMonths(h.month, 1) }.reduce(0) { $0 + $1.amount }
            }
            let compute = h.costRent + h.costPower + h.costChips
            out.append(Statement(month: h.month, revenue: h.revenue, groupRevenue: h.revGroup, computeCosts: compute, peopleCosts: h.costPayroll,
                                 otherCosts: h.opex - compute - h.costPayroll, ebitda: h.revenue - h.opex, interestIncome: h.interestIncome,
                                 oneOff: h.oneOffIncome, interest: h.costInterest, taxes: h.taxes, netCompany: h.profit,
                                 subRevenue: c?.subRevenue ?? 0, subCosts: c?.subCosts ?? 0, subTax: c?.subTax ?? 0, intercompany: c?.intercompany ?? 0,
                                 minority: c?.minority ?? 0, associates: c?.associates ?? 0, balance: c,
                                 cashChange: change, operating: change - financing - investing, investing: investing, financing: financing))
        }
        return out
    }

    // MARK: Runway scenarios

    struct Scenario: Identifiable {
        var id: String { name }
        var name: String
        var detail: String
        var cash: [Double]
        /// First month cash goes below zero (nil if it never does in the window).
        var zeroMonth: Int?
    }

    /// Cash over the next `months` under a base, a bear and a bull case, with your debt service and dividends.
    static func scenarios(_ s: GameState, months: Int = 24) -> [Scenario] {
        let recent = Array(s.history.suffix(3))
        guard !recent.isEmpty else { return [] }
        let rev0 = recent.reduce(0) { $0 + $1.revenue } / Double(recent.count)
        let opex0 = recent.reduce(0) { $0 + $1.opex } / Double(recent.count)
        var g = 0.0
        if s.history.count >= 4, let a = s.history.last?.revenue {
            let b = s.history[s.history.count - 4].revenue
            if a > 0 && b > 0 { g = pow(a / b, 1.0 / 3) - 1 }
        }
        g = clamp(g, -0.08, 0.12)
        let taxRate = HQ.taxRate(s)
        func run(_ shock: Double, _ dg: Double, _ costGrowth: Double) -> [Double] {
            var cash = s.cash
            var rev = rev0 * shock
            var opex = opex0
            var loans = s.loans
            var debts = s.corp.debts
            var out: [Double] = []
            for t in 1...months {
                rev *= 1 + g + dg
                opex *= 1 + costGrowth
                var interest = 0.0, principal = 0.0
                for i in loans.indices where loans[i].balance > 1 {
                    let int = loans[i].balance * loans[i].rate / 1200
                    var p = max(0, loans[i].payment - int)
                    if loans[i].monthsLeft <= 1 { p = loans[i].balance }
                    p = min(p, loans[i].balance)
                    loans[i].balance -= p
                    loans[i].monthsLeft -= 1
                    interest += int
                    principal += p
                }
                for i in debts.indices where debts[i].balance > 1 {
                    let r = debts[i].rate + debts[i].penalty
                    let int = debts[i].balance * r / 1200
                    var p = 0.0
                    if debts[i].amortizing {
                        p = max(0, Economy.monthlyPayment(principal: debts[i].balance, annualRate: r, months: max(1, debts[i].monthsLeft)) - int)
                    }
                    if debts[i].monthsLeft <= 1 && debts[i].kind != .convertible { p = debts[i].balance }
                    if debts[i].monthsLeft <= 1 && debts[i].kind == .convertible {
                        if pricePerShare(s) < debts[i].conversionPrice { p = debts[i].balance } else { debts[i].balance = 0 }
                    }
                    p = min(p, debts[i].balance)
                    debts[i].balance -= p
                    debts[i].monthsLeft -= 1
                    interest += int
                    principal += p
                }
                let pre = rev - opex - interest
                let tax = max(0, pre) * taxRate
                cash += pre - tax - principal
                if s.isPublic && s.corp.dividendQuarterly > 0 && t % 3 == 0 { cash -= s.corp.dividendQuarterly }
                out.append(cash)
            }
            return out
        }
        let costG = max(0.005, g * 0.5)
        let cases: [(String, String, [Double])] = [
            ("Base", "Revenue keeps its 3-month trend (\(g >= 0 ? "+" : "")\(Fmt.pct(g, decimals: 1))/mo); costs grow \(Fmt.pct(costG, decimals: 1))/mo.", run(1, 0, costG)),
            ("Bear", "Revenue drops 15% now and grows 4 points/mo slower; costs keep growing.", run(0.85, -0.04, costG)),
            ("Bull", "Revenue grows 3 points/mo faster than its trend.", run(1, 0.03, costG * 1.3)),
        ]
        return cases.map { c in Scenario(name: c.0, detail: c.1, cash: c.2, zeroMonth: c.2.firstIndex { $0 < 0 }.map { $0 + 1 }) }
    }

    // MARK: Acquisition targets

    struct Target: Identifiable {
        var id: String
        var name: String
        var kind: SubsidiaryKind
        var country: String
        var revenue: Double
        var prevRevenue: Double
        var headcount: Int
        var ceo: String
        var ceoSkill: Double
        var cash: Double
        var valuation: Double
        var price: Double
    }

    /// Three startups for sale each quarter (the same three all quarter, until you buy one).
    static func targets(_ s: GameState) -> [Target] {
        let ym = s.date.ym
        let quarter = "\(ym.year)Q\((ym.month - 1) / 3)"
        let kinds = SubsidiaryKind.allCases.filter { s.year >= $0.minYear }
        guard !kinds.isEmpty else { return [] }
        let home = homeID(s)
        var out: [Target] = []
        for i in 0..<3 {
            let key = "t|\(quarter)|\(i)"
            guard !s.corp.bought.contains(key) else { continue }
            func u(_ t: String) -> Double { unit(s, "\(key)|\(t)") }
            let kind = kinds[min(kinds.count - 1, Int(u("kind") * Double(kinds.count)))]
            let others = jurisdictions.filter { $0.id != home }
            let country: String
            if kind == .regional || u("abroad") < 0.35 {
                country = others[min(others.count - 1, Int(u("where") * Double(others.count)))].id
            } else {
                country = home
            }
            var sub = Subsidiary(id: key, name: kind.startupNames[min(5, Int(u("name") * 6))], kind: kind, country: country, founded: s.date,
                                 ceo: personName(s, key), ceoSkill: (40 + 55 * u("ceo")).rounded())
            sub.transferRate = kind.defaultTransfer
            let cap = revenueCap(sub, s.year)
            let rev = cap * pow(10, -2.2 + 1.4 * u("size"))
            let prev = rev / (1.15 + 0.35 * u("growth"))
            sub.revenue = rev
            sub.headcount = Int(rev / revenuePerHeadMonth(kind, s.year) * 1.2) + kind.baseTeam / 2
            sub.cash = rev * (2 + 4 * u("cash"))
            sub.history = [SubMonth(month: GameCalendar.addMonths(s.month.month, -3), revenue: prev, costs: 0, license: 0, tax: 0, cash: 0, headcount: 0, valuation: 0),
                           SubMonth(month: GameCalendar.addMonths(s.month.month, -2), revenue: prev, costs: 0, license: 0, tax: 0, cash: 0, headcount: 0, valuation: 0),
                           SubMonth(month: GameCalendar.addMonths(s.month.month, -1), revenue: prev, costs: 0, license: 0, tax: 0, cash: 0, headcount: 0, valuation: 0),
                           SubMonth(month: s.month.month, revenue: rev, costs: 0, license: 0, tax: 0, cash: 0, headcount: 0, valuation: 0)]
            let v = fundamental(sub, s)
            let price = (v * 1.3 / 1e5).rounded(.up) * 1e5
            out.append(Target(id: key, name: sub.name, kind: kind, country: country, revenue: rev, prevRevenue: prev, headcount: sub.headcount,
                              ceo: sub.ceo, ceoSkill: sub.ceoSkill, cash: sub.cash, valuation: v, price: price))
        }
        return out
    }

    static func personName(_ s: GameState, _ key: String) -> String {
        let f = NameBank.first, l = NameBank.last
        return "\(f[min(f.count - 1, Int(unit(s, "first|\(key)") * Double(f.count)))]) \(l[min(l.count - 1, Int(unit(s, "last|\(key)") * Double(l.count)))])"
    }

    static func investorName(_ s: GameState, _ key: String) -> String {
        let pool = NameBank.investors.filter { !$0.contains("strategic") }
        return pool[min(pool.count - 1, Int(unit(s, "inv|\(key)") * Double(pool.count)))]
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch (d.kind, option) {
        case ("corp_funding", 0):
            if s.injectSubsidiary(d.ref, amount: d.amount) != nil { outsideRaise(&s, d) }
        case ("corp_funding", 1):
            outsideRaise(&s, d)
        case ("corp_funding", _):
            _ = s.windDownSubsidiary(d.ref)
        case ("corp_covenant", _):
            guard let i = s.corp.debts.firstIndex(where: { $0.id.uuidString == d.ref }) else { return }
            let debt = s.corp.debts[i]
            var choice = option
            if choice == 1 && s.cash < debt.balance { choice = 0 }
            if choice == 0 && s.cash < d.amount { choice = 2 }
            switch choice {
            case 0:
                s.cash -= d.amount
                s.month.costInterest += d.amount
                s.corp.debts[i].waiverUntil = GameCalendar.addMonths(s.date, 6)
                Sim.news(&s, "Covenant waiver: \(Fmt.money(d.amount))", "Lenders agreed not to test the \(debt.kind.rawValue.lowercased())'s covenants for six months.", .finance)
                record(&s, "Paid \(Fmt.money(d.amount)) for a covenant waiver")
            case 1:
                s.cash -= debt.balance
                s.corp.flow.debtRepaid += debt.balance
                s.corp.debts.remove(at: i)
                Sim.news(&s, "Debt repaid after a covenant breach", "You paid off the \(Fmt.money(debt.balance)) \(debt.kind.rawValue.lowercased()).", .finance)
                record(&s, "Repaid the \(debt.kind.rawValue.lowercased()) after a breach")
            default:
                s.corp.debts[i].penalty = min(4, s.corp.debts[i].penalty + 2)
                s.corp.debts[i].cleanMonths = 0
                s.corp.debts[i].waiverUntil = GameCalendar.addMonths(s.date, 6)
                Sim.news(&s, "Penalty rate on your \(debt.kind.rawValue.lowercased())", "Lenders added 2 points of interest in exchange for six months' grace. It comes off after six months inside the covenants.", .finance, good: false)
                record(&s, "Took a +2 point penalty rate on the \(debt.kind.rawValue.lowercased())")
            }
        case ("corp_downgrade", 0):
            var left = min(d.amount, max(0, s.cash))
            guard left > 1e5 else { return }
            let paid = left
            for i in s.corp.debts.indices.sorted(by: { s.corp.debts[$0].kind == .convertible ? false : s.corp.debts[$1].kind == .convertible }) where left > 0 {
                let p = min(left, s.corp.debts[i].balance)
                s.corp.debts[i].balance -= p
                left -= p
            }
            s.corp.debts.removeAll { $0.balance <= 1 }
            s.cash -= paid - left
            s.corp.flow.debtRepaid += paid - left
            s.boardConfidence = clamp(s.boardConfidence + 3, 0, 100)
            Sim.news(&s, "Paying down debt", "You repaid \(Fmt.money(paid - left)) of corporate debt after the downgrade.", .finance)
            record(&s, "Repaid \(Fmt.money(paid - left)) after a downgrade")
        case ("corp_downgrade", 1):
            if s.corp.dividendQuarterly > 0 && s.isPublic {
                s.sharePrice *= 0.95
                s.valuation = s.sharePrice * s.totalShares
            }
            s.corp.dividendQuarterly = 0
            s.corp.lastBuyback = s.date
            s.boardConfidence = clamp(s.boardConfidence + 2, 0, 100)
            Sim.news(&s, "Payouts suspended", "No dividend or buybacks until the balance sheet recovers.", .finance)
            record(&s, "Suspended dividends and buybacks after a downgrade")
        case ("corp_audit", _):
            guard let i = s.corp.subs.firstIndex(where: { $0.id == d.ref }) else { return }
            var pay = d.amount
            var title = "Transfer-pricing audit settled"
            if option == 1 {
                if unit(s, "court|\(d.ref)|\(monthKey(s.date))") < 0.5 {
                    pay = d.amount * 0.1
                    title = "You won the transfer-pricing case"
                } else {
                    pay = d.amount * 2
                    s.brand = max(0, s.brand - 2)
                    title = "You lost the transfer-pricing case"
                }
            }
            s.cash -= pay
            s.month.taxes += pay
            s.corp.auditsSettled += pay
            s.corp.subs[i].transferRate = clamp(s.corp.subs[i].transferRate, armsLength.lowerBound, armsLength.upperBound)
            Sim.news(&s, title, "\(Fmt.money(pay)) in tax, penalties or fees over \(s.corp.subs[i].name)'s licence fee, now \(Fmt.pct(s.corp.subs[i].transferRate, decimals: 0)) of its revenue.",
                     .finance, good: option == 1 && pay < d.amount)
            record(&s, "\(title): \(Fmt.money(pay))")
        default:
            break
        }
    }

    static func outsideRaise(_ s: inout GameState, _ d: Decision) {
        guard let i = s.corp.subs.firstIndex(where: { $0.id == d.ref }) else { return }
        let sub = s.corp.subs[i]
        if sub.valuation >= d.amount * 1.5 {
            raise(&s, i, amount: d.amount, pre: sub.valuation * 0.8, investor: investorName(s, "\(sub.id)|\(monthKey(s.date))"))
        } else {
            _ = s.windDownSubsidiary(sub.id)
        }
    }

    /// New money into a subsidiary at `pre` pre-money: everyone, you included, is diluted.
    static func raise(_ s: inout GameState, _ i: Int, amount: Double, pre: Double, investor: String) {
        let f = pre / (pre + amount)
        s.corp.subs[i].stake *= f
        for h in s.corp.subs[i].holders.indices { s.corp.subs[i].holders[h].stake *= f }
        if let h = s.corp.subs[i].holders.firstIndex(where: { $0.name == investor }) {
            s.corp.subs[i].holders[h].stake += 1 - f
        } else {
            s.corp.subs[i].holders.append(SubHolder(name: investor, stake: 1 - f))
        }
        s.corp.subs[i].cash += amount
        s.corp.subs[i].valuation = pre + amount
        let sub = s.corp.subs[i]
        Sim.news(&s, "\(sub.name) raises \(Fmt.money(amount))", "Led by \(investor) at \(Fmt.money(pre)) pre-money. You now own \(Fmt.pct(sub.stake)) of it.", .finance)
        record(&s, "\(sub.name) raised \(Fmt.money(amount)) from \(investor); your stake \(Fmt.pct(sub.stake))")
    }
}

// MARK: - Player actions

extension GameState {
    private mutating func subIndex(_ id: String) -> Int? { corp.subs.firstIndex { $0.id == id && $0.live } }

    func subsidiaryBlocker(_ kind: SubsidiaryKind, country: String) -> String? {
        if year < kind.minYear { return "\(kind.title) subsidiaries make sense from \(Int(kind.minYear))." }
        if corp.subs.filter(\.live).count >= Corporate.maxSubsidiaries { return "You run \(Corporate.maxSubsidiaries) subsidiaries already — sell, spin off or fold one in first." }
        if kind == .regional {
            if country == Corporate.homeID(self) { return "A regional entity goes in another country." }
            if corp.subs.contains(where: { $0.live && $0.kind == .regional && $0.country == country }) { return "You already have an entity in \(Corporate.jurisdiction(country).name)." }
        }
        return nil
    }

    /// Start a subsidiary with `seed` of your cash.
    mutating func startSubsidiary(_ kind: SubsidiaryKind, country: String, seed: Double) -> String? {
        if let why = subsidiaryBlocker(kind, country: country) { return why }
        let need = Corporate.minSeed(kind, self, country: country)
        if seed + 1 < need { return "It needs at least \(Fmt.money(need)) to start." }
        if seed > cash { return "You have \(Fmt.money(cash))." }
        corp.counter += 1
        let id = "sub\(corp.counter)"
        let j = Corporate.jurisdiction(country)
        let name = kind == .regional ? "\(companyName) \(j.name)" : "\(companyName) \(kind.suffix)"
        var sub = Subsidiary(id: id, name: name, kind: kind, country: country, founded: date, ceo: Corporate.personName(self, id),
                             ceoSkill: (45 + 45 * Corporate.unit(self, "ceo|\(id)")).rounded())
        sub.cash = seed
        sub.basis = seed
        sub.headcount = kind.baseTeam
        sub.transferRate = kind.defaultTransfer
        sub.valuation = seed
        corp.subs.append(sub)
        corp.engaged = true
        cash -= seed
        corp.flow.subInvested += seed
        month.capex += seed
        Sim.news(&self, "\(name) is born", "A \(kind.title.lowercased()) subsidiary in \(j.flag) \(j.name) with \(Fmt.money(seed)), \(kind.baseTeam) people and \(sub.ceo) as CEO. It licenses your models at \(Fmt.pct(sub.transferRate, decimals: 0)) of its revenue.",
                 .company, important: true, good: true)
        Corporate.record(&self, "Started \(name) with \(Fmt.money(seed))")
        return nil
    }

    mutating func acquireSubsidiary(_ targetID: String) -> String? {
        guard let t = Corporate.targets(self).first(where: { $0.id == targetID }) else { return "That company is no longer for sale." }
        if let why = subsidiaryBlocker(t.kind, country: t.country) { return why }
        if t.price > cash { return "It costs \(Fmt.money(t.price)); you have \(Fmt.money(cash))." }
        corp.counter += 1
        let id = "sub\(corp.counter)"
        var sub = Subsidiary(id: id, name: t.name, kind: t.kind, country: t.country, founded: date, ceo: t.ceo, ceoSkill: t.ceoSkill)
        sub.cash = t.cash
        sub.basis = t.price
        sub.headcount = t.headcount
        sub.revenue = t.revenue
        sub.transferRate = t.kind.defaultTransfer
        sub.valuation = t.valuation
        sub.acquired = true
        sub.history = [SubMonth(month: GameCalendar.addMonths(month.month, -3), revenue: t.prevRevenue, costs: 0, license: 0, tax: 0, cash: t.cash, headcount: t.headcount, valuation: 0),
                       SubMonth(month: GameCalendar.addMonths(month.month, -2), revenue: (t.prevRevenue * t.revenue).squareRoot(), costs: 0, license: 0, tax: 0, cash: t.cash, headcount: t.headcount, valuation: 0),
                       SubMonth(month: GameCalendar.addMonths(month.month, -1), revenue: t.revenue, costs: 0, license: 0, tax: 0, cash: t.cash, headcount: t.headcount, valuation: t.valuation)]
        corp.subs.append(sub)
        corp.bought.insert(t.id)
        corp.engaged = true
        cash -= t.price
        corp.flow.subInvested += t.price
        month.capex += t.price
        Sim.news(&self, "\(companyName) buys \(t.name) for \(Fmt.money(t.price))",
                 "A \(t.kind.title.lowercased()) company in \(Corporate.jurisdiction(t.country).name): \(Fmt.money(t.revenue * 12)) annual revenue, \(t.headcount) people. CEO \(t.ceo) stays on. It now runs as your subsidiary.",
                 .company, image: "nvidia_hq", important: true, good: true)
        Corporate.record(&self, "Bought \(t.name) for \(Fmt.money(t.price))")
        return nil
    }

    mutating func setSubsidiaryStrategy(_ id: String, _ v: Double) {
        guard let i = subIndex(id) else { return }
        corp.subs[i].strategy = clamp(v, 0, 1)
    }

    mutating func setTransferRate(_ id: String, _ v: Double) {
        guard let i = subIndex(id), corp.subs[i].separate else { return }
        corp.subs[i].transferRate = clamp(v, 0, 0.5)
    }

    /// Put more of your cash in. With outside holders it's priced at the current mark, so your stake rises.
    mutating func injectSubsidiary(_ id: String, amount: Double) -> String? {
        guard let i = subIndex(id), corp.subs[i].separate else { return "Not found." }
        guard amount > 0 else { return "Pick an amount." }
        if amount > cash { return "You have \(Fmt.money(cash))." }
        let sub = corp.subs[i]
        if !sub.holders.isEmpty {
            let v = max(sub.valuation, 1)
            let f = v / (v + amount)
            corp.subs[i].stake = sub.stake * f + (1 - f)
            for h in corp.subs[i].holders.indices { corp.subs[i].holders[h].stake *= f }
            corp.subs[i].valuation = v + amount
        }
        corp.subs[i].cash += amount
        corp.subs[i].basis += amount
        cash -= amount
        corp.flow.subInvested += amount
        month.capex += amount
        Sim.news(&self, "\(Fmt.money(amount)) into \(sub.name)", "You own \(Fmt.pct(corp.subs[i].stake)) of it.", .finance)
        Corporate.record(&self, "Put \(Fmt.money(amount)) into \(sub.name)")
        return nil
    }

    /// Sell part of your stake to minority investors. The gain over what you put in is taxed with the month.
    mutating func sellSubsidiaryStake(_ id: String, fraction: Double) -> String? {
        guard let i = subIndex(id), corp.subs[i].separate else { return "Not found." }
        let sub = corp.subs[i]
        let f = min(fraction, sub.stake)
        guard f >= 0.01 else { return "Pick a stake to sell." }
        if !sub.isPublic && sub.revenue <= 0 { return "Investors want to see revenue first." }
        let proceeds = f * sub.valuation * (sub.isPublic ? 0.97 : 0.85)
        let basis = sub.basis * f / max(sub.stake, 0.0001)
        let buyer = sub.isPublic ? "Public float" : Corporate.investorName(self, "\(id)|\(Corporate.monthKey(date))|sell")
        corp.subs[i].stake -= f
        corp.subs[i].basis -= basis
        if let h = corp.subs[i].holders.firstIndex(where: { $0.name == buyer }) {
            corp.subs[i].holders[h].stake += f
        } else {
            corp.subs[i].holders.append(SubHolder(name: buyer, stake: f))
        }
        cash += proceeds
        corp.flow.subProceeds += proceeds
        let gain = proceeds - basis
        if gain > 0 { month.oneOffIncome += gain }
        if corp.subs[i].stake < 0.0001 {
            corp.subs[i].stake = 0
            corp.subs[i].status = .sold
            corp.subs[i].statusDate = date
        }
        Sim.news(&self, "You sell \(Fmt.pct(f, decimals: 0)) of \(sub.name)", "\(Fmt.money(proceeds)) from \(buyer) (\(gain >= 0 ? "a gain" : "a loss") of \(Fmt.money(abs(gain))) on what you put in). You keep \(Fmt.pct(corp.subs[i].stake)).",
                 .finance, good: true)
        Corporate.record(&self, "Sold \(Fmt.pct(f, decimals: 0)) of \(sub.name) for \(Fmt.money(proceeds))")
        return nil
    }

    /// The subsidiary sells new shares to investors: cash for it, dilution for you.
    mutating func raiseForSubsidiary(_ id: String, amount: Double) -> String? {
        guard let i = subIndex(id), corp.subs[i].separate else { return "Not found." }
        let sub = corp.subs[i]
        if sub.revenue <= 0 { return "Investors want to see revenue first." }
        if amount > sub.valuation * 0.5 { return "Investors will put in at most half its value (\(Fmt.money(sub.valuation * 0.5)))." }
        Corporate.raise(&self, i, amount: amount, pre: sub.valuation * (sub.isPublic ? 0.95 : 0.9), investor: sub.isPublic ? "Public float" : Corporate.investorName(self, "\(id)|\(Corporate.monthKey(date))"))
        return nil
    }

    func subsidiaryIPOBlocker(_ sub: Subsidiary) -> String? {
        if sub.isPublic { return "Already listed." }
        if GameCalendar.daysBetween(sub.founded, date) < 365 && !sub.acquired { return "Needs a year of results." }
        let minValue = max(3e8, Finance.maxRaise(year) * 0.01)
        if sub.valuation < minValue && sub.revenue * 12 < 5e7 { return "Needs a \(Fmt.money(minValue)) valuation or $50M of annual revenue." }
        return nil
    }

    /// List the subsidiary: it sells 20% new shares to the public.
    mutating func ipoSubsidiary(_ id: String) -> String? {
        guard let i = subIndex(id), corp.subs[i].separate else { return "Not found." }
        if let why = subsidiaryIPOBlocker(corp.subs[i]) { return why }
        let pre = corp.subs[i].valuation * 0.9
        let raised = pre * 0.25
        Corporate.raise(&self, i, amount: raised, pre: pre, investor: "Public float")
        let pop = 1 + 0.3 * Corporate.unit(self, "pop|\(id)")
        corp.subs[i].valuation *= pop
        corp.subs[i].isPublic = true
        corp.subs[i].listed = date
        let sub = corp.subs[i]
        Sim.news(&self, "\(sub.name) lists: \(Fmt.money(raised)) raised", "Priced at \(Fmt.money(pre + raised)), it closed day one worth \(Fmt.money(sub.valuation)). You keep \(Fmt.pct(sub.stake)).",
                 .finance, image: "stock_exchange", important: true, good: true)
        Corporate.record(&self, "Listed \(sub.name), raising \(Fmt.money(raised))")
        return nil
    }

    /// Hand your stake to your own shareholders: the subsidiary leaves the group as an independent company.
    mutating func spinOffSubsidiary(_ id: String) -> String? {
        guard let i = subIndex(id), corp.subs[i].separate else { return "Not found." }
        let sub = corp.subs[i]
        if !sub.isPublic && GameCalendar.daysBetween(sub.founded, date) < 365 { return "Spin-offs need a year of results or a listing." }
        let value = sub.stake * sub.valuation
        let mine = value * founderStake
        founderCash += mine
        corp.subs[i].status = .spunOff
        corp.subs[i].statusDate = date
        corp.subs[i].stake = 0
        valuation = Economy.valuation(self)
        Sim.news(&self, "\(sub.name) spun off", "Your shareholders receive its shares directly — \(Fmt.money(value)) of value leaves the company. Your own slice is worth \(Fmt.money(mine)) and counts toward your net worth.",
                 .finance, image: "stock_exchange", important: true, good: true)
        Corporate.record(&self, "Spun off \(sub.name) (\(Fmt.money(value)))")
        return nil
    }

    func foldInCost(_ sub: Subsidiary) -> Double { (1 - sub.stake) * sub.valuation * (sub.isPublic ? 1.25 : 1.1) }

    /// Buy out the other holders and merge it in as a division: its cash and results become yours.
    mutating func foldInSubsidiary(_ id: String) -> String? {
        guard let i = subIndex(id), corp.subs[i].separate else { return "Not found." }
        let sub = corp.subs[i]
        let cost = foldInCost(sub)
        if cost > cash { return "Buying out the other holders costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        corp.flow.subInvested += cost
        month.capex += cost
        cash += sub.cash
        corp.flow.subProceeds += max(0, sub.cash)
        corp.subs[i].cash = 0
        corp.subs[i].stake = 1
        corp.subs[i].holders = []
        corp.subs[i].isPublic = false
        corp.subs[i].status = .folded
        corp.subs[i].statusDate = date
        corp.subs[i].transferRate = 0
        Sim.news(&self, "\(sub.name) folded back in", "\(cost > 0 ? "You bought out the other holders for \(Fmt.money(cost)). " : "")Its \(Fmt.money(sub.cash)) of cash and its results are now part of the company's own books.",
                 .company, important: true)
        Corporate.record(&self, "Folded \(sub.name) back in\(cost > 0 ? " (buy-out \(Fmt.money(cost)))" : "")")
        return nil
    }

    /// Close it: pay severance, hand back what's left (your share of it).
    mutating func windDownSubsidiary(_ id: String) -> String? {
        guard let i = subIndex(id) else { return "Not found." }
        let sub = corp.subs[i]
        let severance = Double(sub.headcount) * Corporate.payPerHeadMonth(sub, year) * 2
        let left = sub.status == .folded ? -severance : sub.stake * max(0, sub.cash - severance)
        cash += left
        if left >= 0 { corp.flow.subProceeds += left } else { month.costOther -= left }
        corp.subs[i].status = .closed
        corp.subs[i].statusDate = date
        corp.subs[i].cash = 0
        corp.subs[i].headcount = 0
        Sim.news(&self, "\(sub.name) wound down", "\(sub.headcount) people let go with two months' pay. \(left >= 0 ? "You recovered \(Fmt.money(left))." : "Severance cost you \(Fmt.money(-left)).")",
                 .company, good: false)
        Corporate.record(&self, "Wound down \(sub.name)")
        return nil
    }

    /// A new CEO: severance, a month's disruption, and a new skill level.
    mutating func replaceSubsidiaryCEO(_ id: String) -> String? {
        guard let i = subIndex(id), corp.subs[i].separate else { return "Not found." }
        let sub = corp.subs[i]
        let cost = Corporate.payPerHeadMonth(sub, year) * 24
        let pay = min(cost, max(0, sub.cash))
        corp.counter += 1
        let key = "\(id)|ceo\(corp.counter)"
        corp.subs[i].ceo = Corporate.personName(self, key)
        corp.subs[i].ceoSkill = (40 + 58 * Corporate.unit(self, "skill|\(key)")).rounded()
        corp.subs[i].cash -= pay
        corp.subs[i].shake = 0.04
        Sim.news(&self, "\(sub.name) has a new CEO", "\(corp.subs[i].ceo) replaces \(sub.ceo). The transition costs a month of momentum.", .company)
        Corporate.record(&self, "\(sub.name): \(corp.subs[i].ceo) replaces \(sub.ceo)")
        return nil
    }

    // MARK: Corporate debt

    mutating func borrowCorporate(_ kind: CorpDebtKind, amount: Double) -> String? {
        guard let q = Corporate.quotes(self).first(where: { $0.kind == kind }), q.available else { return "Not available." }
        if amount <= 0 || amount > q.max + 1 { return "Up to \(Fmt.money(q.max))." }
        let m = Corporate.metrics(self)
        var d = CorpDebt(kind: kind, principal: amount, balance: amount, rate: q.rate, termMonths: q.term, monthsLeft: q.term, taken: date)
        d.notch = corp.rating >= 0 ? corp.rating : m.notch
        switch kind {
        case .termLoan:
            d.maxLeverage = 4
            d.minCoverage = 2
        case .convertible:
            d.conversionPrice = Corporate.pricePerShare(self) * 1.25
        case .greenBond:
            d.minCash = amount * q.rate / 100 / 2
        }
        corp.debts.append(d)
        if corp.rating < 0 { corp.rating = m.notch }
        corp.engaged = true
        cash += amount
        corp.flow.debtIn += amount
        Sim.news(&self, "\(kind.rawValue): \(Fmt.money(amount))", "\(Fmt.trim(q.rate, 2))% for \(q.term / 12) years. \(q.covenants).", .finance)
        Corporate.record(&self, "Took a \(Fmt.money(amount)) \(kind.rawValue.lowercased()) at \(Fmt.trim(q.rate, 2))%")
        return nil
    }

    mutating func repayCorporateDebt(_ id: UUID) -> String? {
        guard let i = corp.debts.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let d = corp.debts[i]
        // Bonds are called at a small premium.
        let cost = d.balance * (d.kind == .greenBond ? 1.02 : 1)
        if cost > cash { return "Need \(Fmt.money(cost))." }
        cash -= cost
        if cost > d.balance { month.costInterest += cost - d.balance }
        corp.flow.debtRepaid += d.balance
        corp.debts.remove(at: i)
        Corporate.record(&self, "Repaid the \(d.kind.rawValue.lowercased()) early")
        return nil
    }

    /// Turn a convertible note into shares early (only when the shares are worth more than the conversion price).
    mutating func convertNote(_ id: UUID) -> String? {
        guard let i = corp.debts.firstIndex(where: { $0.id == id }), corp.debts[i].kind == .convertible else { return "Not found." }
        if Corporate.pricePerShare(self) < corp.debts[i].conversionPrice { return "Noteholders won't convert below \(Fmt.price(corp.debts[i].conversionPrice)) a share." }
        var d = corp.debts[i]
        Corporate.convert(&self, &d)
        corp.debts.remove(at: i)
        Corporate.record(&self, "Converted a note into shares")
        return nil
    }

    // MARK: Shareholder returns

    mutating func setDividend(quarterly: Double) -> String? {
        guard isPublic else { return "Dividends come after the IPO." }
        let q = max(0, quarterly)
        if q > 0 && q * 2 > cash { return "Keep at least twice the payout in cash." }
        let old = corp.dividendQuarterly
        corp.dividendQuarterly = q
        corp.engaged = true
        if q > old * 1.05 { sharePrice *= old == 0 ? 1.02 : 1.01 } else if q < old * 0.95 { sharePrice *= 0.94 }
        valuation = sharePrice * totalShares
        Sim.news(&self, q == 0 ? "Dividend cancelled" : (old == 0 ? "First dividend declared" : "Dividend changed"),
                 q == 0 ? "No more quarterly payouts." : "\(Fmt.money(q)) a quarter (\(Fmt.price(q / max(1, totalShares))) a share).", .finance, good: q >= old)
        Corporate.record(&self, q == 0 ? "Cancelled the dividend" : "Set the dividend to \(Fmt.money(q)) a quarter")
        return nil
    }

    var buybackRoom: Double {
        guard isPublic else { return 0 }
        let bought = corp.buybacks.filter { GameCalendar.daysBetween($0.date, date) < 365 }.reduce(0) { $0 + $1.shares }
        return max(0, min(totalShares * 0.1 - bought, publicShares * 0.5))
    }

    var buybackBlocker: String? {
        guard isPublic else { return "Buybacks come after the IPO." }
        if let last = corp.lastBuyback, GameCalendar.daysBetween(last, date) < 30 { return "One buyback a month — next \(GameCalendar.addDays(last, 30).gameShort)." }
        if buybackRoom < 1 { return "You've bought back 10% of the shares this year." }
        return nil
    }

    /// Buy your own shares in the market at a 2% premium; they're cancelled.
    mutating func buyback(amount: Double) -> String? {
        if let why = buybackBlocker { return why }
        guard amount > 0 else { return "Pick an amount." }
        let price = sharePrice * 1.02
        let shares = min(amount / price, buybackRoom)
        let spend = shares * price
        if spend > cash * 0.8 { return "Keep a cushion: spend at most \(Fmt.money(cash * 0.8))." }
        let capBefore = sharePrice * totalShares
        publicShares -= shares
        cash -= spend
        sharePrice = max(0.5, (capBefore - spend) / max(1, totalShares) * 1.01)
        valuation = sharePrice * totalShares
        corp.buybacks.append(ShareIssue(date: date, shares: shares))
        let today = date
        corp.buybacks.removeAll { GameCalendar.daysBetween($0.date, today) > 730 }
        corp.lastBuyback = date
        corp.flow.buybacks += spend
        corp.buybacksSpent += spend
        corp.engaged = true
        Sim.news(&self, "Buyback: \(Fmt.money(spend))", "Bought and cancelled \(Fmt.count(shares)) shares at \(Fmt.price(price)). Your stake is now \(Fmt.pct(founderStake)).", .finance, good: true)
        Corporate.record(&self, "Bought back \(Fmt.count(shares)) shares for \(Fmt.money(spend))")
        return nil
    }

    var tenderBlocker: String? {
        if isPublic { return "Public companies' employees sell on the market." }
        if rounds.isEmpty { return "Needs a priced round first." }
        if valuation < 1e8 { return "Buyers want a $100M valuation first." }
        if let last = corp.lastTender, GameCalendar.daysBetween(last, date) < 365 { return "One tender offer a year — next \(GameCalendar.addDays(last, 365).gameShort)." }
        if employeePoolShares < 1 { return "No employee shares left to sell." }
        return nil
    }

    /// Let employees sell part of their equity to new investors (a secondary): no cash for the company, a morale boost.
    mutating func tenderOffer(fraction: Double) -> String? {
        if let why = tenderBlocker { return why }
        let f = clamp(fraction, 0.05, 0.3)
        let shares = employeePoolShares * f
        let price = valuation / max(1, totalShares) * 0.9
        employeePoolShares -= shares
        if let i = holdings.firstIndex(where: { $0.name == "Tender offer buyers" }) {
            holdings[i].shares += shares
        } else {
            holdings.append(Holding(name: "Tender offer buyers", shares: shares))
        }
        for i in employees.indices { employees[i].morale = min(100, employees[i].morale + 8) }
        corp.lastTender = date
        corp.engaged = true
        Sim.news(&self, "Tender offer: employees sell \(Fmt.money(shares * price))", "\(Fmt.pct(f, decimals: 0)) of the employee pool sold at \(Fmt.price(price)) a share. Morale +8.", .finance, good: true)
        Corporate.record(&self, "Tender offer: employees sold \(Fmt.money(shares * price))")
        return nil
    }
}
