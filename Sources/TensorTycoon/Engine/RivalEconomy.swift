import Foundation

/// The business behind every rival lab: revenue from its market share, compute and payroll costs, cash and runway,
/// funding rounds (the real ones until October 2026, procedural after), IPOs, distress, fire sales and bankruptcy.
/// Plus the market cycle, and your own stakes in rivals.
enum RivalEconomy {
    /// All-in cost of running one H100-equivalent for a month (owned and rented, power included).
    static func costPerH100eMonth(_ y: Double) -> Double {
        interpolate([(2016, 2_600), (2020, 2_200), (2022, 2_000), (2024, 1_600), (2025, 1_500), (2026, 1_150), (2028, 800), (2030, 600),
                     (2032, 420), (2035, 260)], at: y)
    }

    static func parent(_ c: CompetitorState, _ s: GameState) -> String? { RivalHistory.parent(c.id, at: s.year) }

    /// API revenue per day: each product's token share at its own price.
    static func apiRevenueDay(_ lab: String, _ snap: MarketSnapshot) -> Double {
        snap.api.filter { $0.lab == lab }.reduce(0) { $0 + $1.share * snap.apiTokenPool * $1.price / 1e6 }
    }

    /// Monthly revenue a lab earns from its shares of today's market.
    static func monthlyRevenue(_ c: CompetitorState, _ snap: MarketSnapshot) -> Double {
        // Most of an open-weights lab's usage runs on other people's servers.
        let open = c.def.openWeights ? 0.5 : 1
        let apiDay = apiRevenueDay(c.id, snap)
        let allAPI = snap.api.reduce(0) { $0 + $1.share * snap.apiTokenPool * $1.price / 1e6 }
        let api = apiDay * 30.4 * open
        let consumer = snap.consumerUsersPool * c.consumerShare * Market.paidConversion(price: 20, freeTier: true) * 20
        let agents = snap.agentSeatsPool * c.agentShare * 100
        // Enterprises buy from the labs that earn the API money, not the ones with the cheapest tokens.
        let enterprise = allAPI > 0 ? snap.enterprisePool / 12 * apiDay / allAPI * open : 0
        return api + consumer + agents + enterprise
    }

    /// Year-on-year revenue growth (1 = flat), when there's a year of history.
    static func growth(_ c: CompetitorState) -> Double? {
        let h = c.revenueHistory
        guard h.count >= 13, h[h.count - 13] > 1e5 else { return nil }
        return h.last! / h[h.count - 13]
    }

    static func runwayMonths(_ c: CompetitorState) -> Double? {
        let burn = c.costMonth - (c.revenueHistory.last ?? 0)
        return burn > 0 ? max(0, c.cash) / burn : nil
    }

    static func status(_ c: CompetitorState, _ s: GameState) -> String {
        if c.bankrupt { return "Bankrupt" }
        if c.acquired { return "Acquired" }
        if parent(c, s) != nil { return "Funded by parent" }
        if c.distressMonths > 0 { return "Distressed" }
        if c.isPublic { return "Public" }
        if let r = runwayMonths(c) { return r < 12 ? "Burning cash" : "Well funded" }
        return "Profitable"
    }

    // MARK: Valuation

    static func sentiment(_ s: GameState) -> Double {
        clamp(s.market.hype / 1.3, 0.5, 2) * (inCorrection(s) ? 0.65 : 1)
    }

    static func inCorrection(_ s: GameState) -> Bool { (s.correctionUntil ?? .distantPast) > s.date }

    /// What investors would pay for the lab today.
    static func targetValuation(_ c: CompetitorState, _ s: GameState) -> Double {
        let y = s.year
        let talent = Macro.frontierValuation(y) * exp(2.2 * c.def.offset(y)) * clamp(s.market.hype / 1.3, 0.5, 2)
        let g = growth(c).map { clamp(1 + (min($0, 6) - 1) * 0.12, 0.8, 1.6) } ?? 1
        let revenueValue = c.revenueRun * Macro.revenueMultiple(y) * g * sentiment(s)
        if c.id == "deepgrove" || c.id == "openweights" { return max(revenueValue * 0.8, talent * 0.4) }
        // Labs without much revenue are priced on their people and their models.
        let talentWeight = c.revenueRun < 2e9 ? 0.5 : 0.25
        return max(revenueValue, talent * talentWeight * (inCorrection(s) ? 0.65 : 1))
    }

