import Foundation

// MARK: - 3.9: hype, launch events, developer days and viral moments

/// What kind of show you put on.
enum StageKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case launch, devDay
    var id: String { rawValue }

    var title: String {
        switch self {
        case .launch: "Launch event"
        case .devDay: "Developer day"
        }
    }

    var symbol: String {
        switch self {
        case .launch: "sparkles.tv.fill"
        case .devDay: "chevron.left.forwardslash.chevron.right"
        }
    }

    var blurb: String {
        switch self {
        case .launch: "A keynote for your next model. Your best unreleased model goes live on stage; if you released one in the last three weeks, the show is its big moment."
        case .devDay: "A conference for the developers who build on your API: tools, credits, a store and a community hackathon. Grows your developer ecosystem."
        }
    }
}

/// Where the show happens: how much it costs, how many people see it and how high anticipation can climb.
enum StageFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case livestream, pressEvent, arena
    var id: String { rawValue }

    var title: String {
        switch self {
        case .livestream: "Livestream from the office"
        case .pressEvent: "Press event"
        case .arena: "Arena keynote"
        }
    }

    var short: String {
        switch self {
        case .livestream: "Livestream"
        case .pressEvent: "Press event"
        case .arena: "Arena"
        }
    }

    var detail: String {
        switch self {
        case .livestream: "A camera, a couch and your team. Cheap, intimate, easy to miss."
        case .pressEvent: "A rented hall, 300 journalists and a product video. The standard."
        case .arena: "Five thousand seats, a live band and a stream everyone watches. Big reach, big stakes."
        }
    }

    /// Share of the keynote budget (GameState.keynoteCost) it costs to book.
    var costShare: Double {
        switch self {
        case .livestream: 0.15
        case .pressEvent: 0.5
        case .arena: 1.2
        }
    }

    /// How far the show's score carries (hype, brand, viewers).
    var reach: Double {
        switch self {
        case .livestream: 0.6
        case .pressEvent: 0.9
        case .arena: 1.25
        }
    }

    /// Anticipation builds toward this while the event is on the calendar.
    var anticipationCap: Double {
        switch self {
        case .livestream: 55
        case .pressEvent: 70
        case .arena: 88
        }
    }
}

/// One slot in a run of show.
enum StageSegment: String, Codable, CaseIterable, Identifiable, Sendable {
    case benchmarks, liveDemo, agentDemo, pricing, safety, partner, cameo, oneMoreThing
    case sdk, credits, store, hackathon
    var id: String { rawValue }

    var title: String {
        switch self {
        case .benchmarks: "Benchmark charts"
        case .liveDemo: "Live demo"
        case .agentDemo: "Live agent demo"
        case .pricing: "Pricing reveal"
        case .safety: "Safety segment"
        case .partner: "Customer on stage"
        case .cameo: "Celebrity cameo"
        case .oneMoreThing: "\"One more thing\""
        case .sdk: "Agent SDK and tools"
        case .credits: "Startup credits"
        case .store: "App store"
        case .hackathon: "Community hackathon"
        }
    }

    var symbol: String {
        switch self {
        case .benchmarks: "chart.bar.xaxis"
        case .liveDemo: "play.display"
        case .agentDemo: "figure.run.circle"
        case .pricing: "tag.fill"
        case .safety: "checkmark.shield.fill"
        case .partner: "person.2.wave.2.fill"
        case .cameo: "star.circle.fill"
        case .oneMoreThing: "ellipsis.circle.fill"
        case .sdk: "shippingbox.fill"
        case .credits: "creditcard.fill"
        case .store: "square.grid.3x3.fill"
        case .hackathon: "laptopcomputer.and.iphone"
        }
    }

    var detail: String {
        switch self {
        case .benchmarks: "Safe. Lands well when the model tops the board; a top-5 miss reads as chart crimes."
        case .liveDemo: "The model, live, no edits. A hit is the clip of the year; a crash is too."
        case .agentDemo: "It books the flight, files the expenses and orders the pizza, live. Bigger payoff, bigger risk."
        case .pricing: "Announce the price on stage. An undercut gets the loudest cheer and draws a price war."
        case .safety: "Your system card, explained. Calms the public and researchers; the crowd checks its phones."
        case .partner: "A big customer's chief executive says nice things. Investors love it."
        case .cameo: "A famous face. Costs extra; charming three times in four, cringe the fourth."
        case .oneMoreThing: "Tease the model after this one. Hype carries over, but you'll have to ship it within five months."
        case .sdk: "Agent tooling and SDKs. Developers build more on you."
        case .credits: "Free compute for startups. Costs real money; the ecosystem grows fastest."
        case .store: "A marketplace for apps on your models. Chat users come for it; spam can follow."
        case .hackathon: "A weekend for a thousand outside developers. Sometimes a community demo goes viral."
        }
    }

