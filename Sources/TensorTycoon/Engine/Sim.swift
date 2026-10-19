import Foundation

enum Sim {
    // MARK: - Daily tick

    static func advanceDay(_ s: inout GameState) {
        guard s.gameOver == nil else { return }
        let oldMonth = s.date.ym
        s.date = GameCalendar.addDays(s.date, 1)
        let b = s.bonuses

        hardwareNews(&s)
        historicalEvents(&s)
        deliveries(&s)
        rentalExpiry(&s)
        siteConstruction(&s)
        rebalance(&s, Economy.pools(s))
        Operations.daily(&s, b)
        s.xenoInsightToday = 0
        Training.daily(&s, b)
        Families.daily(&s, b)   // 3.5: model families (distillation, post-training)
        RSI.daily(&s, b)
        Swarms.daily(&s, b)
        Silicon.daily(&s)
        Xeno.daily(&s, b)
        SecurityOps.daily(&s)
        ResearchLab.daily(&s, b)
        DataEconomy.daily(&s)   // 3.6: data economy
        FoundingKit.daily(&s)   // 3.5: starter quests
        XenoScience.daily(&s)
        Science.daily(&s)   // 3.6: science labs
        Treasury.autoPrice(&s, b)
        dailyMarket(&s, b)
        ChipBusiness.daily(&s)
        dailyCosts(&s, Economy.pools(s))
        Treasury.daily(&s)
        Competitors.daily(&s)
        Capabilities.daily(&s)   // 3.4: domain scores, milestones, product lines
        RivalIntel.daily(&s)
        Finance.daily(&s)
        Events.daily(&s)
        if GameCalendar.components(s.date).day % 7 == 3 { BenchLife.weekly(&s) }
        World.daily(&s)   // 3.4: world and stakeholders
        AdvancedProjects.daily(&s)   // 3.5: advanced projects
        Semis.daily(&s)   // 3.5: semiconductors (nothing until you hire a team or book capacity)
        if GameCalendar.components(s.date).day % 7 == 5 { Pulse.weekly(&s) }   // 3.4: industry chatter and buzz
        Launches.daily(&s)   // 3.7: launch reports and rivals' lagged answers
        if GameCalendar.components(s.date).day % 7 == 1 { Progression.weekly(&s) }   // 3.7: company stages

        if s.date.ym != oldMonth { Monthly.close(&s) }
        Achievements.check(&s)
        checkSolvency(&s)
        Fun.daily(&s)   // 3.5: conferences, challenges, hackathons, scenarios
        Alerts.daily(&s)
        Alerts.applyStandingAnswers(&s)
        Alerts.expireInbox(&s)
    }

    // MARK: - News helper

    static func news(_ s: inout GameState, _ title: String, _ body: String, _ cat: NewsCategory,
                     image: String? = nil, important: Bool = false, good: Bool? = nil) {
        s.news.insert(NewsItem(date: s.date, title: title, body: body, category: cat, image: image, important: important, good: good), at: 0)
        if s.news.count > 400 { s.news.removeLast(s.news.count - 400) }
        s.unreadNews += 1
    }

    // MARK: - Hardware announcements

    static func hardwareNews(_ s: inout GameState) {
        let ym = s.date.ym
        for a in HardwareCatalog.all {
            if a.announced <= ym && !s.announcedHardware.contains(a.id) {
                s.announcedHardware.insert(a.id)
                if a.available > ym {
                    news(&s, "\(a.vendor.rawValue) announces \(a.name)",
                         "\(a.fact) Expected availability: \(a.available.label). \(Fmt.memory(a.memoryGB)) \(a.memoryType), \(Fmt.trim(a.bandwidthTBs, 1)) TB/s, \(Fmt.tflops(a.best)) \(a.bestPrecisionLabel).",
                         .hardware, image: a.image)
                }
            }
            if a.available <= ym && !s.availableHardware.contains(a.id) {
                s.availableHardware.insert(a.id)
                let how = a.purchasable ? "Orders are open" : "Available to rent on \(a.cloudProvider)"
                news(&s, "\(a.name) is now available", "\(how). \(a.fact)", .hardware, image: a.image, important: a.cls == .datacenter || a.cls == .tpu, good: true)
            }
        }
    }

