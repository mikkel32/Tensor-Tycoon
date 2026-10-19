import Foundation

// MARK: - 3.5: Advanced Projects — saved state

/// How a government contract pays, and who carries the risk.
enum ContractType: String, Codable, CaseIterable, Identifiable, Sendable {
    case fixedPrice, costPlus, grant, prize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedPrice: "Fixed-price"
        case .costPlus: "Cost-plus-fixed-fee"
        case .grant: "Milestone grant"
        case .prize: "Prize challenge"
        }
    }

    var short: String {
        switch self {
        case .fixedPrice: "Fixed price"
        case .costPlus: "Cost-plus"
        case .grant: "Grant"
        case .prize: "Prize"
        }
    }

    var symbol: String {
        switch self {
        case .fixedPrice: "lock.fill"
        case .costPlus: "arrow.triangle.2.circlepath"
        case .grant: "gift.fill"
        case .prize: "trophy.fill"
        }
    }

    var risk: String {
        switch self {
        case .fixedPrice: "You're paid the price you bid at milestones, whatever it costs you. Overruns come out of your margin; far behind schedule, the government can terminate for default."
        case .costPlus: "Your costs are reimbursed monthly plus a fixed fee at milestones. Stable, but you carry compliance overhead, and audits can disallow costs."
        case .grant: "Fixed payments at milestones that cover most of the cost (you co-fund the rest). Little upside, little risk — and you usually keep the rights to what you build."
        case .prize: "No pay until you finish. The first team to deliver takes the purse; a rival may get there first."
        }
    }
}

/// Who owns what the programme produces.
enum IPTerms: String, Codable, CaseIterable, Sendable {
    case government, licence, shared

    var title: String {
        switch self {
        case .government: "Government owns the IP"
        case .licence: "You own it; government licence"
        case .shared: "Shared rights"
        }
    }

    var short: String {
        switch self {
        case .government: "Gov't IP"
        case .licence: "Your IP"
        case .shared: "Shared IP"
        }
    }

    /// How much of the programme's research effects you can use commercially (before any secrecy decision).
    var commercialShare: Double {
        switch self {
        case .government: 0.4
        case .licence: 1.0
        case .shared: 0.75
        }
    }
}

/// Classification of a programme. Needs staff cleared to the level, facilities accredited to it and weight security.
enum Classification: Int, Codable, CaseIterable, Comparable, Sendable {
    case unclassified = 0, controlled, secret, topSecret

    static func < (a: Classification, b: Classification) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .unclassified: "Unclassified"
        case .controlled: "Controlled (CUI)"
        case .secret: "Secret"
        case .topSecret: "Top Secret/SCI"
        }
    }

    var short: String {
        switch self {
        case .unclassified: "U"
        case .controlled: "CUI"
        case .secret: "S"
        case .topSecret: "TS/SCI"
        }
    }

    /// Clearance title for staff at this level.
    var clearance: String {
        switch self {
        case .unclassified: "None"
        case .controlled: "Public trust"
        case .secret: "Secret"
        case .topSecret: "Top Secret/SCI"
        }
    }

    /// Weight-security level the company must hold to perform at this level.
    var requiredSL: Int {
        switch self {
        case .unclassified: 1
        case .controlled: 2
        case .secret: 3
        case .topSecret: 4
        }
    }

    /// Publishing papers from the work: free, reviewed, or forbidden.
    var publication: String {
        switch self {
        case .unclassified: "Publish freely"
        case .controlled: "Pre-publication review"
        case .secret, .topSecret: "No publication"
        }
    }

    /// Agents (swarms) may work on it only below Secret.
    var agentsAllowed: Bool { self <= .controlled }
}

/// The life of a programme, from bid to commercial use.
enum ProgrammeStage: Int, Codable, CaseIterable, Comparable, Sendable {
    case proposal = 0, award, feasibility, research, experimentation, prototype, testing, validation, completion, commercialisation

    static func < (a: ProgrammeStage, b: ProgrammeStage) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .proposal: "Proposal"
        case .award: "Award & mobilisation"
        case .feasibility: "Feasibility"
        case .research: "Research"
        case .experimentation: "Experimentation"
        case .prototype: "Prototype"
        case .testing: "Independent testing"
        case .validation: "Validation"
        case .completion: "Completion"
        case .commercialisation: "Commercialisation"
        }
    }

    var short: String {
        switch self {
        case .proposal: "Bid"
        case .award: "Award"
        case .feasibility: "Feas."
        case .research: "Research"
        case .experimentation: "Expts"
        case .prototype: "Proto"
        case .testing: "Test"
        case .validation: "Valid."
        case .completion: "Done"
        case .commercialisation: "Comm."
        }
    }

    /// Share of the programme's work in each working stage (feasibility … completion sum to 1).
    var workShare: Double {
        switch self {
        case .feasibility: 0.10
        case .research: 0.22
        case .experimentation: 0.20
        case .prototype: 0.20
        case .testing: 0.13
        case .validation: 0.10
        case .completion: 0.05
        default: 0
        }
    }

    /// Direct spending per month relative to the programme average (test campaigns and prototypes cost more).
    var intensity: Double {
        switch self {
        case .feasibility: 0.6
        case .research: 0.85
        case .experimentation: 1.1
        case .prototype: 1.35
        case .testing: 1.25
        case .validation: 0.9
        case .completion: 0.6
        default: 0.25
        }
    }

    /// Stages that end in a test that can fail and send the team back to rework.
    var hasTrial: Bool { self == .experimentation || self == .prototype || self == .testing }

    static let working: [ProgrammeStage] = [.feasibility, .research, .experimentation, .prototype, .testing, .validation, .completion]
}

