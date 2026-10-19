import Foundation

// MARK: - 3.6: AI organisations

/// What a team (a swarm inside an organisation) does.
enum TeamRole: String, Codable, CaseIterable, Identifiable, Sendable, DefaultValue {
    /// Do the organisation's work.
    case specialists
    /// Plan, route and review the specialists' work: they produce nothing themselves, but let a big organisation
    /// coordinate (a higher scaling exponent, less overhead) and catch errors and drift.
    case supervisors

    static var defaultValue: TeamRole { .specialists }
    var id: String { rawValue }

    var title: String {
        switch self {
        case .specialists: "Specialists"
        case .supervisors: "Supervisors"
        }
    }

    var symbol: String {
        switch self {
        case .specialists: "person.3.fill"
        case .supervisors: "person.crop.circle.badge.checkmark"
        }
    }
}

/// One line of an organisation's project history: monthly progress reports, incidents, milestones and changes.
struct OrgReport: Codable, Hashable, Identifiable {
    var id = StableID.next()
    var date: Date
    var kind: Kind
    var title: String
    var body: String = ""

    enum Kind: String, Codable, Sendable {
        case report, incident, milestone, change
    }
}

/// A class of work an organisation takes on. Stronger agents unlock more of them (`minQuality` is researcher-equivalents
/// per agent, the scale of `Swarms.tier`). With several unlocked, the organisation splits its effort across them.
struct OrgActivity: Sendable {
    let name: String
    let minQuality: Double
    let effect: String
    /// 3.9: researcher-equivalents on it for full strength (log-scaled from 1). Work only research leads (≥ 2) or
    /// superhuman agents (≥ 8) can do takes a far bigger organisation to finish.
    var full: Double = 1e5
}

/// An AI organisation: teams of agents (swarms) working one objective under supervisors, with a compute budget (the
/// teams' inference chips), a money budget for tools, labs and equipment, a verification share and a level of human
/// oversight. Its output depends on the capability domains of the models its teams run (AgentOrgs).
struct AgentOrg: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var kind: SwarmMission
    var objective: String
    var founded: Date
    /// Human oversight: 0 humans approve every change, 1 humans spot-check, 2 fully autonomous (the swarm scale).
    var autonomy: Int = 1
    /// Share of each team's agents that watch the others for misalignment (as on a swarm).
    var oversight: Double = 0.1
    /// Share of the specialists' time spent re-checking each other's work (0–0.5).
    var verification: Double = 0.1
    /// Monthly money budget for tools, data, lab time and equipment.
    var budgetMonthly: Double = 0
    /// The activity that gets most of the effort when several are unlocked.
    var focus: Int = 0
    var paused = false
    /// Newest first, capped.
    var history: [OrgReport] = []

    // Live stats, refreshed daily
    @D var workforce: Double = 0
    @D var quality: Double = 0
    @D var agents: Double = 0
    /// Supervision staffing (0–1).
    @D var supervision: Double = 0
    @D var spendToday: Double = 0
    @D var totalOutput: Double = 0
    @D var totalSpend: Double = 0
    @D var monthOutput: Double = 0
    @D var monthSpend: Double = 0
    @D var monthDays: Double = 0
    /// Architecture research: progress towards the next technique.
    @D var techProgress: Double = 0
    @D var incidents: Int = 0
    /// 3.9: a measurable objective — a metric (`AgentOrgs.metrics`), the target, where it stood when set, and the
    /// deadline — and how it ended (0 open, 1 met, 2 missed) and when.
    @D var goalKey: String = ""
    @D var goalTarget: Double = 0
    @D var goalStart: Double = 0
    @D var goalDeadline: Date? = nil
    @D var goalSet: Date? = nil
    @D var goalStatus: Int = 0
    @D var goalClosed: Date? = nil
}

