import Foundation

// MARK: - 3.4: research for the 2030s

extension ResearchCatalog {
    private static func late(_ id: String, _ name: String, _ cat: ResearchCategory, _ year: Double, _ cost: Double,
                             _ prereqs: [String], _ effects: [ResearchEffect], _ blurb: String, tradeoff: String? = nil) -> ResearchItem {
        ResearchItem(id: id, name: name, category: cat, year: year, cost: cost, prereqs: prereqs, effects: effects, blurb: blurb,
                     tradeoff: tradeoff)
    }

    /// Concrete breakthroughs projected for 2028–2034, so the tree keeps going after the real timeline runs out.
    /// They are in `all` but not `core` (which seeds new games), the research tree lists them with `core`, and the
    /// research director never picks them before 2027 — so early eras play exactly as before.
    static let lateGame: [ResearchItem] = [
        late("verified_reasoning", "Verifiable Reasoning Chains", .reasoning, 2028.1, 26_000, ["verifiers", "formal_math"],
             [.rl(0.08), .skill(.reasoning, 0.06), .safety(3)],
             "Projected for 2028: every step of a long chain of thought ships with a machine-checkable certificate — Lean proofs for maths, type-checked programs for code, executable tests for the rest. RL stops rewarding answers that are merely convincing."),
        late("lifelong_agents", "Lifelong Agent Memory", .agents, 2028.4, 28_000, ["continual_learning", "long_horizon_rl"],
             [.skill(.agent, 0.06), .agentQuality(0.12), .skill(.longctx, 0.05)],
             "Projected for 2028: agents that remember every project they have worked on and get better at your codebase week by week, without retraining the base model. Continual learning, finally in production."),
        late("robot_fm", "Robotics Foundation Models", .multimodal, 2028.6, 32_000, ["world_models", "vla"],
             [.skill(.agent, 0.05), .skill(.vis, 0.08), .enterpriseDemand(0.12), .consumerDemand(0.04)],
             "Projected for 2028: one policy that drives arms, legs and grippers, trained in simulation and on data streamed back from robot fleets. Warehouses, factories and hospitals start signing up."),
        late("automated_alignment", "Automated Alignment Research", .safety, 2028.8, 34_000, ["auto_research", "ai_control"],
             [.safety(10), .agentSafety(0.2), .bugGuard(0.15), .enterpriseDemand(0.05)],
             "Projected for 2028–29: trusted AI researchers run interpretability and red-teaming experiments around the clock, so oversight scales with the models it oversees."),
        late("optical_compute", "Photonic Compute Fabrics", .systems, 2029.0, 36_000, ["optical_switching", "fp4_qat"],
             [.scaleOut(0.12), .throughput(0.12), .tps(0.1)],
             "Projected for 2029: co-packaged optics and photonic matrix engines move data — and some of the maths — with light. Big clusters lose less to communication and inference uses less power."),
        late("materials_ai", "AI Materials Discovery", .science, 2029.2, 36_000, ["alphafold", "co_mathematician"],
             [.chipDesign(0.15), .enterpriseDemand(0.06), .rp(0.05)],
             "Projected for 2029: models propose crystals, electrolytes and alloys, and robotic labs synthesise them overnight. Better packaging materials and coolants feed straight back into your chips."),
        late("world_model_planning", "World-Model Planning", .reasoning, 2029.5, 40_000, ["world_models", "tree_search"],
             [.skill(.agent, 0.06), .skill(.reasoning, 0.04), .agentRL(0.1)],
             "Projected for 2029: agents rehearse their plans inside a learned simulator before acting, searching over possible futures the way game engines once searched over chess moves."),
        late("analog_inference", "Analog In-Memory Inference", .inference, 2029.8, 38_000, ["kv_quant", "fp4_qat"],
             [.throughput(0.25), .tps(0.15), .skill(.reasoning, -0.02)],
             "Projected for 2029–30: keep the weights in analog memory cells and do the maths where they sit. Serving gets far cheaper.",
             tradeoff: "Analog noise costs a sliver of reasoning precision (−0.02)."),
        late("ai_scientist", "Autonomous AI Scientists", .science, 2030.3, 50_000, ["auto_research", "materials_ai"],
             [.rp(0.3), .enterpriseDemand(0.08), .forecast(0.1)],
             "Projected for 2030: closed-loop systems that form hypotheses, run the experiments, read the results and write the paper. Your research team gets an army of tireless postdocs."),
        late("neuromorphic_serving", "Neuromorphic Co-processors", .inference, 2030.6, 48_000, ["analog_inference"],
             [.tps(0.25), .throughput(0.15), .apiDemand(0.05)],
             "Projected for 2030: event-driven spiking hardware handles the sparse parts of every forward pass. Tokens per watt jump again."),
        late("provable_agents", "Provably Safe Agents", .safety, 2030.9, 55_000, ["automated_alignment", "verified_reasoning"],
             [.safety(8), .agentSafety(0.25), .enterpriseDemand(0.08), .distillGuard(0.2)],
             "Projected for 2030–31: agents act only through interfaces with formally verified guarantees — they can't exceed their mandate even if they want to. Regulators and enterprises love it."),
        late("fleet_learning", "Embodied Fleet Learning", .data, 2031.3, 60_000, ["robot_fm", "synthetic_data"],
             [.dataTokens(0.6), .dataAlgo(0.06), .skill(.agent, 0.03)],
             "Projected for 2031: millions of deployed robots stream back experience every day. For physical skills, the data wall disappears."),
        late("agent_orgs", "Million-Agent Organisations", .agents, 2031.6, 65_000, ["lifelong_agents", "swarm_governance"],
             [.coordination(0.02), .agentQuality(0.15), .enterpriseDemand(0.05)],
             "Projected for 2031: markets, managers and auditors made of agents, coordinating millions of workers with less overhead than a ten-person startup."),
        late("always_on_pretraining", "Always-On Pre-training", .optimization, 2032.0, 80_000, ["continual_learning", "wsd"],
             [.algo(0.08), .forecast(0.2), .stability(0.05)],
             "Projected for 2032: models never stop pre-training. Every release is a checkpoint of one endless run fed by fresh data, and nothing learned is thrown away."),
        late("complete_interp", "Whole-Model Interpretability", .safety, 2032.5, 85_000, ["nla", "automated_alignment"],
             [.safety(12), .bugGuard(0.3), .legibility(0.15)],
             "Projected for 2032: every circuit in a frontier model mapped and labelled by automated interpretability agents. Hidden goals have nowhere to hide."),
        late("self_designed_arch", "Self-Designed Architectures", .architecture, 2033.0, 110_000, ["ai_scientist", "unified_arch"],
             [.algo(0.12), .skill(.reasoning, 0.04)],
             "Projected for 2033: architecture search run by models better at it than the researchers who used to do it. Each generation is designed by the last."),
        late("discovered_learning", "Machine-Discovered Learning Algorithms", .optimization, 2034.0, 150_000, ["self_designed_arch", "always_on_pretraining"],
             [.algo(0.15), .rlEfficiency(0.2), .rp(0.15)],
             "Projected for 2034: the optimizer, the loss and the curriculum are all found by search over programs. Training gets cheaper faster than chips do."),
    ]

