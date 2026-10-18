import Foundation

/// The business history of the rival labs, mapped from their real-world counterparts (rounds, valuations,
/// headcount) up to October 2026. After that, their finances run on the game's own economics.
enum RivalHistory {
    /// The last date covered by real data. After it, rounds, IPOs and failures are procedural.
    static let end = 2026.79

    struct Round: Sendable {
        let year: Double
        let label: String
        let amount: Double
        /// Post-money valuation (0 = unchanged).
        let post: Double
        let lead: String
        /// Already covered by a historical news event.
        var quiet = false
        var kind: RivalRound.Kind = .equity
    }

    static let rounds: [String: [Round]] = [
        // OpenAI's path: Microsoft, then the mega-rounds.
        "prometheus": [
            Round(year: 2019.55, label: "Strategic investment", amount: 1e9, post: 1e10, lead: "Microsoft", kind: .strategic),
            Round(year: 2021.05, label: "Strategic investment", amount: 2e9, post: 1.4e10, lead: "Microsoft", kind: .strategic),
            Round(year: 2023.06, label: "Multi-year partnership", amount: 1e10, post: 2.9e10, lead: "Microsoft", kind: .strategic),
            Round(year: 2023.9, label: "Employee tender", amount: 0, post: 8.6e10, lead: "Thrive Northern", kind: .tender),
            Round(year: 2024.75, label: "Convertible round", amount: 6.6e9, post: 1.57e11, lead: "Thrive Northern"),
            Round(year: 2025.25, label: "Mega-round", amount: 4e10, post: 3e11, lead: "Vision Mega Fund"),
            Round(year: 2025.8, label: "Secondary sale", amount: 0, post: 5e11, lead: "Thrive Northern", kind: .tender),
            Round(year: 2026.16, label: "Strategic round", amount: 5e10, post: 0, lead: "Amazon", quiet: true, kind: .strategic),
            Round(year: 2026.25, label: "Mega-round", amount: 7.2e10, post: 8.52e11, lead: "Andromeda Ventures", quiet: true),
            Round(year: 2026.61, label: "Employee tender", amount: 0, post: 8.52e11, lead: "the company", kind: .tender),
        ],
        // Anthropic: small Series A, then the cloud giants, then rounds that outran everyone.
        "halcyon": [
            Round(year: 2021.38, label: "Series A", amount: 1.24e8, post: 5.5e8, lead: "Founders Forge"),
            Round(year: 2022.3, label: "Series B", amount: 5.8e8, post: 4e9, lead: "Orbit Fund"),
            Round(year: 2023.4, label: "Series C", amount: 4.5e8, post: 4.1e9, lead: "Sequel Capital"),
            Round(year: 2023.74, label: "Strategic investment", amount: 1.25e9, post: 0, lead: "Amazon", kind: .strategic),
            Round(year: 2023.8, label: "Strategic investment", amount: 2e9, post: 1.84e10, lead: "Google", kind: .strategic),
            Round(year: 2024.22, label: "Strategic investment", amount: 2.75e9, post: 0, lead: "Amazon", kind: .strategic),
            Round(year: 2024.89, label: "Strategic investment", amount: 4e9, post: 4e10, lead: "Amazon", kind: .strategic),
            Round(year: 2025.17, label: "Series E", amount: 3.5e9, post: 6.15e10, lead: "Lightpath Partners"),
            Round(year: 2025.67, label: "Series F", amount: 1.3e10, post: 1.83e11, lead: "Index Peak"),
            Round(year: 2025.88, label: "Strategic investment", amount: 1.5e10, post: 0, lead: "NVIDIA", kind: .strategic),
            Round(year: 2026.12, label: "Series G", amount: 3e10, post: 3.8e11, lead: "Falcon Sovereign Fund", quiet: true),
            Round(year: 2026.31, label: "Strategic investment", amount: 1.5e10, post: 0, lead: "Amazon and Google", kind: .strategic),
            Round(year: 2026.41, label: "Series H", amount: 6.5e10, post: 9.65e11, lead: "Benchmark Hill", quiet: true),
        ],
        // xAI: three fast rounds, a merger with a social network, then its founder's rocket company.
        "xenon": [
            Round(year: 2023.91, label: "Series A", amount: 1.35e8, post: 6.7e8, lead: "Founders Forge"),
            Round(year: 2024.4, label: "Series B", amount: 6e9, post: 2.4e10, lead: "Kestrel Growth"),
            Round(year: 2024.97, label: "Series C", amount: 6e9, post: 5e10, lead: "Falcon Sovereign Fund"),
            Round(year: 2025.24, label: "Merger with a social network", amount: 0, post: 8e10, lead: "all-stock", kind: .merger),
            Round(year: 2025.5, label: "Debt and equity", amount: 1e10, post: 1.13e11, lead: "General Atlas", kind: .debt),
            Round(year: 2026.02, label: "Series E", amount: 2e10, post: 2.3e11, lead: "NVIDIA", quiet: true),
            Round(year: 2026.09, label: "Merged into its founder's rocket company", amount: 0, post: 2.5e11, lead: "all-stock", quiet: true, kind: .merger),
        ],
        // DeepSeek: funded by its quant-fund parent until its first outside round.
        "dragonlake": [
            Round(year: 2026.45, label: "First outside round", amount: 7.2e9, post: 5.5e10, lead: "Tidal Wave Capital"),
        ],
        // Mistral: Europe's champion.
        "sirocco": [
            Round(year: 2023.45, label: "Seed", amount: 1.13e8, post: 2.6e8, lead: "Lightpath Partners"),
            Round(year: 2023.94, label: "Series A", amount: 4.15e8, post: 2.2e9, lead: "Andromeda Ventures"),
            Round(year: 2024.45, label: "Series B", amount: 6.45e8, post: 6.2e9, lead: "General Atlas"),
            Round(year: 2025.68, label: "Series C", amount: 2e9, post: 1.37e10, lead: "a European chip-equipment maker", kind: .strategic),
            Round(year: 2026.18, label: "Data-centre debt", amount: 8.3e8, post: 0, lead: "a bank syndicate", kind: .debt),
            Round(year: 2026.69, label: "Series D", amount: 3.5e9, post: 2.4e10, lead: "Kestrel Growth"),
        ],
        // SSI: billions raised before shipping anything.
        "aletheia": [
            Round(year: 2024.68, label: "Series A", amount: 1e9, post: 5e9, lead: "Sequel Capital"),
            Round(year: 2025.28, label: "Series B", amount: 2e9, post: 3.2e10, lead: "Greylock Harbor"),
            Round(year: 2026.57, label: "Strategic investment", amount: 5e9, post: 0, lead: "NVIDIA", kind: .strategic),
        ],
    ]

