import Foundation

// MARK: - 3.8: economic crises

/// The economy's cycle. Three kinds of crisis, each with real effects that last until it passes:
///
/// - **AI-bubble correction**: when valuations run far ahead of revenue (the bubble meter), they break. Revenue and
///   hype multiples fall, private marks and their round floors follow, a listed share price drops at once, rounds are
///   smaller and rarer, debt costs a little more, and hype — which sizes every market — falls. GPUs and cloud capacity
///   get cheaper. Rival labs are marked down with you.
/// - **Credit crunch**: lenders pull back. Spreads widen by up to 3.5 points, banks and bond buyers lend only to strong
///   credits, venture debt stops, and equity rounds shrink too. More likely during a correction.
/// - **Rate shock**: the policy rate jumps by 1.5–3.5 points over a couple of months, then eases: debt costs more,
///   idle cash earns more, and long-dated growth is worth less.
///
/// The real crises of the past are played on their dates (the March 2020 pandemic freeze; the 2022 tech sell-off, whose
/// rate rises are already in the real Fed funds rate). After the real timeline ends, crises are rolled each month with
/// hashed odds (no draws from the game's random numbers), so a seed always plays the same cycle. Every effect is exactly
/// neutral when no crisis is under way.
enum Crises {
    // MARK: Effects (1 or 0 outside a crisis)

    /// The worst severity (0–1) of a kind under way today.
    static func severity(_ s: GameState, _ kind: CrisisKind) -> Double {
        s.corp.cycle.active.filter { $0.kind == kind && $0.start <= s.date && $0.end > s.date }.map(\.severity).max() ?? 0
    }

    static func crunchSeverity(_ s: GameState) -> Double { severity(s, .crunch) }

    /// Revenue and hype multiples (the lab's valuation, subsidiaries, private marks' round floors).
    static func multipleFactor(_ s: GameState) -> Double {
        (1 - 0.45 * severity(s, .correction)) * (1 - 0.15 * severity(s, .rateShock)) * (1 - 0.1 * severity(s, .crunch))
    }

    /// Size and price of equity rounds.
    static func roundFactor(_ s: GameState) -> Double {
        (1 - 0.4 * severity(s, .correction)) * (1 - 0.25 * severity(s, .crunch)) * (1 - 0.1 * severity(s, .rateShock))
    }

    /// How often term sheets arrive while you're raising.
    static func offerFactor(_ s: GameState) -> Double {
        (1 - 0.5 * severity(s, .correction)) * (1 - 0.4 * severity(s, .crunch))
    }

    /// Extra credit spread on every new loan (percentage points).
    static func spreadAdd(_ s: GameState) -> Double { 3.5 * severity(s, .crunch) + 1.0 * severity(s, .correction) }

    /// Extra points on the policy rate from a rolled rate shock: up over its first 15%, held until 60%, eased to zero
    /// by the end. Historical shocks add nothing (their rate rises are in the real Fed funds data).
    static func rateAdd(_ s: GameState) -> Double {
        var add = 0.0
        for c in s.corp.cycle.active where c.kind == .rateShock && !c.historical && c.start <= s.date && c.end > s.date {
            let span = Double(max(1, GameCalendar.daysBetween(c.start, c.end)))
            let t = Double(GameCalendar.daysBetween(c.start, s.date)) / span
            let shape = t < 0.15 ? t / 0.15 : (t < 0.6 ? 1 : max(0, (1 - t) / 0.4))
            add = max(add, (1.5 + 2 * c.severity) * shape)
        }
        return add
    }

    // MARK: The bubble meter

    struct Meter {
        var hype: Double
        var multiple: Double
        var age: Double
        var total: Double { clamp(hype + multiple + age, 0, 100) }
    }

    /// How frothy AI valuations are (0–100): hype above its normal level for the year, the industry's valuation
    /// multiple against the era's norm, and how long it's been since the last correction (froth builds up).
    static func meter(_ s: GameState) -> Meter {
        let y = s.year
        let hype = clamp((s.market.hype / max(0.5, EventCatalog.hypeBase(y)) - 1) * 150, 0, 40)
        let ind = s.industryMultiple > 0 ? s.industryMultiple : RivalEconomy.industryMultiple(s)
        let multiple = ind > 0 ? clamp((ind / Macro.revenueMultiple(y) - 0.8) * 40, 0, 40) : 0
        let since = lastStart(s, .correction) ?? s.startDate
        let age = clamp(Double(GameCalendar.daysBetween(since, s.date)) / 365 / 4 * 20, 0, 20)
        return Meter(hype: hype, multiple: multiple, age: age)
    }

    /// Monthly odds of a correction at a bubble reading: 0.2% at zero, about 1% at 50, 3.7% at 100.
    static func correctionOdds(_ bubble: Double) -> Double { 0.002 + 0.035 * pow(bubble / 100, 2) }

    static func lastStart(_ s: GameState, _ kind: CrisisKind) -> Date? {
        (s.corp.cycle.active + s.corp.cycle.past).filter { $0.kind == kind }.map(\.start).max()
    }

