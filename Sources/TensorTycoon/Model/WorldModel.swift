import Foundation

// MARK: - 3.4: the world outside the labs

/// A part of the economy that takes up AI at its own pace: fast where the work is digital and lightly regulated
/// (software, media), slow where mistakes are costly or the rules are strict (healthcare, government), and late where
/// it needs robots (manufacturing).
enum Sector: String, Codable, CaseIterable, Identifiable, Sendable {
    case software, finance, healthcare, education, government, manufacturing, media, science

    var id: String { rawValue }
    var index: Int { Sector.allCases.firstIndex(of: self) ?? 0 }

    var title: String {
        switch self {
        case .software: "Software"
        case .finance: "Finance"
        case .healthcare: "Healthcare"
        case .education: "Education"
        case .government: "Government"
        case .manufacturing: "Manufacturing"
        case .media: "Media"
        case .science: "Science"
        }
    }

    var symbol: String {
        switch self {
        case .software: "chevron.left.forwardslash.chevron.right"
        case .finance: "chart.line.uptrend.xyaxis"
        case .healthcare: "cross.case.fill"
        case .education: "graduationcap.fill"
        case .government: "building.columns.fill"
        case .manufacturing: "gearshape.2.fill"
        case .media: "play.rectangle.fill"
        case .science: "atom"
        }
    }

    /// The adoption S-curve: the frontier capability at which the sector gets half way to its ceiling, how gradual the
    /// curve is, and the ceiling (some work never moves to AI).
    var curve: (midpoint: Double, width: Double, ceiling: Double) {
        switch self {
        case .software: (5.3, 0.7, 0.97)
        case .finance: (6.4, 0.9, 0.92)
        case .healthcare: (7.2, 1.1, 0.88)
        case .education: (6.0, 1.0, 0.85)
        case .government: (8.0, 1.2, 0.78)
        case .manufacturing: (9.2, 1.0, 0.82)
        case .media: (5.7, 0.8, 0.90)
        case .science: (6.3, 1.0, 0.90)
        }
    }

    /// Share of the gap to its target adoption the sector closes in a month.
    var speed: Double {
        switch self {
        case .software: 0.09
        case .media: 0.07
        case .finance: 0.06
        case .education, .science: 0.05
        case .healthcare: 0.035
        case .manufacturing: 0.03
        case .government: 0.025
        }
    }

    /// How much safety concern and strict rules hold the sector back (0–1).
    var caution: Double {
        switch self {
        case .software: 0.15
        case .media: 0.4
        case .science, .manufacturing: 0.3
        case .education: 0.6
        case .finance: 0.7
        case .government: 0.85
        case .healthcare: 1.0
        }
    }

    /// Workers worldwide (millions) whose jobs AI can reach in this sector.
    var workforce: Double {
        switch self {
        case .software: 30
        case .finance: 90
        case .healthcare: 140
        case .education: 100
        case .government: 150
        case .manufacturing: 400
        case .media: 40
        case .science: 20
        }
    }

    /// How deep automation goes once the sector has adopted AI (1 = average).
    var depth: Double {
        switch self {
        case .software: 1.25
        case .media: 1.1
        case .finance: 1.0
        case .science: 0.9
        case .manufacturing: 0.8
        case .education, .government: 0.7
        case .healthcare: 0.6
        }
    }

    static let totalWorkforce: Double = Sector.allCases.reduce(0) { $0 + $1.workforce }
}

/// A jurisdiction whose AI rules and view of your lab the game tracks.
enum Region: String, Codable, CaseIterable, Identifiable, Sendable {
    case us, eu, uk, china, gulf, india, japanKorea = "jk"

    var id: String { rawValue }
    var index: Int { Region.allCases.firstIndex(of: self) ?? 0 }

    var title: String {
        switch self {
        case .us: "United States"
        case .eu: "European Union"
        case .uk: "United Kingdom"
        case .china: "China"
        case .gulf: "Gulf states"
        case .india: "India"
        case .japanKorea: "Japan & Korea"
        }
    }