/// A rival lab's bid on a solicitation (fixed when the solicitation is posted).
struct RivalBid: Codable, Hashable, Sendable {
    var lab: String
    /// Technical margin over the bar (domain points).
    var tech: Double
    /// Price as a share of the ceiling.
    var price: Double
}

/// Your proposal on a solicitation.
struct ProposalBid: Codable, Hashable, Sendable {
    /// Price as a share of the ceiling (fixed-price and grants), or the fee rate (cost-plus). Prizes ignore it.
    var price: Double
    var submitted: Date
    var proposalCost: Double
    /// Win odds quoted when you submitted.
    var odds: Double
}

/// A contract opportunity on the marketplace.
struct Solicitation: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var agency: String
    var template: String
    var title: String
    var type: ContractType
    var ip: IPTerms
    var classification: Int
    /// Price ceiling (fixed-price), funding available (grant), target cost (cost-plus) or purse (prize).
    var ceiling: Double
    /// The government's own cost estimate.
    var estCost: Double
    var months: Int
    /// Capability domain → bar (domain points) on your best model.
    var domains: [String: Double]
    var research: [String]
    /// Compute the work needs, in H100-equivalents (cleared compute when classified; cloud otherwise).
    var computeH100e: Double
    /// Role → cleared staff required.
    var staff: [String: Int]
    var risk: Double
    var basis: EvaluationBasis
    var posted: Date
    var closes: Date
    var bidders: [RivalBid] = []
    /// A follow-on offered to the incumbent: few or no competitors.
    @D var followOn: Bool = false
    @D var bid: ProposalBid? = nil

    var agencyDef: AgencyDef? { AgencyCatalog.byID[agency] }
    var templateDef: ProgrammeTemplate? { AgencyCatalog.templateByID[template] }
    var level: Classification { Classification(rawValue: classification) ?? .unclassified }
    var staffTotal: Int { staff.values.reduce(0, +) }
}

/// Something that happened on a programme.
struct ProgrammeEvent: Codable, Hashable, Sendable {
    var date: Date
    var text: String
    /// +1 good, −1 bad, 0 neutral.
    var tone: Int = 0
}

/// One month of a programme's books.
struct ProgrammeMonth: Codable, Hashable, Sendable {
    var date: Date
    var revenue: Double
    var direct: Double
    var allocated: Double
    var progress: Double
}

enum ProgrammeStatus: String, Codable, Sendable {
    case active, completed, terminated, cancelled, lapsed, lost

    var title: String {
        switch self {
        case .active: "Active"
        case .completed: "Completed"
        case .terminated: "Terminated for default"
        case .cancelled: "Terminated for convenience"
        case .lapsed: "Lapsed"
        case .lost: "Beaten to it"
        }
    }
}

/// What you did with a classified discovery.
enum SecrecyChoice: String, Codable, Sendable {
    case none = "", pending, classified, review, approved, denied, cleanRoom, cleanRoomDone, tainted, licensed, partnered, retained

    var title: String {
        switch self {
        case .none: ""
        case .pending: "Decision waiting in your inbox"
        case .classified: "Kept classified"
        case .review: "Civilian-use review under way"
        case .approved: "Approved for civilian use"
        case .denied: "Civilian use denied"
        case .cleanRoom: "Clean-room rebuild under way"
        case .cleanRoomDone: "Clean-room version in use"
        case .tainted: "Clean-room version withdrawn"
        case .licensed: "Permitted parts licensed"
        case .partnered: "Commercialised with an authorised partner"
        case .retained: "Retained for internal use only"
        }
    }

    /// The result may be used commercially (sold, licensed, put into products) and its patent can be licensed.
    var commercial: Bool { self == .approved || self == .cleanRoomDone || self == .licensed || self == .partnered }
}

extension SecrecyChoice: DefaultValue { static var defaultValue: SecrecyChoice { .none } }

