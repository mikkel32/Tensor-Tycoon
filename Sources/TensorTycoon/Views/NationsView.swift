import Charts
import SwiftUI

// MARK: - 3.7: Nations

/// National AI strategies and economies, region by region: the seven dials each government reviews every January, why
/// they moved, what they do to you, and the rival labs that specialise against you. Read from `GameState.nations`
/// (updated monthly).
struct NationsView: View {
    @Environment(GameStore.self) private var store
    @State private var selected: Region? = nil
    @State private var country: String? = nil

    var body: some View {
        let s = store.game
        let n = s.nations
        Page(title: "Nations", subtitle: "Every region runs its own AI strategy and reviews it each January against public mood, incidents, jobs, grids and who holds the frontier. The dials change what chips, power, hiring and contracts cost you.", screen: .nations) {
            ScreenHint(.nations)
            if !n.ready || n.strategies.isEmpty {
                Card { EmptyStateView(symbol: "globe.europe.africa", title: "Strategies are set at month end", message: "Come back after the first month closes.") }
            } else {
                let region = selected ?? HQ.region(s)
                NationsHeadline(state: s)
                CardGrid(minWidth: 340, maxColumns: 2) {
                    NationsEffectsCard(state: s)
                    NationsRivalsCard(state: s, open: { store.open(.competitors) })
                }
                NationsTable(state: s, selected: region) { selected = $0 }
                CardGrid(minWidth: 340, maxColumns: 2) {
                    NationDetailCard(state: s, region: region)
                    NationsTimelineCard(state: s, region: region)
                }
                // 3.4 overhaul: the country layer, attractiveness and your national partnerships
                let picked = country ?? (HQ.isDefault(s) ? "fr" : s.hqCountry)
                CountriesCard(state: s, selected: picked) { country = $0 }
                CardGrid(minWidth: 340, maxColumns: 2) {
                    CountryDetailCard(state: s, id: picked)
                    NationalPartnershipsCard(state: s)
                }
            }
        }
    }
}

/// Your home, its stance, and the world's AI economy in four numbers.
private struct NationsHeadline: View {
    let state: GameState

    var body: some View {
        let n = state.nations
        let home = HQ.region(state)
        let st = n.strategy(home)
        let econ = Region.allCases.map { (n.economy($0), $0.weight) }
        let gdp = econ.reduce(0) { $0 + $1.0.gdpGrowth * $1.1 }
        let share = econ.reduce(0) { $0 + $1.0.aiShare * $1.1 }
        let invest = econ.reduce(0) { $0 + $1.0.aiInvestment }
        let auto = econ.reduce(0) { $0 + $1.0.automation * $1.1 }
        let recessions = Region.allCases.filter { Nations.recessionDepth(state, $0) > 0 }
        KPIRow(minWidth: 190) {
            StatTile(title: "Your home: \(home.short)", value: st.stance.isEmpty ? "—" : st.stance, detail: "Reviewed January \(st.reviewed)",
                     symbol: "house.fill", tint: .accentColor)
            StatTile(title: "World GDP growth", value: "\(Fmt.trim(gdp, 1))%", detail: recessions.isEmpty ? "Weighted by AI spending" : "Recession in \(recessions.map(\.short).joined(separator: ", "))",
                     symbol: "chart.line.uptrend.xyaxis", tint: recessions.isEmpty && gdp >= 2 ? Theme.good : Theme.warning)
            StatTile(title: "AI share of GDP", value: "\(Fmt.trim(share, 1))%", detail: "Across the seven regions", symbol: "cpu.fill", tint: .purple)
            StatTile(title: "AI investment", value: Fmt.money(invest) + "/yr", detail: "Public and private", symbol: "banknote.fill", tint: .blue)
            StatTile(title: "Out of work to automation", value: "\(Fmt.trim(auto, 2))%", detail: "Of the workforce", symbol: "person.2.fill",
                     tint: auto >= 1 ? .red : .orange)
        }
    }
}

