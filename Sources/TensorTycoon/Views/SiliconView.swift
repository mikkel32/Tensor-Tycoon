import SwiftUI

struct SiliconView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let unlocked = store.derived.bonuses.has(.customSilicon)
        Page(title: "Custom Silicon", subtitle: "Google has TPUs, Amazon has Trainium, Microsoft has Maia, Meta has MTIA. Design your own accelerator — years of work, a nine-figure budget, and a chip nobody else can buy.") {
            HeroBanner(image: "wafer", height: 160) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your own accelerator").font(.title.weight(.bold))
                    Text("Architecture → RTL → tape-out → bring-up → volume. Roughly 15–20 months, sold to you at cost.")
                        .font(.callout).opacity(0.9)
                }
            }
            if !unlocked {
                Card {
                    CardHeader("Locked", symbol: "lock.fill")
                    Text("Research **Custom Accelerator Design** to start a silicon program, then hire chip designers in Team.")
                    HStack {
                        let queued = s.researchQueue.contains("custom_silicon")
                        Button(queued ? "Queued" : "Queue research") {
                            store.mutate { $0.queueResearch("custom_silicon") }
                            store.show("Queued Custom Accelerator Design")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(queued)
                        Button("Open Research") { store.open(.research) }
                    }
                }
            } else {
                let active = s.chipProjects.filter { !$0.done }
                if active.isEmpty {
                    NewChipProgram(state: s)
                } else {
                    ForEach(active) { p in ChipProjectCard(project: p, state: s) }
                }
                SiliconTeamCard(state: s)
            }
            if !s.customChips.isEmpty {
                Text("Your chips").font(.title3.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14, alignment: .top)], spacing: 14) {
                    ForEach(s.customChips.reversed()) { c in CustomChipCard(chip: c, state: s) }
                }
            }
            SupplyDealsCard(state: s)
        }
    }
}

private struct NewChipProgram: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var partner: ChipPartner = .broadcom
    @State private var focus: ChipFocus = .training
    @State private var budgetLog = 8.7  // log10 dollars

    var body: some View {
        let s = state
        let budget = pow(10, budgetLog)
        let draft = ChipProject(name: "", partner: partner, focus: focus, budget: budget, started: s.date, phaseDaysLeft: 0, generation: s.customChips.count + 1)
        let ref = Silicon.reference(s)
        let perf = clamp(0.6 + 0.15 * log10(max(budget, 1e7) / 1e8) + 0.08 * Silicon.designerFactor(s) + partner.quality + 0.07 * Double(draft.generation - 1), 0.45, 1.3)
        Card {
            CardHeader("Start a chip program", symbol: "plus.circle.fill", subtitle: "Generation \(draft.generation) · \(Silicon.process(s.year))")
            Text("Design partner").font(.callout.weight(.semibold))
            HStack(spacing: 10) {
                ForEach(ChipPartner.allCases) { p in
                    Button { partner = p } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.rawValue).font(.callout.weight(.semibold))
                            Text(p.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
                            HStack(spacing: 6) {
                                Pill(text: "Quality \(p.quality >= 0 ? "+" : "")\(Int(p.quality * 100))", color: p.quality > 0 ? .green : (p.quality < 0 ? .orange : .secondary))
                                Pill(text: "Cost ×\(Fmt.trim(p.costFactor, 2))", color: .secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(partner == p ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(partner == p ? Color.accentColor : .clear, lineWidth: 1.5))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Focus", selection: $focus) {
                        ForEach(ChipFocus.allCases) { f in Text(f.rawValue).tag(f) }
                    }
                    .pickerStyle(.segmented)
                    Text(focus == .training ? "Training chips: max BF16/FP8 throughput and a big scale-up domain." : "Inference chips: more memory per chip, better FP4, lower power, fast decode.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("Budget")
                        Slider(value: $budgetLog, in: 7.7...10.3)
                        Text(Fmt.money(budget)).font(.callout.monospacedDigit().weight(.semibold)).frame(width: 90, alignment: .trailing)
                    }
                    Text("Paid gradually over the program. Respins add 25% each. You need 10% up front.").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Expected result").font(.headline)
                    SpecRow(label: "Benchmark vs \(ref.name)", value: "~\(Int(perf * 100))%", estimated: true)
                    SpecRow(label: "Unit cost", value: "~\(Fmt.money((ref.price ?? 30_000) * 0.38 * partner.costFactor))", estimated: true)
                    SpecRow(label: "Time to volume", value: "~\(Int(Silicon.totalDays(draft, s) / 30)) months", estimated: true)
                    SpecRow(label: "Chip designers", value: "\(s.employees.filter { $0.role == .chipDesigner }.count)")
                    Button {
                        store.act("Chip program started") { $0.startChipProject(partner: partner, focus: focus, budget: budget) }
                    } label: {
                        Label("Kick off program", systemImage: "memorychip").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(12)
                .frame(width: 320)
                .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 12))
            }
        }
    }
}

