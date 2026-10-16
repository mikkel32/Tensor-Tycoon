import Foundation

/// Everything your lab's identity changes: the doctrine you founded it on, your own background and the culture
/// perks you've earned. All values are additive offsets from "no effect".
struct TraitBonuses: Sendable {
    /// Research speed (fraction).
    var rp = 0.0
    /// Extra speed on frontier research (fraction).
    var frontierRP = 0.0
    /// The founder's own research output, in researcher-equivalents.
    var founderRP = 0.0
    /// Pre-training efficiency (log10 effective compute).
    var algo = 0.0
    /// Discount on hardware purchases and rentals (fraction).
    var hardware = 0.0
    var leadTime = 0.0
    var allocation = 0.0
    /// Training MFU (points, 0.01 = 1 pt).
    var mfu = 0.0
    var power = 0.0
    /// Fewer loss spikes (fraction).
    var spikes = 0.0
    /// Safety points on models and the safety score.
    var safety = 0.0
    /// Less alignment drift in swarms and self-improvement (fraction; negative = more drift).
    var drift = 0.0
    var consumer = 0.0
    var api = 0.0
    var enterprise = 0.0
    var agentSeats = 0.0
    /// Brand points per month.
    var brand = 0.0
    var openBrand = 0.0
    /// Investors pay more (fraction).
    var valuation = 0.0
    /// Payroll change (fraction, negative is cheaper).
    var payroll = 0.0
    /// Candidate skill points.
    var hiring = 0.0
    var chipDesign = 0.0
    var chipSales = 0.0
    var swarm = 0.0
    var coordination = 0.0
    var insight = 0.0
    var labor = 0.0
    var rsi = 0.0
    /// Percentage points off loan rates.
    var loanRate = 0.0
    /// Extra percentage points of yield on cash.
    var yield = 0.0
    /// Smaller fines, settlements and regulatory costs (fraction).
    var fines = 0.0
    /// Board confidence per month.
    var confidence = 0.0

    var driftKeep: Double { clamp(1 - drift, 0.3, 1.6) }
}

// MARK: - Doctrine

