import Foundation

/// Rival labs as strategists. Every few months each lab reads its own situation — how far behind the leader it is,
/// whether it's losing share, how long its cash lasts, whether you're pulling ahead — weighs it against its
/// character, and picks a play: race, price war, enterprise push, open-weights gambit, talent raid, lobbying,
/// efficiency drive, consumer blitz, agent push or a hyperscaler alliance. Plays change what they do to the market
/// and to you, and every choice comes with its reason.
/// Before October 2026 plays only touch the market (prices, brand, products, people); a lab's capability and
/// funding stay on their historical track.
enum RivalStrategy {
    /// Strategy starts to matter once there's a market to fight over.
    static let start = 2022.85

    /// How naturally each play comes to each lab (0–1).
    static func personality(_ id: String) -> [RivalPlay: Double] {
        switch id {
        case "prometheus":
            [.race: 0.9, .consumer: 0.9, .agents: 0.7, .enterprise: 0.5, .priceWar: 0.4, .talentRaid: 0.5, .lobby: 0.6, .openGambit: 0.3, .efficiency: 0.2, .alliance: 0.6]
        case "deepgrove":
            [.race: 0.8, .consumer: 0.6, .enterprise: 0.6, .priceWar: 0.7, .agents: 0.5, .lobby: 0.4, .openGambit: 0.4, .talentRaid: 0.5, .efficiency: 0.3, .alliance: 0]
        case "halcyon":
            [.enterprise: 0.9, .agents: 0.9, .race: 0.6, .lobby: 0.7, .consumer: 0.3, .priceWar: 0.1, .openGambit: 0, .talentRaid: 0.3, .efficiency: 0.3, .alliance: 0.6]
        case "xenon":
            [.race: 1.0, .consumer: 0.7, .talentRaid: 0.8, .priceWar: 0.4, .openGambit: 0.5, .lobby: 0.3, .enterprise: 0.2, .agents: 0.4, .efficiency: 0.1, .alliance: 0.4]
        case "openweights":
            [.openGambit: 1.0, .talentRaid: 0.9, .race: 0.6, .consumer: 0.6, .priceWar: 0.3, .enterprise: 0.2, .agents: 0.3, .lobby: 0.4, .efficiency: 0.2, .alliance: 0]
        case "dragonlake":
            [.efficiency: 0.9, .priceWar: 0.9, .openGambit: 0.9, .race: 0.4, .enterprise: 0.2, .consumer: 0.3, .agents: 0.4, .talentRaid: 0.1, .lobby: 0, .alliance: 0.3]
        case "sirocco":
            [.enterprise: 0.8, .lobby: 0.6, .efficiency: 0.6, .openGambit: 0.6, .priceWar: 0.4, .race: 0.3, .consumer: 0.4, .agents: 0.4, .talentRaid: 0.1, .alliance: 0.7]
        case "aletheia":
            [.race: 1.0, .talentRaid: 0.7, .efficiency: 0.3, .lobby: 0.2, .enterprise: 0, .consumer: 0, .agents: 0.1, .priceWar: 0, .openGambit: 0, .alliance: 0.5]
        default:
            [:]
        }
    }

    /// Bills each lab's lobbyists push.
    static func favouredBills(_ id: String) -> [String] {
        switch id {
        case "prometheus": ["preemption", "compute_licensing", "permitting"]
        case "deepgrove": ["preemption", "permitting"]
        case "halcyon": ["transparency", "independent_auditors", "chip_security"]
        case "xenon": ["preemption", "permitting"]
        case "openweights": ["preemption", "nairr"]
        case "sirocco": ["nairr", "transparency"]
        case "aletheia": ["independent_auditors", "kill_switch"]
        default: []
        }
    }

    static func play(_ c: CompetitorState) -> RivalPlay? { RivalPlay(rawValue: c.play) }

    static func isActive(_ c: CompetitorState, _ s: GameState) -> Bool {
        !c.acquired && !c.bankrupt && c.exitNote.isEmpty && s.year >= c.def.founded.decimal && !c.models.isEmpty
    }

    // MARK: Reading the situation