// MARK: Effects on you

private struct NationsEffectsCard: View {
    let state: GameState

    var body: some View {
        let rows = Nations.effectsOnYou(state)
        Card {
            CardHeader("Effects on you", symbol: "person.crop.circle.badge.exclamationmark",
                       subtitle: "What national strategies do to your costs and business right now")
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(r.title).font(.callout).frame(width: 170, alignment: .leading)
                    HStack(spacing: 3) {
                        if let good = r.good {
                            Image(systemName: good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.caption2).accessibilityLabel(good ? "Helps you" : "Hurts you")
                        }
                        Text(r.value).font(.callout.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(r.good == true ? Theme.good : (r.good == false ? Theme.bad : Color.secondary))
                    .frame(width: 92, alignment: .leading)
                    Text(r.why).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Costs move with the dials at home (and with energy policy wherever your datacenters are). Rival labs read their own home strategy when they choose what to specialise in.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: Rival specialisations

private struct NationsRivalsCard: View {
    let state: GameState
    let open: () -> Void

    var body: some View {
        let s = state
        let labs = s.competitors.filter { Nations.active($0, s) && s.nations.focus[$0.id]?.rivalFocus != nil }
            .sorted { $0.brand > $1.brand }
        Card {
            CardHeader(title: "Rival specialisations", symbol: "scope", subtitle: "What each lab focuses on, and what it's weighing") {
                Button("Rival labs") { open() }.buttonStyle(.link)
            }
            if labs.isEmpty {
                Text("Labs pick a specialty once they have a model on the market.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(labs.prefix(8)) { c in
                if let st = s.nations.focus[c.id], let f = st.rivalFocus {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(c.def.name).font(.callout).frame(width: 140, alignment: .leading).lineLimit(1)
                        Label(f.title, systemImage: f.symbol).font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.competitorColor(c.def.color))
                            .frame(width: 150, alignment: .leading)
                        if let next = RivalFocus(rawValue: st.considering) {
                            Pill(text: "Weighing \(next.title.lowercased())", color: .orange)
                        }
                        Spacer(minLength: 0)
                        Text(Nations.home(c.id).short).font(.caption2).foregroundStyle(.secondary)
                    }
                    .help(st.reason)
                }
            }
            if let last = s.nations.rivalLog.first {
                Divider()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(last.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 82, alignment: .leading)
                    Text(last.text).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: The table

private struct NationsTable: View {
    let state: GameState
    let selected: Region
    let pick: (Region) -> Void

    var body: some View {
        let n = state.nations
        Card {
            CardHeader("Strategies and economies", symbol: "globe.europe.africa.fill",
                       subtitle: "Dials 0–100. Click a region for its history and the reasons behind each move.")
            HStack(spacing: 8) {
                Text("Region").frame(width: 120, alignment: .leading)
                Text("Stance").frame(width: 130, alignment: .leading)
                ForEach(NationLever.allCases) { l in
                    Image(systemName: l.symbol).frame(width: 46).help(l.title)
                }
                Spacer()
                Text("GDP").frame(width: 48, alignment: .trailing)
                Text("AI/GDP").frame(width: 54, alignment: .trailing)
                Text("Jobless").frame(width: 54, alignment: .trailing)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Region.allCases) { r in
                let st = n.strategy(r)
                let e = n.economy(r)
                Button { pick(r) } label: {
                    HStack(spacing: 8) {
                        Text(r.title).font(.callout.weight(r == selected ? .semibold : .regular)).frame(width: 120, alignment: .leading)
                        Text(st.stance).font(.caption).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
                        ForEach(NationLever.allCases) { l in
                            let v = st.level(l)
                            VStack(spacing: 2) {
                                Text("\(Int(v.rounded()))").font(.caption.monospacedDigit())
                                Meter(value: v / 100, tint: NationsTint.lever(l), height: 4)
                            }
                            .frame(width: 46)
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            if Nations.recessionDepth(state, r) > 0 {
                                Image(systemName: Tone.bad.symbol).font(.caption2).foregroundStyle(Theme.bad).accessibilityLabel("Recession")
                                    .help("In recession: growth −\(Fmt.trim(Nations.recessionDepth(state, r), 1)) points")
                            }
                            Text("\(Fmt.trim(e.gdpGrowth, 1))%").font(.caption.monospacedDigit())
                        }
                        .frame(width: 48, alignment: .trailing)
                        Text("\(Fmt.trim(e.aiShare, 1))%").font(.caption.monospacedDigit()).frame(width: 54, alignment: .trailing)
                        Text("\(Fmt.trim(e.automation, 2))%").font(.caption.monospacedDigit()).frame(width: 54, alignment: .trailing)
                    }
                    .padding(.vertical, 3)
                    .background(r == selected ? Color.accentColor.opacity(0.08) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 14) {
                ForEach(NationLever.allCases) { l in
                    Label(l.title, systemImage: l.symbol).font(.caption2).foregroundStyle(.secondary).help(l.high)
                }
            }
        }
    }
}

// MARK: One region

private struct NationDetailCard: View {
    let state: GameState
    let region: Region

    var body: some View {
        let n = state.nations
        let st = n.strategy(region)
        let e = n.economy(region)
        Card {
            CardHeader("\(region.title): \(st.stance)", symbol: "flag.fill",
                       subtitle: "AI investment \(Fmt.money(e.aiInvestment))/yr · GDP growth \(Fmt.trim(e.gdpGrowth, 1))% · AI \(Fmt.trim(e.aiShare, 1))% of GDP")
            NationLeversChart(rows: n.years.filter { $0.region == region.rawValue })
                .frame(height: 200)
            if st.reasons.isEmpty {
                Text("No big moves at the last review: the strategy kept its course.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Why it moved in January \(st.reviewed)").font(.caption.weight(.semibold))
                ForEach(Array(st.reasons.prefix(5).enumerated()), id: \.offset) { _, line in
                    Text("• " + line).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            ForEach(NationLever.allCases) { l in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: l.symbol).foregroundStyle(NationsTint.lever(l)).frame(width: 18)
                    Text(l.title).font(.caption.weight(.semibold)).frame(width: 150, alignment: .leading)
                    Text("\(Int(st.level(l).rounded()))").font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                    Text(l.effect).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            let labs = state.competitors.filter { Nations.active($0, state) && Nations.home($0.id) == region }
            if !labs.isEmpty {
                Text("Home labs: " + labs.map { c in "\(c.def.name)\(Nations.focus(state, c.id).map { " (\($0.title.lowercased()))" } ?? "")" }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct NationsTimelineCard: View {
    let state: GameState
    let region: Region

    var body: some View {
        let notes = state.nations.timeline.filter { $0.who == region.rawValue }.prefix(10)
        Card {
            CardHeader("\(region.short) strategy, year by year", symbol: "calendar", subtitle: "Each January's review and any recessions, newest first")
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(note.kind == "recession" ? note.date.gameMonth : "\(note.date.ym.year)").font(.caption.monospacedDigit().weight(.semibold)).frame(width: 64, alignment: .leading)
                    if note.kind == "recession" {
                        Image(systemName: "chart.line.downtrend.xyaxis").font(.caption2).foregroundStyle(Theme.warning).accessibilityLabel("Recession")
                    }
                    Text(note.text).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
            let rows = state.nations.years.filter { $0.region == region.rawValue }.suffix(8)
            if !rows.isEmpty {
                Divider()
                HStack {
                    Text("Year").frame(width: 40, alignment: .leading)
                    Text("GDP").frame(width: 50, alignment: .trailing)
                    Text("AI/GDP").frame(width: 56, alignment: .trailing)
                    Text("AI investment").frame(width: 100, alignment: .trailing)
                    Text("Jobless").frame(width: 56, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(rows.reversed().enumerated()), id: \.offset) { _, y in
                    HStack {
                        Text("\(y.year)").frame(width: 40, alignment: .leading)
                        Text("\(Fmt.trim(y.gdpGrowth, 1))%").frame(width: 50, alignment: .trailing)
                        Text("\(Fmt.trim(y.aiShare, 1))%").frame(width: 56, alignment: .trailing)
                        Text(Fmt.money(y.aiInvestment)).frame(width: 100, alignment: .trailing)
                        Text("\(Fmt.trim(y.automation, 2))%").frame(width: 56, alignment: .trailing)
                    }
                    .font(.caption2.monospacedDigit())
                }
            }
        }
    }
}

/// A region's dials over the years.
struct NationLeversChart: View {
    struct Point: Identifiable {
        let id: Int
        let year: Int
        let lever: String
        let value: Double
    }

    let rows: [NationYear]

    var body: some View {
        let pts = points()
        if pts.isEmpty {
            Text("No history yet.").font(.caption).foregroundStyle(.secondary)
        } else {
            Chart(pts) { p in
                LineMark(x: .value("Year", p.year), y: .value("Level", p.value))
                    .foregroundStyle(by: .value("Dial", p.lever))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...100)
            .chartLegend(position: .bottom, alignment: .leading)
        }
    }

    func points() -> [Point] {
        var out: [Point] = []
        for r in rows {
            for l in NationLever.allCases where r.levels.indices.contains(l.index) {
                out.append(Point(id: out.count, year: r.year, lever: l.title, value: r.levels[l.index]))
            }
        }
        return out
    }
}

enum NationsTint {
    static func lever(_ l: NationLever) -> Color {
        switch l {
        case .subsidy: .blue
        case .sovereign: .purple
        case .exports: .red
        case .data: .orange
        case .safety: .green
        case .visas: .teal
        case .energy: .yellow
        }
    }
}

// MARK: - Rival lab profile: specialisation & why

/// "Specialisation & why" on a rival lab's profile: its focus, the reasons, the case for each alternative, and how it
/// answered your launches.
struct LabSpecialisationCard: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let s = state
        let st = s.nations.focus[comp.id]
        Card {
            CardHeader("Specialisation & why", symbol: "scope", subtitle: "Where it focuses, read from its strengths, its home country's strategy and where you're strong")
            if let st, let f = st.rivalFocus {
                Label("\(f.title)\(st.since.map { " since \($0.gameMonth)" } ?? "")", systemImage: f.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.competitorColor(comp.def.color))
                Text(st.reason).font(.caption).fixedSize(horizontal: false, vertical: true)
                Text("Effect: \(f.effect)").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let next = RivalFocus(rawValue: st.considering) {
                    Label("Weighing a move into \(next.noun)\(st.consideringSince.map { " since \($0.gameMonth)" } ?? ""): it commits if the case still holds next quarter.",
                          systemImage: "hourglass")
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                SpecRow(label: "Home", value: "\(Nations.home(comp.id).title) · \(s.nations.strategy(Nations.home(comp.id)).stance)")
                if let next = st.nextReview, comp.alive { SpecRow(label: "Next review", value: next.gameMonth) }
                let scores = st.scores.sorted { $0.value > $1.value }
                if !scores.isEmpty {
                    Text("How each specialty scored at its last review").font(.caption.weight(.semibold))
                    let top = max(0.01, scores.first?.value ?? 1)
                    ForEach(scores, id: \.key) { k, v in
                        if let rf = RivalFocus(rawValue: k) {
                            HStack(spacing: 8) {
                                Text(rf.title).font(.caption).frame(width: 120, alignment: .leading)
                                Meter(value: clamp(v / top, 0, 1), tint: rf == f ? Theme.competitorColor(comp.def.color) : .secondary, height: 5)
                                Text(Fmt.trim(v, 2)).font(.caption2.monospacedDigit()).frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
                let log = s.nations.rivalLog.filter { $0.who == comp.id }.prefix(4)
                if !log.isEmpty {
                    Divider()
                    Text("Moves and answers to you").font(.caption.weight(.semibold))
                    ForEach(Array(log.enumerated()), id: \.offset) { _, n in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(n.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 82, alignment: .leading)
                            Text(n.text).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let r = s.nations.reactions.first(where: { $0.lab == comp.id }) {
                    Label("Preparing an answer to your \(r.launch)", systemImage: "arrow.uturn.backward.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text(comp.alive ? "No specialty yet: labs pick one once they have a model on the market (set at month end)." : "Out of the race.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Dashboard card

/// Nations in one card, for the dashboard: your home's stance, what it does to you, and the latest rival move.
struct NationsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let n = s.nations
        let home = HQ.region(s)
        Card {
            CardHeader(title: "Nations", symbol: "globe.europe.africa.fill", subtitle: n.ready ? "\(home.title): \(n.strategy(home).stance.lowercased())" : nil) {
                Button("Open") { store.open(.nations) }.buttonStyle(.link)
            }
            if n.ready {
                let effects = Nations.effectsOnYou(s).filter { $0.good != nil }.prefix(3)
                if effects.isEmpty {
                    Text("National strategies leave your costs where they are.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(effects.enumerated()), id: \.offset) { _, e in
                    HStack(spacing: 6) {
                        Text(e.title).font(.caption)
                        Spacer()
                        Image(systemName: e.good == true ? Tone.good.symbol : Tone.bad.symbol).font(.caption2)
                            .foregroundStyle(e.good == true ? Theme.good : Theme.bad).accessibilityLabel(e.good == true ? "Helps you" : "Hurts you")
                        Text(e.value).font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
                if let r = n.rivalLog.first, GameCalendar.daysBetween(r.date, s.date) <= 120 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "scope").font(.caption).foregroundStyle(.orange)
                        Text(r.text).font(.caption).lineLimit(2)
                    }
                } else if let t = n.timeline.first(where: { $0.who == home.rawValue }) {
                    Text(t.text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            } else {
                Text("Strategies are set at the end of the month.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 3.4 overhaul: countries

/// The headquarters countries side by side: how attractive each is for an AI lab right now, how that moved since last
/// January, and the biggest reasons.
private struct CountriesCard: View {
    let state: GameState
    let selected: String
    let pick: (String) -> Void

    var body: some View {
        let s = state
        Card {
            CardHeader("Countries", symbol: "mappin.and.ellipse",
                       subtitle: "Attractiveness for an AI lab, 0–100: a summary of what the game charges and pays you there today (costs, tax, talent, capital, public money, power, the economy, chip access). Click a country for its own dials.")
            ForEach(CountryCatalog.all) { c in
                let a = Nations.appeal(s, c.id)
                let last = s.nations.countries[c.id]?.history.dropLast().last?.appeal
                let change = last.map { a.value - $0 }
                Button { pick(c.id) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        FlagView(id: c.id).frame(width: 21, height: 14)
                        Text(c.name).font(.callout.weight(c.id == selected ? .semibold : .regular)).frame(width: 120, alignment: .leading)
                        Text("\(Int(a.value.rounded()))").font(.callout.monospacedDigit().weight(.semibold)).frame(width: 32, alignment: .trailing)
                        Meter(value: a.value / 100, tint: c.id == s.hqCountry ? Color.accentColor : Theme.neutral, height: 5).frame(width: 90)
                        if let change, abs(change) >= 0.5 {
                            Label(Fmt.signed(change, 0), systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.monospacedDigit()).foregroundStyle(change > 0 ? Theme.good : Theme.bad)
                                .frame(width: 56, alignment: .leading)
                        } else {
                            Text("—").font(.caption).foregroundStyle(.tertiary).frame(width: 56, alignment: .leading)
                        }
                        Text(Self.reasons(a.parts))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            .help(Self.reasons(a.parts, count: 8))
                        Spacer(minLength: 0)
                        if c.id == s.hqCountry { Pill("Home", tone: .accent) }
                    }
                    .padding(.vertical, 2)
                    .background(c.id == selected ? Color.accentColor.opacity(0.08) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            Text("Change is against the last January review. The US is its own region; the four European countries set their own funding, sovereign programme, talent and energy policy on top of the EU's rules.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "Cost of a hire +17 · Corporate tax +5 · …"
    static func reasons(_ parts: [(label: String, value: Double)], count: Int = 3) -> String {
        parts.prefix(count).map { p in p.label + " " + Fmt.signed(p.value, 0) }.joined(separator: " · ")
    }
}

/// One country: its dials against its region's, why they moved, what makes it attractive or not, and its dated events.
private struct CountryDetailCard: View {
    let state: GameState
    let id: String

    var body: some View {
        let s = state
        let c = CountryCatalog.get(id)
        let cp = s.nations.countries[id]
        let a = Nations.appeal(s, id)
        Card {
            CardHeader("\(c.name): attractiveness \(Int(a.value.rounded()))", symbol: "flag.fill",
                       subtitle: c.character.isEmpty ? "The US sets its own rules as a region." : "National dials on top of the \(c.region.short)'s, reviewed each January")
            ForEach(Array(a.parts.enumerated()), id: \.offset) { _, p in
                HStack(spacing: 8) {
                    Text(p.label).font(.caption).frame(width: 220, alignment: .leading)
                    Image(systemName: p.value > 0 ? Tone.good.symbol : Tone.bad.symbol).font(.caption2)
                        .foregroundStyle(p.value > 0 ? Theme.good : Theme.bad).accessibilityLabel(p.value > 0 ? "Helps" : "Hurts")
                    Text(Fmt.signed(p.value, 1)).font(.caption.monospacedDigit())
                }
            }
            if !c.character.isEmpty {
                Divider()
                let region = s.nations.strategy(c.region)
                ForEach(NationLever.allCases) { l in
                    let v = Nations.level(s, country: id, l)
                    let r = region.level(l)
                    HStack(spacing: 8) {
                        Image(systemName: l.symbol).foregroundStyle(NationsTint.lever(l)).frame(width: 18)
                        Text(l.title).font(.caption.weight(.semibold)).frame(width: 150, alignment: .leading)
                        Text("\(Int(v.rounded()))").font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                        Text("\(c.region.short) \(Int(r.rounded()))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                        if c.characterWhy.indices.contains(l.index), !c.characterWhy[l.index].isEmpty {
                            Text(c.characterWhy[l.index]).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                if let cp, !cp.reasons.isEmpty {
                    Text("Why it moved in January \(cp.reviewed)").font(.caption.weight(.semibold))
                    ForEach(Array(cp.reasons.prefix(4).enumerated()), id: \.offset) { _, line in
                        Text("• " + line).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let h = cp?.history, h.count >= 2 {
                    Text(Self.trend(h))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            let notes = s.nations.timeline.filter { $0.who == id }.prefix(6)
            if !notes.isEmpty {
                Divider()
                ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(n.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 82, alignment: .leading)
                        if n.kind == "event" { Pill("Real event", tone: .info) }
                        Text(n.text).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Dates and descriptions of real events are facts; how far they move the dials is a game estimate.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    /// "Attractiveness by January: 2023 61 · 2024 63 · …"
    static func trend(_ h: [CountryYear]) -> String {
        "Attractiveness by January: " + h.suffix(8).map { y in "\(y.year) \(Int(y.appeal.rounded()))" }.joined(separator: " · ")
    }
}
