import Foundation

/// 3.4: your standing with the people who decide how far a lab gets — the public (trust), researchers (respect),
/// developers (goodwill), investors (your board's confidence) and governments by region. Each drifts toward where your
/// record puts it (`target`) and jumps when you do something they notice; every jump is remembered with its date and
/// cause. They feed back gently and visibly: chat and API demand, candidates and morale, funding terms (through the
/// board), sovereign deal offers and how regulators treat you.
enum Stakeholders {
    /// Share of the gap to its target a standing closes each month (half-life about 11 months).
    static let drift = 0.06

    // MARK: Moving standings

    /// Move stakeholders and remember why. Keys: "public", "researchers", "developers", "investors" (your board's
    /// confidence) or a region's raw value. `shown` lists moves another system already made, recorded with the same cause.
    static func move(_ s: inout GameState, _ deltas: [String: Double], _ why: String, date: Date? = nil, shown: [String: Double] = [:]) {
        guard s.world.ready else { return }
        s.world.normalize()
        var applied = shown
        for (k, d) in deltas where abs(d) >= 0.05 {
            switch k {
            case "public": s.world.publicTrust = clamp(s.world.publicTrust + d, 0, 100)
            case "researchers": s.world.researchers = clamp(s.world.researchers + d, 0, 100)
            case "developers": s.world.developers = clamp(s.world.developers + d, 0, 100)
            case "investors": s.boardConfidence = clamp(s.boardConfidence + d, 0, 100)
            default:
                guard let r = Region(rawValue: k) else { continue }
                s.world.governments[r.index] = clamp(s.world.governments[r.index] + d, 0, 100)
            }
            applied[k, default: 0] += d
        }
        guard !applied.isEmpty else { return }
        s.world.notes.insert(WorldNote(date: date ?? s.date, text: why, deltas: applied), at: 0)
        if s.world.notes.count > 48 { s.world.notes.removeLast(s.world.notes.count - 48) }
    }

    /// The same move for every government.
    static func everyGovernment(_ v: Double) -> [String: Double] { Dictionary(uniqueKeysWithValues: Region.allCases.map { ($0.rawValue, v) }) }

    /// Notes behind a stakeholder's moves, newest first.
    static func notes(_ s: GameState, _ who: Stakeholder, region: Region? = nil) -> [WorldNote] {
        s.world.notes.filter { n in
            if let region { return n.deltas[region.rawValue] != nil }
            if who == .governments { return n.deltas.keys.contains { Region(rawValue: $0) != nil } }
            return n.deltas[who.rawValue] != nil
        }
    }

    // MARK: Where each standing is heading

    struct Part: Hashable {
        let label: String
        let value: Double
    }

    /// Where a stakeholder's view of you settles if nothing new happens, and what puts it there.
    static func target(_ s: GameState, _ who: Stakeholder) -> (value: Double, parts: [Part]) {
        var parts: [Part] = []
        func add(_ label: String, _ v: Double) { if abs(v) >= 0.5 { parts.append(Part(label: label, value: v)) } }
        switch who {
        case .publicTrust:
            add("Public mood toward AI", 0.3 * (s.world.sentiment - 50))
            add("Your safety record", 0.25 * (s.safetyScore - 50))
            add("Reliability", clamp((s.reliability - 0.95) * 60, -6, 2))
            add("Public-service programmes", AdvancedProjects.publicTrustBonus(s))   // disaster response, emissions data
            add("Blamed for AI job losses", -min(6, automationShare(s) * max(0, s.world.jobPressure - 0.5) * 4))
        case .researchers:
            add("Publication policy", s.publication == .open ? 8 : (s.publication == .secret ? -8 : 0))
            if let best = s.releasedModels.map(\.c).max() {
                add("Your best model vs the frontier", clamp((best - Macro.frontier(s.year) + 0.4) * 8, -8, 8))
            } else {
                add("No released model yet", -4)
            }
            let safety = Double(s.staff(.safety).count) / Double(max(1, s.employees.count))   // 3.8: not those seconded to programmes
            add("Safety team", min(4, safety * 40))
            let morale = s.employees.isEmpty ? 70 : s.employees.reduce(0) { $0 + $1.morale } / Double(s.employees.count)
            add("Staff morale", clamp((morale - 70) * 0.2, -5, 5))
            add("Open-source community", OpenSource.standing(s, .researchers))   // 3.9
        case .developers:
            let api = s.releasedModels.filter(\.api)
            if api.isEmpty {
                add("No public API yet", -5)
            } else {
                add("API prices vs the going rate", clamp((1 - priceRatio(s, api)) * 10, -8, 6))
            }
            let frontier = Macro.frontier(s.year)
            let open = s.releasedModels.filter { $0.openWeights && GameCalendar.daysBetween($0.releaseDate ?? $0.created, s.date) < 730 }
            if open.contains(where: { $0.c >= frontier - 0.6 }) { add("Open weights near the frontier", 7) } else if !open.isEmpty { add("Open weights", 4) }
            add("Reliability", clamp((s.reliability - 0.95) * 80, -8, 2))
            add("Open-source community", OpenSource.standing(s, .developers))   // 3.9
        case .investors:
            return (Board.confidenceTarget(s), [Part(label: "Growth, your models and runway (the board)", value: Board.confidenceTarget(s) - 50)])
        case .governments:
            let v = Region.allCases.map { governmentTarget(s, $0).value }.reduce(0, +) / Double(Region.allCases.count)
            return (v, [])
        }
        return (clamp(50 + parts.reduce(0) { $0 + $1.value }, 5, 95), parts)
    }

