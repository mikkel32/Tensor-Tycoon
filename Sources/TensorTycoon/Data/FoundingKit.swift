import Foundation

// MARK: - Founding kit: the catalog

/// Groups of founding cards on the new-game screen.
enum KitCategory: String, CaseIterable, Identifiable, Sendable {
    case research, rl, compute, money, talent, data, product, wildcard
    var id: String { rawValue }

    var title: String {
        switch self {
        case .research: "Research"
        case .rl: "RL & post-training"
        case .compute: "Compute"
        case .money: "Money"
        case .talent: "Talent"
        case .data: "Data"
        case .product: "Product"
        case .wildcard: "Wildcards"
        }
    }

    var symbol: String {
        switch self {
        case .research: "lightbulb.fill"
        case .rl: "arrow.triangle.2.circlepath.circle.fill"
        case .compute: "cpu.fill"
        case .money: "dollarsign.circle.fill"
        case .talent: "person.crop.circle.badge.plus"
        case .data: "externaldrive.fill"
        case .product: "sparkles"
        case .wildcard: "dice.fill"
        }
    }
}

/// How the founding kit is limited.
enum KitMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A points budget set by difficulty.
    case standard
    /// Take any cards you like.
    case sandbox
    /// Any cards, and research runs four times faster on top.
    case genius
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Budget"
        case .sandbox: "Sandbox"
        case .genius: "Genius"
        }
    }

    var blurb: String {
        switch self {
        case .standard: "Spend a points budget set by difficulty. Cards with drawbacks give points back."
        case .sandbox: "No budget: take every card you want."
        case .genius: "No budget, and research runs ×\(Int(FoundingKit.geniusMultiplier)) faster on top of your cards (capped at ×\(Int(FoundingKit.researchCap)) in total)."
        }
    }
}

/// One starting advantage. Costs are in kit points; a negative cost is a drawback card that gives points back.
struct FoundingCard: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let category: KitCategory
    let cost: Int
    let symbol: String
    let blurb: String
    let pros: [String]
    var cons: [String] = []

    var isDrawback: Bool { cost < 0 }
}

enum FoundingKit {
    /// Research speed in Genius mode, before cards.
    static let geniusMultiplier = 4.0
    /// The most any combination of cards and modes can multiply research by.
    static let researchCap = 6.0
    /// The RL lab's top level.
    static let rlMaxLevel = 5

    static func budget(_ d: Difficulty) -> Int {
        switch d {
        case .easy: 20
        case .normal: 12
        case .hard: 8
        }
    }