    struct Situation {
        var myC: Double
        var leaderC: Double
        var leaderIsPlayer: Bool
        var leaderClosed: Bool
        var isLeader: Bool
        var rank: Int
        /// How far behind the leader, in months of frontier progress.
        var monthsBehind: Double
        /// How far your best released model leads the best rival model (log10 compute; negative = behind).
        var playerLead: Double
        var share: Double
        /// Change in API share over about six months.
        var shareTrend: Double
        var playerAPIShare: Double
        var runway: Double?
        var parentFunded: Bool
        var distressed: Bool
        var correction: Bool
        var hype: Double
        var playerResearchers: Int
    }

    /// Frontier progress per month right now (log10 effective compute).
    static func frontierPerMonth(_ y: Double) -> Double {
        max(0.01, (Macro.frontier(y + 0.5) - Macro.frontier(y - 0.5)) / 12)
    }

    static func situation(_ s: GameState, _ i: Int, playerAPIShare: Double) -> Situation {
        let c = s.competitors[i]
        let myC = c.latest?.c ?? -10
        let rivals = s.competitors.filter { isActive($0, s) }.compactMap { r in r.latest.map { (r.id, $0.c, $0.open) } }
        let bestRival = rivals.max { $0.1 < $1.1 }
        let playerBest = s.models.filter { $0.released && !$0.retired }.map(\.c).max() ?? -10
        let leaderIsPlayer = playerBest > (bestRival?.1 ?? -10)
        let leaderC = max(playerBest, bestRival?.1 ?? -10)
        let rank = rivals.filter { $0.1 > myC }.count + (playerBest > myC ? 1 : 0) + 1
        let hist = c.shareHistory
        let then = hist.count >= 6 ? hist[hist.count - 6] : (hist.first ?? c.apiShare)
        return Situation(
            myC: myC, leaderC: leaderC, leaderIsPlayer: leaderIsPlayer,
            leaderClosed: leaderIsPlayer ? !s.models.contains { $0.released && $0.openWeights && $0.c >= playerBest - 0.01 } : !(bestRival?.2 ?? false),
            isLeader: rank == 1, rank: rank,
            monthsBehind: max(0, leaderC - myC) / frontierPerMonth(s.year),
            playerLead: playerBest - (bestRival?.1 ?? -10),
            share: c.apiShare, shareTrend: c.apiShare - then, playerAPIShare: playerAPIShare,
            // Before October 2026 the real labs found the money they needed; a parent pays for its division.
            runway: s.year < RivalHistory.end || RivalEconomy.parent(c, s) != nil ? nil : RivalEconomy.runwayMonths(c),
            parentFunded: RivalEconomy.parent(c, s) != nil,
            distressed: c.distressMonths > 0, correction: RivalEconomy.inCorrection(s), hype: s.market.hype,
            playerResearchers: s.employees.filter { $0.role == .researcher }.count)
    }

    struct Option {
        var play: RivalPlay
        var score: Double
        var reason: String
    }

