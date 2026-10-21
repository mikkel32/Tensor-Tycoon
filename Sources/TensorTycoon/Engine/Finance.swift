import Foundation

enum Finance {
    static func daily(_ s: inout GameState) {
        // Fundraising: investors trickle in with term sheets.
        let before = s.raiseOffers.count
        s.raiseOffers.removeAll { $0.expires < s.date }
        if s.raising { s.raiseOffersExpired += before - s.raiseOffers.count }
        if s.raising {
            let started = s.lastRaise ?? s.date
            if s.raiseOffers.count < 3 && s.rng.chance(0.07 * Crises.offerFactor(s)) {   // 3.8: fewer term sheets in a crisis
                makeOffer(&s)
            }
            if GameCalendar.daysBetween(started, s.date) > 60 && s.raiseOffers.isEmpty {
                s.raising = false
                let lapsed = s.raiseOffersExpired
                Sim.news(&s, "Fundraise stalled",
                         lapsed > 0 ? "After two months no term sheet is open: \(lapsed) offer\(lapsed == 1 ? "" : "s") expired unanswered (each lasts 14 days). Start again and accept one in time."
                                    : "After two months of pitches no investor bit. Improve your model or traction and try again.",
                         .finance, important: true, good: false)
            }
        }

        // Public markets: daily share price random walk toward fundamentals.
        if s.isPublic {
            let fundamental = privateValue(s) / max(1, s.totalShares)
            let gap = log(max(fundamental, 0.01) / max(s.sharePrice, 0.01))
            let vol = 0.022 * s.market.hype
            let r = gap * 0.02 + s.rng.gaussian() * vol
            s.sharePrice = max(0.5, s.sharePrice * exp(r))
            s.valuation = s.sharePrice * s.totalShares
            if GameCalendar.components(s.date).day % 2 == 0 {
                s.stock.append(StockPoint(date: s.date, price: s.sharePrice))
                if s.stock.count > 1500 { s.stock.removeFirst(s.stock.count - 1500) }
            }
        }
    }

    /// Valuation ignoring the current share price (used as the fundamental anchor once public).
    static func privateValue(_ s: GameState) -> Double {
        var t = s
        t.isPublic = false
        return Economy.valuation(t)
    }

    static func makeOffer(_ s: inout GameState) {
        let v = privateValue(s)
        let strategic = s.rng.chance(s.year > 2019 ? 0.3 : 0.1)
        // Investors price off where the company is marked (which moves slowly) and where its fundamentals say
        // it's heading. Lab identity and how much the board believes in you move the price. 3.8: an up-round reaches at
        // most 8× the current mark, and a crisis prices every round lower.
        let anchor = s.valuation > 0 && !s.isPublic ? min((s.valuation * v).squareRoot(), s.valuation * 8) : v
        var pre = anchor * s.rng.range(0.85, 1.2) * (strategic ? 1.15 : 1) * max(0.6, 1 + s.traits.valuation) * Board.valuationFactor(s) * HQ.investorFactor(s, value: anchor)
            * Crises.roundFactor(s)
        if s.valuation > 0 && !s.isPublic { pre = min(pre, s.valuation * 6) }   // 3.8: no round re-prices a company more than 6× in one go
        pre = max(pre, 2_000_000)
        let f = s.raiseFraction
        let cap = maxRaise(s.year) * s.rng.range(0.5, 1.0) * Crises.roundFactor(s)
        let amount = min(pre * f / (1 - f), cap)
        let investor = strategic ? "Nimbus Cloud (strategic)" : s.rng.pick(NameBank.investors.filter { !$0.contains("strategic") })
        let credits = strategic ? amount * 0.4 : 0
        let offer = RaiseOffer(investor: investor, amount: amount, preMoney: pre, expires: GameCalendar.addDays(s.date, 14),
                               roundName: Economy.roundName(amount: amount, index: s.rounds.count), cloudCredits: credits)
        s.raiseOffers.append(offer)
        Sim.news(&s, "Term sheet: \(investor)",
                 "\(Fmt.money(amount)) at \(Fmt.money(pre)) pre-money (\(Fmt.pct(amount / (pre + amount), decimals: 1)) dilution)\(strategic ? ", 40% paid as cloud credits" : ""). Expires in 14 days.",
                 .finance, image: "sf_skyline", important: true, good: true)
        Alerts.raise(&s, .termSheet, key: offer.id.uuidString, title: "Term sheet from \(investor)",
                     body: "\(Fmt.money(amount)) at \(Fmt.money(pre)) pre-money. It expires in 14 days.", screen: .funding, cooldown: 0)
    }

