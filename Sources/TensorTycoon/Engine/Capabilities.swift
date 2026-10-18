import Foundation

// MARK: - 3.4: capability domains

/// What a model can do, field by field. Every domain uses the capability yardstick the leaderboard uses
/// (100 = the frontier of early 2023, +10 = ten times the effective compute), so a domain score reads the same in
/// 2019 and in 2035 and a 10-point gap is always a 10× gap.
enum CapDomain: String, Codable, CaseIterable, Identifiable, Sendable {
    case knowledge, reasoning, math, science, coding, agents, memory, vision, voice, social, robotics

    var id: String { rawValue }

    /// Position in a stored score array (the order of `allCases`).
    var index: Int {
        switch self {
        case .knowledge: 0
        case .reasoning: 1
        case .math: 2
        case .science: 3
        case .coding: 4
        case .agents: 5
        case .memory: 6
        case .vision: 7
        case .voice: 8
        case .social: 9
        case .robotics: 10
        }
    }

    static let count = 11

    var label: String {
        switch self {
        case .knowledge: "Knowledge"
        case .reasoning: "Reasoning"
        case .math: "Mathematics"
        case .science: "Science"
        case .coding: "Coding"
        case .agents: "Agents & autonomy"
        case .memory: "Long memory"
        case .vision: "Vision & video"
        case .voice: "Voice & audio"
        case .social: "Social & persuasion"
        case .robotics: "Robotics"
        }
    }

    /// For tight spaces (radar spokes, table headers).
    var short: String {
        switch self {
        case .knowledge: "Knowledge"
        case .reasoning: "Reasoning"
        case .math: "Math"
        case .science: "Science"
        case .coding: "Coding"
        case .agents: "Agents"
        case .memory: "Memory"
        case .vision: "Vision"
        case .voice: "Voice"
        case .social: "Social"
        case .robotics: "Robotics"
        }
    }

    var symbol: String {
        switch self {
        case .knowledge: "books.vertical.fill"
        case .reasoning: "brain"
        case .math: "function"
        case .science: "atom"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .agents: "figure.walk.motion"
        case .memory: "archivebox.fill"
        case .vision: "eye.fill"
        case .voice: "waveform"
        case .social: "person.2.wave.2.fill"
        case .robotics: "gearshape.2.fill"
        }
    }

    var about: String {
        switch self {
        case .knowledge: "What it knows and recalls correctly: facts, law, medicine, the professions."
        case .reasoning: "Multi-step logic and puzzles it has never seen."
        case .math: "Competition and research mathematics, up to new proofs."
        case .science: "Expert science questions, experiment design and discovery."
        case .coding: "Writing, fixing and shipping real software."
        case .agents: "Working on its own for hours or weeks with tools and a computer."
        case .memory: "Using huge contexts and remembering across sessions."
        case .vision: "Understanding images, screens and video, and generating them."
        case .voice: "Listening and speaking in real time, with tone and emotion."
        case .social: "Conversation, empathy, reading people and changing their minds."
        case .robotics: "Controlling robot bodies in the physical world. Needs dedicated research."
        }
    }
}

extension ResearchItem {
    /// Its effects as research cards list them: including the domain effects of items that predate the domains.
    var shownEffects: [ResearchEffect] {
        guard let extra = Capabilities.legacy[id] else { return effects }
        return effects + extra.map { .domain($0.0, $0.1) }
    }
}

/// One model's score in every domain, on the capability scale. Stored as a bare array (compact saves).
struct DomainScores: Codable, Hashable, Sendable {
    var v: [Double]

    init(_ v: [Double]) { self.v = v }

    init(from decoder: Decoder) throws { v = try decoder.singleValueContainer().decode([Double].self) }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(v)
    }

    subscript(_ d: CapDomain) -> Double { d.index < v.count ? v[d.index] : 0 }

    /// The higher of two scores in each domain.
    func best(_ o: DomainScores) -> DomainScores {
        DomainScores(CapDomain.allCases.map { Swift.max(self[$0], o[$0]) })
    }

    /// The average of a weighted mix of domains.
    func mix(_ w: [(CapDomain, Double)]) -> Double {
        let total = w.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        return w.reduce(0) { $0 + self[$1.0] * $1.1 } / total
    }
}

enum Capabilities {
    /// The effective capability (log10 compute units) that scores 100.
    static let anchorX = BenchmarkCatalog.ability(BenchmarkCatalog.capabilityAnchor)

    static func score(_ x: Double) -> Double { 100 + 10 * (x - anchorX) }