    static let all: [FoundingCard] = [
        // MARK: Research
        FoundingCard(id: "genius_team", name: "Genius research team", category: .research, cost: 7, symbol: "brain.filled.head.profile",
                     blurb: "Your first hires are the people other labs write papers about.",
                     pros: ["Research ×2"]),
        FoundingCard(id: "mad_science", name: "Mad-science division", category: .research, cost: 11, symbol: "flask.fill",
                     blurb: "A basement full of people who don't sleep and don't ask permission.",
                     pros: ["Research ×3"], cons: ["−6 safety", "+20% alignment drift"]),
        FoundingCard(id: "prodigy", name: "Prodigy", category: .research, cost: 3, symbol: "graduationcap.fill",
                     blurb: "You arrive having already reproduced the next three papers.",
                     pros: ["Your first 3 research projects finish on day one"]),
        FoundingCard(id: "paper_mill", name: "Paper mill", category: .research, cost: 2, symbol: "doc.on.doc.fill",
                     blurb: "A paper a week, every week. People notice.",
                     pros: ["+15% research speed", "+0.3 brand a month", "+3 hiring skill"]),
        FoundingCard(id: "eureka_engine", name: "Eureka engine", category: .research, cost: 3, symbol: "lightbulb.max.fill",
                     blurb: "Long walks, whiteboards in the shower, a culture of wild ideas.",
                     pros: ["Eureka moments 3× as often", "New unique ideas 2× as often"]),
        FoundingCard(id: "polymath", name: "Polymath founder", category: .research, cost: 3, symbol: "person.fill.badge.plus",
                     blurb: "You still write the best code in the building.",
                     pros: ["You do the research of three people"]),
        FoundingCard(id: "frontier_fever", name: "Frontier fever", category: .research, cost: 2, symbol: "sparkles",
                     blurb: "Your team only gets out of bed for ideas nobody has had yet.",
                     pros: ["+50% frontier research", "+10% research speed"]),

        // MARK: RL & post-training
        FoundingCard(id: "rl_pioneers", name: "RL pioneers", category: .rl, cost: 4, symbol: "arrow.triangle.2.circlepath",
                     blurb: "You trained agents to play games before it was cool. Now you train models to think.",
                     pros: ["Opens your RL lab at level 2", "Reasoning & RL research 2× as fast"]),
        FoundingCard(id: "rlhf_pipeline", name: "RLHF pipeline", category: .rl, cost: 3, symbol: "hand.thumbsup.fill",
                     blurb: "A labelling vendor, a preference dataset and the code to use them, ready on day one.",
                     pros: ["Instruction Tuning, RLHF and DPO researched", "RL lab +1 level"]),
        FoundingCard(id: "reward_whisperers", name: "Reward-model whisperers", category: .rl, cost: 2, symbol: "scope",
                     blurb: "They can tell a reward hack from a real gain at a glance.",
                     pros: ["RL lab +1 level", "−20% post-training compute", "+0.05 instruction following"]),
        FoundingCard(id: "self_play", name: "Self-play gym", category: .rl, cost: 3, symbol: "figure.fencing",
                     blurb: "Thousands of environments where models play against copies of themselves.",
                     pros: ["RL lab +1 level", "+0.06 agentic RL", "+0.04 reasoning"]),
        FoundingCard(id: "verifier_farm", name: "Verifier farm", category: .rl, cost: 2, symbol: "checkmark.seal.fill",
                     blurb: "Auto-graded math, code and science problems by the million.",
                     pros: ["+0.05 RL strength", "+0.03 coding", "−15% RL compute"]),
        FoundingCard(id: "olympiad", name: "Olympiad alumni", category: .rl, cost: 2, symbol: "medal.fill",
                     blurb: "Half the team has a gold medal in something.",
                     pros: ["+0.06 reasoning", "+0.03 coding"]),

        // MARK: Compute
        FoundingCard(id: "angel_cluster", name: "Angel GPU cluster", category: .compute, cost: 3, symbol: "square.stack.3d.up.fill",
                     blurb: "An angel investor pays in graphics cards instead of cash.",
                     pros: ["+12 starter GPUs", "A garage wired for 4× the power"]),
        FoundingCard(id: "cloud_credits", name: "Cloud credits", category: .compute, cost: 2, symbol: "cloud.fill",
                     blurb: "A cloud provider wants you on its platform early.",
                     pros: ["Cloud credits worth your whole starting cash"]),
        FoundingCard(id: "dc_in_a_box", name: "Datacenter in a box", category: .compute, cost: 5, symbol: "server.rack",
                     blurb: "A prepaid colocation hall, racked and powered, with datacenter GPUs inside.",
                     pros: ["A 250 kW colocation hall, rent-free", "Datacenter GPUs worth about half your starting cash"]),
        FoundingCard(id: "chip_whisperer", name: "Chip whisperer", category: .compute, cost: 3, symbol: "memorychip.fill",
                     blurb: "Every vendor's sales rep has your personal number.",
                     pros: ["−8% on hardware & rentals", "−30% lead times", "×1.5 vendor allocation", "+2 pts MFU"]),
        FoundingCard(id: "overclock", name: "Overclocked garage", category: .compute, cost: 2, symbol: "gauge.with.dots.needle.100percent",
                     blurb: "Custom kernels, custom cooling, custom everything.",
                     pros: ["+3 pts MFU", "×1.05 effective compute"]),

        // MARK: Money
        FoundingCard(id: "rich_uncle", name: "Rich uncle", category: .money, cost: 3, symbol: "banknote.fill",
                     blurb: "He doesn't understand what you do, and he doesn't want shares.",
                     pros: ["+100% starting cash, no dilution"]),
        FoundingCard(id: "sovereign", name: "Sovereign backer", category: .money, cost: 5, symbol: "building.columns.fill",
                     blurb: "A national wealth fund wants a seat at the AI table.",
                     pros: ["+400% starting cash", "+0.3 board confidence a month"], cons: ["The fund takes 20% of the company"]),
        FoundingCard(id: "banker", name: "Friendly banker", category: .money, cost: 1, symbol: "creditcard.fill",
                     blurb: "Your college roommate runs a lending desk.",
                     pros: ["−1.5 pts on loan rates", "+0.5 pt yield on cash"]),
        FoundingCard(id: "hype_merchant", name: "Hype merchant", category: .money, cost: 2, symbol: "megaphone.fill",
                     blurb: "You could sell a GPU to a GPU company.",
                     pros: ["+20% valuation in rounds", "+8 starting brand"], cons: ["−10% research speed"]),
        FoundingCard(id: "bootstrapped", name: "Bootstrapped & lean", category: .money, cost: -3, symbol: "leaf.fill",
                     blurb: "Ramen, rented chairs and nobody to answer to.",
                     pros: ["−10% payroll", "+0.3 board confidence a month"], cons: ["−50% starting cash"]),

        // MARK: Talent
        FoundingCard(id: "star_visionary", name: "Star researcher", category: .talent, cost: 3, symbol: "star.circle.fill",
                     blurb: "A skill-88 Visionary leaves a big lab to join you.",
                     pros: ["A skill-88 Visionary researcher joins"]),
        FoundingCard(id: "star_kernel", name: "Kernel wizard", category: .talent, cost: 2, symbol: "wand.and.stars",
                     blurb: "Writes GPU kernels by hand, for fun.",
                     pros: ["A skill-85 Kernel Wizard ML engineer joins"]),
        FoundingCard(id: "defectors", name: "Ex-big-lab defectors", category: .talent, cost: 5, symbol: "person.3.fill",
                     blurb: "A whole team quits a giant on the same Friday.",
                     pros: ["3 senior researchers and an infra engineer join"], cons: ["They're paid 20% over market"]),
        FoundingCard(id: "safety_lead", name: "Safety lead", category: .talent, cost: 2, symbol: "shield.lefthalf.filled",
                     blurb: "The person who wrote the red-teaming playbook everyone copies.",
                     pros: ["A skill-82 Red Teamer joins", "+5 safety"]),
        FoundingCard(id: "talent_magnet", name: "Talent magnet", category: .talent, cost: 2, symbol: "magnet",
                     blurb: "Everyone wants to work with you.",
                     pros: ["+8 hiring skill", "−5% payroll"]),

        // MARK: Data
        FoundingCard(id: "exclusive_data", name: "Exclusive dataset", category: .data, cost: 3, symbol: "lock.doc.fill",
                     blurb: "Decades of proprietary text nobody else can buy.",
                     pros: ["×1.15 data efficiency", "+0.02 reasoning", "+0.02 coding"]),
        FoundingCard(id: "synth_engine", name: "Synthetic data engine", category: .data, cost: 3, symbol: "gearshape.2.fill",
                     blurb: "A pipeline that writes, checks and filters its own textbooks.",
                     pros: ["+30% usable training tokens", "×1.1 data efficiency"]),
        FoundingCard(id: "data_curator", name: "Data curator", category: .data, cost: 2, symbol: "tray.full.fill",
                     blurb: "Knows which pages to throw away.",
                     pros: ["A skill-84 Data Curator joins", "Fewer contaminated benchmarks"]),

        // MARK: Product
        FoundingCard(id: "viral_launch", name: "Viral launch", category: .product, cost: 3, symbol: "flame.fill",
                     blurb: "Your demo video got 40 million views before you had a product.",
                     pros: ["+15 starting brand", "+20% consumer demand"]),
        FoundingCard(id: "enterprise_rolodex", name: "Enterprise rolodex", category: .product, cost: 3, symbol: "briefcase.fill",
                     blurb: "Every CIO in the country has had dinner with you.",
                     pros: ["+25% enterprise deals", "A skill-80 Rainmaker joins"]),
        FoundingCard(id: "dev_darling", name: "Developer darling", category: .product, cost: 2, symbol: "chevron.left.forwardslash.chevron.right",
                     blurb: "Your open-source library has more stars than some countries.",
                     pros: ["+20% API demand", "+0.2 brand a month"]),

        // MARK: Wildcards
        FoundingCard(id: "alien_signal", name: "Alien signal", category: .wildcard, cost: 3, symbol: "antenna.radiowaves.left.and.right",
                     blurb: "A weight file that nobody trained, found on an old drive. It shouldn't work. It does.",
                     pros: ["40% of the way to your first alien architecture", "+40% alien insight"]),
        FoundingCard(id: "time_traveller", name: "Time traveller's notes", category: .wildcard, cost: 3, symbol: "clock.arrow.circlepath",
                     blurb: "A notebook in your handwriting, dated years from now.",
                     pros: ["Forecasts start 40% sharper", "The era briefing shows four years ahead", "+5% research speed"]),
        FoundingCard(id: "reg_friend", name: "Regulatory friend", category: .wildcard, cost: 2, symbol: "building.2.fill",
                     blurb: "An old friend now sits on the AI committee.",
                     pros: ["−50% fines and settlements", "+0.3 board confidence a month", "+3 safety"]),
        FoundingCard(id: "glass_cannon", name: "Glass cannon", category: .wildcard, cost: -2, symbol: "bolt.trianglebadge.exclamationmark.fill",
                     blurb: "Move fast, break things, including possibly the model.",
                     pros: ["Research ×1.5", "+3 pts MFU"], cons: ["−12 safety", "+40% alignment drift", "+50% fines"]),
        FoundingCard(id: "impatient_board", name: "Impatient board", category: .wildcard, cost: -3, symbol: "hourglass",
                     blurb: "Your investors want a return by Christmas.",
                     pros: [], cons: ["Board confidence drifts down 0.8 a month"]),
    ]

