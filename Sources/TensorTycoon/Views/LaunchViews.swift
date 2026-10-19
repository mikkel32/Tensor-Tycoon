import SwiftUI

// MARK: - 3.7: launch plans and launch reports

/// Choose a launch plan — strategy, pricing stance, safety posture — and see what it will do, line by line.
struct LaunchPlanPicker: View {
    @Environment(GameStore.self) private var store
    @Binding var plan: LaunchPlan
    let state: GameState
    /// Where the model would land on the leaderboard (drives the press and the size of any spike).
    let rank: Int
    var showDefaultButton = true

    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 8) {
            Picker("Strategy", selection: $plan.strategy) {
                ForEach(LaunchStyle.allCases) { l in
                    let locked = !Launches.available(l, s)
                    Label(locked ? "\(l.title) — \(Launches.requiredStage(l)?.title ?? "")" : l.title, systemImage: locked ? "lock.fill" : l.symbol).tag(l)
                }
            }
            Text(plan.strategy.detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker("Price", selection: $plan.pricing) {
                ForEach(PricingStance.allCases) { p in Text(p.title).tag(p) }
            }
            .pickerStyle(.segmented)
            .help(plan.pricing.detail)
            Picker("Safety", selection: $plan.safety) {
                ForEach(SafetyPosture.allCases) { p in Text(p.title).tag(p) }
            }
            .help(plan.safety.detail)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Launches.effects(plan, s, rank: rank), id: \.self) { e in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: e.good == true ? "arrowtriangle.up.fill" : (e.good == false ? "arrowtriangle.down.fill" : "circle.fill"))
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(e.good == true ? Color.green : (e.good == false ? Color.red : Color.secondary))
                            .frame(width: 10)
                        Text("\(Text(e.label).bold()) \(e.text)").font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 8))
            if let e = Launches.blocker(plan, s), !plan.isDefault {
                Label(e, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
            } else if Launches.cost(plan, s) > 0 {
                Text("Costs \(Fmt.money(Launches.cost(plan, s))) on launch day.").font(.caption).foregroundStyle(.secondary)
            }
            if showDefaultButton {
                HStack {
                    if plan == s.launchDefault {
                        Label("Your default plan", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Make this my default") { store.mutate { $0.setLaunchDefault(plan) } }
                            .buttonStyle(.link).font(.caption)
                            .help("One-click launches, the Chief of Staff's Launch it and the launch delegate use your default plan.")
                    }
                    Spacer()
                    if !plan.isDefault {
                        Button("Plain release") { plan = LaunchPlan() }.buttonStyle(.link).font(.caption)
                    }
                }
            }
        }
    }
}

/// A compact "Plan: …" button that opens the picker in a popover (for tight footers).
struct LaunchPlanButton: View {
    @Binding var plan: LaunchPlan
    let state: GameState
    let rank: Int
    @State private var open = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            Label(plan.summary, systemImage: plan.strategy.symbol).lineLimit(1)
        }
        .help("Choose how to launch: strategy, price and safety posture")
        .popover(isPresented: $open, arrowEdge: .top) {
            LaunchPlanPicker(plan: $plan, state: state, rank: rank)
                .padding(14)
                .frame(width: 380)
        }
    }
}

extension LaunchReport {
    var verdictTitle: String { verdict == "beat" ? "Beat the plan" : (verdict == "on" ? "On plan" : "Below plan") }
    var verdictColor: Color { verdict == "beat" ? .green : (verdict == "on" ? .blue : .orange) }
    var verdictSymbol: String { verdict == "beat" ? "star.circle.fill" : (verdict == "on" ? "checkmark.circle.fill" : "exclamationmark.circle.fill") }
}

/// The launch-day report, a week after release: traffic, press, benchmarks, rivals, stakeholders, and the verdict.
struct LaunchReportSheet: View {
    @Environment(GameStore.self) private var store
    let recordID: UUID

    var body: some View {
        if let s = store.state, let r = s.launches.first(where: { $0.id == recordID }) {
            content(s, r)
        } else {
            VStack(spacing: 12) {
                Text("Launch not found").font(.headline)
                Button("Close") { store.launchReportID = nil }
            }
            .padding(40)
        }
    }

