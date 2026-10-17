import Foundation

// MARK: - People

enum Role: String, Codable, CaseIterable, Identifiable, Sendable {
    case researcher, mlEngineer, infra, data, sales, safety, chipDesigner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .researcher: "Research Scientist"
        case .mlEngineer: "ML Engineer"
        case .infra: "Infrastructure Engineer"
        case .data: "Data Engineer"
        case .sales: "Sales & Partnerships"
        case .safety: "Safety Researcher"
        case .chipDesigner: "Chip Designer"
        }
    }

    var plural: String {
        switch self {
        case .researcher: "Researchers"
        case .mlEngineer: "ML Engineers"
        case .infra: "Infra Engineers"
        case .data: "Data Engineers"
        case .sales: "Sales & BD"
        case .safety: "Safety Team"
        case .chipDesigner: "Silicon Team"
        }
    }

    var symbol: String {
        switch self {
        case .researcher: "brain.head.profile"
        case .mlEngineer: "hammer.fill"
        case .infra: "server.rack"
        case .data: "cylinder.split.1x2.fill"
        case .sales: "briefcase.fill"
        case .safety: "checkmark.shield.fill"
        case .chipDesigner: "cpu"
        }
    }

    var effect: String {
        switch self {
        case .researcher: "Generates research points every day."
        case .mlEngineer: "Raises training MFU and keeps big runs stable."
        case .infra: "Keeps clusters up. Each one can babysit a few hundred accelerators."
        case .data: "Improves data quality (+capability) and synthetic-data throughput."
        case .sales: "Brings in enterprise deals and grows your brand."
        case .safety: "Raises your safety score, slows alignment drift in self-improvement runs."
        case .chipDesigner: "Designs your own AI accelerators: faster tape-outs, better chips, fewer respins."
        }
    }
}

struct Employee: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var role: Role
    var skill: Double
    var salary: Double
    var morale: Double = 75
    var hired: Date
    var star: Bool = false
    var equity: Double = 0
    @D var trait: String = ""
    @D var promoted: Bool = false
}

struct Candidate: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var role: Role
    var skill: Double
    var salary: Double
    var equity: Double
    var star: Bool
    var expires: Date
    var bio: String
    @D var trait: String = ""
}

// MARK: - Hardware

enum RentalTerm: String, Codable, CaseIterable, Identifiable {
    case onDemand = "On-demand"
    case reserved1y = "1-year reserved"
    case reserved3y = "3-year reserved"

    var id: String { rawValue }

    var discount: Double {
        switch self {
        case .onDemand: 1.0
        case .reserved1y: 0.68
        case .reserved3y: 0.48
        }
    }

    var months: Int? {
        switch self {
        case .onDemand: nil
        case .reserved1y: 12
        case .reserved3y: 36
        }
    }
}

struct OwnedBatch: Codable, Identifiable, Hashable {
    var id = UUID()
    var accelID: String
    var count: Int
    var siteID: UUID
    var purchased: Date
    var unitCost: Double
}

struct Rental: Codable, Identifiable, Hashable {
    var id = UUID()
    var accelID: String
    var count: Int
    var hourly: Double
    var term: RentalTerm
    var start: Date
    var end: Date?
}

struct HardwareOrder: Codable, Identifiable, Hashable {
    var id = UUID()
    var accelID: String
    var count: Int
    var siteID: UUID
    var unitCost: Double
    var ordered: Date
    var arrives: Date
}

struct Site: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: SiteKind
    var locationID: String
    var capacityKW: Double
    var cooling: Cooling
    var powerDeal: PowerDeal
    var opened: Date
    var ready: Date
    var capex: Double
    var monthlyFee: Double
    var expanding: Double = 0       // extra kW under construction
    var expansionReady: Date? = nil
    /// 3.3: capacity of later phases of a phased campus, not started yet (paid for as each phase starts).
    @D var plannedKW: Double = 0
    /// Size of each construction phase.
    @D var phaseKW: Double = 0
    /// The next phase is waiting for cash.
    @D var phaseBlocked: Bool = false

    var location: Location { LocationCatalog.byID[locationID] ?? LocationCatalog.all[0] }

    func isReady(_ date: Date) -> Bool { date >= ready }

    var pue: Double {
        switch kind {
        case .garage, .office: 1.55
        case .colo: cooling.basePUE + 0.07 + location.pueDelta * 0.5
        case .datacenter: cooling.basePUE + location.pueDelta
        }
    }

    var powerPrice: Double {
        switch kind {
        case .garage: 0.16
        case .office: 0.14
        case .colo: location.powerPrice * 1.1 * powerDeal.priceMultiplier
        case .datacenter: location.powerPrice * powerDeal.priceMultiplier
        }
    }

    var maxChipTDP: Double {
        switch kind {
        case .garage: 600
        case .office: 1_000
        case .colo, .datacenter: 100_000
        }
    }
}