    // MARK: Setup

    /// Fill in a lab's books when a game starts (or an older save loads): its real rounds so far, cash and staff.
    static func bootstrap(_ s: inout GameState) {
        let y = s.year
        for i in s.competitors.indices where !s.competitors[i].econReady {
            let id = s.competitors[i].id
            s.competitors[i].econReady = true
            s.competitors[i].headcount = RivalHistory.headcount(id, at: y)
            let past = (RivalHistory.rounds[id] ?? []).filter { $0.year <= y }
            for r in past { s.competitors[i].rounds.append(record(r)) }
            s.competitors[i].historyIndex = past.count
            s.competitors[i].totalRaised = past.reduce(0) { $0 + $1.amount }
            if let v = RivalHistory.valuation(id, at: y) { s.competitors[i].valuation = v }
            // Most of what they raised is already spent on compute; keep about a year of runway.
            s.competitors[i].cash = s.competitors[i].totalRaised * 0.3
            s.competitors[i].fundingFactor = 1
        }
    }

    static func record(_ r: RivalHistory.Round) -> RivalRound {
        RivalRound(date: GameCalendar.date(Int(r.year), max(1, min(12, Int((r.year - Double(Int(r.year))) * 12) + 1)), 15),
                   label: r.label, amount: r.amount, postMoney: r.post, lead: r.lead, kind: r.kind)
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        bootstrap(&s)
        let y = s.year
        let snap = Market.snapshot(s)
        let live = y >= RivalHistory.end
        for i in s.competitors.indices {
            guard !s.competitors[i].acquired, y >= s.competitors[i].def.founded.decimal else { continue }
            applyHistory(&s, i)
            operate(&s, i, snap)
            revalue(&s, i)
            if live && parent(s.competitors[i], s) == nil {
                fundraise(&s, i)
                ipo(&s, i)
            }
        }
        marketCycle(&s)
        commitments(&s)
    }

    /// Real rounds whose date has passed.
    static func applyHistory(_ s: inout GameState, _ i: Int) {
        let id = s.competitors[i].id
        let all = RivalHistory.rounds[id] ?? []
        while s.competitors[i].historyIndex < all.count, all[s.competitors[i].historyIndex].year <= s.year {
            let r = all[s.competitors[i].historyIndex]
            s.competitors[i].historyIndex += 1
            s.competitors[i].rounds.append(record(r))
            s.competitors[i].cash += r.amount
            s.competitors[i].totalRaised += r.amount
            if r.post > 0 { s.competitors[i].valuation = r.post }
            let name = s.competitors[i].def.name
            if !r.quiet && r.amount > 0 {
                Sim.news(&s, "\(name) raises \(Fmt.money(r.amount))\(r.post > 0 ? " at \(Fmt.money(r.post))" : "")",
                         "\(r.label) led by \(r.lead). \(r.kind == .strategic ? "A strategic investor: much of the money comes back as cloud and chip purchases." : "")",
                         .finance, image: "stock_exchange")
            } else if !r.quiet && r.kind == .tender {
                Sim.news(&s, "\(name) staff sell shares at \(Fmt.money(r.post))", "A secondary sale values the lab at \(Fmt.money(r.post)).", .finance, image: "stock_exchange")
            }
            if [.equity, .strategic, .rescue, .ipo].contains(r.kind) { dilute(&s, i, amount: r.amount, post: r.post) }
            if r.kind == .equity { offerStake(&s, i, amount: r.amount, post: r.post) }
        }
    }

