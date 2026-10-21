import Foundation

// MARK: - 3.9: Government contract marketplace — saved state

/// Where an opportunity stands in your pipeline.
enum GovOppStatus: String, Codable, Sendable {
    /// A sources-sought notice: the agency is shaping the requirement and the solicitation isn't out yet.
    case notice
    case open, writing, submitted, won, lost, missed, protesting, held, withdrawn

    var title: String {
        switch self {
        case .notice: "Sources sought"
        case .open: "Open"
        case .writing: "Writing"
        case .submitted: "Under evaluation"
        case .won: "Won"
        case .lost: "Lost"
        case .missed: "Missed the deadline"
        case .protesting: "Your protest is pending"
        case .held: "Award protested by a competitor"
        case .withdrawn: "Withdrawn"
        }
    }

    var decided: Bool { self == .won || self == .lost || self == .missed || self == .withdrawn }
}

/// How hard you work a proposal: who writes it and how long it takes.
enum CaptureEffort: Int, Codable, CaseIterable, Identifiable, Sendable {
    case light = 1, standard, full

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .standard: "Standard"
        case .full: "Full capture"
        }
    }

    var blurb: String {
        switch self {
        case .light: "The founder writes it in the evenings from boilerplate. Cheap and fast; evaluators notice."
        case .standard: "A named technical lead writes the volumes with a reviewer pass. What most winning small-business bids look like."
        case .full: "A capture plan: calls with the programme manager, a red-team review, a costed work plan and letters of support."
        }
    }

    /// Cost multiplier on the opportunity's bid-and-proposal cost.
    var costMult: Double { [0, 0.45, 1.0, 1.9][rawValue] }
    /// Score points on the proposal quality.
    var quality: Double { [0, -2.0, 0, 2.2][rawValue] }
}

/// A government solicitation in the marketplace and everything you did about it.
struct GovOpp: Codable, Identifiable, Hashable, Sendable {
    var id: String
    /// GovMarketCatalog kind ("sbir1", "eic", …).
    var kind: String
    /// The work, as Advanced Projects runs it once won (agency, template, type, ceiling, staff, months …).
    var sol: Solicitation
    var status: GovOppStatus = .open
    /// When a sources-sought notice turns into a solicitation.
    @D var release: Date? = nil
    /// When the agency expects to announce its decision.
    var decisionDue: Date
    /// Typical share of proposals funded in this kind of competition.
    var baseRate: Double
    /// Other proposals expected.
    var field: Int
    /// Invite-only follow-on (Phase II, production) for a performer.
    @D var invited: Bool = false
    /// The programme it follows on from (Phase I → Phase II).
    @D var parent: UUID? = nil
    /// Customer agency for a task order (the vehicle's agency holds the contract).
    @D var customer: String = ""
    /// You answered its sources-sought notice (capture credit).
    @D var answeredNotice: Bool = false

    // Your proposal
    @D var effort: Int = 0
    @D var lead: UUID? = nil
    /// The lead's skill when the proposal went in (the evaluation reads the proposal, not who still works for you).
    @D var leadSkill: Double? = nil
    @D var writeStart: Date? = nil
    @D var writeDone: Date? = nil
    @D var price: Double = 0.95
    @D var bpCost: Double = 0
    @D var submitted: Date? = nil
    /// Share of the proposal finished when it went in (submitting early takes a quality hit).
    @D var written: Double = 1
    @D var oddsAtSubmit: Double = 0

    // The decision
    @D var decided: Date? = nil
    @D var roll: Double = 0
    @D var finalOdds: Double = 0
    @D var winner: String = ""
    @D var winnerPrice: Double = 0
    /// The agency's debrief or evaluation summary.
    @D var debrief: [String] = []
    /// Slip notes (continuing resolutions, lapses, year-end acceleration).
    @D var notes: [String] = []
    /// Protest (yours, or a competitor's against your award).
    @D var protestFiled: Date? = nil
    @D var protestDue: Date? = nil
    @D var protestCost: Double = 0
    @D var protestOutcome: String = ""
    /// Programme it became in Advanced Projects.
    @D var programme: UUID? = nil

    var agencyDef: AgencyDef? { sol.agencyDef }
    var def: GovKindDef? { GovMarketCatalog.kind(kind) }
    var effortLevel: CaptureEffort? { CaptureEffort(rawValue: effort) }
}

/// A seat on a multiple-award contract vehicle: task orders under it are competed only among holders.
struct GovSeat: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var agency: String
    var name: String
    var awarded: Date
    /// End of the base period (options can extend it).
    var ends: Date
    var orders: Int = 0
    var ordersValue: Double = 0
}

