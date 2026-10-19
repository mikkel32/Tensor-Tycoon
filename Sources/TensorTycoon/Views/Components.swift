import SwiftUI

/// Colours tied to the game's content (logos, vendors, news categories, roles). The design tokens — spacing, radii, the
/// type ramp, semantic colours and grid columns — live in DesignSystem.swift.
enum Theme {
    static let logoColors: [Color] = [.indigo, .blue, .teal, .green, .orange, .pink, .purple, .red, .mint, .cyan]
    static let accentGradient = LinearGradient(colors: [Color(red: 0.42, green: 0.36, blue: 1.0), Color(red: 0.0, green: 0.78, blue: 0.95)],
                                               startPoint: .leading, endPoint: .trailing)
    static let positive = good
    static let negative = bad
    static let corner: CGFloat = Radius.card

    static func logoColor(_ i: Int) -> Color { logoColors[abs(i) % logoColors.count] }

    static func competitorColor(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    static func vendorColor(_ v: Vendor) -> Color {
        switch v {
        case .nvidia: Color(red: 0.46, green: 0.73, blue: 0.0)
        case .google: Color(red: 0.26, green: 0.52, blue: 0.96)
        case .amd: Color(red: 0.93, green: 0.11, blue: 0.14)
        case .intel: Color(red: 0.0, green: 0.44, blue: 0.77)
        case .aws: Color(red: 1.0, green: 0.6, blue: 0.0)
        case .microsoft: Color(red: 0.0, green: 0.64, blue: 0.94)
        case .apple: .gray
        case .cerebras: Color(red: 0.95, green: 0.36, blue: 0.1)
        case .groq: Color(red: 0.96, green: 0.31, blue: 0.21)
        case .tesla: Color(red: 0.8, green: 0.0, blue: 0.0)
        case .huawei: Color(red: 0.8, green: 0.05, blue: 0.1)
        case .qualcomm: Color(red: 0.2, green: 0.38, blue: 0.89)
        case .tenstorrent: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .custom: .purple
        }
    }

    static func categoryColor(_ c: NewsCategory) -> Color {
        switch c {
        case .company: .indigo
        case .hardware: .green
        case .competitor: .orange
        case .market: .teal
        case .finance: .yellow
        case .policy: .purple
        case .research: .pink
        }
    }

    static func roleColor(_ r: Role) -> Color {
        switch r {
        case .researcher: .purple
        case .mlEngineer: .blue
        case .infra: .teal
        case .data: .orange
        case .sales: .green
        case .safety: .pink
        case .chipDesigner: .indigo
        }
    }
}

// MARK: - Containers

/// The standard surface: every block of content on a page sits in one.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

/// A card's title row: symbol, title, an optional subtitle, and trailing controls (a "?" and a link to the screen).
struct CardHeader<Trailing: View>: View {
    let title: String
    var symbol: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(title).font(TypeRamp.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle { Text(subtitle).font(TypeRamp.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: Theme.Space.s)
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

/// A page-level group heading (the dashboard's Needs you / Race / Business / Programmes): bigger than a card title,
/// with a hairline under it.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var symbol: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
                Text(title).font(TypeRamp.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(TypeRamp.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: Theme.Space.s)
                trailing
            }
            Divider()
        }
        .padding(.top, Theme.Space.xs)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

/// Standard scrolling page: a header (the screen's symbol, title, subtitle and a "?" that explains the screen), then
/// the content. Pass `screen` so the header gets its symbol and help.
struct Page<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var screen: Screen? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: title, subtitle: subtitle, screen: screen)
                content
            }
            .padding(Theme.pagePadding)
            .frame(maxWidth: Theme.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollContentBackground(.hidden)
        .background(PageBackground())
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String?
    let screen: Screen?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let screen {
                Image(systemName: screen.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Theme.accentGradient, in: .rect(cornerRadius: Theme.Radius.tile))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(title).font(TypeRamp.pageTitle)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: Theme.readableWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let screen { ScreenHelpButton(screen: screen) }
        }
    }
}

/// The page header's "?": what the screen is for, the first useful thing to do and its key term.
struct ScreenHelpButton: View {
    let screen: Screen
    @State private var shown = false

