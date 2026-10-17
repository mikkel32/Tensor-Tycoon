import Foundation

/// Your lab's signature secret: a proprietary research programme only you have, live from the first day of any era.
/// It grows through five levels as you pour research into it, and levels 3 and 5 unlock capstone abilities.
enum SignatureSecret: String, CaseIterable, Identifiable, Codable, Sendable {
    case cortex, oracle, ouroboros, lodestar, mirror, forge, atlas, keel, antenna

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cortex: "Dendritic Cortex"
        case .oracle: "Insight Engine"
        case .ouroboros: "Recursive Self-Distillation"
        case .lodestar: "Dense Reward Oracle"
        case .mirror: "Synthetic Mind Data"
        case .forge: "Neural Compiler"
        case .atlas: "Cognitive Scaffold"
        case .keel: "Alignment Keel"
        case .antenna: "Xeno Resonance"
        }
    }

    /// Internal programme name, shown in caps.
    var codename: String { rawValue.uppercased() }

    var symbol: String {
        switch self {
        case .cortex: "brain.filled.head.profile"
        case .oracle: "lightbulb.max.fill"
        case .ouroboros: "arrow.triangle.2.circlepath"
        case .lodestar: "star.circle.fill"
        case .mirror: "square.on.square.dashed"
        case .forge: "hammer.circle.fill"
        case .atlas: "person.3.sequence.fill"
        case .keel: "shield.lefthalf.filled.badge.checkmark"
        case .antenna: "dot.radiowaves.left.and.right"
        }
    }

    var tagline: String {
        switch self {
        case .cortex: "A neural architecture nobody else has: more intelligence from every FLOP."
        case .oracle: "Tools that make your researchers several times faster."
        case .ouroboros: "Every model you train teaches the next one."
        case .lodestar: "A reward model that can't be fooled, so RL keeps paying off."
        case .mirror: "Machine-written data as good as the best human text — and endless."
        case .forge: "A compiler that squeezes every chip to its physical limit."
        case .atlas: "A scaffold that turns any model into a reliable, long-running agent."
        case .keel: "Alignment that makes models more trustworthy and more useful."
        case .antenna: "A strange knack for hearing what alien designs are trying to say."
        }
    }

    var blurb: String {
        switch self {
        case .cortex:
            "Your founding insight: a dendritic layer where every neuron computes on its inputs before summing them. It isn't in any paper, and nobody else will think of it for years."
        case .oracle:
            "An internal system that reads every paper, proposes experiments and predicts their results. Your researchers spend their time on the ideas that will work."
        case .ouroboros:
            "Each finished model is distilled into the starting point and the training data of the next. The more models you train, the further ahead you start."
        case .lodestar:
            "A dense, process-level reward signal trained on its own adversarial attacks. Reinforcement learning stays honest at any scale."
        case .mirror:
            "A data engine that writes, verifies and filters its own curriculum. The data wall never arrives for you."
        case .forge:
            "A whole-program compiler for neural networks, from graph to kernels to chip layout. Your hardware runs closer to its limit than anyone else's."
        case .atlas:
            "Memory, planning and self-checking wrapped around the model. Your agents keep their footing for days."
        case .keel:
            "Training that makes honesty and helpfulness the same objective. Customers, regulators and your own swarms trust what you ship."
        case .antenna:
            "A family of probes that map the internal geometry of designs no human wrote. Alien tech comes to you faster and makes more sense."
        }
    }

    /// What each level adds (every level stacks).
    var perLevel: [ResearchEffect] {
        switch self {
        case .cortex: [.algo(0.07), .skill(.reasoning, 0.03)]
        case .oracle: [.rp(0.2), .forecast(0.08)]
        case .ouroboros: [.distill(0.06), .postTrainCost(0.06), .algo(0.02)]
        case .lodestar: [.rl(0.05), .rlEfficiency(0.08), .skill(.reasoning, 0.03)]
        case .mirror: [.dataTokens(0.25), .dataAlgo(0.03), .contaminationGuard(0.1)]
        case .forge: [.mfu(0.03), .throughput(0.12), .failureCost(0.08), .chipDesign(0.05)]
        case .atlas: [.skill(.agent, 0.04), .agentQuality(0.12), .coordination(0.008)]
        case .keel: [.safety(5), .agentSafety(0.08), .enterpriseDemand(0.04), .skill(.chat, 0.03)]
        case .antenna: [.insight(0.2), .legibility(0.04)]
        }
    }

    /// Extra effects at level 3.
    var capstone3: [ResearchEffect] {
        switch self {
        case .cortex: [.skill(.longctx, 0.15)]
        case .oracle: []
        case .ouroboros: [.distill(0.15)]
        case .lodestar: [.skill(.code, 0.08)]
        case .mirror: [.dataAlgo(0.05)]
        case .forge: [.tps(0.2)]
        case .atlas: [.agentRL(0.1)]
        case .keel: []
        case .antenna: []
        }
    }

    /// Extra effects at level 5.
    var capstone5: [ResearchEffect] {
        switch self {
        case .cortex: [.algo(0.15)]
        case .oracle: [.rp(0.3)]
        case .ouroboros: []
        case .lodestar: [.rl(0.1)]
        case .mirror: [.dataAlgo(0.1)]
        case .forge: [.throughput(0.3)]
        case .atlas: []
        case .keel: [.safety(10)]
        case .antenna: [.legibility(0.1)]
        }
    }

    /// The level-3 capstone, in words.
    var capstone3Text: String {
        switch self {
        case .cortex: "Dendritic memory: +0.15 long-context skill."
        case .oracle: "Eureka moments come twice as often."
        case .ouroboros: "Students land 15% closer to their teachers when distilled."
        case .lodestar: "Training never suffers reward hacking or sycophancy surprises."
        case .mirror: "Repeated data loses no value: the data wall is gone."
        case .forge: "+20% tokens per second on every model you serve."
        case .atlas: "Agents need 40% fewer tokens, so the same chips run bigger swarms."
        case .keel: "Swarms and self-improvement runs drift 30% less."
        case .antenna: "Alien search works with a model a step below the frontier."
        }
    }

    /// The level-5 capstone, in words.
    var capstone5Text: String {
        switch self {
        case .cortex: "Full dendritic stack: another ×1.4 effective compute on every run."
        case .oracle: "Cascades: each finished project has a 25% chance to finish the next one too."
        case .ouroboros: "Lineage doubles: every model you've trained adds twice as much to the next."
        case .lodestar: "Self-improvement runs climb 30% faster."
        case .mirror: "Verified self-play data: another ×1.26 data efficiency on every run."
        case .forge: "+30% throughput, and chip programmes and alien tape-outs finish 40% faster."
        case .atlas: "Swarm output grows almost linearly with size."
        case .keel: "+10 safety, and safeguards cost your models no serving throughput."
        case .antenna: "+10 legibility, and every alien discovery arrives one generation stronger."
        }
    }

    /// Research points to reach `level` from the level below.
    static func cost(toLevel level: Int) -> Double {
        switch level {
        case ...1: 0
        case 2: 250
        case 3: 1_500
        case 4: 6_000
        default: 20_000
        }
    }

    static let maxLevel = 5

    /// Default research share for a new lab.
    static let defaultShare = 0.25

    // MARK: Virtual research items

    /// Research items that carry the signature's effects into the bonus aggregator (scaled by level via `results`).
    static let virtualItems: [ResearchItem] = allCases.flatMap { sig -> [ResearchItem] in
        [
            ResearchItem(id: "sig:\(sig.rawValue)", name: sig.title, category: .frontier, year: 0, cost: 0, prereqs: [],
                         effects: sig.perLevel, blurb: sig.blurb),
            ResearchItem(id: "sig:\(sig.rawValue):3", name: "\(sig.title) capstone", category: .frontier, year: 0, cost: 0, prereqs: [],
                         effects: sig.capstone3, blurb: sig.capstone3Text),
            ResearchItem(id: "sig:\(sig.rawValue):5", name: "\(sig.title) mastery", category: .frontier, year: 0, cost: 0, prereqs: [],
                         effects: sig.capstone5, blurb: sig.capstone5Text),
        ]
    } + [
        // Ouroboros lineage: scaled by how many models you've trained.
        ResearchItem(id: "sig:lineage", name: "Model lineage", category: .frontier, year: 0, cost: 0, prereqs: [],
                     effects: [.algo(0.01)], blurb: "Every model you've trained makes the next one start further ahead."),
    ]
}
