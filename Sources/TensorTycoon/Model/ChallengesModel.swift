import Foundation

// MARK: - 3.9: grand challenges and the open-source community

/// Where one edition of a grand challenge stands.
enum ChallengeStatus: String, Codable, Sendable {
    /// Announced: entries open until `entryCloses`.
    case open
    /// You entered; results on `results`.
    case entered
    /// You didn't enter (or couldn't); the field still competes.
    case watching
    /// Results are in.
    case done
}

/// How hard you go at an edition you enter.
enum ChallengeEffort: Int, Codable, CaseIterable, Identifiable, Sendable {
    case none = 0, standard = 1, allIn = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "Not entered"
        case .standard: "Standard entry"
        case .allIn: "All-in entry"
        }
    }
}

/// One team's line in an edition's standings.
struct ChallengeStanding: Codable, Hashable {
    /// "player", a rival lab ID, or "outside:<team name>".
    var lab: String
    var team: String
    var model: String
    var score: Double
}

/// One edition of a grand challenge: announced, entered (or watched) and decided.
struct ChallengeEdition: Codable, Identifiable, Hashable {
    /// "<challenge>|<year>".
    var id: String
    var challenge: String
    var year: Int
    var announced: Date
    var entryCloses: Date
    /// The public leaderboard halfway through (a nudge to push harder), and the results.
    var checkpoint: Date
    var results: Date
    var status: ChallengeStatus = .open
    var effort: ChallengeEffort = .none
    /// Entered on the exhibition track (no prize money: the entry wasn't open weights where the prize needs it).
    @D var exhibition: Bool = false
    /// The model you entered (its name) and what you've spent.
    @D var model: String = ""
    @D var spent: Double = 0
    /// You paid to push harder after the checkpoint.
    @D var pushed: Bool = false
    @D var checkpointDone: Bool = false
    /// Your place on the public leaderboard at the checkpoint (0 = not entered).
    @D var checkpointPlace: Int = 0
    /// Final standings, best first (only once decided).
    @D var standings: [ChallengeStanding] = []
    /// The grand prize bar was cleared, and by whom (a standings `lab`).
    @D var grandBy: String = ""
    /// What you took home.
    @D var prize: Double = 0
    @D var place: Int = 0
    /// The bar this edition asks for (0 = the challenge's own): once cleared, recurring challenges move to harder
    /// targets and the bar rises with the field.
    @D var bar: Double = 0

    var def: ChallengeDef? { ChallengeCatalog.byID[challenge] }
}

/// Kinds of thing you can open-source.
enum RepoKind: String, Codable, Sendable {
    case model, tool, challenge
}

/// One open repository: model weights, a tool or library, or a challenge system you had to publish.
struct OpenRepo: Codable, Identifiable, Hashable {
    /// "model:<uuid>", "tool:<def id>" or "crs:<edition id>".
    var id: String
    var kind: RepoKind
    var name: String
    var released: Date
    var stars: Double = 0
    var forks: Double = 0
    /// Active outside contributors (falls when you stop maintaining it).
    var contributors: Double = 0
    /// How good it was against the state of the art when it came out (0 … 1.5).
    var quality: Double = 1
    var maintained = true
    /// Where its stars are heading (set monthly; the panel shows it).
    var potential: Double = 0
}

/// Everything grand challenges and the open-source community remember (one field on GameState; older saves load empty).
struct ChallengesState: Codable, Hashable, DefaultValue {
    static var defaultValue: ChallengesState { ChallengesState() }

    /// Editions announced so far, oldest first (decided ones stay as the record).
    @D var editions: [ChallengeEdition] = []
    /// Set on the first tick: grand prizes claimed in our timeline before the game's date are marked claimed.
    @D var started: Bool = false
    /// Challenge ID → who cleared its grand prize bar for good ("player", a lab ID or "outside:<team>").
    @D var claimed: [String: String] = [:]
    @D var prizeMoney: Double = 0
    @D var wins: Int = 0
    @D var podiums: Int = 0
    @D var grandPrizes: Int = 0
    // Open source
    @D var repos: [OpenRepo] = []
    /// Community goodwill (0–100): how developers and researchers feel about what you give away.
    @D var goodwill: Double = 0
    /// Safety scrutiny (0–100): how closely regulators and the safety community watch your open releases.
    @D var scrutiny: Double = 0
    /// Contributor grants and bug bounties (a monthly budget that grows the community faster).
    @D var grants: Bool = false
    /// Star milestones passed ("10k", "100k" …) and lifetime counts.
    @D var milestones: Set<String> = []
    @D var contributorHires: Int = 0
    @D var incidents: Int = 0
    /// Spent on maintainers and grants, lifetime.
    @D var spent: Double = 0
    /// Recent community moves in plain words, newest first.
    @D var log: [String] = []
    @D var lastIncident: Date? = nil

    init() {}

    var stars: Double { repos.reduce(0) { $0 + $1.stars } }
    var forks: Double { repos.reduce(0) { $0 + $1.forks } }
    var contributors: Double { repos.reduce(0) { $0 + $1.contributors } }
}
