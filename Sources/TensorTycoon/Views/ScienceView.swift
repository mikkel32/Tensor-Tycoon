import SwiftUI

// MARK: - 3.6: science labs

struct ScienceView: View {
    @Environment(GameStore.self) private var store
    @State private var report: SciDiscovery? = nil

    var body: some View {
        let s = store.game
        let sc = s.science
        let running = sc.projects.filter { $0.status == .running }
        let pending = Science.pending(s)
        Page(title: "Science Labs",
             subtitle: "Build laboratories, staff them and run real research: hypothesis to commercialisation, ten stages that can fail. Discoveries lower your costs, sharpen your models, open product lines and feed moonshots.", screen: .science) {
            KPIRow {
                StatTile(title: "Laboratories", value: "\(sc.labs.count)", detail: sc.labs.isEmpty ? "None yet" : "\(sc.labs.reduce(0) { $0 + $1.staff }) scientists",
                         symbol: "building.2.fill", tint: .indigo)
                StatTile(title: "Projects running", value: "\(running.count)", detail: "\(sc.projects.filter { $0.status == .done }.count) commercialised",
                         symbol: "flask.fill", tint: .teal)
                StatTile(title: "Discoveries", value: "\(sc.discoveries.count)", detail: pending.isEmpty ? "\(sc.patents.count) patents" : "\(pending.count) awaiting a decision",
                         symbol: "sparkles", tint: .purple)
                StatTile(title: "Last month", value: Fmt.money(sc.lastIncome - sc.lastCost),
                         detail: "\(Fmt.money(sc.lastCost)) costs · \(Fmt.money(sc.lastIncome)) licences", symbol: "dollarsign.circle.fill",
                         tint: sc.lastIncome >= sc.lastCost ? .green : .orange)
            }
            ForEach(pending) { d in
                Card {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles").font(.title2).foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discovery: \(d.title)").font(.headline)
                            Text("The report is in. Patent it, keep it secret, publish it, spin it out\(d.projectDef.flatMap { Science.feedable(s, $0) } != nil ? " or feed it to a moonshot" : ""). If you don't decide, it's patented.")
                                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Read the report") { report = d }.buttonStyle(.borderedProminent)
                    }
                }
            }
            if sc.labs.isEmpty {
                Card {
                    EmptyStateView(symbol: "testtube.2", title: "No laboratories yet",
                                   message: "A lab costs millions to build and run. Pick the field that pays you back: energy research for your power bill, robotics for the Robotics Brain, computing for maths and cheaper inference.")
                }
            }
            ForEach(sc.labs) { lab in LabCard(lab: lab, state: s) }
            BuildLabCard(state: s)
            if !running.isEmpty || !sc.projects.isEmpty {
                Text("Projects").font(.title3.weight(.semibold)).padding(.top, 6)
                ForEach(sc.projects.filter { $0.status == .running }) { p in ProjectCard(project: p, state: s) }
                let past = sc.projects.filter { $0.status != .running }
                if !past.isEmpty {
                    Card {
                        CardHeader("Finished projects", symbol: "checkmark.seal")
                        ForEach(past.reversed()) { p in ProjectRow(project: p, state: s) }
                    }
                }
            }
            if !sc.discoveries.isEmpty {
                Card {
                    CardHeader("Discoveries", symbol: "sparkles", subtitle: "Each has a report: what it means, what it's worth, how rivals will respond.")
                    ForEach(sc.discoveries.reversed()) { d in
                        Button { report = d } label: { DiscoveryRow(discovery: d, state: s) }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            IPPortfolioCard(state: s)
            RivalScienceCard(state: s)
            CompanyHistoryCard(state: s)
        }
        .sheet(item: $report) { d in DiscoveryReportSheet(id: d.id) }
    }
}

// MARK: - Labs

private struct LabCard: View {
    @Environment(GameStore.self) private var store
    let lab: SciLab
    let state: GameState
    @State private var confirmClose = false

