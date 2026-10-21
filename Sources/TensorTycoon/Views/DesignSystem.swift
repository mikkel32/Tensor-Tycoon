import SwiftUI

// MARK: - Design tokens
//
// One place for the numbers every screen shares: spacing, corner radii, the type ramp, semantic colours and number
// formatting. Components (Components.swift) are built from these; screens should reach for a component first and a
// token second, and only then for a literal.

extension Theme {
    /// The spacing scale. Cards sit `gap` apart, sections `section` apart; inside a card rows use `s`–`m`.
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Between cards in a grid or column.
    static let gap: CGFloat = Space.l
    /// Between dashboard sections and other page-level groups.
    static let sectionGap: CGFloat = 28
    /// Inside a card.
    static let cardPadding: CGFloat = Space.l
    /// Around a page.
    static let pagePadding: CGFloat = Space.xl
    /// Pages stop growing here and centre on very wide windows.
    static let pageMaxWidth: CGFloat = 1500
    /// Long explanatory text stops here so lines stay readable on wide windows.
    static let readableWidth: CGFloat = 860

    /// Corner radii, from a chip to a hero photo.
    enum Radius {
        static let chip: CGFloat = 6
        static let control: CGFloat = 8
        static let inset: CGFloat = 10
        static let tile: CGFloat = 14
        static let card: CGFloat = 16
        static let hero: CGFloat = 20
    }

    // Semantic colours. System colours adapt to light and dark mode; never encode meaning by colour alone — pair
    // these with a symbol or a word (`Tone`, `ToneLabel`, `Pill(text:tone:)`).
    static let good = Color.green
    static let bad = Color.red
    static let warning = Color.orange
    static let info = Color.blue
    static let neutral = Color.secondary
    static let accent = Color.accentColor

    /// A faint fill for inset panels inside a card (adapts to light and dark mode, unlike white or black at low opacity).
    static let insetFill = Color.primary.opacity(0.05)
    /// A faint outline for inset panels and unselected choices.
    static let hairline = Color.primary.opacity(0.12)

    /// Adaptive grid columns: as many as fit at `min` points wide. Works from a 1100pt window to a wide display.
    static func columns(min: CGFloat, spacing: CGFloat = Theme.gap) -> [GridItem] {
        [GridItem(.adaptive(minimum: min), spacing: spacing, alignment: .top)]
    }

    /// KPI tiles: four across on a normal window, two on a narrow one.
    static let tileColumns = columns(min: 180, spacing: Space.m)
    /// Cards in a grid: two across at 1100pt, three or four on a wide display.
    static let cardColumns = columns(min: 360)
    /// Compact cards (people, chips, listings).
    static let compactCardColumns = columns(min: 280)
}

/// The type ramp. Use these rather than ad-hoc sizes so pages read as one product.
enum TypeRamp {
    /// Page titles.
    static let pageTitle = Font.largeTitle.weight(.bold)
    /// Dashboard sections and other page-level groups.
    static let sectionTitle = Font.title3.weight(.semibold)
    /// Card titles.
    static let cardTitle = Font.headline
    /// Running text in cards.
    static let body = Font.callout
    /// Secondary lines, captions and explanations.
    static let caption = Font.caption
    /// Tiny labels under numbers.
    static let micro = Font.caption2
    /// A tile's label.
    static let label = Font.caption.weight(.medium)
    /// The one verdict number a screen is about (a forecast, a rank, a rating).
    static let display = Font.system(size: 40, weight: .bold).monospacedDigit()
    /// A headline number on a hero banner or a card's top-right corner.
    static let bannerMetric = Font.system(size: 30, weight: .bold).monospacedDigit()
    /// The big number on a page (a hero stat, a verdict).
    static let heroMetric = Font.title.weight(.bold).monospacedDigit()
    /// The number on a KPI tile.
    static let metric = Font.title2.weight(.semibold).monospacedDigit()
    /// The number on a compact stat.
    static let metricSmall = Font.headline.monospacedDigit()
    /// Numbers in tables and key-value rows: monospaced digits so columns line up.
    static let tableNumber = Font.callout.monospacedDigit()
    /// Small numbers in captions.
    static let captionNumber = Font.caption.monospacedDigit()
}