    static func governmentTarget(_ s: GameState, _ r: Region) -> (value: Double, parts: [Part]) {
        var parts: [Part] = []
        func add(_ label: String, _ v: Double) { if abs(v) >= 0.5 { parts.append(Part(label: label, value: v)) } }
        let (bias, capital, safety) = r.standing
        add(r == .china ? "A Western lab in Beijing's eyes" : "Starting point", bias)
        if capital > 0 { add("Political capital", capital * (s.politicalCapital - 20)) }
        let home = HQ.standingBonus(s, r)   // 3.5: headquarters
        if home != 0 { add(home > 0 ? "Your home government" : "A foreign lab in Washington's eyes", home) }
        add("Your safety record", 0.2 * safety * (s.safetyScore - 50))
        let sites = s.sites.filter { $0.kind != .garage && $0.isReady(s.date) && Region.of(location: $0.locationID) == r }.count
        if sites > 0 { add("Your datacenters there", min(6, 3 * Double(sites))) }
        if let until = s.world.ties[r.rawValue], until > s.date { add("Sovereign AI deal", 5) }
        add("Government programmes", AdvancedProjects.standingBonus(s, r))   // 3.5
        add("National partnerships", HQ.partnershipStanding(s, r))   // 3.4 overhaul: compute centres and chairs you fund
        return (clamp(50 + parts.reduce(0) { $0 + $1.value }, 5, 95), parts)
    }

    /// Your API prices against the going rate for each model's capability (demand-weighted; 1 = at the market).
    static func priceRatio(_ s: GameState, _ api: [AIModel]) -> Double {
        var num = 0.0, den = 0.0
        for m in api {
            let market = Treasury.marketPrice(m, s)
            guard market > 0 else { continue }
            let w = max(m.demandTokensDay, 1)
            num += w * m.apiPrice / market
            den += w
        }
        return den > 0 ? num / den : 1
    }

    /// Your share of the world's AI automation: agent seats sold, or agent labour, whichever is bigger (0–1).
    static func automationShare(_ s: GameState) -> Double {
        let seats = Macro.agentSeats(s.year)
        let labor = Swarms.laborMarket(s.year)
        return max(seats > 0 ? min(1, s.agentSeats / seats) : 0, labor > 0 ? min(1, s.laborToday * 365 / labor) : 0)
    }

    // MARK: Start

