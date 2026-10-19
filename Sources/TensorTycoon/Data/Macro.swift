import Foundation

/// Real-world anchored macro curves. x = fractional year.
enum Macro {
    /// Effective capability (log10 training FLOPs - 21, plus algorithmic gains) of the best
    /// model in the world. Anchors: GPT-2 2019, GPT-3 2020, GPT-4 2023, o-series 2024-25, 2026 frontier.
    static let frontierCurve: [(Double, Double)] = [
        (2016.5, -1.8), (2017.5, -1.0), (2018.5, -0.2), (2019.1, 0.4), (2020.4, 2.8),
        (2021.9, 3.4), (2022.3, 3.9), (2022.9, 4.4), (2023.2, 5.1), (2024.2, 5.5),
        (2024.4, 5.6), (2024.7, 5.9), (2025.2, 6.5), (2025.6, 7.0), (2025.9, 7.3),
        (2026.4, 7.75), (2026.8, 8.1), (2027.5, 8.6), (2028.5, 9.3), (2030.0, 10.2), (2035.0, 12.5),
    ]

    static func frontier(_ y: Double) -> Double { interpolate(frontierCurve, at: y, extrapolate: true) }

    /// Total annual revenue of all AI model providers (API + subscriptions + enterprise), USD.
    static let marketCurve: [(Double, Double)] = [
        (2016.5, 1.5e7), (2017.5, 2.5e7), (2018.5, 5e7), (2019.5, 1e8), (2020.5, 2e8), (2021.5, 4e8),
        (2022.5, 7e8), (2022.9, 9e8), (2023.0, 1.6e9), (2023.5, 4e9), (2024.5, 1.2e10), (2025.5, 4e10),
        (2026.5, 1.5e11), (2027.5, 3.2e11), (2028.5, 5.5e11), (2029.5, 8e11), (2030.5, 1.1e12), (2035.5, 2.6e12),
        // 3.4: growth eases after 2035 instead of compounding at 19% a year forever.
        (2040.5, 4.8e12),
    ]

    static func marketSize(_ y: Double) -> Double { interpolateLog(marketCurve, at: y, extrapolate: true) }

    /// Weekly active users of AI chat assistants worldwide (all providers).
    static let usersCurve: [(Double, Double)] = [
        (2016.5, 2e4), (2020.5, 1e5), (2022.85, 3e5), (2022.95, 2e7), (2023.1, 1e8), (2023.9, 2.2e8),
        (2024.9, 4.5e8), (2025.9, 1.1e9), (2026.5, 1.6e9), (2027.5, 2.3e9), (2028.5, 2.9e9), (2030.5, 3.8e9),
        // 3.4: saturates toward the world's internet population instead of growing without limit.
        (2033.5, 4.6e9), (2036.5, 5.1e9), (2045, 5.7e9),
    ]

    static func chatUsers(_ y: Double, chatMoment: Double?) -> Double {
        // The consumer boom starts at the "chat moment" (Nov 30 2022 by default, earlier if the player triggers it).
        let moment = chatMoment ?? 2022.91
        let shift = 2022.91 - moment
        return interpolateLog(usersCurve, at: y + max(0, min(shift, 2.0)), extrapolate: true)
    }

    /// Headline price of a frontier model, USD per 1M blended tokens.
    static let frontierPriceCurve: [(Double, Double)] = [
        (2016.5, 80), (2020.4, 60), (2022.5, 20), (2023.2, 40), (2023.9, 18), (2024.4, 8), (2025.0, 6),
        (2025.6, 4.5), (2026.0, 6), (2026.8, 6.5), (2028.0, 5), (2030.0, 4), (2035.0, 3),
    ]

    static func frontierPrice(_ y: Double) -> Double { interpolateLog(frontierPriceCurve, at: y) }

    /// Expected price for a model of capability c (cheaper the further behind the frontier).
    static func referencePrice(c: Double, y: Double) -> Double {
        frontierPrice(y) * exp(2.3 * min(0.4, c - frontier(y)))
    }

    /// Tokens an average active chat user consumes per day.
    static func tokensPerUserDay(_ y: Double) -> Double {
        interpolateLog([(2022.9, 2_500), (2024.0, 5_000), (2025.0, 9_000), (2026.0, 18_000), (2028.0, 40_000), (2032.0, 80_000)], at: y)
    }

