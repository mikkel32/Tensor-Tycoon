import Foundation

// MARK: - Agent swarms

/// What an agent swarm spends its days on.
enum SwarmMission: String, Codable, CaseIterable, Identifiable {
    case research = "Automated research"
    case xeno = "Alien architecture search"
    case trainingOps = "Training operations"
    case silicon = "Chip design"
    case alignment = "Alignment research"
    case workforce = "Digital workforce"
    case security = "Security operations"
    case intel = "Competitive intelligence"
    // 3.6: missions only an AI organisation can take on (AgentOrgs)
    case software = "Software engineering"
    case discovery = "Scientific discovery"
    case infrastructure = "Infrastructure management"
    case robotics = "Robotics engineering"
    case finance = "Financial analysis"
    case experiments = "Experiment coordination"

    var id: String { rawValue }

    /// The missions a stand-alone swarm can run (the newer ones need an organisation around the agents).
    static let swarmCases: [SwarmMission] = [.research, .xeno, .trainingOps, .silicon, .alignment, .workforce, .security, .intel]

    var symbol: String {
        switch self {
        case .research: "lightbulb.max.fill"
        case .xeno: "atom"
        case .trainingOps: "wrench.and.screwdriver.fill"
        case .silicon: "memorychip.fill"
        case .alignment: "checkmark.shield.fill"
        case .workforce: "briefcase.fill"
        case .security: "lock.shield.fill"
        case .intel: "binoculars.fill"
        case .software: "chevron.left.forwardslash.chevron.right"
        case .discovery: "flask.fill"
        case .infrastructure: "server.rack"
        case .robotics: "gearshape.2.fill"
        case .finance: "chart.line.uptrend.xyaxis"
        case .experiments: "testtube.2"
        }
    }

    var blurb: String {
        switch self {
        case .research: "Agents read papers, write code and run ablations around the clock. Adds research points every day."
        case .xeno: "Agents search design spaces no human would try. Enough insight yields an alien architecture: a chip and a model design nobody else has."
        case .trainingOps: "Agents babysit your clusters: predict failing GPUs, restart in seconds, catch silent corruption and loss spikes. Point a swarm at one run — past 100K chips, coverage is what keeps it alive."
        case .silicon: "Agents write RTL and run verification. Chip programs and alien tape-outs finish faster, with better silicon."
        case .alignment: "Agents red-team and audit other models. Raises your safety score and slows alignment drift in self-improvement runs and swarms."
        case .workforce: "Rent your agents to companies as a digital workforce: support, coding, back office. Paid per worker-day."
        case .security: "Agents hunt intruders, review every commit and watch the weights 24/7. Attacks that get past your defences succeed less often."
        case .intel: "Agents read every paper, job post, import record and power filing. Sharper Rival Watch forecasts: launch dates, compute and capability."
        case .software: "Agent engineers maintain your serving stack and ship features: product lines cost less to serve and, with engineer-level agents, get better."
        case .discovery: "An institute of agent scientists: hypotheses, simulations and autonomous experiments. Moonshots get likelier and, with senior-researcher agents, finish sooner."
        case .infrastructure: "Agents run your datacenters: predictive maintenance, failover and power tuning. Fewer outages and, with engineer-level agents, a smaller power bill."
        case .robotics: "Agents build robot policies in simulation and on real hardware. Your Robotics Brain product line gets better."
        case .finance: "Agent analysts manage the treasury: idle cash earns a little more."
        case .experiments: "Agents schedule, launch and read out your small experiments and proxy runs, so they finish sooner."
        }
    }