    /// Largest private round the market can absorb in a given year (OpenAI's $40B in 2025 was a record).
    static func maxRaise(_ y: Double) -> Double {
        interpolateLog([(2016, 1.5e8), (2020, 1e9), (2023, 1e10), (2025, 4e10), (2027, 6e10), (2030, 1e11)], at: y, extrapolate: true)
    }

    /// 3.8: one credit system. The score the rating agencies compute (Corporate.metrics: leverage, interest cover,
    /// size, liquidity, runway) is mapped onto the 300–850 scale band by band, so the credit score and the corporate
    /// rating always read the same letter; the score moves 30% of the way each month, and bounced payments cost more.
    static func updateCreditScore(_ s: inout GameState) {
        let m = Corporate.metrics(s, closing: true)
        var target = Corporate.creditScore(forScore: m.score)
        if s.cash < 0 { target -= 150 }
        s.creditScore = clamp(s.creditScore * 0.7 + target * 0.3, 300, 850)
    }

    static func payLoans(_ s: inout GameState) {
        for i in s.loans.indices {
            let interest = s.loans[i].balance * s.loans[i].rate / 100 / 12
            var principal = min(s.loans[i].balance, s.loans[i].payment - interest)
            if s.loans[i].monthsLeft <= 1 { principal = s.loans[i].balance }
            principal = max(0, principal)
            s.cash -= interest + principal
            s.month.costInterest += interest
            Books.post(&s, .repayments, -principal)   // 3.8
            s.loans[i].balance -= principal
            s.loans[i].monthsLeft -= 1
            if s.cash < 0 {
                s.creditScore -= 25
                if s.loans[i].kind == .gpuBacked && s.daysNegativeCash > 20 {
                    // 3.8: the lender takes chips for the balance: no cash moves, the difference to their book value is a gain or loss.
                    let book = seizeCollateral(&s, value: s.loans[i].balance)
                    s.month.assetGains += s.loans[i].balance - book
                    s.loans[i].balance = 0
                }
            }
        }
        let paidOff = s.loans.filter { $0.balance <= 1 }
        s.loans.removeAll { $0.balance <= 1 }
        for l in paidOff {
            Sim.news(&s, "Loan repaid: \(l.kind.rawValue)", "You've paid off \(Fmt.money(l.principal)). Your credit score thanks you.", .finance, good: true)
        }
    }

    /// Hands the lender chips worth `value` at resale; returns their book value.
    @discardableResult
    static func seizeCollateral(_ s: inout GameState, value: Double) -> Double {
        var remaining = value
        var seized = 0
        var book = 0.0
        for i in s.owned.indices where remaining > 0 {
            guard let a = HardwareCatalog.get(s.owned[i].accelID) else { continue }
            let unit = Economy.resaleValue(a, s, unitCost: s.owned[i].unitCost, purchased: s.owned[i].purchased)
            let n = min(s.owned[i].count, Int(ceil(remaining / max(unit, 1))))
            book += Books.book(s.owned[i], chips: n, at: s.date)
            s.owned[i].count -= n
            seized += n
            remaining -= Double(n) * unit
        }
        s.owned.removeAll { $0.count <= 0 }
        Sim.news(&s, "Lender seizes \(Fmt.int(seized)) accelerators", "You defaulted on a GPU-backed loan. The collateral has been repossessed.",
                 .finance, image: "gpu_cluster", important: true, good: false)
        return book
    }

    static func settleSupplyDeals(_ s: inout GameState) {
        for i in s.supplyDeals.indices where s.supplyDeals[i].nextSettlement <= s.date {
            let d = s.supplyDeals[i]
            let shortfall = max(0, d.annualCommit - d.spentThisYear)
            if shortfall > 0 {
                let penalty = shortfall * 0.5
                s.cash -= penalty
                s.month.costOther += penalty
                Sim.news(&s, "\(d.vendor) take-or-pay penalty: \(Fmt.money(penalty))", "You spent \(Fmt.money(d.spentThisYear)) of your \(Fmt.money(d.annualCommit)) commitment this year.",
                         .finance, important: true, good: false)
            }
            s.supplyDeals[i].spentThisYear = 0
            s.supplyDeals[i].yearsLeft -= 1
            s.supplyDeals[i].nextSettlement = GameCalendar.addMonths(d.nextSettlement, 12)
        }
        let ended = s.supplyDeals.filter { $0.yearsLeft <= 0 }
        s.supplyDeals.removeAll { $0.yearsLeft <= 0 }
        for d in ended {
            Sim.news(&s, "\(d.vendor) supply agreement ended", "Renew it in the Hardware Store to keep priority allocation.", .hardware)
        }
    }