    var short: String {
        switch self {
        case .us: "US"
        case .eu: "EU"
        case .uk: "UK"
        case .china: "China"
        case .gulf: "Gulf"
        case .india: "India"
        case .japanKorea: "Japan/Korea"
        }
    }

    /// "in the EU", "in China".
    var inPlace: String {
        switch self {
        case .us: "in the US"
        case .eu: "in the EU"
        case .uk: "in the UK"
        case .china: "in China"
        case .gulf: "in the Gulf"
        case .india: "in India"
        case .japanKorea: "in Japan and Korea"
        }
    }

    /// Who writes the rules there (for news).
    var regulator: String {
        switch self {
        case .us: "Congress"
        case .eu: "The European Commission"
        case .uk: "The UK government"
        case .china: "China's internet regulator"
        case .gulf: "Gulf regulators"
        case .india: "India's IT ministry"
        case .japanKorea: "Regulators in Tokyo and Seoul"
        }
    }

    /// Whether `regulator` takes a plural verb ("Gulf regulators propose …").
    var regulatorIsPlural: Bool { self == .gulf || self == .japanKorea }

    /// How strict the rules would be with no incidents (0–100): the real laws to 2026, a gentle drift after.
    func baseline(_ y: Double) -> Double {
        let pts: [(Double, Double)]
        switch self {
        case .us: pts = [(2016, 12), (2022.5, 15), (2023.85, 30), (2025.05, 21), (2026.0, 28), (2026.8, 32), (2030, 38), (2036, 42)]
        case .eu: pts = [(2016, 22), (2021.3, 35), (2023.95, 50), (2024.6, 58), (2025.6, 66), (2027.95, 72), (2032, 74)]
        case .uk: pts = [(2016, 15), (2023.85, 28), (2026, 33), (2030, 40)]
        case .china: pts = [(2016, 25), (2023.6, 50), (2025.0, 55), (2030, 60)]
        case .gulf: pts = [(2016, 8), (2024, 12), (2030, 18)]
        case .india: pts = [(2016, 8), (2024.2, 18), (2026, 22), (2030, 30)]
        case .japanKorea: pts = [(2016, 12), (2024, 18), (2026.0, 30), (2030, 35)]
        }
        return interpolate(pts, at: y)
    }

    /// How strongly lawmakers there answer safety concern and public mood.
    var responsiveness: Double {
        switch self {
        case .eu: 1.0
        case .uk: 0.8
        case .us, .japanKorea: 0.6
        case .china: 0.5
        case .india: 0.4
        case .gulf: 0.2
        }
    }

    /// Weight in the world average (roughly its share of AI spending).
    var weight: Double {
        switch self {
        case .us: 0.32
        case .eu, .china: 0.20
        case .japanKorea: 0.12
        case .india: 0.08
        case .uk: 0.05
        case .gulf: 0.03
        }
    }

    /// Where a new lab starts with this government (points from 50), how much your political capital counts there,
    /// and how much your safety record does.
    var standing: (bias: Double, capital: Double, safety: Double) {
        switch self {
        case .us: (2, 0.5, 0.6)
        case .eu: (-2, 0.08, 1.2)
        case .uk: (0, 0.12, 1.0)
        case .china: (-15, 0, 0.3)
        case .gulf: (4, 0.1, 0.2)
        case .india: (2, 0.08, 0.5)
        case .japanKorea: (1, 0.08, 0.8)
        }
    }

    /// Datacenter locations (LocationCatalog IDs) in the region.
    var locations: [String] {
        switch self {
        case .us: ["nova", "texas", "iowa", "oregon", "arizona"]
        case .eu: ["iceland"]
        case .gulf: ["uae"]
        default: []
        }
    }

    static func of(location id: String) -> Region? { allCases.first { $0.locations.contains(id) } }
}