extension SwarmMission {
    /// What an organisation on this mission is called.
    var orgTitle: String {
        switch self {
        case .research: "Architecture research department"
        case .xeno: "Alien architecture lab"
        case .trainingOps: "Training operations department"
        case .silicon: "Semiconductor engineering team"
        case .alignment: "Alignment institute"
        case .workforce: "Digital workforce agency"
        case .security: "Security operations team"
        case .intel: "Competitive intelligence bureau"
        case .software: "Software engineering team"
        case .discovery: "Scientific discovery institute"
        case .infrastructure: "Infrastructure management team"
        case .robotics: "Robotics engineering team"
        case .finance: "Financial analysis department"
        case .experiments: "Experiment coordination team"
        }
    }

    var defaultObjective: String {
        switch self {
        case .research: "Find better architectures and training recipes than anyone has published."
        case .xeno: "Search design spaces no human would try for an alien architecture."
        case .trainingOps: "Keep every training run alive and fast."
        case .silicon: "Ship our chips sooner and better."
        case .alignment: "Red-team and audit every model and agent we run."
        case .workforce: "Sell agent labour to the economy at a profit."
        case .security: "Keep our weights and systems out of attackers' hands."
        case .intel: "Know what every rival will ship before they do."
        case .software: "Make our products cheaper to serve and better to use."
        case .discovery: "Turn compute into scientific breakthroughs."
        case .infrastructure: "Run our datacenters with no outages and the lowest power bill."
        case .robotics: "Make our robot brain the one every robot runs."
        case .finance: "Put our idle cash to work."
        case .experiments: "Get every experiment answered sooner."
        }
    }

    /// The capability domains this work leans on beyond general agentic skill (which every mission uses: it sets what
    /// an agent is worth in the first place). Weights sum to 1.
    var domainMix: [(CapDomain, Double)] {
        switch self {
        case .research: [(.reasoning, 0.4), (.coding, 0.3), (.math, 0.3)]
        case .xeno: [(.reasoning, 0.4), (.math, 0.3), (.science, 0.3)]
        case .trainingOps: [(.coding, 0.7), (.reasoning, 0.3)]
        case .silicon: [(.coding, 0.5), (.science, 0.3), (.math, 0.2)]
        case .alignment: [(.reasoning, 0.6), (.social, 0.2), (.knowledge, 0.2)]
        case .workforce: [(.coding, 0.4), (.knowledge, 0.3), (.social, 0.3)]
        case .security: [(.coding, 0.7), (.reasoning, 0.3)]
        case .intel: [(.reasoning, 0.5), (.knowledge, 0.3), (.social, 0.2)]
        case .software: [(.coding, 0.8), (.reasoning, 0.2)]
        case .discovery: [(.science, 0.6), (.math, 0.2), (.reasoning, 0.2)]
        case .infrastructure: [(.coding, 0.6), (.knowledge, 0.4)]
        case .robotics: [(.robotics, 0.6), (.vision, 0.4)]
        case .finance: [(.math, 0.5), (.knowledge, 0.3), (.reasoning, 0.2)]
        case .experiments: [(.coding, 0.5), (.science, 0.3), (.reasoning, 0.2)]
        }
    }

    /// The weakest agent (researcher-equivalents per agent) an organisation of this kind can be founded with.
    var minQuality: Double {
        switch self {
        case .software, .infrastructure, .finance: 0.05
        case .experiments, .robotics: 0.2
        case .discovery: 0.6
        default: 0
        }
    }

    /// Money each researcher-equivalent-day of work needs for tools, data, lab time and equipment, and how much the
    /// work suffers without it (share of output lost when the budget is zero).
    var toolCost: (perDay: Double, weight: Double) {
        switch self {
        case .discovery: (120, 0.3)
        case .robotics: (150, 0.3)
        case .silicon: (80, 0.25)
        case .xeno: (40, 0.15)
        case .research, .experiments: (25, 0.15)
        default: (10, 0.1)
        }
    }

