import SwiftUI

// MARK: - 3.5: Semiconductors — chip design, fabs and foundries, the supply chain and sales

enum SemiTab: String, CaseIterable, Identifiable {
    case design = "Design"
    case fabs = "Fabs & Foundries"
    case supply = "Supply chain"
    case sales = "Sales"
    var id: String { rawValue }
}

struct SemiconductorsView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: SemiTab = .design

    var body: some View {
        let s = store.game
        let last = s.semi.history.first
        let inDesign = s.semi.designs.filter { $0.phase.rawValue < SemiPhase.production.rawValue }.count
        let making = s.semi.designs.filter(\.inProduction).count
        Page(title: "Semiconductors",
             subtitle: "Design your own accelerators, tape them out at a process node, book wafers or build a fab, buy advanced packaging and HBM, and sell what you make — or keep it all for yourself.", screen: .semiconductors) {
            HeroBanner(image: "fab_cleanroom", height: 150) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your chip business").font(.title2.weight(.bold))
                    Text("\(s.semi.teams.reduce(0) { $0 + $1.engineers }) chip engineers · \(inDesign) design\(inDesign == 1 ? "" : "s") under way · \(making) in production · \(s.semi.fabs.count) fab\(s.semi.fabs.count == 1 ? "" : "s")")
                        .font(.callout)
                    PhotoPill(text: "Illustrative photo", symbol: "photo")
                }
            }
            KPIRow(minWidth: 190) {
                StatTile(title: "Chips last month", value: Fmt.count(last?.chips ?? 0),
                         detail: last.map { "from \(Fmt.count($0.wafers)) wafers" + ($0.bottleneck.isEmpty ? "" : " · limited by \($0.bottleneck)") } ?? "Nothing in production yet",
                         symbol: "cpu.fill", tint: .indigo)
                StatTile(title: "Sales last month", value: Fmt.money((last?.revenue ?? 0) + (last?.foundryRevenue ?? 0)),
                         detail: last.map { "\(Fmt.count($0.sold)) chips sold · costs \(Fmt.money($0.costs))" } ?? "Open a product for sale on the Sales tab",
                         symbol: "dollarsign.circle.fill", tint: .green)
                StatTile(title: "Supplier reputation", value: "\(Int(Semis.reputation(s) * 100))/100",
                         detail: "Chips shipped (\(Fmt.count(s.semi.shipped))) and software", symbol: "star.fill", tint: .orange)
                StatTile(title: "Software maturity", value: Fmt.pct(s.semi.software, decimals: 0),
                         detail: "Compiler, kernels, drivers · \(s.semi.compilerEngineers) engineers", symbol: "chevron.left.forwardslash.chevron.right", tint: .purple)
                StatTile(title: "Supply shocks", value: "\(Semis.activeShocks(s).count)",
                         detail: Semis.activeShocks(s).first?.title ?? "Packaging \(Semis.tightWords(Semis.tightness("pack", s.year))), HBM \(Semis.tightWords(Semis.tightness("hbm", s.year)))",
                         symbol: "exclamationmark.triangle.fill", tint: Semis.activeShocks(s).isEmpty ? .teal : .red)
            }
            SectionTabs(selection: $tab, options: SemiTab.allCases)
            switch tab {
            case .design: SemiDesignTab(state: s)
            case .fabs: SemiFabsTab(state: s)
            case .supply: SemiSupplyTab(state: s)
            case .sales: SemiSalesTab(state: s)
            }
        }
    }
}

// MARK: - Shared bits

enum SemiStyle {
    static func color(_ p: SemiPhase) -> Color {
        switch p {
        case .architecture, .rtl, .physical: .blue
        case .tapeout: .purple
        case .bringup: .orange
        case .production: .green
        case .retired: .secondary
        }
    }

    static func tone(_ t: Int) -> Color { t > 0 ? .green : (t < 0 ? .orange : .secondary) }
}

/// A caption that says where a number comes from.
private struct Why: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Label(text, systemImage: "function").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

private struct EventLine: View {
    let e: SemiEvent
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(e.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
            let tone: Tone = e.tone > 0 ? .good : (e.tone < 0 ? .warning : .neutral)
            Image(systemName: tone == .neutral ? "circle.fill" : tone.symbol)
                .font(.system(size: tone == .neutral ? 5 : 9))
                .foregroundStyle(tone == .neutral ? Color.secondary : tone.color)
                .accessibilityLabel(tone.word)
            Text(e.text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Design tab

private struct SemiDesignTab: View {
    let state: GameState

    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 16) {
            SemiTeamsCard(state: s)
            SoftwareStackCard(state: s)
            if !s.semi.teams.isEmpty { NewDesignCard(state: s) }
            ForEach(s.semi.designs.reversed()) { d in DesignCard(design: d, state: s) }
        }
    }
}

private struct SemiTeamsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var hire = 300

    var body: some View {
        let s = state
        let perEng = Semis.engineerCost(s.year)
        Card {
            CardHeader("Design teams", symbol: "person.3.fill",
                       subtitle: "Architects, verification and physical-design engineers. Bigger teams finish sooner (time ∝ 1/√size); every tape-out a team ships makes its next one safer and better.")
            if !s.bonuses.has(.customSilicon) {
                NextStep("Research Custom Accelerator Design to start a chip programme.", action: "Research", screen: .research)
            }
            ForEach(s.semi.teams) { t in
                HStack(spacing: 10) {
                    Image(systemName: "person.3.sequence.fill").foregroundStyle(.indigo).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.name).font(.callout.weight(.semibold))
                        let busy = Semis.teamBusy(s, t.id)
                        Text("\(t.engineers) engineers · \(t.experience) tape-out\(t.experience == 1 ? "" : "s") shipped · \(Fmt.money(Double(t.engineers) * perEng))/yr · \(busy.map { "designing \($0.name)" } ?? "free")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("−50") { store.act("Team resized") { $0.resizeChipTeam(t.id, engineers: t.engineers - 50) } }
                        .help("Lay off 50 (severance a quarter of a year's cost)")
                    Button("+50") { store.act("Team resized") { $0.resizeChipTeam(t.id, engineers: t.engineers + 50) } }
                        .help("Hire 50 (recruiting a quarter of a year's cost)")
                    Button("Disband") { store.act("Team disbanded") { $0.disbandChipTeam(t.id) } }
                }
            }
            HStack {
                Stepper("Hire a new team of \(hire) engineers", value: $hire, in: 50...2_000, step: 50)
                Spacer()
                Text("\(Fmt.money(Double(hire) * perEng))/yr + \(Fmt.money(Double(hire) * perEng * 0.25)) recruiting").font(.caption).foregroundStyle(.secondary)
                Button("Hire team") { store.act("Design team hired") { $0.hireChipTeam(engineers: hire) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!s.bonuses.has(.customSilicon))
            }
            Why("\(Fmt.money(perEng)) per engineer a year in \(Int(s.year)) (salary, equity, EDA seats and lab space).")
        }
    }
}

private struct NewDesignCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var node = ""
    @State private var die = "large"
    @State private var stacks = 6
    @State private var focus: ChipFocus = .training
    @State private var verification = 1
    @State private var teamID: UUID? = nil
    @State private var link: ChipLink = .switched
    @State private var portOf: UUID? = nil