/// The founding philosophy of your lab, chosen when you start.
enum LabDoctrine: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced, scaling, safety, open, product, efficiency, hardware, agents, moonshot
    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: "Generalists"
        case .scaling: "Scaling Maximalists"
        case .safety: "Safety First"
        case .open: "Open Science"
        case .product: "Product Studio"
        case .efficiency: "Efficiency Hackers"
        case .hardware: "Silicon Natives"
        case .agents: "Agent Pioneers"
        case .moonshot: "Superintelligence Moonshot"
        }
    }

    var symbol: String {
        switch self {
        case .balanced: "circle.grid.cross.fill"
        case .scaling: "chart.line.uptrend.xyaxis"
        case .safety: "checkmark.shield.fill"
        case .open: "lock.open.fill"
        case .product: "sparkles"
        case .efficiency: "gauge.with.dots.needle.67percent"
        case .hardware: "memorychip.fill"
        case .agents: "person.3.sequence.fill"
        case .moonshot: "moon.stars.fill"
        }
    }

    var tagline: String {
        switch self {
        case .balanced: "No dogma. A little better at everything, great at nothing."
        case .scaling: "The bitter lesson, taken literally: more compute wins."
        case .safety: "Constitutional training and responsible scaling before anything else."
        case .open: "Publish everything, release weights, let the world build on you."
        case .product: "Taste, polish and growth loops. Users first."
        case .efficiency: "Do more with less: MoE, FP8 and a lean team."
        case .hardware: "Co-design the chip and the model, like a TPU lab."
        case .agents: "Models that act, not chat. Swarms from day one."
        case .moonshot: "Skip the products. Build the thing that builds everything."
        }
    }

    var pros: [String] {
        switch self {
        case .balanced: ["+3% research speed", "+0.1 brand a month"]
        case .scaling: ["−8% on hardware & rentals", "×1.5 vendor allocation", "+2 pts MFU", "+10% valuation in rounds"]
        case .safety: ["+15 safety", "−30% alignment drift", "+20% enterprise deals", "−50% fines"]
        case .open: ["Open-weights releases give double brand", "+12% research speed", "+5 hiring skill", "Starts with an open publication policy"]
        case .product: ["+30% consumer demand", "+10% API demand", "+0.5 brand a month"]
        case .efficiency: ["×1.15 effective training compute", "−15% payroll", "+2 pts MFU"]
        case .hardware: ["Custom Accelerator Design researched", "+30% faster, better chips", "+25% chip-sales demand", "−10% power, −4% hardware"]
        case .agents: ["+30% agent quality", "+0.02 swarm coordination", "+25% agent seats", "+25% digital-workforce market"]
        case .moonshot: ["+35% frontier research speed", "+25% self-improvement gains", "+25% alien insight", "+15% valuation in rounds"]
        }
    }

    var cons: [String] {
        switch self {
        case .balanced: []
        case .scaling: ["−8 safety", "+15% alignment drift"]
        case .safety: ["−8% research speed", "−10% consumer demand"]
        case .open: ["−10% API demand", "−5% valuation in rounds"]
        case .product: ["−10% research speed"]
        case .efficiency: ["−0.3 brand a month", "−10% valuation in rounds"]
        case .hardware: ["−10% consumer demand"]
        case .agents: ["−4 safety", "+10% alignment drift"]
        case .moonshot: ["−15% consumer demand", "An impatient board (confidence drifts down)"]
        }
    }

    func apply(_ t: inout TraitBonuses) {
        switch self {
        case .balanced:
            t.rp += 0.03; t.brand += 0.1
        case .scaling:
            t.hardware += 0.08; t.allocation += 0.5; t.mfu += 0.02; t.valuation += 0.10
            t.safety -= 8; t.drift -= 0.15
        case .safety:
            t.safety += 15; t.drift += 0.30; t.enterprise += 0.20; t.fines += 0.5; t.confidence += 0.3
            t.rp -= 0.08; t.consumer -= 0.10
        case .open:
            t.openBrand += 1.0; t.rp += 0.12; t.hiring += 5
            t.api -= 0.10; t.valuation -= 0.05
        case .product:
            t.consumer += 0.30; t.api += 0.10; t.brand += 0.5
            t.rp -= 0.10
        case .efficiency:
            t.algo += 0.06; t.payroll -= 0.15; t.mfu += 0.02
            t.brand -= 0.3; t.valuation -= 0.10
        case .hardware:
            t.chipDesign += 0.3; t.chipSales += 0.25; t.power += 0.10; t.hardware += 0.04
            t.consumer -= 0.10
        case .agents:
            t.swarm += 0.30; t.coordination += 0.02; t.agentSeats += 0.25; t.labor += 0.25
            t.safety -= 4; t.drift -= 0.10
        case .moonshot:
            t.frontierRP += 0.35; t.rsi += 0.25; t.insight += 0.25; t.valuation += 0.15
            t.consumer -= 0.15; t.confidence -= 0.6
        }
    }
}

// MARK: - Founder background

