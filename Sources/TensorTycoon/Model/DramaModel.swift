import Foundation

// MARK: - 3.9: dramatic events — fires, blackouts, leaks, lawsuits, scandals and lucky breaks, each with a choice

/// How a dramatic event turned out for you, for the log's colour.
enum DramaTone: Int, Codable, Sendable {
    case bad = -1, mixed = 0, good = 1
}

/// One dramatic event: what happened, what you chose and what came of it.
struct DramaRecord: Codable, Identifiable, Hashable {
    var id = StableID.next()
    /// DramaCatalog event ID.
    var event: String
    var date: Date
    var title: String
    /// What happened before you chose (the damage already done, the offer on the table).
    var summary: String
    /// The option you took ("" while it waits in the inbox).
    @D var choice: String = ""
    /// What came of it, filled in when you answer and again when a follow-up lands (a verdict, a payout).
    @D var outcome: String = ""
    @D var tone: DramaTone = .mixed
    /// The inbox decision it posted.
    @D var decision: UUID? = nil
    /// You didn't answer and the inbox picked the safe default.
    @D var defaulted: Bool = false
}

extension DramaTone: DefaultValue { static var defaultValue: DramaTone { .mixed } }

/// Something a choice set in motion that lands later: an insurance payout, a court verdict, a celebrity's next headline.
struct DramaFollowUp: Codable, Hashable {
    var kind: String
    var due: Date
    var ref: String = ""
    var amount: Double = 0
    /// The DramaRecord it reports back to.
    var record: UUID? = nil
}

/// 3.9: dramatic events (Drama). Older saves decode empty and start with a quiet grace period.
struct DramaState: Codable, Hashable, DefaultValue {
    static var defaultValue: DramaState { DramaState() }

    /// When the last dramatic event fired (events are spaced at least `Drama.gapDays` apart).
    @D var last: Date? = nil
    /// Event ID → when it last fired (each has its own cooldown).
    @D var fired: [String: Date] = [:]
    /// Newest first, at most 40.
    @D var log: [DramaRecord] = []
    @D var followUps: [DramaFollowUp] = []
    /// Lasting fixes your answers bought: "fire_suppression", "backup_power", "ir_retainer", "oncall", "posting_policy",
    /// "watermarks", "insured". Each makes its event rarer or softer next time.
    @D var hardened: Set<String> = []
    /// Lifetime count, and how many you answered yourself (the rest went to the inbox default).
    @D var count: Int = 0
    @D var answered: Int = 0

    /// The record for a decision.
    func index(of decision: UUID) -> Int? { log.firstIndex { $0.decision == decision } }
}
