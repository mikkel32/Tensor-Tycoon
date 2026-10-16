import Foundation

/// Money that isn't revenue: interest on cash, API repricing and the founder's own wealth.
enum Treasury {
    /// What idle cash earns in T-bills and money-market funds (percent per year).
    static func yieldRate(_ s: GameState) -> Double { max(0, Economy.fedRate(s) - 0.4) }

    static func daily(_ s: inout GameState) {
        guard s.cash > 0 else { return }
        let interest = s.cash * yieldRate(s) / 100 / 365
        s.cash += interest
        s.month.interestIncome += interest
    }

    /// The price auto-priced models move toward: just under the market rate for their capability.
    static func targetPrice(_ m: AIModel, _ s: GameState) -> Double {
        let c = m.c - Physics.servingPenalty(m.servingPrecision)
        return max(0.001, Macro.referencePrice(c: c, y: s.year) * s.market.apiPricePressure * 0.85)
    }

    static func autoPrice(_ s: inout GameState) {
        for i in s.models.indices where s.models[i].autoPrice && !s.models[i].retired {
            let target = targetPrice(s.models[i], s)
            let p = s.models[i].apiPrice + (target - s.models[i].apiPrice) * 0.05
            s.models[i].apiPrice = max(0.001, (p * 1000).rounded() / 1000)
        }
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
