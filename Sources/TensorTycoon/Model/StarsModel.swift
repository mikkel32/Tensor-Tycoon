import Foundation

// 3.9: star researchers and the talent wars — personalities, ambitions, bidding wars, burnout, prizes and chemistry.
// One field on GameState (`stars`), so older saves load with it empty and profiles appear for the stars they already have.

/// What drives a star, and so what wins them over in a bidding war.
enum StarPersonality: String, Codable, CaseIterable, Sendable {
    case idealist, mercenary, builder, showman, scholar, maverick, steady

    var title: String {
        switch self {
        case .idealist: "Idealist"
        case .mercenary: "Mercenary"
        case .builder: "Builder"
        case .showman: "Showman"
        case .scholar: "Scholar"
        case .maverick: "Maverick"
        case .steady: "Steady hand"
        }
    }

    var blurb: String {
        switch self {
        case .idealist: "Here for the mission. Money matters less than what the work is for."
        case .mercenary: "Knows exactly what they're worth and who'll pay it."
        case .builder: "Wants the biggest cluster in the building and to ship on it."
        case .showman: "Loves a stage, a title and a launch with their name on it."
        case .scholar: "Thinks in papers. Wants freedom to chase ideas and publish them."
        case .maverick: "Does their best work when nobody tells them what to do."
        case .steady: "Low drama, high output, and hard to lure away."
        }
    }

    var symbol: String {
        switch self {
        case .idealist: "heart.text.square.fill"
        case .mercenary: "dollarsign.circle.fill"
        case .builder: "hammer.fill"
        case .showman: "music.mic"
        case .scholar: "book.closed.fill"
        case .maverick: "bolt.fill"
        case .steady: "anchor"
        }
    }

    /// How much each lever moves them (about 1 is ordinary).
    func weight(_ l: StarLever) -> Double {
        switch (self, l) {
        case (.idealist, .salary): 0.5
        case (.idealist, .equity): 0.5
        case (.idealist, .title): 0.6
        case (.idealist, .compute): 1.0
        case (.idealist, .mandate): 1.6
        case (.mercenary, .salary): 1.6
        case (.mercenary, .equity): 1.4
        case (.mercenary, .title): 0.6
        case (.mercenary, .compute): 0.5
        case (.mercenary, .mandate): 0.3
        case (.builder, .salary): 0.6
        case (.builder, .equity): 0.6
        case (.builder, .title): 0.6
        case (.builder, .compute): 1.8
        case (.builder, .mandate): 0.8
        case (.showman, .salary): 1.0
        case (.showman, .equity): 0.8
        case (.showman, .title): 1.6
        case (.showman, .compute): 0.6
        case (.showman, .mandate): 0.6
        case (.scholar, .salary): 0.5
        case (.scholar, .equity): 0.4
        case (.scholar, .title): 0.7
        case (.scholar, .compute): 1.0
        case (.scholar, .mandate): 1.8
        case (.maverick, .salary): 0.8
        case (.maverick, .equity): 0.8
        case (.maverick, .title): 0.4
        case (.maverick, .compute): 1.0
        case (.maverick, .mandate): 1.6
        case (.steady, _): 0.9
        }
    }

    /// How often rivals' offers tempt them, and how fast they wear out.
    var poachability: Double {
        switch self {
        case .mercenary: 1.5
        case .showman, .maverick: 1.2
        case .builder: 1.0
        case .idealist, .scholar: 0.8
        case .steady: 0.5
        }
    }

    var burnRate: Double {
        switch self {
        case .builder, .showman: 1.3
        case .maverick, .mercenary: 1.0
        case .idealist: 1.1
        case .scholar: 0.8
        case .steady: 0.6
        }
    }
}

/// The field a star is known for: their breakthroughs land there.
enum StarSpecialty: String, Codable, CaseIterable, Sendable {
    case scaling, reasoning, interpretability, systems, multimodal, data, agents, science, chips, markets

    var title: String {
        switch self {
        case .scaling: "Scaling laws"
        case .reasoning: "Reasoning & RL"
        case .interpretability: "Interpretability"
        case .systems: "Distributed systems"
        case .multimodal: "Multimodal"
        case .data: "Data"
        case .agents: "Agents"
        case .science: "AI for science"
        case .chips: "Chip architecture"
        case .markets: "Go-to-market"
        }
    }

