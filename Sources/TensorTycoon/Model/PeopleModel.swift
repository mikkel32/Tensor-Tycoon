import Foundation

// 3.4: the people of AI — the cast (Cast), the voices in the news (Voices) and the industry chatter (Pulse).
// Everything here is presentational: none of it feeds back into the simulation.

/// What someone does in the industry right now (careers change it).
enum CastKind: String, Codable, CaseIterable, Sendable {
    case leader, scientist, researcher, analyst, investor, journalist, official, critic, academic, free

    var title: String {
        switch self {
        case .leader: "Lab leader"
        case .scientist: "Chief scientist"
        case .researcher: "Researcher"
        case .analyst: "Analyst"
        case .investor: "Investor"
        case .journalist: "Press"
        case .official: "Policy"
        case .critic: "Critic"
        case .academic: "Academic"
        case .free: "Between jobs"
        }
    }

    /// Works at an AI lab.
    var atLab: Bool { self == .leader || self == .scientist || self == .researcher }
}

/// How someone tends to behave and talk.
enum CastTrait: String, Codable, CaseIterable, Sendable {
    case bold, cautious, contrarian, showman, academic, hypeProne, doomer, accelerationist, pragmatic, secretive

    var title: String {
        switch self {
        case .bold: "Bold"
        case .cautious: "Cautious"
        case .contrarian: "Contrarian"
        case .showman: "Showman"
        case .academic: "Academic"
        case .hypeProne: "Hype-prone"
        case .doomer: "Doomer"
        case .accelerationist: "Accelerationist"
        case .pragmatic: "Pragmatic"
        case .secretive: "Secretive"
        }
    }
}

/// How someone sounds when quoted. Quote templates are written for a voice or for its family.
enum VoiceStyle: String, Codable, CaseIterable, Sendable {
    case showman, brash, booster, evangelist, sovereign
    case measured, earnest, professor
    case terse, cryptic
    case contrarian, wry, activist
    case alarmed
    case numbers, reporter

    var family: VoiceFamily {
        switch self {
        case .showman, .brash, .booster, .evangelist, .sovereign: .bold
        case .measured, .earnest, .professor: .careful
        case .terse, .cryptic: .terse
        case .contrarian, .wry, .activist: .skeptic
        case .alarmed: .worried
        case .numbers, .reporter: .numbers
        }
    }
}

enum VoiceFamily: String, Sendable {
    case bold, careful, terse, skeptic, worried, numbers

    /// The one-letter tag quote templates use.
    var tag: Character {
        switch self {
        case .bold: "B"
        case .careful: "C"
        case .terse: "T"
        case .skeptic: "S"
        case .worried: "W"
        case .numbers: "N"
        }
    }
}

/// A dated line in someone's career.
struct CastEntry: Codable, Hashable {
    var date: Date
    var text: String
    /// Where they were after this (lab ID, "player", an organisation's name, or empty when between jobs).
    @D var org: String = ""
    @D var role: String = ""
}

/// A notable person: a lab leader, a researcher, an analyst, a reporter, an official, a critic — or one of yours.
struct CastMember: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    /// CastKind raw value (stored as text so a save from a newer build still loads).
    var kind: String
    /// Job title, e.g. "Chief executive", "Reasoning lead", "Senior analyst".
    var role: String
    /// Lab ID, "player", an organisation's name, or empty when between jobs.
    var org: String
    /// CastTrait raw values.
    var traits: [String]
    /// VoiceStyle raw value.
    var voice: String
    /// −1 closed weights … +1 open weights.
    var open: Double
    /// 0 relaxed … 1 very worried about AI risk.
    var safety: Double
    /// −1 against regulation … +1 for it.
    var regulation: Double
    /// Their account on the Pulse.
    var handle: String
    /// Where they're from, for flavour and for picking names of people they hire.
    var region: String
    /// 0–1: how often the press quotes them.
    var stature: Double
    var active: Bool = true
    /// In the current job since.
    var since: Date
    /// Newest first.
    var history: [CastEntry] = []
    /// One line about them for the people directory.
    @D var blurb: String = ""
    /// How the press introduces them, when their role and organisation don't say it well ("who chairs the Senate's AI subcommittee").
    @D var desc: String = ""
    /// The lab they most recently left.
    @D var lastLab: String = ""
    /// One of your employees, for your own people.
    @D var employeeID: String = ""
    /// What they work on ("reasoning RL", "pre-training"), for quotes and news.
    @D var focus: String = ""
    /// Scripted career beats already played (or skipped because life went another way).
    @D var beatsDone: [String] = []

    var castKind: CastKind { CastKind(rawValue: kind) ?? .researcher }
    var voiceStyle: VoiceStyle { VoiceStyle(rawValue: voice) ?? .measured }
    var castTraits: [CastTrait] { traits.compactMap(CastTrait.init(rawValue:)) }
    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

/// A post on the Pulse, the industry's chatter feed.
struct PulsePost: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    /// Cast member ID, or empty for an anonymous account.
    var author: String
    var handle: String
    /// Display name when it was posted.
    var name: String
    var text: String
    /// Labs it's about ("player" for you), for buzz.
    var labs: [String]
    /// −1 … +1 towards those labs.
    var tone: Double
    /// PulseKind raw value.
    var kind: String
    var likes: Int
    @D var reposts: Int = 0
    /// The story or rumour that set it off.
    @D var topic: String = ""
}

/// What a post is.
enum PulseKind: String, CaseIterable, Sendable {
    case hype, skeptic, joke, bench, rumor, reaction, money, policy, safety, people, ambient

    var title: String {
        switch self {
        case .hype: "Hype"
        case .skeptic: "Skeptics"
        case .joke: "Jokes"
        case .bench: "Benchmarks"
        case .rumor: "Rumours"
        case .reaction: "Reactions"
        case .money: "Money"
        case .policy: "Policy"
        case .safety: "Safety"
        case .people: "People"
        case .ambient: "Chatter"
        }
    }
}

/// How loudly and how kindly the industry has been talking about a lab over the last ~60 days.
struct LabBuzz: Codable, Hashable {
    /// 0–100.
    var attention: Double = 0
    /// −1 … +1.
    var tone: Double = 0
    var posts: Int = 0
    /// Weekly attention, oldest first (last 12 weeks).
    var trend: [Double] = []

    var label: String {
        if attention < 8 { return "Quiet" }
        let loud = attention >= 55
        switch tone {
        case 0.3...: return loud ? "Loud and glowing" : "Warm"
        case 0.08..<0.3: return loud ? "Loud, mostly positive" : "Mildly positive"
        case -0.08..<0.08: return loud ? "Loud and divided" : "Mixed"
        case -0.3 ..< -0.08: return loud ? "Loud, mostly critical" : "Cool"
        default: return loud ? "Under fire" : "Sour"
        }
    }
}

/// An anonymous account on the Pulse.
struct PulseAccount: Sendable {
    let handle: String
    let name: String
    /// insider, skeptic, joker, booster, dev, bench, finance or worried.
    let persona: String
}