    /// Paid seats for coding / computer-use agents across the industry.
    static func agentSeats(_ y: Double) -> Double {
        guard y >= 2024.9 else { return 0 }
        return interpolateLog([(2024.9, 1e5), (2025.5, 3e6), (2026.0, 8e6), (2026.8, 2e7), (2028.0, 6e7), (2030.0, 1.5e8), (2035, 4e8), (2040, 6e8)], at: y, extrapolate: true)
    }

    /// Tokens an agent seat burns per day (agents read whole codebases and loop for hours).
    static func tokensPerSeatDay(_ y: Double) -> Double {
        interpolateLog([(2025.0, 4e5), (2026.0, 1e6), (2027.0, 2e6), (2030.0, 5e6)], at: y)
    }

    /// Share of total market that is consumer subscriptions vs API vs enterprise.
    static func segmentSplit(_ y: Double, chatMoment: Bool) -> (consumer: Double, api: Double, enterprise: Double) {
        if !chatMoment { return (0.05, 0.45, 0.50) }
        let consumer = interpolate([(2022.9, 0.35), (2024.0, 0.45), (2026.0, 0.35), (2030.0, 0.30)], at: y)
        let enterprise = interpolate([(2022.9, 0.2), (2024.0, 0.15), (2026.0, 0.2), (2030.0, 0.25)], at: y)
        return (consumer, 1 - consumer - enterprise, enterprise)
    }

    /// US effective federal funds rate (monthly average, approximate), percent.
    static let fedFunds: [(Double, Double)] = [
        (2016.5, 0.38), (2017.0, 0.66), (2017.45, 1.04), (2017.95, 1.30), (2018.2, 1.51), (2018.45, 1.82), (2018.7, 2.13),
        (2018.95, 2.40), (2019.5, 2.40), (2019.6, 2.13), (2019.75, 1.83), (2019.95, 1.55), (2020.15, 1.58), (2020.2, 0.65),
        (2020.3, 0.05), (2021.95, 0.08), (2022.2, 0.33), (2022.45, 1.21), (2022.7, 3.08), (2022.95, 4.10), (2023.2, 4.65),
        (2023.55, 5.33), (2024.65, 5.33), (2024.7, 5.13), (2024.85, 4.64), (2024.95, 4.48), (2025.65, 4.33), (2025.7, 4.22),
        (2025.8, 4.09), (2025.9, 3.88), (2025.95, 3.64), (2026.5, 3.55), (2026.8, 3.40),
    ]

    static func historicalRate(_ y: Double) -> Double? {
        y <= 2026.8 ? interpolate(fedFunds, at: y) : nil
    }

    /// Market salary (USD/yr, total comp) for a role at a skill of 50.
    static func salary(_ role: Role, _ y: Double) -> Double {
        let pts: [(Double, Double)]
        switch role {
        case .researcher: pts = [(2016, 200_000), (2019, 300_000), (2022, 450_000), (2024, 800_000), (2026, 1_300_000), (2030, 2_000_000)]
        case .mlEngineer: pts = [(2016, 180_000), (2019, 240_000), (2022, 330_000), (2024, 450_000), (2026, 650_000), (2030, 900_000)]
        case .infra: pts = [(2016, 170_000), (2019, 220_000), (2022, 280_000), (2024, 350_000), (2026, 450_000), (2030, 600_000)]
        case .data: pts = [(2016, 150_000), (2019, 190_000), (2022, 240_000), (2024, 290_000), (2026, 360_000), (2030, 450_000)]
        case .sales: pts = [(2016, 140_000), (2019, 170_000), (2022, 210_000), (2024, 250_000), (2026, 300_000), (2030, 380_000)]
        case .safety: pts = [(2016, 160_000), (2019, 220_000), (2022, 330_000), (2024, 500_000), (2026, 800_000), (2030, 1_100_000)]
        case .chipDesigner: pts = [(2016, 190_000), (2020, 240_000), (2023, 320_000), (2026, 420_000), (2030, 520_000)]
        }
        return interpolate(pts, at: y, extrapolate: true)
    }