    /// Every play the lab could run, scored, each with the reason it would give.
    static func options(_ s: GameState, _ i: Int, _ x: Situation) -> [Option] {
        let c = s.competitors[i]
        let p = personality(c.id)
        let y = s.year
        let live = y >= RivalHistory.end
        let behind = Int(x.monthsBehind.rounded())
        let short = x.runway.map { $0 < 12 } ?? false
        let lastOpen = c.openModels.last?.date
        var out: [Option] = []
        func add(_ play: RivalPlay, _ score: Double, _ reason: String) {
            out.append(Option(play: play, score: score + (p[play] ?? 0) * 0.6, reason: reason))
        }

        // Race: close enough to catch the leader, with the money to try.
        var race = 0.3 + (x.monthsBehind > 1 && x.monthsBehind < 10 ? 0.45 : 0) + (x.hype > 1.3 ? 0.15 : 0)
        if short && !x.parentFunded { race -= 0.8 }
        if x.correction { race -= 0.35 }
        add(.race, race, x.isLeader ? "It leads and means to stay there." :
                (x.monthsBehind < 10 ? "About \(max(1, behind)) months behind the leader — close enough to catch up with a bigger run." : "Far behind, and betting a giant run closes the gap."))

        // Price war: losing share, or you are taking it.
        var price = 0.15 + (x.shareTrend < -0.02 ? 0.55 : 0) + (x.playerAPIShare > 0.1 ? 0.35 : 0)
        if short { price -= 0.5 }
        add(.priceWar, price, x.shareTrend < -0.02 ? "Its API share fell \(Fmt.trim(-x.shareTrend * 100, 1)) points in six months." :
                (x.playerAPIShare > 0.1 ? "Your API share hit \(Fmt.pct(x.playerAPIShare, decimals: 0)) — it wants it back." : "Buying share while the market grows."))

        // Enterprise: can't win on raw capability, so it sells service.
        add(.enterprise, 0.25 + (x.monthsBehind > 4 ? 0.3 : 0) + (y >= 2024 ? 0.1 : 0),
            x.monthsBehind > 4 ? "It can't win on raw capability, so it's selling reliability and support to big companies." : "Enterprise contracts are the steadiest money in AI.")

        // Open-weights gambit: far behind a closed leader — commoditise them. At most every 18 months.
        if lastOpen.map({ GameCalendar.daysBetween($0, s.date) > 540 }) ?? true, !x.isLeader {
            add(.openGambit, 0.05 + (x.monthsBehind > 6 ? 0.5 : 0) + (x.leaderClosed ? 0.2 : 0),
                x.leaderClosed ? "About \(behind) months behind a closed leader: giving away a strong model makes the leader's moat worth less." : "Open weights buy developers' loyalty.")
        }

        // Talent raid: you're ahead and it has money.
        if x.playerResearchers >= 4 && (c.raidCooldown ?? .distantPast) < s.date {
            add(.talentRaid, 0.05 + (x.playerLead > 0.05 ? 0.6 : 0) + (x.playerLead > 0.3 ? 0.5 : 0) + (c.cash > 5e9 || x.parentFunded ? 0.2 : 0) - (short ? 0.5 : 0),
                x.playerLead > 0.05 ? "You lead the world, and the fastest way to catch up is to hire your people." : "It's building out its research team.")
        }

        // Efficiency: short of money, or the market just turned.
        add(.efficiency, 0.05 + (short ? 1.0 : 0) + (x.distressed ? 1.0 : 0) + (x.correction ? 0.45 : 0),
            x.distressed ? "It's running out of money." : (short ? "\(Int(x.runway ?? 0)) months of runway left." : (x.correction ? "The market correction made money expensive." : "Squeezing more out of every GPU.")))

        // Consumer blitz.
        add(.consumer, 0.15 + (y < 2028 ? 0.15 : 0) + (c.consumerShare < 0.08 ? 0.1 : 0),
            "Chat apps are where the users are, and users are what investors count.")

        // Agent push.
        if y >= 2025 {
            add(.agents, 0.25 + (x.monthsBehind < 4 ? 0.15 : 0), "Agents are the fastest-growing market in AI.")
        }

        // Hyperscaler alliance: independent, needs money but still attractive. Every three years at most.
        if live && !x.parentFunded && (c.lastAlliance.map { GameCalendar.daysBetween($0, s.date) > 1_095 } ?? true) {
            add(.alliance, 0.05 + ((x.runway ?? 99) < 24 && (x.runway ?? 99) > 6 ? 0.45 : 0) + (x.monthsBehind > 3 ? 0.15 : 0),
                "Trading equity for a cloud giant's compute keeps it in the race.")
        }
        return out
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        let y = s.year
        let playerAPIShare = s.models.filter { $0.released && $0.api }.isEmpty ? 0
            : Market.snapshot(s).api.filter(\.isPlayer).reduce(0) { $0 + $1.share }
        for i in s.competitors.indices {
            guard isActive(s.competitors[i], s) else {
                if !s.competitors[i].play.isEmpty { s.competitors[i].play = "" }
                continue
            }
            s.competitors[i].shareHistory.append(s.competitors[i].apiShare)
            if s.competitors[i].shareHistory.count > 12 { s.competitors[i].shareHistory.removeFirst() }
            guard y >= start else { continue }
            let x = situation(s, i, playerAPIShare: playerAPIShare)
            let c = s.competitors[i]
            let current = play(c)
            // Running out of money forces a rethink; so does a crash in the middle of a race.
            let forced = (x.distressed && current != .efficiency) || (x.correction && current == .race)
            if forced || current == nil || (c.nextReview ?? .distantPast) <= s.date {
                review(&s, i, x)
            }
            effects(&s, i, x)
        }
    }

