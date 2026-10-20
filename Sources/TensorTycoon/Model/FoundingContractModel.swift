import Foundation

// MARK: - 3.9: the founding government contract — saved state

/// How a founding award pays.
enum FoundingTerms: String, Codable, Sendable {
    /// Firm-fixed-price: the price is paid in slices as milestones are accepted, whatever the work costs you.
    case fixedPrice
    /// Cost-plus-fixed-fee: costs charged to the contract (with the indirect rate) are reimbursed every month, up to the
    /// ceiling, and the fee is paid as milestones are accepted.
    case costPlus
    /// Grant: an advance at signature, interim payments as milestones are accepted, the balance after the final report —
    /// all capped at the eligible costs you claim times the funding rate, with a retention held until closeout.
    case grant

    var title: String {
        switch self {
        case .fixedPrice: "Firm-fixed-price, paid at milestones"
        case .costPlus: "Cost-plus-fixed-fee"
        case .grant: "Grant with pre-financing"
        }
    }

    var short: String {
        switch self {
        case .fixedPrice: "Fixed price"
        case .costPlus: "Cost-plus"
        case .grant: "Grant"
        }
    }

    var symbol: String {
        switch self {
        case .fixedPrice: "lock.fill"
        case .costPlus: "arrow.triangle.2.circlepath"
        case .grant: "gift.fill"
        }
    }
}

extension FoundingTerms: DefaultValue { static var defaultValue: FoundingTerms { .fixedPrice } }

/// What a milestone in the statement of work asks for. Every one is checked against what really happens in the game.
enum FCMilestoneKind: String, Codable, Sendable {
    /// Kick-off meeting and work plan: accepted a couple of weeks after signature.
    case kickoff
    /// Key personnel: at least `target` technical staff on the payroll.
    case staffing
    /// A named research item finished (`ref`).
    case research
    /// A model at capability `target` or better (or the same index on today's suite), trained after the award.
    case model
    /// A peer-reviewed paper accepted, or a result published openly, after the award.
    case paper
    /// The delivered model released and serving (a live demonstration for the agency's evaluators).
    case release
    /// Test and evaluation: a model through a dangerous-capability evaluation (from 2023.5), else a safety score of `target`.
    case safety
    /// Interim technical report, filed on its own once half the period has run.
    case report
    /// Final technical report: written in three weeks once every other milestone is met.
    case final

    var symbol: String {
        switch self {
        case .kickoff: "person.2.wave.2.fill"
        case .staffing: "person.badge.plus"
        case .research: "lightbulb.fill"
        case .model: "cube.fill"
        case .paper: "doc.richtext.fill"
        case .release: "play.rectangle.fill"
        case .safety: "checkmark.shield.fill"
        case .report: "doc.text.fill"
        case .final: "flag.checkered"
        }
    }

    /// Share of the price (fixed price) or fee (cost-plus) it pays, before the plan is normalised.
    var weight: Double {
        switch self {
        case .kickoff: 0.10
        case .staffing: 0.05
        case .research: 0.15
        case .model: 0.30
        case .paper: 0.07
        case .release: 0.10
        case .safety: 0.07
        case .report: 0.06
        case .final: 0.20
        }
    }

    /// When it falls due, as a share of the period of performance.
    var dueShare: Double {
        switch self {
        case .kickoff: 0.08
        case .staffing: 0.3
        case .research: 0.55
        case .model: 0.75
        case .paper: 0.85
        case .release: 0.9
        case .safety: 0.9
        case .report: 0.5
        case .final: 1.0
        }
    }
}

extension FCMilestoneKind: DefaultValue { static var defaultValue: FCMilestoneKind { .report } }

/// One deliverable in the statement of work.
struct FCMilestone: Codable, Hashable, Identifiable, Sendable {
    @D var id: String = ""
    @D var kind: FCMilestoneKind = .report
    @D var title: String = ""
    @D var detail: String = ""
    var due: Date = .distantFuture
    /// Share of the price (fixed price) or fee (cost-plus) it releases; 0 for grants (they pay on claims).
    @D var share: Double = 0
    /// Capability (model, release), headcount (staffing) or safety score (safety, before evaluations existed).
    @D var target: Double = 0
    /// Research item (research).
    @D var ref: String = ""
    @D var met: Date? = nil
    /// Paid on acceptance.
    @D var paid: Double = 0

    func late(_ today: Date) -> Bool { met.map { $0 > due } ?? (today > due) }
}

/// Where a founding award stands.
enum FCStatus: String, Codable, Sendable {
    case offered, active, stopWork, completed, terminated, declined, lapsed

    var title: String {
        switch self {
        case .offered: "Awaiting signature"
        case .active: "Active"
        case .stopWork: "Stop-work order"
        case .completed: "Completed"
        case .terminated: "Terminated for default"
        case .declined: "Declined"
        case .lapsed: "Closed out incomplete"
        }
    }

