import Foundation

// MARK: - 3.9: government relations — public affairs, hearings, promises, export licences and the policy calendar

/// Everything government relations remembers. Saved with the game; older saves decode empty and start clean.
struct GovState: Codable, Hashable, DefaultValue {
    static var defaultValue: GovState { GovState() }

    // Public affairs (lobbying itself stays `GameState.lobbyBudget`)
    /// Monthly spend on policy research: think tanks, white papers, academic fellowships.
    @D var thinkTank: Double = 0
    /// Monthly spend on a public campaign: ads, op-eds, explainer videos, town halls.
    @D var campaign: Double = 0
    /// Monthly donations to an AI-industry super PAC (US politics only).
    @D var pac: Double = 0
    /// The region your public-affairs team works (Region raw value); empty means your home region.
    @D var focus: String = ""
    /// How much attention your political money draws from reporters and watchdogs, 0–100.
    @D var exposure: Double = 0
    /// Public-affairs money spent so far, lobbying included.
    @D var spent: Double = 0
    @D var scandals: Int = 0
    @D var lastScandal: Date? = nil
    @D var lastBacklash: Date? = nil

    // Hearings
    /// The hearing you're invited to, or sitting in.
    @D var hearing: Hearing? = nil
    /// Hearings so far, newest first.
    @D var hearings: [HearingRecord] = []
    /// Mock hearings booked for the next one (0–2).
    @D var prep: Int = 0

    // Promises
    @D var commitments: [GovCommitment] = []
    /// How much each rival lab resents you (lab ID → 0–100), from what you said about it in public.
    @D var grudges: [String: Double] = [:]
    @D var lastRivalBill: Date? = nil

    // The policy calendar
    /// Dated policy events reached in this game (PolicyCalendar IDs).
    @D var events: Set<String> = []
    /// What you answered (event ID → option index).
    @D var choices: [String: Int] = [:]
    /// The answer's label, for the calendar (event ID → label).
    @D var answered: [String: String] = [:]
    /// Follow-ups waiting for their date ("kind|ref" → due).
    @D var followUps: [String: Date] = [:]

    // Export controls
    /// US export licences for advanced chips by destination region (Region raw value → valid until).
    @D var licences: [String: Date] = [:]
    /// Licence applications waiting for an answer (Region raw value → decision date).
    @D var applications: [String: Date] = [:]
    /// Applications turned down (Region raw value → when you can apply again).
    @D var denied: [String: Date] = [:]
    /// Validated End User status: advanced chips ship to your datacenters anywhere without a licence.
    @D var veu: Bool = false
    /// Last fine for an unlicensed cluster (site licence key → date).
    @D var audits: [String: Date] = [:]
    @D var veuDue: Date? = nil

    // Safety institutes
    /// Models (IDs) a safety institute asked to test, and those it tested.
    @D var asked: Set<String> = []
    @D var tested: Set<String> = []

    /// What happened, newest first.
    @D var log: [GovNote] = []
}

/// A hearing: an invitation first, then a session of questions.
struct Hearing: Codable, Hashable {
    /// HearingVenue raw value.
    var venue: String
    /// HearingTopic raw value.
    var topic: String
    /// The day the committee sits.
    var date: Date
    var invited: Date
    /// "founder", "policy" or "declined"; empty until you answer the invitation.
    @D var witness: String = ""
    /// Question IDs in the order they'll be asked.
    @D var questions: [String] = []
    @D var answers: [Int] = []
    /// The committee's mood, 0–100.
    @D var mood: Double = 50
    /// Why you're there, for the invitation ("after the jailbreak", "Xen-3 leads the world").
    @D var reason: String = ""
    /// Stakeholder moves so far (Stakeholders keys, plus "capital").
    @D var effects: [String: Double] = [:]
    /// What each answer said, for the record.
    @D var lines: [String] = []
    @D var clip: String = ""
    /// The session has opened (questions are being asked).
    @D var live: Bool = false
}

/// A finished hearing, for the record on the Government Relations page.
struct HearingRecord: Codable, Hashable {
    var date: Date
    var venue: String
    var topic: String
    var witness: String
    var grade: String
    var mood: Double
    @D var lines: [String] = []
    @D var effects: [String: Double] = [:]
    @D var clip: String = ""
}

/// A public promise made at a hearing or by signing a pledge. Kept promises build trust; broken ones are remembered.
struct GovCommitment: Codable, Hashable, Identifiable {
    /// GovPromise raw value.
    var id: String
    var made: Date
    /// Where you made it ("before the US Senate", "at the Bletchley summit").
    var venue: String
    /// The government it was made to (Region raw value): it remembers most.
    @D var region: String = ""
    /// "active", "kept" or "broken".
    @D var status: String = "active"
    /// A deadline, for promises with one.
    @D var due: Date? = nil
    @D var closed: Date? = nil
    @D var note: String = ""

    var promise: GovPromise? { GovPromise(rawValue: id) }
    var active: Bool { status == "active" }
}

/// Something that happened in government relations.
struct GovNote: Codable, Hashable {
    var date: Date
    var text: String
    /// "hearing", "promise", "spend", "scandal", "policy", "export", "institute".
    @D var kind: String = ""
}

/// The promises a lab can make in public, and how the game checks them.
enum GovPromise: String, Codable, CaseIterable, Sendable {
    case evals, institute, security, framework, noPAC, safetyBills

    var title: String {
        switch self {
        case .evals: "Evaluate every frontier model before release"
        case .institute: "Give safety institutes pre-release access"
        case .security: "Reach security level SL3 within 18 months"
        case .framework: "Publish a frontier safety framework"
        case .noPAC: "Keep money out of election campaigns"
        case .safetyBills: "Don't lobby against safety legislation"
        }
    }

    /// How it's kept, or broken.
    var rule: String {
        switch self {
        case .evals: "Broken if a model near the frontier ships and stays unevaluated for 60 days. Kept after two clean years."
        case .institute: "Broken if you refuse a safety institute's request to test a model. Kept after two clean years."
        case .security: "Kept when weight security reaches SL3; broken if the deadline passes first."
        case .framework: "Kept once you research Dangerous-Capability Evals, or at the deadline if you have a safety team of two or more; broken otherwise."
        case .noPAC: "Broken the month you give to a super PAC. Kept after two clean years."
        case .safetyBills: "Broken if you oppose a safety bill. Kept after two clean years."
        }
    }

    var symbol: String {
        switch self {
        case .evals: "checklist.checked"
        case .institute: "building.columns.fill"
        case .security: "lock.shield.fill"
        case .framework: "doc.text.fill"
        case .noPAC: "banknote"
        case .safetyBills: "doc.text.magnifyingglass"
        }
    }
}