    /// Revenue, costs and cash for the month.
    static func operate(_ s: inout GameState, _ i: Int, _ snap: MarketSnapshot) {
        let y = s.year
        let c = s.competitors[i]
        let rev = monthlyRevenue(c, snap)
        s.competitors[i].revenueHistory.append(rev)
        if s.competitors[i].revenueHistory.count > 36 { s.competitors[i].revenueHistory.removeFirst() }
        s.competitors[i].revenueRun = rev * 12
        // Staff: the real numbers until October 2026, then they grow with revenue.
        if y < RivalHistory.end {
            s.competitors[i].headcount = RivalHistory.headcount(c.id, at: y)
        } else if c.distressMonths == 0, let g = growth(c), g > 1.1 {
            s.competitors[i].headcount = Int(Double(c.headcount) * (1 + min(0.03, (g - 1) * 0.01)))
        }
        let compute = c.computeH100e * costPerH100eMonth(y)
        let payroll = Double(s.competitors[i].headcount) * Macro.salary(.researcher, y) / 12 * 1.6
        let cost = compute + payroll + rev * 0.12
        s.competitors[i].computeCostMonth = compute
        s.competitors[i].costMonth = cost
        guard parent(c, s) == nil else { return }
        s.competitors[i].cash += rev - cost
        // Before October 2026, history says they found the money: keep a few months of runway.
        if y < RivalHistory.end {
            s.competitors[i].cash = max(s.competitors[i].cash, max(0, cost - rev) * 6)
        }
        // Flush labs build more; starved ones cut. Nobody can spend much more on compute than revenue plus savings allow.
        let runway = runwayMonths(s.competitors[i])
        if y >= RivalHistory.end {
            let affordable = (rev * 1.6 + max(0, s.competitors[i].cash) / 24) / max(1, costPerH100eMonth(y))
            if c.distressMonths > 0 {
                s.competitors[i].fundingFactor = max(0.4, c.funding * 0.92)
            } else if c.computeH100e > affordable * 1.1 {
                s.competitors[i].fundingFactor = max(0.4, c.funding * 0.96)
            } else if runway == nil || runway! > 24 {
                s.competitors[i].fundingFactor = min(1.6, c.funding * 1.01)
            }
        }
    }

    static func revalue(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let y = s.year
        if y < RivalHistory.end, let v = RivalHistory.valuation(c.id, at: y) {
            s.competitors[i].valuation = v
            return
        }
        let target = targetValuation(c, s)
        if c.isPublic {
            s.competitors[i].valuation = target * s.rng.range(0.95, 1.05)
        } else {
            // Private marks move slowly, and rarely below the last round outside a crisis.
            var v = c.valuation + (target - c.valuation) * 0.2
            if let last = c.lastRound, !inCorrection(s), c.distressMonths == 0 { v = max(v, last.postMoney * 0.75) }
            s.competitors[i].valuation = max(1e7, v)
        }
    }

    // MARK: Fundraising, distress, IPO