    var body: some View {
        Button {
            shown.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("About \(screen.title)")
        .accessibilityLabel("About \(screen.title)")
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            ScreenAboutPopover(screen: screen) { shown = false }
        }
    }
}

struct ScreenAboutPopover: View {
    @Environment(GameStore.self) private var store
    @AppStorage(HintStore.seenKey) private var seen = ""
    @AppStorage(HintStore.enabledKey) private var enabled = true
    let screen: Screen
    let close: () -> Void

    var body: some View {
        let hint = ScreenGuide.hint(for: screen)
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Label(screen.title, systemImage: screen.symbol).font(.headline)
            if let hint {
                Text(hint.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                Label(hint.firstStep, systemImage: "arrow.right.circle.fill")
                    .font(.caption.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let term = screen.helpTerm {
                Divider()
                Text("Key term: \(term.title)").font(.caption.weight(.semibold))
                Text(term.definition).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack(spacing: Theme.Space.m) {
                if hint != nil, enabled, HintStore.screens(in: seen).contains(screen.rawValue) {
                    Button("Show this screen's hint again") { seen = HintStore.removing(screen, from: seen) }
                        .buttonStyle(.link)
                }
                Spacer(minLength: 0)
                Button("Help & Glossary") {
                    close()
                    if let term = screen.helpTerm { HelpRouter.shared.show(term, in: store) } else { store.open(.help) }
                }
                .buttonStyle(.link)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 360)
    }
}

struct PageBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [Color.indigo.opacity(0.10), .clear], startPoint: .top, endPoint: .center)
                .frame(height: 420)
        }
        .ignoresSafeArea()
    }
}

/// Wide photo banner with a gradient and overlay text. Hovering it names what the photo shows and who took it.
/// `illustrative: true` marks a photo standing in for something it doesn't show (the player's own office or site,
/// a fictional facility) with the "Illustrative photo" pill, top-trailing so it never covers the overlay text.
struct HeroBanner<Overlay: View>: View {
    let image: String
    var height: CGFloat = 190
    var illustrative = false
    @ViewBuilder var overlay: Overlay

    private var credit: String { ImageLibrary.tooltip(image, illustrative: illustrative) }

    var body: some View {
        Photo(key: image, thumb: false)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.2), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
            }
            .overlay {
                // A bottom scrim keeps stats on the trailing side readable over bright photos too.
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                overlay
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                    .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                if illustrative {
                    PhotoPill(text: "Illustrative photo", symbol: "photo")
                        .padding(10)
                        .accessibilityLabel("Illustrative photo, not the actual place")
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.hero))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.hero).strokeBorder(.white.opacity(0.08)))
            .help(credit)
    }
}

// MARK: - Grids

/// Equal-width columns: as many as fit at `minWidth`, at most `maxColumns`, and never more than there are items — so
/// four KPI tiles span the full width on a wide window and wrap two by two on a narrow one, with no empty slots.
/// Rows take the height of their tallest item.
struct EqualColumns: Layout {
    var minWidth: CGFloat
    var spacing: CGFloat = Theme.gap
    var maxColumns: Int = 6

    private func columns(_ width: CGFloat, _ count: Int) -> Int {
        guard count > 0 else { return 1 }
        let fit = Int(((width + spacing) / (minWidth + spacing)).rounded(.down))
        return max(1, min(fit, maxColumns, count))
    }