// MARK: - Models & training

enum TrainMode: String, Codable, CaseIterable, Identifiable {
    case scratch = "Pre-train from scratch"
    case finetune = "Fine-tune an open model"
    case distill = "Distill from your model"
    var id: String { rawValue }
}

enum AttentionKind: String, Codable, CaseIterable, Identifiable {
    case mha = "Multi-head"
    case gqa = "Grouped-query"
    case mla = "Latent (MLA)"
    var id: String { rawValue }
}

enum MixerKind: String, Codable, CaseIterable, Identifiable {
    case transformer = "Transformer"
    case hybrid = "Hybrid SSM"
    case diffusion = "Diffusion LM"
    case alien = "Alien (xeno)"
    var id: String { rawValue }
}

enum OptimizerKind: String, Codable, CaseIterable, Identifiable {
    case adamw = "AdamW"
    case shampoo = "Shampoo / SOAP"
    case muon = "Muon"
    var id: String { rawValue }
}

enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case cosine = "Cosine"
    case wsd = "Warmup-Stable-Decay"
    var id: String { rawValue }
}

enum DataMix: String, Codable, CaseIterable, Identifiable {
    case balanced = "Balanced"
    case code = "Code-heavy"
    case stem = "Math & science"
    case multilingual = "Multilingual"
    case conversational = "Conversational"
    var id: String { rawValue }

    var detail: String {
        switch self {
        case .balanced: "The default web/code/books mix."
        case .code: "30% code: coding and agent scores up, chat a little flatter."
        case .stem: "Math, papers and textbooks: reasoning up, trivia down."
        case .multilingual: "A third non-English: global markets and multilingual scores."
        case .conversational: "Forums and dialogue: friendlier chat, weaker STEM."
        }
    }
}

/// RL compute as a share of pre-training compute.
enum RLLevel: Int, Codable, CaseIterable, Identifiable {
    case off = 0, light, standard, heavy, extreme
    var id: Int { rawValue }
    var label: String { ["Off", "Light", "Standard", "Heavy", "Extreme"][rawValue] }
    var share: Double { [0, 0.01, 0.05, 0.20, 0.60][rawValue] }
    var detail: String {
        ["No reasoning RL.", "1% of pre-training compute — a taste of o1.", "5% — a solid reasoning model.",
         "20% — o3-class reasoning.", "60% — Grok 4-style: RL compute rivals pre-training."][rawValue]
    }
}

struct ModelDesign: Codable, Hashable {
    var name: String = "Model-1"
    var mode: TrainMode = .scratch
    var baseModelRef: String? = nil
    var paramsB: Double = 1.0
    var activeFraction: Double = 1.0
    var tokensT: Double = 0.02
    var precision: Precision = .bf16
    var contextK: Int = 2
    var vision = false
    var audio = false
    var video = false
    var instruct = true
    var rlhf = false
    var reasoning = false
    var toolUse = false
    var safetyTraining = false
    var benchmarkTuning = false
    var accelID: String = "v100_16"
    var chips: Int = 8
    // Architecture & recipe
    var attention: AttentionKind = .mha
    var mixer: MixerKind = .transformer
    var optimizer: OptimizerKind = .adamw
    var schedule: ScheduleKind = .cosine
    var dataMix: DataMix = .balanced
    var syntheticShare: Double = 0
    var rlLevel: RLLevel = .standard
    var agentRL = false
    var mtp = false
    var anneal = false
    var useDPO = false

    var activeParamsB: Double { paramsB * activeFraction }
    var isMoE: Bool { activeFraction < 0.999 }
    var effectiveRL: RLLevel { reasoning ? (rlLevel == .off ? .standard : rlLevel) : .off }

    /// Identifies the "family" of recipe a scaling ladder validates.
    var recipeSignature: String {
        "\(isMoE ? "moe" : "dense")|\(mixer.rawValue)|\(optimizer.rawValue)|\(attention.rawValue)|\(precision.rawValue)"
    }
}

enum RunStatus: String, Codable {
    case running = "Training"
    case paused = "Paused"
    case postTraining = "Post-training"
    case done = "Complete"
    case cancelled = "Cancelled"
}

struct LossPoint: Codable, Hashable {
    var tokensT: Double
    var loss: Double
    @D var spike: Bool = false
    /// The scaling-law forecast for this point.
    @D var pred: Double = 0
    @D var gnorm: Double = 0
}

struct TrainCheckpoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var fraction: Double
    var tokensT: Double
    var loss: Double
    var c: Double
    var index: Double
    var date: Date
    var flopsDone: Double
    var forkedModelID: UUID? = nil
    @D var projected: Double = 0
    @D var projectedLow: Double = 0
    @D var projectedHigh: Double = 0
}

