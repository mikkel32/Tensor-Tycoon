import Charts
import SwiftUI

struct LogSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// What VoiceOver reads: a log slider's raw position means nothing, so name it and say its value in units.
    var label = "Amount"
    var valueText = ""

    var body: some View {
        Slider(value: Binding(get: { log10(clamp(value, range.lowerBound, range.upperBound)) },
                              set: { value = pow(10, $0) }),
               in: log10(range.lowerBound)...log10(range.upperBound))
            .accessibilityLabel(label)
            .accessibilityValue(valueText.isEmpty ? Fmt.trim(value, 2) : valueText)
    }
}

enum Recipe: String, CaseIterable, Identifiable {
    case quick = "Quick experiment"
    case optimal = "Compute-optimal"
    case overtrained = "Inference-optimised"
    case moe = "Frontier MoE"
    case reasoning = "Reasoning model"
    case finetune = "Fine-tune open model"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .quick: "bolt.fill"
        case .optimal: "scalemass.fill"
        case .overtrained: "speedometer"
        case .moe: "square.stack.3d.up.fill"
        case .reasoning: "lightbulb.max.fill"
        case .finetune: "wand.and.stars"
        }
    }

    var tint: Color {
        switch self {
        case .quick: .yellow
        case .optimal: .blue
        case .overtrained: .teal
        case .moe: .purple
        case .reasoning: .pink
        case .finetune: .green
        }
    }

    var blurb: String {
        switch self {
        case .quick: "A week on 10% of your cluster. See where you stand before betting big."
        case .optimal: "30 days, sized by your scaling science (Kaplan before Chinchilla, ~20 tokens/param after)."
        case .overtrained: "Smaller model on far more data (Llama-style). Weaker per FLOP, cheap and fast to serve."
        case .moe: "Sparse experts + your best optimizer and attention. DeepSeek-V3-style efficiency."
        case .reasoning: "Chat + preference tuning + heavy reasoning RL + tools. Math and coding beast."
        case .finetune: "The best open-weights model that fits your chips, made yours in ~10 days."
        }
    }
}

struct ModelLabView: View {
    @Environment(GameStore.self) private var store
    @State private var design = ModelDesign()
    @State private var prepared = false
    @State private var lr: LRSchedule = .standard
    @State private var interval = 0.1
    @State private var autoRollback = false
    @State private var targetIndex = 50.0
    /// 3.5: the pre-training review for substantial runs.
    @State private var reviewing = false
    @AppStorage("labAdvanced") private var advanced = false
    /// 3.5: model families — distil or post-train an existing model instead of training a new one.
    @State private var familySheet: FamilySheet?
    /// 3.9: "Plan my next model" proposals, replanned when the day or the fleet changes.
    @State private var proposals: [RunPlanner.Proposal] = []
    @State private var servingPlan: RunPlanner.Proposal? = nil   // 3.9: a plan waiting for "take chips off serving"

    var body: some View {
        let s = store.game
        let d = store.derived
        let b = d.bonuses
        Page(title: "Model Lab", subtitle: "Design a training run. Every choice moves the forecast — and the forecast is honest about how sure it is.", screen: .lab) {
            ScreenHint(.lab)
            if d.pools.isEmpty {
                Card {
                    EmptyStateView(symbol: "cpu", title: "No compute", message: "You need accelerators to train. Buy some or rent cloud capacity.",
                                   actionTitle: "Hardware Store") { store.open(.hardware) }
                }
            } else {
                planStrip(s)
                recipeStrip(s, b)
                upgradeStrip(s)
                HStack(alignment: .top, spacing: 18) {
                    designForm(s, d, b)
                        .frame(minWidth: 440, maxWidth: 540)
                    VStack(spacing: 14) {
                        ArchitectureDiagram(design: design, state: s)
                        ForecastPanel(design: design, lr: lr, interval: interval, state: s, derived: d,
                                      start: {
                                          // Experiments start at once; anything bigger gets the pre-training review first.
                                          if Physics.estimate(design, state: store.game, lr: lr, interval: interval)?.toy ?? true { launch() } else { reviewing = true }
                                      },
                                      ladder: startLadder,
                                      resize: { n in design.chips = max(1, n) })
                        TargetPlanner(design: $design, target: $targetIndex, state: s, derived: d)
                    }
                }
            }
        }
        .onAppear { if !prepared { prepare(s, d); prepared = true }; proposals = RunPlanner.proposals(store.game) }
        .onChange(of: store.game.date) { _, _ in if !reviewing { proposals = RunPlanner.proposals(store.game) } }
        .sheet(isPresented: $reviewing) {
            RunReviewSheet(design: $design, lr: $lr, interval: $interval, launch: launch, ladder: startLadder)
        }
        .familySheet($familySheet)
    }

