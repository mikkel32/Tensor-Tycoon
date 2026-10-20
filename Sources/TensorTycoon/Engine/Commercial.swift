import Foundation

// MARK: - 3.8: go-to-market capacity

/// How much business you can actually book. A great model doesn't turn into revenue overnight: customers have to find
/// you, integrate your API, get through procurement and be supported once they're live. Two limits apply to what
/// customers pay for your models directly (API, chat subscriptions, agent seats and enterprise contracts):
///
/// - **Ramp**: booked revenue grows at most 50% a month while you hold under 1% of the AI market, easing to 35% at a
///   tenth of it and 20% if you had all of it — plus however fast the market itself is growing, so a boom like the
///   chat moment carries you with it. (Rival labs are held to 25%.) A first launch can book about 0.1% of the month's
///   AI market.
/// - **Team**: every employee can look after about 0.025% of the month's AI market and every salesperson six times
///   that, so the bar rises with the era: a garage team can't serve the world.
///
/// Demand beyond the limit isn't served by you this month: it's recorded as unbooked demand with the limit that held it
/// back, and your share of the API, chat and agent markets is scaled to what you can take on (contract revenue counts
/// first). Everything else you sell (compute, chips, licensing, product lines, programmes) is outside it.
enum Commercial {
    enum Limit: String, Sendable {
        case ramp, team

        var title: String {
            switch self {
            case .ramp: "how fast customers sign up"
            case .team: "the size of your team"
            }
        }
    }

    /// Share of a month's AI market a first launch can book.
    static let launchShare = 0.001
    /// Share of a month's AI market one employee can look after, and how many employees a salesperson counts as.
    static let perHeadShare = 0.00025
    static let salesWeight = 6.0

    struct Capacity {
        /// Monthly revenue the ramp allows.
        var ramp: Double
        /// Monthly revenue your team can look after.
        var team: Double
        /// Booked revenue it grows from (per month), and the growth it allows.
        var base: Double
        var growth: Double
        var cap: Double { min(ramp, team) }
        var limit: Limit { ramp <= team ? .ramp : .team }
    }

    static func monthlyMarket(_ s: GameState) -> Double { Macro.marketSize(s.year) / 12 }

    /// Monthly growth the go-to-market can sustain at a share of the AI market: 50% under 1%, 35% at 10%, 20% at 100%.
    static func growthAllowance(share: Double) -> Double {
        clamp(0.5 - 0.15 * log10(max(share, 1e-9) / 0.01), 0.2, 0.5)
    }

    /// How fast the AI market itself grew over the last month (1 when flat or shrinking, at most 1.3).
    static func marketGrowth(_ y: Double) -> Double { clamp(Macro.marketSize(y) / Macro.marketSize(y - 1.0 / 12), 1, 1.3) }

    /// The most a month can book on the ramp from a base month: launch floor, or the base grown by the allowance and
    /// the market's own growth.
    static func ramp(base: Double, market: Double, year: Double) -> Double {
        max(market * launchShare, base * (1 + growthAllowance(share: base / max(1, market))) * marketGrowth(year))
    }

    /// Commercial revenue booked per day in your best recent month (the last three closed months: customers don't
    /// leave because one month was weak).
    static func bookedDaily(_ s: GameState) -> Double {
        let recent = s.history.suffix(3).map { $0.commercialRevenue / Double(GameCalendar.daysInMonth($0.month)) }.max() ?? 0
        // 3.9: a lab that went dark for a few months (every model retired, an outage) wins its customers back as fast as
        // it can serve them: relationships and the brand don't vanish, so the ramp grows from 80% of its best year.
        return max(recent, 0.8 * peakBookedDaily(s))
    }

    /// Commercial revenue per day in your best month of the last twelve.
    static func peakBookedDaily(_ s: GameState) -> Double {
        s.history.suffix(12).map { $0.commercialRevenue / Double(GameCalendar.daysInMonth($0.month)) }.max() ?? 0
    }

    /// Employees counted for the team limit: everyone, with salespeople (by their weight) counting six times.
    static func teamUnits(_ s: GameState) -> Double {
        let sales = s.employees.filter { $0.role == .sales }.reduce(0.0) { $0 + $1.weight }
        return Double(s.employees.count) + (salesWeight - 1) * sales
    }

    static func capacity(_ s: GameState) -> Capacity {
        let market = monthlyMarket(s)
        let base = bookedDaily(s) * 30.44
        let g = (1 + growthAllowance(share: base / max(1, market))) * marketGrowth(s.year) - 1
        // 3.9: customers you already served are already looked after: the team limit never falls below your best month
        // of the last year, so growing past it is what takes more people.
        let team = max(teamUnits(s) * market * perHeadShare, peakBookedDaily(s) * 30.44)
        return Capacity(ramp: ramp(base: base, market: market, year: s.year), team: team, base: base, growth: g)
    }

    /// Enterprise contracts running today, per day (they're booked first).
    static func contractsDaily(_ s: GameState) -> Double { s.deals.filter(\.active).reduce(0) { $0 + $1.monthly } / 30.4 }

