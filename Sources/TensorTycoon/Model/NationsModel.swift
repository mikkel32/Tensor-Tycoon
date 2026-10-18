import Foundation

// MARK: - 3.7: national AI strategies, national economies and rival specialisations

/// One dial of a nation's AI strategy, 0–100.
enum NationLever: String, Codable, CaseIterable, Identifiable, Sendable {
    case subsidy, sovereign, exports, data, safety, visas, energy

    var id: String { rawValue }
    var index: Int { NationLever.allCases.firstIndex(of: self) ?? 0 }

    var title: String {
        switch self {
        case .subsidy: "Compute subsidies"
        case .sovereign: "Sovereign-AI programme"
        case .exports: "Export controls"
        case .data: "Data rules"
        case .safety: "Safety regime"
        case .visas: "Talent visas"
        case .energy: "Energy policy"
        }
    }

    /// Lower-case, for sentences ("compute subsidies 40 → 52").
    var phrase: String { title.lowercased() }

    var symbol: String {
        switch self {
        case .subsidy: "cpu.fill"
        case .sovereign: "flag.fill"
        case .exports: "shippingbox.and.arrow.backward.fill"
        case .data: "lock.doc.fill"
        case .safety: "checkmark.shield.fill"
        case .visas: "person.badge.plus"
        case .energy: "bolt.fill"
        }
    }

    /// What a high setting means.
    var high: String {
        switch self {
        case .subsidy: "Public money for GPUs, research grants and AI factories"
        case .sovereign: "The state builds or buys national models and favours home labs for contracts"
        case .exports: "Advanced chips and model weights need licences to leave the country"
        case .data: "Strict consent, localisation and copyright rules on training data"
        case .safety: "Evaluations, audits and incident reporting before and after release"
        case .visas: "Fast visas for researchers and engineers from abroad"
        case .energy: "Fast permits, cheap power contracts and new generation for datacenters"
        }
    }

    /// What it does in the game, in one line.
    var effect: String {
        switch self {
        case .subsidy: "At home: chips and cloud a little cheaper. Everywhere: AI adoption a little faster."
        case .sovereign: "Agencies there spend more on AI contracts; home labs get the inside track."
        case .exports: "Labs in countries it targets pay more for chips."
        case .data: "Slows consumer adoption; lifts the value of licensed data."
        case .safety: "Rules there tighten faster after incidents; enterprise buyers trust audited labs."
        case .visas: "At home: more candidates on the market."
        case .energy: "Datacenter power there costs less (or more, when it's restrictive)."
        }
    }
}

/// A region's AI strategy: seven dials, the stance they add up to, and why they last moved.
struct NationStrategy: Codable, Hashable {
    /// Dial settings, NationLever order, 0–100.
    @D var levels: [Double] = []
    /// A two- or three-word name for the overall stance ("Sovereign build-out").
    @D var stance: String = ""
    /// Why the dials moved at the last review, biggest first.
    @D var reasons: [String] = []
    /// The year of the last review.
    @D var reviewed: Int = 0

    func level(_ l: NationLever) -> Double { levels.indices.contains(l.index) ? levels[l.index] : 40 }
}

/// A region's economy as AI reshapes it.
struct NationEconomy: Codable, Hashable {
    /// Real GDP growth this year (%).
    @D var gdpGrowth: Double = 0
    /// AI's share of GDP (%).
    @D var aiShare: Double = 0
    /// Public and private AI investment ($/year).
    @D var aiInvestment: Double = 0
    /// Share of the workforce out of work because of automation (%).
    @D var automation: Double = 0
    /// AI's share of GDP a year ago (for growth).
    @D var aiShareYearAgo: Double = 0
}

/// A region's year, for the history table and charts.
struct NationYear: Codable, Hashable {
    var year: Int
    var region: String
    @D var levels: [Double] = []
    @D var gdpGrowth: Double = 0
    @D var aiShare: Double = 0
    @D var aiInvestment: Double = 0
    @D var automation: Double = 0
    @D var stance: String = ""
}

/// Something that moved a nation's strategy or a rival's specialisation, and why.
struct NationNote: Codable, Hashable {
    var date: Date
    /// Region raw value, or a lab ID for rival notes.
    var who: String
    var text: String
    /// "strategy", "focus", "reaction".
    @D var kind: String = "strategy"
}

