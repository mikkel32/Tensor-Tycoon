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

// MARK: - 3.10: funding requests and agency commissions

/// How big a funding request is: a one-off share of the year's authorisation, a lasting rise in the base budget, and
/// the strength of case (0–100) the committee wants to see for it in full.
enum FundingAsk: String, Codable, CaseIterable, Identifiable, Sendable {
    case modest, expansion, moonshot
    var id: String { rawValue }
    var title: String {
        switch self {
        case .modest: "Top-up"
        case .expansion: "Expansion"
        case .moonshot: "Moonshot"
        }
    }
    var symbol: String {
        switch self {
        case .modest: "plus.circle.fill"
        case .expansion: "arrow.up.right.circle.fill"
        case .moonshot: "sparkles"
        }
    }
    /// One-off payment, as a share of the annual authorisation.
    var oneOff: Double {
        switch self {
        case .modest: 0.15
        case .expansion: 0.30
        case .moonshot: 0.60
        }
    }
    /// Lasting rise in the base annual budget.
    var raise: Double {
        switch self {
        case .modest: 0
        case .expansion: 0.10
        case .moonshot: 0.25
        }
    }
    /// Strength of case needed for the full amount.
    var bar: Double {
        switch self {
        case .modest: 30
        case .expansion: 55
        case .moonshot: 80
        }
    }
}

struct FundingRequest: Codable, Hashable, Identifiable {
    var id: String
    var date: Date
    var ask: FundingAsk
    var score: Double
    /// Share of the ask approved (0 = turned down).
    var fraction: Double
    var amount: Double
    /// Rise in the base annual budget, as a share.
    var raise: Double
}

/// What the programme had at its last approved request (or its founding): the next case is judged on what's new.
struct ProgressSnapshot: Codable, Hashable {
    var date: Date
    var researched: Int
    var models: Int
    var bestC: Double
    var missions: Int
    var missed: Int
    var commissions: Int
    var security: Int
}

enum CommissionStatus: String, Codable, Sendable {
    case offered, active, inService, completed, failed, declined, expired, cancelled
}

/// 3.10: a government agency's order for a model built for it: trained after you accept, meeting its bar in one
/// capability domain, and sometimes evaluated, kept internal, released with open weights or run under a security level.
struct AgencyCommission: Codable, Hashable, Identifiable {
    var id: String
    var agency: String
    var symbol: String
    var title: String
    var detail: String
    var domain: CapDomain
    var capabilityMin: Double
    /// Points against today's frontier reference in `domain` (Capabilities.edge).
    var domainEdgeMin: Double
    var safetyMin: Double = 0
    var needsEvaluation = false
    /// The programme's security level the agency requires (0 = none).
    var securityMin = 0
    var openWeights = false
    /// Never released publicly: the agency runs it on its own systems.
    var internalOnly = false
    /// Contract value: 20% on acceptance, 80% on delivery.
    var value: Double
    /// Paid monthly for `serviceMonths` once delivered.
    var serviceYearly: Double
    var serviceMonths = 24
    var deliveryDays: Int
    var offered: Date
    var expires: Date
    var accepted: Date? = nil
    var due: Date? = nil
    var status: CommissionStatus = .offered
    var modelID: UUID? = nil
    var modelName = ""
    var delivered: Date? = nil
    var serviceUntil: Date? = nil
    var paid: Double = 0
    var closed: Date? = nil
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
    // 3.10: funding requests backed by progress, and models built for agencies.
    @D var requests: [FundingRequest] = []
    @D var lastRequest: Date? = nil
    @D var evidence: ProgressSnapshot? = nil
    @D var commissions: [AgencyCommission] = []
    @D var commissionSequence: Int = 0
    @D var lastCommissionOffer: Date? = nil
    @D var commissionsDelivered: Int = 0
    @D var commissionsFailed: Int = 0
}
