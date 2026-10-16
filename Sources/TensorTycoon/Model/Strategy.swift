import Foundation

/// What the board is asking for: a measurable goal with a deadline and a reward.
enum ObjectiveKind: String, Codable, CaseIterable, Sendable {
    case revenue, index, rank, users, valuation, profit, compute, safety, research, agents, release, chipSales

    var symbol: String {
        switch self {
        case .revenue: "chart.line.uptrend.xyaxis"
        case .index: "trophy.fill"
        case .rank: "medal.fill"
        case .users: "person.2.fill"
        case .valuation: "building.columns.fill"
        case .profit: "plus.forwardslash.minus"
        case .compute: "cpu.fill"
        case .safety: "checkmark.shield.fill"
        case .research: "lightbulb.fill"
        case .agents: "person.3.sequence.fill"
        case .release: "shippingbox.fill"
        case .chipSales: "shippingbox.and.arrow.backward.fill"
        }
    }
}

struct Objective: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: ObjectiveKind
    var title: String
    var detail: String
    var start: Double
    var target: Double
    var issued: Date
    var deadline: Date
    var rewardCash: Double
    var rewardPoints: Int
    var rewardConfidence: Double
    var done = false
    var failed = false
    var progress: Double = 0
}