    /// Segments each kind of show can use.
    static func options(_ k: StageKind) -> [StageSegment] {
        switch k {
        case .launch: [.benchmarks, .liveDemo, .agentDemo, .pricing, .safety, .partner, .cameo, .oneMoreThing]
        case .devDay: [.sdk, .credits, .store, .hackathon, .liveDemo, .agentDemo, .safety, .cameo]
        }
    }
}

/// A show on the calendar.
struct StageEvent: Codable, Hashable, Identifiable {
    var id = StableID.next()
    var kind: StageKind
    var format: StageFormat
    var announced: Date
    var date: Date
    var segments: [StageSegment] = []
    var rehearsals: Int = 0
    var pricing: PricingStance = .match
    /// What booking it cost (and the cameo fee, paid on the day).
    @D var cost: Double = 0
    /// A model released ahead of the show: the show is its big moment, and its day-one boost waits for it.
    @D var modelID: UUID? = nil
    @D var postponed: Int = 0
    /// The "nothing to launch" warning went out for this date.
    @D var warnedFor: Date? = nil
}

/// One beat of a show, as the live blog wrote it.
struct ShowBeat: Codable, Hashable {
    /// "10:04"
    var clock: String
    var text: String
    /// −1 … +1: how the room took it.
    var tone: Double
    @D var segment: String = ""
}

/// A show that happened.
struct StageShow: Codable, Hashable, Identifiable {
    var id = StableID.next()
    var kind: StageKind
    var format: StageFormat
    var date: Date
    var title: String
    /// The model it launched or showcased ("" for a vision keynote or a developer day).
    var model: String
    var beats: [ShowBeat] = []
    /// 0–100.
    var score: Double
    var viewers: Double
    var hypeBefore: Double
    var hypeAfter: Double
    @D var headline: String = ""
    /// Live-demo outcomes: "ok", "fail" or "".
    @D var demo: String = ""
}

/// A viral moment: a meme, a clip or a backlash.
struct ViralMoment: Codable, Hashable, Identifiable {
    var id = StableID.next()
    var date: Date
    /// ViralCatalog id.
    var kind: String
    var title: String
    var detail: String
    var hashtag: String
    var positive: Bool
    var views: Double
    @D var hypeDelta: Double = 0
    @D var brandDelta: Double = 0
    /// How you answered ("" while it waits in the inbox or when nothing was asked).
    @D var response: String = ""
    @D var model: String = ""
}

/// A recent reason the meter moved.
struct HypeDriver: Codable, Hashable {
    var date: Date
    var amount: Double
    var text: String
}

/// How a launch spent the hype: the day-one boost on its model and the gap between promise and delivery.
struct HypeLaunch: Codable, Hashable {
    var modelID: UUID
    var model: String
    var date: Date
    var hype: Double
    /// Day-one demand boost (0.3 = +30%), halving every `Hype.boostHalfLife` days.
    var boost: Double
    /// What the model delivered on the same 0–100 scale, and the show's score (−1 when there was no show).
    var delivered: Double
    @D var showScore: Double = -1
    /// "overhyped", "sleeper" or "".
    @D var verdict: String = ""
}

/// Everything hype remembers (one field on GameState, so older saves start at zero).
struct HypeState: Codable, Hashable, DefaultValue {
    static var defaultValue: HypeState { HypeState() }

    /// 0–100: how much the world is waiting for your next thing.
    @D var meter: Double = 0
    /// Weekly samples of the meter, oldest first (a year).
    @D var history: [Double] = []
    @D var drivers: [HypeDriver] = []
    /// Teasers posted since your last launch, and the last one.
    @D var teasers: Int = 0
    @D var lastTeaser: Date? = nil
    /// The show on the calendar, and the shows that happened (newest first).
    @D var event: StageEvent? = nil
    @D var shows: [StageShow] = []
    @D var lastDevDay: Date? = nil
    /// Launches that spent hype (newest first).
    @D var launches: [HypeLaunch] = []
    /// A "one more thing" promise: ship a new model by this date.
    @D var promise: Date? = nil
    @D var promiseModel: String = ""
    /// Viral moments (newest first), and a viral clip's lift on the chat app.
    @D var viral: [ViralMoment] = []
    @D var viralBoost: Double = 0
    @D var viralDate: Date? = nil
    /// An app store's lift on the chat app (from a developer day), and until when.
    @D var storeUntil: Date? = nil
    /// A safety segment on stage: fewer backlash moments until this date.
    @D var calmUntil: Date? = nil
    /// 0–100: standing on the conference circuit (orals, best papers, keynotes). Researchers want to work for it.
    @D var prestige: Double = 0
    /// A recruiting booth booked at a conference ("<venue>|<year>").
    @D var booth: String = ""
    @D var boothsRun: Int = 0
    @D var hires: Int = 0
    /// Set up once (an older save's meter starts from its brand rather than zero).
    @D var ready: Bool = false

    init() {}
}
