import Foundation

/// Your chief of staff: a short, prioritised list of things that need your attention right now.
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
}

enum Advisor {
    static func items(_ s: GameState, pools: [ComputePool]) -> [AdvisorItem] {
        var out: [AdvisorItem] = []
        func add(_ id: String, _ level: AdvisorItem.Level, _ symbol: String, _ title: String, _ detail: String, _ screen: Screen) {
            out.append(AdvisorItem(id: id, level: level, symbol: symbol, title: title, detail: detail, screen: screen))
        }

        // Money
        if s.cash < 0 {
            add("cash", .urgent, "exclamationmark.octagon.fill", "Out of cash", "Raise money, borrow, sell hardware or cut costs within \(60 - s.daysNegativeCash) days.", .funding)
        } else if let months = Treasury.runwayMonths(s), months < 4 {
            add("runway", .urgent, "hourglass", "\(Fmt.trim(months, 1)) months of runway", "Start a fundraise now — rounds take weeks.", .funding)
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
        if s.culturePoints > 0 {
            add("culture", .info, "theatermasks.fill", "\(s.culturePoints) culture point\(s.culturePoints == 1 ? "" : "s") to spend", "Adopt perks in Strategy & Traits.", .strategy)
        }

        // Research
        if s.signatureLevel == 0 {
            add("signature", .warning, "crown.fill", "Choose your lab's signature secret", "A research programme only you have, live from day one.", .research)
        }
        if s.researchQueue.isEmpty && !s.autoResearch {
            add("research", .warning, "lightbulb.fill", "Research queue is empty", "Your researchers are idle. Turn on the research director to keep it full.", .research)
        }
        let refinable = s.exoticOwned.filter { s.researched.contains($0) && (s.exoticMastery[$0] ?? 1) < Breakthroughs.maxMastery }
        if !refinable.isEmpty && s.researchQueue.count <= 1 && !s.researchQueue.contains(where: { $0.hasPrefix(Breakthroughs.refinePrefix) }) {
            add("refine", .info, "star.square.on.square.fill", "Refine a unique breakthrough", "Mastery II and III make your secret tech much stronger.", .research)
        }

        // Compute
        let total = pools.reduce(0) { $0 + $1.total }
        let idle = pools.reduce(0) { $0 + $1.free }
        if total >= 16 && Double(idle) > Double(total) * 0.15 {
            add("idle", .warning, "cpu", "\(Fmt.int(idle)) accelerators idle", "Train, serve, run agents — or lease them out.", .compute)
        }

        // Models & serving
        for m in s.releasedModels where m.api && m.deployments.isEmpty && m.id == s.releasedModels.max(by: { $0.c < $1.c })?.id {
            add("deploy-\(m.id)", .warning, "cube.box.fill", "\(m.name) has no servers", "Your best released model can't take API traffic.", .models)
        }
        if let m = s.models.filter({ $0.capacityTokensDay > 0 && $0.demandTokensDay > $0.capacityTokensDay * 1.15 }).max(by: { $0.demandTokensDay < $1.demandTokensDay }) {
            add("capacity-\(m.id)", .warning, "flame.fill", "\(m.name) is over capacity", "Users are churning. Add inference chips.", .models)
        }
        let unreleased = s.models.filter { !$0.released && !$0.retired && !$0.preview }
        if let m = unreleased.max(by: { $0.c < $1.c }), m.c > (s.releasedModels.map(\.c).max() ?? -10) {
            add("release-\(m.id)", .info, "shippingbox.fill", "\(m.name) is ready to ship", "It beats everything you've released.", .models)
        }
        if s.models.contains(where: { $0.released && $0.api && !$0.autoPrice && $0.apiPrice > Treasury.targetPrice($0, s) * 1.8 }) {
            add("price", .info, "tag.fill", "Some API prices are stale", "Turn on auto-pricing or match the market.", .models)
        }

        // The industry
        if let c = s.competitors.first(where: { !$0.acquired && $0.distressMonths > 0 }) {
            add("distress-\(c.id)", .info, "exclamationmark.triangle.fill", "\(c.def.name) is running out of money", "Its researchers and compute may soon be cheap.", .industry)
        }
        // Rival Watch: a launch that will likely beat your best model, within the month.
        let watchSet = Leaderboard.indexSet(s)
        if let r = RivalIntel.rows(s, set: watchSet).first(where: { $0.threat == .passYou && GameCalendar.daysBetween(s.date, $0.outlook.center) <= 30 }),
           let mine = RivalIntel.playerBest(s, set: watchSet) {
            add("watch-\(r.id)", .warning, "binoculars.fill", "\(r.project.name) is about to pass you",
                "\(r.lab), rumoured \(RivalIntel.windowText(r.outlook)) at ~\(Fmt.score(r.outlook.index)) vs your \(Fmt.score(mine.index)). Ship your next model first to steal the launch.", .rivalWatch)
        }
        if RivalEconomy.inCorrection(s) {
            add("correction", .info, "chart.line.downtrend.xyaxis", "The AI market is correcting", "Valuations are down, but GPUs and cloud capacity are cheaper.", .industry)
        }

        // Business
        let leads = s.deals.filter { !$0.active }.count
        if leads > 0 {
            add("leads", .info, "briefcase.fill", "\(leads) enterprise lead\(leads == 1 ? "" : "s")", "Review them before they expire.", .market)
        }

        // Swarms, alien tech, chips
        if let sw = s.swarms.filter({ !$0.paused }).min(by: { $0.alignmentMeasured < $1.alignmentMeasured }), sw.alignmentMeasured < 50 {
            add("swarm-align", .urgent, "shield.lefthalf.filled", "\(sw.name) alignment at \(Int(sw.alignmentMeasured))", "Raise oversight, audit or purge before it turns.", .swarms)
        }
        if let sw = s.swarms.first(where: { !$0.paused && $0.agents > 0 && $0.active < Double($0.agents) * 0.6 }) {
            add("swarm-chips", .info, "person.3.sequence.fill", "\(sw.name) is compute-bound", "Only \(Fmt.count(sw.active)) of \(Fmt.count(Double(sw.agents))) agents can run.", .swarms)
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
        if let l = s.chipLines.first(where: { $0.active && $0.demandToday > $0.capacityMonth / 30.4 * 1.5 && $0.pendingCapacity == 0 }) {
            add("fab-\(l.chipID)", .info, "shippingbox.fill", "Chip demand outstrips your foundry", "Buyers want \(Fmt.count(l.demandToday * 30.4))/month.", .chipSales)
        }

        // Security & policy
        let attract = SecurityOps.attractiveness(s)
        if attract >= 1.0 && s.security < .sl3 && s.securityTarget <= s.security.rawValue {
            add("security", .warning, "lock.shield.fill", "Your weights are a target at \(s.security.title)", "Near-frontier weights draw criminals and state hackers. Upgrade security.", .security)
        }
        let pending = s.bills.filter { $0.stance == 0 }
        if let b = pending.first, let bill = PolicyCatalog.byID[b.id] {
            add("bill-\(b.id)", .info, "building.columns.fill", "Vote coming on \(bill.title)", "Decide whether to lobby before \(b.vote.gameShort).", .security)
        }

        // People
        if s.employees.count >= Economy.officeCapacity(s) {
            add("office", .info, "building.2.fill", "Office is full", "Upgrade it to keep hiring.", .team)
        }
        return out.sorted { $0.level > $1.level }
    }
}