    static func monthlyRate(_ s: inout GameState) {
        if Macro.historicalRate(s.year) == nil {
            // After the real data ends, rates random-walk with mean reversion toward 3%.
            var r = s.market.interestRate <= 1.0 ? 3.4 : s.market.interestRate
            r += (3.0 - r) * 0.04 + s.rng.gaussian() * 0.12
            s.market.interestRate = clamp(r, 0.1, 9)
        } else {
            s.market.interestRate = Macro.historicalRate(s.year) ?? 3
        }
    }
}

enum Monthly {
    static func close(_ s: inout GameState) {
        let b = s.bonuses
        Partners.monthly(&s)
        Xeno.monthly(&s)
        XenoScience.monthly(&s)
        ResearchLab.monthly(&s)
        Moonshots.monthly(&s)   // 3.4: late game
        AdvancedProjects.monthly(&s)   // 3.5: advanced projects
        Semis.monthly(&s)   // 3.5: semiconductors
        SecurityOps.monthly(&s)
        Policy.monthly(&s)
        RivalIntel.monthly(&s)
        HQ.monthly(&s)   // 3.5: grants, partnerships and contracts from home
        if s.publication == .secret { s.brand = max(0, s.brand - 0.25) }
        // Enterprise contracts tick
        for i in s.deals.indices where s.deals[i].active {
            s.deals[i].monthsLeft -= 1
            if s.deals[i].breaches > 6 {
                s.deals[i].active = false
                s.deals[i].expires = .distantPast   // 3.9: gone, not back among the leads with its breaches wiped
                s.brand = max(0, s.brand - 4)
                Sim.news(&s, "\(s.deals[i].client) cancels its contract", s.deals[i].modelID == nil ? "Repeated SLA breaches: none of your models met their Intelligence Index bar." : "Repeated SLA breaches: your capacity couldn't keep up with their traffic.",
                         .company, important: true, good: false)
            }
            s.deals[i].breaches = 0
        }
        let finished = s.deals.filter { $0.active && $0.monthsLeft <= 0 }
        s.deals.removeAll { ($0.active && $0.monthsLeft <= 0) || (!$0.active && $0.expires < s.date) }
        for d in finished {
            Sim.news(&s, "Contract completed: \(d.client)", "The \(d.title) contract ran its full term.", .company, good: true)
        }
        Business.generateDeals(&s, b)

        Corporate.monthly(&s)   // 3.5: corporate — subsidiaries trade, corporate debt is serviced, dividends paid
        Finance.payLoans(&s)
        Finance.monthlyRate(&s)
        Finance.settleSupplyDeals(&s)

        // 3.8: depreciation of owned accelerators and datacenter shells (a cost with no cash), before tax
        Books.depreciate(&s)
        // Taxes on the month's profit, after losses carried forward
        let pre = s.month.revenue + s.month.interestIncome + s.month.oneOffIncome + s.month.assetGains - s.month.opex
            - s.month.costDepreciation - s.month.costInterest
        HQ.settleTaxes(&s, pre: pre)   // 3.5: the home country's rate and R&D credit (21% in the US)

        // Market modifiers drift back to normal
        let target = EventCatalog.hypeBase(s.year)
        s.market.hype += (target - s.market.hype) * 0.08
        s.market.hardwarePrice += (1 - s.market.hardwarePrice) * 0.06
        s.market.consumerGPUPrice += (1 - s.market.consumerGPUPrice) * 0.08
        s.market.rentPrice += (1 - s.market.rentPrice) * 0.07
        s.market.leadTimeDays += (21 - s.market.leadTimeDays) * 0.1
        s.market.apiPricePressure += (1 - s.market.apiPricePressure) * 0.08
        s.market.buildDelay += (1 - s.market.buildDelay) * 0.03

        // Brand: decays, marketing and leadership grow it
        let marketingBoost = s.marketingBudget > 0 ? 3.0 * log10(1 + s.marketingBudget / 50_000) : 0
        let sales = s.employees.filter { $0.role == .sales }.reduce(0.0) { $0 + $1.weight }
        var leader = 0.0
        if let top = Leaderboard.entries(s, includeUnreleased: false).first, top.isPlayer { leader = 4 }
        // Brand drifts toward what your reach and quality "deserve"
        let bestReleased = s.releasedModels.map(\.c).max() ?? -10
        let quality = 30 * exp(1.5 * min(0, bestReleased - Macro.frontier(s.year)))
        let reach = 9 * log10(1 + s.consumerUsers / 1e5) + 6 * log10(1 + (s.history.last?.revAPI ?? 0) / 1e5)
        let deserved = clamp(8 + quality + reach, 0, 92)
        s.brand += (deserved - s.brand) * 0.08
        s.brand = clamp(s.brand + marketingBoost * 0.5 + min(2, sales * 0.2) + leader + (s.reliability - 0.9) * 5 + s.traits.brand, 0, 100)

        // Safety score: team + research + released models
        let safetyTeam = s.workforce(.safety)
        let released = s.releasedModels
        let modelSafety = released.isEmpty ? 40 : released.map(\.safety).reduce(0, +) / Double(released.count)
        // 3.9: bumps from decisions, bills and security events since the last close carry over and fade 10% a month,
        // instead of snapping back when the score is rebuilt.
        if s.safetyLastClose > 0 { s.safetyAdjust += s.safetyScore - s.safetyLastClose }
        s.safetyAdjust = clamp(s.safetyAdjust * 0.9, -30, 30)
        s.safetyScore = clamp(modelSafety * 0.6 + b.safety * 0.4 + min(25, safetyTeam * 4) + 10 * s.swarmSafety + s.traits.safety * 0.5
                              + (s.lawsPassed.contains("transparency") ? 5 : 0) + s.safetyAdjust, 0, 100)
        s.safetyLastClose = max(0.01, s.safetyScore)   // never 0, which means "not tracked yet"

        People.monthly(&s)
        Competitors.monthly(&s)
        Events.monthly(&s)
        Board.monthly(&s)
        StrategyEvents.monthly(&s)
        Cast.monthly(&s)   // 3.4: careers
        Victory.monthly(&s)
        Xeno.rivalDiscovery(&s)
        World.monthly(&s)   // 3.4: world and stakeholders
        Nations.monthly(&s)   // 3.7: national strategies and economies, rival specialisations and answers
        WorldMap.monthly(&s)   // 3.9: world map — new places and continents

        Crises.monthly(&s)   // 3.8: corrections, credit crunches and rate shocks start and end

        // Valuation and records. A private company's mark moves halfway (in log terms) toward its new level each
        // month, so one launch or one bad month doesn't swing it 40× or wipe out two thirds of it overnight.
        let mark = Economy.valuation(s)
        if !s.isPublic && s.valuation > 0 && mark > 0 {
            s.valuation = Economy.smoothedMark(old: s.valuation, new: mark, floor: Economy.roundFloor(s))   // 3.8: at most +60% / −30% a month
        } else {
            s.valuation = mark
        }
        Finance.updateCreditScore(&s)
        Corporate.closeBooks(&s)   // 3.5: corporate — rating, covenants, audits and the statements snapshot
        s.month.cashEnd = s.cash
        s.month.valuation = s.valuation
        s.month.bestIndex = s.models.map(\.index).max() ?? 0
        s.month.chips = Double(Economy.totalChips(s))
        var record = s.month
        Briefing.snapshot(s, &record)
        s.month = record
        Briefing.build(&s, record)
        s.history.append(s.month)
        if s.history.count > 480 { s.history.removeFirst() }
        s.month = MonthRecord(month: GameCalendar.date(s.date.ym.year, s.date.ym.month, 1))
        Books.open(&s)   // 3.8: the next month reconciles against today's cash
        if (s.history.last?.profit ?? 0) > 0 { s.achievements.insert("profitable") }
    }
}