    static func fundraise(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let rev = c.revenueHistory.last ?? 0
        let burn = max(0, c.costMonth - rev)
        let runway = burn > 0 ? max(0, c.cash) / burn : 999
        // Listed labs sell new shares at the market price when they need money.
        if c.isPublic {
            guard runway < 9 else { return }
            if s.rng.chance(inCorrection(s) ? 0.5 : 0.9) {
                let amount = clamp(max(burn * 24, c.valuation * 0.04), 1e8, c.valuation * 0.15)
                dilute(&s, i, amount: amount, post: c.valuation + amount)
                s.competitors[i].rounds.append(RivalRound(date: s.date, label: "Share offering", amount: amount, postMoney: c.valuation, lead: "public markets", kind: .equity))
                s.competitors[i].cash += amount
                s.competitors[i].totalRaised += amount
                s.competitors[i].valuation *= 0.97
                s.competitors[i].distressMonths = 0
                Sim.news(&s, "\(c.def.name) sells \(Fmt.money(amount)) of new shares", "A follow-on offering to fund its compute build-out. The stock dips 3%.", .finance, image: "stock_exchange")
            } else if runway < 4 {
                distress(&s, i)
            }
            return
        }
        let monthsSince = c.rounds.last.map { Double(GameCalendar.daysBetween($0.date, s.date)) / 30.4 } ?? 99
        let opportunistic = monthsSince > 15 && runway < 24 && s.rng.chance(0.12)
        guard runway < 9 || opportunistic else { return }
        var chance = 0.55 + (s.market.hype - 1.2) * 0.4 + (c.def.offset(s.year) + 0.3) * 0.5
        if inCorrection(s) { chance -= 0.35 }
        if c.distressMonths > 0 { chance -= 0.1 }
        if s.rng.chance(clamp(chance, 0.1, 0.95)) {
            let amount = clamp(max(burn * 24, c.valuation * 0.08), 5e7, c.valuation * 0.3)
            let step = inCorrection(s) || c.distressMonths > 0 ? s.rng.range(0.6, 0.9) : s.rng.range(1.0, 1.3)
            let post = max(c.valuation * step, amount * 3)
            let lead = s.rng.pick(NameBank.investors)
            let down = (c.lastRound?.postMoney ?? 0) > post
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            let equity = c.rounds.filter { $0.kind == .equity }.count
            let label = down ? "Down round" : (equity >= 7 ? "Growth round" : "Series \(letters[min(25, equity)])")
            dilute(&s, i, amount: amount, post: post)
            s.competitors[i].rounds.append(RivalRound(date: s.date, label: label, amount: amount, postMoney: post, lead: lead, kind: .equity))
            s.competitors[i].cash += amount
            s.competitors[i].totalRaised += amount
            s.competitors[i].valuation = post
            s.competitors[i].distressMonths = 0
            s.competitors[i].fundingFactor = min(1.6, c.funding * 1.05)
            Sim.news(&s, "\(c.def.name) raises \(Fmt.money(amount)) at \(Fmt.money(post))\(down ? " — a down round" : "")",
                     "\(label) led by \(lead). \(down ? "Investors marked the lab down from \(Fmt.money(c.lastRound?.postMoney ?? 0))." : "It buys about \(Int(min(99, (c.cash + amount) / max(1, burn)))) months of runway.")",
                     .finance, image: "stock_exchange", good: nil)
            offerStake(&s, i, amount: amount, post: post)
        } else if runway < 4 {
            distress(&s, i)
        }
    }

    static func distress(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        s.competitors[i].distressMonths += 1
        s.competitors[i].fundingFactor = max(0.4, c.funding * 0.9)
        s.competitors[i].headcount = Int(Double(c.headcount) * 0.92)
        // Out of cash, they stop subsidising tokens.
        s.competitors[i].priceCut = max(-0.2, c.priceCut - 0.05)
        switch s.competitors[i].distressMonths {
        case 1:
            Sim.news(&s, "\(c.def.name) struggles to raise", "Investors passed on its latest round. Layoffs and price rises follow; its runway is down to a few months.",
                     .finance, image: "stock_exchange", important: true)
        case 2:
            fireSaleOffer(&s, i)
        case 4...:
            fate(&s, i)
        default:
            break
        }
    }