    /// The skills this mission leans on, as weights on reasoning, code and agentic skill (they sum to 3, so 1 each is
    /// the average agentic task), plus chat and safety for the missions that need them.
    var skillMix: (reasoning: Double, code: Double, agent: Double, chat: Double, safety: Double) {
        switch self {
        case .research: (1.3, 0.9, 0.8, 0, 0)
        case .xeno: (1.5, 0.6, 0.9, 0, 0)
        case .trainingOps: (0.5, 1.2, 1.3, 0, 0)
        case .silicon: (0.9, 1.4, 0.7, 0, 0)
        case .alignment: (1.4, 0.6, 1.0, 0, 0.006)
        case .workforce: (0.6, 1.0, 1.4, 0.25, 0)
        case .security: (0.7, 1.3, 1.0, 0, 0.003)
        case .intel: (1.4, 0.4, 1.2, 0.15, 0)
        case .software: (0.6, 1.5, 0.9, 0, 0)
        case .discovery: (1.5, 0.7, 0.8, 0, 0)
        case .infrastructure: (0.6, 1.2, 1.2, 0, 0)
        case .robotics: (1.0, 1.0, 1.0, 0, 0)
        case .finance: (1.3, 0.8, 0.9, 0.1, 0)
        case .experiments: (0.8, 1.2, 1.0, 0, 0)
        }
    }
}

struct AgentSwarm: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var modelID: UUID
    /// Agents you asked for. How many actually run depends on the chips behind the swarm.
    var agents: Int
    var mission: SwarmMission
    var accelID: String
    var chips: Int
    var autonomy: Int
    /// Share of agents that watch the others instead of working.
    var oversight: Double
    var started: Date
    var paused = false
    var alignment: Double = 90
    var alignmentMeasured: Double = 90
    /// Live stats, refreshed daily.
    var active: Double = 0
    var workforce: Double = 0
    var output: Double = 0
    var totalOutput: Double = 0
    var revenue: Double = 0
    var incidents = 0
    var log: [String] = []
    var lastDecision: Date? = nil
    /// 3.3: a training-ops swarm can watch one run (nil = spread over all runs).
    @D var targetRunID: UUID? = nil
    /// Days on the current mission: agents get better at a job they keep doing.
    @D var missionDays: Double = 0
    /// 3.6: the AI organisation this swarm is a team of (nil = a stand-alone swarm, which works as it always did).
    @D var orgID: UUID? = nil
    /// 3.6: what the team does inside its organisation.
    @D var role: TeamRole = .specialists
    /// 3.8: paused because its model was retired and nothing could take its place (resumes when a model comes back).
    @D var pausedNoModel: Bool = false

    static let autonomyNames = ["Supervised", "Semi-autonomous", "Fully autonomous"]

    /// Up to +25% from experience on the same mission (half of it in about three months).
    var experience: Double { 1 + 0.25 * (1 - exp(-missionDays / 120)) }
}

// MARK: - Alien architectures

enum XenoPolicy: String, Codable, CaseIterable, Identifiable {
    case exclusive = "Keep exclusive"
    case sellChips = "Sell chips"
    case license = "License blueprint"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .exclusive: "lock.fill"
        case .sellChips: "shippingbox.fill"
        case .license: "doc.text.fill"
        }
    }

    var blurb: String {
        switch self {
        case .exclusive: "Only you build it — at production cost. Rivals get nothing and investors price in the moat."
        case .sellChips: "Make the chips and sell them to big players at a markup. Huge revenue, but whoever buys them gets stronger."
        case .license: "Sell the blueprint: big upfront fees and royalties. Licensees integrate it within ~6 months and the secret is out for good."
        }
    }
}

struct ArchLicense: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var buyerID: String
    var buyerName: String
    var signed: Date
    var upfront: Double
    var royaltyMonthly: Double
    var monthsLeft: Int
    /// When the licensee's own models start using it.
    var effective: Date
    /// For offers not yet signed.
    var expires: Date? = nil
}

