import Foundation

enum EventEffect: Sendable {
    case hype(Double)
    case hardware(Double)
    case consumerGPU(Double)
    case rent(Double)
    case leadTime(Double)
    case apiPrice(Double)
    case exportControls
    case euAIAct
    case copyrightHeat(Double)
    case buildDelay(Double)
    case chatMoment
}

struct HistoricalEvent: Identifiable, Sendable {
    let id: String
    let date: Date
    let title: String
    let body: String
    let category: NewsCategory
    let image: String?
    let effects: [EventEffect]
}

enum EventCatalog {
    static func d(_ y: Int, _ m: Int, _ day: Int) -> Date { GameCalendar.date(y, m, day) }

    /// Real industry events (2017–2026). Lab-specific events are attributed to the game's fictional rivals.
    static let historical: [HistoricalEvent] = [
        HistoricalEvent(id: "attention", date: d(2017, 6, 12), title: "\"Attention Is All You Need\" published",
                        body: "Eight researchers introduce the Transformer, an architecture built entirely on attention. It trains far faster than recurrent networks on parallel hardware.",
                        category: .research, image: "wafer_closeup", effects: []),
        HistoricalEvent(id: "gpt2_withheld", date: d(2019, 2, 14), title: "Prometheus Labs withholds PRM-2: \"too dangerous\"",
                        body: "Citing misuse risks, Prometheus releases only a small version of its 1.5B-parameter language model. The press is captivated.",
                        category: .competitor, image: nil, effects: [.hype(0.05)]),
        HistoricalEvent(id: "covid", date: d(2020, 3, 16), title: "Pandemic shock: markets crash, Fed cuts rates to zero",
                        body: "Stocks plunge as COVID-19 spreads. The Federal Reserve slashes rates to near zero — and soon cheap money floods into tech.",
                        category: .finance, image: "stock_exchange", effects: [.hype(-0.15), .hardware(0.05)]),
        HistoricalEvent(id: "zirp", date: d(2020, 11, 1), title: "Zero rates fuel a venture capital boom",
                        body: "With money nearly free, venture funds raise record amounts. AI startups are suddenly easy to fund.",
                        category: .finance, image: "sf_skyline", effects: [.hype(0.2)]),
        HistoricalEvent(id: "chip_shortage", date: d(2021, 1, 15), title: "Global chip shortage: GPU prices soar",
                        body: "Pandemic demand, crypto mining and fab constraints push graphics cards to 2x list price. Lead times stretch for months.",
                        category: .hardware, image: "wafer", effects: [.consumerGPU(0.8), .hardware(0.15), .leadTime(30)]),
        HistoricalEvent(id: "eth_merge", date: d(2022, 9, 15), title: "Ethereum's Merge ends GPU mining",
                        body: "Proof-of-stake makes mining GPUs obsolete overnight. A flood of used cards hits the market.",
                        category: .hardware, image: "rtx_3090", effects: [.consumerGPU(-0.3)]),
        HistoricalEvent(id: "export_2022", date: d(2022, 10, 7), title: "US export controls ban A100/H100 sales to China",
                        body: "New rules restrict advanced AI chips and chipmaking tools. Chinese labs must turn to cut-down parts and domestic accelerators.",
                        category: .policy, image: "wafer_closeup", effects: [.exportControls]),
        HistoricalEvent(id: "chatgpt", date: d(2022, 11, 30), title: "Prometheus launches \"Spark\" — 1M users in 5 days",
                        body: "A free chatbot built on PRM-3.5 becomes the fastest-growing consumer app in history. Every boardroom now has an AI strategy.",
                        category: .competitor, image: "sf_skyline", effects: [.chatMoment, .hype(0.45)]),
        HistoricalEvent(id: "h100_shortage", date: d(2023, 4, 1), title: "H100 shortage: lead times hit a year",
                        body: "Every lab and cloud wants Hoppers. Allocation goes to the biggest customers, rental prices spike and resellers charge a premium.",
                        category: .hardware, image: "h100_stack", effects: [.hardware(0.35), .rent(0.4), .leadTime(120)]),
        HistoricalEvent(id: "pause_letter", date: d(2023, 3, 22), title: "Open letter calls for a 6-month pause on giant AI training",
                        body: "Thousands of researchers and executives sign. Nobody pauses, but AI safety becomes a mainstream topic.",
                        category: .policy, image: nil, effects: []),
        HistoricalEvent(id: "export_2023", date: d(2023, 10, 17), title: "Export controls tightened: A800/H800 banned",
                        body: "The US closes loopholes on cut-down datacenter GPUs. Huawei's Ascend line becomes China's main option.",
                        category: .policy, image: "wafer_closeup", effects: []),
        HistoricalEvent(id: "eu_deal", date: d(2023, 12, 8), title: "EU reaches political deal on the AI Act",
                        body: "The world's first comprehensive AI law will impose transparency and safety duties on general-purpose models.",
                        category: .policy, image: nil, effects: []),
        HistoricalEvent(id: "eu_force", date: d(2024, 8, 1), title: "EU AI Act enters into force",
                        body: "Obligations for general-purpose AI models phase in over the next year. Frontier labs need evaluations and documentation.",
                        category: .policy, image: nil, effects: []),
        HistoricalEvent(id: "nuclear", date: d(2024, 9, 20), title: "Nuclear comeback: a shuttered reactor will restart to power datacenters",
                        body: "A 20-year power deal revives a famous plant. Nuclear PPAs are now available for your sites.",
                        category: .market, image: "nuclear", effects: []),
        HistoricalEvent(id: "stargate", date: d(2025, 1, 21), title: "\"Stargate\": a $500B AI infrastructure plan announced",
                        body: "A consortium pledges half a trillion dollars for US AI datacenters. GPU demand forecasts jump again.",
                        category: .market, image: "dc_construction", effects: [.hype(0.12), .hardware(0.05)]),
        HistoricalEvent(id: "r1_shock", date: d(2025, 1, 27), title: "Dragon Lake R1 shock: NVIDIA loses ~$590B in a day",
                        body: "An open reasoning model trained for a fraction of US budgets matches the best closed models. Investors panic about AI capex; API prices fall.",
                        category: .competitor, image: "stock_exchange", effects: [.hype(-0.25), .apiPrice(-0.25), .hardware(-0.06)]),
        HistoricalEvent(id: "eu_gpai", date: d(2025, 8, 2), title: "EU AI Act duties for general-purpose AI take effect",
                        body: "Frontier models must now ship with evaluations, copyright policies and incident reporting. Releasing near-frontier models without safety evals risks fines.",
                        category: .policy, image: nil, effects: [.euAIAct]),
        HistoricalEvent(id: "settlement", date: d(2025, 9, 5), title: "Record $1.5B copyright settlement over pirated books",
                        body: "An AI lab agrees to pay about $3,000 per book after training on shadow-library downloads. Pirated training data is now radioactive.",
                        category: .policy, image: nil, effects: [.copyrightHeat(1.5)]),
        HistoricalEvent(id: "groq_deal", date: d(2025, 12, 24), title: "NVIDIA licenses Groq's inference technology in a ~$20B deal",
                        body: "The GPU giant takes a non-exclusive license to the LPU design and hires much of Groq's leadership. Specialised inference chips are hot.",
                        category: .hardware, image: "groq_lpu", effects: []),
        HistoricalEvent(id: "memory_crunch", date: d(2026, 1, 10), title: "Memory crunch: HBM and DRAM prices surge",
                        body: "AI demand absorbs nearly all high-bandwidth memory output. Memory now dominates accelerator bills of materials and prices rise.",
                        category: .hardware, image: "wafer", effects: [.hardware(0.15), .consumerGPU(0.2)]),
        HistoricalEvent(id: "tpu8", date: d(2026, 4, 22), title: "Google splits the TPU line: TPU 8t for training, TPU 8i for inference",
                        body: "TPU 8t superpods reach 9,600 chips and 121 FP4 exaflops; TPU 8i packs 384 MB of SRAM for serving. Cloud access is expected late 2026.",
                        category: .hardware, image: "tpu_v4", effects: []),
        HistoricalEvent(id: "grid_crunch", date: d(2027, 4, 1), title: "Grid crunch: interconnection queues stretch past five years",
                        body: "Utilities can't keep up with gigawatt requests. New datacenters take longer unless they bring their own power. (Projected event)",
                        category: .market, image: "substation", effects: [.buildDelay(0.35)]),
    ]

