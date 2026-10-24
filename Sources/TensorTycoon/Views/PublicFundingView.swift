import SwiftUI

/// 3.10: a government branch's money in one place: where it comes from, the case for more, and models built for the
/// agencies that order them.
struct PublicFundingView: View {
    @Environment(GameStore.self) private var store
    @State private var asking: FundingAsk?

    var body: some View {
        let s = store.game
        Page(title: "Funding & Commissions", subtitle: "Ask the committee for money by showing your progress, and build models that government agencies order and pay for.", screen: .publicFunding) {
            if !s.isPublicProgram {
                Card {
                    EmptyStateView(symbol: "banknote", title: "No public programme",
                                   message: "Choose the Government AI branch origin when founding a new game.",
                                   actionTitle: "Back to Dashboard") { store.open(.dashboard) }
                }
            } else {
                hero(s)
                MoneySourcesCard(state: s)
                CardGrid(minWidth: 400, maxColumns: 2) {
                    ProgressCaseCard(state: s)
                    FundingAskCard(state: s, asking: $asking)
                }
                CommissionsCard(state: s)
                RequestHistoryCard(state: s)
            }
        }
        .confirmationDialog(asking.map { "Ask for a \($0.title.lowercased())?" } ?? "", isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }), titleVisibility: .visible) {
            if let ask = asking {
                let o = PublicFunding.outcome(ask, s)
                Button("Ask for \(Fmt.money(o.amount))") {
                    store.act("Funding approved") { $0.requestPublicFunding(ask) }
                    asking = nil
                }
            }
            Button("Not yet", role: .cancel) { asking = nil }
        } message: {
            if let ask = asking {
                let o = PublicFunding.outcome(ask, s)
                Text("On a case of \(Int(PublicFunding.score(s)))/100 the committee approves \(Fmt.pct(o.fraction, decimals: 0)): \(Fmt.money(o.amount)) now\(o.raise > 0 ? " and \(Fmt.pct(o.raise, decimals: 0)) more base budget every year" : ""). The next request can go in \(PublicFunding.cooldownDays) days later, judged on what you deliver from now on.")
            }
        }
    }

    private func hero(_ s: GameState) -> some View {
        let p = s.publicProgram
        let runway = Treasury.runwayMonths(s)
        return HeroBanner(image: "gov_capitol", height: 150) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Funding & Commissions", systemImage: "banknote.fill").font(.title.weight(.bold))
                    Text("\(PublicProgram.levelNames[clamp(p.level, 1, 4)]) · \(p.mandate.title) · \(Fmt.money(p.totalReceived)) received so far").font(.callout).opacity(0.9)
                }
                Spacer()
                HStack(spacing: 22) {
                    heroMetric("Annual budget", Fmt.money(PublicProgram.authorisedBudget(s)))
                    heroMetric("Reserves", Fmt.money(s.cash))
                    heroMetric("Runway", runway.map { $0 > 36 ? "3+ years" : "\(Int($0)) months" } ?? "Self-funding")
                }
            }
        }
    }

    private func heroMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title).font(.caption).opacity(0.8)
            Text(value).font(.title2.weight(.bold).monospacedDigit())
        }
    }
}

// MARK: - Where the money comes from

