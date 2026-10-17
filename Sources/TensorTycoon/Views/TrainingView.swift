import Charts
import SwiftUI

struct TrainingView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let active = s.runs.filter { $0.status != .done && $0.status != .cancelled }
        let past = Array(s.runs.filter { $0.status == .done || $0.status == .cancelled }.reversed())
        Page(title: "Training Runs", subtitle: "Mission control. Watch the loss against the forecast, catch bugs, call the spikes — and find out whether you trained a genius.") {
            if active.isEmpty {
                Card {
                    EmptyStateView(symbol: "chart.line.downtrend.xyaxis", title: "Nothing training",
                                   message: "Design a model in the Model Lab — pick a recipe and hit start.",
                                   actionTitle: "Open Model Lab") { store.open(.lab) }
                }
            }
            ForEach(active) { run in
                if run.kind == .proxy {
                    LadderCard(run: run)
                } else {
                    RunCard(run: run, state: s, free: store.derived.free(run.design.accelID))
                }
            }
            if !past.isEmpty {
                Text("History").font(.title3.weight(.semibold)).padding(.top, 6)
                Card {
                    ForEach(past) { run in
                        let model = run.modelID.flatMap { id in s.models.first { $0.id == id } }
                        Button {
                            if run.modelID != nil { store.reportRunID = run.id }
                        } label: {
                            HStack {
                                Image(systemName: run.kind == .proxy ? "chart.line.uptrend.xyaxis" : (run.status == .done ? "checkmark.circle.fill" : "xmark.circle.fill"))
                                    .foregroundStyle(run.status == .done ? (run.kind == .proxy ? .indigo : .green) : .secondary)
                                Text(run.design.name).font(.callout.weight(.semibold))
                                Text(run.kind == .proxy ? "scaling ladder · \(Fmt.flops(run.flopsTotal))" : "\(Fmt.params(run.design.paramsB)) · \(Fmt.tokens(run.design.tokensT)) tokens · \(Fmt.int(run.design.chips))× \(HardwareCatalog.get(run.design.accelID)?.name ?? "")")
                                    .font(.caption).foregroundStyle(.secondary)
                                if run.spikes > 0 { Pill(text: "\(run.spikes) spikes", color: .orange) }
                                if let model {
                                    Pill(text: "Index \(Fmt.score(store.derived.entry(model.id)?.index ?? model.index))", color: .purple)
                                    if let fc = run.forecast {
                                        let delta = model.index - fc.index
                                        Pill(text: abs(delta) < 1.5 ? "on forecast" : (delta > 0 ? "+\(Fmt.trim(delta, 1)) vs forecast" : "\(Fmt.trim(delta, 1)) vs forecast"),
                                             color: abs(delta) < 1.5 ? .secondary : (delta > 0 ? .green : .orange))
                                    }
                                }
                                Spacer()
                                Text("\(Fmt.flops(run.flopsDone)) FLOPs · \(Fmt.money(run.cost))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                Text(run.started.gameShort).font(.caption).foregroundStyle(.tertiary)
                                if run.modelID != nil { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .help(run.modelID != nil ? "Open the training report" : "")
                        Divider()
                    }
                }
            }
        }
    }
}

private struct LadderCard: View {
    @Environment(GameStore.self) private var store
    let run: TrainingRun

    var body: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.title).foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(run.design.name).font(.title3.weight(.bold))
                        Pill(text: "Scaling ladder", color: .indigo)
                        Pill(text: run.status.rawValue, color: run.status == .paused ? .orange : .blue)
                    }
                    Text("Five proxy runs from \(Fmt.flops(run.flopsTotal / 300)) to \(Fmt.flops(run.flopsTotal)) FLOPs, validating the recipe for a \(Fmt.flops(run.proxyCompute)) run.")
                        .font(.callout).foregroundStyle(.secondary)
                    Meter(value: run.progress, tint: .indigo, height: 8)
                }
                Spacer()
                LadderChart(points: run.loss)
                    .frame(width: 260, height: 90)
                Button("Cancel", role: .destructive) { store.act("Ladder cancelled") { $0.setRunStatus(run.id, .cancelled) } }
            }
        }
    }
}

