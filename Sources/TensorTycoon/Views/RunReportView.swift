import Charts
import SwiftUI

struct RunReportID: Identifiable, Equatable {
    let id: UUID
}

/// The payoff moment: the model results screen, shown when a training run finishes (and from the run history).
/// 3.5: identity, plan vs reality, domains against the best rival, serving, problems met, the training firsts it set and
/// how to ship it. A record-breaking model gets a short staged reveal first (skippable; none with Reduce Motion).
struct RunReportSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let runID: UUID
    @State private var shownIndex = 0.0
    /// 0 curtain, 1 the index, 2 the rank, 3 the full results.
    @State private var stage = 3
    @State private var revealed = false
    @State private var launchPlan: LaunchPlan?   // 3.7: nil = your default plan
    @State private var openWeights = false

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
        let top = rivals.max { $0.index < $1.index }
        let results = model.map { TrainingExperience.results(run, model: $0, index: index, board: d.board, set: d.indexSet, state: s) }
        let rank = results?.rank ?? Leaderboard.labRank(index: index, board: released, gone: d.gone)
        let prevBest = results?.previous?.index ?? 0
        let days = results?.days ?? max(1, GameCalendar.daysBetween(run.started, run.finished ?? s.date))
        let verdict = verdict(rank: rank, index: index, top: top?.index ?? 0, prevBest: prevBest, first: results?.previous == nil)

        ZStack {
            VStack(spacing: 0) {
                header(run, accel: accel, days: days, index: index, rank: rank)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if rank == 1 { numberOneBanner(index: index, top: top) }
                        Label(verdict.text, systemImage: verdict.symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(verdict.color)
                        if let results { planVsReality(run, results) }
                        if let results, !results.firsts.isEmpty { firstsStrip(results.firsts) }
                        if let model, let fc = run.forecast, results?.disappointing ?? false {
                            ForecastVerdict(run: run, forecast: fc, model: model, index: index, set: d.indexSet)
                        }
                        LeaderboardPlacement(index: index, rivals: rivals, playerColor: Theme.logoColor(s.logoColor))
                            .frame(height: 82)
                        if let results { domainsCard(results) }
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                if let profile {
                                    BenchmarkBars(profile: profile, set: d.indexSet, arena: model.map(Leaderboard.playerArena) ?? 0)
                                }
                                HStack(spacing: 10) {
                                    ReportStat(label: "Task horizon", value: profile.map { BenchmarkCatalog.formatHorizon(BenchmarkCatalog.taskHorizonMinutes($0)) } ?? "—", symbol: "timer")
                                    ReportStat(label: "vs your last best", value: results?.previous != nil ? signed(index - prevBest) : "First model", symbol: "arrow.up.right")
                                    ReportStat(label: "World #1", value: top.map { "\(Fmt.score($0.index))" } ?? "—", symbol: "crown.fill")
                                }
                                if let model { yourModels(s, d, model: model, index: index) }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                            VStack(alignment: .leading, spacing: 10) {
                                if let results, let model { servingCard(results, model) }
                                Text("Training loss").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                LossChart(points: run.loss, checkpoints: run.saved.map(\.tokensT))
                                    .equatable()
                                    .frame(height: 110)
                                Text("Eval index at checkpoints").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                EvalChart(checkpoints: run.saved)
                                    .equatable()
                                    .frame(height: 90)
                                HStack(spacing: 10) {
                                    ReportStat(label: "Final loss", value: run.loss.last.map { Fmt.trim($0.loss, 3) } ?? "—", symbol: "chart.line.downtrend.xyaxis")
                                    ReportStat(label: "Checkpoints", value: "\(run.saved.count)", symbol: "externaldrive.badge.checkmark")
                                    ReportStat(label: "Loss spikes", value: "\(run.spikes)", symbol: "bolt.trianglebadge.exclamationmark")
                                }
                            }
                            .frame(width: 360)
                        }
                        problemsCard(run, s)
                        if let model, let fc = run.forecast, !(results?.disappointing ?? false) {
                            ForecastVerdict(run: run, forecast: fc, model: model, index: index, set: d.indexSet)
                        }
                        if !run.events.isEmpty {
                            DisclosureGroup("Ops notes (\(run.events.count))") {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(Array(run.events.prefix(20).enumerated()), id: \.offset) { _, e in
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
                footer(model, run, s, d)
            }
            if stage < 3 { reveal(run, index: index, rank: rank, top: top) }
        }
        .frame(width: 920, height: 760)
        // The staged reveal plays once, when the run has just finished (not when reopened from the history).
        .onAppear { start(record: (results?.record ?? false) && run.finished.map { GameCalendar.daysBetween($0, s.date) <= 1 } ?? false, index: index) }
    }

    // MARK: Reveal

    private func start(record: Bool, index: Double) {
        guard !revealed else { return }
        revealed = true
        guard record && !reduceMotion else {
            stage = 3
            if reduceMotion { shownIndex = index } else { withAnimation(.easeOut(duration: 1.1)) { shownIndex = index } }
            return
        }
        stage = 0
        shownIndex = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard stage < 3 else { return }
            stage = 1
            withAnimation(.easeOut(duration: 1.4)) { shownIndex = index }
            try? await Task.sleep(for: .milliseconds(1_700))
            guard stage < 3 else { return }
            withAnimation(.easeOut(duration: 0.4)) { stage = 2 }
            try? await Task.sleep(for: .milliseconds(1_600))
            withAnimation(.easeOut(duration: 0.4)) { stage = 3 }
        }
    }

    private func reveal(_ run: TrainingRun, index: Double, rank: Int, top: Leaderboard.Entry?) -> some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.92))
            VStack(spacing: 18) {
                Text(run.design.name).font(.system(size: 44, weight: .black)).foregroundStyle(.white)
                Text("\(Fmt.params(run.design.paramsB)) parameters · \(Fmt.flops(run.flopsTotal + run.postTrainFlops)) FLOPs")
                    .font(.title3).foregroundStyle(.white.opacity(0.6))
                if stage >= 1 {
                    VStack(spacing: 2) {
                        Text("Intelligence Index").font(.headline).foregroundStyle(.white.opacity(0.7))
                        Text(Fmt.score(shownIndex))
                            .font(.system(size: 96, weight: .black).monospacedDigit())
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(value: shownIndex))
                    }
                    .transition(.opacity)
                }
                if stage >= 2 {
                    Text(rank == 1 ? "NEW WORLD #1" : "#\(rank) worldwide")
                        .font(.system(size: rank == 1 ? 40 : 30, weight: .heavy))
                        .foregroundStyle(rank == 1 ? .yellow : .white)
                        .transition(.scale.combined(with: .opacity))
                    if rank == 1, let top {
                        Text("Ahead of \(top.lab)'s \(top.model) (\(Fmt.score(top.index)))").font(.title3).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") { stage = 3; shownIndex = index }.keyboardShortcut(.cancelAction).padding(16)
                }
                Spacer()
            }
        }
        .contentShape(.rect)
        .onTapGesture { stage = 3; shownIndex = index }
    }

    // MARK: Sections

    private func header(_ run: TrainingRun, accel: Accelerator?, days: Int, index: Double, rank: Int) -> some View {
        let dsg = run.design
        let arch = TrainingExperience.sketch(dsg, state: store.game)
        return ZStack(alignment: .bottomLeading) {
            Photo(key: accel?.image ?? "supercomputer", thumb: false)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom))
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        PhotoPill(text: "Training complete", color: .green, symbol: "checkmark.seal.fill")
                        if dsg.objective != .general { PhotoPill(text: dsg.objective.label, color: .indigo, symbol: dsg.objective.symbol) }
                        if !dsg.family.isEmpty { PhotoPill(text: "\(dsg.family)\(dsg.generation > 0 ? " · gen \(dsg.generation)" : "")", color: .gray, symbol: "square.stack.fill") }
                    }
                    Text(dsg.name).font(.system(size: 34, weight: .heavy)).foregroundStyle(.white)
                    Text("\(Fmt.params(dsg.paramsB)) params\(dsg.isMoE ? " (\(Fmt.params(dsg.activeParamsB)) active, \(arch.experts) experts)" : "") · \(arch.layers) layers · \(dsg.attention.rawValue) · \(dsg.contextK >= 1000 ? "1M" : "\(dsg.contextK)K") context")
                        .font(.callout).foregroundStyle(.white.opacity(0.85))
                    Text("\(Fmt.tokens(dsg.tokensT)) tokens · \(Fmt.flops(run.flopsTotal + run.postTrainFlops)) FLOPs · \(Fmt.int(dsg.chips))× \(accel?.name ?? "?") · \(days) days · \(Fmt.money(run.cost))")
                        .font(.callout).foregroundStyle(.white.opacity(0.75))
                    if !dsg.blurb.isEmpty { Text(dsg.blurb).font(.caption).foregroundStyle(.white.opacity(0.7)) }
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
    }

    private func numberOneBanner(index: Double, top: Leaderboard.Entry?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill").font(.title).foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("The best model in the world").font(.title2.weight(.heavy))
                Text(top.map { "Index \(Fmt.score(index)) against \($0.lab)'s \($0.model) at \(Fmt.score($0.index)) — every rival lab is reading your release notes." }
                     ?? "No released rival model comes close.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(LinearGradient(colors: [.yellow.opacity(0.28), .orange.opacity(0.12)], startPoint: .leading, endPoint: .trailing), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.6), lineWidth: 1.5))
    }

    /// What the plan said at launch against what happened: capability, time, money, rank.
    private func planVsReality(_ run: TrainingRun, _ r: TrainingExperience.Results) -> some View {
        HStack(spacing: 10) {
            compare("Capability", planned: r.forecastIndex.map { Fmt.score($0) }, actual: Fmt.score(r.index),
                    delta: r.forecastIndex.map { r.index - $0 }, unit: " pts", higherIsBetter: true,
                    note: r.forecastLow.map { lo in "band \(Fmt.score(lo))–\(Fmt.score(r.forecastHigh ?? lo)) on today's evals"
                        + (r.launchIndex.map { " (\(Fmt.score($0)) at launch)" } ?? "") })
            compare("Duration", planned: r.plannedDays.map { Fmt.days($0) }, actual: Fmt.days(Double(r.days)),
                    delta: r.plannedDays.map { (Double(r.days) - $0) / max($0, 1) }, unit: "%", higherIsBetter: false, note: nil)
            compare("Cost", planned: r.plannedCost.map { Fmt.money($0) }, actual: Fmt.money(r.cost),
                    delta: r.plannedCost.map { (r.cost - $0) / max($0, 1) }, unit: "%", higherIsBetter: false, note: nil)
            compare("Rank", planned: r.expectedRank.map { "#\($0)" }, actual: "#\(r.rank)",
                    delta: r.expectedRank.map { Double($0 - r.rank) }, unit: "", higherIsBetter: true, note: "forecast vs the board at launch")
        }
    }

    private func compare(_ title: String, planned: String?, actual: String, delta: Double?, unit: String, higherIsBetter: Bool, note: String?) -> some View {
        let good = delta.map { higherIsBetter ? $0 >= -0.001 : $0 <= 0.05 } ?? true
        let deltaText: String? = delta.map { v in
            unit == "%" ? "\(v >= 0 ? "+" : "−")\(Int((abs(v) * 100).rounded()))%" : (unit.isEmpty ? (v == 0 ? "as forecast" : "\(v > 0 ? "+" : "−")\(Int(abs(v)))") : "\(v >= 0 ? "+" : "−")\(Fmt.trim(abs(v), 1))\(unit)")
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(actual).font(.title3.weight(.bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(planned.map { "planned \($0)" } ?? "no plan recorded").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            if let deltaText { Text(deltaText).font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(good ? .green : .orange) }
            if let note { Text(note).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 10))
    }

    private func firstsStrip(_ firsts: [TrainingFirst]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Lab history made", systemImage: "rosette").font(.headline).foregroundStyle(.orange)
            ForEach(firsts) { f in
                HStack(spacing: 10) {
                    Image(systemName: f.symbol)
                        .font(.callout.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(f.title).font(.callout.weight(.semibold))
                        Text(f.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.08), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.35)))
    }

    private func domainsCard(_ r: TrainingExperience.Results) -> some View {
        let rival = DomainScores(CapDomain.allCases.map { d in r.margins.first { $0.domain == d }?.rival ?? 0 })
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Capability domains", systemImage: "circle.hexagongrid.fill").font(.headline)
                Spacer()
                Text("small numbers: vs the best rival in each").font(.caption2).foregroundStyle(.secondary)
            }
            DomainGrid(scores: r.domains, compare: rival, columns: 4)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    let ahead = (r.margins.first.map { $0.score > $0.rival }) ?? false
                    Text(ahead ? "Strengths" : "Closest to the leaders").font(.caption.weight(.semibold)).foregroundStyle(ahead ? .green : .secondary)
                    ForEach(Array(r.margins.filter { $0.score > 0 }.prefix(3).enumerated()), id: \.offset) { _, m in
                        Text("\(m.domain.label): \(Int(m.score.rounded())) — \(margin(m.score - m.rival)) vs \(m.lab.isEmpty ? "the field" : m.lab)").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Weaknesses").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    ForEach(Array(r.margins.suffix(3).reversed().enumerated()), id: \.offset) { _, m in
                        Text("\(m.domain.label): \(Int(m.score.rounded())) — \(margin(m.score - m.rival)) vs \(m.lab.isEmpty ? "the field" : m.lab)").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("10 points is 10× effective compute. \(CapStyle.scaleNote)").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))
    }

    private func margin(_ v: Double) -> String { (v >= 0 ? "+" : "−") + Fmt.trim(abs(v), 1) }

    private func yourModels(_ s: GameState, _ d: Derived, model: AIModel, index: Double) -> some View {
        let mine = s.models.filter { !$0.preview && $0.created <= model.created }.suffix(6)
        let hi = max(index, mine.map { d.entry($0.id)?.index ?? $0.index }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Your models").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(mine)) { m in
                let v = m.id == model.id ? index : (d.entry(m.id)?.index ?? m.index)
                HStack(spacing: 6) {
                    Text(m.name).font(.caption.weight(m.id == model.id ? .bold : .regular)).frame(width: 120, alignment: .leading).lineLimit(1)
                    Meter(value: v / hi, tint: m.id == model.id ? .purple : .gray, height: 6)
                    Text(Fmt.score(v)).font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private func servingCard(_ r: TrainingExperience.Results, _ m: AIModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Serving").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ReportStat(label: "Tokens/s per user", value: r.tps.map { Fmt.trim($0, 0) } ?? "—", symbol: "hare.fill")
                ReportStat(label: "Cost per 1M tokens", value: r.servingPerM.map { Fmt.price($0) } ?? "—", symbol: "dollarsign.circle")
                ReportStat(label: "Launch price /1M", value: Fmt.price(m.apiPrice), symbol: "tag.fill")
            }
        }
    }

    /// Everything that went wrong (or surprisingly right) on the way.
    private func problemsCard(_ run: TrainingRun, _ s: GameState) -> some View {
        var rows: [(String, String, Color)] = []
        if run.interruptions > 0 { rows.append(("bolt.trianglebadge.exclamationmark", "\(run.interruptions) hardware interruptions cost \(Fmt.trim(run.lostHours, 0)) cluster-hours", .orange)) }
        if run.spikes > 0 { rows.append(("waveform.path.ecg", "\(run.spikes) loss spike\(run.spikes == 1 ? "" : "s")", .orange)) }
        if run.bugPenalty > 0 || run.bugFound { rows.append(("ladybug.fill", run.bugFound ? "A silent bug was found and fixed" : "A silent bug was never found", run.bugFound ? .secondary : .red)) }
        if run.contaminated { rows.append(("drop.triangle.fill", "Benchmark contamination left in: scores flatter it", .red)) }
        if run.sycophantic { rows.append(("hand.thumbsup.fill", "Shipped sycophantic: preference tuning made it a flatterer", .red)) }
        if run.rewardHacked { rows.append(("exclamationmark.lock.fill", "Reward-hacked reasoning RL", .red)) }
        if run.sdcMissed >= 1 { rows.append(("exclamationmark.octagon.fill", "\(Int(run.sdcMissed)) nodes silently corrupted gradients unnoticed", .red)) }
        if run.prevented >= 1 { rows.append(("shield.checkered", "Ops agents prevented \(Int(run.prevented)) failures and caught \(Int(run.sdcCaught)) corrupt nodes", .green)) }
        if run.ledger.tracked && run.ledger.rewound > 0 {
            rows.append(("arrow.uturn.backward", "\(Fmt.pct(run.ledger.rewound / run.ledger.peak, decimals: 1)) of peak compute thrown away by rollbacks and redone stages", .orange))
        }
        if !run.emerged.isEmpty { rows.append(("sparkles", "\(run.emerged.count) emergent abilit\(run.emerged.count == 1 ? "y" : "ies") between checkpoints", .green)) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("What happened along the way", systemImage: "list.bullet.clipboard").font(.headline)
                Spacer()
            }
            if rows.isEmpty {
                Text("A clean run: no incidents worth mentioning.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    Label(r.1, systemImage: r.0).font(.callout).foregroundStyle(r.2 == .secondary ? Color.primary : r.2)
                }
            }
            if let actual = TrainingExperience.actualSlices(run.ledger) {
                Text("Where the cluster's peak compute went\(run.ledger.since > 0.005 ? " (tracked from \(Fmt.pct(run.ledger.since, decimals: 0)))" : "")")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ComputeBar(slices: actual).equatable()
                Text("Energy used: \(energyText(run.ledger.energyMWh)).").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))
    }

    private func footer(_ model: AIModel?, _ run: TrainingRun, _ s: GameState, _ d: Derived) -> some View {
        HStack(spacing: 10) {
            Toggle("Show results when runs finish", isOn: Binding(get: { store.showRunReports }, set: { store.showRunReports = $0 }))
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
                    LaunchPlanButton(plan: Binding(get: { launchPlan ?? s.launchDefault }, set: { launchPlan = $0 }), state: s, rank: d.rank(model.id))
                        .frame(maxWidth: 260)
                    Toggle("Open weights", isOn: $openWeights).toggleStyle(.checkbox)
                        .help("Publish the weights too: brand with developers, but anyone can serve it.")
                    Button("Keep private") { close() }
                    Button {
                        releaseAndDeploy(model, run)
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

    /// Clearing the store's run ID closes the sheet (calling dismiss() too would make the shell forget the next sheet).
    private func close() {
        store.reportRunID = nil
    }

    /// Release with an API in the chosen launch style and put every idle chip of the training hardware behind it.
    private func releaseAndDeploy(_ m: AIModel, _ run: TrainingRun) {
        let plan = launchPlan ?? store.game.launchDefault
        let open = openWeights
        let ok = store.act("\(m.name) is live") { st in
            if let e = st.release(m.id, api: true, openWeights: open, plan: plan) { return e }
            let free = Economy.freeChips(st, run.design.accelID)
            if free > 0 { _ = st.deploy(m.id, accelID: run.design.accelID, chips: free) }
            if st.chatModelID == nil && m.design.instruct { st.chatModelID = m.id }
            return nil
        }
        if ok { close() }
    }

    private func verdict(rank: Int, index: Double, top: Double, prevBest: Double, first: Bool) -> (text: String, symbol: String, color: Color) {
        if rank == 1 { return ("New world #1. Every lab is reading your release notes.", "crown.fill", .yellow) }
        if rank <= 3 { return ("Top 3 in the world — frontier-class.", "flame.fill", .orange) }
        if !first && index > prevBest + 5 { return ("Your best model yet by a wide margin.", "arrow.up.forward.circle.fill", .green) }
        if index >= top - 10 { return ("Within striking distance of the frontier.", "scope", .blue) }
        if !first && index < prevBest { return ("Weaker than your previous best — useful as a cheap, fast model.", "tortoise.fill", .secondary) }
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
