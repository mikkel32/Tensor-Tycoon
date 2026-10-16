import Foundation

enum ResearchCategory: String, CaseIterable, Sendable, Identifiable {
    case architecture = "Architecture"
    case optimization = "Optimization & Scaling Science"
    case systems = "Systems & Hardware"
    case data = "Data"
    case postTraining = "Post-training & Alignment"
    case reasoning = "Reasoning & RL"
    case agents = "Agents & Tools"
    case multimodal = "Multimodal"
    case inference = "Inference & Serving"
    case safety = "Safety & Interpretability"
    case frontier = "Frontier"
    case exotic = "Unique Breakthroughs"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .architecture: "square.stack.3d.up.fill"
        case .optimization: "chart.line.uptrend.xyaxis"
        case .systems: "gearshape.2.fill"
        case .data: "externaldrive.fill.badge.icloud"
        case .postTraining: "slider.horizontal.3"
        case .reasoning: "brain"
        case .agents: "figure.walk.motion"
        case .multimodal: "eye.fill"
        case .inference: "bolt.fill"
        case .safety: "checkmark.shield.fill"
        case .frontier: "sparkles"
        case .exotic: "atom"
        }
    }
}

/// Things research can unlock (new design options, training stages, products).
enum Feature: String, Sendable, CaseIterable {
    case transformer, moe, fineMoE, gqa, mla, ssmHybrid, diffusionLM, mtp
    case muon, shampoo, wsd, muP, proxyLadder, curriculum
    case fp8Training, fp4Training, int8Serving, int4Serving
    case context32k, context128k, context1m
    case vision, audio, video, imageGen
    case chat, rlhf, dpo, reasoning, prm, extremeRL, toolUse, agents, computerUse, distillation
    case modelParallel, sharding, scalingLaws, immersion, multiSite, syntheticData
    case autoResearch, rsi, aiControl, customSilicon, latentReasoning, loopedDepth
}

/// Skill dimensions of a model beyond raw capability (all in "effective capability" units).
enum SkillDim: String, Sendable, CaseIterable {
    case reasoning, code, agent, chat, lang, longctx, vis

    var label: String {
        switch self {
        case .reasoning: "reasoning"
        case .code: "coding"
        case .agent: "agentic skill"
        case .chat: "instruction following"
        case .lang: "multilingual"
        case .longctx: "long-context recall"
        case .vis: "vision"
        }
    }
}

enum ResearchEffect: Sendable {
    /// Pre-training efficiency for every run (log10 effective compute).
    case algo(Double)
    /// Data-pipeline efficiency (log10 effective compute).
    case dataAlgo(Double)
    /// Extra efficiency only when the design uses Mixture-of-Experts.
    case moeAlgo(Double)
    /// Extra efficiency only with the Muon optimizer.
    case muonAlgo(Double)
    /// Extra efficiency for AdamW-family optimizers (second-order preconditioning).
    case shampooAlgo(Double)
    case skill(SkillDim, Double)
    /// Strength of RL reasoning at standard RL compute (reasoning skill units).
    case rl(Double)
    /// Cheaper RL (fraction of RL compute saved).
    case rlEfficiency(Double)
    /// Agentic RL environments (agent skill when tool use / agents are trained).
    case agentRL(Double)
    /// How close a distilled student gets to its teacher.
    case distill(Double)
    /// Fewer reasoning tokens per answer (cheaper, faster serving).
    case thinkingEfficiency(Double)
    /// Fewer loss spikes and divergences.
    case stability(Double)
    /// Tighter scaling-law forecasts.
    case forecast(Double)
    /// Less time lost per hardware failure.
    case failureCost(Double)
    /// Fewer silent training bugs.
    case bugGuard(Double)
    /// Fewer benchmark-contamination incidents.
    case contaminationGuard(Double)
    case mfu(Double)
    case throughput(Double)
    case tps(Double)
    case kvMemory(Double)
    case scaleOut(Double)
    case postTrainCost(Double)
    case rp(Double)
    case dataTokens(Double)
    case safety(Double)
    case consumerDemand(Double)
    case apiDemand(Double)
    case enterpriseDemand(Double)
    case unlock(Feature)

    var isNumeric: Bool {
        switch self {
        case .unlock, .consumerDemand, .apiDemand, .enterpriseDemand: false
        default: true
        }
    }
}

/// What a rival lab gains from owning an exotic technique.
struct RivalBoost: Sendable {
    var c = 0.0
    var reasoning = 0.0
    var code = 0.0
    var agent = 0.0
    var chat = 0.0
    var lang = 0.0
    var longctx = 0.0
    var tps = 1.0
    var price = 1.0
}

struct ResearchItem: Identifiable, Sendable {
    let id: String
    let name: String
    let category: ResearchCategory
    let year: Double
    let cost: Double
    let prereqs: [String]
    let effects: [ResearchEffect]
    let blurb: String
    var tradeoff: String? = nil
    var rival: RivalBoost? = nil

    var isExotic: Bool { category == .exotic }

    func effectSummary(result r: Double = 1) -> [String] {
        effects.map { ResearchCatalog.describe($0, r: r) }
    }

    var effectSummary: [String] { effectSummary() }

    /// A vague description of what an unrevealed technique is about (for rumours).
    var domainHint: String {
        for e in effects {
            switch e {
            case .unlock(let f):
                switch f {
                case .transformer, .moe, .fineMoE, .gqa, .mla, .ssmHybrid, .diffusionLM, .mtp, .loopedDepth: return "architecture"
                case .latentReasoning, .reasoning, .prm, .extremeRL: return "reasoning"
                case .toolUse, .agents, .computerUse: return "agents"
                case .vision, .audio, .video, .imageGen: return "multimodal"
                case .rsi, .autoResearch: return "self-improvement"
                case .customSilicon, .fp8Training, .fp4Training: return "hardware"
                case .syntheticData, .curriculum: return "data"
                case .aiControl: return "alignment"
                default: continue
                }
            case .skill(let d, _):
                switch d {
                case .reasoning: return "reasoning"
                case .code: return "coding"
                case .agent: return "agents"
                case .chat: return "post-training"
                case .lang: return "multilingual"
                case .longctx: return "long-context"
                case .vis: return "multimodal"
                }
            case .tps, .throughput, .kvMemory: return "inference"
            case .algo, .dataAlgo, .moeAlgo, .muonAlgo, .shampooAlgo: return "training-efficiency"
            case .rl, .rlEfficiency, .thinkingEfficiency, .distill: return "reasoning"
            case .agentRL: return "agents"
            case .safety, .bugGuard: return "alignment"
            case .mfu, .scaleOut, .failureCost: return "infrastructure"
            case .dataTokens, .contaminationGuard: return "data"
            default: continue
            }
        }
        return "research"
    }
}

/// Aggregated effects from everything researched, scaled by how well each result turned out in your lab.
struct ResearchBonuses: Sendable {
    var algo = 0.0
    var dataAlgo = 0.0
    var moeAlgo = 0.0
    var muonAlgo = 0.0
    var shampooAlgo = 0.0
    var skills: [SkillDim: Double] = [:]
    var rl = 0.0
    var rlEfficiency = 0.0
    var agentRL = 0.0
    var distill = 0.0
    var thinkingEfficiency = 0.0
    var stability = 0.0
    var forecastKeep = 1.0
    var failureKeep = 1.0
    var bugKeep = 1.0
    var contaminationKeep = 1.0
    var mfu = 0.0
    var throughput = 0.0
    var tps = 0.0
    var kvMemory = 0.0
    var scaleOut = 0.0
    var postTrainCost = 0.0
    var rp = 0.0
    var dataTokens = 0.0
    var safety = 0.0
    var consumerDemand = 0.0
    var apiDemand = 0.0
    var enterpriseDemand = 0.0
    var features: Set<Feature> = []
    var results: [String: Double] = [:]
    var researched: Set<String> = []