    var body: some View {
        let s = state
        let def = lab.def
        let active = Science.active(lab, s)
        let ready = lab.isReady(s.date)
        Card(padding: 0) {
            HeroBanner(image: def.image, height: 150) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        PhotoPill(text: ready ? "Open" : "Opens \(lab.ready.gameMonth)", color: ready ? .green : .orange, symbol: ready ? "checkmark" : "hammer.fill")
                        PhotoPill(text: Science.siteName(lab.site), symbol: "mappin.and.ellipse")
                        if Science.isHome(lab.site, s) { PhotoPill(text: "Home incentives", color: .mint, symbol: "house.fill") }
                    }
                    Text(lab.name).font(.title2.weight(.bold))
                    Text(def.blurb).font(.caption).lineLimit(2)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Equipment level \(lab.equipment) of \(Science.maxEquipment)").font(.caption).foregroundStyle(.secondary)
                        Meter(value: Double(lab.equipment) / Double(Science.maxEquipment), tint: .teal, height: 7)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(lab.staff) \(def.staffTitle) · skill \(Int(lab.skill.rounded()))").font(.caption).foregroundStyle(.secondary)
                        Meter(value: lab.skill / 100, tint: .purple, height: 7)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Projects \(active.count) of \(Science.capacity(lab))").font(.caption).foregroundStyle(.secondary)
                        Meter(value: Double(active.count) / Double(max(1, Science.capacity(lab))), tint: .indigo, height: 7)
                    }
                }
                SpecRow(label: "Running cost", value: "\(Fmt.money(Science.facilityMonth(lab, s)))/mo facility + \(Fmt.money(Science.staffMonth(lab, s)))/mo staff")
                SpecRow(label: "Fields", value: (def.primary.map { ScienceCatalog.field($0).name } + def.secondary.map { "\(ScienceCatalog.field($0).name) (less suited)" }).joined(separator: ", "))
                if let up = lab.upgradeReady {
                    Label("Equipment upgrade arrives \(up.gameShort)", systemImage: "shippingbox.fill").font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button("Hire 4 (\(Fmt.money(4 * Science.salary(lab.site, s) * 0.15)))") {
                        store.act("Hired 4 \(def.staffTitle)") { $0.hireScientists(lab.id, 4) }
                    }
                    .disabled(lab.staff >= Science.staffCap(lab))
                    Button("Let 2 go") { store.mutate { $0.releaseScientists(lab.id, 2) } }
                        .disabled(lab.staff < 2)
                    if lab.equipment < Science.maxEquipment && lab.upgradeReady == nil {
                        Button("Upgrade equipment (\(Fmt.money(Science.upgradeCost(lab, s))))") {
                            store.act("Equipment ordered") { $0.upgradeLab(lab.id) }
                        }
                    }
                    Spacer()
                    Button("Close lab…", role: .destructive) { confirmClose = true }
                        .buttonStyle(.link).font(.caption)
                        .confirmationDialog("Close the \(lab.name)?", isPresented: $confirmClose) {
                            Button("Close it", role: .destructive) { store.mutate { $0.closeLab(lab.id) } }
                            Button("Keep it", role: .cancel) {}
                        }
                }
                .controlSize(.small)
                if ready && active.count < Science.capacity(lab) {
                    StartProjectList(lab: lab, state: s)
                }
                ImageCreditLabel(key: def.image, representative: true)
            }
            .padding(16)
        }
    }
}

private struct StartProjectList: View {
    @Environment(GameStore.self) private var store
    let lab: SciLab
    let state: GameState
    @State private var agents = 0
    @State private var compute = 1
    @State private var showAll = false

    var body: some View {
        let s = state
        let list = Science.available(lab, s)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Start a project").font(.subheadline.weight(.semibold))
                Spacer()
                Stepper("Agents: \(agents)", value: $agents, in: 0...Science.agentMax, step: 2).font(.caption)
                Picker("Compute", selection: $compute) {
                    Text("None").tag(0)
                    Text("Small").tag(1)
                    Text("Medium").tag(2)
                    Text("Large").tag(3)
                }
                .frame(width: 170)
                .font(.caption)
            }
            Text("Agents cost \(Fmt.money(Science.agentDay(s)))/day each; compute \(Fmt.money(Science.computeMonth(1, s)))/month per tier. Both help most on simulation and design.")
                .font(.caption2).foregroundStyle(.secondary)
            if list.isEmpty {
                Text("Nothing new this lab can take on until later years.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(showAll ? list : Array(list.prefix(4)), id: \.id) { d in
                let f = ScienceCatalog.field(d.field)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: f.symbol).foregroundStyle(Color.accentColor).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(d.name).font(.callout.weight(.medium))
                            Pill(text: f.name, color: .secondary)
                            Pill(text: d.speculative ? "Speculative" : "Grounded", color: d.speculative ? .orange : .green)
                            if !lab.def.primary.contains(d.field) { Pill("Lab less suited", tone: .warning) }
                        }
                        Text(d.pitch).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text(d.basis).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Start") {
                        store.act("\(d.name) started") { $0.startScienceProject(d.id, lab: lab.id, agents: agents, compute: compute) }
                    }
                    .controlSize(.small)
                }
            }
            if list.count > 4 {
                Button(showAll ? "Show fewer" : "Show all \(list.count)") { showAll.toggle() }.buttonStyle(.link).font(.caption)
            }
        }
        .padding(12)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

