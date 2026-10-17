import Foundation

/// Rival Watch: each lab's next frontier run, the rumour mill around it and your intel desk.
/// The truth (start, compute, release date, capability) is simulated; what you see is the rumour mill's
/// version of it, which sharpens as the release gets closer and as you spend on intel.
/// Rumours use hashed randomness, not the game's RNG, so watching rivals never changes the game itself.
enum RivalIntel {
    /// Monthly intel budgets offered on the Rival Watch screen.
    static let budgets: [Double] = [0, 1e6, 5e6, 2e7, 5e7]

    // MARK: Hashed randomness

    /// FNV-1a with a splitmix64 finaliser: keys that differ only in their last characters (consecutive days)
    /// still give independent rolls.
    static func unit(_ key: String) -> Double {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01b3
        }
        h ^= h >> 30
        h = h &* 0xbf58_476d_1ce4_e5b9
        h ^= h >> 27
        h = h &* 0x94d0_49bb_1331_11eb
        h ^= h >> 31
        return Double(h >> 11) / Double(UInt64(1) << 53)
    }

    static func gauss(_ key: String) -> Double {
        let u1 = max(1e-9, unit(key + "#a")), u2 = unit(key + "#b")
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    static func dayIndex(_ d: Date) -> Int { Int(d.timeIntervalSince1970 / 86_400) }

    // MARK: Intel quality

    /// How good your view of the rivals is (0–1): press coverage, paid intel and your own model reading the signals.
    static func quality(_ s: GameState) -> Double {
        var q = 0.12
        q += 0.5 * log10(1 + s.intelBudget / 2.5e5) / log10(1 + 5e7 / 2.5e5)
        q += osint(s)
        q += min(0.08, Double(s.acquiredLabs.count) * 0.03)
        // A competitive-intelligence swarm reading every filing and paper.
        q += 0.2 * s.swarmIntel
        return clamp(q, 0.05, 0.95)
    }

    /// Your best model reading job posts, papers, import records and power filings (up to +0.25).
    static func osint(_ s: GameState) -> Double {
        guard let m = s.models.filter({ $0.released && !$0.retired }).max(by: { Swarms.agenticX($0) < Swarms.agenticX($1) }) else { return 0 }
        return 0.25 * clamp(log10(1 + Swarms.quality(m) * 20) / log10(21), 0, 1)
    }

    /// The part of intel quality your budget buys.
    static func budgetPart(_ s: GameState) -> Double {
        0.5 * log10(1 + s.intelBudget / 2.5e5) / log10(1 + 5e7 / 2.5e5)
    }

    /// Half-width of the rumoured launch window 60 days before a release, at your current intel quality.
    static func windowDays60(_ s: GameState) -> Double { max(2, (5 + 0.3 * 60) * (1.15 - quality(s))) }

    static func qualityLabel(_ q: Double) -> String {
        switch q {
        case ..<0.25: "Press coverage"
        case ..<0.45: "Industry analysts"
        case ..<0.65: "Well-sourced"
        case ..<0.8: "Insider network"
        default: "Near-perfect"
        }
    }

    // MARK: Projects

    static func isActive(_ c: CompetitorState, _ s: GameState) -> Bool {
        !c.acquired && !c.bankrupt && c.exitNote.isEmpty && s.year >= c.def.founded.decimal
    }

    static let codenames = ["Kestrel", "Halberd", "Lodestone", "Nightjar", "Tamarisk", "Cobalt", "Heron", "Basilisk", "Quasar", "Juniper",
                            "Talon", "Obsidian", "Meridian", "Zephyr", "Sable", "Pinnacle", "Ember", "Glacier", "Monsoon", "Vesper",
                            "Argent", "Bramble", "Cinder", "Fathom", "Gossamer", "Harrow", "Ironwood", "Kraken", "Lantern", "Mirage",
                            "Nimbus", "Onyx", "Prism", "Quill", "Raptor", "Sextant", "Thistle", "Umbra", "Vortex", "Wren", "Yarrow", "Zenith"]

    static func sites(_ id: String) -> [String] {
        switch id {
        case "prometheus": ["its Abilene, Texas campus", "its Ohio gigawatt site", "a partner cloud in Wisconsin", "its New Mexico campus"]
        case "deepgrove": ["TPU pods in Council Bluffs", "a multi-datacentre TPU fabric", "TPU superpods in Oklahoma"]
        case "halcyon": ["a Trainium cluster in Indiana", "rented TPU capacity", "its own Texas campus"]
        case "xenon": ["the Behemoth supercluster in Memphis", "Behemoth II in Memphis", "a gas-turbine-powered site in Mississippi"]
        case "openweights": ["its Louisiana mega-campus", "its Ohio gigawatt cluster", "tents of GPUs next to its Texas datacentre"]
        case "dragonlake": ["its Hangzhou cluster", "domestic accelerators in Guizhou", "a rented cluster in Malaysia"]
        case "sirocco": ["its Paris-area datacentre", "a nuclear-powered campus in France", "rented capacity in the Nordics"]
        case "aletheia": ["rented TPU capacity", "a quiet cluster in Tel Aviv"]
        default: ["its main cluster"]
        }
    }

    /// Lay out the run behind a lab's next release.
    static func plan(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let def = c.def
        let count = c.releaseCount
        let release = c.nextRelease
        let key = "\(def.id)|\(count)"
        let total = clamp(def.cadenceMonths * 30.4 * 1.2, 110, 280)
        let started = GameCalendar.addDays(release, -Int(total))
        let preDays = total * 0.58
        let preEnd = GameCalendar.addDays(started, Int(preDays))
        let y = release.decimalYear
        // Pre-training compute implied by the capability they're aiming for (the game's c is calibrated to real FLOPs).
        let cTarget = Competitors.plannedC(s, compIndex: i, date: release)
        let flops = pow(10, cTarget + 21 - Competitors.algoGain(y))
        let perChip = 4e14 * 86_400 * preDays
        let chips = min(flops / perChip, max(1, c.computeH100e) * 0.7)
        let siteList = sites(def.id)
        s.competitors[i].project = RivalProject(
            name: Competitors.modelName(def, count: count),
            codename: codenames[Int(unit(key + "name") * Double(codenames.count)) % codenames.count],
            count: count, started: started, preEnd: preEnd, release: release,
            chips: max(8, chips), site: siteList[count % siteList.count], flops: flops,
            dateBias: gauss(key + "date") * 18, capBias: gauss(key + "cap") * 0.22,
            procedural: count >= def.releases.count && release.decimalYear >= RivalHistory.end)
    }

    static func phase(_ p: RivalProject, on d: Date) -> RivalPhase {
        if d < p.started { return .planning }
        if d < p.preEnd { return .pretraining }
        let left = GameCalendar.daysBetween(d, p.release)
        if left <= 10 { return .imminent }
        if left <= 40 { return .redteam }
        return .posttraining
    }

    /// Share of the way from the start of training to release (0–1).
    static func progress(_ p: RivalProject, on d: Date) -> Double {
        let total = Double(max(1, GameCalendar.daysBetween(p.started, p.release)))
        return clamp(Double(GameCalendar.daysBetween(p.started, d)) / total, 0, 1)
    }

    /// Share of pre-training done.
    static func preProgress(_ p: RivalProject, on d: Date) -> Double {
        let total = Double(max(1, GameCalendar.daysBetween(p.started, p.preEnd)))
        return clamp(Double(GameCalendar.daysBetween(p.started, d)) / total, 0, 1)
    }

    // MARK: Forecasts

    /// Intelligence Index of a lab's next model at capability `c` on today's benchmarks.
    static func index(_ s: GameState, _ i: Int, c: Double, on date: Date, set: [Benchmark]) -> Double {
        let comp = s.competitors[i]
        let def = comp.def
        let y = date.decimalYear
        let m = CompetitorModel(name: "", date: date, c: c, reasoning: y >= Competitors.reasoningStart(def.id), scores: [:], index: 0,
                                price: 0, open: def.openWeights, tps: 0, paramsB: 0)
        var p = Leaderboard.profile(m, def: def, boost: Competitors.boost(s, def.id, at: y))
        p.key = "watch|\(def.id)|\(comp.releaseCount)"
        // Scored directly, not through the shared score cache: forecasts must never change when it gets flushed.
        guard !set.isEmpty else { return 0 }
        return set.reduce(0) { $0 + $1.score(p) } / Double(set.count)
    }

    /// What the rumour mill says about a lab's next model today.
    static func outlook(_ s: GameState, _ i: Int, set: [Benchmark]? = nil) -> RivalOutlook? {
        let comp = s.competitors[i]
        guard let p = comp.project, isActive(comp, s) else { return nil }
        let set = set ?? Leaderboard.indexSet(s)
        let q = quality(s)
        let today = s.date
        let left = Double(max(0, GameCalendar.daysBetween(today, p.release)))
        let span = Double(max(30, GameCalendar.daysBetween(p.started, p.release)))
        let haze = clamp(left / span, 0, 1)
        let half = max(2, (5 + 0.3 * left) * (1.15 - q))
        var center = left + p.dateBias * (1 - q) * (0.25 + 0.75 * haze)
        center = max(center, min(left, 2))
        let low = GameCalendar.addDays(today, Int(max(0, center - half).rounded()))
        let high = GameCalendar.addDays(today, Int(max(center - half + 1, center + half).rounded()))
        let truth = Competitors.plannedC(s, compIndex: i, date: p.release)
        let mean = truth + p.capBias * (1 - q) * (0.3 + 0.7 * haze)
        let sd = 0.05 + 0.22 * (1 - q) * (0.3 + 0.7 * haze)
        var idx = index(s, i, c: mean, on: p.release, set: set)
        var lo = index(s, i, c: mean - 1.28 * sd, on: p.release, set: set)
        var hi = index(s, i, c: mean + 1.28 * sd, on: p.release, set: set)
        if let leak = p.evalLeak {
            let blended = (idx + leak) / 2
            lo = blended - (idx - lo) * 0.7
            hi = blended + (hi - idx) * 0.7
            idx = blended
        }
        return RivalOutlook(phase: phase(p, on: today), low: low, high: high, center: GameCalendar.addDays(today, Int(center.rounded())),
                            halfWidth: half, index: idx, indexLow: lo, indexHigh: hi, c: mean, sd: sd,
                            trainingKnown: p.leaked.contains("start") || q >= 0.5)
    }

    /// Your best released model on today's benchmarks.
    static func playerBest(_ s: GameState, set: [Benchmark]) -> (name: String, index: Double)? {
        s.models.filter { $0.released && !$0.retired }
            .map { ($0.name, BenchmarkCatalog.index(Leaderboard.profile($0), set: set)) }
            .max { $0.1 < $1.1 }
    }

    /// Your next model: a finished one waiting to ship, or the full run due soonest.
    static func playerNext(_ s: GameState) -> (name: String, date: Date, index: Double, low: Double, high: Double)? {
        if let ready = s.models.filter({ !$0.released && !$0.retired && !$0.preview }).max(by: { $0.index < $1.index }) {
            return (ready.name, s.date, ready.index, ready.index, ready.index)
        }
        var best: (name: String, date: Date, index: Double, low: Double, high: Double)?
        for run in s.runs where run.kind == .full && (run.status == .running || run.status == .postTraining || run.status == .paused) {
            let perDay = Training.dailyFlops(run, state: s) * 0.9
            guard perDay > 0 else { continue }
            let left = max(0, run.flopsTotal - run.flopsDone) + max(0, run.postTrainFlops - run.postTrainDone)
            let eta = GameCalendar.addDays(s.date, Int(min(2_000, left / perDay).rounded(.up)))
            let proj = Training.projectedIndex(s, run)
            if best == nil || eta < best!.date { best = (run.design.name, eta, proj.0, proj.1, proj.2) }
        }
        return best
    }

    // MARK: Watch list

    enum Threat: String, Sendable {
        case passYou = "Likely to pass you"
        case close = "Neck and neck"
        case behind = "Behind you"
        case unknown = "No model of yours yet"
    }

    struct Row: Identifiable {
        var id: String
        var lab: String
        var color: UInt32
        var symbol: String
        var project: RivalProject
        var outlook: RivalOutlook
        var threat: Threat
        var last: CompetitorModel?
    }

    /// Every active lab's next model, soonest rumoured launch first.
    static func rows(_ s: GameState, set: [Benchmark]) -> [Row] {
        let mine = playerBest(s, set: set)?.index
        var out: [Row] = []
        for i in s.competitors.indices {
            guard let p = s.competitors[i].project, let o = outlook(s, i, set: set) else { continue }
            let threat: Threat
            if let mine {
                threat = o.index > mine + 2 ? .passYou : (o.index < mine - 2 ? .behind : .close)
            } else {
                threat = .unknown
            }
            let def = s.competitors[i].def
            out.append(Row(id: def.id, lab: def.name, color: def.color, symbol: def.symbol, project: p, outlook: o, threat: threat,
                           last: s.competitors[i].models.last))
        }
        return out.sorted { $0.outlook.center < $1.outlook.center }
    }

    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.calendar = GameCalendar.calendar
        f.timeZone = GameCalendar.calendar.timeZone
        f.dateFormat = "d MMM"
        return f
    }()

    /// "Q3 2028" while the window is wide, "3–20 Mar" or "28 Feb – 14 Mar" as it narrows, "~9 Mar" at the end.
    static func windowText(_ o: RivalOutlook) -> String {
        let span = GameCalendar.daysBetween(o.low, o.high)
        if span <= 4 { return "~" + dayMonth.string(from: o.center) }
        if o.halfWidth >= 40 {
            let a = GameCalendar.components(o.low), b = GameCalendar.components(o.high)
            let qa = (a.month - 1) / 3 + 1, qb = (b.month - 1) / 3 + 1
            if a.year == b.year && qa == qb { return "Q\(qa) \(a.year)" }
            if a.year == b.year { return "Q\(qa)–Q\(qb) \(a.year)" }
            return "Q\(qa) \(a.year) – Q\(qb) \(b.year)"
        }
        let a = GameCalendar.components(o.low), b = GameCalendar.components(o.high)
        if a.year == b.year && a.month == b.month {
            return "\(a.day)–\(dayMonth.string(from: o.high))"
        }
        return "\(dayMonth.string(from: o.low)) – \(dayMonth.string(from: o.high))"
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        let today = s.date
        let day = dayIndex(today)
        let q = quality(s)
        for i in s.competitors.indices {
            guard isActive(s.competitors[i], s) else {
                if s.competitors[i].project != nil { s.competitors[i].project = nil }
                continue
            }
            if s.competitors[i].project?.count != s.competitors[i].releaseCount { plan(&s, i) }
            guard var p = s.competitors[i].project else { continue }
            p.release = s.competitors[i].nextRelease
            let def = s.competitors[i].def
            let lab = def.name
            let key = "\(def.id)|\(p.count)"
            func roll(_ beat: String) -> Double { unit("\(key)|\(beat)|\(day)") }
            func fire(_ beat: String) -> Bool { !p.leaked.contains(beat) }
            let left = GameCalendar.daysBetween(today, p.release)
            // Keep the call made about six weeks out, to score the rumour mill when the model ships.
            if p.callCenter == nil && left <= 45, let o = outlook(s, i) {
                p.callCenter = o.center
                p.callC = o.c
                p.callSD = o.sd
            }

            if fire("start") && today >= p.started && roll("start") < 0.04 + 0.2 * q {
                p.leaked.insert("start")
                let src = ["The Informant reports", "Insiders say", "Supply-chain checks suggest", "Power-utility filings show"][Int(roll("src") * 4) % 4]
                add(&s, def.id, p.count, kind: "start", reliability: q > 0.45 ? .credible : .speculative,
                    title: "\(lab) is training \(p.codename)",
                    body: "\(src) \(lab) started pre-training its next frontier model, codenamed \(p.codename), on about \(Fmt.count(p.chips)) H100-equivalents at \(p.site).")
            }
            if fire("compute") && today >= GameCalendar.addDays(p.started, 21) && roll("compute") < 0.015 + 0.07 * q {
                p.leaked.insert("compute")
                let mine = s.maxRunCompute > 0 ? " — \(Fmt.trim(p.flops / s.maxRunCompute, p.flops > 10 * s.maxRunCompute ? 0 : 1))× your largest run" : ""
                add(&s, def.id, p.count, kind: "compute", reliability: .credible,
                    title: "\(p.codename): a \(Fmt.flops(p.flops))-FLOP run",
                    body: "SemiReport estimates \(p.codename)'s pre-training at about \(Fmt.flops(p.flops)) FLOPs on \(Fmt.count(p.chips)) H100-equivalents\(mine).")
            }
            if fire("pre") && today >= p.preEnd && roll("pre") < 0.05 + 0.2 * q {
                p.leaked.insert("pre")
                add(&s, def.id, p.count, kind: "pre", reliability: .credible,
                    title: "\(p.codename) finishes pre-training",
                    body: "\(lab) moved \(p.codename) into post-training: reinforcement learning on reasoning and agentic tasks, then safety testing.")
            }
            if fire("eval") && q > 0.2 && today >= GameCalendar.addDays(p.preEnd, 14) && roll("eval") < 0.01 + 0.05 * q {
                p.leaked.insert("eval")
                let set = Leaderboard.indexSet(s)
                let truth = index(s, i, c: Competitors.plannedC(s, compIndex: i, date: p.release), on: p.release, set: set)
                let leak = truth + gauss("\(key)|evalnoise") * 4 * (1 - q)
                p.evalLeak = leak
                var versus = ""
                if let mine = playerBest(s, set: set) {
                    versus = leak > mine.index ? " — above your \(mine.name) (\(Fmt.score(mine.index)))" : " — below your \(mine.name) (\(Fmt.score(mine.index)))"
                }
                add(&s, def.id, p.count, kind: "eval", reliability: q > 0.55 ? .credible : .speculative,
                    title: "Leaked evals: \(p.codename) at ~\(Fmt.score(leak))",
                    body: "Numbers from an internal eval run put \(p.name) around \(Fmt.score(leak)) on the Intelligence Index\(versus).")
            }
            if fire("redteam") && left <= 45 && left > 7 && roll("redteam") < (0.03 + 0.1 * q) * (Competitors.trait(def.id).safety > 0 ? 1.5 : 1) {
                p.leaked.insert("redteam")
                add(&s, def.id, p.count, kind: "redteam", reliability: .credible,
                    title: "\(lab) hands \(p.codename) to red-teamers",
                    body: "External safety testers say they have early access to \(p.name). Launches usually follow within four to six weeks.")
            }
            if fire("imminent") && left <= 7 && roll("imminent") < 0.12 + 0.3 * q {
                p.leaked.insert("imminent")
                let where_ = ["a staging API endpoint", "a leaked pricing page", "strings in a beta build of the \(def.chatProduct) app", "a cloud provider's model catalogue"][Int(roll("where") * 4) % 4]
                let set = Leaderboard.indexSet(s)
                let threat = (outlook(s, i, set: set)?.index ?? 0) > (playerBest(s, set: set)?.index ?? 0)
                add(&s, def.id, p.count, kind: "imminent", reliability: .confirmed,
                    title: "\(p.name) launch within days",
                    body: "\(p.name) appeared in \(where_). The launch looks imminent.", news: true, important: threat)
            }
            // The rumour mill gets things wrong, more often when you aren't paying for better sources.
            if left > 30 && roll("noise") < 0.004 * (1 - q) {
                let n = Int(roll("noisekind") * 3)
                let (t, b): (String, String)
                switch n {
                case 0: (t, b) = ("\(p.name) next week?", "A well-known leaker claims \(lab) will ship \(p.name) next week.")
                case 1: (t, b) = ("\(lab) said to have scrapped \(p.codename)", "An anonymous post claims \(lab) abandoned \(p.codename) after disappointing results.")
                default: (t, b) = ("\(p.codename) 'feels like AGI' internally", "Staff at \(lab) are said to be stunned by \(p.codename). Take it with a pinch of salt.")
                }
                var r = RivalRumor(date: today, labID: def.id, title: t, body: b, reliability: .speculative, kind: "noise", count: p.count)
                r.wrong = true
                s.rumors.insert(r, at: 0)
            }
            // Procedural releases can slip (history is fixed).
            if p.procedural && fire("slip") && today >= GameCalendar.addDays(p.preEnd, 20) && left > 20 {
                p.leaked.insert("slip")
                let odds: Double = ["halcyon": 0.3, "aletheia": 0.35, "deepgrove": 0.25].first { $0.key == def.id }?.value ?? 0.2
                if unit("\(key)|slip") < odds {
                    let days = 14 + Int(unit("\(key)|slipdays") * 35)
                    p.release = GameCalendar.addDays(p.release, days)
                    s.competitors[i].nextRelease = p.release
                    p.delays += 1
                    let reasons = ["red-teaming found a jailbreak class that needs another round of safety training",
                                   "a reward-hacking problem surfaced late in RL",
                                   "a cluster outage cost weeks of post-training",
                                   "evals came in below the bar leadership set",
                                   "a power shortfall at \(p.site) throttled the run"]
                    add(&s, def.id, p.count, kind: "delay", reliability: .credible,
                        title: "\(p.name) slips to \(p.release.gameMonth)",
                        body: "\(lab) pushed \(p.name) back about \(days / 7) weeks: \(reasons[Int(unit("\(key)|why") * Double(reasons.count)) % reasons.count]).",
                        news: true)
                }
            }
            s.competitors[i].project = p
        }
        if s.rumors.count > 150 { s.rumors.removeLast(s.rumors.count - 150) }
    }

    static func add(_ s: inout GameState, _ labID: String, _ count: Int, kind: String, reliability: RivalRumor.Reliability,
                    title: String, body: String, news: Bool = false, important: Bool = false) {
        s.rumors.insert(RivalRumor(date: s.date, labID: labID, title: title, body: body, reliability: reliability, kind: kind, count: count), at: 0)
        if news { Sim.news(&s, title, body, .competitor, important: important) }
    }

    // MARK: Releases

    /// A rival just shipped: score the rumour mill's call and check whether you upstaged them.
    static func released(_ s: inout GameState, _ i: Int, model: CompetitorModel, index: Double, outlook o: RivalOutlook?) {
        let def = s.competitors[i].def
        if let o, let p = s.competitors[i].project {
            // Score the six-weeks-out call on the benchmarks the model actually shipped against.
            let set = Leaderboard.indexSet(s)
            let c = p.callCenter == nil ? o.c : p.callC
            let sd = p.callCenter == nil ? o.sd : p.callSD
            let release = s.date
            func idx(_ x: Double) -> Double { RivalIntel.index(s, i, c: x, on: release, set: set) }
            s.watchRecord.insert(WatchCall(date: s.date, labID: def.id, model: model.name, forecast: idx(c), low: idx(c - 1.28 * sd), high: idx(c + 1.28 * sd),
                                           actual: index, dateError: GameCalendar.daysBetween(p.callCenter ?? o.center, model.date),
                                           rushed: p.rushed, delays: p.delays), at: 0)
            if s.watchRecord.count > 30 { s.watchRecord.removeLast() }
        }
        s.competitors[i].project = nil
        // Ship a better model in the two weeks before a rival's launch and you own the news cycle.
        let set = Leaderboard.indexSet(s)
        let since = GameCalendar.addDays(s.date, -14)
        if let mine = s.models.filter({ $0.released && ($0.releaseDate ?? .distantPast) >= since }).max(by: { $0.index < $1.index }),
           BenchmarkCatalog.index(Leaderboard.profile(mine), set: set) >= index {
            s.brand = min(100, s.brand + 2)
            s.competitors[i].brand = max(0, s.competitors[i].brand - 1)
            Sim.news(&s, "\(mine.name) steals \(def.name)'s thunder",
                     "\(model.name) landed days after \(mine.name) and couldn't beat it. Coverage is all about \(s.companyName). Brand +2.",
                     .competitor, important: true, good: true)
            Achievements.unlock(&s, "upstage")
        }
    }

    /// You shipped a model: rivals whose next model now looks second-best either rush or hold back to train harder.
    static func playerReleased(_ s: inout GameState, name: String, index: Double) {
        let set = Leaderboard.indexSet(s)
        let today = s.date
        for i in s.competitors.indices {
            guard isActive(s.competitors[i], s), var p = s.competitors[i].project, p.procedural, !p.leaked.contains("codered") else { continue }
            let left = GameCalendar.daysBetween(today, p.release)
            guard today >= p.preEnd, left > 21, let o = outlook(s, i, set: set), index > o.index + 1 else { continue }
            p.leaked.insert("codered")
            let def = s.competitors[i].def
            let key = "\(def.id)|\(p.count)|codered"
            let rushOdds = ["prometheus": 0.65, "xenon": 0.75, "deepgrove": 0.45, "openweights": 0.5, "dragonlake": 0.5, "sirocco": 0.4,
                            "halcyon": 0.25, "aletheia": 0.1][def.id] ?? 0.4
            if unit(key) < rushOdds {
                let pull = min(28, left - 10)
                p.release = GameCalendar.addDays(p.release, -pull)
                p.cAdjust -= 0.03
                p.rushed = true
                s.competitors[i].nextRelease = p.release
                add(&s, def.id, p.count, kind: "codered", reliability: .credible,
                    title: "Code red at \(def.name)",
                    body: "\(def.name) declared a code red after \(name) topped the charts. \(p.name) is being pulled forward by about \(max(1, pull / 7)) weeks — with less post-training than planned.",
                    news: true, important: true)
            } else {
                let push = 21 + Int(unit(key + "d") * 21)
                p.release = GameCalendar.addDays(p.release, push)
                p.cAdjust += 0.05
                p.delays += 1
                s.competitors[i].nextRelease = p.release
                add(&s, def.id, p.count, kind: "hold", reliability: .credible,
                    title: "\(def.name) holds \(p.name) back",
                    body: "After \(name) leapfrogged it, \(def.name) is giving \(p.codename) another \(push / 7) weeks of RL rather than ship second-best.",
                    news: true, important: true)
            }
            s.competitors[i].project = p
        }
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        guard s.intelBudget > 0 else { return }
        s.cash -= s.intelBudget
        s.month.costOther += s.intelBudget
    }

    /// Set up projects for a new game or an old save.
    static func bootstrap(_ s: inout GameState) {
        for i in s.competitors.indices where isActive(s.competitors[i], s) && s.competitors[i].project?.count != s.competitors[i].releaseCount {
            plan(&s, i)
        }
    }
}

// MARK: - Track record

/// How a rumour-mill forecast compared with the model that actually shipped.
struct WatchCall: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var labID: String
    var model: String
    var forecast: Double
    var low: Double
    var high: Double
    var actual: Double
    /// Actual release minus the rumoured centre, in days.
    var dateError: Int
    var rushed: Bool
    var delays: Int

    var hit: Bool { actual >= low - 0.5 && actual <= high + 0.5 }
}

// MARK: - Player actions

extension GameState {
    mutating func setIntelBudget(_ amount: Double) {
        intelBudget = max(0, amount)
    }
}