enum LRSchedule: Int, Codable, CaseIterable, Identifiable {
    case conservative = -1, standard = 0, aggressive = 1
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .conservative: "Conservative"
        case .standard: "Standard"
        case .aggressive: "Aggressive"
        }
    }
    var detail: String {
        switch self {
        case .conservative: "Low peak LR: very stable, slightly worse model."
        case .standard: "Tuned warmup + cosine decay."
        case .aggressive: "High LR: a bit better & faster — if it doesn't blow up."
        }
    }
    var spikeMult: Double { [0.35, 1.0, 2.3][rawValue + 1] }
    var qualityBonus: Double { [-0.025, 0, 0.03][rawValue + 1] }
    var speed: Double { [0.98, 1.0, 1.04][rawValue + 1] }
}

struct TrainingRun: Codable, Identifiable, Hashable {
    var id = UUID()
    var design: ModelDesign
    var status: RunStatus = .running
    var started: Date
    var flopsTotal: Double
    var flopsDone: Double = 0
    var postTrainFlops: Double = 0
    var postTrainDone: Double = 0
    var cost: Double = 0
    var loss: [LossPoint] = []
    var failures: Int = 0
    var note: String = ""
    var dataSnapshot: [String] = []
    var cFinal: Double? = nil
    @D var saved: [TrainCheckpoint] = []
    @D var lr: Int = 0
    @D var checkpointEvery: Double = 0
    @D var qualityPenalty: Double = 0
    @D var spikes: Int = 0
    @D var autoRollback: Bool = false
    @D var events: [String] = []
    @D var modelID: UUID? = nil
    @D var finished: Date? = nil
    // v3: realistic training
    var kind: RunKind = .full
    var forecast: RunForecast? = nil
    /// Hidden: how much better/worse than forecast this run truly is (log10 effective compute).
    var epsilon: Double = 0
    /// Hidden silent bug: penalty and the pre-training fraction where it starts (2 = no bug).
    var bugPenalty: Double = 0
    var bugOnset: Double = 2
    var bugFound = false
    /// What the team believes so far (posterior over epsilon).
    var revealMean: Double = 0
    var revealSigma: Double = 0
    var stageIndex: Int = 0
    var stageDone: Double = 0
    var stages: [RunStage] = []
    var interruptions: Int = 0
    var lostHours: Double = 0
    var dReasoning: Double = 0
    var dCode: Double = 0
    var dChat: Double = 0
    var dSafety: Double = 0
    var dLang: Double = 0
    var contaminated = false
    var rewardHacked = false
    var sycophantic = false
    var decided: Set<String> = []
    var emerged: Set<String> = []
    var proxyCompute: Double = 0
    // 3.3: ops agents watching the run
    /// Share of the run's chips watched by ops agents (refreshed daily).
    @D var opsCoverage: Double = 0
    /// Failures drained before they crashed the job.
    @D var prevented: Double = 0
    /// Nodes caught (and missed) silently corrupting gradients.
    @D var sdcCaught: Double = 0
    @D var sdcMissed: Double = 0

    var schedule: LRSchedule { LRSchedule(rawValue: lr) ?? .standard }
    var interval: Double { checkpointEvery > 0 ? checkpointEvery : 0.1 }

    var progress: Double { flopsTotal > 0 ? min(1, flopsDone / flopsTotal) : 0 }
}

enum RunKind: String, Codable {
    case full, proxy
}

/// A post-training stage with its compute budget.
struct RunStage: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var flops: Double
    var isPre: Bool
}

/// What the scaling-law forecast said when the run started.
struct RunForecast: Codable, Hashable {
    var c: Double
    var sigma: Double
    var index: Double
    var indexLow: Double
    var indexHigh: Double
    var tier: String
    var comparable: String
    var finalLoss: Double
}

/// A completed scaling ladder: small proxy runs that validate a recipe up to some compute.
struct ScalingFit: Codable, Hashable, Identifiable {
    var id = UUID()
    var signature: String
    var maxCompute: Double
    var date: Date
}

enum PublicationPolicy: String, Codable, CaseIterable, Identifiable {
    case open = "Open science"
    case selective = "Selective"
    case secret = "Secretive"
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .open: "Publish everything: +brand per paper, +10% research speed, stronger hires and easier headhunting. Your unique breakthroughs leak to every rival ~6 months after you finish them."
        case .selective: "Publish safety and minor work, keep your unique breakthroughs secret. The industry default."
        case .secret: "Publish nothing: rivals learn nothing from you, but top researchers prefer labs that publish — weaker candidates, harder headhunting, and your brand slowly erodes."
        }
    }
}

struct Deployment: Codable, Identifiable, Hashable {
    var id = UUID()
    var accelID: String
    var chips: Int
}