    /// The research category their work speeds up most.
    var category: ResearchCategory? {
        switch self {
        case .scaling: .optimization
        case .reasoning: .reasoning
        case .interpretability: .safety
        case .systems: .systems
        case .multimodal: .multimodal
        case .data: .data
        case .agents: .agents
        case .science: .science
        case .chips: .systems
        case .markets: nil
        }
    }

    /// What a breakthrough of theirs looks like.
    var results: [String] {
        switch self {
        case .scaling: ["a cleaner scaling law for data-constrained training", "a learning-rate recipe that transfers across model sizes", "a fix for the loss spikes that kept killing big runs"]
        case .reasoning: ["a reward model that is much harder to game", "a way to train longer chains of thought without collapse", "a verifier that checks proofs step by step"]
        case .interpretability: ["a feature map of the model's own deception circuits", "a probe that flags sycophancy before release", "a method to read out what a model plans three steps ahead"]
        case .systems: ["a pipeline schedule that recovers 9% of idle GPU time", "a checkpointing scheme that halves restart time", "a collective-communication trick for cross-datacenter training"]
        case .multimodal: ["a video tokenizer that is four times cheaper", "a single model that reads charts, screenshots and handwriting", "an audio front end that keeps tone and timing"]
        case .data: ["a filter that throws out the worst 30% of the web corpus", "a synthetic-data loop that stops model collapse", "a dedup pass that finds near-copies across languages"]
        case .agents: ["a memory design that keeps long tasks on track", "a tool-use curriculum that cuts agent failures by a third", "a sandbox benchmark the whole field adopts"]
        case .science: ["a protein-design model that works in the wet lab first time", "a materials screen that finds two new stable compounds", "a weather model that beats the national forecast"]
        case .chips: ["a matrix-unit layout that saves 12% die area", "a memory controller that hides HBM latency", "a packaging plan that raises yield"]
        case .markets: ["a pricing model that big customers sign up for", "an enterprise pilot programme that converts", "a partner channel that opens a new market"]
        }
    }

    /// The title that goes with leading it.
    var head: String {
        switch self {
        case .scaling: "Head of Pre-training"
        case .reasoning: "Head of Reasoning"
        case .interpretability: "Head of Interpretability"
        case .systems: "Head of Systems"
        case .multimodal: "Head of Multimodal"
        case .data: "Head of Data"
        case .agents: "Head of Agents"
        case .science: "Head of AI for Science"
        case .chips: "Head of Silicon"
        case .markets: "Chief Revenue Officer"
        }
    }

    /// How a prize citation names the field.
    var field: String {
        switch self {
        case .scaling: "scaling laws"
        case .reasoning: "reasoning and reinforcement learning"
        case .interpretability: "interpretability"
        case .systems: "distributed training"
        case .multimodal: "multimodal learning"
        case .data: "training data"
        case .agents: "AI agents"
        case .science: "AI for science"
        case .chips: "AI accelerators"
        case .markets: "AI products"
        }
    }

    static func options(_ r: Role) -> [StarSpecialty] {
        switch r {
        case .researcher: [.scaling, .reasoning, .interpretability, .multimodal, .agents, .science, .data]
        case .mlEngineer: [.systems, .scaling, .reasoning]
        case .infra: [.systems]
        case .data: [.data, .multimodal]
        case .sales: [.markets]
        case .safety: [.interpretability, .reasoning]
        case .chipDesigner: [.chips, .systems]
        }
    }
}

/// What a star wants from their career.
enum StarAmbition: String, Codable, CaseIterable, Sendable {
    case lead, compute, publish, wealth, mission, ship, recognition

    var title: String {
        switch self {
        case .lead: "Run something"
        case .compute: "Big compute"
        case .publish: "Publish"
        case .wealth: "Get rich"
        case .mission: "Do it safely"
        case .ship: "Ship the frontier"
        case .recognition: "Be recognised"
        }
    }

    /// The lever that satisfies it, when one does.
    var lever: StarLever? {
        switch self {
        case .lead: .title
        case .compute: .compute
        case .publish, .mission: .mandate
        case .wealth: .salary
        case .ship, .recognition: nil
        }
    }
}

/// Things you can give a star (in a counter-offer or any time from the Stars panel).
enum StarLever: String, Codable, CaseIterable, Identifiable, Sendable {
    case salary, equity, title, compute, mandate
    var id: String { rawValue }