    /// A distressed lab that can't find money: bought by a giant, rescued at a deep discount, or bankrupt.
    static func fate(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let stake = s.rivalStakes[c.id] ?? 0
        let roll = s.rng.next() % 100
        if roll < 45 {
            let price = c.valuation * s.rng.range(0.4, 0.8)
            let buyer = s.rng.pick(["a search giant", "a cloud giant", "a social-media giant", "a chip giant"])
            s.competitors[i].acquired = true
            s.competitors[i].exitNote = "Acquired by \(buyer) for \(Fmt.money(price))"
            var body = "\(buyer.prefix(1).uppercased() + buyer.dropFirst()) buys the struggling lab for \(Fmt.money(price)), mostly for its people."
            if stake > 0 {
                let payout = stake * price
                s.cash += payout
                s.month.oneOffIncome += payout - (s.rivalStakeCost[c.id] ?? 0)
                body += " Your \(Fmt.pct(stake)) stake pays \(Fmt.money(payout))."
            }
            Sim.news(&s, "\(c.def.name) sold to \(buyer)", body, .competitor, image: "nvidia_hq", important: true)
        } else if roll < 75 {
            s.competitors[i].acquired = true
            s.competitors[i].bankrupt = true
            s.competitors[i].exitNote = "Filed for bankruptcy on \(s.date.gameShort)"
            Sim.news(&s, "\(c.def.name) files for bankruptcy",
                     "The lab ran out of money. Its models go offline and its researchers are on the market — a good moment to hire.\(stake > 0 ? " Your stake is worth nothing." : "")",
                     .competitor, image: "stock_exchange", important: true, good: nil)
        } else {
            let post = c.valuation * 0.4
            let amount = max(c.costMonth * 12, 1e8)
            dilute(&s, i, amount: amount, post: post)
            s.competitors[i].rounds.append(RivalRound(date: s.date, label: "Rescue round", amount: amount, postMoney: post, lead: s.rng.pick(NameBank.investors), kind: .rescue))
            s.competitors[i].cash += amount
            s.competitors[i].valuation = post
            s.competitors[i].distressMonths = 0
            Sim.news(&s, "\(c.def.name) rescued at \(Fmt.money(post))", "A rescue round keeps the lab alive at 40% of its old value. Early investors are wiped out.", .finance, image: "stock_exchange")
            return
        }
        if stake > 0 && s.competitors[i].bankrupt {
            s.month.oneOffIncome -= s.rivalStakeCost[c.id] ?? 0
        }
        s.rivalStakes[c.id] = nil
        s.rivalStakeCost[c.id] = nil
    }

    static func ipo(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        guard !c.isPublic, c.distressMonths == 0, s.year >= RivalHistory.ipoEarliest(c.id),
              c.valuation >= Macro.frontierValuation(s.year) * 0.3, c.revenueRun >= Macro.marketSize(s.year) * 0.04, !inCorrection(s) else { return }
        guard s.rng.chance(c.id == "halcyon" ? 0.25 : 0.08) else { return }
        let pop = s.rng.range(1.0, 1.4)
        let value = c.valuation * pop
        let raised = c.valuation * 0.05
        dilute(&s, i, amount: raised, post: value)
        s.competitors[i].isPublic = true
        s.competitors[i].valuation = value
        s.competitors[i].cash += raised
        s.competitors[i].totalRaised += raised
        s.competitors[i].rounds.append(RivalRound(date: s.date, label: "IPO", amount: raised, postMoney: value, lead: "public markets", kind: .ipo))
        s.market.hype += 0.04
        Sim.news(&s, "\(c.def.name) goes public at \(Fmt.money(value))",
                 "It raised \(Fmt.money(raised)) and \(pop > 1.15 ? "popped \(Int((pop - 1) * 100))% on its first day" : "traded flat"). AI stocks rally.\((s.rivalStakes[c.id] ?? 0) > 0 ? " Your stake is now liquid." : "")",
                 .finance, image: "stock_exchange", important: true)
    }

    // MARK: Market cycle

    static func industryMultiple(_ s: GameState) -> Double {
        let labs = s.competitors.filter { !$0.acquired && parent($0, s) == nil && $0.revenueRun > 1e9 }
        let rev = labs.reduce(0) { $0 + $1.revenueRun }
        return rev > 0 ? labs.reduce(0) { $0 + $1.valuation } / rev : 0
    }

    static func marketCycle(_ s: inout GameState) {
        s.industryMultiple = industryMultiple(s)
        guard s.year >= RivalHistory.end, !inCorrection(s) else { return }
        if let last = s.lastCorrection, GameCalendar.daysBetween(last, s.date) < 365 * 4 { return }
        // Froth: rich multiples on top of euphoric sentiment eventually break.
        let froth = (s.industryMultiple > 30 ? 0.02 : 0) + (s.market.hype > 1.5 ? 0.02 : 0)
        guard s.market.hype > 1.35, froth > 0, s.rng.chance(froth) else { return }
        let before = s.competitors.filter { !$0.acquired }.reduce(0) { $0 + $1.valuation }
        s.market.hype *= 0.72
        s.correctionUntil = GameCalendar.addDays(s.date, 300)
        s.lastCorrection = s.date
        s.market.hardwarePrice = max(0.5, s.market.hardwarePrice - 0.08)
        s.market.rentPrice = max(0.5, s.market.rentPrice - 0.08)
        for i in s.competitors.indices where !s.competitors[i].acquired { s.competitors[i].valuation *= 0.7 }
        Sim.news(&s, "The AI correction: \(Fmt.money(before * 0.3)) wiped off AI valuations",
                 "Investors balked at paying \(Int(s.industryMultiple))× revenue. Rounds are smaller, down rounds are back and weaker labs may not survive — but GPUs and cloud capacity just got cheaper.",
                 .finance, image: "stock_exchange", important: true, good: false)
    }

