import Charts
import SwiftUI

struct TrainingView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let active = s.runs.filter { $0.status != .done && $0.status != .cancelled }
        let past = Array(s.runs.filter { $0.status == .done || $0.status == .cancelled }.reversed())
        // 3.5: one run at a time gets the full command centre; the switcher picks which.
        let focus = active.first { $0.id == store.focusRunID } ?? active.first { $0.kind == .full } ?? active.first
        let firsts = s.trainingFirsts.filter { !$0.quiet }
        Page(title: "Training Runs", subtitle: "Mission control. Watch the loss against the forecast, catch bugs, call the spikes — and find out whether you trained a genius.", screen: .training) {
            ScreenHint(.training)
            if active.isEmpty {
                Card {
                    EmptyStateView(symbol: "chart.line.downtrend.xyaxis", title: "Nothing training",
                                   message: "Design a model in the Model Lab — pick a recipe and hit start.",
                                   actionTitle: "Open Model Lab") { store.open(.lab) }
                }
            }
            if active.count > 1 {
                RunSwitcher(runs: active, selected: focus?.id, decisions: s.decisions) { store.focusRunID = $0 }
            }
            if let run = focus {
                if run.kind == .proxy {
                    LadderCard(run: run)
                } else {
                    CommandCentre(run: run, state: s, free: store.derived.free(run.design.accelID))
                        .id(run.id)
                }
            }
            if !firsts.isEmpty { LabHistoryCard(firsts: firsts) }
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
                                Text(run.kind == .proxy ? "scaling ladder · \(Fmt.flops(run.flopsTotal))" : "\(Fmt.params(run.design.paramsB)) · \(Fmt.tokens(run.design.tokensT)) tokens · \(run.design.parts.map { "\(Fmt.int($0.chips))× \(HardwareCatalog.get($0.accelID)?.name ?? "")" }.joined(separator: " + "))")
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
                        .help(run.modelID != nil ? "Open the results" : "")
                        Divider()
                    }
                }
            }
        }
        .overlay {
            // 3.5: a major run's launch sequence. Presentation only: the clock and the run carry on underneath.
            if let id = store.launchRunID, let run = s.runs.first(where: { $0.id == id }) {
                LaunchSequence(run: run, state: s) { store.launchRunID = nil }
            }
        }
    }
}

// MARK: - 3.5: run switcher

/// Every live run as a chip: pick one for the command centre. Runs with a call waiting are marked.
private struct RunSwitcher: View {
    let runs: [TrainingRun]
    let selected: UUID?
    let decisions: [Decision]
    let select: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(runs) { run in
                    let on = run.id == selected
                    let waiting = decisions.contains { $0.ref == run.id.uuidString }
                    Button { select(run.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: run.kind == .proxy ? "chart.line.uptrend.xyaxis" : run.design.objective.symbol).font(.caption)
                                Text(run.design.name).font(.callout.weight(.semibold)).lineLimit(1)
                                if waiting { Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange).font(.caption) }
                            }
                            Text(run.status == .paused ? "Paused" : (run.kind == .proxy ? "Scaling ladder" : Training.currentStageName(run)))
                                .font(.caption2).foregroundStyle(.secondary)
                            Meter(value: run.status == .postTraining ? run.postTrainDone / max(run.postTrainFlops, 1) : run.progress,
                                  tint: run.status == .postTraining ? .purple : .blue, height: 4)
                        }
                        .padding(9)
                        .frame(width: 170, alignment: .leading)
                        .background(on ? AnyShapeStyle(Color.accentColor.opacity(0.16)) : AnyShapeStyle(.quaternary.opacity(0.35)), in: .rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Color.accentColor.opacity(0.6) : Color.clear))
                        .contentShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 2)
        }
        .scrollIndicators(.never)
    }
}

// MARK: - 3.5: lab history

/// Your lab's training firsts, newest first: the company's own milestones, each shown once when it happens.
private struct LabHistoryCard: View {
    let firsts: [TrainingFirst]
    @State private var all = false