    /// Weigh every option and pick one. Labs stick with a play that's still nearly the best.
    static func review(_ s: inout GameState, _ i: Int, _ x: Situation) {
        let c = s.competitors[i]
        let month = s.date.ym.year * 12 + s.date.ym.month
        var opts = options(s, i, x)
        for k in opts.indices {
            opts[k].score += (RivalIntel.unit("\(c.id)|strategy|\(month)|\(opts[k].play.rawValue)") - 0.5) * 0.3
        }
        guard let best = opts.max(by: { $0.score < $1.score }) else { return }
        let current = play(c)
        let keep = current.flatMap { cur in opts.first { $0.play == cur } }.map { $0.score >= best.score - 0.12 } ?? false
        let months = 4 + Int(RivalIntel.unit("\(c.id)|review|\(month)") * 4)
        s.competitors[i].nextReview = GameCalendar.addMonths(s.date, months)
        // Lobbying runs alongside any play: top labs push the rules that suit them.
        let lobbyOdds = (personality(c.id)[.lobby] ?? 0) * (x.rank <= 3 ? 0.4 : 0.15) * (s.year >= 2023.5 ? 1 : 0)
        if lobbyOdds > 0 && RivalIntel.unit("\(c.id)|lobby|\(month)") < lobbyOdds && sponsorBill(&s, i) {
            let reason = x.rank <= 2 && !x.leaderIsPlayer ? "A challenger is closing in; rules that raise the cost of entry suit an incumbent." : "Shaping AI law before it's written."
            s.competitors[i].playLog.insert("\(s.date.gameMonth): \(RivalPlay.lobby.title) — \(reason)", at: 0)
            if s.competitors[i].playLog.count > 8 { s.competitors[i].playLog.removeLast() }
        }
        if keep, let cur = current {
            if let o = opts.first(where: { $0.play == cur }) { s.competitors[i].playReason = o.reason }
            return
        }
        begin(&s, i, best.play, reason: best.reason)
    }

    /// Switch to a new play: news, a rumour, and any one-off moves.
    static func begin(_ s: inout GameState, _ i: Int, _ play: RivalPlay, reason: String) {
        let def = s.competitors[i].def
        let name = def.name
        s.competitors[i].play = play.rawValue
        s.competitors[i].playSince = s.date
        s.competitors[i].playReason = reason
        s.competitors[i].playLog.insert("\(s.date.gameMonth): \(play.title) — \(reason)", at: 0)
        if s.competitors[i].playLog.count > 8 { s.competitors[i].playLog.removeLast() }
        let live = s.year >= RivalHistory.end
        switch play {
        case .openGambit:
            openRelease(&s, i)
        case .alliance where live:
            ally(&s, i)
        case .priceWar:
            Sim.news(&s, "\(name) starts a price war", "\(reason) It is cutting API prices sharply; expect token prices across the market to fall.",
                     .competitor, important: true, good: false)
            if s.models.contains(where: { $0.released && !$0.retired && $0.api }) {
                Alerts.raise(&s, .priceWar, key: def.id, title: "\(name) starts a price war",
                             body: "Its API prices fall up to 45%. Match on your most exposed model, hold and lean on quality, or move upmarket to enterprise.",
                             screen: .market, cooldown: 90)
            }
        case .race:
            Sim.news(&s, "\(name) goes all-in on its next model", "\(reason) It's committing far more compute to its next runs.", .competitor)
        case .talentRaid:
            RivalIntel.add(&s, def.id, s.competitors[i].releaseCount, kind: "strategy", reliability: .credible,
                           title: "\(name) recruiters are calling your team",
                           body: "\(reason) Expect offers to your best researchers.")
        case .efficiency:
            Sim.news(&s, "\(name) tightens its belt", "\(reason) It's cutting costs and raising prices.", .competitor)
        case .enterprise:
            Sim.news(&s, "\(name) launches an enterprise push", "\(reason) A bigger sales team and stronger service guarantees.", .competitor)
        case .consumer:
            Sim.news(&s, "\(name) pours money into \(def.chatProduct)", "\(reason) A marketing blitz for its chat app.", .competitor)
        case .agents:
            Sim.news(&s, "\(name) bets on agents", "\(reason) Its agent product gets the company's best people.", .competitor)
        default:
            break
        }
        if play != .talentRaid {
            let q = RivalIntel.quality(s)
            RivalIntel.add(&s, def.id, s.competitors[i].releaseCount, kind: "strategy", reliability: q > 0.45 ? .credible : .speculative,
                           title: "\(name): \(play.title.lowercased())", body: "\(reason) \(play.effect)")
        }
    }

