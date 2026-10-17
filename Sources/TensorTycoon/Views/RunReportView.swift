import Charts
import SwiftUI

struct RunReportID: Identifiable, Equatable {
    let id: UUID
}

/// The payoff moment: shown when a training run finishes (and from the run history).
struct RunReportSheet: View {
    @Environment(GameStore.self) private var store
    let runID: UUID
    @State private var shownIndex = 0.0

    var body: some View {
        let d = store.derived
        if let s = store.state, let run = s.runs.first(where: { $0.id == runID }) {
            let model = run.modelID.flatMap { id in s.models.first { $0.id == id } }
            content(s, d, run, model)
        } else {
            Text("Run not found").padding(40)
        }
    }

    @ViewBuilder
    private func content(_ s: GameState, _ d: Derived, _ run: TrainingRun, _ model: AIModel?) -> some View {
        let accel = HardwareCatalog.get(run.design.accelID)
        let profile = model.map { Leaderboard.profile($0) }
        let index = profile.map { BenchmarkCatalog.index($0, set: d.indexSet) } ?? 0
        let released = d.board.filter(\.released)
        let rivals = released.filter { !$0.isPlayer }
        let rank = rivals.filter { $0.index > index }.count + 1
        let top = rivals.max { $0.index < $1.index }
        let prevBest = s.models.filter { $0.id != model?.id }.map(\.index).max() ?? 0
        let days = max(1, GameCalendar.daysBetween(run.started, run.finished ?? s.date))
        let verdict = verdict(rank: rank, index: index, top: top?.index ?? 0, prevBest: prevBest)

        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Photo(key: accel?.image ?? "supercomputer", thumb: false)
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        PhotoPill(text: "Training complete", color: .green, symbol: "checkmark.seal.fill")
                        Text(run.design.name).font(.system(size: 34, weight: .heavy)).foregroundStyle(.white)
                        Text("\(Fmt.params(run.design.paramsB)) params · \(Fmt.tokens(run.design.tokensT)) tokens · \(Fmt.int(run.design.chips))× \(accel?.name ?? "?") · \(days) days · \(Fmt.money(run.cost))")
                            .font(.callout).foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Intelligence Index").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                        Text(Fmt.score(shownIndex))
                            .font(.system(size: 54, weight: .black).monospacedDigit())
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(value: shownIndex))
                        Text("#\(rank) worldwide").font(.headline).foregroundStyle(rank == 1 ? .yellow : .white)
                    }
                }
                .padding(20)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(verdict.text, systemImage: verdict.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(verdict.color)

                    LeaderboardPlacement(index: index, rivals: rivals, playerColor: Theme.logoColor(s.logoColor))
                        .frame(height: 82)

                    if let model, let fc = run.forecast {
                        ForecastVerdict(run: run, forecast: fc, model: model, index: index, set: d.indexSet)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let profile {
                                BenchmarkBars(profile: profile, set: d.indexSet, arena: model.map(Leaderboard.playerArena) ?? 0)
                            }
                            HStack(spacing: 10) {
                                ReportStat(label: "Task horizon", value: profile.map { BenchmarkCatalog.formatHorizon(BenchmarkCatalog.taskHorizonMinutes($0)) } ?? "—", symbol: "timer")
                                ReportStat(label: "vs your last best", value: prevBest > 0 ? signed(index - prevBest) : "First model", symbol: "arrow.up.right")
                                ReportStat(label: "World #1", value: top.map { "\(Fmt.score($0.index))" } ?? "—", symbol: "crown.fill")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Training loss").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            LossChart(points: run.loss, checkpoints: run.saved.map(\.tokensT))
                                .equatable()
                                .frame(height: 120)
                            Text("Eval index at checkpoints").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            EvalChart(checkpoints: run.saved)
                                .equatable()
                                .frame(height: 100)
                            HStack(spacing: 10) {
                                ReportStat(label: "Final loss", value: run.loss.last.map { Fmt.trim($0.loss, 3) } ?? "—", symbol: "chart.line.downtrend.xyaxis")
                                ReportStat(label: "Checkpoints", value: "\(run.saved.count)", symbol: "externaldrive.badge.checkmark")
                                ReportStat(label: "Loss spikes", value: "\(run.spikes)", symbol: "bolt.trianglebadge.exclamationmark")
                            }
                        }
                        .frame(width: 360)
                    }

                    if !run.events.isEmpty {
                        DisclosureGroup("Run log (\(run.events.count) events)") {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(run.events.prefix(14).enumerated()), id: \.offset) { _, e in
                                    Text(e).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(20)
            }

            Divider()
            HStack(spacing: 10) {
                Toggle("Show this report when runs finish", isOn: Binding(get: { store.showRunReports }, set: { store.showRunReports = $0 }))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                if let model {
                    Button("Open in Models") {
                        store.focusModelID = model.id
                        store.open(.models)
                        close()
                    }
                    if !model.released {
                        Button("Keep private") { close() }
                        Button {
                            releaseAndDeploy(model, run, s, d)
                        } label: {
                            Label("Release & deploy", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Done") { close() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    }
                } else {
                    Button("Done") { close() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 860, height: 700)
        .onAppear {
            shownIndex = 0
            withAnimation(.easeOut(duration: 1.1)) { shownIndex = index }
        }
    }

    /// Clearing the store's run ID closes the sheet (calling dismiss() too would make the shell forget the next sheet).
    private func close() {
        store.reportRunID = nil
    }

    /// Release with an API and put every idle chip of the training hardware behind it (keeping a few for research).
    private func releaseAndDeploy(_ m: AIModel, _ run: TrainingRun, _ s: GameState, _ d: Derived) {
        let ok = store.act("\(m.name) is live") { st in
            if let e = st.release(m.id, api: true, openWeights: false) { return e }
            let free = Economy.freeChips(st, run.design.accelID)
            if free > 0 { _ = st.deploy(m.id, accelID: run.design.accelID, chips: free) }
            if st.chatModelID == nil && m.design.instruct { st.chatModelID = m.id }
            return nil
        }
        if ok { close() }
    }

    private func verdict(rank: Int, index: Double, top: Double, prevBest: Double) -> (text: String, symbol: String, color: Color) {
        if rank == 1 { return ("New world #1. Every lab is reading your release notes.", "crown.fill", .yellow) }
        if rank <= 3 { return ("Top 3 in the world — frontier-class.", "flame.fill", .orange) }
        if prevBest > 0 && index > prevBest + 5 { return ("Your best model yet by a wide margin.", "arrow.up.forward.circle.fill", .green) }
        if index >= top - 10 { return ("Within striking distance of the frontier.", "scope", .blue) }
        if prevBest > 0 && index < prevBest { return ("Weaker than your previous best — useful as a cheap, fast model.", "tortoise.fill", .secondary) }
        return ("A solid start. Scale compute and research to close the gap.", "chart.line.uptrend.xyaxis", .blue)
    }

    private func signed(_ v: Double) -> String { (v >= 0 ? "+" : "") + Fmt.trim(v, 1) }
}

/// Why the model landed where it did: the pre-run forecast, the run's luck, bugs and post-training surprises.
private struct ForecastVerdict: View {
    let run: TrainingRun
    let forecast: RunForecast
    let model: AIModel
    let index: Double
    let set: [Benchmark]

    private struct Factor: Identifiable {
        let id: String
        let detail: String
        let value: String
        let good: Bool?
    }

    var body: some View {
        let expected = expectedIndex
        let delta = index - expected
        let z = (model.c - model.cForecast) / max(0.01, model.forecastSigma)
        let (headline, color): (String, Color) = switch delta {
        case 4...: ("Beat the forecast — this run turned out special", .green)
        case 1.5..<4: ("A little better than forecast", .green)
        case -1.5..<1.5: ("Right on forecast — the scaling laws held", .blue)
        case -4 ..< -1.5: ("A little worse than forecast", .orange)
        default: ("Missed the forecast — something went wrong", .red)
        }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Forecast vs reality", systemImage: "scope").font(.headline)
                Spacer()
                Text(headline).font(.callout.weight(.semibold)).foregroundStyle(color)
            }
            HStack(spacing: 10) {
                ReportStat(label: "Forecast at launch", value: "\(Fmt.score(forecast.index)) (\(Fmt.score(forecast.indexLow))–\(Fmt.score(forecast.indexHigh)))", symbol: "chart.bar.doc.horizontal")
                ReportStat(label: "Expected on today's evals", value: Fmt.score(expected), symbol: "list.number")
                ReportStat(label: "Actual", value: "\(Fmt.score(index)) (\(delta >= 0 ? "+" : "")\(Fmt.trim(delta, 1)))", symbol: "flag.checkered")
                ReportStat(label: "Surprise", value: abs(z) < 0.5 ? "Typical" : "\(Fmt.trim(abs(z), 1))σ \(z > 0 ? "lucky" : "unlucky")", symbol: "dice.fill")
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("What moved the result").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(factors) { f in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: f.good == nil ? "circle.fill" : (f.good! ? "arrow.up.circle.fill" : "arrow.down.circle.fill"))
                                .font(.caption)
                                .foregroundStyle(f.good == nil ? Color.secondary : (f.good! ? Color.green : Color.red))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(f.id).font(.caption.weight(.semibold))
                                Text(f.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(f.value).font(.caption.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tier").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(model.tier.isEmpty ? forecast.tier : model.tier).font(.callout.weight(.bold))
                    if model.tier != forecast.tier && !model.tier.isEmpty {
                        Text("Forecast said: \(forecast.tier)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("Closest real model").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                    Text(forecast.comparable).font(.callout)
                    if !model.keyTech.isEmpty {
                        Text("Key tech").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                        FlowTags(tags: model.keyTech)
                    }
                }
                .frame(width: 250, alignment: .leading)
            }
        }
        .padding(14)
        .background(color.opacity(0.07), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.3), lineWidth: 1))
    }

    /// The forecast re-scored on today's benchmarks, so a rotated index doesn't skew the comparison.
    private var expectedIndex: Double {
        var p = Leaderboard.profile(model)
        p.c = model.cForecast
        p.key += "-forecast"
        return BenchmarkCatalog.index(p, set: set)
    }

    private var factors: [Factor] {
        var out: [Factor] = []
        func compute(_ v: Double) -> String { "×\(Fmt.trim(pow(10, v), 2)) compute" }
        let luck = run.epsilon
        out.append(Factor(id: "Run luck", detail: "Seed, data order and how well the hyperparameters transferred to full scale",
                          value: compute(luck), good: abs(luck) < 0.01 ? nil : luck > 0))
        if run.bugPenalty > 0 {
            out.append(Factor(id: run.bugFound ? "Silent bug — caught" : "Silent bug — never found",
                              detail: run.bugFound ? "Found from the loss curve and fixed before it did lasting damage" : "A data or code bug quietly hurt every token after it appeared",
                              value: run.bugFound ? "fixed" : compute(-run.bugPenalty), good: run.bugFound ? nil : false))
        }
        if run.qualityPenalty > 0.001 {
            out.append(Factor(id: "Instabilities", detail: "\(run.spikes) loss spike\(run.spikes == 1 ? "" : "s") and rollbacks left scars", value: compute(-run.qualityPenalty), good: false))
        }
        let sched = run.schedule.qualityBonus
        if abs(sched) > 0.001 {
            out.append(Factor(id: "Learning-rate schedule", detail: run.schedule.detail, value: compute(sched), good: sched > 0))
        }
        let post: [(String, Double)] = [("reasoning", run.dReasoning), ("coding", run.dCode), ("chat", run.dChat), ("safety", run.dSafety / 10), ("multilingual", run.dLang)]
        let surprises = post.filter { abs($0.1) > 0.005 }
        if !surprises.isEmpty {
            let net = surprises.reduce(0) { $0 + $1.1 }
            out.append(Factor(id: "Post-training surprises", detail: surprises.map { "\($0.1 > 0 ? "+" : "−")\(Fmt.trim(abs($0.1), 2)) \($0.0)" }.joined(separator: " · "),
                              value: net >= 0 ? "net +" : "net −", good: net >= 0))
        }
        if run.rewardHacked { out.append(Factor(id: "Reward hacking", detail: "The RL policy learned to game its graders", value: "−reasoning", good: false)) }
        if run.sycophantic { out.append(Factor(id: "Sycophancy", detail: "Preference tuning made it too eager to agree", value: "−chat", good: false)) }
        if run.contaminated { out.append(Factor(id: "Contaminated evals", detail: "Benchmark questions leaked into training data — scores flatter it", value: "tuned", good: false)) }
        if run.interruptions > 0 {
            out.append(Factor(id: "Hardware failures", detail: "\(run.interruptions) interruptions, \(Fmt.trim(run.lostHours, 0)) cluster-hours lost (cost time, not quality)", value: "\(run.interruptions)×", good: nil))
        }
        if !run.emerged.isEmpty {
            let names = run.emerged.compactMap { id in set.first { $0.id == id }?.name ?? BenchmarkCatalog.real.first { $0.id == id }?.name }.sorted()
            out.append(Factor(id: "Emergent abilities", detail: names.prefix(4).joined(separator: ", "), value: "\(run.emerged.count)", good: true))
        }
        return out
    }
}

/// Small wrapping row of tags.
private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(stride(from: 0, to: tags.count, by: 2)), id: \.self) { i in
                HStack(spacing: 4) {
                    ForEach(tags[i ..< min(i + 2, tags.count)], id: \.self) { Pill(text: $0, color: .indigo) }
                }
            }
        }
    }
}