    func has(_ f: Feature) -> Bool { features.contains(f) }
    func skill(_ d: SkillDim) -> Double { skills[d] ?? 0 }
    /// Realised quality of a researched item (1 = as expected).
    func result(_ id: String) -> Double { results[id] ?? 1 }
    /// Remaining forecast error after scaling-science research (1 = none).
    var forecastScale: Double { forecastKeep }
}

enum ResearchCatalog {
    private static func r(_ id: String, _ name: String, _ cat: ResearchCategory, _ year: Double, _ cost: Double,
                          _ prereqs: [String] = [], _ effects: [ResearchEffect], _ blurb: String,
                          tradeoff: String? = nil, rival: RivalBoost? = nil) -> ResearchItem {
        ResearchItem(id: id, name: name, category: cat, year: year, cost: cost, prereqs: prereqs, effects: effects,
                     blurb: blurb, tradeoff: tradeoff, rival: rival)
    }

    static let all: [ResearchItem] = core + exotic

    // MARK: - Core techniques (real research, with historical dates)

    static let core: [ResearchItem] = [
        // MARK: Architecture
        r("transformer", "Transformer", .architecture, 2017.45, 60, [],
          [.unlock(.transformer), .algo(0.20)],
          "\"Attention Is All You Need\" (Jun 2017). Self-attention replaces recurrence and scales on parallel hardware. Without it you're training LSTMs."),
        r("gpt_pretraining", "Generative Pre-training", .architecture, 2018.45, 90, ["transformer"],
          [.algo(0.05), .skill(.chat, 0.05)],
          "GPT-1 (Jun 2018): a decoder-only Transformer pre-trained on raw text, then adapted. The recipe every LLM still follows."),
        r("pre_ln", "Pre-LayerNorm & Residual Scaling", .architecture, 2019.1, 140, ["transformer"],
          [.algo(0.03), .stability(0.12)],
          "Normalise before each block (GPT-2, Feb 2019). Deep Transformers stop diverging early in training."),
        r("rope", "Rotary Position Embeddings", .architecture, 2021.3, 420, ["transformer"],
          [.unlock(.context32k), .algo(0.02), .skill(.longctx, 0.05)],
          "RoFormer (Apr 2021): rotate queries and keys by position. Later stretched with NTK/YaRN scaling to 32K+ tokens."),
        r("modern_block", "SwiGLU · RMSNorm · No Biases", .architecture, 2022.3, 520, ["pre_ln"],
          [.algo(0.06), .stability(0.05)],
          "The PaLM / LLaMA block recipe: gated SwiGLU feed-forwards, RMSNorm and bias-free layers. Same compute, better model."),
        r("qk_norm", "QK-Norm & Logit Soft-capping", .architecture, 2023.3, 900, ["modern_block"],
          [.stability(0.22)],
          "Normalise queries and keys (ViT-22B) and cap attention logits (Gemma 2). Attention logits stop exploding at scale."),
        r("gqa", "Grouped-Query Attention", .architecture, 2023.4, 700, ["transformer"],
          [.unlock(.gqa), .kvMemory(0.5), .throughput(0.15)],
          "Share key/value heads across query groups (May 2023): KV cache shrinks ~8× with almost no quality loss."),
        r("mla", "Multi-head Latent Attention", .architecture, 2024.4, 2_200, ["gqa"],
          [.unlock(.mla), .kvMemory(0.3), .throughput(0.2)],
          "DeepSeek-V2 (May 2024): compress keys and values into a small latent. Huge KV savings — choose it in the Model Lab."),
        r("moe", "Mixture-of-Experts", .architecture, 2021.0, 1_300, ["sharding"],
          [.unlock(.moe), .moeAlgo(0.40)],
          "Switch Transformer / GShard: route each token to a few experts. Total parameters grow, compute per token doesn't. Gains grow with scale and sparsity.",
          tradeoff: "MoE routers are touchier: more loss spikes until you research load balancing."),
        r("fine_moe", "Fine-grained & Shared Experts", .architecture, 2024.0, 3_000, ["moe"],
          [.unlock(.fineMoE), .moeAlgo(0.20)],
          "DeepSeekMoE (Jan 2024): many small experts plus always-on shared experts. Unlocks 1/32 and 1/64 sparsity."),
        r("aux_free", "Auxiliary-loss-free Load Balancing", .architecture, 2024.95, 3_400, ["fine_moe"],
          [.moeAlgo(0.05), .stability(0.12)],
          "DeepSeek-V3 (Dec 2024): bias-adjusted routing keeps experts balanced without hurting the loss. No irrecoverable spikes."),
        r("mtp", "Multi-Token Prediction", .architecture, 2024.3, 2_000, ["transformer"],
          [.unlock(.mtp), .tps(0.15)],
          "Predict several future tokens per step (Gloeckle et al., DeepSeek-V3). A training signal and a built-in speculative-decoding head."),
        r("long_context", "128K Context", .architecture, 2023.9, 1_700, ["rope", "flash_attention"],
          [.unlock(.context128k), .skill(.longctx, 0.08), .enterpriseDemand(0.1)],
          "Long-document training mixtures and sequence parallelism make 128K-token windows practical (GPT-4 Turbo, Nov 2023)."),
        r("ring_attention", "1M-token Context (Ring Attention)", .architecture, 2024.15, 3_600, ["long_context"],
          [.unlock(.context1m), .skill(.longctx, 0.06), .enterpriseDemand(0.1)],
          "Ring attention spreads one sequence across many chips (Gemini 1.5, Feb 2024). Whole codebases fit in the prompt."),
        r("sparse_attention", "Native Sparse Attention", .architecture, 2025.15, 4_800, ["ring_attention"],
          [.skill(.longctx, 0.15), .throughput(0.08), .tps(0.08)],
          "NSA / DeepSeek Sparse Attention (2025): learned sparse attention patterns make million-token context cheap."),
        r("ssm_hybrid", "Hybrid SSM / Attention", .architecture, 2024.3, 2_800, ["long_context"],
          [.unlock(.ssmHybrid), .skill(.longctx, 0.05)],
          "Mamba (Dec 2023) layers interleaved with attention (Jamba, Nemotron-H). Linear-time context and fast decoding.",
          tradeoff: "Hybrid models decode faster but give up a little reasoning quality."),

        // MARK: Optimization & scaling science
        r("adamw", "AdamW (Decoupled Weight Decay)", .optimization, 2017.95, 100, [],
          [.algo(0.03), .stability(0.05)],
          "Loshchilov & Hutter (Nov 2017): fix how Adam applies weight decay. Still the default optimizer."),
        r("warmup_cosine", "Warmup + Cosine Schedules", .optimization, 2017.6, 80, [],
          [.algo(0.02), .stability(0.05)],
          "Linear warmup then cosine decay. Big models stop blowing up in the first thousand steps."),
        r("large_batch", "Critical Batch Size", .optimization, 2018.95, 260, ["adamw"],
          [.scaleOut(0.12), .forecast(0.05)],
          "\"An Empirical Model of Large-Batch Training\" (Dec 2018): how big a batch can get before it stops helping — so more chips stay useful."),
        r("scaling_laws", "Neural Scaling Laws", .optimization, 2020.05, 300, ["transformer"],
          [.unlock(.scalingLaws), .forecast(0.40), .algo(0.02)],
          "Kaplan et al. (Jan 2020): loss falls as a power law in compute. Unlocks forecasts in the Model Lab."),
        r("mup", "μP Hyperparameter Transfer", .optimization, 2022.2, 700, ["scaling_laws"],
          [.unlock(.muP), .forecast(0.30), .algo(0.03), .stability(0.08), .bugGuard(0.25)],
          "Tensor Programs V (Mar 2022): tune hyperparameters on a small model and transfer them to a huge one unchanged."),
        r("chinchilla", "Compute-Optimal Training (Chinchilla)", .optimization, 2022.25, 600, ["scaling_laws"],
          [.forecast(0.25), .algo(0.02)],
          "Hoffmann et al. (Mar 2022): ~20 tokens per parameter. Before this, recipes size models like GPT-3 — big and under-trained. After it, the Model Lab sizes runs compute-optimally."),
        r("z_loss", "z-loss & Stable Softmax", .optimization, 2022.3, 450, ["modern_block"],
          [.stability(0.15)],
          "PaLM (Apr 2022): a small auxiliary loss keeps output logits from drifting. Fewer mysterious spikes."),
        r("proxy_ladder", "Predictable Scaling", .optimization, 2023.2, 1_200, ["mup"],
          [.unlock(.proxyLadder), .forecast(0.15), .bugGuard(0.15)],
          "GPT-4 technical report (Mar 2023): final loss forecast from runs with up to 10,000× less compute. Unlocks the scaling ladder in the Model Lab."),
        r("curriculum", "Annealing & Data Curriculum", .optimization, 2024.1, 2_200, ["data_mixture"],
          [.unlock(.curriculum), .algo(0.05), .skill(.reasoning, 0.03), .skill(.code, 0.02)],
          "MiniCPM / Llama 3 (2024): end pre-training by decaying the learning rate on the best data. Adds an annealing stage."),
        r("wsd", "Warmup-Stable-Decay Schedules", .optimization, 2024.3, 1_800, ["curriculum"],
          [.unlock(.wsd), .algo(0.02)],
          "MiniCPM (Apr 2024): a flat learning rate with a short decay at the end. Checkpoints stay usable and runs can be extended."),
        r("shampoo", "Second-order Preconditioning", .optimization, 2024.7, 3_200, ["adamw"],
          [.unlock(.shampoo), .shampooAlgo(0.08)],
          "Distributed Shampoo / SOAP (AlgoPerf winner, 2024): precondition gradients with curvature. A cheaper path to a better optimizer.",
          tradeoff: "Extra optimizer math costs ~2% MFU."),
        r("muon", "Muon Optimizer", .optimization, 2025.15, 4_200, ["adamw"],
          [.unlock(.muon), .muonAlgo(0.25)],
          "Moonlight (Feb 2025): orthogonalised momentum reaches AdamW quality with ~52% of the FLOPs. Select it in the Model Lab.",
          tradeoff: "Attention logits can blow up at scale: Muon runs spike much more until MuonClip is researched."),
        r("muon_clip", "MuonClip (QK-clip)", .optimization, 2025.5, 4_000, ["muon", "qk_norm"],
          [.stability(0.10), .muonAlgo(0.03)],
          "Kimi K2 (Jul 2025): clip query/key weights after each Muon step. A 15.5T-token run with zero loss spikes."),

        // MARK: Systems & hardware
        r("mixed_precision", "Mixed Precision Training", .systems, 2017.8, 150, [],
          [.mfu(0.06)],
          "FP16/BF16 math with FP32 master weights doubles tensor-core throughput."),
        r("pipeline", "Pipeline Parallelism", .systems, 2018.95, 300, ["transformer"],
          [.scaleOut(0.08), .mfu(0.01)],
          "GPipe (Nov 2018) and 1F1B schedules: split layers across chips and keep them all busy."),
        r("model_parallel", "Tensor Parallelism", .systems, 2019.7, 500, ["pipeline"],
          [.unlock(.modelParallel), .scaleOut(0.1)],
          "Megatron-LM (Sep 2019) splits matrix multiplies across a node, so one model can exceed one GPU's memory."),
        r("sharding", "ZeRO / FSDP Sharding", .systems, 2020.1, 700, ["model_parallel"],
          [.unlock(.sharding)],
          "Shard optimizer states, gradients and weights over every chip. Model size is limited only by total memory."),
        r("flash_attention", "FlashAttention", .systems, 2022.4, 900, ["transformer"],
          [.mfu(0.05), .throughput(0.1)],
          "IO-aware tiled attention (May 2022): never materialise the N×N matrix. 2–4× faster attention."),
        r("flash_attention3", "FlashAttention-3 Kernels", .systems, 2024.5, 1_800, ["flash_attention"],
          [.mfu(0.04), .throughput(0.08)],
          "Warp-specialised, asynchronous Hopper/Blackwell kernels reaching 75% of peak."),
        r("fp8_training", "FP8 Training", .systems, 2023.3, 2_000, ["mixed_precision"],
          [.unlock(.fp8Training)],
          "Transformer Engine (2023), proven at scale by DeepSeek-V3: 8-bit floating point with fine-grained scaling. ~2× throughput."),
        r("fp4_training", "FP4 / NVFP4 Training", .systems, 2025.6, 5_200, ["fp8_training"],
          [.unlock(.fp4Training)],
          "Micro-scaled 4-bit training on Blackwell-class hardware. Another ~2×, with a small quality cost."),
        r("checkpointing", "Fault Tolerance & Async Checkpointing", .systems, 2023.0, 1_000, ["sharding"],
          [.failureCost(0.70)],
          "At 16K GPUs something fails every ~3 hours (Llama 3: 419 unexpected interruptions in 54 days). Fast restarts keep goodput above 90%."),
        r("elastic", "Elastic Training & Hot Spares", .systems, 2024.15, 2_400, ["checkpointing"],
          [.failureCost(0.50), .scaleOut(0.05)],
          "MegaScale (Feb 2024): swap failed nodes without stopping the job. Interruptions cost minutes, not hours."),
        r("sdc_detection", "Silent Data Corruption Detection", .systems, 2024.5, 2_000, ["checkpointing"],
          [.bugGuard(0.30)],
          "Bit-flips that don't crash anything silently poison a run. Fleet-wide checksums catch them."),
        r("optical_net", "Rail-Optimised Scale-out Networking", .systems, 2022.6, 2_400, ["model_parallel"],
          [.scaleOut(0.3)],
          "Rail-optimised InfiniBand / RoCE fabrics and optical switches for 100K-chip clusters."),
        r("dualpipe", "DualPipe & Expert Parallelism", .systems, 2024.95, 3_200, ["moe", "pipeline"],
          [.mfu(0.03), .scaleOut(0.08)],
          "DeepSeek-V3: overlap computation with all-to-all expert communication. MoE stops being network-bound."),
        r("diloco", "Multi-Datacenter Training (DiLoCo)", .systems, 2024.6, 4_300, ["optical_net"],
          [.unlock(.multiSite), .scaleOut(0.2)],
          "Low-communication optimizers (DiLoCo, Nov 2023) let one run span several campuses."),
        r("custom_silicon", "Custom Accelerator Design", .systems, 2016.4, 2_000, [],
          [.unlock(.customSilicon)],
          "Google revealed the first TPU in 2016. Design your own AI chips with a silicon partner — unlocks the Custom Silicon lab."),
        r("immersion_cooling", "Immersion Cooling", .systems, 2023.5, 1_500, [],
          [.unlock(.immersion)],
          "Submerge servers in dielectric fluid. PUE drops to ~1.05."),

        // MARK: Data
        r("data_filtering", "Quality Filtering", .data, 2020.3, 350, [],
          [.dataAlgo(0.12)],
          "Classifier-based quality filters (C4, GPT-3, RefinedWeb). Throwing away bad text beats adding more of it."),
        r("dedup", "Deduplication", .data, 2021.55, 450, ["data_filtering"],
          [.dataAlgo(0.05), .safety(2), .contaminationGuard(0.2)],
          "\"Deduplicating Training Data Makes Language Models Better\" (Jul 2021): fewer memorised strings, better perplexity."),
        r("code_data", "Code Pre-training Corpus", .data, 2021.5, 600, ["data_filtering"],
          [.skill(.code, 0.04), .skill(.reasoning, 0.02)],
          "Large deduplicated GitHub corpora (Codex, The Stack) teach models to program — and to reason."),
        r("multilingual", "Multilingual Corpus", .data, 2021.0, 600, [],
          [.skill(.lang, 0.25), .consumerDemand(0.12), .apiDemand(0.08)],
          "Balanced data across 100+ languages opens global markets."),
        r("data_mixture", "Data Mixture Optimisation", .data, 2023.4, 1_300, ["dedup"],
          [.dataAlgo(0.08)],
          "DoReMi (May 2023): tune the ratio of web, code, math and books. Same tokens, better model."),
        r("decontamination", "Benchmark Decontamination", .data, 2023.5, 900, ["dedup"],
          [.contaminationGuard(0.6)],
          "Scrub test sets out of the training mix. Your scores mean something — and survive scrutiny."),
        r("math_corpus", "Math Web Corpora", .data, 2023.8, 1_400, ["data_filtering"],
          [.skill(.reasoning, 0.04)],
          "OpenWebMath / DeepSeekMath (2023–24): harvest every equation on the web. Math scores move."),
        r("edu_classifier", "Educational-Quality Classifiers", .data, 2024.4, 2_400, ["data_mixture"],
          [.dataAlgo(0.12), .skill(.reasoning, 0.02)],
          "Phi (Jun 2023) and FineWeb-Edu (May 2024): keep the textbook-quality pages. A 2–3× data-efficiency gain."),
        r("long_docs", "Long-Document Curation", .data, 2024.0, 1_600, ["long_context"],
          [.skill(.longctx, 0.08)],
          "Books, repos and transcripts packed into long sequences. Models learn to actually use their context."),
        r("synthetic_data", "Synthetic Data Pipelines", .data, 2024.0, 2_600, ["data_mixture"],
          [.unlock(.syntheticData), .dataAlgo(0.06), .dataTokens(0.5)],
          "Generate and verify textbook-quality data with your own models. The data wall moves. Set the synthetic share in the Model Lab.",
          tradeoff: "Too much unverified synthetic data causes model collapse."),
        r("data_flywheel", "Usage Data Flywheel", .data, 2023.0, 1_200, ["rlhf"],
          [.skill(.chat, 0.08), .apiDemand(0.05)],
          "Opt-in conversation data and thumbs-up/down feedback steer the next model."),

        // MARK: Post-training & alignment
        r("instruction_tuning", "Instruction Tuning", .postTraining, 2021.8, 400, ["transformer"],
          [.unlock(.chat), .skill(.chat, 0.85)],
          "FLAN / InstructGPT (2021–22): supervised fine-tuning turns a text predictor into an assistant."),
        r("rlhf", "RLHF", .postTraining, 2022.2, 1_100, ["instruction_tuning"],
          [.unlock(.rlhf), .skill(.chat, 0.45), .consumerDemand(0.15), .safety(5)],
          "Reinforcement learning from human preference rankings (InstructGPT, Mar 2022). The secret sauce of ChatGPT."),
        r("constitutional", "Constitutional AI / RLAIF", .postTraining, 2022.95, 1_700, ["rlhf"],
          [.safety(10), .postTrainCost(0.2), .skill(.chat, 0.05)],
          "Use AI feedback guided by written principles instead of only human labels (Dec 2022)."),
        r("dpo", "Direct Preference Optimization", .postTraining, 2023.4, 900, ["rlhf"],
          [.unlock(.dpo), .postTrainCost(0.25), .skill(.chat, 0.04)],
          "Rafailov et al. (May 2023): optimize preferences directly without a reward model. Cheaper and stabler."),
        r("llm_judges", "Reward Models & LLM Judges", .postTraining, 2023.45, 1_000, ["rlhf"],
          [.skill(.chat, 0.05), .postTrainCost(0.1)],
          "Judging LLM-as-a-judge (Jun 2023): strong models grade weaker ones at scale."),
        r("character", "Character Training", .postTraining, 2024.45, 1_800, ["constitutional"],
          [.skill(.chat, 0.07), .consumerDemand(0.06)],
          "Train a consistent personality: curious, honest, warm (2024). People like talking to it."),
        r("anti_sycophancy", "Anti-Sycophancy Training", .postTraining, 2024.0, 1_400, ["rlhf"],
          [.safety(4), .skill(.chat, 0.03)],
          "Stop the model telling people what they want to hear. Prevents embarrassing sycophantic launches."),
        r("deliberative", "Deliberative Alignment", .postTraining, 2024.95, 3_000, ["reasoning_rl", "constitutional"],
          [.safety(7)],
          "Teach reasoning models to think through a written spec before answering (Dec 2024)."),

        // MARK: Reasoning & RL
        r("cot", "Chain-of-Thought", .reasoning, 2022.1, 250, ["instruction_tuning"],
          [.skill(.reasoning, 0.05)],
          "\"Let's think step by step\" (Jan 2022). Showing work boosts math accuracy."),
        r("self_consistency", "Self-Consistency", .reasoning, 2022.25, 400, ["cot"],
          [.skill(.reasoning, 0.02)],
          "Sample many chains of thought and take a majority vote (Mar 2022)."),
        r("star", "Self-Taught Reasoner (STaR)", .reasoning, 2022.25, 500, ["cot"],
          [.skill(.reasoning, 0.02), .rl(0.03)],
          "Bootstrap reasoning by fine-tuning on the model's own correct rationales (Mar 2022)."),
        r("prm", "Process Reward Models", .reasoning, 2023.4, 1_800, ["star"],
          [.unlock(.prm), .rl(0.06)],
          "\"Let's Verify Step by Step\" (May 2023): reward each reasoning step, not just the answer."),
        r("reasoning_rl", "RL with Verifiable Rewards", .reasoning, 2024.7, 7_000, ["cot", "rlhf"],
          [.unlock(.reasoning), .rl(0.36)],
          "o1 / R1-style RL on checkable problems (Sep 2024). Models think for thousands of tokens. Choose RL compute in the Model Lab — gains grow log-linearly with it."),
        r("grpo", "GRPO", .reasoning, 2024.1, 2_600, ["star"],
          [.rlEfficiency(0.35), .rl(0.04)],
          "DeepSeekMath (Feb 2024): group-relative policy optimization drops the value network. RL gets much cheaper."),
        r("verifiers", "Verifiable Environments at Scale", .reasoning, 2025.4, 4_500, ["reasoning_rl"],
          [.rl(0.06), .skill(.code, 0.04)],
          "Thousands of auto-graded math, code and science environments. RL stops running out of problems."),
        r("long_cot_distill", "Long-CoT Distillation", .reasoning, 2025.05, 3_000, ["reasoning_rl", "distillation"],
          [.distill(0.2), .skill(.reasoning, 0.03)],
          "DeepSeek-R1 (Jan 2025): distilling a reasoner's traces into small models works shockingly well."),
        r("thinking_budget", "Hybrid Reasoning & Thinking Budgets", .reasoning, 2025.15, 3_200, ["reasoning_rl"],
          [.thinkingEfficiency(0.35), .apiDemand(0.08)],
          "Claude 3.7 (Feb 2025): one model that can answer instantly or think at length. Fewer wasted tokens."),
        r("rl_scaling", "RL Scaling Infrastructure", .reasoning, 2025.5, 6_000, ["verifiers"],
          [.unlock(.extremeRL), .rl(0.05), .rlEfficiency(0.1)],
          "Grok 4 (Jul 2025) spent roughly as much compute on RL as on pre-training. Unlocks the \"extreme\" RL setting."),

        // MARK: Agents & tools
        r("react", "ReAct Prompting", .agents, 2022.8, 450, ["cot"],
          [.skill(.agent, 0.03)],
          "Interleave reasoning and actions (Oct 2022). The first step toward agents."),
        r("tool_use", "Tool Use & Function Calling", .agents, 2023.45, 1_300, ["instruction_tuning"],
          [.unlock(.toolUse), .skill(.code, 0.03), .skill(.agent, 0.04), .enterpriseDemand(0.15)],
          "Structured function calls, retrieval and code execution (Jun 2023)."),
        r("code_interpreter", "Code Execution Sandboxes", .agents, 2023.5, 1_000, ["tool_use"],
          [.skill(.code, 0.03), .skill(.agent, 0.03)],
          "Let the model run its own code. Data analysis and math get reliable."),
        r("computer_use", "Computer Use", .agents, 2024.8, 3_600, ["tool_use", "vision"],
          [.unlock(.computerUse), .skill(.agent, 0.05)],
          "Claude computer use (Oct 2024), Operator (Jan 2025): see the screen, move the mouse, type."),
        r("mcp", "Tool Ecosystem Protocols", .agents, 2024.9, 2_000, ["tool_use"],
          [.skill(.agent, 0.03), .enterpriseDemand(0.1), .apiDemand(0.05)],
          "Model Context Protocol (Nov 2024): one standard to plug models into every tool and data source."),
        r("agents", "Agentic RL", .agents, 2025.1, 5_000, ["tool_use", "reasoning_rl"],
          [.unlock(.agents), .agentRL(0.15), .skill(.code, 0.05), .enterpriseDemand(0.4), .apiDemand(0.25)],
          "Long-horizon coding and computer-use agents trained with RL in sandboxes. Enable agentic RL in the Model Lab."),
        r("multi_agent", "Multi-Agent Orchestration", .agents, 2025.4, 3_800, ["agents"],
          [.skill(.agent, 0.04)],
          "Deep-research systems: an orchestrator spawning sub-agents in parallel."),
        r("long_horizon", "Long-Horizon Memory & Agents", .agents, 2025.6, 5_500, ["agents"],
          [.agentRL(0.08), .skill(.longctx, 0.03)],
          "Context management, notes and memory let agents work for hours (task horizons double every ~7 months)."),

        // MARK: Multimodal
        r("vision", "Vision-Language Models", .multimodal, 2023.2, 1_700, ["transformer"],
          [.unlock(.vision), .consumerDemand(0.1), .enterpriseDemand(0.05)],
          "Image encoders projected into the token stream (GPT-4V). Users paste screenshots and charts."),
        r("native_multimodal", "Native Multimodal Pre-training", .multimodal, 2023.95, 2_600, ["vision"],
          [.skill(.vis, 0.12), .consumerDemand(0.05)],
          "Gemini (Dec 2023): train on interleaved images, audio and text from the start."),
        r("audio", "Native Speech-to-Speech", .multimodal, 2024.37, 2_600, ["native_multimodal"],
          [.unlock(.audio), .consumerDemand(0.12)],
          "GPT-4o (May 2024): end-to-end audio tokens — real-time voice with emotion and interruptions."),
        r("video", "Video Generation (Diffusion Transformers)", .multimodal, 2024.15, 4_800, ["vision"],
          [.unlock(.video), .consumerDemand(0.15)],
          "Sora (Feb 2024): spacetime-patch diffusion transformers generate minute-long clips."),
        r("image_gen", "Native Image Generation", .multimodal, 2025.25, 3_000, ["native_multimodal"],
          [.unlock(.imageGen), .consumerDemand(0.15)],
          "GPT-4o images (Mar 2025): the language model draws, with perfect text rendering. A consumer phenomenon."),

        // MARK: Inference & serving
        r("int8_serving", "INT8 / FP8 Inference", .inference, 2022.6, 500, [],
          [.unlock(.int8Serving)],
          "LLM.int8() and SmoothQuant: serve in 8 bits at half the memory."),
        r("int4_serving", "4-bit Quantization", .inference, 2023.2, 1_300, ["int8_serving"],
          [.unlock(.int4Serving)],
          "GPTQ / AWQ / NVFP4 weights. A 70B model fits on a single 48 GB card."),
        r("continuous_batching", "Continuous Batching & PagedAttention", .inference, 2023.5, 1_000, ["transformer"],
          [.throughput(0.6)],
          "vLLM (Jun 2023): paged KV memory and iteration-level scheduling. Several times more throughput."),
        r("speculative", "Speculative Decoding", .inference, 2023.1, 1_300, ["transformer"],
          [.tps(0.6)],
          "A draft model proposes, the big one verifies in parallel. 2–3× faster per user."),
        r("eagle", "EAGLE Draft Heads", .inference, 2024.1, 1_600, ["speculative"],
          [.tps(0.25)],
          "Feature-level draft heads (Jan 2024) push speculative decoding to 3–4×."),
        r("kv_quant", "KV-Cache Quantization", .inference, 2024.2, 1_500, ["int8_serving"],
          [.kvMemory(0.25)],
          "Store the KV cache in 4–8 bits: longer contexts and bigger batches on the same chips."),
        r("disaggregation", "Prefill/Decode Disaggregation", .inference, 2024.3, 2_400, ["continuous_batching"],
          [.throughput(0.3)],
          "Run prompt processing and generation on separate pools (DistServe, Dynamo)."),
        r("prompt_caching", "Prompt Caching", .inference, 2024.6, 1_200, ["continuous_batching"],
          [.throughput(0.15), .apiDemand(0.1)],
          "Reuse KV caches for repeated prefixes; agents and chat history get 90% cheaper."),
        r("distillation", "Knowledge Distillation", .inference, 2023.6, 1_300, ["instruction_tuning"],
          [.unlock(.distillation), .distill(0.15)],
          "Train small, cheap models on a big model's outputs. Unlocks \"Distill\" in the Model Lab."),

        // MARK: Safety & interpretability
        r("red_teaming", "Red-Teaming Program", .safety, 2022.5, 700, [],
          [.safety(12)],
          "Adversarial testing before launch. Fewer viral jailbreaks."),
        r("evals_rsp", "Dangerous-Capability Evals (RSP)", .safety, 2023.7, 1_700, ["red_teaming"],
          [.safety(14), .enterpriseDemand(0.1)],
          "Scaling policies with bio/cyber/autonomy evals. Required by the EU AI Act for frontier models."),
        r("unlearning", "Hazardous-Knowledge Unlearning", .safety, 2024.2, 1_900, ["evals_rsp"],
          [.safety(6)],
          "WMDP / RMU (Mar 2024): remove bioweapon and cyberweapon know-how while keeping general skill."),
        r("interpretability", "Mechanistic Interpretability", .safety, 2024.4, 2_900, ["evals_rsp"],
          [.safety(14), .enterpriseDemand(0.05), .bugGuard(0.1)],
          "Sparse autoencoders find millions of human-readable features inside your model (May 2024)."),
        r("constitutional_classifiers", "Constitutional Classifiers", .safety, 2025.1, 3_000, ["constitutional"],
          [.safety(8)],
          "Input/output classifiers trained on a constitution (Feb 2025): universal jailbreaks become rare."),
        r("cot_monitoring", "Chain-of-Thought Monitoring", .safety, 2025.2, 3_200, ["reasoning_rl"],
          [.safety(6)],
          "Read the model's reasoning to catch reward hacking and scheming. RL runs flag cheating before it ships."),
        r("watermarking", "Text Watermarking", .safety, 2024.8, 1_200, [],
          [.safety(2), .consumerDemand(0.02)],
          "SynthID-style statistical watermarks (Oct 2024): provenance for generated text."),
        r("scalable_oversight", "Scalable Oversight", .safety, 2026.5, 8_500, ["interpretability"],
          [.safety(18)],
          "Use weaker trusted models to supervise stronger ones. Needed as capabilities race ahead."),
        r("ai_control", "AI Control & Sandboxing", .safety, 2026.9, 7_000, ["scalable_oversight"],
          [.safety(10), .unlock(.aiControl)],
          "Trusted monitors, sandboxes and tripwires around untrusted models. Self-improvement runs drift 35% less and get caught faster."),

        // MARK: Frontier (speculative future)
        r("continual_learning", "Continual Learning", .frontier, 2027.3, 12_000, ["agents"],
          [.algo(0.10), .skill(.agent, 0.06)],
          "Models that keep learning after deployment without catastrophic forgetting."),
        r("world_models", "World Models", .frontier, 2027.8, 16_000, ["video"],
          [.algo(0.08), .skill(.vis, 0.1), .consumerDemand(0.15)],
          "Learned simulators of the physical world for robotics and planning."),
        r("auto_research", "Automated AI Research", .frontier, 2028.3, 25_000, ["continual_learning"],
          [.rp(1.0), .algo(0.08), .forecast(0.4), .unlock(.autoResearch)],
          "Your agents run experiments around the clock. Research doubles, forecasts sharpen, and the Self-Improvement Lab opens."),
        r("unified_arch", "Unified Cognitive Architecture", .frontier, 2029.0, 50_000, ["auto_research", "world_models"],
          [.algo(0.25), .rl(0.1)],
          "Memory, planning and perception in one trainable system."),
        r("rsi", "Recursive Self-Improvement", .frontier, 2030.0, 90_000, ["unified_arch", "scalable_oversight"],
          [.algo(0.4), .rp(1.0), .unlock(.rsi)],
          "Models that improve their own training. Unlocks capability runs and full autonomy in the Self-Improvement Lab. Handle with extreme care."),
    ]