    // MARK: Monthly

    /// At each month close (before the valuation is re-marked): crises that ended are closed, the meter is read,
    /// history's crises are played on their dates, and after the real timeline new ones may start.
    static func monthly(_ s: inout GameState) {
        let today = s.date
        let ended = s.corp.cycle.active.filter { $0.end <= today }
        s.corp.cycle.active.removeAll { $0.end <= today }
        for c in ended {
            s.corp.cycle.past.insert(c, at: 0)
            Sim.news(&s, "The \(c.kind.title.lowercased()) is over", afterword(c.kind), .finance, image: "stock_exchange", good: true)
        }
        if s.corp.cycle.past.count > 20 { s.corp.cycle.past.removeLast(s.corp.cycle.past.count - 20) }
        s.corp.cycle.bubble = meter(s).total

        // A correction the rival economy started on its own (RivalEconomy.marketCycle) is tracked like any other.
        if RivalEconomy.inCorrection(s), severity(s, .correction) == 0, let last = s.lastCorrection, let until = s.correctionUntil,
           GameCalendar.daysBetween(last, today) <= 40 {
            s.corp.cycle.active.append(Crisis(kind: .correction, start: last, end: until, severity: 0.6,
                                             cause: "Investors balked at paying \(Int(s.industryMultiple))× revenue for AI labs."))
        }

        for h in history where !s.corp.cycle.scripted.contains(h.id) && h.start <= today && h.end > today {
            s.corp.cycle.scripted.insert(h.id)
            guard s.startDate < h.end else { continue }
            for (kind, sev) in h.kinds {
                begin(&s, Crisis(kind: kind, start: max(h.start, s.startDate), end: h.end, severity: sev, cause: h.cause, historical: true),
                      headline: h.headline, body: h.body)
            }
        }

        guard s.year >= RivalHistory.end else { return }
        let key = "\(today.ym.year)-\(today.ym.month)"
        func roll(_ tag: String) -> Double { RivalIntel.unit("crisis|\(s.lifecycleSalt)|\(tag)|\(key)") }
        func since(_ kind: CrisisKind) -> Double {
            lastStart(s, kind).map { Double(GameCalendar.daysBetween($0, today)) / 30.44 } ?? 999
        }
        // AI-bubble correction: the meter sets the odds.
        let bubble = s.corp.cycle.bubble
        if severity(s, .correction) == 0, !RivalEconomy.inCorrection(s), since(.correction) >= 24, roll("correction") < correctionOdds(bubble) {
            let sev = 0.4 + 0.5 * roll("correction-sev")
            let months = 8 + Int(roll("correction-len") * 9)
            let m = meter(s)
            let why = m.multiple >= m.hype
                ? "AI labs traded at \(Int(s.industryMultiple))× revenue against a norm of \(Int(Macro.revenueMultiple(s.year)))×"
                : "Hype ran \(Fmt.pct(s.market.hype / max(0.5, EventCatalog.hypeBase(s.year)) - 1, decimals: 0)) above its usual level"
            begin(&s, Crisis(kind: .correction, start: today, end: GameCalendar.addMonths(today, months), severity: sev,
                             cause: "\(why), and a run of disappointing earnings broke the spell (bubble meter \(Int(bubble))/100)."),
                  headline: "The AI bubble bursts", body: nil)
        }
        // Credit crunch: rare on its own, far likelier while valuations are collapsing or rates are high.
        let crunchOdds = 0.003 + (severity(s, .correction) > 0 ? 0.025 : 0) + (Economy.fedRate(s) > 6 ? 0.004 : 0)
        if severity(s, .crunch) == 0, since(.crunch) >= 30, roll("crunch") < crunchOdds {
            let sev = 0.4 + 0.5 * roll("crunch-sev")
            let months = 4 + Int(roll("crunch-len") * 7)
            let why = severity(s, .correction) > 0 ? "Losses on AI lending after the correction made banks pull back."
                : (Economy.fedRate(s) > 6 ? "With rates above 6%, a wave of defaults at leveraged datacenter developers spooked lenders."
                   : "A large private-credit fund froze withdrawals after losses on GPU-backed loans, and lenders everywhere pulled back.")
            begin(&s, Crisis(kind: .crunch, start: today, end: GameCalendar.addMonths(today, months), severity: sev, cause: why),
                  headline: "Credit crunch: lenders pull back", body: nil)
        }
        // Rate shock: inflation surprises happen whatever the AI market is doing.
        if severity(s, .rateShock) == 0, since(.rateShock) >= 48, roll("rates") < 0.004 {
            let sev = 0.3 + 0.6 * roll("rates-sev")
            let months = 12 + Int(roll("rates-len") * 13)
            begin(&s, Crisis(kind: .rateShock, start: today, end: GameCalendar.addMonths(today, months), severity: sev,
                             cause: "Inflation came in far above forecasts (energy prices, datacenter-driven power demand) and the central bank moved fast."),
                  headline: "Rate shock: the Fed moves fast", body: nil)
        }
    }