    var body: some View {
        let s = state
        let nodes = Semis.designable(s)
        let nodeID = nodes.contains(where: { $0.id == node }) ? node : (nodes.last { $0.launch <= s.year }?.id ?? nodes.first?.id ?? "n7")
        let team = Semis.team(s, teamID) ?? s.semi.teams.first { Semis.teamBusy(s, $0.id) == nil } ?? s.semi.teams.first
        let parents = Semis.portable(s, focus: focus, node: nodeID)
        let parent = parents.first { $0.id == portOf }
        let isDerived = parent != nil
        let p = Semis.plan(node: nodeID, verification: verification, team: team, derived: isDerived, link: link, s)
        let gen = parent?.generation ?? Semis.nextGeneration(focus, s)
        let arch = Semis.archQuality(generation: gen, team: team, port: parent, node: nodeID, s)
        let sp = Semis.spec(node: nodeID, die: die, stacks: stacks, focus: focus, link: link, arch: arch.value, erratum: false,
                            year: s.year + p.designDays / 365, s)
        let probe = SemiDesign(name: "", generation: gen, node: nodeID, die: die, stacks: stacks, focus: focus, verification: verification, teamID: team?.id,
                               link: link.rawValue, started: s.date)
        let n = SemiCatalog.node(nodeID)
        let opensAt = SemiCatalog.foundries.map { Semis.opens(n, $0) }.min() ?? n.launch
        let fsw = SemiCatalog.foundryByID["fsw"]!
        let launchYield = Semis.previewYield(node: nodeID, die: die, foundry: fsw, s, at: s.year + p.months / 12)
        Card {
            CardHeader("New chip design", symbol: "pencil.and.ruler.fill",
                       subtitle: "Pick a process node, a die, memory and how hard to verify. The forecast updates as you choose.")
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Process node").font(.callout)
                    Picker("Node", selection: Binding(get: { nodeID }, set: { node = $0 })) {
                        ForEach(nodes) { nd in Text("\(nd.name) — opens \(Fmt.trim(nd.launch, 1))").tag(nd.id) }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Die").font(.callout)
                    Picker("Die", selection: $die) {
                        ForEach(SemiCatalog.dies.filter { $0.from <= s.year }) { d in Text(d.name).tag(d.id) }
                    }.labelsHidden()
                }
                GridRow {
                    Text("HBM stacks").font(.callout)
                    Picker("HBM", selection: $stacks) {
                        ForEach(SemiCatalog.stackChoices, id: \.self) { k in
                            Text("\(k) × \(Fmt.memory(Semis.stackGB(s.year))) = \(Fmt.memory(Double(k) * Semis.stackGB(s.year))), \(Fmt.trim(Double(k) * Semis.stackTBs(s.year), 1)) TB/s").tag(k)
                        }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Built for").font(.callout)
                    Picker("Focus", selection: $focus) { ForEach(ChipFocus.allCases) { f in Text(f.rawValue).tag(f) } }
                        .pickerStyle(.segmented).labelsHidden()
                }
                GridRow {
                    Text("Interconnect").font(.callout)
                    Picker("Interconnect", selection: $link) {
                        ForEach(ChipLink.allCases.filter { $0.from <= s.year }) { l in Text(l.title).tag(l) }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Verification").font(.callout)
                    Picker("Verification", selection: $verification) {
                        ForEach(0..<3, id: \.self) { v in Text("\(Semis.verificationName(v)) (time ×\(Fmt.trim(Semis.verificationTime[v], 2)), respin ×\(Fmt.trim(Semis.verificationRisk[v], 2)))").tag(v) }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Team").font(.callout)
                    Picker("Team", selection: Binding(get: { team?.id }, set: { teamID = $0 })) {
                        ForEach(s.semi.teams) { t in Text("\(t.name) — \(t.engineers) engineers\(Semis.teamBusy(s, t.id) != nil ? " (busy)" : "")").tag(Optional(t.id)) }
                    }.labelsHidden()
                }
                if !parents.isEmpty {
                    GridRow {
                        Text("Port").font(.callout)
                        Picker("Port", selection: $portOf) {
                            Text("New architecture (generation \(Semis.nextGeneration(focus, s)))").tag(UUID?.none)
                            ForEach(parents) { d in Text("Port \(d.name) — gen \(d.generation), architecture \(Fmt.trim(d.arch, 2))").tag(Optional(d.id)) }
                        }.labelsHidden()
                    }
                }
            }
            Text(SemiCatalog.die(die).blurb).font(.caption).foregroundStyle(.secondary)
            Text(linkNote(isDerived)).font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Forecast").font(.headline)
                    Text("About \(Int(p.months.rounded())) months to production · \(Fmt.money(p.total)) to get there").font(.callout)
                    Text("Team \(Fmt.money(p.teamCost)) · EDA & IP \(Fmt.money(p.ipCost)) · masks \(Fmt.money(p.maskCost))").font(.caption).foregroundStyle(.secondary)
                    Text("Respin odds at bring-up: \(Fmt.pct(p.respin, decimals: 0))").font(.callout.weight(.semibold)).foregroundStyle(p.respin > 0.35 ? .orange : .primary)
                    Text("Ultra bin ≈ \(Fmt.count(sp.bf16)) TFLOPS BF16 · \(Fmt.count(sp.fp4)) FP4 at \(Int(sp.tdpW)) W (\(Semis.perfLabel(sp.bf16, s)) today)").font(.callout)
                    Text("\(Fmt.memory(sp.memoryGB)) \(Semis.hbmGeneration(s.year + p.designDays / 365)) at \(Fmt.trim(sp.bandwidthTBs, 1)) TB/s · \(sp.scaleUp)-chip scale-up domains · trains at \(Fmt.pct(sp.trainFactor, decimals: 0)) of its peak's efficiency")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Packaging: \(Fmt.trim(Semis.slotsPerChip(probe), 2)) slots a chip · assembly yield \(Fmt.pct(Semis.assemblyYield(probe, s), decimals: 1))")
                        .font(.caption).foregroundStyle(stacks > 8 || link == .optical ? Theme.warning : .secondary)
                    Text("First-wafer yield ≈ \(Fmt.pct(launchYield.good, decimals: 0)) good dies (D0 \(Fmt.trim(launchYield.d0, 2))/cm², \(Int(launchYield.diesPerWafer)) dies a wafer)")
                        .font(.caption).foregroundStyle(.secondary)
                    if opensAt > s.year {
                        Text("No foundry offers \(n.short) yet: tape-out waits until \(Fmt.trim(opensAt, 1)).").font(.caption).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Button("Start design") {
                    store.act("Design started") { $0.startChipDesign(node: nodeID, die: die, stacks: stacks, focus: focus, verification: verification, teamID: team?.id, link: link, portOf: parent?.id) }
                }
                .buttonStyle(.borderedProminent)
            }
            Why("Time: \(p.timeWhy).")
            Why("Respin: \(p.respinWhy).")
            Why("Generation \(gen): one past your newest qualified \(focus.rawValue.lowercased()) chip (designs that never shipped don't count).")
            Why("Architecture \(Fmt.trim(arch.value, 2)): \(arch.why).")
            Why("Performance: \(sp.why). Fixed when it tapes out — a chip doesn't get faster by shipping later.")
        }
    }
}

extension NewDesignCard {
    /// The interconnect's trade-off, and what a port gives up.
    func linkNote(_ port: Bool) -> String {
        var t = link.blurb
        if port { t += " A port reuses its parent's architecture: 60% of the time, 0.7× the respin odds and 0.8× the masks, but no architecture step — the node does the work." }
        return t
    }
}

private struct DesignCard: View {
    @Environment(GameStore.self) private var store
    let design: SemiDesign
    let state: GameState
    @State private var showTimeline = false

    var body: some View {
        let d = design
        let s = state
        let n = SemiCatalog.node(d.node)
        let die = SemiCatalog.die(d.die)
        Card {
            CardHeader(title: d.name, symbol: "cpu",
                       subtitle: "Gen \(d.generation) · \(n.name) · \(die.name) · \(d.stacks) HBM stacks · \(Semis.link(d).short) · \(d.focus.rawValue.lowercased()) · \(Semis.verificationName(d.verification).lowercased()) verification\(d.derivedFrom.isEmpty ? "" : " · port of \(d.derivedFrom)")") {
                Pill(text: d.phase.title, color: SemiStyle.color(d.phase))
            }
            if d.phase.rawValue < SemiPhase.production.rawValue {
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        let done = i < d.phaseRaw
                        let cur = i == d.phaseRaw
                        VStack(alignment: .leading, spacing: 2) {
                            Meter(value: done ? 1 : (cur ? 1 - d.phaseDaysLeft / max(1, d.phaseDays) : 0), tint: SemiStyle.color(SemiPhase(rawValue: i) ?? .architecture))
                            Text(SemiPhase(rawValue: i)?.title ?? "").font(.caption2).foregroundStyle(cur ? .primary : .secondary).lineLimit(1)
                        }
                    }
                }
                Text(d.phase.detail).font(.caption).foregroundStyle(.secondary)
                if !d.waiting.isEmpty { Label(d.waiting, systemImage: "hourglass").font(.caption).foregroundStyle(.orange) }
                if d.bugOpen { Label("A bug decision is waiting in your inbox.", systemImage: "ladybug.fill").font(.caption).foregroundStyle(.red) }
                HStack {
                    Text("\(Int(max(0, d.phaseDaysLeft))) days left in this phase · spent \(Fmt.money(d.spent)) · respin odds \(Fmt.pct(d.respinOdds, decimals: 0))\(d.respins + d.metalFixes > 0 ? " · \(d.respins) respin\(d.respins == 1 ? "" : "s"), \(d.metalFixes) metal fix\(d.metalFixes == 1 ? "" : "es")" : "")")
                        .font(.caption.monospacedDigit())
                    Spacer()
                    Button("Cancel design") { store.act("Design cancelled") { $0.cancelChipDesign(d.id) } }
                }
            } else {
                ChipBinsTable(design: d, state: s)
                HStack {
                    Text(productLine(d)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if d.inProduction { Button("Retire") { store.act("Product retired") { $0.retireChipDesign(d.id) } } }
                }
            }
            DisclosureGroup("Timeline (\(d.timeline.count))", isExpanded: $showTimeline) {
                VStack(alignment: .leading, spacing: 3) { ForEach(Array(d.timeline.enumerated()), id: \.offset) { _, e in EventLine(e: e) } }
            }
            .font(.caption)
        }
    }
}

extension DesignCard {
    /// Architecture, money and the bring-up roll of a product, in a line.
    func productLine(_ d: SemiDesign) -> String {
        var t = "Arch \(Fmt.trim(d.arch, 2))"
        if d.erratum { t += " (shipped with an erratum)" }
        t += " · spent \(Fmt.money(d.spent)) to qualify · production cost so far \(Fmt.money(d.cost)) · revenue \(Fmt.money(d.revenue))"
        if d.lastRoll >= 0 && d.qualified != nil { t += " · bring-up roll \(Fmt.trim(d.lastRoll, 2)) against \(Fmt.pct(d.respinOdds, decimals: 0)) odds" }
        return t
    }
}

private struct ChipBinsTable: View {
    let design: SemiDesign
    let state: GameState