    /// 3.9: past the first activities, research leads (≥ 2 researcher-equivalents an agent) and superhuman agents (≥ 8)
    /// unlock new classes of work with their own effects — and full strength takes 10⁶ or 10⁸ researcher-equivalents,
    /// so a bigger organisation keeps finding more to do instead of maxing out at a thousand agents.
    var activities: [OrgActivity] {
        switch self {
        case .research: [OrgActivity(name: "Ablations & reproductions", minQuality: 0, effect: "Research points"),
                         OrgActivity(name: "New techniques", minQuality: 0.6, effect: "Publishes techniques: +0.3% training MFU each (up to 10)"),
                         OrgActivity(name: "Automated research", minQuality: 8, effect: "Techniques 3× faster and up to 20 of them", full: 1e8)]
        case .software: [OrgActivity(name: "Maintenance & serving optimisation", minQuality: 0, effect: "Product lines up to 25% cheaper to serve"),
                         OrgActivity(name: "Feature shipping", minQuality: 0.2, effect: "Product-line quality up to +2 points"),
                         OrgActivity(name: "Compilers & kernels for your chips", minQuality: 0.6, effect: "Your chips' software matures up to 0.8 a year faster"),
                         OrgActivity(name: "Self-optimising serving stack", minQuality: 2, effect: "Product lines up to 15% more cheaper to serve", full: 1e6)]
        case .discovery: [OrgActivity(name: "Hypotheses & simulation", minQuality: 0, effect: "Moonshot odds up to +10%"),
                          OrgActivity(name: "Autonomous experiments", minQuality: 0.6, effect: "Running moonshots finish up to 1.5× faster"),
                          OrgActivity(name: "Automated science", minQuality: 2, effect: "Your science labs' stages up to 1.5× faster", full: 1e6)]
        case .infrastructure: [OrgActivity(name: "Fleet monitoring", minQuality: 0, effect: "Site outages up to 60% rarer"),
                               OrgActivity(name: "Power & cooling optimisation", minQuality: 0.2, effect: "Power bill up to 12% lower"),
                               OrgActivity(name: "Construction planning", minQuality: 2, effect: "Campus builds up to 30% faster", full: 1e6)]
        case .robotics: [OrgActivity(name: "Simulation & data", minQuality: 0, effect: "Robotics Brain quality up to +2 points"),
                         OrgActivity(name: "Hardware-in-the-loop", minQuality: 0.6, effect: "Robotics Brain quality up to +3 more points")]
        case .finance: [OrgActivity(name: "Treasury management", minQuality: 0, effect: "Interest on cash up to +0.4 points")]
        case .experiments: [OrgActivity(name: "Experiment scheduling", minQuality: 0, effect: "Experiments and proxy runs up to 1.5× faster")]
        case .xeno: [OrgActivity(name: "Design-space search", minQuality: 0, effect: "Alien-architecture insight")]
        case .trainingOps: [OrgActivity(name: "Cluster babysitting", minQuality: 0, effect: "Training-run ops coverage and MFU"),
                            OrgActivity(name: "Kernel autotuning", minQuality: 2, effect: "Training MFU up to +2 points", full: 1e6)]
        case .silicon: [OrgActivity(name: "RTL & verification", minQuality: 0, effect: "Faster, better chip programs"),
                        OrgActivity(name: "Physical design & yield learning", minQuality: 2, effect: "Defect density up to −25%, architecture cap +0.15", full: 1e6),
                        OrgActivity(name: "Autonomous architecture search", minQuality: 8, effect: "Architecture up to +0.12, respin odds up to −40%", full: 1e8)]
        case .alignment: [OrgActivity(name: "Red-teaming & audits", minQuality: 0, effect: "Safety score, slower drift"),
                          OrgActivity(name: "Automated interpretability", minQuality: 2, effect: "Agent drift up to 30% slower", full: 1e6)]
        case .workforce: [OrgActivity(name: "Client work", minQuality: 0, effect: "Labour revenue"),
                          OrgActivity(name: "Enterprise automation", minQuality: 2, effect: "Labour market you can reach up to +50%", full: 1e6)]
        case .security: [OrgActivity(name: "Threat hunting", minQuality: 0, effect: "Attacks succeed less often")]
        case .intel: [OrgActivity(name: "Open-source intelligence", minQuality: 0, effect: "Sharper Rival Watch")]
        }
    }
}
