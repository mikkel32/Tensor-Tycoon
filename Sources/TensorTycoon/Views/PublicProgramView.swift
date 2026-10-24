import SwiftUI

/// The government career's operating screen: appropriations, measurable missions, oversight and promotion.
struct PublicProgramView: View {
    @Environment(GameStore.self) private var store
    @State private var renegotiating: PublicMission?
    @State private var auditLimit = 10

    var body: some View {
        let s = store.game
        let p = s.publicProgram
        Page(title: "Public AI Programme", subtitle: "Build national AI capability through measured delivery, appropriated funding and democratic oversight.", screen: .publicProgram) {
            if !s.isPublicProgram {
                Card {
                    EmptyStateView(symbol: "building.columns", title: "No public programme",
                                   message: "Choose the Government AI branch origin when founding a new game.",
                                   actionTitle: "Back to Dashboard") { store.open(.dashboard) }
                }
            } else {
                HeroBanner(image: "gov_capitol", height: 170) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(PublicProgram.levelNames[clamp(p.level, 1, 4)], systemImage: "building.columns.fill").font(.title.weight(.bold))
                            Text("\(p.mandate.title) · \(s.companyName) · director \(s.founderName)").font(.callout).opacity(0.9)
                            Text("No equity, no venture rounds and no IPO: public value is the operating objective.").font(.caption).opacity(0.78)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Public-service victory").font(.caption).opacity(0.8)
                            Text("\(Int(Victory.progress(.publicService, s) * 100))%").font(TypeRamp.bannerMetric)
                            Text("\(p.completedMissions)/12 missions · oversight \(Int(p.oversight))/75 · safety \(Int(s.safetyScore))/70").font(.caption2).opacity(0.8)
                        }
                    }
                }

                HowItWorksCard(state: s)