/// Five small loss curves fanning out — what a scaling ladder looks like.
private struct LadderChart: View {
    let points: [LossPoint]

    var body: some View {
        let done = points.count
        Chart {
            ForEach(0..<5, id: \.self) { k in
                let scale = pow(3.0, Double(k))
                ForEach(0..<min(done, 30), id: \.self) { i in
                    let x = Double(i + 1) / 30 * scale
                    LineMark(x: .value("Compute", x), y: .value("Loss", 3.4 * pow(x + 0.05, -0.08) - 0.12 * Double(k)), series: .value("Run", k))
                        .foregroundStyle(.indigo.opacity(0.35 + 0.13 * Double(k)))
                }
            }
        }
        .chartXScale(type: .log)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

private struct RunCard: View {
    @Environment(GameStore.self) private var store
    let run: TrainingRun
    let state: GameState
    let free: Int
    @State private var resize = 0
    @State private var showLog = false

    var body: some View {
        let s = state
        let b = store.derived.bonuses
        let a = HardwareCatalog.get(run.design.accelID)
        let mfu = a.map { Physics.mfu(accel: $0, chips: run.design.chips, state: s, bonuses: b) } ?? 0
        let good = Physics.goodput(chips: run.design.chips, state: s, bonuses: b, coverage: run.opsCoverage) * Sim.checkpointOverhead(run.interval)
        let flopsPerSec = Double(run.design.chips) * (a?.trainTFLOPS(run.design.precision) ?? 0) * 1e12 * mfu * good * run.schedule.speed
        let perDay = flopsPerSec * 86_400
        let postTotal = run.postTrainFlops
        let remaining = max(0, run.flopsTotal - run.flopsDone) + max(0, postTotal - run.postTrainDone)
        let eta = perDay > 0 ? remaining / perDay : .infinity
        let inPost = run.status == .postTraining
        let tokensPerSec = flopsPerSec / (6 * max(run.design.activeParamsB, 0.001) * 1e9)

        Card {
            // Header
            HStack(alignment: .top, spacing: 16) {
                if let a {
                    Photo(key: a.image)
                        .frame(width: 120, height: 80)
                        .clipShape(.rect(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(run.design.name).font(.title2.weight(.bold))
                        Pill(text: run.status == .paused ? "Paused" : Training.currentStageName(run), color: run.status == .paused ? .orange : (inPost ? .purple : .blue))
                        if run.stalledDays >= 7 { Pill(text: "Stalled \(run.stalledDays) days", color: .red) }
                        if run.design.isMoE { Pill(text: "MoE", color: .teal) }
                        if run.design.reasoning { Pill(text: "RL: \(run.design.effectiveRL.label)", color: .pink) }
                        if run.design.optimizer != .adamw { Pill(text: run.design.optimizer.rawValue, color: .indigo) }
                        Pill(text: "LR: \(run.schedule.label)", color: run.schedule == .aggressive ? .orange : .secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(run.status == .paused ? "Paused" : Fmt.days(eta)).font(.title3.weight(.bold).monospacedDigit())
                            Text(run.status == .paused ? "waiting for you" : "to completion").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Text("\(Fmt.params(run.design.paramsB)) params (\(Fmt.params(run.design.activeParamsB)) active) · \(Fmt.tokens(run.design.tokensT)) tokens · \(run.design.precision.short) · \(run.design.contextK >= 1000 ? "1M" : "\(run.design.contextK)K") context")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("\(Fmt.int(run.design.chips))× \(a?.name ?? "?") · MFU \(Fmt.pct(mfu, decimals: 0)) · goodput \(Fmt.pct(good, decimals: 0))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            StageTimeline(run: run)
            if let fc = run.forecast { ForecastTracker(run: run, forecast: fc) }

            // Live numbers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                LiveStat(label: "Tokens / sec", value: Fmt.count(tokensPerSec), symbol: "text.word.spacing", tint: .blue)
                LiveStat(label: "Effective compute", value: Fmt.tflops(flopsPerSec / 1e12), symbol: "bolt.fill", tint: .yellow)
                LiveStat(label: "Loss vs forecast", value: lossDelta(run), symbol: "chart.line.downtrend.xyaxis", tint: .teal)
                LiveStat(label: "Base-model eval", value: run.saved.last.map { Fmt.score($0.index) } ?? "—", symbol: "checklist", tint: .purple)
                LiveStat(label: "Spent", value: Fmt.money(run.cost), symbol: "dollarsign.circle.fill", tint: .green)
                LiveStat(label: "Interruptions · lost", value: "\(run.interruptions) · \(Fmt.trim(run.lostHours, 0))h", symbol: "bolt.trianglebadge.exclamationmark",
                         tint: run.interruptions > 0 ? .orange : .gray)
            }

            if run.kind == .full { OpsPanel(run: run, state: s) }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Training loss").font(.caption.weight(.semibold))
                    LossChart(points: run.loss, checkpoints: run.saved.map(\.tokensT))
                        .frame(height: 170)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Projected final index").font(.caption.weight(.semibold))
                    ProjectionChart(checkpoints: run.saved, forecast: run.forecast)
                        .frame(height: 170)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cluster (\(Fmt.int(run.design.chips)) chips)").font(.caption.weight(.semibold))
                    ClusterHeatmap(chips: run.design.chips, active: run.status != .paused, failureRate: min(0.25, Double(run.design.chips) * Training.failuresPerChipDay * 30),
                                   phase: inPost ? .post : .pre)
                        .frame(height: 118)
                        .clipShape(.rect(cornerRadius: 8))
                    Text("Gradient norm").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    GradNormChart(points: run.loss)
                        .frame(height: 36)
                }
                .frame(width: 260)
            }

            // Checkpoints
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Checkpoints", systemImage: "externaldrive.badge.checkmark").font(.headline)
                    Text("every \(Int(run.interval * 100))%").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Fork a checkpoint to ship an early preview model while training continues.").font(.caption).foregroundStyle(.secondary)
                }
                if run.saved.isEmpty {
                    Text("The first checkpoint saves at \(Int(run.interval * 100))%.").font(.callout).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(run.saved.reversed()) { cp in
                                CheckpointCard(cp: cp, runID: run.id, canRollback: run.status != .postTraining || true)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .scrollIndicators(.automatic)
                }
            }

            // Settings & controls
            HStack(spacing: 14) {
                Picker("LR", selection: Binding(get: { run.schedule }, set: { v in store.mutate { $0.setRunSettings(run.id, lr: v, checkpointEvery: run.interval, autoRollback: run.autoRollback) } })) {
                    ForEach(LRSchedule.allCases) { l in Text(l.label).tag(l) }
                }
                .frame(width: 230)
                Picker("Checkpoint", selection: Binding(get: { run.interval }, set: { v in store.mutate { $0.setRunSettings(run.id, lr: run.schedule, checkpointEvery: v, autoRollback: run.autoRollback) } })) {
                    Text("2%").tag(0.02)
                    Text("5%").tag(0.05)
                    Text("10%").tag(0.1)
                    Text("25%").tag(0.25)
                }
                .frame(width: 170)
                Toggle("Auto-rollback", isOn: Binding(get: { run.autoRollback }, set: { v in store.mutate { $0.setRunSettings(run.id, lr: run.schedule, checkpointEvery: run.interval, autoRollback: v) } }))
                    .toggleStyle(.switch)
                Spacer()
                Button(showLog ? "Hide log" : "Run log", systemImage: "list.bullet.rectangle") { showLog.toggle() }
            }
            if showLog {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(run.events.prefix(14).enumerated()), id: \.offset) { _, e in
                        Text(e).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
            }
            HStack {
                if run.status == .paused {
                    Button("Resume", systemImage: "play.fill") { store.act("Resumed") { $0.setRunStatus(run.id, .running) } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Pause", systemImage: "pause.fill") { store.act("Paused — chips released") { $0.setRunStatus(run.id, .paused) } }
                }
                Button("Cancel run", systemImage: "xmark", role: .destructive) { store.act("Run cancelled") { $0.setRunStatus(run.id, .cancelled) } }
                Spacer()
                Text("Resize cluster").font(.caption).foregroundStyle(.secondary)
                QuantityPicker(value: $resize, range: 1...max(1, free + (run.status == .paused ? 0 : run.design.chips)))
                Button("Apply") { store.act("Cluster resized") { $0.resizeRun(run.id, chips: resize) } }
                    .disabled(resize == run.design.chips)
            }
        }
        .onAppear { resize = run.design.chips }
    }

    private func lossDelta(_ run: TrainingRun) -> String {
        guard let last = run.loss.last(where: { !$0.spike }), last.pred > 0 else { return run.loss.last.map { String(format: "%.3f", $0.loss) } ?? "—" }
        let d = last.loss - last.pred
        return String(format: "%.3f (%@%.3f)", last.loss, d <= 0 ? "−" : "+", abs(d))
    }
}

/// Agents watching the run's GPUs: coverage, what it buys and a way to add more.
private struct OpsPanel: View {
    @Environment(GameStore.self) private var store
    let run: TrainingRun
    let state: GameState
    @State private var assigning = false

    var body: some View {
        let s = state
        let b = store.derived.bonuses
        let chips = run.design.chips
        let cov = run.opsCoverage
        let now = Training.goodput(chips: chips, coverage: cov, state: s, bonuses: b)
        let full = Training.goodput(chips: chips, coverage: 1, state: s, bonuses: b)
        let watchers = s.swarms.filter { $0.mission == .trainingOps && !$0.paused && ($0.targetRunID == run.id || $0.targetRunID == nil) }
        let minutes = 1_440 / max(1e-9, Double(chips) * Training.failuresPerChipDay)
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Ops coverage", systemImage: "wrench.and.screwdriver.fill").font(.headline)
                    Spacer()
                    Text(Fmt.pct(cov, decimals: 0)).font(.headline.monospacedDigit())
                }
                Meter(value: cov, tint: cov >= 0.9 ? .green : (cov >= 0.5 ? .orange : .red), height: 8)
                Text(watchers.isEmpty ? "No agents watch this run. Human infra engineers handle restarts at human speed."
                                      : "Watched by \(watchers.map(\.name).joined(separator: ", ")).")
                    .font(.caption).foregroundStyle(.secondary)
                Text("A hardware fault every \(minutes < 60 ? "\(Int(minutes.rounded())) minutes" : Fmt.days(minutes / 1_440)) at this size.")
                    .font(.caption).foregroundStyle(.secondary)
                if full - now > 0.15 {
                    Label("This run loses \(Fmt.pct(1 - now, decimals: 0)) of its time to failures. Full ops coverage would get it to \(Fmt.pct(full, decimals: 0)).",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                if let adv = Training.goodputAdvice(chips: chips, coverage: cov, running: true, state: s, bonuses: b), adv.blocked || run.stalledDays >= 7 {
                    Text(run.stalledDays >= 7 ? "No progress in \(run.stalledDays) days. \(adv.headline)" : adv.headline)
                        .font(.caption).foregroundStyle(.red)
                    ForEach(adv.fixes, id: \.self) { fix in
                        Label(fix, systemImage: "wrench.and.screwdriver").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                LiveStat(label: "Goodput now", value: Fmt.pct(now, decimals: 0), symbol: "gauge.with.dots.needle.67percent", tint: now > 0.85 ? .green : .orange)
                LiveStat(label: "At full coverage", value: Fmt.pct(full, decimals: 0), symbol: "checkmark.seal.fill", tint: .teal)
                LiveStat(label: "Failures prevented", value: Fmt.count(run.prevented), symbol: "shield.checkered", tint: .indigo)
                LiveStat(label: "Corrupt nodes caught · missed", value: "\(Int(run.sdcCaught)) · \(Int(run.sdcMissed))", symbol: "exclamationmark.octagon.fill",
                         tint: run.sdcMissed >= 1 ? .red : .gray)
            }
            .frame(width: 360)
            Button("Assign agents…", systemImage: "person.3.sequence.fill") { assigning = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 10))
        .sheet(isPresented: $assigning) { OpsAssignSheet(run: run) }
    }
}

/// Point an ops swarm at a run, or spin up a new one sized for it.
private struct OpsAssignSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let run: TrainingRun
    @State private var modelID: UUID?
    @State private var accelID = ""
    @State private var target = 1.0

    var body: some View {
        let s = store.game
        let d = store.derived
        let b = d.bonuses
        let models = s.models.filter { !$0.retired }
            .sorted { Swarms.quality($0, s, mission: .trainingOps) > Swarms.quality($1, s, mission: .trainingOps) }
        let existing = s.swarms.filter { $0.mission == .trainingOps }
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ops agents for \(run.design.name)").font(.title2.weight(.bold))
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Agents read telemetry from every GPU: they drain nodes that are about to fail, restart the job from in-memory snapshots in seconds, quarantine nodes that silently corrupt gradients and rewind loss spikes. A run needs one engineer-equivalent per 600 chips; a smarter model covers more chips per agent.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !existing.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your ops swarms").font(.headline)
                    ForEach(existing) { sw in
                        HStack {
                            Text(sw.name).font(.callout.weight(.semibold))
                            Text("\(Fmt.count(sw.workforce)) engineer-eq · \(sw.targetRunID == run.id ? "watching this run" : (sw.targetRunID == nil ? "watching all runs" : "watching another run"))")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if sw.targetRunID == run.id {
                                Button("Watch all runs") { store.act("Swarm reassigned") { $0.setSwarmTarget(sw.id, runID: nil) } }
                            } else {
                                Button("Watch this run") { store.act("Swarm reassigned") { $0.setSwarmTarget(sw.id, runID: run.id) } }
                            }
                        }
                    }
                }
                Divider()
            }
            Text("New ops swarm").font(.headline)
            if models.isEmpty {
                Text("Train a model first: ops agents are copies of one of your models.").foregroundStyle(.secondary)
            } else {
                Picker("Model", selection: $modelID) {
                    ForEach(models) { m in
                        let q = Swarms.quality(m, s, mission: .trainingOps)
                        Text("\(m.name) · \(Swarms.tier(q)) · \(Fmt.trim(q, 2)) engineer-eq per agent").tag(UUID?.some(m.id))
                    }
                }
                Picker("Hardware", selection: $accelID) {
                    Text("Choose…").tag("")
                    ForEach(d.pools.filter { $0.free > 0 }) { p in Text("\(p.accel.name) — \(Fmt.int(p.free)) free").tag(p.accel.id) }
                }
                HStack {
                    Text("Coverage to add")
                    Slider(value: $target, in: 0.25...1, step: 0.05)
                    Text(Fmt.pct(target, decimals: 0)).monospacedDigit().frame(width: 50)
                }
                if let m = models.first(where: { $0.id == modelID }), !accelID.isEmpty {
                    let base = Training.agentsForCoverage(m, chips: max(1, Int(Double(run.design.chips) * target)), s, b)
                    let need = Int((Double(base) / 0.95).rounded(.up))
                    let chips = Swarms.chipsNeeded(m, accelID: accelID, agents: need, s, b)
                    let free = d.free(accelID)
                    let after = min(1, run.opsCoverage + target)
                    SpecRow(label: "Agents needed", value: Fmt.int(need))
                    SpecRow(label: "Inference chips", value: "\(Fmt.int(chips)) of \(Fmt.int(free)) free")
                    SpecRow(label: "Goodput", value: "\(Fmt.pct(Training.goodput(chips: run.design.chips, coverage: run.opsCoverage, state: s, bonuses: b), decimals: 0)) → \(Fmt.pct(Training.goodput(chips: run.design.chips, coverage: after, state: s, bonuses: b), decimals: 0))")
                    Button {
                        let ok = store.act("Ops agents deployed") {
                            $0.startSwarm(name: "\(run.design.name) Ops", modelID: m.id, agents: need, mission: .trainingOps, accelID: accelID,
                                          chips: max(1, min(chips, free)), autonomy: 1, oversight: 0.05, targetRunID: run.id)
                        }
                        if ok { dismiss() }
                    } label: {
                        Label("Deploy \(Fmt.int(need)) ops agents", systemImage: "person.3.sequence.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(chips > free)
                    if chips > free {
                        Text("Not enough idle \(HardwareCatalog.get(accelID)?.name ?? "chips"). Pick other hardware, free some up or aim for less coverage.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 640)
        .onAppear {
            if modelID == nil { modelID = models.first?.id }
            if accelID.isEmpty { accelID = d.pools.filter { $0.free > 0 }.max(by: { $0.free < $1.free })?.accel.id ?? "" }
        }
    }
}

private struct LiveStat: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).font(.caption).foregroundStyle(tint)
            Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 10))
    }
}

/// Stage pills with live progress through pre-training and each post-training phase.
private struct StageTimeline: View {
    let run: TrainingRun

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(run.stages.enumerated()), id: \.offset) { idx, st in
                let progress = progress(idx, st)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: progress >= 1 ? "checkmark.circle.fill" : (progress > 0 ? "circle.dotted.circle" : "circle"))
                            .foregroundStyle(progress >= 1 ? .green : (progress > 0 ? StageColors.color(st.name) : .secondary))
                            .symbolEffect(.pulse, isActive: progress > 0 && progress < 1 && run.status != .paused)
                        Text(st.name).font(.caption.weight(.semibold)).lineLimit(1)
                    }
                    Meter(value: progress, tint: StageColors.color(st.name), height: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))
    }