private struct MoneySourcesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let p = s.publicProgram
        let missions = p.missions.filter { $0.status == .active }
        let service = Commissions.inService(s).reduce(0) { $0 + $1.serviceYearly }
        Card {
            CardHeader("Where the money comes from", symbol: "arrow.down.circle.fill", subtitle: "Four sources. Two are automatic; two you earn.")
            EqualColumns(minWidth: 210, spacing: 12, maxColumns: 4) {
                source("1", "calendar", .blue, "Quarterly budget", "Automatic",
                       "\(Fmt.money(PublicProgram.nextTranche(s))) arrives \(p.lastTranche.map { "on \(GameCalendar.addDays($0, 90).gameShort)" } ?? "each quarter"). Less if oversight is weak or reserves pile up.")
                source("2", "target", .purple, "Mission payments", "Automatic",
                       missions.isEmpty ? "New missions arrive soon." : "\(Fmt.money(missions.reduce(0) { $0 + $1.reward })) waiting on \(missions.count) active mission\(missions.count == 1 ? "" : "s"), paid the day each is met.",
                       action: ("Missions", .publicProgram))
                source("3", "hand.raised.fill", .green, "Funding requests", PublicFunding.readyOn(s).map { "Next \($0.gameShort)" } ?? "Ready now",
                       "Once a quarter, ask for more. The committee pays for progress: research, models, missions and agency work since your last request.")
                source("4", "building.2.fill", .orange, "Agency commissions", "\(Commissions.inService(s).count) in service",
                       "Agencies order models built for them: paid to build, then \(service > 0 ? "\(Fmt.money(service)) a year" : "a yearly fee") to run.\(Commissions.open(s).isEmpty ? "" : " \(Commissions.open(s).count) order\(Commissions.open(s).count == 1 ? "" : "s") waiting.")")
            }
        }
    }

    private func source(_ n: String, _ symbol: String, _ tint: Color, _ title: String, _ status: String, _ text: String, action: (String, Screen)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(tint.opacity(0.18)).frame(width: 30, height: 30)
                    Image(systemName: symbol).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(n). \(title)").font(.callout.weight(.semibold))
                    Text(status).font(.caption2.weight(.medium)).foregroundStyle(tint)
                }
            }
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let action { Button(action.0) { store.open(action.1) }.buttonStyle(.link).font(.caption) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

// MARK: - The case for more money

private struct ProgressCaseCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let score = PublicFunding.score(s)
        let tint: Color = score >= 80 ? .green : score >= 55 ? .teal : score >= 30 ? .orange : .red
        Card {
            CardHeader(title: "Your progress case", symbol: "doc.text.magnifyingglass",
                       subtitle: "What the committee sees since \(s.publicProgram.evidence?.date.gameShort ?? "the start"), your last approved request") {
                Text("\(Int(score))/100").font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(tint)
            }
            Meter(value: score / 100, tint: tint, height: 10)
            HStack(spacing: 0) {
                ForEach(FundingAsk.allCases) { ask in
                    Text("\(ask.title) \(Int(ask.bar))").font(.caption2).foregroundStyle(score >= ask.bar ? .green : .secondary)
                        .frame(maxWidth: .infinity, alignment: ask == .modest ? .leading : ask == .moonshot ? .trailing : .center)
                }
            }
            Divider()
            ForEach(PublicFunding.lines(s)) { line in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: line.symbol).foregroundStyle(line.points > 0 ? Color.accentColor : line.points < 0 ? .red : .secondary).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.title).font(.callout.weight(.semibold))
                        Text(line.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(line.points >= 0 ? "+" : "")\(Int(line.points.rounded())) / \(Int(line.max))")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(line.points > 0 ? .green : line.points < 0 ? .red : .secondary)
                }
            }
            Text("Research, models, missions and agency deliveries count from your last approved request; standing, safety and stewardship are judged as they are today.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

private struct FundingAskCard: View {
    let state: GameState
    @Binding var asking: FundingAsk?

    var body: some View {
        let s = state
        let ready = PublicFunding.readyOn(s)
        let score = PublicFunding.score(s)
        Card {
            CardHeader("Ask for funding", symbol: "hand.raised.fill",
                       subtitle: ready.map { "The committee hears one request a quarter: next on \($0.gameShort)" } ?? "The committee will hear a request today")
            ForEach(FundingAsk.allCases) { ask in
                let o = PublicFunding.outcome(ask, s)
                let full = PublicProgram.authorisedBudget(s) * ask.oneOff
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: ask.symbol).font(.title2).foregroundStyle(o.fraction >= 1 ? .green : o.fraction > 0 ? .orange : .secondary).frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ask.title).font(.callout.weight(.semibold))
                        Text("\(Fmt.money(full)) now\(ask.raise > 0 ? " · base budget +\(Fmt.pct(ask.raise, decimals: 0)) for good" : ""). Full amount at a case of \(Int(ask.bar)).")
                            .font(.caption).foregroundStyle(.secondary)
                        verdict(ask, o, score: score)
                    }
                    Spacer()
                    Button("Ask") { asking = ask }
                        .buttonStyle(.borderedProminent)
                        .disabled(ready != nil || o.fraction <= 0)
                        .help(ready != nil ? "One request a quarter." : o.fraction <= 0 ? "Build a stronger case first." : "Ask for \(Fmt.money(o.amount)).")
                }
                .padding(10)
                .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
            }
            Text("No gamble: the committee's answer is shown before you ask. A partial case gets part of the money; each approval resets the record, so the next request needs new progress.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func verdict(_ ask: FundingAsk, _ o: (fraction: Double, amount: Double, raise: Double), score: Double) -> some View {
        if o.fraction >= 1 {
            Pill(text: "Approved in full: \(Fmt.money(o.amount))", color: .green, symbol: "checkmark.seal.fill")
        } else if o.fraction > 0 {
            Pill(text: "\(Fmt.pct(o.fraction, decimals: 0)) approved: \(Fmt.money(o.amount)) · \(Int(ask.bar - score)) points short of full", color: .orange, symbol: "circle.lefthalf.filled")
        } else {
            Pill(text: "Needs \(Int(ask.bar - PublicFunding.partialBand - score)) more points to be considered", color: .secondary, symbol: "xmark.circle")
        }
    }
}

