import Charts
import SwiftUI

struct RSIView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let b = store.derived.bonuses
        let unlocked = b.has(.autoResearch) || b.has(.rsi)
        Page(title: "Self-Improvement Lab", subtitle: "Let a model improve its own training, generation after generation. Checkpoints let you promote, roll back or audit — because alignment drifts when nobody's watching.", screen: .rsi) {
            HeroBanner(image: "supercomputer", height: 160) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recursive self-improvement").font(.title.weight(.bold))
                    Text(unlocked ? (b.has(.rsi) ? "Fully unlocked: capability runs and full autonomy." : "Research & efficiency runs unlocked. Research Recursive Self-Improvement for capability runs.")
                                  : "Locked — research Automated AI Research to open the lab.")
                        .font(.callout).opacity(0.9)
                }
            }
            if !unlocked {
                LockedRSI(state: s)
            } else {
                NewRSIRun(state: s)
                ForEach(s.rsiRuns.filter { $0.status != .halted }) { run in RSIRunCard(run: run) }
                let halted = s.rsiRuns.filter { $0.status == .halted }
                if !halted.isEmpty {
                    Text("Halted runs").font(.title3.weight(.semibold))
                    ForEach(halted) { run in RSIRunCard(run: run) }
                }
            }
        }
    }
}