/// The groups whose view of your lab the world keeps track of. Investors are your board (`boardConfidence`).
enum Stakeholder: String, CaseIterable, Identifiable, Sendable {
    case publicTrust = "public", researchers, developers, investors, governments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .publicTrust: "The public"
        case .researchers: "Researchers"
        case .developers: "Developers"
        case .investors: "Investors"
        case .governments: "Governments"
        }
    }

    /// What the number measures.
    var measure: String {
        switch self {
        case .publicTrust: "trust"
        case .researchers: "respect"
        case .developers: "goodwill"
        case .investors: "confidence"
        case .governments: "standing"
        }
    }

    var symbol: String {
        switch self {
        case .publicTrust: "person.3.fill"
        case .researchers: "brain.head.profile"
        case .developers: "chevron.left.forwardslash.chevron.right"
        case .investors: "banknote.fill"
        case .governments: "building.columns.fill"
        }
    }
}

/// Something that moved the world or your standing, and when.
struct WorldNote: Codable, Hashable {
    var date: Date
    var text: String
    /// Who or what moved and by how much: a stakeholder ("public", "researchers", "developers", "investors"), a region's
    /// raw value, or for world notes "concern", "mood", "grid".
    @D var deltas: [String: Double] = [:]
    /// "" for a change in your standing, "world" for something that moved the world, "consequence" for what followed.
    @D var kind: String = ""
}

/// The world at the end of one month, for charts.
struct WorldSnapshot: Codable, Hashable {
    var month: Date
    /// Adoption by sector (Sector order), 0–100.
    @D var adoption: [Double] = []
    @D var sentiment: Double = 50
    @D var concern: Double = 0
    /// Share of the work AI can reach that it now does, 0–100.
    @D var tasks: Double = 0
    /// People out of work because of AI (millions).
    @D var looking: Double = 0
    @D var powerGW: Double = 0
    /// AI's share of the world's electricity, 0–100.
    @D var aiShare: Double = 0
    /// Rule strictness by region (Region order), 0–100.
    @D var strictness: [Double] = []
    /// Your standing: public, researchers, developers, investors, governments (average).
    @D var standing: [Double] = []
}

/// Everything the world remembers between months. Saved with the game; missing keys decode to the defaults.
struct WorldState: Codable, DefaultValue {
    static var defaultValue: WorldState { WorldState() }

    @D var ready: Bool = false
    /// Keys the world's hashed rolls to this game (set once from the RNG's state, without drawing from it).
    @D var salt: String = ""

    // The world
    /// Adoption by sector (Sector order), 0–1.
    @D var adoption: [Double] = []
    /// Extra adoption a sector gets from world events (Sector order).
    @D var boosts: [Double] = []
    /// Public sentiment toward AI, 0–100 (50 is neutral).
    @D var sentiment: Double = 50
    /// Public concern about AI safety, 0–100.
    @D var concern: Double = 15
    /// Share of the work AI can reach that it now does, 0–1.
    @D var tasks: Double = 0
    /// Jobs AI has taken (millions, cumulative), jobs it has made, and people still looking for work because of it.
    @D var displaced: Double = 0
    @D var newJobs: Double = 0
    @D var looking: Double = 0
    /// Jobs inside the AI industry itself (millions).
    @D var aiJobs: Double = 0
    /// The world's AI fleet (H100-equivalents), its power draw (GW) and its share of the world's electricity (0–1).
    @D var computeH100e: Double = 0
    @D var powerGW: Double = 0
    @D var aiShare: Double = 0
    /// How hard AI's load pushes the grids, 0–100, and the part of it that comes from recent grid events.
    @D var gridStress: Double = 0
    @D var gridShock: Double = 0
    /// Rule strictness by region (Region order), 0–100.
    @D var strictness: [Double] = []
    /// Public trust in each rival lab (lab ID → 0–100).
    @D var labTrust: [String: Double] = [:]
    /// The latest major incident ("the agent worm") and when it happened.
    @D var incident: String = ""
    @D var incidentDate: Date? = nil

    // Your standing (investors are `boardConfidence`)
    @D var publicTrust: Double = 50
    @D var researchers: Double = 50
    @D var developers: Double = 50
    /// Standing with each government (Region order), 0–100.
    @D var governments: [Double] = []

