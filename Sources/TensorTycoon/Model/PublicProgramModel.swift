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

/// 3.10: what you can ask the government for. Every request is granted at once and comes with tasks to deliver.
enum GovRequestKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case funding, chips, power
    var id: String { rawValue }
    var title: String {
        switch self {
        case .funding: "Funding"
        case .chips: "GPUs"
        case .power: "Facility power"
        }
    }
    var symbol: String {
        switch self {
        case .funding: "banknote.fill"
        case .chips: "cpu.fill"
        case .power: "bolt.fill"
        }
    }
}

enum GrantTaskKind: String, Codable, Sendable {
    case research, train, hire, safety, security, release, agency, missions
    var symbol: String {
        switch self {
        case .research: "lightbulb.fill"
        case .train: "cpu.fill"
        case .hire: "person.3.fill"
        case .safety: "checkmark.shield.fill"
        case .security: "lock.shield.fill"
        case .release: "paperplane.fill"
        case .agency: "building.2.fill"
        case .missions: "target"
        }
    }
}

/// One thing the committee wants in return for a request. Counts are measured from `baseline` at the request.
struct GrantTask: Codable, Hashable, Identifiable {
    var id: String
    var kind: GrantTaskKind
    var title: String
    var target: Double
    var baseline: Double = 0
    var capabilityMin: Double = 0
    var done = false
}

enum GovRequestStatus: String, Codable, Sendable {
    case active, completed, failed
}

/// 3.10: a funding, GPU or power request the government granted, and the tasks attached to it.
struct GovRequest: Codable, Hashable, Identifiable {
    var id: String
    var kind: GovRequestKind
    var title: String
    var issued: Date
    var due: Date
    var amount: Double = 0
    var chips = 0
    var accelID = ""
    var powerKW: Double = 0
    /// When the GPUs arrive or the new power is commissioned (the money arrives at once).
    var arrives: Date? = nil
    var arrived = false
    var tasks: [GrantTask]
    var status: GovRequestStatus = .active
    var closed: Date? = nil
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
    // 3.10: requests the government granted, with their tasks; the state's own compute facility; agency orders.
    @D var grants: [GovRequest] = []
    @D var grantSequence: Int = 0
    @D var grantsCompleted: Int = 0
    @D var grantsFailed: Int = 0
    /// Withheld from the next quarterly budgets after a request's tasks were missed.
    @D var clawback: Double = 0
    @D var facilityID: UUID? = nil
    @D var commissions: [AgencyCommission] = []
    @D var commissionSequence: Int = 0
    @D var lastCommissionOffer: Date? = nil
    @D var commissionsDelivered: Int = 0
    @D var commissionsFailed: Int = 0
}