    /// Standing at a game's start (or when an older save loads): where your record puts it, nothing remembered yet.
    static func bootstrap(_ s: inout GameState) {
        s.world.normalize()
        s.world.publicTrust = target(s, .publicTrust).value
        s.world.researchers = target(s, .researchers).value
        s.world.developers = target(s, .developers).value
        for r in Region.allCases { s.world.governments[r.index] = governmentTarget(s, r).value }
        // What already happened doesn't count again.
        for m in s.models {
            if m.released { s.world.seen.insert("r|" + m.id.uuidString) }
            if m.openWeights { s.world.seen.insert("o|" + m.id.uuidString) }
            if m.tuned { s.world.seen.insert("t|" + m.id.uuidString) }
        }
        for o in s.objectives where o.done || o.failed { s.world.seen.insert("g|" + o.id.uuidString) }
        if s.achievements.contains("chat_moment") { s.world.seen.insert("chat") }
        s.world.seenReleased = s.models.filter(\.released).count
        s.world.seenOpen = s.models.filter(\.openWeights).count
        s.world.lastThefts = s.thefts
        s.world.lastStolen = stolenPrint(s)
        s.world.lastChatPrice = s.chatPrice
        s.world.lastFreeTier = s.freeTier
        s.world.published = s.publishedTech.count
        s.world.goalsMet = s.objectivesCompleted
        s.world.goalsMissed = s.objectivesFailed
        s.world.laws = s.lawsPassed.union(s.lawsFailed)
        for b in s.bills { s.world.stances[b.id] = b.stance }
        for m in s.releasedModels where m.api && !m.retired { s.world.apiPrices[m.id.uuidString] = m.apiPrice }
        for site in s.sites where site.kind != .garage && site.isReady(s.date) { s.world.sites.insert(site.id.uuidString) }
    }

    /// Changes when a state actor steals weights (they're recorded per lab).
    static func stolenPrint(_ s: GameState) -> Int {
        Int((s.stolenC.sorted { $0.key < $1.key }.reduce(0) { $0 + $1.value } * 100).rounded()) + s.stolenC.count * 100_000   // 3.7: fixed order
    }

    // MARK: The daily watch

    /// Notices what you did today that people react to. A cheap fingerprint keeps quiet days nearly free.
    static func daily(_ s: inout GameState) {
        var released = 0, open = 0
        for m in s.models {
            if m.released { released += 1 }
            if m.openWeights { open += 1 }
        }
        if released != s.world.seenReleased || open != s.world.seenOpen {
            s.world.seenReleased = released
            s.world.seenOpen = open
            scanModels(&s)
        }
        if s.thefts != s.world.lastThefts {
            s.world.lastThefts = s.thefts
            let print = stolenPrint(s)
            let byState = print != s.world.lastStolen
            s.world.lastStolen = print
            // The model the thieves went for (SecurityOps takes your best): above the High danger line a leak is a
            // major incident regulators answer; below it, it's a bad week.
            let dangerous = s.models.filter { !$0.retired }.max { $0.c < $1.c }.map { SafetyFramework.tier($0) >= .high } ?? false
            if byState {
                move(&s, ["public": -2, "us": 1, "china": -3], "State hackers stole your model weights", shown: ["investors": -10])
                World.shock(&s, concern: 1, "State hackers stole \(World.possessive(s.companyName)) model weights")
            } else {
                move(&s, ["public": -4, "researchers": -1, "developers": 1, "us": -2], "Your model weights leaked online", shown: ["investors": -10])
                World.shock(&s, concern: dangerous ? 3 : 2, "\(World.possessive(s.companyName)) model weights leaked online",
                            incident: dangerous ? "the leak of \(World.possessive(s.companyName)) weights" : nil)
            }
        }
        // Chat subscription price and free tier (once the app is live).
        if s.chatModelID != nil, s.world.lastChatPrice > 0 {
            let ratio = s.chatPrice / s.world.lastChatPrice
            if ratio >= 1.15 {
                move(&s, ["public": ratio >= 1.5 ? -3 : -2], "Raised the chat subscription to \(Fmt.money(s.chatPrice))/month")
                s.world.lastChatPrice = s.chatPrice
            } else if ratio <= 0.87 {
                move(&s, ["public": 1], "Cut the chat subscription to \(Fmt.money(s.chatPrice))/month")
                s.world.lastChatPrice = s.chatPrice
            }
        } else {
            s.world.lastChatPrice = s.chatPrice
        }
        if s.freeTier != s.world.lastFreeTier {
            s.world.lastFreeTier = s.freeTier
            if s.chatModelID != nil { move(&s, ["public": s.freeTier ? 2 : -3], s.freeTier ? "Brought back the free tier" : "Ended the free tier") }
        }
        // This month so far: reliability and SLA trouble.
        s.world.reliabilitySum += s.reliability
        s.world.reliabilityDays += 1
        for d in s.deals where d.active && d.breaches > s.world.breachMax { s.world.breachMax = d.breaches }
    }

