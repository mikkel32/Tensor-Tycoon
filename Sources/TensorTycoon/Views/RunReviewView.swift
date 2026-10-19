import SwiftUI

// MARK: - 3.5: pre-training review

/// The last look before a substantial run: everything the estimate, the forecast and the Rival Watch say about it,
/// with a fix next to each problem. Experiments skip it and start straight away.
struct RunReviewSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var design: ModelDesign
    @Binding var lr: LRSchedule
    @Binding var interval: Double
    let launch: () -> Void
    let ladder: () -> Void

    var body: some View {
        let s = store.game
        let d = store.derived
        VStack(spacing: 0) {
            if let r = TrainingExperience.review(design, lr: lr, interval: interval, state: s, set: d.indexSet, board: d.board, watch: d.watch) {
                header(r, s)
                Divider()
                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            ArchitectureDiagram(design: design, state: s, compact: true)
                            dataCard(r, s)
                            computeCard(r)
                            scheduleCard(r, s)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        VStack(alignment: .leading, spacing: 14) {
                            warningsCard(r)
                            forecastCard(r, s, d)
                            positionCard(r)
                            breakdownCard(r)
                            risksCard(r)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .padding(18)
                }
                Divider()
                footer(r)
            } else {
                Text("Pick hardware to review this run.").padding(40)
                Button("Close") { dismiss() }.padding(.bottom, 20)
            }
        }
        .frame(width: 1040, height: 780)
    }

    // MARK: Sections

    private func header(_ r: TrainingExperience.Review, _ s: GameState) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: design.objective.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(scaleColor(r.scale).gradient, in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Pre-training review").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Pill(text: r.scale.label, color: scaleColor(r.scale), symbol: r.scale >= .major ? "flame.fill" : nil)
                    Pill(text: design.objective.label, color: .indigo, symbol: design.objective.symbol)
                }
                Text(design.name).font(.title.weight(.bold))
                Text(identityLine(r, s)).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(r.frontierSource.isEmpty ? "Compute" : "vs the largest known run").font(.caption).foregroundStyle(.secondary)
                Text(r.frontierSource.isEmpty ? Fmt.flops(r.est.flops) : "\(Fmt.trim(r.frontierShare, r.frontierShare < 10 ? 2 : 0))×")
                    .font(.title2.weight(.bold).monospacedDigit())
                if !r.frontierSource.isEmpty { Text(r.frontierSource).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
        .padding(18)
    }

    private func identityLine(_ r: TrainingExperience.Review, _ s: GameState) -> String {
        var parts: [String] = []
        if !design.family.isEmpty { parts.append("\(design.family)\(design.generation > 0 ? " generation \(design.generation)" : "")") }
        parts.append(design.mode == .scratch ? "pre-trained from scratch" : design.mode.rawValue.lowercased())
        if !design.blurb.isEmpty { parts.append(design.blurb) }
        return parts.joined(separator: " · ")
    }

    private func dataCard(_ r: TrainingExperience.Review, _ s: GameState) -> some View {
        let unique = Physics.uniqueTokensT(design, state: s)
        let epochs = design.tokensT / max(unique, 1e-9)
        return Card {
            CardHeader("Data", symbol: "externaldrive")
            SpecRow(label: "Training tokens", value: Fmt.tokens(design.tokensT))
            SpecRow(label: "Unique data available", value: Fmt.tokens(unique))
            SpecRow(label: "Passes over the data", value: design.mode == .scratch ? "\(Fmt.trim(epochs, epochs < 10 ? 2 : 0)) epochs" : "—")
            SpecRow(label: "Tokens per active parameter", value: Fmt.int(Int(design.tokensT * 1000 / max(design.activeParamsB, 0.001))))
            SpecRow(label: "Mixture", value: design.dataMix.rawValue + (design.mixShift == .keep ? "" : " → \(design.mixShift.rawValue.lowercased())"))
            if design.syntheticShare > 0 { SpecRow(label: "Synthetic share", value: Fmt.pct(design.syntheticShare, decimals: 0)) }
        }
    }

    private func computeCard(_ r: TrainingExperience.Review) -> some View {
        let e = r.est
        let memShare = r.memPerChipGB / max(r.accel.memoryGB, 1)
        return Card {
            CardHeader("Compute", symbol: "cpu")
            SpecRow(label: "Pre-training + post-training", value: "\(Fmt.flops(e.flops)) + \(Fmt.flops(e.postFlops)) FLOPs")
            SpecRow(label: "Accelerators", value: "\(Fmt.int(design.chips))× \(r.accel.name)")
            SpecRow(label: "Precision", value: design.precision.short)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Memory per chip").foregroundStyle(.secondary)
                    Spacer()
                    Text(r.accel.weightStreaming ? "streams weights" : "\(Fmt.memory(r.memPerChipGB)) of \(Fmt.memory(r.accel.memoryGB))")
                        .monospacedDigit().foregroundStyle(e.memory.ok ? Color.primary : Color.red)
                }
                .font(.callout)
                if !r.accel.weightStreaming { Meter(value: memShare, tint: memShare > 1 ? .red : (memShare > 0.85 ? .orange : .green), height: 6) }
                Text(e.memory.note).font(.caption2).foregroundStyle(.secondary)
            }
            SpecRow(label: "Interconnect", value: "\(r.accel.interconnect) · \(Fmt.int(r.scaleUpDomains)) domain\(r.scaleUpDomains == 1 ? "" : "s") of \(r.accel.scaleUp)")
            if r.scaleOutLoss > 0.005 {
                Text("Scale-out across domains costs \(Fmt.pct(r.scaleOutLoss, decimals: 0)) of MFU.").font(.caption).foregroundStyle(r.scaleOutLoss > 0.15 ? .orange : .secondary)
            }
            SpecRow(label: "Expected MFU · goodput", value: "\(Fmt.pct(e.mfu, decimals: 0)) · \(Fmt.pct(e.goodput, decimals: 0))")
            SpecRow(label: "Ops-agent coverage", value: Fmt.pct(e.coverage, decimals: 0))
            SpecRow(label: "Useful compute per day", value: "\(Fmt.flops(Physics.flopsPerDay(design, state: store.game, lr: lr, interval: interval))) FLOPs")
        }
    }

    private func scheduleCard(_ r: TrainingExperience.Review, _ s: GameState) -> some View {
        let e = r.est
        return Card {
            CardHeader("Time, money and power", symbol: "clock")
            SpecRow(label: "Duration", value: e.finishes ? Fmt.days(e.days) + (e.incidentDays >= 0.5 ? " (incl. ~\(Fmt.days(e.incidentDays)) for incidents)" : "") : "Never finishes")
            SpecRow(label: "Completion", value: r.finish?.gameShort ?? "—")
            SpecRow(label: "Cost", value: e.finishes ? "\(Fmt.money(e.totalCost)) (\(Fmt.money(e.dailyCost))/day)" : "—")
            SpecRow(label: "Cash after", value: e.finishes ? Fmt.money(s.cash - e.totalCost) : "—")
            SpecRow(label: "Facility power", value: "\(powerText(r.powerMW)) at PUE \(Fmt.trim(TrainingExperience.pue(s), 2))")
            SpecRow(label: "Energy", value: e.finishes ? energyText(r.energyMWh) : "—")
        }
    }

    private func warningsCard(_ r: TrainingExperience.Review) -> some View {
        Card {
            CardHeader(r.warnings.isEmpty ? "Ready to launch" : "Before you launch", symbol: r.warnings.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                       subtitle: r.warnings.isEmpty ? "No problems found with this plan." : "Each issue comes with what would fix it.")
            WarningList(warnings: r.warnings) { apply($0) }
        }
    }

    private func forecastCard(_ r: TrainingExperience.Review, _ s: GameState, _ d: Derived) -> some View {
        let top = d.board.filter { $0.released && !$0.isPlayer }.map(\.index).max() ?? 0
        let mine = d.board.filter(\.isPlayer).map(\.index).max()
        let sigma = r.est.forecast.sigma
        return Card {
            CardHeader(title: "Forecast", symbol: "sparkles", subtitle: r.known ? "Scaling-law prediction · 80% interval" : "No scaling laws yet") {
                if r.known { Pill(text: r.tier, color: tierColor(r.tier)) }
            }
            if !r.known {
                // Without scaling laws nobody can say in advance how good a run will be: the first checkpoint evals will.
                Label("Your lab can't predict this model's quality yet. Research Neural Scaling Laws for real forecasts; until then you'll find out at the first eval checkpoints.",
                      systemImage: "questionmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Fmt.score(r.mean)).font(TypeRamp.display)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Intelligence Index · \(Fmt.score(r.low))–\(Fmt.score(r.high))").foregroundStyle(.secondary)
                    Text("Comparable to \(r.comparable)").font(.caption.weight(.semibold))
                    Text("±\(Fmt.trim(sigma, 2)) (×\(Fmt.trim(pow(10, sigma), 2)) effective compute)").font(.caption).foregroundStyle(.secondary)
                }
            }
            BandStrip(low: r.low, mean: r.mean, high: r.high, top: top, mine: mine).frame(height: 34)
            Text("Expected capability domains").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            DomainGrid(scores: r.domains, compare: s.labDomains["player"], columns: 3)
            }
        }
    }

    private func positionCard(_ r: TrainingExperience.Review) -> some View {
        Card {
            CardHeader("Competitive position", symbol: "flag.checkered")
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(r.known ? "#\(r.rankNow)" : "?").font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(r.known && r.rankNow == 1 ? .yellow : .primary)
                    Text("if it shipped today").font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(r.finish == nil ? "—" : (r.known ? "#\(r.rankAtFinish)" : "?")).font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(r.rankAtFinish == 1 ? .yellow : (r.rankAtFinish > r.rankNow ? .orange : .primary))
                    Text("when it finishes (Rival Watch)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(r.servingPerM.map { Fmt.price($0) } ?? "—").font(.title3.weight(.semibold).monospacedDigit())
                    Text("to serve 1M tokens").font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !r.known {
                Text("Without scaling laws there's no forecast to rank.").font(.caption).foregroundStyle(.secondary)
            } else if r.rivalsAhead.isEmpty {
                Text(r.finish == nil ? "It never finishes as planned." : "No rival release the Rival Watch expects before then beats its forecast.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(r.rivalsAhead.prefix(4).enumerated()), id: \.offset) { _, a in
                    HStack {
                        Image(systemName: "binoculars.fill").font(.caption2).foregroundStyle(.orange)
                        Text("\(a.lab) \(a.model)").font(.caption.weight(.semibold))
                        Spacer()
                        Text("≈ \(Fmt.score(a.index)) · ~\(a.date.gameShort)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func breakdownCard(_ r: TrainingExperience.Review) -> some View {
        Card {
            CardHeader("Where the compute goes", symbol: "chart.bar.xaxis", subtitle: "Expected split of the cluster's peak FLOPs")
            ComputeBar(slices: r.slices).equatable()
            if let bn = r.bottleneck { BottleneckCard(bottleneck: bn) { apply($0) } }
        }
    }

    @ViewBuilder
    private func risksCard(_ r: TrainingExperience.Review) -> some View {
        Card {
            CardHeader("Risks", symbol: "exclamationmark.shield")
            SpecRow(label: "Hardware faults expected", value: Fmt.count(r.expectedFailures))
            if r.est.toy {
                Label("Experiment-sized: no mid-run incidents.", systemImage: "checkmark.shield").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(r.risks, id: \.self) { risk in
                Label(risk, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func footer(_ r: TrainingExperience.Review) -> some View {
        let blocked = r.warnings.contains { $0.level == .block }
        let ladderOK = store.derived.bonuses.has(.proxyLadder) && design.mode == .scratch && !r.est.forecast.ladderCovered && r.est.finishes
        return HStack(spacing: 10) {
            Toggle("Launch sequence for major runs", isOn: Binding(get: { store.showLaunchSequence }, set: { store.showLaunchSequence = $0 }))
                .toggleStyle(.checkbox)
                .font(.caption)
            Spacer()
            if ladderOK {
                Button {
                    dismiss()
                    ladder()
                } label: {
                    Label("Scaling ladder first", systemImage: "chart.line.uptrend.xyaxis")
                }
                .help("Five proxy runs at up to 2% of this compute: a tighter forecast, tuned hyperparameters and most bugs caught.")
            }
            Button("Back to the Lab") { dismiss() }.keyboardShortcut(.cancelAction)
            Button {
                dismiss()
                launch()
            } label: {
                Label("Launch \(design.name)", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(blocked)
        }
        .padding(14)
    }

    // MARK: Helpers

    private func apply(_ action: TrainingExperience.FixAction) {
        switch action {
        case .designCheckpoint(let v): interval = v
        case .designLR(let v): lr = v
        case .ladder:
            dismiss()
            ladder()
        case .open(let screen):
            dismiss()
            store.open(screen)
        case .designChips, .designTokens, .designParams, .reshape:
            var d = design
            let note = TrainingExperience.applyDesignFix(action, to: &d, state: store.game)
            design = d
            store.show(note ?? "Plan updated")
        case .resizeRun, .runCheckpoint, .runLR, .assignOps:
            break
        }
    }
}

func scaleColor(_ s: TrainingExperience.RunScale) -> Color {
    switch s {
    case .experiment: .secondary
    case .standard: .blue
    case .major: .orange
    case .frontier: .pink
    }
}

/// Facility power: kW below a megawatt.
func powerText(_ mw: Double) -> String {
    mw >= 1 ? "\(Fmt.trim(mw, mw < 10 ? 1 : 0)) MW" : "\(Fmt.trim(mw * 1000, mw * 1000 < 10 ? 1 : 0)) kW"
}

/// Energy in the largest sensible unit.
func energyText(_ mwh: Double) -> String {
    if mwh >= 1_000_000 { return "\(Fmt.trim(mwh / 1_000_000, 2)) TWh" }
    if mwh >= 1_000 { return "\(Fmt.trim(mwh / 1_000, 1)) GWh" }
    if mwh >= 1 { return "\(Fmt.trim(mwh, mwh < 10 ? 1 : 0)) MWh" }
    return "\(Fmt.trim(mwh * 1000, 0)) kWh"
}

// MARK: - Warnings and fixes

struct WarningList: View {
    let warnings: [TrainingExperience.Warning]
    let perform: (TrainingExperience.FixAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(warnings) { w in
                let tint: Color = w.level == .block ? .red : (w.level == .warn ? .orange : .blue)
                VStack(alignment: .leading, spacing: 5) {
                    Label(w.title, systemImage: w.level == .block ? "xmark.octagon.fill" : (w.level == .warn ? "exclamationmark.triangle.fill" : "info.circle.fill"))
                        .font(.callout.weight(.semibold)).foregroundStyle(tint)
                    Text(w.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !w.fixes.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(w.fixes) { f in
                                Button(f.label) { perform(f.action) }.controlSize(.small)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.07), in: .rect(cornerRadius: 10))
            }
        }
    }
}

/// What limits a run most and what would fix it.
struct BottleneckCard: View {
    let bottleneck: TrainingExperience.Bottleneck
    let perform: (TrainingExperience.FixAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Bottleneck: \(bottleneck.headline.prefix(1).lowercased() + bottleneck.headline.dropFirst())", systemImage: "scope")
                .font(.callout.weight(.semibold))
                .foregroundStyle(ComputeBar.color(bottleneck.kind))
            Text(bottleneck.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !bottleneck.fixes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(bottleneck.fixes) { f in
                        Button(f.label) { perform(f.action) }.controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ComputeBar.color(bottleneck.kind).opacity(0.08), in: .rect(cornerRadius: 10))
    }
}

// MARK: - Compute breakdown

/// A stacked bar of where peak compute goes, with a legend. Cheap: a handful of rectangles.
struct ComputeBar: View, Equatable {
    let slices: [TrainingExperience.Slice]
    var compact = false

    static func color(_ k: TrainingExperience.Slice.Kind) -> Color {
        switch k {
        case .useful: .green
        case .kernel: .gray
        case .comm: .blue
        case .checkpoint: .teal
        case .stragglers: .yellow
        case .failures: .red
        case .incidents: .orange
        case .rewound: .purple
        }
    }

    var body: some View {
        let shown = slices.filter { $0.share > 0.0005 }
        let total = max(shown.reduce(0) { $0 + $1.share }, 1e-9)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                HStack(spacing: 1) {
                    ForEach(shown) { sl in
                        Rectangle().fill(Self.color(sl.kind).gradient)
                            .frame(width: max(1, g.size.width * CGFloat(sl.share / total)))
                            .help("\(sl.label): \(Fmt.pct(sl.share, decimals: 1)) — \(sl.about)")
                    }
                }
                .clipShape(.rect(cornerRadius: 5))
            }
            .frame(height: compact ? 10 : 16)
            if !compact {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 3) {
                    ForEach(shown) { sl in
                        HStack(spacing: 5) {
                            Circle().fill(Self.color(sl.kind)).frame(width: 7, height: 7)
                            Text(sl.label).font(.caption2).lineLimit(1)
                            Spacer(minLength: 2)
                            Text(Fmt.pct(sl.share, decimals: 1)).font(.caption2.monospacedDigit().weight(.semibold))
                        }
                        .help(sl.about)
                    }
                }
            }
        }
    }
}

// MARK: - Architecture diagram

/// The design drawn as a stack: modalities in, embedding, the repeated block (attention + dense FFN or the expert pool
/// with its active experts lit), context, and the output head. Everything shown comes from the design; layer widths
/// are the usual proportions for its size (expand Technical details for the numbers).
struct ArchitectureDiagram: View {
    let design: ModelDesign
    let state: GameState
    var compact = false
    @State private var details = false

    var body: some View {
        let a = TrainingExperience.sketch(design, state: state)
        Card {
            CardHeader(title: "Architecture", symbol: "square.stack.3d.up", subtitle: subtitle(a)) {
                Pill(text: Fmt.params(design.paramsB) + (design.isMoE ? " · \(Fmt.params(design.activeParamsB)) active" : ""), color: .indigo)
            }
            HStack(alignment: .center, spacing: 14) {
                inputs(a)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                block(a)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                VStack(spacing: 6) {
                    node("Output head", symbol: "text.cursor", tint: .gray)
                    if design.mtp { node("+ draft heads", symbol: "forward.fill", tint: .teal) }
                }
                .frame(width: 104)
            }
            contextBar(a)
            DisclosureGroup("Technical details", isExpanded: $details) {
                VStack(alignment: .leading, spacing: 3) {
                    SpecRow(label: "Layers", value: a.ssmLayers > 0 ? "\(a.layers) (\(a.attentionLayers) attention, \(a.ssmLayers) state-space)" : "\(a.layers)")
                    SpecRow(label: "Model width", value: Fmt.int(a.dModel))
                    SpecRow(label: "Attention", value: attentionLine(a))
                    SpecRow(label: design.isMoE ? "Expert FFN width" : "FFN width", value: Fmt.int(a.ffn))
                    if design.isMoE { SpecRow(label: "Experts", value: "\(a.experts), \(a.activeExperts) active per token") }
                    SpecRow(label: "Weights (BF16)", value: Fmt.memory(a.weightsGB))
                    SpecRow(label: "KV cache, one full context", value: Fmt.memory(a.kvCacheGB))
                    SpecRow(label: "Precision (training)", value: design.precision.short)
                    Text(a.routing).font(.caption).foregroundStyle(.secondary)
                    Text(a.attentionNote).font(.caption).foregroundStyle(.secondary)
                    Text(a.mixerNote).font(.caption).foregroundStyle(.secondary)
                    Text("Depth and width follow the usual proportions for this parameter count; the simulation uses the parameters, sparsity, attention, mixer, context and modalities.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
            .font(.callout)
        }
    }

    private func subtitle(_ a: TrainingExperience.ArchSketch) -> String {
        let kind = design.mixer == .transformer ? (design.isMoE ? "Mixture-of-Experts transformer" : "Dense transformer") : design.mixer.rawValue
        return "\(kind) · \(a.layers) layers · \(design.attention.rawValue) attention"
    }

    private func attentionLine(_ a: TrainingExperience.ArchSketch) -> String {
        switch design.attention {
        case .mha: "\(a.heads) heads, multi-head"
        case .gqa: "\(a.heads) query heads, \(a.kvHeads) key/value heads"
        case .mla: "\(a.heads) heads, \(a.latent)-wide latent KV"
        }
    }

    private func inputs(_ a: TrainingExperience.ArchSketch) -> some View {
        VStack(spacing: 6) {
            ForEach(a.modalities, id: \.self) { m in
                node(m, symbol: m == "Text" ? "text.alignleft" : (m == "Vision" ? "eye.fill" : (m == "Voice" ? "waveform" : "film")), tint: m == "Text" ? .blue : .orange)
            }
            node("Embedding", symbol: "square.grid.2x2", tint: .gray)
        }
        .frame(width: 104)
    }

    private func node(_ title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(tint.opacity(0.35)))
    }

    private func block(_ a: TrainingExperience.ArchSketch) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: "× \(a.layers)").font(.headline.monospacedDigit())
                Text("repeated blocks").font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            if a.ssmLayers > 0 {
                node("\(a.ssmLayers / max(1, a.attentionLayers))× state-space (Mamba) per attention layer", symbol: "waveform.path", tint: .cyan)
            }
            node(design.attention == .mla ? "Latent attention" : (design.attention == .gqa ? "Grouped-query attention" : "Multi-head attention"),
                 symbol: "eye", tint: .purple)
            if design.isMoE {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Router → top-\(a.activeExperts) of \(a.experts) experts").font(.caption2.weight(.semibold))
                    ExpertGrid(experts: a.experts, active: a.activeExperts)
                        .frame(height: a.experts > 64 ? 34 : 22)
                }
                .padding(7)
                .background(Color.teal.opacity(0.1), in: .rect(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.teal.opacity(0.35)))
            } else {
                node("Dense feed-forward", symbol: "rectangle.split.3x1", tint: .teal)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }

    private func contextBar(_ a: TrainingExperience.ArchSketch) -> some View {
        let frac = clamp(log10(Double(max(2, a.contextK))) / log10(1000), 0.1, 1)
        return HStack(spacing: 8) {
            Text("Context").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Meter(value: frac, tint: .indigo, height: 6)
            Text(a.contextK >= 1000 ? "1M tokens" : "\(a.contextK)K tokens").font(.caption2.monospacedDigit())
        }
    }
}

/// The expert pool as a grid of cells, the routed ones lit (up to 128 cells; bigger pools are drawn in groups).
struct ExpertGrid: View {
    let experts: Int
    let active: Int

    var body: some View {
        let cells = min(experts, 128)
        let lit = max(1, Int((Double(active) / Double(experts) * Double(cells)).rounded(.up)))
        Canvas { g, size in
            let rows = cells > 64 ? 4 : (cells > 16 ? 2 : 1)
            let cols = Int((Double(cells) / Double(rows)).rounded(.up))
            let w = size.width / CGFloat(cols), h = size.height / CGFloat(rows)
            // Spread the lit cells across the pool (routing picks different experts for every token).
            let step = max(1, cells / lit)
            for i in 0..<cells {
                let r = i / cols, c = i % cols
                let rect = CGRect(x: CGFloat(c) * w + 0.5, y: CGFloat(r) * h + 0.5, width: max(1, w - 1), height: max(1, h - 1))
                let on = i % step == step / 2 && i / step < lit
                g.fill(Path(roundedRect: rect, cornerRadius: min(w, h) * 0.25), with: .color(on ? Color.teal : Color.gray.opacity(0.25)))
            }
        }
        .accessibilityLabel("\(experts) experts, \(active) active per token")
    }
}