                CardGrid(minWidth: 270, maxColumns: 4) {
                    Card {
                        CardHeader("Annual authorisation", symbol: "banknote.fill", subtitle: "Before quarterly performance adjustments")
                        Text(Fmt.money(PublicProgram.authorisedBudget(s))).font(.title2.weight(.bold).monospacedDigit())
                        SpecRow(label: "Next estimated tranche", value: Fmt.money(PublicProgram.nextTranche(s)))
                        SpecRow(label: "Current reserves", value: Fmt.money(s.cash))
                        if let last = p.lastTranche {
                            Text("Next quarterly review around \(GameCalendar.addDays(last, 90).gameShort). Large reserves, weak oversight and probation reduce releases.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Card {
                        CardHeader("Oversight confidence", symbol: "checkmark.shield.fill", subtitle: p.probation ? "Programme on probation" : "Delivery and accountability")
                        HStack {
                            Text("\(Int(p.oversight))/100").font(.title2.weight(.bold).monospacedDigit())
                            Spacer()
                            if p.probation { Pill(text: "Probation", color: .red) } else { Pill(text: "Active oversight", color: .green) }
                        }
                        Meter(value: p.oversight / 100, tint: p.oversight >= 60 ? .green : p.oversight >= 35 ? .orange : .red, height: 9)
                        Text("Safety, delivery streaks, cash, public trust and transparency move confidence. Reviews begin below 45.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Card {
                        CardHeader("Delivery record", symbol: "checklist.checked", subtitle: "Results payments and culture points come from completed missions")
                        Text("\(p.completedMissions) delivered").font(.title2.weight(.bold))
                        SpecRow(label: "Missed deadlines", value: "\(p.failedMissions)")
                        SpecRow(label: "Current streak", value: "\(p.deliveryStreak)")
                        Text("Two missions are active at once. Renegotiation costs 3 oversight and has a 45-day cooldown.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Card {
                        CardHeader("Programme actions", symbol: "slider.horizontal.3")
                        Button("Publish transparency report", systemImage: "doc.text.magnifyingglass") {
                            store.act("Transparency report published") { $0.publishPublicTransparency() }
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Every 60 days. Costs programme funds; improves oversight and public trust.")
                        Button("Ask for funding", systemImage: "hand.raised.fill") { store.open(.publicFunding) }
                            .help("Once a quarter, on Funding & Commissions: the committee pays for the progress you've made since your last request.")
                        Button("Agency orders", systemImage: "building.2.fill") { store.open(.publicFunding) }
                            .help("Models built for government agencies, paid to build and to run.")
                        Text(p.lastTransparency.map { "Last transparency report \($0.gameShort)." } ?? "No transparency report published yet.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Card {
                    CardHeader(title: "Active public missions", symbol: "target", subtitle: "Progress is measured from the live simulation, not clicked through") {
                        Pill(text: "\(p.missions.filter { $0.status == .active }.count)/\(PublicProgram.activeTarget) active", color: .purple)
                    }
                    let active = p.missions.filter { $0.status == .active }
                    if active.isEmpty { Text("New missions will be issued on the next simulation day.").foregroundStyle(.secondary) }
                    ForEach(active) { mission in
                        let measured = PublicProgram.measure(mission, s)
                        let days = GameCalendar.daysBetween(s.date, mission.due)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .top) {
                                Image(systemName: mission.kind.symbol).font(.title3).foregroundStyle(.purple).frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mission.title).font(.callout.weight(.semibold))
                                    Text(mission.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(Fmt.money(mission.reward)).font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(.green)
                                    Text(days >= 0 ? "\(days) days left · due \(mission.due.gameShort)" : "Overdue")
                                        .font(.caption2).foregroundStyle(days < 30 ? .orange : .secondary)
                                }
                            }
                            HStack {
                                Meter(value: measured.progress, tint: measured.progress >= 0.75 ? .green : .purple, height: 8)
                                Text("\(Fmt.trim(max(0, measured.value), 1)) / \(Fmt.trim(mission.target, 1))")
                                    .font(.caption.monospacedDigit()).frame(width: 90, alignment: .trailing)
                                Button("Renegotiate") { renegotiating = mission }.buttonStyle(.link).font(.caption)
                            }
                        }
                        .padding(11)
                        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 10))
                    }
                }

                Card {
                    CardHeader("Mandate progression", symbol: "stairs", subtitle: "Promotions expand authorisation and add public compute and facility support")
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(1...4, id: \.self) { level in
                            VStack(alignment: .leading, spacing: 5) {
                                Label("Level \(level)", systemImage: level <= p.level ? "checkmark.seal.fill" : "circle")
                                    .font(.caption.weight(.semibold)).foregroundStyle(level <= p.level ? .green : .secondary)
                                Text(PublicProgram.levelNames[level]).font(.callout.weight(.semibold))
                                if level == 1 {
                                    Text("Founding pilot").font(.caption2).foregroundStyle(.secondary)
                                } else {
                                    Text("\(PublicProgram.promotionThresholds[level - 1]) missions · oversight \([0, 0, 55, 60, 65][level])+ · safety \([0, 0, 50, 55, 60][level])+")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Text("Budget ×\(Fmt.trim(PublicProgram.budgetMultipliers[level - 1], 2))").font(.caption2).foregroundStyle(.tertiary)
                            }
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(level == p.level ? Color.purple.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 9))
                        }
                    }
                }

                let closed = p.missions.filter { $0.status != .active }.sorted { ($0.closed ?? $0.due) > ($1.closed ?? $1.due) }
                if !closed.isEmpty {
                    Card {
                        CardHeader("Mission record", symbol: "archivebox.fill", subtitle: "Latest closed and replaced mandates")
                        ForEach(closed.prefix(8)) { mission in
                            HStack {
                                Image(systemName: mission.status == .completed ? "checkmark.circle.fill" : mission.status == .failed ? "xmark.octagon.fill" : "arrow.triangle.2.circlepath")
                                    .foregroundStyle(mission.status == .completed ? .green : mission.status == .failed ? .red : .secondary)
                                Text(mission.title).font(.callout)
                                Spacer()
                                Text(mission.status == .completed ? "Delivered" : mission.status == .failed ? "Missed" : "Replaced")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text((mission.closed ?? mission.due).gameShort).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Card {
                    CardHeader(title: "Public audit trail", symbol: "doc.plaintext.fill", subtitle: "Bounded programme history, newest first") {
                        if p.history.count > 10 {
                            Button(auditLimit >= p.history.count ? "Show fewer" : "Show all") { auditLimit = auditLimit >= p.history.count ? 10 : p.history.count }
                                .buttonStyle(.link)
                        }
                    }
                    ForEach(p.history.prefix(auditLimit)) { record in
                        HStack(alignment: .top) {
                            Image(systemName: record.good == true ? "checkmark.circle.fill" : record.good == false ? "exclamationmark.circle.fill" : "circle")
                                .foregroundStyle(record.good == true ? .green : record.good == false ? .orange : .secondary)
                            Text(record.text).font(.caption)
                            Spacer()
                            Text(record.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Renegotiate \(renegotiating?.title ?? "mission")?", isPresented: Binding(get: { renegotiating != nil }, set: { if !$0 { renegotiating = nil } }), titleVisibility: .visible) {
            Button("Renegotiate · oversight −3") {
                if let mission = renegotiating { store.act("Replacement mission issued") { $0.rerollPublicMission(mission.id) } }
                renegotiating = nil
            }
            Button("Keep mission", role: .cancel) { renegotiating = nil }
        } message: {
            Text("The current mission is replaced. This has a 45-day cooldown and requires at least 12 oversight confidence.")
        }
    }
}

/// 3.10: the whole loop on one card, so a new director knows what to do first.
private struct HowItWorksCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let p = s.publicProgram
        let missions = p.missions.filter { $0.status == .active }
        Card {
            CardHeader("How your programme works", symbol: "questionmark.circle.fill", subtitle: "You don't raise money or answer to investors: you deliver, and the government pays")
            EqualColumns(minWidth: 210, spacing: 12, maxColumns: 4) {
                step(1, "calendar", .blue, "Budget every quarter",
                     "\(Fmt.money(PublicProgram.nextTranche(s))) arrives \(p.lastTranche.map { "on \(GameCalendar.addDays($0, 90).gameShort)" } ?? "each quarter"). Spend it on people, chips and training runs.", nil)
                step(2, "target", .purple, "Deliver missions",
                     missions.isEmpty ? "Two missions are issued at a time." : "Now: " + missions.map(\.title).joined(separator: "; ") + ". Each pays on delivery and counts toward promotion.", nil)
                step(3, "hand.raised.fill", .green, "Ask for more money",
                     "Once a quarter, show the committee your progress. Your case today: \(Int(PublicFunding.score(s)))/100.", ("Funding requests", .publicFunding))
                step(4, "building.2.fill", .orange, "Build for agencies",
                     Commissions.open(s).isEmpty && Commissions.active(s).isEmpty ? "Ministries order models made for them; the first order arrives soon." : "\(Commissions.open(s).count) waiting, \(Commissions.active(s).count) being built.", ("Agency orders", .publicFunding))
            }
        }
    }

    private func step(_ n: Int, _ symbol: String, _ tint: Color, _ title: String, _ text: String, _ link: (String, Screen)?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(n)").font(.callout.weight(.bold)).foregroundStyle(.white).frame(width: 24, height: 24).background(tint, in: .circle)
                Label(title, systemImage: symbol).font(.callout.weight(.semibold)).foregroundStyle(tint)
            }
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let link { Button(link.0) { store.open(link.1) }.buttonStyle(.link).font(.caption) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

private extension PublicMissionKind {
    var symbol: String {
        switch self {
        case .train: "chart.line.downtrend.xyaxis"
        case .release: "paperplane.fill"
        case .evaluate: "checklist.checked"
        case .research: "lightbulb.fill"
        case .hire: "person.3.fill"
        case .openWeights: "lock.open.fill"
        case .safety: "checkmark.shield.fill"
        case .security: "lock.shield.fill"
        }
    }
}
