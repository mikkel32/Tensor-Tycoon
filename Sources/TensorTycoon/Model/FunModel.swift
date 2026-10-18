import Foundation

// MARK: - 3.5: fun systems — conferences, challenges, hackathons, scenarios

/// How a paper fared.
enum PaperOutcome: String, Codable, Sendable {
    case submitted, rejected, poster, oral, best

    var label: String {
        switch self {
        case .submitted: "Under review"
        case .rejected: "Rejected"
        case .poster: "Poster"
        case .oral: "Oral talk"
        case .best: "Best paper"
        }
    }

    var symbol: String {
        switch self {
        case .submitted: "hourglass"
        case .rejected: "xmark.circle"
        case .poster: "doc.richtext"
        case .oral: "mic.fill"
        case .best: "rosette"
        }
    }
}

/// One paper you sent to a conference.
struct PaperRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var venue: String
    var year: Int
    var title: String
    /// The research item (or "model:<name>") it writes up.
    var source: String
    /// Quality from 0 to 1, rolled when it was written.
    var quality: Double
    /// It revealed one of your unique breakthroughs.
    var reveal = false
    var outcome: PaperOutcome = .submitted
}

/// A conference that has happened: who won best paper, how many papers each lab got in, who gave the keynote.
struct ConfEdition: Codable, Identifiable, Hashable {
    var id: String { "\(venue)|\(year)" }
    var venue: String
    var year: Int
    var bestLab: String
    var bestTitle: String
    /// Lab ID ("player" for you) → accepted papers.
    var accepted: [String: Int] = [:]
    var keynote: String = ""
}

/// One edition of a public challenge.
struct ContestResult: Codable, Identifiable, Hashable {
    var id: String { "\(contest)|\(year)" }
    var contest: String
    var year: Int
    /// Lab IDs ("player" for you) and scores, best first.
    var standings: [ContestEntry] = []
    var purse: Double = 0
    /// The grand prize was claimed this edition, by the winner.
    var grand = false
    /// The bar the grand prize asked for.
    var bar: Double = 0
}

struct ContestEntry: Codable, Hashable {
    var lab: String
    var model: String
    var score: Double
}

enum HackTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case wild, demo, prototype

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wild: "Wild ideas"
        case .demo: "Demo day"
        case .prototype: "Product prototypes"
        }
    }

    var blurb: String {
        switch self {
        case .wild: "Everyone chases the idea they never get time for. Most go nowhere; one might jump-start your research."
        case .demo: "Build the flashiest thing your models can do and post it. A hit lifts your brand and the public's mood about you."
        case .prototype: "Wire your models into a product a customer would pay for. A good one turns into a paid pilot."
        }
    }

    var symbol: String {
        switch self {
        case .wild: "lightbulb.max.fill"
        case .demo: "play.rectangle.fill"
        case .prototype: "hammer.fill"
        }
    }
}

/// A hackathon week: running, or done with its result.
struct Hackathon: Codable, Identifiable, Hashable {
    var id = UUID()
    var theme: HackTheme
    var started: Date
    var ends: Date
    var people: Int
    var done = false
    /// 0 flop, 1 decent, 2 hit.
    var tier = 0
    var headline = ""
    var detail = ""
}

/// How a scenario ended.
struct ScenarioOutcome: Codable, Hashable {
    var won: Bool
    var date: Date
    var score: Int
    var summary: String
}

/// Everything the fun systems remember (one field on GameState, so older saves load with it empty).
struct FunState: Codable, Hashable, DefaultValue {
    static var defaultValue: FunState { FunState() }

    /// Your submissions, newest first.
    @D var papers: [PaperRecord] = []
    /// Conferences that have happened, newest first.
    @D var editions: [ConfEdition] = []
    /// Research items (and model write-ups) already turned into papers.
    @D var writtenUp: Set<String> = []
    @D var keynotes: Int = 0
    /// "founder|<year>" or "scientist|<year>" once you've accepted the Meridian keynote.
    @D var keynotePlan: String = ""
    /// Challenge editions decided so far, newest first.
    @D var contests: [ContestResult] = []
    /// Challenge ID → how many grand prizes have been claimed (each one raises the bar).
    @D var grandClaims: [String: Int] = [:]
    @D var prizeMoney: Double = 0
    /// Hackathons, newest first (the first may be running).
    @D var hackathons: [Hackathon] = []
    /// The challenge-mode scenario this game is playing ("" for a sandbox game) and how it ended.
    @D var scenarioID: String = ""
    @D var scenarioOutcome: ScenarioOutcome? = nil
    /// Your valuation when the scenario began.
    @D var scenarioStartValue: Double = 0
    /// When you first held #1 on the Intelligence Index.
    @D var firstNo1: Date? = nil
    /// A scenario's scripted event already happened.
    @D var scripted: Set<String> = []

    init() {}
}