    // MARK: - Scripted history

    static func historicalEvents(_ s: inout GameState) {
        for e in EventCatalog.historical + EventCatalog.future where e.date <= s.date && !s.firedEvents.contains(e.id) && e.date >= max(s.startDate, GameCalendar.addDays(s.date, -60)) {
            s.firedEvents.insert(e.id)
            // History about a lab that has been bought, gone bust or left the market doesn't happen.
            if let lab = e.lab, let c = s.competitors.first(where: { $0.id == lab }), c.acquired || c.bankrupt || !c.exitNote.isEmpty { continue }
            var important = false
            for eff in e.effects {
                switch eff {
                case .hype(let v): s.market.hype = max(0.4, s.market.hype + v); important = true
                case .hardware(let v): s.market.hardwarePrice = max(0.5, s.market.hardwarePrice + v)
                case .consumerGPU(let v): s.market.consumerGPUPrice = max(0.5, s.market.consumerGPUPrice + v)
                case .rent(let v): s.market.rentPrice = max(0.5, s.market.rentPrice + v)
                case .leadTime(let v): s.market.leadTimeDays += v
                case .apiPrice(let v): s.market.apiPricePressure = max(0.4, s.market.apiPricePressure + v)
                case .exportControls: s.market.exportControls = true
                case .euAIAct: s.market.euAIAct = true; important = true
                case .copyrightHeat(let v): s.market.copyrightHeat += v
                case .buildDelay(let v): s.market.buildDelay += v
                case .chatMoment:
                    if s.chatMoment == nil { s.chatMoment = s.year }
                    important = true
                }
            }
            news(&s, e.title, e.body, e.category, image: e.image, important: important)
        }
    }

    // MARK: - Hardware logistics

    static func deliveries(_ s: inout GameState) {
        let arrived = s.orders.filter { $0.arrives <= s.date }
        guard !arrived.isEmpty else { return }
        s.orders.removeAll { $0.arrives <= s.date }
        // Remember what was ordered when: vendors allocate per quarter.
        let cutoff = GameCalendar.addDays(s.date, -120)
        s.orderLog.removeAll { $0.ordered < cutoff }
        s.orderLog += arrived.map { OrderStamp(accelID: $0.accelID, count: $0.count, ordered: $0.ordered) }
        for o in arrived {
            s.owned.append(OwnedBatch(accelID: o.accelID, count: o.count, siteID: o.siteID, purchased: s.date, unitCost: o.unitCost))
            let name = HardwareCatalog.get(o.accelID)?.name ?? o.accelID
            let site = s.sites.first { $0.id == o.siteID }?.name ?? "your site"
            news(&s, "Delivered: \(Fmt.int(o.count))× \(name)", "Racked, cabled and burned in at \(site). They're ready for work.",
                 .company, image: HardwareCatalog.get(o.accelID)?.image, good: true)
        }
        mergeOwned(&s)
    }

    static func mergeOwned(_ s: inout GameState) {
        var merged: [String: OwnedBatch] = [:]
        for b in s.owned where b.count > 0 {
            let key = "\(b.accelID)|\(b.siteID)"
            if var m = merged[key] {
                let total = m.count + b.count
                m.unitCost = (m.unitCost * Double(m.count) + b.unitCost * Double(b.count)) / Double(total)
                m.count = total
                merged[key] = m
            } else {
                merged[key] = b
            }
        }
        // 3.7: ties (same day) by merge key, so the order never depends on the Dictionary's.
        s.owned = merged.sorted { a, b in a.value.purchased != b.value.purchased ? a.value.purchased < b.value.purchased : a.key < b.key }.map(\.value)
    }

    static func rentalExpiry(_ s: inout GameState) {
        let expired = s.rentals.filter { ($0.end ?? .distantFuture) <= s.date }
        guard !expired.isEmpty else { return }
        s.rentals.removeAll { ($0.end ?? .distantFuture) <= s.date }
        for r in expired {
            news(&s, "Reserved capacity ended: \(Fmt.int(r.count))× \(HardwareCatalog.get(r.accelID)?.name ?? "")",
                 "Your \(r.term.rawValue.lowercased()) contract finished. Rent again if you still need the capacity.", .company)
        }
    }

