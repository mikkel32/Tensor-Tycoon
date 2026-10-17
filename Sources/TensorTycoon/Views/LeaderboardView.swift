import Charts
import SwiftUI

/// The AI race, labs first: one row per lab (its flagship model), every model one click away.
struct LeaderboardView: View {
    @Environment(GameStore.self) private var store
    @State private var showLabs = true
    @State private var labSort = "rank"
    @State private var sortKey = "index"
    @State private var weights: Leaderboard.Filter.Weights = .any
    @State private var reasoningOnly = false
    @State private var band: Leaderboard.Filter.Band = .any
    @State private var expanded: Set<String> = []

    var body: some View {
        let s = store.game
        let d = store.derived
        let set = d.indexSet
        let filter = Leaderboard.Filter(weights: weights, reasoningOnly: reasoningOnly, band: band, year: s.year)
        let labs = Leaderboard.labs(d.board, state: s)
        let gone = Leaderboard.goneLabs(s)
        let standing = Leaderboard.standing(labs, board: d.board, gone: gone)
        let leader = labs.filter { $0.rank == 1 }.max { $0.flagship.capability < $1.flagship.capability }
        let race = Leaderboard.race(labs, today: s.date)
        let colors = labColors(labs, s)

        return Page(title: "Leaderboard", subtitle: "The AI race, lab by lab: each lab's flagship model, ranked by Intelligence Index, with a capability score that stays comparable across years.") {
            StandingCard(standing: standing)
            HStack(alignment: .top, spacing: 16) {
                Card {
                    CardHeader("The race", symbol: "chart.line.uptrend.xyaxis", subtitle: "Flagship capability of the leading labs over the last four years")
                    RaceChart(points: race.points, colors: colors)
                        .equatable()
                        .frame(height: 230)
                    RaceLegend(series: race.series, colors: colors)
                }
                ReadingGuide(set: set, saturated: s.benchSaturated)
                    .frame(width: 430)
            }
            controls(filter)
            if showLabs {
                LabTable(lines: lines(labs, filter), leader: leader, now: s.date, colors: colors, expanded: $expanded)
            } else {
                modelTable(d, set: set, f: filter, colors: colors)
            }
            footnote(s, gone: gone)
        }
    }