    /// Effective capability in each domain, from a model's skills plus domain-specific know-how `e`.
    static func xs(_ p: ModelProfile, extra e: [Double], video: Bool) -> [Double] {
        func ex(_ d: CapDomain) -> Double { d.index < e.count ? e[d.index] : 0 }
        let ctx = p.contextK >= 1000 ? 0.5 : (p.contextK >= 128 ? 0.0 : (p.contextK >= 32 ? -1.0 : -3.0))
        var x = [Double](repeating: 0, count: CapDomain.count)
        x[CapDomain.knowledge.index] = p.c + 0.1 * p.lang + ex(.knowledge)
        x[CapDomain.reasoning.index] = p.c + p.reasoning + ex(.reasoning)
        x[CapDomain.math.index] = p.c + 1.1 * p.reasoning + ex(.math)
        x[CapDomain.science.index] = p.c + 0.9 * p.reasoning + 0.15 * p.code + ex(.science)
        x[CapDomain.coding.index] = p.c + p.code + 0.6 * p.reasoning + ex(.coding)
        x[CapDomain.agents.index] = p.agenticX + ex(.agents)
        x[CapDomain.memory.index] = p.c + ctx + p.longctx + 0.3 * p.agent + ex(.memory)
        // Without the modality a model can't see or hear; a speech pipeline bolted onto a text model is far behind.
        x[CapDomain.vision.index] = p.vision ? p.c + 0.2 * p.reasoning + p.vis + (video ? 0.2 : 0) + ex(.vision) : p.c - 4
        x[CapDomain.voice.index] = p.audio ? p.c + 0.3 * p.reasoning + 0.5 * p.chat + ex(.voice) : p.c + 0.5 * p.chat - 2.5
        x[CapDomain.social.index] = p.c + 0.5 * p.chat + 0.3 * p.reasoning + ex(.social)
        // Bodies are hard: without robotics research a text model's "robotics" is a long way behind everything else.
        x[CapDomain.robotics.index] = p.c + 0.4 * p.agent + (p.vision ? p.vis : -1.5) - 3.2 + ex(.robotics)
        return x
    }

    static func scores(_ p: ModelProfile, extra e: [Double], video: Bool) -> DomainScores {
        // Scores bottom out at 0: a 2017 text model simply can't see, hear or drive a robot.
        DomainScores(xs(p, extra: e, video: video).map { (max(0, score($0)) * 10).rounded() / 10 })
    }

    // MARK: Domain know-how from research

    /// Domain effects of research items that predate the domains (their cards list them too).
    static let legacy: [String: [(CapDomain, Double)]] = [
        "rag": [(.knowledge, 0.08)],
        "few_shot": [(.reasoning, 0.03)],
        "multilingual": [(.knowledge, 0.03)],
        "deep_research": [(.knowledge, 0.06), (.science, 0.06), (.agents, 0.04)],
        "formal_math": [(.math, 0.25), (.science, 0.03)],
        "co_mathematician": [(.math, 0.2), (.science, 0.05)],
        "verified_reasoning": [(.math, 0.15), (.coding, 0.05)],
        "alphafold": [(.science, 0.15)],
        "graphcast": [(.science, 0.08)],
        "materials_ai": [(.science, 0.25)],
        "ai_scientist": [(.science, 0.35), (.agents, 0.05)],
        "swe_agent": [(.coding, 0.05)],
        "computer_use": [(.agents, 0.08), (.vision, 0.03)],
        "long_horizon_rl": [(.agents, 0.05)],
        "agent_orgs": [(.agents, 0.1)],
        "long_horizon": [(.memory, 0.08)],
        "nested_learning": [(.memory, 0.12)],
        "recursive_lm": [(.memory, 0.08)],
        "engram": [(.memory, 0.06), (.knowledge, 0.04)],
        "continual_learning": [(.memory, 0.15)],
        "lifelong_agents": [(.memory, 0.2)],
        "vision": [(.vision, 0.05)],
        "native_multimodal": [(.vision, 0.08), (.voice, 0.05)],
        "video": [(.vision, 0.15)],
        "image_gen": [(.vision, 0.08)],
        "latent_diffusion": [(.vision, 0.05)],
        "world_models": [(.vision, 0.12), (.robotics, 0.35)],
        "audio": [(.voice, 0.15)],
        "whisper": [(.voice, 0.12)],
        "character": [(.social, 0.08)],
        "anti_sycophancy": [(.social, 0.03)],
        "vla": [(.robotics, 0.5)],
        "robot_fm": [(.robotics, 0.8)],
        "fleet_learning": [(.robotics, 0.5)],
        "world_model_planning": [(.robotics, 0.25), (.agents, 0.05)],
        // Unique breakthroughs (yours or a rival's)
        "x_titans": [(.memory, 0.15)],
        "x_infinite_context": [(.memory, 0.15)],
        "x_world_sim": [(.vision, 0.1), (.robotics, 0.2)],
        "x_alphaevolve": [(.coding, 0.08), (.math, 0.05)],
    ]