    /// A crisis begins: its one-off shocks, the market's reaction, and news that explains it.
    static func begin(_ s: inout GameState, _ c: Crisis, headline: String, body: String?) {
        s.corp.cycle.active.append(c)
        let sev = c.severity
        var hit: [String] = []
        switch c.kind {
        case .correction:
            if !c.historical {
                s.market.hype = max(0.5, s.market.hype * (1 - 0.3 * sev))
                s.market.hardwarePrice = max(0.5, s.market.hardwarePrice - 0.08 * sev)
                s.market.rentPrice = max(0.5, s.market.rentPrice - 0.08 * sev)
            }
            // Past the real timeline the rival labs are marked down with you (before it, their history is fixed).
            if s.year >= RivalHistory.end {
                for i in s.competitors.indices where !s.competitors[i].acquired { s.competitors[i].valuation *= 1 - 0.35 * sev }
                s.correctionUntil = max(s.correctionUntil ?? .distantPast, c.end)
                s.lastCorrection = c.start
            }
            if s.isPublic {
                s.sharePrice = max(0.5, s.sharePrice * (1 - 0.3 * sev))
                s.valuation = s.sharePrice * s.totalShares
                hit.append("your stock fell \(Fmt.pct(0.3 * sev, decimals: 0)) on the day")
            }
            hit.append("revenue multiples are \(Fmt.pct(0.45 * sev, decimals: 0)) lower")
            hit.append("rounds are \(Fmt.pct(0.4 * sev, decimals: 0)) smaller and term sheets rarer")
            if !c.historical { hit.append("hype (and with it demand) fell \(Fmt.pct(0.3 * sev, decimals: 0)), but GPUs and cloud capacity got cheaper") }
        case .crunch:
            if !c.historical { s.market.hype = max(0.5, s.market.hype * (1 - 0.05 * sev)) }
            if s.isPublic {
                s.sharePrice = max(0.5, s.sharePrice * (1 - 0.1 * sev))
                s.valuation = s.sharePrice * s.totalShares
            }
            hit.append("loan spreads are \(Fmt.trim(3.5 * sev, 1)) points wider")
            hit.append("banks and bond buyers lend only to strong credits")
            if sev >= 0.5 { hit.append("venture debt has stopped") }
            hit.append("equity rounds are \(Fmt.pct(0.25 * sev, decimals: 0)) smaller")
        case .rateShock:
            if s.isPublic {
                s.sharePrice = max(0.5, s.sharePrice * (1 - 0.08 * sev))
                s.valuation = s.sharePrice * s.totalShares
            }
            if !c.historical { hit.append("the policy rate will rise about \(Fmt.trim(1.5 + 2 * sev, 1)) points over the next two months") }
            hit.append("growth multiples are \(Fmt.pct(0.15 * sev, decimals: 0)) lower")
            hit.append("new debt costs more and idle cash earns more")
        }
        let until = "Expected to last until about \(c.end.gameMonth)."
        let text = (body.map { $0 + " " } ?? "") + c.cause + " For you: " + hit.joined(separator: "; ") + ". " + until
        Sim.news(&s, headline, text, .finance, image: "stock_exchange", important: true, good: false)
        Alerts.raise(&s, .corporate, key: "crisis|\(c.kind.rawValue)", title: "\(c.kind.title) under way", body: hit.prefix(2).joined(separator: "; ").capitalizedFirst + ".",
                     screen: .finance, cooldown: 0)
    }

    static func afterword(_ k: CrisisKind) -> String {
        switch k {
        case .correction: "Multiples and rounds are back to normal for the market's mood. Marks recover as the months go by."
        case .crunch: "Banks and bond buyers are lending again at normal spreads."
        case .rateShock: "The policy rate is back on its usual path."
        }
    }

    // MARK: History

    struct Historical {
        let id: String
        let start: Date
        let end: Date
        let kinds: [(CrisisKind, Double)]
        let headline: String
        let body: String
        let cause: String
    }

    /// The real crises the timeline passes through.
    static let history: [Historical] = [
        Historical(id: "covid2020", start: GameCalendar.date(2020, 3, 1), end: GameCalendar.date(2020, 7, 1),
                   kinds: [(.crunch, 0.6), (.correction, 0.3)],
                   headline: "Pandemic panic freezes markets",
                   body: "Stocks fell a third in a month and credit markets seized up as the world locked down.",
                   cause: "COVID-19 shut economies overnight."),
        Historical(id: "selloff2022", start: GameCalendar.date(2022, 5, 1), end: GameCalendar.date(2023, 2, 1),
                   kinds: [(.rateShock, 0.6), (.correction, 0.4)],
                   headline: "Tech sell-off as rates climb",
                   body: "The Fed is raising rates at the fastest pace in forty years; growth stocks and late-stage private rounds are being repriced.",
                   cause: "Inflation hit 9% and the Fed answered with 75-point hikes."),
    ]
}