    private func progress(_ idx: Int, _ st: RunStage) -> Double {
        if st.isPre {
            var start = 0.0
            for (i, s) in run.stages.enumerated() where s.isPre {
                let share = s.flops / max(run.flopsTotal, 1)
                if i == idx { return clamp((run.progress - start) / max(share, 1e-9), 0, 1) }
                start += share
            }
            return 0
        }
        if run.status != .postTraining { return run.status == .done ? 1 : 0 }
        if idx < run.stageIndex { return 1 }
        if idx > run.stageIndex { return 0 }
        return clamp(run.stageDone / max(st.flops, 1), 0, 1)
    }
}

/// Forecast vs. what the run is actually showing.
private struct ForecastTracker: View {
    let run: TrainingRun
    let forecast: RunForecast

    var body: some View {
        let last = run.saved.last
        let ahead = run.revealMean
        let status: (String, Color, String) = {
            guard last != nil else { return ("Waiting for the first eval checkpoint", .secondary, "hourglass") }
            if abs(ahead) < max(0.02, forecast.sigma * 0.15) { return ("Right on forecast", .blue, "equal.circle.fill") }
            if ahead > 0 { return (ahead > forecast.sigma ? "Way ahead of forecast — this could be special" : "Tracking ahead of forecast", .green, "arrow.up.right.circle.fill") }
            return (ahead < -forecast.sigma ? "Well behind forecast — something's off" : "Tracking behind forecast", .orange, "arrow.down.right.circle.fill")
        }()
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Forecast at launch").font(.caption).foregroundStyle(.secondary)
                Text("\(Fmt.score(forecast.index))").font(.title2.weight(.bold).monospacedDigit())
                Text("\(Fmt.score(forecast.indexLow))–\(Fmt.score(forecast.indexHigh)) · \(forecast.tier)").font(.caption2).foregroundStyle(.secondary)
            }
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Projected now").font(.caption).foregroundStyle(.secondary)
                Text(last.map { Fmt.score($0.projected) } ?? "—").font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(status.1)
                    .contentTransition(.numericText())
                Text(last.map { "\(Fmt.score($0.projectedLow))–\(Fmt.score($0.projectedHigh))" } ?? "after first checkpoint").font(.caption2).foregroundStyle(.secondary)
            }
            Divider().frame(height: 40)
            Label(status.0, systemImage: status.2).font(.callout.weight(.semibold)).foregroundStyle(status.1)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Comparable to").font(.caption).foregroundStyle(.secondary)
                Text(forecast.comparable).font(.caption.weight(.semibold)).lineLimit(1)
            }
        }
        .padding(12)
        .background(status.1.opacity(0.08), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(status.1.opacity(0.25)))
    }
}