    /// Every research item's domain effects: its own `.domain` effects plus the legacy table.
    static let effectsByID: [String: [(CapDomain, Double)]] = {
        var out = legacy
        for item in ResearchCatalog.all {
            for e in item.effects {
                if case .domain(let d, let v) = e { out[item.id, default: []].append((d, v)) }
            }
        }
        return out
    }()

    /// What your research adds to each domain (scaled by how well each result turned out in your lab).
    static func researchDomains(_ s: GameState) -> [Double] {
        var e = [Double](repeating: 0, count: CapDomain.count)
        for id in s.researched {
            guard let fx = effectsByID[id] else { continue }
            let q = s.researchResults[id] ?? 1
            for (d, v) in fx { e[d.index] += v * q }
        }
        for (d, v) in AdvancedProjects.domainEffects(s) { e[d.index] += v }   // 3.5: delivered government programmes
        for (d, v) in Science.domainKnowHow(s) { e[d.index] += v }   // 3.6: science-lab discoveries
        return e
    }

    /// Domain know-how the whole field has published by `y`: cumulative steps per domain.
    private static let fieldSteps: [[(Double, Double)]] = {
        var steps = [[(Double, Double)]](repeating: [], count: CapDomain.count)
        for item in ResearchCatalog.all where !item.isExotic {
            guard let fx = effectsByID[item.id] else { continue }
            for (d, v) in fx { steps[d.index].append((item.year, v)) }
        }
        return steps.map { list in
            var acc = 0.0
            return list.sorted { $0.0 < $1.0 }.map { acc += $0.1; return ($0.0, acc) }
        }
    }()

    static func field(_ d: CapDomain, at y: Double) -> Double {
        var v = 0.0
        for (yr, acc) in fieldSteps[d.index] {
            if yr > y { break }
            v = acc
        }
        return v
    }

    /// What a rival lab knows in each domain when it ships a model in year `y`: most of what the field has published
    /// (a few months after it appears), its own specialities and its unique breakthroughs.
    static func rivalDomains(_ s: GameState, lab: String, at y: Double) -> [Double] {
        var e = CapDomain.allCases.map { 0.85 * field($0, at: y - 0.25) }
        for (d, v) in specialty(lab) { e[d.index] += v }
        for tech in s.rivalTech[lab] ?? [] {
            guard let item = ResearchCatalog.byID[tech], item.year <= y + 0.3, let fx = effectsByID[tech] else { continue }
            for (d, v) in fx { e[d.index] += v }
        }
        return e
    }

    /// Each lab's long-standing strengths by domain (log10 compute units: 0.1 is one point).
    static func specialty(_ lab: String) -> [(CapDomain, Double)] {
        switch lab {
        case "prometheus": [(.social, 0.15), (.voice, 0.15), (.vision, 0.05), (.agents, 0.05)]
        case "deepgrove": [(.vision, 0.2), (.science, 0.3), (.robotics, 0.35), (.memory, 0.1), (.knowledge, 0.1), (.math, 0.1)]
        case "halcyon": [(.coding, 0.15), (.agents, 0.1), (.social, 0.05)]
        case "xenon": [(.robotics, 0.25), (.voice, 0.1), (.knowledge, 0.05), (.social, -0.1)]
        case "openweights": [(.robotics, 0.1), (.vision, 0.05), (.knowledge, 0.05)]
        case "dragonlake": [(.math, 0.15), (.coding, 0.1), (.science, 0.05)]
        case "sirocco": [(.knowledge, 0.05), (.social, 0.05)]
        case "aletheia": [(.math, 0.2), (.science, 0.2), (.reasoning, 0.05), (.social, -0.1)]
        default:
            // Labs founded during the game lean on their founding idea.
            switch CompetitorCatalog.spec(lab)?.kind {
            case .sovereign: [(.knowledge, 0.05), (.science, 0.05)]
            case .spinout: [(.reasoning, 0.05), (.agents, 0.05)]
            default: []
            }
        }
    }

    // MARK: Scoring models

    static func playerScores(_ m: AIModel, research e: [Double]) -> DomainScores {
        guard !m.domainBonus.isEmpty else { return scores(Leaderboard.profile(m), extra: e, video: m.design.video) }
        // 3.5: model families — distillation retention and post-training passes add per-domain know-how.
        var x = e
        for (i, v) in m.domainBonus.enumerated() where i < x.count { x[i] += v }
        return scores(Leaderboard.profile(m), extra: x, video: m.design.video)
    }

    static func rivalScores(_ s: GameState, _ m: CompetitorModel, lab: String, def: CompetitorDef) -> DomainScores {
        let y = m.date.decimalYear
        let p = Leaderboard.profile(m, def: def, boost: Competitors.boost(s, lab, at: y))
        // Big labs generate video from 2024.
        return scores(p, extra: rivalDomains(s, lab: lab, at: y), video: p.vision && y >= 2024.2)
    }

