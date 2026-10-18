import Foundation

/// Model-weight security levels, after RAND's "Securing AI Model Weights" (Nevo et al., 2024):
/// each level is defined by the most capable attacker it can reliably stop.
enum SecurityLevel: Int, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case sl1 = 1, sl2, sl3, sl4, sl5
    var id: Int { rawValue }

    static func < (a: SecurityLevel, b: SecurityLevel) -> Bool { a.rawValue < b.rawValue }

    var title: String { "SL\(rawValue)" }

    var stops: String {
        switch self {
        case .sl1: "Amateur attempts"
        case .sl2: "Professional opportunistic hackers"
        case .sl3: "Cybercrime syndicates and insider threats"
        case .sl4: "Standard operations by state-backed cyber units"
        case .sl5: "Top-priority operations by the most capable nation-states"
        }
    }

    /// RAND's attacker profile ("operational capacity") for the level this one stops.
    var attacker: String {
        switch self {
        case .sl1: "1 person, a few days, up to $1K"
        case .sl2: "1 skilled person, several weeks, up to $10K"
        case .sl3: "~10 professionals for months and up to $1M — or one insider"
        case .sl4: "~100 people, a year, up to $10M and state resources"
        case .sl5: "~1,000 people, several years, up to $1B"
        }
    }

    /// Example measures from RAND's report (each level includes everything below it).
    var measures: String {
        switch self {
        case .sl1: "MFA, single sign-on, least privilege, access logs, best-effort weight encryption."
        case .sl2: "Weights only on servers, keys in a key-management system, FIDO hardware keys, guarded datacenters, every copy tracked."
        case .sl3: "Centralised weight storage, narrow access interfaces, multi-party authorisation, insider-threat programme, elite red team, honeypots."
        case .sl4: "Isolated weight storage, confidential computing, hardware-enforced output-rate limits, hardware source audits, device bans."
        case .sl5: "Fully isolated network, side-channel defences, formally verified hardware, TS/SCI-grade protection, eight independent security layers."
        }
    }

    /// One-time cost of reaching this level (before company-size scaling).
    var upgradeCost: Double {
        switch self {
        case .sl1: 0
        case .sl2: 1.5e6
        case .sl3: 2.5e7
        case .sl4: 3e8
        case .sl5: 3e9
        }
    }

    /// Months of work to reach this level from the one below.
    var upgradeMonths: Int {
        switch self {
        case .sl1: 0
        case .sl2: 2
        case .sl3: 6
        case .sl4: 14
        case .sl5: 30
        }
    }

    /// Monthly upkeep (before company-size scaling).
    var upkeep: Double {
        switch self {
        case .sl1: 0
        case .sl2: 6e4
        case .sl3: 6e5
        case .sl4: 6e6
        case .sl5: 4e7
        }
    }

    /// Research slows behind compartments and air gaps.
    var friction: Double {
        switch self {
        case .sl1, .sl2: 0
        case .sl3: 0.02
        case .sl4: 0.05
        case .sl5: 0.10
        }
    }
}

/// A bill working its way through the legislature, and where you stand on it.
struct PolicyBill: Codable, Identifiable, Hashable {
    var id: String
    var proposed: Date
    var vote: Date
    /// −1 oppose, 0 stay out, +1 support.
    var stance: Int = 0
    /// 3.3: the rival lab whose lobbyists back it, and how much that adds to its chances.
    @D var sponsor: String = ""
    @D var boost: Double = 0
}

enum PolicyCatalog {
    struct Bill: Sendable {
        let id: String
        let title: String
        let summary: String
        /// Chance it passes if nobody lobbies.
        let basePass: Double
        let ifPasses: String
        let ifFails: String
        /// How the public sees supporting it: positive = popular.
        let popularity: Double
        /// Whether safety-minded people see it as a safety measure.
        let safetyBill: Bool
        let earliest: Double
    }