enum Business {
    static func generateDeals(_ s: inout GameState, _ b: ResearchBonuses) {
        s.deals.removeAll { !$0.active && $0.expires < s.date }
        guard let best = s.releasedModels.max(by: { $0.index < $1.index }) else { return }
        let sales = s.employees.filter { $0.role == .sales }.reduce(0.0) { $0 + $1.weight }
        let pending = s.deals.filter { !$0.active }.count
        guard pending < 4 else { return }
        let frontier = Macro.frontier(s.year)
        var p = clamp(0.15 + sales * 0.12 + s.brand / 300, 0, 0.9) * (1 + b.enterpriseDemand) * max(0.3, 1 + s.traits.enterprise)
        if s.lawsPassed.contains("liability") { p *= clamp(1 + (s.safetyScore - 50) / 150, 0.6, 1.4) }
        // Rivals running enterprise pushes win some of the deals that would have come to you.
        p *= RivalStrategy.playerDealFactor(s)
        p *= Corporate.dealFactor(s)   // 3.5: a consulting arm brings leads (exactly 1 without one)
        p *= Nations.dealFactor(s)   // 3.7: a growing home economy buys more
        p *= Launches.dealFactor(s)   // 3.7: enterprise-first launches and the Startup stage (exactly 1 without either)
        p *= Commercial.leadFactor(s)   // 3.8: a team already fully booked finds fewer new leads
        let n = s.rng.chance(p) ? (s.rng.chance(p * 0.5) ? 2 : 1) : 0
        for _ in 0..<n {
            let titles = s.year < 2022 ? ["custom NLP model", "document classification", "translation pipeline", "search ranking", "chatbot pilot"]
                                       : ["customer-support agents", "coding assistant rollout", "document intelligence", "internal copilot",
                                          "research assistant", "claims automation", "contract review", "voice agents"]
            let title = s.rng.pick(titles)
            let size = Macro.marketSize(s.year) * Macro.segmentSplit(s.year, chatMoment: s.chatMoment != nil).enterprise
            // A typical deal is a tiny slice of the enterprise market, sized by how well your best model does this
            // kind of work against the frontier (3.8: its domain mix, not one capability number).
            var monthly = size / 12 * s.rng.range(0.00002, 0.0004) * Capabilities.dealFit(s, title: title) * (1 + sales * 0.05)
            // 3.9: a lab with a real slice of the API market gets the big accounts too: contract size grows with your share
            // (×1 at none, ×4 at 15%, ×9 at 40%), since the enterprise pool is shared in proportion to it.
            monthly *= 1 + 20 * min(0.4, playerAPIShare(s))
            monthly = max(monthly, 8_000)
            let months = [6, 12, 12, 24, 36][s.rng.int(0, 4)]
            // Clients size their token needs at the market rate for a near-frontier model, not at your price.
            let price = max(0.05, Macro.referencePrice(c: frontier - 0.3, y: s.year) * s.market.apiPricePressure)
            let tokens = monthly / 30.4 / price * 1e6 * s.rng.range(0.4, 0.9)
            // The bar is set by what the market offers (85–100% of the best rival flagship), so some leads
            // need a better model than you have.
            let deal = EnterpriseDeal(client: s.rng.pick(NameBank.clients), title: title, monthly: monthly,
                                      tokensPerDay: tokens, months: months, monthsLeft: months,
                                      minIndex: marketBar(s, fallback: best.index) * s.rng.range(0.85, 1.0),
                                      minSafety: s.rng.range(20, 70), expires: GameCalendar.addDays(s.date, 30))
            s.deals.append(deal)
            Sim.news(&s, "Enterprise lead: \(deal.client)", "\(Fmt.money(monthly))/month for \(deal.title), \(months) months. Review it in Market.",
                     .market, important: false, good: true)
        }
    }