    static let lateGameIDs: Set<String> = Set(lateGame.map(\.id))
}

// MARK: - Frontier programmes (repeatable research)

/// 3.4: open-ended research for when the tree runs dry. Each programme has unlimited levels: every level costs more
/// than the last and adds a little less, but never nothing — so research money always buys progress.
struct FrontierProgram: Identifiable, Sendable {
    let id: String
    let name: String
    let category: ResearchCategory
    let symbol: String
    /// Year the programme can start.
    let opens: Double
    /// Research needed first.
    let prereq: String
    /// Research points for level 1.
    let baseCost: Double
    /// What level 1 gives; later levels add a shrinking share of it.
    let effects: [ResearchEffect]
    let blurb: String

    static let prefix = "prog:"
    /// Queue entry (and bonus id) for this programme.
    var entry: String { FrontierProgram.prefix + id }

    static let all: [FrontierProgram] = [
        FrontierProgram(id: "scaling", name: "Scaling Science", category: .optimization, symbol: "chart.line.uptrend.xyaxis",
                        opens: 2027.5, prereq: "continual_learning", baseCost: 8_000,
                        effects: [.algo(0.045), .dataAlgo(0.01), .dataTokens(0.05)],
                        blurb: "Open-ended work on why models learn: optimizers, data recipes and scaling laws. Every level makes every future training run go further."),
        FrontierProgram(id: "reasoning", name: "Reasoning at Scale", category: .reasoning, symbol: "brain",
                        opens: 2027.5, prereq: "rl_scaling", baseCost: 7_000,
                        effects: [.rl(0.025), .skill(.reasoning, 0.02), .skill(.code, 0.015), .thinkingEfficiency(0.015)],
                        blurb: "Harder verifiable problems, better reward models and smarter search at test time. Models think longer, better and cheaper."),
        FrontierProgram(id: "autonomy", name: "Agent Autonomy", category: .agents, symbol: "figure.walk.motion",
                        opens: 2027.5, prereq: "auto_experiments", baseCost: 7_000,
                        effects: [.skill(.agent, 0.02), .agentRL(0.015), .agentQuality(0.05), .enterpriseDemand(0.01)],
                        blurb: "Longer horizons, better tools and environments that look like real jobs. Agents finish more work without a human in the loop."),
        FrontierProgram(id: "serving", name: "Serving Efficiency", category: .inference, symbol: "bolt.fill",
                        opens: 2027.5, prereq: "fp4_qat", baseCost: 6_000,
                        effects: [.tps(0.06), .throughput(0.03), .thinkingEfficiency(0.01), .apiDemand(0.015), .consumerDemand(0.01)],
                        blurb: "Kernels, schedulers, caching and speculative decoding, tuned for every new chip. Faster answers win customers."),
        FrontierProgram(id: "alignment", name: "Alignment Science", category: .safety, symbol: "checkmark.shield.fill",
                        opens: 2027.5, prereq: "ai_control", baseCost: 6_000,
                        effects: [.safety(1.5), .bugGuard(0.03), .legibility(0.02), .distillGuard(0.02), .enterpriseDemand(0.015)],
                        blurb: "Interpretability, oversight and evaluations that keep up with your models. Customers and regulators trust what you ship."),
        FrontierProgram(id: "discovery", name: "AI for Science", category: .science, symbol: "testtube.2",
                        opens: 2028.0, prereq: "co_mathematician", baseCost: 8_000,
                        effects: [.rp(0.025), .chipDesign(0.01), .enterpriseDemand(0.01)],
                        blurb: "Point your models at mathematics, biology and materials. The tools they build make your own researchers faster."),
    ]