    private func layout(_ width: CGFloat, _ subviews: Subviews) -> (cols: Int, colWidth: CGFloat, rows: [CGFloat]) {
        let cols = columns(width, subviews.count)
        let colWidth = max(0, (width - spacing * CGFloat(cols - 1)) / CGFloat(cols))
        var rows: [CGFloat] = []
        var i = 0
        while i < subviews.count {
            var h: CGFloat = 0
            for j in i..<min(i + cols, subviews.count) {
                h = max(h, subviews[j].sizeThatFits(ProposedViewSize(width: colWidth, height: nil)).height)
            }
            rows.append(h)
            i += cols
        }
        return (cols, colWidth, rows)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = max(0, CGFloat(min(subviews.count, maxColumns)) * (minWidth + spacing) - spacing)
        let proposed = proposal.width ?? ideal
        let width = proposed.isFinite ? proposed : ideal
        let l = layout(width, subviews)
        let height = l.rows.reduce(0, +) + spacing * CGFloat(max(0, l.rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let l = layout(bounds.width, subviews)
        var y = bounds.minY
        for (r, h) in l.rows.enumerated() {
            for c in 0..<l.cols {
                let i = r * l.cols + c
                guard i < subviews.count else { break }
                subviews[i].place(at: CGPoint(x: bounds.minX + CGFloat(c) * (l.colWidth + spacing), y: y), anchor: .topLeading,
                                  proposal: ProposedViewSize(width: l.colWidth, height: h))
            }
            y += h + spacing
        }
    }
}

/// A row of KPI tiles (`StatTile`) that wraps on narrow windows instead of squeezing.
struct KPIRow<Content: View>: View {
    var minWidth: CGFloat = 180
    @ViewBuilder var content: Content

    var body: some View {
        EqualColumns(minWidth: minWidth, spacing: Theme.Space.m, maxColumns: 6) { content }
    }
}

/// Cards side by side: two at 1100pt, three on a wide display (or `maxColumns`), one when the window is narrow.
struct CardGrid<Content: View>: View {
    var minWidth: CGFloat = 360
    var maxColumns: Int = 3
    @ViewBuilder var content: Content

    var body: some View {
        EqualColumns(minWidth: minWidth, spacing: Theme.gap, maxColumns: maxColumns) { content }
    }
}

// MARK: - Numbers

/// A headline number: symbol, label, the value in monospaced digits, an optional trend arrow and a detail line.
struct StatTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var symbol: String
    var tint: Color = .accentColor
    var trend: Double? = nil
    var help: GlossaryTerm? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(tint.gradient, in: .rect(cornerRadius: Theme.Radius.chip))
                    .accessibilityHidden(true)
                Text(title).font(TypeRamp.label).foregroundStyle(.secondary).lineLimit(1)
                if let help { HelpButton(term: help) }
                Spacer(minLength: 0)
                if let trend {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(trend >= 0 ? Theme.good : Theme.bad)
                        .accessibilityLabel(trend >= 0 ? "Trending up" : "Trending down")
                }
            }
            Text(value)
                .font(TypeRamp.metric)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            if let detail {
                Text(detail).font(TypeRamp.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tile).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
        .accessibilityElement(children: help == nil ? .combine : .contain)
    }
}

/// A compact number inside a card. `.boxed` (label over value on an inset panel), `.tinted` (icon, value, label on a
/// tinted panel) or `.plain` (value over label, no panel). Replaces the per-screen LineStat/OrgStat/RSIStat/… copies.
struct MetricTile: View {
    enum Style { case boxed, tinted, plain }

    let label: String
    let value: String
    var symbol: String? = nil
    var tint: Color = .primary
    var style: Style = .boxed

    var body: some View {
        Group {
            switch style {
            case .boxed:
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    if let symbol {
                        Label(label, systemImage: symbol).font(TypeRamp.caption).foregroundStyle(.secondary).lineLimit(1)
                    } else {
                        Text(label).font(TypeRamp.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text(value).font(TypeRamp.metricSmall).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
            case .tinted:
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    if let symbol { Image(systemName: symbol).font(.caption).foregroundStyle(tint).accessibilityHidden(true) }
                    Text(value).font(TypeRamp.metricSmall).lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(label).font(TypeRamp.micro).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.inset))
            case .plain:
                HStack(spacing: Theme.Space.s) {
                    if let symbol { Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 18).accessibilityHidden(true) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(value).font(.callout.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
                        Text(label).font(TypeRamp.micro).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A label and its value on one line; numbers in monospaced digits so a column of rows lines up. `tone` colours the
/// value and adds its symbol; `help` adds a "?".
struct SpecRow: View {
    let label: String
    let value: String
    var estimated = false
    var tone: Tone? = nil
    var help: GlossaryTerm? = nil

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Text(label).foregroundStyle(.secondary)
            if let help { HelpButton(term: help) }
            Spacer(minLength: Theme.Space.s)
            if let tone, tone != .neutral {
                Image(systemName: tone.symbol).font(.caption).foregroundStyle(tone.color).accessibilityLabel(tone.word)
            }
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
                .foregroundStyle(tone.map { $0 == .neutral ? Color.primary : $0.color } ?? Color.primary)
            if estimated {
                Text("est.").font(.caption2).foregroundStyle(Theme.warning)
            }
        }
        .font(TypeRamp.body)
    }
}

/// The design system's name for `SpecRow`.
typealias KeyValueRow = SpecRow

// MARK: - Labels and badges

struct Pill: View {
    let text: String
    var color: Color = .secondary
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.14), in: .capsule)
    }
}

extension Pill {
    /// A status pill whose meaning is carried by its symbol and word as well as its colour.
    init(_ text: String, tone: Tone) {
        self.text = text
        self.color = tone.color
        self.symbol = tone == .neutral ? nil : tone.symbol
    }
}

/// Coloured text with the tone's symbol in front, for verdicts like "Win odds 62%" or "Over budget".
struct ToneLabel: View {
    let text: String
    let tone: Tone
    var font: Font = .callout.weight(.semibold)