enum FounderBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, researcher, hardwareExec, serialFounder, bigTech, policy, hacker
    var id: String { rawValue }

    static var choosable: [FounderBackground] { allCases.filter { $0 != .none } }

    var title: String {
        switch self {
        case .none: "Founder"
        case .researcher: "Star Researcher"
        case .hardwareExec: "Ex-Hardware Executive"
        case .serialFounder: "Serial Founder"
        case .bigTech: "Big-Tech Veteran"
        case .policy: "Policy Insider"
        case .hacker: "Dropout Hacker"
        }
    }

    var symbol: String {
        switch self {
        case .none: "person.fill"
        case .researcher: "brain.head.profile"
        case .hardwareExec: "cpu.fill"
        case .serialFounder: "arrow.triangle.2.circlepath"
        case .bigTech: "building.2.fill"
        case .policy: "building.columns.fill"
        case .hacker: "terminal.fill"
        }
    }

    var blurb: String {
        switch self {
        case .none: "No particular edge."
        case .researcher: "You wrote one of the papers everyone cites. You still run experiments yourself."
        case .hardwareExec: "You sold GPUs to every lab. Vendors take your calls."
        case .serialFounder: "Two exits behind you. Investors write checks on a first meeting."
        case .bigTech: "Ten years shipping at a giant. You know how to hire and how enterprises buy."
        case .policy: "Ex-government advisor on AI. Regulators trust you."
        case .hacker: "Left school to build. Cheap, scrappy, brilliant with GPUs."
        }
    }

    var perks: [String] {
        switch self {
        case .none: []
        case .researcher: ["You count as 2 researchers", "+5% research speed", "+3 hiring skill"]
        case .hardwareExec: ["−6% on hardware & rentals", "−25% lead times", "×1.5 vendor allocation"]
        case .serialFounder: ["+25% starting cash", "+15% valuation in rounds", "+0.5 board confidence a month", "−0.5 pt loan rates"]
        case .bigTech: ["+15% enterprise deals", "+4 hiring skill", "−5% payroll"]
        case .policy: ["−60% fines and settlements", "+5 safety", "+5 starting brand"]
        case .hacker: ["−20% payroll", "+2 pts MFU", "×1.05 effective compute", "−20% starting cash", "−5% valuation in rounds"]
        }
    }

    func apply(_ t: inout TraitBonuses) {
        switch self {
        case .none: break
        case .researcher: t.founderRP += 1.0; t.rp += 0.05; t.hiring += 3
        case .hardwareExec: t.hardware += 0.06; t.leadTime += 0.25; t.allocation += 0.5
        case .serialFounder: t.valuation += 0.15; t.confidence += 0.5; t.loanRate += 0.5
        case .bigTech: t.enterprise += 0.15; t.hiring += 4; t.payroll -= 0.05
        case .policy: t.fines += 0.6; t.safety += 5
        case .hacker: t.payroll -= 0.20; t.mfu += 0.02; t.algo += 0.02; t.valuation -= 0.05
        }
    }

    var startCash: Double {
        switch self {
        case .serialFounder: 1.25
        case .hacker: 0.8
        default: 1
        }
    }
}

// MARK: - Culture perks

enum CultureBranch: String, CaseIterable, Identifiable, Sendable {
    case research = "Research"
    case compute = "Compute"
    case product = "Product"
    case finance = "Finance"
    case safety = "Safety"
    case agents = "Agents"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .research: "lightbulb.fill"
        case .compute: "cpu.fill"
        case .product: "sparkles"
        case .finance: "dollarsign.circle.fill"
        case .safety: "checkmark.shield.fill"
        case .agents: "person.3.sequence.fill"
        }
    }
}

struct CulturePerk: Identifiable, Sendable {
    let id: String
    let name: String
    let branch: CultureBranch
    let tier: Int
    let effect: String

    var cost: Int { tier }
}

