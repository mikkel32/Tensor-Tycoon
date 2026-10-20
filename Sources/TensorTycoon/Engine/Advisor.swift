import Foundation

/// A one-click fix the Chief of Staff can carry out for you.
enum AdvisorFix: Hashable {
    case deploy(model: UUID, accel: String, chips: Int)
    case launch(UUID)
    case autoPrice([UUID])
    case autoResearch
    case queueRefine(String)
    case resumeRun(UUID)
    case shrinkAndResume(UUID, chips: Int)
    case lease(accel: String, chips: Int)
    case renewRental(UUID)
    case raise(Double)
    case upgradeOffice
    case upgradeSecurity
    case auditSwarm(UUID)
    case auditRSI(UUID)
    case setChat(UUID)
    case setAgent(UUID)
    case raises
    case enableDelegate(String)
    /// 3.5: lease datacenter space (location, MW, years).
    case leaseCapacity(String, Double, Int)
    /// Handled by the app: open this decision.
    case openDecision(UUID)
    /// 3.8: set a fab's share for its product (the rest goes to foundry customers).
    case fabShare(UUID, Double)
}

/// Your chief of staff: a short, prioritised list of things that need your attention right now, most with a fix.
struct AdvisorItem: Identifiable, Hashable {
    enum Level: Int, Comparable {
        case info, warning, urgent
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }
    var id: String
    var level: Level
    var symbol: String
    var title: String
    var detail: String
    var screen: Screen
    var fix: AdvisorFix? = nil
    var fixLabel: String = ""
}