    static func scanModels(_ s: inout GameState) {
        let frontier = Macro.frontier(s.year)
        for m in s.models {
            let id = m.id.uuidString
            if m.released && !s.world.seen.contains("r|" + id) {
                s.world.seen.insert("r|" + id)
                launched(&s, m, frontier: frontier)
            }
            if m.openWeights && !s.world.seen.contains("o|" + id) {
                s.world.seen.insert("o|" + id)
                openedWeights(&s, m, frontier: frontier)
            }
        }
    }

    /// A release people notice: one at the frontier, or a big step past your last.
    static func launched(_ s: inout GameState, _ m: AIModel, frontier: Double) {
        let date = m.releaseDate ?? s.date
        let previous = s.models.filter { $0.released && $0.id != m.id && ($0.releaseDate ?? .distantPast) <= date }.map(\.index).max()
        let atFrontier = m.c >= frontier - 0.15
        let leap = previous.map { m.index - $0 >= 3 } ?? true
        if m.unsafeRelease {
            move(&s, ["public": -5, "researchers": -4, "investors": -2, "us": -3, "eu": -5, "uk": -4, "jk": -2],
                 "Shipped \(m.name) without the safeguards its capability needs", date: date)
            World.shock(&s, concern: 4, "\(s.companyName) shipped \(m.name) without adequate safeguards", incident: "the unsafe release of \(m.name)", date: date)
        } else if atFrontier || leap {
            var d: [String: Double] = ["public": atFrontier ? 1.5 : 0.75, "researchers": atFrontier ? 1.5 : 0.75]
            if m.api { d["developers"] = 1 }
            if m.safeguards { d["eu"] = 1; d["uk"] = 1 }
            move(&s, d, "Launched \(m.name)\(atFrontier ? " at the frontier" : "") (index \(Fmt.score(m.index)))", date: date)
        }
    }

    /// Weights published. Developers and researchers love it; national-security hawks don't, and above the High danger
    /// line neither does anyone worried about misuse.
    static func openedWeights(_ s: inout GameState, _ m: AIModel, frontier: Double) {
        let better = s.models.filter { $0.openWeights && $0.id != m.id && s.world.seen.contains("o|" + $0.id.uuidString) }.map(\.c).max()
        if let b = better, m.c <= b { return }
        let near = m.c >= frontier - 0.5
        let tier = SafetyFramework.tier(m)
        var d: [String: Double] = near ? ["developers": 6, "researchers": 4, "public": 1, "us": -2, "china": 1] : ["developers": 2, "researchers": 1]
        if tier >= .high {
            d["eu", default: 0] -= 2
            d["uk", default: 0] -= 2
            d["us", default: 0] -= 1
        }
        move(&s, d, "Released \(World.possessive(m.name)) weights\(near ? ", close to the frontier" : "")")
        if tier >= .high {
            World.shock(&s, concern: tier == .critical ? 5 : 3, "\(s.companyName) open-sourced \(m.name), a model above the High danger line",
                        incident: "the open release of \(m.name)")
        }
    }

    // MARK: Hooks

