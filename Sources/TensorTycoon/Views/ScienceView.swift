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
                         detail: "\(Fmt.money(sc.lastCost)) costs · \(Fmt.money(sc.lastIncome)) licences and spin-outs", symbol: "dollarsign.circle.fill",
                         tint: sc.lastIncome >= sc.lastCost ? Tone.good.color : Tone.warning.color)
            }
            ForEach(pending) { d in
                Card {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles").font(.title2).foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discovery: \(d.title)").font(.headline)
                            Text(Self.pendingLine(s, d))
                                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Read the report") { report = d }.buttonStyle(.borderedProminent)
                    }
                }
            }
            EnergyReachCard(state: s)
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
            TechnologiesCard(state: s)
            BreakthroughsCard(state: s)
            IPPortfolioCard(state: s)
            RivalScienceCard(state: s)
            CompanyHistoryCard(state: s)
        }
        .sheet(item: $report) { d in DiscoveryReportSheet(id: d.id) }
    }

    static func pendingLine(_ s: GameState, _ d: SciDiscovery) -> String {
        let options = Science.offered(s, d).map { $0.label.lowercased() }.joined(separator: ", ")
        return "The report is in: " + options + ". If you don't decide, it's patented."
    }
}

/// What your energy results do for you, owned hardware or not: the power bill, cloud and colocation prices, build
/// time and the grid queue. Shown once you have an energy-type discovery.
private struct EnergyReachCard: View {
    let state: GameState
    var body: some View {
        let s = state
        if Science.powerFactor(s) < 1 || Science.queueFactor(s) < 1 {
            let rent = Self.monthlyRent(s)
            Card {
                CardHeader("What your energy results save", symbol: "bolt.fill",
                           subtitle: "Owned datacenters pay less for power; providers pass part of the saving on to renters; new capacity comes sooner.")
                KPIRow(minWidth: 150) {
                    MetricTile(label: "Your power bill", value: "−\(Fmt.pct(1 - Science.powerFactor(s), decimals: 1))", symbol: "bolt.fill", tint: Tone.good.color)
                    MetricTile(label: "Cloud rentals", value: "−\(Fmt.pct(1 - Science.cloudFactor(s), decimals: 2))", symbol: "cloud.fill", tint: Tone.good.color)
                    MetricTile(label: "Colocation", value: "−\(Fmt.pct(1 - Science.coloFactor(s), decimals: 1))", symbol: "building.2.fill", tint: Tone.good.color)
                    MetricTile(label: "Campus build time", value: "−\(Fmt.pct(1 - Science.buildFactor(s), decimals: 0))", symbol: "hammer.fill", tint: Tone.good.color)
                    MetricTile(label: "Grid queue", value: "−\(Fmt.pct(1 - Science.queueFactor(s), decimals: 0))", symbol: "powerplug.fill", tint: Tone.good.color)
                }
                if rent > 0 {
                    Text(Self.rebateLine(s, rent: rent)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    static func monthlyRent(_ s: GameState) -> Double {
        s.rentals.reduce(0) { $0 + $1.hourly * 24 * 30.4 * Double($1.count) }
    }

    static func rebateLine(_ s: GameState, rent: Double) -> String {
        let saving = rent * (1 / Science.cloudFactor(s) - 1)
        var t = "On your current rentals (" + Fmt.money(rent) + "/month) the cloud rebate is worth about "
        t += Fmt.money(saving) + "/month; new rentals are priced with it."
        return t
    }
}

/// New technology categories your discoveries opened, and where each one shows.
private struct TechnologiesCard: View {
    /// "Opens with: <headline> (<field>, from <year>, grounded)."
    static func needsLine(_ project: String) -> String {
        guard let d = ScienceCatalog.projectByID[project] else { return "Opens with a discovery." }
        var t = "Opens with: " + d.headline + " (" + ScienceCatalog.field(d.field).name
        t += ", from \(Int(d.year)), "
        t += d.speculative ? "speculative)." : "grounded)."
        return t
    }

    let state: GameState
    var body: some View {
        let s = state
        let open = ScienceCatalog.unlocks.filter { Science.has($0.unlock, s) }
        if !open.isEmpty || !s.science.labs.isEmpty {
            Card {
                CardHeader("New technologies", symbol: "lock.open.fill",
                           subtitle: "A few discoveries open something new rather than make a number better.")
                ForEach(ScienceCatalog.unlocks, id: \.project) { u in
                    let when = Science.unlockDate(u.unlock, s)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: when == nil ? "lock.fill" : "lock.open.fill")
                            .foregroundStyle(when == nil ? Color.secondary : Tone.good.color).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(u.title).font(.callout.weight(.medium))
                                if let when { Pill("Open since \(when.gameShort)", tone: .good) }
                            }
                            Text(when == nil ? Self.needsLine(u.project) : u.detail)
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
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
                        } message: {
                            Text("Its projects stop: discoveries they made stay yours at lab scale (at most half their full effect). Severance is three months' pay.")
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
                            if d.year > s.year { Pill(text: "Opened early by your discoveries", color: .purple, symbol: "lock.open.fill") }
                            if let u = ScienceCatalog.unlock(d.id) { Pill(text: "Unlocks: \(u.title)", color: .indigo, symbol: "sparkles") }
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
                        } message: {
                            Text(p.discovery == nil ? "Nothing is discovered yet: the money spent is gone."
                                                    : "The discovery stays yours at lab scale — at most half its full effect, like a dead end — and the field learns nothing from it.")
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
    @Environment(GameStore.self) private var store
    let project: SciProject
    let state: GameState
    var body: some View {
        let p = project
        let s = state
        VStack(alignment: .leading, spacing: 4) {
        HStack {
            Image(systemName: p.status == .done ? "checkmark.seal.fill" : (p.status == .stalled ? "pause.circle.fill" : "xmark.circle.fill"))
                .foregroundStyle(p.status == .done ? .green : (p.status == .stalled ? .orange : .secondary))
            Text(p.projectDef?.name ?? p.def).font(.callout)
            Text(p.status.label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(p.log.filter { $0.outcome == "rerun" }.count) reruns · \(Fmt.money(p.spent))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text("\(p.started.gameShort) → \(p.ended?.gameShort ?? "…")").font(.caption2).foregroundStyle(.tertiary)
        }
        if p.status == .stalled, let d = p.projectDef {
            // 3.8: a stopped project can be restarted at the stage it stopped at.
            let lab = s.science.labs.first { $0.id == p.lab } ?? s.science.labs.first { $0.isReady(s.date) && $0.def.runs(d.field) && Science.active($0, s).count < Science.capacity($0) }
            let cost = Science.stageCost(p, p.currentStage, s)
            let wait = Science.resumeBlocker(p, s)
            HStack(spacing: 8) {
                Button("Resume") {
                    store.act("\(d.name) resumed") { $0.resumeScienceProject(p.id, lab: lab?.id) }
                }
                .disabled(lab == nil || wait != nil)
                .font(.caption)
                Text(wait.map { "New ideas by \($0.gameShort) · " } ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
                + Text("Restarts at \(Science.stageName(p.currentStage, d.field).lowercased()) for \(Fmt.money(cost))\(lab == nil ? " · needs a free lab that can run it" : "")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
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
                        Label(Self.effectsTitle(d), systemImage: "bolt.fill").font(.headline)
                        ForEach(Science.effectLines(ScienceCatalog.effect(def), strength: Science.strength(d), s), id: \.self) { line in
                            Label(line, systemImage: "arrow.right").font(.callout)
                        }
                    }
                    if let u = ScienceCatalog.unlock(def.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("New technology: \(u.title)", systemImage: "lock.open.fill").font(.headline)
                            Text(u.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
                        ForEach(Science.offered(s, d), id: \.self) { c in
                            Button {
                                store.act("\(c.label): \(d.title)") { $0.chooseDiscoveryFollowUp(d.id, c) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: c.symbol).frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.label).font(.callout.weight(.semibold))
                                        Text(Science.blocker(s, d, c) ?? Science.choiceDetail(c, def, s, scooped: !d.scooped.isEmpty, level: d.level)).font(.caption)
                                            .foregroundStyle(Science.blocker(s, d, c) == nil ? Color.secondary : Tone.warning.color)
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

    /// "Effects today (62% of full, +20% while it's secret)".
    static func effectsTitle(_ d: SciDiscovery) -> String {
        var t = "Effects today (\(Int((d.level * 100).rounded()))% of full"
        if d.sciChoice == .secret && !d.rivalCaughtUp { t += ", +20% while it's secret" }
        if d.labScaleOnly { t += ", lab scale only" }
        return t + ")"
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

/// Unique AI breakthroughs from your research lab, each with its report and follow-up.
private struct BreakthroughsCard: View {
    let state: GameState
    @State private var open: SciBreakthrough? = nil

    var body: some View {
        let s = state
        if !s.science.breakthroughs.isEmpty {
            Card {
                CardHeader("Unique breakthroughs", symbol: "sparkles",
                           subtitle: "Techniques only your lab has. Each has a report: what it does, what it's worth, how rivals respond — and a choice to publish, keep or license it.")
                ForEach(s.science.breakthroughs.reversed()) { b in
                    Button { open = b } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles").foregroundStyle(.purple).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.title).font(.callout.weight(.medium))
                                Text("\(Breakthroughs.rarity(b.tech).title) · \(b.date.gameShort)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if b.choice.isEmpty { Pill(text: "Decide", color: .orange, symbol: "exclamationmark.circle") }
                            else { Pill(text: Science.breakthroughChoiceLabel(b), color: .indigo) }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .sheet(item: $open) { b in BreakthroughReportSheet(id: b.id) }
        }
    }
}

/// A unique breakthrough's report and follow-up (publish, keep, license through `licenseExotic`).
struct BreakthroughReportSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID

    var body: some View {
        let s = store.game
        if let b = s.science.breakthroughs.first(where: { $0.id == id }) {
            let codes = Self.openCodes(s, b)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HeroBanner(image: "wafer_closeup", height: 150) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                PhotoPill(text: Breakthroughs.rarity(b.tech).title, symbol: "sparkles")
                                PhotoPill(text: b.date.gameShort, symbol: "calendar")
                            }
                            Text(b.title).font(.title.weight(.bold))
                            Text("Breakthrough report").font(.caption)
                        }
                    }
                    section("Technical significance", "atom", b.report.significance)
                    section("Commercial consequences", "chart.line.uptrend.xyaxis", b.report.commercial)
                    section("Impact on your work", "point.3.connected.trianglepath.dotted", b.report.impact)
                    section("Competitor responses", "binoculars.fill", b.report.competitors)
                    Divider()
                    if !b.choice.isEmpty {
                        Label(Self.choiceLine(b), systemImage: "checkmark.seal.fill").font(.headline)
                    }
                    if !codes.isEmpty {
                        Text("Follow-up decision").font(.headline)
                        ForEach(codes, id: \.self) { code in
                            Button {
                                store.act(Science.breakthroughLabel(code, s)) { $0.chooseBreakthrough(b.id, code) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Science.breakthroughLabel(code, s)).font(.callout.weight(.semibold))
                                    Text(Science.breakthroughDetail(code, tech: b.tech, s)).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Spacer()
                        Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                    }
                }
                .padding(22)
            }
            .frame(minWidth: 600, minHeight: 520)
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

    /// The choices the breakthrough's open decision offers (none once it's answered).
    static func openCodes(_ s: GameState, _ b: SciBreakthrough) -> [String] {
        guard let id = b.decision, let dec = s.decisions.first(where: { $0.id == id }), let last = dec.ref.split(separator: "|").last else { return [] }
        return last.split(separator: ",").map(String.init)
    }

    /// "Licensed to X (3 Mar 2027)", or published and also licensed.
    static func choiceLine(_ b: SciBreakthrough) -> String {
        var t = Science.breakthroughChoiceLabel(b)
        if let when = b.choiceDate { t += " (" + when.gameShort + ")" }
        if !b.licensee.isEmpty && b.choice != "license" { t += " · licensed to " + b.licensee }
        return t
    }
}

/// The company's history: one timeline of stages, deals, launches, training firsts, milestones, discoveries, unique
/// breakthroughs and government programmes (`Science.companyHistory`), filterable by kind.
struct CompanyHistoryCard: View {
    let state: GameState
    @State private var kind = "all"
    @State private var showAll = false

    var body: some View {
        let all = Science.companyHistory(state)
        let items = all.filter { kind == "all" || $0.kind == kind }
        Card {
            CardHeader(title: "Company history", symbol: "clock.arrow.circlepath", subtitle: "Everything that made the company, newest first.") {
                Picker("Show", selection: $kind) {
                    Text("Everything").tag("all")
                    ForEach(Science.historyKinds, id: \.kind) { k in Text(k.label).tag(k.kind) }
                }
                .frame(width: 180)
                .labelsHidden()
            }
            if items.isEmpty {
                Text(all.isEmpty ? "Nothing yet. Launches, deals, training firsts, milestones and discoveries land here." : "Nothing of that kind yet.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(items.reversed().prefix(showAll ? 400 : 40))) { e in
                HStack(spacing: 10) {
                    Image(systemName: e.symbol)
                        .foregroundStyle(Self.color(e.kind))
                        .frame(width: 22)
                        .accessibilityLabel(Science.historyKinds.first { $0.kind == e.kind }?.label ?? e.kind)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.title).font(.callout)
                        if !e.detail.isEmpty { Text(e.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                    }
                    Spacer()
                    Text(e.date.gameShort).font(.caption).foregroundStyle(.tertiary)
                }
            }
            if items.count > 40 {
                Button(showAll ? "Show the latest 40" : "Show all \(items.count)") { showAll.toggle() }.buttonStyle(.link).font(.caption)
            }
        }
    }

    /// A colour per kind of entry (a category, not a verdict).
    static func color(_ kind: String) -> Color {
        switch kind {
        case "company": .indigo
        case "launch": .blue
        case "training": .cyan
        case "milestone": .orange
        case "discovery": .purple
        case "breakthrough": .pink
        case "programme": .teal
        case "finance": .mint
        default: .secondary
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
