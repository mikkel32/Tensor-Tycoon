import Foundation

/// A reusable, player-authored training recipe. Blueprints are configuration, not a second training system: launching
/// one still goes through GameState.startTraining and all of its hardware, research, memory and cash validation.
struct RunBlueprint: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var detail: String = ""
    var design: ModelDesign
    var lr: LRSchedule = .standard
    var checkpointEvery: Double = 0.1
    var autoRollback: Bool = false
    var automation: RunAutomationPolicy = RunAutomationPolicy()
    var created: Date
    var lastUsed: Date? = nil
    var uses: Int = 0

    /// SwiftUI editors use a placeholder identity until the player saves. The real identity is allocated inside
    /// `saveBlueprint`, so merely opening or redrawing an editor never consumes the persisted deterministic ID stream.
    static func draft(design: ModelDesign, date: Date) -> RunBlueprint {
        RunBlueprint(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                     name: "\(design.name) recipe", design: design, created: date)
    }
}

/// Opt-in supervision for one run. Every automatic action uses the same intervention code as a manual action; the two
/// budgets are independent so an automation policy cannot spend either its run allowance or the player's cash reserve.
struct RunAutomationPolicy: Codable, Hashable {
    var enabled: Bool = false
    var diagnostics: Bool = true
    var investigate: Bool = true
    var redTeam: Bool = true
    var cashReserve: Double = 0
    var spendingCap: Double = 250_000
}

struct RecipeObservation: Codable, Hashable {
    var runID: UUID
    var date: Date
    var compute: Double
    /// Actual capability minus its launch forecast, with learning-rate and incident effects removed.
    var residual: Double
}

struct RecipeLearning: Codable, Hashable {
    var signature: String
    var observations: [RecipeObservation] = []
}

/// The bounded, inspectable result of a completed run. This is the evidence behind recipe learning and the training
/// insights screen; it is not a parallel model-history database.
struct RunOutcome: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var runID: UUID
    var blueprintID: UUID? = nil
    var name: String
    var signature: String
    var date: Date
    var compute: Double
    var forecastC: Double
    var actualC: Double
    var forecastIndex: Double
    var actualIndex: Double
    var residual: Double
    var cost: Double
    var days: Int
    var incidents: Int
    var supervised: Bool
    var automationActions: Int
    var automationSpent: Double
}

struct RecipeEvidence: Hashable {
    var correction: Double = 0
    var samples: Int = 0
    var uncertaintyCut: Double = 0
    var effectiveWeight: Double = 0
}