enum Advisor {
    static func items(_ s: GameState, pools: [ComputePool], watch: [RivalIntel.Row]? = nil, set: [Benchmark]? = nil) -> [AdvisorItem] {
        var out: [AdvisorItem] = []
        func add(_ id: String, _ level: AdvisorItem.Level, _ symbol: String, _ title: String, _ detail: String, _ screen: Screen,
                 fix: AdvisorFix? = nil, _ fixLabel: String = "") {
            out.append(AdvisorItem(id: id, level: level, symbol: symbol, title: title, detail: detail, screen: screen, fix: fix, fixLabel: fixLabel))
        }
        let indexSet = set ?? Leaderboard.indexSet(s)

        // Money
        if s.cash < 0 {
            add("cash", .urgent, "exclamationmark.octagon.fill", "Out of cash", "Raise money, borrow, sell hardware or cut costs within \(60 - s.daysNegativeCash) days.", .funding)
        } else if let months = Treasury.runwayMonths(s), months < 4 {
            add("runway", .urgent, "hourglass", "\(Fmt.trim(months, 1)) months of runway", "Start a fundraise now — rounds take weeks.", .funding,
                fix: s.raising || s.isPublic ? nil : .raise(0.15), "Start raising")
        }
        if !s.raiseOffers.isEmpty {
            add("offers", .warning, "banknote.fill", "\(s.raiseOffers.count) term sheet\(s.raiseOffers.count == 1 ? "" : "s") waiting", "Offers expire in 14 days.", .funding)
        }
        if s.boardConfidence < 25 && !s.founderControls {
            add("board", .urgent, "person.crop.circle.badge.exclamationmark", "The board is losing faith (\(Int(s.boardConfidence))/100)", "Hit a board goal or you may be replaced.", .strategy)
        }
        if let o = s.objectives.filter({ !$0.done && !$0.failed }).min(by: { $0.deadline < $1.deadline }),
           GameCalendar.daysBetween(s.date, o.deadline) < 60, o.progress < 0.7 {
            add("goal", .warning, o.kind.symbol, "Board goal due \(o.deadline.gameShort)", o.title, .strategy)
        }

        // Inbox: offers waiting for an answer
        for d in s.decisions where !Alerts.isUrgent(d) {
            let left = d.deadline.map { GameCalendar.daysBetween(s.date, $0) } ?? 21
            add("inbox-\(d.id)", left <= 5 ? .warning : .info, "tray.full.fill", d.title,
                "Waiting for your answer — \(left) day\(left == 1 ? "" : "s") left, then it resolves on its own.", .dashboard,
                fix: .openDecision(d.id), "Answer")
        }

        // Training
        for r in s.runs where r.status == .paused && s.decisions.allSatisfy({ $0.ref != r.id.uuidString }) {
            let free = Economy.freeChips(s, r.design.accelID)
            if free >= r.design.chips {
                add("run-\(r.id)", .warning, "pause.circle.fill", "\(r.design.name) is paused", r.note.isEmpty ? "Its chips are free again — resume it." : r.note, .training,
                    fix: .resumeRun(r.id), "Resume")
            } else if free >= max(1, r.design.chips / 4) {
                add("run-\(r.id)", .warning, "pause.circle.fill", "\(r.design.name) is stalled",
                    "\(r.note.isEmpty ? "Not enough chips to resume." : r.note) It can resume on the \(Fmt.int(free)) that are free, slower.", .training,
                    fix: .shrinkAndResume(r.id, chips: free), "Resume on \(Fmt.int(free))")
            } else {
                add("run-\(r.id)", .warning, "pause.circle.fill", "\(r.design.name) is stalled", r.note.isEmpty ? "Not enough free chips to resume it." : r.note, .training)
            }
        }
        if let r = s.runs.first(where: { $0.kind == .full && Training.isLive($0) && $0.design.chips >= 50_000 && $0.opsCoverage < 0.5 }) {
            add("ops-\(r.id)", .warning, "wrench.and.screwdriver.fill", "\(r.design.name) is losing time to failures",
                "Only \(Fmt.pct(r.opsCoverage, decimals: 0)) of its \(Fmt.int(r.design.chips)) chips are watched by ops agents. Assign agents on its run card.", .training)
        }

        // Nothing training: the frontier moves without you.
        if !s.runs.contains(where: { $0.kind == .full && ($0.status == .running || $0.status == .postTraining || $0.status == .paused) }),
           let newest = s.models.filter({ !$0.preview }).map(\.created).max(), GameCalendar.daysBetween(newest, s.date) > 60,
           pools.reduce(0, { $0 + $1.free }) >= 8 {
            add("next-run", .info, "flask.fill", "No frontier run in progress", "Your newest model is \(GameCalendar.daysBetween(newest, s.date)) days old and chips are free. Rivals ship every few months.", .lab,
                fix: s.ops.autoTrain ? nil : .enableDelegate("autoTrain"), "Let the COO plan it")
        }

        // Research
        if s.signatureLevel == 0 {
            add("signature", .warning, "crown.fill", "Choose your lab's signature secret", "A research programme only you have, live from day one.", .research)
        }
        if s.researchQueue.isEmpty && !s.autoResearch {
            add("research", .warning, "lightbulb.fill", "Research queue is empty", "Your researchers are idle. The research director keeps the queue full.", .research,
                fix: .autoResearch, "Turn on the director")
        }
        let refinable = s.exoticOwned.filter { s.researched.contains($0) && (s.exoticMastery[$0] ?? 1) < Breakthroughs.maxMastery }
        if let r = refinable.first, s.researchQueue.count <= 1 && !s.researchQueue.contains(where: { $0.hasPrefix(Breakthroughs.refinePrefix) }) {
            add("refine", .info, "star.square.on.square.fill", "Refine a unique breakthrough", "Mastery II and III make your secret tech much stronger.", .research,
                fix: .queueRefine(r), "Queue refinement")
        }

        // Models & serving
        let released = s.models.filter { $0.released && !$0.retired }
        let best = released.max { $0.index < $1.index }
        if let m = released.max(by: { $0.c < $1.c }), m.api, m.deployments.isEmpty {
            let fix = deployFix(s, m, pools: pools, target: 4)
            add("deploy-\(m.id)", .warning, "cube.box.fill", "\(m.name) has no servers", "Your best released model can't take API traffic.", .models,
                fix: fix.map { .deploy(model: m.id, accel: $0.0, chips: $0.1) },
                fix.map { "Deploy \(Fmt.int($0.1)) chips (\(Fmt.count($0.2)) tokens/day)" } ?? "")
        }
        if let m = s.models.filter({ $0.capacityTokensDay > 0 && $0.demandTokensDay > $0.capacityTokensDay * 1.15 }).max(by: { $0.demandTokensDay < $1.demandTokensDay }) {
            let fix = growFix(s, m)
            add("capacity-\(m.id)", .warning, "flame.fill", "\(m.name) is over capacity", "Demand is \(Int(m.demandTokensDay / m.capacityTokensDay * 100))% of capacity; users are churning.", .models,
                fix: fix.map { .deploy(model: m.id, accel: $0.0, chips: $0.1) } ?? (s.ops.autoscale ? nil : .enableDelegate("autoscale")),
                fix.map { "Add \(Fmt.int($0.2)) chips" } ?? "Let the COO scale it")
        }
        let unreleased = s.models.filter { !$0.released && !$0.retired && !$0.preview }
        if let m = unreleased.max(by: { $0.c < $1.c }), m.c > (released.map(\.c).max() ?? -10) {
            let tier = SafetyFramework.tier(m)
            let unsafe = tier >= .high && !SafetyFramework.meetsBar(m)
            add("release-\(m.id)", unsafe ? .warning : .info, "shippingbox.fill", "\(m.name) is ready to ship",
                unsafe ? "It crosses the \(tier.label) line with safety \(Int(m.safety)), below the \(Int(tier.requiredSafety)) its safeguards need. Releasing now invites misuse."
                       : "It beats everything you've released. Launching moves your chat app, agents and contracts onto it.", .models,
                fix: unsafe ? nil : .launch(m.id), "Launch it")
        }
        let stale = s.models.filter { $0.released && $0.api && !$0.autoPrice && $0.apiPrice > Treasury.targetPrice($0, s) * 1.8 }
        if !stale.isEmpty {
            add("price", .info, "tag.fill", "Some API prices are stale", "\(stale.map(\.name).joined(separator: ", ")) cost far more than the market pays.", .models,
                fix: .autoPrice(stale.map(\.id)), "Turn on auto-pricing")
        }
        if let best, best.design.instruct, let chat = s.chatModelID, chat != best.id,
           let cm = s.models.first(where: { $0.id == chat }), best.index > cm.index + 2 {
            add("chat-\(best.id)", .info, "bubble.left.fill", "Your chat app runs \(cm.name)", "\(best.name) scores \(Fmt.score(best.index - cm.index)) points higher.", .market,
                fix: .setChat(best.id), "Switch to \(best.name)")
        }
        if let best, best.design.toolUse, let ag = s.agentModelID, ag != best.id,
           let am = s.models.first(where: { $0.id == ag }), best.index > am.index + 2 {
            add("agent-\(best.id)", .info, "figure.walk.motion", "Your agent product runs \(am.name)", "\(best.name) would be a better agent.", .market,
                fix: .setAgent(best.id), "Switch to \(best.name)")
        }

        // Compute
        let total = pools.reduce(0) { $0 + $1.total }
        let reserve = s.ops.reserveShare
        func spare(_ p: ComputePool) -> Int { max(0, p.free - Int(Double(p.total) * reserve)) }
        let idle = pools.reduce(0) { $0 + spare($1) }
        if total >= 16 && idle >= max(16, total / 20) {
            let biggest = pools.filter { $0.owned > 0 }.max { spare($0) < spare($1) }
            let leasable = biggest.map { min(spare($0), $0.owned - (s.leases[$0.accel.id] ?? 0)) } ?? 0
            if let p = biggest, leasable >= 64 {
                add("idle", .warning, "cpu", "\(Fmt.int(idle)) accelerators idle", "Train, serve, run agents — or lease them out.", .compute,
                    fix: .lease(accel: p.accel.id, chips: (s.leases[p.accel.id] ?? 0) + leasable), "Lease \(Fmt.int(leasable)) \(p.accel.name)")
            } else {
                add("idle", .warning, "cpu", "\(Fmt.int(idle)) accelerators idle", "Train, serve, run agents — or lease them out.", .compute)
            }
        }
        // 3.5: out of datacenter power with little on the way.
        if let pb = Power.powerBound(s) {
            if let q = DCMarket.quickLease(s, mw: pb.suggestMW), let loc = LocationCatalog.byID[q.locationID] {
                add("power-bound", .warning, "bolt.trianglebadge.exclamationmark.fill", "Your datacenters are \(Fmt.pct(pb.used, decimals: 0)) full",
                    "Little new power is on the way, so new chips will have nowhere to go. Lease space now, or buy or build a campus on the Datacenters page.", .datacenters,
                    fix: .leaseCapacity(q.locationID, pb.suggestMW, 3),
                    "Lease \(Fmt.watts(pb.suggestMW * 1e6)) in \(loc.name.split(separator: ",").first.map(String.init) ?? loc.name) (\(Fmt.money(q.rate * pb.suggestMW * 1000))/mo, \(q.days) days)")
            }
        }
        if let site = s.sites.first(where: { $0.phaseBlocked && $0.plannedKW > 0 }) {
            add("phase-\(site.id)", .info, "hammer.fill", "\(site.name): next phase waits for cash",
                "\(Fmt.watts(site.plannedKW * 1000)) of planned capacity is on hold until you can pay for the next phase.", .datacenters)
        }
        for r in s.rentals {
            guard let end = r.end, r.term.months != nil, GameCalendar.daysBetween(s.date, end) <= 14, GameCalendar.daysBetween(s.date, end) >= 0 else { continue }
            let name = HardwareCatalog.get(r.accelID)?.name ?? r.accelID
            add("rental-\(r.id)", .warning, "clock.badge.exclamationmark", "\(Fmt.int(r.count))× \(name) reservation ends \(end.gameShort)",
                "When it ends, those chips leave your fleet and whatever runs on them gets cut back.", .compute, fix: .renewRental(r.id), "Renew it")
        }

        // The industry
        if let c = s.competitors.first(where: { !$0.acquired && $0.distressMonths > 0 }) {
            add("distress-\(c.id)", .info, "exclamationmark.triangle.fill", "\(c.def.name) is running out of money", "Its researchers and compute may soon be cheap.", .industry)
        }
        let rows = watch ?? RivalIntel.rows(s, set: indexSet)
        if let r = rows.first(where: { $0.threat == .passYou && GameCalendar.daysBetween(s.date, $0.outlook.center) <= 30 }),
           let mine = RivalIntel.playerBest(s, set: indexSet) {
            add("watch-\(r.id)", .warning, "binoculars.fill", "\(r.project.name) is about to pass you",
                "\(r.lab), rumoured \(RivalIntel.windowText(r.outlook)) at ~\(Fmt.score(r.outlook.index)) vs your \(Fmt.score(mine.index)). Ship your next model first to steal the launch.", .rivalWatch)
        }
        if let war = s.competitors.first(where: { RivalStrategy.isActive($0, s) && RivalStrategy.play($0) == .priceWar }), released.contains(where: \.api) {
            add("pricewar-\(war.id)", .info, "tag.slash.fill", "\(war.def.name) is in a price war", "\(war.playReason) Auto-pricing follows the market; or compete on quality.", .rivalWatch)
        }
        if RivalEconomy.inCorrection(s) {
            add("correction", .info, "chart.line.downtrend.xyaxis", "The AI market is correcting", "Valuations are down, but GPUs and cloud capacity are cheaper.", .industry)
        }

        // Business
        let leads = s.deals.filter { !$0.active }.count
        if leads > 0 {
            add("leads", .info, "briefcase.fill", "\(leads) enterprise lead\(leads == 1 ? "" : "s")", "Review them before they expire.", .market,
                fix: s.ops.autoLeads ? nil : .enableDelegate("autoLeads"), "Let the COO sign the ones you can serve")
        }
        if let d = s.deals.filter({ $0.active && $0.breaches >= 2 }).max(by: { $0.breaches < $1.breaches }) {
            add("sla-\(d.id)", d.breaches >= 4 ? .urgent : .warning, "exclamationmark.bubble.fill", "\(d.client) is unhappy",
                "\(d.breaches) SLA breaches this month; six and they cancel. Its model needs more capacity.", .market,
                fix: s.ops.autoscale ? nil : .enableDelegate("autoscale"), "Let the COO scale capacity")
        }

        // Swarms, self-improvement, alien tech, chips
        if let sw = s.swarms.filter({ !$0.paused }).min(by: { $0.alignmentMeasured < $1.alignmentMeasured }), sw.alignmentMeasured < 50 {
            add("swarm-align", .urgent, "shield.lefthalf.filled", "\(sw.name) alignment at \(Int(sw.alignmentMeasured))", "Raise oversight, audit or purge before it turns.", .swarms,
                fix: .auditSwarm(sw.id), "Deep audit")
        }
        if let sw = s.swarms.first(where: { !$0.paused && $0.agents > 0 && $0.active < Double($0.agents) * 0.6 }) {
            add("swarm-chips", .info, "person.3.sequence.fill", "\(sw.name) is compute-bound", "Only \(Fmt.count(sw.active)) of \(Fmt.count(Double(sw.agents))) agents can run.", .swarms)
        }
        if let r = s.rsiRuns.filter({ $0.status == .running }).min(by: { $0.alignmentMeasured < $1.alignmentMeasured }), r.alignmentMeasured < 50 {
            add("rsi-\(r.id)", r.alignmentMeasured < 35 ? .urgent : .warning, "arrow.triangle.2.circlepath.circle.fill", "\(r.name) alignment at \(Int(r.alignmentMeasured))",
                "A self-improving model this far out of line can try to escape. Audit, raise oversight or roll back.", .rsi, fix: .auditRSI(r.id), "Deep audit")
        }
        if let a = s.xenoArtifacts.first(where: { $0.kind.hasVenture && $0.venture.isEmpty }) {
            add("xeno-venture-\(a.id)", .info, "dollarsign.circle.fill", "\(a.name) could be a business", "License it or build it in-house on the Alien Tech page.", .xeno)
        }
        if XenoScience.hasUndeciphered(s) && s.xenoStudyShare <= 0 {
            add("xeno-study", .info, "eye.trianglebadge.exclamationmark", "Nobody is studying your alien tech", "Put some research into decoding it: stronger effects, fewer anomalies.", .xeno)
        }
        if let a = s.alienArchs.first(where: { $0.chipID == nil && !$0.fabbing }) {
            add("xeno-fab", .info, "atom", "\(a.name) chip isn't taped out", "It costs a few percent of a GPU to make.", .xeno)
        }
        let offers = s.alienArchs.reduce(0) { $0 + $1.offers.count }
        if offers > 0 {
            add("xeno-offers", .warning, "doc.text.fill", "\(offers) license offer\(offers == 1 ? "" : "s")", "Big players want your blueprint.", .xeno)
        }
        if let l = s.chipLines.first(where: { l in
            let alien = AlienFab.isAlienChip(l.chipID)
            return l.active && l.demandToday > (alien ? AlienFab.merchantPerLine(s) : l.capacityMonth / 30.4) * 1.5
                && (alien ? s.alienFab.pendingCapacity : l.pendingCapacity) == 0
        }) {
            add("fab-\(l.chipID)", .info, "shippingbox.fill", "Chip demand outstrips your foundry", "Buyers want \(Fmt.count(l.demandToday * 30.4))/month.", .chipSales)
        }
        // 3.5: the alien path's first blocked step (chips with nowhere to go, a stalled run on alien silicon).
        if !s.alienArchs.isEmpty, let st = AlienPath.stages(s).first(where: { $0.status == .blocked && $0.id != "search" && $0.id != "tapeout" && $0.id != "nextgen" }) {
            add("xeno-path-\(st.id)", .warning, st.symbol, "Alien tech: \(st.title.lowercased()) is blocked", st.blocker ?? st.detail, .xeno)
        }

        // Security & policy
        let attract = SecurityOps.attractiveness(s)
        if attract >= 1.0 && s.security < .sl3 && s.securityTarget <= s.security.rawValue {
            let next = SecurityLevel(rawValue: s.security.rawValue + 1) ?? s.security
            add("security", .warning, "lock.shield.fill", "Your weights are a target at \(s.security.title)", "Near-frontier weights draw criminals and state hackers. Upgrade security.", .security,
                fix: .upgradeSecurity, "Upgrade to \(next.title) (\(Fmt.money(SecurityOps.upgradeCost(next, s))))")
        }

        // People
        if s.employees.count >= Economy.officeCapacity(s) {
            add("office", .info, "building.2.fill", "Office is full", "Upgrade it to keep hiring.", .team, fix: .upgradeOffice, "Move to a bigger office")
        }
        let underpaid = s.employees.filter { $0.salary < Macro.salary($0.role, s.year) * 0.75 }
        if underpaid.count >= 3 && !s.ops.autoRaises {
            add("pay", .warning, "dollarsign.arrow.circlepath", "\(underpaid.count) people are paid well below market", "Morale falls and rivals poach. Give raises, or let the COO keep pay current.", .team,
                fix: .raises, "Give raises")
        }
        out += Semis.advisorItems(s)   // 3.5: semiconductors (nothing until you're in the business)
        let today = s.date
        return out.filter { item in s.snoozed[item.id].map { $0 <= today } ?? true }.sorted { $0.level > $1.level }
    }