    var body: some View {
        let d = design
        let ref = Silicon.reference(state)
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
            GridRow {
                Text("Bin").font(.caption.weight(.semibold))
                Text("Performance").font(.caption.weight(.semibold))
                Text("Memory").font(.caption.weight(.semibold))
                Text("Power").font(.caption.weight(.semibold))
                Text("Made").font(.caption.weight(.semibold))
                Text("Your stock").font(.caption.weight(.semibold))
                Text("For sale").font(.caption.weight(.semibold))
            }
            ForEach(0..<3, id: \.self) { b in
                if d.chipIDs.indices.contains(b), let a = HardwareCatalog.get(d.chipIDs[b]) {
                    GridRow {
                        Text(SemiCatalog.binNames[b]).font(.caption)
                        Text("\(Fmt.count(a.bf16)) TF (\(Fmt.trim(a.bf16 / max(1, ref.bf16), 2))× \(ref.name))").font(.caption.monospacedDigit())
                        Text("\(Fmt.memory(a.memoryGB)) · \(Fmt.trim(a.bandwidthTBs, 1)) TB/s").font(.caption.monospacedDigit())
                        Text("\(Int(a.tdpW)) W").font(.caption.monospacedDigit())
                        Text(Fmt.count(d.made[b])).font(.caption.monospacedDigit())
                        Text(Fmt.count(d.stockMine[b])).font(.caption.monospacedDigit())
                        Text(Fmt.count(d.stockSale[b])).font(.caption.monospacedDigit())
                    }
                }
            }
        }
        Why("Bins: perfect dies that clock high are Ultra; slower perfect dies and dies with one defect in a spare block are Standard (0.88×); dies with blocks fused off are Lite (0.7×, three quarters of the HBM).")
        if let a = d.chipIDs.first.flatMap({ HardwareCatalog.get($0) }) {
            Why("Training MFU \(Fmt.pct(a.baseMFU, decimals: 1)) before your lab's bonuses (software maturity \(Fmt.pct(state.semi.software, decimals: 0))) · serving ×\(Fmt.trim(a.serveFactor, 2)) · \(a.interconnect), \(a.scaleUp)-chip domains at \(Fmt.count(a.interconnectGBs)) GB/s.")
        }
    }
}

// MARK: - Fabs & foundries tab

private struct SemiFabsTab: View {
    let state: GameState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FoundryBookingCard(state: state)
            BookingsCard(state: state)
            OwnFabCard(state: state)
        }
    }
}

private struct FoundryBookingCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var foundry = "fsw"
    @State private var node = ""
    @State private var wafers = 1_000.0
    @State private var months = 24
    @State private var delay = 0
    @State private var designID: UUID? = nil

    var body: some View {
        let s = state
        let f = SemiCatalog.foundryByID[foundry] ?? SemiCatalog.foundries[0]
        let offers = SemiCatalog.nodes.filter { Semis.offered($0, f, s.year) }
        let nodeID = offers.contains(where: { $0.id == node }) ? node : (offers.last?.id ?? "")
        let n = SemiCatalog.node(nodeID)
        let cap = Semis.waferCap(f, n, s)
        let booked = Semis.waferBooked(s, foundry: f.id, node: nodeID)
        let price = Semis.waferPrice(n, f, s.year) * (months >= 24 ? 0.92 : 1)
        let lead = Semis.leadDays(f.leadDays, "wafer", s)
        let candidates = s.semi.designs.filter { $0.node == nodeID && $0.phase != .retired }
        let target = candidates.first { $0.id == designID } ?? candidates.first
        Card {
            CardHeader("Book wafers at a foundry", symbol: "building.2.fill",
                       subtitle: "Take-or-pay: you pay for every wafer booked from its start date, used or not. Wafers that arrive before a design qualifies are wasted — time the start.")
            ForEach(SemiCatalog.foundries) { fd in
                let o = SemiCatalog.nodes.filter { Semis.offered($0, fd, s.year) }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fd.name).font(.callout.weight(.semibold))
                        Text("\(fd.place) · yields ×\(Fmt.trim(fd.d0Factor, 2)) defects · price ×\(Fmt.trim(fd.priceFactor, 2)) · quake risk \(Fmt.pct(fd.quake, decimals: 0))").font(.caption).foregroundStyle(.secondary)
                        Text(fd.blurb).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(o.isEmpty ? "No AI-class nodes yet" : o.map { "\($0.short) \(Fmt.money(Semis.waferPrice($0, fd, s.year)))" }.joined(separator: " · "))
                        .font(.caption.monospacedDigit()).multilineTextAlignment(.trailing)
                }
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Foundry").font(.callout)
                    Picker("Foundry", selection: $foundry) { ForEach(SemiCatalog.foundries) { fd in Text(fd.name).tag(fd.id) } }.labelsHidden()
                }
                GridRow {
                    Text("Node").font(.callout)
                    Picker("Node", selection: Binding(get: { nodeID }, set: { node = $0 })) { ForEach(offers) { nd in Text(nd.name).tag(nd.id) } }.labelsHidden()
                }
                GridRow {
                    Text("Wafers a month").font(.callout)
                    Stepper("\(Fmt.count(wafers)) (you can get \(Fmt.count(max(0, cap.value - booked))) more)", value: $wafers, in: 100...50_000, step: 100)
                }
                GridRow {
                    Text("Term").font(.callout)
                    Picker("Term", selection: $months) { Text("12 months").tag(12); Text("24 months (−8%)").tag(24) }.pickerStyle(.segmented).labelsHidden()
                }
                GridRow {
                    Text("Start").font(.callout)
                    Stepper(delay * 30 <= lead ? "As soon as possible (\(lead) days lead time)" : "In \(delay) months", value: $delay, in: 0...36)
                }
                GridRow {
                    Text("For").font(.callout)
                    Picker("Design", selection: Binding(get: { target?.id }, set: { designID = $0 })) {
                        Text("No product yet").tag(UUID?.none)
                        ForEach(candidates) { d in Text("\(d.name) (\(d.phase.title.lowercased()))").tag(Optional(d.id)) }
                    }.labelsHidden()
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Fmt.money(price)) a wafer · \(Fmt.money(price * wafers))/month · deposit \(Fmt.money(price * wafers))").font(.callout)
                    if let t = target {
                        let y = t.inProduction ? Semis.productYield(t, foundry: f, s) : Semis.previewYield(node: t.node, die: t.die, foundry: f, s)
                        let chips = wafers * y.diesPerWafer * y.good / Double(SemiCatalog.die(t.die).dies)
                        Text("≈ \(Fmt.count(chips)) \(t.name) chips a month at today's yield (\(Fmt.pct(y.good, decimals: 0)) good dies, \(Int(y.diesPerWafer)) a wafer)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let why = Semis.foundryBlocker(f, n, s) { Text(why).font(.caption).foregroundStyle(.red) }
                }
                Spacer()
                Button("Book wafers") {
                    store.act("Wafers booked") { $0.bookWafers(foundry: f.id, node: nodeID, wafersMonth: wafers, months: months, startDelayMonths: delay, designID: target?.id) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(nodeID.isEmpty)
            }
            if !nodeID.isEmpty { Why("Your allocation: \(cap.why) = \(Fmt.count(cap.value))/month (\(Fmt.count(booked)) already booked).") }
            Why("Price: \(n.short) launch price \(Fmt.money(n.waferPrice)) × \(f.name) \(Fmt.trim(f.priceFactor, 2)), cheaper as the node matures, +\(Fmt.pct(0.4 * Semis.tightness("wafer", s.year), decimals: 0)) while wafers are \(Semis.tightWords(Semis.tightness("wafer", s.year))).")
        }
    }
}

