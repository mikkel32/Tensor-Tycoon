import Foundation

// MARK: - 3.5: model families

/// A size tier in a model family. The flagship is the model you trained; every other tier is distilled from it.
enum FamilyTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case flagship, core, spark, mote

    var id: String { rawValue }

    /// The tier's name inside a family ("Atlas Spark").
    var label: String {
        switch self {
        case .flagship: "Titan"
        case .core: "Core"
        case .spark: "Spark"
        case .mote: "Mote"
        }
    }

    /// Student parameters as a share of the teacher's.
    var sizeFraction: Double {
        switch self {
        case .flagship: 1
        case .core: 0.3
        case .spark: 0.08
        case .mote: 0.015
        }
    }

    var role: String {
        switch self {
        case .flagship: "The hardest problems and enterprise contracts. Priced for quality."
        case .core: "The workhorse: most API traffic at a mid price."
        case .spark: "Fast and cheap: the free chat tier and price-sensitive API buyers."
        case .mote: "Tiny and nearly free to serve: bulk classification, routing, on-device."
        }
    }

    var symbol: String {
        switch self {
        case .flagship: "crown.fill"
        case .core: "cube.fill"
        case .spark: "bolt.fill"
        case .mote: "circle.grid.cross.fill"
        }
    }

    /// Order inside a family view (flagship first).
    var rank: Int {
        switch self {
        case .flagship: 0
        case .core: 1
        case .spark: 2
        case .mote: 3
        }
    }
}

struct FamilyMember: Codable, Hashable {
    var modelID: UUID
    var tier: FamilyTier
    @D var joined: Date? = nil
}

/// A flagship and the smaller tiers distilled from it, sold under one name.
struct ModelFamily: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var created: Date
    var members: [FamilyMember] = []
    /// The family's own reputation (0–100): grows as tiers ship and the flagship ranks; lifts every member's API demand.
    @D var brand: Double = 20
    /// The member that serves the chat app's free users (nil: the chat model serves everyone).
    @D var freeTierID: UUID? = nil
    /// Flagship generations that joined (the first flagship is generation 1).
    @D var generation: Int = 1

    func has(_ id: UUID) -> Bool { members.contains { $0.modelID == id } }
    func tier(of id: UUID) -> FamilyTier? { members.first { $0.modelID == id }?.tier }
}

/// Data budget of a distillation: tokens per student parameter.
enum DistillData: Int, Codable, CaseIterable, Identifiable, Sendable {
    case light = 1, standard = 2, heavy = 4

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .light: "Light"
        case .standard: "Standard"
        case .heavy: "Heavy"
        }
    }
    var tokensPerParam: Double { 10 * Double(rawValue) }
    /// Multiplies the distillation gap: more teacher outputs, closer student.
    var gapFactor: Double {
        switch self {
        case .light: 1.15
        case .standard: 1.0
        case .heavy: 0.88
        }
    }
}

/// A post-training pass on a model you already have.
enum PostTrainPass: String, Codable, CaseIterable, Identifiable, Sendable {
    case reasoningRL, agentic, safety, longContext, specCode, specScience, specMedicine

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reasoningRL: "Reasoning RL"
        case .agentic: "Tool use & agentic training"
        case .safety: "Safety tuning"
        case .longContext: "Long-context extension"
        case .specCode: "Specialise: code"
        case .specScience: "Specialise: science"
        case .specMedicine: "Specialise: medicine"
        }
    }

    var symbol: String {
        switch self {
        case .reasoningRL: "brain"
        case .agentic: "figure.walk.motion"
        case .safety: "checkmark.shield.fill"
        case .longContext: "archivebox.fill"
        case .specCode: "chevron.left.forwardslash.chevron.right"
        case .specScience: "atom"
        case .specMedicine: "cross.case.fill"
        }
    }

    var blurb: String {
        switch self {
        case .reasoningRL: "RL on verifiable problems: it learns to think before answering. Smarter at math and science, chattier and pricier to serve."
        case .agentic: "Tool calls, computer use and long tasks in sandboxed environments. Better agent, wider misuse surface."
        case .safety: "Refusal training, red-teaming and constitutional tuning. Enterprises and regulators like it; some users hit refusals."
        case .longContext: "Extends the context window a step and trains it to use it. Better memory; the KV cache makes it costlier to serve."
        case .specCode: "A long code-heavy fine-tune. Much stronger engineer, a little narrower everywhere else."
        case .specScience: "Papers, lab protocols and science problems. A research assistant, at some cost to conversation."
        case .specMedicine: "Clinical text and careful answers. Knows medicine and stays cautious; narrower at code and agents."
        }
    }

    /// Share of the model's pre-training compute one pass takes (before research discounts).
    var computeShare: Double {
        switch self {
        case .reasoningRL: 0.04
        case .agentic: 0.03
        case .safety: 0.008
        case .longContext: 0.02
        case .specCode, .specScience, .specMedicine: 0.015
        }
    }

    var isSpecialisation: Bool { self == .specCode || self == .specScience || self == .specMedicine }
}

enum ModelJobKind: String, Codable, Sendable {
    case distill, postTrain, merge
}

/// Compute set aside for a distillation, a post-training pass or a merge. Its chips count as training chips.
struct ModelJob: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var kind: ModelJobKind
    /// The teacher (distillation) or the model being improved.
    var modelID: UUID
    var familyID: UUID? = nil
    var name: String = ""
    @D var tier: String = FamilyTier.spark.rawValue
    @D var data: Int = DistillData.standard.rawValue
    @D var pass: String = ""
    var accelID: String
    var chips: Int
    var flops: Double
    var done: Double = 0
    var started: Date
    var cost: Double = 0
    @D var paused: Bool = false
    /// Release the result with an API and servers as soon as it's done (distillation).
    @D var autoLaunch: Bool = true

    var progress: Double { flops > 0 ? min(1, done / flops) : 1 }
    var tierValue: FamilyTier { FamilyTier(rawValue: tier) ?? .spark }
    var dataValue: DistillData { DistillData(rawValue: data) ?? .standard }
    var passValue: PostTrainPass? { PostTrainPass(rawValue: pass) }
}

struct FamilyState: Codable, Hashable, DefaultValue {
    static var defaultValue: FamilyState { FamilyState() }

    @D var families: [ModelFamily] = []
    @D var jobs: [ModelJob] = []
    /// Lifetime counts, for the dashboard card and achievements-style lines.
    @D var distilled: Int = 0
    @D var passes: Int = 0
    @D var merges: Int = 0

    var isEmpty: Bool { families.isEmpty && jobs.isEmpty }
}
