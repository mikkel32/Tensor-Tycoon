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
            for (i, p) in props.enumerated() {
                print("proposal \(i) \(p.label): \(p.design.name) · \(p.blurb) · forecast c \(Fmt.trim(p.est.forecast.c, 2)) (vs best live \(p.vsBest.map { Fmt.trim($0, 2) } ?? "none"), vs rivals \(Fmt.trim(p.vsRival, 2))) · \(Fmt.params(p.design.paramsB)) on \(Fmt.tokens(p.design.tokensT)) · goodput \(Fmt.pct(p.est.goodput, decimals: 0)) · left out \(p.leftOut) · free for serving: \(p.othersIdle)")
            }
            if let n = Int(spec.split(separator: "@").first ?? ""), props.indices.contains(n) {
                print(RunPlanner.start(props[n], &s).map { "could not start: \($0)" } ?? "started \(props[n].design.name)")
            }
        }
        for spec in pending where !spec.contains("@") { planAndStart(spec) }
        for day in 0..<days where s.gameOver == nil {
            for spec in pending where spec.hasSuffix("@\(day)") { planAndStart(spec) }
            for _ in 0..<10 where answer {
                guard let d = s.decisions.first else { break }
                s.resolveDecision(d.id, option: 0)
            }
            Sim.advanceDay(&s)
            report(s)
        }
        if let g = s.gameOver { print("GAME OVER: \(g)") }
        if !s.opsLog.isEmpty { print("delegate log (newest first):"); for l in s.opsLog.prefix(25) { print("  \(l)") } }
        if !s.ops.tally.isEmpty { print("delegate tally: \(s.ops.tally.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value) (\(Fmt.money(s.ops.moved[$0.key] ?? 0)))" }.joined(separator: ", "))") }
        return 0
    }

    nonisolated(unsafe) private static var announced = Set<String>()
    nonisolated(unsafe) private static var startDate = Date.distantPast

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
            print("    RUN \(r.design.name): \(r.status.rawValue) \(Fmt.pct(r.progress, decimals: 1)) · \(Fmt.int(r.design.chips)) chips · cost \(Fmt.money(r.cost)) · \(r.interruptions) interruptions" + (r.note.isEmpty ? "" : " · \(r.note)"))
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
        for a in s.alerts where a.date == s.date { print("    ALERT\(a.critical ? "!" : ""): \(a.title) — \(a.body)") }
        for n in s.news.prefix(12) where n.date == s.date && (n.title.hasPrefix("Inbox:") || n.title.contains("ovenant") || n.title.contains("enalty")) {
            print("    NEWS: \(n.title) — \(n.body)")
        }
        let fab = s.orders.filter { AlienFab.isAlienChip($0.accelID) }
        if s.alienFab.exists {
            let own = s.owned.filter { AlienFab.isAlienChip($0.accelID) }.reduce(0) { $0 + $1.count }
            print("    fab \(Fmt.int(Int(s.alienFab.capacityMonth)))/mo · own chips installed \(Fmt.int(own)) · "
                  + (fab.isEmpty ? "no orders" : fab.map { "\(Fmt.int($0.count)) to come (\(Fmt.int($0.delivered ?? 0)) delivered), next chips \(AlienFab.nextShipment($0, s).gameShort), all by \($0.arrives.gameShort)" }.joined(separator: "; ")))
        }
    }
}