private struct BookingsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("Wafer bookings", symbol: "calendar", subtitle: "The one-month deposit comes back when a booking ends. Cancelling costs half of what's left of the commitment (less the deposit).")
            if s.semi.bookings.isEmpty {
                Text("No wafers booked.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(s.semi.bookings) { bk in
                let f = SemiCatalog.foundryByID[bk.foundry]
                let target = s.semi.designs.first { $0.id == bk.designID }
                let factor = Semis.waferFactor(s, foundry: bk.foundry)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Fmt.count(bk.wafersMonth)) \(SemiCatalog.node(bk.node).short) wafers/month at \(f?.name ?? bk.foundry)").font(.callout.weight(.semibold))
                        Text("\(bk.active(s.date) ? "Running" : "Starts \(bk.start.gameShort)") until \(bk.end.gameShort) · \(Fmt.money(bk.price)) a wafer = \(Fmt.money(bk.price * bk.wafersMonth))/month"
                             + (factor < 1 ? " · shock: \(Fmt.pct(factor, decimals: 0)) of capacity" : ""))
                            .font(.caption).foregroundStyle(factor < 1 ? .orange : .secondary)
                        if bk.active(s.date) && !(target?.inProduction ?? false) {
                            Text("These wafers go to no product in production — you're paying for nothing.").font(.caption).foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Menu(target?.name ?? "Assign…") {
                        Button("Nothing") { store.act { $0.assignBooking(bk.id, to: nil) } }
                        ForEach(s.semi.designs.filter { $0.node == bk.node && $0.phase != .retired }) { d in
                            Button(d.name) { store.act("Assigned to \(d.name)") { $0.assignBooking(bk.id, to: d.id) } }
                        }
                    }
                    .fixedSize()
                    Button("Cancel (\(Fmt.money(s.bookingCancelFee(bk))))") { store.act("Booking cancelled") { $0.cancelBooking(bk.id) } }
                }
            }
        }
    }
}

private struct OwnFabCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var site = "phoenix"
    @State private var node = ""
    @State private var size = 20_000.0

    var body: some View {
        let s = state
        let st = SemiCatalog.siteByID[site] ?? SemiCatalog.sites[0]
        let nodes = SemiCatalog.nodes.filter { $0.launch <= s.year && $0.launch >= s.year - 8 }
        let nodeID = nodes.contains(where: { $0.id == node }) ? node : (nodes.last?.id ?? "n7")
        let n = SemiCatalog.node(nodeID)
        let cost = Semis.fabCost(n, wafers: size) * Progression.fabFactor(s)   // 3.7
        let net = cost * (1 - st.subsidy)
        let days = Semis.fabBuildDays(st, wafers: size)
        let mw = Semis.fabMWFull(n, size)
        let powerMonth = mw * 1_000 * 24 * 30.4 * st.power * Power.gridMultiplier(s)
        let fixedMonth = cost * 0.003
        let perWafer = 0.22 * n.waferPrice
        Card {
            CardHeader("Your own fabs", symbol: "building.columns.fill",
                       subtitle: "Years to build and billions to pay — then wafers at a fraction of a foundry's price, no allocation fights, and spare capacity you can sell to other chipmakers.")
            ForEach(s.semi.fabs) { fab in FabRow(fab: fab, state: s) }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Site").font(.callout)
                    Picker("Site", selection: $site) { ForEach(SemiCatalog.sites) { x in Text("\(x.name) — \(Fmt.pct(x.subsidy, decimals: 0)) incentives").tag(x.id) } }.labelsHidden()
                }
                GridRow {
                    Text("Process").font(.callout)
                    Picker("Node", selection: Binding(get: { nodeID }, set: { node = $0 })) { ForEach(nodes) { nd in Text(nd.name).tag(nd.id) } }.labelsHidden()
                }
                GridRow {
                    Text("Size").font(.callout)
                    Picker("Size", selection: $size) { ForEach(SemiCatalog.fabSizes, id: \.self) { w in Text("\(Fmt.count(w)) wafers/month").tag(w) } }.pickerStyle(.segmented).labelsHidden()
                }
            }
            Text(st.blurb).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Fmt.money(cost)) to build (\(Fmt.money(net)) after incentives) · opens in about \(Fmt.trim(Double(days) / 365, 1)) years").font(.callout)
                    Text("15% up front (\(Fmt.money(net * 0.15))), the rest paid as it's built (≈ \(Fmt.money(net * 0.85 / max(1, Double(days) / 30.4)))/month)").font(.caption).foregroundStyle(.secondary)
                    Text("Needs \(Int(mw)) MW of power (\(Fmt.money(powerMonth))/month on the grid at $\(Fmt.trim(st.power * Power.gridMultiplier(s), 3))/kWh; a power deal can cut it) and \(Fmt.count(n.fabWater * size / 1_000)) m³ of water a day · water stress \(Fmt.pct(st.water, decimals: 0)) · quake risk \(Fmt.pct(st.quake, decimals: 0))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Running: \(Fmt.money(fixedMonth))/month staff & upkeep + \(Fmt.money(perWafer)) consumables a wafer (a foundry charges \(Fmt.money(Semis.waferPrice(n, SemiCatalog.foundryByID["fsw"]!, s.year))))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Break ground") { store.act("Fab construction started") { $0.buildFab(site: st.id, node: nodeID, wafersMonth: size) } }
                    .buttonStyle(.borderedProminent)
            }
            Why("Cost: $2B of site, cleanrooms and utilities + \(Fmt.money(n.fabPerWafer)) of tools per wafer-a-month of \(n.short) capacity. Build: (30 + 2 per 10k wafers) months × \(st.name) \(Fmt.trim(st.buildFactor, 2)).")
            Why("Yield ramp: a new fab starts at 3.5× the node's defect density and learns with every wafer (1 + 2.5·e^(−wafers/40k)); tools come online from 15% to 100% over the first year.")
        }
    }
}

private struct FabRow: View {
    @Environment(GameStore.self) private var store
    let fab: SemiFab
    let state: GameState