// MARK: - Agency commissions

private struct CommissionsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let offers = Commissions.open(s)
        let active = Commissions.active(s)
        let service = Commissions.inService(s)
        let record = s.publicProgram.commissions.filter { ![.offered, .active, .inService].contains($0.status) }.reversed()
        Card {
            CardHeader(title: "Agency commissions", symbol: "building.2.fill",
                       subtitle: "Government agencies order models built just for them. Accept an order, train a model that meets its bar, hand it over.") {
                Pill(text: "\(s.publicProgram.commissionsDelivered) delivered", color: .green)
            }
            if offers.isEmpty && active.isEmpty && service.isEmpty {
                Text("No orders yet. Agencies send one about every \(Commissions.offerEveryDays) days; they arrive in the news and here.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if !offers.isEmpty {
                section("Orders waiting for an answer", "tray.and.arrow.down.fill")
                ForEach(offers) { c in OfferRow(state: s, commission: c) }
            }
            if !active.isEmpty {
                section("Building now", "hammer.fill")
                ForEach(active) { c in ActiveCommissionRow(state: s, commission: c) }
            }
            if !service.isEmpty {
                section("In service", "checkmark.seal.fill")
                ForEach(service) { c in
                    HStack(spacing: 10) {
                        Image(systemName: c.symbol).foregroundStyle(.green).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(c.modelName) at the \(c.agency)").font(.callout.weight(.semibold))
                            Text("\(c.title) · \(Fmt.money(c.serviceYearly))/yr until \(c.serviceUntil?.gameShort ?? "—") · \(Fmt.money(c.paid)) paid so far\(c.internalOnly ? " · keep it internal" : "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            if !record.isEmpty {
                section("Record", "archivebox.fill")
                ForEach(Array(record.prefix(6))) { c in
                    HStack {
                        Image(systemName: c.status == .completed ? "checkmark.circle.fill" : c.status == .failed || c.status == .cancelled ? "xmark.octagon.fill" : "minus.circle")
                            .foregroundStyle(c.status == .completed ? .green : c.status == .failed || c.status == .cancelled ? .red : .secondary)
                        Text("\(c.agency): \(c.title)").font(.caption)
                        Spacer()
                        Text(statusText(c.status)).font(.caption2).foregroundStyle(.secondary)
                        Text((c.closed ?? c.offered).gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func section(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
    }

    private func statusText(_ st: CommissionStatus) -> String {
        switch st {
        case .completed: "Service complete"
        case .failed: "Missed the deadline"
        case .cancelled: "Contract ended"
        case .declined: "Declined"
        case .expired: "Offer lapsed"
        default: ""
        }
    }
}

/// The bar an order sets, as chips.
private struct RequirementChips: View {
    let commission: AgencyCommission

    var body: some View {
        let c = commission
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) { chips(c) }
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func chips(_ c: AgencyCommission) -> some View {
        Pill(text: "Capability \(Fmt.trim(c.capabilityMin, 2))+", color: .blue, symbol: "cpu")
        Pill(text: "\(c.domain.label) \(Commissions.signed(c.domainEdgeMin))+", color: .purple, symbol: "scope")
        if c.safetyMin > 0 { Pill(text: "Safety \(Int(c.safetyMin))+", color: .green, symbol: "checkmark.shield") }
        if c.needsEvaluation { Pill(text: "Evaluated", color: .teal, symbol: "checklist") }
        if c.internalOnly { Pill(text: "Internal only", color: .orange, symbol: "lock.fill") }
        if c.openWeights { Pill(text: "Open weights", color: .mint, symbol: "lock.open.fill") }
        if c.securityMin > 0 { Pill(text: "SL\(c.securityMin)", color: .red, symbol: "lock.shield") }
    }
}

private struct OfferRow: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let commission: AgencyCommission

    var body: some View {
        let c = commission
        let left = GameCalendar.daysBetween(state.date, c.expires)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: c.symbol).font(.title2).foregroundStyle(.orange).frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(c.agency): \(c.title)").font(.callout.weight(.semibold))
                    Text(c.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.money(c.value)).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(.green)
                    Text("+ \(Fmt.money(c.serviceYearly))/yr for \(c.serviceMonths / 12) years").font(.caption2).foregroundStyle(.secondary)
                }
            }
            RequirementChips(commission: c)
            HStack {
                Text("\(Fmt.money(c.value * Commissions.upfront)) when you accept, the rest on delivery. \(c.deliveryDays) days to deliver a model trained after you accept. Offer open \(max(0, left)) more days.")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Decline") { store.mutate { $0.declineCommission(c.id) } }
                Button("Accept") { store.act("Order accepted") { $0.acceptCommission(c.id) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(Commissions.active(state).count >= Commissions.maxActive)
            }
        }
        .padding(11)
        .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 10))
    }
}

private struct ActiveCommissionRow: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let commission: AgencyCommission

    var body: some View {
        let s = state
        let c = commission
        let days = c.due.map { GameCalendar.daysBetween(s.date, $0) } ?? 0
        let elapsed = 1 - Double(max(0, days)) / Double(max(1, c.deliveryDays))
        let models = Commissions.candidatesModels(c, s)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: c.symbol).font(.title2).foregroundStyle(.purple).frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(c.agency): \(c.title)").font(.callout.weight(.semibold))
                    Text("\(Fmt.money(c.value * (1 - Commissions.upfront))) on delivery, then \(Fmt.money(c.serviceYearly))/yr").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(days >= 0 ? "\(days) days left" : "Overdue").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(days < 45 ? .orange : .secondary)
            }
            Meter(value: elapsed, tint: days < 45 ? .orange : .purple, height: 6)
            RequirementChips(commission: c)
            if models.isEmpty {
                HStack {
                    Text("No model trained since you accepted. Design one aimed at \(c.domain.label.lowercased()) in the Model Lab; a specialist fork or post-training pass in \(c.domain.label.lowercased()) helps it clear the bar.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Model Lab") { store.open(.lab) }
                    Button("Families") { store.open(.families) }
                }
            } else {
                ForEach(models.prefix(4)) { m in
                    let checks = Commissions.checks(c, m, s)
                    let ok = Commissions.qualifies(c, m, s)
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(ok ? .green : .secondary)
                        Text(m.name).font(.callout.weight(.medium)).frame(width: 150, alignment: .leading).lineLimit(1)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(checks) { ch in
                                    Pill(text: "\(ch.label): \(ch.detail)", color: ch.met ? .green : .red, symbol: ch.met ? "checkmark" : "xmark")
                                }
                            }
                            .font(.caption2)
                        }
                        Button("Deliver") { store.act("Model delivered") { $0.deliverCommission(c.id, modelID: m.id) } }
                            .buttonStyle(.borderedProminent)
                            .disabled(!ok)
                    }
                }
            }
        }
        .padding(11)
        .background(Color.purple.opacity(0.07), in: .rect(cornerRadius: 10))
    }
}

private struct RequestHistoryCard: View {
    let state: GameState

    var body: some View {
        let requests = state.publicProgram.requests
        if !requests.isEmpty {
            Card {
                CardHeader("Funding history", symbol: "clock.arrow.circlepath", subtitle: "Every request the committee approved")
                ForEach(requests) { r in
                    HStack {
                        Image(systemName: r.ask.symbol).foregroundStyle(r.fraction >= 1 ? .green : .orange)
                        Text("\(r.ask.title) · case \(Int(r.score))").font(.callout)
                        Spacer()
                        Text(Fmt.money(r.amount)).font(.callout.monospacedDigit().weight(.semibold))
                        if r.raise > 0 { Text("+\(Fmt.pct(r.raise, decimals: 0)) budget").font(.caption).foregroundStyle(.secondary) }
                        Text(r.date.gameShort).font(.caption2).foregroundStyle(.tertiary).frame(width: 80, alignment: .trailing)
                    }
                }
            }
        }
    }
}