/// Projected final index after each checkpoint, against the launch forecast band.
struct ProjectionChart: View, Equatable {
    let checkpoints: [TrainCheckpoint]
    let forecast: RunForecast?

    var body: some View {
        if checkpoints.isEmpty {
            Text("Each eval checkpoint updates the projection.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                if let fc = forecast {
                    RectangleMark(xStart: .value("Start", 0), xEnd: .value("End", 100), yStart: .value("Low", fc.indexLow), yEnd: .value("High", fc.indexHigh))
                        .foregroundStyle(.gray.opacity(0.12))
                    RuleMark(y: .value("Forecast", fc.index)).foregroundStyle(.gray.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                ForEach(checkpoints) { cp in
                    AreaMark(x: .value("Progress", cp.fraction * 100), yStart: .value("Low", cp.projectedLow), yEnd: .value("High", cp.projectedHigh))
                        .foregroundStyle(.purple.opacity(0.18))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Progress", cp.fraction * 100), y: .value("Projected", cp.projected))
                        .foregroundStyle(.purple)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Progress", cp.fraction * 100), y: .value("Projected", cp.projected))
                        .foregroundStyle(cp.forkedModelID != nil ? .green : .purple)
                        .symbolSize(24)
                }
            }
            .chartXScale(domain: 0...100)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxisLabel("% of pre-training")
        }
    }
}

private struct GradNormChart: View {
    let points: [LossPoint]
    var body: some View {
        Chart(Array(points.suffix(120).enumerated()), id: \.offset) { _, p in
            LineMark(x: .value("t", p.tokensT), y: .value("‖g‖", min(p.gnorm, 4)))
                .foregroundStyle(p.spike ? .red : .gray)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct LossChart: View, Equatable {
    let points: [LossPoint]
    let checkpoints: [Double]

    var body: some View {
        if points.count < 2 {
            Text("Warming up…").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(Array(points.enumerated()).filter { $0.element.pred > 0 }, id: \.offset) { _, p in
                    LineMark(x: .value("Tokens (T)", p.tokensT), y: .value("Loss", p.pred), series: .value("Series", "Forecast"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.gray.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Tokens (T)", p.tokensT), y: .value("Loss", p.loss), series: .value("Series", "Actual"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.accentGradient)
                }
                ForEach(Array(points.enumerated()).filter { $0.element.spike }, id: \.offset) { _, p in
                    PointMark(x: .value("Tokens (T)", p.tokensT), y: .value("Loss", p.loss))
                        .foregroundStyle(.red)
                        .symbolSize(60)
                        .annotation(position: .top) { Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.red) }
                }
                ForEach(Array(checkpoints.enumerated()), id: \.offset) { _, t in
                    RuleMark(x: .value("Checkpoint", t))
                        .foregroundStyle(.green.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxisLabel("Tokens seen (T)")
        }
    }
}

struct EvalChart: View, Equatable {
    let checkpoints: [TrainCheckpoint]

    var body: some View {
        if checkpoints.isEmpty {
            Text("Evals run at each checkpoint.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(checkpoints) { cp in
                AreaMark(x: .value("Progress", cp.fraction * 100), y: .value("Index", cp.index))
                    .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.35), .purple.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Progress", cp.fraction * 100), y: .value("Index", cp.index))
                    .foregroundStyle(.purple)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Progress", cp.fraction * 100), y: .value("Index", cp.index))
                    .foregroundStyle(cp.forkedModelID != nil ? .green : .purple)
            }
            .chartXScale(domain: 0...100)
            .chartXAxisLabel("% of pre-training")
        }
    }
}

private struct CheckpointCard: View {
    @Environment(GameStore.self) private var store
    let cp: TrainCheckpoint
    let runID: UUID
    let canRollback: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(Int(cp.fraction * 100))%").font(.title3.weight(.bold).monospacedDigit())
                Spacer()
                if cp.forkedModelID != nil { Pill(text: "Forked", color: .green, symbol: "arrow.triangle.branch") }
            }
            Text("\(Fmt.tokens(cp.tokensT)) tokens · loss \(String(format: "%.3f", cp.loss))").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "checklist").font(.caption2).foregroundStyle(.purple)
                Text("Base eval \(Fmt.score(cp.index))").font(.caption.weight(.semibold))
            }
            if cp.projected > 0 {
                Text("→ final ≈ \(Fmt.score(cp.projected))").font(.caption2).foregroundStyle(.secondary)
            }
            Text(cp.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
            HStack(spacing: 6) {
                Button("Fork") { store.act("Preview model created") { $0.forkCheckpoint(runID, checkpoint: cp.id) } }
                    .disabled(cp.forkedModelID != nil)
                    .help("Ship this checkpoint as a preview model")
                Button("Roll back") { store.act("Rolled back") { $0.rollbackRun(runID, checkpoint: cp.id) } }
                    .disabled(!canRollback)
                    .help("Throw away everything after this checkpoint")
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(width: 170, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(cp.forkedModelID != nil ? Color.green.opacity(0.5) : .clear))
    }
}

/// A live, purely visual map of the cluster: every cell is a group of accelerators.
struct ClusterHeatmap: View {
    enum Phase { case pre, post }
    let chips: Int
    let active: Bool
    let failureRate: Double
    let phase: Phase

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { ctx in
            Canvas { g, size in
                let cells = min(max(chips, 1), 384)
                let cols = max(1, Int(ceil(sqrt(Double(cells) * size.width / max(size.height, 1)))))
                let rows = max(1, Int(ceil(Double(cells) / Double(cols))))
                // Square cells, capped so a handful of chips doesn't become one giant block; grid is centered.
                let side = min(size.width / CGFloat(cols), size.height / CGFloat(rows), 30)
                let w = side, h = side
                let ox = (size.width - side * CGFloat(cols)) / 2
                let oy = (size.height - side * CGFloat(rows)) / 2
                let t = ctx.date.timeIntervalSinceReferenceDate
                let tick = Int(t / 0.35)
                g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.85)))
                for i in 0..<cells {
                    let r = i / cols, c = i % cols
                    let rect = CGRect(x: ox + CGFloat(c) * w + 1, y: oy + CGFloat(r) * h + 1, width: max(1, w - 2), height: max(1, h - 2))
                    let seed = BenchmarkCatalog.hashUnit("\(i)-\(tick)")
                    var color: Color
                    if !active {
                        color = .gray.opacity(0.25)
                    } else if seed < failureRate * 0.02 {
                        color = .red
                    } else {
                        let load = 0.55 + 0.45 * sin(t * 2.2 + Double(i) * 0.37) * 0.5 + seed * 0.25
                        color = (phase == .pre ? Color.green : Color.purple).opacity(clamp(load, 0.25, 1))
                    }
                    g.fill(Path(roundedRect: rect, cornerRadius: min(w, h) * 0.2), with: .color(color))
                }
            }
        }
        .accessibilityLabel("Cluster activity map")
    }
}
