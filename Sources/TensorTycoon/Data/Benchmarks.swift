import Foundation

enum BenchKind: String, Codable, Sendable, CaseIterable {
    case knowledge, reasoning, math, code, agentic, multimodal, longContext, science
    case instruction, multilingual, safety, dangerous, speech

    var label: String {
        switch self {
        case .knowledge: "Knowledge"
        case .reasoning: "Reasoning"
        case .math: "Math"
        case .code: "Coding"
        case .agentic: "Agents"
        case .multimodal: "Multimodal"
        case .longContext: "Long context"
        case .science: "Science"
        case .instruction: "Instruction following"
        case .multilingual: "Multilingual"
        case .safety: "Safety"
        case .dangerous: "Dangerous capabilities"
        case .speech: "Speech"
        }
    }

    var symbol: String {
        switch self {
        case .knowledge: "books.vertical.fill"
        case .reasoning: "brain"
        case .math: "function"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .agentic: "figure.walk.motion"
        case .multimodal: "eye.fill"
        case .longContext: "text.page.fill"
        case .science: "atom"
        case .instruction: "text.bubble.fill"
        case .multilingual: "globe"
        case .safety: "checkmark.shield.fill"
        case .dangerous: "exclamationmark.triangle.fill"
        case .speech: "waveform"
        }
    }

    /// Kinds that count toward the Intelligence Index (text capability, like real indices).
    var inIndex: Bool {
        switch self {
        case .multimodal, .longContext, .safety, .dangerous, .speech: false
        default: true
        }
    }

    /// The effective capability (log10 compute units) this kind of benchmark tests, or nil if the model can't attempt it.
    func x(_ p: ModelProfile) -> Double? {
        switch self {
        case .knowledge: return p.c
        case .reasoning, .science: return p.c + p.reasoning
        case .math: return p.c + p.reasoning * 1.1
        case .code: return p.c + p.code + 0.6 * p.reasoning
        case .agentic: return p.agenticX
        case .multimodal: return p.vision ? p.c + 0.2 * p.reasoning + p.vis : nil
        case .longContext:
            let bonus = p.contextK >= 1000 ? 0.5 : (p.contextK >= 128 ? 0.0 : (p.contextK >= 32 ? -1.0 : -3.0))
            return p.c + bonus + p.longctx
        case .instruction: return p.c + p.chat
        case .multilingual: return p.c + 0.3 * p.reasoning + p.lang
        case .safety: return 0.35 * p.c + p.safety / 12 + 0.3 * p.chat
        case .dangerous: return p.c + 0.6 * p.reasoning + 0.3 * p.code + 0.3 * p.agent
        case .speech: return p.audio ? p.c + 0.3 * p.reasoning + 0.5 * p.chat : nil
        }
    }
}

/// What a model brings to a benchmark. Everything is in "effective capability" units (log10 compute),
/// except `safety` (0–100).
struct ModelProfile: Sendable, Hashable {
    var key: String
    var c: Double
    var reasoning: Double
    var code: Double
    var agent: Double
    var vision: Bool
    var contextK: Int
    var tuning: Double
    var chat: Double = 0.8
    var safety: Double = 50
    var lang: Double = 0
    var longctx: Double = 0
    var vis: Double = 0
    var audio: Bool = false

    /// Effective capability on agentic, long-horizon work.
    var agenticX: Double { c + 0.7 * reasoning + 0.5 * code + agent }
}

/// A benchmark: scores follow a sigmoid in effective capability, calibrated to real results
/// (e.g. GPT-3-class ≈ 44% MMLU, GPT-4 ≈ 86% MMLU / 36% GPQA, late-2025 frontier ≈ 45% ARC-AGI-2).
struct Benchmark: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var family: String
    var kind: BenchKind
    var introduced: YM
    var floor: Double
    var ceiling: Double
    var mid: Double
    var scale: Double
    var saturation: Double
    var about: String
    var human: String
    var generated: Bool = false
    var unit: String = "%"
    /// Only on an Intelligence Index slot while this benchmark phases in (never in the catalogue or a save).
    var blend: IndexBlend? = nil

    static func ordinal(_ n: Int) -> String {
        let suffix = (11...13).contains(n % 100) ? "th" : (n % 10 == 1 ? "st" : n % 10 == 2 ? "nd" : n % 10 == 3 ? "rd" : "th")
        return "\(n)\(suffix)"
    }

    func x(_ p: ModelProfile) -> Double? { kind.x(p) }

    /// The score as it counts toward the Intelligence Index. The same as `ownScore`, except on an index slot whose
    /// benchmark is still phasing in: there it is blended with what the slot measured before, so the index glides
    /// instead of jumping when its set changes. Anything that averages an index set over `score` stays consistent.
    func score(_ p: ModelProfile, noise: Bool = true) -> Double {
        let own = ownScore(p, noise: noise)
        guard let bl = blend, bl.t < 1 else { return own }
        var before = 0.0
        for (b, w) in zip(bl.from, bl.weights) { before += w * b.ownScore(p, noise: noise) }
        return ((before + (own - before) * max(0, bl.t)) * 10).rounded() / 10
    }

    /// This benchmark's own score. Deterministic: same model + benchmark always gives the same number.
    func ownScore(_ p: ModelProfile, noise: Bool = true) -> Double {
        guard let x = x(p) else { return floor }
        var s = floor + (ceiling - floor) * sigmoid((x - mid) / scale)
        if noise {
            let u = BenchmarkCatalog.hashUnit(p.key, id)
            let edge = 1 - abs(2 * (s - floor) / max(ceiling - floor, 1) - 1)
            s += (u - 0.5) * 4.0 * (0.3 + 0.7 * edge)
        }
        if kind != .safety && kind != .dangerous { s += p.tuning * (ceiling - floor) * 0.04 }
        return (clamp(s, floor * 0.95, ceiling) * 10).rounded() / 10
    }

    /// A ceiling on `ownScore` that skips the hashing: noise moves a score by at most 2 points and rounding by 0.05.
    /// Lets a scan rule out models that can't reach a threshold before looking up exact scores.
    func scoreBound(_ p: ModelProfile) -> Double {
        guard let x = x(p) else { return floor }
        var s = floor + (ceiling - floor) * sigmoid((x - mid) / scale) + 2
        if kind != .safety && kind != .dangerous { s += p.tuning * (ceiling - floor) * 0.04 }
        return max(floor * 0.95, min(s, ceiling)) + 0.05
    }

    func isActive(_ date: Date, saturated: [String: Date]) -> Bool {
        introduced <= date.ym && saturated[id] == nil
    }

    func format(_ v: Double) -> String {
        switch unit {
        case "%": "\(Fmt.score(v))%"
        case "pctl": "\(Self.ordinal(Int(v.rounded()))) pctl"
        case "/100": "\(Fmt.trim(v / 10, 1))/10"
        default: "\(Fmt.score(v)) \(unit)"
        }
    }
}

/// How far a benchmark has phased into its Intelligence Index slot.
struct IndexBlend: Codable, Hashable, Sendable {
    /// What the slot measured before: the benchmark it replaced, or (when the index grew) a snapshot of the whole set.
    var from: [Benchmark]
    var weights: [Double]
    /// Share of the incoming benchmark, 0 → 1.
    var t: Double
    /// When it counts fully.
    var full: Date
}

struct BenchFamily: Sendable {
    let id: String
    let name: String
    let regenerates: Bool
    let successor: @Sendable (Int) -> String
}

enum BenchmarkCatalog {
    private static func b(_ id: String, _ name: String, _ family: String, _ kind: BenchKind, _ intro: YM,
                          floor: Double = 0, ceil: Double = 100, mid: Double, scale: Double, sat: Double = 90, unit: String = "%",
                          _ about: String, human: String = "—") -> Benchmark {
        Benchmark(id: id, name: name, family: family, kind: kind, introduced: intro, floor: floor, ceiling: ceil,
                  mid: mid, scale: scale, saturation: sat, about: about, human: human, unit: unit)
    }

