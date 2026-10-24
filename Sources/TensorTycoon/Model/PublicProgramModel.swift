import Foundation

/// Who the player is building for. This is a career choice, not a cosmetic difficulty setting.
enum FoundingOrigin: String, Codable, CaseIterable, Identifiable, Sendable {
    case startup, government
    var id: String { rawValue }
    var title: String { self == .startup ? "Independent startup" : "Government AI branch" }
    var symbol: String { self == .startup ? "lightbulb.fill" : "building.columns.fill" }
    var detail: String {
        self == .startup
            ? "Raise venture capital, build a company and own the upside."
            : "Deliver public missions, earn appropriations and answer to democratic oversight."
    }
}

enum PublicMandate: String, Codable, CaseIterable, Identifiable, Sendable, DefaultValue {
    case digitalServices, openScience, nationalSecurity
    static var defaultValue: PublicMandate { .digitalServices }
    var id: String { rawValue }
    var title: String {
        switch self {
        case .digitalServices: "Digital public services"
        case .openScience: "Open science"
        case .nationalSecurity: "National security"
        }
    }
    var symbol: String {
        switch self {
        case .digitalServices: "person.2.fill"
        case .openScience: "book.closed.fill"
        case .nationalSecurity: "shield.lefthalf.filled"
        }
    }
    var detail: String {
        switch self {
        case .digitalServices: "Reliable models, capable teams and safe services for citizens."
        case .openScience: "Open weights, reproducible research and a stronger public research commons."
        case .nationalSecurity: "Secure infrastructure, rigorous evaluations and controlled capability development."
        }
    }
}

enum PublicMissionKind: String, Codable, CaseIterable, Sendable {
    case train, release, evaluate, research, hire, openWeights, safety, security
}

enum PublicMissionStatus: String, Codable, Sendable {
    case active, completed, failed, replaced
}

struct PublicMission: Codable, Hashable, Identifiable {
    var id: String
    var kind: PublicMissionKind
    var title: String
    var detail: String
    var issued: Date
    var due: Date
    /// Count, score or level required. `baseline` is subtracted for cumulative counts.
    var target: Double
    var baseline: Double = 0
    var capabilityMin: Double = 0
    var researchID: String = ""
    var progress: Double = 0
    var reward: Double
    var status: PublicMissionStatus = .active
    var closed: Date? = nil
}

struct PublicAuditRecord: Codable, Hashable, Identifiable {
    var id: String
    var date: Date
    var text: String
    var good: Bool?
}

/// Persisted state for a government AI branch. Older saves decode an inactive programme unchanged.
struct PublicProgramState: Codable, Hashable, DefaultValue {
    static var defaultValue: PublicProgramState { PublicProgramState() }

    @D var active: Bool = false
    @D var mandate: PublicMandate = .digitalServices
    @D var level: Int = 1
    /// Base annual authorisation before the programme-level multiplier.
    @D var annualBudget: Double = 0
    @D var oversight: Double = 70
    @D var probation: Bool = false
    @D var missions: [PublicMission] = []
    @D var completedMissions: Int = 0
    @D var failedMissions: Int = 0
    @D var sequence: Int = 0
    @D var deliveryStreak: Int = 0
    @D var lastTranche: Date? = nil
    @D var lastReview: Date? = nil
    @D var lastTransparency: Date? = nil
    @D var lastSupplemental: Date? = nil
    @D var supplementalYear: Int = 0
    @D var lastReroll: Date? = nil
    @D var logSequence: Int = 0
    @D var history: [PublicAuditRecord] = []
    /// Appropriations, results payments and supplements received over the programme's life.
    @D var totalReceived: Double = 0
    /// Emergency appropriations after running out of cash (PublicProgram.solvency), and the last one.
    @D var rescues: Int = 0
    @D var lastRescue: Date? = nil
}
