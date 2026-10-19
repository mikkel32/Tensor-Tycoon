import Foundation

/// The business behind every rival lab: revenue from its market share, compute and payroll costs, cash and runway,
/// funding rounds (the real ones until October 2026, procedural after), IPOs, distress, fire sales and bankruptcy.
/// Plus the market cycle, and your own stakes in rivals.
///
/// After October 2026 every number follows the money, so a lab's figures tell one story:
/// - compute is what its revenue, cash and backers pay for (contracts move it a little each month, and the world's
///   chip supply caps everyone);
/// - staff follow revenue (sales, support, product) and compute (research and infrastructure);
/// - valuation follows revenue, or — for a lab without much — how close its best model is to the frontier;
/// - the size of its next training run follows its compute (RivalIntel.sizeRun), so a lab short of compute ships a weaker model.
enum RivalEconomy {
    /// All-in cost of running one H100-equivalent for a month (owned and rented, power included).
    static func costPerH100eMonth(_ y: Double) -> Double {
        interpolate([(2016, 2_600), (2020, 2_200), (2022, 2_000), (2024, 1_600), (2025, 1_500), (2026, 1_150), (2028, 800), (2030, 600),
                     (2032, 420), (2035, 260)], at: y)
    }

    /// What one H100-equivalent costs this lab a month: under export controls Dragon Lake runs on domestic
    /// accelerators and grey-market GPUs, paying far more for the same compute.
    static func unitCost(_ c: CompetitorState, _ s: GameState) -> Double {
        // 3.8: a lab that specialised in its own silicon runs about 20% cheaper once its chips are in (two years).
        costPerH100eMonth(s.year) * (c.id == "dragonlake" && s.market.exportControls ? 1.6 : 1) * (1 - 0.2 * Market.specialistRamp(s, c.id, .hardware, years: 2))
    }

    /// Who pays the bills when it isn't investors: a giant parent, or a state.
    static func parent(_ c: CompetitorState, _ s: GameState) -> String? {
        if let p = RivalHistory.parent(c.id, at: s.year) { return p }
        if let spec = c.spec, spec.kind == .sovereign { return spec.backer.isEmpty ? "its government" : spec.backer }
        return nil
    }

    static func isStateLab(_ c: CompetitorState) -> Bool { c.spec?.kind == .sovereign }

    /// Divisions of a giant and national labs: valued as part of something bigger.
    static func isDivision(_ c: CompetitorState) -> Bool { c.id == "deepgrove" || c.id == "openweights" || isStateLab(c) }

    /// API revenue per day: each product's token share at its own price.
    static func apiRevenueDay(_ lab: String, _ snap: MarketSnapshot) -> Double {
        snap.api.filter { $0.lab == lab }.reduce(0) { $0 + $1.share * snap.apiTokenPool * $1.price / 1e6 }
    }

    /// Monthly revenue a lab earns from its shares of today's market.
    static func monthlyRevenue(_ c: CompetitorState, _ snap: MarketSnapshot, _ s: GameState) -> Double {
        // Most of an open-weights lab's usage runs on other people's servers.
        let open = c.def.openWeights ? 0.5 : 1
        let apiDay = apiRevenueDay(c.id, snap)
        let api = apiDay * 30.4 * open
        let consumer = snap.consumerUsersPool * c.consumerShare * Market.paidConversion(price: 20, freeTier: true) * 20
        let agents = snap.agentSeatsPool * c.agentShare * 100
        return api + consumer + agents + enterpriseRevenue(c, snap, s)
    }