    private func controls(_ filter: Leaderboard.Filter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Picker("Show", selection: $showLabs) {
                    Text("Labs").tag(true)
                    Text("All models").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                Spacer()
                sortPicker
            }
            HStack(spacing: 14) {
                Picker("Weights", selection: $weights) {
                    Text("Open & closed").tag(Leaderboard.Filter.Weights.any)
                    Text("Open weights").tag(Leaderboard.Filter.Weights.open)
                    Text("Closed").tag(Leaderboard.Filter.Weights.closed)
                }
                .frame(width: 210)
                Toggle("Reasoning models", isOn: $reasoningOnly).toggleStyle(.switch)
                Picker("Price", selection: $band) {
                    ForEach(Leaderboard.Filter.Band.allCases) { b in Text(filter.label(b)).tag(b) }
                }
                .frame(width: 230)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var sortPicker: some View {
        if showLabs {
            Picker("Sort by", selection: $labSort) {
                Text("Rank").tag("rank")
                Text("Capability").tag("capability")
                Text("Biggest movers").tag("trend")
                Text("Newest release").tag("newest")
                Text("Cheapest").tag("price")
                Text("Fastest").tag("tps")
            }
            .frame(width: 230)
        } else {
            Picker("Sort by", selection: $sortKey) {
                Text("Intelligence Index").tag("index")
                Text("Capability").tag("capability")
                ForEach(store.derived.indexSet) { b in Text(b.name).tag(b.id) }
                Text("LMArena Elo").tag("arena")
                Text("Task horizon").tag("horizon")
                Text("Newest").tag("date")
                Text("Cheapest").tag("price")
                Text("Fastest").tag("tps")
            }
            .frame(width: 260)
        }
    }

    /// One line per lab still in the race (plus yours), showing its best model that passes the filters.
    private func lines(_ labs: [Leaderboard.LabRow], _ f: Leaderboard.Filter) -> [LabLine] {
        var out: [LabLine] = []
        for r in labs where r.rank > 0 || r.isPlayer {
            if let e = r.shown(f) { out.append(LabLine(row: r, shown: e)) }
        }
        func place(_ l: LabLine) -> Int { l.row.rank > 0 ? l.row.rank : 99 }
        switch labSort {
        case "capability": out.sort { $0.shown.capability > $1.shown.capability }
        case "trend": out.sort { ($0.row.rankChange ?? -99, $0.row.capabilityGain ?? -99) > ($1.row.rankChange ?? -99, $1.row.capabilityGain ?? -99) }
        case "newest": out.sort { ($0.row.lastRelease ?? .distantPast) > ($1.row.lastRelease ?? .distantPast) }
        case "price": out.sort { ($0.shown.price ?? .infinity) < ($1.shown.price ?? .infinity) }
        case "tps": out.sort { ($0.shown.tps ?? 0) > ($1.shown.tps ?? 0) }
        default: out.sort { place($0) != place($1) ? place($0) < place($1) : $0.shown.index > $1.shown.index }
        }
        return out
    }

    private func labColors(_ labs: [Leaderboard.LabRow], _ s: GameState) -> [String: Color] {
        var out: [String: Color] = [:]
        for r in labs {
            out[r.labID] = r.isPlayer ? Theme.logoColor(s.logoColor) : (CompetitorCatalog.byID[r.labID].map { Theme.competitorColor($0.color) } ?? .gray)
        }
        return out
    }

    @ViewBuilder
    private func modelTable(_ d: Derived, set: [Benchmark], f: Leaderboard.Filter, colors: [String: Color]) -> some View {
        let cols = Array(set.prefix(4))
        let byBench = d.benchmarks.first { $0.id == sortKey }
        let entries = d.board.filter { f.includes($0) }.sorted { a, b in
            switch sortKey {
            case "capability": return a.capability > b.capability
            case "arena": return a.arena > b.arena
            case "date": return a.date > b.date
            case "price": return (a.price ?? .infinity) < (b.price ?? .infinity)
            case "tps": return (a.tps ?? 0) > (b.tps ?? 0)
            case "horizon": return a.horizon > b.horizon
            case "index": return a.index > b.index
            default:
                if let bm = byBench { return a.score(bm) > b.score(bm) }
                return a.c > b.c
            }
        }
        Card(padding: 0) {
            Table(entries) {
                TableColumn("Model") { e in
                    HStack(spacing: 8) {
                        Circle().fill(colors[e.labID] ?? .gray).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text(e.model).fontWeight(e.isPlayer ? .bold : .regular)
                                if e.open { Image(systemName: "lock.open").font(.caption2).foregroundStyle(.blue) }
                                if e.reasoning { Image(systemName: "lightbulb.max").font(.caption2).foregroundStyle(.pink) }
                                if e.isPlayer && !e.released { Text("unreleased").font(.caption2).foregroundStyle(.orange) }
                            }
                            Text("\(e.lab) · \(e.date.gameMonth)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .width(min: 180, ideal: 230)
                TableColumn("Capability") { e in Text(verbatim: "\(Int(e.capability.rounded()))").monospacedDigit().fontWeight(.semibold) }.width(72)
                TableColumn("Index") { e in Text(Fmt.score(e.index)).monospacedDigit() }.width(50)
                TableColumn(name(cols, 0)) { e in score(e, cols, 0) }.width(78)
                TableColumn(name(cols, 1)) { e in score(e, cols, 1) }.width(78)
                TableColumn(name(cols, 2)) { e in score(e, cols, 2) }.width(78)
                TableColumn(name(cols, 3)) { e in score(e, cols, 3) }.width(78)
                TableColumn("Elo") { e in Text(verbatim: "\(Int(e.arena))").monospacedDigit() }.width(48)
                TableColumn("Horizon") { e in Text(BenchmarkCatalog.formatHorizon(e.horizon)).monospacedDigit() }.width(70)
                TableColumn("Price · Speed") { e in Text(priceSpeed(e)).monospacedDigit().foregroundStyle(.secondary) }
                    .width(min: 100, ideal: 120)
            }
            .frame(minHeight: 480)
        }
    }

    private func footnote(_ s: GameState, gone: Set<String>) -> some View {
        let left = s.competitors.filter { gone.contains($0.id) }.map { "\($0.def.name) (\($0.bankrupt ? "bankrupt" : "acquired"))" }
        return VStack(alignment: .leading, spacing: 4) {
            if !left.isEmpty {
                Text("Out of the race: \(left.joined(separator: ", ")). Their models still appear under All models.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Rival labs are fictional; benchmarks and hardware are real. Task horizon = how long a task (for a human) the model completes 50% of the time, à la METR.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func name(_ cols: [Benchmark], _ i: Int) -> String { i < cols.count ? cols[i].name : "—" }

    private func score(_ e: Leaderboard.Entry, _ cols: [Benchmark], _ i: Int) -> some View {
        Text(i < cols.count ? Fmt.score(e.score(cols[i])) : "—").monospacedDigit()
    }
}

private func priceSpeed(_ e: Leaderboard.Entry) -> String {
    "\(e.price.map { Fmt.price($0) } ?? "—") · \(e.tps.map { "\(Int($0)) t/s" } ?? "—")"
}

private struct LabLine: Identifiable {
    var id: String { row.labID }
    let row: Leaderboard.LabRow
    /// The lab's best model that passes the current filters.
    let shown: Leaderboard.Entry
}

/// Where you stand, and what it would take to lead.
private struct StandingCard: View {
    let standing: Leaderboard.Standing

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your place").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: standing.rank.map { "#\($0)" } ?? "—").font(.system(size: 40, weight: .bold).monospacedDigit())
                    Text("of \(standing.labs) labs").font(.caption).foregroundStyle(.secondary)
                }
                .frame(width: 100, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text(standing.headline).font(.title3.weight(.semibold))
                    Text(standing.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let ready = standing.ready {
                        Label(ready, systemImage: "shippingbox.fill").font(.callout).foregroundStyle(.orange)
                    }
                }
                Spacer()
            }
        }
    }
}

/// A short legend for the numbers, in place.
private struct ReadingGuide: View {
    let set: [Benchmark]
    let saturated: [String: Date]

    var body: some View {
        let now = set.map { b -> String in
            if let bl = b.blend { return "\(b.name) \(Int((bl.t * 100).rounded()))%" }
            return saturated[b.id] != nil ? "\(b.name) (saturated, rotating out)" : b.name
        }
        Card {
            CardHeader("How to read this", symbol: "questionmark.circle")
            GuideRow(symbol: "function", title: "Intelligence Index",
                     text: "The average score on ten text benchmarks, from the hardest frontier test to nearly saturated ones: about 50 is level with the field, higher is ahead. Once two labs pass a benchmark's saturation line it rotates out as soon as a successor is ready, one at a time, and the newcomer phases in over eight weeks, so a model's index drifts down gently as the bar rises.")
            Text("In the index now: \(now.joined(separator: " · "))")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            GuideRow(symbol: "ruler", title: "Capability",
                     text: "A fixed yardstick: GPT-4 (2023) = 100, and every +10 is ten times the effective compute, averaged over the index's eight skills. It never re-bases, so compare it across years. The gap to #1 says how much more compute closing it takes.")
            GuideRow(symbol: "trophy", title: "Rank",
                     text: "Place among labs still in the race, by each lab's flagship index: the same rank the Dashboard, the news and the monthly briefing use. Arrows compare with a quarter ago, on today's benchmarks.")
        }
    }
}

private struct GuideRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Step lines of each leading lab's best released capability; yours drawn thicker.
struct RaceChart: View, Equatable {
    let points: [Leaderboard.RacePoint]
    let colors: [String: Color]

    var body: some View {
        if points.isEmpty {
            Text("Each lab's flagship capability appears here as models ship.")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Capability", p.capability), series: .value("Lab", p.labID))
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(colors[p.labID] ?? Color.gray)
                    .lineStyle(StrokeStyle(lineWidth: p.isPlayer ? 3.5 : 1.5))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel("Capability")
        }
    }
}

private struct RaceLegend: View {
    let series: [Leaderboard.RaceSeries]
    let colors: [String: Color]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(series) { sr in
                HStack(spacing: 5) {
                    Circle().fill(colors[sr.id] ?? Color.gray).frame(width: 8, height: 8)
                    Text(sr.lab).font(.caption.weight(sr.isPlayer ? .bold : .regular)).lineLimit(1)
                    Text(verbatim: "\(Int(sr.capability.rounded()))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LabTable: View {
    let lines: [LabLine]
    let leader: Leaderboard.LabRow?
    let now: Date
    let colors: [String: Color]
    @Binding var expanded: Set<String>

    var body: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                LabHeader()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                Divider()
                if lines.isEmpty {
                    Text("No lab has a model that matches these filters.")
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(14)
                }
                ForEach(lines) { line in
                    LabRowView(line: line, leader: leader, now: now, color: colors[line.id] ?? Color.gray, isExpanded: expanded.contains(line.id)) {
                        if expanded.contains(line.id) { expanded.remove(line.id) } else { expanded.insert(line.id) }
                    }
                    Divider()
                }
            }
        }
    }
}

private struct LabHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Rank").frame(width: 70, alignment: .leading)
                .help("Place among labs still in the race, by flagship Intelligence Index. Arrows: change since a quarter ago, on today's benchmarks.")
            Text("Lab · flagship").frame(maxWidth: .infinity, alignment: .leading)
            Text("Capability").frame(width: 104, alignment: .trailing)
                .help("Fixed yardstick: GPT-4 = 100, and +10 is ten times the effective compute. Below it: the gain over the last quarter.")
            Text("Index").frame(width: 56, alignment: .trailing)
                .help("Intelligence Index: the average score on the ten benchmarks in the index today. About 50 is level with the field.")
            Text("vs #1").frame(width: 84, alignment: .trailing)
                .help("Capability gap to the #1 lab's flagship (+10 = ten times the effective compute).")
            Text("Price · speed").frame(width: 140, alignment: .trailing)
            Text("Last release").frame(width: 110, alignment: .trailing)
            Spacer().frame(width: 14)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

private struct LabRowView: View {
    let line: LabLine
    let leader: Leaderboard.LabRow?
    let now: Date
    let color: Color
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        let r = line.row
        let e = line.shown
        VStack(alignment: .leading, spacing: 6) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    RankCell(row: r).frame(width: 70, alignment: .leading)
                    HStack(spacing: 8) {
                        Circle().fill(color).frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.lab).fontWeight(r.isPlayer ? .bold : .semibold)
                            HStack(spacing: 4) {
                                Text(e.model).font(.caption).foregroundStyle(.secondary)
                                if e.open { Image(systemName: "lock.open").font(.caption2).foregroundStyle(.blue) }
                                if e.reasoning { Image(systemName: "lightbulb.max").font(.caption2).foregroundStyle(.pink) }
                                if !e.released { Text("unreleased").font(.caption2).foregroundStyle(.orange) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(verbatim: "\(Int(e.capability.rounded()))").monospacedDigit().fontWeight(.semibold)
                        if let g = r.capabilityGain, g >= 0.5 {
                            Text(verbatim: "+\(Fmt.trim(g, 1)) this quarter").font(.caption2).foregroundStyle(.green)
                        }
                    }
                    .frame(width: 104, alignment: .trailing)
                    Text(Fmt.score(e.index)).monospacedDigit().frame(width: 56, alignment: .trailing)
                    Text(gap(e)).font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 84, alignment: .trailing)
                    Text(priceSpeed(e)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 140, alignment: .trailing)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(r.lastRelease.map { $0.gameMonth } ?? "—").font(.caption)
                        if let d = r.lastRelease {
                            Text(Leaderboard.ago(d, now: now)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 110, alignment: .trailing)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.secondary).frame(width: 14)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if isExpanded {
                ModelHistory(models: r.models, now: now)
                    .padding(.leading, 80)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(r.isPlayer ? Color.accentColor.opacity(0.07) : Color.clear)
    }

    private func gap(_ e: Leaderboard.Entry) -> String {
        guard let l = leader else { return "—" }
        if l.labID == line.row.labID { return "#1" }
        let g = e.capability - l.flagship.capability
        return g >= 0 ? "+\(Fmt.trim(g, 1))" : Fmt.trim(g, 1)
    }
}

private struct RankCell: View {
    let row: Leaderboard.LabRow

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: row.rank > 0 ? "\(row.rank)" : "—").font(.title3.monospacedDigit().weight(.bold))
            if let c = row.rankChange {
                if c > 0 {
                    Text(verbatim: "▲\(c)").font(.caption2.weight(.semibold)).foregroundStyle(.green)
                } else if c < 0 {
                    Text(verbatim: "▼\(-c)").font(.caption2.weight(.semibold)).foregroundStyle(.red)
                } else {
                    Text(verbatim: "–").font(.caption2).foregroundStyle(.secondary)
                }
            } else if row.rank > 0 {
                Text("new").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// A lab's models, newest first.
private struct ModelHistory: View {
    let models: [Leaderboard.Entry]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(models.prefix(12)) { m in
                HStack(spacing: 10) {
                    Text(m.model).font(.caption.weight(.medium)).lineLimit(1).frame(width: 170, alignment: .leading)
                    Text(m.date.gameMonth).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                    if m.open { Image(systemName: "lock.open").font(.caption2).foregroundStyle(.blue) }
                    if m.reasoning { Image(systemName: "lightbulb.max").font(.caption2).foregroundStyle(.pink) }
                    if !m.released { Text("unreleased").font(.caption2).foregroundStyle(.orange) }
                    Spacer()
                    Text(verbatim: "capability \(Int(m.capability.rounded()))").font(.caption.monospacedDigit())
                    Text(verbatim: "index \(Fmt.score(m.index))").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 76, alignment: .trailing)
                    Text(priceSpeed(m)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 140, alignment: .trailing)
                }
            }
            if models.count > 12 {
                Text("…and \(models.count - 12) older models under All models.").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