    var body: some View {
        Label(text, systemImage: tone.symbol)
            .font(font)
            .foregroundStyle(tone.color)
    }
}

/// A coloured dot (or dash) and a label, for chart legends.
struct LegendItem: View {
    let color: Color
    let label: String
    var value: String? = nil
    var dashed = false

    var body: some View {
        HStack(spacing: 5) {
            if dashed {
                Capsule().fill(color).frame(width: 12, height: 2.5).accessibilityHidden(true)
            } else {
                Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
            }
            Text(label).lineLimit(1)
            if let value { Text(value).monospacedDigit().foregroundStyle(.secondary) }
        }
        .font(.caption)
    }
}

// MARK: - Bars and progress

struct Meter: View {
    let value: Double
    var tint: Color = .accentColor
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(tint.gradient)
                    .frame(width: max(height, geo.size.width * clamp(value, 0, 1)))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.smooth, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Fmt.odds(value))
    }
}

/// A probability: a bar coloured by how good the odds are, the percentage, and a word ("Likely", "Long shot") with a
/// symbol so the meaning doesn't rest on colour. `risk` flips it for failure odds, where lower is better.
struct OddsBar: View {
    let probability: Double
    var label: String? = nil
    var risk = false
    /// Tone thresholds: at or above `good` is good, at or above `warning` a warning (reversed for `risk`).
    var good: Double? = nil
    var warning: Double? = nil

    var body: some View {
        let p = clamp(probability, 0, 1)
        let tone = risk ? Tone.risk(p, good: good ?? 0.15, warning: warning ?? 0.35)
                        : Tone.level(p, good: good ?? 0.6, warning: warning ?? 0.3)
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: 6) {
                if let label { Text(label).font(TypeRamp.caption).foregroundStyle(.secondary).lineLimit(1) }
                Spacer(minLength: Theme.Space.xs)
                Image(systemName: tone.symbol).font(.caption).foregroundStyle(tone.color).accessibilityHidden(true)
                Text(Fmt.odds(p)).font(.callout.weight(.semibold).monospacedDigit()).foregroundStyle(tone.color)
                Text(word(p)).font(TypeRamp.caption).foregroundStyle(.secondary)
            }
            Meter(value: p, tint: tone.color, height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? (risk ? "Risk" : "Odds"))
        .accessibilityValue("\(Fmt.odds(p)), \(word(p))")
    }

    private func word(_ p: Double) -> String {
        if risk {
            return p <= (good ?? 0.15) ? "low risk" : (p <= (warning ?? 0.35) ? "some risk" : "high risk")
        }
        switch p {
        case 0.85...: return "near certain"
        case 0.6...: return "likely"
        case 0.4...: return "even"
        case 0.2...: return "unlikely"
        default: return "long shot"
        }
    }
}

/// One step of a `StageStrip`.
struct StageStep: Identifiable {
    enum Status { case done, current, upcoming, failed, blocked }

    let id: String
    let title: String
    var status: Status
    /// How far through the current step (0–1); nil draws it half full.
    var progress: Double? = nil
    /// A short badge under the title (reruns, a date).
    var note: String? = nil
    /// Tooltip.
    var help: String? = nil
}