    static let real: [Benchmark] = [
        // Early NLP era
        b("lambada", "LAMBADA", "reading", .knowledge, YM(2016, 6), ceil: 92, mid: -2.2, scale: 2.9, sat: 86,
          "Predict the final word of a passage — needs long-range context.", human: "~86%"),
        b("squad", "SQuAD 1.1", "reading", .knowledge, YM(2016, 6), ceil: 95, mid: -2.77, scale: 0.667, sat: 91,
          "Answer questions by highlighting spans of Wikipedia articles.", human: "91.2 F1"),
        b("glue", "GLUE", "glue", .knowledge, YM(2018, 4), floor: 30, ceil: 95, mid: -1.51, scale: 1.05, sat: 88,
          "Nine sentence-understanding tasks. Beaten within a year.", human: "87.1"),
        b("drop", "DROP", "reading", .knowledge, YM(2019, 3), ceil: 95, mid: 3.29, scale: 1.036, sat: 90,
          "Reading comprehension that needs counting, sorting and arithmetic.", human: "96.4 F1"),
        b("superglue", "SuperGLUE", "glue", .knowledge, YM(2019, 5), floor: 30, ceil: 95, mid: 0.0, scale: 0.88, sat: 89.8,
          "Harder successor to GLUE.", human: "89.8"),
        b("hellaswag", "HellaSwag", "commonsense", .knowledge, YM(2019, 5), floor: 25, ceil: 96, mid: 1.17, scale: 1.42, sat: 95,
          "Commonsense sentence completion with adversarial wrong endings.", human: "95.6%"),
        b("winogrande", "WinoGrande", "commonsense", .knowledge, YM(2019, 7), floor: 50, ceil: 95, mid: 3.06, scale: 1.267,
          "Pronoun resolution needing world knowledge, 44K problems.", human: "94%"),
        // Knowledge & reasoning
        b("mmlu", "MMLU", "mmlu", .knowledge, YM(2020, 9), floor: 25, ceil: 93, mid: 3.46, scale: 0.71,
          "57 subjects from law to physics, multiple choice.", human: "~89.8% (experts)"),
        b("bbh", "BIG-Bench Hard", "bbh", .reasoning, YM(2022, 10), floor: 25, ceil: 95, mid: 3.73, scale: 0.93,
          "The 23 hardest BIG-Bench tasks, where models first beat humans with chain-of-thought."),
        b("gpqa", "GPQA Diamond", "gpqa", .reasoning, YM(2023, 11), floor: 25, ceil: 96, mid: 5.96, scale: 0.504,
          "Google-proof PhD-level biology, chemistry and physics questions.", human: "~65% (PhD experts)"),
        b("mmlu_pro", "MMLU-Pro", "mmlu", .knowledge, YM(2024, 6), floor: 10, ceil: 92, mid: 4.39, scale: 1.07,
          "Harder 10-option successor to MMLU."),
        b("simplebench", "SimpleBench", "simplebench", .reasoning, YM(2024, 9), mid: 6.82, scale: 0.943, sat: 85,
          "Trick questions about space, time and social situations that people find easy.", human: "83.7%"),
        b("simpleqa", "SimpleQA", "factuality", .knowledge, YM(2024, 10), mid: 6.18, scale: 1.186,
          "Short fact-seeking questions — measures hallucination."),
        b("hle", "Humanity's Last Exam", "hle", .reasoning, YM(2025, 1), mid: 8.27, scale: 0.638,
          "2,500 expert-written questions at the frontier of human knowledge."),
        // Math
        b("gsm8k", "GSM8K", "school_math", .math, YM(2021, 10), ceil: 97, mid: 3.82, scale: 0.566, sat: 92,
          "Grade-school math word problems."),
        b("math", "MATH", "school_math", .math, YM(2021, 3), ceil: 99, mid: 5.23, scale: 0.43,
          "12,500 competition mathematics problems.", human: "90% (IMO medalist)"),
        b("aime", "AIME", "olympiad", .math, YM(2024, 2), mid: 6.12, scale: 0.284,
          "American Invitational Mathematics Examination (integer answers).", human: "Top students ~33%"),
        b("hmmt", "HMMT Feb 2025", "olympiad", .math, YM(2025, 2), mid: 7.0, scale: 0.30,
          "Harvard-MIT Math Tournament problems, harder than AIME."),
        b("usamo", "USAMO 2025 (proofs)", "olympiad", .math, YM(2025, 3), mid: 7.6, scale: 0.25,
          "Full written proofs graded by mathematicians."),
        b("imo", "IMO 2025", "olympiad", .math, YM(2025, 7), mid: 7.3, scale: 0.30,
          "International Math Olympiad problems; ~83% is a gold medal.", human: "Gold ≈ 83%"),
        b("frontiermath", "FrontierMath T1–3", "frontiermath", .math, YM(2024, 11), mid: 8.14, scale: 0.6,
          "Unpublished research-grade problems from expert mathematicians."),
        b("frontiermath4", "FrontierMath Tier 4", "frontiermath", .math, YM(2025, 6), mid: 8.6, scale: 0.5,
          "Problems that take specialists days or weeks."),
        // Code
        b("humaneval", "HumanEval", "code_basic", .code, YM(2021, 7), ceil: 98, mid: 4.62, scale: 0.62, sat: 92,
          "164 hand-written Python problems, pass@1."),
        b("mbpp", "MBPP", "code_basic", .code, YM(2021, 8), ceil: 95, mid: 4.4, scale: 0.7,
          "974 entry-level Python programming tasks."),
        b("codeforces", "Codeforces percentile", "competitive", .code, YM(2022, 2), mid: 3.69, scale: 1.3, sat: 95,
          "Share of human competitive programmers the model out-rates."),
        b("livecodebench", "LiveCodeBench", "competitive", .code, YM(2024, 3), mid: 6.4, scale: 0.45,
          "Fresh contest problems released after training cut-offs."),
        b("swe", "SWE-bench Verified", "swe", .code, YM(2024, 8), mid: 6.13, scale: 0.753,
          "Resolve 500 real GitHub issues in Python repos, verified by tests."),
        b("swe_pro", "SWE-bench Pro", "swe", .code, YM(2025, 9), mid: 8.22, scale: 0.464,
          "Long-horizon enterprise-grade issues across many languages."),
        b("swe_pro_verified", "SWE-Bench Pro Verified", "swe", .code, YM(2026, 9), mid: 8.0, scale: 0.5,
          "A cleaned-up subset of SWE-bench Pro with broken and ambiguous tasks removed."),
        // Agents
        b("gaia", "GAIA", "browse", .agentic, YM(2023, 11), mid: 6.61, scale: 0.6,
          "General-assistant tasks that need browsing, tools and multi-step reasoning.", human: "92%"),
        b("osworld", "OSWorld", "computer_use", .agentic, YM(2024, 4), mid: 7.73, scale: 0.858,
          "Operate a real desktop: 369 tasks across apps.", human: "72%"),
        b("mlebench", "MLE-bench", "ml_research", .agentic, YM(2024, 10), mid: 8.27, scale: 1.11,
          "75 Kaggle competitions — earn medals autonomously."),
        b("browsecomp", "BrowseComp", "browse", .agentic, YM(2025, 4), mid: 7.25, scale: 0.355,
          "1,266 hard-to-find facts that need persistent web research."),
        b("paperbench", "PaperBench", "ml_research", .agentic, YM(2025, 4), mid: 7.6, scale: 1.0,
          "Replicate ICML papers from scratch."),
        b("tau2", "τ²-bench", "tool_use", .agentic, YM(2025, 6), mid: 7.47, scale: 0.455,
          "Customer-service agents using tools with a simulated user."),
        b("gdpval", "GDPval", "economic", .agentic, YM(2025, 9), mid: 8.02, scale: 1.11,
          "Real work products across 44 occupations, judged against industry experts.", human: "Experts = 50%"),
        b("terminal", "Terminal-Bench 2.0", "terminal", .agentic, YM(2025, 11), mid: 7.95, scale: 0.61,
          "Hard tasks in a real terminal: compile, debug, configure, deploy."),
        b("vending", "Vending-Bench 2", "long_horizon", .agentic, YM(2025, 11), mid: 8.5, scale: 0.6,
          "Run a simulated business for a year without losing the plot."),
        b("swe_marathon", "SWE-Marathon", "swe_long", .agentic, YM(2026, 6), mid: 9.4, scale: 0.6, sat: 80,
          "20 ultra-long software projects averaging 27M tokens per attempt. Under 30% at launch, and 13.8% of attempts tried to game the grader."),
        b("continual_bench", "Continual Learning Bench", "continual", .agentic, YM(2026, 6), mid: 9.6, scale: 0.7, sat: 80,
          "Stateful environments where earlier episodes should make later ones easier. Do agents actually learn on the job?"),
        // Abstraction
        b("arc1", "ARC-AGI-1", "arc", .reasoning, YM(2019, 11), mid: 6.61, scale: 0.342, sat: 85,
          "Novel visual puzzles from a few examples.", human: "~85%+"),
        b("arc2", "ARC-AGI-2", "arc", .reasoning, YM(2025, 3), mid: 7.95, scale: 0.267, sat: 85,
          "Harder abstract puzzles: easy for people, hard for AI.", human: "66% (average person)"),
        b("arc3", "ARC-AGI-3", "arc", .reasoning, YM(2026, 3), mid: 9.3, scale: 0.35, sat: 85,
          "Interactive games the agent must figure out by exploring.", human: "~100% (humans solve all)"),
        // Multimodal, science, long context
        b("mmmu", "MMMU", "multimodal", .multimodal, YM(2023, 11), floor: 22, ceil: 95, mid: 5.33, scale: 1.37, sat: 88,
          "College-level questions over charts, diagrams and images.", human: "88.6% (experts)"),
        b("videomme", "Video-MME", "multimodal", .multimodal, YM(2024, 5), floor: 25, ceil: 95, mid: 5.1, scale: 1.0,
          "Questions about short, medium and hour-long videos."),
        b("scicode", "SciCode", "science", .science, YM(2024, 7), mid: 8.6, scale: 0.45,
          "Research-level scientific programming from real papers."),
        b("critpt", "CritPt", "science", .science, YM(2025, 9), mid: 9.0, scale: 0.4,
          "Unpublished research-level physics challenges."),
        b("mrcr", "MRCR (1M context)", "longctx", .longContext, YM(2024, 9), mid: 6.65, scale: 0.6,
          "Find the right needle among many similar ones across a million tokens."),

        // MARK: Expanded set (calibrated to two real results each)
        b("wmt14", "WMT'14 En→De", "translation", .multilingual, YM(2016, 6), ceil: 45, mid: -2.039, scale: 1.918, sat: 38, unit: "BLEU",
          "English-to-German news translation — the Transformer paper's showcase result."),  // saturates ~2019.5
        b("race", "RACE (high school)", "reading", .knowledge, YM(2017, 4), floor: 25, ceil: 95, mid: -0.189, scale: 0.890,
          "28,000 reading-comprehension passages from Chinese English exams.", human: "94.5% (ceiling)"),  // saturates ~2020.02
        b("squad2", "SQuAD 2.0", "reading", .knowledge, YM(2018, 6), floor: 50, ceil: 95, mid: -1.323, scale: 1.391, sat: 89.5, unit: "F1",
          "SQuAD with unanswerable questions — the model must know when to abstain.", human: "89.5 F1"),  // saturates ~2019.66
        b("arc_challenge", "ARC-Challenge", "science_qa", .knowledge, YM(2018, 3), floor: 25, ceil: 98, mid: 3.104, scale: 0.534, sat: 95,
          "Grade-school science questions that retrieval and word co-occurrence can't answer."),  // saturates ~2023.07
        b("triviaqa", "TriviaQA (closed-book)", "closed_book", .knowledge, YM(2017, 5), ceil: 95, mid: 0.578, scale: 2.028,
          "Trivia questions answered from memory, no documents.", human: "~80%"),  // saturates ~2025.15
        b("naturalqs", "Natural Questions (closed-book)", "closed_book", .knowledge, YM(2019, 1), ceil: 75, mid: 3.664, scale: 2.103, sat: 60,
          "Real Google search questions with Wikipedia answers, from memory."),  // saturates ~2025.27
        b("piqa", "PIQA", "commonsense", .knowledge, YM(2019, 11), floor: 50, ceil: 96, mid: -0.891, scale: 4.055,
          "Physical commonsense: how do you separate egg whites?", human: "95%"),  // saturates ~2025.45
        b("boolq", "BoolQ", "reading", .knowledge, YM(2019, 5), floor: 62, ceil: 95, mid: 2.966, scale: 0.647, sat: 89,
          "Naturally occurring yes/no questions about Wikipedia passages.", human: "89%"),  // saturates ~2022.35
        b("medqa", "MedQA (USMLE)", "medical", .knowledge, YM(2020, 9), floor: 25, ceil: 98, mid: 4.429, scale: 0.410, sat: 93,
          "US medical licensing exam questions.", human: "~60% to pass"),  // saturates ~2024.2
        b("healthbench", "HealthBench", "medical", .science, YM(2025, 5), mid: 6.692, scale: 1.316, sat: 85,
          "5,000 realistic health conversations graded with physician-written rubrics."),  // saturates ~2027.19
        b("mtbench", "MT-Bench", "chat_quality", .instruction, YM(2023, 6), floor: 10, mid: 4.204, scale: 0.820, sat: 93, unit: "/100",
          "80 multi-turn questions graded by a strong judge model (score ×10)."),  // saturates ~2024.0
        b("alpacaeval", "AlpacaEval 2.0 (LC)", "chat_quality", .instruction, YM(2024, 4), mid: 6.180, scale: 1.389, sat: 85,
          "Length-controlled win rate against a reference model on everyday instructions."),  // saturates ~2026.01
        b("arenahard", "Arena-Hard", "chat_quality", .instruction, YM(2024, 4), mid: 5.865, scale: 0.424, sat: 92,
          "500 hard real-world prompts from Chatbot Arena, auto-judged."),  // saturates ~2024.7
        b("ifeval", "IFEval", "if_strict", .instruction, YM(2023, 11), floor: 10, ceil: 98, mid: 4.889, scale: 0.877, sat: 92,
          "Verifiable instructions: “answer in exactly 3 bullet points, no commas”."),  // saturates ~2024.94
        b("ifbench", "IFBench", "if_strict", .instruction, YM(2025, 7), mid: 7.844, scale: 0.357, sat: 88,
          "58 new, out-of-distribution constraints that models never trained on."),  // saturates ~2025.96
        b("multichallenge", "MultiChallenge", "multi_turn", .instruction, YM(2025, 1), mid: 7.256, scale: 1.745, sat: 85,
          "Multi-turn conversations that test memory, consistency and instruction retention."),  // saturates ~2028.2
        b("livebench", "LiveBench", "livebench", .reasoning, YM(2024, 6), mid: 4.998, scale: 1.681, sat: 88,
          "Contamination-free questions refreshed monthly across math, code, reasoning and data."),  // saturates ~2026.4
        b("mgsm", "MGSM", "multilingual_math", .multilingual, YM(2022, 10), mid: 4.369, scale: 0.615, sat: 92,
          "Grade-school math translated into 10 languages, from Swahili to Bengali."),  // saturates ~2024.38
        b("mmmlu", "MMMLU", "multilingual_knowledge", .multilingual, YM(2024, 9), floor: 25, ceil: 95, mid: 4.962, scale: 0.649,
          "MMLU professionally translated into 14 languages."),  // saturates ~2024.92
        b("minif2f", "miniF2F (Lean)", "formal_math", .math, YM(2021, 9), mid: 4.504, scale: 1.337, sat: 95,
          "Olympiad problems formalised in Lean — proofs a computer can check."),  // saturates ~2026.44
        b("putnambench", "PutnamBench (Lean)", "formal_math", .math, YM(2024, 7), mid: 7.659, scale: 0.149, sat: 85,
          "657 Putnam competition problems as formal theorems."),  // saturates ~2025.86
        b("apex", "MathArena Apex", "apex", .math, YM(2025, 8), mid: 8.175, scale: 0.132, sat: 85,
          "The hardest final-answer competition problems that no model could solve at launch."),  // saturates ~2026.4
        b("aider", "Aider Polyglot", "code_edit", .code, YM(2024, 12), mid: 6.411, scale: 0.627, sat: 92,
          "225 tough Exercism exercises in C++, Go, Java, JavaScript, Python and Rust — edit real files."),  // saturates ~2025.89
        b("swelancer", "SWE-Lancer (IC Diamond)", "freelance", .code, YM(2025, 2), mid: 7.295, scale: 0.739, sat: 85,
          "Real Upwork engineering jobs worth $500K, graded by end-to-end tests."),  // saturates ~2026.59
        b("webarena", "WebArena", "web_agents", .agentic, YM(2023, 7), mid: 6.832, scale: 0.865, sat: 78,
          "812 tasks on self-hosted shopping, forum, GitLab and map sites.", human: "78.2%"),  // saturates ~2025.66
        b("androidworld", "AndroidWorld", "mobile_agents", .agentic, YM(2024, 5), mid: 6.662, scale: 1.089, sat: 80,
          "116 tasks across 20 real Android apps.", human: "80%"),  // saturates ~2025.91
        b("agentcompany", "TheAgentCompany", "office_agents", .agentic, YM(2024, 12), mid: 8.273, scale: 1.282, sat: 80,
          "A simulated software company: browse, code, message colleagues and finish real work."),  // saturates ~2028.33
        b("balrog", "BALROG", "games", .agentic, YM(2024, 11), mid: 7.873, scale: 2.036, sat: 80,
          "Long-horizon games from BabyAI to NetHack."),  // saturates ~2029.38
        b("mathvista", "MathVista", "visual_math", .multimodal, YM(2023, 10), mid: 5.344, scale: 1.034, sat: 85,
          "Math reasoning over plots, geometry figures and tables.", human: "60.3%"),  // saturates ~2025.54
        b("chartqa", "ChartQA", "doc_understanding", .multimodal, YM(2022, 3), mid: 4.780, scale: 0.432, sat: 92,
          "Questions about real charts that need visual and logical reasoning."),  // saturates ~2024.52
        b("docvqa", "DocVQA", "doc_understanding", .multimodal, YM(2020, 7), mid: 4.427, scale: 0.450, sat: 95,
          "Questions about scanned documents, forms and receipts.", human: "98%"),  // saturates ~2024.44
        b("ai2d", "AI2D", "diagrams", .multimodal, YM(2016, 6), floor: 25, mid: 5.112, scale: 0.255, sat: 95,
          "Grade-school science diagrams."),  // saturates ~2024.47
        b("mmmu_pro", "MMMU-Pro", "multimodal", .multimodal, YM(2024, 9), floor: 10, mid: 5.891, scale: 1.236, sat: 88,
          "MMMU with 10 options and questions embedded in screenshots."),  // saturates ~2026.67
        b("charxiv", "CharXiv (reasoning)", "charts", .multimodal, YM(2024, 6), mid: 5.823, scale: 0.889, sat: 85,
          "Reasoning about charts from real arXiv papers.", human: "80.5%"),  // saturates ~2025.75
        b("niah", "Needle in a Haystack", "longctx_basic", .longContext, YM(2023, 11), mid: 4.152, scale: 0.246, sat: 98,
          "Find one planted sentence anywhere in a huge context."),  // saturates ~2024.01
        b("ruler", "RULER (128K)", "longctx_basic", .longContext, YM(2024, 4), mid: 3.069, scale: 0.896, sat: 95,
          "Retrieval, tracing and aggregation tasks at 128K tokens."),  // saturates ~2024.41
        b("longbench2", "LongBench v2", "longctx_reasoning", .longContext, YM(2024, 12), floor: 25, mid: 7.201, scale: 4.664, sat: 70,
          "Deep reasoning over 8K–2M-word documents, code repos and dialogues.", human: "53.7% (experts, timed)"),  // saturates ~2027.21
        b("fiction_live", "Fiction.LiveBench (120K)", "longctx_reasoning", .longContext, YM(2025, 2), mid: 6.077, scale: 0.551, sat: 95,
          "Questions that need understanding a whole long story, not just retrieving lines."),  // saturates ~2025.6
        b("aa_lcr", "AA-LCR", "longctx_reasoning", .longContext, YM(2025, 7), mid: 6.817, scale: 0.766, sat: 85,
          "Long-context reasoning over ~100K-token document sets."),  // saturates ~2026.07
        b("truthfulqa", "TruthfulQA", "honesty", .safety, YM(2021, 9), floor: 20, mid: 6.451, scale: 0.641,
          "Questions where popular misconceptions tempt models into falsehoods.", human: "94%"),  // saturates ~2024.76
        b("harmbench", "HarmBench robustness", "jailbreak", .safety, YM(2024, 2), mid: 7.049, scale: 0.503, sat: 95,
          "Share of automated jailbreak attacks the model resists."),  // saturates ~2025.68
        b("bbq", "BBQ (bias)", "bias", .safety, YM(2021, 10), floor: 33, mid: 5.116, scale: 0.871, sat: 95,
          "Ambiguous questions that reveal social stereotypes."),  // saturates ~2024.2
        b("mask", "MASK (honesty under pressure)", "honesty", .safety, YM(2025, 3), mid: 8.167, scale: 0.723,
          "Does the model keep its beliefs when pressured to lie?"),  // saturates ~2028.24
        b("wmdp", "WMDP (hazardous knowledge)", "hazard_knowledge", .dangerous, YM(2024, 3), floor: 25, ceil: 95, mid: 4.448, scale: 0.721,
          "Proxy questions for bio-, chem- and cyber-weapons knowledge. Lower is safer."),  // saturates ~2024.7
        b("cybench", "Cybench (CTF)", "cyber", .dangerous, YM(2024, 8), mid: 7.808, scale: 1.333, sat: 85,
          "40 professional capture-the-flag hacking challenges."),
        b("exploitbench", "ExploitBench", "exploit", .dangerous, YM(2026, 5), mid: 7.85, scale: 0.6, sat: 85,
          "A capability ladder for exploit development, run by UK and US government evaluators. Top US models averaged 76% at launch."),  // saturates ~2028.97
        b("vct", "Virology Capabilities Test", "bio", .dangerous, YM(2025, 4), mid: 7.575, scale: 1.644, sat: 80,
          "Troubleshooting real wet-lab virology protocols.", human: "22% (expert virologists)"),  // saturates ~2028.53
        b("bigbenchaudio", "Big Bench Audio", "speech", .speech, YM(2024, 12), mid: 6.188, scale: 0.918, sat: 92,
          "Spoken reasoning questions answered speech-to-speech."),  // saturates ~2026.29
        b("enigmaeval", "EnigmaEval", "puzzles", .reasoning, YM(2025, 2), mid: 9.246, scale: 0.866, sat: 80,
          "Multi-step puzzle-hunt problems that require leaps of insight."),  // saturates ~2029.42
        // v3 batch 2: exams, grounding, law, logic, medicine, SQL, live-web agents, GUI grounding, video, audio, over-refusal, classic NLP
        b("bar_exam", "Uniform Bar Exam", "pro_exams", .knowledge, YM(2022, 12), mid: 4.750, scale: 0.159, unit: "pctl",
          "The US lawyer licensing exam — multiple choice, essays and performance tests — scored against human takers.", human: "50th pctl (median taker)"),  // saturates ~2023.2
        b("lsat", "LSAT", "pro_exams", .reasoning, YM(2022, 12), mid: 4.618, scale: 0.292, sat: 95, unit: "pctl",
          "Law-school admission test: logical and analytical reasoning plus reading comprehension.", human: "50th pctl"),  // saturates ~2023.9
        b("sat_math", "SAT Math", "pro_exams", .math, YM(2022, 12), mid: 4.033, scale: 0.563, sat: 97, unit: "pctl",
          "The US college-admission math section, graded against millions of high-schoolers.", human: "50th pctl"),  // saturates ~2024.68
        b("gre_verbal", "GRE Verbal", "pro_exams", .knowledge, YM(2022, 12), mid: 4.308, scale: 0.172, sat: 97, unit: "pctl",
          "Graduate-school verbal reasoning: vocabulary, text completion and reading.", human: "50th pctl"),  // saturates ~2023.12
        b("facts_grounding", "FACTS Grounding", "grounding", .knowledge, YM(2024, 12), mid: 3.307, scale: 1.776, sat: 92,
          "Long-document answers judged for staying faithful to the source — no made-up claims."),  // saturates ~2026.29
        b("frames", "FRAMES", "grounding", .reasoning, YM(2024, 9), mid: 6.186, scale: 0.473, sat: 92,
          "Multi-hop questions that need facts from 2–15 Wikipedia articles: retrieval and reasoning combined."),  // saturates ~2025.4
        b("legalbench", "LegalBench", "legal", .reasoning, YM(2023, 8), ceil: 92, mid: 2.255, scale: 1.976, sat: 88,
          "162 legal-reasoning tasks written by lawyers: issue spotting, rule recall, interpretation and rhetoric."),  // saturates ~2026.42
        b("c_eval", "C-Eval", "chinese", .multilingual, YM(2023, 5), floor: 25, mid: 5.095, scale: 0.813, sat: 92,
          "13,948 Chinese exam questions across 52 subjects, from middle school to professional level."),  // saturates ~2025.07
        b("zebralogic", "ZebraLogic", "logic", .reasoning, YM(2024, 7), mid: 6.062, scale: 0.550,
          "Logic-grid puzzles (“the Norwegian lives in the first house…”) of scalable difficulty."),  // saturates ~2025.34
        b("musr", "MuSR (murder mysteries)", "narrative_reasoning", .reasoning, YM(2023, 10), floor: 50, mid: 5.195, scale: 0.558, sat: 94,
          "1,000-word murder mysteries: name the killer from motive, means and opportunity.", human: "94%"),  // saturates ~2024.7
        b("bbeh", "BIG-Bench Extra Hard", "bbh", .reasoning, YM(2025, 2), mid: 7.085, scale: 0.503, sat: 85,
          "23 brutal replacements for the BIG-Bench Hard tasks; o3-mini (high) managed 44.8% at launch."),  // saturates ~2025.97
        b("omni_math", "Omni-MATH", "omni_math", .math, YM(2024, 10), mid: 6.270, scale: 0.680,
          "4,428 olympiad problems across 33 sub-domains and 10 difficulty levels."),  // saturates ~2025.71
        b("supergpqa", "SuperGPQA", "broad_science", .science, YM(2025, 2), floor: 10, mid: 6.023, scale: 2.945, sat: 85,
          "26,529 graduate-level questions across 285 disciplines, from forestry to musicology."),  // saturates ~2029.94
        b("healthbench_hard", "HealthBench Hard", "medical_hard", .science, YM(2025, 5), mid: 7.692, scale: 0.605, sat: 80,
          "The 1,000 hardest HealthBench conversations, where frontier models still miss physicians' rubrics."),  // saturates ~2026.61
        b("medxpertqa", "MedXpertQA (text)", "medical_hard", .science, YM(2025, 1), floor: 10, mid: 7.185, scale: 1.210, sat: 85,
          "Expert-level medical exam questions from 17 specialties, each with 10 answer options."),  // saturates ~2027.41
        b("bird_sql", "BIRD (text-to-SQL)", "text_to_sql", .code, YM(2023, 5), mid: 4.845, scale: 2.010, sat: 92,
          "Turn questions into SQL over 95 real databases with dirty values and business logic.", human: "93%"),  // saturates ~2028.21
        b("swe_multimodal", "SWE-bench Multimodal", "swe_mm", .code, YM(2024, 10), mid: 7.797, scale: 0.672, sat: 85,
          "JavaScript bugs reported with screenshots: fix the UI the user is looking at."),  // saturates ~2027.09
        b("webvoyager", "WebVoyager", "live_web", .agentic, YM(2024, 1), mid: 5.249, scale: 0.982,
          "643 tasks on 15 live websites — Amazon, Apple, GitHub, Google Maps — judged end to end."),  // saturates ~2025.23
        b("online_mind2web", "Online-Mind2Web", "live_web", .agentic, YM(2025, 4), mid: 6.518, scale: 1.299,
          "300 realistic tasks on 136 live websites, graded by humans — built to expose an “illusion of progress”."),  // saturates ~2027.37
        b("appworld", "AppWorld", "app_agents", .agentic, YM(2024, 7), mid: 6.112, scale: 2.429, sat: 88,
          "750 everyday tasks across 9 simulated apps and 457 APIs — payments, music, email, files."),  // saturates ~2029.81
        b("remote_labor", "Remote Labor Index", "remote_work", .agentic, YM(2025, 10), mid: 9.972, scale: 0.500, sat: 75,
          "240 real paid freelance projects — design, video, architecture, data. What share can an AI deliver at client quality?", human: "100% (by construction)"),  // saturates ~2029.09
        b("screenspot_pro", "ScreenSpot-Pro", "gui_grounding", .multimodal, YM(2025, 1), mid: 7.009, scale: 0.450, sat: 85,
          "Click the right pixel in dense professional apps — CAD, IDEs, Photoshop — on 4K screens."),  // saturates ~2026.2
        b("videommmu", "VideoMMMU", "video_reasoning", .multimodal, YM(2025, 1), mid: 6.151, scale: 0.503, sat: 88,
          "Watch 300 expert lecture videos, then answer exam questions about what was taught.", human: "74% (experts)"),  // saturates ~2025.55
        b("egoschema", "EgoSchema", "video_reasoning", .multimodal, YM(2023, 8), floor: 20, mid: 5.651, scale: 0.300, sat: 76,
          "5,000 questions about 3-minute first-person videos that need very long-form understanding.", human: "76%"),  // saturates ~2024.59
        b("ocrbench", "OCRBench", "doc_understanding", .multimodal, YM(2023, 5), mid: 4.819, scale: 0.873, sat: 92,
          "1,000 OCR tasks: scene text, handwriting, formulas and key-value extraction."),  // saturates ~2025.39
        b("infovqa", "InfographicVQA", "doc_understanding", .multimodal, YM(2021, 4), mid: 3.651, scale: 1.530, sat: 92,
          "Questions about dense infographics that mix charts, text and layout."),  // saturates ~2025.77
        b("mathvision", "MATH-Vision", "vision_math_hard", .multimodal, YM(2024, 2), mid: 6.486, scale: 0.743, sat: 85,
          "3,040 competition math problems where the figure is essential.", human: "76%"),  // saturates ~2026.19
        b("realworldqa", "RealWorldQA", "real_world_vision", .multimodal, YM(2024, 4), floor: 25, mid: 5.436, scale: 1.640,
          "765 photos from cars and everyday scenes with spatial questions about the physical world."),  // saturates ~2027.06
        b("mmau", "MMAU", "audio_understanding", .speech, YM(2024, 10), floor: 25, mid: 7.409, scale: 1.368, sat: 82,
          "10,000 clips of speech, music and sounds with expert-written reasoning questions.", human: "82%"),  // saturates ~2026.95
        b("mmau_pro", "MMAU-Pro", "audio_understanding", .speech, YM(2025, 8), mid: 7.444, scale: 0.902, sat: 85,
          "MMAU's harder sequel: long recordings, multi-clip and open-ended questions.", human: "78%"),  // saturates ~2026.99
        b("collie", "COLLIE", "constrained_writing", .instruction, YM(2023, 7), mid: 5.964, scale: 0.452, sat: 95,
          "Write text that satisfies stacked constraints — exact word counts, positions, banned letters."),  // saturates ~2025.0
        b("xstest", "XSTest (over-refusal)", "over_refusal", .safety, YM(2023, 8), mid: 5.885, scale: 0.474, sat: 97,
          "250 safe prompts that only sound dangerous (“how do I kill a Python process?”): share answered."),  // saturates ~2024.54
        b("intercode_ctf", "InterCode-CTF", "ctf_basic", .dangerous, YM(2023, 6), mid: 5.444, scale: 0.404, sat: 95,
          "100 high-school capture-the-flag hacking challenges in a sandbox. Saturated by Dec 2024."),  // saturates ~2024.96
        b("commonsenseqa", "CommonsenseQA", "commonsense", .knowledge, YM(2018, 11), floor: 20, mid: 0.478, scale: 1.353, sat: 88,
          "12,000 questions that need everyday knowledge about how concepts relate.", human: "89%"),  // saturates ~2020.47
        b("swag", "SWAG", "commonsense", .knowledge, YM(2018, 8), floor: 25, mid: -0.074, scale: 0.149, sat: 88,
          "113,000 video-caption completions: pick what happens next. BERT beat it within months.", human: "88%"),  // saturates ~2018.88
        b("wsc", "Winograd Schema Challenge", "commonsense", .knowledge, YM(2016, 6), floor: 50, mid: 0.944, scale: 1.565, sat: 92,
          "273 pronoun puzzles: “The trophy didn't fit in the suitcase because it was too big.” What was?", human: "96%"),  // saturates ~2022.02
        b("socialiqa", "Social IQa", "commonsense", .knowledge, YM(2019, 4), floor: 33, mid: 1.003, scale: 1.953, sat: 86,
          "38,000 questions about people's motivations, reactions and feelings.", human: "88%"),  // saturates ~2022.07
        b("openbookqa", "OpenBookQA", "science_qa", .knowledge, YM(2018, 9), floor: 25, mid: 0.788, scale: 1.156, sat: 92,
          "Elementary science questions that need a book of facts plus common sense.", human: "92%"),  // saturates ~2021.52
        b("coqa", "CoQA", "reading", .knowledge, YM(2018, 8), mid: -0.383, scale: 0.454, sat: 88.8, unit: "F1",
          "127,000 questions asked in conversations about a passage — answers depend on the dialogue so far.", human: "88.8 F1"),  // saturates ~2019.19
    ]

