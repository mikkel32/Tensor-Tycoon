import Foundation

/// How rare (and how strong) a unique breakthrough is.
enum Rarity: String, Codable, CaseIterable, Sendable {
    case rare, epic, legendary

    var title: String { rawValue.capitalized }

    /// Licence value before scaling by year and mastery.
    var licenseBase: Double {
        switch self {
        case .rare: 4e7
        case .epic: 1.5e8
        case .legendary: 6e8
        }
    }
}

/// Two unique breakthroughs that are far stronger together.
struct Fusion: Identifiable, Sendable {
    let id: String
    let name: String
    let a: String
    let b: String
    let effects: [ResearchEffect]
    let blurb: String
}

/// Unique breakthroughs: rarity, mastery, fusions and the extra techniques added in 3.3.
enum Breakthroughs {
    static let rarity: [String: Rarity] = [
        "x_lattice_optimizer": .legendary, "x_world_sim": .legendary, "x_quantum_routing": .legendary,
        "x_neuromorphic": .legendary, "x_holographic": .legendary, "x_recursive_distill": .legendary,
        "x_energy_reasoning": .legendary, "x_alphaevolve": .legendary, "x_latent_reasoning": .legendary,
        "x_diffusion_lm": .epic, "x_looped_depth": .epic, "x_absolute_zero": .epic, "x_titans": .epic,
        "x_persona_societies": .epic, "x_oracle_data": .epic, "x_photonic": .epic, "x_thermodynamic": .epic,
        "x_retro": .epic, "x_learned_optimizers": .epic, "x_infinite_context": .epic, "x_memory_layers": .epic,
        "x_grokking": .epic, "x_dreamer": .epic, "x_self_rewarding": .epic, "x_evolved_nas": .epic,
    ]

    static func rarity(_ id: String) -> Rarity { rarity[id] ?? .rare }

    // MARK: Mastery

    static let maxMastery = 3

    /// Positive effects of a unique breakthrough are multiplied by this at each mastery level (it's yours, so it's
    /// already a little stronger than the idea on paper).
    static func masteryMultiplier(_ level: Int) -> Double {
        switch level {
        case ...1: 1.25
        case 2: 1.75
        default: 2.3
        }
    }

    /// Research points to refine a unique breakthrough to `level`.
    static func refineCost(_ item: ResearchItem, toLevel level: Int) -> Double {
        let r: Double = switch rarity(item.id) {
        case .rare: 0.5
        case .epic: 0.6
        case .legendary: 0.7
        }
        return (item.cost * r * Double(level - 1) / 10).rounded() * 10
    }

    static let refinePrefix = "refine:"

    static func refineID(_ id: String) -> String { refinePrefix + id }

    // MARK: Fusions