    /// Labs that are divisions of a giant, funded by the parent's cash flow.
    static func parent(_ id: String, at y: Double) -> String? {
        switch id {
        case "deepgrove": return "its search-and-cloud parent"
        case "openweights": return "its social-media parent"
        case "xenon": return y >= 2026.09 ? "its founder's rocket company" : nil
        case "dragonlake": return y < 2026.45 ? "its quant-fund parent" : nil
        default: return nil
        }
    }

    /// Real headcount anchors (approximate) for each lab.
    static func headcount(_ id: String, at y: Double) -> Int {
        let pts: [(Double, Double)]
        switch id {
        case "prometheus": pts = [(2016, 60), (2019, 120), (2023, 750), (2024, 2_000), (2025, 3_000), (2026.7, 4_500)]
        case "deepgrove": pts = [(2016, 700), (2020, 1_200), (2023, 2_500), (2026.7, 6_000)]
        case "halcyon": pts = [(2021, 10), (2023, 300), (2024, 1_000), (2025.9, 2_300), (2026.7, 3_500)]
        case "xenon": pts = [(2023.5, 20), (2024.5, 300), (2025.5, 1_200), (2026.7, 1_200)]
        case "openweights": pts = [(2016, 300), (2023, 1_500), (2026.7, 3_000)]
        case "dragonlake": pts = [(2023.3, 60), (2025, 160), (2026.7, 250)]
        case "sirocco": pts = [(2023.3, 15), (2024, 100), (2025, 600), (2026.7, 1_000)]
        case "aletheia": pts = [(2024.4, 10), (2025, 40), (2026.7, 60)]
        default: pts = [(2016, 50)]
        }
        return Int(interpolate(pts, at: y))
    }

    /// Earliest year each independent lab would consider listing.
    static func ipoEarliest(_ id: String) -> Double {
        switch id {
        case "halcyon": 2026.85
        case "prometheus": 2027.2
        case "sirocco", "dragonlake": 2027.5
        default: 2028.0
        }
    }

    /// Valuation implied by the real rounds at year `y` (log-interpolated between them), or nil before the first.
    static func valuation(_ id: String, at y: Double) -> Double? {
        let pts = (rounds[id] ?? []).filter { $0.post > 0 }.map { ($0.year, $0.post) }
        guard let first = pts.first, y >= first.0 else { return nil }
        if y >= pts.last!.0 { return pts.last!.1 }
        return interpolateLog(pts, at: y)
    }
}