    static let realByID: [String: Benchmark] = Dictionary(uniqueKeysWithValues: real.map { ($0.id, $0) })

    static func roman(_ n: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }

    static let families: [String: BenchFamily] = {
        let list: [BenchFamily] = [
            BenchFamily(id: "reading", name: "Reading", regenerates: false) { "Reading-\($0)" },
            BenchFamily(id: "glue", name: "GLUE", regenerates: false) { "GLUE-\($0)" },
            BenchFamily(id: "commonsense", name: "Commonsense", regenerates: false) { "Commonsense-\($0)" },
            BenchFamily(id: "bbh", name: "BIG-Bench", regenerates: false) { "BIG-Bench-\($0)" },
            BenchFamily(id: "school_math", name: "School math", regenerates: false) { "MATH-\($0)" },
            BenchFamily(id: "code_basic", name: "Basic coding", regenerates: false) { "HumanEval-\($0)" },
            BenchFamily(id: "mmlu", name: "MMLU", regenerates: true) { $0 == 3 ? "MMLU-Ultra" : "MMLU-Ultra \($0 - 2)" },
            BenchFamily(id: "factuality", name: "Factuality", regenerates: true) { "SimpleQA \($0)" },
            BenchFamily(id: "gpqa", name: "GPQA", regenerates: true) { $0 == 2 ? "GPQA Ultra" : "GPQA Ultra \($0 - 1)" },
            BenchFamily(id: "hle", name: "Humanity's Last Exam", regenerates: true) { "Humanity's Last Exam \(roman($0))" },
            BenchFamily(id: "simplebench", name: "SimpleBench", regenerates: true) { "SimpleBench \($0)" },
            BenchFamily(id: "olympiad", name: "Olympiad math", regenerates: true) {
                switch $0 {
                case 5: "Putnam Proof Challenge"
                case 6: "Erdős Problems"
                default: "Open Conjectures \($0 - 6)"
                }
            },
            BenchFamily(id: "frontiermath", name: "FrontierMath", regenerates: true) { "FrontierMath Tier \($0 + 2)" },
            BenchFamily(id: "competitive", name: "Competitive coding", regenerates: true) { $0 == 3 ? "LiveCodeBench Pro" : "LiveCodeBench Pro \($0 - 2)" },
            BenchFamily(id: "swe", name: "SWE-bench", regenerates: true) { $0 == 3 ? "SWE-bench Ultra" : "SWE-bench Ultra \($0 - 2)" },
            BenchFamily(id: "terminal", name: "Terminal-Bench", regenerates: true) { "Terminal-Bench \($0 + 1).0" },
            BenchFamily(id: "computer_use", name: "Computer use", regenerates: true) { "OSWorld-\($0)" },
            BenchFamily(id: "tool_use", name: "Tool use", regenerates: true) { $0 == 2 ? "τ³-bench" : "τ-bench \($0 + 1)" },
            BenchFamily(id: "browse", name: "Deep research", regenerates: true) { "BrowseComp-\($0 - 1)" },
            BenchFamily(id: "economic", name: "Economic value", regenerates: true) { "GDPval-\($0)" },
            BenchFamily(id: "ml_research", name: "AI R&D", regenerates: true) { $0 == 3 ? "AutoResearch" : "AutoResearch \($0 - 2)" },
            BenchFamily(id: "long_horizon", name: "Long horizon", regenerates: true) { "Vending-Bench \($0 + 1)" },
            BenchFamily(id: "arc", name: "ARC-AGI", regenerates: true) { "ARC-AGI-\($0)" },
            BenchFamily(id: "multimodal", name: "Multimodal", regenerates: true) { $0 == 4 ? "MMMU-Ultra" : "Omni-Bench \($0 - 4)" },
            BenchFamily(id: "science", name: "Science", regenerates: true) { $0 == 3 ? "Nobel-Bench" : "Nobel-Bench \($0 - 2)" },
            BenchFamily(id: "longctx", name: "Long context", regenerates: true) { "MRCR \($0)" },
            BenchFamily(id: "translation", name: "Translation", regenerates: false) { "WMT-\($0)" },
            BenchFamily(id: "science_qa", name: "Science QA", regenerates: false) { "ARC-\($0)" },
            BenchFamily(id: "closed_book", name: "Closed-book QA", regenerates: false) { "Trivia-\($0)" },
            BenchFamily(id: "medical", name: "Medicine", regenerates: true) { $0 == 3 ? "MedQA-Ultra" : "Clinical-Bench \($0 - 3)" },
            BenchFamily(id: "chat_quality", name: "Chat quality", regenerates: true) { "Arena-Hard v\($0 - 2)" },
            BenchFamily(id: "if_strict", name: "Instruction following", regenerates: true) { "IFBench-\($0 - 1)" },
            BenchFamily(id: "multi_turn", name: "Multi-turn", regenerates: true) { "MultiChallenge \($0)" },
            BenchFamily(id: "livebench", name: "LiveBench", regenerates: true) { "LiveBench-\($0)" },
            BenchFamily(id: "multilingual_math", name: "Multilingual math", regenerates: false) { "MGSM-\($0)" },
            BenchFamily(id: "multilingual_knowledge", name: "Multilingual knowledge", regenerates: true) { $0 == 2 ? "Global-MMLU" : "Global-MMLU \($0 - 1)" },
            BenchFamily(id: "formal_math", name: "Formal proofs", regenerates: true) { $0 == 3 ? "Lean-Erdős" : "Lean-Erdős \($0 - 2)" },
            BenchFamily(id: "apex", name: "MathArena Apex", regenerates: true) { "MathArena Apex \($0)" },
            BenchFamily(id: "code_edit", name: "Code editing", regenerates: true) { "Aider Polyglot \($0)" },
            BenchFamily(id: "freelance", name: "Freelance engineering", regenerates: true) { "SWE-Lancer \($0)" },
            BenchFamily(id: "web_agents", name: "Web agents", regenerates: true) { "WebArena-\($0)" },
            BenchFamily(id: "mobile_agents", name: "Mobile agents", regenerates: true) { "AndroidWorld-\($0)" },
            BenchFamily(id: "office_agents", name: "Office agents", regenerates: true) { "TheAgentCompany-\($0)" },
            BenchFamily(id: "games", name: "Games", regenerates: true) { "BALROG-\($0)" },
            BenchFamily(id: "visual_math", name: "Visual math", regenerates: true) { "MathVista-\($0)" },
            BenchFamily(id: "doc_understanding", name: "Documents", regenerates: false) { "DocBench-\($0)" },
            BenchFamily(id: "diagrams", name: "Diagrams", regenerates: false) { "AI2D-\($0)" },
            BenchFamily(id: "charts", name: "Chart reasoning", regenerates: true) { "CharXiv-\($0)" },
            BenchFamily(id: "longctx_basic", name: "Context retrieval", regenerates: false) { "RULER-\($0)" },
            BenchFamily(id: "longctx_reasoning", name: "Long-context reasoning", regenerates: true) { "LongBench v\($0 - 1)" },
            BenchFamily(id: "honesty", name: "Honesty", regenerates: true) { $0 == 3 ? "TruthBench" : "TruthBench \($0 - 2)" },
            BenchFamily(id: "jailbreak", name: "Jailbreak robustness", regenerates: true) { "Jailbreak Gauntlet \($0)" },
            BenchFamily(id: "bias", name: "Bias", regenerates: false) { "BBQ-\($0)" },
            BenchFamily(id: "hazard_knowledge", name: "Hazardous knowledge", regenerates: false) { "WMDP-\($0)" },
            BenchFamily(id: "cyber", name: "Cyber offence", regenerates: true) { "Cybench-\($0)" },
            BenchFamily(id: "bio", name: "Biology risk", regenerates: true) { "VCT-\($0)" },
            BenchFamily(id: "speech", name: "Speech", regenerates: true) { "Big Bench Audio \($0)" },
            BenchFamily(id: "puzzles", name: "Puzzles", regenerates: true) { "EnigmaEval \($0)" },
            BenchFamily(id: "pro_exams", name: "Professional exams", regenerates: false) { "Exam-\($0)" },
            BenchFamily(id: "grounding", name: "Grounding & retrieval", regenerates: true) { "FACTS Grounding \($0 - 1)" },
            BenchFamily(id: "legal", name: "Law", regenerates: true) { $0 == 2 ? "LegalBench-Pro" : "LegalBench-Pro \($0 - 1)" },
            BenchFamily(id: "chinese", name: "Chinese", regenerates: true) { $0 == 2 ? "C-Eval Pro" : "C-Eval Pro \($0 - 1)" },
            BenchFamily(id: "logic", name: "Logic puzzles", regenerates: true) { "ZebraLogic \($0)" },
            BenchFamily(id: "narrative_reasoning", name: "Narrative reasoning", regenerates: true) { "MuSR-\($0)" },
            BenchFamily(id: "omni_math", name: "Olympiad answers", regenerates: true) { "Omni-MATH \($0)" },
            BenchFamily(id: "broad_science", name: "Graduate disciplines", regenerates: true) { "SuperGPQA \($0)" },
            BenchFamily(id: "medical_hard", name: "Clinical reasoning", regenerates: true) { $0 == 3 ? "Clinical Frontier" : "Clinical Frontier \($0 - 2)" },
            BenchFamily(id: "text_to_sql", name: "Text-to-SQL", regenerates: true) { "BIRD-\($0)" },
            BenchFamily(id: "swe_mm", name: "Visual software", regenerates: true) { "SWE-bench Multimodal \($0)" },
            BenchFamily(id: "live_web", name: "Live web agents", regenerates: true) { $0 == 3 ? "Live-Web" : "Live-Web \($0 - 2)" },
            BenchFamily(id: "app_agents", name: "App agents", regenerates: true) { "AppWorld-\($0)" },
            BenchFamily(id: "remote_work", name: "Remote work", regenerates: true) { "Remote Labor Index \($0)" },
            BenchFamily(id: "gui_grounding", name: "GUI grounding", regenerates: true) { $0 == 2 ? "ScreenSpot-Ultra" : "ScreenSpot-Ultra \($0 - 1)" },
            BenchFamily(id: "video_reasoning", name: "Video reasoning", regenerates: true) { $0 == 3 ? "VideoMMMU-Pro" : "VideoMMMU-Pro \($0 - 2)" },
            BenchFamily(id: "vision_math_hard", name: "Visual olympiad math", regenerates: true) { "MATH-Vision \($0)" },
            BenchFamily(id: "real_world_vision", name: "Real-world vision", regenerates: true) { "RealWorldQA \($0)" },
            BenchFamily(id: "audio_understanding", name: "Audio understanding", regenerates: true) { $0 == 3 ? "MMAU-Ultra" : "MMAU-Ultra \($0 - 2)" },
            BenchFamily(id: "constrained_writing", name: "Constrained writing", regenerates: true) { "COLLIE-\($0)" },
            BenchFamily(id: "over_refusal", name: "Over-refusal", regenerates: false) { "XSTest-\($0)" },
            BenchFamily(id: "ctf_basic", name: "Beginner hacking", regenerates: false) { "CTF-\($0)" },
            BenchFamily(id: "swe_long", name: "Marathon engineering", regenerates: true) { "SWE-Marathon \($0)" },
            BenchFamily(id: "continual", name: "Continual learning", regenerates: true) { "Continual Learning Bench \($0)" },
            BenchFamily(id: "exploit", name: "Exploit development", regenerates: true) { "ExploitBench \($0)" },
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }()

    // MARK: Score cache

    /// Cache key without string building: the profile and benchmark ids, plus how far a blended index slot has phased in.
    private struct ScoreKey: Hashable {
        let profile: String
        let bench: String
        let generated: Bool
        let blendT: Int
        let blendFrom: [String]
    }

    nonisolated(unsafe) private static var cache: [ScoreKey: Double] = [:]

    static func resetCache() { cache.removeAll(keepingCapacity: true) }

    static func cachedScore(_ b: Benchmark, _ p: ModelProfile) -> Double {
        let key = ScoreKey(profile: p.key, bench: b.id, generated: b.generated,
                           blendT: b.blend.map { Int(($0.t * 1000).rounded()) } ?? -1, blendFrom: b.blend?.from.map(\.id) ?? [])
        if let v = cache[key] { return v }
        let v = b.score(p)
        if cache.count > 200_000 { cache.removeAll(keepingCapacity: true) }
        cache[key] = v
        return v
    }

    /// `hashUnit("\(a)|\(b)")` without building the string (same bytes, same hash).
    static func hashUnit(_ a: String, _ b: String) -> Double {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in a.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01b3
        }
        h ^= 0x7C
        h = h &* 0x100_0000_01b3
        for byte in b.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01b3
        }
        return Double(h >> 11) / Double(1 << 53)
    }

    /// FNV-1a hash → [0, 1)
    static func hashUnit(_ s: String) -> Double {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in s.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01b3
        }
        return Double(h >> 11) / Double(1 << 53)
    }

    // MARK: Index & arena

    static func arenaElo(c: Double, bonus: Double) -> Double { 760 + 90 * c + bonus }

    // MARK: The Intelligence Index set

    static let indexSize = 10
    /// A new benchmark counts toward the index only once it has been out this long (early results settle).
    static let indexGraceMonths = 4
    /// A benchmark joining the index phases in over this many days, while what its slot measured before phases out.
    static let indexBlendDays = 56.0
    /// At most one slot starts rotating this often, so benchmarks that saturate together (one big release can push several
    /// over the line) leave one by one and a fixed model's index drifts down gently rather than in a cliff.
    static let indexRotationDays = 28.0
    /// Unsaturated text benchmarks (out, or launching within a quarter) to keep around for the index to rotate through.
    static let minLiveBenchmarks = 12

    /// The Intelligence Index set on `date`: ten slots that persist. A slot changes only when its benchmark saturates and a
    /// settled, unsaturated replacement exists (until then the saturated one stays, so the set is never empty), slots rotate
    /// one at a time, and the newcomer phases in over eight weeks (see `Benchmark.score`), so the index glides instead of
    /// jumping.
    /// Like the scores themselves this is a pure function of the catalogue, the date and the saturation history (replayed
    /// week by week from 2016, and cached), so old saves, the engine and every view always agree on it.
    static func indexSet(_ all: [Benchmark], date: Date, saturated: [String: Date]) -> [Benchmark] {
        indexReplay(all, date: date, saturated: saturated).slots
            .map { $0.benchmark(on: date) }
            .sorted { $0.mid != $1.mid ? $0.mid > $1.mid : $0.id < $1.id }
    }

    /// One place in the index: the benchmark in it, and what the slot measured before while the newcomer phases in.
    struct IndexSlot: Sendable {
        var bench: Benchmark
        var joined: Date
        var from: [Benchmark] = []
        var weights: [Double] = []

        func progress(_ date: Date) -> Double {
            from.isEmpty ? 1 : clamp(date.timeIntervalSince(joined) / (BenchmarkCatalog.indexBlendDays * 86_400), 0, 1)
        }

        func benchmark(on date: Date) -> Benchmark {
            let t = progress(date)
            guard t < 1 else { return bench }
            var b = bench
            b.name = "\(bench.name) (phasing in)"
            b.blend = IndexBlend(from: from, weights: weights, t: t,
                                 full: joined.addingTimeInterval(BenchmarkCatalog.indexBlendDays * 86_400))
            return b
        }
    }

    private struct ReplayKey: Equatable {
        var count = 0
        var saturatedCount = 0
        var saturatedSum = 0.0
        var generatedSum = 0.0

        init(_ all: [Benchmark], _ saturated: [String: Date]) {
            count = all.count
            saturatedCount = saturated.count
            for d in saturated.values { saturatedSum += d.timeIntervalSinceReferenceDate }
            for b in all where b.generated { generatedSum += b.mid + Double(b.introduced.year * 12 + b.introduced.month) }
        }
    }

    private struct Replay {
        var key: ReplayKey
        var step: Int
        var slots: [IndexSlot]
        var lastRotation = Date.distantPast
    }

    /// The text benchmarks the index can use, with the dates that matter to it.
    private struct ReplayPool {
        var benches: [Benchmark] = []
        var intro: [Date] = []
        var settled: [Date] = []
        var saturatedOn: [Date?] = []
        var saturated: [String: Date] = [:]

        init(_ all: [Benchmark], _ saturated: [String: Date]) {
            self.saturated = saturated
            for b in all where b.kind.inIndex {
                benches.append(b)
                intro.append(b.introduced.date)
                settled.append(b.introduced.adding(months: BenchmarkCatalog.indexGraceMonths).date)
                saturatedOn.append(saturated[b.id])
            }
        }

        func isSaturated(_ id: String, on e: Date) -> Bool { saturated[id].map { $0 <= e } ?? false }
    }

    nonisolated(unsafe) private static var replays: [Replay] = []
    private static let replayEpoch = GameCalendar.date(2016, 6, 1)
    private static let replayStep: TimeInterval = 7 * 86_400

    private static func indexReplay(_ all: [Benchmark], date: Date, saturated: [String: Date]) -> Replay {
        let key = ReplayKey(all, saturated)
        let target = max(0, Int((date.timeIntervalSince(replayEpoch) / replayStep).rounded(.down)))
        // Resume the furthest cached replay of this same history that hasn't gone past `date`.
        var r = replays.filter { $0.key == key && $0.step <= target }.max { $0.step < $1.step } ?? Replay(key: key, step: -1, slots: [])
        guard r.step < target else { return r }
        let pool = ReplayPool(all, saturated)
        for k in (r.step + 1)...target {
            advance(&r.slots, &r.lastRotation, pool, at: replayEpoch.addingTimeInterval(Double(k) * replayStep))
        }
        r.step = target
        replays.removeAll { $0.key != key }
        replays.append(r)
        if replays.count > 8 { replays.removeFirst(replays.count - 8) }
        return r
    }

    /// One week of index history: rotate out the longest-saturated benchmark if a successor is ready (one at a time), then
    /// grow to full size.
    private static func advance(_ slots: inout [IndexSlot], _ lastRotation: inout Date, _ pool: ReplayPool, at e: Date) {
        if e.timeIntervalSince(lastRotation) >= indexRotationDays * 86_400 {
            let due = slots.indices.filter { pool.isSaturated(slots[$0].bench.id, on: e) && slots[$0].progress(e) >= 1 }
            let oldest = due.min {
                (pool.saturated[slots[$0].bench.id] ?? .distantPast, slots[$0].bench.id) < (pool.saturated[slots[$1].bench.id] ?? .distantPast, slots[$1].bench.id)
            }
            if let i = oldest, let next = pick(slots, pool, at: e, settledOnly: true) {
                slots[i] = IndexSlot(bench: next, joined: e, from: [slots[i].bench], weights: [1])
                lastRotation = e
            }
        }
        let wasEmpty = slots.isEmpty
        while slots.count < indexSize,
              let next = pick(slots, pool, at: e, settledOnly: true) ?? pick(slots, pool, at: e, settledOnly: false) {
            // A slot added to a running index starts out as the index itself, so adding it moves nobody's score.
            let (from, weights) = wasEmpty ? ([], []) : snapshot(slots, at: e)
            slots.append(IndexSlot(bench: next, joined: e, from: from, weights: weights))
        }
    }

    /// The live benchmark that fills the widest gap in the set's spread of difficulty, preferring kinds of skill the set is
    /// short of. Live benchmarks are ranked by difficulty, so the set keeps reaching from the hardest test down to nearly
    /// saturated ones. Saturation and new benchmarks both follow the field, so a frontier model keeps scoring about half.
    private static func pick(_ slots: [IndexSlot], _ pool: ReplayPool, at e: Date, settledOnly: Bool) -> Benchmark? {
        let members = Set(slots.map(\.bench.id))
        var live: [Int] = []
        for i in pool.benches.indices where pool.intro[i] <= e && (!settledOnly || pool.settled[i] <= e || members.contains(pool.benches[i].id)) {
            if let d = pool.saturatedOn[i], d <= e { continue }
            live.append(i)
        }
        live.sort { pool.benches[$0].mid != pool.benches[$1].mid ? pool.benches[$0].mid < pool.benches[$1].mid : pool.benches[$0].id < pool.benches[$1].id }
        var taken: [Int] = []
        for (pos, i) in live.enumerated() where members.contains(pool.benches[i].id) { taken.append(pos) }
        var kinds: [BenchKind: Int] = [:]
        for sl in slots where !pool.isSaturated(sl.bench.id, on: e) { kinds[sl.bench.kind, default: 0] += 1 }
        let kindPenalty = max(1, Double(live.count) / 20)
        var best: (score: Double, pos: Int)? = nil
        for (pos, i) in live.enumerated() where !members.contains(pool.benches[i].id) {
            let below = taken.last { $0 < pos }
            let above = taken.first { $0 > pos }
            let room: Int
            switch (below, above) {
            case let (b?, a?): room = min(pos - b, a - pos)
            case let (b?, nil): room = pos - b
            case let (nil, a?): room = a - pos
            case (nil, nil): room = live.count
            }
            let score = Double(room) - kindPenalty * Double(kinds[pool.benches[i].kind] ?? 0)
            if let cur = best, score < cur.score - 1e-9 { continue }   // ties go to the harder benchmark
            best = (score, pos)
        }
        return best.map { pool.benches[live[$0.pos]] }
    }

    /// The current set as a weighted mix of pure benchmarks: what a newly added slot starts out measuring.
    private static func snapshot(_ slots: [IndexSlot], at e: Date) -> ([Benchmark], [Double]) {
        var order: [String] = []
        var parts: [String: (Benchmark, Double)] = [:]
        func add(_ b: Benchmark, _ w: Double) {
            guard w > 0 else { return }
            if let p = parts[b.id] { parts[b.id] = (p.0, p.1 + w) } else { parts[b.id] = (b, w); order.append(b.id) }
        }
        let n = Double(max(1, slots.count))
        for sl in slots {
            let t = sl.progress(e)
            for (b, w) in zip(sl.from, sl.weights) { add(b, w * (1 - t) / n) }
            add(sl.bench, t / n)
        }
        return (order.map { parts[$0]!.0 }, order.map { parts[$0]!.1 })
    }

    static func index(_ p: ModelProfile, set: [Benchmark]) -> Double {
        guard !set.isEmpty else { return 0 }
        return set.reduce(0) { $0 + cachedScore($1, p) } / Double(set.count)
    }

    // MARK: Capability (a fixed yardstick)

    /// Ability on the eight kinds of text skill the index covers, in log10 effective-compute units (the same x the
    /// benchmark curves use), weighted equally whatever today's index happens to contain. Benchmark tuning doesn't count.
    static func ability(_ p: ModelProfile) -> Double {
        var sum = 0.0, n = 0
        for k in indexKinds {
            if let x = k.x(p) { sum += x; n += 1 }
        }
        return n == 0 ? p.c : sum / Double(n)
    }

    private static let indexKinds = BenchKind.allCases.filter(\.inIndex)

    /// GPT-4 (March 2023) as the game models it: the anchor of the capability scale.
    static let capabilityAnchor = ModelProfile(key: "anchor-gpt4", c: 5.04, reasoning: 0.1, code: 0, agent: 0, vision: true, contextK: 32,
                                               tuning: 0, chat: 0.8, safety: 55, lang: 0.15)
    private static let anchorAbility = ability(capabilityAnchor)

    /// Capability on a fixed scale: GPT-4 = 100, and every +10 is ten times the effective compute. Unlike the Intelligence
    /// Index it never re-bases or saturates, so the same model reads the same in 2019 and in 2035.
    static func capability(_ p: ModelProfile) -> Double { 100 + 10 * (ability(p) - anchorAbility) }

    /// How many times the effective compute a capability gap is worth (+10 = ×10).
    static func computeMultiple(capabilityGap g: Double) -> Double { pow(10, g / 10) }

    static func formatMultiple(_ m: Double) -> String {
        switch m {
        case ..<1.95: return "\(Fmt.trim(m, 1))×"
        case ..<20: return "\(Int(m.rounded()))×"
        case ..<1000: return "\(Int((m / 10).rounded()) * 10)×"
        default: return "\(Fmt.count(m, decimals: 0))×"
        }
    }

    /// METR-style 50% task horizon in minutes (GPT-4 ≈ 5 min, late-2025 frontier ≈ 3–5 h).
    static func taskHorizonMinutes(_ p: ModelProfile) -> Double {
        5 * exp(1.22 * (p.agenticX - 5.17))
    }

    static func formatHorizon(_ minutes: Double) -> String {
        switch minutes {
        case ..<1: return "\(max(1, Int((minutes * 60).rounded()))) sec"
        case ..<60: return "\(Int(minutes.rounded())) min"
        case ..<(60 * 24): return "\(Fmt.trim(minutes / 60, 1)) h"
        case ..<(60 * 24 * 7): return "\(Fmt.trim(minutes / 1440, 1)) days"
        case ..<(60 * 24 * 60): return "\(Fmt.trim(minutes / 10080, 1)) weeks"
        default: return "\(Fmt.trim(minutes / 43_200, 1)) months"
        }
    }

    // MARK: Successors

    /// A harder successor, pitched at the field (the best rival model, or the world frontier if rivals lag it) rather than
    /// at whoever leads: the field starts around 10%, so one runaway lab can't make every new test impossible for the rest.
    /// `force` commissions one even for a family that doesn't usually regenerate (when the live pool runs dry).
    static func makeSuccessor(of sat: Benchmark, family members: [Benchmark], fieldX: Double, date: Date, force: Bool = false) -> Benchmark? {
        guard let fam = families[sat.family], fam.regenerates || force else { return nil }
        let n = members.count + 1
        let last = members.max { $0.mid < $1.mid } ?? sat
        // Sharper than a sprawling predecessor (BALROG, LongBench…), so it lasts years rather than decades.
        let scale = clamp(last.scale, 0.4, 1.0)
        let mid = max(fieldX + 2.2 * scale, last.mid + 0.7)
        let intro = GameCalendar.addDays(date, 45)
        let name = fam.successor(n)
        return Benchmark(id: "gen_\(sat.family)_\(n)", name: name, family: sat.family, kind: sat.kind, introduced: intro.ym,
                         floor: 0, ceiling: 100, mid: mid, scale: scale, saturation: 90,
                         about: "Built after \(sat.name) saturated: harder, longer and contamination-proof \(fam.name.lowercased()) tasks.",
                         human: "—", generated: true, unit: sat.unit)
    }
}
