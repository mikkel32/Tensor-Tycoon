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
            if t == "auto:price" { s.autoSubPrice = true; continue }
            if t == "evenshortage" { s.evenShortage = true; continue }
            if t == "ops:autoscale" { s.ops.autoscale = true; continue }
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
        report(s)
        var dayNo = 0
        for _ in 0..<days where s.gameOver == nil {
            dayNo += 1
            for _ in 0..<10 where answer {
                guard let d = s.decisions.first else { break }
                s.resolveDecision(d.id, option: 0)
            }
            Sim.advanceDay(&s)
            report(s)
            if dayNo % 30 == 0 { moneyLine(s); forecastLines(s) }
        }
        return 0
    }

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