    /// Chips to give model `m` on the fastest pool with room, sized to its demand (`replicas` replicas when it has
    /// none yet): (accelID, total chips after, tokens a day they serve).
    static func deployFix(_ s: GameState, _ m: AIModel, pools: [ComputePool], target replicas: Int) -> (String, Int, Double)? {
        let b = s.bonuses
        var best: (String, Int, Double)?
        for p in pools where p.free > 0 {
            guard let (per, k) = Operations.perChip(m, p.accel.id, b) else { continue }
            let want = m.demandTokensDay > 0 ? Int((m.demandTokensDay / 0.8 / per / Double(k)).rounded(.up)) * k : k * replicas
            let n = min(p.free, max(k, want)) / k * k
            guard n > 0 else { continue }
            let cap = Double(n) * per
            // Fastest chips first; among equals, the pool that covers most.
            if best == nil || per > (Operations.perChip(m, best!.0, b)?.0 ?? 0) + 1e-9
                || (abs(per - (Operations.perChip(m, best!.0, b)?.0 ?? 0)) <= 1e-9 && cap > best!.2) { best = (p.accel.id, n, cap) }
        }
        return best
    }

    /// Chips that bring an over-capacity model to ~80% load on its own hardware: (accelID, total after, added).
    static func growFix(_ s: GameState, _ m: AIModel) -> (String, Int, Int)? {
        let b = s.bonuses
        guard let dep = m.deployments.max(by: { $0.chips < $1.chips }), let (per, k) = Operations.perChip(m, dep.accelID, b) else { return nil }
        let wanted = Int((m.demandTokensDay / 0.8 / per / Double(k)).rounded(.up)) * k
        let add = min(wanted - dep.chips, Economy.freeChips(s, dep.accelID)) / k * k
        guard add > 0 else { return nil }
        return (dep.accelID, dep.chips + add, add)
    }