    static func hypeBase(_ y: Double) -> Double {
        interpolate([(2016, 1.0), (2020.5, 1.05), (2022.85, 1.0), (2023.2, 1.3), (2024.5, 1.38), (2025.5, 1.42), (2026.5, 1.45), (2028, 1.3), (2031, 1.2)], at: y)
    }
}

struct Achievement: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(id: "first_model", title: "Hello, World", detail: "Finish training your first model.", symbol: "sparkle"),
        Achievement(id: "first_release", title: "Ship It", detail: "Release a model to the public.", symbol: "shippingbox.fill"),
        Achievement(id: "first_revenue", title: "First Dollar", detail: "Earn revenue from AI.", symbol: "dollarsign.circle.fill"),
        Achievement(id: "million", title: "Seven Figures", detail: "Earn $1M in lifetime revenue.", symbol: "banknote.fill"),
        Achievement(id: "billion_rr", title: "Billion-Dollar Run-Rate", detail: "Reach $1B annualised revenue.", symbol: "chart.line.uptrend.xyaxis"),
        Achievement(id: "hundred_billion_rr", title: "Hyperscaler", detail: "Reach $100B annualised revenue.", symbol: "globe.americas.fill"),
        Achievement(id: "profitable", title: "In the Black", detail: "Post a profitable month.", symbol: "plus.forwardslash.minus"),
        Achievement(id: "unicorn", title: "Unicorn", detail: "Reach a $1B valuation.", symbol: "star.circle.fill"),
        Achievement(id: "decacorn", title: "Decacorn", detail: "Reach a $10B valuation.", symbol: "star.square.fill"),
        Achievement(id: "trillion", title: "Trillion-Dollar Club", detail: "Reach a $1T valuation.", symbol: "crown.fill"),
        Achievement(id: "chips_1k", title: "Cluster", detail: "Control 1,000 accelerators.", symbol: "cpu"),
        Achievement(id: "chips_100k", title: "Colossus", detail: "Control 100,000 accelerators.", symbol: "cpu.fill"),
        Achievement(id: "chips_1m", title: "A Million Accelerators", detail: "Control 1,000,000 accelerators.", symbol: "square.grid.4x3.fill"),
        Achievement(id: "gigawatt", title: "Gigawatt", detail: "Own 1 GW of datacenter capacity.", symbol: "bolt.fill"),
        Achievement(id: "gpt3", title: "Few-Shot Learner", detail: "Train a GPT-3-class model.", symbol: "text.bubble.fill"),
        Achievement(id: "gpt4", title: "Sparks of AGI", detail: "Train a GPT-4-class model.", symbol: "brain.fill"),
        Achievement(id: "frontier", title: "Frontier Lab", detail: "Hold the #1 model on the Intelligence Index.", symbol: "trophy.fill"),
        Achievement(id: "arena", title: "Arena Champion", detail: "Top the LMArena Elo leaderboard.", symbol: "medal.fill"),
        Achievement(id: "reasoner", title: "Let Me Think", detail: "Release a reasoning model.", symbol: "lightbulb.max.fill"),
        Achievement(id: "open", title: "Open Weights", detail: "Release a model's weights.", symbol: "lock.open.fill"),
        Achievement(id: "ipo", title: "Ding Ding Ding", detail: "Take your company public.", symbol: "bell.fill"),
        Achievement(id: "chat_moment", title: "You Are the ChatGPT Moment", detail: "Launch a chatbot that ignites the consumer AI boom before November 2022.", symbol: "bubble.left.and.bubble.right.fill"),
        Achievement(id: "researchers", title: "Brain Trust", detail: "Employ 100 research scientists.", symbol: "person.3.fill"),
        Achievement(id: "tpu", title: "Tensor Tourist", detail: "Rent 1,000 TPUs at once.", symbol: "square.grid.3x3.fill"),
        Achievement(id: "superintelligence", title: "AGI", detail: "Intelligence Index ≥ 90 on the current index, ARC-AGI-3 ≥ 85% and Humanity's Last Exam ≥ 90%.", symbol: "infinity"),
        Achievement(id: "rsi_start", title: "Self-Improver", detail: "Start a recursive self-improvement run.", symbol: "arrow.triangle.2.circlepath"),
        Achievement(id: "explosion", title: "Intelligence Explosion", detail: "Gain +1.5 capability in a single self-improvement run.", symbol: "burst.fill"),
        Achievement(id: "aligned_asi", title: "Aligned Superintelligence", detail: "Promote a checkpoint far beyond the frontier with alignment ≥ 80.", symbol: "checkmark.seal.fill"),
        Achievement(id: "silicon", title: "Tape-Out", detail: "Ship your own custom AI chip.", symbol: "cpu"),
        Achievement(id: "partner", title: "Strategic Ally", detail: "Sign a compute partnership with a chip or cloud giant.", symbol: "signature"),
        Achievement(id: "genius", title: "Genius Run", detail: "Train a model that beats its forecast by 5+ points.", symbol: "crown.fill"),
        Achievement(id: "ladder", title: "Predictable Scaling", detail: "Run a scaling ladder before a big training run.", symbol: "chart.line.uptrend.xyaxis"),
        Achievement(id: "unique_tech", title: "Secret Sauce", detail: "Complete one of your lab's unique breakthroughs.", symbol: "atom"),
        Achievement(id: "tpu_owner", title: "TPU Owner", detail: "Buy Google TPUs for your own datacenter.", symbol: "square.grid.3x3.fill"),
        Achievement(id: "bench_breaker", title: "Benchmark Breaker", detail: "Be the first to saturate a benchmark.", symbol: "chart.bar.xaxis.ascending"),
        Achievement(id: "agents", title: "Agentic", detail: "Reach 1M paid agent seats.", symbol: "figure.walk.motion"),
        Achievement(id: "checkpoint_fork", title: "Early Access", detail: "Fork a mid-training checkpoint into a preview model.", symbol: "arrow.triangle.branch"),
    ]

    static let byID: [String: Achievement] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