/// A horizontal pipeline of stages (a programme's phases, a science project's trials). Each stage shows a bar and a
/// symbol for its status — done, under way, upcoming, failed or blocked — so it reads without colour.
struct StageStrip: View {
    let steps: [StageStep]
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.xs) {
            ForEach(steps) { st in
                VStack(spacing: 3) {
                    Meter(value: fill(st), tint: color(st), height: 6)
                    HStack(spacing: 3) {
                        Image(systemName: symbol(st.status)).font(.system(size: 9, weight: .bold)).foregroundStyle(color(st))
                            .accessibilityHidden(true)
                        Text(st.title)
                            .font(.caption2.weight(st.status == .current ? .bold : .regular))
                            .foregroundStyle(st.status == .current ? .primary : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    if let note = st.note {
                        Text(note).font(.caption2.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.warning)
                    }
                }
                .frame(maxWidth: .infinity)
                .help(st.help ?? st.title)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(st.title): \(word(st.status))\(st.note.map { ", \($0)" } ?? "")")
            }
        }
    }

    private func fill(_ st: StageStep) -> Double {
        switch st.status {
        case .done, .failed: 1
        case .current: st.progress ?? 0.5
        case .upcoming, .blocked: 0
        }
    }

    private func color(_ st: StageStep) -> Color {
        switch st.status {
        case .done: Theme.good
        case .current: tint
        case .failed: Theme.bad
        case .blocked: Theme.warning
        case .upcoming: .secondary
        }
    }

    private func symbol(_ s: StageStep.Status) -> String {
        switch s {
        case .done: "checkmark"
        case .current: "circle.fill"
        case .failed: "xmark"
        case .blocked: "lock.fill"
        case .upcoming: "circle"
        }
    }

    private func word(_ s: StageStep.Status) -> String {
        switch s {
        case .done: "done"
        case .current: "under way"
        case .failed: "failed"
        case .blocked: "blocked"
        case .upcoming: "upcoming"
        }
    }
}

// MARK: - Tabs, charts and empty states

/// A screen's section switcher: one segmented control, the same width rules everywhere.
struct SectionTabs<T: Hashable & Identifiable>: View {
    @Binding var selection: T
    let options: [T]
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 0) {
            Picker("Section", selection: $selection) {
                ForEach(options) { t in Text(title(t)).tag(t) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: min(CGFloat(options.count) * 160, 760))
            Spacer(minLength: 0)
        }
    }
}

extension SectionTabs where T: RawRepresentable, T.RawValue == String {
    init(selection: Binding<T>, options: [T]) {
        _selection = selection
        self.options = options
        self.title = { $0.rawValue }
    }
}

/// A chart in a card: header, the chart at a fixed height (Charts layout is expensive; give it a stable frame), and an
/// optional caption that says how to read it.
struct ChartCard<Plot: View, Trailing: View>: View {
    let title: String
    var symbol: String? = nil
    var subtitle: String? = nil
    var height: CGFloat = 200
    var caption: String? = nil
    let chart: Plot
    let trailing: Trailing

    init(title: String, symbol: String? = nil, subtitle: String? = nil, height: CGFloat = 200, caption: String? = nil,
         @ViewBuilder chart: () -> Plot, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        self.height = height
        self.caption = caption
        self.chart = chart()
        self.trailing = trailing()
    }

    var body: some View {
        Card {
            CardHeader(title: title, symbol: symbol, subtitle: subtitle) { trailing }
            chart.frame(height: height)
            if let caption {
                Text(caption).font(TypeRamp.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension ChartCard where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, subtitle: String? = nil, height: CGFloat = 200, caption: String? = nil,
         @ViewBuilder chart: () -> Plot) {
        self.init(title: title, symbol: symbol, subtitle: subtitle, height: height, caption: caption, chart: chart, trailing: { EmptyView() })
    }
}

/// What's missing and what to do about it. `compact` for use inside a card.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            Image(systemName: symbol).font(.system(size: compact ? 24 : 34)).foregroundStyle(.tertiary).accessibilityHidden(true)
            Text(title).font(compact ? .callout.weight(.semibold) : .headline)
            Text(message).font(compact ? .caption : .callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).controlSize(compact ? .small : .regular).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? Theme.Space.l : 30)
    }
}

struct CompanyLogo: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: size * 0.28)
            )
            .shadow(color: color.opacity(0.35), radius: size * 0.15, y: size * 0.05)
    }
}

