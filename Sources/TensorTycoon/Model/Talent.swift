import Foundation

/// What makes a person special. Stars arrive with one; veterans can be promoted into one you choose.
enum TalentTrait: String, Codable, CaseIterable, Identifiable, Sendable {
    case visionary, kernelWizard, firefighter, curator, rainmaker, redTeamer, tapeoutVet
    case mentor, loyal, diva, workhorse
    var id: String { rawValue }

    var title: String {
        switch self {
        case .visionary: "Visionary"
        case .kernelWizard: "Kernel Wizard"
        case .firefighter: "Firefighter"
        case .curator: "Data Curator"
        case .rainmaker: "Rainmaker"
        case .redTeamer: "Red Teamer"
        case .tapeoutVet: "Tape-out Veteran"
        case .mentor: "Mentor"
        case .loyal: "Loyal"
        case .diva: "Brilliant Diva"
        case .workhorse: "Workhorse"
        }
    }

    var symbol: String {
        switch self {
        case .visionary: "sparkles"
        case .kernelWizard: "wand.and.stars"
        case .firefighter: "flame.fill"
        case .curator: "tray.full.fill"
        case .rainmaker: "cloud.rain.fill"
        case .redTeamer: "shield.lefthalf.filled"
        case .tapeoutVet: "memorychip.fill"
        case .mentor: "person.2.fill"
        case .loyal: "heart.fill"
        case .diva: "theatermasks.fill"
        case .workhorse: "figure.run"
        }
    }

    var detail: String {
        switch self {
        case .visionary: "Counts as 1.6 researchers of the same skill."
        case .kernelWizard: "Counts as 1.8 engineers toward MFU and stability."
        case .firefighter: "Counts as 2 infra engineers when clusters fail."
        case .curator: "Counts as 1.8 data engineers."
        case .rainmaker: "Counts as 2 salespeople: more deals, more brand."
        case .redTeamer: "Counts as 1.8 safety researchers."
        case .tapeoutVet: "Counts as 1.8 chip designers."
        case .mentor: "+10% output and lifts everyone's morale."
        case .loyal: "+5% output and never leaves for a rival."
        case .diva: "+50% output, but colleagues in the same role lose morale."
        case .workhorse: "+25% output."
        }
    }

    /// The trait tied to a role.
    static func specialty(_ r: Role) -> TalentTrait {
        switch r {
        case .researcher: .visionary
        case .mlEngineer: .kernelWizard
        case .infra: .firefighter
        case .data: .curator
        case .sales: .rainmaker
        case .safety: .redTeamer
        case .chipDesigner: .tapeoutVet
        }
    }

    /// Traits someone in this role can have (or be promoted into).
    static func options(_ r: Role) -> [TalentTrait] { [specialty(r), .mentor, .workhorse, .loyal, .diva] }

    /// Promotion choices: the specialty plus two people skills.
    static func promotions(_ r: Role) -> [TalentTrait] { [specialty(r), .mentor, .workhorse] }

    var multiplier: Double {
        switch self {
        case .visionary: 1.6
        case .kernelWizard, .curator, .redTeamer, .tapeoutVet: 1.8
        case .firefighter, .rainmaker: 2.0
        case .mentor: 1.1
        case .loyal: 1.05
        case .diva: 1.5
        case .workhorse: 1.25
        }
    }
}

extension Employee {
    var talent: TalentTrait? { TalentTrait(rawValue: trait) }
    var traitMultiplier: Double { talent?.multiplier ?? 1 }
    /// Contribution in "skill-50 people", including their trait.
    var weight: Double { skill / 50 * traitMultiplier }
}

extension Candidate {
    var talent: TalentTrait? { TalentTrait(rawValue: trait) }
}