    // MARK: The daily pass

    /// Cheap fingerprint of the model population: changes when any model appears or is released.
    static func fingerprint(_ s: GameState) -> Int {
        var n = 0
        for c in s.competitors { n += c.models.count + c.openModels.count }
        for m in s.models {
            n += 1000
            if m.released { n += 1_000_000 }
        }
        return n
    }

    /// Score new models, check milestones, then run the product lines. Only does real work when a model appeared or
    /// shipped (or on the first of the month).
    static func daily(_ s: inout GameState) {
        if !s.capsReady { bootstrap(&s) }
        let f = fingerprint(s)
        if f != s.capsSeen {
            s.capsSeen = f
            let fresh = scoreNew(&s)
            refreshLabs(&s)
            Milestones.check(&s, newModels: fresh, announce: true)
            if leadsEverywhere(s) { Achievements.unlock(&s, "renaissance") }
        }
        ProductLines.daily(&s)
    }

    /// Your best released scores beat every rival lab still in business in every domain.
    static func leadsEverywhere(_ s: GameState) -> Bool {
        guard let mine = s.labDomains["player"] else { return false }
        let alive = Set(s.competitors.filter(\.alive).map(\.id))
        for (lab, v) in s.labDomains where lab != "player" && alive.contains(lab) {
            for d in CapDomain.allCases where v[d] >= mine[d] { return false }
        }
        return true
    }

    /// Score every model that has no scores yet. Returns the IDs scored (rivals' and yours).
    @discardableResult
    static func scoreNew(_ s: inout GameState) -> [String] {
        var fresh: [String] = []
        var mine: [Double]? = nil
        for m in s.models where s.domainScores[m.id.uuidString] == nil {
            let e = mine ?? researchDomains(s)
            mine = e
            s.domainScores[m.id.uuidString] = playerScores(m, research: e)
            fresh.append(m.id.uuidString)
        }
        for c in s.competitors {
            let def = c.def
            for m in c.models + c.openModels where s.domainScores[m.id.uuidString] == nil {
                s.domainScores[m.id.uuidString] = rivalScores(s, m, lab: c.id, def: def)
                fresh.append(m.id.uuidString)
            }
        }
        return fresh
    }

    /// Each lab's best released score per domain ("player" for you).
    static func refreshLabs(_ s: inout GameState) {
        var out: [String: DomainScores] = [:]
        for c in s.competitors {
            var best: DomainScores? = nil
            for m in c.models + c.openModels {
                guard let v = s.domainScores[m.id.uuidString] else { continue }
                best = best.map { $0.best(v) } ?? v
            }
            if let best { out[c.id] = best }
        }
        var mine: DomainScores? = nil
        for m in s.models where m.released {
            guard let v = s.domainScores[m.id.uuidString] else { continue }
            mine = mine.map { $0.best(v) } ?? v
        }
        if let mine { out["player"] = mine }
        s.labDomains = out
    }

    /// New games and older saves: score every model, seed the milestone history and the rivals' product lines.
    static func bootstrap(_ s: inout GameState) {
        s.capsReady = true
        // Public domain research from before the lab was founded is already known (as with the rest of the tree).
        let y0 = s.startDate.decimalYear
        for item in ResearchCatalog.capabilityTech where item.year <= y0 - 0.05 { s.researched.insert(item.id) }
        scoreNew(&s)
        refreshLabs(&s)
        Milestones.replayHistory(&s)
        ProductLines.bootstrap(&s)
        s.capsSeen = fingerprint(s)
    }

    // MARK: Views and forecasts

    /// Your best scores per domain: released models, and any model (released or not).
    static func playerBest(_ s: GameState, releasedOnly: Bool) -> DomainScores? {
        var best: DomainScores? = nil
        for m in s.models where !m.retired && (m.released || !releasedOnly) {
            guard let v = s.domainScores[m.id.uuidString] else { continue }
            best = best.map { $0.best(v) } ?? v
        }
        return best
    }

    /// The best rival lab still in business in each domain today: (lab ID, score).
    static func bestRival(_ s: GameState) -> [(lab: String, score: Double)] {
        let alive = Set(s.competitors.filter(\.alive).map(\.id))
        return CapDomain.allCases.map { d in
            var best: (String, Double) = ("", 0)
            for (lab, v) in s.labDomains where lab != "player" && alive.contains(lab) && v[d] > best.1 { best = (lab, v[d]) }
            return best
        }
    }

    /// Domain scores a Model Lab design is forecast to reach (from its forecast profile, with today's research).
    static func forecast(_ p: ModelProfile, design d: ModelDesign, state s: GameState) -> DomainScores {
        scores(p, extra: researchDomains(s), video: d.video)
    }
}