    static let fusions: [Fusion] = [
        Fusion(id: "fusion:silent_deliberation", name: "Silent Deliberation", a: "x_latent_reasoning", b: "x_looped_depth",
               effects: [.skill(.reasoning, 0.12), .thinkingEfficiency(0.2)],
               blurb: "Loop the block in latent space: deep thought without a single visible token."),
        Fusion(id: "fusion:infinite_recall", name: "Infinite Recall", a: "x_titans", b: "x_ttt_layers",
               effects: [.skill(.longctx, 0.3), .skill(.agent, 0.06)],
               blurb: "A memory that trains itself while it reads. Nothing is ever forgotten."),
        Fusion(id: "fusion:lightning_decoder", name: "Lightning Decoder", a: "x_diffusion_lm", b: "x_bitnet",
               effects: [.tps(1.0), .throughput(0.4)],
               blurb: "Ternary weights denoising whole paragraphs at once. Thousands of tokens per second."),
        Fusion(id: "fusion:self_taught_society", name: "Self-Taught Society", a: "x_absolute_zero", b: "x_persona_societies",
               effects: [.agentRL(0.2), .rl(0.1)],
               blurb: "A society of agents that sets each other's exams. No human data required."),
        Fusion(id: "fusion:clear_mind", name: "Clear Mind", a: "x_crosscoders", b: "x_kan",
               effects: [.safety(10), .legibility(0.1), .bugGuard(0.3)],
               blurb: "Readable layers plus feature diffs: you can see every change training makes."),
        Fusion(id: "fusion:perfect_curriculum", name: "Perfect Curriculum", a: "x_oracle_data", b: "x_grokking",
               effects: [.dataAlgo(0.1), .skill(.reasoning, 0.06)],
               blurb: "The right document at the right step, trained until it truly generalises."),
        Fusion(id: "fusion:ouroboros_prime", name: "Ouroboros Prime", a: "x_recursive_distill", b: "x_model_merging",
               effects: [.distill(0.25), .algo(0.04)],
               blurb: "Distil, merge, distil again. Every generation inherits the best of all the last."),
        Fusion(id: "fusion:optimizer_singularity", name: "Optimizer Singularity", a: "x_lattice_optimizer", b: "x_learned_optimizers",
               effects: [.algo(0.15), .stability(0.25)],
               blurb: "A learned optimizer that tames the lattice method's instability. Huge gains, no divergence."),
        Fusion(id: "fusion:silicon_dream", name: "Silicon Dream", a: "x_neuromorphic", b: "x_thermodynamic",
               effects: [.throughput(0.8), .tps(0.4)],
               blurb: "Spiking networks sampling on thermodynamic hardware: inference for almost free."),
        Fusion(id: "fusion:light_speed", name: "Light-Speed Cluster", a: "x_photonic", b: "x_quantum_routing",
               effects: [.scaleOut(0.3), .moeAlgo(0.15)],
               blurb: "Experts routed in one shot across an optical fabric. The cluster thinks as one."),
        Fusion(id: "fusion:living_archive", name: "Living Archive", a: "x_retro", b: "x_memory_layers",
               effects: [.algo(0.08), .skill(.lang, 0.1)],
               blurb: "Retrieval and memory layers together: a model that knows everything it has ever read."),
        Fusion(id: "fusion:autonomous_scientist", name: "Autonomous Scientist", a: "x_alphaevolve", b: "x_evolved_nas",
               effects: [.rp(0.3), .algo(0.05)],
               blurb: "Coding agents evolving the architecture they run on. Research compounds."),
        Fusion(id: "fusion:dreaming_agents", name: "Dreaming Agents", a: "x_dreamer", b: "x_world_sim",
               effects: [.agentRL(0.25), .skill(.agent, 0.1)],
               blurb: "Agents that rehearse a thousand futures in a learned world before acting in the real one."),
        Fusion(id: "fusion:elastic_depth", name: "Elastic Depth", a: "x_mixture_of_depths", b: "x_universal_tf",
               effects: [.throughput(0.2), .skill(.reasoning, 0.05)],
               blurb: "Easy tokens skip layers; hard ones loop. Compute goes exactly where thinking is needed."),
        Fusion(id: "fusion:hyperspace_router", name: "Hyperspace Router", a: "x_hyper_connections", b: "x_sparse_upcycling",
               effects: [.algo(0.06), .moeAlgo(0.06)],
               blurb: "Multi-stream residuals feeding upcycled experts. Free capability, twice."),
        Fusion(id: "fusion:polyglot_engine", name: "Polyglot Engine", a: "x_byte_latent", b: "x_hypernetworks",
               effects: [.skill(.lang, 0.2)],
               blurb: "Raw bytes in, language-specific adapters generated on the fly. Fluent in everything."),
        Fusion(id: "fusion:total_recall", name: "Total Recall Window", a: "x_infinite_context", b: "x_sparse_patterns",
               effects: [.skill(.longctx, 0.3), .kvMemory(0.2)],
               blurb: "Compressed memory plus learned sparsity: whole codebases and libraries in one context."),
        Fusion(id: "fusion:evolving_search", name: "Evolving Search", a: "x_pbt", b: "x_self_rewarding",
               effects: [.rlEfficiency(0.2), .forecast(0.2)],
               blurb: "Populations of self-rewarding learners, each tuning the next. RL that tunes itself."),
    ]

    static let fusionByID: [String: Fusion] = Dictionary(uniqueKeysWithValues: fusions.map { ($0.id, $0) })

    static var fusionItems: [ResearchItem] {
        fusions.map { f in
            ResearchItem(id: f.id, name: f.name, category: .exotic, year: 0, cost: 0, prereqs: [f.a, f.b], effects: f.effects, blurb: f.blurb)
        }
    }

    /// Fusions whose two halves are both researched.
    static func activeFusions(_ researched: Set<String>) -> [Fusion] {
        fusions.filter { researched.contains($0.a) && researched.contains($0.b) }
    }

    /// The fusion a breakthrough belongs to (each one has at most one partner).
    static func fusion(for id: String) -> Fusion? { fusions.first { $0.a == id || $0.b == id } }

    static func partner(of id: String) -> String? {
        guard let f = fusion(for: id) else { return nil }
        return f.a == id ? f.b : f.a
    }
}