    /// 3.9: what contracts worth `contracts` a day actually bill. Enterprise budgets are fixed: rivals win the enterprise
    /// pool in proportion to their API business (RivalEconomy); if your contracts plus theirs would outspend it, yours
    /// are squeezed to your share. The Sim bills this, and bookings count this (not the nominal amount).
    static func enterpriseDaily(_ s: GameState, _ snap: MarketSnapshot, contracts: Double? = nil) -> Double {
        let c = contracts ?? contractsDaily(s)
        var billedAPI = 0.0, rivalsBilled = 0.0
        for p in snap.api {
            billedAPI += p.share * p.price
            if !p.isPlayer { rivalsBilled += p.share * p.price * (p.open ? 0.5 : 1) }
        }
        let rivals = billedAPI > 0 ? snap.enterprisePool / 365 * rivalsBilled / billedAPI : 0
        return c * Market.budgetFactor(c, pool: snap.enterprisePool / 365, others: rivals)
    }

    /// What the API, chat and agent demand reaching you today would pay if you took all of it.
    static func potentialDaily(_ s: GameState, _ snap: MarketSnapshot) -> Double {
        var api = 0.0
        for p in snap.api where p.isPlayer { api += p.share * snap.apiTokenPool / 1e6 * p.price }
        var chat = 0.0
        if let c = snap.consumer.first(where: \.isPlayer) {
            let conv = Market.paidConversion(price: s.chatPrice, freeTier: s.freeTier, wtp: Market.chatWTP(s))
            chat = c.share * snap.consumerUsersPool * conv * s.chatPrice / 30.4
        }
        var agents = 0.0
        if let a = snap.agents.first(where: \.isPlayer) { agents = a.share * snap.agentSeatsPool * max(1, s.agentPrice) / 30.4 }
        return api + chat + agents
    }

    /// The share of today's API, chat and agent demand your go-to-market can take on (1 when it can take it all), with
    /// what you'd leave unbooked. Called by the market each day; it records the unbooked demand on the month.
    static func reach(_ s: inout GameState, _ snap: MarketSnapshot) -> Double {
        s.corp.unbookedToday = 0
        let potential = potentialDaily(s, snap)
        guard potential > 0 else { return 1 }
        let r = reachValue(s, snap)
        if r < 0.999 {
            s.corp.unbookedToday = potential * (1 - r)
            s.month.revUnbooked += potential * (1 - r)
            s.month.bookingLimit = capacity(s).limit.rawValue
        }
        return r
    }

    /// 3.9: `reach` without recording anything, for forecasts at other prices (the Price lab). Contracts count at what
    /// they actually bill after the enterprise budget squeeze.
    static func reachValue(_ s: GameState, _ snap: MarketSnapshot) -> Double {
        let potential = potentialDaily(s, snap)
        guard potential > 0 else { return 1 }
        return clamp(roomDaily(s, snap) / potential, 0, 1)
    }

    /// 3.9: bookings per day left for API, chat and agents once contracts are counted (negative when contracts alone
    /// fill the cap).
    static func roomDaily(_ s: GameState, _ snap: MarketSnapshot) -> Double {
        capacity(s).cap / 30.44 - enterpriseDaily(s, snap)
    }

    /// 3.9: what signing a contract worth `monthly` adds a month once the bookings it pushes out are counted: while
    /// bookings are full, a contract takes the place of API, chat and agent revenue (it's booked first) and only what
    /// goes past the cap is new. Returns the net gain and the revenue displaced, per month.
    static func contractNet(_ s: GameState, _ snap: MarketSnapshot, monthly: Double) -> (net: Double, displaced: Double) {
        let potential = potentialDaily(s, snap)
        let before = enterpriseDaily(s, snap)
        let after = enterpriseDaily(s, snap, contracts: contractsDaily(s) + monthly / 30.4)
        let cap = capacity(s).cap / 30.44
        let othersBefore = min(potential, max(0, cap - before))
        let othersAfter = min(potential, max(0, cap - after))
        let displaced = (othersBefore - othersAfter) * 30.4
        return ((after - before) * 30.4 - displaced, displaced)
    }

    /// Enterprise leads come less often when your team is already fully booked.
    static func leadFactor(_ s: GameState) -> Double {
        let cap = capacity(s).cap
        guard cap > 0 else { return 1 }
        return clamp(1.2 - contractsDaily(s) * 30.4 / cap, 0.2, 1)
    }

    /// One line for the Finance page and the briefing: what held bookings back last month and what to do about it.
    static func explanation(_ r: MonthRecord) -> String? {
        guard r.revUnbooked > 1, let limit = Limit(rawValue: r.bookingLimit) else { return nil }
        switch limit {
        case .ramp: return "\(Fmt.money(r.revUnbooked)) of demand went unbooked: bookings grow at most 50% a month while you're small (20–35% once you're big), plus the market's own growth. It grows on its own."
        case .team: return "\(Fmt.money(r.revUnbooked)) of demand went unbooked: your team can't look after more customers. Hire Sales & BD (each counts as six people) or grow the team."
        }
    }
}