/// A design found by an agent swarm or a self-improving model: a model architecture plus a matching chip.
struct AlienArch: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var generation: Int
    var discovered: Date
    /// Extra log10 effective training compute for models built on it.
    var computeGain: Double
    /// Throughput of its chip vs the best NVIDIA/AMD part at discovery.
    var chipPerf: Double
    /// Production cost of its chip as a share of that part's price.
    var costFactor: Double
    var powerFactor: Double
    /// How much of it humans can follow (0–1). Low legibility costs safety.
    var legibility: Double
    var policy: XenoPolicy = .exclusive
    var chipID: String? = nil
    var fabbing = false
    var fabDaysLeft: Double = 0
    var fabRespins = 0
    var licenses: [ArchLicense] = []
    var offers: [ArchLicense] = []
    /// Once licensed, the blueprint is out for good.
    var licensedOnce = false
    var lastOffer: Date? = nil
    // 3.5: alien fab — chip generations, revisions and errata.
    /// Latest chip version in production (0 = only RTL, 1 = v1, 2 = v2, 3 = v3).
    @D var chipVersion: Int = 0
    /// Every chip made from this architecture, oldest first.
    @D var chipIDs: [String] = []
    /// A next-generation revision of the chip is being designed.
    @D var revising: Bool = false
    @D var reviseDaysLeft: Double = 0
    @D var reviseTotal: Double = 0
    @D var reviseRespins: Int = 0
    /// Total days of the tape-out under way (for its progress bar).
    @D var fabTotal: Double = 0
    /// Errata your chips have thrown so far.
    @D var errata: Int = 0

    var multiplier: Double { pow(10, computeGain) }
}

// MARK: - Selling compute

/// A custom or alien chip you manufacture for other companies.
struct ChipLine: Codable, Identifiable, Hashable {
    var id: String { chipID }
    var chipID: String
    var price: Double
    var active = true
    var sellToRivals = true
    /// Chips per month the foundry makes for sale.
    var capacityMonth: Double = 0
    var pendingCapacity: Double = 0
    var pendingReady: Date? = nil
    var shipped: Double = 0
    var revenue: Double = 0
    var profit: Double = 0
    var unitsToday: Double = 0
    var demandToday: Double = 0
    var buyerUnits: [String: Double] = [:]
}

/// Customers for chips, compute and licenses: hyperscalers, sovereign funds and the rival labs themselves.
struct BigPlayer: Identifiable, Sendable {
    let id: String
    let name: String
    let kind: String
    let symbol: String
    /// Share of the neutral (non-rival) market.
    let weight: Double
}

enum BigPlayerCatalog {
    static let neutral: [BigPlayer] = [
        BigPlayer(id: "nimbus", name: "Nimbus Cloud", kind: "Hyperscaler", symbol: "cloud.fill", weight: 0.30),
        BigPlayer(id: "stratus", name: "Stratus Compute", kind: "Hyperscaler", symbol: "server.rack", weight: 0.22),
        BigPlayer(id: "atlas", name: "Atlas Neocloud", kind: "GPU cloud", symbol: "square.stack.3d.up.fill", weight: 0.14),
        BigPlayer(id: "meridian", name: "Meridian Sovereign AI", kind: "Sovereign fund", symbol: "building.columns.fill", weight: 0.14),
        BigPlayer(id: "helios", name: "Helios Robotics", kind: "Robotics", symbol: "gearshape.2.fill", weight: 0.10),
        BigPlayer(id: "northwind", name: "Northwind Telecom", kind: "Telco cloud", symbol: "antenna.radiowaves.left.and.right", weight: 0.10),
    ]

    static func name(_ id: String) -> String {
        neutral.first { $0.id == id }?.name ?? CompetitorCatalog.byID[id]?.name ?? id
    }

    static func isRival(_ id: String) -> Bool { CompetitorCatalog.byID[id] != nil }

    /// Everyone who could buy today, with their share of chip demand. Rivals split half the market by compute share.
    static func buyers(_ s: GameState, includeRivals: Bool) -> [(id: String, weight: Double)] {
        var out = neutral.map { ($0.id, $0.weight * (includeRivals ? 0.5 : 1)) }
        if includeRivals {
            let rivals = s.competitors.filter { !$0.acquired && s.year >= $0.def.founded.decimal }
            let total = rivals.reduce(0) { $0 + $1.def.computeShare }
            for r in rivals where total > 0 { out.append((r.id, 0.5 * r.def.computeShare / total)) }
        }
        return out
    }
}
