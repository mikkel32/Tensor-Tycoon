import SwiftUI

/// Reusable blueprints, live supervision and the measured results that feed later forecasts.
struct BlueprintLibrary: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var editing: RunBlueprint?
    @State private var deleting: RunBlueprint?

    var body: some View {
        let blueprints = state.blueprints.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        Card {
            CardHeader(title: "Blueprint library", symbol: "shippingbox.and.arrow.backward.fill",
                       subtitle: "\(blueprints.count)/\(TrainingSystems.maxBlueprints) reusable runs · launch, supervise, measure, then forecast with evidence") {
                Button("Design in Model Lab", systemImage: "flask") { store.open(.lab) }.buttonStyle(.link)
            }
            if blueprints.isEmpty {
                Text("Save a design as a blueprint in the Model Lab. It keeps the full architecture, learning-rate schedule, checkpoints and optional supervision policy; launching still checks hardware, research, memory and cash.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(blueprints) { bp in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: bp.automation.enabled ? "checklist.checked" : "doc.text.fill")
                                .font(.title3).foregroundStyle(bp.automation.enabled ? .teal : .indigo).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    Text(bp.name).font(.callout.weight(.semibold))
                                    if bp.automation.enabled { Pill(text: "supervised", color: .teal) }
                                    if bp.uses > 0 { Pill(text: "\(bp.uses) launches", color: .secondary) }
                                }
                                Text("\(Fmt.params(bp.design.paramsB)) · \(Fmt.tokens(bp.design.tokensT)) · \(Fmt.int(bp.design.allChips)) chips · \(bp.lr.label) · checkpoints every \(Int(bp.checkpointEvery * 100))%")
                                    .font(.caption).foregroundStyle(.secondary)
                                if !bp.detail.isEmpty { Text(bp.detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(2) }
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 5) {
                                HStack {
                                    Button("Launch") { launch(bp) }.buttonStyle(.borderedProminent)
                                    Button("Edit") { editing = bp }
                                    Button(role: .destructive) { deleting = bp } label: { Image(systemName: "trash") }
                                        .help("Delete blueprint; existing runs and measured outcomes are kept")
                                }
                                .controlSize(.small)
                                Text(bp.lastUsed.map { "Last used \($0.gameShort)" } ?? "Not launched yet")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.32), in: .rect(cornerRadius: 10))
                    }
                }
            }
        }
        .sheet(item: $editing) { bp in
            BlueprintEditorSheet(blueprint: bp, isNew: false) { updated in
                store.act("Blueprint updated") { $0.saveBlueprint(updated) }
            }
        }
        .confirmationDialog("Delete \(deleting?.name ?? "blueprint")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete blueprint", role: .destructive) {
                if let bp = deleting { store.mutate { $0.deleteBlueprint(bp.id) } }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Runs already launched and their measured outcomes are not deleted.")
        }
    }

    private func launch(_ bp: RunBlueprint) {
        let before = Set(store.game.runs.map(\.id))
        guard store.act("Blueprint launched", { $0.launchBlueprint(bp.id) }) else { return }
        if let run = store.game.runs.first(where: { !before.contains($0.id) && $0.kind == .full }) {
            store.focusRunID = run.id
            if store.showLaunchSequence, let plan = run.plan,
               (TrainingExperience.RunScale(rawValue: plan.scale) ?? .standard) >= .major { store.launchRunID = run.id }
        }
    }
}