private struct BuildLabCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var kind: LabKind = .computing
    @State private var site = "sf"

    var body: some View {
        let s = state
        let def = ScienceCatalog.lab(kind)
        let st = Science.site(site)
        let cost = Science.capex(kind, site: site, s)
        let local = st.strengths[kind] ?? 0
        Card {
            CardHeader("Build a laboratory", symbol: "hammer.fill", subtitle: "Where you build matters: local talent is better at some kinds of lab, and labs at home get incentives.")
            HStack(alignment: .top, spacing: 16) {
                Photo(key: def.image)
                    .frame(width: 220, height: 130)
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Laboratory", selection: $kind) {
                        ForEach(ScienceCatalog.labs) { l in Label(l.name, systemImage: l.symbol).tag(l.kind) }
                    }
                    Picker("City", selection: $site) {
                        ForEach(ScienceCatalog.sites) { x in
                            Text("\(Science.siteName(x.id))\((x.strengths[kind] ?? 0) >= 4 ? " ★" : "")").tag(x.id)
                        }
                    }
                    Text(def.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("\(st.note). Local hires \(local > 0 ? "+\(Int(local)) skill" : "average") for this lab.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            SpecRow(label: "Build cost", value: Fmt.money(cost))
            SpecRow(label: "Opens in", value: "\(def.buildDays) days")
            SpecRow(label: "Runs", value: "\(def.capacity) projects at once (more with better equipment)")
            SpecRow(label: "Fields", value: (def.primary + def.secondary).map { ScienceCatalog.field($0).name }.joined(separator: ", "))
            SpecRow(label: "Scientist cost here", value: "\(Fmt.money(Science.salary(site, s)))/year each")
            HStack {
                Button("Build for \(Fmt.money(cost)) with 8 \(def.staffTitle)") {
                    store.act("Construction started") { $0.buildLab(kind, site: site) }
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                ImageCreditLabel(key: def.image, representative: true)
            }
        }
    }
}

// MARK: - Projects

/// The ten stages as a strip: done, current, ahead, skipped.
/// A project's stages on the shared `StageStrip`: passed, under way, dead end or still to come, with reruns noted.
struct ScienceStageStrip: View {
    let project: SciProject
    var body: some View {
        let field = project.projectDef?.field ?? .materials
        StageStrip(steps: Science.stages(field).map { st in
            let passed = project.log.contains { $0.stage == st.rawValue && $0.outcome == "passed" }
            let dead = project.log.contains { $0.stage == st.rawValue && $0.outcome == "dead end" }
            let reruns = project.log.filter { $0.stage == st.rawValue && $0.outcome == "rerun" }.count
            let current = project.status == .running && project.stage == st.rawValue
            return StageStep(id: "\(st.rawValue)", title: Science.stageName(st, field),
                             status: dead ? .failed : (passed ? .done : (current ? .current : .upcoming)),
                             note: reruns > 0 ? "↺\(reruns)" : nil, help: ScienceCatalog.stage(st).blurb)
        }, tint: Theme.info)
    }
}

private struct ProjectCard: View {
    @Environment(GameStore.self) private var store
    let project: SciProject
    let state: GameState
    @State private var confirmCancel = false

    var body: some View {
        let s = state
        let p = project
        if let d = p.projectDef {
            let f = ScienceCatalog.field(d.field)
            let st = p.currentStage
            let o = Science.odds(p, st, s)
            let days = Science.stageDays(p, st, s)
            Card {
                HStack(alignment: .top) {
                    Image(systemName: f.symbol).font(.title2).foregroundStyle(Color.accentColor).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(d.name).font(.headline)
                            Pill(text: d.speculative ? "Speculative" : "Grounded", color: d.speculative ? .orange : .green)
                            if !p.scooped.isEmpty { Pill(text: "Scooped by \(Science.labName(s, p.scooped))", color: .red, symbol: "exclamationmark.triangle.fill") }
                        }
                        Text("\(f.name) · \(p.labName(s)) · since \(p.started.gameShort) · \(Fmt.money(p.spent)) spent").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int((Science.chanceToEnd(p, s) * 100).rounded()))%").font(.title3.weight(.semibold).monospacedDigit())
                        Text("chance to commercialise").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ScienceStageStrip(project: p)
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Science.stageName(st, d.field)) · attempt \(p.attempts + 1)").font(.subheadline.weight(.semibold))
                        Text(ScienceCatalog.stage(st).blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Meter(value: p.progress / max(1, days), tint: .blue, height: 6)
                        Text("Day \(Int(p.progress)) of about \(Int(days.rounded())) · next attempt costs \(Fmt.money(Science.stageCost(p, st, s)))").font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Odds this stage: \(Int((o.p * 100).rounded()))%").font(.subheadline.weight(.semibold))
                        ForEach(Array(o.parts.enumerated()), id: \.offset) { _, part in
                            HStack {
                                Text(part.0).font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(part.1 >= 0 ? "+" : "−")\(Int(abs(part.1 * 100).rounded()))").font(.caption2.monospacedDigit())
                                    .foregroundStyle(part.0 == "Base odds" ? Color.primary : (part.1 >= 0 ? Color.green : Color.orange))
                            }
                        }
                    }
                    .frame(width: 260)
                }
                HStack {
                    Stepper("Agents: \(p.agents)", value: Binding(get: { p.agents }, set: { v in store.mutate { $0.setProjectSupport(p.id, agents: v, compute: p.compute) } }),
                            in: 0...Science.agentMax, step: 2)
                    Picker("Compute", selection: Binding(get: { p.compute }, set: { v in store.mutate { $0.setProjectSupport(p.id, agents: p.agents, compute: v) } })) {
                        Text("None").tag(0)
                        Text("Small").tag(1)
                        Text("Medium").tag(2)
                        Text("Large").tag(3)
                    }
                    .frame(width: 170)
                    Spacer()
                    Button("Stop project…", role: .destructive) { confirmCancel = true }
                        .buttonStyle(.link)
                        .confirmationDialog("Stop \(d.name)?", isPresented: $confirmCancel) {
                            Button("Stop it", role: .destructive) { store.mutate { $0.cancelScienceProject(p.id) } }
                            Button("Keep going", role: .cancel) {}
                        }
                }
                .font(.caption)
                .controlSize(.small)
                if !p.log.isEmpty {
                    DisclosureGroup("Timeline (\(p.log.count) attempts)") {
                        ForEach(Array(p.log.enumerated()), id: \.offset) { _, l in TimelineRow(entry: l, field: d.field) }
                    }
                    .font(.caption)
                }
            }
        }
    }
}