/// A yearly performance assessment (CPARS-style in the US, a periodic review in Europe).
struct GovAssessment: Codable, Hashable, Sendable {
    var date: Date
    var agency: String
    var contract: String
    /// 0–1 average delivery against the plan in the period.
    var score: Double
    var rating: String
}

/// How an anchor contract pays.
enum AnchorPayment: String, Codable, Sendable {
    /// Monthly invoices against a funded line (US level-of-effort contracts and framework call-offs).
    case invoice
    /// Grant style: pre-financing at signature, interim payments at each reporting period, the balance at the end.
    case tranche
}

enum AnchorStatus: String, Codable, Sendable {
    case active, completed, expired, terminated, walkedAway

    var title: String {
        switch self {
        case .active: "Active"
        case .completed: "Completed"
        case .expired: "Option not exercised"
        case .terminated: "Terminated for default"
        case .walkedAway: "Ended at your request"
        }
    }
}

/// The founding government contract: a funded multi-year agreement with a base period, options tied to the fiscal
/// year, a team you commit to it, monthly billing and a yearly performance rating.
struct AnchorContract: Codable, Identifiable, Hashable, Sendable {
    var id = StableID.next()
    var agency: String
    var title: String
    var scope: String
    var defence: Bool
    var start: Date
    /// End of the current funded period (the base period, then each exercised option).
    var periodEnd: Date
    /// Option periods left to exercise.
    var optionsLeft: Int
    var optionsTotal: Int
    /// Annual value of the current period.
    var annual: Double
    /// Role → people the agency expects on it.
    var staff: [String: Int]
    var assigned: [UUID] = []
    var payment: AnchorPayment
    var status: AnchorStatus = .active
    /// Earned (work delivered at the contract rate) and paid so far.
    var earned: Double = 0
    var paid: Double = 0
    /// Earned this period, and the period's months with their delivery (0–1.1).
    var periodEarned: Double = 0
    var periodDelivery: [Double] = []
    var underStaffedMonths: Int = 0
    var cureNotice = false
    /// Stopped by a lapse in appropriations (no billing).
    var stopped = false
    var stoppedDays: Int = 0
    /// Waiting for an option to be exercised (a lapse at the period end).
    var awaitingOption = false
    /// The total grant value (tranche contracts) and the pre-financing paid at signature.
    var total: Double = 0
    var history: [ProgrammeEvent] = []
    var ended: Date? = nil
    @D var growthGiven: Int = 0

    var headcount: Int { staff.values.reduce(0, +) }
}

/// One fiscal-calendar status you have been told about (for transition news).
struct GovFiscalSeen: Codable, Hashable, Sendable {
    var calendar: String
    var phase: String
    var date: Date
}

/// Everything the government marketplace keeps.
struct GovMarketState: Codable, Hashable, Sendable {
    /// Keys the hashed rolls to this game (from the RNG's state, without drawing from it).
    @D var salt: String = ""
    @D var started: Bool = false
    @D var counter: Int = 0
    @D var opps: [GovOpp] = []
    /// Decided opportunities, newest first (kept for the record and debriefs).
    @D var history: [GovOpp] = []
    @D var seats: [GovSeat] = []
    @D var assessments: [GovAssessment] = []
    @D var anchor: AnchorContract? = nil
    @D var pastAnchors: [AnchorContract] = []
    @D var anchorOffered: Bool = false
    @D var anchorDeclined: Bool = false
    /// Programmes whose follow-on (Phase II, production) has been decided.
    @D var followed: Set<UUID> = []
    /// Calendar → phase last announced.
    @D var fiscal: [String: String] = [:]
    /// "agency|year" → year-end offer made.
    @D var yearEnd: Set<String> = []
    @D var wins: Int = 0
    @D var losses: Int = 0
    @D var bpSpent: Double = 0
    @D var awarded: Double = 0
    @D var protestsFiled: Int = 0
    @D var protestsWon: Int = 0
    /// Compute allocations won (cloud credits).
    @D var computeAwarded: Double = 0
    /// You've written a proposal or signed the anchor contract: fiscal news and alerts from then on.
    @D var engaged: Bool = false

    var pipeline: [GovOpp] { opps.filter { $0.status == .writing || $0.status == .submitted || $0.status == .protesting || $0.status == .held } }
}

extension GovMarketState: DefaultValue { static var defaultValue: GovMarketState { GovMarketState() } }