    static let byID: [String: FoundingCard] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func cards(_ ids: [String]) -> [FoundingCard] { ids.compactMap { byID[$0] } }

    static func cost(_ ids: [String]) -> Int { cards(ids).reduce(0) { $0 + $1.cost } }

    /// Research multiplier from cards (and Genius mode), capped.
    static func researchMultiplier(kit: [String], genius: Bool) -> Double {
        guard genius || !kit.isEmpty else { return 1 }
        var m = genius ? geniusMultiplier : 1
        for id in kit {
            switch id {
            case "genius_team": m *= 2
            case "mad_science": m *= 3
            case "glass_cannon": m *= 1.5
            default: break
            }
        }
        return min(researchCap, m)
    }

    /// Kit cards that change your lab's identity bonuses.
    static func apply(_ id: String, _ t: inout TraitBonuses) {
        switch id {
        case "mad_science": t.safety -= 6; t.drift -= 0.20
        case "paper_mill": t.rp += 0.15; t.brand += 0.3; t.hiring += 3
        case "polymath": t.founderRP += 2
        case "frontier_fever": t.frontierRP += 0.5; t.rp += 0.10
        case "chip_whisperer": t.hardware += 0.08; t.leadTime += 0.3; t.allocation += 0.5; t.mfu += 0.02
        case "overclock": t.mfu += 0.03; t.algo += 0.02
        case "sovereign": t.confidence += 0.3
        case "banker": t.loanRate += 1.5; t.yield += 0.5
        case "hype_merchant": t.valuation += 0.20; t.rp -= 0.10
        case "bootstrapped": t.payroll -= 0.10; t.confidence += 0.3
        case "safety_lead": t.safety += 5
        case "talent_magnet": t.hiring += 8; t.payroll -= 0.05
        case "viral_launch": t.consumer += 0.20
        case "enterprise_rolodex": t.enterprise += 0.25
        case "dev_darling": t.api += 0.20; t.brand += 0.2
        case "alien_signal": t.insight += 0.4
        case "time_traveller": t.rp += 0.05
        case "reg_friend": t.fines += 0.5; t.confidence += 0.3; t.safety += 3
        case "glass_cannon": t.mfu += 0.03; t.safety -= 12; t.drift -= 0.40; t.fines -= 0.5
        case "impatient_board": t.confidence -= 0.8
        default: break
        }
    }