    // MARK: - Unique breakthroughs (each lab gets a few; nobody gets them all)

    static let exotic: [ResearchItem] = [
        r("x_diffusion_lm", "Diffusion Language Models", .exotic, 2025.1, 4_500, ["transformer"],
          [.unlock(.diffusionLM), .tps(1.5), .throughput(0.4)],
          "LLaDA / Mercury (2025): generate whole passages by iterative denoising instead of one token at a time. Pick the Diffusion architecture in the Model Lab.",
          tradeoff: "5–10× faster decoding, but a diffusion model gives up some quality and reasoning.",
          rival: RivalBoost(c: -0.05, tps: 4, price: 0.7)),
        r("x_latent_reasoning", "Latent-Space Reasoning", .exotic, 2025.0, 5_500, ["reasoning_rl"],
          [.unlock(.latentReasoning), .thinkingEfficiency(0.5), .skill(.reasoning, 0.08), .safety(-6)],
          "Coconut (Dec 2024): reason in continuous hidden states instead of words. Far fewer thinking tokens.",
          tradeoff: "You can't read thoughts that aren't words: −6 safety, harder to monitor.",
          rival: RivalBoost(c: 0.04, reasoning: 0.1, price: 0.85)),
        r("x_looped_depth", "Recurrent-Depth Transformers", .exotic, 2025.1, 5_000, ["transformer"],
          [.unlock(.loopedDepth), .skill(.reasoning, 0.12), .throughput(-0.15)],
          "Huginn (Feb 2025): loop a block many times at inference — more thinking without more parameters.",
          tradeoff: "Each answer costs more compute to serve (−15% throughput).",
          rival: RivalBoost(c: 0.03, reasoning: 0.12, tps: 0.85)),
        r("x_ttt_layers", "Test-Time Training Layers", .exotic, 2024.55, 4_800, ["long_context"],
          [.skill(.longctx, 0.4), .stability(-0.12)],
          "TTT layers (Jul 2024): the hidden state is itself a small model trained on the context as you read it.",
          tradeoff: "Inner-loop training makes runs less stable.",
          rival: RivalBoost(longctx: 0.4)),
        r("x_titans", "Neural Long-Term Memory", .exotic, 2025.0, 5_200, ["long_context"],
          [.skill(.longctx, 0.3), .skill(.agent, 0.06)],
          "Titans (Jan 2025): a memory module that learns what to remember at test time. Agents that don't forget.",
          rival: RivalBoost(agent: 0.08, longctx: 0.3)),
        r("x_hyper_connections", "Hyper-Connections", .exotic, 2024.75, 3_600, ["modern_block"],
          [.algo(0.06), .stability(0.08)],
          "Replace residual connections with learned multi-stream mixing (Sep 2024). Free quality.",
          rival: RivalBoost(c: 0.06)),
        r("x_model_merging", "Evolutionary Model Merging", .exotic, 2024.2, 3_000, ["distillation"],
          [.distill(0.15), .skill(.lang, 0.12)],
          "Sakana (Mar 2024): breed new models by evolving merges of existing ones — no training needed.",
          rival: RivalBoost(c: 0.02, lang: 0.15, price: 0.85)),
        r("x_absolute_zero", "Self-Play Reasoning from Zero Data", .exotic, 2025.35, 6_000, ["reasoning_rl"],
          [.rl(0.15), .rlEfficiency(0.2), .safety(-3)],
          "Absolute Zero (May 2025): the model invents its own problems and learns to solve them. No human data.",
          tradeoff: "Self-generated curricula reward-hack more often (−3 safety).",
          rival: RivalBoost(c: 0.03, reasoning: 0.15, code: 0.05)),
        r("x_bitnet", "Ternary 1.58-bit Networks", .exotic, 2024.15, 4_200, ["int4_serving"],
          [.tps(0.6), .throughput(0.6), .algo(-0.06)],
          "BitNet b1.58 (Feb 2024): weights in {−1, 0, +1}. Matrix multiplies become additions.",
          tradeoff: "Ternary models need more training compute for the same quality.",
          rival: RivalBoost(c: -0.04, tps: 2, price: 0.5)),
        r("x_byte_latent", "Tokenizer-free Byte Latent Models", .exotic, 2024.95, 4_400, ["transformer"],
          [.skill(.lang, 0.25), .algo(0.03), .mfu(-0.03)],
          "Byte Latent Transformer (Dec 2024): dynamic byte patches replace tokenizers. Every language and script on equal footing.",
          rival: RivalBoost(c: 0.02, lang: 0.3)),
        r("x_memory_layers", "Memory Layers at Scale", .exotic, 2024.95, 4_600, ["moe"],
          [.algo(0.07), .mfu(-0.02)],
          "Trainable key-value lookup layers (Dec 2024): store far more facts per FLOP. Factuality jumps.",
          rival: RivalBoost(c: 0.06)),
        r("x_energy_reasoning", "Energy-Based Reasoning", .exotic, 2026.5, 9_000, ["reasoning_rl"],
          [.skill(.reasoning, 0.2), .rl(0.08), .throughput(-0.2)],
          "Score whole candidate solutions with a learned energy function and optimise toward the best one. System-2 thinking, natively.",
          tradeoff: "Optimisation at inference is expensive (−20% throughput).",
          rival: RivalBoost(c: 0.05, reasoning: 0.2, tps: 0.8)),
        r("x_world_sim", "World-Simulator Pre-training", .exotic, 2027.2, 14_000, ["video"],
          [.algo(0.18), .skill(.agent, 0.1), .skill(.vis, 0.15)],
          "Pre-train on predicting the physical world, not just text. Agents gain intuition for cause and effect.",
          rival: RivalBoost(c: 0.12, agent: 0.12)),
        r("x_neuromorphic", "Neuromorphic Sparse Inference", .exotic, 2028.0, 18_000, ["custom_silicon"],
          [.throughput(1.0), .tps(0.5), .algo(-0.04)],
          "Event-driven spiking execution: only the neurons that change do any work. Serving gets absurdly cheap.",
          tradeoff: "Spiking conversion loses a little quality.",
          rival: RivalBoost(tps: 1.5, price: 0.4)),
        r("x_holographic", "Holographic Weight Compression", .exotic, 2029.0, 26_000, ["x_bitnet"],
          [.kvMemory(0.5), .throughput(0.5), .tps(0.3)],
          "Store weights as interference patterns in a compressed basis. Models run in a quarter of the memory.",
          rival: RivalBoost(tps: 1.4, price: 0.6)),
        r("x_quantum_routing", "Quantum-Annealed Expert Routing", .exotic, 2030.0, 40_000, ["fine_moe"],
          [.moeAlgo(0.3), .mfu(-0.05)],
          "Solve the expert-assignment problem for whole batches at once on annealing hardware.",
          tradeoff: "Coordination overhead costs MFU.",
          rival: RivalBoost(c: 0.15)),
        r("x_thermodynamic", "Thermodynamic Sampling Chips", .exotic, 2026.8, 10_000, ["custom_silicon"],
          [.throughput(0.35), .tps(0.2)],
          "Probabilistic hardware that samples from distributions physically. Generation energy plummets.",
          rival: RivalBoost(tps: 1.3, price: 0.7)),
        r("x_photonic", "Photonic Interconnect Fabric", .exotic, 2026.5, 9_500, ["optical_net"],
          [.scaleOut(0.4), .unlock(.multiSite)],
          "Co-packaged optics on every chip: a million accelerators behave like one.",
          rival: RivalBoost(c: 0.05)),
        r("x_recursive_distill", "Recursive Self-Distillation", .exotic, 2027.0, 12_000, ["long_cot_distill"],
          [.distill(0.3), .algo(0.05)],
          "Each generation teaches the next, smaller and sharper. Students overtake teachers.",
          rival: RivalBoost(c: 0.05, price: 0.8)),
        r("x_grokking", "Grokking Schedules", .exotic, 2026.2, 7_500, ["wsd"],
          [.skill(.reasoning, 0.1), .algo(0.03)],
          "Train far past convergence with tuned weight decay until memorisation flips into generalisation.",
          rival: RivalBoost(c: 0.02, reasoning: 0.1)),
        r("x_persona_societies", "Synthetic Agent Societies", .exotic, 2027.0, 13_000, ["multi_agent"],
          [.agentRL(0.2), .skill(.chat, 0.1)],
          "Train agents inside simulated companies full of other agents. Collaboration skills emerge.",
          rival: RivalBoost(agent: 0.2, chat: 0.1)),
        r("x_crosscoders", "Crosscoder Model Diffing", .exotic, 2025.6, 5_500, ["interpretability"],
          [.safety(12), .bugGuard(0.3)],
          "Compare models feature-by-feature to see exactly what training changed. Bugs and hidden goals show up early.",
          rival: RivalBoost(chat: 0.05)),
        r("x_lattice_optimizer", "Lattice Second-Order Optimizer", .exotic, 2029.0, 30_000, ["muon"],
          [.algo(0.35), .stability(-0.25)],
          "An optimizer that solves for the curvature of the whole loss landscape at once. Enormous gains — when it doesn't diverge.",
          tradeoff: "Very unstable: −25% stability.",
          rival: RivalBoost(c: 0.2)),
        r("x_oracle_data", "Oracle Data Selection", .exotic, 2026.0, 8_000, ["edu_classifier"],
          [.dataAlgo(0.15)],
          "Influence functions pick, for every gradient step, the single most useful document left.",
          rival: RivalBoost(c: 0.1)),
    ]

