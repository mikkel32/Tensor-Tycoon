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
                        // Finished runs open their results; cancelled runs and scaling ladders have none, so they're plain rows.
                        if run.modelID != nil {
                            Button { store.reportRunID = run.id } label: { historyRow(run, s) }
                                .buttonStyle(.plain)
                                .help("Open the results")
                        } else {
                            historyRow(run, s)
                        }
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

extension TrainingView {
    /// One finished, cancelled or ladder run in the history list.
    func historyRow(_ run: TrainingRun, _ s: GameState) -> some View {
        let model = run.modelID.flatMap { id in s.models.first { $0.id == id } }
        return HStack {
            Image(systemName: run.kind == .proxy ? "chart.line.uptrend.xyaxis" : (run.status == .done ? "checkmark.circle.fill" : "xmark.circle.fill"))
                .foregroundStyle(run.status == .done ? (run.kind == .proxy ? .indigo : .green) : .secondary)
            Text(run.design.name).font(.callout.weight(.semibold))
            Text(run.kind == .proxy ? "scaling ladder · \(Fmt.flops(run.flopsTotal))" : "\(Fmt.params(run.design.paramsB)) · \(Fmt.tokens(run.design.tokensT)) tokens · \(Fmt.int(run.design.chips))× \(HardwareCatalog.get(run.design.accelID)?.name ?? "")")
                .font(.caption).foregroundStyle(.secondary)
            if run.spikes > 0 { Pill(text: "\(run.spikes) spikes", color: .orange) }
            if run.endedEarlyAt > 0 { Pill("ended at \(Int(run.endedEarlyAt * 100))%", tone: .info) }
            if let model {
                Pill(text: "Index \(Fmt.score(store.derived.entry(model.id)?.index ?? model.index))", color: .purple)
                if let fc = run.forecast, !run.forecastHidden {
                    let delta = model.index - fc.index
                    Pill(text: abs(delta) < 1.5 ? "on forecast" : (delta > 0 ? "+\(Fmt.trim(delta, 1)) vs forecast" : "\(Fmt.trim(delta, 1)) vs forecast"),
                         color: abs(delta) < 1.5 ? .secondary : (delta > 0 ? .green : .orange))
                }
            } else if run.status == .cancelled {
                Text(run.note.isEmpty ? "Cancelled" : run.note).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(Fmt.flops(run.flopsDone)) FLOPs · \(Fmt.money(run.cost))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(run.started.gameShort).font(.caption).foregroundStyle(.tertiary)
            if run.modelID != nil { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
        }
        .contentShape(.rect)
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
    @State private var online = 0.0

    /// The beats of the sequence: a major run gets five, a frontier run (half the largest known run or more) seven,
    /// with the datacenters it spans, the cluster coming online and how it measures against the field.
    private enum Beat { case identity, architecture, sites, cluster, compute, power, started }

    private var frontier: Bool { (TrainingExperience.RunScale(rawValue: run.plan?.scale ?? 1) ?? .standard) >= .frontier }
    private var beats: [Beat] { frontier ? [.identity, .architecture, .sites, .cluster, .compute, .power, .started] : [.identity, .architecture, .cluster, .compute, .started] }
    private var calm: Bool { reduceMotion || store.reduceAnimations }

    var body: some View {
        let d = run.design
        let s = state
        let a = HardwareCatalog.get(d.accelID)
        let arch = TrainingExperience.sketch(d, state: s)
        let scale = TrainingExperience.RunScale(rawValue: run.plan?.scale ?? 1) ?? .standard
        let shown = calm ? beats.count : step
        let ref = TrainingExperience.frontierReference(s)
        ZStack {
            Rectangle().fill(.black.opacity(0.9)).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Pill(text: scale.label.uppercased(), color: scaleColor(scale), symbol: "flame.fill")
                    Spacer()
                    Button(shown >= beats.count ? "Open the command centre" : "Skip") { done() }
                        .keyboardShortcut(.cancelAction)
                }
                ForEach(Array(beats.prefix(shown).enumerated()), id: \.offset) { _, beat in
                    switch beat {
                    case .identity:
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.family.isEmpty ? "\(d.objective.label) model" : "\(d.family)\(d.generation > 0 ? " · generation \(d.generation)" : "")")
                                .font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                            Text(d.name).font(.system(size: frontier ? 64 : 56, weight: .black)).foregroundStyle(.white)
                            if !d.blurb.isEmpty { Text(d.blurb).font(.title3).foregroundStyle(.white.opacity(0.75)) }
                        }
                        .transition(.opacity)
                    case .architecture:
                        line("square.stack.3d.up.fill", "Architecture",
                             "\(Fmt.params(d.paramsB)) parameters\(d.isMoE ? " · \(arch.experts) experts, \(arch.activeExperts) active (\(Fmt.params(d.activeParamsB)))" : "") · \(arch.layers) layers · \(d.attention.rawValue) attention · \(d.contextK >= 1000 ? "1M" : "\(d.contextK)K") context")
                    case .sites:
                        line("building.2.fill", "Datacenters", siteNames(s, all: true))
                    case .cluster:
                        VStack(alignment: .leading, spacing: 6) {
                            line("cpu.fill", "Cluster", "\(Fmt.int(d.chips))× \(a?.name ?? "accelerators") · ops agents watching \(Fmt.pct(run.opsCoverage, decimals: 0))\(frontier ? "" : " · \(siteNames(s, all: false))")")
                            if frontier {
                                // The chips coming online, as the scheduler brings the job up domain by domain.
                                ProgressView(value: calm ? 1 : online)
                                    .tint(.green)
                                    .frame(maxWidth: 560)
                                Text("\(Fmt.int(Int(Double(d.chips) * (calm ? 1 : online)))) of \(Fmt.int(d.chips)) accelerators online")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    case .compute:
                        line("bolt.fill", "Compute",
                             "\(Fmt.flops(run.flopsTotal + run.postTrainFlops)) FLOPs"
                             + (run.plan.map { $0.frontierShare >= 0.05 ? " · \(Fmt.trim($0.frontierShare, 2))× the largest known run" + (ref.source.isEmpty ? "" : " (\(ref.source))") : "" } ?? "")
                             + (run.plan.map { $0.days > 0 ? " · \(Fmt.days($0.days)), done ~\($0.finish.gameShort)" : "" } ?? ""))
                    case .power:
                        line("powerplug.fill", "Power",
                             "\(powerText(run.plan?.powerMW ?? 0)) at the wall\(run.plan.map { $0.powerMW > 0 ? ", about as much as \(Fmt.count($0.powerMW * 1_000 / 1.2)) homes" : "" } ?? "")"
                             + (run.plan.map { $0.cost > 0 ? " · \(Fmt.money($0.cost)) budgeted" : "" } ?? ""))
                    case .started:
                        HStack(spacing: 10) {
                            Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Training has started").font(.title2.weight(.bold)).foregroundStyle(.white)
                                if run.forecastHidden {
                                    Text("No forecast: without scaling laws you'll learn how good it is at the first eval checkpoints.")
                                        .font(.callout).foregroundStyle(.white.opacity(0.75))
                                } else if let fc = run.forecast {
                                    Text("Forecast: index \(Fmt.score(fc.index)) (\(Fmt.score(fc.indexLow))–\(Fmt.score(fc.indexHigh))) · \(fc.tier)")
                                        .font(.callout).foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                Spacer()
                HStack(spacing: 18) {
                    Toggle("Play launch sequences for major runs", isOn: Binding(get: { store.showLaunchSequence }, set: { store.showLaunchSequence = $0 }))
                    Toggle("Reduce animations", isOn: Binding(get: { store.reduceAnimations }, set: { store.reduceAnimations = $0 }))
                }
                .toggleStyle(.checkbox).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(48)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .contentShape(.rect)
        .onTapGesture { if shown >= beats.count { done() } else { step = beats.count; online = 1 } }
        .task {
            guard !calm else { return }
            let pause = frontier ? 1_000 : 800
            for i in 1...beats.count {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 150 : pause))
                withAnimation(.easeOut(duration: 0.4)) { step = max(step, i) }
                if frontier && beats[i - 1] == .cluster {
                    withAnimation(.easeInOut(duration: Double(pause) / 1_000 * 0.9)) { online = 1 }
                }
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
    private func siteNames(_ s: GameState, all: Bool) -> String {
        let ids = Set(s.owned.filter { $0.accelID == run.design.accelID }.map(\.siteID))
        var names = s.sites.filter { ids.contains($0.id) }.map { "\($0.name) (\($0.location.name))" }
        if s.rentals.contains(where: { $0.accelID == run.design.accelID }) { names.append("rented cloud capacity") }
        let cap = all ? 6 : 3
        return names.isEmpty ? "your fleet" : names.prefix(cap).joined(separator: ", ") + (names.count > cap ? " and \(names.count - cap) more" : "")
    }
}

/// 3.4: a landmark first gets the screen to itself for a moment (a trillion parameters, past the frontier, half a
/// million accelerators, autonomous research…). Presentation only: the game carries on underneath.
struct FirstCeremony: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let first: TrainingFirst
    let done: () -> Void
    @State private var shown = false

    var body: some View {
        let calm = reduceMotion || store.reduceAnimations
        ZStack {
            Rectangle().fill(.black.opacity(0.88)).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: first.symbol)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.yellow)
                    .scaleEffect(shown || calm ? 1 : 0.6)
                    .opacity(shown || calm ? 1 : 0)
                Text("A first for \(store.game.companyName)".uppercased()).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.55))
                Text(first.title).font(.system(size: 44, weight: .black)).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(first.model).font(.title2.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                Text(first.detail).font(.title3).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).frame(maxWidth: 680)
                Text(first.date.gameLong).font(.callout).foregroundStyle(.white.opacity(0.5))
                Button("Continue") { done() }
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 8)
            }
            .padding(48)
        }
        .contentShape(.rect)
        .onTapGesture { done() }
        .onAppear {
            guard !calm else { return }
            withAnimation(.spring(duration: 0.7)) { shown = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
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
/// 3.4: the ladder's measured loss against the scaling-law prediction it is fitting, on log tokens (what the proxy
/// runs actually recorded, not an illustration).
private struct LadderChart: View {
    let points: [LossPoint]

    var body: some View {
        if points.count < 2 {
            Text("The first proxy runs are warming up.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(Array(points.enumerated()).filter { $0.element.pred > 0 }, id: \.offset) { _, p in
                    LineMark(x: .value("Tokens (T)", max(p.tokensT, 1e-6)), y: .value("Loss", p.pred), series: .value("Series", "Power law"))
                        .foregroundStyle(.gray.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    PointMark(x: .value("Tokens (T)", max(p.tokensT, 1e-6)), y: .value("Loss", p.loss))
                        .foregroundStyle(.indigo)
                        .symbolSize(14)
                }
            }
            .chartXScale(type: .log)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxisLabel("Proxy tokens (T, log)")
        }
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
    @State private var confirmCancel = false

    var body: some View {
        let s = state
        let b = store.derived.bonuses
        let a = HardwareCatalog.get(run.design.accelID)
        // The same MFU and goodput the daily simulation uses for this run (its design, ops coverage and hot spares).
        let mfu = a.map { Physics.runMFU(run.design, accel: $0, coverage: run.opsCoverage, state: s, bonuses: b) } ?? 0
        let good = Training.goodput(chips: run.design.chips, coverage: run.opsCoverage, state: s, bonuses: b, spares: run.design.spares) * Sim.checkpointOverhead(run.interval)
        let flopsPerSec = Double(run.design.chips) * (a?.trainTFLOPS(run.design.precision) ?? 0) * 1e12 * mfu * good * run.schedule.speed
        let perDay = flopsPerSec * 86_400
        let postTotal = run.postTrainFlops
        let total = run.flopsTotal + postTotal
        let doneFlops = min(run.flopsDone, run.flopsTotal) + run.postTrainDone
        let remaining = max(0, run.flopsTotal - run.flopsDone) + max(0, postTotal - run.postTrainDone)
        let eta = perDay > 0 ? remaining / perDay : .infinity
        let inPost = run.status == .postTraining
        let tokensPerSec = flopsPerSec / (6 * max(run.design.activeParamsB, 0.001) * 1e9)
        let daily = a.map { Economy.chipDailyCost($0, count: run.design.chips, state: s) } ?? 0
        let power = a.map { TrainingExperience.powerMW(chips: run.design.chips, accel: $0, state: s) } ?? 0
        let decisions = s.decisions.filter { $0.ref == run.id.uuidString }
        let actual = TrainingExperience.actualSlices(run.ledger)
        let incidentShare = run.plan.map { $0.days > 0 ? $0.incidentDays / $0.days : 0 } ?? 0
        let expected = TrainingExperience.expectedSlices(run.design, coverage: run.opsCoverage, interval: run.interval, incidentShare: incidentShare, state: s)
        let basis = (run.ledger.days >= 3 ? actual : nil) ?? expected
        let bottleneck = TrainingExperience.bottleneck(basis, design: run.design, coverage: run.opsCoverage, interval: run.interval, running: true, state: s)
        let scale = TrainingExperience.RunScale(rawValue: run.plan?.scale ?? 1) ?? .standard
        let lambda = Double(run.design.chips) * Training.failuresPerChipDay * (1 - Training.opsEffect(run.opsCoverage, s).prevented)
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
                        Text(run.loss.last?.val ?? 0 > 0 ? "— training · ⋯ forecast · ╌ held-out validation" : "— training · ⋯ forecast · ╌ validation (smoothed)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    LossChart(points: run.loss, checkpoints: run.saved.map(\.tokensT),
                              validation: TrainingExperience.validation(run, state: s)
                                  .map { LossChart.Pair(t: $0.tokensT, l: $0.loss) })
                        .equatable()
                        .frame(height: 170)
                        .help(run.loss.last?.val ?? 0 > 0
                              ? "Validation is measured on held-out data the model never trains on. It pulls away from the training loss when data repeats too often or a silent bug corrupts training: run a diagnostic sweep to find out which."
                              : "This run started before held-out validation was recorded: the dashed line is the training loss smoothed, plus a gap for repeated data.")
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
                    Text("Cluster (\(Fmt.int(run.design.chips)) chips)").font(.caption.weight(.semibold))
                    ClusterHeatmap(run: run, mfu: mfu, scaleUp: a?.scaleUp ?? 8, active: run.status != .paused)
                        .frame(height: 130)
                        .clipShape(.rect(cornerRadius: 8))
                    Text(heatmapLegend(mfu: mfu, lambda: lambda)).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                    Text("Gradient norm").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    GradNormChart(points: run.loss)
                        .frame(height: 30)
                }
                .frame(width: 260)
            }

            computePanel(actual: actual, expected: expected, bottleneck: bottleneck)

            if run.telemetry.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Throughput").font(.caption.weight(.semibold))
                        Text("green: useful compute as a share of peak, day by day · dashed: what MFU × goodput promised · red: days lost to an incident")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    ThroughputChart(days: run.telemetry).equatable().frame(height: 110)
                }
            }

            if run.kind == .full { OpsPanel(run: run, state: s, assigning: $assigning) }
            if run.kind == .full { InterventionsPanel(run: run, state: s) }

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
                Button("Cancel run", systemImage: "xmark", role: .destructive) { confirmCancel = true }
                    .confirmationDialog("Cancel \(run.design.name)?", isPresented: $confirmCancel) {
                        if let cp = run.saved.last, cp.forkedModelID == nil {
                            Button("Keep the \(Int(cp.fraction * 100))% checkpoint as a model, then cancel") {
                                store.act("Checkpoint kept; run cancelled") { s in
                                    if let e = s.forkCheckpoint(run.id, checkpoint: cp.id) { return e }
                                    return s.setRunStatus(run.id, .cancelled)
                                }
                            }
                        }
                        Button("Cancel without keeping anything", role: .destructive) { store.act("Run cancelled") { $0.setRunStatus(run.id, .cancelled) } }
                        Button("Keep training", role: .cancel) {}
                    } message: {
                        Text("\(Fmt.money(run.cost)) spent so far. The chips go back to your pool; the compute already used is lost unless you keep a checkpoint.")
                    }
                Spacer()
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

    private func confidence(_ run: TrainingRun) -> String {
        guard let fc = run.forecast else { return "—" }
        let sd = run.saved.isEmpty ? fc.sigma : run.revealSigma
        return "±\(Fmt.trim(sd, 2))" + (run.saved.isEmpty ? "" : " (was ±\(Fmt.trim(fc.sigma, 2)))")
    }

    private func heatmapLegend(mfu: Double, lambda: Double) -> String {
        let minutes = 1_440 / max(lambda, 1e-9)
        let every = minutes < 60 ? "\(Int(minutes.rounded())) min" : (minutes < 2_880 ? "\(Fmt.trim(minutes / 60, 1)) h" : Fmt.days(minutes / 1_440))
        let week = run.telemetry.suffix(7).reduce(0) { $0 + $1.failures }
        return "Red: a fault today · amber: faults this week (\(week)) · purple: corrupt nodes quarantined · cyan: watched by ops agents · brightness: MFU \(Fmt.pct(mfu, decimals: 0)) · a fault every \(every). Click a cell."
    }

    private func lossDelta(_ run: TrainingRun) -> String {
        guard let last = run.loss.last(where: { !$0.spike }), last.pred > 0 else { return run.loss.last.map { String(format: "%.3f", $0.loss) } ?? "—" }
        let d = last.loss - last.pred
        return String(format: "%.3f (%@%.3f)", last.loss, d <= 0 ? "−" : "+", abs(d))
    }
}

/// Agents watching the run's GPUs: coverage, what it buys and a way to add more.
/// 3.4: the calls you can make on a live run, each with its cost and effect shown before you commit.
private struct InterventionsPanel: View {
    @Environment(GameStore.self) private var store
    let run: TrainingRun
    let state: GameState
    @State private var extendBy = 0.25
    @State private var confirmStop = false

    var body: some View {
        let s = state
        let diag = TrainingInterventions.diagnoseBlocker(s, run)
        let cost = TrainingInterventions.diagnoseCost(s, run)
        let rep = TrainingInterventions.repetition(run)
        let inv = TrainingInterventions.investigateBlocker(s, run)
        let red = TrainingInterventions.redTeamBlocker(s, run)
        let stop = TrainingInterventions.endEarlyBlocker(s, run)
        let stopPreview = stop == nil ? TrainingInterventions.stopPreview(s, run) : nil
        let ext = TrainingInterventions.extendBlocker(s, run, by: extendBy)
        let extPreview = ext == nil ? TrainingInterventions.extendPreview(s, run, by: extendBy) : nil
        let planned = Training.projectedIndex(s, run).0
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Run decisions", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Text("Every call costs cluster time or money; what it does is shown first.").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Theme.columns(min: 260), alignment: .leading, spacing: 10) {
                tile("Diagnostic sweep", symbol: "stethoscope",
                     body: "Evaluate the latest checkpoint and the held-out loss, scan the data for leaked benchmarks and look for a silent bug. \(Fmt.money(cost.money)) and a quarter-day of cluster time."
                        + (rep.epochs > 0 ? " Data so far: \(Fmt.trim(rep.epochs, 2)) passes\(rep.gap > 0.001 ? ", held-out gap \(Fmt.trim(rep.gap, 3))" : "")." : ""),
                     result: latest("Diagnostic sweep"), blocker: diag, action: "Run the sweep") {
                    store.act("Diagnostic sweep done") { $0.diagnoseRun(run.id) }
                }
                if run.spikes > 0 || run.investigated {
                    tile("Investigate instability", symbol: "waveform.path.badge.minus",
                         body: "Half a day of engineers on the \(run.spikes) loss spike\(run.spikes == 1 ? "" : "s"): find the cause and fix it. Spikes about 45% less likely for the rest of the run.",
                         result: latest("Instability investigation"), blocker: inv, action: "Investigate") {
                        store.act("Cause found and fixed") { $0.investigateRun(run.id) }
                    }
                }
                if run.design.reasoning {
                    tile("Red-team the RL environments", symbol: "shield.lefthalf.filled",
                         body: "Harden the graders before reasoning RL starts: the stage takes 5% longer, and the model is about 70% less likely to learn to game its rewards.",
                         result: run.redTeamed ? "Graders hardened." : nil, blocker: red, action: "Red-team them") {
                        store.act("Red team assigned") { $0.redTeamRun(run.id) }
                    }
                }
                tile("End pre-training now", symbol: "flag.checkered",
                     body: stopPreview.map { p in
                         "Index ≈ \(Fmt.score(p.indexNow)) if it stops now, against ≈ \(Fmt.score(p.indexPlanned)) as planned. Saves \(Fmt.days(p.daysLeft)) and \(Fmt.money(p.costLeft))."
                             + (p.decayShare > 0 ? " The learning rate decays over a final \(Int(p.decayShare * 100))%." : " The cosine schedule stops undecayed (×\(Fmt.trim(pow(10, -p.schedulePenalty), 3)) quality).")
                     } ?? (run.endedEarlyAt > 0 ? "Ended at \(Int(run.endedEarlyAt * 100))% of the original plan." : "Stop pre-training where it is, decay the learning rate and move on to post-training."),
                     result: nil, blocker: stop, action: "End pre-training…") {
                    confirmStop = true
                }
                VStack(alignment: .leading, spacing: 6) {
                    tile("Extend pre-training", symbol: "plus.forwardslash.minus",
                         body: extPreview.map { p in
                             "+\(Int(extendBy * 100))% tokens: index ≈ \(Fmt.score(p.index)) (\(Fmt.signed(p.index - planned, 1))) for \(Fmt.days(p.days)) and \(Fmt.money(p.cost)) more."
                                 + (run.design.schedule == .wsd && s.bonuses.has(.wsd) ? " WSD carries on at its stable learning rate." : " A cosine schedule must be re-warmed (2% more compute, a little quality).")
                         } ?? "Train on more tokens than planned, if your data allows.",
                         result: run.extendedBy > 0 ? "Extended by \(Int(run.extendedBy * 100))% so far." : nil, blocker: ext, action: "Extend") {
                        store.act("Run extended") { $0.extendRun(run.id, by: extendBy) }
                    }
                    Picker("By", selection: $extendBy) {
                        Text("+25%").tag(0.25)
                        Text("+50%").tag(0.5)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
        .confirmationDialog("End pre-training of \(run.design.name) now?", isPresented: $confirmStop) {
            Button("End pre-training") { store.act("Pre-training ended early") { $0.endPretrainingEarly(run.id) } }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text(stopPreview.map { "Projected index ≈ \(Fmt.score($0.indexNow)) instead of ≈ \(Fmt.score($0.indexPlanned)); you save \(Fmt.money($0.costLeft))." } ?? "")
        }
    }

    /// The latest run-log line that starts with `prefix` (what the last call found).
    private func latest(_ prefix: String) -> String? {
        run.events.first { $0.contains(prefix) }.map { line in
            line.split(separator: "·", maxSplits: 1).last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? line
        }
    }

    private func tile(_ title: String, symbol: String, body: String, result: String?, blocker: String?, action: String,
                      perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.callout.weight(.semibold))
            Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let result {
                Text(result).font(.caption).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.control))
            }
            Button(action, action: perform)
                .controlSize(.small)
                .disabled(blocker != nil)
                .help(blocker ?? "")
            if let blocker {
                Text(blocker).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

private struct OpsPanel: View {
    @Environment(GameStore.self) private var store
    let run: TrainingRun
    let state: GameState
    @Binding var assigning: Bool

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
                if run.forecastHidden {
                    Text("—").font(.title2.weight(.bold).monospacedDigit())
                    Text("no scaling laws at launch").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("\(Fmt.score(forecast.index))").font(.title2.weight(.bold).monospacedDigit())
                    Text("\(Fmt.score(forecast.indexLow))–\(Fmt.score(forecast.indexHigh)) · \(forecast.tier)").font(.caption2).foregroundStyle(.secondary)
                }
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

/// 3.4: the cluster as the simulation lived it. Each cell is a slice of the run's chips (whole scale-up domains);
/// every hardware fault in the run's telemetry lands in a cell by a stable hash of the day and the fault, so a day with
/// three faults lights three cells, and they cool from red to amber over the following days. Purple cells hold nodes the
/// ops agents quarantined for silently corrupting gradients; a cyan outline marks the share the agents watch; brightness
/// is the run's MFU. Nothing moves unless the simulation does, so it is still when the game is paused (and with Reduce
/// Motion). Click a cell to inspect it.
struct ClusterHeatmap: View {
    let run: TrainingRun
    let mfu: Double
    let scaleUp: Int
    let active: Bool

    @State private var selected: Int?

    /// Cells drawn: one per scale-up domain up to 384, then groups of domains.
    var cells: Int { max(1, min(384, run.design.chips / max(1, min(scaleUp, run.design.chips)))) }
    var chipsPerCell: Int { max(1, run.design.chips / cells) }

    struct CellState {
        var lastFault: Int?      // days since the most recent fault in this cell
        var faults = 0           // faults in the window
        var quarantined = 0      // corrupt nodes caught
        var watched = false
    }

    /// Per-cell state from the last `window` days of telemetry.
    func states(window: Int = 14) -> [CellState] {
        var out = Array(repeating: CellState(), count: cells)
        let days = Array(run.telemetry.suffix(window))
        let seed = Self.mix((UInt64(run.id.uuidString.prefix(8), radix: 16) ?? 0) &+ UInt64(run.design.chips))
        for (k, day) in days.enumerated() {
            let age = days.count - 1 - k
            let stamp = UInt64(day.date.timeIntervalSince1970 / 86_400)
            for f in 0..<min(day.failures, cells * 4) {
                let c = Int(Self.mix(seed ^ stamp &* 0x9E37 ^ UInt64(f) &* 0xC2B2_AE3D) % UInt64(cells))
                out[c].faults += 1
                out[c].lastFault = min(out[c].lastFault ?? age, age)
            }
            for q in 0..<min(Int(day.sdcCaught.rounded()), cells) {
                let c = Int(Self.mix(seed ^ stamp &* 0x51AB ^ UInt64(q) &* 0x2545_F491) % UInt64(cells))
                out[c].quarantined += 1
            }
        }
        let watched = Int((Double(cells) * clamp(run.opsCoverage, 0, 1)).rounded())
        for c in 0..<cells where Int(Self.mix(seed ^ UInt64(c) &* 0x27D4_EB2F) % 1_000) < watched * 1_000 / max(1, cells) { out[c].watched = true }
        return out
    }

    var body: some View {
        let st = states()
        let post = run.status == .postTraining
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let size = geo.size
                let cols = max(1, Int(ceil(sqrt(Double(cells) * size.width / max(size.height, 1)))))
                let rows = max(1, Int(ceil(Double(cells) / Double(cols))))
                let side = min(size.width / CGFloat(cols), size.height / CGFloat(rows), 30)
                let ox = (size.width - side * CGFloat(cols)) / 2
                let oy = (size.height - side * CGFloat(rows)) / 2
                Canvas { g, _ in
                    g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.85)))
                    let bright = clamp(mfu / 0.7, 0.25, 1)
                    for i in 0..<cells {
                        let r = i / cols, c = i % cols
                        let rect = CGRect(x: ox + CGFloat(c) * side + 1, y: oy + CGFloat(r) * side + 1, width: max(1, side - 2), height: max(1, side - 2))
                        let cell = st[i]
                        let color: Color
                        if !active {
                            color = .gray.opacity(0.3)
                        } else if let age = cell.lastFault, age <= 6 {
                            color = age == 0 ? .red : .orange.opacity(max(0.35, 0.9 - Double(age) * 0.1))
                        } else if cell.quarantined > 0 {
                            color = .purple.opacity(0.8)
                        } else {
                            color = (post ? Color.indigo : Color.green).opacity(bright)
                        }
                        g.fill(Path(roundedRect: rect, cornerRadius: side * 0.2), with: .color(color))
                        if cell.watched && side >= 6 {
                            g.stroke(Path(roundedRect: rect, cornerRadius: side * 0.2), with: .color(.cyan.opacity(0.55)), lineWidth: 0.6)
                        }
                        if selected == i {
                            g.stroke(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: side * 0.2), with: .color(.white), lineWidth: 1.5)
                        }
                    }
                }
                .contentShape(.rect)
                .onTapGesture { p in
                    let c = Int((p.x - ox) / side), r = Int((p.y - oy) / side)
                    let i = r * cols + c
                    selected = (c >= 0 && c < cols && r >= 0 && i >= 0 && i < cells && selected != i) ? i : nil
                }
            }
            .accessibilityLabel("Cluster map: \(cells) cells of \(Fmt.int(chipsPerCell)) chips, \(st.filter { ($0.lastFault ?? 99) <= 6 }.count) with faults in the last week, MFU \(Int(mfu * 100))%")
            if let i = selected, i < st.count {
                let cell = st[i]
                Text("Cell \(i + 1): \(Fmt.int(chipsPerCell)) chips · \(cell.faults == 0 ? "no faults in 14 days" : "\(cell.faults) fault\(cell.faults == 1 ? "" : "s") in 14 days, the last \(cell.lastFault == 0 ? "today" : "\(cell.lastFault ?? 0) days ago")")"
                     + "\(cell.quarantined > 0 ? " · \(cell.quarantined) corrupt node\(cell.quarantined == 1 ? "" : "s") quarantined" : "") · \(cell.watched ? "watched by ops agents" : "not watched")")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    private static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 3.4: what the cluster actually delivered, day by day: useful compute as a share of peak, against what MFU and
/// goodput promised, with the days a loss spike or a fault storm hit.
struct ThroughputChart: View, Equatable {
    let days: [RunDay]

    var body: some View {
        if days.count < 2 {
            Text("Each day of training adds a point.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    AreaMark(x: .value("Day", i), y: .value("Useful %", d.peak > 0 ? d.useful / d.peak * 100 : 0))
                        .foregroundStyle(.green.opacity(0.25))
                        .interpolationMethod(.stepCenter)
                    LineMark(x: .value("Day", i), y: .value("Expected %", d.mfu * d.goodput * 100), series: .value("Series", "Expected"))
                        .foregroundStyle(.gray.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    if d.spike || d.useful == 0 {
                        PointMark(x: .value("Day", i), y: .value("Useful %", 0))
                            .foregroundStyle(.red)
                            .symbolSize(18)
                    }
                }
            }
            .chartYScale(domain: 0...80)
            .chartXAxisLabel("Last \(days.count) days")
            .chartYAxisLabel("% of peak")
        }
    }
}