    // MARK: Research-side effects (virtual research items)

    static let rlLabID = "kit:rllab"

    /// What one level of the RL lab adds (scaled by level through `results`).
    static let rlLabPerLevel: [ResearchEffect] = [.skill(.reasoning, 0.02), .rl(0.03), .agentRL(0.015), .rlEfficiency(0.04), .postTrainCost(0.03)]

    /// Cards whose effects run through the research bonuses.
    static let researchEffects: [String: [ResearchEffect]] = [
        "reward_whisperers": [.postTrainCost(0.2), .skill(.chat, 0.05)],
        "self_play": [.agentRL(0.06), .skill(.reasoning, 0.04)],
        "verifier_farm": [.rl(0.05), .skill(.code, 0.03), .rlEfficiency(0.15)],
        "olympiad": [.skill(.reasoning, 0.06), .skill(.code, 0.03)],
        "exclusive_data": [.dataAlgo(0.06), .skill(.reasoning, 0.02), .skill(.code, 0.02)],
        "synth_engine": [.dataTokens(0.3), .dataAlgo(0.04)],
        "data_curator": [.contaminationGuard(0.3)],
        "time_traveller": [.forecast(0.4)],
    ]

    static let virtualItems: [ResearchItem] = [
        ResearchItem(id: rlLabID, name: "RL lab", category: .reasoning, year: 0, cost: 0, prereqs: [], effects: rlLabPerLevel,
                     blurb: "Your reinforcement-learning lab: environments, reward models and the people who tune them."),
    ] + researchEffects.keys.sorted().compactMap { id in
        guard let card = byID[id], let effects = researchEffects[id] else { return nil }
        return ResearchItem(id: "kit:\(id)", name: card.name, category: .frontier, year: 0, cost: 0, prereqs: [], effects: effects, blurb: card.blurb)
    }

