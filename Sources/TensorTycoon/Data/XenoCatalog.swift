import Foundation

/// Static data for alien discoveries: names, what each kind does, ventures and mega-projects.
enum XenoCatalog {
    static let names: [XenoKind: [String]] = [
        .optimizer: ["Gradient Tide", "Silent Descent", "The Long Fall", "Curvature Bloom", "Basin Song"],
        .codec: ["Folded Light", "Whisper Codec", "Dense Echo", "Crystal Stream", "Null Weave"],
        .materials: ["Cold Lattice", "Stillwater Alloy", "Meissner Glass", "Quiet Iron", "Halcyon Ceramic"],
        .mathematics: ["The Unwritten Lemma", "Orchard Proofs", "Infinite Ledger", "Shadow Algebra", "Glass Topology"],
        .biology: ["Folding Garden", "Living Key", "Thousand Cures", "Green Cipher", "Patient Spiral"],
        .cognition: ["The Other Mind", "Deep Current", "Lantern", "Second Voice", "Pale Choir"],
    ]

    /// Base strength of a first find of each kind.
    static func basePotency(_ k: XenoKind) -> Double {
        switch k {
        case .architecture, .optimizer, .codec, .mathematics: 1.0
        case .materials, .biology: 0.9
        case .cognition: 1.1
        }
    }

    /// Starting legibility: some kinds are easier for humans to read than others.
    static func baseLegibility(_ k: XenoKind) -> Double {
        switch k {
        case .mathematics: 0.5
        case .materials, .codec, .optimizer: 0.4
        case .biology, .architecture: 0.35
        case .cognition: 0.15
        }
    }

    /// Monthly anomaly risk at zero legibility.
    static func anomalyRisk(_ k: XenoKind) -> Double {
        switch k {
        case .cognition: 0.08
        case .biology: 0.05
        case .architecture, .optimizer, .mathematics: 0.03
        case .materials, .codec: 0.02
        }
    }