struct VendorBadge: View {
    let vendor: Vendor
    var onPhoto = false
    var body: some View {
        if onPhoto {
            PhotoPill(text: vendor.rawValue, color: Theme.vendorColor(vendor), symbol: vendor.symbol)
        } else {
            Pill(text: vendor.rawValue, color: Theme.vendorColor(vendor), symbol: vendor.symbol)
        }
    }
}

/// High-contrast pill for labels drawn on top of photos (white text on a dark capsule, tinted icon).
struct PhotoPill: View {
    let text: String
    var color: Color = .white
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).foregroundStyle(color) }
            Text(text).foregroundStyle(.white)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.62), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }
}

/// A generic photo standing in for one of the player's (fictional) facilities or deals, captioned as such.
/// `Photo` measures the banner and decodes a banner-sized copy, so wide strips stay sharp.
struct IllustrativeBanner: View {
    let key: String
    var height: CGFloat = 80

    var body: some View {
        Photo(key: key)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(.rect(cornerRadius: 8))
            .overlay(alignment: .bottomLeading) { PhotoPill(text: "Illustrative photo", symbol: "photo").padding(6) }
            .help(ImageLibrary.tooltip(key, illustrative: true))
    }
}

/// A one-line photo credit (author, licence, source) with the full attribution and any edits in its tooltip.
struct ImageCreditLabel: View {
    let key: String
    var representative = false
    var body: some View {
        if let c = ImageLibrary.credit(key) {
            Text("\(representative ? "Representative photo · " : "")Photo: \(c.author) · \(c.license) · Wikimedia Commons")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .help(ImageLibrary.attributionTooltip(c))
        }
    }
}

struct ToastView: View {
    let toast: Toast
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.isError ? .orange : .green)
            Text(toast.message).font(.callout).lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

/// A number field with +/- buttons for quick quantity selection.
struct QuantityPicker: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var presets: [Int] = [1, 8, 64, 512, 4096, 32_768, 262_144, 1_048_576]

    var body: some View {
        HStack(spacing: 6) {
            Button { value = max(range.lowerBound, value / 2) } label: { Image(systemName: "minus") }
                .buttonStyle(.bordered)
                .help("Halve").accessibilityLabel("Halve the quantity")
            TextField("Qty", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .multilineTextAlignment(.center)
                .onChange(of: value) { _, new in value = clamp(new, range.lowerBound, max(range.lowerBound, range.upperBound)) }
            Button { value = min(range.upperBound, max(1, value * 2)) } label: { Image(systemName: "plus") }
                .buttonStyle(.bordered)
                .help("Double").accessibilityLabel("Double the quantity")
            Menu("Presets") {
                ForEach(presets.filter { $0 <= range.upperBound }, id: \.self) { p in
                    Button(Fmt.int(p)) { value = p }
                }
                Button("Max (\(Fmt.int(range.upperBound)))") { value = range.upperBound }
            }
            .menuStyle(.button)
            .fixedSize()
        }
    }
}

extension View {
    func cardStyle() -> some View {
        self.padding(Theme.cardPadding)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

func signedMoney(_ v: Double) -> String { Fmt.signedMoney(v) }

/// Horizontal bar for a ratio vs a reference (1.0), drawn on a log scale from 1/10x to 100x.
struct LogBarRow: View {
    let label: String
    let ratio: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.caption).frame(width: 120, alignment: .leading)
            GeometryReader { geo in
                let pos = { (v: Double) in clamp((log10(max(v, 0.001)) + 1) / 3, 0, 1) * geo.size.width }
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(ratio >= 1 ? Color.green.gradient : Color.orange.gradient)
                        .frame(width: max(6, pos(ratio)))
                    Rectangle().fill(.secondary).frame(width: 1.5, height: 16).offset(x: pos(1))
                }
            }
            .frame(height: 12)
            Text("\(Fmt.trim(ratio, ratio < 10 ? 2 : 0))×").font(.caption.monospacedDigit()).frame(width: 52, alignment: .trailing)
        }
    }
}

extension BenchKind {
    var color: Color {
        switch self {
        case .knowledge: .blue
        case .reasoning: .purple
        case .math: .orange
        case .code: .teal
        case .agentic: .indigo
        case .multimodal: .pink
        case .longContext: .cyan
        case .science: .green
        case .instruction: .mint
        case .multilingual: .brown
        case .safety: .green
        case .dangerous: .red
        case .speech: .yellow
        }
    }
}