struct AIModel: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var design: ModelDesign
    var created: Date
    var c: Double
    var reasoning: Bool
    var reasoningBoost: Double
    var codeBoost: Double
    var arenaBonus: Double
    var scores: [String: Double]
    var index: Double
    var released: Bool = false
    var releaseDate: Date? = nil
    var api: Bool = false
    var openWeights: Bool = false
    var apiPrice: Double = 1.0
    var servingPrecision: Precision = .bf16
    var deployments: [Deployment] = []
    var usedShadowData: Bool = false
    var tuned: Bool = false
    var safety: Double = 50
    var lawsuitResolved = false
    var retired = false
    @D var agentBoost: Double = 0
    @D var efficiencyBoost: Double = 0
    @D var rsiGeneration: Int = 0
    @D var preview: Bool = false
    @D var safeguards: Bool = false
    @D var unsafeRelease: Bool = false
    /// Re-price daily to track the market for this capability level.
    @D var autoPrice: Bool = false
    var chatSkill: Double = 0.8
    var langSkill: Double = 0
    var longctxSkill: Double = 0
    var visSkill: Double = 0
    var cForecast: Double = 0
    var forecastSigma: Double = 0
    var tier: String = ""
    var keyTech: [String] = []
    // live stats (updated daily)
    var demandTokensDay: Double = 0
    var servedTokensDay: Double = 0
    var capacityTokensDay: Double = 0
    var revenueDay: Double = 0
    var tps: Double = 0
}

// MARK: - Market & business

struct EnterpriseDeal: Codable, Identifiable, Hashable {
    var id = UUID()
    var client: String
    var title: String
    var monthly: Double
    var tokensPerDay: Double
    var months: Int
    var monthsLeft: Int
    var minIndex: Double
    var minSafety: Double
    var expires: Date
    var modelID: UUID? = nil
    var active = false
    var breaches = 0
}

enum LoanKind: String, Codable, CaseIterable, Identifiable {
    case friends = "Friends & family loan"
    case bank = "Bank term loan"
    case gpuBacked = "GPU-backed loan"
    case venture = "Venture debt"
    case bond = "Corporate bond"
    var id: String { rawValue }
}

struct Loan: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: LoanKind
    var principal: Double
    var balance: Double
    var rate: Double
    var termMonths: Int
    var monthsLeft: Int
    var payment: Double
    var taken: Date
}

struct Holding: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var shares: Double
}

struct FundingRound: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var date: Date
    var amount: Double
    var preMoney: Double
    var lead: String
    var percent: Double
}

struct RaiseOffer: Codable, Identifiable, Hashable {
    var id = UUID()
    var investor: String
    var amount: Double
    var preMoney: Double
    var expires: Date
    var roundName: String
    var cloudCredits: Double = 0
}

enum NewsCategory: String, Codable, CaseIterable, Identifiable {
    case company = "Company"
    case hardware = "Hardware"
    case competitor = "Competitors"
    case market = "Market"
    case finance = "Finance"
    case policy = "Policy"
    case research = "Research"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .company: "building.2"
        case .hardware: "cpu"
        case .competitor: "person.2.wave.2"
        case .market: "chart.line.uptrend.xyaxis"
        case .finance: "dollarsign.circle"
        case .policy: "building.columns"
        case .research: "lightbulb"
        }
    }
}

struct NewsItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var title: String
    var body: String
    var category: NewsCategory
    var image: String? = nil
    var important = false
    var good: Bool? = nil
}

struct DecisionOption: Codable, Hashable {
    var label: String
    var detail: String
}

struct Decision: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: String
    var title: String
    var body: String
    var image: String?
    var options: [DecisionOption]
    var date: Date
    var amount: Double = 0
    var ref: String = ""
}

struct CompetitorModel: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var date: Date
    var c: Double
    var reasoning: Bool
    var scores: [String: Double]
    var index: Double
    var price: Double
    var open: Bool
    var tps: Double
    var paramsB: Double
}

struct CompetitorState: Codable, Identifiable, Hashable {
    var id: String
    var models: [CompetitorModel] = []
    var nextRelease: Date
    var releaseCount: Int = 0
    var valuation: Double = 0
    var computeH100e: Double = 0
    var brand: Double
    var apiShare: Double = 0
    var consumerShare: Double = 0
    var acquired = false
    @D var priceCut: Double = 0
    @D var agentShare: Double = 0
    /// H100-equivalents of your chips this lab has bought (ages out slowly).
    @D var armedH100e: Double = 0
    // 3.3: the business behind each lab
    @D var econReady: Bool = false
    @D var cash: Double = 0
    /// Annualised revenue (this month × 12).
    @D var revenueRun: Double = 0
    /// Monthly revenue, oldest first (last 36 months).
    @D var revenueHistory: [Double] = []
    @D var costMonth: Double = 0
    @D var computeCostMonth: Double = 0
    @D var headcount: Int = 0
    @D var totalRaised: Double = 0
    @D var rounds: [RivalRound] = []
    /// How many of the lab's real-world rounds have been applied.
    @D var historyIndex: Int = 0
    @D var isPublic: Bool = false
    @D var distressMonths: Int = 0
    /// Compute multiplier from how well funded the lab is (0 in old saves means 1).
    @D var fundingFactor: Double = 0
    @D var bankrupt: Bool = false
    /// How the lab left the market, if it did.
    @D var exitNote: String = ""
    /// 3.3: the run behind the lab's next release (Rival Watch).
    @D var project: RivalProject? = nil

