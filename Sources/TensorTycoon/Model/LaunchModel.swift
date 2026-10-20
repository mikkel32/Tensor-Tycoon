import Foundation

// MARK: - 3.7: launches

/// A rival's answer to one of your launches. Rivals react with a lag: the answer is queued at launch with its odds and
/// a due date, shown as "expected" until then, and rolled (hashed, not from the RNG) when it falls due.
struct LaunchResponse: Codable, Hashable, Identifiable {
    var id = StableID.next()
    var lab: String
    /// "price" (cuts API prices) or "counter" (answers with its own event and steals the spotlight).
    var kind: String
    var odds: Double
    var due: Date
    /// nil until due; then whether the lab actually answered.
    @D var happened: Bool? = nil
    @D var note: String = ""
}

/// The launch-day report, written a week after release.
struct LaunchReport: Codable, Hashable {
    var date: Date
    /// Chat users gained since launch day (negative when the app shrank).
    var signUps: Double
    var chatUsers: Double
    /// The model's API and total traffic, and what your API sold on the eve of launch.
    var apiTokensDay: Double
    var tokensDay: Double
    var tokensBefore: Double
    var servedShare: Double
    var revenueDay: Double
    var rank: Int
    var index: Double
    /// −1 (hostile) … +1 (glowing).
    var pressTone: Double
    var quotes: [String] = []
    var benchmarks: [String] = []
    var rivals: [String] = []
    var stakeholders: [String] = []
    /// "beat", "on" or "below".
    var verdict: String
    var verdictText: String
    @D var leads: Int = 0
    // 3.8: the model as the market met it
    @D var architecture: String = ""
    @D var pricePerM: Double = 0
    @D var servingPerM: Double = 0
    @D var tokensPerSec: Double = 0
    /// Product lines and API segments it powers, and your API share on the eve of launch and a week later.
    @D var powers: [String] = []
    @D var segments: [String] = []
    @D var apiShareBefore: Double = 0
    @D var apiShare: Double = 0
    /// What the launch moved in the market (enterprise leads won from rivals, developer ecosystem, investors).
    @D var moves: [String] = []
}

/// One launch: the plan, what it changed on the day, the reactions it queued and (after a week) its report.
struct LaunchRecord: Codable, Hashable, Identifiable {
    var id = StableID.next()
    var modelID: UUID
    var modelName: String
    var date: Date
    var plan: LaunchPlan
    var rank: Int
    var index: Double
    /// Your best index before this launch (nil for your first).
    var previousBest: Double?
    var brandGain: Double
    var cost: Double
    /// Chat users and the demand on your other live models (tokens/day) on launch day (the report's baselines).
    var usersBefore: Double
    var tokensBefore: Double
    var leadsBefore: Int
    /// Who launched it: "" for you, "delegate" or "family" for automation.
    @D var by: String = ""
    @D var responses: [LaunchResponse] = []
    @D var report: LaunchReport? = nil
    /// A second marketing wave bought after a weak first week.
    @D var secondWave: Date? = nil
    /// A rival's counter-event cut the launch's buzz short from this date.
    @D var upstaged: Date? = nil
    // 3.8
    /// Your API share the day before launch.
    @D var apiShareBefore: Double = 0
    /// A hand-set price the pricing stance replaced (restored when the stance ends; 0 when auto-priced), and the
    /// price the stance set.
    @D var priorPrice: Double = 0
    @D var stancePrice: Double = 0
    @D var priceSettled: Bool = false
    /// Post-training passes the model had at launch (a research preview's feedback discounts the next one).
    @D var passesAtLaunch: Int = 0
    /// Limited-access testing: the day testers handed over and the model went on general sale.
    @D var generalRelease: Date? = nil
}

/// 3.8: what launches leave behind in the market after the day itself.
struct MarketMovesState: Codable, Hashable, DefaultValue {
    static var defaultValue: MarketMovesState { MarketMovesState() }
    /// Developers building on your models (0–100): fed by open weights, API share and developer standing, it lifts API
    /// demand and fades slowly when you stop feeding it.
    @D var devEcosystem: Double = 0
    /// Your lab's leaderboard rank at the last monthly check (0 = nothing released yet).
    @D var lastRank: Int = 0
    /// What investors make of your rank changes (−1 … +1): jumps when you climb or fall, fades over months.
    @D var rankMomentum: Double = 0
    /// Lifetime: contracts lost to a rival at renewal, and leads launches won from rivals.
    @D var churned: Int = 0
    @D var leadsWon: Int = 0
    /// Recent moves in plain words, newest first.
    @D var log: [String] = []
    /// The last time a rival pivoted to the domain where you're weakest (RivalStrategy.pivot).
    @D var lastPivot: Date? = nil
}

// MARK: - 3.7: company stages

/// How big a company you've become. Each stage has explicit criteria and unlocks a power in an existing system.
enum CompanyStage: Int, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case garage, startup, scaleUp, frontierLab, hyperscaler, civilisational
    var id: Int { rawValue }
    static func < (a: CompanyStage, b: CompanyStage) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .garage: "Garage"
        case .startup: "Startup"
        case .scaleUp: "Scale-up"
        case .frontierLab: "Frontier Lab"
        case .hyperscaler: "Hyperscaler"
        case .civilisational: "Civilisational"
        }
    }

    var symbol: String {
        switch self {
        case .garage: "wrench.and.screwdriver.fill"
        case .startup: "lightbulb.fill"
        case .scaleUp: "chart.line.uptrend.xyaxis"
        case .frontierLab: "flag.checkered"
        case .hyperscaler: "server.rack"
        case .civilisational: "globe.americas.fill"
        }
    }

    var blurb: String {
        switch self {
        case .garage: "A few people, borrowed GPUs and a model nobody has heard of."
        case .startup: "A real product with paying customers."
        case .scaleUp: "A top-ten lab with a sales team and a policy office."
        case .frontierLab: "One of the handful of labs that set the pace."
        case .hyperscaler: "A compute empire and a model at the very top."
        case .civilisational: "A company the world's future runs through."
        }
    }

    var next: CompanyStage? { CompanyStage(rawValue: rawValue + 1) }
}

/// Your stage and when you reached each one.
struct ProgressionState: Codable, Hashable, DefaultValue {
    static var defaultValue: ProgressionState { ProgressionState() }
    /// Set once the stage has been worked out (new games and older saves, silently).
    @D var ready: Bool = false
    @D var stage: Int = 0
    /// Stage raw value → when it was reached. Stages credited silently on load have no ceremony.
    @D var reached: [Int: Date] = [:]
    /// Stages credited when an older save was loaded (no news, no rewards).
    @D var credited: Set<Int> = []
    /// The latest promotion, for the ceremony card.
    @D var lastPromotion: Date? = nil
    /// Your lab's leaderboard rank at the last weekly check (0 = nothing released).
    @D var rank: Int = 0
    /// 3.8: features a save was already using when stages began to gate them (Progression.Feature raw values): kept
    /// open whatever the stage. Worked out once (`gatesChecked`), with the subsidiaries it already ran.
    @D var grandfathered: Set<String> = []
    @D var gatesChecked: Bool = false
    @D var grandfatheredSlots: Int = 0

    var current: CompanyStage { CompanyStage(rawValue: stage) ?? .garage }
}
