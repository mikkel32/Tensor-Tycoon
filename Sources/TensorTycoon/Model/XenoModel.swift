import Foundation

/// What an alien discovery turns out to be. The first one is always an architecture; after that you choose what
/// your agents search for.
enum XenoKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case architecture, optimizer, codec, materials, mathematics, biology, cognition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .architecture: "Architecture"
        case .optimizer: "Optimizer"
        case .codec: "Compression codec"
        case .materials: "Materials"
        case .mathematics: "Mathematics"
        case .biology: "Biology"
        case .cognition: "Cognition"
        }
    }

    var symbol: String {
        switch self {
        case .architecture: "atom"
        case .optimizer: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .codec: "rectangle.compress.vertical"
        case .materials: "diamond.fill"
        case .mathematics: "function"
        case .biology: "allergens.fill"
        case .cognition: "brain.filled.head.profile"
        }
    }

    /// What it does, in one line.
    var summary: String {
        switch self {
        case .architecture: "A model design and a chip no human would invent."
        case .optimizer: "Training that needs a fraction of the compute."
        case .codec: "Serving that needs a fraction of the chips."
        case .materials: "Room-temperature superconductors: cheap power, faster datacenters, a new industry."
        case .mathematics: "Proofs and methods that speed up all research — and that universities will pay for."
        case .biology: "Protein and drug designs worth billions to pharma, or to you."
        case .cognition: "Raw machine intelligence: smarter models, at the price of understanding them."
        }
    }

    /// Whether you can build a business on it (license it out or run it in-house).
    var hasVenture: Bool { self == .materials || self == .biology || self == .mathematics }
}

/// A non-architecture alien discovery.
struct XenoArtifact: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var kind: XenoKind
    var name: String
    var generation: Int
    var discovered: Date
    /// How strong it is (1 = a typical first find).
    var potency: Double
    /// How much of it humans understand (0–1). Understanding unlocks its full effect and makes it safer.
    var legibility: Double
    /// Switched off until this date after an anomaly.
    @D var quarantinedUntil: Date? = nil
    @D var anomalies: Int = 0
    /// "", "license" or "inhouse".
    @D var venture: String = ""
    @D var venturePartner: String = ""
    /// In-house ventures earn from this date.
    @D var ventureReady: Date? = nil
    @D var ventureMonthly: Double = 0
    @D var ventureMonthsLeft: Int = 0
    @D var ventureRevenue: Double = 0

    func active(on date: Date) -> Bool { (quarantinedUntil ?? .distantPast) <= date }

    var ventureLive: Bool { !venture.isEmpty && ventureMonthly > 0 }
}

/// A giant programme that needs alien tech to even attempt.
struct MegaProject: Codable, Identifiable, Hashable {
    var id: String
    var started: Date
    var daysLeft: Double
    var totalDays: Double
    var cost: Double
    var done = false
    @D var finished: Date? = nil
}