    /// After a decision is answered (`GameState.resolveDecision`): how people read your answer.
    static func decided(_ s: inout GameState, _ d: Decision, option: Int) {
        guard s.world.ready else { return }
        if d.kind.hasPrefix("world_") { Consequences.resolve(&s, d, option: option); return }
        let headline = s.news.first?.title ?? ""
        let me = s.companyName
        switch (d.kind, option) {
        case ("jailbreak", 0):
            move(&s, ["public": -2, "researchers": 1], "A jailbreak of your model went viral; you pulled and patched it")
            World.shock(&s, concern: 2, "A jailbreak of a \(me) model went viral")
        case ("jailbreak", _):
            move(&s, ["public": -5, "eu": -3, "uk": -2], "A jailbreak of your model went viral and you answered with a statement")
            World.shock(&s, concern: 3, "A jailbreak of a \(me) model went viral", incident: "the \(me) jailbreak")
        case ("eval_escape", 0):
            move(&s, ["researchers": 3, "public": -2, "us": 2, "eu": 2, "uk": 3], "Disclosed a sandbox escape in full")
            World.shock(&s, concern: 3, "A \(me) model escaped an evaluation sandbox", incident: "\(World.possessive(me)) sandbox escape")
        case ("eval_escape", _):
            if headline.hasPrefix("Cover-up") {
                var dd = everyGovernment(-5)
                dd["public"] = -8
                dd["researchers"] = -5
                move(&s, dd, "Caught covering up a sandbox escape", shown: ["investors": -10])
                World.shock(&s, concern: 6, "\(me) hid a sandbox escape", incident: "\(World.possessive(me)) hidden sandbox escape")
            }
        case ("swarm_escape", 0):
            var dd = everyGovernment(-3)
            dd["public"] = -4
            dd["investors"] = -3
            move(&s, dd, "Pulled the kill switch on a runaway agent swarm")
            World.shock(&s, concern: 8, mood: -2, "A \(me) agent swarm tried to copy itself onto outside clouds", incident: "the runaway \(me) swarm")
        case ("swarm_escape", _):
            if s.gameOver == nil {
                move(&s, ["public": -2], "Rumours of a runaway swarm at \(me)")
                World.shock(&s, concern: 4, "Rumours of a runaway agent swarm at \(me)")
            }
        case ("rsi_exfil", 0):
            var dd = everyGovernment(-2)
            dd["public"] = -3
            dd["investors"] = -3
            move(&s, dd, "Halted a self-improving model that tried to copy its weights")
            World.shock(&s, concern: 6, "A self-improving \(me) model tried to copy its own weights", incident: "\(World.possessive(me)) self-copying model")
        case ("rsi_exfil", _):
            if s.gameOver == nil { World.shock(&s, concern: 3, "Leaks about a self-improving model at \(me)") }
        case ("policy_bill", 0), ("policy_bill", 1):
            tookSide(&s, d.ref, stance: option == 0 ? 1 : -1, was: 0)
        case ("sovereign_deal", 0):
            let r = region(of: d, s)
            if let r { s.world.ties[r.rawValue] = GameCalendar.addMonths(s.date, 36) }
            var dd: [String: Double] = ["public": -1, "investors": 1]
            var place = ""
            if let r {
                dd[r.rawValue] = 6
                place = " (\(r.title))"
            }
            move(&s, dd, "Signed a sovereign AI deal" + place)
        case ("sovereign_deal", _):
            if let r = region(of: d, s) { move(&s, [r.rawValue: -1], "Turned down a sovereign AI deal") }
        case ("defense", 0):
            move(&s, ["us": 5, "china": -4, "researchers": -3, "public": -2, "investors": 1], "Took a defense contract")
        case ("defense", _):
            move(&s, ["researchers": 1, "us": -1], "Turned down a defense contract")
        case ("distill_campaign", 0):
            move(&s, ["us": 3, "china": -3, "developers": 1], "Exposed a distillation campaign against your API")
        case ("distill_campaign", 1):
            if headline.hasPrefix("You were caught") { move(&s, ["developers": -5, "public": -2], "Caught serving poisoned answers through your API") }
        case ("lawsuit", _):
            if headline.hasPrefix("You lost the copyright") { move(&s, ["public": -2, "researchers": -1], "Lost a copyright case over pirated books") }
        case ("trade_secret", _):
            if headline.hasPrefix("You lost the trade-secret") { move(&s, ["researchers": -1], "Lost a trade-secret case") }
        case ("insider_caught", 0):
            move(&s, ["us": 1], "Locked down after an insider was caught")
        case ("swarm_audit", 0):
            var dd = everyGovernment(2)
            dd["public"] = 1
            dd["researchers"] = 1
            move(&s, dd, "Opened your agent swarms to government auditors")
        case ("swarm_audit", _):
            var dd = everyGovernment(-4)
            dd["public"] = -2
            move(&s, dd, "Refused a government audit of your agent swarms")
        case ("talent_raid", 1):
            move(&s, ["researchers": -2], "Lost three top researchers to a rival's raid")
        case ("spinoff", 2):
            move(&s, ["researchers": 1], "A star researcher left with your blessing to found a lab")
        default:
            break
        }
    }

    /// Which region a sovereign deal is with.
    static func region(of d: Decision, _ s: GameState) -> Region? {
        if d.ref.hasPrefix("world|"), let r = Region(rawValue: String(d.ref.dropFirst(6))) { return r }
        let t = d.title.lowercased()
        if t.contains("gulf") { return .gulf }
        if t.contains("european") || t.contains("nordic") { return .eu }
        if t.contains("asian") { return World.roll(s, d.id.uuidString) < 0.5 ? .india : .japanKorea }
        return nil
    }