    var def: CompetitorDef { CompetitorCatalog.byID[id]! }
    var funding: Double { fundingFactor > 0 ? fundingFactor : 1 }
    var lastRound: RivalRound? { rounds.last { $0.postMoney > 0 } }
    var latest: CompetitorModel? { models.last }
}

/// A rival lab's funding event.
struct RivalRound: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable { case equity, strategic, tender, debt, merger, ipo, rescue }
    var id = UUID()
    var date: Date
    var label: String
    var amount: Double
    var postMoney: Double
    var lead: String
    var kind: Kind
}

/// A rival that agreed to spend money on your compute when you invested in it.
struct ComputeCommitment: Codable, Hashable, Identifiable {
    var id = UUID()
    var labID: String
    var labName: String
    var monthly: Double
    var monthsLeft: Int
}

struct MonthRecord: Codable, Identifiable, Hashable {
    var id: Date { month }
    var month: Date
    var revAPI = 0.0
    var revConsumer = 0.0
    var revEnterprise = 0.0
    var revOther = 0.0
    @D var revAgents: Double = 0
    @D var revCloud: Double = 0
    @D var revChips: Double = 0
    @D var revLicensing: Double = 0
    @D var revLabor: Double = 0
    @D var interestIncome: Double = 0
    /// Upfront license fees and other one-off income (not recurring revenue).
    @D var oneOffIncome: Double = 0
    /// Cost of goods for chips you sell.
    @D var costChips: Double = 0
    var costRent = 0.0
    var costPower = 0.0
    var costSites = 0.0
    var costPayroll = 0.0
    var costData = 0.0
    var costMarketing = 0.0
    var costInterest = 0.0
    var costOther = 0.0
    var taxes = 0.0
    var capex = 0.0
    var cashEnd = 0.0
    var valuation = 0.0
    var users = 0.0
    var paidUsers = 0.0
    var apiTokensDay = 0.0
    var bestIndex = 0.0
    var chips = 0.0

    var revenue: Double { revAPI + revConsumer + revEnterprise + revOther + revAgents + revCloud + revChips + revLicensing + revLabor }
    /// Selling hardware and leasing compute: valued like a hardware business, not a software one.
    var hardwareRevenue: Double { revCloud + revChips }
    var opex: Double { costRent + costPower + costSites + costPayroll + costData + costMarketing + costOther + costChips }
    var profit: Double { revenue + interestIncome + oneOffIncome - opex - costInterest - taxes }
}

struct StockPoint: Codable, Hashable {
    var date: Date
    var price: Double
}

struct MarketModifiers: Codable, Hashable {
    var hype = 1.0
    var hardwarePrice = 1.0
    var consumerGPUPrice = 1.0
    var rentPrice = 1.0
    var leadTimeDays = 21.0
    var apiPricePressure = 1.0
    var buildDelay = 1.0
    var exportControls = false
    var euAIAct = false
    var copyrightHeat = 1.0
    var interestRate = 1.0
}

// MARK: - The whole game

struct GameState: Codable {
    var version = GameState.currentVersion
    var companyName: String
    var founderName: String
    var logoSymbol: String
    var logoColor: Int
    var difficulty: Difficulty
    var eraID: String
    var startDate: Date
    var date: Date
    var cash: Double
    var cloudCredits: Double = 0
    var rng: GameRNG

    var brand: Double = 10
    var safetyScore: Double = 30
    var market = MarketModifiers()

    // Research
    var researched: Set<String> = []
    var researchProgress: [String: Double] = [:]
    var researchQueue: [String] = []
    var researchChips: [String: Int] = [:]
    var rpToday: Double = 0

    // People
    var employees: [Employee] = []
    var candidates: [Candidate] = []
    var officeLevel = 0

    // Hardware
    var sites: [Site] = []
    var owned: [OwnedBatch] = []
    var rentals: [Rental] = []
    var orders: [HardwareOrder] = []

    // Models
    var runs: [TrainingRun] = []
    var models: [AIModel] = []
    var dataSources: Set<String> = ["web", "wiki", "code_open", "papers"]