    /// RL lab levels each card adds.
    static func rlLevels(_ id: String) -> Int {
        switch id {
        case "rl_pioneers": 2
        case "rlhf_pipeline", "reward_whisperers", "self_play": 1
        default: 0
        }
    }

    // MARK: Starter quests

    struct QuestReward: Sendable {
        /// Cash as a fraction of the era's starting cash.
        var cash = 0.0
        var credits = 0.0
        var brand = 0.0
        var culture = 0
        var confidence = 0.0
        /// Days of research added to the current project.
        var researchDays = 0.0
        var rlLevels = 0

        var text: String {
            var parts: [String] = []
            if cash > 0 { parts.append("a cash grant") }
            if credits > 0 { parts.append("cloud credits") }
            if researchDays > 0 { parts.append("\(Int(researchDays)) days of research") }
            if brand > 0 { parts.append("+\(Int(brand)) brand") }
            if culture > 0 { parts.append("+\(culture) culture point\(culture == 1 ? "" : "s")") }
            if confidence > 0 { parts.append("+\(Int(confidence)) board confidence") }
            if rlLevels > 0 { parts.append("a free RL lab level") }
            return parts.joined(separator: ", ")
        }
    }

    static func questReward(_ key: String) -> QuestReward? {
        switch key {
        case "research": QuestReward(researchDays: 10)
        case "train": QuestReward(cash: 0.10)
        case "ship": QuestReward(brand: 5)
        case "chat": QuestReward(brand: 3, culture: 1)
        case "hire": QuestReward(culture: 1)
        case "compute": QuestReward(credits: 0.10)
        case "ops": QuestReward(confidence: 5)
        case "raise": QuestReward(brand: 2, confidence: 5)
        case "rl": QuestReward(rlLevels: 1)
        case "million": QuestReward(cash: 0.15, brand: 5, culture: 1)
        case "top10": QuestReward(brand: 5, culture: 1)
        case "profit": QuestReward(culture: 1, confidence: 8)
        default: nil
        }
    }
}