/// A won contract and its execution.
struct Programme: Codable, Identifiable, Hashable, Sendable {
    var id = StableID.next()
    var sol: Solicitation
    /// Contract value: the price (fixed-price), award (grant), target cost + fee (cost-plus) or purse (prize).
    var value: Double
    /// Cost-plus fee (paid at milestones).
    var fee: Double = 0
    var awarded: Date
    var stage: ProgrammeStage = .award
    /// Progress through the current stage (0–1).
    var progress: Double = 0
    var months: Int = 0
    var status: ProgrammeStatus = .active
    var staff: [UUID] = []
    var swarm: UUID? = nil
    /// Cleared compute assigned (H100e).
    var compute: Double = 0
    /// Cost growth the team discovers as it goes (fixed at award from the risk and your margin).
    var costGrowth: Double = 1
    var reworks: Int = 0
    /// Stage raw value → failed trials in it.
    var trials: [String: Int] = [:]
    var revenue: Double = 0
    var direct: Double = 0
    var allocated: Double = 0
    var proposalCost: Double = 0
    var disallowed: Double = 0
    /// Milestone payments made (stage raw values).
    var paid: Set<Int> = []
    var cureNotice = false
    var stopWork = false
    var audits: Int = 0
    var findings: Int = 0
    var mobilisingMonths: Int = 0
    var history: [ProgrammeEvent] = []
    var books: [ProgrammeMonth] = []
    var ended: Date? = nil
    /// Prize challenges: when a rival team would finish.
    var rivalFinish: Date? = nil
    var rivalLab: String = ""
    @D var secrecy: SecrecyChoice = .none
    @D var secrecyUntil: Date? = nil
    @D var royaltyMonthly: Double = 0
    @D var royaltyMonthsLeft: Int = 0
    /// How much of the template's research effects you can use (0–1).
    @D var effectScale: Double = 0

    var level: Classification { sol.level }
    var template: ProgrammeTemplate? { sol.templateDef }
    var agency: AgencyDef? { sol.agencyDef }
    var profit: Double { revenue - direct - allocated - proposalCost - disallowed }
    var cashProfit: Double { revenue - direct - proposalCost - disallowed }

    /// Overall completion (0–1) across the working stages.
    var completion: Double {
        guard stage >= .feasibility else { return 0 }
        if stage >= .completion && status != .active { return 1 }
        let done = ProgrammeStage.working.filter { $0 < stage }.reduce(0) { $0 + $1.workShare }
        return min(1, done + stage.workShare * progress)
    }
}

enum FacilityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case secureLab, restrictedCompute, clearedHall
    /// workshops and test bays for hardware programmes (satellites, edge chips, fab process control, cooling).
    case engineering
    /// an accredited annex to one of your science labs, for classified experiments.
    case confidentialScience
    /// a government-certified research environment: certified networks and enclaves, audited every year.
    case certified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .secureLab: "Secure research lab"
        case .restrictedCompute: "Restricted compute centre"
        case .clearedHall: "Cleared datacenter hall"
        case .engineering: "Specialised engineering facility"
        case .confidentialScience: "Confidential science laboratory"
        case .certified: "Government-certified research environment"
        }
    }

    /// For facility names ("Paris Engineering Facility 1").
    var nameSuffix: String {
        switch self {
        case .secureLab: "Secure Lab"
        case .restrictedCompute: "Restricted Compute"
        case .clearedHall: "Cleared Hall"
        case .engineering: "Engineering Facility"
        case .confidentialScience: "Confidential Lab"
        case .certified: "Certified Environment"
        }
    }

    var symbol: String {
        switch self {
        case .secureLab: "lock.rectangle.stack.fill"
        case .restrictedCompute: "cpu.fill"
        case .clearedHall: "server.rack"
        case .engineering: "wrench.and.screwdriver.fill"
        case .confidentialScience: "flask.fill"
        case .certified: "checkmark.seal.fill"
        }
    }

    /// Illustrative photo (a generic server room, workshop or laboratory, not a real classified site).
    var image: String {
        switch self {
        case .secureLab: "lab_anechoic"   // a university RF-shielded test chamber standing in for a shielded lab
        case .restrictedCompute: "hpc_frontier"
        case .clearedHall: "dc_hall"
        case .engineering: "lab_electronics"
        case .confidentialScience: "lab_physics"
        case .certified: "rack_rear"
        }
    }

    var blurb: String {
        switch self {
        case .secureLab: "Accredited workspace where cleared staff work on classified programmes. Capacity is desks."
        case .restrictedCompute: "An air-gapped compute centre with its own accelerators, accredited for classified work. Capacity is H100-equivalents."
        case .clearedHall: "A hall inside one of your own datacenters, walled off and accredited. Cheaper and faster than a standalone centre; it draws on the site's power."
        case .engineering: "Clean workshops, environmental chambers and test bays for hardware programmes: satellites, edge accelerators, fab process control, cooling and aircraft. Each bay hosts one programme. Draws real power."
        case .confidentialScience: "An accredited annex to one of your science labs, where cleared scientists run classified experiments (materials, instruments). Needs a science lab. Each bench hosts one programme."
        case .certified: "A certified research environment: approved networks, audited enclaves and key management, for cryptography, secure communications and verified software. Needs a secure lab at the same level; audited every year."
        }
    }

    var unit: String {
        switch self {
        case .secureLab: "desks"
        case .restrictedCompute, .clearedHall: "H100e"
        case .engineering: "bays"
        case .confidentialScience: "benches"
        case .certified: "enclaves"
        }
    }

    /// Compute facilities (capacity in H100e).
    var isCompute: Bool { self == .restrictedCompute || self == .clearedHall }

    /// Facilities a programme template can require (one unit per programme).
    var isProgrammeSpace: Bool { self == .engineering || self == .confidentialScience || self == .certified }

    /// One-line role, for requirement lists.
    var short: String {
        switch self {
        case .secureLab: "secure lab"
        case .restrictedCompute: "restricted compute"
        case .clearedHall: "cleared hall"
        case .engineering: "engineering bay"
        case .confidentialScience: "confidential lab bench"
        case .certified: "certified enclave"
        }
    }
}