    // Products
    var chatModelID: UUID? = nil
    var chatPrice: Double = 20
    var freeTier = true
    var marketingBudget: Double = 0
    var consumerUsers: Double = 0
    var paidUsers: Double = 0
    var consumerShare: Double = 0
    var consumerServedFraction: Double = 1
    var reliability: Double = 1
    var chatMoment: Double? = nil

    // Enterprise
    var deals: [EnterpriseDeal] = []

    // Finance
    var loans: [Loan] = []
    var rounds: [FundingRound] = []
    var founderShares: Double = 8_000_000
    var holdings: [Holding] = []
    var employeePoolShares: Double = 2_000_000
    var raiseOffers: [RaiseOffer] = []
    var raising = false
    var raiseFraction = 0.15
    var lastRaise: Date? = nil
    var isPublic = false
    var sharePrice: Double = 0
    var publicShares: Double = 0
    var stock: [StockPoint] = []
    var valuation: Double = 0
    var creditScore: Double = 600

    // Competitors & world
    var competitors: [CompetitorState] = []
    var news: [NewsItem] = []
    var unreadNews = 0
    var decisions: [Decision] = []
    var firedEvents: Set<String> = []
    var announcedHardware: Set<String> = []
    var availableHardware: Set<String> = []

    // History
    var history: [MonthRecord] = []
    var month: MonthRecord
    var achievements: Set<String> = []
    var lifetimeRevenue: Double = 0
    var lifetimeFLOPs: Double = 0
    var daysNegativeCash = 0
    var gameOver: String? = nil
    var exitValue: Double? = nil

    // v2 systems
    @D var rsiRuns: [RSIRun] = []
    @D var rsiRPToday: Double = 0
    @D var chipProjects: [ChipProject] = []
    @D var customChips: [CustomChip] = []
    @D var supplyDeals: [SupplyDeal] = []
    @D var agentModelID: UUID? = nil
    @D var agentPrice: Double = 100
    @D var agentSeats: Double = 0
    @D var agentShare: Double = 0
    @D var benchSaturated: [String: Date] = [:]
    @D var benchSaturatedBy: [String: String] = [:]
    @D var generatedBenchmarks: [Benchmark] = []
    @D var regulatoryFlags: Set<String> = []

    // v3 systems
    var researchResults: [String: Double] = [:]
    var exoticOwned: [String] = []
    var rivalTech: [String: [String]] = [:]
    var publication: PublicationPolicy = .selective
    var scalingFits: [ScalingFit] = []
    var techExperience: [String: Double] = [:]
    var maxRunCompute: Double = 0
    var partnerships: [Partnership] = []
    var partnerContacted: [String: Date] = [:]
    @D var lastHeadhunt: Date? = nil
    /// Your unique breakthroughs you published under an open-science policy (rivals adopt them ~6 months later).
    @D var publishedTech: [String: Date] = [:]

    // v4 systems: agent swarms, alien architectures, selling compute, personal wealth
    @D var swarms: [AgentSwarm] = []
    @D var swarmRPToday: Double = 0
    /// Mission levels (0–1) from today's swarms, read by training, silicon and safety.
    @D var swarmOps: Double = 0
    @D var swarmSilicon: Double = 0
    @D var swarmSafety: Double = 0
    @D var laborToday: Double = 0
    @D var xenoInsight: Double = 0
    @D var xenoInsightToday: Double = 0
    @D var alienArchs: [AlienArch] = []
    @D var chipLines: [ChipLine] = []
    /// Accelerator ID → chips leased out to other companies.
    @D var leases: [String: Int] = [:]
    @D var leaseRevenueToday: Double = 0
    @D var founderCash: Double = 0
    @D var lastFounderSale: Date? = nil

    // v4.1: traits, the board, acquisitions
    @D var traitsInitialized: Bool = false
    @D var doctrineID: String = ""
    @D var backgroundID: String = ""
    @D var perks: Set<String> = []
    @D var culturePoints: Int = 0
    @D var objectives: [Objective] = []
    @D var objectivesCompleted: Int = 0
    @D var objectivesFailed: Int = 0
    @D var boardConfidence: Double = 0
    @D var lastBoardThreat: Date? = nil
    @D var acquiredLabs: [String] = []
    @D var lastAntitrustBlock: Date? = nil
    @D var exclusiveSupplyUntil: Date? = nil
    /// The game ended with you leaving the CEO job but keeping your shares.
    @D var keptStake: Bool = false