    static let byID: [String: FrontierProgram] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// The programme behind a queue entry, if it is one.
    static func get(entry: String) -> FrontierProgram? {
        guard entry.hasPrefix(prefix) else { return nil }
        return byID[String(entry.dropFirst(prefix.count))]
    }

    /// Research points for `level` (the first level is 1): costs rise a little faster than linearly.
    func cost(level: Int) -> Double { (baseCost * pow(Double(max(1, level)), 1.1) / 10).rounded() * 10 }

    /// What one level adds, as a share of level 1.
    static func marginal(_ level: Int) -> Double { pow(Double(max(1, level)), -0.25) }

    /// Combined strength after `level` levels, in units of level 1.
    static func strength(_ level: Int) -> Double {
        level <= 0 ? 0 : (1...level).reduce(0.0) { $0 + marginal($1) }
    }

    func isOpen(_ s: GameState) -> Bool { s.year >= opens && s.researched.contains(prereq) }

    /// Bonus carriers: one virtual item per programme, scaled by its strength.
    static var virtualItems: [ResearchItem] {
        all.map { ResearchItem(id: $0.entry, name: $0.name, category: $0.category, year: 0, cost: 0, prereqs: [], effects: $0.effects, blurb: $0.blurb) }
    }
}

extension GameState {
    func programLevel(_ id: String) -> Int { programLevels[id] ?? 0 }

    /// Levels completed across every frontier programme.
    var programLevelsTotal: Int { programLevels.values.reduce(0, +) }
}