    var body: some View {
        let list = Array(firsts.reversed())
        Card {
            CardHeader(title: "Lab history", symbol: "rosette", subtitle: "Training firsts — each one happens only once") {
                if list.count > 4 { Button(all ? "Show fewer" : "Show all \(list.count)") { all.toggle() }.buttonStyle(.link) }
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array((all ? list : Array(list.prefix(4))).enumerated()), id: \.element.id) { i, f in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Image(systemName: f.symbol)
                                .font(.callout.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
                                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                            if i < (all ? list.count : min(4, list.count)) - 1 {
                                Rectangle().fill(.quaternary).frame(width: 2, height: 22)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(f.title).font(.callout.weight(.semibold))
                                Spacer()
                                Text(f.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Text("\(f.model)\(f.detail.isEmpty ? "" : " — \(f.detail)")").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 3.5: launch sequence

/// A short, skippable presentation for a major run: identity, architecture, cluster, sites and compute, then the
/// command centre. Purely visual — the run started the moment you clicked Launch. With Reduce Motion it shows
/// everything at once without animation.
private struct LaunchSequence: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let run: TrainingRun
    let state: GameState
    let done: () -> Void
    @State private var step = 0

    private static let steps = 5

    var body: some View {
        let d = run.design
        let s = state
        let a = HardwareCatalog.get(d.accelID)
        let arch = TrainingExperience.sketch(d, state: s)
        let sites = siteNames(s)
        let scale = TrainingExperience.RunScale(rawValue: run.plan?.scale ?? 1) ?? .standard
        let shown = reduceMotion ? Self.steps : step
        ZStack {
            Rectangle().fill(.black.opacity(0.88)).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Pill(text: scale.label.uppercased(), color: scaleColor(scale), symbol: "flame.fill")
                    Spacer()
                    Button(shown >= Self.steps ? "Open the command centre" : "Skip") { done() }
                        .keyboardShortcut(.cancelAction)
                }
                if shown >= 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(d.family.isEmpty ? "\(d.objective.label) model" : "\(d.family)\(d.generation > 0 ? " · generation \(d.generation)" : "")")
                            .font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                        Text(d.name).font(.system(size: 56, weight: .black)).foregroundStyle(.white)
                        if !d.blurb.isEmpty { Text(d.blurb).font(.title3).foregroundStyle(.white.opacity(0.75)) }
                    }
                    .transition(.opacity)
                }
                if shown >= 2 {
                    line("square.stack.3d.up.fill", "Architecture",
                         "\(Fmt.params(d.paramsB)) parameters\(d.isMoE ? " · \(arch.experts) experts, \(arch.activeExperts) active (\(Fmt.params(d.activeParamsB)))" : "") · \(arch.layers) layers · \(d.attention.rawValue) attention · \(d.contextK >= 1000 ? "1M" : "\(d.contextK)K") context")
                }
                if shown >= 3 {
                    line("cpu.fill", "Cluster",
                         "\(Fmt.int(d.chips))× \(a?.name ?? "accelerators") · \(powerText(run.plan?.powerMW ?? 0)) · \(sites)")
                }
                if shown >= 4 {
                    line("bolt.fill", "Compute",
                         "\(Fmt.flops(run.flopsTotal + run.postTrainFlops)) FLOPs"
                         + (run.plan.map { $0.frontierShare >= 0.05 ? " · \(Fmt.trim($0.frontierShare, 2))× the largest known run" : "" } ?? "")
                         + (run.plan.map { $0.days > 0 ? " · \(Fmt.days($0.days)), done ~\($0.finish.gameShort)" : "" } ?? ""))
                }
                if shown >= 5 {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Training has started").font(.title2.weight(.bold)).foregroundStyle(.white)
                            if let fc = run.forecast {
                                Text("Forecast: index \(Fmt.score(fc.index)) (\(Fmt.score(fc.indexLow))–\(Fmt.score(fc.indexHigh))) · \(fc.tier)")
                                    .font(.callout).foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }
                Spacer()
                Toggle("Play launch sequences for major runs", isOn: Binding(get: { store.showLaunchSequence }, set: { store.showLaunchSequence = $0 }))
                    .toggleStyle(.checkbox).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(48)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .contentShape(.rect)
        .onTapGesture { if shown >= Self.steps { done() } else { step = Self.steps } }
        .task {
            guard !reduceMotion else { return }
            for i in 1...Self.steps {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 150 : 800))
                withAnimation(.easeOut(duration: 0.4)) { step = max(step, i) }
            }
        }
    }

    private func line(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.cyan).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.5))
                Text(text).font(.title3.weight(.semibold)).foregroundStyle(.white)
            }
        }
        .transition(.opacity)
    }

    /// Where the run's chips are: owned batches by site, plus rented cloud capacity.
    private func siteNames(_ s: GameState) -> String {
        let ids = Set(s.owned.filter { $0.accelID == run.design.accelID }.map(\.siteID))
        var names = s.sites.filter { ids.contains($0.id) }.map { "\($0.name) (\($0.location.name))" }
        if s.rentals.contains(where: { $0.accelID == run.design.accelID }) { names.append("rented cloud capacity") }
        return names.isEmpty ? "your fleet" : names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " and \(names.count - 3) more" : "")
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

