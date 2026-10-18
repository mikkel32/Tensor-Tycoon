import Charts
import SwiftUI

/// The Rivals hub answers four questions in four tabs: who your rivals are and how strong (Overview), what each one is
/// and does (Labs, with a profile per lab), what they're about to ship (Watch) and the money behind it all (Industry).
/// One sidebar entry; the older screens (`.competitors`, `.rivalWatch`, `.industry`) open their tab here.
enum RivalsTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case labs = "Labs"
    case watch = "Watch"
    case industry = "Industry"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .overview: "The field at a glance: who leads, who's rising, where the money is and what just happened."
        case .labs: "Every lab: its models, its strategy and why, its books, its products and its dealings with you. Click one for its profile."
        case .watch: "Every lab's next frontier run as the rumour mill sees it: the cluster, a launch window that narrows as the date nears and a capability forecast against your models."
        case .industry: "The money behind the models: revenue, compute bills, rounds, listings, takeovers and failures — and the market cycle."
        }
    }
}

struct RivalsHubView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: RivalsTab
    @State private var lab: String?

    init(tab: RivalsTab, lab: String? = nil) {
        _tab = State(initialValue: tab)
        _lab = State(initialValue: lab)
    }

    var body: some View {
        Page(title: "Rivals", subtitle: tab.subtitle) {
            ScreenHint(.rivals)
            RivalsTabBar(tab: $tab, lab: $lab)
            content
        }
        .onAppear { takeLink() }
        .onChange(of: store.rivalsTab) { takeLink() }
        .onChange(of: store.rivalsLab) { takeLink() }
    }

    /// A link from elsewhere (an alert, the briefing, the leaderboard) picks the tab or lab.
    private func takeLink() {
        if let id = store.rivalsLab {
            lab = id
            tab = .labs
        } else if let t = store.rivalsTab {
            tab = t
            lab = nil
        }
        if store.rivalsLab != nil { store.rivalsLab = nil }
        if store.rivalsTab != nil { store.rivalsTab = nil }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .overview:
            RivalsOverviewTab(open: { openLab($0) }, show: { tab = $0 })
        case .labs:
            if let lab {
                LabProfileView(labID: lab, open: { openLab($0) }, close: { self.lab = nil })
            } else {
                RivalLabsTab(open: { openLab($0) })
            }
        case .watch:
            RivalWatchTab(open: { openLab($0) })
        case .industry:
            IndustryTab(open: { openLab($0) })
        }
    }

    private func openLab(_ id: String) {
        lab = id
        tab = .labs
    }
}

private struct RivalsTabBar: View {
    @Binding var tab: RivalsTab
    @Binding var lab: String?

    var body: some View {
        HStack(spacing: 12) {
            Picker("Section", selection: $tab) {
                ForEach(RivalsTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 440)
            if tab == .labs && lab != nil {
                Button {
                    lab = nil
                } label: {
                    Label("All labs", systemImage: "chevron.left")
                }
                .buttonStyle(.link)
            }
            Spacer()
        }
    }
}

// MARK: - Shared pieces

enum RivalsStyle {
    static func color(_ labID: String) -> Color { Theme.competitorColor(CompetitorCatalog.def(labID).color) }

    static func tone(_ t: RivalFeedItem.Tone) -> Color {
        switch t {
        case .good: .green
        case .bad: .red
        case .warning: .orange
        case .neutral: .secondary
        }
    }

    static func behind(_ months: Double) -> String {
        if months >= 60 { return "—" }
        if months < 0.5 { return "Leads" }
        return "\(Int(months.rounded())) mo"
    }

    static func momentum(_ v: Double?) -> String {
        guard let v else { return "new" }
        return (v >= 0 ? "+" : "−") + Fmt.score(abs(v))
    }

    static func statusColor(_ status: String) -> Color {
        switch status {
        case "Bankrupt": .red
        case "Acquired", "Merged", "Wound down": .secondary
        case "Distressed": .orange
        case "Public": .blue
        case "Funded by parent": .purple
        case "State-funded": .teal
        case "Pre-launch": .mint
        case "Burning cash": .yellow
        default: .green
        }
    }
}

/// One line of a rivals feed: what happened, to whom, when.
struct RivalFeedRow: View {
    let item: RivalFeedItem
    var open: ((String) -> Void)? = nil