    /// Ongoing effects of the current play.
    static func effects(_ s: inout GameState, _ i: Int, _ x: Situation) {
        guard let p = play(s.competitors[i]) else { return }
        let live = s.year >= RivalHistory.end
        let c = s.competitors[i]
        switch p {
        case .race:
            if live && !(x.runway.map { $0 < 9 } ?? false) {
                s.competitors[i].fundingFactor = min(1.8, c.funding * 1.05)
                if var proj = c.project, proj.procedural {
                    proj.cAdjust = min(0.06, proj.cAdjust + 0.012)
                    s.competitors[i].project = proj
                }
            }
        case .priceWar:
            s.competitors[i].priceCut = min(0.45, max(c.priceCut, 0.1) + 0.08)
            s.market.apiPricePressure = max(0.5, s.market.apiPricePressure - 0.01)
        case .efficiency:
            if live { s.competitors[i].fundingFactor = max(0.6, c.funding * 0.95) }
            s.competitors[i].priceCut = max(-0.15, c.priceCut - 0.04)
        case .consumer:
            s.competitors[i].brand = min(100, c.brand + 1.5)
        case .talentRaid:
            if s.decisions.count < 3, (c.raidCooldown ?? .distantPast) < s.date, !raidedRecently(s),
               RivalIntel.unit("\(c.id)|raid|\(s.date.ym.year * 12 + s.date.ym.month)") < 0.35 {
                raid(&s, i)
            }
        default:
            break
        }
    }

    // MARK: One-off moves

    /// Give away a strong open-weights model (or, for an open lab, its best model under a permissive licence).
    static func openRelease(_ s: inout GameState, _ i: Int) {
        let def = s.competitors[i].def
        guard let latest = s.competitors[i].latest else { return }
        s.market.apiPricePressure = max(0.5, s.market.apiPricePressure - 0.06)
        if def.openWeights {
            s.competitors[i].brand = min(100, s.competitors[i].brand + 3)
            Sim.news(&s, "\(def.name) frees \(latest.name) for any use", "\(s.competitors[i].playReason) A fully permissive licence and free hosted inference for developers. Token prices fall.",
                     .competitor, important: true, good: false)
            return
        }
        var m = CompetitorModel(name: "\(latest.name) Open", date: s.date, c: latest.c - 0.15, reasoning: latest.reasoning, scores: [:], index: 0,
                                price: max(0.01, (latest.price * 0.25 * 1000).rounded() / 1000), open: true, tps: latest.tps * 1.3,
                                paramsB: max(1, latest.paramsB * 0.5))
        m.index = BenchmarkCatalog.index(Leaderboard.profile(m, def: def, boost: Competitors.boost(s, def.id, at: s.year)), set: Leaderboard.indexSet(s))
        s.competitors[i].openModels.append(m)
        if s.competitors[i].openModels.count > 4 { s.competitors[i].openModels.removeFirst() }
        Sim.news(&s, "\(def.name) open-sources \(m.name)", "\(s.competitors[i].playReason) Anyone can now download a model only a step behind its flagship. Intelligence Index \(Fmt.score(m.index)). API prices across the industry come under pressure.",
                 .competitor, important: true, good: false)
    }