// MARK: - Tone

/// What a value means for the player. Every tone has a colour, a symbol and a word, so meaning never rests on colour
/// alone (colour-blind players and VoiceOver get the symbol and the word).
enum Tone: Hashable, Sendable {
    case good, bad, warning, info, neutral, accent

    var color: Color {
        switch self {
        case .good: Theme.good
        case .bad: Theme.bad
        case .warning: Theme.warning
        case .info: Theme.info
        case .neutral: Theme.neutral
        case .accent: Theme.accent
        }
    }

    var symbol: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .bad: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .neutral: "circle"
        case .accent: "star.circle.fill"
        }
    }

    /// For VoiceOver and tooltips.
    var word: String {
        switch self {
        case .good: "Good"
        case .bad: "Problem"
        case .warning: "Warning"
        case .info: "Note"
        case .neutral: "Neutral"
        case .accent: "Highlight"
        }
    }

    /// Good when positive, bad when negative.
    static func sign(_ v: Double, zero: Tone = .neutral) -> Tone { v > 0 ? .good : (v < 0 ? .bad : zero) }

    /// Higher is better: good at or above `good`, a warning at or above `warning`, bad below.
    static func level(_ v: Double, good: Double, warning: Double) -> Tone { v >= good ? .good : (v >= warning ? .warning : .bad) }

    /// Lower is better (risk, failure odds): good at or below `good`, a warning up to `warning`, bad above.
    static func risk(_ v: Double, good: Double, warning: Double) -> Tone { v <= good ? .good : (v <= warning ? .warning : .bad) }
}

// MARK: - Number formatting

/// View-side additions to `Fmt`: signed values with a true minus sign, so gains and losses line up and read the same
/// on every screen.
extension Fmt {
    /// "+$1.2M" / "−$450K".
    static func signedMoney(_ v: Double, decimals: Int = 1) -> String {
        (v < 0 ? "−" : "+") + money(abs(v), decimals: decimals)
    }

    /// "+12%" / "−3.5%" from a fraction.
    static func signedPct(_ v: Double, decimals: Int = 0) -> String {
        (v < 0 ? "−" : "+") + pct(abs(v), decimals: decimals)
    }

    /// "+1.5" / "−2" with trailing zeros trimmed.
    static func signed(_ v: Double, _ decimals: Int = 1) -> String {
        (v < 0 ? "−" : "+") + trim(abs(v), decimals)
    }

    /// A probability as a whole percentage: "62%".
    static func odds(_ p: Double) -> String { "\(Int((clamp(p, 0, 1) * 100).rounded()))%" }
}

// MARK: - Screen help

extension Screen {
    /// The glossary term closest to what the screen is about, for the page header's "?".
    var helpTerm: GlossaryTerm? {
        switch self {
        case .dashboard: .chiefOfStaff
        case .operations: .delegates
        case .strategy: .board
        case .security: .securityLevels
        case .lab: .forecast
        case .training: .goodput
        case .models: .servingCapacity
        case .leaderboard: .intelligenceIndex
        case .rivals, .rivalWatch, .competitors: .forecastBand
        case .benchmarks: .saturation
        case .rsi: .rsi
        case .swarms: .swarms
        case .xeno: .alienTech
        case .hardware: .reservedCloud
        case .partners: .cloudCredits
        case .compute, .datacenters, .silicon: .h100e
        case .research: .researchPoints
        case .data: .effectiveCompute
        case .market: .brand
        case .industry: .marketCorrection
        case .chipSales: .leasing
        case .finance: .runway
        case .funding: .dilution
        case .corporate: .valuation
        case .world: .stakeholders
        case .nations: .regulation
        case .milestones: .milestones
        case .products: .productLines
        case .pulse: .pulse
        case .families: .distillation
        case .government: .politicalCapital   // 3.9
        case .team, .news, .achievements, .credits, .help, .events, .advancedProjects, .semiconductors, .science, .progression: nil
        case .govContracts: nil   // 3.9
        }
    }
}