private struct ReportStat: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
    }
}

/// A 0–100 strip with every rival lab's best model as a tick and your model as a big marker.
/// Labels are packed greedily into up to three rows so close scores never overlap.
private struct LeaderboardPlacement: View {
    let index: Double
    let rivals: [Leaderboard.Entry]
    let playerColor: Color

    private struct Mark: Identifiable {
        let id: String
        let lab: String
        let score: Double
        let color: Color
        var row = 0
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let marks = layout(width: w)
            ZStack(alignment: .topLeading) {
                Capsule().fill(LinearGradient(colors: [.gray.opacity(0.15), .orange.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                    .offset(y: 24)
                ForEach(marks) { m in
                    let x = w * min(1, max(0, m.score / 100))
                    let tick = 14 + CGFloat(m.row) * 13
                    Rectangle().fill(m.color).frame(width: 2, height: tick)
                        .position(x: x, y: 22 + tick / 2)
                    Text(m.lab).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary).fixedSize()
                        .position(x: x, y: 22 + tick + 6)
                        .help("\(m.lab): \(Fmt.score(m.score))")
                }
                VStack(spacing: 2) {
                    Text("You \(Fmt.score(index))").font(.caption.weight(.bold)).foregroundStyle(playerColor).fixedSize()
                    Circle().fill(playerColor).frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
                .position(x: w * min(1, max(0, index / 100)), y: 16)
            }
        }
    }

    private func layout(width w: CGFloat) -> [Mark] {
        var best: [String: Leaderboard.Entry] = [:]
        for e in rivals where e.index > (best[e.labID]?.index ?? -1) { best[e.labID] = e }
        var marks = best.values.sorted { $0.index < $1.index }.map { e in
            Mark(id: e.labID, lab: e.lab, score: e.index,
                 color: CompetitorCatalog.byID[e.labID].map { Theme.competitorColor($0.color) } ?? .gray)
        }
        var rowEnd: [CGFloat] = [-.infinity, -.infinity, -.infinity]
        for i in marks.indices {
            let x = w * min(1, max(0, marks[i].score / 100))
            let half = CGFloat(marks[i].lab.count) * 2.7 + 4
            let row = rowEnd.firstIndex { x - half > $0 } ?? (rowEnd.indices.min { rowEnd[$0] < rowEnd[$1] } ?? 0)
            marks[i].row = row
            rowEnd[row] = x + half
        }
        return marks
    }
}