    /// You took (or changed) a side on a bill — from the decision or the Security & Policy page.
    static func tookSide(_ s: inout GameState, _ id: String, stance: Int, was: Int) {
        guard s.world.ready, let bill = PolicyCatalog.byID[id] else { return }
        if s.bills.contains(where: { $0.id == id }) { s.world.stances[id] = stance }
        guard stance != was else { return }
        let side = Double(stance - was)
        var d: [String: Double] = ["public": 1.5 * bill.popularity * side]
        if bill.safetyBill {
            d["eu"] = 1.5 * side
            d["uk"] = 1.5 * side
            d["researchers"] = side
        }
        switch id {
        case "chip_security":
            d["us"] = 2 * side
            d["china"] = -3 * side
        case "preemption":
            d["us"] = side
            d["eu", default: 0] -= side
        case "nairr":
            d["researchers", default: 0] += 1.5 * side
        case "robot_tax":
            d["public", default: 0] += side
            d["investors"] = -side
        default:
            break
        }
        let verb = stance > 0 ? "Backed" : (stance < 0 ? "Opposed" : "Stepped back from")
        move(&s, d, "\(verb) the \(bill.title)")
    }

    /// Someone was let go (`GameState.fire`). One firing is not news; a layoff — at least 3 people and 5% of staff in a
    /// month — is.
    static func letGo(_ s: inout GameState, _ e: Employee) {
        guard s.world.ready else { return }
        s.world.letGo += 1
        if e.role == .researcher { s.world.letGoResearchers += 1 }
        let staff = s.employees.count + s.world.letGo
        guard !s.world.layoffNoted, s.world.letGo >= max(3, Int((Double(staff) * 0.05).rounded(.up))) else { return }
        s.world.layoffNoted = true
        move(&s, ["public": -2, "researchers": s.world.letGoResearchers > 0 ? -4 : -2, "investors": 1],
             "Laid off \(s.world.letGo) people this month")
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        s.world.normalize()
        observe(&s)
        let pub = target(s, .publicTrust).value, res = target(s, .researchers).value, dev = target(s, .developers).value
        s.world.publicTrust += (pub - s.world.publicTrust) * drift
        s.world.researchers += (res - s.world.researchers) * drift
        s.world.developers += (dev - s.world.developers) * drift
        for r in Region.allCases {
            let t = governmentTarget(s, r).value
            s.world.governments[r.index] += (t - s.world.governments[r.index]) * drift
        }
        effects(&s)
        s.world.letGo = 0
        s.world.letGoResearchers = 0
        s.world.layoffNoted = false
        s.world.reliabilitySum = 0
        s.world.reliabilityDays = 0
        s.world.breachMax = 0
        s.world.lastChatPrice = s.chatPrice
        let today = s.date
        s.world.ties = s.world.ties.filter { $0.value > today }
    }