/// 3.5: the training command centre — one run, every number from the simulation: progress and stage, loss and a
/// derived validation curve, the capability projection against the launch forecast, where the cluster's compute is
/// going (and what limits it), cost, energy, failures, checkpoints, ops coverage and the calls waiting for you.
private struct CommandCentre: View {
    @Environment(GameStore.self) private var store
    let run: TrainingRun
    let state: GameState
    let free: Int
    @State private var resize = 0
    @State private var showLog = false
    @State private var assigning = false

    var body: some View {
        let s = state
        let b = store.derived.bonuses
        let a = HardwareCatalog.get(run.design.accelID)
        let mfu = a.map { Physics.mfu(accel: $0, chips: run.design.allChips, state: s, bonuses: b) } ?? 0
        let good = Physics.goodput(chips: run.design.allChips, state: s, bonuses: b, coverage: run.opsCoverage) * Sim.checkpointOverhead(run.interval)
        let flopsPerSec = Physics.throughputChips(run.design) * (a?.trainTFLOPS(run.design.precision) ?? 0) * 1e12 * mfu * good * run.schedule.speed
        let perDay = flopsPerSec * 86_400
        let postTotal = run.postTrainFlops
        let total = run.flopsTotal + postTotal
        let doneFlops = min(run.flopsDone, run.flopsTotal) + run.postTrainDone
        let remaining = max(0, run.flopsTotal - run.flopsDone) + max(0, postTotal - run.postTrainDone)
        let eta = perDay > 0 ? remaining / perDay : .infinity
        let inPost = run.status == .postTraining
        let tokensPerSec = flopsPerSec / (6 * max(run.design.activeParamsB, 0.001) * 1e9)
        let daily = Physics.dailyChipCost(run.design, state: s)
        let power = run.design.parts.reduce(0.0) { acc, p in acc + (HardwareCatalog.get(p.accelID).map { TrainingExperience.powerMW(chips: p.chips, accel: $0, state: s) } ?? 0) }
        let decisions = s.decisions.filter { $0.ref == run.id.uuidString }
        let actual = TrainingExperience.actualSlices(run.ledger)
        let incidentShare = run.plan.map { $0.days > 0 ? $0.incidentDays / $0.days : 0 } ?? 0
        let expected = TrainingExperience.expectedSlices(run.design, coverage: run.opsCoverage, interval: run.interval, incidentShare: incidentShare, state: s)
        let basis = (run.ledger.days >= 3 ? actual : nil) ?? expected
        let bottleneck = TrainingExperience.bottleneck(basis, design: run.design, coverage: run.opsCoverage, interval: run.interval, running: true, state: s)
        let scale = TrainingExperience.RunScale(rawValue: run.plan?.scale ?? 1) ?? .standard
        let lambda = Double(run.design.allChips) * Training.failuresPerChipDay * (1 - Training.opsEffect(run.opsCoverage, s).prevented)
        let progress = total > 0 ? doneFlops / total : 0
        let projected = run.cost + daily * (eta.isFinite ? eta : 0)
        let plannedCost = run.plan?.cost ?? 0
        let overBudget = eta.isFinite && plannedCost > 0 && projected > plannedCost * 1.15

        Card {
            hero(run, scale: scale, progress: progress, eta: eta, inPost: inPost, accel: a, mfu: mfu, good: good, s)
            StageTimeline(run: run)
            if !decisions.isEmpty { decisionStrip(decisions) }
            if let fc = run.forecast { ForecastTracker(run: run, forecast: fc) }

            // Vital signs
            EqualColumns(minWidth: 120, spacing: 10, maxColumns: 6) {
                LiveStat(label: "Tokens / sec", value: Fmt.count(tokensPerSec), symbol: "text.word.spacing", tint: .blue)
                LiveStat(label: "Effective compute", value: Fmt.tflops(flopsPerSec / 1e12), symbol: "bolt.fill", tint: .yellow)
                LiveStat(label: "Loss vs forecast", value: lossDelta(run), symbol: "chart.line.downtrend.xyaxis", tint: .teal)
                LiveStat(label: "Base-model eval", value: run.saved.last.map { Fmt.score($0.index) } ?? "—", symbol: "checklist", tint: .purple)
                LiveStat(label: "Compute done · left", value: "\(Fmt.flops(doneFlops)) · \(Fmt.flops(remaining))", symbol: "cpu", tint: .indigo)
                LiveStat(label: "Spent · projected", value: "\(Fmt.money(run.cost)) · \(eta.isFinite ? Fmt.money(projected) : "—")", symbol: "dollarsign.circle.fill",
                         tint: overBudget ? .orange : .green)
                LiveStat(label: "Power · energy", value: "\(powerText(power)) · \(run.ledger.tracked ? energyText(run.ledger.energyMWh) : "—")", symbol: "powerplug.fill", tint: .orange)
                LiveStat(label: "Interruptions · lost", value: "\(run.interruptions) · \(Fmt.trim(run.lostHours, 0))h", symbol: "bolt.trianglebadge.exclamationmark",
                         tint: run.interruptions > 0 ? .orange : .gray)
                LiveStat(label: "Stability: spikes · ‖g‖", value: "\(run.spikes) · \(run.loss.last.map { Fmt.trim($0.gnorm, 2) } ?? "—")", symbol: "waveform.path.ecg",
                         tint: run.spikes > 0 ? .orange : .green)
                LiveStat(label: "Checkpoints", value: "\(run.saved.count) · every \(Int(run.interval * 100))%", symbol: "externaldrive.badge.checkmark", tint: .teal)
                LiveStat(label: "Ops coverage", value: Fmt.pct(run.opsCoverage, decimals: 0), symbol: "wrench.and.screwdriver.fill",
                         tint: run.opsCoverage >= 0.9 ? .green : (run.opsCoverage >= 0.5 ? .orange : .red))
                LiveStat(label: "Forecast confidence", value: confidence(run), symbol: "scope", tint: .purple)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Loss").font(.caption.weight(.semibold))
                        Text("— training · ⋯ forecast · ╌ validation (derived)").font(.caption2).foregroundStyle(.secondary)
                    }
                    LossChart(points: run.loss, checkpoints: run.saved.map(\.tokensT),
                              validation: TrainingExperience.validation(run, state: s)
                                  .map { LossChart.Pair(t: $0.tokensT, l: $0.loss) })
                        .equatable()
                        .frame(height: 170)
                        .help("Validation is the training loss averaged over five points plus a generalisation gap of 0.01 per extra pass over the data. The simulation draws only the training loss.")
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Capability estimate vs forecast band").font(.caption.weight(.semibold))
                    ProjectionChart(checkpoints: run.saved, forecast: run.forecast)
                        .equatable()
                        .frame(height: 170)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cluster (\(Fmt.int(run.design.allChips)) chips)").font(.caption.weight(.semibold))
                    ClusterHeatmap(chips: run.design.allChips, active: run.status != .paused && store.speed > 0, mfu: mfu,
                                   goodput: Training.goodput(chips: run.design.allChips, coverage: run.opsCoverage, state: s, bonuses: b),
                                   failuresPerDay: lambda, daysPerSecond: GameStore.speeds[min(store.speed, GameStore.speeds.count - 1)].daysPerSecond,
                                   coverage: run.opsCoverage, phase: inPost ? .post : .pre)
                        .frame(height: 118)
                        .clipShape(.rect(cornerRadius: 8))
                    Text(heatmapLegend(mfu: mfu, lambda: lambda)).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    Text("Gradient norm").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    GradNormChart(points: run.loss)
                        .frame(height: 30)
                }
                .frame(width: 260)
            }