    /// Why your standing moved, newest first.
    @D var notes: [WorldNote] = []
    /// What moved the world, newest first.
    @D var log: [WorldNote] = []
    /// What followed from the state of the world (Consequences), newest first.
    @D var consequences: [WorldNote] = []
    /// Month-end snapshots, oldest first.
    @D var history: [WorldSnapshot] = []

    // Consequences
    /// Rule key → when it last fired.
    @D var fired: [String: Date] = [:]
    /// Thresholds already crossed ("jobs" → 1–3, "agi" → 1–2).
    @D var levels: [String: Int] = [:]
    @D var lastConsequence: Date? = nil

    // What the world has already noticed (so each thing counts once)
    /// "r|<model>" released, "o|<model>" open weights, "t|<model>" benchmark-tuned, "chat" (you started the chat boom).
    @D var seen: Set<String> = []
    /// Scripted world events whose effects on the world are applied.
    @D var applied: Set<String> = []
    @D var seenReleased: Int = 0
    @D var seenOpen: Int = 0
    @D var lastThefts: Int = 0
    @D var lastStolen: Int = 0
    @D var lastChatPrice: Double = 0
    @D var lastFreeTier: Bool = true
    @D var published: Int = 0
    @D var goalsMet: Int = 0
    @D var goalsMissed: Int = 0
    /// Laws already counted (passed or failed).
    @D var laws: Set<String> = []
    /// Your side on bills still pending (bill ID → −1, 0, +1).
    @D var stances: [String: Int] = [:]
    /// API price per model at the last month end (model ID → $/1M tokens).
    @D var apiPrices: [String: Double] = [:]
    /// Ready datacenter sites already counted.
    @D var sites: Set<String> = []
    /// Regions where a sovereign deal of yours runs (region → until).
    @D var ties: [String: Date] = [:]

    // This month so far
    @D var letGo: Int = 0
    @D var letGoResearchers: Int = 0
    @D var layoffNoted: Bool = false
    @D var reliabilitySum: Double = 0
    @D var reliabilityDays: Int = 0
    @D var breachMax: Int = 0
    /// Last month's average reliability (0 before the first month).
    @D var lastReliability: Double = 0
    /// When enterprise SLA trouble was last noted.
    @D var lastBreachNote: Date? = nil

    /// Sizes the per-sector and per-region arrays (a save from another version may have fewer or more).
    mutating func normalize() {
        func fit(_ a: inout [Double], _ n: Int, _ fill: Double) {
            if a.count < n { a += Array(repeating: fill, count: n - a.count) }
            if a.count > n { a.removeLast(a.count - n) }
        }
        fit(&adoption, Sector.allCases.count, 0)
        fit(&boosts, Sector.allCases.count, 0)
        fit(&governments, Region.allCases.count, 50)
        if strictness.count != Region.allCases.count {
            let old = strictness
            strictness = Region.allCases.map { old.indices.contains($0.index) ? old[$0.index] : $0.baseline(2026) }
        }
    }

    // Convenience
    func adoption(_ sector: Sector) -> Double { adoption.indices.contains(sector.index) ? adoption[sector.index] : 0 }
    func strictness(_ r: Region) -> Double { strictness.indices.contains(r.index) ? strictness[r.index] : r.baseline(2020) }
    func government(_ r: Region) -> Double { governments.indices.contains(r.index) ? governments[r.index] : 50 }

    /// People out of work because of AI as a share of the workers it can reach (percent).
    var jobPressure: Double { looking / Sector.totalWorkforce * 100 }

    /// Average standing with governments.
    var governmentAverage: Double { governments.isEmpty ? 50 : governments.reduce(0, +) / Double(governments.count) }

    /// Rule strictness weighted by each region's share of the market.
    var averageStrictness: Double {
        var sum = 0.0
        for r in Region.allCases { sum += r.weight * strictness(r) }
        return sum
    }

    /// Average adoption across sectors, 0–1.
    var averageAdoption: Double { adoption.isEmpty ? 0 : adoption.reduce(0, +) / Double(adoption.count) }
}