    // v4.2: security, policy
    /// Model-weight security level (1–5; 0 in old saves means SL1).
    @D var securityRaw: Int = 0
    @D var securityTarget: Int = 0
    @D var securityDaysLeft: Double = 0
    @D var thefts: Int = 0
    @D var attacksFoiled: Int = 0
    /// Rival lab ID → capability of the weights they stole from you.
    @D var stolenC: [String: Double] = [:]
    @D var lobbyBudget: Double = 0
    @D var politicalCapital: Double = 0
    @D var bills: [PolicyBill] = []
    @D var lawsPassed: Set<String> = []
    @D var lawsFailed: Set<String> = []
    // v4.2: victories, rival alien tech
    @D var victories: Set<String> = []
    @D var monthsAtTop: Int = 0
    @D var monthsGuardian: Int = 0
    @D var apiShareNow: Double = 0
    /// Rival lab ID → when it found its own alien architecture.
    @D var rivalXeno: [String: Date] = [:]

    // v4.3 (3.3): signature secret, research director, unique breakthroughs, xenoscience
    @D var signatureID: String = ""
    @D var signatureLevel: Int = 0
    /// Research points put toward the next signature level.
    @D var signatureProgress: Double = 0
    /// Share of daily research that goes to the signature programme.
    @D var signatureShare: Double = 0
    @D var signatureRPToday: Double = 0
    /// The research director keeps the queue full.
    @D var autoResearch: Bool = false
    @D var researchFocus: String = ""
    @D var eurekas: Int = 0
    /// Unique breakthrough ID → mastery level (1–3).
    @D var exoticMastery: [String: Int] = [:]
    /// Fusions already announced.
    @D var fusionsSeen: Set<String> = []
    @D var exoticLicenses: [ExoticLicense] = []
    @D var xenoArtifacts: [XenoArtifact] = []
    /// What the next alien search looks for (XenoKind raw value; empty means architecture).
    @D var xenoTarget: String = ""
    /// Share of daily research spent decoding alien discoveries.
    @D var xenoStudyShare: Double = 0
    @D var studyRPToday: Double = 0
    @D var megaProjects: [MegaProject] = []
    // 3.3: the AI industry
    /// Rival lab ID → share of it you own, and what you paid.
    @D var rivalStakes: [String: Double] = [:]
    @D var rivalStakeCost: [String: Double] = [:]
    @D var computeCommitments: [ComputeCommitment] = []
    /// An AI-market correction is under way until this date.
    @D var correctionUntil: Date? = nil
    @D var lastCorrection: Date? = nil
    /// Industry valuation ÷ revenue run-rate (independent labs), for the bubble meter.
    @D var industryMultiple: Double = 0
    // 3.3: agent missions
    @D var swarmSecurity: Double = 0
    @D var swarmIntel: Double = 0
    // 3.3: Rival Watch
    /// Monthly spend on competitive intelligence.
    @D var intelBudget: Double = 0
    /// The rumour mill, newest first.
    @D var rumors: [RivalRumor] = []
    /// How past rumour-mill forecasts compared with what shipped, newest first.
    @D var watchRecord: [WatchCall] = []

    var totalShares: Double {
        founderShares + employeePoolShares + publicShares + holdings.reduce(0) { $0 + $1.shares }
    }

    var founderStake: Double { founderShares / max(1, totalShares) }

    var doctrine: LabDoctrine { LabDoctrine(rawValue: doctrineID) ?? .balanced }
    var background: FounderBackground { FounderBackground(rawValue: backgroundID) ?? .none }
    /// Doctrine + founder background + culture perks.
    var traits: TraitBonuses { CultureCatalog.bonuses(doctrine: doctrine, background: background, perks: perks) }
    var security: SecurityLevel { SecurityLevel(rawValue: max(1, securityRaw)) ?? .sl1 }
    var signature: SignatureSecret? { signatureLevel > 0 ? SignatureSecret(rawValue: signatureID) : nil }
    var focus: ResearchFocus { ResearchFocus(rawValue: researchFocus) ?? .balanced }
    var xenoTargetKind: XenoKind { XenoKind(rawValue: xenoTarget) ?? .architecture }

    /// Whether your signature is `secret` at `level` or higher.
    func signatureAt(_ secret: SignatureSecret, _ level: Int) -> Bool { signature == secret && signatureLevel >= level }

    /// You control the board while you hold a majority of the shares.
    var founderControls: Bool { founderStake >= 0.5 }

    /// Your stake at today's valuation plus everything you've cashed out.
    var founderNetWorth: Double { founderStake * valuation + founderCash }

    var year: Double { date.decimalYear }

    static let currentVersion = 3


    var releasedModels: [AIModel] { models.filter { $0.released && !$0.retired } }

    var bestModel: AIModel? { models.max { $0.c < $1.c } }

    var benchmarks: [Benchmark] { BenchmarkCatalog.real + generatedBenchmarks }
}

// MARK: - Self-improvement (RSI)