    private func content(_ s: GameState, _ r: LaunchRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch report").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(r.modelName).font(.largeTitle.weight(.bold))
                            Text("Launched \(r.date.gameLong) · \(r.plan.summary)\(r.by.isEmpty ? "" : " · by the \(r.by == "family" ? "family pipeline" : "launch delegate")")")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let rep = r.report {
                            Label(rep.verdictTitle, systemImage: rep.verdictSymbol)
                                .font(.title3.weight(.semibold)).foregroundStyle(rep.verdictColor)
                        }
                    }
                    if let rep = r.report {
                        report(s, r, rep)
                    } else {
                        Card {
                            Label("The report arrives a week after launch (\(GameCalendar.addDays(r.date, 7).gameShort)).", systemImage: "clock")
                                .foregroundStyle(.secondary)
                        }
                        planCard(s, r)
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Open in Models") {
                    store.focusModelID = r.modelID
                    store.open(.models)
                    store.launchReportID = nil
                }
                .disabled(!s.models.contains { $0.id == r.modelID })
                Spacer()
                Button("Done") { store.launchReportID = nil }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 560, idealHeight: 700)
    }

    @ViewBuilder
    private func report(_ s: GameState, _ r: LaunchRecord, _ rep: LaunchReport) -> some View {
        Text(rep.verdictText).font(.callout).fixedSize(horizontal: false, vertical: true)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            StatTile(title: "Sign-ups (week)", value: (rep.signUps >= 0 ? "+" : "") + Fmt.count(rep.signUps),
                     detail: "\(Fmt.count(rep.chatUsers)) chat users", symbol: "person.badge.plus", tint: .purple)
            StatTile(title: "API traffic", value: "\(Fmt.count(rep.apiTokensDay))/day",
                     detail: rep.tokensBefore > 1 ? "\(Fmt.trim(rep.tokensDay / rep.tokensBefore, 1))× your models' traffic before" : "first API traffic",
                     symbol: "arrow.left.arrow.right", tint: .teal)
            StatTile(title: "Revenue", value: "\(Fmt.money(rep.revenueDay))/day", detail: "served \(Fmt.pct(rep.servedShare, decimals: 0)) of demand",
                     symbol: "dollarsign.circle", tint: rep.servedShare < 0.8 ? .orange : .green)
            StatTile(title: "Leaderboard", value: "#\(rep.rank)", detail: "index \(Fmt.score(rep.index))\(rep.leads > 0 ? " · \(rep.leads) new lead\(rep.leads == 1 ? "" : "s")" : "")",
                     symbol: "trophy", tint: .yellow)
        }
        section("The press", symbol: "newspaper", tone: rep.pressTone) {
            if rep.quotes.isEmpty {
                Text("Nobody went on the record this week.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(rep.quotes, id: \.self) { q in
                Text(q).font(.callout).italic().fixedSize(horizontal: false, vertical: true)
            }
        }
        section("Benchmark reception", symbol: "chart.bar.xaxis") {
            ForEach(rep.benchmarks, id: \.self) { Text($0).font(.callout).fixedSize(horizontal: false, vertical: true) }
        }
        section("Rivals", symbol: "binoculars") {
            ForEach(Launches.rivalLines(s, r), id: \.self) { line in
                Text(line).font(.callout).foregroundStyle(line.hasPrefix("Expected") ? .secondary : .primary).fixedSize(horizontal: false, vertical: true)
            }
        }
        section("Stakeholders", symbol: "person.3") {
            if rep.stakeholders.isEmpty { Text("No one's view of you moved much.").font(.callout).foregroundStyle(.secondary) }
            ForEach(rep.stakeholders, id: \.self) { Text($0).font(.callout).fixedSize(horizontal: false, vertical: true) }
        }
        planCard(s, r)
    }

    private func planCard(_ s: GameState, _ r: LaunchRecord) -> some View {
        Card {
            CardHeader("The plan", symbol: r.plan.strategy.symbol, subtitle: "\(r.plan.summary) · launched at #\(r.rank) · brand \(r.brandGain >= 0 ? "+" : "")\(Fmt.trim(r.brandGain, 1))\(r.cost > 0 ? " · cost \(Fmt.money(r.cost))" : "")")
            Text("Aimed at \(Launches.goal(r.plan.strategy).text).").font(.callout).foregroundStyle(.secondary)
        }
    }

    private func section<C: View>(_ title: String, symbol: String, tone: Double? = nil, @ViewBuilder _ content: () -> C) -> some View {
        Card {
            HStack {
                Label(title, systemImage: symbol).font(.headline)
                Spacer()
                if let tone {
                    Pill(text: tone >= 0.3 ? "Warm" : (tone <= -0.1 ? "Cool" : "Mixed"), color: tone >= 0.3 ? .green : (tone <= -0.1 ? .orange : .secondary))
                }
            }
            VStack(alignment: .leading, spacing: 6) { content() }
        }
    }
}

/// Every launch, newest first, with its verdict.
struct LaunchHistoryCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    var limit = 30

    var body: some View {
        let list = Array(state.launches.filter { $0.by != "family" }.reversed().prefix(limit))
        Card {
            CardHeader("Launch history", symbol: "paperplane.fill", subtitle: "Each launch's plan and its report, a week after release.")
            if list.isEmpty {
                Text("No launches yet. Release a model from Models & Serving or a run's results screen, and pick a launch plan.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(list) { r in
                HStack(spacing: 10) {
                    Image(systemName: r.plan.strategy.symbol).foregroundStyle(.secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.modelName).font(.callout.weight(.semibold))
                        Text("\(r.date.gameShort) · \(r.plan.summary) · #\(r.rank)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let rep = r.report {
                        Pill(text: rep.verdictTitle, color: rep.verdictColor, symbol: rep.verdictSymbol)
                    } else {
                        Pill(text: "Report \(GameCalendar.addDays(r.date, 7).gameShort)", color: .secondary, symbol: "clock")
                    }
                    Button("Report") { store.launchReportID = r.id }.controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