    // MARK: Your stakes and compute deals

    static func stakeValue(_ s: GameState, _ id: String) -> Double {
        guard let f = s.rivalStakes[id], let c = s.competitors.first(where: { $0.id == id }), !c.acquired else { return 0 }
        return f * c.valuation
    }

    static func stakesValue(_ s: GameState) -> Double { s.rivalStakes.keys.reduce(0) { $0 + stakeValue(s, $1) } }

    /// New money in a lab (equity, strategic, rescue and IPO rounds — not tenders, debt or mergers) dilutes every
    /// existing holder, you included: your stake shrinks by amount ÷ post-money. A round that leaves the
    /// valuation unchanged (post 0) comes in at today's valuation. Call it before offering a slice of the round.
    static func dilute(_ s: inout GameState, _ i: Int, amount: Double, post: Double) {
        let id = s.competitors[i].id
        guard amount > 0, let f = s.rivalStakes[id], f > 0 else { return }
        let p = post > 0 ? post : s.competitors[i].valuation
        guard p > 0 else { return }
        let kept = f * max(0, 1 - amount / p)
        if kept < 1e-7 {
            // Wiped out (a rescue round bigger than the lab's new value).
            s.month.oneOffIncome -= s.rivalStakeCost[id] ?? 0
            s.rivalStakes[id] = nil
            s.rivalStakeCost[id] = nil
            Sim.news(&s, "Your stake in \(s.competitors[i].def.name) is wiped out", "The new money takes the whole company. Early investors get nothing.",
                     .finance, image: "stock_exchange", good: false)
        } else {
            s.rivalStakes[id] = kept
        }
    }

    /// Whether you sell compute (chips or leased GPUs) a rival could commit to buy.
    static func sellsCompute(_ s: GameState) -> Bool { s.chipLines.contains { $0.active } || s.leases.values.contains { $0 > 0 } }

    /// When a rival raises, a big enough player may get a slice of the round.
    static func offerStake(_ s: inout GameState, _ i: Int, amount: Double, post: Double) {
        let c = s.competitors[i]
        guard amount > 0, post > 0, s.valuation >= 1e9, s.decisions.count < 3, s.gameOver == nil else { return }
        let small = amount * 0.05
        guard s.cash >= small * 1.5, s.rng.chance(0.7) else { return }
        let big = amount * 0.15
        let deal = sellsCompute(s)
        Events.addDecision(&s, kind: "rival_round", title: "Join \(c.def.name)'s round?",
                           body: "\(c.def.name) is raising \(Fmt.money(amount)) at \(Fmt.money(post)). Strategic investors like you get an allocation. A stake rises (or falls) with their value and pays out if they're sold or go public.\(deal ? " Because you sell compute, a big cheque comes with a deal: they spend twice your investment on your chips and cloud over two years." : "")",
                           image: "stock_exchange",
                           options: [DecisionOption(label: "Invest \(Fmt.money(small))", detail: "\(Fmt.pct(small / post)) of \(c.def.name)."),
                                     DecisionOption(label: "Invest \(Fmt.money(big))", detail: "\(Fmt.pct(big / post)) of \(c.def.name)\(deal ? ", plus \(Fmt.money(big * 2 / 24))/month of compute purchases for two years" : "").") ,
                                     DecisionOption(label: "Pass", detail: "Keep your cash.")],
                           amount: amount, ref: "\(c.id)|\(post)")
    }