private struct LockedRSI: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let chain = ["continual_learning", "world_models", "auto_research", "unified_arch", "rsi"]
        Card {
            CardHeader("The road to self-improvement", symbol: "map")
            ForEach(chain, id: \.self) { id in
                if let item = ResearchCatalog.byID[id] {
                    let done = state.researched.contains(id)
                    let cost = Sim.researchCost(item, year: state.year)
                    let progress = state.researchProgress[id] ?? 0
                    HStack {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.callout.weight(.semibold))
                            Text(item.effectSummary.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !done {
                            Text("\(Fmt.count(progress)) / \(Fmt.count(cost)) RP").font(.caption.monospacedDigit())
                        }
                    }
                }
            }
            HStack {
                Button("Queue the whole chain") {
                    store.mutate { s in for id in chain { s.queueResearch(id) } }
                    store.show("Queued the self-improvement research chain")
                }
                .buttonStyle(.borderedProminent)
                Button("Research page") { store.open(.research) }
                Text("Tip: put compute on research and hire researchers — the RP multiplier caps at ~90 H100s of research compute.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct NewRSIRun: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var baseID: UUID? = nil
    @State private var target: RSITarget = .research
    @State private var autonomy = 1
    @State private var oversight = 0.2
    @State private var checkpointEvery = 2
    @State private var accelID = ""
    @State private var chips = 0

    var body: some View {
        let s = state
        let d = store.derived
        let b = d.bonuses
        let models = s.models.filter { !$0.retired }.sorted { $0.c > $1.c }
        Card {
            CardHeader(title: "Start a run", symbol: "play.circle.fill") { HelpButton(term: .rsi) }
            if models.isEmpty {
                NextStep("Train a model first — self-improvement starts from one of your models.", action: "Open Model Lab", screen: .lab)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Base model", selection: $baseID) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(models) { m in Text("\(m.name) (index \(Fmt.score(d.entry(m.id)?.index ?? 0)))").tag(UUID?.some(m.id)) }
                        }
                        HStack(spacing: 8) {
                            ForEach(RSITarget.allCases) { t in
                                let locked = t == .capabilities && !b.has(.rsi)
                                Button { target = t } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: t.symbol).foregroundStyle(target == t ? Color.accentColor : .secondary)
                                            if locked { Image(systemName: "lock.fill").font(.caption2) }
                                        }
                                        Text(t.rawValue).font(.callout.weight(.semibold))
                                        Text(t.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(target == t ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(target == t ? Color.accentColor : .clear, lineWidth: 1.5))
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .disabled(locked)
                                .opacity(locked ? 0.5 : 1)
                            }
                        }
                        Picker("Autonomy", selection: $autonomy) {
                            ForEach(0..<3) { i in Text(RSIRun.autonomyNames[i]).tag(i).disabled(i == 2 && !b.has(.rsi)) }
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text("Oversight")
                            Slider(value: $oversight, in: 0...0.5, step: 0.05)
                            Text("\(Int(oversight * 100))% of compute").font(.callout.monospacedDigit()).frame(width: 120, alignment: .trailing)
                        }
                        Picker("Checkpoint every", selection: $checkpointEvery) {
                            Text("1 gen").tag(1)
                            Text("2 gens").tag(2)
                            Text("5 gens").tag(5)
                            Text("10 gens").tag(10)
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Picker("Hardware", selection: $accelID) {
                                Text("Choose…").tag("")
                                ForEach(d.pools) { p in Text("\(p.accel.name) — \(p.free) free").tag(p.accel.id) }
                            }
                            QuantityPicker(value: $chips, range: 1...max(1, d.free(accelID)))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    forecastPanel(s, b, models)
                        .frame(width: 330)
                }
            }
        }
        .onAppear {
            if baseID == nil { baseID = models.first?.id }
            if accelID.isEmpty, let p = d.pools.max(by: { Double($0.free) * $0.accel.bf16 < Double($1.free) * $1.accel.bf16 }) {
                accelID = p.accel.id
                chips = max(1, p.free)
            }
            if b.has(.rsi) { target = .capabilities }
        }
    }

    @ViewBuilder
    private func forecastPanel(_ s: GameState, _ b: ResearchBonuses, _ models: [AIModel]) -> some View {
        let c = models.first { $0.id == baseID }?.c ?? 0
        let f = RSI.forecast(target: target, autonomy: autonomy, oversight: oversight, accelID: accelID, chips: chips, c: c, s, b)
        VStack(alignment: .leading, spacing: 8) {
            Text("Forecast").font(.headline)
            SpecRow(label: "Effective compute", value: Fmt.tflops(f.effectivePF * 1000))
            SpecRow(label: "Generation time", value: Fmt.days(f.daysPerGeneration))
            if target == .research {
                SpecRow(label: "Research output", value: "\(Fmt.count(f.rpPerDay)) RP/day")
            } else if target == .architecture {
                SpecRow(label: "Alien insight", value: "\(Fmt.trim(f.insightPerDay, 1))/day")
                SpecRow(label: "Next discovery needs", value: "\(Fmt.count(max(0, Xeno.insightNeeded(s) - s.xenoInsight))) more")
            } else {
                SpecRow(label: "First-generation gain", value: "+\(Fmt.trim(f.firstGain, 3)) capability")
                SpecRow(label: "Gain ceiling (this compute)", value: "+\(Fmt.trim(f.maxGain, 2))")
            }
            SpecRow(label: "Alignment drift / gen", value: "−\(Fmt.trim(f.driftPerGeneration, 2))")
            SpecRow(label: "Monitor detection", value: Fmt.pct(f.detection, decimals: 0))
            if autonomy == 2 && oversight < 0.15 {
                Label("Full autonomy with little oversight is how containment incidents happen.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            Button {
                guard let id = baseID else { store.show("Pick a base model", error: true); return }
                store.act("Self-improvement started") {
                    $0.startRSI(baseModelID: id, target: target, autonomy: autonomy, oversight: oversight, checkpointEvery: checkpointEvery, accelID: accelID, chips: chips)
                }
            } label: {
                Label("Begin self-improvement", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(accelID.isEmpty || baseID == nil)
        }
        .padding(12)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

private struct RSIRunCard: View {
    @Environment(GameStore.self) private var store
    let run: RSIRun
    @State private var confirmHalt = false
    @State private var autonomy = 1
    @State private var oversight = 0.2
    @State private var every = 2
    @State private var chips = 1
    @State private var showLog = true

    var body: some View {
        let d = store.derived
        let p0 = profile(c: run.cStart)
        let pNow = profile(c: run.cMeasured)
        let idx0 = BenchmarkCatalog.index(p0, set: d.indexSet)
        let idxNow = BenchmarkCatalog.index(pNow, set: d.indexSet)
        let align = run.alignmentMeasured
        let alignColor: Color = align >= 70 ? .green : (align >= 45 ? .yellow : .red)
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: run.target.symbol).font(.title2).foregroundStyle(Color.accentColor)
                        Text(run.name).font(.title2.weight(.bold))
                        Pill(text: run.status.rawValue, color: run.status == .running ? .green : (run.status == .paused ? .orange : .secondary))
                        Pill(text: run.target.rawValue, color: .purple)
                        Pill(text: RSIRun.autonomyNames[run.autonomy], color: run.autonomy == 2 ? .red : .secondary)
                    }
                    Text("Generation \(run.generation) · \(Fmt.int(run.chips))× \(HardwareCatalog.get(run.accelID)?.name ?? "?") · oversight \(Int(run.oversight * 100))% · started \(run.started.gameShort)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    if run.status == .running {
                        Button("Pause", systemImage: "pause.fill") { store.act { $0.setRSIStatus(run.id, .paused) } }
                    } else if run.status == .paused {
                        Button("Resume", systemImage: "play.fill") { store.act { $0.setRSIStatus(run.id, .running) } }.buttonStyle(.borderedProminent)
                    }
                    if run.status != .halted {
                        Button("Deep audit", systemImage: "magnifyingglass") { store.act("Audit complete") { $0.auditRSI(run.id) } }
                            .help("Expensive but accurate alignment measurement; also catches eval gaming.")
                        Button("Halt…", systemImage: "stop.fill", role: .destructive) { confirmHalt = true }
                            .confirmationDialog("Halt \(run.name) for good?", isPresented: $confirmHalt, titleVisibility: .visible) {
                                Button("Halt the run", role: .destructive) { store.act { $0.setRSIStatus(run.id, .halted) } }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("A halted self-improvement run can't be resumed. Its checkpoints stay, and you can still promote them to models. Pause it instead if you only need its chips.")
                            }
                    }
                }
            }

            EqualColumns(minWidth: 120, spacing: 10, maxColumns: 5) {
                RSIStat(label: run.target == .research ? "Research generated" : (run.target == .architecture ? "Alien insight found" : "Capability gain (measured)"),
                        value: run.target == .research ? "\(Fmt.count(run.rpGenerated)) RP"
                            : (run.target == .architecture ? Fmt.count(run.rpGenerated) : "+\(Fmt.trim(run.cMeasured - run.cStart, 2))"),
                        symbol: run.target == .architecture ? "atom" : "arrow.up.right", tint: .blue)
                RSIStat(label: "Index (est.)", value: "\(Fmt.score(idx0)) → \(Fmt.score(idxNow))", symbol: "checklist", tint: .purple)
                RSIStat(label: "Alignment (last eval)", value: "\(Int(align))/100", symbol: "shield.lefthalf.filled", tint: alignColor)
                RSIStat(label: "Serving efficiency", value: "×\(Fmt.trim(run.efficiency, 2))", symbol: "gauge.with.dots.needle.100percent", tint: .teal)
                RSIStat(label: "Compute spent", value: Fmt.money(run.cost), symbol: "dollarsign.circle", tint: .green)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Generation \(run.generation + 1) in progress").font(.caption.weight(.semibold))
                    Spacer()
                    Text(Fmt.pct(run.genProgress, decimals: 0)).font(.caption.monospacedDigit())
                }
                Meter(value: run.genProgress, tint: .purple, height: 8)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Measured capability by checkpoint").font(.caption.weight(.semibold))
                    RSIChart(points: run.checkpoints.map { RSIChart.P(gen: $0.generation, value: $0.cMeasured - run.cStart) }, color: .blue, domain: nil)
                        .equatable()
                        .frame(height: 150)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alignment evals by checkpoint").font(.caption.weight(.semibold))
                    RSIChart(points: run.checkpoints.map { RSIChart.P(gen: $0.generation, value: $0.alignmentMeasured) }, color: .green, domain: 0...100)
                        .equatable()
                        .frame(height: 150)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Checkpoints", systemImage: "externaldrive.badge.checkmark").font(.headline)
                if run.checkpoints.isEmpty {
                    Text("The first checkpoint saves after \(run.checkpointEvery) generation\(run.checkpointEvery == 1 ? "" : "s").").font(.callout).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(run.checkpoints.reversed()) { cp in
                                RSICheckpointCard(cp: cp, run: run, index: BenchmarkCatalog.index(profile(c: cp.cMeasured), set: d.indexSet))
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }

            if run.status != .halted {
                HStack(spacing: 14) {
                    Picker("Autonomy", selection: $autonomy) {
                        ForEach(0..<3) { i in Text(RSIRun.autonomyNames[i]).tag(i) }
                    }
                    .frame(width: 260)
                    HStack {
                        Text("Oversight")
                        Slider(value: $oversight, in: 0...0.5, step: 0.05).frame(width: 140)
                        Text("\(Int(oversight * 100))%").monospacedDigit()
                    }
                    Picker("Checkpoint", selection: $every) {
                        Text("1").tag(1); Text("2").tag(2); Text("5").tag(5); Text("10").tag(10)
                    }
                    .frame(width: 140)
                    QuantityPicker(value: $chips, range: 1...max(1, d.free(run.accelID) + run.chips))
                    Button("Apply") {
                        store.act("Run updated") { $0.tuneRSI(run.id, autonomy: autonomy, oversight: oversight, checkpointEvery: every, chips: chips) }
                    }
                }
            }
            DisclosureGroup("Run log", isExpanded: $showLog) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(run.log.prefix(12).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced()).foregroundStyle(line.contains("Incident") || line.contains("hacking") ? .orange : .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            autonomy = run.autonomy
            oversight = run.oversight
            every = run.checkpointEvery
            chips = run.chips
        }
    }

    private func profile(c: Double) -> ModelProfile {
        ModelProfile(key: "rsi-\(run.id.uuidString)-\(Int(c * 1000))", c: c, reasoning: run.reasoning, code: run.code, agent: run.agent,
                     vision: run.design.vision, contextK: run.design.contextK, tuning: 0)
    }
}

private struct RSIStat: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        MetricTile(label: label, value: value, symbol: symbol, tint: tint, style: .tinted)
    }
}

