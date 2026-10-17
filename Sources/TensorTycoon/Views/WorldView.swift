import Charts
import SwiftUI

// MARK: - 3.4: World & Standing

/// The world outside the labs — adoption, jobs, public mood, energy, rules by region — and how the people who matter
/// see your lab, with what moved them. Everything here is read from `GameState.world` (updated monthly).
struct WorldView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let w = s.world
        Page(title: "World & Standing", subtitle: "How the world is taking AI — adoption, jobs, mood, energy and rules — and how the people who matter see your lab. It all moves once a month.") {
            if !w.ready || w.history.isEmpty {
                EmptyStateView(symbol: "globe.americas", title: "The world updates at month end", message: "Come back after the first month closes.")
            } else {
                WorldHeadline(state: s)
                StandingCard(state: s)
                RegulationCard(state: s)
                HStack(alignment: .top, spacing: 16) {
                    Card {
                        CardHeader("AI adoption by sector", symbol: "chart.line.uptrend.xyaxis", subtitle: "Share of each sector's organisations using AI regularly")
                        WorldHistoryChart(kind: .adoption, history: w.history)
                            .equatable()
                            .frame(height: 230)
                        AdoptionList(world: w)
                    }
                    Card {
                        CardHeader("Public mood and safety concern", symbol: "waveform.path.ecg", subtitle: "0–100. Mood above 50 is warm; concern rises with incidents and fades slowly")
                        WorldHistoryChart(kind: .mood, history: w.history)
                            .equatable()
                            .frame(height: 230)
                        Text("Useful AI warms people up; job losses and fear cool them down. Incidents — yours, rivals' or anyone's — push concern up, and it takes a year or more to settle.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    JobsCard(state: s)
                    EnergyCard(state: s, mine: store.derived.h100e)
                }
                HStack(alignment: .top, spacing: 16) {
                    ConsequencesCard(world: w)
                    LabTrustCard(state: s)
                }
            }
        }
    }
}

/// Tiles across the top: the state of the world in five numbers.
private struct WorldHeadline: View {
    let state: GameState

    var body: some View {
        let w = state.world
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
            StatTile(title: "Public mood toward AI", value: "\(Int(w.sentiment.rounded()))", detail: World.moodLabel(w.sentiment),
                     symbol: "face.smiling", tint: w.sentiment >= 50 ? .green : .orange, trend: WorldTrend.change(w.history, months: 3) { $0.sentiment })
            StatTile(title: "Safety concern", value: "\(Int(w.concern.rounded()))", detail: World.concernLabel(w.concern),
                     symbol: "exclamationmark.shield.fill", tint: w.concern >= 50 ? .red : .orange, trend: WorldTrend.change(w.history, months: 3) { $0.concern })
            StatTile(title: "Work done by AI", value: Fmt.pct(w.tasks, decimals: 1), detail: "\(Fmt.trim(w.looking, 1))M people looking for work",
                     symbol: "person.2.fill", tint: .purple)
            StatTile(title: "AI power draw", value: "\(Fmt.trim(w.powerGW, w.powerGW < 10 ? 1 : 0)) GW",
                     detail: "\(Fmt.pct(w.aiShare, decimals: 1)) of world electricity", symbol: "bolt.fill", tint: .yellow)
            StatTile(title: "Your public trust", value: "\(Int(w.publicTrust.rounded()))", detail: World.standingLabel(w.publicTrust),
                     symbol: "person.3.fill", tint: WorldTint.standing(w.publicTrust), trend: WorldTrend.standing(w.history, 0, now: w.publicTrust))
        }
    }
}

// MARK: Your standing

private struct StandingCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Your standing", symbol: "person.crop.circle.badge.checkmark",
                       subtitle: "Each settles where your record puts it and jumps when you do something people notice. 50 is neutral.")
            ForEach(Stakeholder.allCases) { who in
                StandingRow(state: state, who: who)
                if who != .governments { Divider() }
            }
        }
    }
}

private struct StandingRow: View {
    let state: GameState
    let who: Stakeholder