    var live: Bool { self == .active || self == .stopWork }
}

extension FCStatus: DefaultValue { static var defaultValue: FCStatus { .offered } }

/// The performance ratings agencies give (a CPARS-style scale).
enum FCRating {
    static let titles = ["Unsatisfactory", "Marginal", "Satisfactory", "Very good", "Exceptional"]
    static func title(_ r: Int) -> String { titles[clamp(r, 0, 4)] }
    /// What the rating does to your past-performance record with the agency (Advanced Projects).
    static let record: [Double] = [-3, -1, 1, 2, 3]
}

/// A founding award: one phase of one scheme with one agency.
struct FoundingContract: Codable, Hashable, Identifiable, Sendable {
    @D var id: String = ""
    /// FoundingCatalog scheme ID.
    @D var scheme: String = ""
    /// 1 = the first award; 2 = its Phase II / option period.
    @D var phase: Int = 1
    @D var agency: String = ""
    /// "Small Business Innovation Research — Phase I".
    @D var programme: String = ""
    /// Contract or grant agreement number.
    @D var number: String = ""
    @D var title: String = ""
    @D var objective: String = ""
    @D var terms: FoundingTerms = .fixedPrice
    /// Price (fixed price), ceiling including fee (cost-plus) or maximum grant.
    @D var budget: Double = 0
    @D var indirectRate: Double = 0
    @D var feeRate: Double = 0
    /// Share of eligible costs a grant pays (you co-fund the rest).
    @D var fundingRate: Double = 1
    /// Grants: share of the grant paid as pre-financing at signature.
    @D var advanceShare: Double = 0
    /// Grants: share of the grant held back until closeout.
    @D var retention: Double = 0
    /// Share of the month's R&D spending that may be charged to the work.
    @D var chargeShare: Double = 0.5
    @D var months: Int = 6
    var start: Date = .distantPast
    var end: Date = .distantFuture
    @D var officer: String = ""
    @D var manager: String = ""
    @D var milestones: [FCMilestone] = []
    @D var status: FCStatus = .offered
    @D var stretch: Bool = false
    /// The offer lapses (inbox default signs it) on this date.
    @D var offerExpires: Date? = nil
    /// Costs charged to the work so far (direct with indirect), and of which direct.
    @D var charged: Double = 0
    @D var direct: Double = 0
    /// Received so far, and the reimbursement voucher due next month (cost-plus: paid net-30).
    @D var paid: Double = 0
    @D var voucher: Double = 0
    @D var feePaid: Double = 0
    /// Disallowed by the closeout audit.
    @D var disallowed: Double = 0
    @D var audited: Bool = false
    var midterm: Date = .distantFuture
    @D var reviewRating: Int? = nil
    @D var finalRating: Int? = nil
    @D var extensionMonths: Int = 0
    @D var extensionAsked: Bool = false
    /// A cure notice runs until this date; then a stop-work order.
    @D var cureUntil: Date? = nil
    /// A stop-work order runs until this date; then termination for default.
    @D var stopUntil: Date? = nil
    @D var ended: Date? = nil
    /// What counted as "before the award": accepted papers and published results then.
    @D var papersAtStart: Int = 0
    @D var publishedAtStart: Int = 0
    /// Your best capability at the award (the model milestone's starting line).
    @D var cAtStart: Double = 0
    @D var reports: Int = 0
    @D var history: [ProgrammeEvent] = []

    var agencyDef: AgencyDef? { AgencyCatalog.byID[agency] }
    var agencyShort: String { agencyDef?.short ?? agency.uppercased() }
    /// The fee on a cost-plus award.
    var fee: Double { terms == .costPlus ? budget - budget / (1 + feeRate) : 0 }
    /// What may be reimbursed as costs on a cost-plus award (the ceiling without the fee).
    var costCeiling: Double { budget - fee }
    var metCount: Int { milestones.filter { $0.met != nil }.count }
    var remaining: Double { max(0, budget - paid - disallowed) }
    func next(_ today: Date) -> FCMilestone? { milestones.filter { $0.met == nil }.min { $0.due < $1.due } }
}

/// Everything the founding contract keeps.
struct FoundingState: Codable, Hashable, DefaultValue {
    static var defaultValue: FoundingState { FoundingState() }
    /// A founding award has been offered to this game (at founding, or once on loading an older save).
    @D var offered: Bool = false
    /// Keys the hashed rolls to this game (set once, from the RNG's state, without drawing from it).
    @D var salt: String = ""
    /// Current award first, then earlier phases.
    @D var contracts: [FoundingContract] = []
    @D var lifetimePaid: Double = 0
    /// A sole-source follow-on was posted to the Advanced Projects marketplace (solicitation ID).
    @D var transition: String = ""

    var current: FoundingContract? { contracts.first }
}