    var body: some View {
        let s = state
        let target = s.semi.designs.first { $0.id == fab.designID }
        let total = Double(max(1, GameCalendar.daysBetween(fab.started, fab.opens)))
        let done = Double(GameCalendar.daysBetween(fab.started, s.date))
        VStack(alignment: .leading, spacing: 4) {
            IllustrativeBanner(key: ImagePicker.pick(fab.open(s.date) ? .fab : .fabConstruction, seed: fab.name), height: 70)
            HStack {
                Text(fab.name).font(.callout.weight(.semibold))
                Pill(text: SemiCatalog.node(fab.node).short, color: .indigo)
                Spacer()
                if fab.open(s.date) {
                    Menu(target?.name ?? "Foundry services") {
                        Button("Sell the capacity (foundry services)") { store.act { $0.assignFab(fab.id, to: nil) } }
                        ForEach(s.semi.designs.filter { $0.node == fab.node && $0.phase != .retired }) { d in
                            Button(d.name) { store.act("\(fab.name) makes \(d.name)") { $0.assignFab(fab.id, to: d.id) } }
                        }
                    }
                    .fixedSize()
                }
            }
            if fab.open(s.date) {
                let ramp = Semis.fabRamp(fab, s)
                let fs = Semis.foundryServicePrice(fab, s)
                Text("Running at \(Fmt.pct(ramp, decimals: 0)) of \(Fmt.count(fab.wafersMonth)) wafers/month · defects ×\(Fmt.trim(Semis.fabD0Factor(fab), 2)) the node's best after \(Fmt.count(fab.wafersDone)) wafers · \(Int(Semis.fabMW(fab, s))) MW · \(Fmt.count(Semis.fabWater(fab, s))) m³ water/day")
                    .font(.caption).foregroundStyle(.secondary)
                if let target {
                    HStack {
                        Text("Wafers to \(target.name): \(Fmt.pct(fab.productShare, decimals: 0)) (\(Fmt.count(fab.wafersMonth * ramp * fab.productShare))/month)").font(.caption).frame(width: 260, alignment: .leading)
                        Slider(value: Binding(get: { fab.productShare }, set: { v in store.mutate { $0.setFabShare(fab.id, share: (v * 20).rounded() / 20) } }), in: 0...1)
                    }
                }
                if target == nil || fab.productShare < 1 {
                    Text("Selling \(target == nil ? "all its" : "the other") wafers to other chipmakers at \(Fmt.money(fs.price)) each (they take \(Fmt.pct(fs.fill, decimals: 0)) of what you offer).").font(.caption).foregroundStyle(.secondary)
                }
                if Semis.ownFabFactor(s, fab) < 1 { Text("A supply shock cuts output to \(Fmt.pct(Semis.ownFabFactor(s, fab), decimals: 0)).").font(.caption).foregroundStyle(.orange) }
                HStack {
                    Text(powerLine(fab, s)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Menu("Power deal") {
                        ForEach(PowerDeal.allCases.filter { $0.available(s) }) { deal in
                            Button(deal.rawValue) { store.act("\(fab.name): \(deal.rawValue.lowercased())") { $0.setFabPower(fab.id, deal: deal) } }
                        }
                    }
                    .fixedSize()
                }
            } else {
                Meter(value: done / total, tint: .orange)
                Text("Under construction: opens \(fab.opens.gameShort) · \(Fmt.money(fab.unpaid)) still to pay").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension FabRow {
    func powerLine(_ fab: SemiFab, _ s: GameState) -> String {
        let price = Semis.fabPowerPrice(fab, s)
        let month = Semis.fabMW(fab, s) * 1_000 * 24 * 30.4 * price
        return "Power: \(Semis.fabPowerDeal(fab).rawValue) at $\(Fmt.trim(price, 3))/kWh · \(Fmt.money(month))/month"
    }
}

// MARK: - Supply chain tab

private struct SemiSupplyTab: View {
    let state: GameState
    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 16) {
            ForEach(s.semi.designs.filter(\.inProduction)) { d in FlowCard(design: d, state: s) }
            WorldSupplyCard(state: s)
            SupplyContractsCard(state: s, kind: "pack")
            SupplyContractsCard(state: s, kind: "hbm")
        }
    }
}

private struct FlowCard: View {
    let design: SemiDesign
    let state: GameState

    var body: some View {
        let d = design
        let s = state
        let src = Semis.sources(d, s)
        let die = SemiCatalog.die(d.die)
        let wafers = src.reduce(0) { $0 + $1.wafersDay } * 30.4
        let dies = src.reduce(0) { $0 + $1.wafersDay * 30.4 * $1.yield.diesPerWafer * $1.yield.good }
        let chipsPossible = dies / Double(die.dies)
        let slots = Semis.packSlotsDay(s) * 30.4
        let hbm = Semis.hbmStacksDay(s) * 30.4
        let needSlots = chipsPossible * Semis.slotsPerChip(d)
        let needHBM = chipsPossible * Double(d.stacks)
        Card {
            CardHeader("\(d.name): from wafer to chip", symbol: "arrow.triangle.branch",
                       subtitle: "This month's pace. The slowest step sets your output; dies wait in the die bank, HBM waits in stock.")
            HStack(spacing: 10) {
                FlowStep(title: "Wafers", value: Fmt.count(wafers), detail: "\(src.count) source\(src.count == 1 ? "" : "s")", ok: wafers > 0)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                FlowStep(title: "Good dies", value: Fmt.count(dies), detail: "\(Fmt.count(chipsPossible)) chips' worth", ok: dies > 0)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                FlowStep(title: "Packaging", value: Fmt.count(slots), detail: "needs \(Fmt.count(needSlots)) slots", ok: slots >= needSlots)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                FlowStep(title: "HBM", value: Fmt.count(hbm), detail: "needs \(Fmt.count(needHBM)) stacks", ok: hbm + s.semi.hbmStock >= needHBM)
            }
            ForEach(Array(src.enumerated()), id: \.offset) { _, x in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(x.name): \(Fmt.count(x.wafersDay * 30.4)) wafers/month · \(Int(x.yield.diesPerWafer)) dies a wafer · \(Fmt.pct(x.yield.good, decimals: 0)) good (Ultra \(Fmt.pct(x.yield.bins[0], decimals: 0)), Standard \(Fmt.pct(x.yield.bins[1], decimals: 0)), Lite \(Fmt.pct(x.yield.bins[2], decimals: 0)), scrap \(Fmt.pct(x.yield.scrap, decimals: 0)))")
                        .font(.caption)
                    Why("\(x.yield.why). Defects per die λ = D0 × \(Int(die.area)) mm² = \(Fmt.trim(x.yield.lambda, 2)); a die is perfect with probability e^−λ = \(Fmt.pct(exp(-x.yield.lambda), decimals: 0)); \(Fmt.pct(x.yield.speed, decimals: 0)) of perfect dies hit Ultra clocks.")
                }
            }
            if src.isEmpty { Text("No wafers: book some at a foundry or assign a fab.").font(.caption).foregroundStyle(.orange) }
            Text(bankLine(d, s)).font(.caption).foregroundStyle(.secondary)
            if d.dieBank.reduce(0, +) > 1 {
                let days = Semis.dieBankDays(d, s)
                Why("The bank holds \(days.isFinite ? "\(Fmt.trim(days / 30.4, 1)) months" : "more than packaging takes") of packaging. Holding a die costs \(Fmt.pct(Semis.dieCarryMonthly, decimals: 1)) of its wafer cost a month and \(Fmt.pct(Semis.dieLossMonthly(d, s), decimals: 0)) age out a month\(Semis.superseded(d, s) ? " (a newer generation is out)" : ""). Surplus beyond two months of the packaging you run or have contracted \(s.semi.holdExcessDies ? "stays in the bank" : "goes to other packagers as known-good die at about \(Fmt.money(Semis.kgdPrice(d, s))) a die")\(d.kgdSold > 0 ? " — \(Fmt.count(d.kgdSold)) sold so far" : "").")
            }
            if let fsw = SemiCatalog.foundryByID["fsw"] {
                let uc = Semis.unitCost(d, foundry: fsw, s)
                Why("One good chip costs about \(Fmt.money(uc.total)) to make at \(fsw.name) today: wafer \(Fmt.money(uc.wafer)) + packaging \(Fmt.money(uc.pack)) + HBM \(Fmt.money(uc.hbm)) + test \(Fmt.money(uc.test)).")
            }
        }
    }
}

extension FlowCard {
    /// The die bank by bin, its target and write-offs, HBM in stock and assembly.
    func bankLine(_ d: SemiDesign, _ s: GameState) -> String {
        var bins: [String] = []
        for b in 0..<3 { bins.append("\(SemiCatalog.binNames[b]) \(Fmt.count(d.dieBank[b]))") }
        var t = "Die bank: " + bins.joined(separator: ", ")
        t += " dies (target \(Fmt.count(Semis.dieBankTarget(d, s))), \(Fmt.count(d.diesScrapped)) written off so far)"
        t += " · HBM in stock: \(Fmt.count(s.semi.hbmStock)) stacks"
        t += " · assembly yield \(Fmt.pct(Semis.assemblyYield(d, s), decimals: 1)) (\(Fmt.trim(Semis.slotsPerChip(d), 2)) slots a chip)"
        return t
    }
}

private struct FlowStep: View {
    let title: String
    let value: String
    let detail: String
    let ok: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(ok ? Color.primary : Color.orange)
            Text(detail).font(.caption2).foregroundStyle(ok ? Color.secondary : Color.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorldSupplyCard: View {
    let state: GameState
    var body: some View {
        let s = state
        Card {
            CardHeader("The world's supply", symbol: "globe.asia.australia.fill",
                       subtitle: "How scarce each input is this year. Tight markets mean smaller allocations, longer lead times and higher prices.")
            ForEach([("wafer", "Leading-edge wafers"), ("pack", "Advanced packaging"), ("hbm", "HBM memory")], id: \.0) { k, name in
                let t = Semis.tightness(k, s.year)
                HStack {
                    Text(name).font(.callout).frame(width: 170, alignment: .leading)
                    Meter(value: t, tint: t > 0.7 ? .red : (t > 0.45 ? .orange : .green))
                    Text(Semis.tightWords(t)).font(.caption).frame(width: 70, alignment: .trailing)
                }
            }
            Why("The early-2020s chip shortage hit wafers; the AI boom made advanced packaging the bottleneck in 2023–24 and HBM in 2024–26. Prices carry a premium of up to 40–60% at the tightest.")
            let shocks = s.semi.shocks.sorted { $0.start > $1.start }
            if shocks.isEmpty {
                Text("No supply shocks so far.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(shocks.prefix(6)) { sh in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(sh.title).font(.callout.weight(.semibold))
                        Pill(text: sh.active(s.date) ? "Until \(sh.end.gameShort)" : "Over", color: sh.active(s.date) ? .red : .secondary)
                        if sh.mitigated { Pill(text: "Re-routed", color: .teal) }
                    }
                    Text(sh.body).font(.caption).foregroundStyle(.secondary)
                    Text(shockEffects(sh)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func shockEffects(_ sh: SupplyShock) -> String {
        var parts: [String] = []
        let who = sh.foundry.isEmpty ? "all foundries" : (SemiCatalog.foundryByID[sh.foundry]?.name ?? sh.foundry)
        if sh.wafers < 1 { parts.append("wafers at \(who) \(Fmt.pct(sh.wafers, decimals: 0))") }
        if sh.packaging < 1 { parts.append("packaging \(Fmt.pct(sh.packaging, decimals: 0))") }
        if sh.hbm < 1 { parts.append("HBM \(Fmt.pct(sh.hbm, decimals: 0))") }
        if sh.drought < 1 { parts.append("fabs at water-stressed sites \(Fmt.pct(sh.drought, decimals: 0))") }
        if sh.export { parts.append("no sales to China, Gulf demand halved, Chinese foundries frozen") }
        return "Capacity left: " + parts.joined(separator: " · ") + (sh.mitigated ? " (half recovered by re-routing)" : "")
    }
}

private struct SupplyContractsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let kind: String
    @State private var supplier = ""
    @State private var units = 10_000.0
    @State private var months = 24
    @State private var lineSize = 10_000.0

    var body: some View {
        let s = state
        let pack = kind == "pack"
        let sups = SemiCatalog.suppliers.filter { $0.kind == kind && $0.from <= s.year }
        let sup = sups.first { $0.id == supplier } ?? sups.first
        let mine = s.semi.supply.filter { $0.kind == kind }
        let unit = pack ? "slots" : "stacks"
        Card {
            CardHeader(pack ? "Advanced packaging" : "HBM memory", symbol: pack ? "square.stack.3d.up.fill" : "memorychip.fill",
                       subtitle: pack ? "Every chip sits on a silicon interposer next to its HBM (the CoWoS-class step). Chiplet designs use more of a slot."
                                      : "Every chip needs its HBM stacks (Lite parts use three quarters). Stacks you don't use wait in stock.")
            ForEach(mine) { c in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(c.own ? "Your own line" : (SemiCatalog.supplierByID[c.supplier]?.name ?? c.supplier)): \(Fmt.count(c.units)) \(unit)/month").font(.callout.weight(.semibold))
                        Text(c.own ? (c.start > s.date ? "Being built: opens \(c.start.gameShort), \(Fmt.money(c.unpaid)) still to pay" : "Running at \(Fmt.pct(Semis.ownLineRamp(c, s), decimals: 0)) · \(Fmt.money(c.price)) a slot to run")
                             : "\(c.active(s.date) ? "Running" : "Starts \(c.start.gameShort)") until \(c.end.gameShort) · \(Fmt.money(c.price)) each = \(Fmt.money(c.price * c.units))/month")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !c.own { Button("Cancel") { store.act("Contract cancelled") { $0.cancelSupply(c.id) } }.help("Costs half of what's left of the commitment") }
                }
            }
            if let sup {
                let cap = Semis.supplyCap(sup, s) - Semis.supplyBooked(s, supplier: sup.id)
                let price = Semis.supplyPrice(sup, s) * (months >= 24 ? 0.92 : 1)
                Divider()
                HStack {
                    Picker("Supplier", selection: Binding(get: { sup.id }, set: { supplier = $0 })) { ForEach(sups) { x in Text(x.name).tag(x.id) } }.labelsHidden().fixedSize()
                    Stepper("\(Fmt.count(units)) \(unit)/month", value: $units, in: 100...500_000, step: pack ? 1_000 : 5_000)
                    Picker("Term", selection: $months) { Text("12 mo").tag(12); Text("24 mo").tag(24) }.pickerStyle(.segmented).labelsHidden().frame(width: 130)
                    Spacer()
                    Button("Sign") { store.act("Contract signed") { $0.signSupply(supplier: sup.id, units: units, months: months) } }.buttonStyle(.borderedProminent)
                }
                Text("\(sup.blurb) \(Fmt.money(price)) each → \(Fmt.money(price * units))/month · up to \(Fmt.count(max(0, cap))) more a month · \(Semis.leadDays(sup.leadDays, kind, s)) days lead · \(pack ? "assembly" : "stack") yield \(Fmt.pct(sup.yield, decimals: 0))")
                    .font(.caption).foregroundStyle(.secondary)
                Why(pack ? "Price: \(Fmt.money(Semis.packPrice(s.year))) a slot in \(Int(s.year)) × \(sup.name) \(Fmt.trim(sup.priceFactor, 2)) × shortage premium \(Fmt.trim(1 + 0.6 * Semis.tightness(kind, s.year), 2))."
                         : "Price: \(Fmt.memory(Semis.stackGB(s.year))) \(Semis.hbmGeneration(s.year)) stack × \(Fmt.money(Semis.hbmPerGB(s.year)))/GB × \(sup.name) \(Fmt.trim(sup.priceFactor, 2)) × shortage premium \(Fmt.trim(1 + 0.6 * Semis.tightness(kind, s.year), 2)).")
            }
            if pack {
                Divider()
                HStack {
                    Text("Build your own packaging line").font(.callout)
                    Picker("Size", selection: $lineSize) { ForEach(SemiCatalog.packLineSizes, id: \.self) { x in Text("\(Fmt.count(x))/mo").tag(x) } }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
                    Spacer()
                    Text("\(Fmt.money(1e9 + lineSize * 80_000)) · 15 months · then $300 a slot").font(.caption).foregroundStyle(.secondary)
                    Button("Build line") { store.act("Packaging line under construction") { $0.buildPackagingLine(slots: lineSize) } }
                }
            }
        }
    }
}

// MARK: - Sales tab

private struct SemiSalesTab: View {
    let state: GameState
    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 16) {
            SalesPolicyCard(state: s)
            ComputeEconomicsCard(state: s)
            ForEach(s.semi.designs.filter { $0.inProduction || $0.phase == .retired }) { d in ProductSalesCard(design: d, state: s) }
            ContractsCard(state: s)
            BuyersCard(state: s)
            SemiHistoryCard(state: s)
        }
    }
}

private struct SalesPolicyCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let rules = Semis.exportRules(s)
        let armed = s.competitors.filter { (s.semi.buyers[$0.id] ?? 0) > 0 }
        Card {
            CardHeader("Who gets your chips", symbol: "person.2.badge.gearshape.fill",
                       subtitle: "Every finished chip is split between your own stock and customer stock. Big orders wait in your inbox.")
            HStack {
                Text("Keep for my fleet: \(Fmt.pct(s.semi.keepShare, decimals: 0))").font(.callout).frame(width: 200, alignment: .leading)
                Slider(value: Binding(get: { s.semi.keepShare }, set: { v in store.mutate { $0.setSemiPolicy(keepShare: (v * 20).rounded() / 20) } }), in: 0...1)
            }
            Toggle("Sell to rival labs on the open market", isOn: Binding(get: { s.semi.allowRivals }, set: { v in store.act { $0.setSemiPolicy(allowRivals: v) } }))
            Text("Rival labs are a quarter of the market. Every chip they buy adds to their fleet — and to their next models: \(armed.isEmpty ? "none have bought from you yet" : armed.map { "\($0.def.name) \(Fmt.count(s.semi.buyers[$0.id] ?? 0)) chips" }.joined(separator: ", ")).")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Sell to sovereign AI funds", isOn: Binding(get: { s.semi.allowSovereigns }, set: { v in store.mutate { $0.setSemiPolicy(allowSovereigns: v) } }))
            Toggle("Sell surplus dies to other packagers (known-good die)", isOn: Binding(get: { !s.semi.holdExcessDies }, set: { v in store.mutate { $0.setSemiPolicy(holdExcessDies: !v) } }))
            Text(rules.china ? "Export controls: no sales to Chinese buyers\(rules.gulfHalf ? "; Gulf sales need licences (half the demand)" : "")." : "No export controls on your chips right now.")
                .font(.caption).foregroundStyle(rules.china ? .orange : .secondary)
            if let until = Semis.exclusiveUntil(s) {
                Label("You promised exclusive supply until \(until.gameShort): no chips to rival labs, on the market or by order.", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(Theme.warning)
            }
            Why(reputationWhy(s))
        }
    }
}

extension SalesPolicyCard {
    func reputationWhy(_ s: GameState) -> String {
        var t = "Supplier reputation \(Int(Semis.reputation(s) * 100))/100 = 5 + 15 × log10(1 + chips shipped / 50k)"
        t += " + 20 × software maturity (\(Fmt.pct(s.semi.software, decimals: 0)))"
        if s.semi.repHit > 0 { t += " − \(Int(s.semi.repHit * 100)) for late orders" }
        t += ". Buyers need to trust your software stack before they switch. Your SKUs share one vendor share of the market."
        return t
    }
}

private struct ProductSalesCard: View {
    let design: SemiDesign
    let state: GameState

    var body: some View {
        let d = design
        Card {
            CardHeader(title: d.name, symbol: "shippingbox.fill", subtitle: "Revenue \(Fmt.money(d.revenue)) · production cost \(Fmt.money(d.cost)) · \(Fmt.count(d.sold.reduce(0, +))) sold · \(Fmt.count(d.taken.reduce(0, +))) kept") {
                Pill(text: d.phase.title, color: SemiStyle.color(d.phase))
            }
            ForEach(0..<3, id: \.self) { b in
                if d.chipIDs.indices.contains(b), let a = HardwareCatalog.get(d.chipIDs[b]) { BinSalesRow(design: d, bin: b, chip: a, state: state) }
            }
        }
    }
}

private struct BinSalesRow: View {
    @Environment(GameStore.self) private var store
    let design: SemiDesign
    let bin: Int
    let chip: Accelerator
    let state: GameState
    @State private var price = 0.0
    @State private var take = 0

    var body: some View {
        let d = design
        let s = state
        let b = bin
        let p = price > 0 ? price : d.prices[b]
        let dem = Semis.demand(d.id, bin: b, price: p, s)
        let open = Semis.buyers(s).filter { $0.blocked == nil }.reduce(0) { $0 + $1.weight }
        let uc = Semis.unitCost(d, foundry: SemiCatalog.foundryByID["fsw"]!, s)
        let avail = Int(d.stockMine[b] + d.stockSale[b])
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(chip.name).font(.callout.weight(.semibold))
                Spacer()
                Toggle("On sale", isOn: Binding(get: { d.onSale[b] }, set: { v in store.act { $0.setChipPrice(d.id, bin: b, onSale: v) } }))
                    .disabled(!d.inProduction)
            }
            HStack {
                Text("Price").font(.caption)
                TextField("Price", value: Binding(get: { p }, set: { price = $0 }), format: .number).textFieldStyle(.roundedBorder).frame(width: 110)
                Button("Set") { store.act("Price set") { $0.setChipPrice(d.id, bin: b, price: p) } }
                Text("≈ \(Fmt.count(dem.perDay * open * 30.4))/month demand · \(Fmt.pct(1 - uc.total / max(1, p), decimals: 0)) gross margin").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Stock: yours \(Fmt.count(d.stockMine[b])) · customers \(Fmt.count(d.stockSale[b]))").font(.caption.monospacedDigit())
            }
            HStack {
                QuantityPicker(value: $take, range: 0...max(0, avail), presets: [64, 512, 4096, 32_768])
                Button("Take for my fleet") { store.act("Chips on their way") { $0.orderOwnChips(chip.id, count: take) } }
                    .disabled(take <= 0)
                Text("\(Fmt.money(chip.price ?? 0)) each for the server around it (the silicon, about \(Fmt.money(Semis.siliconCost(chip.id, s))), is already paid) · arrives in \(Semis.shipDays) days").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Stock → customers") { store.mutate { $0.moveChipStock(d.id, bin: b, toMine: false) } }.help("Move your stock of this part to customer stock")
                Button("Stock → mine") { store.mutate { $0.moveChipStock(d.id, bin: b, toMine: true) } }.help("Move customer stock to your own")
            }
            Why("Demand: \(dem.why), × \(Fmt.pct(open, decimals: 0)) of buyers you sell to. Cost per chip \(Fmt.money(uc.total)) (see Supply chain).")
            Divider()
        }
    }
}

private struct ContractsCard: View {
    let state: GameState
    var body: some View {
        let s = state
        let open = s.semi.contracts.filter { !$0.closed }
        Card {
            CardHeader("Orders", symbol: "doc.text.fill", subtitle: "Accepted orders ship from customer stock before spot sales. Late ones pay 15% of what's missing.")
            if open.isEmpty { Text("No open orders. Customers send big orders to your inbox while you have chips on sale.").font(.callout).foregroundStyle(.secondary) }
            ForEach(open) { c in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(Semis.customerName(c.customer)): \(Fmt.count(c.units)) × \(s.semi.designs.first { $0.id == c.designID }?.name ?? "") \(SemiCatalog.binNames[clamp(c.bin, 0, 2)]) at \(Fmt.money(c.price))")
                            .font(.callout)
                        Spacer()
                        Text("due \(c.deadline.gameShort)").font(.caption).foregroundStyle(GameCalendar.daysBetween(s.date, c.deadline) < 30 ? .orange : .secondary)
                    }
                    Meter(value: c.delivered / max(1, c.units), tint: .green)
                }
            }
        }
    }
}

