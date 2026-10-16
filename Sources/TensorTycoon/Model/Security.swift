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

    var measures: String {
        switch self {
        case .sl1: "Passwords, basic access control, an engineer who cares."
        case .sl2: "MFA everywhere, patched systems, logging, security team on call."
        case .sl3: "Least-privilege weight access, insider-risk programme, red teams, hardened training clusters."
        case .sl4: "Confidential computing, weights encrypted in use, two-person rule, vetted staff, isolated networks."
        case .sl5: "Air-gapped facilities, hardware supply-chain assurance, government-grade counter-intelligence."
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
             summary: "Labs training above 10^26 FLOP must publish safety frameworks and report critical incidents, modelled on California's SB 53.",
             basePass: 0.6, ifPasses: "Safety score +5 for everyone who complies; $2M of paperwork per 10^26 run.", ifFails: "Nothing changes.",
             popularity: 0.6, safetyBill: true, earliest: 2024.5),
        Bill(id: "preemption", title: "Federal AI Preemption Act",
             summary: "One national AI rulebook that overrides state laws.",
             basePass: 0.4, ifPasses: "Compliance gets cheaper: fines −30%, AI hype +0.05.", ifFails: "A patchwork of state rules: fines +15%.",
             popularity: -0.2, safetyBill: false, earliest: 2025.4),
        Bill(id: "chip_security", title: "Chip Security Act",
             summary: "Location verification for exported AI chips and tighter export licences.",
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
    ]

    static let byID: [String: Bill] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
