import Charts
import SwiftUI

struct LeaderboardView: View {
    @Environment(GameStore.self) private var store
    @State private var latestOnly = true
    @State private var sortKey = "index"

    var body: some View {
        let s = store.game
        let d = store.derived
        let set = d.indexSet
        var entries = d.board
        if latestOnly {
            var seen = Set<String>()
            entries = entries.sorted { $0.date > $1.date }.filter { e in
                if e.isPlayer { return true }
                return seen.insert(e.labID).inserted
            }
        }
        let cols = Array(set.prefix(5))
        let byBench = d.benchmarks.first { $0.id == sortKey }
        entries.sort { a, b in
            switch sortKey {
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

        return Page(title: "Leaderboard", subtitle: "Every model in the world, scored on real benchmarks. The Intelligence Index averages 10 live benchmarks from the hardest to the nearly-saturated — when one saturates it retires and a harder successor eventually takes its place.") {
            Card {
                CardHeader(title: "Capability over time", symbol: "chart.dots.scatter") {
                    Button("Benchmarks") { store.open(.benchmarks) }.buttonStyle(.link)
                }
                ScatterChart(points: d.board.filter { $0.date > GameCalendar.addMonths(s.date, -60) }.map {
                    ScatterChart.Point(id: $0.id, date: $0.date, index: $0.index, lab: $0.lab, isPlayer: $0.isPlayer)
                })
                .equatable()
                .frame(height: 220)
            }
            HStack {
                Toggle("Latest model per lab", isOn: $latestOnly).toggleStyle(.switch)
                Spacer()
                Picker("Sort by", selection: $sortKey) {
                    Text("Intelligence Index").tag("index")
                    ForEach(set) { b in Text(b.name).tag(b.id) }
                    Text("LMArena Elo").tag("arena")
                    Text("Task horizon").tag("horizon")
                    Text("Newest").tag("date")
                    Text("Cheapest").tag("price")
                    Text("Fastest").tag("tps")
                }
                .frame(width: 260)
            }
            Card(padding: 0) {
                Table(entries) {
                    TableColumn("Model") { e in
                        HStack(spacing: 8) {
                            Circle().fill(color(e, s)).frame(width: 8, height: 8)
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
                    TableColumn("Index") { e in Text(Fmt.score(e.index)).monospacedDigit().fontWeight(.semibold) }.width(50)
                    TableColumn(name(cols, 0)) { e in score(e, cols, 0) }.width(78)
                    TableColumn(name(cols, 1)) { e in score(e, cols, 1) }.width(78)
                    TableColumn(name(cols, 2)) { e in score(e, cols, 2) }.width(78)
                    TableColumn(name(cols, 3)) { e in score(e, cols, 3) }.width(78)
                    TableColumn(name(cols, 4)) { e in score(e, cols, 4) }.width(78)
                    TableColumn("Elo") { e in Text(verbatim: "\(Int(e.arena))").monospacedDigit() }.width(48)
                    TableColumn("Horizon") { e in Text(BenchmarkCatalog.formatHorizon(e.horizon)).monospacedDigit() }.width(70)
                    TableColumn("Price · Speed") { e in
                        Text("\(e.price.map { Fmt.price($0) } ?? "—") · \(e.tps.map { "\(Int($0)) t/s" } ?? "—")").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 120)
                }
                .frame(minHeight: 480)
            }
            Text("Rival labs are fictional; benchmarks and hardware are real. Task horizon = how long a task (for a human) the model completes 50% of the time, à la METR.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func name(_ cols: [Benchmark], _ i: Int) -> String { i < cols.count ? cols[i].name : "—" }

    private func score(_ e: Leaderboard.Entry, _ cols: [Benchmark], _ i: Int) -> some View {
        Text(i < cols.count ? Fmt.score(e.score(cols[i])) : "—").monospacedDigit()
    }

    private func color(_ e: Leaderboard.Entry, _ s: GameState) -> Color {
        if e.isPlayer { return Theme.logoColor(s.logoColor) }
        return CompetitorCatalog.byID[e.labID].map { Theme.competitorColor($0.color) } ?? .gray
    }
}

struct ScatterChart: View, Equatable {
    struct Point: Identifiable, Equatable {
        let id: String
        let date: Date
        let index: Double
        let lab: String
        let isPlayer: Bool
    }
    let points: [Point]

    var body: some View {
        Chart(points) { p in
            PointMark(x: .value("Date", p.date), y: .value("Index", p.index))
                .foregroundStyle(by: .value("Lab", p.lab))
                .symbolSize(p.isPlayer ? 120 : 45)
        }
        .chartYScale(domain: 0...100)
    }
}
