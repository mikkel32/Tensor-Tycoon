import Foundation

// MARK: - 3.9: endings and legacy

/// One line of the company's history that nothing else in the save keeps (records, crises, near misses, the treaty,
/// the state's pressure). Launches, rounds, stages and milestones are read from their own records instead.
struct ChronicleEntry: Codable, Hashable {
    var date: Date
    /// "record", "crisis", "people", "policy", "safety", "rank", "victory".
    var kind: String
    var title: String
    @D var detail: String = ""
    @D var symbol: String = "circle.fill"
    /// true: good news, false: bad, nil: neither.
    @D var good: Bool? = nil
}

/// The International Compact on Frontier AI: talks, your part in them and the text that came out.
struct TreatyArc: Codable, Hashable, DefaultValue {
    static var defaultValue: TreatyArc { TreatyArc() }
    /// 0 none yet · 1 talks open · 2 signed · 3 collapsed.
    @D var stage: Int = 0
    @D var opened: Date? = nil
    /// When the final text is due.
    @D var due: Date? = nil
    @D var signed: Date? = nil
    /// +1 the safety coalition, −1 the light-touch camp, 0 watching.
    @D var stance: Int = 0
    /// Whether you were offered a seat (a released model in the top ten when talks opened or later).
    @D var invited: Bool = false
    /// Weight you've put behind the text, and everyone else's.
    @D var influence: Double = 0
    @D var others: Double = 0
    /// The verification-clause session (mid-talks) has been offered.
    @D var draftingOffered: Bool = false
    /// The text ended up the way you argued for.
    @D var shaped: Bool = false

    var share: Double { influence + others > 0 ? influence / (influence + others) : 0 }
}

/// Everything the endings system keeps in a save. Older saves decode the defaults and seed silently.
struct EndingsState: Codable, Hashable, DefaultValue {
    static var defaultValue: EndingsState { EndingsState() }

    /// Counters below have been seeded (so a save loaded mid-game doesn't log its past as news).
    @D var ready: Bool = false
    @D var chronicle: [ChronicleEntry] = []
    // What the monthly scan has already seen.
    @D var wasTop: Bool = false
    @D var valuationTier: Int = 0
    @D var revenueTier: Int = 0
    @D var staffTier: Int = 0
    @D var thefts: Int = 0
    @D var victoriesSeen: Set<String> = []
    @D var moonshotsSeen: Int = 0
    @D var starsSeen: Set<String> = []
    @D var boardThreatSeen: Date? = nil
    @D var correctionSeen: Date? = nil
    @D var bestRank: Int = 0

    // Arcs
    @D var treaty: TreatyArc = TreatyArc()
    /// 0–100: how hard the state is leaning on a lab it thinks is too powerful to leave alone.
    @D var friction: Double = 0
    /// 0 quiet · 1 golden share asked · 2 emergency powers invoked · 3 lost in court (ultimatum).
    @D var stateStage: Int = 0
    @D var stateAsked: Date? = nil
    @D var goldenShare: Bool = false
    /// Months in a row the lab has been out of the race.
    @D var irrelevant: Int = 0
    @D var outcompetedOffered: Date? = nil
    @D var giantOffered: Bool = false
    /// The dangerous-capability finding fired, and whether you shipped anyway (an incident may follow).
    @D var brinkFired: Bool = false
    @D var brinkRisk: Date? = nil
    /// Containment emergencies you came through (escape attempts shut down, dangerous models held back).
    @D var nearMisses: [Date] = []
    @D var avertedOffers: Int = 0
    @D var avertedDue: Date? = nil

    // The end
    /// EndingKind raw value once the game has ended ("" while it runs).
    @D var ending: String = ""
    /// Set by an ending this system offered, just before the game ends (classify reads it first).
    @D var pending: String = ""
    /// A variant of the ending ("acquihire" / "opensource" for outcompeted…).
    @D var variant: String = ""
    @D var endedOn: Date? = nil
    @D var finalScore: Int = 0
    /// LegacyPerk raw values this company was founded with (New Game+).
    @D var perks: [String] = []
}