    /// Your share of API demand today (0 without a model on sale).
    static func playerAPIShare(_ s: GameState) -> Double {
        Market.snapshot(s).api.filter(\.isPlayer).reduce(0) { $0 + $1.share }
    }

    /// The Intelligence Index of the best rival flagship on the market (`fallback` if there is none).
    static func marketBar(_ s: GameState, fallback: Double) -> Double {
        s.competitors.filter { !$0.acquired }.compactMap { $0.latest?.index }.max() ?? fallback
    }

    /// Your best released model that meets a contract's bar (nil if none does).
    static func qualifyingModel(_ d: EnterpriseDeal, _ s: GameState) -> AIModel? {
        s.releasedModels.filter { $0.index + 0.01 >= d.minIndex }.max { $0.index < $1.index }
    }

    /// Contracts whose model is gone (retired, or never set) move to your best model that meets their bar.
    /// If none does, they stay unserved and breach their SLA every day until the client walks.
    static func rehomeDeals(_ s: inout GameState, from retired: UUID? = nil) {
        var moved: [String] = [], stranded: [String] = []
        for i in s.deals.indices where s.deals[i].active && s.deals[i].tokensPerDay > 0 {
            let current = s.deals[i].modelID
            let gone = current == nil || current == retired || !s.releasedModels.contains { $0.id == current }
            guard gone else { continue }
            if let m = qualifyingModel(s.deals[i], s) {
                s.deals[i].modelID = m.id
                moved.append("\(s.deals[i].client) → \(m.name)")
            } else {
                s.deals[i].modelID = nil
                stranded.append(s.deals[i].client)
            }
        }
        if !moved.isEmpty {
            Sim.news(&s, "Contracts moved to another model", "\(moved.joined(separator: ", ")). Make sure it has the capacity.", .company)
        }
        if !stranded.isEmpty {
            Sim.news(&s, "\(stranded.count) contract\(stranded.count == 1 ? " has" : "s have") no model good enough",
                     "\(stranded.joined(separator: ", ")) need\(stranded.count == 1 ? "s" : "") a better model than you have released. They'll breach their SLA every day until you assign one in Market.",
                     .company, important: true, good: false)
        }
    }
}