    /// 3.9: concrete designs sized to the chips you own and have idle, with forecast against your best model and the rivals.
    @ViewBuilder
    private func planStrip(_ s: GameState) -> some View {
        if proposals.isEmpty {
            let idle = Economy.pools(s).reduce(0) { $0 + $1.free }
            Label(RunPlanner.shortfall(s) ?? (idle < 4 ? "No idle chips to plan a run on: free some from serving, research or leases, or buy more." : "No design on your idle chips would finish a useful run yet; use the recipes below."),
                  systemImage: "wand.and.stars").font(.callout).foregroundStyle(.secondary)
        } else {
            Card {
                CardHeader(title: "Plan my next model", symbol: "wand.and.stars",
                           subtitle: "Sized to your idle chips with every technique you have researched. A whole-fleet plan mixes chip types: each group trains at its own speed, 85% efficient together.") {
                    Button("Replan") { proposals = RunPlanner.proposals(store.game) }.buttonStyle(.link)
                }
                HStack(alignment: .top, spacing: 12) {
                    ForEach(proposals) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(p.label).font(.callout.weight(.semibold)); Spacer(); Text("c \(Fmt.trim(p.est.forecast.c, 2))").font(.callout.monospacedDigit()) }
                            Text(p.blurb).font(.caption)
                            Text("\(Fmt.params(p.design.paramsB)) parameters on \(Fmt.tokens(p.design.tokensT)) tokens")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(verdict(p)).font(.caption.weight(.semibold)).foregroundStyle(p.vsRival >= 0 ? .green : (p.vsBest ?? 1) > 0 ? .orange : .red)
                            if p.leftOut > 0 {
                                Text("\(Fmt.int(p.leftOut)) idle \(p.design.accelID.isEmpty ? "" : (HardwareCatalog.get(p.design.accelID)?.name ?? "")) left out: \(p.leftOutWhy).")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            if !p.othersIdle.isEmpty {
                                Text("Stays free for serving: \(p.othersIdle).").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            HStack {
                                if p.fromServing > 0 {
                                    Button("Take off serving & start…") { servingPlan = p }.buttonStyle(.borderedProminent)
                                } else {
                                    Button("Review & start") { design = p.design; lr = .standard; interval = 0.1; reviewing = true }.buttonStyle(.borderedProminent)
                                    Button("Edit") { design = p.design; lr = .standard; interval = 0.1 }
                                }
                            }
                            .controlSize(.small)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 10))
                    }
                }
            }
            .confirmationDialog("Move \(Fmt.int(servingPlan?.fromServing ?? 0)) chips from serving to training?",
                                isPresented: Binding(get: { servingPlan != nil }, set: { if !$0 { servingPlan = nil } }), titleVisibility: .visible) {
                Button("Take them off serving and start") {
                    if let p = servingPlan, store.act("Training started", { RunPlanner.start(p, &$0) }) { proposals = RunPlanner.proposals(store.game) }
                    servingPlan = nil
                }
                Button("Cancel", role: .cancel) { servingPlan = nil }
            } message: {
                Text("Your weakest models lose those servers first. Users who can't be served go elsewhere until the run ends and the new model launches.")
            }
        }
    }

    private func verdict(_ p: RunPlanner.Proposal) -> String {
        let rival = p.vsRival >= 0 ? "ahead of every rival by \(Fmt.trim(p.vsRival, 2))" : "\(Fmt.trim(-p.vsRival, 2)) behind the best rival"
        guard let b = p.vsBest else { return "No live model of yours; \(rival)" }
        return (b > 0 ? "+\(Fmt.trim(b, 2)) over your best model; " : "\(Fmt.trim(b, 2)) vs your best model; ") + rival
    }

    /// 3.5: model families — a lineup without a new pre-training run: distil a cheaper tier or post-train a model you have.
    @ViewBuilder
    private func upgradeStrip(_ s: GameState) -> some View {
        let mine = s.models.filter { !$0.retired && !$0.preview }.sorted { $0.index > $1.index }
        if !mine.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.down.right.fill").foregroundStyle(.teal)
                Text("Already have a strong model? Distil a cheaper tier from it or post-train it into a point release.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Menu("Distil a tier") {
                    ForEach(mine.prefix(8)) { m in Button("\(m.name) · index \(Fmt.score(m.index))") { familySheet = .distill(m.id) } }
                }
                .fixedSize()
                Menu("Post-train") {
                    ForEach(mine.prefix(8)) { m in Button("\(m.name) · index \(Fmt.score(m.index))") { familySheet = .postTrain(m.id) } }
                }
                .fixedSize()
                Button("Model Families") { store.open(.families) }.buttonStyle(.link)
            }
        }
    }

    /// Starts the run. A major run (by compute against the largest known run) gets its launch sequence on the
    /// Training screen; the simulation doesn't wait for it.
    private func launch() {
        let d = design
        guard store.act("Training started", { $0.startTraining(d, lr: lr, checkpointEvery: interval, autoRollback: autoRollback) }) else { return }
        if let run = store.game.runs.last(where: { $0.design.name == d.name && $0.kind == .full }) {
            store.focusRunID = run.id
            if store.showLaunchSequence, let p = run.plan, (TrainingExperience.RunScale(rawValue: p.scale) ?? .standard) >= .major {
                store.launchRunID = run.id
            }
        }
        design.name = nextName(design.name)
        if design.generation > 0 { design.generation += 1 }
        store.open(.training)
    }

    private func startLadder() {
        let d = design
        if store.act("Scaling ladder started", { $0.startLadder(d) }) {
            store.focusRunID = store.game.runs.last?.id
            store.open(.training)
        }
    }

    // MARK: Recipes

    private func recipeStrip(_ s: GameState, _ b: ResearchBonuses) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Recipe.allCases) { r in
                    let locked = (r == .moe && !b.has(.moe)) || (r == .reasoning && !b.has(.reasoning)) || (r == .finetune && Physics.openModels(s).isEmpty)
                    Button { apply(r, s) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: r.symbol).font(.title3).foregroundStyle(r.tint)
                                Spacer()
                                if locked { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
                            }
                            Text(r.rawValue).font(.callout.weight(.semibold))
                            Text(r.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
                        }
                        .padding(12)
                        .frame(width: 190, alignment: .leading)
                        .background(LinearGradient(colors: [r.tint.opacity(0.18), r.tint.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(r.tint.opacity(0.3)))
                        .contentShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)
                    .opacity(locked ? 0.5 : 1)
                    .help(locked ? "Research needed" : r.blurb)
                }
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.never)
    }

    /// What the chosen expert layout costs and buys (built step by step: one long concatenation is too slow to type-check).
    private func moeNote(_ b: ResearchBonuses, _ s: GameState) -> String {
        let l = TrainingExperience.layout(design)
        let keep = HardwareCatalog.get(design.accelID).map { Physics.moeEfficiency(design, accel: $0, bonuses: b) } ?? 1
        let share = Int((1 / l.fraction).rounded())
        var t = "Each token goes to \(l.active) of \(l.experts) experts (1/\(share) of the weights active). "
        t += "Routing traffic and load imbalance cost \(Fmt.pct(1 - keep, decimals: 0)) of training throughput"
        if !s.researched.contains("dualpipe") { t += " (DualPipe research hides most of it)" }
        t += ". More, smaller experts specialise more"
        if !b.has(.fineMoE) { t += " once fine-grained experts are researched" }
        t += " and send more traffic"
        t += s.researched.contains("aux_free") ? "." : "; without aux-loss-free routing, big pools also spike more."
        return t
    }

    private func bestRecipe(_ b: ResearchBonuses) {
        design.optimizer = b.has(.muon) ? .muon : (b.has(.shampoo) ? .shampoo : .adamw)
        design.attention = b.has(.mla) ? .mla : (b.has(.gqa) ? .gqa : .mha)
        design.mtp = b.has(.mtp)
        design.anneal = b.has(.curriculum)
        design.schedule = b.has(.wsd) ? .wsd : .cosine
        design.safetyEvals = store.game.researched.contains("evals_rsp")   // 3.4: an evaluation stage once you can run one
        design.mixer = .transformer
    }

    private func apply(_ r: Recipe, _ s: GameState) {
        let b = store.derived.bonuses
        design.mode = .scratch
        design.baseModelRef = nil
        design.activeFraction = 1
        design.reasoning = false
        design.toolUse = false
        design.agentRL = false
        design.instruct = b.has(.chat)
        design.rlhf = b.has(.rlhf)
        design.syntheticShare = 0
        design.dataMix = .balanced
        design.mixShift = .keep
        // A recipe sets the knobs itself; the objective label follows it.
        design.objective = r == .reasoning ? .reasoning : (r == .overtrained ? .efficient : .general)
        if design.precision == .bf16 { fixPrecision(s) }
        var note: String? = nil
        switch r {
        case .quick:
            design.chips = max(1, store.derived.free(design.accelID) / 10)
            lr = .aggressive
            interval = 0.25
            note = autoSize(s, days: 7, overtrain: 1)
        case .optimal:
            design.chips = max(1, store.derived.free(design.accelID))
            bestRecipe(b)
            design.mtp = false
            lr = .standard
            interval = 0.1
            note = autoSize(s, days: 30, overtrain: 1)
        case .overtrained:
            design.chips = max(1, store.derived.free(design.accelID))
            bestRecipe(b)
            lr = .standard
            interval = 0.1
            note = autoSize(s, days: 30, overtrain: 8)
        case .moe:
            design.chips = max(1, store.derived.free(design.accelID))
            bestRecipe(b)
            design.activeFraction = b.has(.fineMoE) ? 1.0 / 32 : 1.0 / 16
            lr = .standard
            interval = 0.05
            note = autoSize(s, days: 30, overtrain: 2)
        case .reasoning:
            design.chips = max(1, store.derived.free(design.accelID))
            bestRecipe(b)
            design.reasoning = b.has(.reasoning)
            design.rlLevel = b.has(.extremeRL) ? .heavy : .standard
            design.toolUse = b.has(.toolUse)
            design.agentRL = b.has(.agents)
            design.instruct = true
            design.rlhf = b.has(.rlhf)
            if b.has(.moe) { design.activeFraction = 1.0 / 8 }
            design.dataMix = .stem
            design.mixShift = b.has(.curriculum) ? .stem : .keep
            lr = .standard
            interval = 0.05
            note = autoSize(s, days: 35, overtrain: 2)
        case .finetune:
            design.chips = max(1, store.derived.free(design.accelID))
            guard pickFinetuneBase(s) else {
                store.show("No open model fits your cluster's memory. Rent bigger chips or research model parallelism.", error: true)
                return
            }
            lr = .conservative
            interval = 0.25
        }
        store.show("Recipe applied: \(r.rawValue)" + (note.map { ". \($0)" } ?? ""))
    }

    // MARK: Form

    @ViewBuilder
    private func designForm(_ s: GameState, _ d: Derived, _ b: ResearchBonuses) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Card {
                CardHeader(title: "Identity", symbol: "textformat") {
                    Toggle("Advanced", isOn: $advanced).toggleStyle(.switch).controlSize(.small)
                        .help("Show every architecture, data and optimization control")
                }
                TextField("Model name", text: $design.name).textFieldStyle(.roundedBorder).font(.title3)
                HStack(spacing: 8) {
                    TextField("Family (e.g. \(design.name.split(separator: "-").first.map(String.init) ?? "Atlas"))", text: $design.family)
                        .textFieldStyle(.roundedBorder)
                    Stepper(design.generation > 0 ? "Generation \(design.generation)" : "No generation", value: $design.generation, in: 0...99)
                        .fixedSize()
                }
                TextField("One-line description (shown in the review and results)", text: $design.blurb).textFieldStyle(.roundedBorder).font(.callout)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Objective").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(ModelObjective.allCases) { o in
                            let on = design.objective == o
                            Button {
                                let changes = o.apply(to: &design, state: s)
                                store.show("Objective: \(o.label)" + (changes.isEmpty ? "" : " — " + changes.joined(separator: ", ")))
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: o.symbol).font(.callout)
                                    Text(o.label).font(.caption2.weight(.semibold)).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .foregroundStyle(on ? Color.white : Color.primary)
                                .background(on ? AnyShapeStyle(Color.indigo.gradient) : AnyShapeStyle(.quaternary.opacity(0.5)), in: .rect(cornerRadius: 8))
                                .contentShape(.rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .help(o.blurb)
                        }
                    }
                    Text(design.objective.blurb + " It works through the settings below, so the forecast shows exactly what it buys.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Picker("Approach", selection: $design.mode) {
                    ForEach(TrainMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                switch design.mode {
                case .scratch:
                    Text("Full pre-training. Most expensive, but the model is truly yours.").font(.caption).foregroundStyle(.secondary)
                case .finetune:
                    let open = Physics.openModels(s)
                    if open.isEmpty {
                        Label("No open-weights models exist yet.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                    } else {
                        Picker("Base model", selection: Binding(get: { design.baseModelRef ?? "" }, set: { setBase($0, s) })) {
                            Text("Choose…").tag("")
                            ForEach(open, id: \.model.id) { item in
                                let sized = item.model.name.hasSuffix(Fmt.params(item.model.paramsB))
                                Text("\(item.model.name) — \(item.lab)\(sized ? "" : " · \(Fmt.params(item.model.paramsB))")").tag(item.model.id.uuidString)
                            }
                        }
                        Text("Download open weights and fine-tune on your data. Cheap and fast, but less differentiated.").font(.caption).foregroundStyle(.secondary)
                    }
                case .distill:
                    if !b.has(.distillation) {
                        Label("Research Knowledge Distillation to unlock.", systemImage: "lock.fill").font(.caption).foregroundStyle(.orange)
                    }
                    Picker("Teacher", selection: Binding(get: { design.baseModelRef ?? "" }, set: { design.baseModelRef = $0.isEmpty ? nil : $0 })) {
                        Text("Choose…").tag("")
                        ForEach(s.models) { m in Text(m.name).tag(m.id.uuidString) }
                    }
                    Text("Train a smaller student on a big model's outputs. It can get close to the teacher.").font(.caption).foregroundStyle(.secondary)
                    if let ref = design.baseModelRef, let id = UUID(uuidString: ref) {
                        Button("Distil it as a family tier instead (per-domain retention, serving cost)…") { familySheet = .distill(id) }
                            .buttonStyle(.link).font(.caption)
                    }
                }
            }

            if design.mode != .finetune {
                Card {
                    CardHeader("Architecture", symbol: "square.stack.3d.up")
                    Toggle("Mixture-of-Experts", isOn: Binding(get: { design.isMoE }, set: { design.activeFraction = $0 ? 1.0 / 8 : 1 }))
                        .disabled(!b.has(.moe))
                    if design.isMoE {
                        // Sparsity (the active share) sets the MoE gain; the pool size sets how finely experts specialise
                        // and how much all-to-all traffic every layer sends (3.4).
                        Picker("Sparsity", selection: Binding(get: { TrainingExperience.experts(for: design.activeFraction).fraction },
                                                              set: { design.activeFraction = $0; design.experts = 0 })) {
                            ForEach(TrainingExperience.expertLayouts) { l in
                                let locked = l.needsFine && !b.has(.fineMoE)
                                Text(locked ? "1/\(Int((1 / l.fraction).rounded())) 🔒" : "1/\(Int((1 / l.fraction).rounded()))").tag(l.fraction).disabled(locked)
                            }
                        }
                        .pickerStyle(.segmented)
                        let standard = TrainingExperience.experts(for: design.activeFraction)
                        Picker("Expert pool", selection: Binding(get: { design.experts == 0 ? standard.experts : design.experts },
                                                                 set: { design.experts = $0 == standard.experts ? 0 : $0 })) {
                            ForEach(TrainingExperience.expertChoices(for: design.activeFraction), id: \.self) { n in
                                let locked = n > 64 && !b.has(.fineMoE)
                                Text(locked ? "\(n) 🔒" : "\(n)").tag(n).disabled(locked)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(moeNote(b, s))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        let paramCap = Physics.maxParamsB(s)
                        HStack {
                            Text("Total parameters")
                            Spacer()
                            Text(Fmt.params(design.paramsB)).font(.body.monospacedDigit().weight(.semibold))
                        }
                        LogSlider(value: $design.paramsB, range: 0.05...paramCap, label: "Total parameters", valueText: Fmt.params(design.paramsB))
                        if design.isMoE {
                            Text("\(Fmt.params(design.activeParamsB)) active per token").font(.caption).foregroundStyle(.secondary)
                        }
                        if design.paramsB >= paramCap * 0.98 {
                            Text("At the \(Fmt.params(paramCap)) limit of your training stack. \(Physics.paramCapLifts(s))")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if advanced {
                        LabeledPicker(title: "Attention", selection: $design.attention, options: AttentionKind.allCases,
                                      enabled: { $0 == .mha || ($0 == .gqa && b.has(.gqa)) || ($0 == .mla && b.has(.mla)) })
                        // 3.4: the KV cache is what serving pays for long contexts.
                        let kvToken = Physics.kvBytesPerToken(design)
                        Text("KV cache: \(Fmt.memory(kvToken / 1e9 * 1_000)) per 1,000 tokens of context, \(Fmt.memory(kvToken * Double(design.contextK) * 1024 / 1e9)) for a full \(design.contextK >= 1000 ? "1M" : "\(design.contextK)K") window — \(Fmt.pct(Physics.kvFactor(design), decimals: 0)) of multi-head attention's serving overhead. Smaller caches mean fewer chips per replica and faster long-context decoding.")
                            .font(.caption).foregroundStyle(.secondary)
                        let hasAlien = !s.alienArchs.isEmpty
                        LabeledPicker(title: "Architecture", selection: $design.mixer, options: MixerKind.allCases,
                                      enabled: { $0 == .transformer || ($0 == .hybrid && b.has(.ssmHybrid)) || ($0 == .diffusion && b.has(.diffusionLM)) || ($0 == .alien && hasAlien) })
                        if design.mixer != .transformer {
                            Text(mixerNote(design.mixer, s))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        FeatureToggle(title: "Multi-token prediction", detail: "A better training signal, and its extra heads decode several tokens at a time: faster serving, only for models trained with it.", isOn: $design.mtp, enabled: b.has(.mtp))
                    } else {
                        Text("\(design.attention.rawValue) attention · \(design.mixer.rawValue)\(design.mtp ? " · multi-token prediction" : "") — Advanced to change")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Context window", selection: $design.contextK) {
                        Text("2K").tag(2)
                        Text("8K").tag(8)
                        Text("32K").tag(32).disabled(!b.has(.context32k))
                        Text("128K").tag(128).disabled(!b.has(.context128k))
                        Text("1M").tag(1000).disabled(!b.has(.context1m))
                    }
                    .pickerStyle(.segmented)
                }

                Card {
                    CardHeader("Data", symbol: "externaldrive")
                    VStack(alignment: .leading, spacing: 4) {
                        let tokenCap = Physics.maxTokensT(design, state: s)
                        HStack {
                            Text(design.mode == .scratch ? "Training tokens" : "Student tokens")
                            Spacer()
                            Text(Fmt.tokens(design.tokensT)).font(.body.monospacedDigit().weight(.semibold))
                        }
                        LogSlider(value: $design.tokensT, range: 0.0005...tokenCap, label: design.mode == .scratch ? "Training tokens" : "Student tokens", valueText: Fmt.tokens(design.tokensT))
                        HStack {
                            let ratio = design.tokensT * 1000 / max(design.activeParamsB, 0.001)
                            Text(verbatim: "\(Int(ratio)) tokens per parameter").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if design.mode == .scratch && b.has(.scalingLaws) {
                                Button(b.researchedChinchilla ? "Compute-optimal" : "Kaplan rule") {
                                    if let note = LabMath.reshape(&design, overtrain: 1, accel: HardwareCatalog.get(design.accelID), state: s) { store.show(note) }
                                }
                                .buttonStyle(.link).font(.caption)
                                .help(b.researchedChinchilla ? "Re-split the same compute between parameters and tokens optimally" : "Kaplan-style sizing: big and under-trained. Research Chinchilla to do better.")
                            }
                        }
                        if design.tokensT >= tokenCap * 0.98 {
                            Text("At the \(Fmt.tokens(tokenCap)) token limit. \(Physics.tokenCapLifts(design, state: s))")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    let avail = Physics.uniqueTokensT(design, state: s)   // 3.6: includes held datasets
                    Text("Unique data available: \(Fmt.tokens(avail)) — more on the Training Data page").font(.caption)
                        .foregroundStyle(design.tokensT > avail * 4 && design.mode == .scratch ? .orange : .secondary)
                    LabeledPicker(title: "Mixture", selection: $design.dataMix, options: DataMix.allCases, enabled: { _ in true })
                    Text(design.dataMix.detail).font(.caption).foregroundStyle(.secondary)
                    if advanced {
                        LabeledPicker(title: "Mid-training shift", selection: $design.mixShift, options: MixShift.allCases,
                                      enabled: { $0 == .keep || b.has(.curriculum) })
                        Text(b.has(.curriculum) ? design.mixShift.detail : "Research Annealing & Data Curriculum to shift the mix mid-training.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if advanced && b.has(.syntheticData) {
                        HStack {
                            Text("Synthetic share")
                            Slider(value: $design.syntheticShare, in: 0...0.5, step: 0.05)
                                .accessibilityLabel("Synthetic share").accessibilityValue("\(Int(design.syntheticShare * 100)) percent")
                            Text("\(Int(design.syntheticShare * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                                .foregroundStyle(design.syntheticShare > 0.3 ? .orange : .primary)
                        }
                    }
                    DataPlanPanel(design: design, state: s)   // 3.6: data economy
                }

                if !advanced {
                    Card {
                        CardHeader(title: "Optimization & operations", symbol: "dial.medium") {
                            Button("Advanced…") { advanced = true }.buttonStyle(.link)
                        }
                        Text("\(design.optimizer.rawValue) · \(design.precision.short) · \(design.schedule.rawValue) · \(lr.label.lowercased()) learning rate · checkpoint every \(Int(interval * 100))%\(autoRollback ? " · auto-rollback" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                        opsCoverageRow(s)
                    }
                } else {
                    Card {
                        CardHeader("Optimization", symbol: "dial.medium")
                        LabeledPicker(title: "Optimizer", selection: $design.optimizer, options: OptimizerKind.allCases,
                                      enabled: { $0 == .adamw || ($0 == .muon && b.has(.muon)) || ($0 == .shampoo && b.has(.shampoo)) })
                        Picker("Precision", selection: $design.precision) {
                            Text("BF16").tag(Precision.bf16)
                            Text("FP8").tag(Precision.fp8).disabled(!b.has(.fp8Training))
                            Text("FP4").tag(Precision.fp4).disabled(!b.has(.fp4Training))
                        }
                        .pickerStyle(.segmented)
                        LabeledPicker(title: "LR schedule", selection: $design.schedule, options: ScheduleKind.allCases, enabled: { $0 == .cosine || b.has(.wsd) })
                        Picker("Peak learning rate", selection: $lr) {
                            ForEach(LRSchedule.allCases) { l in Text(l.label).tag(l) }
                        }
                        .pickerStyle(.segmented)
                        Text(lr.detail).font(.caption).foregroundStyle(.secondary)
                        FeatureToggle(title: "Annealing on the best data", detail: "Finish pre-training by decaying the LR on curated data.", isOn: $design.anneal, enabled: b.has(.curriculum))
                        Picker("Eval checkpoints", selection: $interval) {
                            Text("2%").tag(0.02)
                            Text("5%").tag(0.05)
                            Text("10%").tag(0.1)
                            Text("25%").tag(0.25)
                        }
                        .pickerStyle(.segmented)
                        Text("Each checkpoint runs evals and updates the projection. Saving costs \(Fmt.pct(1 - Sim.checkpointOverhead(interval), decimals: 1)) of throughput at this interval; a loss-spike rollback loses on average half an interval of pre-training.")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("Auto-rollback on loss spikes", isOn: $autoRollback).toggleStyle(.switch)
                        // 3.4: memory and fault tolerance are design choices with costs.
                        LabeledPicker(title: "Memory plan", selection: $design.memoryPlan, options: MemoryPlan.allCases, enabled: { _ in true })
                        Text("\(design.memoryPlan.detail) Needs \(Fmt.trim(Physics.trainingBytes(design, bonuses: b), 1)) bytes per parameter (\(Fmt.trim(Physics.stateBytesPerParam(design), 1)) of optimizer state and weights, \(Fmt.trim(Physics.activationBytesPerParam(design, bonuses: b), 1)) of activations at this context).")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Hot spares", selection: $design.spares) {
                            Text("None").tag(0.0)
                            Text("2%").tag(0.02)
                            Text("5%").tag(0.05)
                        }
                        .pickerStyle(.segmented)
                        Text(design.spares > 0
                             ? "\(Fmt.int(Int(Double(design.chips) * design.spares))) chips stand by to replace a failed node in seconds: \(Fmt.pct(1 - Physics.spareRecovery(design.spares), decimals: 0)) less time lost per failure, \(Fmt.pct(design.spares, decimals: 0)) less compute."
                             : "No spares: every failure waits for the job to be rescheduled. Worth it on big clusters, where failures come every few minutes.")
                            .font(.caption).foregroundStyle(.secondary)
                        opsCoverageRow(s)
                    }
                }
            }

            Card {
                CardHeader("Post-training", symbol: "slider.horizontal.3")
                FeatureToggle(title: "Instruction tuning (SFT)", detail: "Turns a text predictor into an assistant.", isOn: $design.instruct, enabled: b.has(.chat))
                FeatureToggle(title: "Preference tuning (RLHF)", detail: "Big boost to chat quality and Arena Elo.", isOn: $design.rlhf, enabled: b.has(.rlhf) && design.instruct)
                if design.rlhf && b.has(.dpo) {
                    Toggle("Use DPO instead of PPO", isOn: $design.useDPO).toggleStyle(.switch).font(.callout)
                }
                FeatureToggle(title: "Reasoning RL", detail: "RL on verifiable problems — gains grow log-linearly with RL compute.",
                              isOn: $design.reasoning, enabled: b.has(.reasoning) && design.instruct)
                // 3.4: two stages with real consequences for serving and for regulators.
                FeatureToggle(title: "Quantisation-aware training", detail: "A short stage that teaches the model to run in FP8/FP4: it loses about a third as much quality when served quantised.",
                              isOn: $design.qat, enabled: b.has(.int8Serving))
                FeatureToggle(title: "Dangerous-capability evaluations", detail: s.market.euAIAct
                                ? "Required by the EU AI Act for systemic-risk models: without it, a near-frontier release risks fines. Findings are patched before release."
                                : "Test for hazardous capabilities before release and patch what you find; required wherever the EU AI Act applies.",
                              isOn: $design.safetyEvals, enabled: s.researched.contains("evals_rsp"))
                if design.reasoning && b.has(.reasoning) {
                    Picker("RL compute", selection: $design.rlLevel) {
                        ForEach(RLLevel.allCases.filter { $0 != .off }) { l in Text(l.label).tag(l).disabled(l == .extreme && !b.has(.extremeRL)) }
                    }
                    .pickerStyle(.segmented)
                    Text(design.rlLevel.detail).font(.caption).foregroundStyle(.secondary)
                }
                FeatureToggle(title: "Tool use", detail: "Function calling — needed for agents.", isOn: $design.toolUse, enabled: b.has(.toolUse))
                FeatureToggle(title: "Agentic RL", detail: "Train in sandboxes on long tasks. Agents and horizon.", isOn: $design.agentRL, enabled: b.has(.agents) && design.toolUse)
                FeatureToggle(title: "Vision", detail: "Image understanding.", isOn: $design.vision, enabled: b.has(.vision))
                FeatureToggle(title: "Voice", detail: "Speech-to-speech.", isOn: $design.audio, enabled: b.has(.audio))
                FeatureToggle(title: "Video generation", detail: "Expensive, consumer magnet.", isOn: $design.video, enabled: b.has(.video))
                FeatureToggle(title: "Safety training", detail: "Fewer scandals, better enterprise trust.", isOn: $design.safetyTraining, enabled: true)
                FeatureToggle(title: "Benchmark tuning", detail: "+scores now… and a risk of a contamination scandal later.",
                              isOn: $design.benchmarkTuning, enabled: true, warning: true)
            }

            Card {
                CardHeader(title: "Cluster", symbol: "cpu") {
                    Button("Get more compute") { store.open(.hardware) }.buttonStyle(.link)
                }
                Picker("Accelerator", selection: $design.accelID) {
                    ForEach(d.pools) { p in
                        Text("\(p.accel.name) — \(d.availableText(p.accel.id)) of \(p.total)").tag(p.accel.id)
                    }
                }
                .onChange(of: design.accelID) { _, new in
                    design.chips = max(1, store.derived.available(new))
                    fixPrecision(s)
                }
                // 3.9: chips leased out count: starting the run recalls them.
                let free = d.available(design.accelID)
                HStack {
                    Text("Chips")
                    Spacer()
                    QuantityPicker(value: $design.chips, range: 1...max(1, free))
                }
                if (d.leases[design.accelID] ?? 0) > 0 {
                    Text("\(d.availableText(design.accelID)).").font(.caption).foregroundStyle(.secondary)
                }
                if let a = HardwareCatalog.get(design.accelID) {
                    Text("\(Fmt.tflops(a.trainTFLOPS(design.precision))) \(design.precision.short) per chip · \(Fmt.memory(a.memoryGB)) \(a.memoryType) · scale-up domain \(a.scaleUp)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: Helpers

    /// Ops staffing for this cluster: the coverage unpinned training-ops swarms would give it, and what that buys.
    private func opsCoverageRow(_ s: GameState) -> some View {
        let b = store.derived.bonuses
        let cov = Training.plannedCoverage(s, chips: design.chips)
        let now = Training.goodput(chips: design.chips, coverage: cov, state: s, bonuses: b)
        let full = Training.goodput(chips: design.chips, coverage: 1, state: s, bonuses: b)
        return HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(cov >= 0.9 ? .green : (cov >= 0.5 ? .orange : .secondary))
            VStack(alignment: .leading, spacing: 1) {
                Text("Ops-agent coverage \(Fmt.pct(cov, decimals: 0)) · goodput \(Fmt.pct(now, decimals: 0))").font(.callout)
                Text(full - now > 0.02 ? "Full coverage would reach \(Fmt.pct(full, decimals: 0)). A run needs one engineer-equivalent per 600 chips."
                                       : "Failures barely touch a run this size.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if full - now > 0.02 { Button("Agent Swarms") { store.open(.swarms) }.controlSize(.small) }
        }
    }

    private func prepare(_ s: GameState, _ d: Derived) {
        let b = d.bonuses
        if let best = d.pools.max(by: { Double($0.free) * $0.accel.bf16 < Double($1.free) * $1.accel.bf16 }) {
            design.accelID = best.accel.id
            design.chips = max(1, best.free)
        }
        design.name = nextName("\(s.companyName.split(separator: " ").first.map(String.init) ?? "Model")-\(s.models.count)")
        design.instruct = b.has(.chat)
        design.rlhf = b.has(.rlhf)
        design.contextK = b.has(.context128k) ? 128 : (b.has(.context32k) ? 32 : 8)
        design.attention = b.has(.gqa) ? .gqa : .mha
        design.anneal = b.has(.curriculum)
        fixPrecision(s)
        if let note = autoSize(s, days: 30, overtrain: 1) { store.show(note) }
        let top = d.board.filter(\.released).map(\.index).max() ?? 50
        targetIndex = clamp((top * 0.7).rounded(), 5, 95)
    }

    private func fixPrecision(_ s: GameState) {
        let b = store.derived.bonuses
        guard let a = HardwareCatalog.get(design.accelID) else { return }
        if b.has(.fp8Training) && a.fp8 > 0 { design.precision = .fp8 } else { design.precision = .bf16 }
    }

    /// Size the run so it finishes in about `days`, allocating compute the way your scaling science knows how. A cluster
    /// too big to keep running is shrunk first (never sized against a goodput floor). Returns a note for the player.
    private func autoSize(_ s: GameState, days: Double, overtrain: Double) -> String? {
        LabMath.autoSize(&design, days: days, overtrain: overtrain, state: s, lr: lr, interval: interval)
    }

    private func pickFinetuneBase(_ s: GameState) -> Bool {
        guard let a = HardwareCatalog.get(design.accelID) else { return false }
        let b = store.derived.bonuses
        design.chips = Training.healthyChips(design.chips, target: Training.goodputTarget, state: s, bonuses: b)
        let perDay = Physics.flopsPerDay(design, state: s, lr: .conservative, interval: 0.25)
        for item in Physics.openModels(s) {
            var trial = design
            trial.mode = .finetune
            trial.paramsB = item.model.paramsB
            trial.activeFraction = item.model.paramsB > 200 ? 0.06 : 1
            guard Physics.trainingMemory(trial, accel: a, bonuses: b).ok else { continue }
            let tokensT = perDay * 10 / (6 * trial.activeParamsB * 1e9) / 1e12
            guard tokensT >= 0.0005 else { continue }
            design.mode = .finetune
            setBase(item.model.id.uuidString, s)
            design.tokensT = min(0.02, tokensT)
            return true
        }
        return false
    }

    private func setBase(_ ref: String, _ s: GameState) {
        design.baseModelRef = ref.isEmpty ? nil : ref
        if let m = Physics.openModels(s, latestPerLab: nil).first(where: { $0.model.id.uuidString == ref }) {
            design.paramsB = m.model.paramsB
            design.activeFraction = m.model.paramsB > 200 ? 0.06 : 1
            design.tokensT = 0.02
        }
    }

    private func nextName(_ name: String) -> String {
        let parts = name.split(separator: "-")
        if let last = parts.last, let n = Int(last) {
            return parts.dropLast().joined(separator: "-") + "-\(n + 1)"
        }
        return name + "-2"
    }
}

/// One-line explanation of a non-Transformer architecture choice.
private func mixerNote(_ m: MixerKind, _ s: GameState) -> String {
    switch m {
    case .transformer: return ""
    case .hybrid: return "Mamba layers between attention: faster decoding, longer context, slightly weaker reasoning."
    case .diffusion: return "Generates by denoising: 5–10× faster output, lower quality."
    case .alien:
        guard let a = Xeno.best(s) else { return "Your agents haven't found an alien architecture yet." }
        let legible = Xeno.legibility(a, s)
        return "\(a.name), found by your agents: trains like ×\(Fmt.trim(a.multiplier, 1)) the compute and serves cheaper — but humans follow only \(Int(legible * 100))% of it (up to −\(Int(25 * (1 - legible))) safety)."
    }
}

private struct LabeledPicker<T: Hashable & Identifiable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T
    let options: [T]
    let enabled: (T) -> Bool

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { o in
                Text(o.rawValue + (enabled(o) ? "" : " 🔒")).tag(o).disabled(!enabled(o))
            }
        }
    }
}

// MARK: - Forecast

struct ForecastPanel: View {
    let design: ModelDesign
    let lr: LRSchedule
    let interval: Double
    let state: GameState
    let derived: Derived
    let start: () -> Void
    let ladder: () -> Void
    let resize: (Int) -> Void

    var body: some View {
        let s = state
        let b = derived.bonuses
        if let est = Physics.estimate(design, state: s, lr: lr, interval: interval) {
            let f = est.forecast
            let known = b.has(.scalingLaws)
            let set = derived.indexSet
            let band = ForecastEngine.indexBand(adjusted(f), design: design, set: set)
            let top = derived.board.filter { $0.released && !$0.isPlayer }.map(\.index).max() ?? 0
            let mine = derived.board.filter(\.isPlayer).map(\.index).max()
            let tier = ForecastEngine.tier(index: band.mean, top: top)
            let comparable = RealModels.closest(index: band.mean, set: set)
            let days = est.days
            let advice = Training.goodputAdvice(chips: design.chips, coverage: est.coverage, running: false, state: s, bonuses: b)
            let blocked = advice?.blocked ?? false
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    CardHeader(title: "Forecast", symbol: "sparkles", subtitle: known ? "Scaling-law prediction · 80% interval" : "Research Neural Scaling Laws for real forecasts") {
                        HelpButton(term: .forecast)
                        if known { Pill(text: tier, color: tierColor(tier), symbol: tier.hasPrefix("Genius") ? "crown.fill" : nil) }
                    }
                    if known {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(Fmt.score(band.mean)).font(TypeRamp.display)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Intelligence Index · \(Fmt.score(band.low))–\(Fmt.score(band.high))").foregroundStyle(.secondary)
                                if let comparable {
                                    Text("Comparable to \(comparable.name) (\(comparable.lab), \(comparable.date.label))").font(.caption.weight(.semibold))
                                }
                                Text("Final loss ≈ \(String(format: "%.3f", f.finalLoss)) · task horizon ≈ \(BenchmarkCatalog.formatHorizon(BenchmarkCatalog.taskHorizonMinutes(ForecastEngine.profile(adjusted(f), design: design, key: "h"))))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        BandStrip(low: band.low, mean: band.mean, high: band.high, top: top, mine: mine)
                            .frame(height: 34)
                        DriverList(drivers: f.drivers, c: f.c)
                        ForEach(f.notes, id: \.self) { n in
                            Label(n, systemImage: n.hasPrefix("Scaling ladder validated") ? "checkmark.seal.fill" : "scope").font(.caption)
                                .foregroundStyle(n.hasPrefix("Scaling ladder validated") ? .green : .secondary)
                        }
                        HStack(spacing: 14) {
                            Label("±\(Fmt.trim(f.sigma, 2)) uncertainty (×\(Fmt.trim(pow(10, f.sigma), 2)) effective compute)", systemImage: "plusminus.circle")
                            if est.toy {
                                Label("Experiment-sized: no bugs or other mid-run incidents", systemImage: "checkmark.shield").foregroundStyle(.secondary)
                            } else {
                                Label("\(Int(f.bugRisk * 100))% chance of a silent bug", systemImage: "ladybug").foregroundStyle(f.bugRisk > 0.2 ? .orange : .secondary)
                            }
                        }
                        .font(.caption)
                        if b.has(.proxyLadder) && design.mode == .scratch && !f.ladderCovered && est.finishes {
                            let ladderDays = days * 0.02 / 0.33
                            Button(action: ladder) {
                                Label("Run a scaling ladder first (~\(Fmt.days(max(0.2, ladderDays))), \(Fmt.money(est.dailyCost * max(0.2, ladderDays))))", systemImage: "chart.line.uptrend.xyaxis")
                            }
                            .help("Five proxy runs at up to 2% of this compute. Halves the uncertainty, tunes hyperparameters and catches most bugs — like OpenAI did before GPT-4.")
                        }
                        DisclosureGroup("Benchmark predictions") {
                            let p = ForecastEngine.profile(adjusted(f), design: design, key: "pred")
                            VStack(spacing: 4) {
                                ForEach(set) { bm in
                                    HStack {
                                        Image(systemName: bm.kind.symbol).font(.caption2).foregroundStyle(bm.kind.color).frame(width: 14)
                                        Text(bm.name).font(.caption).frame(width: 160, alignment: .leading).lineLimit(1)
                                        Meter(value: bm.score(p, noise: false) / 100, tint: bm.kind.color, height: 7)
                                        Text(bm.format(bm.score(p, noise: false))).font(.caption.monospacedDigit()).frame(width: 52, alignment: .trailing)
                                    }
                                }
                                HStack {
                                    Text("LMArena Elo").font(.caption).frame(width: 174, alignment: .leading)
                                    Text(verbatim: "≈ \(Int(BenchmarkCatalog.arenaElo(c: f.c + lr.qualityBonus, bonus: f.arena)))").font(.caption.monospacedDigit().weight(.semibold))
                                    Spacer()
                                }
                            }
                        }
                        .font(.callout)
                    } else {
                        Label("Without scaling laws you're flying blind — the model could land anywhere.", systemImage: "questionmark.diamond")
                            .foregroundStyle(.secondary)
                        Text("Rough guess: \(ForecastEngine.tier(index: band.mean, top: top).lowercased()) (±\(Fmt.trim(f.sigma, 2)))").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(f.penalties, id: \.self) { pen in
                        Label(pen, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                    }
                    ForEach(Training.postTrainingRisks(design, toy: est.toy, state: s), id: \.self) { risk in
                        Label(risk, systemImage: "exclamationmark.shield").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if known { DesignDomainsCard(profile: ForecastEngine.profile(adjusted(f), design: design, key: "domains"), design: design, state: s) }   // 3.4

                Card {
                    CardHeader("Compute budget", symbol: "bolt.fill")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                        BigNumber(label: "Training compute", value: Fmt.flops(est.flops + est.postFlops), unit: "FLOPs")
                        BigNumber(label: "Wall-clock time", value: est.finishes ? Fmt.days(days) : "Never", unit: est.incidentDays >= 0.5 ? "incl. ~\(Fmt.days(est.incidentDays)) for incidents" : "",
                                  tint: est.finishes ? .primary : .red)
                        BigNumber(label: "Estimated cost", value: est.finishes ? Fmt.money(est.totalCost) : "—", unit: "", tint: est.totalCost > s.cash ? .red : .primary)
                        BigNumber(label: "Cluster throughput", value: Fmt.tflops(clusterTF(est)), unit: "effective")
                        BigNumber(label: "Serving cost", value: Economy.servingCostPerM(design: design, s).map { Fmt.price($0) } ?? "—",
                                  unit: "per 1M tokens at full load (going rate \(Fmt.price(Macro.frontierPrice(s.year))) at the frontier)")
                        BigNumber(label: "MFU · goodput", value: "\(Fmt.pct(est.mfu, decimals: 0)) · \(Fmt.pct(est.goodput, decimals: 0))", unit: "",
                                  tint: est.goodput < Training.goodputFloor ? .red : (est.goodput < Training.goodputTarget ? .orange : .primary))
                        BigNumber(label: "Hardware failures", value: est.finishes ? Fmt.trim(Double(design.chips) * Training.failuresPerChipDay * days, 0)
                                                                                  : Fmt.trim(Double(design.chips) * Training.failuresPerChipDay, 0),
                                  unit: est.finishes ? "expected (Llama 3 rates)" : "per day (Llama 3 rates)")
                    }
                    HStack(spacing: 8) {
                        Image(systemName: est.memory.ok ? "checkmark.seal.fill" : "xmark.octagon.fill")
                            .foregroundStyle(est.memory.ok ? .green : .red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(est.memory.ok ? "Fits in memory" : "Doesn't fit in memory").font(.callout.weight(.semibold))
                            Text("Needs \(Fmt.memory(est.memory.needGB)). \(est.memory.note)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let c = Regulation.note(flops: est.flops, state: s) {
                        Label(c, systemImage: "building.columns").font(.caption).foregroundStyle(.purple)
                    }
                    if let adv = advice {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(adv.blocked ? "This run would stall: expected goodput \(Fmt.pct(adv.goodput, decimals: 0))"
                                              : "Failures will slow this run: expected goodput \(Fmt.pct(adv.goodput, decimals: 0))",
                                  systemImage: adv.blocked ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .font(.callout.weight(.semibold)).foregroundStyle(adv.blocked ? .red : .orange)
                            Text(adv.headline).font(.caption)
                            ForEach(adv.fixes, id: \.self) { fix in
                                Label(fix, systemImage: "wrench.and.screwdriver").font(.caption).foregroundStyle(.secondary)
                            }
                            if adv.healthyChips < design.chips {
                                Button("Use \(Fmt.int(adv.healthyChips)) chips") { resize(adv.healthyChips) }
                                    .controlSize(.small)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((adv.blocked ? Color.red : Color.orange).opacity(0.08), in: .rect(cornerRadius: 10))
                    }
                }

                StagePlan(design: design, est: est, days: days, bonuses: b)

                if design.mode == .scratch && known {
                    Card {
                        CardHeader("Forecast loss curve", symbol: "chart.line.downtrend.xyaxis", subtitle: "Epoch AI's Chinchilla fit, shifted by your algorithmic gains")
                        LossForecastChart(design: design, gain: f.algo + f.data, sigma: f.sigma)
                            .frame(height: 140)
                    }
                }

                Button(action: start) {
                    Label(est.toy ? "Start training \(design.name)" : "Review & launch \(design.name)", systemImage: est.toy ? "play.fill" : "checklist")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!est.memory.ok || blocked)
                if blocked {
                    Text("Hardware failures would leave this run under \(Fmt.pct(Training.goodputFloor, decimals: 0)) goodput, so it can't start. Fix it with one of the options under Compute budget.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func adjusted(_ f: Forecast) -> Forecast {
        var g = f
        g.c += lr.qualityBonus
        return g
    }

    private func clusterTF(_ est: Physics.Estimate) -> Double {
        guard let a = HardwareCatalog.get(design.accelID) else { return 0 }
        return Double(design.chips) * a.trainTFLOPS(design.precision) * est.mfu
    }
}

func tierColor(_ tier: String) -> Color {
    if tier.hasPrefix("Genius") { return .yellow }
    if tier.hasPrefix("Frontier") { return .orange }
    if tier.hasPrefix("Strong") { return .green }
    if tier.hasPrefix("Solid") { return .blue }
    if tier.hasPrefix("Okay") { return .secondary }
    return .red
}

/// The forecast interval on a 0–100 strip, with the world's best and your best marked.
struct BandStrip: View {
    let low: Double
    let mean: Double
    let high: Double
    let top: Double
    let mine: Double?

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let x: (Double) -> CGFloat = { v in w * CGFloat(clamp(v, 0, 100) / 100) }
            ZStack(alignment: .topLeading) {
                Capsule().fill(.quaternary).frame(height: 8).offset(y: 12)
                Capsule().fill(LinearGradient(colors: [.indigo.opacity(0.35), .indigo, .indigo.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, x(high) - x(low)), height: 8)
                    .offset(x: x(low), y: 12)
                Circle().fill(.indigo).frame(width: 14, height: 14).overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .position(x: x(mean), y: 16)
                marker(x: x(top), label: "World #1 \(Fmt.score(top))", color: .orange)
                if let mine { marker(x: x(mine), label: "Your best \(Fmt.score(mine))", color: .green, below: true) }
            }
        }
    }

    private func marker(x: CGFloat, label: String, color: Color, below: Bool = false) -> some View {
        VStack(spacing: 1) {
            if !below { Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(color).fixedSize() }
            Rectangle().fill(color).frame(width: 2, height: 14)
            if below { Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(color).fixedSize() }
        }
        .position(x: x, y: below ? 24 : 6)
    }
}

/// What the forecast is made of, as effective-compute multipliers.
struct DriverList: View {
    let drivers: [ForecastDriver]
    let c: Double

    var body: some View {
        let shown = drivers.filter { $0.kind != .base }
        VStack(alignment: .leading, spacing: 4) {
            if let base = drivers.first(where: { $0.kind == .base }) {
                HStack {
                    Text(base.name).font(.caption.weight(.semibold))
                    Spacer()
                    Text(base.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            ForEach(shown) { d in
                HStack(spacing: 8) {
                    Text(d.name).font(.caption).frame(width: 190, alignment: .leading).lineLimit(1)
                        .help(d.detail)
                    GeometryReader { g in
                        let mid = g.size.width / 2
                        let len = min(mid, CGFloat(abs(d.value)) / 0.6 * mid)
                        Rectangle().fill(d.value >= 0 ? Color.green.gradient : Color.orange.gradient)
                            .frame(width: max(2, len), height: 7)
                            .offset(x: d.value >= 0 ? mid : mid - len, y: 3)
                        Rectangle().fill(.quaternary).frame(width: 1, height: 13).offset(x: mid)
                    }
                    .frame(height: 13)
                    Text(d.kind == .skill ? "+\(Fmt.trim(d.value, 2))" : "×\(Fmt.trim(d.multiplier, d.multiplier < 10 ? 2 : 0))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(d.value >= 0 ? .green : .orange)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

struct LossForecastChart: View {
    let design: ModelDesign
    let gain: Double
    let sigma: Double

    var body: some View {
        let points: [(Double, Double, Double, Double)] = (0..<40).map { i in
            let t = design.tokensT * pow(10, -2 + 2 * Double(i) / 39)
            let raw = ForecastEngine.loss(paramsB: design.activeParamsB, tokensT: t)
            func shifted(_ g: Double) -> Double { ForecastEngine.E + (raw - ForecastEngine.E) * pow(10, -ForecastEngine.gamma * g) }
            return (t, shifted(gain), shifted(gain - 1.28 * sigma), shifted(gain + 1.28 * sigma))
        }
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Tokens (T)", p.0), yStart: .value("Low", p.3), yEnd: .value("High", p.2))
                    .foregroundStyle(.indigo.opacity(0.15))
                LineMark(x: .value("Tokens (T)", p.0), y: .value("Loss", p.1))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.accentGradient)
            }
        }
        .chartXScale(type: .log)
        .chartYAxisLabel("Loss")
        .chartXAxisLabel("Tokens seen (T)")
    }
}

private struct TargetPlanner: View {
    @Environment(GameStore.self) private var store
    @Binding var design: ModelDesign
    @Binding var target: Double
    let state: GameState
    let derived: Derived

    var body: some View {
        let s = state
        let b = derived.bonuses
        Card {
            CardHeader(title: "Target planner", symbol: "scope", subtitle: "Pick the Intelligence Index you want — we'll size the compute") {
                Pill(text: "World #1: \(Fmt.score(derived.board.filter(\.released).map(\.index).max() ?? 0))", color: .orange)
            }
            if !b.has(.scalingLaws) {
                Label("Research Neural Scaling Laws to plan by target.", systemImage: "lock.fill").foregroundStyle(.secondary)
            } else if design.mode == .scratch, let a = HardwareCatalog.get(design.accelID), let est = Physics.estimate(design, state: s) {
                HStack {
                    Text("Target index")
                    Slider(value: $target, in: 5...99, step: 1)
                        .accessibilityLabel("Target index").accessibilityValue(Fmt.score(target))
                    Text(Fmt.score(target)).font(.title3.weight(.bold).monospacedDigit()).frame(width: 50)
                }
                let base = ForecastEngine.profile(est.forecast, design: design, key: "plan")
                if est.goodput < Training.goodputFloor {
                    Text("This cluster loses most of its time to hardware failures (goodput \(Fmt.pct(est.goodput, decimals: 0))). Fix that first: see Compute budget.")
                        .font(.callout).foregroundStyle(.orange)
                } else if let need = LabMath.capabilityFor(index: target, base: base, set: derived.indexSet) {
                    let factor = pow(10, need - base.c)
                    let flops = (est.flops + est.postFlops) * factor
                    let perDay = Physics.flopsPerDay(design, state: s)
                    let days = flops / max(perDay, 1)
                    let cost = est.dailyCost * days
                    HStack(spacing: 18) {
                        PlannerStat(label: "Compute needed", value: Fmt.flops(flops))
                        PlannerStat(label: "On this cluster", value: Fmt.days(days), tint: days > 180 ? .orange : .primary)
                        PlannerStat(label: "Cost", value: Fmt.money(cost), tint: cost > s.cash ? .red : .primary)
                        PlannerStat(label: "vs. current design", value: factor >= 1 ? "\(Fmt.trim(factor, 1))× more" : "\(Fmt.trim(1 / factor, 1))× less")
                    }
                    HStack {
                        Button("Size the run for this target") {
                            let note = LabMath.size(&design, flops: est.flops * factor, overtrain: 1, accel: a, state: s)
                            store.show("Sized for index \(Fmt.score(target)) — check memory and time" + (note.map { ". \($0)" } ?? ""))
                        }
                        .buttonStyle(.bordered)
                        if days > 120 {
                            Text("Tip: more chips or better techniques bring this under 3 months.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("Out of reach with today's research — the hardest benchmarks need breakthroughs first.").font(.callout).foregroundStyle(.orange)
                }
            } else {
                Text("The planner sizes from-scratch pre-training runs.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlannerStat: View {
    let label: String
    let value: String
    var tint: Color = .primary
    var body: some View {
        MetricTile(label: label, value: value, tint: tint, style: .plain)
    }
}

struct FeatureToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let enabled: Bool
    var warning = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(title)
                    if !enabled { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary) }
                }
                Text(enabled ? detail : "Locked — research required").font(.caption).foregroundStyle(warning ? .orange : .secondary)
            }
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!enabled)
        }
        .onChange(of: enabled) { _, on in if !on { isOn = false } }
    }
}

/// The run broken into its real phases, with estimated days for each.
struct StagePlan: View {
    let design: ModelDesign
    let est: Physics.Estimate
    let days: Double
    let bonuses: ResearchBonuses

    var body: some View {
        let stages = Training.stages(design, pretrain: est.flops, bonuses: bonuses)
        let total = max(stages.reduce(0) { $0 + $1.flops }, 1)
        Card {
            CardHeader("Training plan", symbol: "list.number")
            HStack(spacing: 4) {
                ForEach(stages) { st in
                    let share = st.flops / total
                    VStack(alignment: .leading, spacing: 3) {
                        RoundedRectangle(cornerRadius: 4).fill(StageColors.color(st.name).gradient).frame(height: 10)
                        Text(st.name).font(.caption2.weight(.semibold)).lineLimit(1)
                        Text(Fmt.days(max(share * days, 0.1))).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(max(0.05, share))
                }
            }
        }
    }
}

enum StageColors {
    static func color(_ name: String) -> Color {
        switch name {
        case "Pre-training", "Fine-tuning", "Distillation", "Proxy runs": .blue
        case "Annealing", "Decay & anneal": .cyan
        case "SFT", "Base-model evals": .teal
        case "RLHF", "DPO": .green
        case "Multimodal", "Video": .orange
        case "Tool use", "Agentic RL": .indigo
        case "Reasoning RL": .pink
        default: .purple
        }
    }
}

private struct BigNumber: View {
    let label: String
    let value: String
    let unit: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
            if !unit.isEmpty { Text(unit).font(.caption2).foregroundStyle(.tertiary) }
        }
    }
}