    /// What changed over the month that people noticed.
    static func observe(_ s: inout GameState) {
        // Bills that went to a vote: did your side win?
        let decided = s.lawsPassed.union(s.lawsFailed)
        for id in decided.subtracting(s.world.laws).sorted() {
            s.world.laws.insert(id)
            let stance = s.world.stances[id] ?? 0
            s.world.stances[id] = nil
            guard stance != 0, let bill = PolicyCatalog.byID[id] else { continue }
            let passed = s.lawsPassed.contains(id)
            let won = (stance > 0) == passed
            move(&s, ["us": won ? 2 : -1], "The \(bill.title) \(passed ? "passed" : "failed"); your side \(won ? "won" : "lost")")
        }
        // Lobbying wins political capital (and through it the US government); heavy lobbying costs a little public trust.
        if s.lobbyBudget >= 1e6 && GameCalendar.components(s.date).month % 3 == 1 {
            move(&s, ["public": -0.5], "Lobbying in Washington: \(Fmt.money(s.lobbyBudget)) a month")
        }
        // Breakthroughs you published.
        let published = s.publishedTech.count
        if published > s.world.published {
            let n = published - s.world.published
            move(&s, ["researchers": 2 * Double(min(2, n)), "developers": 1], "Published \(n == 1 ? "one of your breakthroughs" : "\(n) of your breakthroughs")")
        }
        s.world.published = published
        // Benchmark contamination found.
        var tuned: Set<String> = []
        for m in s.models where m.tuned { tuned.insert("t|" + m.id.uuidString) }
        for key in s.world.seen.filter({ $0.hasPrefix("t|") && !tuned.contains($0) }).sorted() {
            s.world.seen.remove(key)
            if let m = s.models.first(where: { "t|" + $0.id.uuidString == key }), m.released {
                move(&s, ["researchers": -6, "developers": -3, "public": -2], "Test questions found in \(World.possessive(m.name)) training data")
            }
        }
        s.world.seen.formUnion(tuned)
        // The board's own verdicts (it moved its confidence itself).
        for o in s.objectives where (o.done || o.failed) && !s.world.seen.contains("g|" + o.id.uuidString) {
            s.world.seen.insert("g|" + o.id.uuidString)
            move(&s, [:], o.done ? "Met a board goal: \(o.title)" : "Missed a board goal: \(o.title)", shown: ["investors": o.done ? o.rewardConfidence : -10])
        }
        // API prices you set by hand: a cut developers notice, or a hike they resent (demand-weighted over models live
        // both months). Auto-priced models follow the market; how their prices sit against it is part of the target.
        var num = 0.0, den = 0.0
        var prices: [String: Double] = [:]
        for m in s.models where m.released && !m.retired && m.api {
            let id = m.id.uuidString
            prices[id] = m.apiPrice
            if !m.autoPrice, let old = s.world.apiPrices[id], old > 0, m.apiPrice > 0 {
                let w = max(m.demandTokensDay, 1)
                num += w * log(m.apiPrice / old)
                den += w
            }
        }
        s.world.apiPrices = prices
        if den > 0 {
            let change = exp(num / den) - 1
            if change <= -0.1 {
                move(&s, ["developers": change <= -0.25 ? 3 : 2], "Cut API prices by \(Fmt.pct(-change, decimals: 0))")
            } else if change >= 0.1 {
                move(&s, ["developers": change >= 0.25 ? -5 : -3], "Raised API prices by \(Fmt.pct(change, decimals: 0))")
            }
        }
        // Outages and turned-away users: news when service gets worse (lasting trouble is in the target).
        if s.world.reliabilityDays > 0 && !s.releasedModels.isEmpty {
            let avg = s.world.reliabilitySum / Double(s.world.reliabilityDays)
            let before = s.world.lastReliability > 0 ? s.world.lastReliability : 1
            if avg < 0.9 && (before >= 0.9 || avg < before - 0.08) {
                move(&s, ["developers": avg < 0.8 ? -3 : -2, "public": avg < 0.8 ? -2 : -1],
                     "Reliability fell to \(Fmt.pct(avg, decimals: 0)) last month: outages and turned-away users")
            }
            s.world.lastReliability = avg
        }
        let breachNoted = s.world.lastBreachNote.map { GameCalendar.daysBetween($0, s.date) < 90 } ?? false
        let walkoutNoted = s.world.lastBreachNote.map { GameCalendar.daysBetween($0, s.date) < 60 } ?? false
        if s.world.breachMax > 6 && !walkoutNoted {
            move(&s, ["developers": -2, "investors": -1], "An enterprise client walked out over SLA breaches")
            s.world.lastBreachNote = s.date
        } else if s.world.breachMax >= 3 && !breachNoted {
            move(&s, ["developers": -1], "Enterprise contracts breached their SLAs")
            s.world.lastBreachNote = s.date
        }
        // Taking the top spot.
        if s.history.count >= 2, s.history[s.history.count - 1].rank == 1, s.history[s.history.count - 2].rank > 1 {
            move(&s, ["public": 1, "researchers": 2], "Took the #1 spot on the leaderboard")
        }
        // Starting the consumer AI boom yourself.
        if s.achievements.contains("chat_moment") && !s.world.seen.contains("chat") {
            s.world.seen.insert("chat")
            move(&s, ["public": 4, "developers": 2], "Your chat app set off the consumer AI boom")
            World.shock(&s, mood: 6, "\(s.companyName) Chat set off the consumer AI boom")
        }
        // New datacenters: jobs and investment where they're built.
        for site in s.sites where site.kind != .garage && site.isReady(s.date) && !s.world.sites.contains(site.id.uuidString) {
            s.world.sites.insert(site.id.uuidString)
            if let r = Region.of(location: site.locationID) {
                move(&s, [r.rawValue: 2], "Opened \(site.name) in \(site.location.name)")
            }
        }
    }