    var body: some View {
        let s = state
        let value = Stakeholders.value(s, who)
        let target = Stakeholders.target(s, who)
        let notes = Array(Stakeholders.notes(s, who).prefix(3))
        let index = Stakeholder.allCases.firstIndex(of: who) ?? 0
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: who.symbol).foregroundStyle(WorldTint.standing(value)).frame(width: 18)
                Text("\(who.title)").font(.callout.weight(.semibold))
                Text(who.measure).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let d = WorldTrend.standing(s.world.history, index, now: value), abs(d) >= 1 {
                    Text("\(d >= 0 ? "+" : "−")\(Int(abs(d).rounded())) in 3 months").font(.caption).foregroundStyle(d >= 0 ? .green : .red)
                }
                Text("\(Int(value.rounded()))").font(.title3.weight(.semibold).monospacedDigit())
                Pill(text: World.standingLabel(value), color: WorldTint.standing(value))
            }
            Meter(value: value / 100, tint: WorldTint.standing(value), height: 6)
            Text(Stakeholders.effect(s, who)).font(.caption).foregroundStyle(.secondary)
            Text(heading(target)).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                NoteLine(note: n, who: who)
            }
        }
    }

    private func heading(_ t: (value: Double, parts: [Stakeholders.Part])) -> String {
        switch who {
        case .investors: return "Heading toward \(Int(t.value.rounded())): the board's view of your growth, models and runway. Board goals met and missed move it most."
        case .governments: return "Heading toward \(Int(t.value.rounded())) on average. Regions differ: see Rules by region below."
        default:
            let parts = t.parts.sorted { abs($0.value) > abs($1.value) }.prefix(3)
                .map { "\($0.label) \($0.value >= 0 ? "+" : "−")\(Fmt.trim(abs($0.value), 0))" }
            return "Heading toward \(Int(t.value.rounded()))" + (parts.isEmpty ? "." : ": " + parts.joined(separator: ", ") + ".")
        }
    }
}

/// One remembered cause: date, what happened, and how much it moved this stakeholder.
private struct NoteLine: View {
    let note: WorldNote
    let who: Stakeholder

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(note.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 82, alignment: .leading)
            Text(note.text).font(.caption).lineLimit(1)
            Spacer(minLength: 4)
            Text(amount).font(.caption.monospacedDigit()).foregroundStyle(total >= 0 ? .green : .red)
        }
    }

    private var total: Double {
        if who == .governments { return note.deltas.filter { Region(rawValue: $0.key) != nil }.values.reduce(0, +) }
        return note.deltas[who.rawValue] ?? 0
    }

    private var amount: String {
        func signed(_ v: Double) -> String { "\(v >= 0 ? "+" : "−")\(Fmt.trim(abs(v), 1))" }
        guard who == .governments else { return signed(total) }
        return Region.allCases.compactMap { r in note.deltas[r.rawValue].map { "\(r.short) \(signed($0))" } }.prefix(3).joined(separator: " · ")
    }
}

// MARK: Rules by region

private struct RegulationCard: View {
    let state: GameState

    var body: some View {
        let w = state.world
        let past = w.history.count > 6 ? w.history[w.history.count - 7] : nil
        Card {
            CardHeader("Rules by region", symbol: "building.columns.fill",
                       subtitle: "How strict AI rules are (0–100) and where you stand with each government")
            HStack(spacing: 10) {
                Text("Region").frame(width: 120, alignment: .leading)
                Text("Rules").frame(width: 250, alignment: .leading)
                Text("6 months").frame(width: 64, alignment: .leading)
                Spacer()
                Text("Your standing").frame(width: 170, alignment: .leading)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Region.allCases) { r in
                RegionRow(state: state, region: r, before: past.flatMap { $0.strictness.indices.contains(r.index) ? $0.strictness[r.index] : nil })
            }
            Text("Each region follows its real course to 2026. Fear of AI and a sour public tighten the rules; in the US, the laws that pass and the industry's lobbying move them too. Strict rules slow adoption in healthcare, finance and government. Low standing makes regulators more likely to come after you when something goes wrong.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RegionRow: View {
    let state: GameState
    let region: Region
    let before: Double?

    var body: some View {
        let w = state.world
        let v = w.strictness(region)
        let g = w.government(region)
        let t = Stakeholders.governmentTarget(state, region)
        HStack(spacing: 10) {
            Text(region.title).font(.callout).frame(width: 120, alignment: .leading)
            HStack(spacing: 8) {
                Meter(value: v / 100, tint: WorldTint.strictness(v), height: 7).frame(width: 110)
                Text("\(Int(v.rounded())) · \(World.strictnessLabel(v))").font(.caption.monospacedDigit())
            }
            .frame(width: 250, alignment: .leading)
            Text(change(v)).font(.caption.monospacedDigit()).foregroundStyle(v - (before ?? v) >= 1 ? .orange : .secondary).frame(width: 64, alignment: .leading)
            Spacer()
            HStack(spacing: 6) {
                Meter(value: g / 100, tint: WorldTint.standing(g), height: 6).frame(width: 60)
                Text("\(Int(g.rounded())) · \(World.standingLabel(g))").font(.caption.monospacedDigit())
            }
            .frame(width: 170, alignment: .leading)
            .help("Heading toward \(Int(t.value.rounded())): " + t.parts.map { "\($0.label) \($0.value >= 0 ? "+" : "−")\(Fmt.trim(abs($0.value), 0))" }.joined(separator: ", "))
        }
    }

    private func change(_ v: Double) -> String {
        guard let b = before else { return "—" }
        let d = v - b
        return abs(d) < 1 ? "steady" : "\(d >= 0 ? "+" : "−")\(Int(abs(d).rounded()))"
    }
}

// MARK: Adoption, jobs, energy

private struct AdoptionList: View {
    let world: WorldState

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 6) {
            ForEach(Sector.allCases) { sector in
                HStack(spacing: 6) {
                    Image(systemName: sector.symbol).font(.caption).foregroundStyle(.secondary).frame(width: 16)
                    Text(sector.title).font(.caption)
                    Spacer(minLength: 2)
                    Text(Fmt.pct(world.adoption(sector), decimals: 0)).font(.caption.monospacedDigit().weight(.semibold))
                }
            }
        }
    }
}

private struct JobsCard: View {
    let state: GameState