    static func siteConstruction(_ s: inout GameState) {
        for i in s.sites.indices {
            if s.sites[i].ready > GameCalendar.addDays(s.date, -1) && s.sites[i].ready <= s.date {
                news(&s, "\(s.sites[i].name) is online", "\(Fmt.watts(s.sites[i].capacityKW * 1000)) of IT capacity is energised and ready for hardware.",
                     .company, image: s.sites[i].kind.image, important: true, good: true)
            }
            if let ready = s.sites[i].expansionReady, ready <= s.date {
                s.sites[i].capacityKW += s.sites[i].expanding
                let more = s.sites[i].plannedKW > 0 ? " \(Fmt.watts(s.sites[i].plannedKW * 1000)) more to come." : ""
                news(&s, "\(s.sites[i].name): +\(Fmt.watts(s.sites[i].expanding * 1000)) online",
                     "The campus now runs \(Fmt.watts(s.sites[i].capacityKW * 1000)) of IT capacity.\(more)",
                     .company, image: "dc_construction", good: true)
                s.sites[i].expanding = 0
                s.sites[i].expansionReady = nil
            }
        }
        Campus.daily(&s)
    }

    /// If allocations exceed what we have (rental ended, chips died), recall leases, shrink research and swarms,
    /// then inference, then pause self-improvement and training.
    static func rebalance(_ s: inout GameState, _ pools: [ComputePool]) {
        for pool in pools where pool.allocated > pool.total || pool.leased > pool.owned {
            var excess = pool.allocated - pool.total
            let id = pool.accel.id
            if let l = s.leases[id], l > 0 {
                // Leases come out of owned chips only.
                let cut = min(l, max(excess, l - pool.owned))
                s.leases[id] = l - cut
                if s.leases[id] == 0 { s.leases[id] = nil }
                excess -= cut
            }
            guard excess > 0 else { continue }
            if let r = s.researchChips[id], r > 0 {
                let cut = min(r, excess)
                s.researchChips[id] = r - cut
                excess -= cut
            }
            for si in s.swarms.indices where s.swarms[si].accelID == id && !s.swarms[si].paused && excess > 0 {
                let cut = min(s.swarms[si].chips, excess)
                s.swarms[si].chips -= cut
                excess -= cut
                if s.swarms[si].chips <= 0 {
                    s.swarms[si].chips = 0
                    s.swarms[si].paused = true
                }
                Swarms.log(&s, si, "Lost \(Fmt.int(cut)) \(pool.accel.name) chips — fewer agents can run.")
            }
            if excess > 0 {
                for mi in s.models.indices {
                    for di in s.models[mi].deployments.indices where s.models[mi].deployments[di].accelID == id && excess > 0 {
                        let cut = min(s.models[mi].deployments[di].chips, excess)
                        s.models[mi].deployments[di].chips -= cut
                        excess -= cut
                    }
                    s.models[mi].deployments.removeAll { $0.chips <= 0 }
                }
            }
            if excess > 0 {
                for ri in s.rsiRuns.indices where s.rsiRuns[ri].accelID == id && s.rsiRuns[ri].status == .running && excess > 0 {
                    s.rsiRuns[ri].status = .paused
                    excess -= s.rsiRuns[ri].chips
                    RSI.log(&s, ri, "Paused: not enough \(pool.accel.name) chips.")
                }
            }
            if excess > 0 && pool.accel.vendor == .custom {
                // 3.5: your own chips can't be rented as spares, so a run on them carries on with the chips that are left.
                AlienFab.shrinkRuns(&s, accel: pool.accel, excess: &excess)
            }
            if excess > 0 {
                for ri in s.runs.indices where s.runs[ri].design.accelID == id && (s.runs[ri].status == .running || s.runs[ri].status == .postTraining) && excess > 0 {
                    s.runs[ri].status = .paused
                    s.runs[ri].note = "Paused: not enough \(pool.accel.name) chips."
                    excess -= s.runs[ri].design.chips
                    news(&s, "Training paused: \(s.runs[ri].design.name)", "You no longer have enough \(pool.accel.name) chips for this run.", .company, important: true, good: false)
                    Alerts.raise(&s, .runPaused, key: s.runs[ri].id.uuidString, title: "\(s.runs[ri].design.name) stalled",
                                 body: "Not enough \(pool.accel.name) chips: something else took them, or a rental ended. Free chips up or shrink the run, then resume.",
                                 screen: .training, critical: true, cooldown: 7)
                }
            }
            if excess > 0 && !s.families.jobs.isEmpty { Families.shrink(&s, accelID: id, excess: &excess) }   // 3.5: model families
        }
    }