struct BlueprintEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RunBlueprint
    let isNew: Bool
    let save: (RunBlueprint) -> Bool

    init(blueprint: RunBlueprint, isNew: Bool, save: @escaping (RunBlueprint) -> Bool) {
        _draft = State(initialValue: blueprint)
        self.isNew = isNew
        self.save = save
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(isNew ? "Save training blueprint" : "Edit training blueprint", systemImage: "shippingbox.and.arrow.backward.fill")
                    .font(.title2.weight(.bold))
                Text("A blueprint is a reusable configuration, not a free run. Every launch uses the ordinary training validator and current hardware prices.")
                    .font(.callout).foregroundStyle(.secondary)
                GroupBox("Identity and run") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Blueprint name", text: $draft.name).textFieldStyle(.roundedBorder)
                        TextField("Notes for your future self", text: $draft.detail, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
                        TextField("Model name used at launch", text: $draft.design.name).textFieldStyle(.roundedBorder)
                        HStack {
                            Picker("Learning rate", selection: $draft.lr) {
                                ForEach(LRSchedule.allCases) { Text($0.label).tag($0) }
                            }
                            Picker("Checkpoint interval", selection: $draft.checkpointEvery) {
                                Text("2%").tag(0.02); Text("5%").tag(0.05); Text("10%").tag(0.1); Text("25%").tag(0.25)
                            }
                        }
                        Toggle("Automatically roll back after a failed training run", isOn: $draft.autoRollback)
                        Text("\(Fmt.params(draft.design.paramsB)) parameters · \(Fmt.tokens(draft.design.tokensT)) tokens · \(Fmt.int(draft.design.allChips)) chips. Edit the full architecture in the Model Lab, then save or update the blueprint there.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
                GroupBox("Supervised automation") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable supervision on launched runs", isOn: $draft.automation.enabled)
                        Text("The supervisor uses the existing diagnostic, instability and RL red-team interventions. It never resolves an inbox decision for you.")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("Diagnostic sweeps at 15%, 45% and 70%", isOn: $draft.automation.diagnostics)
                        Toggle("Investigate loss-spike instability", isOn: $draft.automation.investigate)
                        Toggle("Red-team reasoning-RL environments", isOn: $draft.automation.redTeam)
                        HStack {
                            LabeledContent("Cash reserve to protect") {
                                TextField("Reserve", value: $draft.automation.cashReserve, format: .number)
                                    .textFieldStyle(.roundedBorder).frame(width: 150)
                            }
                            LabeledContent("Maximum paid diagnostics per run") {
                                TextField("Cap", value: $draft.automation.spendingCap, format: .number)
                                    .textFieldStyle(.roundedBorder).frame(width: 150)
                            }
                        }
                        Text("Both safeguards must pass before a paid diagnostic runs. A skipped milestone is not retried every day; you can always intervene manually.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                    Button(isNew ? "Save blueprint" : "Save changes") {
                        if save(draft) { dismiss() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 700, idealWidth: 760, minHeight: 650, idealHeight: 720)
    }
}

struct RunSupervisionCard: View {
    @Environment(GameStore.self) private var store
    let run: TrainingRun
    let state: GameState
    @State private var policy: RunAutomationPolicy

    init(run: TrainingRun, state: GameState) {
        self.run = run
        self.state = state
        _policy = State(initialValue: run.automation ?? RunAutomationPolicy())
    }

    var body: some View {
        let saved = run.automation ?? RunAutomationPolicy()
        Card {
            CardHeader(title: "Run supervisor", symbol: "checklist.checked",
                       subtitle: "Opt-in automation with two independent spending safeguards") {
                if run.automation?.enabled == true { Pill(text: "active", color: .teal) } else { Pill(text: "manual", color: .secondary) }
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Supervise this run", isOn: $policy.enabled).toggleStyle(.switch)
                    Toggle("Diagnostics at 15% / 45% / 70%", isOn: $policy.diagnostics)
                    Toggle("Investigate instability", isOn: $policy.investigate)
                    Toggle("Red-team reasoning RL", isOn: $policy.redTeam)
                }
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Protected cash reserve") {
                        TextField("Cash", value: $policy.cashReserve, format: .number).textFieldStyle(.roundedBorder).frame(width: 135)
                    }
                    LabeledContent("Paid-diagnostic cap") {
                        TextField("Cap", value: $policy.spendingCap, format: .number).textFieldStyle(.roundedBorder).frame(width: 135)
                    }
                    Text("Available diagnostic allowance: \(Fmt.money(max(0, policy.spendingCap - run.automationSpent))) · current cash \(Fmt.money(state.cash))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(run.automationActions) actions").font(.callout.monospacedDigit())
                    Text("\(run.automationDiagnostics) paid sweeps · \(Fmt.money(run.automationSpent)) spent").font(.caption).foregroundStyle(.secondary)
                    Text("\(run.automationMilestones.count)/\(TrainingSystems.diagnosticMilestones.count) milestones settled").font(.caption2).foregroundStyle(.tertiary)
                    Button("Apply policy") {
                        var clean = policy
                        clean.cashReserve = max(0, clean.cashReserve)
                        clean.spendingCap = max(0, clean.spendingCap)
                        if store.act("Supervision policy applied", { $0.setRunAutomation(run.id, clean) }) { policy = clean }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(policy == saved)
                }
            }
            Text("Automation does not pause for you and never answers a training incident in the inbox. Budget-skipped milestones are logged in ops notes.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

struct TrainingOutcomeInsights: View {
    let state: GameState

    var body: some View {
        let recent = Array(state.trainingOutcomes.suffix(6).reversed())
        Card {
            CardHeader("Measured outcomes → better forecasts", symbol: "chart.xyaxis.line",
                       subtitle: "Bounded evidence from completed full runs · incident and learning-rate effects removed from recipe residuals")
            if recent.isEmpty {
                Text("Complete a full training run to record its actual capability against the launch forecast. One result is shown here but never moves a forecast; correction starts at two comparable runs and uncertainty falls only after three.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recent) { outcome in
                        let run = state.runs.first(where: { $0.id == outcome.runID })
                        let evidence = run.map { TrainingSystems.evidence($0.design, state: state, flops: outcome.compute) } ?? RecipeEvidence()
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: outcome.residual >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                                .foregroundStyle(outcome.residual >= 0 ? .green : .orange).frame(width: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    Text(outcome.name).font(.callout.weight(.semibold))
                                    if outcome.supervised { Pill(text: "\(outcome.automationActions) supervisor actions", color: .teal) }
                                }
                                Text("Index \(Fmt.score(outcome.forecastIndex)) forecast → \(Fmt.score(outcome.actualIndex)) actual · capability residual \(outcome.residual >= 0 ? "+" : "")\(Fmt.trim(outcome.residual, 3)) · \(outcome.days) days · \(Fmt.money(outcome.cost))")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(outcome.incidents) recorded interruptions/spikes · \(evidence.samples) comparable samples now · forecast correction \(evidence.correction >= 0 ? "+" : "")\(Fmt.trim(evidence.correction, 3)) · uncertainty −\(Fmt.pct(evidence.uncertaintyCut, decimals: 0))")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(outcome.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(9)
                        .background(.quaternary.opacity(0.28), in: .rect(cornerRadius: 9))
                    }
                }
                Text("Compute-distance weighting fades from half a decade to two decades. Capability correction is capped at ±\(Fmt.trim(TrainingSystems.maxCapabilityCorrection, 2)) log10 effective compute and uncertainty reduction at \(Fmt.pct(TrainingSystems.maxUncertaintyCut, decimals: 0)). History: \(state.trainingOutcomes.count)/\(TrainingSystems.maxOutcomes) outcomes, \(state.recipeLearning.count)/\(TrainingSystems.maxRecipeLearning) recipe evidence sets.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