/// A classified facility you built.
struct SecureFacility: Codable, Identifiable, Hashable, Sendable {
    var id = StableID.next()
    var name: String
    var kind: FacilityKind
    /// Accreditation level 1–3 (CUI, Secret, TS/SCI).
    var level: Int
    var siteID: UUID?
    var capacity: Double
    var started: Date
    var ready: Date
    var capex: Double
    var opex: Double
    /// certified environments — audits passed and failed, and a suspension after a failed audit.
    @D var audits: Int = 0
    @D var auditFindings: Int = 0
    @D var suspendedUntil: Date? = nil

    func isReady(_ d: Date) -> Bool { d >= ready }
    /// Ready and not suspended by a failed certification audit.
    func isUsable(_ d: Date) -> Bool { d >= ready && (suspendedUntil.map { d >= $0 } ?? true) }
}

/// a discovery a programme produced, in the shared discovery, patent and history flow. Classified results are
/// patented under a secrecy order (no licences, no publication) until they're cleared for commercial use.
struct ProgrammeDiscovery: Codable, Identifiable, Hashable, Sendable {
    var id = StableID.next()
    var programme: UUID
    var template: String
    var title: String
    var agency: String
    /// Classification of the work it came from (0–3).
    var level: Int
    var date: Date
    /// Patent filed the day it was delivered (a secrecy order keeps classified ones sealed).
    var patentFiled: Date
    var secrecyOrder: Bool
    /// Cleared for commercial use (approval, clean-room, licence or partner) — the secrecy order is lifted.
    var cleared: Date? = nil
    var licensees: Int = 0
    var lastMonth: Double = 0
    var lifetime: Double = 0
    var published: Bool = false

    var classified: Bool { level >= Classification.secret.rawValue }
}

/// An employee's clearance: granted level and any investigation under way.
struct Clearance: Codable, Hashable, Sendable {
    var employee: UUID
    var level: Int = 0
    var target: Int = 0
    var started: Date? = nil
    var ready: Date? = nil
    /// Highest level an investigation turned down.
    var deniedAt: Int = 0
    var cost: Double = 0
}

/// A bid that has been decided, win or lose.
struct BidRecord: Codable, Hashable, Sendable {
    var date: Date
    var title: String
    var agency: String
    var winner: String
    var odds: Double
    var won: Bool
    var price: Double
}

/// Everything the Advanced Projects division keeps.
struct AdvancedState: Codable, Hashable, Sendable {
    /// Keys the division's hashed rolls to this game (set once, from the RNG's state, without drawing from it).
    @D var salt: String = ""
    @D var solicitations: [Solicitation] = []
    @D var programmes: [Programme] = []
    @D var facilities: [SecureFacility] = []
    @D var clearances: [Clearance] = []
    /// Agency → your past-performance rating (−10…+10).
    @D var ratings: [String: Double] = [:]
    @D var bids: [BidRecord] = []
    /// Employees working on programmes (kept in step with the programmes; they don't generate research points).
    @D var seconded: Set<UUID> = []
    @D var counter: Int = 0
    /// You've bid, built or cleared someone: the division sends news and alerts from then on.
    @D var engaged: Bool = false
    /// Last month's facility opex, for the dashboard.
    @D var lastOpex: Double = 0
    /// discoveries from programmes (open and classified), with their patents.
    @D var discoveries: [ProgrammeDiscovery] = []

    var isEmpty: Bool { programmes.isEmpty && facilities.isEmpty && clearances.isEmpty }
}

extension AdvancedState: DefaultValue { static var defaultValue: AdvancedState { AdvancedState() } }