private struct TimelineRow: View {
    let entry: SciStageLog
    let field: SciField
    var body: some View {
        let st = SciStage(rawValue: entry.stage) ?? .hypothesis
        HStack {
            Image(systemName: entry.outcome == "passed" ? "checkmark.circle.fill" : (entry.outcome == "rerun" ? "arrow.counterclockwise.circle.fill" : "xmark.octagon.fill"))
                .foregroundStyle(entry.outcome == "passed" ? .green : (entry.outcome == "rerun" ? .orange : .red))
            Text(Science.stageName(st, field)).font(.caption)
            Spacer()
            Text("\(Int((entry.odds * 100).rounded()))% odds · \(entry.days) days · \(entry.outcome)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            Text(entry.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

private struct ProjectRow: View {
    let project: SciProject
    let state: GameState
    var body: some View {
        let p = project
        HStack {
            Image(systemName: p.status == .done ? "checkmark.seal.fill" : (p.status == .stalled ? "pause.circle.fill" : "xmark.circle.fill"))
                .foregroundStyle(p.status == .done ? .green : (p.status == .stalled ? .orange : .secondary))
            Text(p.projectDef?.name ?? p.def).font(.callout)
            Text(p.status.label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(p.log.filter { $0.outcome == "rerun" }.count) reruns · \(Fmt.money(p.spent))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text("\(p.started.gameShort) → \(p.ended?.gameShort ?? "…")").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Discoveries

private struct DiscoveryRow: View {
    let discovery: SciDiscovery
    let state: GameState
    var body: some View {
        let d = discovery
        let f = d.projectDef.map { ScienceCatalog.field($0.field) }
        HStack(spacing: 10) {
            Image(systemName: f?.symbol ?? "sparkles").foregroundStyle(.purple).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.title).font(.callout.weight(.medium))
                Text("\(f?.name ?? "") · \(d.date.gameShort)\(d.commercialised != nil ? " · commercialised" : (d.labScaleOnly ? " · lab scale only" : ""))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let c = d.sciChoice {
                Pill(text: c.label, color: .indigo, symbol: c.symbol)
            } else {
                Pill(text: "Decide", color: .orange, symbol: "exclamationmark.circle")
            }
            Text("\(Int((d.level * 100).rounded()))% of full effect").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }
}

/// The discovery report: what it means, what it's worth, what it does to your other work, how rivals respond, and
/// the follow-up decision.
struct DiscoveryReportSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID

    var body: some View {
        let s = store.game
        if let d = s.science.discoveries.first(where: { $0.id == id }), let def = d.projectDef {
            let f = ScienceCatalog.field(def.field)
            let image = s.science.projects.first { $0.id == d.project }?.labImage(s) ?? "supercomputer"
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HeroBanner(image: image, height: 170) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                PhotoPill(text: f.name, symbol: f.symbol)
                                PhotoPill(text: def.speculative ? "Speculative" : "Grounded", color: def.speculative ? .orange : .green)
                                PhotoPill(text: d.date.gameShort, symbol: "calendar")
                            }
                            Text(d.title).font(.title.weight(.bold))
                            Text("Discovery report").font(.caption)
                        }
                    }
                    section("Technical significance", "atom", d.report.significance)
                    section("Commercial consequences", "chart.line.uptrend.xyaxis", d.report.commercial)
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Effects today (\(Int((d.level * 100).rounded()))% of full\(d.sciChoice == .secret && !d.rivalCaughtUp ? ", +20% while it's secret" : ""))", systemImage: "bolt.fill").font(.headline)
                        ForEach(Science.effectLines(f.effect, strength: Science.strength(d), s), id: \.self) { line in
                            Label(line, systemImage: "arrow.right").font(.callout)
                        }
                    }
                    section("Impact on your projects", "point.3.connected.trianglepath.dotted", d.report.impact)
                    section("Competitor responses", "binoculars.fill", d.report.competitors)
                    if !d.scooped.isEmpty {
                        Label("\(Science.labName(s, d.scooped)) published first: licences are worth half and secrecy won't last.", systemImage: "exclamationmark.triangle.fill")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    Divider()
                    if let c = d.sciChoice {
                        Label("You chose: \(c.label)\(d.choiceDate.map { " (\($0.gameShort))" } ?? "")", systemImage: c.symbol).font(.headline)
                        if let p = s.science.patents.first(where: { $0.discovery == d.id }) {
                            Text("Patent: \(p.licensees) licensees · \(Fmt.money(p.lastMonth)) last month · \(Fmt.money(p.lifetime)) so far\(p.designedAround ? " · designed around" : "")")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Follow-up decision").font(.headline)
                        ForEach(Science.choices(s, def), id: \.self) { c in
                            Button {
                                store.mutate { $0.chooseDiscoveryFollowUp(d.id, c) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: c.symbol).frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.label).font(.callout.weight(.semibold))
                                        Text(Science.choiceDetail(c, def, s, scooped: !d.scooped.isEmpty)).font(.caption).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        ImageCreditLabel(key: image, representative: true)
                        Spacer()
                        Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                    }
                }
                .padding(22)
            }
            .frame(minWidth: 620, minHeight: 560)
        } else {
            Text("Report not found.").padding(40)
        }
    }

    private func section(_ title: String, _ symbol: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.headline)
            Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - IP, rivals and history

private struct IPPortfolioCard: View {
    let state: GameState
    var body: some View {
        let s = state
        let sc = s.science
        Card {
            CardHeader("IP portfolio", symbol: "doc.badge.gearshape",
                       subtitle: "\(sc.patents.count) patents · \(Fmt.money(sc.licensing)) licence income so far · \(Fmt.money(sc.spinoutCash)) from spin-outs")
            if sc.patents.isEmpty {
                Text("No patents yet. Patent a discovery to license it: modest, steady income that grows if the work is commercialised.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(sc.patents) { p in
                HStack {
                    Image(systemName: ScienceCatalog.field(p.field).symbol).foregroundStyle(.indigo).frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.title).font(.callout)
                        Text("Filed \(p.filed.gameShort) · expires \(p.expires.gameShort) · \(p.licensees) licensees\(p.designedAround ? " · rivals designed around it" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Fmt.money(p.lastMonth))/mo").font(.callout.monospacedDigit())
                    Text("\(Fmt.money(p.lifetime)) total").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RivalScienceCard: View {
    let state: GameState
    var body: some View {
        let s = state
        let alive = ScienceCatalog.rivalLabs.filter { r in s.competitors.contains { $0.id == r.lab && $0.alive } }
        Card {
            CardHeader("Rival science labs", symbol: "binoculars.fill",
                       subtitle: "Some rivals run science arms of their own. Now and then one beats you to a result: that's a scoop.")
            ForEach(alive, id: \.lab) { r in
                let results = s.science.rivals.filter { $0.lab == r.lab }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.arm).font(.callout.weight(.medium))
                        Text(r.fields.map { ScienceCatalog.field($0).name }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(results.count) result\(results.count == 1 ? "" : "s")").font(.caption.monospacedDigit())
                        if let last = results.first, let d = ScienceCatalog.projectByID[last.def] {
                            Text("\(d.headline) · \(last.date.gameShort)\(last.scoopedYou ? " · scooped you" : "")").font(.caption2)
                                .foregroundStyle(last.scoopedYou ? .orange : .secondary)
                        }
                    }
                }
            }
            if s.science.labs.isEmpty {
                Text("You'll hear about their results once you have a lab of your own.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Training firsts and science results on one timeline.
struct CompanyHistoryCard: View {
    let state: GameState
    var body: some View {
        let items = Science.companyHistory(state)
        Card {
            CardHeader("Company history", symbol: "clock.arrow.circlepath", subtitle: "Training firsts, labs and discoveries.")
            if items.isEmpty {
                Text("Nothing yet. Firsts in training and results from your labs land here.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(items.reversed().prefix(40)) { e in
                HStack(spacing: 10) {
                    Image(systemName: e.symbol)
                        .foregroundStyle(e.kind == "training" ? Color.blue : (e.kind == "lab" ? Color.teal : Color.purple))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.title).font(.callout)
                        if !e.detail.isEmpty { Text(e.detail).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text(e.date.gameShort).font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Dashboard

/// A compact science summary for the dashboard (labs, running projects, the next stage to land, pending reports).
struct ScienceDashboardCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let sc = s.science
        let running = sc.projects.filter { $0.status == .running }
        let pending = Science.pending(s)
        Card {
            CardHeader(title: "Science labs", symbol: "testtube.2", subtitle: sc.labs.isEmpty ? "No labs yet" : "\(sc.labs.count) labs · \(running.count) projects · \(sc.discoveries.count) discoveries") {
                Button("Open") { store.open(.science) }.buttonStyle(.link)
            }
            if !pending.isEmpty {
                Label("\(pending.count) discovery report\(pending.count == 1 ? "" : "s") waiting for a decision", systemImage: "sparkles")
                    .font(.callout).foregroundStyle(.purple)
            }
            ForEach(running.prefix(3)) { p in
                if let d = p.projectDef {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(d.name).font(.caption.weight(.medium))
                            Spacer()
                            Text("\(Science.stageName(p.currentStage, d.field)) · \(Int((Science.odds(p, p.currentStage, s).p * 100).rounded()))%")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ScienceStageStrip(project: p)
                    }
                }
            }
            if sc.lastCost > 0 || sc.lastIncome > 0 {
                Text("Last month: \(Fmt.money(sc.lastCost)) costs, \(Fmt.money(sc.lastIncome)) licence income").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