/// How you put a model into the world. 3.7: the launch strategy of a `LaunchPlan` (Launches explains each one's effects).
enum LaunchStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard, stealth, staged, keynote, openWeights, enterprise, government, blitz
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Blog post"
        case .stealth: "Stealth drop"
        case .staged: "Staged rollout"
        case .keynote: "Keynote launch"
        case .openWeights: "Open-weights launch"
        case .enterprise: "Enterprise-first"
        case .government: "Government-first"
        case .blitz: "Benchmark-first"
        }
    }

    var symbol: String {
        switch self {
        case .standard: "doc.richtext"
        case .stealth: "eye.slash"
        case .staged: "list.number"
        case .keynote: "music.mic"
        case .openWeights: "lock.open.fill"
        case .enterprise: "briefcase.fill"
        case .government: "building.columns.fill"
        case .blitz: "chart.bar.xaxis"
        }
    }

    var detail: String {
        switch self {
        case .standard: "A post, a model card, an API page."
        case .stealth: "Switch it on and say nothing. Little brand, no press, no regulators; traffic builds by word of mouth."
        case .staged: "Waitlist, then paid users, then everyone: +4 model safety, quieter launch, pent-up demand when it opens."
        case .keynote: "Livestreamed event and ad campaign: more brand and hype and a day-one rush, costs money; rivals and regulators notice."
        case .openWeights: "Weights and API on day one: developers and researchers flock to it; security hawks and rivals react."
        case .enterprise: "Design partners and contracts before the public: more enterprise leads and investor confidence, a slow public start."
        case .government: "Briefings and sovereign partners first: governments warm to you and sovereign offers come sooner; critics grumble."
        case .blitz: "Publish full evals first: big brand win if you're #1, backlash if you're not top 3."
        }
    }
}

/// 3.7: what a launch charges for the API against the going rate, for its first 120 days.
enum PricingStance: String, Codable, CaseIterable, Identifiable, Sendable {
    case premium, match, undercut
    var id: String { rawValue }

    var title: String {
        switch self {
        case .premium: "Premium"
        case .match: "Match the market"
        case .undercut: "Undercut"
        }
    }

    var detail: String {
        switch self {
        case .premium: "List 25% above the going rate: more per token, fewer tokens; a top-3 model earns a little prestige."
        case .match: "Price where the market is (today's auto-pricing)."
        case .undercut: "List 25% below: developers switch, but the rival you undercut is likely to answer with a price cut."
        }
    }

    /// Multiplier on the launch list price and on the auto-pricing band during the launch window.
    var priceFactor: Double {
        switch self {
        case .premium: 1.25
        case .match: 1
        case .undercut: 0.75
        }
    }
}

/// 3.7: how much safety work a launch publishes.
enum SafetyPosture: String, Codable, CaseIterable, Identifiable, Sendable {
    case light, standard, thorough
    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Short model card"
        case .standard: "Standard system card"
        case .thorough: "Full system card + red-team report"
        }
    }

    var detail: String {
        switch self {
        case .light: "Ship with a page of notes: a little more buzz, but researchers, the public and regulators mark you down."
        case .standard: "The usual system card."
        case .thorough: "Deep system card and an external red-team report: costs money, +3 model safety, trust and calmer regulators."
        }
    }
}

/// 3.7: how a model is put into the world — strategy, price and safety posture. The default plan (blog post, market
/// price, standard system card) is exactly the release the game always had.
struct LaunchPlan: Codable, Hashable, DefaultValue {
    static var defaultValue: LaunchPlan { LaunchPlan() }
    @D var strategy: LaunchStyle = .standard
    @D var pricing: PricingStance = .match
    @D var safety: SafetyPosture = .standard

    init(strategy: LaunchStyle = .standard, pricing: PricingStance = .match, safety: SafetyPosture = .standard) {
        self.strategy = strategy
        self.pricing = pricing
        self.safety = safety
    }

    var isDefault: Bool { strategy == .standard && pricing == .match && safety == .standard }

    var summary: String {
        var parts = [strategy.title]
        if pricing != .match { parts.append(pricing.title.lowercased() + " price") }
        if safety != .standard { parts.append(safety.title.lowercased()) }
        return parts.joined(separator: " · ")
    }
}

extension LaunchStyle: DefaultValue { static var defaultValue: LaunchStyle { .standard } }
extension PricingStance: DefaultValue { static var defaultValue: PricingStance { .match } }
extension SafetyPosture: DefaultValue { static var defaultValue: SafetyPosture { .standard } }