private struct ChipProjectCard: View {
    @Environment(GameStore.self) private var store
    let project: ChipProject
    let state: GameState
    @State private var confirmCancel = false

    var body: some View {
        let p = project
        let s = state
        let speed = Silicon.speed(p, s)
        let phaseTotal = ChipProject.phaseDays[p.phase] * speed
        let phaseFrac = clamp(1 - p.phaseDaysLeft / max(1, phaseTotal), 0, 1)
        let remaining = p.phaseDaysLeft + ChipProject.phaseDays.dropFirst(p.phase + 1).reduce(0, +) * speed
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(p.name).font(.title2.weight(.bold))
                        Pill(text: p.focus.rawValue, color: .indigo)
                        Pill(text: p.partner.rawValue, color: .secondary)
                        if p.respins > 0 { Pill(text: "\(p.respins) respin\(p.respins == 1 ? "" : "s")", color: .orange, symbol: "arrow.uturn.backward") }
                    }
                    Text("Started \(p.started.gameShort) · ~\(Int(remaining / 30) + 1) months to go · \(Fmt.money(p.spent)) of \(Fmt.money(p.budget * (1 + 0.25 * Double(p.respins)))) spent")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel program", role: .destructive) { confirmCancel = true }
            }
            HStack(spacing: 4) {
                ForEach(Array(ChipProject.phases.enumerated()), id: \.offset) { i, name in
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule()
                            .fill(i < p.phase ? Color.green : (i == p.phase ? Color.accentColor : Color.secondary.opacity(0.2)))
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                if i == p.phase {
                                    GeometryReader { g in Capsule().fill(Color.accentColor).frame(width: g.size.width * phaseFrac) }
                                }
                            }
                            .opacity(i == p.phase ? 1 : 0.9)
                        HStack(spacing: 4) {
                            Image(systemName: i < p.phase ? "checkmark.circle.fill" : (i == p.phase ? "circle.dotted.circle" : "circle"))
                                .foregroundStyle(i < p.phase ? .green : (i == p.phase ? Color.accentColor : .secondary))
                            Text(name).font(.caption.weight(i == p.phase ? .semibold : .regular)).lineLimit(1)
                        }
                        Text("\(Int(ChipProject.phaseDays[i] * speed / 30)) mo").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(blurb(p.phase)).font(.caption).foregroundStyle(.secondary)
        }
        .confirmationDialog("Cancel \(p.name)? Money spent is gone.", isPresented: $confirmCancel) {
            Button("Cancel program", role: .destructive) { store.mutate { $0.cancelChipProject(p.id) } }
        }
    }

    private func blurb(_ phase: Int) -> String {
        switch phase {
        case 0: "Architects size systolic arrays, SRAM and HBM stacks against your model roadmap."
        case 1: "Writing RTL and running emulation — the longest phase. Chip designers speed it up."
        case 2: "Masks are made at the foundry. Expensive and nerve-wracking."
        case 3: "First silicon is back. If there's a bug, you'll need a respin."
        default: "Ramping production with packaging partners (CoWoS) and qualifying boards."
        }
    }
}

private struct SiliconTeamCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let designers = state.employees.filter { $0.role == .chipDesigner }
        let f = Silicon.designerFactor(state)
        Card {
            CardHeader("Silicon team", symbol: Role.chipDesigner.symbol, subtitle: "\(designers.count) chip designer\(designers.count == 1 ? "" : "s")")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Team strength").font(.caption.weight(.semibold))
                    Meter(value: f, tint: .indigo, height: 8)
                    Text("Up to 30% faster programs, better chips and fewer respins at full strength (~20 senior designers).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 20)
                Button("Hire in Team") { store.open(.team) }
            }
        }
    }
}