    var body: some View {
        Button {
            open?(item.labID)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RivalsStyle.color(item.labID))
                    .frame(width: 18)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title).font(.callout.weight(.semibold)).foregroundStyle(item.tone == .neutral ? Color.primary : RivalsStyle.tone(item.tone))
                        Spacer()
                        Text(item.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                    Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(open == nil)
    }
}

// MARK: - Overview

struct RivalsOverviewTab: View {
    @Environment(GameStore.self) private var store
    let open: (String) -> Void
    let show: (RivalsTab) -> Void

    var body: some View {
        let s = store.game
        let field = RivalLifecycle.standings(s, board: store.derived.board, revenue: store.derived.runRate, compute: store.derived.h100e)
        VStack(alignment: .leading, spacing: 18) {
            FieldHero(field: field, state: s)
            FieldTiles(field: field, state: s)
            FieldTableCard(field: field, state: s, open: open)
            HStack(alignment: .top, spacing: 16) {
                FieldMomentumCard(field: field, state: s)
                FieldNextUpCard(rows: Array(store.derived.watch.prefix(5)), open: open, show: show)
                    .frame(width: 400)
            }
            FieldMovesCard(state: s, open: open)
            IndustryBuzzCard(open: open)   // 3.4: who the industry is talking about
        }
    }
}

private struct FieldHero: View {
    let field: [RivalStanding]
    let state: GameState

    var body: some View {
        let s = state
        let leader = field.first { $0.index > 0 }
        let rank = field.firstIndex { $0.isPlayer }.map { $0 + 1 }
        let mine = field.first { $0.isPlayer }
        HeroBanner(image: "hyperscale_campus", height: 150) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline(leader)).font(.title.weight(.bold))
                    Text(subline(s)).font(.callout).opacity(0.9)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Your rank").font(.caption).opacity(0.8)
                    Text((mine?.index ?? 0) > 0 ? rank.map { "#\($0) of \(field.count)" } ?? "—" : "—")
                        .font(.system(size: 26, weight: .bold))
                    Text((mine?.index ?? 0) > 0 ? "\(mine?.flagship ?? "") · \(Fmt.score(mine?.index ?? 0))" : "No model released yet")
                        .font(.caption).opacity(0.8)
                }
            }
        }
    }

    private func headline(_ leader: RivalStanding?) -> String {
        guard let leader else { return "The race hasn't started" }
        return leader.isPlayer ? "You lead the field" : "\(leader.name) leads with \(leader.flagship)"
    }

    private func subline(_ s: GameState) -> String {
        let rivals = field.filter { !$0.isPlayer }.count
        let founded = s.customLabs.count
        let gone = s.competitors.filter { !$0.exitNote.isEmpty }.count
        var parts = ["\(rivals) rival lab\(rivals == 1 ? "" : "s") in business"]
        if founded > 0 { parts.append("\(founded) founded since October 2026") }
        if gone > 0 { parts.append("\(gone) gone") }
        return parts.joined(separator: " · ")
    }
}

private struct FieldTiles: View {
    let field: [RivalStanding]
    let state: GameState

    var body: some View {
        let rivals = field.filter { !$0.isPlayer }
        let leader = field.first { $0.index > 0 }
        let rising = rivals.filter { $0.momentum != nil }.max { ($0.momentum ?? 0) < ($1.momentum ?? 0) }
        let revenue = rivals.reduce(0) { $0 + $1.revenue }
        let value = rivals.reduce(0) { $0 + $1.valuation }
        HStack(spacing: 12) {
            StatTile(title: "Labs in the race", value: "\(rivals.count)",
                     detail: "\(state.customLabs.count) new since Oct 2026 · \(state.competitors.filter { !$0.exitNote.isEmpty }.count) gone",
                     symbol: "building.2.fill", tint: .indigo)
            StatTile(title: "Best model", value: leader.map { Fmt.score($0.index) } ?? "—",
                     detail: leader.map { "\($0.flagship) · \($0.isPlayer ? "you" : $0.name)" } ?? "No models yet",
                     symbol: "trophy.fill", tint: .orange)
            StatTile(title: "Rising fastest", value: rising?.name ?? "—",
                     detail: rising.map { "\(RivalsStyle.momentum($0.momentum)) index points in a year" } ?? "Not enough history",
                     symbol: "chart.line.uptrend.xyaxis", tint: .green)
            StatTile(title: "Rivals' revenue", value: Fmt.money(revenue), detail: "Valued at \(Fmt.money(value))",
                     symbol: "dollarsign.circle.fill", tint: .teal)
        }
    }
}

