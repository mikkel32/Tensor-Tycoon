import Foundation

/// A rival lab's next frontier model: the training run behind it and the release it is building toward.
/// The real dates live here; what you see is filtered through the rumour mill (RivalIntel).
struct RivalProject: Codable, Hashable {
    /// The name the model will ship under.
    var name: String
    /// What insiders call it while it trains.
    var codename: String
    /// The release count this project will become (matches CompetitorState.releaseCount until it ships).
    var count: Int
    var started: Date
    /// Pre-training ends; post-training, RL and safety testing follow.
    var preEnd: Date
    /// The true release date (mirrors CompetitorState.nextRelease).
    var release: Date
    /// H100-equivalents on the run.
    var chips: Double
    var site: String
    /// Pre-training compute.
    var flops: Double
    /// How far the rumour mill's date is off, in days, before any intel corrects it.
    var dateBias: Double
    /// How far the rumour mill's capability estimate is off (log10 effective compute).
    var capBias: Double
    /// Capability gained (training longer) or lost (rushing) after a code red.
    var cAdjust: Double = 0
    var delays: Int = 0
    var rushed = false
    /// Rumour beats that already fired for this project.
    var leaked: Set<String> = []
    /// An Intelligence Index figure from leaked internal evals, if any.
    var evalLeak: Double? = nil
    /// The procedural part of the schedule (history is fixed, so no delays or code reds before Oct 2026).
    var procedural = false
    /// The rumour mill's call about six weeks before the planned release, kept to score it afterwards.
    var callCenter: Date? = nil
    var callC: Double = 0
    var callSD: Double = 0
}

/// One item from the rumour mill.
struct RivalRumor: Codable, Hashable, Identifiable {
    enum Reliability: String, Codable, Sendable {
        case confirmed = "Confirmed"
        case credible = "Credible"
        case speculative = "Speculative"
    }

    var id = StableID.next()
    var date: Date
    var labID: String
    var title: String
    var body: String
    var reliability: Reliability
    var kind: String
    /// Hidden until the release: the rumour was wrong.
    var wrong = false
    /// Which project it was about.
    var count: Int = 0
}

/// What the rumour mill currently says about a project.
struct RivalOutlook {
    var phase: RivalPhase
    /// Rumoured release window.
    var low: Date
    var high: Date
    var center: Date
    /// Half-width of the window in days.
    var halfWidth: Double
    /// Forecast Intelligence Index (80% band).
    var index: Double
    var indexLow: Double
    var indexHigh: Double
    /// Forecast capability (log10 effective compute) and its standard deviation.
    var c: Double
    var sd: Double
    /// Whether the start of the run has leaked (otherwise the training bars are guesses).
    var trainingKnown: Bool
}

enum RivalPhase: String, Sendable {
    case planning = "Planning"
    case pretraining = "Pre-training"
    case posttraining = "Post-training & RL"
    case redteam = "Safety testing"
    case imminent = "Launch imminent"

    var symbol: String {
        switch self {
        case .planning: "pencil.and.ruler.fill"
        case .pretraining: "flame.fill"
        case .posttraining: "slider.horizontal.3"
        case .redteam: "checkmark.shield.fill"
        case .imminent: "megaphone.fill"
        }
    }
}
