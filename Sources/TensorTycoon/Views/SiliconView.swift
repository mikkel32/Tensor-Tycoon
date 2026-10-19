import SwiftUI

/// 3.9: Custom Silicon is the summary of your silicon: what your chip business is doing, what your chips cost per
/// PFLOP-day against merchant parts, every chip you own the design of, and any partner programme an older save still
/// has running. New chips are designed on the Semiconductors page (the old partner programmes are closed to new chips).
struct SiliconView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let unlocked = store.derived.bonuses.has(.customSilicon)
        Page(title: "Custom Silicon", subtitle: "Google has TPUs, Amazon has Trainium, Microsoft has Maia, Meta has MTIA. Your own accelerators are designed, made and sold on the Semiconductors page; this is where you see what they are worth to you.", screen: .silicon) {
            HeroBanner(image: "wafer", height: 160) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your own accelerator").font(.title.weight(.bold))
                    Text("Design team → node → tape-out → bring-up → wafers, packaging and HBM → your fleet and your customers.")
                        .font(.callout).opacity(0.9)
                }
            }
            if !unlocked {
                Card {
                    CardHeader("Locked", symbol: "lock.fill")
                    Text("Research **Custom Accelerator Design** to start a chip programme, then hire a design team on the Semiconductors page.")
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
                SiliconProgrammeCard(state: s)
            }
            if s.semi.designs.contains(where: { $0.inProduction || $0.phase == .retired }) { ComputeEconomicsCard(state: s) }
            let legacy = s.chipProjects.filter { !$0.done }
            if !legacy.isEmpty {
                Text("Partner programmes").font(.title3.weight(.semibold))
                Text("Started before partner programmes closed to new chips. They finish as planned and their chips stay yours at cost.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(legacy) { p in ChipProjectCard(project: p, state: s) }
            }
            if unlocked { SiliconTeamCard(state: s) }
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

/// Where your chip business stands, with the way in to it.
private struct SiliconProgrammeCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let inDesign = s.semi.designs.filter { $0.phase.rawValue < SemiPhase.production.rawValue }
        let making = s.semi.designs.filter(\.inProduction)
        Card {
            CardHeader(title: "Your chip programme", symbol: "cpu.fill",
                       subtitle: "Design teams, nodes and foundries, wafers, packaging and HBM, a compiler stack, production and sales: all on the Semiconductors page.") {
                Button("Semiconductors") { store.open(.semiconductors) }.buttonStyle(.borderedProminent)
            }
            if s.semi.isEmpty {
                NextStep("Hire a design team to start your first accelerator. A chip takes one to two years from architecture to qualified silicon, and a compiler team to run well.",
                         action: "Semiconductors", screen: .semiconductors)
            } else {
                EqualColumns(minWidth: 140, spacing: 10, maxColumns: 5) {
                    MetricTile(label: "Engineers", value: "\(s.semi.teams.reduce(0) { $0 + $1.engineers }) + \(s.semi.compilerEngineers) compiler", symbol: "person.3.fill")
                    MetricTile(label: "In design", value: "\(inDesign.count)", symbol: "pencil.and.ruler.fill")
                    MetricTile(label: "In production", value: "\(making.count)", symbol: "cpu")
                    MetricTile(label: "Software maturity", value: Fmt.pct(s.semi.software, decimals: 0), symbol: "chevron.left.forwardslash.chevron.right", tint: s.semi.software < 0.4 ? Theme.warning : .primary)
                    MetricTile(label: "Chips made", value: Fmt.count(s.semi.designs.reduce(0) { $0 + $1.made.reduce(0, +) }), symbol: "shippingbox.fill")
                }
                ForEach(inDesign.prefix(3)) { d in
                    HStack {
                        Text(d.name).font(.callout.weight(.semibold))
                        Pill(text: d.phase.title, color: SemiStyle.color(d.phase))
                        Text("gen \(d.generation) · \(SemiCatalog.node(d.node).short) · respin odds \(Fmt.pct(d.respinOdds, decimals: 0))").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Meter(value: 1 - d.phaseDaysLeft / max(1, d.phaseDays), tint: SemiStyle.color(d.phase)).frame(width: 140)
                    }
                }
            }
            Text("The partner programmes (a design house builds a chip only you can buy, at cost, with nothing to manufacture) are closed to new chips: an accelerator is now something you make — and can sell.")
                .font(.caption).foregroundStyle(.secondary)
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
                    if let a = HardwareCatalog.get(c.id) {
                        row("Training MFU", Fmt.pct(a.baseMFU, decimals: 1), Fmt.pct(ref.baseMFU, decimals: 1))
                        row("Scale-up", "\(a.scaleUp) chips", "\(ref.scaleUp) chips")
                    }
                    row(Semis.isSemiChip(c.id) ? "Server + silicon" : "Price", Fmt.money(c.unitCost + Semis.siliconCost(c.id, state)), ref.price.map { Fmt.money($0) } ?? "—")
                }
                if Semis.isSemiChip(c.id) {
                    Button("Take from stock on the Semiconductors page") { store.open(.semiconductors) }.buttonStyle(.borderedProminent)
                } else {
                    Button("Order in Hardware Store") { store.open(.hardware) }.buttonStyle(.borderedProminent)
                }
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
