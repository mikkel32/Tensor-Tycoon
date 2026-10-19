import Foundation

// MARK: - 3.5: model families

/// A size tier in a model family. The flagship is the model you trained; every other tier is distilled from it.
enum FamilyTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case flagship, core, spark, mote
    /// 3.8: specialists forked from a member (same size, its own servers), sold next to the generalist.
    case coder, scientist, medic, reasoner, omni, robotics

    var id: String { rawValue }

    /// Size tiers (distilled), not specialists.
    static let sizes: [FamilyTier] = [.flagship, .core, .spark, .mote]

    /// A specialist forked from another member.
    var isSpecialist: Bool { !FamilyTier.sizes.contains(self) }

    /// The specialisation pass that makes this specialist.
    var pass: PostTrainPass? {
        switch self {
        case .coder: .specCode
        case .scientist: .specScience
        case .medic: .specMedicine
        case .reasoner: .specReasoning
        case .omni: .specMultimodal
        case .robotics: .specRobotics
        default: nil
        }
    }

    /// The tier's name inside a family ("Atlas Spark").
    var label: String {
        switch self {
        case .flagship: "Titan"
        case .core: "Core"
        case .spark: "Spark"
        case .mote: "Mote"
        case .coder: "Code"
        case .scientist: "Science"
        case .medic: "Med"
        case .reasoner: "Think"
        case .omni: "Omni"
        case .robotics: "Robotics"
        }
    }

    /// Student parameters as a share of the teacher's (specialists are forks: the same size).
    var sizeFraction: Double {
        switch self {
        case .flagship: 1
        case .core: 0.3
        case .spark: 0.08
        case .mote: 0.015
        default: 1
        }
    }

    var role: String {
        switch self {
        case .flagship: "The hardest problems and enterprise contracts. Priced for quality."
        case .core: "The workhorse: most API traffic at a mid price."
        case .spark: "Fast and cheap: the free chat tier and price-sensitive API buyers."
        case .mote: "Tiny and nearly free to serve: bulk classification, routing, on-device."
        case .coder: "The coding specialist: wins the coding API segment and coding contracts."
        case .scientist: "The science specialist: research assistants, science contracts and the Discovery Service."
        case .medic: "The clinical specialist: knowledge-heavy contracts and the Healthcare Assistant."
        case .reasoner: "Thinks longest: maths, logic and the hardest reasoning traffic."
        case .omni: "Sees and hears: the vision and voice API segment."
        case .robotics: "Drives robot bodies: the Robotics Brain and robot makers' APIs."
        }
    }

    var symbol: String {
        switch self {
        case .flagship: "crown.fill"
        case .core: "cube.fill"
        case .spark: "bolt.fill"
        case .mote: "circle.grid.cross.fill"
        case .coder: "chevron.left.forwardslash.chevron.right"
        case .scientist: "atom"
        case .medic: "cross.case.fill"
        case .reasoner: "brain"
        case .omni: "eye.fill"
        case .robotics: "gearshape.2.fill"
        }
    }

    /// Order inside a family view (flagship first, specialists after the size tiers).
    var rank: Int {
        switch self {
        case .flagship: 0
        case .core: 1
        case .spark: 2
        case .mote: 3
        case .coder: 4
        case .scientist: 5
        case .medic: 6
        case .reasoner: 7
        case .omni: 8
        case .robotics: 9
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
    /// 3.8: specialisations that only exist as forks (a new family member).
    case specReasoning, specMultimodal, specRobotics

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
        case .specReasoning: "Specialise: reasoning"
        case .specMultimodal: "Specialise: vision & voice"
        case .specRobotics: "Specialise: robotics"
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
        case .specReasoning: "brain.head.profile"
        case .specMultimodal: "eye.fill"
        case .specRobotics: "gearshape.2.fill"
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
        case .specReasoning: "Long RL on maths, logic and proofs, with a bigger thinking budget. The strongest reasoner in the family, slower and chattier."
        case .specMultimodal: "Trains a vision and audio adapter: it sees images and screens and, with voice research, listens and speaks. Costs a little serving speed."
        case .specRobotics: "Vision-language-action training on robot data: a model that drives robot bodies. Needs robotics research and vision."
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
        case .specReasoning: 0.03
        case .specMultimodal: 0.025
        case .specRobotics: 0.035
        }
    }

    var isSpecialisation: Bool { [.specCode, .specScience, .specMedicine, .specReasoning, .specMultimodal, .specRobotics].contains(self) }

    /// 3.8: specialisations make a new family member instead of changing the model in place.
    var forks: Bool { isSpecialisation }

    /// The specialist tier a fork with this pass joins the family as.
    var tier: FamilyTier? {
        switch self {
        case .specCode: .coder
        case .specScience: .scientist
        case .specMedicine: .medic
        case .specReasoning: .reasoner
        case .specMultimodal: .omni
        case .specRobotics: .robotics
        default: nil
        }
    }

    /// 3.8: the domains whose published techniques a pass teaches the model (its training data and environments use
    /// them). A pass catches the model up on these domains' research and nothing else — a safety pass doesn't teach
    /// robotics.
    var refreshes: [CapDomain] {
        switch self {
        case .reasoningRL: [.reasoning, .math, .calibration]
        case .agentic: [.agents, .reliability]
        case .safety: [.calibration]
        case .longContext: [.memory]
        case .specCode: [.coding, .architecture, .hardware]
        case .specScience: [.science, .math]
        case .specMedicine: [.knowledge, .science]
        case .specReasoning: [.reasoning, .math, .calibration]
        case .specMultimodal: [.vision, .voice]
        case .specRobotics: [.robotics, .vision]
        }
    }
}

enum ModelJobKind: String, Codable, Sendable {
    case distill, postTrain, merge
    /// 3.8: a copy of a member, specialised by a pass, that joins the family as a specialist tier.
    case fork
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

/// 3.8: how long a deployed reasoning model thinks before it answers (test-time compute). More thinking tokens score a
/// little higher on reasoning-heavy domains and cost more to serve; fewer are cheaper and a little weaker.
enum ReasoningEffort: String, Codable, CaseIterable, Identifiable, Sendable, DefaultValue {
    case low, medium, high
    static var defaultValue: ReasoningEffort { .medium }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    /// Multiplies the thinking part of a reasoning model's tokens (Families.thinkingTokens).
    var tokenScale: Double {
        switch self {
        case .low: 0.4
        case .medium: 1
        case .high: 1.8
        }
    }

    /// Effective capability (log10 compute; 0.1 = one point) added to reasoning, maths, science and coding.
    var scoreShift: Double {
        switch self {
        case .low: -0.08
        case .medium: 0
        case .high: 0.06
        }
    }

    static let shiftedDomains: [CapDomain] = [.reasoning, .math, .science, .coding]

    var blurb: String {
        switch self {
        case .low: "Short thinking: cheapest and fastest to serve, −0.8 points in reasoning, maths, science and coding."
        case .medium: "The default thinking budget."
        case .high: "Thinks much longer: +0.6 points in reasoning, maths, science and coding, and a much bigger serving bill."
        }
    }
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
