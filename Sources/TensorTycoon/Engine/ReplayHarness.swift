import Foundation

/// `--replay-save <file> [days] [tech…]`: load a real save, optionally queue techniques the way the Research
/// button does, and play it forward day by day, printing usable and waiting compute and how the research queue
/// moves. For chasing "I bought it but can't use it" and "the queue doesn't move" reports on a player's own game.
enum ReplayHarness {
    static func main(_ args: [String]) -> Int32 {
        guard let path = args.first else {
            print("usage: --replay-save <save.json> [days] [tech…]")
            return 1
        }
        let days = args.count > 1 ? Int(args[1]) ?? 7 : 7
        let techs = Array(args.dropFirst(2))
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), var s = try? dec.decode(GameState.self, from: data) else {
            print("FAILED to load \(path)")
            return 1
        }
        StableID.resume(s)
        SaveMigration.migrate(&s)
        BenchmarkCatalog.resetCache()
        HardwareCatalog.register(s.customChips)
        var answer = true
        var gov = 0   // 3.9: gov prints the government marketplace, gov:auto also plays it (GovMarketHarness)
        var pending: [String] = []   // train:<n>[@<day>]
        for t in techs {
            // cash:<amount> sets cash; noanswer leaves decisions to the inbox defaults; defer:<n> defers every leased tranche n times.
            if t.hasPrefix("cash:") { s.cash = Double(t.dropFirst(5)) ?? s.cash; print("cash set to \(Fmt.money(s.cash))"); continue }
            if t == "noanswer" { answer = false; continue }
            if t == "gov" || t == "gov:auto" { gov = t == "gov" ? 1 : 2; continue }
            if GovHarness.parse(t, &s) { continue }   // 3.9: government relations
            if DramaHarness.arg(t, &s) { continue }   // 3.9: drama, drama:all, drama:list, drama:fire:<id>
            if t.hasPrefix("hype:") { HypeHarness.arg(&s, t); continue }   // 3.9: hype, launch events
            if t == "probe:training" { TrainingProbe.run(s); continue }   // 3.9: Model Lab and training checks
            if t == "nowaiver" { for i in s.corp.debts.indices { s.corp.debts[i].waiverUntil = nil }; continue }
            if t.hasPrefix("defer:") {
                for id in s.sites.map(\.id) { for _ in 0..<(Int(t.dropFirst(6)) ?? 1) { _ = s.deferTranche(id) } }
                continue
            }
            if t.hasPrefix("focus:"), let f = ResearchFocus(rawValue: String(t.dropFirst(6))) {
                print("queue before: \(s.researchQueue)"); s.setResearchFocus(f); print("focus \(f.rawValue) → queue: \(s.researchQueue)")
                continue
            }
            if t.hasPrefix("order:") {
                let parts = t.split(separator: ":").map(String.init)
                let why = parts.count == 3 ? s.orderOwnChips(parts[1], count: Int(parts[2]) ?? 0) : "use order:<chip>:<count>"
                print(why.map { "could not order: \($0)" } ?? "ordered \(parts[2])× \(parts[1])")
                continue
            }
            // move-waiting: truck chips stuck at unopened sites to open ones. redirect:<chip>:<site name>: point that chip's orders elsewhere.
            if t == "move-waiting" { let r = s.relocateWaitingChips(); print("moved \(Fmt.int(r.moved)) waiting chips for \(Fmt.money(r.cost))\(r.why.map { " (\($0))" } ?? "")"); continue }
            if t.hasPrefix("redirect:") {
                let parts = t.split(separator: ":").map(String.init)
                if parts.count == 3, let site = s.sites.first(where: { $0.name == parts[2] }) {
                    for o in s.orders where o.accelID == parts[1] { print("redirect \(o.count)×: \(s.redirectOrder(o.id, to: site.id) ?? "ok")") }
                }
                continue
            }
            // 3.9 hardware checks: hw:sites, hw:power, hw:rent:<chip>:<n>, hw:max:<chip>, hw:expand:<site>:<MW>, hw:deal:<site>:<deal>,
            // hw:lease:<MW> (the lease quote), hw:lease:<chip>:<n> (set by hand), hw:leases, hw:break (break the first reserved rental).
            if t.hasPrefix("hw:") {
                let p = t.split(separator: ":").map(String.init)
                let site = { (n: String) in s.sites.first { $0.name == n } }
                switch p.count > 1 ? p[1] : "" {
                case "sites": for x in s.sites { print("site \(x.name) [\(x.kind)] \(x.powerDeal.rawValue) \(Fmt.watts(x.capacityKW * 1000)) planned \(Fmt.watts(Campus.plannedTotalKW(x) * 1000)) expanding \(Fmt.watts(x.expanding * 1000)) ready \(x.ready.gameShort) lease end \(x.leaseEnd?.gameShort ?? "-")") }
                case "power": let q = Power.summary(s); print("power: chips \(Fmt.watts(q.chipKW * 1000)) reserved \(Fmt.watts(q.reservedKW * 1000)) sublet \(Fmt.watts(q.subleasedKW * 1000)) free \(Fmt.watts(q.freeKW * 1000)) online \(Fmt.watts(q.onlineKW * 1000)) facility \(Fmt.watts(q.facilityMW * 1e6))")
                case "rent" where p.count == 4:
                    if let a = HardwareCatalog.get(p[2]) { print("rent \(p[3])× \(a.name): limit \(Economy.rentalLimit(a, s)) rented \(Economy.rentedCount(a, s)) room \(Economy.rentalRoom(a, s)) -> \(s.rentHardware(a.id, count: Int(p[3]) ?? 0, term: .reserved1y) ?? "ok")") }
                case "max" where p.count == 3:
                    if let a = HardwareCatalog.get(p[2]) { for x in s.sites where x.kind != .garage { print("max \(a.name) at \(x.name): \(Campus.maxOrder(a, site: x, s))") }; print("default site: \(Campus.defaultSite(for: a, count: 8, s)?.name ?? "none")") }
                case "expand" where p.count == 4: if let x = site(p[2]) { print("expand \(x.name) +\(p[3]) MW -> \(s.expandSite(x.id, addKW: (Double(p[3]) ?? 0) * 1000) ?? "ok")") }
                case "deal" where p.count == 4: if let x = site(p[2]), let d = PowerDeal(rawValue: p[3]) { print("deal \(x.name) -> \(d.rawValue): \(s.setPowerDeal(x.id, d) ?? "ok")") }
                case "lease" where p.count == 3: for q in DCMarket.quotes(s, mw: Double(p[2]) ?? 100, template: .training) where q.kind == .lease { print("lease quote \(Fmt.watts(q.mw * 1e6)) up front \(Fmt.money(q.upfront)) · \(q.note)") }
                case "lease" where p.count == 4: print("lease \(p[2]) by hand to \(p[3]): \(s.setLeaseByHand(p[2], chips: Int(p[3]) ?? 0) ?? "ok"), leased now \(s.leases[p[2]] ?? 0)")
                case "leases": print("leases: \(s.leases.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")
                case "break": if let r = s.rentals.first(where: { $0.end != nil }) { print("break \(r.count)× \(r.accelID): penalty \(Fmt.money(Economy.breakPenalty(r, s))) -> \(s.cancelRental(r.id) ?? "ok")") } else { print("no reserved rental") }
                default: print("unknown \(t)")
                }
                continue
            }
            // train:<n> lists "Plan my next model" proposals and starts the n-th (0 = strongest).
            if t.hasPrefix("train:") { pending.append(String(t.dropFirst(6))); continue }
            // fix:<advisor id prefix> applies that Chief of Staff item's one-click fix (3.9).
            if t.hasPrefix("fix:") {
                let id = String(t.dropFirst(4))
                if let item = Advisor.items(s, pools: Economy.pools(s)).first(where: { $0.id.hasPrefix(id) }), let fix = item.fix {
                    print("fix \(item.id): \(item.fixLabel) -> \(Advisor.apply(&s, fix) ?? "ok")")
                } else { print("no fixable advisor item \(id)") }
                continue
            }
            if t.hasPrefix("arena:") { Arena.harnessArg(&s, t); continue }   // 3.9: arena:test:<model>, arena:preview:<model>, arena:release:<model>@<day>
            if t == "auto:price" { s.autoSubPrice = true; continue }
            if t == "evenshortage" { s.evenShortage = true; continue }
            // 3.9: relax prints the security confirmation text and drops a level; safety:<n> bumps the score as a decision would.
            if t == "relax" { print("relax warning: \(SecurityOps.relaxWarning(s))"); print("relax: \(s.downgradeSecurity() ?? "ok") -> \(s.security.title)"); continue }
            if t.hasPrefix("safety:") { s.safetyScore = clamp(s.safetyScore + (Double(t.dropFirst(7)) ?? 0), 0, 100); print("safety bumped to \(Fmt.trim(s.safetyScore, 1))"); continue }
            if t == "ops:autoscale" { s.ops.autoscale = true; continue }
            if t.hasPrefix("ops:") {
                // ops:all, ops:recommended, ops:<delegate> (autoscale, autoLaunch, autoRenew, leaseIdle, autoHire, autoRaises, autoLeads, autoTrain)
                let n = String(t.dropFirst(4))
                if n == "all" || n == "recommended" {
                    let keepBudget = (s.ops.rentBudget, s.ops.hireBudget)
                    s.ops = OpsPolicy.recommended
                    (s.ops.rentBudget, s.ops.hireBudget) = keepBudget
                    if n == "all" { s.ops.autoHire = true }
                } else {
                    switch n {
                    case "autoscale": s.ops.autoscale = true
                    case "autoLaunch": s.ops.autoLaunch = true
                    case "autoRenew": s.ops.autoRenew = true
                    case "leaseIdle": s.ops.leaseIdle = true
                    case "autoHire": s.ops.autoHire = true
                    case "autoRaises": s.ops.autoRaises = true
                    case "autoLeads": s.ops.autoLeads = true
                    case "autoTrain": s.ops.autoTrain = true
                    default: print("unknown delegate \(n)")
                    }
                }
                continue
            }
            // 3.9 serving: precision:<model>:<bf16|fp8|fp4>, deploy:<model>:<chip>:<chips>, rent:<chip>:<count>,
            // price:<model>:<$/1M> — each prints the engine's answer and the model's serving numbers after it.
            if t.hasPrefix("precision:") || t.hasPrefix("deploy:") || t.hasPrefix("rent:") || t.hasPrefix("price:") {
                let p = t.split(separator: ":").map(String.init)
                func serving(_ name: String) {
                    guard let m = s.models.first(where: { $0.name == name }) else { return }
                    let cap = m.deployments.reduce(0.0) { $0 + Physics.capacity(m, deployment: $1, bonuses: s.bonuses) }
                    print("    \(m.name) at \(m.servingPrecision.short): \(m.deployments.map { "\($0.chips) \($0.accelID)" }.joined(separator: " + ")) · capacity \(Fmt.count(cap))/day · serving cost \(Fmt.price(Economy.servingCostPerM(m, s)))/1M · floor \(Fmt.price(Treasury.minPrice(m, s))) · price \(Fmt.price(m.apiPrice))\(m.autoPrice ? " auto" : "")")
                }
                let id = p.count > 1 ? s.models.first(where: { $0.name == p[1] })?.id : nil
                switch p[0] {
                case "precision" where p.count == 3 && id != nil:
                    print("precision \(p[2]): \(Precision(rawValue: p[2]).map { s.setServingPrecision(id!, $0) ?? "ok" } ?? "unknown precision")"); serving(p[1])
                case "deploy" where p.count == 4 && id != nil:
                    print("deploy \(p[3]) \(p[2]): \(s.deploy(id!, accelID: p[2], chips: Int(p[3]) ?? 0) ?? "ok")"); serving(p[1])
                case "rent" where p.count == 3:
                    print("rent \(p[2]) \(p[1]): \(s.rentHardware(p[1], count: Int(p[2]) ?? 0, term: .onDemand) ?? "ok")")
                    for m in s.models where m.released && !m.retired { serving(m.name) }
                case "price" where p.count == 3 && id != nil:
                    print("price \(p[2]): \(s.setAPIPrice(id!, Double(p[2]) ?? 0) ?? "ok")"); serving(p[1])
                default: print("could not parse \(t)")
                }
                continue
            }
            // 3.9: swarms lists every swarm and team and whether it can resume; retune:<name>:<chip id>:<chips> moves one to
            // other hardware; alienorder prints what limits an alien-chip order.
            if t == "swarms" {
                for sw in s.swarms {
                    var probe = s
                    let resume = sw.paused ? (probe.setSwarmPaused(sw.id, false) ?? "ok") : "running"
                    print("swarm \(sw.name): \(Fmt.int(sw.agents)) agents · \(Fmt.int(sw.chips))× \(sw.accelID) (\(Fmt.int(Economy.freeChips(s, sw.accelID))) free) · resume: \(resume)")
                }
                continue
            }
            if t.hasPrefix("retune:") {
                let parts = t.split(separator: ":").map(String.init)
                if parts.count == 4, let sw = s.swarms.first(where: { $0.name == parts[1] }) {
                    let why = s.tuneOrgTeam(sw.id, agents: sw.agents, chips: Int(parts[3]) ?? 0, accelID: parts[2])
                    let now = s.swarms.first { $0.id == sw.id }
                    print("retune \(sw.name): \(why ?? "ok") → \(now.map { "\(Fmt.int($0.chips))× \($0.accelID), \($0.paused ? "paused" : "running")" } ?? "?")")
                } else { print("use retune:<swarm name>:<chip id>:<chips>") }
                continue
            }
            if t == "alienorder" {
                for c in s.customChips where c.alien {
                    let a = AlienFab.orderAdvice(c.id, s)
                    print("alien order \(c.name): suggest \(Fmt.int(a.count)) · \(a.reason ?? "no blocker") · cage \(a.needsCage) · queue full \(a.queueFull) · cage fee \(Fmt.money(AlienFab.cageFee(c.id, chips: 4_000, s)))/mo")
                }
                continue
            }
            if t.hasPrefix("unretire:") {
                let name = String(t.dropFirst("unretire:".count))
                if let m = s.models.first(where: { $0.name == name }) { s.unretire(m.id); print("unretired \(name)") } else { print("no model named \(name)") }
                continue
            }
            // remove:<entry> takes an entry off the queue the way its ✕ does (3.9).
            if t.hasPrefix("remove:") { let e = String(t.dropFirst(7)); print("remove \(e): \(s.removeResearch(e) ?? "ok")"); continue }
            let why = t.hasPrefix(Breakthroughs.refinePrefix) ? s.queueRefine(String(t.dropFirst(Breakthroughs.refinePrefix.count))) : s.queueResearch(t)
            print(s.researchQueue.firstIndex(of: t).map { "queued \(t) at #\($0 + 1)" } ?? "could not queue \(t)\(why.map { ": \($0)" } ?? "")")
        }
        startDate = s.date
        report(s)
        func planAndStart(_ spec: String) {
            let props = RunPlanner.proposals(s)
            if props.isEmpty { print("no proposal: \(RunPlanner.shortfall(s) ?? "nothing to plan")") }
            for (i, p) in props.enumerated() {
                print("proposal \(i) \(p.label): \(p.design.name) · \(p.blurb) · forecast c \(Fmt.trim(p.est.forecast.c, 2)) (vs best live \(p.vsBest.map { Fmt.trim($0, 2) } ?? "none"), vs rivals \(Fmt.trim(p.vsRival, 2))) · \(Fmt.params(p.design.paramsB)) on \(Fmt.tokens(p.design.tokensT)) · goodput \(Fmt.pct(p.est.goodput, decimals: 0)) · left out \(p.leftOut) · free for serving: \(p.othersIdle)")
            }
            if let n = Int(spec.split(separator: "@").first ?? ""), props.indices.contains(n) {
                print(RunPlanner.start(props[n], &s).map { "could not start: \($0)" } ?? "started \(props[n].design.name)")
            }
        }
        for spec in pending where !spec.contains("@") { planAndStart(spec) }
        var dayNo = 0
        for day in 0..<days where s.gameOver == nil {
            dayNo += 1
            for spec in pending where spec.hasSuffix("@\(day)") { planAndStart(spec) }
            HypeHarness.tick(&s, day: day)   // 3.9: hype:…@<day>
            Arena.harnessDay(&s, day)   // 3.9: scheduled arena steps
            for _ in 0..<10 where answer {
                guard let d = s.decisions.first else { break }
                GovHarness.decision(d, s)   // 3.9
                s.resolveDecision(d.id, option: GovHarness.option(d))
            }
            if ProcessInfo.processInfo.environment["REPLAY_CONTRACT"] == "play" { FoundingContracts.assist(&s) }   // 3.9
            Sim.advanceDay(&s)
            if gov > 0 { GovMarketHarness.tick(&s, auto: gov > 1); continue }
            report(s)
            GovHarness.daily(s, dayNo: dayNo)   // 3.9
            if dayNo % 30 == 0 { moneyLine(s); forecastLines(s) }
        }
        GovHarness.summary(s)   // 3.9
        if let g = s.gameOver { print("GAME OVER: \(g)") }
        if ProcessInfo.processInfo.environment["REPLAY_HYPE"] != nil { HypeHarness.summary(s) }   // 3.9
        if !s.opsLog.isEmpty { print("delegate log (newest first):"); for l in s.opsLog.prefix(25) { print("  \(l)") } }
        if !s.ops.tally.isEmpty { print("delegate tally: \(s.ops.tally.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value) (\(Fmt.money(s.ops.moved[$0.key] ?? 0)))" }.joined(separator: ", "))") }
        return 0
    }

    nonisolated(unsafe) private static var announced = Set<String>()
    nonisolated(unsafe) private static var startDate = Date.distantPast
    /// Month-to-date revenue by segment and costs, plus prices: where the money comes from and goes.
    private static func moneyLine(_ s: GameState) {
        let m = s.month
        func b(_ x: Double) -> String { Fmt.money(x) }
        print("    MONEY mtd: rev \(b(m.revenue)) [api \(b(m.revAPI)) chat \(b(m.revConsumer)) ent \(b(m.revEnterprise)) agents \(b(m.revAgents)) other \(b(m.revOther + m.revCloud + m.revChips + m.revLicensing + m.revLabor + m.revGroup))]"
              + " · costs \(b(m.opex)) [rent \(b(m.costRent)) power \(b(m.costPower)) sites \(b(m.costSites)) payroll \(b(m.costPayroll)) data \(b(m.costData)) mkt \(b(m.costMarketing)) chipdesign \(b(m.costChipDesign)) orgs \(b(m.costAgentOrgs)) other \(b(m.costOther)) chips \(b(m.costChips))]"
              + " · wtp chat $\(Fmt.trim(Market.chatWTP(s), 1)) agent $\(Fmt.trim(Market.agentWTP(s) ?? 0, 1)) free-starved \(Fmt.pct(s.freeTierStarved)) · market api $\(Fmt.trim(s.models.last.map { Treasury.marketPrice($0, s) } ?? 0, 3))"
              + " · chat $\(Fmt.trim(s.chatPrice, 1)) agent $\(Fmt.trim(s.agentPrice, 1)) · api: " + s.models.filter { $0.released && !$0.retired && $0.api }.map { "\($0.name) $\(Fmt.trim($0.apiPrice, 3)) \($0.autoPrice ? "auto" : "manual")" }.joined(separator: ", "))
    }

    /// What the price tools say: chat, agent and API revenue a month at a few prices.
    private static func forecastLines(_ s: GameState) {
        let snap = Market.snapshot(s)
        let chat = [10.0, 20, 30, 45, 60, 90].map { p in "$\(Int(p)): \(Fmt.money(MarketForecast.chat(s, price: p, snap: snap).revenueMonth))" }.joined(separator: " ")
        let agent = [50.0, 100, 200, 300, 450, 700].compactMap { p in MarketForecast.agents(s, price: p).map { "$\(Int(p)): \(Fmt.money($0.revenueMonth))" } }.joined(separator: " ")
        if ProcessInfo.processInfo.environment["REPLAY_API"] != nil {
            for p in snap.api.sorted(by: { $0.share > $1.share }).prefix(14) { print("      api \(p.isPlayer ? "*" : " ")\(p.name) c=\(Fmt.trim(p.c, 2)) $\(Fmt.trim(p.price, 3)) brand \(Int(p.brand)) tps \(Int(p.tps)) share \(Fmt.pct(p.share)) attr \(Fmt.trim(p.attraction, 3))") }
            print("      frontier c \(Fmt.trim(Macro.frontier(s.year), 2)) tokens pool \(Fmt.count(snap.apiTokenPool)) budgetScale \(Fmt.trim(snap.apiBudgetScale, 2)) reliability \(Fmt.trim(s.reliability, 2))")
        }
        print("    FORECAST chat/mo \(chat) | agent/mo \(agent)")
        if let m = s.models.first(where: { $0.released && !$0.retired && $0.api }) {
            let api = [0.5, 0.75, 1, 1.5, 2].compactMap { k in MarketForecast.api(s, model: m.id, price: m.apiPrice * k).map { "$\(Fmt.trim(m.apiPrice * k, 2)): \(Fmt.money($0.revenueMonth)) (\(Fmt.pct($0.share)))" } }.joined(separator: " ")
            print("    FORECAST api/mo \(m.name) \(api) · lost API \(Fmt.money(s.lostAPIMonth))/mo chat \(Fmt.pct(s.lostChatFrac)) agents \(Fmt.pct(s.lostAgentFrac))")
        }
    }

    private static func report(_ s: GameState) {
        let pools = Economy.pools(s)
        let usable = pools.reduce(0) { $0 + $1.owned }
        let waiting = Economy.waitingChips(s).reduce(0) { $0 + $1.count }
        let queue = s.researchQueue.prefix(4).map { e in
            "\(e) \(Int(s.researchProgress[e] ?? 0))/\(Int(ResearchLab.entryCost(s, e)))"
        }.joined(separator: ", ")
        print("\(s.date.gameShort): owned usable \(Fmt.int(usable)), idle \(Fmt.int(pools.reduce(0) { $0 + $1.free })), waiting \(Fmt.int(waiting)), research chips \(s.researchChips.values.reduce(0, +))"
              + " · \(Fmt.trim(s.rpToday, 1)) RP/day · queue: \(queue.isEmpty ? "empty" : queue)")
        for r in s.runs where r.started >= startDate {
            print("    RUN \(r.design.name): \(r.status.rawValue) \(Fmt.pct(r.progress, decimals: 1)) · \(r.design.parts.map { "\(Fmt.int($0.chips)) \($0.accelID)" }.joined(separator: " + ")) · cost \(Fmt.money(r.cost)) · \(r.interruptions) interruptions" + (r.note.isEmpty ? "" : " · \(r.note)"))
        }
        if let m = s.models.last, !announced.contains(m.name), s.runs.contains(where: { $0.design.name == m.name && $0.status == .done && $0.started >= startDate }) {
            announced.insert(m.name)
            print("    FINISHED \(m.name): actual c \(Fmt.trim(m.c, 2)) index \(Fmt.score(m.index))")
        }
        let live = s.models.filter { $0.released && !$0.retired }
        var liveText = ""
        for m in live { liveText += " \(m.name) \(Fmt.count(m.capacityTokensDay))/\(Fmt.count(m.demandTokensDay))" }
        var swarmText = ""
        for sw in s.swarms {
            let mname: String = s.models.first(where: { $0.id == sw.modelID })?.name ?? "?"
            swarmText += " [\(sw.name) \(sw.paused ? "paused" : "running") on \(mname)]"
        }
        let chat: String = s.models.first(where: { $0.id == s.chatModelID })?.name ?? "none"
        let agent: String = s.models.first(where: { $0.id == s.agentModelID })?.name ?? "none"
        print("    live models \(live.count) (capacity/demand:\(liveText)) · chat \(chat) · agent \(agent)")
        print("    users \(Fmt.count(s.consumerUsers)) (\(Fmt.count(s.paidUsers)) paid) · seats \(Fmt.count(s.agentSeats)) · cash \(Fmt.money(s.cash)) · lifetime revenue \(Fmt.money(s.lifetimeRevenue)) · swarms:\(swarmText.isEmpty ? " none" : swarmText)")
        for n in s.news.prefix(6) where n.date == s.date && ProcessInfo.processInfo.environment["REPLAY_NEWS"] != nil { print("    news: \(n.title) — \(n.body)") }
        if ProcessInfo.processInfo.environment["REPLAY_POOLS"] != nil {
            for p in pools where p.total > 0 { print("    pool \(p.accel.name): owned \(p.owned) rented \(p.rented) free \(p.free) leased \(p.leased) training \(p.training) research \(p.research) swarm \(p.swarm) inference \(p.inference)") }
        }
        // Money: cash, debts, board confidence and the day's new alerts.
        let debts = s.corp.debts.map { "\($0.kind.rawValue) \(Fmt.money($0.balance)) (+\(Fmt.trim($0.penalty, 1)) pts, \($0.breaches) breaches)" }.joined(separator: ", ")
        let leases = s.sites.filter(\.isTermLease).map { "\($0.name): \(Fmt.money($0.monthlyFee))/mo, +\(Fmt.watts($0.rampKW * 1000)) to come, deposit \(Fmt.money($0.deposit))" }.joined(separator: "; ")
        print("    cash \(Fmt.money(s.cash)) · debt \(Fmt.money(Economy.debt(s))) [\(debts)] · board \(Int(s.boardConfidence)) · rating \(s.corp.rating) · leases: \(leases)")
        if ProcessInfo.processInfo.environment["REPLAY_SITES"] != nil {
            for r in Campus.overview(s) {
                print("    site \(r.site.name): \(r.ready ? "open" : "opens \(r.site.ready.gameShort)") free \(Fmt.watts(r.freeKW * 1000)) of \(Fmt.watts(r.site.capacityKW * 1000)) · chips \(r.chips.map { "\($0.count)× \($0.accelID)" }.joined(separator: ", ")) · waiting \(r.waiting) · arriving \(r.arrivals.prefix(3).map { "\($0.label) \($0.date.gameShort)" }.joined(separator: "; "))")
            }
            for i in Campus.idleOrders(s) { print("    IDLE ORDER: \(i.order.count)× \(i.order.accelID) arrives \(i.order.arrives.gameShort), \(i.site.name) opens \(i.site.ready.gameShort)") }
        }
        let q = Corporate.quotes(s).map { "\($0.kind.rawValue) max \(Fmt.money($0.max))" }.joined(separator: ", ")
        print("    borrowing: \(q) · safe EBITDA \(Fmt.money(Corporate.safeEbitda(s))) · LTM \(Fmt.money(Corporate.ebitdaAnnual(s)))")
        if ProcessInfo.processInfo.environment["REPLAY_ADVISOR"] != nil {
            for i in Advisor.items(s, pools: pools) { print("    ADVISOR[\(i.level)] \(i.title) — \(i.detail)\(i.fix == nil ? "" : "  [\(i.fixLabel)]")") }
        }
        if ProcessInfo.processInfo.environment["REPLAY_HYPE"] != nil { HypeHarness.report(s) }   // 3.9
        if ProcessInfo.processInfo.environment["REPLAY_ARENA"] != nil { Arena.report(s) }   // 3.9: the live model arena
        if ProcessInfo.processInfo.environment["REPLAY_SAFETY"] != nil { print("    SAFETY \(Fmt.trim(s.safetyScore, 1)) (carried adjustment \(Fmt.trim(s.safetyAdjust, 2))) · \(s.security.title)") }
        if ProcessInfo.processInfo.environment["REPLAY_CONTRACT"] != nil { for l in FoundingContracts.replayLines(s) { print(l) } }   // 3.9
        DramaHarness.report(s)   // 3.9: dramatic events as they fire and resolve
        for a in s.alerts where a.date == s.date { print("    ALERT\(a.critical ? "!" : ""): \(a.title) — \(a.body)") }
        for n in s.news.prefix(12) where n.date == s.date && (n.title.hasPrefix("Inbox:") || n.title.contains("ovenant") || n.title.contains("enalty")) {
            print("    NEWS: \(n.title) — \(n.body)")
        }
        if ProcessInfo.processInfo.environment["REPLAY_BOOK"] != nil {
            let c = Commercial.capacity(s)
            print("    BOOKINGS base \(Fmt.money(c.base))/mo · ramp \(Fmt.money(c.ramp)) · team \(Fmt.money(c.team)) (\(Fmt.trim(Commercial.teamUnits(s), 0)) units, \(s.employees.count) staff) · cap \(Fmt.money(c.cap)) · unbooked today \(Fmt.money(s.corp.unbookedToday))/day")
        }
        let fab = s.orders.filter { AlienFab.isAlienChip($0.accelID) }
        if s.alienFab.exists {
            let own = s.owned.filter { AlienFab.isAlienChip($0.accelID) }.reduce(0) { $0 + $1.count }
            print("    fab \(Fmt.int(Int(s.alienFab.capacityMonth)))/mo · own chips installed \(Fmt.int(own)) · "
                  + (fab.isEmpty ? "no orders" : fab.map { "\(Fmt.int($0.count)) to come (\(Fmt.int($0.delivered ?? 0)) delivered), next chips \(AlienFab.nextShipment($0, s).gameShort), all by \($0.arrives.gameShort)" }.joined(separator: "; ")))
        }
    }
}