enum CultureCatalog {
    static let all: [CulturePerk] = [
        CulturePerk(id: "r1", name: "Paper Club", branch: .research, tier: 1, effect: "+8% research speed"),
        CulturePerk(id: "r2", name: "Ablation Discipline", branch: .research, tier: 2, effect: "−20% loss spikes, ×1.05 effective compute"),
        CulturePerk(id: "r3", name: "Idea Flywheel", branch: .research, tier: 3, effect: "+15% research speed"),
        CulturePerk(id: "r4", name: "Research Monastery", branch: .research, tier: 4, effect: "×1.12 effective compute, +20% frontier research"),
        CulturePerk(id: "c1", name: "Bulk Buyer", branch: .compute, tier: 1, effect: "−4% on hardware & rentals"),
        CulturePerk(id: "c2", name: "Cluster Whisperers", branch: .compute, tier: 2, effect: "+3 pts MFU"),
        CulturePerk(id: "c3", name: "Power Brokers", branch: .compute, tier: 3, effect: "−15% power, −20% lead times"),
        CulturePerk(id: "c4", name: "Gigawatt Mindset", branch: .compute, tier: 4, effect: "−6% hardware, ×1.5 vendor allocation"),
        CulturePerk(id: "p1", name: "Growth Team", branch: .product, tier: 1, effect: "+10% consumer demand"),
        CulturePerk(id: "p2", name: "Developer Love", branch: .product, tier: 2, effect: "+15% API demand"),
        CulturePerk(id: "p3", name: "Enterprise Machine", branch: .product, tier: 3, effect: "+25% enterprise deals, +10% agent seats"),
        CulturePerk(id: "p4", name: "Category King", branch: .product, tier: 4, effect: "+0.6 brand a month, +10% consumer demand"),
        CulturePerk(id: "f1", name: "Frugal Culture", branch: .finance, tier: 1, effect: "−5% payroll"),
        CulturePerk(id: "f2", name: "Banker Friends", branch: .finance, tier: 2, effect: "−1 pt loan rates"),
        CulturePerk(id: "f3", name: "Great Storyteller", branch: .finance, tier: 3, effect: "+10% valuation in rounds"),
        CulturePerk(id: "f4", name: "Treasury Desk", branch: .finance, tier: 4, effect: "+1 pt yield on cash, steadier board"),
        CulturePerk(id: "s1", name: "Red Team", branch: .safety, tier: 1, effect: "+5 safety"),
        CulturePerk(id: "s2", name: "Interpretability Culture", branch: .safety, tier: 2, effect: "−15% alignment drift"),
        CulturePerk(id: "s3", name: "Trusted Partner", branch: .safety, tier: 3, effect: "+8 safety, −30% fines"),
        CulturePerk(id: "s4", name: "Guardians", branch: .safety, tier: 4, effect: "−25% alignment drift, +20% enterprise deals"),
        CulturePerk(id: "a1", name: "Agent Ops", branch: .agents, tier: 1, effect: "+10% agent quality"),
        CulturePerk(id: "a2", name: "Swarm Choreography", branch: .agents, tier: 2, effect: "+0.02 swarm coordination"),
        CulturePerk(id: "a3", name: "Xeno Intuition", branch: .agents, tier: 3, effect: "+25% alien insight"),
        CulturePerk(id: "a4", name: "Digital Nation", branch: .agents, tier: 4, effect: "+50% digital-workforce market, +15% agent seats"),
    ]

    static let byID: [String: CulturePerk] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func apply(_ id: String, _ t: inout TraitBonuses) {
        switch id {
        case "r1": t.rp += 0.08
        case "r2": t.spikes += 0.2; t.algo += 0.02
        case "r3": t.rp += 0.15
        case "r4": t.algo += 0.05; t.frontierRP += 0.2
        case "c1": t.hardware += 0.04
        case "c2": t.mfu += 0.03
        case "c3": t.power += 0.15; t.leadTime += 0.2
        case "c4": t.hardware += 0.06; t.allocation += 0.5
        case "p1": t.consumer += 0.10
        case "p2": t.api += 0.15
        case "p3": t.enterprise += 0.25; t.agentSeats += 0.10
        case "p4": t.brand += 0.6; t.consumer += 0.10
        case "f1": t.payroll -= 0.05
        case "f2": t.loanRate += 1.0
        case "f3": t.valuation += 0.10
        case "f4": t.yield += 1.0; t.confidence += 0.4
        case "s1": t.safety += 5
        case "s2": t.drift += 0.15
        case "s3": t.safety += 8; t.fines += 0.3
        case "s4": t.drift += 0.25; t.enterprise += 0.20
        case "a1": t.swarm += 0.10
        case "a2": t.coordination += 0.02
        case "a3": t.insight += 0.25
        case "a4": t.labor += 0.5; t.agentSeats += 0.15
        default: break
        }
    }

    static func bonuses(doctrine: LabDoctrine, background: FounderBackground, perks: Set<String>) -> TraitBonuses {
        var t = TraitBonuses()
        doctrine.apply(&t)
        background.apply(&t)
        for p in perks { apply(p, &t) }
        t.hardware = min(t.hardware, 0.3)
        t.fines = min(t.fines, 0.9)
        return t
    }
}