    /// Enterprises buy from the labs that earn the API money, not the ones with the cheapest tokens. 3.8: an enterprise
    /// push wins a lab a bigger slice (×1.35) of what the rival labs hold between them, never more than the pool: the
    /// rivals' part of the enterprise pool is their (open-discounted) API billing against everyone's, as Sim uses for you.
    static func enterpriseRevenue(_ c: CompetitorState, _ snap: MarketSnapshot, _ s: GameState) -> Double {
        let allAPI = snap.api.reduce(0) { $0 + $1.share * snap.apiTokenPool * $1.price / 1e6 }
        guard allAPI > 0 else { return 0 }
        var plain = 0.0, weighted = 0.0
        for o in s.competitors where !o.acquired {
            let w = apiRevenueDay(o.id, snap) * (o.def.openWeights ? 0.5 : 1)
            plain += w
            weighted += w * RivalStrategy.enterpriseBoost(o)
        }
        let mine = apiRevenueDay(c.id, snap) * (c.def.openWeights ? 0.5 : 1) * RivalStrategy.enterpriseBoost(c)
        guard weighted > 0 else { return 0 }
        return snap.enterprisePool / 12 * (plain / allAPI) * mine / weighted
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
        if c.acquired {
            if c.exitNote.hasPrefix("Merged") { return "Merged" }
            if c.exitNote.hasPrefix("Wound down") { return "Wound down" }
            return "Acquired"
        }
        if c.spec != nil && c.models.isEmpty { return "Pre-launch" }
        if isStateLab(c) { return "State-funded" }
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

    /// How investors rate a lab's science after October 2026: its best model's distance from the frontier, halving for
    /// every four months it trails. A lab with no model yet is priced on what its first run should deliver, at a discount.
    static func promise(_ c: CompetitorState, _ s: GameState) -> Double {
        let y = s.year
        var best = c.models.map(\.c).max() ?? -10
        var unproven = 1.0
        if c.models.isEmpty, let i = s.competitors.firstIndex(where: { $0.id == c.id }) {
            best = Competitors.plannedC(s, compIndex: i, date: c.nextRelease)
            unproven = 0.3
        }
        let behind = max(0, Macro.frontier(y) - best) / RivalStrategy.frontierPerMonth(y)
        return pow(0.5, behind / 4) * unproven
    }

    /// A lab's best model against the frontier (log10 compute; negative when behind). Before its first model, its plan.
    static func standing(_ c: CompetitorState, _ s: GameState) -> Double {
        if let best = c.models.map(\.c).max() { return best - Macro.frontier(s.year) }
        guard let i = s.competitors.firstIndex(where: { $0.id == c.id }) else { return -1 }
        return Competitors.plannedC(s, compIndex: i, date: c.nextRelease) - Macro.frontier(s.year) - 0.2
    }

    /// What investors would pay for the lab today.
    static func targetValuation(_ c: CompetitorState, _ s: GameState) -> Double {
        let y = s.year
        let live = y >= RivalHistory.end
        // Before October 2026 the labs' science is priced off their historical track; after it, off what they ship.
        let science = live ? promise(c, s) : exp(2.2 * c.def.offset(y))
        let talent = Macro.frontierValuation(y) * science * clamp(s.market.hype / 1.3, 0.5, 2)
        let g = growth(c).map { clamp(1 + (min($0, 6) - 1) * 0.12, 0.8, 1.6) } ?? 1
        let revenueValue = c.revenueRun * Macro.revenueMultiple(y) * g * sentiment(s)
        // 3.8: the frontier premium is bounded by fundamentals: at most 60× revenue, or about 1.2% of a frontier lab's
        // worth (scaled by how close its science is) for a lab that has little revenue yet.
        let cap = max(c.revenueRun * 60, Macro.frontierValuation(y) * 0.012 * science)
        if isDivision(c) { return max(revenueValue * 0.8, min(talent * (live ? 0.25 : 0.4), cap)) }
        // Labs without much revenue are priced on their people and their models.
        let talentWeight = c.revenueRun < 2e9 ? 0.5 : 0.25
        return max(revenueValue, min(talent * talentWeight, cap) * (inCorrection(s) ? 0.65 : 1))
    }

    // MARK: Setup

    /// Fill in a lab's books when a game starts (or an older save loads): its real rounds so far, cash and staff.
    static func bootstrap(_ s: inout GameState) {
        // Labs founded during the game resolve through the catalog (a no-op on a new game).
        CompetitorCatalog.register(s.customLabs)
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
        let squeeze = live ? supplySqueeze(s) : 1
        for i in s.competitors.indices {
            // A lab that left the market runs nothing and earns nothing (its exit value stays on the record).
            if live && !s.competitors[i].alive {
                if s.competitors[i].computeH100e > 0 || s.competitors[i].revenueRun > 0 { closeBooks(&s, i) }
                continue
            }
            guard !s.competitors[i].acquired, y >= s.competitors[i].def.founded.decimal else { continue }
            applyHistory(&s, i)
            operate(&s, i, snap, squeeze: squeeze)
            research(&s, i)   // 3.8: R&D buys proprietary techniques
            revalue(&s, i)
            if live && parent(s.competitors[i], s) == nil {
                fundraise(&s, i)
                ipo(&s, i)
            }
            if live { RivalIntel.sizeRun(&s, i) }
        }
        marketCycle(&s)
        commitments(&s)
        if live { RivalLifecycle.monthly(&s, snap) }
    }

    static func closeBooks(_ s: inout GameState, _ i: Int) {
        s.competitors[i].computeH100e = 0
        s.competitors[i].computePlan = 0
        s.competitors[i].revenueRun = 0
        s.competitors[i].costMonth = 0
        s.competitors[i].computeCostMonth = 0
        s.competitors[i].cash = 0
        s.competitors[i].apiShare = 0
        s.competitors[i].consumerShare = 0
        s.competitors[i].agentShare = 0
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
                Voices.historicRound(&s, i, amount: r.amount, title: "\(name) raises \(Fmt.money(r.amount))\(r.post > 0 ? " at \(Fmt.money(r.post))" : "")",
                                     body: "\(r.label) led by \(r.lead). \(r.kind == .strategic ? "A strategic investor: much of the money comes back as cloud and chip purchases." : "")")
            } else if !r.quiet && r.kind == .tender {
                Sim.news(&s, "\(name) staff sell shares at \(Fmt.money(r.post))", "A secondary sale values the lab at \(Fmt.money(r.post)).", .finance, image: "stock_exchange")
            }
            if [.equity, .strategic, .rescue, .ipo].contains(r.kind) { dilute(&s, i, amount: r.amount, post: r.post) }
            if r.kind == .equity { offerStake(&s, i, amount: r.amount, post: r.post) }
        }
    }

    /// Revenue, costs and cash for the month.
    static func operate(_ s: inout GameState, _ i: Int, _ snap: MarketSnapshot, squeeze: Double = 1) {
        let y = s.year
        let live = y >= RivalHistory.end
        let c = s.competitors[i]
        var rev = monthlyRevenue(c, snap, s) + chipSales(&s, i)
        if live, let last = c.revenueHistory.last {
            // Customers come only as fast as a lab can sign and serve them: booked revenue grows at most 25% a month
            // (a hit model still makes a young lab ten times bigger within a year).
            rev = min(rev, max(last * 1.25, 1.5e7))
        }
        s.competitors[i].revenueHistory.append(rev)
        if s.competitors[i].revenueHistory.count > 36 { s.competitors[i].revenueHistory.removeFirst() }
        s.competitors[i].revenueRun = rev * 12
        if live {
            // After October 2026 compute is what the lab can pay for, and staff follow revenue and compute.
            planCompute(&s, i, revenue: rev, squeeze: squeeze)
            staff(&s, i)
        } else {
            // Staff: the real numbers until October 2026.
            s.competitors[i].headcount = RivalHistory.headcount(c.id, at: y)
        }
        let compute = s.competitors[i].computeH100e * (live ? unitCost(c, s) : costPerH100eMonth(y))
        let payroll = live ? Double(s.competitors[i].headcount) * blendedSalary(y) / 12
            : Double(s.competitors[i].headcount) * Macro.salary(.researcher, y) / 12 * 1.6
        // A consumer blitz is mostly marketing.
        let cost = compute + payroll + rev * (RivalStrategy.play(c) == .consumer ? 0.18 : 0.12)
        s.competitors[i].computeCostMonth = compute
        s.competitors[i].costMonth = cost
        s.competitors[i].cash += rev - cost
        // 3.8: no free money. A parent or a state pays from a finite yearly budget; before October 2026 a lab that
        // history says found the money gets it as a recorded bridge round from its investors (diluting them, you
        // included), not out of thin air.
        if parent(c, s) != nil {
            parentDraw(&s, i, burn: max(0, cost - rev))
        } else if !live && s.competitors[i].cash < max(0, cost - rev) * 3 {
            bridge(&s, i, burn: max(0, cost - rev))
        }
    }

    // MARK: 3.8: parents, bridges, R&D and chips

    /// A parent's (or state's) budget for its lab this year: what it planned to spend on it (`backing`, a year of it)
    /// or, before October 2026, the lab's running costs with 20% headroom; a downturn at the parent (about one year in
    /// eight, hashed) cuts it by 40%.
    static func refreshParentBudget(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let year = s.date.ym.year
        var book = s.rivalBooks[c.id] ?? RivalBook()
        guard book.budgetYear != year else { return }
        let live = s.year >= RivalHistory.end
        let base = live ? (backing(c, s) ?? 0) * 12 : max(c.costMonth - (c.revenueHistory.last ?? 0), 0) * 12 * 1.2
        // History (before October 2026) has no downturns to replay.
        let downturn = live && book.budgetYear > 0 && RivalLifecycle.roll(s, "parentcut|\(c.id)|\(year)") < 0.12
        book.budgetYear = year
        book.annualBudget = max(0, base) * (downturn ? 0.6 : 1)
        book.parentBudget = book.annualBudget
        if downturn {
            book.squeezeUntil = GameCalendar.addMonths(s.date, 12)
            if c.alive {
                Sim.news(&s, "\(c.def.name)'s backer cuts its budget", "\(parent(c, s).map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Its parent") is tightening spending: \(c.def.name) gets 40% less this year (\(Fmt.money(book.annualBudget))). Expect slower hiring and less compute.",
                         .competitor)
            }
        }
        s.rivalBooks[c.id] = book
    }

    /// The parent covers the month's burn and keeps about three months of costs in the lab's account, until the year's
    /// budget runs out.
    static func parentDraw(_ s: inout GameState, _ i: Int, burn: Double) {
        refreshParentBudget(&s, i)
        let id = s.competitors[i].id
        guard var book = s.rivalBooks[id] else { return }
        let reserve = s.competitors[i].costMonth * 3
        let want = max(0, reserve - s.competitors[i].cash)
        let draw = min(book.parentBudget, want)
        guard draw > 0 else { return }
        book.parentBudget -= draw
        book.parentPaid += draw
        s.rivalBooks[id] = book
        s.competitors[i].cash += draw
    }

    /// Before October 2026: the lab's investors bridge it with a year of burn, recorded as a round.
    static func bridge(_ s: inout GameState, _ i: Int, burn: Double) {
        let amount = max(burn * 12, s.competitors[i].costMonth * 3)
        guard amount > 0 else { return }
        dilute(&s, i, amount: amount, post: 0)
        s.competitors[i].rounds.append(RivalRound(date: s.date, label: "Bridge funding", amount: amount, postMoney: 0, lead: "existing investors", kind: .equity))
        s.competitors[i].cash += amount
        s.competitors[i].totalRaised += amount
    }

    /// What a breakthrough of its own costs a lab in research spending (people and the compute they experiment on).
    static func techniqueCost(_ y: Double) -> Double {
        interpolateLog([(2016, 1.5e8), (2020, 6e8), (2023, 2e9), (2026, 6e9), (2030, 2e10), (2035, 6e10)], at: y, extrapolate: true)
    }

    /// R&D: a quarter of a lab's compute and half its payroll go on research. When that adds up to a breakthrough's
    /// cost, the lab bets it on a technique nobody else holds (one it could plausibly invent by now): about three bets in
    /// five pay off and the technique becomes the lab's own; the rest fail and most of the spend is gone.
    static func research(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        guard c.alive, !c.models.isEmpty else { return }
        var book = s.rivalBooks[c.id] ?? RivalBook()
        let payroll = max(0, c.costMonth - c.computeCostMonth - (c.revenueHistory.last ?? 0) * 0.12)
        book.rdPool += 0.25 * c.computeCostMonth + 0.5 * payroll
        let cost = techniqueCost(s.year)
        defer { s.rivalBooks[c.id] = book }
        guard book.rdPool >= cost else { return }
        let held = Set(s.exoticOwned).union(s.rivalTech.values.flatMap { $0 })
        let open = ResearchCatalog.exotic.filter { !held.contains($0.id) && $0.year <= s.year + 0.3 && $0.rival != nil }.map(\.id).sorted()
        guard !open.isEmpty else {
            book.rdPool = min(book.rdPool, cost * 2)
            return
        }
        let key = "rd|\(s.lifecycleSalt)|\(c.id)|\(book.techniques)|\(s.date.ym.year)-\(s.date.ym.month)"
        if RivalLifecycle.roll(s, key) < 0.6 {
            let tech = open[Int(RivalLifecycle.roll(s, key + "|pick") * Double(open.count)) % open.count]
            s.rivalTech[c.id, default: []].append(tech)
            book.rdPool -= cost
            book.techniques += 1
            let name = ResearchCatalog.byID[tech]?.name ?? tech
            RivalIntel.add(&s, c.id, c.releaseCount, kind: "breakthrough", reliability: RivalIntel.quality(s) > 0.5 ? .credible : .speculative,
                           title: "\(c.def.name) has a breakthrough of its own",
                           body: "After \(Fmt.money(cost)) of research, \(c.def.name)'s lab cracked \(RivalIntel.quality(s) > 0.5 ? name : "something new (\(ResearchCatalog.byID[tech]?.domainHint ?? "research"))"). Its next models will show it.",
                           news: true, important: false)
        } else {
            book.rdPool -= cost * 0.7
            RivalIntel.add(&s, c.id, c.releaseCount, kind: "strategy", reliability: .speculative,
                           title: "\(c.def.name)'s big research bet falls flat",
                           body: "Insiders say \(c.def.name) spent about \(Fmt.money(cost * 0.7)) on an approach that didn't scale.")
        }
    }

    /// A lab with its own silicon sells some of it to other labs and clouds: part of what the other labs spend on
    /// compute goes to it instead of to the chip makers (no new money: it's their compute spend, redirected), at most
    /// 30% of its own compute bill. Returns this month's chip revenue.
    static func chipSales(_ s: inout GameState, _ i: Int) -> Double {
        let c = s.competitors[i]
        let ramp = Market.specialistRamp(s, c.id, .hardware, years: 2)
        guard ramp > 0 else {
            if s.rivalBooks[c.id]?.chipsSold ?? 0 > 0 { s.rivalBooks[c.id]?.chipsSold = 0 }
            return 0
        }
        let others = s.competitors.filter { $0.alive && $0.id != c.id }.reduce(0) { $0 + $1.computeCostMonth }
        let sales = min(0.05 * others, 0.3 * c.computeCostMonth) * ramp
        var book = s.rivalBooks[c.id] ?? RivalBook()
        book.chipsSold = sales / max(1, unitCost(c, s))
        s.rivalBooks[c.id] = book
        return sales
    }

    // MARK: Compute and people (after October 2026)

    /// Share of revenue labs plough back into compute: high while the race is on, lower as the industry matures
    /// and whenever investors want profits.
    static func reinvestRate(_ s: GameState) -> Double {
        interpolate([(2026.8, 0.8), (2030, 0.65), (2035, 0.5)], at: s.year) * (inCorrection(s) ? 0.8 : 1)
    }

    /// Months over which a lab plans to spend the cash it has: racing labs spend fast, struggling ones slowly.
    static func spendHorizon(_ c: CompetitorState) -> Double {
        if c.distressMonths > 0 { return 40 }
        switch RivalStrategy.play(c) {
        case .race: return 14
        case .efficiency: return 30
        default: return 20
        }
    }

    /// What a parent or a state puts into its lab each month (nil for labs that live on their investors).
    /// A giant parent pays for most of its lab's usual share of the world's compute, so it stays in the race as
    /// the industry grows (the lab's own revenue pays for the rest); a state funds a fixed, slowly growing budget.
    static func backing(_ c: CompetitorState, _ s: GameState) -> Double? {
        guard parent(c, s) != nil else { return nil }
        let y = s.year
        var b: Double
        if let spec = c.spec, spec.kind == .sovereign {
            b = spec.stateBudget * pow(1.12, max(0, y - spec.founded.decimal))
        } else {
            let commitment: Double
            switch c.id {
            case "deepgrove": commitment = 0.8
            case "openweights", "xenon": commitment = 0.65
            default: commitment = 0.5
            }
            b = CompetitorCatalog.industryCompute(y) * c.def.computeShare * costPerH100eMonth(y) * commitment
        }
        return inCorrection(s) ? b * 0.8 : b
    }

    /// The world makes only so many chips: when the labs between them want more than the industry's supply, everyone
    /// gets a pro-rata share (from last month's contracts).
    static func supplySqueeze(_ s: GameState) -> Double {
        let demand = s.competitors.filter { $0.alive && s.year >= $0.def.founded.decimal }
            .reduce(0) { $0 + ($1.computePlan > 0 ? $1.computePlan : $1.computeH100e) }
        let supply = CompetitorCatalog.industryCompute(s.year) * 1.2
        return demand > supply ? supply / demand : 1
    }

    /// The compute a lab needs to train at its usual level: its usual share of the world's compute, split among the
    /// labs in business. A lab with less ships weaker models; one with more, slightly stronger ones. Measured against
    /// the world's compute rather than its rivals', so a runaway leader doesn't make everyone else's models worse.
    static func normalCompute(_ c: CompetitorState, _ s: GameState) -> Double {
        var shares = 0.0
        for o in s.competitors where o.alive && s.year >= o.def.founded.decimal { shares += usualShare(o, s) }
        var normal = CompetitorCatalog.industryCompute(s.year) * usualShare(c, s) / max(0.5, shares)
        // Export controls cap what Dragon Lake can buy; its models were always built around that.
        if c.id == "dragonlake" && s.market.exportControls { normal *= 0.6 }
        return max(1, normal)
    }

    /// A lab's usual share of the industry's compute. A lab founded during the game grows into its share over its
    /// first three years, starting from what a seed round buys.
    static func usualShare(_ c: CompetitorState, _ s: GameState) -> Double {
        guard let age = RivalLifecycle.age(c, s) else { return c.def.computeShare }
        return c.def.computeShare * clamp(0.15 + 0.85 * age / 3, 0.15, 1)
    }

    /// Set the lab's compute from its budget. Contracts move it at most 15–20% a month; a lab can't hold more than a
    /// third of the industry's compute. Its funding factor (compute against its usual share) feeds the capability of
    /// its next models.
    static func planCompute(_ s: inout GameState, _ i: Int, revenue rev: Double, squeeze: Double) {
        let y = s.year
        let c = s.competitors[i]
        let industry = CompetitorCatalog.industryCompute(y)
        let unit = unitCost(c, s)
        let reinvest = rev * reinvestRate(s)
        var budget: Double
        if let backing = backing(c, s) {
            // 3.8: a parent pays from its yearly budget: no more than what's left of it, spread over the rest of the year.
            refreshParentBudget(&s, i)
            let monthsLeft = Double(max(1, 13 - s.date.ym.month))
            let left = (s.rivalBooks[c.id]?.parentBudget ?? 0) / monthsLeft
            budget = reinvest + min(backing, left) + max(0, c.cash - c.costMonth * 3) / spendHorizon(c)
        } else {
            // Investors' money goes on compute over the spend horizon — faster, if there's a year of cash or more,
            // when that wouldn't keep the lab at its usual share (it will need to raise again sooner).
            let cash = max(0, c.cash)
            budget = reinvest + cash / spendHorizon(c)
            if c.distressMonths == 0, runwayMonths(c).map({ $0 >= 12 }) ?? true {
                budget = max(budget, min(normalCompute(c, s) * unit, reinvest + cash / 12))
            }
        }
        // 3.8: an efficiency specialist trains smaller models and buys a quarter less compute for the same results.
        let lean = Market.specialistRamp(s, c.id, .efficient, years: 1)
        let target = min(budget / unit * squeeze * (1 - 0.25 * lean), industry * 0.35)
        let prev = c.computePlan > 0 ? c.computePlan : max(1, c.computeH100e)
        var next = prev + (target - prev) * (target > prev ? 0.15 : 0.2)
        if c.distressMonths > 0 { next = min(next, prev * 0.9) }
        next = max(next, 50)
        s.competitors[i].computePlan = next
        s.competitors[i].computeH100e = next
        s.competitors[i].fundingFactor = fundingFactor(next / (1 - 0.25 * lean), s.competitors[i], s)
    }

    /// Compute against what the lab normally runs (`normalCompute`). Falling short costs capability steeply; having
    /// more helps only a little (a lab's definition already prices in the size it grows to).
    static func fundingFactor(_ compute: Double, _ c: CompetitorState, _ s: GameState) -> Double {
        clamp(compute / normalCompute(c, s), 0.1, 1.5)
    }

    /// Average pay across researchers, engineers, sales and support, with overheads.
    static func blendedSalary(_ y: Double) -> Double {
        (Macro.salary(.researcher, y) + Macro.salary(.mlEngineer, y)) / 2 * 1.3
    }

    /// How lean a founding lab runs (a secretive research lab, a famously small team).
    static func culture(_ c: CompetitorState) -> Double {
        if let spec = c.spec { return spec.leanness }
        switch c.id {
        case "aletheia": return 0.12
        case "dragonlake": return 0.45
        case "xenon": return 0.55
        default: return 1
        }
    }

    /// The team a lab needs: sales, support and product for its revenue, research and infrastructure for its compute
    /// (lean labs run a smaller research org, but customers need serving either way).
    static func staffTarget(_ c: CompetitorState, _ y: Double) -> Double {
        let perRevenue = interpolate([(2026, 4.5e6), (2028, 7e6), (2030, 1.1e7), (2035, 2.5e7)], at: y, extrapolate: true)
        let perCompute = interpolate([(2026, 800), (2028, 1_500), (2030, 3_000), (2035, 10_000)], at: y, extrapolate: true)
        return max(15, c.revenueRun / perRevenue + c.computeH100e / perCompute * culture(c))
    }

    /// Hiring moves headcount toward what the lab needs — up to 12% a month when it's far short (hypergrowth labs
    /// triple in a year), 2% when it's close; attrition takes it down 3% a month. No hiring in distress.
    static func staff(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let now = Double(max(1, c.headcount))
        let gap = staffTarget(c, s.year) / now
        var next = now * clamp(gap, 0.97, 1 + min(0.12, 0.02 + 0.02 * log2(max(1, gap))))
        if c.distressMonths > 0 { next = min(next, now) }
        s.competitors[i].headcount = max(5, Int(next.rounded()))
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
            // Private marks move slowly, and rarely below the last round outside a crisis — until that round is
            // a year and a half old (after October 2026) and the lab's numbers are all investors have to go on.
            var v = c.valuation + (target - c.valuation) * 0.2
            let fresh = y < RivalHistory.end || c.lastRound.map { GameCalendar.daysBetween($0.date, s.date) < 548 } ?? false
            if let last = c.lastRound, !inCorrection(s), c.distressMonths == 0, fresh { v = max(v, last.postMoney * 0.75) }
            s.competitors[i].valuation = max(1e7, v)
        }
    }

    // MARK: Fundraising, distress, IPO

    static func fundraise(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let rev = c.revenueHistory.last ?? 0
        let burn = max(0, c.costMonth - rev)
        let runway = burn > 0 ? max(0, c.cash) / burn : 999
        let monthsSince = c.rounds.last.map { Double(GameCalendar.daysBetween($0.date, s.date)) / 30.4 } ?? 99
        // A lab running well under its usual share of the field's compute raises to buy more, profitable or not:
        // enough to close the gap for a year and a half.
        let normal = normalCompute(c, s)
        let gap = max(0, normal - c.computeH100e) * unitCost(c, s) * 18
        // Listed labs sell new shares at the market price when they need money.
        if c.isPublic {
            let shortOfCompute = c.computeH100e < normal * 0.7 && monthsSince > 9 && c.distressMonths == 0 && s.rng.chance(0.15)
            guard runway < 9 || shortOfCompute else { return }
            if s.rng.chance(inCorrection(s) ? 0.5 : 0.9) {
                let amount = clamp(max(burn * 24, c.valuation * 0.04, gap), 1e8, c.valuation * 0.15)
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
        let opportunistic = monthsSince > 15 && runway < 24 && s.rng.chance(0.12)
        let shortOfCompute = c.computeH100e < normal * 0.7 && monthsSince > 9 && c.distressMonths == 0 && s.rng.chance(0.15)
        guard runway < 9 || opportunistic || shortOfCompute else { return }
        // Investors back labs whose models are close to the frontier.
        var chance = 0.55 + (s.market.hype - 1.2) * 0.4 + (clamp(standing(c, s), -1.2, 0.3) + 0.3) * 0.5
        if inCorrection(s) { chance -= 0.35 }
        if c.distressMonths > 0 { chance -= 0.1 }
        if s.rng.chance(clamp(chance, 0.1, 0.95)) {
            let amount = clamp(max(burn * 24, c.valuation * 0.08, gap), 5e7, c.valuation * 0.3)
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
            // A down round costs the lab people: options under water.
            if down { s.competitors[i].turmoil += 0.3 }
            Voices.round(&s, i, amount: amount, post: post, label: label, lead: lead, down: down, prevPost: c.lastRound?.postMoney ?? 0,
                         runway: burn > 0 ? Int(min(99, (c.cash + amount) / burn)) : nil,
                         title: "\(c.def.name) raises \(Fmt.money(amount)) at \(Fmt.money(post))\(down ? " — a down round" : "")",
                         body: "\(label) led by \(lead). \(down ? "Investors marked the lab down from \(Fmt.money(c.lastRound?.postMoney ?? 0))." : burn > 0 ? "It buys about \(Int(min(99, (c.cash + amount) / burn))) months of runway." : "Most of it goes on compute.")")
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
        // Layoffs: some of the people who go start something of their own.
        s.competitors[i].turmoil += 0.3
        // Out of cash, they stop subsidising tokens.
        s.competitors[i].priceCut = max(-0.2, c.priceCut - 0.05)
        switch s.competitors[i].distressMonths {
        case 1:
            Voices.labStory(&s, "distress", lab: c.id, title: "\(c.def.name) struggles to raise",
                            body: "Investors passed on its latest round. Layoffs and price rises follow; its runway is down to a few months.", .finance, image: "stock_exchange", important: true)
        case 2:
            fireSaleOffer(&s, i)
        case 4...:
            fate(&s, i)
        default:
            break
        }
    }

    /// A distressed lab that can't find money: bought by a rival lab or a giant, rescued at a deep discount, or bankrupt.
    static func fate(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let roll = s.rng.next() % 100
        if roll < 45 {
            let price = c.valuation * s.rng.range(0.4, 0.8)
            // A rival lab with the money gets first pick of the people and the compute.
            if let b = RivalLifecycle.buyer(s, for: i, price: price) {
                RivalLifecycle.takeover(&s, buyer: b, target: i, price: price, distressed: true)
                return
            }
            let giant = s.rng.pick(["a search giant", "a cloud giant", "a social-media giant", "a chip giant"])
            let buyer = RivalLifecycle.walledOff(c) ? "a state-backed tech group" : giant
            let stake = s.rivalStakes[c.id] ?? 0
            let paid = RivalLifecycle.payout(&s, i, price)
            RivalLifecycle.close(&s, i, by: "", note: "Acquired by \(buyer) for \(Fmt.money(price))")
            var body = "\(buyer.prefix(1).uppercased() + buyer.dropFirst()) buys the struggling lab for \(Fmt.money(price)), mostly for its people."
            if paid > 0 { body += " Your \(Fmt.pct(stake)) stake pays \(Fmt.money(paid))." }
            Voices.labStory(&s, "soldgiant", lab: c.id, title: "\(c.def.name) sold to \(buyer)", body: body, .competitor, image: "nvidia_hq", important: true, vars: ["giant": buyer])
            RivalLifecycle.record(&s, .acquired, lab: c.id, title: "Sold to \(buyer)", body: body, amount: price)
        } else if roll < 75 {
            let stake = (s.rivalStakes[c.id] ?? 0) > 0
            RivalLifecycle.payout(&s, i, 0)
            RivalLifecycle.close(&s, i, by: "", note: "Filed for bankruptcy on \(s.date.gameShort)", bankrupt: true)
            let body = "The lab ran out of money. Its models go offline and its researchers are on the market — a good moment to hire.\(stake ? " Your stake is worth nothing." : "")"
            Voices.labStory(&s, "bankrupt", lab: c.id, title: "\(c.def.name) files for bankruptcy", body: body, .competitor, image: "stock_exchange", important: true)
            RivalLifecycle.record(&s, .bankrupt, lab: c.id, title: "Filed for bankruptcy", body: body)
        } else {
            let post = c.valuation * 0.4
            let amount = max(c.costMonth * 12, 1e8)
            dilute(&s, i, amount: amount, post: post)
            let lead = s.rng.pick(NameBank.investors)
            s.competitors[i].rounds.append(RivalRound(date: s.date, label: "Rescue round", amount: amount, postMoney: post, lead: lead, kind: .rescue))
            s.competitors[i].cash += amount
            s.competitors[i].valuation = post
            s.competitors[i].distressMonths = 0
            let body = "A rescue round led by \(lead) keeps the lab alive at 40% of its old value. Early investors are wiped out."
            Voices.labStory(&s, "rescue", lab: c.id, title: "\(c.def.name) rescued at \(Fmt.money(post))", body: body, .finance, image: "stock_exchange", vars: ["post": Fmt.money(post)])
            RivalLifecycle.record(&s, .rescued, lab: c.id, title: "Rescued at \(Fmt.money(post))", body: body, amount: amount)
        }
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
        let body = "It raised \(Fmt.money(raised)) and \(pop > 1.15 ? "popped \(Int((pop - 1) * 100))% on its first day" : "traded flat"). AI stocks rally.\((s.rivalStakes[c.id] ?? 0) > 0 ? " Your stake is now liquid." : "")"
        Voices.ipo(&s, i, value: value, title: "\(c.def.name) goes public at \(Fmt.money(value))", body: body)
        RivalLifecycle.record(&s, .ipo, lab: c.id, title: "Went public at \(Fmt.money(value))", body: body, amount: value)
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
        Voices.correction(&s, wiped: before * 0.3, title: "The AI correction: \(Fmt.money(before * 0.3)) wiped off AI valuations",
                          body: "Investors balked at paying \(Int(s.industryMultiple))× revenue. Rounds are smaller, down rounds are back and weaker labs may not survive — but GPUs and cloud capacity just got cheaper.")
    }

    // MARK: Your stakes and compute deals

    static func stakeValue(_ s: GameState, _ id: String) -> Double {
        guard let f = s.rivalStakes[id], let c = s.competitors.first(where: { $0.id == id }), !c.acquired else { return 0 }
        return f * c.valuation
    }

    static func stakesValue(_ s: GameState) -> Double { s.rivalStakes.keys.sorted().reduce(0) { $0 + stakeValue(s, $1) } }   // 3.7: fixed order

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

    // MARK: 3.8: compute commitments run on your leased chips

    /// H100-equivalents per chip of an accelerator.
    static func h100e(_ a: Accelerator) -> Double { a.bf16 / HardwareCatalog.h100.bf16 }

    /// What a rival pays a month for one H100-equivalent of your leased capacity, rented in full (the list rate).
    static func commitRate(_ a: Accelerator, _ s: GameState) -> Double {
        ChipBusiness.listRate(a, s) * 24 * 30.4 / h100e(a)
    }

    /// H100e of each leased accelerator type already committed to rivals.
    static func committedH100e(_ s: GameState) -> [String: Double] {
        var out: [String: Double] = [:]
        for c in s.computeCommitments where c.monthsLeft > 0 && c.h100e > 0 { out[c.accelID, default: 0] += c.h100e }
        return out
    }

    /// The leased accelerator with the most H100e not yet committed to a rival, and how much.
    static func freeLeaseCapacity(_ s: GameState) -> (accelID: String, h100e: Double)? {
        let committed = committedH100e(s)
        var best: (String, Double)? = nil
        for (id, n) in s.leases.sorted(by: { $0.key < $1.key }) where n > 0 {
            guard let a = HardwareCatalog.get(id) else { continue }
            let free = Double(n) * h100e(a) - (committed[id] ?? 0)
            if free > (best?.1 ?? 0) { best = (id, free) }
        }
        return best.map { (accelID: $0.0, h100e: $0.1) }
    }

    /// The commitment a big cheque could carry: twice the investment over 24 months, as far as your uncommitted leased
    /// capacity can serve it at the list rate (nil when it can't carry a meaningful one).
    static func commitmentOffer(_ s: GameState, invest: Double) -> (accelID: String, h100e: Double, monthly: Double)? {
        guard let free = freeLeaseCapacity(s), let a = HardwareCatalog.get(free.accelID) else { return nil }
        let rate = commitRate(a, s)
        let wanted = invest * 2 / 24
        let h = min(free.h100e, wanted / rate)
        guard h * rate >= wanted * 0.05, h >= 1 else { return nil }
        return (free.accelID, h, h * rate)
    }

    /// When a rival raises, a big enough player may get a slice of the round.
    static func offerStake(_ s: inout GameState, _ i: Int, amount: Double, post: Double) {
        let c = s.competitors[i]
        guard amount > 0, post > 0, s.valuation >= 1e9, s.decisions.count < 3, s.gameOver == nil,
              !s.decisions.contains(where: { $0.kind == "rival_round" }) else { return }
        let small = amount * 0.05
        guard s.cash >= small * 1.5, s.rng.chance(0.35) else { return }
        let big = amount * 0.15
        // 3.8: a compute deal needs leased capacity to run on; it rents those chips in full at the list rate.
        let deal = commitmentOffer(s, invest: big)
        Events.addDecision(&s, kind: "rival_round", title: "Join \(c.def.name)'s round?",
                           body: "\(c.def.name) is raising \(Fmt.money(amount)) at \(Fmt.money(post)). Strategic investors like you get an allocation. A stake rises (or falls) with their value and pays out if they're sold or go public.\(deal.map { " Because you lease out compute, a big cheque comes with a deal: they rent \(Fmt.count($0.h100e)) H100e of your leased chips in full for two years (\(Fmt.money($0.monthly))/month at the list rate, paid from their cash)." } ?? "")",
                           image: "stock_exchange",
                           options: [DecisionOption(label: "Invest \(Fmt.money(small))", detail: "\(Fmt.pct(small / post)) of \(c.def.name)."),
                                     DecisionOption(label: "Invest \(Fmt.money(big))", detail: "\(Fmt.pct(big / post)) of \(c.def.name)\(deal.map { ", plus \(Fmt.money($0.monthly))/month of rented capacity for two years" } ?? "").") ,
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
        guard c.alive else {
            Sim.news(&s, "\(c.def.name)'s round is off", "\(c.exitNote). Your money stays where it is.", .finance)
            return
        }
        s.cash -= invest
        s.month.capex += invest
        s.rivalStakes[c.id, default: 0] += invest / post
        s.rivalStakeCost[c.id, default: 0] += invest
        var body = "You now own \(Fmt.pct(s.rivalStakes[c.id] ?? 0)) of \(c.def.name)."
        if option == 1, let deal = commitmentOffer(s, invest: invest) {
            var commit = ComputeCommitment(labID: c.id, labName: c.def.name, monthly: deal.monthly, monthsLeft: 24)
            commit.accelID = deal.accelID
            commit.h100e = deal.h100e
            s.computeCommitments.append(commit)
            body += " They'll rent \(Fmt.count(deal.h100e)) H100e of your leased chips in full for two years (\(Fmt.money(deal.monthly))/month from their cash) — round-tripping, the industry calls it. Recall those leases and the deal shrinks with them."
        }
        Sim.news(&s, "You invested \(Fmt.money(invest)) in \(c.def.name)", body, .finance, image: "stock_exchange", good: true)
    }

    /// Compute commitments from rivals you invested in. 3.8: the lab pays from its own cash and runs on the leased
    /// chips it rents (its compute grows by them); you earn it as lease income at full occupancy (ChipBusiness). If you
    /// recall the leases, the commitment shrinks to what's still leased; a lab that leaves the market ends it.
    static func commitments(_ s: inout GameState) {
        var used: [String: Double] = [:]
        for i in s.computeCommitments.indices where s.computeCommitments[i].monthsLeft > 0 {
            let d = s.computeCommitments[i]
            guard let ci = s.competitors.firstIndex(where: { $0.id == d.labID }), s.competitors[ci].alive else {
                s.computeCommitments[i].monthsLeft = 0
                continue
            }
            if d.h100e > 0, let a = HardwareCatalog.get(d.accelID) {
                let leased = Double(s.leases[d.accelID] ?? 0) * h100e(a) - (used[d.accelID] ?? 0)
                let live = max(0, min(d.h100e, leased))
                used[d.accelID, default: 0] += live
                let paid = d.monthly * (d.h100e > 0 ? live / d.h100e : 0)
                s.competitors[ci].cash -= paid
                s.competitors[ci].computeH100e += live
            } else {
                // A commitment from before 3.8: hardware revenue with a hardware margin, now paid from the lab's cash.
                let m = d.monthly
                s.competitors[ci].cash -= m
                s.cash += m * 0.55
                s.month.revCloud += m
                s.month.costChips += m * 0.45
                s.lifetimeRevenue += m
            }
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