private struct FieldTableCard: View {
    let field: [RivalStanding]
    let state: GameState
    let open: (String) -> Void

    var body: some View {
        Card {
            CardHeader("The field", symbol: "list.number",
                       subtitle: "Every lab in business and you, by best released model. Click a lab for its profile.")
            FieldHeaderRow()
            ForEach(Array(field.enumerated()), id: \.element.id) { k, row in
                FieldRow(row: row, rank: k + 1, logo: row.isPlayer ? Theme.logoColor(state.logoColor) : Theme.competitorColor(row.color), open: open)
            }
        }
    }
}

private struct FieldHeaderRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("#").frame(width: 24, alignment: .trailing)
            Text("Lab · flagship").frame(maxWidth: .infinity, alignment: .leading)
            Text("Index").frame(width: 50, alignment: .trailing).help("Best released model on today's Intelligence Index")
            Text("12 mo").frame(width: 56, alignment: .trailing).help("Change in that index over the last 12 months")
            Text("Behind").frame(width: 60, alignment: .trailing).help("How far the lab's best model trails the world's best, in months of frontier progress")
            Text("Valuation").frame(width: 80, alignment: .trailing)
            Text("Revenue").frame(width: 80, alignment: .trailing).help("Annualised revenue")
            Text("H100e").frame(width: 66, alignment: .trailing).help("Compute in H100-equivalents: each chip counted as its BF16 speed over an H100's")
            Text("Strategy").frame(width: 150, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

private struct FieldRow: View {
    let row: RivalStanding
    let rank: Int
    let logo: Color
    let open: (String) -> Void

    var body: some View {
        Button {
            if !row.isPlayer { open(row.id) }
        } label: {
            content
        }
        .buttonStyle(.plain)
        .help(row.isPlayer ? "Your best released model" : "Open \(row.name)'s profile")
    }

    private var content: some View {
        HStack(spacing: 8) {
            Text("\(rank)").frame(width: 24, alignment: .trailing).foregroundStyle(.secondary)
            name.frame(maxWidth: .infinity, alignment: .leading)
            Text(row.index > 0 ? Fmt.score(row.index) : "—").frame(width: 50, alignment: .trailing)
            Text(RivalsStyle.momentum(row.momentum))
                .foregroundStyle(momentumColor)
                .frame(width: 56, alignment: .trailing)
            Text(RivalsStyle.behind(row.monthsBehind)).frame(width: 60, alignment: .trailing)
            Text(Fmt.money(row.valuation)).frame(width: 80, alignment: .trailing)
            Text(Fmt.money(row.revenue)).frame(width: 80, alignment: .trailing)
            Text(Fmt.count(row.compute)).frame(width: 66, alignment: .trailing)
            Text(strategy)
                .foregroundStyle((row.play?.threat ?? 0) >= 2 ? Color.red : Color.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
        }
        .font(.callout.monospacedDigit())
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(row.isPlayer ? Color.indigo.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 6))
        .contentShape(.rect)
    }

    private var momentumColor: Color {
        let m = row.momentum ?? 0
        return m > 0.5 ? .green : (m < -0.5 ? .red : .secondary)
    }

    private var strategy: String { row.isPlayer ? "—" : (row.play?.title ?? row.status) }

    private var name: some View {
        HStack(spacing: 8) {
            CompanyLogo(symbol: row.symbol, color: logo, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(row.isPlayer ? "\(row.name) (you)" : row.name).font(.callout.weight(.semibold)).lineLimit(1)
                    if row.isNew {
                        Pill(text: "New", color: .green)
                    } else if !row.kind.isEmpty {
                        Pill(text: row.kind, color: .secondary)
                    }
                }
                Text(row.flagship).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

private struct TrajPoint: Identifiable {
    let id: Int
    let lab: String
    let date: Date
    let index: Double
}

private struct FieldMomentumCard: View {
    let field: [RivalStanding]
    let state: GameState

    var body: some View {
        let s = state
        let since = GameCalendar.addMonths(s.date, -36)
        let top = Array(field.filter { !$0.isPlayer && $0.index > 0 }.prefix(6))
        let points = Self.points(s, labs: top.map(\.id), since: since)
        let scale = Self.scale(s, top)
        Card {
            CardHeader("Momentum", symbol: "chart.line.uptrend.xyaxis",
                       subtitle: "Best Intelligence Index of the top six labs over three years, against yours")
            if points.isEmpty {
                Text("No models yet.").font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Index", p.index))
                        .foregroundStyle(by: .value("Lab", p.lab))
                        .interpolationMethod(.stepEnd)
                }
                .chartForegroundStyleScale(domain: scale.names, range: scale.colors)
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 240)
            }
        }
    }

    static func scale(_ s: GameState, _ top: [RivalStanding]) -> (names: [String], colors: [Color]) {
        var names: [String] = []
        var colors: [Color] = []
        for r in top where !names.contains(r.name) {
            names.append(r.name)
            colors.append(Theme.competitorColor(r.color))
        }
        if !names.contains(s.companyName) {
            names.append(s.companyName)
            colors.append(Theme.logoColor(s.logoColor))
        }
        return (names, colors)
    }

    static func points(_ s: GameState, labs: [String], since: Date) -> [TrajPoint] {
        var out = RivalLifecycle.trajectories(s, labs: labs, since: since).map { TrajPoint(id: $0.id, lab: $0.lab, date: $0.date, index: $0.index) }
        var best = 0.0
        var started = false
        let mine = s.models.filter(\.released).sorted { ($0.releaseDate ?? $0.created) < ($1.releaseDate ?? $1.created) }
        for m in mine {
            let d = m.releaseDate ?? m.created
            if d >= since && !started {
                if best > 0 { out.append(TrajPoint(id: out.count, lab: s.companyName, date: since, index: best)) }
                started = true
            }
            best = max(best, m.index)
            if d >= since { out.append(TrajPoint(id: out.count, lab: s.companyName, date: d, index: best)) }
        }
        if best > 0 {
            if !started { out.append(TrajPoint(id: out.count, lab: s.companyName, date: since, index: best)) }
            out.append(TrajPoint(id: out.count, lab: s.companyName, date: s.date, index: best))
        }
        return out
    }
}

private struct FieldNextUpCard: View {
    let rows: [RivalIntel.Row]
    let open: (String) -> Void
    let show: (RivalsTab) -> Void

    var body: some View {
        Card {
            CardHeader(title: "Next launches", symbol: "binoculars.fill", subtitle: "As the rumour mill sees them") {
                HelpButton(term: .forecastBand)
                Button("Watch") { show(.watch) }.buttonStyle(.link)
            }
            if rows.isEmpty {
                Text("No rival runs to watch yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(rows) { r in
                Button {
                    open(r.id)
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.competitorColor(r.color)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(r.project.name).font(.callout.weight(.semibold)).lineLimit(1)
                            Text("\(r.lab) · \(r.outlook.phase.rawValue)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(RivalIntel.windowText(r.outlook)).font(.caption.monospacedDigit())
                            Text("~\(Fmt.score(r.outlook.index))").font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(RivalWatchView.threatColor(r.threat))
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FieldMovesCard: View {
    let state: GameState
    let open: (String) -> Void

    var body: some View {
        let s = state
        let items = RivalLifecycle.feed(s, since: GameCalendar.addMonths(s.date, -6), limit: 14)
        Card {
            CardHeader("Recent moves", symbol: "bolt.horizontal.fill",
                       subtitle: "Launches, rounds, new strategies, new labs, takeovers and failures over the last six months")
            if items.isEmpty {
                Text("Quiet so far.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                RivalFeedRow(item: item, open: open)
                if item.id != items.last?.id { Divider() }
            }
        }
    }
}