    // MARK: - Training

    static func checkpointOverhead(_ interval: Double) -> Double {
        switch interval {
        case ..<0.03: 0.985
        case ..<0.06: 0.993
        case ..<0.15: 0.997
        default: 1.0
        }
    }

    static func runLog(_ s: inout GameState, _ i: Int, _ text: String) {
        Training.runLog(&s, i, text)
    }

    // MARK: - Research

    static func researchRate(_ s: GameState, _ b: ResearchBonuses) -> Double {
        let people = s.employees.filter { $0.role == .researcher && !s.advanced.seconded.contains($0.id) }.reduce(0.0) { $0 + pow($1.skill / 50, 1.3) * $1.traitMultiplier * (0.6 + $1.morale / 250) }
        let t = s.traits
        let founder = 0.8 * (1 + t.founderRP)
        var computePF = 0.0
        for (id, n) in s.researchChips.sorted(by: { $0.key < $1.key }) where n > 0 {   // 3.7: fixed order (float sums)
            if let a = HardwareCatalog.get(id) { computePF += Double(n) * a.bf16 / 1000 }
        }
        let computeRP = 4 * pow(computePF, 0.45)
        // Compute is a multiplier on people, plus a little on its own.
        let community = s.publication == .open ? 1.1 : 1.0
        return ((founder + people) * (1 + min(3, computeRP / 10)) * (1 + b.rp) + computeRP * 0.2) * community * max(0.5, 1 + t.rp)
            * (1 - s.security.friction)
    }

    static func researchCost(_ item: ResearchItem, year: Double) -> Double {
        // A lab's own secret breakthroughs never get cheaper, and ideas ahead of their time cost more.
        if item.isExotic { return item.cost * (1 + 0.15 * min(10, max(0, item.year - year))) }
        guard year >= item.year else { return item.cost * (1 + 0.3 * (item.year - year)) }
        // Published techniques get cheaper as code, tutorials and open checkpoints pile up.
        let age = year - item.year
        let discount: Double = age >= 3 ? 0.15 : (age >= 1 ? 0.3 : 0.5)
        return item.cost * discount
    }

    // MARK: - Market & revenue