    static func resolveStake(_ s: inout GameState, _ d: Decision, option: Int) {
        let parts = d.ref.split(separator: "|")
        guard option < 2, parts.count == 2, let post = Double(parts[1]), let c = s.competitors.first(where: { $0.id == String(parts[0]) }) else { return }
        let invest = d.amount * (option == 0 ? 0.05 : 0.15)
        guard invest <= s.cash else {
            Sim.news(&s, "Couldn't join \(c.def.name)'s round", "You no longer had \(Fmt.money(invest)) in cash.", .finance, good: false)
            return
        }
        s.cash -= invest
        s.month.capex += invest
        s.rivalStakes[c.id, default: 0] += invest / post
        s.rivalStakeCost[c.id, default: 0] += invest
        var body = "You now own \(Fmt.pct(s.rivalStakes[c.id] ?? 0)) of \(c.def.name)."
        if option == 1 && sellsCompute(s) {
            s.computeCommitments.append(ComputeCommitment(labID: c.id, labName: c.def.name, monthly: invest * 2 / 24, monthsLeft: 24))
            body += " They'll spend \(Fmt.money(invest * 2 / 24)) a month on your compute for two years — round-tripping, the industry calls it."
        }
        Sim.news(&s, "You invested \(Fmt.money(invest)) in \(c.def.name)", body, .finance, image: "stock_exchange", good: true)
    }

    /// Compute commitments from rivals you invested in: hardware revenue with a hardware margin.
    static func commitments(_ s: inout GameState) {
        for i in s.computeCommitments.indices where s.computeCommitments[i].monthsLeft > 0 {
            let m = s.computeCommitments[i].monthly
            s.cash += m * 0.55
            s.month.revCloud += m
            s.month.costChips += m * 0.45
            s.lifetimeRevenue += m
            s.computeCommitments[i].monthsLeft -= 1
        }
        s.computeCommitments.removeAll { $0.monthsLeft <= 0 }
    }

    /// A distressed lab's board would rather sell to you than die.
    static func fireSaleOffer(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let price = c.valuation * 0.5 * (1 - (s.rivalStakes[c.id] ?? 0))
        guard s.valuation > c.valuation * 0.5, s.decisions.count < 3 else { return }
        Events.addDecision(&s, kind: "fire_sale", title: "\(c.def.name) is for sale — cheap",
                           body: "\(c.def.name) is weeks from running out of money. Its board will sell to you for \(Fmt.money(price)), half its last valuation, before a giant swoops in. You'd inherit its techniques, researchers, compute and users (regulators still get a say).",
                           image: "nvidia_hq",
                           options: [DecisionOption(label: "Buy \(c.def.name)", detail: "\(Fmt.money(price * 0.7)) cash + \(Fmt.money(price * 0.3)) in new shares."),
                                     DecisionOption(label: "Pass", detail: "Let the market decide its fate.")],
                           amount: price, ref: c.id)
    }

    static func resolveFireSale(_ s: inout GameState, _ d: Decision, option: Int) {
        guard option == 0 else { return }
        if let err = s.acquireRival(d.ref, stockShare: 0.3, priceOverride: d.amount) {
            Sim.news(&s, "The fire sale fell through", err, .competitor, good: false)
        }
    }
}

extension GameState {
    /// Sell your stake in a rival: full value if it's public, a 15% discount on the private secondary market.
    mutating func sellRivalStake(_ id: String) -> String? {
        guard let f = rivalStakes[id], f > 0, let c = competitors.first(where: { $0.id == id }) else { return "You don't own any of them." }
        let value = f * c.valuation * (c.isPublic ? 1 : 0.85)
        let cost = rivalStakeCost[id] ?? 0
        cash += value
        month.oneOffIncome += value - cost
        rivalStakes[id] = nil
        rivalStakeCost[id] = nil
        Sim.news(&self, "Sold your stake in \(c.def.name)", "\(Fmt.money(value)) for a stake that cost \(Fmt.money(cost)) — \(value >= cost ? "a gain" : "a loss") of \(Fmt.money(abs(value - cost))).",
                 .finance, image: "stock_exchange", good: value >= cost)
        return nil
    }
}