    static let byID: [String: ResearchItem] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    // MARK: Aggregation

    nonisolated(unsafe) private static var bonusCache: (Set<String>, [String: Double], ResearchBonuses)? = nil

    static func bonuses(_ researched: Set<String>, results: [String: Double] = [:]) -> ResearchBonuses {
        if let c = bonusCache, c.0 == researched, c.1 == results { return c.2 }
        let b = computeBonuses(researched, results: results)
        bonusCache = (researched, results, b)
        return b
    }

    private static func computeBonuses(_ researched: Set<String>, results: [String: Double]) -> ResearchBonuses {
        var b = ResearchBonuses()
        b.results = results
        b.researched = researched
        for id in researched {
            guard let item = byID[id] else { continue }
            let q = results[id] ?? 1
            for e in item.effects {
                let v: (Double) -> Double = { $0 * q }
                switch e {
                case .algo(let x): b.algo += v(x)
                case .dataAlgo(let x): b.dataAlgo += v(x)
                case .moeAlgo(let x): b.moeAlgo += v(x)
                case .muonAlgo(let x): b.muonAlgo += v(x)
                case .shampooAlgo(let x): b.shampooAlgo += v(x)
                case .skill(let d, let x):
                    // Instruction tuning and RLHF only shape a model when its design actually runs those stages.
                    if d == .chat && (id == "instruction_tuning" || id == "rlhf") { continue }
                    b.skills[d, default: 0] += v(x)
                case .rl(let x): b.rl += v(x)
                case .rlEfficiency(let x): b.rlEfficiency += v(x)
                case .agentRL(let x): b.agentRL += v(x)
                case .distill(let x): b.distill += v(x)
                case .thinkingEfficiency(let x): b.thinkingEfficiency += v(x)
                case .stability(let x): b.stability += v(x)
                case .forecast(let x): b.forecastKeep *= max(0.05, 1 - min(0.9, v(x)))
                case .failureCost(let x): b.failureKeep *= max(0.05, 1 - min(0.9, v(x)))
                case .bugGuard(let x): b.bugKeep *= max(0.05, 1 - min(0.9, v(x)))
                case .contaminationGuard(let x): b.contaminationKeep *= max(0.05, 1 - min(0.9, v(x)))
                case .mfu(let x): b.mfu += v(x)
                case .throughput(let x): b.throughput += v(x)
                case .tps(let x): b.tps += v(x)
                case .kvMemory(let x): b.kvMemory += v(x)
                case .scaleOut(let x): b.scaleOut += v(x)
                case .postTrainCost(let x): b.postTrainCost += v(x)
                case .rp(let x): b.rp += v(x)
                case .dataTokens(let x): b.dataTokens += v(x)
                case .safety(let x): b.safety += v(x)
                case .consumerDemand(let x): b.consumerDemand += x
                case .apiDemand(let x): b.apiDemand += x
                case .enterpriseDemand(let x): b.enterpriseDemand += x
                case .unlock(let f): b.features.insert(f)
                }
            }
        }
        b.postTrainCost = min(b.postTrainCost, 0.7)
        b.kvMemory = min(b.kvMemory, 0.85)
        b.scaleOut = min(b.scaleOut, 0.85)
        b.rlEfficiency = min(b.rlEfficiency, 0.8)
        b.thinkingEfficiency = min(b.thinkingEfficiency, 0.8)
        b.stability = clamp(b.stability, -0.5, 0.9)
        b.throughput = max(-0.5, b.throughput)
        return b
    }

