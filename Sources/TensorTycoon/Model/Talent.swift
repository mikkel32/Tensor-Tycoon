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

/// How you put a model into the world.
enum LaunchStyle: String, CaseIterable, Identifiable, Sendable {
    case standard, keynote, blitz, staged
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Blog post"
        case .keynote: "Keynote launch"
        case .blitz: "Benchmark blitz"
        case .staged: "Staged rollout"
        }
    }

    var detail: String {
        switch self {
        case .standard: "A post, a model card, an API page."
        case .keynote: "Livestreamed event and ad campaign: more brand and hype, costs money."
        case .blitz: "Lead with benchmark charts: big brand win if you're #1, backlash if you're not top 3."
        case .staged: "Trusted testers first: +4 model safety, quieter launch."
        }
    }
}
