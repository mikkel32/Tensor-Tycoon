import Charts
import SwiftUI

struct BenchmarksView: View {
    @Environment(GameStore.self) private var store
    @State private var selected: Benchmark? = nil
    @State private var kindFilter: BenchKind? = nil
    @State private var query = ""
    @State private var liveOnly = false

    var body: some View {
        let s = store.game
        let d = store.derived
        let all = d.benchmarks
        let released = d.board.filter(\.released)
        let mine = d.board.filter(\.isPlayer)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let visible = all.filter { b in
            (kindFilter == nil || b.kind == kindFilter)
                && (!liveOnly || b.isActive(s.date, saturated: s.benchSaturated))
                && (q.isEmpty || b.name.lowercased().contains(q) || b.about.lowercased().contains(q))
        }
        let families = Dictionary(grouping: visible, by: \.family)
            .sorted { ($0.value.map(\.mid).max() ?? 0) > ($1.value.map(\.mid).max() ?? 0) }
        let active = all.filter { $0.isActive(s.date, saturated: s.benchSaturated) }
        Page(title: "Benchmarks", subtitle: "Real benchmarks from SQuAD to ARC-AGI-3 — knowledge, math, code, agents, vision, speech, long context, instruction following, safety and dangerous capabilities. When models from two labs pass a benchmark's saturation line it retires, and a harder successor pitched at the field appears.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                StatTile(title: "Benchmarks tracked", value: "\(all.count)", detail: "\(all.filter(\.generated).count) created during your game", symbol: "checklist", tint: .blue)
                StatTile(title: "Live", value: "\(active.count)", detail: "Not yet saturated", symbol: "flame.fill", tint: .orange)
                StatTile(title: "Saturated", value: "\(s.benchSaturated.count)", detail: "Rotate out of the index as successors arrive", symbol: "checkmark.seal.fill", tint: .green)
                StatTile(title: "Upcoming", value: "\(all.filter { $0.introduced > s.date.ym }.count)", detail: "Announced, not released", symbol: "calendar.badge.clock", tint: .purple)
            }

            HStack(alignment: .top, spacing: 16) {
                Card {
                    CardHeader("Intelligence Index — current composition", symbol: "function",
                               subtitle: "10 text benchmarks from the hardest to nearly saturated. A saturated one stays until a successor is ready; slots rotate one at a time and a newcomer phases in over eight weeks.")
                    ForEach(d.indexSet) { b in
                        let sota = best(b, in: released)
                        let you = best(b, in: mine)
                        let retiring = s.benchSaturated[b.id] != nil
                        Button { selected = all.first { $0.id == b.id } ?? b } label: {
                            HStack(spacing: 10) {
                                Image(systemName: b.kind.symbol).foregroundStyle(b.kind.color).frame(width: 18)
                                Text(b.name).font(.callout.weight(.medium)).lineLimit(1).frame(width: 190, alignment: .leading)
                                Meter(value: ((sota?.1 ?? 0) - b.floor) / max(1, b.ceiling - b.floor), tint: .orange, height: 8)
                                Text("SOTA \(b.format(sota?.1 ?? 0))").font(.caption.monospacedDigit()).frame(width: 84, alignment: .trailing)
                                Text("You \(you.map { b.format($0.1) } ?? "—")").font(.caption.monospacedDigit()).foregroundStyle(Color.accentColor).frame(width: 74, alignment: .trailing)
                                if let bl = b.blend {
                                    Text(verbatim: "\(Int((bl.t * 100).rounded()))% in").font(.caption2).foregroundStyle(.purple).frame(width: 62, alignment: .trailing)
                                        .help("Phasing in until \(bl.full.gameShort): its slot still partly scores \(bl.from.map(\.name).joined(separator: ", ")). Scores here are the blend.")
                                } else if retiring {
                                    Text("Saturated").font(.caption2).foregroundStyle(.green).frame(width: 62, alignment: .trailing)
                                        .help("Saturated: it leaves the index when a successor is ready.")
                                } else {
                                    Text("Live").font(.caption2).foregroundStyle(.secondary).frame(width: 62, alignment: .trailing)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                FrontierSafetyCard(state: s, released: released, mine: mine)
                    .frame(width: 420)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("All benchmarks").font(.title2.weight(.bold))
                    Text("\(visible.count) shown").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    TextField("Search benchmarks", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                    Toggle("Live only", isOn: $liveOnly).toggleStyle(.switch)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        KindChip(label: "All", symbol: "square.grid.2x2", count: all.count, color: .accentColor, selected: kindFilter == nil) { kindFilter = nil }
                        ForEach(BenchKind.allCases, id: \.self) { k in
                            let n = all.filter { $0.kind == k }.count
                            if n > 0 {
                                KindChip(label: k.label, symbol: k.symbol, count: n, color: k.color, selected: kindFilter == k) {
                                    kindFilter = kindFilter == k ? nil : k
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 14, alignment: .top)], spacing: 14) {
                ForEach(families, id: \.key) { fam in
                    let members = fam.value.sorted { $0.introduced < $1.introduced }
                    Card {
                        CardHeader(title: BenchmarkCatalog.families[fam.key]?.name ?? fam.key, symbol: members.first?.kind.symbol) {
                            if BenchmarkCatalog.families[fam.key]?.regenerates == true {
                                Pill(text: "Regenerates", color: .purple, symbol: "arrow.triangle.2.circlepath")
                            }
                        }
                        ForEach(members) { b in
                            BenchRow(bench: b, state: s, sota: best(b, in: released), you: best(b, in: mine)) { selected = b }
                        }
                    }
                }
            }
            if families.isEmpty {
                Text("No benchmarks match.").foregroundStyle(.secondary)
            }
        }
        .sheet(item: $selected) { b in BenchmarkDetail(bench: b) }
    }

    private func best(_ b: Benchmark, in entries: [Leaderboard.Entry]) -> (Leaderboard.Entry, Double)? {
        var out: (Leaderboard.Entry, Double)? = nil
        for e in entries {
            let v = e.score(b)
            if v > (out?.1 ?? -1) { out = (e, v) }
        }
        return out
    }
}

private struct KindChip: View {
    let label: String
    let symbol: String
    let count: Int
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                Text(label)
                Text("\(count)").foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? .white : color)
            .background(selected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.12)), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

/// Where the world's best model and yours sit against the frontier-safety thresholds.
private struct FrontierSafetyCard: View {
    let state: GameState
    let released: [Leaderboard.Entry]
    let mine: [Leaderboard.Entry]

    var body: some View {
        let world = released.filter { !$0.isPlayer }.max { SafetyFramework.dangerX($0.profile) < SafetyFramework.dangerX($1.profile) }
        let yours = mine.max { SafetyFramework.dangerX($0.profile) < SafetyFramework.dangerX($1.profile) }
        let yourModel = yours.flatMap { e in state.models.first { $0.id.uuidString == e.profile.key } }
        Card {
            CardHeader(title: "Frontier safety thresholds", symbol: "exclamationmark.shield.fill", subtitle: "Dangerous-capability evals (WMDP, Cybench, VCT…) decide what a release needs") { HelpButton(term: .safetyThresholds) }
            DangerGauge(world: world.map { SafetyFramework.dangerX($0.profile) }, yours: yours.map { SafetyFramework.dangerX($0.profile) })
                .frame(height: 64)
            if let world {
                let t = SafetyFramework.tier(world.profile)
                HStack {
                    Text("World's most capable: \(world.model)").font(.caption)
                    Spacer()
                    Pill(text: t.label, color: t.color)
                }
            }
            if let yours {
                let t = SafetyFramework.tier(yours.profile)
                HStack {
                    Text("Yours: \(yours.model)").font(.caption)
                    Spacer()
                    Pill(text: t.label, color: t.color)
                }
                if let m = yourModel, t >= .high {
                    let ok = m.safety >= t.requiredSafety
                    Label(ok ? "Safety \(Int(m.safety)) meets the bar (\(Int(t.requiredSafety))) — ships with safeguards (a bit slower to serve)."
                             : "Safety \(Int(m.safety)) is below the bar (\(Int(t.requiredSafety))). Releasing it anyway costs brand and invites incidents.",
                          systemImage: ok ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(ok ? .green : .red)
                }
            }
            Text("Modelled on Anthropic's RSP, OpenAI's Preparedness Framework and Google DeepMind's Frontier Safety Framework. Raise model safety with the safety post-training stage, RLHF, a safety team and safety research.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DangerGauge: View {
    let world: Double?
    let yours: Double?

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(LinearGradient(colors: [.green.opacity(0.5), .yellow.opacity(0.6), .orange.opacity(0.7), .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                    .offset(y: 26)
                ForEach(SafetyFramework.thresholds, id: \.0) { t in
                    let x = w * SafetyFramework.gauge(t.1)
                    Rectangle().fill(.primary.opacity(0.6)).frame(width: 1.5, height: 18).position(x: x, y: 31)
                    Text(t.0 == .earlyWarning ? "Early" : (t.0 == .high ? "ASL-3" : "ASL-4"))
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).fixedSize()
                        .position(x: x, y: 50)
                }
                if let world {
                    marker("World", color: .secondary, x: w * SafetyFramework.gauge(world), y: 10)
                }
                if let yours {
                    marker("You", color: .accentColor, x: w * SafetyFramework.gauge(yours), y: 10)
                }
            }
        }
    }

    private func marker(_ text: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(text).font(.system(size: 9, weight: .bold)).foregroundStyle(color).fixedSize()
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(color)
        }
        .position(x: x, y: y)
    }
}

private struct BenchRow: View {
    let bench: Benchmark
    let state: GameState
    let sota: (Leaderboard.Entry, Double)?
    let you: (Leaderboard.Entry, Double)?
    let open: () -> Void

    var body: some View {
        let s = state
        let b = bench
        let upcoming = b.introduced > s.date.ym
        let saturated = s.benchSaturated[b.id]
        Button(action: open) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(b.name).font(.callout.weight(.semibold))
                    if b.generated { Pill(text: "New", color: .purple, symbol: "sparkle") }
                    Spacer()
                    if upcoming {
                        Pill(text: "Launches \(b.introduced.label)", color: .purple)
                    } else if let d = saturated {
                        Pill(text: "Saturated \(d.gameMonth)", color: .green, symbol: "checkmark")
                    } else {
                        Pill(text: "Live", color: .orange, symbol: "flame.fill")
                    }
                }
                if !upcoming {
                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            Meter(value: ((sota?.1 ?? 0) - b.floor) / max(1, b.ceiling - b.floor), tint: saturated != nil ? .green : .orange, height: 7)
                            GeometryReader { g in
                                Rectangle().fill(.red.opacity(0.7)).frame(width: 2, height: 11)
                                    .offset(x: g.size.width * (b.saturation - b.floor) / max(1, b.ceiling - b.floor) - 1, y: -2)
                            }
                        }
                        .frame(height: 7)
                        Text(b.format(sota?.1 ?? 0)).font(.caption.monospacedDigit()).frame(width: 58, alignment: .trailing)
                    }
                    HStack {
                        Text(saturated != nil ? "Saturated by \(s.benchSaturatedBy[b.id] ?? "—")" : "SOTA: \(sota.map { "\($0.0.model) (\($0.0.lab))" } ?? "—")")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if let you { Text("You: \(b.format(you.1))").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(Color.accentColor) }
                    }
                } else {
                    Text(b.about).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct BenchmarkDetail: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let bench: Benchmark

    var body: some View {
        if let s = store.state { content(s) }
    }

    @ViewBuilder
    private func content(_ s: GameState) -> some View {
        let d = store.derived
        let entries = d.board.filter(\.released).sorted { $0.date < $1.date }
        var running = 0.0
        let history: [(Date, Double)] = entries.compactMap { e in
            let v = e.score(bench)
            if v > running { running = v; return (e.date, v) }
            return nil
        }
        let mine = d.board.filter(\.isPlayer).sorted { $0.score(bench) > $1.score(bench) }
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: bench.kind.symbol).font(.title).foregroundStyle(.purple)
                VStack(alignment: .leading) {
                    Text(bench.name).font(.title.weight(.bold))
                    Text("\(bench.kind.label) · introduced \(bench.introduced.label)\(bench.generated ? " · created in your timeline" : "")").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(bench.about)
            HStack(spacing: 20) {
                SpecRow(label: "Human baseline", value: bench.human)
                SpecRow(label: "Saturates at", value: bench.format(bench.saturation))
                SpecRow(label: "Random guessing", value: bench.format(bench.floor))
            }
            if let sat = s.benchSaturated[bench.id] {
                Label("Saturated \(sat.gameShort) by \(s.benchSaturatedBy[bench.id] ?? "—")", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            }
            Card {
                CardHeader("State of the art over time", symbol: "chart.line.uptrend.xyaxis")
                if history.isEmpty {
                    Text("No models have attempted it yet.").foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(Array(history.enumerated()), id: \.offset) { _, h in
                            LineMark(x: .value("Date", h.0), y: .value("Score", h.1)).interpolationMethod(.stepEnd)
                            PointMark(x: .value("Date", h.0), y: .value("Score", h.1))
                        }
                        RuleMark(y: .value("Saturation", bench.saturation)).foregroundStyle(.red.opacity(0.6)).lineStyle(StrokeStyle(dash: [4, 3]))
                    }
                    .chartYScale(domain: min(0, bench.floor)...max(100, bench.ceiling))
                    .frame(height: 200)
                }
            }
            if !mine.isEmpty {
                Card {
                    CardHeader("Your models", symbol: "cube.box")
                    ForEach(mine.prefix(6)) { e in
                        HStack {
                            Text(e.model)
                            Spacer()
                            Text(bench.format(e.score(bench))).monospacedDigit().fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 640)
    }
}
