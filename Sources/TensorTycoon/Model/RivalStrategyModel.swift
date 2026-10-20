import Foundation

/// The strategy a rival lab is running. Labs pick one by reading their own situation — how far behind they are,
/// whether they're losing share, how long their cash lasts, whether you're pulling ahead — and their character.
enum RivalPlay: String, Codable, CaseIterable, Sendable {
    case race
    case priceWar
    case enterprise
    case openGambit
    case talentRaid
    case lobby
    case efficiency
    case consumer
    case agents
    case alliance

    var title: String {
        switch self {
        case .race: "Racing for the frontier"
        case .priceWar: "Price war"
        case .enterprise: "Enterprise push"
        case .openGambit: "Open-weights gambit"
        case .talentRaid: "Talent raid"
        case .lobby: "Regulatory moat"
        case .efficiency: "Efficiency drive"
        case .consumer: "Consumer blitz"
        case .agents: "Agent push"
        case .alliance: "Hyperscaler alliance"
        }
    }

    var symbol: String {
        switch self {
        case .race: "flag.checkered"
        case .priceWar: "tag.slash.fill"
        case .enterprise: "building.2.fill"
        case .openGambit: "lock.open.fill"
        case .talentRaid: "person.2.badge.key.fill"
        case .lobby: "building.columns.fill"
        case .efficiency: "scissors"
        case .consumer: "iphone.gen3"
        case .agents: "person.3.sequence.fill"
        case .alliance: "link.circle.fill"
        }
    }

    /// What it does to you, in one line.
    var effect: String {
        switch self {
        case .race: "Spends heavily on compute: its next models get bigger and arrive at full strength."
        case .priceWar: "Cuts API prices hard to win share; token prices across the market fall."
        case .enterprise: "Sales army and service guarantees: wins more enterprise contracts, fewer leads for you."
        case .openGambit: "Gives away a strong open-weights model to commoditise whoever leads."
        case .talentRaid: "Goes after your best researchers with eight-figure offers."
        case .lobby: "Backs rules that suit it in Washington."
        case .efficiency: "Cuts costs and raises prices to stretch its runway; falls behind on compute."
        case .consumer: "Pours money into its chat app and brand."
        case .agents: "Bets the company on agent products; stronger in the agent market."
        case .alliance: "Signs a compute-for-equity deal with a cloud giant: fresh cash and more compute."
        }
    }

    /// How much the play changes the market for you (shown as a threat level).
    var threat: Int {
        switch self {
        case .priceWar, .talentRaid, .openGambit: 2
        case .race, .enterprise, .consumer, .agents, .alliance, .lobby: 1
        case .efficiency: 0
        }
    }
}

/// 3.8: the parts of a rival lab's books 3.3 didn't keep. Parents and states budget a year at a time and can cut it in
/// a downturn; R&D spend buys proprietary techniques over time.
struct RivalBook: Codable, Hashable {
    /// What the parent (or state) still has for its AI lab this budget year, the year it was set, and its full size.
    @D var parentBudget: Double = 0
    @D var budgetYear: Int = 0
    @D var annualBudget: Double = 0
    /// A downturn at the parent cuts the lab's budget until this date.
    @D var squeezeUntil: Date? = nil
    /// Everything the parent has put in.
    @D var parentPaid: Double = 0
    /// R&D spend since the lab's last proprietary technique, and how many it has bought.
    @D var rdPool: Double = 0
    @D var techniques: Int = 0
    /// The lab's own silicon (hardware specialists): H100e sold to other labs last month.
    @D var chipsSold: Double = 0
}