private struct BuyersCard: View {
    let state: GameState
    var body: some View {
        let s = state
        let rows = s.semi.buyers.sorted { $0.value > $1.value }
        let list = Semis.buyers(s)
        Card {
            CardHeader("Customers", symbol: "building.2.crop.circle.fill", subtitle: "Who buys, their share of demand, and what they've bought from you.")
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                ForEach(list.indices, id: \.self) { i in
                    let b = list[i]
                    GridRow {
                        Image(systemName: b.rival ? "flag.2.crossed.fill" : "building.2.fill").foregroundStyle(b.rival ? .orange : .teal)
                        Text(b.name).font(.caption)
                        Text(Fmt.pct(b.weight, decimals: 1)).font(.caption.monospacedDigit())
                        Text(Fmt.count(s.semi.buyers[b.id] ?? 0)).font(.caption.monospacedDigit())
                        Text(b.blocked.map { "Blocked: \($0)" } ?? "").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
            if rows.isEmpty { Text("Nothing sold yet.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct SemiHistoryCard: View {
    let state: GameState
    var body: some View {
        let s = state
        let rows = Array(s.semi.history.prefix(8))
        Card {
            CardHeader("Monthly books", symbol: "tablecells.fill", subtitle: "What the chip business made and cost each month.")
            if rows.isEmpty { Text("The first month closes at the start of next month.").font(.caption).foregroundStyle(.secondary) }
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 3) {
                if !rows.isEmpty {
                    GridRow {
                        ForEach(["Month", "Wafers", "Chips", "Sold", "Kept", "Revenue", "Wafers $", "Pack + HBM", "Team + design", "Fabs", "Held back by"], id: \.self) { h in
                            Text(h).font(.caption2.weight(.semibold))
                        }
                    }
                }
                ForEach(rows.indices, id: \.self) { i in
                    let m = rows[i]
                    GridRow {
                        Text(m.month?.gameMonth ?? "").font(.caption2)
                        Text(Fmt.count(m.wafers)).font(.caption2.monospacedDigit())
                        Text(Fmt.count(m.chips)).font(.caption2.monospacedDigit())
                        Text(Fmt.count(m.sold)).font(.caption2.monospacedDigit())
                        Text(Fmt.count(m.taken)).font(.caption2.monospacedDigit())
                        Text(Fmt.money(m.revenue + m.foundryRevenue)).font(.caption2.monospacedDigit())
                        Text(Fmt.money(m.wafersCost)).font(.caption2.monospacedDigit())
                        Text(Fmt.money(m.packCost + m.hbmCost)).font(.caption2.monospacedDigit())
                        Text(Fmt.money(m.teamCost + m.designCost)).font(.caption2.monospacedDigit())
                        Text(Fmt.money(m.fabCost)).font(.caption2.monospacedDigit())
                        Text(m.bottleneck.isEmpty ? "—" : m.bottleneck).font(.caption2)
                    }
                }
            }
            if !s.semi.log.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 3) { ForEach(Array(s.semi.log.prefix(10).enumerated()), id: \.offset) { _, e in EventLine(e: e) } }
            }
        }
    }
}

// MARK: - Software stack (3.9)

/// Compiler, kernels and drivers for your chips: how mature they are, what that costs your silicon, and what raises it.
private struct SoftwareStackCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var engineers = 150

    var body: some View {
        let s = state
        let m = s.semi.software
        let rates = Semis.softwareRates(s)
        Card {
            CardHeader("Software stack", symbol: "chevron.left.forwardslash.chevron.right",
                       subtitle: "A chip is only as fast as its compiler. Maturity sets your chips' training MFU, serving throughput and how far buyers trust them.")
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Maturity").font(.callout.weight(.semibold))
                        Spacer()
                        Text(Fmt.pct(m, decimals: 0)).font(TypeRamp.metricSmall)
                    }
                    Meter(value: m, tint: .purple)
                    SpecRow(label: "Training MFU vs a mature stack", value: Fmt.pct(Semis.softwareMFU(m), decimals: 0), tone: m < 0.4 ? .warning : .neutral)
                    SpecRow(label: "Serving throughput", value: "×\(Fmt.trim(Semis.softwareServe(m), 2))")
                    SpecRow(label: "Supplier reputation", value: "+\(Int(20 * m))")
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("What raises it (each year closes this share of the gap)").font(.caption.weight(.semibold))
                    if rates.isEmpty {
                        Text(s.semi.designs.isEmpty ? "Nothing to compile for until you start a design." : "Nothing yet: hire compiler engineers, ship chips, or point a software organisation at it.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(rates.enumerated()), id: \.offset) { _, x in
                        SpecRow(label: x.why, value: Fmt.pct(x.rate, decimals: 0))
                    }
                    Text("A new architecture costs some of it (the compiler has to learn it); a port keeps it.").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            HStack {
                Stepper("Compiler & kernel engineers: \(engineers)", value: $engineers, in: 0...1_500, step: 25)
                Spacer()
                Text("\(Fmt.money(Double(engineers) * Semis.engineerCost(s.year) * 0.9))/yr").font(.caption).foregroundStyle(.secondary)
                Button(s.semi.compilerEngineers == 0 ? "Hire" : "Resize") { store.act("Compiler team updated") { $0.setCompilerTeam(engineers: engineers) } }
                    .disabled(engineers == s.semi.compilerEngineers || !s.bonuses.has(.customSilicon))
            }
            Why("Now \(s.semi.compilerEngineers) engineers (\(Fmt.money(Semis.compilerCostYear(s)))/yr). 150 engineers close about 45% of the gap a year; growing it helps with diminishing returns (√ of the team).")
        }
        .onAppear { if s.semi.compilerEngineers > 0 { engineers = s.semi.compilerEngineers } }
    }
}

// MARK: - Compute economics (3.9)

/// What a PFLOP-day of delivered compute costs on your chips against the cheapest merchant part you can buy or rent.
struct ComputeEconomicsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let ec = Semis.computeEconomics(s, store.derived.bonuses)
        Card {
            CardHeader("Compute economics", symbol: "dollarsign.arrow.circlepath",
                       subtitle: "Dollars per PFLOP-day actually delivered: a day of the chip (four-year amortisation and power, or rent) over its FP8 peak × the MFU you reach (training) or × your serving utilisation (inference).")
            if ec.mine.isEmpty {
                Text("None of your chips is in production yet.").font(.callout).foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                GridRow {
                    Text("Chip").font(.caption.weight(.semibold))
                    Text("How").font(.caption.weight(.semibold))
                    Text("$/day").font(.caption.weight(.semibold))
                    Text("Training $/PFLOP-day").font(.caption.weight(.semibold))
                    Text("Serving $/PFLOP-day").font(.caption.weight(.semibold))
                }
                ForEach(Array(rows(ec).enumerated()), id: \.offset) { _, e in
                    GridRow {
                        Text(e.name).font(.caption).lineLimit(1)
                        Text(e.how).font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.money(e.dayCost)).font(.caption.monospacedDigit())
                        Text(Self.cost(e.trainCost, e.trainPF)).font(.caption.monospacedDigit())
                            .foregroundStyle(Self.beats(e, ec.train, train: true) ? Theme.good : Color.primary)
                        Text(Self.cost(e.serveCost, e.servePF)).font(.caption.monospacedDigit())
                            .foregroundStyle(Self.beats(e, ec.serve, train: false) ? Theme.good : Color.primary)
                    }
                }
            }
            Why("Your chips are costed at the server around them plus what their silicon costs to make today; merchant parts at today's price (or rent). The last two rows are the cheapest merchant compute for training and for serving.")
        }
    }

    private func rows(_ ec: (mine: [Semis.Economics], train: Semis.Economics?, serve: Semis.Economics?)) -> [Semis.Economics] {
        var out = ec.mine
        if let t = ec.train { out.append(t) }
        if let v = ec.serve { out.append(v) }
        return out
    }

    private static func cost(_ value: Double, _ pf: Double) -> String { pf > 0 ? Fmt.money(value) : "—" }

    /// One of your chips that beats the cheapest merchant compute.
    private static func beats(_ e: Semis.Economics, _ best: Semis.Economics?, train: Bool) -> Bool {
        guard e.own, let best else { return false }
        return train ? e.trainCost < best.trainCost : e.serveCost < best.serveCost
    }
}

