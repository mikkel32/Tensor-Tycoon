import Foundation

// MARK: - 3.4: capability domains

/// What a model can do, field by field. Every domain uses the capability yardstick the leaderboard uses
/// (100 = the frontier of early 2023, +10 = ten times the effective compute), so a domain score reads the same in
/// 2019 and in 2035 and a 10-point gap is always a 10× gap.
enum CapDomain: String, Codable, CaseIterable, Identifiable, Sendable {
    case knowledge, reasoning, math, science, coding, agents, memory, vision, voice, social, robotics
    /// 3.8: appended (stored score arrays from older saves are shorter; `DomainScores` reads 0 past their end).
    case hardware, reliability, calibration, architecture, multilingual

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
        case .hardware: 11
        case .reliability: 12
        case .calibration: 13
        case .architecture: 14
        case .multilingual: 15
        }
    }

    static let count = 16
    /// How many domains saves from before 3.8 stored.
    static let legacyCount = 11

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
        case .hardware: "Hardware engineering"
        case .reliability: "Reliability"
        case .calibration: "Calibration"
        case .architecture: "Architecture design"
        case .multilingual: "Multilingual"
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
        case .hardware: "Chips"
        case .reliability: "Reliability"
        case .calibration: "Calibration"
        case .architecture: "Arch"
        case .multilingual: "Languages"
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
        case .hardware: "cpu.fill"
        case .reliability: "checkmark.seal.fill"
        case .calibration: "gauge.with.dots.needle.50percent"
        case .architecture: "square.stack.3d.up.fill"
        case .multilingual: "globe"
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
        case .hardware: "Designing and verifying chips: RTL, layouts, bring-up. Your chip programmes respin less with a strong one."
        case .reliability: "Getting long jobs right every time: fewer errors in agent organisations, steadier agent seats."
        case .calibration: "Knowing what it doesn't know: honest confidence, fewer confident mistakes and fewer safety incidents."
        case .architecture: "Designing models and training recipes: speeds up your architecture and efficiency research."
        case .multilingual: "Working in every language, not just English: buyers in Europe, China, Japan, India and the Gulf."
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

    /// The effective capability behind a score (the inverse of `score`).
    static func capability(fromScore v: Double) -> Double { anchorX + (v - 100) / 10 }

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
        // 3.8: chips are a specialist craft (two decades behind general ability without chip-design know-how);
        // reliability is reasoning plus agentic practice; calibration is reasoning plus the care safety training adds;
        // designing models leans on coding and reasoning; languages follow multilingual data.
        x[CapDomain.hardware.index] = p.c + 0.5 * p.code + 0.3 * p.reasoning - 2.0 + ex(.hardware)
        x[CapDomain.reliability.index] = p.c + 0.3 * p.reasoning + 0.3 * p.agent - 0.5 + ex(.reliability)
        x[CapDomain.calibration.index] = p.c + 0.5 * p.reasoning + 0.006 * (p.safety - 50) - 0.3 + ex(.calibration)
        x[CapDomain.architecture.index] = p.c + 0.4 * p.code + 0.5 * p.reasoning - 1.5 + ex(.architecture)
        x[CapDomain.multilingual.index] = p.c + p.lang - 0.3 + ex(.multilingual)
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
        "few_shot": [(.reasoning, 0.03), (.multilingual, 0.03)],
        "multilingual": [(.knowledge, 0.03), (.multilingual, 0.3)],
        "deep_research": [(.knowledge, 0.06), (.science, 0.06), (.agents, 0.04)],
        "formal_math": [(.math, 0.25), (.science, 0.03)],
        "co_mathematician": [(.math, 0.2), (.science, 0.05)],
        "verified_reasoning": [(.math, 0.15), (.coding, 0.05), (.calibration, 0.05)],
        "alphafold": [(.science, 0.15)],
        "graphcast": [(.science, 0.08)],
        "materials_ai": [(.science, 0.25)],
        "ai_scientist": [(.science, 0.35), (.agents, 0.05)],
        "swe_agent": [(.coding, 0.05), (.reliability, 0.04)],
        "computer_use": [(.agents, 0.08), (.vision, 0.03)],
        "long_horizon_rl": [(.agents, 0.05), (.reliability, 0.08)],
        "agent_orgs": [(.agents, 0.1), (.reliability, 0.05)],
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
        "whisper": [(.voice, 0.12), (.multilingual, 0.05)],
        "character": [(.social, 0.08)],
        "anti_sycophancy": [(.social, 0.03), (.calibration, 0.12)],
        "vla": [(.robotics, 0.5)],
        "robot_fm": [(.robotics, 0.8)],
        "fleet_learning": [(.robotics, 0.5)],
        "world_model_planning": [(.robotics, 0.25), (.agents, 0.05)],
        // 3.8: chip design
        "custom_silicon": [(.hardware, 0.25)],
        "kernel_compilers": [(.hardware, 0.05), (.architecture, 0.03)],
        "fp8_training": [(.hardware, 0.05)],
        "ai_chip_design": [(.hardware, 0.6), (.architecture, 0.05)],
        "xeno_materials": [(.hardware, 0.2)],
        "code_data": [(.hardware, 0.03)],
        // 3.8: reliability
        "prm": [(.reliability, 0.08)],
        "best_of_n": [(.reliability, 0.05), (.calibration, 0.03)],
        "self_refine": [(.reliability, 0.05)],
        "structured_outputs": [(.reliability, 0.08)],
        "mcp": [(.reliability, 0.05)],
        "verifiers": [(.reliability, 0.1)],
        "multi_agent": [(.reliability, 0.05)],
        "orchestration": [(.reliability, 0.05)],
        "agent_sandboxes": [(.reliability, 0.05)],
        "scalable_oversight": [(.reliability, 0.08), (.calibration, 0.05)],
        // 3.8: calibration
        "self_consistency": [(.calibration, 0.08)],
        "llm_judges": [(.calibration, 0.05)],
        "deliberative": [(.calibration, 0.08)],
        "weak_to_strong": [(.calibration, 0.05)],
        "safe_completions": [(.calibration, 0.08)],
        "rubric_rl": [(.calibration, 0.06)],
        "interpretability": [(.calibration, 0.05)],
        "circuit_tracing": [(.calibration, 0.05)],
        "cot_monitoring": [(.calibration, 0.05)],
        // 3.8: architecture design
        "scaling_laws": [(.architecture, 0.05)],
        "mup": [(.architecture, 0.05)],
        "proxy_ladder": [(.architecture, 0.05)],
        "fine_moe": [(.architecture, 0.05)],
        "mla": [(.architecture, 0.04)],
        "ssm_hybrid": [(.architecture, 0.04)],
        "mhc": [(.architecture, 0.05)],
        "auto_experiments": [(.architecture, 0.15)],
        "auto_research": [(.architecture, 0.4)],
        "unified_arch": [(.architecture, 0.3)],
        // 3.8: languages
        "tokenizers": [(.multilingual, 0.1)],
        "t5_c4": [(.multilingual, 0.03)],
        // Unique breakthroughs (yours or a rival's)
        "x_titans": [(.memory, 0.15)],
        "x_infinite_context": [(.memory, 0.15)],
        "x_world_sim": [(.vision, 0.1), (.robotics, 0.2)],
        "x_alphaevolve": [(.coding, 0.08), (.math, 0.05), (.hardware, 0.1), (.architecture, 0.1)],
        "x_evolved_nas": [(.architecture, 0.3)],
        "x_hyper_connections": [(.architecture, 0.1)],
        "x_byte_latent": [(.multilingual, 0.15)],
        "x_thermodynamic": [(.hardware, 0.15)],
        "x_neuromorphic": [(.hardware, 0.15)],
        "x_photonic": [(.hardware, 0.1)],
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

    /// What your research adds to each domain (scaled by how well each result turned out in your lab). `upTo` keeps
    /// only techniques published by then (rebuilding the know-how of a model trained before 3.8).
    static func researchDomains(_ s: GameState, upTo: Double? = nil) -> [Double] {
        var e = [Double](repeating: 0, count: CapDomain.count)
        for id in s.researched.sorted() {   // 3.7: fixed order (float sums)
            guard let fx = effectsByID[id] else { continue }
            if let upTo, (ResearchCatalog.byID[id]?.year ?? 0) > upTo { continue }
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
    /// (a few months after it appears), its own specialities, its unique breakthroughs and (3.8) the specialisation it
    /// chose: up to +1.5 points in its focus domains, ramping over its first year, and −0.5 elsewhere as the team moves.
    static func rivalDomains(_ s: GameState, lab: String, at y: Double) -> [Double] {
        var e = CapDomain.allCases.map { 0.85 * field($0, at: y - 0.25) }
        for (d, v) in specialty(lab) { e[d.index] += v }
        for tech in s.rivalTech[lab] ?? [] {
            guard let item = ResearchCatalog.byID[tech], item.year <= y + 0.3, let fx = effectsByID[tech] else { continue }
            for (d, v) in fx { e[d.index] += v }
        }
        for (d, v) in Science.rivalKnowHow(s, lab: lab, at: y) { e[d.index] += v }   // their science results, and what you published
        for (d, v) in AdvancedProjects.rivalDomainEffects(s, lab: lab) { e[d.index] += v }   // 3.8: government contracts it delivered
        for (d, v) in focusShift(s, lab: lab, at: y) { e[d.index] += v }
        return e
    }

    /// 3.8: how far a lab's specialisation has moved its models by `y`: +0.15 (1.5 points) in the focus domains once
    /// the team has had a year at it, −0.05 everywhere else. Business focuses (consumer, enterprise, sovereign, open
    /// weights) tune for their domains too; an efficiency focus changes size and price, not domains (Market).
    static func focusShift(_ s: GameState, lab: String, at y: Double) -> [(CapDomain, Double)] {
        guard let st = s.nations.focus[lab], let f = st.rivalFocus, f != .efficient, let since = st.since else { return [] }
        let ramp = clamp((y - since.decimalYear) / 1.0, 0, 1)
        guard ramp > 0 else { return [] }
        return CapDomain.allCases.map { d in (d, f.domains.contains(d) ? 0.15 * ramp : -0.05 * ramp) }
    }

    /// Each lab's long-standing strengths by domain (log10 compute units: 0.1 is one point).
    static func specialty(_ lab: String) -> [(CapDomain, Double)] {
        switch lab {
        case "prometheus": [(.social, 0.15), (.voice, 0.15), (.vision, 0.05), (.agents, 0.05), (.multilingual, 0.05)]
        case "deepgrove": [(.vision, 0.2), (.science, 0.3), (.robotics, 0.35), (.memory, 0.1), (.knowledge, 0.1), (.math, 0.1), (.hardware, 0.35), (.multilingual, 0.15)]
        case "halcyon": [(.coding, 0.15), (.agents, 0.1), (.social, 0.05), (.reliability, 0.15), (.calibration, 0.15)]
        case "xenon": [(.robotics, 0.25), (.voice, 0.1), (.knowledge, 0.05), (.social, -0.1), (.hardware, 0.1), (.calibration, -0.1)]
        case "openweights": [(.robotics, 0.1), (.vision, 0.05), (.knowledge, 0.05), (.multilingual, 0.1)]
        case "dragonlake": [(.math, 0.15), (.coding, 0.1), (.science, 0.05), (.architecture, 0.2), (.multilingual, 0.1)]
        case "sirocco": [(.knowledge, 0.05), (.social, 0.05), (.multilingual, 0.3)]
        case "aletheia": [(.math, 0.2), (.science, 0.2), (.reasoning, 0.05), (.social, -0.1), (.calibration, 0.1), (.architecture, 0.1)]
        default:
            // Labs founded during the game lean on their founding idea.
            switch CompetitorCatalog.spec(lab)?.kind {
            case .sovereign: [(.knowledge, 0.05), (.science, 0.05), (.multilingual, 0.15)]
            case .spinout: [(.reasoning, 0.05), (.agents, 0.05)]
            default: []
            }
        }
    }

    // MARK: Scoring models

    /// A model's scores from its domain know-how. A model with a know-how snapshot (3.8) is scored on it; `e` (today's
    /// research) only counts for a model being scored for the first time. Distillation retention, post-training passes
    /// and (for reasoning models) the reasoning effort add on top.
    static func playerScores(_ m: AIModel, research e: [Double]) -> DomainScores {
        var x = m.knowHow.count >= CapDomain.count ? m.knowHow : e
        for (i, v) in m.domainBonus.enumerated() where i < x.count { x[i] += v }   // 3.5: model families
        if m.reasoning && m.effort != .medium {
            for d in ReasoningEffort.shiftedDomains { x[d.index] += m.effort.scoreShift }   // 3.8: test-time compute
        }
        return scores(Leaderboard.profile(m), extra: x, video: m.design.video)
    }

    /// 3.8: the model's domain know-how from research: its snapshot; for a model scored before 3.8, what its stored
    /// scores imply (so rebuilding them changes nothing), with techniques published by its training for any domain
    /// the old save didn't score; and for a new model, today's research.
    static func knowHow(_ m: AIModel, _ s: GameState) -> [Double] {
        if m.knowHow.count >= CapDomain.count { return m.knowHow }
        guard let v = s.domainScores[m.id.uuidString], !v.v.isEmpty else { return researchDomains(s) }
        let older = researchDomains(s, upTo: m.created.decimalYear + 0.1)
        var plain = m
        plain.knowHow = []
        plain.domainBonus = []
        let base = xs(Leaderboard.profile(plain), extra: [], video: m.design.video)
        return CapDomain.allCases.map { d in
            guard d.index < v.v.count else { return older[d.index] }
            let bonus = d.index < m.domainBonus.count ? m.domainBonus[d.index] : 0
            let effort = m.reasoning && ReasoningEffort.shiftedDomains.contains(d) ? m.effort.scoreShift : 0
            // A score at the floor only says the know-how was low enough; the inverted value keeps it there.
            return capability(fromScore: v.v[d.index]) - base[d.index] - bonus - effort
        }
    }

    /// Store a model's know-how snapshot before anything about it changes (a pass, a merge, a new reasoning effort).
    static func ensureKnowHow(_ s: inout GameState, _ i: Int) {
        guard s.models[i].knowHow.count < CapDomain.count else { return }
        s.models[i].knowHow = knowHow(s.models[i], s)
    }

    /// A pass teaches the model the published techniques in its own domains (and nothing else): its snapshot catches
    /// up to today's research there.
    static func refresh(_ s: inout GameState, _ i: Int, domains: [CapDomain]) {
        ensureKnowHow(&s, i)
        let now = researchDomains(s)
        for d in domains where now[d.index] > s.models[i].knowHow[d.index] { s.models[i].knowHow[d.index] = now[d.index] }
    }

    static func rivalScores(_ s: GameState, _ m: CompetitorModel, lab: String, def: CompetitorDef) -> DomainScores {
        let y = m.date.decimalYear
        let p = Leaderboard.profile(m, def: def, boost: Competitors.boost(s, lab, at: y))
        // Big labs generate video from 2024.
        return scores(p, extra: rivalDomains(s, lab: lab, at: y), video: p.vision && y >= 2024.2)
    }

    /// 3.8: a frontier model of year `y` with everything the field has published: the yardstick the hooks below measure
    /// your models against.
    static func reference(_ y: Double) -> DomainScores {
        scores(Leaderboard.frontierReference(y), extra: CapDomain.allCases.map { field($0, at: y) }, video: y >= 2024.2)
    }

    // MARK: The daily pass

    /// Cheap fingerprint of the model population: changes when any model appears, is released or is retired.
    static func fingerprint(_ s: GameState) -> Int {
        var n = 0
        for c in s.competitors { n += c.models.count + c.openModels.count }
        for m in s.models {
            n += 1000
            if m.released { n += 1_000_000 }
            if m.retired { n += 1_000_000_000 }   // 3.8: a retired model stops counting for the lab
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

    /// Score every model that has no scores yet. Returns the IDs scored (rivals' and yours). A model of yours keeps the
    /// research it was scored with (its know-how snapshot) for good.
    @discardableResult
    static func scoreNew(_ s: inout GameState) -> [String] {
        var fresh: [String] = []
        var mine: [Double]? = nil
        for i in s.models.indices where s.domainScores[s.models[i].id.uuidString] == nil {
            if s.models[i].knowHow.count < CapDomain.count {
                let e = mine ?? researchDomains(s)
                mine = e
                s.models[i].knowHow = e
            }
            s.domainScores[s.models[i].id.uuidString] = playerScores(s.models[i], research: s.models[i].knowHow)
            fresh.append(s.models[i].id.uuidString)
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

    /// Each lab's best released score per domain ("player" for you; retired models no longer count).
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
        for m in s.models where m.released && !m.retired {
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

    /// 3.8: saves scored before the five new domains. Your models get a know-how snapshot that reproduces their stored
    /// scores and are scored in the new domains; rival models keep their stored scores and gain the new ones.
    static func upgrade(_ s: inout GameState) {
        guard s.capsReady else { return }
        var changed = false
        for i in s.models.indices {
            guard let v = s.domainScores[s.models[i].id.uuidString], v.v.count < CapDomain.count else { continue }
            ensureKnowHow(&s, i)
            let fresh = playerScores(s.models[i], research: s.models[i].knowHow)
            s.domainScores[s.models[i].id.uuidString] = DomainScores(v.v + Array(fresh.v.dropFirst(v.v.count)))
            changed = true
        }
        for c in s.competitors {
            let def = c.def
            for m in c.models + c.openModels {
                guard let v = s.domainScores[m.id.uuidString], v.v.count < CapDomain.count else { continue }
                let fresh = rivalScores(s, m, lab: c.id, def: def)
                s.domainScores[m.id.uuidString] = DomainScores(v.v + Array(fresh.v.dropFirst(v.v.count)))
                changed = true
            }
        }
        if changed { refreshLabs(&s) }
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
        let labs = s.labDomains.sorted { $0.key < $1.key }   // 3.7: ties go the same way every launch
        return CapDomain.allCases.map { d in
            var best: (String, Double) = ("", 0)
            for (lab, v) in labs where lab != "player" && alive.contains(lab) && v[d] > best.1 { best = (lab, v[d]) }
            return best
        }
    }

    /// Domain scores a Model Lab design is forecast to reach (from its forecast profile, with today's research).
    static func forecast(_ p: ModelProfile, design d: ModelDesign, state s: GameState) -> DomainScores {
        scores(p, extra: researchDomains(s), video: d.video)
    }

    // MARK: 3.8: what the new domains do elsewhere

    /// Your best released score in `d` against a frontier model of today with everything published (points; −10 with
    /// nothing released).
    static func edge(_ s: GameState, _ d: CapDomain) -> Double {
        guard let mine = s.labDomains["player"] else { return -10 }
        return mine[d] - reference(s.year)[d]
    }

    /// One model's score in `d` against today's frontier reference (points).
    static func edge(_ m: AIModel, _ d: CapDomain, _ s: GameState) -> Double {
        let v = s.domainScores[m.id.uuidString] ?? playerScores(m, research: knowHow(m, s))
        return v[d] - reference(s.year)[d]
    }

    /// Hardware engineering → chip design. Your best released model's hardware-engineering edge (points against a
    /// frontier model with every published technique). Semiconductor programmes read it through the two factors below.
    static func hardwareSkill(_ s: GameState) -> Double { edge(s, .hardware) }

    /// Multiplier on a chip design's respin odds: a model that checks the RTL and the layout catches bugs before
    /// tape-out (0.7 at +10 points, 1.15 with no model that understands chips).
    static func respinFactor(_ s: GameState) -> Double { clamp(exp(-0.035 * hardwareSkill(s)), 0.7, 1.15) }

    /// Multiplier on a chip architecture's quality (0.95–1.1): the model explores more of the design space.
    static func chipArchFactor(_ s: GameState) -> Double { clamp(1 + 0.01 * hardwareSkill(s), 0.95, 1.1) }

    /// Reliability → agent organisations. Multiplier on a model's agent error rate: 0.6 for a model 12 points more
    /// reliable than the frontier reference, 1.4 for one 8 points less.
    static func agentErrorFactor(_ m: AIModel, _ s: GameState) -> Double { clamp(exp(-0.04 * edge(m, .reliability, s)), 0.6, 1.4) }

    /// Calibration → safety incidents. Multiplier on the odds of a misuse or jailbreak incident: models that know what
    /// they don't know make fewer confident mistakes, and models that went through limited-access testing (Launches)
    /// ship with their worst failure modes found.
    static func incidentFactor(_ s: GameState) -> Double {
        let calibration = clamp(exp(-0.03 * edge(s, .calibration)), 0.6, 1.3)
        let live = s.models.filter { $0.released && !$0.retired }
        guard !live.isEmpty else { return calibration }
        let tested = Set(s.launches.filter { $0.plan.strategy == .limitedAccess }.map(\.modelID))
        let share = Double(live.filter { tested.contains($0.id) }.count) / Double(live.count)
        return calibration * (1 - 0.3 * share)
    }

    /// Architecture design → research. Speed of architecture, optimisation and inference research: your models propose
    /// and test designs (up to +40%; twice the effect once Automated AI Research runs the experiments).
    static func researchSpeed(_ s: GameState, _ item: ResearchItem) -> Double {
        guard [.architecture, .optimization, .inference].contains(item.category), s.labDomains["player"] != nil else { return 1 }
        let k = s.researched.contains("auto_research") ? 0.04 : 0.02
        return clamp(1 + k * edge(s, .architecture), 0.9, 1.4)
    }

    /// Multilingual → regional demand. Share of API buyers who need more than English: the non-English regions' share
    /// of world AI investment (Nations), about 60%, of whom a fifth buy for language work specifically.
    static func multilingualShare(_ s: GameState) -> Double {
        let english: Set<Region> = [.us, .uk]
        guard s.nations.ready else {
            return 0.2 * Region.allCases.filter { !english.contains($0) }.reduce(0) { $0 + $1.weight }
        }
        var all = 0.0, other = 0.0
        for r in Region.allCases {
            let v = s.nations.economy(r).aiInvestment
            all += v
            if !english.contains(r) { other += v }
        }
        return all > 0 ? 0.2 * other / all : 0.12
    }

    // MARK: 3.8: enterprise work by domain

    /// What an enterprise deal's work leans on (its title). Unknown titles weigh general knowledge and reasoning.
    static func dealDomains(_ title: String) -> [(CapDomain, Double)] {
        let t = title.lowercased()
        if t.contains("coding") || t.contains("copilot") { return [(.coding, 0.6), (.agents, 0.2), (.reliability, 0.2)] }
        if t.contains("voice") { return [(.voice, 0.6), (.social, 0.25), (.multilingual, 0.15)] }
        if t.contains("translation") { return [(.multilingual, 0.7), (.knowledge, 0.3)] }
        if t.contains("support") || t.contains("chatbot") { return [(.social, 0.4), (.knowledge, 0.3), (.multilingual, 0.15), (.reliability, 0.15)] }
        if t.contains("claims") || t.contains("contract") || t.contains("document") || t.contains("classification") {
            return [(.knowledge, 0.4), (.calibration, 0.3), (.reliability, 0.3)]
        }
        if t.contains("research") { return [(.science, 0.4), (.reasoning, 0.3), (.knowledge, 0.3)] }
        if t.contains("search") || t.contains("nlp") { return [(.knowledge, 0.5), (.multilingual, 0.2), (.reasoning, 0.3)] }
        if t.contains("agent") || t.contains("automation") { return [(.agents, 0.5), (.reliability, 0.3), (.coding, 0.2)] }
        return [(.knowledge, 0.4), (.reasoning, 0.3), (.social, 0.3)]
    }

    /// A model's fit for a deal: its score on the deal's domain mix against today's frontier reference (points).
    static func dealFitPoints(_ m: AIModel, title: String, _ s: GameState) -> Double {
        let mix = dealDomains(title)
        let v = s.domainScores[m.id.uuidString] ?? playerScores(m, research: knowHow(m, s))
        return v.mix(mix) - reference(s.year).mix(mix)
    }

    /// Hook for enterprise deal generation (Finance): multiplier on a lead's size and odds for this kind of work, from
    /// your best released model for it — exp(0.15 × points against the frontier reference), 0.3–3×. A coding rollout
    /// goes to whoever has the best coder, not the best average.
    static func dealFit(_ s: GameState, title: String) -> Double {
        let best = s.models.filter { $0.released && !$0.retired }.map { dealFitPoints($0, title: title, s) }.max() ?? -10
        return clamp(exp(0.15 * best), 0.3, 3)
    }

    /// The best score any live rival lab has on a deal's domain mix: (lab ID, points).
    static func bestRivalFor(_ s: GameState, title: String) -> (lab: String, score: Double)? {
        let mix = dealDomains(title)
        let alive = Set(s.competitors.filter(\.alive).map(\.id))
        var best: (String, Double)? = nil
        for (lab, v) in s.labDomains.sorted(by: { $0.key < $1.key }) where lab != "player" && alive.contains(lab) {
            let x = v.mix(mix)
            if x > (best?.1 ?? -1) { best = (lab, x) }
        }
        return best.map { (lab: $0.0, score: $0.1) }
    }
}