    static let all: [Bill] = [
        Bill(id: "transparency", title: "Frontier AI Transparency Act",
             summary: "Labs training above 10^26 FLOP must publish safety frameworks and report critical incidents within 15 days, modelled on California's SB 53 (in force Jan 2026) and New York's RAISE Act.",
             basePass: 0.6, ifPasses: "Safety score +5 for everyone who complies; $2M of paperwork per 10^26 run.", ifFails: "Nothing changes.",
             popularity: 0.6, safetyBill: true, earliest: 2024.5),
        Bill(id: "preemption", title: "Federal AI Preemption Act",
             summary: "One national AI rulebook that overrides state laws on model development. The Senate struck a state-law moratorium 99–1 in 2025; the White House's 2026 framework proposes three years of preemption.",
             basePass: 0.35, ifPasses: "Compliance gets cheaper: fines −30%, AI hype +0.05.", ifFails: "A patchwork of state rules: fines +15%.",
             popularity: -0.2, safetyBill: false, earliest: 2025.4),
        Bill(id: "chip_security", title: "Chip Security Act",
             summary: "Location verification for exported AI chips and tighter export licences, after H200 exports to China moved to case-by-case licensing in Jan 2026.",
             basePass: 0.5, ifPasses: "Export controls tighten: Dragon Lake loses compute, hardware prices +3%.", ifFails: "Smuggling continues; Dragon Lake keeps pace.",
             popularity: 0.3, safetyBill: true, earliest: 2025.3),
        Bill(id: "copyright", title: "AI Training Copyright Act",
             summary: "Training on copyrighted works requires a licence and royalties.",
             basePass: 0.35, ifPasses: "Copyright heat +0.5: lawsuits more likely and costlier.", ifFails: "Fair use holds: copyright heat −0.3.",
             popularity: 0.4, safetyBill: false, earliest: 2023.5),
        Bill(id: "permitting", title: "Datacenter Permitting Reform",
             summary: "Fast-track permits and grid interconnection for AI datacenters.",
             basePass: 0.5, ifPasses: "Datacenters build ~25% faster.", ifFails: "Queues get worse: builds ~10% slower.",
             popularity: -0.1, safetyBill: false, earliest: 2024.0),
        Bill(id: "compute_licensing", title: "Frontier Compute Licensing",
             summary: "A federal licence for any training run above 10^27 FLOP.",
             basePass: 0.3, ifPasses: "$25M licence per 10^27 run; every rival lab slows down.", ifFails: "No licence regime.",
             popularity: 0.2, safetyBill: true, earliest: 2026.0),
        Bill(id: "liability", title: "AI Liability Act",
             summary: "Developers are liable for serious harms caused by their models.",
             basePass: 0.35, ifPasses: "Lawsuits and incidents cost more; labs with high safety scores gain enterprise trust.", ifFails: "Liability stays murky.",
             popularity: 0.5, safetyBill: true, earliest: 2025.0),
        Bill(id: "nairr", title: "National AI Research Resource",
             summary: "Public compute for universities and startups.",
             basePass: 0.55, ifPasses: "Cloud rental prices −5%, AI hype up.", ifFails: "Nothing changes.",
             popularity: 0.6, safetyBill: false, earliest: 2023.0),
        Bill(id: "agent_registry", title: "Autonomous Agent Accountability Act",
             summary: "Fleets of more than 100,000 AI agents must be registered and audited.",
             basePass: 0.4, ifPasses: "Swarms over 100k agents pay a registration fee; audits catch drift earlier.", ifFails: "Swarms stay unregulated.",
             popularity: 0.5, safetyBill: true, earliest: 2026.3),
        Bill(id: "dc_moratorium", title: "Hyperscale Datacenter Moratorium",
             summary: "A one-year freeze on permits for new datacenters of 50 MW or more over power and water, like New York's July 2026 order.",
             basePass: 0.35, ifPasses: "New datacenters take ~35% longer to build.", ifFails: "Permits keep flowing.",
             popularity: 0.3, safetyBill: false, earliest: 2026.5),
        Bill(id: "independent_auditors", title: "Independent AI Verification Act",
             summary: "Accredited third-party auditors work inside frontier labs, after California's SB 813 and AB 1405 (Sep 2026).",
             basePass: 0.45, ifPasses: "Frontier labs pay ~$1M a month for on-site auditors; safety +3 and audits catch swarm drift earlier.", ifFails: "Labs keep auditing themselves.",
             popularity: 0.5, safetyBill: true, earliest: 2026.6),
        Bill(id: "kill_switch", title: "Loss-of-Control Act",
             summary: "Labs must be able to halt any deployed model within an hour and report loss-of-control incidents within 24 hours, following California's Sep 2026 kill-switch order.",
             basePass: 0.4, ifPasses: "A one-time $50M kill-switch build for frontier labs; escaped models and swarms are contained 25% more often.", ifFails: "Shutdown stays voluntary.",
             popularity: 0.6, safetyBill: true, earliest: 2026.7),
        // 3.4: world and stakeholders — only introduced when AI job losses pass a threshold (Consequences), never at random.
        Bill(id: "robot_tax", title: "Automation Dividend Act",
             summary: "A \"robot tax\": a levy on revenue from AI agents and automated labour, paid into retraining and a monthly dividend, after protests over AI job losses.",
             basePass: 0.4, ifPasses: "Agent-seat and agent-labour revenue pays a 4% levy; people who lost work to AI find new jobs faster and public mood improves.",
             ifFails: "No levy. The debate comes back if job losses keep rising.",
             popularity: 0.5, safetyBill: false, earliest: 9_999),
    ]

    static let byID: [String: Bill] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