// MARK: - Dashboard card

/// The chip business at a glance: designs in flight, last month's output and sales, and anything blocking it.
struct SemiconductorCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let last = s.semi.history.first
        Card {
            CardHeader(title: "Semiconductors", symbol: "circle.grid.cross.fill") {
                Button("Semiconductors") { store.open(.semiconductors) }.buttonStyle(.link)
            }
            if s.semi.isEmpty {
                Text("Design your own accelerators and sell them — or keep every one for yourself.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(s.semi.designs.filter { $0.phase.rawValue < SemiPhase.production.rawValue }.prefix(2)) { d in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(d.name).font(.callout.weight(.semibold))
                        Pill(text: d.phase.title, color: SemiStyle.color(d.phase))
                        Spacer()
                        Text("respin \(Fmt.pct(d.respinOdds, decimals: 0))").font(.caption).foregroundStyle(.secondary)
                    }
                    Meter(value: 1 - d.phaseDaysLeft / max(1, d.phaseDays), tint: SemiStyle.color(d.phase))
                    if !d.waiting.isEmpty { Text(d.waiting).font(.caption2).foregroundStyle(.orange) }
                }
            }
            if let last, last.chips > 0 || last.revenue > 0 {
                Text("Last month: \(Fmt.count(last.chips)) chips made, \(Fmt.count(last.sold)) sold for \(Fmt.money(last.revenue)), \(Fmt.count(last.taken)) kept"
                     + (last.bottleneck.isEmpty || last.bottleneck == "wafers" ? "." : " · held back by \(last.bottleneck)."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Semis.activeShocks(s).prefix(1)) { sh in
                Label("\(sh.title) until \(sh.end.gameShort)", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
            }
        }
    }
}