/// What a rival lab specialises in.
enum RivalFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case coding, science, robotics, consumer, enterprise, sovereign, openWeights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coding: "Coding & agents"
        case .science: "Science"
        case .robotics: "Robotics"
        case .consumer: "Consumer"
        case .enterprise: "Enterprise"
        case .sovereign: "Sovereign AI"
        case .openWeights: "Open weights"
        }
    }

    /// For sentences: "moving into science".
    var noun: String {
        switch self {
        case .coding: "coding and agents"
        case .science: "science"
        case .robotics: "robotics"
        case .consumer: "consumer products"
        case .enterprise: "enterprise"
        case .sovereign: "sovereign AI"
        case .openWeights: "open weights"
        }
    }

    var symbol: String {
        switch self {
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .science: "atom"
        case .robotics: "gearshape.2.fill"
        case .consumer: "iphone.gen3"
        case .enterprise: "building.2.fill"
        case .sovereign: "building.columns.fill"
        case .openWeights: "lock.open.fill"
        }
    }

    /// The capability domains it competes on.
    var domains: [CapDomain] {
        switch self {
        case .coding: [.coding, .agents]
        case .science: [.science, .math]
        case .robotics: [.robotics, .vision]
        case .consumer: [.social, .voice]
        case .enterprise: [.knowledge, .agents]
        case .sovereign: [.knowledge, .coding]
        case .openWeights: [.knowledge, .reasoning]
        }
    }

    /// The product lines it contests.
    var products: [String] {
        switch self {
        case .coding: ["operator"]
        case .science: ["science", "health"]
        case .robotics: ["robotics", "video"]
        case .consumer: ["voice", "tutor", "video"]
        case .enterprise: ["operator", "health"]
        case .sovereign: ["government"]
        case .openWeights: []
        }
    }

    /// What it does to you, in one line.
    var effect: String {
        switch self {
        case .coding: "Its Operator product gets its best people: tougher competition for computer-use agents."
        case .science: "Stronger Discovery and Healthcare products; bids harder for research and health agencies."
        case .robotics: "Stronger Robotics Brain and Video Studio products."
        case .consumer: "Stronger voice, tutor and video apps, and a brand that grows."
        case .enterprise: "Stronger Operator and Healthcare products; bids for more government work."
        case .sovereign: "Wins its home government's contracts and sells a Government & Defence line."
        case .openWeights: "Gives strong models away: API prices across the market stay under pressure."
        }
    }
}

/// A rival lab's specialisation, why it chose it, and what it's weighing next.
struct RivalFocusState: Codable, Hashable {
    @D var focus: String = ""
    @D var since: Date? = nil
    @D var reason: String = ""
    /// What its scoring said, focus by focus (for "Specialisation & why").
    @D var scores: [String: Double] = [:]
    /// A move it's weighing: it waits a quarter for the evidence to hold before committing.
    @D var considering: String = ""
    @D var consideringSince: Date? = nil
    @D var nextReview: Date? = nil
    /// When it last reacted to one of your launches.
    @D var lastReaction: Date? = nil

    var rivalFocus: RivalFocus? { RivalFocus(rawValue: focus) }
}

/// A rival's answer to one of your launches, scheduled for later (they need weeks to respond).
struct RivalReaction: Codable, Hashable {
    var lab: String
    /// "price", "follow", "poach".
    var kind: String
    var due: Date
    /// The launch it answers: a product line ID, or a model name.
    var ref: String
    /// What you launched, for the news ("your Discovery Service").
    var launch: String
    var launched: Date
    @D var product: String = ""
}

/// Everything nations and rival specialisations remember. Saved with the game; older saves decode empty and set up at
/// the next month end.
struct NationsState: Codable, DefaultValue {
    static var defaultValue: NationsState { NationsState() }

    @D var ready: Bool = false
    /// Strategies and economies, Region order.
    @D var strategies: [NationStrategy] = []
    @D var economies: [NationEconomy] = []
    /// One row per region per year, oldest first.
    @D var years: [NationYear] = []
    /// What moved, newest first.
    @D var timeline: [NationNote] = []

    // Rivals
    @D var focus: [String: RivalFocusState] = [:]
    /// Domain → when your lead in it began (your best released score above every rival's).
    @D var leadSince: [String: Date] = [:]
    /// Your best released domain scores as rivals last read them (refreshed each quarter), and when.
    @D var seenScores: [Double] = []
    @D var seenAt: Date? = nil
    /// Launches already queued for an answer ("m|<model id>", "p|<product>").
    @D var answered: Set<String> = []
    @D var reactions: [RivalReaction] = []
    /// Quality push on a rival product (lab|product → until).
    @D var pushes: [String: Date] = [:]
    /// Rival notes (specialisations and reactions), newest first.
    @D var rivalLog: [NationNote] = []

    func strategy(_ r: Region) -> NationStrategy { strategies.indices.contains(r.index) ? strategies[r.index] : NationStrategy() }
    func economy(_ r: Region) -> NationEconomy { economies.indices.contains(r.index) ? economies[r.index] : NationEconomy() }
    func level(_ r: Region, _ l: NationLever) -> Double { strategy(r).level(l) }
}