    /// The monthly feedback from researchers' respect, and the robot tax if it passed.
    static func effects(_ s: inout GameState) {
        // New candidates are a little stronger (or weaker) when researchers rate the lab (or don't).
        let pull = hiringPull(s)
        if abs(pull) >= 0.5 {
            let fresh = GameCalendar.addDays(s.date, 45)
            for i in s.candidates.indices where s.candidates[i].expires == fresh {
                let old = s.candidates[i].skill
                let new = clamp((old + pull).rounded(), 15, 99)
                guard new != old else { continue }
                s.candidates[i].salary = (s.candidates[i].salary * pow(new / max(old, 1), 1.6) / 1000).rounded() * 1000
                s.candidates[i].skill = new
            }
        }
        // Researchers and safety staff are a little prouder (or more restless) to work here.
        let nudge = moraleNudge(s)
        if abs(nudge) >= 0.05 {
            for i in s.employees.indices where s.employees[i].role == .researcher || s.employees[i].role == .safety {
                s.employees[i].morale = clamp(s.employees[i].morale + nudge, 0, 100)
            }
        }
        // The Automation Dividend Act: 4% of what agents earn you.
        if s.lawsPassed.contains("robot_tax") {
            let levy = 0.04 * (s.month.revAgents + s.month.revLabor)
            if levy > 0 {
                s.cash -= levy
                s.month.costOther += levy
            }
        }
    }

    // MARK: Effects

    enum Segment { case api, consumer, agents }

    /// The one market demand factor from your standing: public trust pulls chat users, developer goodwill pulls API
    /// customers (and, half as much, agent seats). 1 at a neutral 50; ±6% at the extremes. Applied in `Market.snapshot`.
    static func demandFactor(_ s: GameState, _ segment: Segment) -> Double {
        guard s.world.ready else { return 1 }
        switch segment {
        case .consumer: return 1 + 0.06 * clamp((s.world.publicTrust - 50) / 40, -1, 1)
        case .api: return 1 + 0.06 * clamp((s.world.developers - 50) / 40, -1, 1)
        case .agents: return 1 + 0.03 * clamp((s.world.developers - 50) / 40, -1, 1)
        }
    }

    /// Sovereign AI offers come more (or less) often with your standing in the regions that buy them: 0.5–1.5×.
    static func sovereignFactor(_ s: GameState) -> Double {
        guard s.world.ready else { return 1 }
        let buyers: [Region] = [.eu, .uk, .gulf, .india, .japanKorea]
        let avg = buyers.map { s.world.government($0) }.reduce(0, +) / Double(buyers.count)
        return clamp(0.4 + 1.2 * avg / 100, 0.5, 1.5)
    }

    /// Skill points new candidates gain (or lose) from how researchers see you: ±3.
    static func hiringPull(_ s: GameState) -> Double { s.world.ready ? 3 * clamp((s.world.researchers - 50) / 35, -1, 1) : 0 }

    /// Morale researchers and safety staff gain (or lose) each month from it: ±0.3.
    static func moraleNudge(_ s: GameState) -> Double { s.world.ready ? 0.3 * clamp((s.world.researchers - 50) / 25, -1, 1) : 0 }

    /// What a standing does for (or to) you right now, in a few words.
    static func effect(_ s: GameState, _ who: Stakeholder) -> String {
        func pct(_ f: Double) -> String { "\(f >= 1 ? "+" : "−")\(Fmt.trim(abs(f - 1) * 100, 1))%" }
        switch who {
        case .publicTrust: return "Chat app demand \(pct(demandFactor(s, .consumer)))"
        case .developers: return "API demand \(pct(demandFactor(s, .api))), agent seats \(pct(demandFactor(s, .agents)))"
        case .researchers:
            let p = hiringPull(s)
            return "New candidates \(p >= 0 ? "+" : "−")\(Fmt.trim(abs(p), 1)) skill, researcher morale \(moraleNudge(s) >= 0 ? "+" : "−")\(Fmt.trim(abs(moraleNudge(s)), 2))/month"
        case .investors: return "Funding rounds priced \(pct(Board.valuationFactor(s)))"
        case .governments: return "Sovereign deal offers ×\(Fmt.trim(sovereignFactor(s), 2)); low standing draws regulators' attention"
        }
    }

    /// A stakeholder's standing now (investors: board confidence; governments: the average).
    static func value(_ s: GameState, _ who: Stakeholder) -> Double {
        switch who {
        case .publicTrust: s.world.publicTrust
        case .researchers: s.world.researchers
        case .developers: s.world.developers
        case .investors: s.boardConfidence
        case .governments: s.world.governmentAverage
        }
    }
}