private struct RSICheckpointCard: View {
    @Environment(GameStore.self) private var store
    let cp: RSICheckpoint
    let run: RSIRun
    let index: Double

    var body: some View {
        let a = cp.alignmentMeasured
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("g\(cp.generation)").font(.title3.weight(.bold).monospacedDigit())
                Spacer()
                if cp.promotedModelID != nil { Pill(text: "Promoted", color: .green, symbol: "checkmark") }
            }
            Text("+\(Fmt.trim(cp.cMeasured - run.cStart, 2)) capability").font(.caption.weight(.semibold))
            Text("Index ≈ \(Fmt.score(index))").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("Alignment").font(.caption)
                AlignmentBadge(value: a)
            }
            Text(cp.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
            HStack(spacing: 6) {
                Button("Promote") { store.act("Promoted to a model") { $0.promoteCheckpoint(run.id, checkpoint: cp.id) } }
                    .disabled(cp.promotedModelID != nil)
                Button("Roll back") { store.act("Rolled back") { $0.rollbackRSI(run.id, checkpoint: cp.id) } }
                    .disabled(run.status == .halted)
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(width: 160, alignment: .leading)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

struct RSIChart: View, Equatable {
    struct P: Equatable { let gen: Int; let value: Double }
    let points: [P]
    let color: Color
    let domain: ClosedRange<Double>?

    var body: some View {
        if points.isEmpty {
            Text("No checkpoints yet").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let chart = Chart(Array(points.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Generation", p.gen), y: .value("Value", p.value))
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Generation", p.gen), y: .value("Value", p.value))
                    .foregroundStyle(color)
                    .symbolSize(20)
            }
            if let domain {
                chart.chartYScale(domain: domain)
            } else {
                chart
            }
        }
    }
}