    static func dailyMarket(_ s: inout GameState, _ b: ResearchBonuses) {
        let y = s.year
        let snap = Market.snapshot(s)

        // Update competitor share display
        for i in s.competitors.indices {
            let id = s.competitors[i].id
            s.competitors[i].apiShare = snap.api.filter { $0.lab == id }.reduce(0) { $0 + $1.share }
            s.competitors[i].consumerShare = snap.consumer.filter { $0.lab == id }.reduce(0) { $0 + $1.share }
            s.competitors[i].agentShare = snap.agents.filter { $0.lab == id }.reduce(0) { $0 + $1.share }
        }

        // Demand per player model
        var demand: [UUID: Double] = [:]
        var apiDemand: [UUID: Double] = [:]
        for p in snap.api where p.isPlayer {
            guard let id = p.modelID else { continue }
            let tokens = p.share * snap.apiTokenPool
            apiDemand[id, default: 0] += tokens
            demand[id, default: 0] += tokens
        }

        // Consumer
        var chatTokens = 0.0
        var freeRoute: (id: UUID, share: Double)? = nil
        var freeServed = 1.0
        // What rival apps earn per weekly user a month (RivalEconomy's assumption).
        let rivalChatARPU = Market.paidConversion(price: 20, freeTier: true) * 20
        if let chat = snap.consumer.first(where: { $0.isPlayer }) {
            let target = chat.share * snap.consumerUsersPool
            let speed = s.year < 2022.91 ? 0.08 : 0.04
            var users = s.consumerUsers + (target - s.consumerUsers) * speed
            // Paying users follow the price against what the app is worth to them (chatWTP).
            let wtp = Market.chatWTP(s)
            if !s.freeTier { users = min(users, target * 0.06 * Market.wtpDemand(s.chatPrice / wtp)) }
            s.consumerUsers = max(0, users)
            s.consumerShare = chat.share
            let conv = Market.paidConversion(price: s.chatPrice, freeTier: s.freeTier, wtp: wtp)
            // Consumers' subscription budget is fixed (the consumer pool): if every app's subscribers together would
            // outspend it, fewer of yours pay — you get your share of the pool, never more than all of it.
            let others = (1 - chat.share) * snap.consumerUsersPool * rivalChatARPU / 30.4
            s.paidUsers = s.consumerUsers * conv
                * Market.budgetFactor(s.consumerUsers * conv * s.chatPrice / 30.4, pool: snap.consumerRevenuePool, others: others)
            let reasoningMult = chat.reasoning ? 2.2 : 1
            chatTokens = s.consumerUsers * Macro.tokensPerUserDay(y) * reasoningMult
            if let id = chat.modelID, let free = Families.freeRoute(s, chatID: id) {
                // 3.5: model families — free users are served by a cheaper tier, paying users by the chat model.
                freeRoute = (free.id, Families.freeShare(s))
                let base = s.consumerUsers * Macro.tokensPerUserDay(y)
                let paid = base * (1 - freeRoute!.share) * reasoningMult
                let freeTokens = base * freeRoute!.share * (free.reasoning ? 2.2 : 1)
                chatTokens = paid + freeTokens
                demand[id, default: 0] += paid
                demand[free.id, default: 0] += freeTokens
            } else if let id = chat.modelID { demand[id, default: 0] += chatTokens }
            // Player can trigger the consumer boom early
            if s.chatMoment == nil, let m = s.models.first(where: { $0.id == chat.modelID }), m.c >= 4.1, m.design.instruct, m.design.rlhf {
                s.chatMoment = y
                s.firedEvents.insert("chatgpt")
                s.market.hype += 0.5
                s.brand = min(100, s.brand + 35)
                s.achievements.insert("chat_moment")
                news(&s, "\(s.companyName) Chat goes viral — 1M users in a week",
                     "Your assistant becomes the fastest-growing app ever. The consumer AI boom has started early, and you're leading it.",
                     .company, image: "sf_skyline", important: true, good: true)
            }
        } else {
            s.consumerUsers *= 0.97
            let conv = Market.paidConversion(price: s.chatPrice, freeTier: s.freeTier, wtp: Market.chatWTP(s))
            s.paidUsers = s.consumerUsers * conv * Market.budgetFactor(s.consumerUsers * conv * s.chatPrice / 30.4, pool: snap.consumerRevenuePool,
                                                                      others: snap.consumerUsersPool * rivalChatARPU / 30.4)
            s.consumerShare = 0
        }

        // Coding & computer-use agents (seat subscriptions)
        var agentModelID: UUID? = nil
        var billedSeats = 0.0
        if let ag = snap.agents.first(where: { $0.isPlayer }) {
            // Seat budgets are fixed too (the agent pool): at a price that would outspend it you sell fewer seats.
            let othersSpend = (snap.agents.filter { !$0.isPlayer }.reduce(0) { $0 + $1.share * $1.price }
                               + max(0, 1 - snap.agents.reduce(0) { $0 + $1.share }) * snap.agentSeatBudget) * snap.agentSeatsPool / 30.4
            let natural = ag.share * snap.agentSeatsPool * max(1, s.agentPrice) / 30.4
            let target = ag.share * snap.agentSeatsPool * Market.budgetFactor(natural, pool: snap.agentRevenuePool, others: othersSpend)
            s.agentSeats = max(0, s.agentSeats + (target - s.agentSeats) * 0.05)
            // Seats take weeks to sign up or wind down, but only as many as your share supports at today's price pay it.
            billedSeats = min(s.agentSeats, target)
            s.agentShare = ag.share
            agentModelID = ag.modelID
            if let id = ag.modelID { demand[id, default: 0] += s.agentSeats * Macro.tokensPerSeatDay(y) }
            if s.agentSeats >= 1_000_000 { Achievements.unlock(&s, "agents") }
        } else {
            s.agentSeats *= 0.95
            s.agentShare = 0
            billedSeats = s.agentSeats
        }

        // Contracts with no model behind them (theirs was retired): move them to one that meets their bar,
        // or they miss their SLA every day until the client walks.
        for di in s.deals.indices where s.deals[di].active && s.deals[di].modelID == nil && s.deals[di].tokensPerDay > 0 {
            if let m = Business.qualifyingModel(s.deals[di], s) { s.deals[di].modelID = m.id } else { s.deals[di].breaches += 1 }
        }

        // Enterprise token commitments
        var entTokens: [UUID: Double] = [:]
        for d in s.deals where d.active {
            if let mid = d.modelID {
                entTokens[mid, default: 0] += d.tokensPerDay
                demand[mid, default: 0] += d.tokensPerDay
            }
        }

        // Serve
        var servedTotal = 0.0, demandTotal = 0.0
        var revAPI = 0.0
        var chatServed = 1.0
        var agentServed = 1.0
        for i in s.models.indices {
            let id = s.models[i].id
            let cap = s.models[i].deployments.reduce(0) { $0 + Physics.capacity(s.models[i], deployment: $1, bonuses: b) }
            let dem = demand[id] ?? 0
            let served = min(cap, dem)
            // Contract traffic is served first (provisioned throughput): a shortage hits API, chat and agent users
            // before it breaks an SLA.
            let ent = entTokens[id] ?? 0
            let entFrac = ent > 0 ? min(1, cap / ent) : 1
            let frac = dem > ent ? min(1, max(0, cap - ent) / (dem - ent)) : 1
            let load = cap > 0 ? dem / cap : 0
            s.models[i].capacityTokensDay = cap
            s.models[i].demandTokensDay = dem
            s.models[i].servedTokensDay = served
            s.models[i].tps = Physics.modelTPS(s.models[i], bonuses: b, load: min(load, 2))
            let api = (apiDemand[id] ?? 0) * frac
            let r = api / 1e6 * s.models[i].apiPrice
            s.models[i].revenueDay = r
            revAPI += r
            if id == s.chatModelID { chatServed = frac }
            if id == freeRoute?.id { freeServed = frac }
            if id == agentModelID { agentServed = frac }
            if ent > 0 && entFrac < 0.95 {
                for di in s.deals.indices where s.deals[di].active && s.deals[di].modelID == id {
                    s.deals[di].breaches += 1
                }
            }
            servedTotal += served
            demandTotal += dem
        }
        if let r = freeRoute { chatServed = chatServed * (1 - r.share) + freeServed * r.share }
        s.consumerServedFraction = chatServed
        let overall = demandTotal > 0 ? servedTotal / demandTotal : 1
        s.reliability = clamp(s.reliability * 0.93 + overall * 0.07, 0.05, 1)

        let revConsumer = s.paidUsers * s.chatPrice / 30.4 * (0.5 + 0.5 * chatServed)
        // Enterprise budgets are fixed too: rivals win the enterprise pool in proportion to their API business
        // (RivalEconomy); if your contracts plus theirs would outspend it, yours are squeezed to your share.
        let contracts = s.deals.filter(\.active).reduce(0.0) { $0 + $1.monthly } / 30.4
        var billedAPI = 0.0, rivalsBilled = 0.0
        for p in snap.api {
            billedAPI += p.share * p.price
            if !p.isPlayer { rivalsBilled += p.share * p.price * (p.open ? 0.5 : 1) }
        }
        let rivalsEnterprise = billedAPI > 0 ? snap.enterprisePool / 365 * rivalsBilled / billedAPI : 0
        let revEnterprise = contracts * Market.budgetFactor(contracts, pool: snap.enterprisePool / 365, others: rivalsEnterprise)
        let revAgents = billedSeats * max(1, s.agentPrice) / 30.4 * (0.4 + 0.6 * agentServed)
        let total = revAPI + revConsumer + revEnterprise + revAgents
        s.month.revAgents += revAgents
        s.month.revAPI += revAPI
        s.month.revConsumer += revConsumer
        s.month.revEnterprise += revEnterprise
        s.month.apiTokensDay = s.models.reduce(0) { $0 + $1.servedTokensDay }
        s.month.users = s.consumerUsers
        s.month.paidUsers = s.paidUsers
        s.cash += total
        s.lifetimeRevenue += total
    }

