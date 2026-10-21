import Foundation

// MARK: - 3.9: the live model arena

/// The arena's categories, in the order every per-category array uses.
enum ArenaCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case writing, coding, math, vision, agents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .writing: "Writing"
        case .coding: "Coding"
        case .math: "Math"
        case .vision: "Vision"
        case .agents: "Agents"
        }
    }

    var symbol: String {
        switch self {
        case .writing: "pencil.and.scribble"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .math: "function"
        case .vision: "eye.fill"
        case .agents: "figure.walk.motion"
        }
    }

    var index: Int { ArenaCategory.allCases.firstIndex(of: self) ?? 0 }

    /// Share of the day's battles (among the categories that are open): most arena prompts are writing and code.
    var mix: Double {
        switch self {
        case .writing: 0.30
        case .coding: 0.28
        case .math: 0.14
        case .vision: 0.14
        case .agents: 0.14
        }
    }

    /// How much answer style (tone, formatting, length) sways voters. Writing is mostly taste; maths mostly right or wrong.
    var style: Double {
        switch self {
        case .writing: 1.0
        case .coding: 0.4
        case .math: 0.25
        case .vision: 0.6
        case .agents: 0.3
        }
    }

    /// The capability domains a category's prompts test.
    var domains: [(CapDomain, Double)] {
        switch self {
        case .writing: [(.social, 0.5), (.knowledge, 0.3), (.multilingual, 0.2)]
        case .coding: [(.coding, 1)]
        case .math: [(.math, 0.8), (.reasoning, 0.2)]
        case .vision: [(.vision, 1)]
        case .agents: [(.agents, 0.8), (.coding, 0.2)]
        }
    }

    /// When the category starts: this many years after the arena opens, but no later than it did for real
    /// (vision battles June 2024, WebDev agent battles December 2024).
    var opensAfter: (years: Double, realYear: Double) {
        switch self {
        case .writing, .coding, .math: (0, 0)
        case .vision: (1.1, 2024.45)
        case .agents: (1.6, 2024.95)
        }
    }

    /// What the battles look like, for the screen.
    var blurb: String {
        switch self {
        case .writing: "Stories, emails, essays, advice: voters pick the answer they'd rather read."
        case .coding: "Real programming questions; voters check which answer runs and reads better."
        case .math: "Word problems to olympiad questions, where a wrong answer loses whatever its style."
        case .vision: "Charts, photos, screenshots and handwriting: the model has to see to answer."
        case .agents: "WebDev-style battles: each model builds a working app from one prompt and voters try both."
        }
    }
}

/// The live arena: who plays, their ratings, the match feed and the weekly table.
struct ArenaState: Codable, Hashable, DefaultValue {
    static var defaultValue: ArenaState { ArenaState() }

    /// When the public arena opened in this game (nil until it does).
    @D var opened: Date? = nil
    /// Every model that has played: on the board now (`active`) or retired from it.
    @D var entries: [ArenaEntry] = []
    /// The latest battles, newest first.
    @D var feed: [ArenaMatch] = []
    /// The latest weekly top 10, overall.
    @D var top10: [ArenaTopRow] = []
    @D var lastWeekly: Date? = nil
    @D var weeks: Int = 0
    /// Overall rank of each model on the last weekly table (model id → rank), for demand and the leaderboard.
    @D var ranks: [String: Int] = [:]
    @D var matchCount: Int = 0
    @D var votes: Double = 0
    /// Your best overall rank so far with a released model (0: never ranked).
    @D var bestRank: Int = 0
    @D var weeksAtTop: Int = 0
    @D var firstTop: Date? = nil
    /// Who topped the last weekly table: a lab id ("player" for you) and the model shown.
    @D var leaderLab: String = ""
    @D var leaderModel: String = ""
    /// The board's "stay #1" goal while it runs.
    @D var pledge: ArenaPledge? = nil
    @D var pledgesMet: Int = 0
    @D var pledgesMissed: Int = 0
    @D var lastPledgeOffer: Date? = nil
    @D var lastUpsetNews: Date? = nil
    /// Rate limits for #1 headlines, so two close models swapping places don't make news every week.
    @D var lastTopNews: Date? = nil
    @D var lastLeaderNews: Date? = nil
    /// Codenames already used for anonymous tests (none repeats).
    @D var usedCodenames: Set<String> = []
    @D var seq: Int = 0
}

/// One model on (or once on) the arena.
struct ArenaEntry: Codable, Hashable, Identifiable {
    /// The model's id (AIModel or CompetitorModel).
    var id: String
    var name: String
    var lab: String
    /// "player" or a rival lab id.
    var labID: String
    var joined: Date
    var open: Bool = false
    var overall: Double
    /// Rating per category (ArenaCategory order).
    var ratings: [Double]
    /// Hidden strength per category from the model's capability profile (0: it can't play that category).
    var truth: [Double]
    var truthOverall: Double
    var matches: Int = 0
    var wins: Int = 0
    var catMatches: [Int] = [0, 0, 0, 0, 0]
    var votes: Double = 0
    /// Overall rating at each weekly table, oldest first.
    var history: [Double] = []
    var active: Bool = true
    var left: Date? = nil
    /// Placed from earlier public results when the arena was already running at the game's start (never provisional).
    var seeded: Bool = false
    /// Anonymous test of an unreleased model of yours: it plays under this name until you release it.
    var codename: String = ""
    var peakRank: Int = 0
    /// Testers have traced the codename to your lab.
    var leaked: Bool = false

    var isPlayer: Bool { labID == "player" }
    var anonymous: Bool { !codename.isEmpty }
    var shownName: String { anonymous ? codename : name }
    /// Too few battles for a settled rating (the arena marks these "preliminary").
    var provisional: Bool { !seeded && matches < 10 }

    func rating(_ c: ArenaCategory?) -> Double { c.map { $0.index < ratings.count ? ratings[$0.index] : 0 } ?? overall }
    func plays(_ c: ArenaCategory) -> Bool { c.index < truth.count && truth[c.index] > 0 }
}

/// One battle: a batch of crowd votes between two anonymous answers.
struct ArenaMatch: Codable, Hashable, Identifiable {
    var id: Int
    var date: Date
    var category: ArenaCategory
    var a: String
    var b: String
    /// Names as shown that day (a codename stays a codename in the feed).
    var aName: String
    var bName: String
    var aLab: String
    var bLab: String
    var votes: Int
    /// A's share of the votes (ties split).
    var shareA: Double
    /// Category ratings before the battle.
    var ratingA: Double
    var ratingB: Double
    /// A's category rating change (B moved the other way).
    var delta: Double
    var upset: Bool

    var aWon: Bool { shareA > 0.5 }
    var tie: Bool { abs(shareA - 0.5) < 0.005 }
}

/// A row of the weekly top 10.
struct ArenaTopRow: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var labID: String
    var lab: String
    var rating: Double
    var rank: Int
    /// Rank on the table before (0: new to the top 10).
    var prev: Int
    var anonymous: Bool = false
}

/// The board's goal after you take #1: hold the top spot on enough of the next weekly tables.
struct ArenaPledge: Codable, Hashable {
    var started: Date
    var model: String
    var weeksNeeded: Int
    var weeksTotal: Int
    var weeksSeen: Int = 0
    var weeksHeld: Int = 0
    var reward: Double
    var confidence: Double
}