    /// What an artifact adds to your research bonuses (per unit of effective potency).
    static let virtualItems: [ResearchItem] = [
        ResearchItem(id: "xeno:optimizer", name: "Alien optimizer", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.algo(0.15), .stability(0.15)], blurb: ""),
        ResearchItem(id: "xeno:codec", name: "Alien codec", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.throughput(0.6), .tps(0.3), .kvMemory(0.25)], blurb: ""),
        ResearchItem(id: "xeno:materials", name: "Alien materials", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.scaleOut(0.2), .mfu(0.02)], blurb: ""),
        ResearchItem(id: "xeno:mathematics", name: "Alien mathematics", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.rp(0.3), .forecast(0.25), .skill(.reasoning, 0.06)], blurb: ""),
        ResearchItem(id: "xeno:biology", name: "Alien biology", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.skill(.vis, 0.05), .consumerDemand(0.05)], blurb: ""),
        ResearchItem(id: "xeno:cognition", name: "Alien cognition", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.skill(.reasoning, 0.12), .skill(.agent, 0.1), .algo(0.08)], blurb: ""),
        ResearchItem(id: "xeno:cognition_risk", name: "Unread alien cognition", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.safety(-10)], blurb: ""),
        ResearchItem(id: "xeno:contact", name: "Contact Protocol", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.rp(0.5), .algo(0.1), .insight(1.0)], blurb: ""),
    ]

    /// Effects of one unit of each kind, in words (for cards).
    static func effectText(_ k: XenoKind) -> [String] {
        switch k {
        case .architecture: ["×2–×5 training compute for models built on it", "A chip with several times the best GPU's throughput"]
        case .optimizer: ["+0.15 log effective compute on every run (×1.4)", "+15% stability"]
        case .codec: ["+60% inference throughput", "+30% tokens per second", "−25% KV-cache memory"]
        case .materials: ["−35% power cost at all your sites", "Datacenters build 25% faster", "Better scale-out"]
        case .mathematics: ["+30% research speed", "Tighter forecasts", "+0.06 reasoning"]
        case .biology: ["A pharma business worth billions", "Brand and consumer goodwill"]
        case .cognition: ["+0.12 reasoning, +0.10 agentic skill", "+0.08 log effective compute", "−10 safety while it's unread"]
        }
    }

    // MARK: Ventures

    static func partners(_ k: XenoKind) -> [String] {
        switch k {
        case .materials: ["Helion Grid Co.", "Atlas Energy", "Meridian Steel", "Northstar Utilities"]
        case .biology: ["Vireo Pharma", "Northwind Therapeutics", "Kestrel Bio", "Halden & Reyes"]
        case .mathematics: ["Global Science Consortium", "Quanta Research Trust", "Institute for Advanced Proof"]
        default: []
        }
    }

    /// Upfront licence fee as a share of a frontier lab's valuation, per unit of potency.
    static func licenseShare(_ k: XenoKind) -> Double {
        switch k {
        case .materials: 0.003
        case .biology: 0.004
        case .mathematics: 0.001
        default: 0
        }
    }

    /// Monthly in-house revenue as a share of a frontier lab's valuation, per unit of potency.
    static func inhouseShare(_ k: XenoKind) -> Double {
        switch k {
        case .materials: 0.0004
        case .biology: 0.0006
        case .mathematics: 0.00015
        default: 0
        }
    }

    static func inhouseMonths(_ k: XenoKind) -> Int {
        switch k {
        case .materials: 12
        case .biology: 18
        default: 6
        }
    }

    // MARK: Mega-projects

    struct Mega: Identifiable, Sendable {
        let id: String
        let name: String
        let symbol: String
        let blurb: String
        let effect: String
        let requirement: String
        /// Cost as a share of a frontier lab's valuation (with a floor).
        let costShare: Double
        let minCost: Double
        let days: Double
    }

    static let megaProjects: [Mega] = [
        Mega(id: "xeno_foundry", name: "Xeno Foundry", symbol: "building.2.crop.circle.fill",
             blurb: "A fab built to the alien chip's own process rules, run by the agents that designed it.",
             effect: "Alien chips cost 60% less to make, and new chip versions take half as long to design.",
             requirement: "An alien chip in production", costShare: 0.004, minCost: 2e9, days: 300),
        Mega(id: "babel", name: "Project Babel", symbol: "character.book.closed.fill",
             blurb: "A translation layer between alien representations and human concepts.",
             effect: "Every alien discovery becomes 25 points more legible, future ones start 15 points higher, and anomalies halve.",
             requirement: "Two alien discoveries", costShare: 0.0015, minCost: 8e8, days: 240),
        Mega(id: "supergrid", name: "Superconducting Grid", symbol: "bolt.horizontal.circle.fill",
             blurb: "Lossless transmission and storage across all your campuses.",
             effect: "Power costs 70% less everywhere you operate, and datacenters build 30% faster.",
             requirement: "Alien materials", costShare: 0.003, minCost: 2e9, days: 360),
        Mega(id: "panacea", name: "Project Panacea", symbol: "cross.case.fill",
             blurb: "Turn alien biology into approved treatments for diseases nobody could cure.",
             effect: "A pharmaceutical franchise paying billions a year, +25 brand and +5 safety.",
             requirement: "Alien biology", costShare: 0.0025, minCost: 1.5e9, days: 540),
        Mega(id: "contact", name: "Contact Protocol", symbol: "antenna.radiowaves.left.and.right.circle.fill",
             blurb: "Stop reverse-engineering and start asking: a channel to the minds that keep producing these designs.",
             effect: "Alien insight doubles, research +50%, +0.1 log compute on every run, and a path to Alien Tech Mastery.",
             requirement: "Four alien discoveries and Project Babel", costShare: 0.008, minCost: 5e9, days: 365),
    ]

    static let megaByID: [String: Mega] = Dictionary(uniqueKeysWithValues: megaProjects.map { ($0.id, $0) })
}