    /// Valuation of a frontier-level lab (sets the scale for the "hype" valuation).
    static let frontierLabValuation: [(Double, Double)] = [
        (2016.5, 1e9), (2019.0, 1e9), (2019.5, 1.5e9), (2021.0, 1.4e10), (2023.0, 2.9e10), (2023.3, 8.6e10),
        (2024.8, 1.57e11), (2025.2, 3e11), (2025.8, 5e11), (2026.5, 8.5e11), (2028.0, 1.5e12), (2030.0, 2.5e12),
        // 3.4: after 2030 a frontier lab's worth grows with the AI market (~19% a year), not 29% a year.
        (2035.0, 6e12),
    ]

    static func frontierValuation(_ y: Double) -> Double { interpolateLog(frontierLabValuation, at: y, extrapolate: true) }

    /// EV / forward revenue multiple investors pay for AI labs.
    static func revenueMultiple(_ y: Double) -> Double {
        // 3.4: multiples keep easing after 2030 as the industry matures (18× → 12× by 2036).
        interpolate([(2016, 12), (2021.5, 20), (2022.9, 25), (2023.5, 40), (2025.0, 35), (2026.5, 30), (2030, 18), (2036, 12)], at: y)
    }

    /// Seed-stage valuation for a credible team with no product.
    static func seedValuation(_ y: Double) -> Double {
        interpolate([(2016, 1.2e7), (2020, 2e7), (2023, 5e7), (2025, 1e8), (2026.5, 1.5e8), (2030, 2e8)], at: y)
    }

    /// Typical hardware depreciation per year once a successor ships.
    static let depreciationPerYear = 0.22
}

enum Difficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy = "Founder Mode"
    case normal = "Realistic"
    case hard = "Bubble Bursts"

    var id: String { rawValue }

    var cashMultiplier: Double {
        switch self {
        case .easy: 2.0
        case .normal: 1.0
        case .hard: 0.6
        }
    }

    var demandMultiplier: Double {
        switch self {
        case .easy: 1.35
        case .normal: 1.0
        case .hard: 0.8
        }
    }

    var competitorBoost: Double {
        switch self {
        case .easy: -0.15
        case .normal: 0
        case .hard: 0.12
        }
    }

    /// How much of a lead you've held for a training cycle rival labs answer with their next runs.
    var rivalResponse: Double {
        switch self {
        case .easy: 0.6
        case .normal: 0.85
        case .hard: 1.0
        }
    }

    var blurb: String {
        switch self {
        case .easy: "Double the starting cash, generous customers, slower rivals."
        case .normal: "Calibrated to the real industry. Compute is expensive and rivals are relentless."
        case .hard: "Thin margins, picky customers, rivals a step ahead and more bad news."
        }
    }
}

struct Era: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let start: Date
    let cash: Double
    let image: String
    let blurb: String

    static let all: [Era] = [
        Era(id: "2017", title: "Attention Is All You Need", subtitle: "July 2017",
            start: GameCalendar.date(2017, 7, 3), cash: 3_000_000, image: "p100_die",
            blurb: "The Transformer paper just dropped. V100s are brand new, TPU v2 is coming. Nobody knows that scale is all you need — yet."),
        Era(id: "2020", title: "The Scaling Era", subtitle: "June 2020",
            start: GameCalendar.date(2020, 6, 1), cash: 8_000_000, image: "hpc_summit",
            blurb: "A100s are shipping and a 175B-parameter model is about to stun the world. Rates are near zero and VCs are hungry."),
        Era(id: "2022", title: "The ChatGPT Moment", subtitle: "September 2022",
            start: GameCalendar.date(2022, 9, 1), cash: 15_000_000, image: "h100_stack",
            blurb: "H100s are about to ship. In three months a chatbot will reach 100M users. Will it be yours?"),
        Era(id: "2026", title: "The Gigawatt Race", subtitle: "October 2026",
            start: GameCalendar.date(2026, 10, 15), cash: 40_000_000, image: "hgx_b200",
            blurb: "Today. Rubin is shipping, TPU 8t/8i are imminent and labs measure clusters in gigawatts. Find your niche or out-build the giants."),
    ]
}