    /// Carry out a fix. Returns an error message, or nil.
    static func apply(_ s: inout GameState, _ fix: AdvisorFix) -> String? {
        switch fix {
        case .deploy(let model, let accel, let chips):
            return s.deploy(model, accelID: accel, chips: chips)
        case .launch(let id):
            return s.launch(id)
        case .autoPrice(let ids):
            for id in ids { s.setAutoPrice(id, true) }
            return nil
        case .autoResearch:
            s.setAutoResearch(true)
            return nil
        case .queueRefine(let id):
            return s.queueRefine(id)
        case .resumeRun(let id):
            return s.setRunStatus(id, .running)
        case .shrinkAndResume(let id, let chips):
            if let e = s.resizeRun(id, chips: chips) { return e }
            return s.setRunStatus(id, .running)
        case .lease(let accel, let chips):
            return s.setLease(accel, chips: chips)
        case .renewRental(let id):
            guard let i = s.rentals.firstIndex(where: { $0.id == id }), let end = s.rentals[i].end, let months = s.rentals[i].term.months else { return "Nothing to renew." }
            s.rentals[i].end = GameCalendar.addMonths(end, months)
            if let rate = Economy.rentQuote(HardwareCatalog.get(s.rentals[i].accelID) ?? HardwareCatalog.h100, s) {
                s.rentals[i].hourly = rate * s.rentals[i].term.discount
            }
            return nil
        case .raise(let fraction):
            return s.startRaise(fraction: fraction)
        case .upgradeOffice:
            return s.upgradeOffice()
        case .upgradeSecurity:
            return s.upgradeSecurity()
        case .auditSwarm(let id):
            return s.auditSwarm(id)
        case .auditRSI(let id):
            return s.auditRSI(id)
        case .setChat(let id):
            s.setChatModel(id)
            return nil
        case .setAgent(let id):
            s.setAgentModel(id)
            return nil
        case .raises:
            for e in s.employees where e.salary < Macro.salary(e.role, s.year) * 0.85 { s.giveRaise(e.id) }
            return nil
        case .enableDelegate(let name):
            // Turn it on and let it do its first round now, not at its next scheduled check.
            let precision = Operations.competence(s).precision
            switch name {
            case "autoscale": s.ops.autoscale = true; Operations.autoscale(&s, s.bonuses, precision: precision)
            case "autoLeads": s.ops.autoLeads = true; Operations.autoLeads(&s)
            case "autoLaunch": s.ops.autoLaunch = true; Operations.autoLaunch(&s)
            case "autoRenew": s.ops.autoRenew = true; Operations.autoRenew(&s)
            case "leaseIdle": s.ops.leaseIdle = true; Operations.leaseIdle(&s)
            case "autoHire": s.ops.autoHire = true; Operations.autoHire(&s, precision: precision)
            case "autoRaises": s.ops.autoRaises = true; Operations.autoRaises(&s)
            case "autoTrain": s.ops.autoTrain = true; Operations.autoTrain(&s, precision: precision)
            default: return "Unknown delegate."
            }
            return nil
        case .leaseCapacity(let loc, let mw, let years):
            return s.leaseCapacity(locationID: loc, mw: mw, years: years, cooling: s.year >= 2023 ? .liquid : .air)
        case .openDecision:
            return nil
        case .fabShare(let id, let share):
            guard s.semi.fabs.contains(where: { $0.id == id }) else { return "That fab is gone." }
            s.setFabShare(id, share: share)
            return nil
        }
    }
}
