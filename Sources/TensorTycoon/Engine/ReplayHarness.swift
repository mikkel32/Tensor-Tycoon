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
        var pending: [String] = []   // train:<n>[@<day>]
        for t in techs {
            // cash:<amount> sets cash; noanswer leaves decisions to the inbox defaults; defer:<n> defers every leased tranche n times.
            if t.hasPrefix("cash:") { s.cash = Double(t.dropFirst(5)) ?? s.cash; print("cash set to \(Fmt.money(s.cash))"); continue }
            if t == "noanswer" { answer = false; continue }
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
            if t == "auto:price" { s.autoSubPrice = true; continue }
            if t == "evenshortage" { s.evenShortage = true; continue }
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
            if t.hasPrefix("unretire:") {
                let name = String(t.dropFirst("unretire:".count))
                if let m = s.models.first(where: { $0.name == name }) { s.unretire(m.id); print("unretired \(name)") } else { print("no model named \(name)") }
                continue
            }
            if t.hasPrefix(Breakthroughs.refinePrefix) {
                _ = s.queueRefine(String(t.dropFirst(Breakthroughs.refinePrefix.count)))
            } else {
                s.queueResearch(t)
            }
            print(s.researchQueue.firstIndex(of: t).map { "queued \(t) at #\($0 + 1)" } ?? "could not queue \(t)")
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
            for _ in 0..<10 where answer {
                guard let d = s.decisions.first else { break }
                s.resolveDecision(d.id, option: 0)
            }
            Sim.advanceDay(&s)
            report(s)
            if dayNo % 30 == 0 { moneyLine(s); forecastLines(s) }
        }
        if let g = s.gameOver { print("GAME OVER: \(g)") }
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
