import Foundation

/// 3.4: the world outside the labs. Once a month it moves: AI adoption by sector, the jobs AI takes and makes, public
/// mood and safety concern, AI's energy footprint and how strict each region's rules are. Its inputs are the game's own
/// systems — the frontier, prices, open models, incidents, scripted world events, laws, lobbying and the world's chip
/// fleet. It never draws from the game's RNG (`roll` hashes where it needs chance), so watching the world can't change
/// the rest of the game except through the effects it explains.
enum World {
    // MARK: Inputs

    struct Inputs {
        var y: Double
        /// Best capability on the market (frontier c).
        var capability: Double
        /// When the consumer chat boom started (nil before it has).
        var chatMoment: Double?
        /// The API price level (`market.apiPricePressure`): below 1 when open models and price wars push prices down.
        var pricePressure: Double = 1
        /// An open-weights model sits within reach of the frontier.
        var openNearFrontier = false
        var passed: Set<String> = []
        var failed: Set<String> = []
        var politicalCapital: Double = 0
        /// Your own fleet (H100-equivalents).
        var playerH100e: Double = 0
        /// 3.7: the pull of national AI strategies on adoption (Nations.adoptionPull; 0 in the replay of history).
        var national: Double = 0
    }

    /// The best capability on the market: the frontier curve, or more if a released model (yours or a rival's) is ahead.
    static func capability(_ s: GameState) -> Double {
        var best = Macro.frontier(s.year)
        for m in s.models where m.released && !m.retired { best = max(best, m.c) }
        for c in s.competitors where c.alive { if let m = c.latest { best = max(best, m.c) } }
        return best
    }

    static func inputs(_ s: GameState) -> Inputs {
        let c = capability(s)
        var open = s.models.contains { $0.openWeights && $0.c >= c - 0.6 }
        if !open {
            open = s.competitors.contains { comp in
                comp.alive && ((comp.latest.map { $0.open && $0.c >= c - 0.6 } ?? false) || (comp.openModels.last.map { $0.c >= c - 0.6 } ?? false))
            }
        }
        return Inputs(y: s.year, capability: c, chatMoment: s.chatMoment, pricePressure: s.market.apiPricePressure, openNearFrontier: open,
                      passed: s.lawsPassed, failed: s.lawsFailed, politicalCapital: s.politicalCapital, playerH100e: Economy.h100e(s),
                      national: Nations.adoptionPull(s))
    }

    /// Power per H100-equivalent of AI compute (kW), servers and cooling included: newer chips do more per watt.
    static func kwPerH100e(_ y: Double) -> Double {
        interpolate([(2016, 2.2), (2020, 2.0), (2023, 1.8), (2026, 1.4), (2028, 0.95), (2030, 0.65), (2035, 0.2)], at: y)
    }

    /// Average electricity use of the whole world (GW), growing about 2.5% a year.
    static func worldPowerGW(_ y: Double) -> Double { 2_900 * pow(1.025, y - 2020) }

    /// Where safety concern settles with no incidents: it grows with what AI can do.
    static func baselineConcern(_ capability: Double) -> Double { 12 + 30 * sigmoid((capability - 7.5) / 1.3) }

    /// How the US's own AI laws (the bills on the Security & Policy page) shift its rules.
    static func usLawShift(_ passed: Set<String>, _ failed: Set<String>) -> Double {
        let strictLaws = ["transparency", "compute_licensing", "liability", "agent_registry", "independent_auditors", "kill_switch", "dc_moratorium", "robot_tax"]
        var shift = Double(strictLaws.filter(passed.contains).count) * 3
        if passed.contains("preemption") { shift -= 6 }
        if failed.contains("preemption") { shift += 2 }
        return shift
    }