    var body: some View {
        let w = state.world
        let share = Stakeholders.automationShare(state)
        Card {
            CardHeader("Jobs", symbol: "person.2.badge.gearshape.fill", subtitle: "Workers whose jobs AI can reach: about \(Int(Sector.totalWorkforce / 1_000)) billion worldwide")
            HStack(spacing: 10) {
                JobFigure(label: "Work done by AI", value: Fmt.pct(w.tasks, decimals: 1))
                JobFigure(label: "Jobs lost to AI", value: "\(Fmt.trim(w.displaced, 0))M")
                JobFigure(label: "Jobs AI created", value: "\(Fmt.trim(w.newJobs, 0))M")
                JobFigure(label: "Still looking", value: "\(Fmt.trim(w.looking, 1))M")
            }
            WorldHistoryChart(kind: .work, history: w.history)
                .equatable()
                .frame(height: 150)
            Text(pressureText(w.jobPressure)).font(.caption).foregroundStyle(w.jobPressure >= Consequences.jobThresholds[0] ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            if share >= 0.01 {
                Text("Your agents do about \(Fmt.pct(share, decimals: 0)) of the world's agent work. Past 12%, protesters name you, and the public blames you for job losses.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pressureText(_ p: Double) -> String {
        let t = Consequences.jobThresholds
        let now = "\(Fmt.trim(p, 2))% of those workers are out of work because of AI."
        if p >= t[2] { return now + " Past \(Fmt.trim(t[2], 1))% a robot tax gets debated." }
        if p >= t[1] { return now + " Strikes are likely; past \(Fmt.trim(t[2], 1))% a robot tax gets debated." }
        if p >= t[0] { return now + " Protests are under way; strikes come past \(Fmt.trim(t[1], 1))%." }
        return now + " Protests start past \(Fmt.trim(t[0], 1))%."
    }
}

private struct JobFigure: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EnergyCard: View {
    let state: GameState
    let mine: Double

    var body: some View {
        let w = state.world
        let myShare = w.computeH100e > 0 ? min(1, mine / w.computeH100e) : 0
        Card {
            CardHeader("Energy and compute", symbol: "bolt.fill", subtitle: "The world's AI fleet and what it draws from the grid")
            HStack(spacing: 10) {
                JobFigure(label: "AI power draw", value: "\(Fmt.trim(w.powerGW, w.powerGW < 10 ? 1 : 0)) GW")
                JobFigure(label: "Of world electricity", value: Fmt.pct(w.aiShare, decimals: 1))
                JobFigure(label: "World AI compute", value: "\(Fmt.count(w.computeH100e)) H100e")
                JobFigure(label: "Yours", value: Fmt.pct(myShare, decimals: myShare < 0.1 ? 1 : 0))
            }
            WorldHistoryChart(kind: .power, history: w.history)
                .equatable()
                .frame(height: 150)
            HStack(spacing: 8) {
                Text("Grid stress").font(.caption)
                Meter(value: w.gridStress / 100, tint: WorldTint.strictness(w.gridStress), height: 7).frame(width: 140)
                Text("\(Int(w.gridStress.rounded())) · \(World.gridLabel(w.gridStress))").font(.caption.monospacedDigit())
            }
            Text("Stress grows with AI's share of the grid and how fast it climbs; heatwaves and gas shocks add to it, new power sources ease it. A strained grid brings emergencies, permit freezes and moratorium bills.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: What happened

private struct ConsequencesCard: View {
    let world: WorldState

    var body: some View {
        Card {
            CardHeader("What followed", symbol: "arrow.triangle.branch",
                       subtitle: "Consequences of the state of the world, not dice rolls — a handful a year at most")
            if world.consequences.isEmpty {
                Text("Nothing yet. Big incidents bring regulators, job losses bring protests and a robot-tax debate, grid strain brings emergencies and moratoria, very capable AI brings an AGI debate, and rising trust brings partnership offers.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(world.consequences.prefix(8).enumerated()), id: \.offset) { _, n in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(n.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 82, alignment: .leading)
                    Text(n.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !world.log.isEmpty {
                Divider()
                Text("What moved the world").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(world.log.prefix(6).enumerated()), id: \.offset) { _, n in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(n.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 82, alignment: .leading)
                        Text(n.text).font(.caption).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(WorldNotes.effects(n)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct LabTrustCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let labs = s.world.labTrust.sorted { $0.value > $1.value }.prefix(8)
        Card {
            CardHeader("Labs the public trusts", symbol: "hand.thumbsup.fill", subtitle: "Public trust in each lab, 0–100")
            HStack(spacing: 8) {
                Text(s.companyName).font(.caption.weight(.bold)).frame(width: 150, alignment: .leading).lineLimit(1)
                Meter(value: s.world.publicTrust / 100, tint: .accentColor, height: 7)
                Text("\(Int(s.world.publicTrust.rounded()))").font(.caption.monospacedDigit().weight(.bold)).frame(width: 28, alignment: .trailing)
            }
            ForEach(Array(labs), id: \.key) { lab in
                let def = CompetitorCatalog.def(lab.key)
                HStack(spacing: 8) {
                    Text(def.name).font(.caption).frame(width: 150, alignment: .leading).lineLimit(1)
                    Meter(value: lab.value / 100, tint: Theme.competitorColor(def.color), height: 7)
                    Text("\(Int(lab.value.rounded()))").font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                }
            }
            Text("A lab's name, culture and turmoil set its trust; its incidents knock it down. Yours is your public trust above.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Dashboard card

/// The world in one card, for the dashboard: mood, concern, your standing and the latest consequence.
struct WorldCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let w = s.world
        Card {
            CardHeader(title: "The world", symbol: "globe.americas.fill") {
                Button("World & Standing") { store.open(.world) }.buttonStyle(.link)
            }
            if w.ready {
                HStack(spacing: 14) {
                    WorldFigure(label: "Public mood", value: w.sentiment, text: World.moodLabel(w.sentiment), tint: w.sentiment >= 50 ? .green : .orange)
                    WorldFigure(label: "Safety concern", value: w.concern, text: World.concernLabel(w.concern), tint: w.concern >= 50 ? .red : .orange)
                    WorldFigure(label: "Your public trust", value: w.publicTrust, text: World.standingLabel(w.publicTrust), tint: WorldTint.standing(w.publicTrust))
                }
                HStack(spacing: 12) {
                    Text("Researchers \(Int(w.researchers.rounded()))").font(.caption)
                    Text("Developers \(Int(w.developers.rounded()))").font(.caption)
                    Text("Governments \(Int(w.governmentAverage.rounded()))").font(.caption)
                    Spacer()
                    Text("AI does \(Fmt.pct(w.tasks, decimals: 0)) of reachable work").font(.caption).foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
                if let c = w.consequences.first, GameCalendar.daysBetween(c.date, s.date) <= 120 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.triangle.branch").font(.caption).foregroundStyle(.orange)
                        Text(c.text).font(.callout).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(c.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                } else if let n = w.notes.first {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.checkmark").font(.caption).foregroundStyle(.secondary)
                        Text(n.text).font(.callout).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(n.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("The world updates at the end of each month.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private struct WorldFigure: View {
    let label: String
    let value: Double
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(value.rounded()))").font(.title3.weight(.semibold).monospacedDigit())
                Text(text).font(.caption).foregroundStyle(tint)
            }
            Meter(value: value / 100, tint: tint, height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Charts

/// Monthly world history as lines. Redraws only when a month is added.
struct WorldHistoryChart: View, Equatable {
    enum Kind { case adoption, mood, work, power }

    struct Point: Identifiable {
        let id: Int
        let date: Date
        let series: String
        let value: Double
    }

    let kind: Kind
    let history: [WorldSnapshot]

    static func == (a: WorldHistoryChart, b: WorldHistoryChart) -> Bool {
        a.kind == b.kind && a.history.count == b.history.count && a.history.last?.month == b.history.last?.month
    }

    var body: some View {
        let pts = points()
        if pts.isEmpty {
            Text("No history yet.").font(.caption).foregroundStyle(.secondary)
        } else if kind == .adoption || kind == .mood {
            Chart(pts) { p in
                LineMark(x: .value("Month", p.date), y: .value("Value", p.value))
                    .foregroundStyle(by: .value("Series", p.series))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...100)
            .chartLegend(position: .bottom, alignment: .leading)
        } else {
            Chart(pts) { p in
                LineMark(x: .value("Month", p.date), y: .value("Value", p.value))
                    .foregroundStyle(by: .value("Series", p.series))
                    .interpolationMethod(.monotone)
            }
            .chartLegend(position: .bottom, alignment: .leading)
        }
    }

    /// Every second month (and the latest), so a long game stays light to draw.
    func points() -> [Point] {
        var out: [Point] = []
        let last = history.count - 1
        for (i, h) in history.enumerated() where i % 2 == last % 2 {
            func add(_ series: String, _ v: Double) { out.append(Point(id: out.count, date: h.month, series: series, value: v)) }
            switch kind {
            case .adoption:
                for sector in Sector.allCases where h.adoption.indices.contains(sector.index) { add(sector.title, h.adoption[sector.index]) }
            case .mood:
                add("Public mood", h.sentiment)
                add("Safety concern", h.concern)
                if h.standing.count == 5 { add("Your public trust", h.standing[0]) }
            case .work:
                add("Work done by AI (%)", h.tasks)
                add("Out of work because of AI (millions)", h.looking)
            case .power:
                add("AI power draw (GW)", h.powerGW)
            }
        }
        return out
    }
}

// MARK: - Helpers

enum WorldTint {
    static func standing(_ v: Double) -> Color { v >= 60 ? .green : (v >= 45 ? .blue : (v >= 30 ? .orange : .red)) }
    static func strictness(_ v: Double) -> Color { v >= 70 ? .red : (v >= 45 ? .orange : (v >= 25 ? .yellow : .green)) }
}

enum WorldTrend {
    /// Change in a world figure against `months` ago (nil without enough history).
    static func change(_ history: [WorldSnapshot], months: Int, _ value: (WorldSnapshot) -> Double) -> Double? {
        guard history.count > months, let now = history.last else { return nil }
        return value(now) - value(history[history.count - 1 - months])
    }

    /// Change in a standing (Stakeholder order) against three months ago.
    static func standing(_ history: [WorldSnapshot], _ index: Int, now: Double) -> Double? {
        let rows = history.filter { $0.standing.count == 5 }
        guard rows.count > 3 else { return nil }
        return now - rows[rows.count - 4].standing[index]
    }
}

enum WorldNotes {
    /// "concern +5 · mood −2 · EU +3" for a world note.
    static func effects(_ n: WorldNote) -> String {
        func signed(_ v: Double) -> String { "\(v >= 0 ? "+" : "−")\(Fmt.trim(abs(v), 0))" }
        var parts: [String] = []
        if let c = n.deltas["concern"] { parts.append("concern \(signed(c))") }
        if let m = n.deltas["mood"] { parts.append("mood \(signed(m))") }
        if let g = n.deltas["grid"] { parts.append("grid \(signed(g))") }
        let regions = Region.allCases.compactMap { r in n.deltas[r.rawValue].map { "\(r.short) rules \(signed($0))" } }
        if regions.count >= 5 { parts.append("rules everywhere \(signed(n.deltas[Region.us.rawValue] ?? 0))") } else { parts += regions }
        return parts.prefix(3).joined(separator: " · ")
    }
}