            computePanel(actual: actual, expected: expected, bottleneck: bottleneck)

            if run.kind == .full { OpsPanel(run: run, state: s, assigning: $assigning) }

            // Checkpoints
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Checkpoints", systemImage: "externaldrive.badge.checkmark").font(.headline)
                    Text("every \(Int(run.interval * 100))%").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Fork a checkpoint to ship an early preview model while training continues; roll back to throw away what came after.").font(.caption).foregroundStyle(.secondary)
                }
                if run.saved.isEmpty {
                    Text("The first checkpoint saves at \(Int(run.interval * 100))%.").font(.callout).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(run.saved.reversed()) { cp in
                                CheckpointCard(cp: cp, runID: run.id, canRollback: true)
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
                Button(showLog ? "Fewer ops notes" : "All ops notes", systemImage: "list.bullet.rectangle") { showLog.toggle() }
            }
            opsNotes(run)
            HStack {
                if run.status == .paused {
                    Button("Resume", systemImage: "play.fill") { store.act("Resumed") { $0.setRunStatus(run.id, .running) } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Pause", systemImage: "pause.fill") { store.act("Paused — chips released") { $0.setRunStatus(run.id, .paused) } }
                }
                Button("Cancel run", systemImage: "xmark", role: .destructive) { store.act("Run cancelled") { $0.setRunStatus(run.id, .cancelled) } }
                Spacer()
                if resize != run.design.chips, let note = resizeNote(run) { Text(note).font(.caption).foregroundStyle(.secondary) }
                Text("Resize cluster").font(.caption).foregroundStyle(.secondary)
                QuantityPicker(value: $resize, range: 1...max(1, free + (run.status == .paused ? 0 : run.design.chips)))
                Button("Apply") { store.act("Cluster resized") { $0.resizeRun(run.id, chips: resize) } }
                    .disabled(resize == run.design.chips)
            }
        }
        .onAppear { resize = run.design.chips }
        .sheet(isPresented: $assigning) { OpsAssignSheet(run: run) }
    }

    // MARK: Pieces

    private func hero(_ run: TrainingRun, scale: TrainingExperience.RunScale, progress: Double, eta: Double, inPost: Bool, accel a: Accelerator?,
                      mfu: Double, good: Double, _ s: GameState) -> some View {
        let d = run.design
        return HStack(alignment: .top, spacing: 16) {
            if let a {
                Photo(key: a.image)
                    .frame(width: 120, height: 80)
                    .clipShape(.rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(d.name).font(.title2.weight(.bold))
                    Pill(text: run.status == .paused ? "Paused" : Training.currentStageName(run), color: run.status == .paused ? .orange : (inPost ? .purple : .blue))
                    if scale >= .major { Pill(text: scale.label, color: scaleColor(scale), symbol: "flame.fill") }
                    if d.objective != .general { Pill(text: d.objective.label, color: .indigo, symbol: d.objective.symbol) }
                    if run.stalledDays >= 7 { Pill(text: "Stalled \(run.stalledDays) days", color: .red) }
                    if d.isMoE { Pill(text: "MoE \(TrainingExperience.experts(for: d.activeFraction).label)", color: .teal) }
                    if d.reasoning { Pill(text: "RL: \(d.effectiveRL.label)", color: .pink) }
                    if d.optimizer != .adamw { Pill(text: d.optimizer.rawValue, color: .indigo) }
                    Pill(text: "LR: \(run.schedule.label)", color: run.schedule == .aggressive ? .orange : .secondary)
                }
                if !d.family.isEmpty || !d.blurb.isEmpty {
                    Text([d.family.isEmpty ? nil : "\(d.family)\(d.generation > 0 ? " gen \(d.generation)" : "")", d.blurb.isEmpty ? nil : d.blurb].compactMap { $0 }.joined(separator: " · "))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Text("\(Fmt.params(d.paramsB)) params (\(Fmt.params(d.activeParamsB)) active) · \(Fmt.tokens(d.tokensT)) tokens · \(d.precision.short) · \(d.contextK >= 1000 ? "1M" : "\(d.contextK)K") context")
                    .font(.callout).foregroundStyle(.secondary)
                Text("\(Fmt.int(d.chips))× \(a?.name ?? "?") · MFU \(Fmt.pct(mfu, decimals: 0)) · goodput \(Fmt.pct(good, decimals: 0))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.pct(progress, decimals: 1)).font(TypeRamp.bannerMetric)
                    .contentTransition(.numericText())
                Meter(value: progress, tint: inPost ? .purple : .blue, height: 7).frame(width: 170)
                Text(run.status == .paused ? "Paused — waiting for you" : (eta.isFinite ? "\(Fmt.days(eta)) left · ~\(GameCalendar.addDays(s.date, Int(eta.rounded(.up))).gameShort)" : "Not progressing"))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if let p = run.plan, p.days > 0 {
                    Text("Planned: \(Fmt.days(p.days)), ~\(p.finish.gameShort)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// Calls this run is waiting on — set apart from the routine ops notes below.
    private func decisionStrip(_ decisions: [Decision]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(decisions.count == 1 ? "A call is waiting" : "\(decisions.count) calls are waiting", systemImage: "exclamationmark.bubble.fill")
                .font(.headline).foregroundStyle(.orange)
            ForEach(decisions) { dcs in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dcs.title).font(.callout.weight(.semibold))
                        Text(dcs.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Button("Decide…") { store.openDecisionID = dcs.id }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.45)))
    }

    private func computePanel(actual: [TrainingExperience.Slice]?, expected: [TrainingExperience.Slice], bottleneck: TrainingExperience.Bottleneck?) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Where the compute goes", systemImage: "chart.bar.xaxis").font(.headline)
                    HelpButton(term: .goodput)
                    Spacer()
                    if run.ledger.since > 0.005 {
                        Text("tracked from \(Fmt.pct(run.ledger.since, decimals: 0))").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                if let actual {
                    Text("So far (\(run.ledger.days) day\(run.ledger.days == 1 ? "" : "s"), \(Fmt.flops(run.ledger.peak)) peak FLOPs)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    ComputeBar(slices: actual).equatable()
                }
                Text(actual == nil ? "Expected" : "Expected at this coverage").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                ComputeBar(slices: expected, compact: actual != nil).equatable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                if let bottleneck {
                    BottleneckCard(bottleneck: bottleneck) { perform($0) }
                } else {
                    Label("No single bottleneck: the cluster is close to as good as it gets.", systemImage: "checkmark.seal.fill")
                        .font(.callout).foregroundStyle(.green)
                }
            }
            .frame(width: 380, alignment: .topLeading)
        }
        .padding(12)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }

    @ViewBuilder
    private func opsNotes(_ run: TrainingRun) -> some View {
        let notes = Array(run.events.prefix(showLog ? 20 : 4))
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("Ops notes — routine, no action needed").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                ForEach(Array(notes.enumerated()), id: \.offset) { _, e in
                    Text(e).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
        }
    }

    private func perform(_ action: TrainingExperience.FixAction) {
        switch action {
        case .resizeRun(let n): store.act("Cluster resized") { $0.resizeRun(run.id, chips: n) }
        case .runCheckpoint(let v): store.mutate { $0.setRunSettings(run.id, lr: run.schedule, checkpointEvery: v, autoRollback: run.autoRollback) }
        case .runLR(let l): store.mutate { $0.setRunSettings(run.id, lr: l, checkpointEvery: run.interval, autoRollback: run.autoRollback) }
        case .assignOps: assigning = true
        case .open(let screen): store.open(screen)
        default: break
        }
    }

    /// 3.9: what the chosen cluster size would do to the finish date, from the same flops-per-day model the estimate uses.
    private func resizeNote(_ run: TrainingRun) -> String? {
        var now = run.design, then = run.design
        then.chips = max(1, resize)
        let s = store.game
        let a = Physics.flopsPerDay(now, state: s, lr: run.schedule, interval: run.interval)
        let b = Physics.flopsPerDay(then, state: s, lr: run.schedule, interval: run.interval)
        guard a > 0, b > 0 else { return nil }
        now.chips = run.design.chips
        let postTotal = run.stages.filter { !$0.isPre }.reduce(0.0) { $0 + $1.flops }
        let left = max(0, run.flopsTotal - run.flopsDone) + max(0, postTotal - run.postTrainDone)
        let was = left / a, will = left / b
        return "\(resize > run.design.chips ? "Adding" : "Removing") \(Fmt.int(abs(resize - run.design.chips))) chips: about \(Fmt.days(was)) left becomes \(Fmt.days(will))"
    }

    private func confidence(_ run: TrainingRun) -> String {
        guard let fc = run.forecast else { return "—" }
        let sd = run.saved.isEmpty ? fc.sigma : run.revealSigma
        return "±\(Fmt.trim(sd, 2))" + (run.saved.isEmpty ? "" : " (was ±\(Fmt.trim(fc.sigma, 2)))")
    }

    private func heatmapLegend(mfu: Double, lambda: Double) -> String {
        let cells = min(max(run.design.chips, 1), 384)
        let per = Int((Double(run.design.chips) / Double(cells)).rounded(.up))
        let minutes = 1_440 / max(lambda, 1e-9)
        let every = minutes < 60 ? "\(Int(minutes.rounded())) min" : (minutes < 2_880 ? "\(Fmt.trim(minutes / 60, 1)) h" : Fmt.days(minutes / 1_440))
        return "\(per == 1 ? "1 chip" : "\(per) chips") per cell · brightness = MFU \(Fmt.pct(mfu, decimals: 0)) · amber = lost to failures · a fault every \(every)"
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
    @Binding var assigning: Bool

    var body: some View {
        let s = state
        let b = store.derived.bonuses
        let chips = run.design.allChips
        let cov = run.opsCoverage
        let now = Training.goodput(chips: chips, coverage: cov, state: s, bonuses: b)
        let full = Training.goodput(chips: chips, coverage: 1, state: s, bonuses: b)
        let watchers = s.swarms.filter { $0.mission == .trainingOps && !$0.paused && ($0.targetRunID == run.id || $0.targetRunID == nil) }
        let minutes = 1_440 / max(1e-9, Double(chips) * Training.failuresPerChipDay)
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Ops coverage", systemImage: "wrench.and.screwdriver.fill").font(.headline)
                    HelpButton(term: .goodput)
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
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
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
        MetricTile(label: label, value: value, symbol: symbol, tint: tint, style: .tinted)
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
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
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
    struct Pair: Hashable {
        let t: Double
        let l: Double
    }

    let points: [LossPoint]
    let checkpoints: [Double]
    /// 3.5: the derived validation series (`TrainingExperience.validation`), drawn dashed when present.
    var validation: [Pair] = []

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
                ForEach(Array(validation.enumerated()), id: \.offset) { _, v in
                    LineMark(x: .value("Tokens (T)", v.t), y: .value("Loss", v.l), series: .value("Series", "Validation"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.purple.opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
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
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(cp.forkedModelID != nil ? Color.green.opacity(0.5) : .clear))
    }
}

/// A live map of the cluster, every cell a group of accelerators, driven by the run's real rates: cell brightness is
/// MFU, the share of amber cells is the time lost to failures and restarts (1 − goodput), and red cells flash at the
/// fault rate the simulation draws from, scaled to game time (faults per chip-day × chips per cell × game days per
/// frame). Ops-watched cells get a thin outline. Paused game or run: one static frame.
struct ClusterHeatmap: View {
    enum Phase { case pre, post }
    let chips: Int
    let active: Bool
    let mfu: Double
    let goodput: Double
    let failuresPerDay: Double
    let daysPerSecond: Double
    let coverage: Double
    let phase: Phase

    private static let frame = 0.35

    var body: some View {
        TimelineView(.animation(minimumInterval: Self.frame, paused: !active)) { ctx in
            Canvas { g, size in
                let cells = min(max(chips, 1), 384)
                let cols = max(1, Int(ceil(sqrt(Double(cells) * size.width / max(size.height, 1)))))
                let rows = max(1, Int(ceil(Double(cells) / Double(cols))))
                // Square cells, capped so a handful of chips doesn't become one giant block; grid is centered.
                let side = min(size.width / CGFloat(cols), size.height / CGFloat(rows), 30)
                let ox = (size.width - side * CGFloat(cols)) / 2
                let oy = (size.height - side * CGFloat(rows)) / 2
                let t = ctx.date.timeIntervalSinceReferenceDate
                let tick = Int(t / Self.frame)
                // Chance a cell sees a fault during one frame of game time.
                let perCell = failuresPerDay / Double(cells)
                let pFault = 1 - exp(-perCell * daysPerSecond * Self.frame)
                let lost = clamp(1 - goodput, 0, 1)
                let watched = Int((Double(cells) * clamp(coverage, 0, 1)).rounded())
                let bright = clamp(mfu / 0.7, 0.2, 1)
                g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.85)))
                for i in 0..<cells {
                    let r = i / cols, c = i % cols
                    let rect = CGRect(x: ox + CGFloat(c) * side + 1, y: oy + CGFloat(r) * side + 1, width: max(1, side - 2), height: max(1, side - 2))
                    let seed = Self.noise(i, tick)
                    let color: Color
                    if !active {
                        color = .gray.opacity(0.25)
                    } else if seed < pFault {
                        color = .red
                    } else if Self.noise(i &+ 7_919, tick / 4) < lost {
                        color = .orange.opacity(0.75)
                    } else {
                        let flicker = 0.85 + 0.15 * sin(t * 2.2 + Double(i) * 0.37)
                        color = (phase == .pre ? Color.green : Color.purple).opacity(clamp(bright * flicker, 0.2, 1))
                    }
                    g.fill(Path(roundedRect: rect, cornerRadius: side * 0.2), with: .color(color))
                    if i < watched && side >= 6 {
                        g.stroke(Path(roundedRect: rect, cornerRadius: side * 0.2), with: .color(.cyan.opacity(0.5)), lineWidth: 0.6)
                    }
                }
            }
        }
        .accessibilityLabel("Cluster activity map: MFU \(Int(mfu * 100))%, goodput \(Int(goodput * 100))%")
    }

    /// Cheap per-cell flicker in 0..<1 (integer mix, no string hashing on every frame).
    private static func noise(_ i: Int, _ tick: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: i) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(truncatingIfNeeded: tick) &* 0xC2B2_AE3D_27D4_EB4F
        h ^= h >> 31
        h = h &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 29
        return Double(h >> 11) / Double(1 << 53)
    }
}