    // MARK: Text

    static func describe(_ e: ResearchEffect, r: Double = 1) -> String {
        func x(_ v: Double) -> String { "×\(Fmt.trim(pow(10, v * r), 2))" }
        func pct(_ v: Double) -> String { "\(v * r >= 0 ? "+" : "−")\(Int(abs(v * r) * 100))%" }
        switch e {
        case .algo(let v): return "\(x(v)) effective training compute"
        case .dataAlgo(let v): return "\(x(v)) data efficiency"
        case .moeAlgo(let v): return "\(x(v)) effective compute for MoE models"
        case .muonAlgo(let v): return "\(x(v)) effective compute with the Muon optimizer"
        case .shampooAlgo(let v): return "\(x(v)) effective compute with second-order optimizers"
        case .skill(let d, let v): return "\(v * r >= 0 ? "+" : "−")\(Fmt.trim(abs(v * r), 2)) \(d.label)"
        case .rl(let v): return "+\(Fmt.trim(v * r, 2)) RL reasoning strength"
        case .rlEfficiency(let v): return "\(pct(v)) cheaper RL"
        case .agentRL(let v): return "+\(Fmt.trim(v * r, 2)) agentic RL strength"
        case .distill(let v): return "\(pct(v)) distillation quality"
        case .thinkingEfficiency(let v): return "\(pct(v)) fewer thinking tokens"
        case .stability(let v): return v >= 0 ? "\(Int(v * r * 100))% fewer loss spikes" : "\(Int(-v * r * 100))% more loss spikes"
        case .forecast(let v): return "\(Int(min(0.9, v * r) * 100))% tighter forecasts"
        case .failureCost(let v): return "\(Int(min(0.9, v * r) * 100))% less time lost per hardware failure"
        case .bugGuard(let v): return "\(Int(min(0.9, v * r) * 100))% fewer silent training bugs"
        case .contaminationGuard(let v): return "\(Int(min(0.9, v * r) * 100))% fewer contamination incidents"
        case .mfu(let v): return "\(v >= 0 ? "+" : "−")\(Int(abs(v * r) * 100)) pts training MFU"
        case .throughput(let v): return "\(pct(v)) inference throughput"
        case .tps(let v): return "\(pct(v)) tokens/sec per user"
        case .kvMemory(let v): return "−\(Int(v * r * 100))% KV-cache memory"
        case .scaleOut(let v): return "−\(Int(v * r * 100))% large-cluster scaling loss"
        case .postTrainCost(let v): return "−\(Int(v * r * 100))% post-training cost"
        case .rp(let v): return "+\(Int(v * r * 100))% research speed"
        case .dataTokens(let v): return "+\(Int(v * r * 100))% usable training tokens"
        case .safety(let v): return "\(v >= 0 ? "+" : "−")\(Int(abs(v * r))) safety"
        case .consumerDemand(let v): return "+\(Int(v * 100))% consumer demand"
        case .apiDemand(let v): return "+\(Int(v * 100))% API demand"
        case .enterpriseDemand(let v): return "+\(Int(v * 100))% enterprise deal flow"
        case .unlock(let f): return "Unlocks: \(featureName(f))"
        }
    }