    /// A hashed roll in 0..<1 for this game (no RNG draw).
    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("world|\(s.world.salt)|\(key)") }

    /// "Tensor Labs'" / "Halcyon's".
    static func possessive(_ name: String) -> String { name.hasSuffix("s") ? name + "'" : name + "'s" }

    // MARK: The monthly model

    /// One month of the world. Shared by the replay of history (`bootstrap`) and live play.
    static func step(_ w: inout WorldState, _ i: Inputs) {
        w.normalize()
        let y = i.y
        // Adoption: each sector climbs its own S-curve in frontier capability, slowed by concern and strict rules,
        // sped up by cheap and open models — and by the chat boom that made everyone try AI.
        let awareness = i.chatMoment.map { 0.35 + 0.65 * clamp((y - $0) / 0.5, 0, 1) } ?? 0.35
        let price = clamp(1 + 0.3 * (1 - i.pricePressure), 0.92, 1.12) + (i.openNearFrontier ? 0.03 : 0)
        let concernDrag = 0.3 * clamp((w.concern - 30) / 50, 0, 1)
        let ruleDrag = 0.2 * clamp((w.averageStrictness - 30) / 50, 0, 1)
        for sector in Sector.allCases {
            let k = sector.index
            let (mid, width, ceiling) = sector.curve
            let boost = w.boosts.indices.contains(k) ? w.boosts[k] : 0
            let target = min(0.98, ceiling * sigmoid((i.capability - mid) / width) * awareness * price
                             * (1 - sector.caution * concernDrag) * (1 - sector.caution * ruleDrag) * (1 + i.national) + boost)
            let a = w.adoption[k]
            w.adoption[k] = clamp(a + (target - a) * (target > a ? sector.speed : sector.speed * 0.4), 0, 0.99)
        }

        // Jobs: deeper automation as capability grows. About a fifth of newly automated work becomes lost jobs; some new
        // work appears, and people find jobs again over time (faster with retraining money from a robot tax).
        let depth = 0.04 + 0.6 * sigmoid((i.capability - 8.8) / 1.3)
        var reach = 0.0
        for sector in Sector.allCases { reach += sector.workforce * min(1, w.adoption[sector.index] * depth * sector.depth) }
        let tasks = reach / Sector.totalWorkforce
        let lost = max(0, tasks - w.tasks) * Sector.totalWorkforce * 0.22
        w.tasks = tasks
        let aiJobs = Macro.marketSize(y) / 2.5e5 / 1e6
        let made = lost * 0.4 + max(0, aiJobs - w.aiJobs)
        w.aiJobs = aiJobs
        w.displaced += lost
        w.newJobs += made
        let rehired = i.passed.contains("robot_tax") ? 0.045 : 0.035
        w.looking = max(0, w.looking + lost - made - w.looking * rehired)

        // Mood and concern. Useful AI warms people up; job losses and fear cool them down. Concern settles slowly
        // toward a level that rises with capability; incidents push it up in between (`shock`).
        let base = baselineConcern(i.capability)
        var mood = 50 + 14 * (w.averageAdoption - 0.3) - 3 * w.jobPressure - 0.3 * max(0, w.concern - 25)
        if i.passed.contains("robot_tax") { mood += 3 }
        w.sentiment = clamp(w.sentiment + (clamp(mood, 10, 85) - w.sentiment) * 0.1, 0, 100)
        w.concern = clamp(w.concern + (base - w.concern) * 0.04, 0, 100)

        // Rules by region: each follows its real-world course, tightened by fear and a sour public, and in the US by
        // the laws that pass and loosened by the industry's lobbying (political capital).
        for r in Region.allCases {
            var target = r.baseline(y) + r.responsiveness * (0.35 * (w.concern - base) + 0.25 * (50 - w.sentiment))
            if r == .us { target += usLawShift(i.passed, i.failed) - 0.08 * i.politicalCapital }
            let k = r.index
            w.strictness[k] = clamp(w.strictness[k] + (clamp(target, 0, 100) - w.strictness[k]) * 0.06, 0, 100)
        }

        // Energy: the world's AI fleet (yours on top, once it's bigger than a typical lab's) and what it draws.
        let fleet = Economy.worldFleet(y)
        w.computeH100e = fleet + max(0, i.playerH100e - 0.1 * fleet)
        w.powerGW = w.computeH100e * kwPerH100e(y) / 1e6
        let share = w.powerGW / worldPowerGW(y)
        let yearAgo = w.history.count >= 12 ? w.history[w.history.count - 12].aiShare / 100 : share
        w.gridShock *= 0.9
        w.gridStress = clamp(900 * share + 3_500 * max(0, share - yearAgo) + w.gridShock, 0, 100)
        w.aiShare = share
    }

    /// Public trust in a rival lab settles here: its brand, its culture, and the turmoil it's in.
    static func labTrustTarget(_ c: CompetitorState) -> Double {
        var t = 40 + 0.3 * (c.brand - 40)
        switch c.id {
        case "halcyon": t += 10
        case "deepgrove": t += 4
        case "xenon": t -= 4
        case "dragonlake": t -= 6
        default: break
        }
        if c.def.openWeights { t += 3 }
        return clamp(t - 10 * c.turmoil, 10, 90)
    }

    // MARK: Start

    /// Sets up the world for a new game or an older save: replays the world from mid-2016 to today with the scripted
    /// history that already happened, then places your standing where your record puts it. Idempotent.
    static func bootstrap(_ s: inout GameState) {
        guard !s.world.ready else { return }
        var w = WorldState()
        w.ready = true
        w.salt = String(s.rng.state, radix: 36)
        w.adoption = Array(repeating: 0, count: Sector.allCases.count)
        w.boosts = Array(repeating: 0, count: Sector.allCases.count)
        w.strictness = Region.allCases.map { $0.baseline(2016.5) }
        w.governments = Array(repeating: 50, count: Region.allCases.count)
        w.concern = baselineConcern(Macro.frontier(2016.5))
        w.sentiment = 55

        // The scripted events that already happened, oldest first.
        let past = impacts.compactMap { (id, impact) -> (String, Date, Impact)? in
            guard s.firedEvents.contains(id), let e = scripted[id], e.date <= s.date, happened(e, s) else { return nil }
            return (id, e.date, impact)
        }.sorted { ($0.1, $0.0) < ($1.1, $1.0) }
        let now = s.year
        let chat = s.chatMoment
        var next = 0
        var d = GameCalendar.date(2016, 8, 1)
        let playerH100e = Economy.h100e(s)
        while d <= s.date {
            while next < past.count && past[next].1 < d {
                apply(&w, past[next].2, s)
                w.applied.insert(past[next].0)
                next += 1
            }
            let y = d.decimalYear
            let recent = y >= now - 1
            let i = Inputs(y: y, capability: Macro.frontier(y), chatMoment: chat.flatMap { y >= $0 ? $0 : nil },
                           openNearFrontier: y >= 2023.1, passed: recent ? s.lawsPassed : [], failed: recent ? s.lawsFailed : [],
                           politicalCapital: recent ? s.politicalCapital : 0, playerH100e: recent ? playerH100e : 0)
            step(&w, i)
            w.history.append(snapshot(w, month: d, standing: []))
            d = GameCalendar.addMonths(d, 1)
        }
        while next < past.count {
            apply(&w, past[next].2, s)
            w.applied.insert(past[next].0)
            next += 1
        }
        // Mapped events that were skipped (their lab had left the market) never apply later either.
        for id in impacts.keys where s.firedEvents.contains(id) { w.applied.insert(id) }
        for c in s.competitors where c.alive && s.year >= c.def.founded.decimal { w.labTrust[c.id] = labTrustTarget(c) }
        s.world = w
        Stakeholders.bootstrap(&s)
        if !s.world.history.isEmpty {
            s.world.history[s.world.history.count - 1] = snapshot(s.world, month: s.world.history[s.world.history.count - 1].month, standing: standingRow(s))
        }
    }

    // MARK: Daily and monthly

    /// Cheap daily watch: releases, open weights, leaks, prices (see `Stakeholders.daily`).
    static func daily(_ s: inout GameState) {
        guard s.world.ready else { return }
        Stakeholders.daily(&s)
    }

    /// The month closes: world events land, the world moves, your standing drifts and reacts, consequences follow.
    static func monthly(_ s: inout GameState) {
        guard s.gameOver == nil else { return }
        guard s.world.ready else { bootstrap(&s); return }
        applyScripted(&s)
        let i = inputs(s)
        step(&s.world, i)
        for c in s.competitors {
            guard c.alive, s.year >= c.def.founded.decimal else { s.world.labTrust[c.id] = nil; continue }
            let t = s.world.labTrust[c.id] ?? labTrustTarget(c)
            s.world.labTrust[c.id] = clamp(t + (labTrustTarget(c) - t) * 0.05, 0, 100)
        }
        Stakeholders.monthly(&s)
        Consequences.monthly(&s)
        s.world.history.append(snapshot(s.world, month: s.date, standing: standingRow(s)))
        if s.world.history.count > 300 { s.world.history.removeFirst(s.world.history.count - 300) }
    }

    static func standingRow(_ s: GameState) -> [Double] {
        [s.world.publicTrust, s.world.researchers, s.world.developers, s.boardConfidence, s.world.governmentAverage].map(round1)
    }

    static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    static func snapshot(_ w: WorldState, month: Date, standing: [Double]) -> WorldSnapshot {
        WorldSnapshot(month: month, adoption: w.adoption.map { round1($0 * 100) }, sentiment: round1(w.sentiment), concern: round1(w.concern),
                      tasks: round1(w.tasks * 100), looking: round1(w.looking), powerGW: round1(w.powerGW), aiShare: (w.aiShare * 10_000).rounded() / 100,
                      strictness: w.strictness.map(round1), standing: standing)
    }

    // MARK: Shocks

    /// Something happened that moves the world now: concern, mood, a region's rules, the grids. Logged with its cause.
    /// `incident` names a major incident regulators may answer ("the agent worm").
    static func shock(_ s: inout GameState, concern: Double = 0, mood: Double = 0, regions: [Region: Double] = [:], grid: Double = 0,
                      _ text: String, incident: String? = nil, date: Date? = nil) {
        guard s.world.ready else { return }
        var w = s.world
        var deltas: [String: Double] = [:]
        if concern != 0 { w.concern = clamp(w.concern + concern, 0, 100); deltas["concern"] = concern }
        if mood != 0 { w.sentiment = clamp(w.sentiment + mood, 0, 100); deltas["mood"] = mood }
        for (r, v0) in regions where w.strictness.indices.contains(r.index) {
            let v = v0 > 0 ? v0 * Nations.safetyResponse(s, r) : v0   // 3.4 overhaul: a strict safety regime tightens harder
            w.strictness[r.index] = clamp(w.strictness[r.index] + v, 0, 100)
            deltas[r.rawValue] = v
        }
        if grid != 0 { w.gridShock += grid; deltas["grid"] = grid }
        if let incident { w.incident = incident; w.incidentDate = date ?? s.date }
        s.world = w
        log(&s, WorldNote(date: date ?? s.date, text: text, deltas: deltas, kind: "world"))
    }

    static func log(_ s: inout GameState, _ note: WorldNote) {
        s.world.log.insert(note, at: 0)
        if s.world.log.count > 40 { s.world.log.removeLast(s.world.log.count - 40) }
    }

    // MARK: Scripted world events

    /// What a scripted event does to the world (on top of what it does to the market).
    struct Impact {
        var concern = 0.0
        var mood = 0.0
        var strict: [Region: Double] = [:]
        var grid = 0.0
        /// A rival lab whose public trust moves, and by how much.
        var lab: String? = nil
        var trust = 0.0
        var boost: [Sector: Double] = [:]
        /// Names a major incident regulators may answer.
        var incident: String? = nil
    }

    private static func everywhere(_ v: Double) -> [Region: Double] { Dictionary(uniqueKeysWithValues: Region.allCases.map { ($0, v) }) }

    static let impacts: [String: Impact] = [
        // 2017–2026
        "gpt2_withheld": Impact(concern: 2, lab: "prometheus", trust: 3),
        "chatgpt": Impact(mood: 6),
        "pause_letter": Impact(concern: 9, mood: -2),
        "eu_deal": Impact(strict: [.eu: 3]),
        "settlement": Impact(mood: -2),
        "supply_chain_risk": Impact(lab: "halcyon", trust: 2),
        "distillation": Impact(lab: "dragonlake", trust: -4),
        "glasswing": Impact(concern: 3, lab: "halcyon", trust: 3),
        "sandbox_escape": Impact(concern: 5, lab: "prometheus", trust: -6, incident: "Prometheus' sandbox escape"),
        "critical_cyber": Impact(concern: 3),
        "model_shelved": Impact(lab: "prometheus", trust: 2),
        "revenue_gap": Impact(lab: "prometheus", trust: -3),
        "super_pacs": Impact(mood: -1),
        "kill_switch_eo": Impact(strict: [.us: 3]),
        "ny_moratorium": Impact(strict: [.us: 2], grid: 8),
        "pjm_auction": Impact(grid: 10),
        "force_majeure": Impact(grid: 6),
        "grid_crunch": Impact(grid: 12),
        // 2027–2036 (projected)
        "f_agent_department": Impact(mood: -2, boost: [.finance: 0.03]),
        "f_agent_worm": Impact(concern: 10, mood: -4, strict: [.us: 3, .eu: 3], incident: "the agent worm"),
        "f_eu_high_risk": Impact(strict: [.eu: 4]),
        "f_cluster_licences": Impact(strict: [.us: 3]),
        "f_productivity": Impact(mood: 4),
        "f_grid_curtail": Impact(grid: 15),
        "f_deepfake_election": Impact(concern: 5, mood: -3, strict: [.us: 2, .eu: 2], incident: "the deepfake election scandal"),
        "f_liability_act": Impact(strict: [.us: 4]),
        "f_conjecture": Impact(mood: 2, lab: "halcyon", trust: 3, boost: [.science: 0.04]),
        "f_graduate_jobs": Impact(mood: -4),
        "f_open_frontier": Impact(lab: "openweights", trust: 3),
        "f_compute_levy": Impact(mood: 2),
        "f_ai_diagnosis": Impact(mood: 2, boost: [.healthcare: 0.06]),
        "f_heat_dome": Impact(grid: 18),
        "f_un_convention": Impact(concern: -3, strict: everywhere(3)),
        "f_flash_crash": Impact(concern: 3, mood: -2),
        "f_fusion_month": Impact(mood: 2, grid: -8),
        "f_weights_export": Impact(strict: [.us: 3]),
        "f_robot_boom": Impact(boost: [.manufacturing: 0.10]),
        "f_bio_scare": Impact(concern: 8, mood: -3, strict: [.us: 2, .eu: 3, .uk: 3], incident: "the biosecurity scare"),
        "f_compute_glut": Impact(grid: -5),
        "f_ai_dividend": Impact(mood: 6),
        "f_self_exfiltration": Impact(concern: 8, mood: -2, lab: "xenon", trust: -8, incident: "Xenon's self-copying agent"),
        "f_run_cap": Impact(strict: [.us: 2]),
        "f_gas_shock": Impact(grid: 10),
        "f_ai_drug": Impact(mood: 4, boost: [.healthcare: 0.03, .science: 0.02]),
        "f_margin_crash": Impact(mood: -1),
        "f_agent_disclosure": Impact(strict: everywhere(2)),
        "f_supergrid": Impact(grid: -12),
        "f_sandbagging": Impact(concern: 6, strict: [.us: 2, .eu: 2, .uk: 2], incident: "the sandbagging scandal"),
        "f_past_agi": Impact(concern: 3, mood: 1),
        "f_ai_gdp": Impact(mood: 1),
    ]

    /// The scripted events by ID.
    static let scripted: [String: HistoricalEvent] = {
        var out: [String: HistoricalEvent] = [:]
        for e in EventCatalog.historical + EventCatalog.future { out[e.id] = e }
        return out
    }()

    /// A lab-specific event doesn't happen if its lab has left the market (as in `Sim.historicalEvents`).
    static func happened(_ e: HistoricalEvent, _ s: GameState) -> Bool {
        guard let lab = e.lab, let c = s.competitors.first(where: { $0.id == lab }) else { return true }
        return !(c.acquired || c.bankrupt || !c.exitNote.isEmpty)
    }

    /// Applies an event's effect on the world (no log; used by the replay).
    static func apply(_ w: inout WorldState, _ i: Impact, _ s: GameState) {
        w.concern = clamp(w.concern + i.concern, 0, 100)
        w.sentiment = clamp(w.sentiment + i.mood, 0, 100)
        for (r, v) in i.strict where w.strictness.indices.contains(r.index) {
            let d = v > 0 ? v * Nations.safetyResponse(s, r) : v   // 3.4 overhaul: a strict safety regime tightens harder after incidents
            w.strictness[r.index] = clamp(w.strictness[r.index] + d, 0, 100)
        }
        w.gridShock += i.grid
        for (sector, v) in i.boost where w.boosts.indices.contains(sector.index) { w.boosts[sector.index] += v }
        if let lab = i.lab, let t = w.labTrust[lab] { w.labTrust[lab] = clamp(t + i.trust, 0, 100) }
    }

    /// Live play: scripted events that fired since last month move the world, with a note dated to the event. An event
    /// marked fired before its date didn't happen (you started the chat boom yourself, say).
    static func applyScripted(_ s: inout GameState) {
        let due = impacts.keys.filter { s.firedEvents.contains($0) && !s.world.applied.contains($0) }
            .compactMap { id in scripted[id].map { (id, $0) } }.sorted { ($0.1.date, $0.0) < ($1.1.date, $1.0) }
        guard !due.isEmpty else { return }
        for (id, e) in due {
            s.world.applied.insert(id)
            guard let impact = impacts[id], e.date <= s.date, happened(e, s) else { continue }
            var w = s.world
            if let lab = impact.lab, w.labTrust[lab] == nil, let c = s.competitors.first(where: { $0.id == lab }) { w.labTrust[lab] = labTrustTarget(c) }
            apply(&w, impact, s)
            if let label = impact.incident { w.incident = label; w.incidentDate = e.date }
            s.world = w
            var deltas: [String: Double] = [:]
            if impact.concern != 0 { deltas["concern"] = impact.concern }
            if impact.mood != 0 { deltas["mood"] = impact.mood }
            if impact.grid != 0 { deltas["grid"] = impact.grid }
            for (r, v) in impact.strict { deltas[r.rawValue] = v }
            if !deltas.isEmpty { log(&s, WorldNote(date: e.date, text: e.title, deltas: deltas, kind: "world")) }
        }
        // Notes from the month's own shocks came in as they happened; keep the log newest first.
        s.world.log.sort { $0.date > $1.date }
    }

    // MARK: Words

    static func moodLabel(_ v: Double) -> String {
        switch v {
        case 65...: "Enthusiastic"
        case 55..<65: "Warm"
        case 45..<55: "Mixed"
        case 35..<45: "Uneasy"
        case 25..<35: "Hostile"
        default: "Angry"
        }
    }

    static func concernLabel(_ v: Double) -> String {
        switch v {
        case 65...: "Alarmed"
        case 50..<65: "High"
        case 35..<50: "Elevated"
        case 20..<35: "Moderate"
        default: "Low"
        }
    }

    static func strictnessLabel(_ v: Double) -> String {
        switch v {
        case 80...: "Restrictive"
        case 60..<80: "Very strict"
        case 40..<60: "Strict"
        case 20..<40: "Moderate"
        default: "Light-touch"
        }
    }

    static func gridLabel(_ v: Double) -> String {
        switch v {
        case 70...: "Crunch"
        case 50..<70: "Strained"
        case 30..<50: "Tight"
        default: "Comfortable"
        }
    }

    static func standingLabel(_ v: Double) -> String {
        switch v {
        case 75...: "Excellent"
        case 60..<75: "Good"
        case 45..<60: "Neutral"
        case 30..<45: "Poor"
        default: "Hostile"
        }
    }

    // MARK: Briefing

    /// One or two lines for the monthly briefing, only when something in the world or your standing moved a lot.
    static func briefingLines(_ s: GameState) -> [BriefingLine] {
        let w = s.world
        guard w.ready, w.history.count >= 2 else { return [] }
        let now = w.history[w.history.count - 1], before = w.history[w.history.count - 2]
        let since = before.month
        var lines: [(score: Double, line: BriefingLine)] = []
        let screen = Screen.world.rawValue
        for n in w.consequences where n.date >= since {
            lines.append((100, BriefingLine(text: n.text + ".", good: nil, screen: screen)))
        }
        // Your standing: the biggest move of the month, with what caused it. (Investors are the board, which the
        // briefing already covers through its goals.)
        let names = ["public trust", "researchers' respect", "developer goodwill", "investor confidence", "standing with governments"]
        let keys = ["public", "researchers", "developers", "investors", nil]
        if now.standing.count == 5 && before.standing.count == 5 {
            var best: (Int, Double)? = nil
            for k in [0, 1, 2, 4] where abs(now.standing[k] - before.standing[k]) >= 8 {
                if best == nil || abs(now.standing[k] - before.standing[k]) > abs(best!.1) { best = (k, now.standing[k] - before.standing[k]) }
            }
            if let (k, d) = best {
                let causes = w.notes.filter { n in n.date >= since && (keys[k].map { n.deltas[$0] != nil } ?? n.deltas.keys.contains { Region(rawValue: $0) != nil }) }
                    .prefix(2).map { $0.text.prefix(1).lowercased() + $0.text.dropFirst() }
                lines.append((abs(d) * 3, BriefingLine(text: "\(names[k].prefix(1).uppercased() + names[k].dropFirst()) \(Int(before.standing[k].rounded())) → \(Int(now.standing[k].rounded()))"
                                                       + (causes.isEmpty ? "." : ": " + causes.joined(separator: "; ") + "."), good: d > 0, screen: screen)))
            }
        }
        let mood = now.sentiment - before.sentiment
        if abs(mood) >= 5 {
            lines.append((abs(mood) * 2.5, BriefingLine(text: "Public mood toward AI \(mood > 0 ? "warmed" : "soured"): \(Int(before.sentiment.rounded())) → \(Int(now.sentiment.rounded())) (\(moodLabel(now.sentiment).lowercased())).",
                                                         good: nil, screen: screen)))
        }
        let fear = now.concern - before.concern
        if fear >= 8 {
            let why = w.incidentDate.map { $0 >= since } == true && !w.incident.isEmpty ? " after \(w.incident)" : ""
            lines.append((fear * 2.5, BriefingLine(text: "Safety concern jumped \(Int(before.concern.rounded())) → \(Int(now.concern.rounded()))\(why). Regulators are watching.",
                                                    good: false, screen: screen)))
        }
        if now.strictness.count == before.strictness.count {
            for r in Region.allCases where now.strictness.indices.contains(r.index) && now.strictness[r.index] - before.strictness[r.index] >= 6 {
                lines.append((now.strictness[r.index] - before.strictness[r.index], BriefingLine(
                    text: "\(r.short) rules tightened: \(Int(before.strictness[r.index].rounded())) → \(Int(now.strictness[r.index].rounded())) (\(strictnessLabel(now.strictness[r.index]).lowercased())).",
                    good: false, screen: screen)))
            }
        }
        return lines.sorted { $0.score > $1.score }.prefix(2).map { $0.line }
    }
}