private struct CustomChipCard: View {
    @Environment(GameStore.self) private var store
    let chip: CustomChip
    let state: GameState

    var body: some View {
        let c = chip
        let ref = Silicon.reference(state)
        Card(padding: 0) {
            Photo(key: c.focus == .training ? "wafer" : "wafer_closeup")
                .frame(height: 110)
                .clipped()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(c.name).font(.title3.weight(.bold))
                    Spacer()
                    Pill(text: c.focus.rawValue, color: .indigo)
                }
                Text("\(c.process) · gen \(c.generation) · delivered \(c.available.gameMonth)").font(.caption).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                    GridRow {
                        Text("").font(.caption)
                        Text("Yours").font(.caption.weight(.semibold))
                        Text(ref.name).font(.caption.weight(.semibold)).lineLimit(1)
                    }
                    row("BF16", Fmt.tflops(c.bf16), Fmt.tflops(ref.bf16))
                    row("FP8", Fmt.tflops(c.fp8), Fmt.tflops(ref.fp8))
                    row("FP4", Fmt.tflops(c.fp4), ref.fp4 > 0 ? Fmt.tflops(ref.fp4) : "—")
                    row("Memory", "\(Int(c.memoryGB)) GB", "\(Int(ref.memoryGB)) GB")
                    row("Bandwidth", "\(Fmt.trim(c.bandwidthTBs, 1)) TB/s", "\(Fmt.trim(ref.bandwidthTBs, 1)) TB/s")
                    row("Power", "\(Int(c.tdpW)) W", "\(Int(ref.tdpW)) W")
                    row("Price", Fmt.money(c.unitCost), ref.price.map { Fmt.money($0) } ?? "—")
                }
                Button("Order in Hardware Store") { store.open(.hardware) }.buttonStyle(.borderedProminent)
            }
            .padding(14)
        }
    }

    private func row(_ k: String, _ a: String, _ b: String) -> some View {
        GridRow {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(a).font(.caption.monospacedDigit().weight(.semibold))
            Text(b).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

struct SupplyDealsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var vendor: Vendor = .nvidia
    @State private var annualLog = 7.7
    @State private var years = 3

    var body: some View {
        let s = state
        let annual = pow(10, annualLog)
        Card {
            CardHeader("Supply agreements", symbol: "signature", subtitle: "Take-or-pay contracts: commit to annual spend for a discount, 4× allocation and half the lead time")
            ForEach(s.supplyDeals) { d in
                HStack {
                    Text(d.vendor).font(.callout.weight(.semibold)).frame(width: 110, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Meter(value: d.spentThisYear / max(1, d.annualCommit), tint: d.spentThisYear >= d.annualCommit ? .green : .orange, height: 6)
                        Text("\(Fmt.money(d.spentThisYear)) of \(Fmt.money(d.annualCommit)) this contract year · settles \(d.nextSettlement.gameShort)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Pill(text: "−\(Fmt.pct(d.discount, decimals: 0))", color: .green)
                    Text("\(d.yearsLeft) yr left").font(.caption.monospacedDigit()).frame(width: 60, alignment: .trailing)
                }
            }
            Divider()
            HStack(spacing: 12) {
                Picker("Vendor", selection: $vendor) {
                    ForEach([Vendor.nvidia, .amd, .google, .aws, .intel, .cerebras, .groq]) { v in Text(v.rawValue).tag(v) }
                }
                .frame(width: 180)
                Slider(value: $annualLog, in: 7...10.5) { Text("Per year") }
                Text("\(Fmt.money(annual))/yr").font(.callout.monospacedDigit()).frame(width: 100, alignment: .trailing)
                Picker("Years", selection: $years) {
                    ForEach([1, 2, 3, 5], id: \.self) { Text("\($0)").tag($0) }
                }
                .frame(width: 110)
                Button("Sign") {
                    store.act("Agreement signed") { $0.signSupplyDeal(vendor: vendor, annual: annual, years: years) }
                }
                .buttonStyle(.borderedProminent)
            }
            Text("If you spend less than the commitment in a contract year, you pay 50% of the shortfall.").font(.caption).foregroundStyle(.tertiary)
        }
    }
}