    static func featureName(_ f: Feature) -> String {
        switch f {
        case .transformer: "Transformer models"
        case .moe: "Mixture-of-Experts"
        case .fineMoE: "Fine-grained experts (1/32, 1/64)"
        case .gqa: "Grouped-query attention"
        case .mla: "Multi-head latent attention"
        case .ssmHybrid: "Hybrid SSM architecture"
        case .diffusionLM: "Diffusion LM architecture"
        case .mtp: "Multi-token prediction"
        case .muon: "Muon optimizer"
        case .shampoo: "Shampoo/SOAP optimizer"
        case .wsd: "WSD learning-rate schedule"
        case .muP: "μP hyperparameter transfer"
        case .proxyLadder: "Scaling ladder (derisking runs)"
        case .curriculum: "Annealing stage"
        case .fp8Training: "FP8 training"
        case .fp4Training: "FP4 training"
        case .int8Serving: "8-bit serving"
        case .int4Serving: "4-bit serving"
        case .context32k: "32K context"
        case .context128k: "128K context"
        case .context1m: "1M context"
        case .vision: "Vision input"
        case .audio: "Voice mode"
        case .video: "Video generation"
        case .imageGen: "Image generation"
        case .chat: "Chat assistants"
        case .rlhf: "RLHF"
        case .dpo: "DPO preference tuning"
        case .reasoning: "Reasoning RL"
        case .prm: "Process reward models"
        case .extremeRL: "Extreme RL compute"
        case .toolUse: "Tool use"
        case .agents: "Agentic RL"
        case .computerUse: "Computer use"
        case .distillation: "Distillation"
        case .modelParallel: "Models larger than one GPU"
        case .sharding: "Fully sharded training"
        case .scalingLaws: "Capability forecasts"
        case .immersion: "Immersion-cooled sites"
        case .multiSite: "Multi-site training"
        case .syntheticData: "Synthetic data"
        case .autoResearch: "Self-Improvement Lab (research & efficiency)"
        case .rsi: "Capability self-improvement & full autonomy"
        case .aiControl: "AI control safeguards"
        case .customSilicon: "Custom Silicon lab"
        case .latentReasoning: "Latent reasoning"
        case .loopedDepth: "Recurrent depth"
        }
    }
}