    /// Put one of the lab's favoured bills in front of Congress. Returns whether it did.
    @discardableResult
    static func sponsorBill(_ s: inout GameState, _ i: Int) -> Bool {
        let def = s.competitors[i].def
        let pending = Set(s.bills.map(\.id))
        let open = favouredBills(def.id).compactMap { PolicyCatalog.byID[$0] }.filter {
            s.year >= $0.earliest && !s.lawsPassed.contains($0.id) && !s.lawsFailed.contains($0.id) && !pending.contains($0.id)
        }
        guard s.bills.count < 3, s.decisions.count < 3, let bill = open.first else { return false }
        Policy.introduce(&s, bill, sponsor: def.name, boost: 0.15)
        return true
    }

    /// A compute-for-equity deal with a cloud giant.
    static func ally(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let amount = clamp(c.valuation * 0.08, 5e8, 5e10)
        let giant = ["a cloud giant", "a chip giant", "a sovereign cloud", "a hyperscaler"][Int(RivalIntel.unit("\(c.id)|ally|\(s.date.ym.year)") * 4) % 4]
        // New money dilutes anyone already holding a stake, you included.
        RivalEconomy.dilute(&s, i, amount: amount, post: 0)
        s.competitors[i].rounds.append(RivalRound(date: s.date, label: "Compute alliance", amount: amount, postMoney: 0, lead: giant, kind: .strategic))
        s.competitors[i].cash += amount
        s.competitors[i].totalRaised += amount
        s.competitors[i].fundingFactor = min(1.8, c.funding + 0.15)
        s.competitors[i].lastAlliance = s.date
        Sim.news(&s, "\(c.def.name) signs a \(Fmt.money(amount)) alliance with \(giant)", "\(c.playReason) Most of the money comes back as compute.",
                 .finance, image: "stock_exchange", important: true)
    }

    /// Whether any lab went after your team in the last nine months (raids are rare enough to matter).
    static func raidedRecently(_ s: GameState) -> Bool {
        let cutoff = GameCalendar.addMonths(s.date, 3)
        return s.competitors.contains { ($0.raidCooldown ?? .distantPast) > cutoff }
    }

    /// The lab goes after your three best researchers.
    static func raid(_ s: inout GameState, _ i: Int) {
        let rival = s.competitors[i]
        let researchers = s.employees.filter { $0.role == .researcher }.sorted { $0.skill > $1.skill }
        guard researchers.count >= 4 else { return }
        // A lab tries again a year later at the earliest; nobody raids within nine months of the last raid.
        s.competitors[i].raidCooldown = GameCalendar.addMonths(s.date, 12)
        let top = researchers.prefix(3)
        let bonus = top.reduce(0) { $0 + $1.salary } * 0.6
        Events.addDecision(&s, kind: "talent_raid", title: "\(rival.def.name) is raiding your research team",
                           body: "\(rival.playReason) \(top.map(\.name).joined(separator: ", ")) have offers with eight-figure packages.",
                           image: "sf_skyline",
                           options: [DecisionOption(label: "Retention bonuses (\(Fmt.money(bonus)))", detail: "They stay, morale up."),
                                     DecisionOption(label: "Let them go", detail: "Lose your three best researchers. \(rival.def.name)'s next model gets stronger.")],
                           amount: bonus, ref: rival.id)
    }

    // MARK: Hooks used by the market

    /// Whether the strategy (rather than your market share) sets this lab's prices.
    static func controlsPrice(_ c: CompetitorState) -> Bool { play(c) == .priceWar || play(c) == .efficiency }

    static func enterpriseBoost(_ c: CompetitorState) -> Double { play(c) == .enterprise ? 1.35 : 1 }

    static func agentBoost(_ c: CompetitorState) -> Double { play(c) == .agents ? 1.35 : 1 }

    /// Your enterprise leads dry up a little for every rival running an enterprise push (two at most count).
    static func playerDealFactor(_ s: GameState) -> Double {
        pow(0.85, Double(min(2, s.competitors.filter { isActive($0, s) && play($0) == .enterprise }.count)))
    }

    /// Release cadence: racing labs ship sooner, belt-tightening ones later (procedural releases only).
    static func cadence(_ c: CompetitorState) -> Double {
        switch play(c) {
        case .race: 0.9
        case .efficiency: 1.15
        default: 1
        }
    }
}