enum RSITarget: String, Codable, CaseIterable, Identifiable {
    case capabilities = "Capabilities"
    case research = "Automated research"
    case efficiency = "Inference efficiency"
    case architecture = "Architecture search"
    var id: String { rawValue }

    var blurb: String {
        switch self {
        case .capabilities: "The model rewrites its own training recipe, data and architecture. Each generation is smarter."
        case .research: "Thousands of model instances run experiments for you, producing research points around the clock."
        case .efficiency: "The model optimises its own kernels, quantisation and distillation: more tokens per chip."
        case .architecture: "The model redesigns its own architecture and the chip it runs on, piling up insight toward an alien architecture."
        }
    }

    var symbol: String {
        switch self {
        case .capabilities: "arrow.up.forward.circle.fill"
        case .research: "lightbulb.max.fill"
        case .efficiency: "gauge.with.dots.needle.100percent"
        case .architecture: "atom"
        }
    }
}

enum RSIStatus: String, Codable {
    case running = "Running"
    case paused = "Paused"
    case halted = "Halted"
}

struct RSICheckpoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var generation: Int
    var date: Date
    var c: Double
    var cMeasured: Double
    var alignment: Double
    var alignmentMeasured: Double
    var efficiency: Double
    var reasoning: Double
    var agent: Double
    var promotedModelID: UUID? = nil
}

struct RSIRun: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var baseModelID: UUID
    var design: ModelDesign
    var started: Date
    var status: RSIStatus = .running
    var target: RSITarget
    var autonomy: Int
    var oversight: Double
    var checkpointEvery: Int
    var accelID: String
    var chips: Int
    var generation = 0
    var genProgress = 0.0
    var cStart: Double
    var c: Double
    var cMeasured: Double
    var reasoning: Double
    var code: Double
    var agent: Double
    var arena: Double
    var alignment: Double = 92
    var alignmentMeasured: Double = 92
    var efficiency: Double = 1
    var rpGenerated: Double = 0
    var flops: Double = 0
    var cost: Double = 0
    var checkpoints: [RSICheckpoint] = []
    var log: [String] = []
    var incidents = 0
    var hackedGenerations = 0
    var lastDecision: Date? = nil

    static let autonomyNames = ["Supervised", "Semi-autonomous", "Fully autonomous"]
}

// MARK: - Custom silicon

enum ChipPartner: String, Codable, CaseIterable, Identifiable {
    case broadcom = "Broadcom"
    case marvell = "Marvell"
    case mediatek = "MediaTek"
    case inHouse = "In-house team"
    var id: String { rawValue }

    var quality: Double {
        switch self {
        case .broadcom: 0.08
        case .marvell: 0.03
        case .mediatek: 0.0
        case .inHouse: -0.05
        }
    }

    var costFactor: Double {
        switch self {
        case .broadcom: 1.0
        case .marvell: 0.85
        case .mediatek: 0.75
        case .inHouse: 0.6
        }
    }

    var speed: Double {
        switch self {
        case .broadcom: 0.9
        case .marvell, .mediatek: 1.0
        case .inHouse: 1.25
        }
    }

    var blurb: String {
        switch self {
        case .broadcom: "Designs Google's TPUs. Best results, premium price."
        case .marvell: "Custom silicon for hyperscalers like AWS and Microsoft."
        case .mediatek: "Cost-efficient partner, strong at inference parts."
        case .inHouse: "Cheapest per chip but slow — needs a big silicon team."
        }
    }
}

enum ChipFocus: String, Codable, CaseIterable, Identifiable {
    case training = "Training"
    case inference = "Inference"
    var id: String { rawValue }
}

struct ChipProject: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var partner: ChipPartner
    var focus: ChipFocus
    var budget: Double
    var started: Date
    var phase: Int = 0
    var phaseDaysLeft: Double
    var spent: Double = 0
    var respins: Int = 0
    var generation: Int
    var done = false

    static let phases = ["Architecture", "RTL & verification", "Tape-out", "First silicon bring-up", "Volume ramp"]
    static let phaseDays: [Double] = [90, 180, 60, 90, 75]
}

struct CustomChip: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var focus: ChipFocus
    var available: Date
    var process: String
    var memoryGB: Double
    var memoryType: String
    var bandwidthTBs: Double
    var bf16: Double
    var fp8: Double
    var fp4: Double
    var tdpW: Double
    var unitCost: Double
    var decodeEff: Double
    var scaleUp: Int
    var generation: Int
    /// Designed by your agents from an alien architecture.
    @D var alien: Bool = false
}

// MARK: - Supply agreements

struct SupplyDeal: Codable, Identifiable, Hashable {
    var id = UUID()
    var vendor: String
    var annualCommit: Double
    var yearsLeft: Int
    var start: Date
    var nextSettlement: Date
    var spentThisYear: Double = 0
    var discount: Double
}
