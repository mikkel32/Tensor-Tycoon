import Foundation

/// Money that isn't revenue: interest on cash, API repricing and the founder's own wealth.
enum Treasury {
    /// What idle cash earns in T-bills and money-market funds (percent per year).
    static func yieldRate(_ s: GameState) -> Double { max(0, Economy.fedRate(s) - 0.4 + s.traits.yield) }

    static func daily(_ s: inout GameState) {
        guard s.cash > 0 else { return }
        let interest = s.cash * yieldRate(s) / 100 / 365
        s.cash += interest
        s.month.interestIncome += interest
    }

    /// The going API rate for this model's quality ($/1M tokens), after the price cuts rivals are running.
    static func marketPrice(_ m: AIModel, _ s: GameState) -> Double {
        let c = m.c - Physics.servingPenalty(m.servingPrecision)
        return Macro.referencePrice(c: c, y: s.year) * s.market.apiPricePressure * (1 - rivalPriceCut(s))
    }

    /// The average API price cut across live rival labs (negative when distressed labs raise prices).
    static func rivalPriceCut(_ s: GameState) -> Double {
        let live = s.competitors.filter { !$0.acquired && !$0.models.isEmpty }
        guard !live.isEmpty else { return 0 }
        return clamp(live.reduce(0) { $0 + $1.priceCut } / Double(live.count), -0.2, 0.45)
    }

    /// The lowest API price you can set: what serving a million tokens of the model costs you.
    static func minPrice(_ m: AIModel, _ s: GameState, bonuses: ResearchBonuses? = nil) -> Double {
        max(0.001, (Economy.servingCostPerM(m, s, bonuses: bonuses) * 1000).rounded(.up) / 1000)
    }

    /// Where a new model's price starts: just under the going rate for its capability, never below cost.
    static func targetPrice(_ m: AIModel, _ s: GameState) -> Double {
        max(minPrice(m, s), tidy(marketPrice(m, s) * 0.85))
    }

    /// Auto-pricing keeps a model's serving chips 80–90% busy: it raises the price a few percent a day while
    /// demand outruns capacity and cuts it while chips sit idle, within 0.5–2× the going rate (which follows
    /// rivals' price cuts) and never above 2.5× the frontier rate, and never below serving cost.
    static func autoPrice(_ s: inout GameState, _ bonuses: ResearchBonuses? = nil) {
        for i in s.models.indices where s.models[i].autoPrice && !s.models[i].retired {
            let m = s.models[i]
            let market = marketPrice(m, s)
            var p = max(m.apiPrice, 0.001)
            if m.capacityTokensDay > 0 && m.released && m.api {
                let load = m.demandTokensDay / m.capacityTokensDay
                if load > 0.9 { p *= min(1.04, pow(load / 0.9, 0.25)) }
                if load < 0.8 { p *= max(0.96, pow(max(load, 0.01) / 0.8, 0.25)) }
            } else {
                // Not selling yet: drift toward the going rate.
                p += (market * 0.85 - p) * 0.05
            }
            // Never more than 2.5× what a frontier model charges, however far ahead the model is.
            let ceiling = min(market * 2, Macro.frontierPrice(s.year) * s.market.apiPricePressure * 2.5)
            p = clamp(p, min(market * 0.5, ceiling), ceiling)
            if !m.deployments.isEmpty { p = max(p, minPrice(m, s, bonuses: bonuses)) }
            s.models[i].apiPrice = max(0.001, tidy(p))
        }
    }

    /// Four significant figures: tidy on screen, fine enough that a small daily step isn't rounded away.
    static func tidy(_ p: Double) -> Double {
        guard p > 0 else { return 0 }
        let unit = pow(10, floor(log10(p)) - 3)
        return (p / unit).rounded() * unit
    }

    /// Months of runway at last month's burn (nil when profitable).
    static func runwayMonths(_ s: GameState) -> Double? {
        guard let last = s.history.last else { return nil }
        let burn = -last.profit
        guard burn > 0 else { return nil }
        return max(0, s.cash) / burn
    }

    static let founderSaleCooldownDays = 180
    static let capitalGainsTax = 0.2

    /// Price per share a founder secondary would clear at today.
    static func founderSalePrice(_ s: GameState) -> Double {
        if s.isPublic { return s.sharePrice * 0.97 }
        return s.valuation / max(1, s.totalShares) * 0.85
    }

    static func founderSaleBlocker(_ s: GameState) -> String? {
        if let last = s.lastFounderSale, GameCalendar.daysBetween(last, s.date) < founderSaleCooldownDays {
            return "Investors allow one founder sale every six months — next window \(GameCalendar.addDays(last, founderSaleCooldownDays).gameShort)."
        }
        if !s.isPublic && s.rounds.isEmpty { return "Nobody buys founder shares before you've raised a round." }
        if !s.isPublic && s.valuation < 5e7 { return "Secondary buyers want a $50M valuation first." }
        if s.founderShares < 1 { return "You have no shares left to sell." }
        return nil
    }
}

extension GameState {
    /// Sell part of your own stake. The money is yours, not the company's.
    mutating func sellFounderShares(fraction: Double) -> String? {
        if let why = Treasury.founderSaleBlocker(self) { return why }
        let f = clamp(fraction, 0.01, 0.25)
        let shares = founderShares * f
        let price = Treasury.founderSalePrice(self)
        let gross = shares * price
        founderShares -= shares
        if isPublic {
            publicShares += shares
            sharePrice *= 1 - f * 0.12
            valuation = sharePrice * totalShares
        } else {
            if let i = holdings.firstIndex(where: { $0.name == "Secondary buyers" }) {
                holdings[i].shares += shares
            } else {
                holdings.append(Holding(name: "Secondary buyers", shares: shares))
            }
        }
        let net = gross * (1 - Treasury.capitalGainsTax)
        founderCash += net
        lastFounderSale = date
        if f > 0.1 { brand = max(0, brand - 2) }
        if founderCash >= 1e9 { Achievements.unlock(&self, "liquid_billionaire") }
        Sim.news(&self, "\(founderName) sells \(Fmt.pct(f, decimals: 0)) of their stake",
                 "\(Fmt.money(gross)) at \(Fmt.price(price))/share (\(Fmt.money(net)) after tax). \(f > 0.1 ? "The press calls it a vote of no confidence. Brand −2." : "A quiet, pre-planned sale.")",
                 .finance, image: "stock_exchange", important: f > 0.1, good: true)
        return nil
    }

    mutating func setAutoPrice(_ id: UUID, _ on: Bool) {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return }
        models[i].autoPrice = on
    }
}