    var title: String {
        switch self {
        case .salary: "Pay"
        case .equity: "Equity"
        case .title: "Title"
        case .compute: "Compute budget"
        case .mandate: "Research mandate"
        }
    }

    var symbol: String {
        switch self {
        case .salary: "dollarsign.circle"
        case .equity: "chart.pie"
        case .title: "rosette"
        case .compute: "cpu"
        case .mandate: "map"
        }
    }
}

/// A dated line in a star's story.
struct StarBeat: Codable, Hashable {
    var date: Date
    var text: String
    /// +1 good, −1 bad, 0 neutral (the panel colours it).
    @D var tone: Int = 0
}

/// One of your stars (keyed by their employee ID).
struct StarProfile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var personality: StarPersonality
    var specialty: StarSpecialty
    var ambition: StarAmbition
    /// One line of backstory.
    var origin: String
    var joined: Date
    /// 0 fresh … 100 burned out.
    @D var fatigue: Double = 15
    /// 0 unknown … 100 a household name in the field.
    @D var renown: Double = 10
    /// A title you gave them ("Chief Scientist", "Head of Reasoning", "Distinguished Scientist").
    @D var title: String = ""
    /// A dedicated cluster budget, a month.
    @D var computeBudget: Double = 0
    /// Free to set their own research agenda.
    @D var mandate: Bool = false
    @D var sabbaticalUntil: Date? = nil
    @D var lastSabbatical: Date? = nil
    @D var offersFended: Int = 0
    /// The last time a rival came for them (labs don't call the same person every month).
    @D var lastOffer: Date? = nil
    @D var breakthroughs: Int = 0
    /// Came back after leaving.
    @D var boomerang: Bool = false
    /// Award IDs ("lovelace|2028").
    @D var awards: [String] = []
    /// Months in a row their want has gone unmet.
    @D var unmetMonths: Int = 0
    /// Newest first.
    @D var story: [StarBeat] = []
}

/// A rival's offer for one of your stars, or your offer for one of theirs (`outgoing`).
struct StarOffer: Codable, Hashable {
    /// Your star's employee ID, or (outgoing) the rival researcher's cast ID.
    var star: String
    var name: String
    /// Competitor ID, or a description ("a big-tech lab").
    var lab: String
    var round: Int = 1
    /// Their pay offer a year, and the equity they put on the table (in dollars).
    var salary: Double
    var equity: Double
    /// The title they offer (empty if none).
    var title: String
    /// They promise a cluster of the star's own.
    var compute: Bool
    var started: Date
    var decision: UUID? = nil
    @D var outgoing: Bool = false
}

/// A star who left: where to, why, and whether they've asked to come back.
struct StarAlumnus: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var role: Role
    var skill: Double
    var salary: Double
    var personality: StarPersonality
    var specialty: StarSpecialty
    var ambition: StarAmbition
    var origin: String
    /// Competitor ID or a description.
    var lab: String
    var left: Date
    var reason: String
    /// Parted on good terms (you let them go gracefully).
    @D var amicable: Bool = false
    @D var asked: Bool = false
    @D var returned: Bool = false
    @D var awards: [String] = []
    @D var story: [StarBeat] = []
}

/// One year's prize.
struct StarAward: Codable, Hashable, Identifiable {
    var id: String { "\(prize)|\(year)" }
    var prize: String
    var year: Int
    var winner: String
    /// "player", a lab ID or an organisation's name.
    var org: String
    var citation: String
    @D var mine: Bool = false
}

/// Everything the star system remembers (one field on GameState).
struct StarsState: Codable, Hashable, DefaultValue {
    static var defaultValue: StarsState { StarsState() }

    @D var profiles: [StarProfile] = []
    @D var offer: StarOffer? = nil
    /// Newest first.
    @D var alumni: [StarAlumnus] = []
    /// Newest first.
    @D var awards: [StarAward] = []
    @D var lastOffer: Date? = nil
    @D var lastRaid: Date? = nil
    /// Prize winners make the lab a magnet for talent until this date.
    @D var haloUntil: Date? = nil
    /// Headcount at the last sync (a hire or departure triggers the next one).
    @D var synced: Int = -1
    /// Running totals.
    @D var wars: Int = 0
    @D var warsWon: Int = 0
    @D var defections: Int = 0
    @D var boomerangs: Int = 0
    @D var raidsWon: Int = 0
    @D var burnouts: Int = 0
}