    // MARK: - Costs

    static func dailyCosts(_ s: inout GameState, _ pools: [ComputePool]) {
        // Cloud rentals (cloud credits first)
        var rent = 0.0
        for r in s.rentals {
            let cost = r.hourly * 24 * Double(r.count)
            rent += cost
            if let v = HardwareCatalog.get(r.accelID)?.vendor.rawValue, let di = s.supplyDeals.firstIndex(where: { $0.vendor == v }) {
                s.supplyDeals[di].spentThisYear += cost
            }
            if let a = HardwareCatalog.get(r.accelID) { Partners.recordSpend(&s, accel: a, amount: cost, purchase: false) }
        }
        let credit = min(s.cloudCredits, rent)
        s.cloudCredits -= credit
        let rentCash = rent - credit
        // Power for owned hardware
        var utilByAccel: [String: Double] = [:]
        for p in pools where p.total > 0 { utilByAccel[p.accel.id] = Double(p.allocated) / Double(p.total) }
        var power = 0.0
        let grid = Power.gridMultiplier(s)   // 3.5: strained grids cost datacenters more
        for bt in s.owned {
            guard let a = HardwareCatalog.get(bt.accelID), let site = s.sites.first(where: { $0.id == bt.siteID }), site.isReady(s.date) else { continue }
            let util = utilByAccel[a.id] ?? 0
            let draw = Economy.chipKW(a) * Double(bt.count) * (0.3 + 0.65 * util)
            power += draw * site.pue * 24 * site.powerPrice * (site.kind == .colo || site.kind == .datacenter ? grid : 1)
                * Nations.powerFactor(s, location: site.locationID)   // 3.7: energy policy where the site is
        }
        power *= max(0.5, 1 - s.traits.power) * XenoScience.powerFactor(s) * AgentOrgs.powerFactor(s) * Science.powerFactor(s)   // 3.6: infrastructure teams; energy discoveries
        let sites = s.sites.reduce(0) { $0 + $1.monthlyFee } / 30.4
        let office = Economy.office(s, s.officeLevel).monthly / 30.4   // 3.5: local rent
        let payroll = Economy.payrollYear(s) / 365
        let data = Economy.dataMonthlyCost(s) / 30.4
        let marketing = s.marketingBudget / 30.4
        let maintenance = s.sites.filter { $0.kind == .datacenter }.reduce(0) { $0 + $1.capex * 0.015 } / 365
        s.month.costRent += rentCash
        s.month.costPower += power
        s.month.costSites += sites + office + maintenance
        s.month.costPayroll += payroll
        s.month.costData += data
        s.month.costMarketing += marketing
        s.cash -= rentCash + power + sites + office + payroll + data + marketing + maintenance
    }

    // MARK: - Solvency

    static func checkSolvency(_ s: inout GameState) {
        if s.cash < 0 {
            s.daysNegativeCash += 1
            if s.daysNegativeCash == 1 {
                news(&s, "⚠️ You are out of cash", "Payroll and bills are bouncing. Raise money, take a loan, sell hardware or cut costs within 60 days or the company goes bankrupt.",
                     .finance, image: "stock_exchange", important: true, good: false)
            }
            if s.daysNegativeCash == 30 {
                news(&s, "⚠️ 30 days left before bankruptcy", "Creditors are circling. Fix your cash position now.", .finance, important: true, good: false)
            }
            if s.daysNegativeCash >= 60 {
                s.gameOver = "Bankrupt on \(s.date.gameShort). Creditors seized the hardware and the team scattered to rival labs."
                news(&s, "\(s.companyName) files for bankruptcy", s.gameOver!, .finance, important: true, good: false)
            }
        } else {
            s.daysNegativeCash = 0
        }
    }
}
