import SwiftUI

// MARK: - 3.5: Advanced Projects — government contracts, classified facilities and clearances

enum AdvancedTab: String, CaseIterable, Identifiable {
    case market = "Marketplace"
    case programmes = "Programmes"
    case facilities = "Facilities & Clearances"
    case agencies = "Agencies & Record"
    case discoveries = "Discoveries & Patents"
    var id: String { rawValue }
}

struct AdvancedProjectsView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: AdvancedTab = .market

    var body: some View {
        let s = store.game
        let a = s.advanced
        let active = a.programmes.filter { $0.status == .active }
        let backlog = active.reduce(0.0) { $0 + max(0, $1.value - $1.contractRevenue) }
        let lifetime = a.programmes.reduce(0.0) { $0 + $1.contractRevenue }
        let royalties = a.programmes.reduce(0.0) { $0 + $1.royalties } + a.discoveries.reduce(0.0) { $0 + $1.lifetime }
        let cleared = a.clearances.filter { $0.level > 0 }.count
        Page(title: "Advanced Projects",
             subtitle: "Government research contracts. Agencies post solicitations; you bid against rival labs, then deliver with cleared people, cleared compute and accredited facilities. Classified work pays in standing and access — and sometimes in discoveries you may or may not be allowed to use.", screen: .advancedProjects) {
            HeroBanner(image: "supercomputer", height: 150) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Advanced Projects division").font(.title2.weight(.bold))
                    Text("\(active.count) active programme\(active.count == 1 ? "" : "s") · \(a.solicitations.filter { $0.bid == nil }.count) open solicitations · home: \(HQ.country(s).name) (\(AdvancedProjects.homeRegion(s).title))")
                        .font(.callout)
                    PhotoPill(text: "Illustrative photo: Sierra supercomputer, LLNL", symbol: "photo")
                }
            }
            KPIRow {
                StatTile(title: "Active programmes", value: "\(active.count)", detail: active.isEmpty ? "Win a contract on the marketplace" : "\(Fmt.money(backlog)) still to bill",
                         symbol: "building.columns.fill", tint: .indigo)
                StatTile(title: "Contract payments", value: Fmt.money(lifetime), detail: paymentsDetail(royalties),
                         symbol: "dollarsign.circle.fill", tint: .green)
                StatTile(title: "Cleared staff", value: "\(cleared)", detail: clearedDetail(a),
                         symbol: "person.badge.shield.checkmark.fill", tint: .teal)
                StatTile(title: "Cleared compute", value: "\(Fmt.int(Int(AdvancedProjects.computeCapacity(s, atLeast: 1)))) H100e", detail: computeDetail(s),
                         symbol: "lock.rectangle.stack.fill", tint: .orange)
            }
            FoundingContractCard(state: s)   // 3.9: the founding award
            SectionTabs(selection: $tab, options: AdvancedTab.allCases)
            switch tab {
            case .market: MarketplaceSection(state: s)
            case .programmes: ProgrammesSection(state: s)
            case .facilities: FacilitiesSection(state: s)
            case .agencies: AgenciesSection(state: s)
            case .discoveries: DiscoveriesSection(state: s)
            }
        }
    }

    private func paymentsDetail(_ royalties: Double) -> String {
        var t = "Booked as contract revenue"
        if royalties > 0 { t += " · " + Fmt.money(royalties) + " of royalties as licensing" }
        return t
    }

    private func clearedDetail(_ a: AdvancedState) -> String {
        var t = "\(a.clearances.filter { $0.ready != nil }.count) investigations under way"
        if a.lastPremium > 0 { t += " · " + Fmt.money(a.lastPremium) + "/mo premium" }
        return t
    }

    private func computeDetail(_ s: GameState) -> String {
        let desks = Fmt.int(Int(AdvancedProjects.seatCapacity(s, atLeast: 1)))
        let monthly = s.advanced.lastOpex + AdvancedProjects.facilityPowerDay(s) * 30.4
        return "\(desks) secure desks · \(Fmt.money(monthly))/mo with power"
    }
}

// MARK: - Shared bits

enum AdvStyle {
    static func color(_ c: Classification) -> Color {
        switch c {
        case .unclassified: .green
        case .controlled: .blue
        case .secret: .orange
        case .topSecret: .red
        }
    }

    static func color(_ t: ContractType) -> Color {
        switch t {
        case .fixedPrice: .purple
        case .costPlus: .teal
        case .grant: .mint
        case .prize: .yellow
        }
    }

    static func defaultPrice(_ t: ContractType) -> Double { t == .costPlus ? 0.08 : 0.95 }
}

private struct RequirementLine: View {
    let ok: Bool
    let text: String

    var body: some View {
        Label(text, systemImage: ok ? "checkmark.circle.fill" : "xmark.circle")
            .font(.caption)
            .foregroundStyle(ok ? Color.secondary : Theme.warning)
            .accessibilityLabel("\(ok ? "Met" : "Not met"): \(text)")
    }
}

/// The checklist behind a solicitation: domain bars, research, people, compute, facility and security.
private struct RequirementsList: View {
    let sol: Solicitation
    let state: GameState

    var body: some View {
        let s = state
        let mine = AdvancedProjects.playerScores(s)
        VStack(alignment: .leading, spacing: 3) {
            ForEach(sol.domains.sorted(by: { $0.key < $1.key }), id: \.key) { k, bar in
                let d = CapDomain(rawValue: k)
                let have = d.flatMap { dd in mine.map { $0[dd] } } ?? 0
                RequirementLine(ok: have >= bar, text: "\(d?.label ?? k) \(Int(bar.rounded())) on your best model (you: \(mine == nil ? "—" : "\(Int(have.rounded()))"))")
            }
            ForEach(sol.research, id: \.self) { r in
                RequirementLine(ok: s.researched.contains(r), text: "Research: \(ResearchCatalog.byID[r]?.name ?? r)")
            }
            let ready = AdvancedProjects.staffReadiness(sol, s)
            RequirementLine(ok: ready >= 1, text: "Staff: " + sol.staff.sorted(by: { $0.key < $1.key }).map { "\($0.value) \(Role(rawValue: $0.key)?.plural.lowercased() ?? $0.key)" }.joined(separator: ", ")
                + (sol.level > .unclassified ? " cleared \(sol.level.clearance)" : "") + " (\(Fmt.pct(ready, decimals: 0)) available)")
            if sol.level > .unclassified {
                let free = AdvancedProjects.freeCompute(s, sol.level)
                RequirementLine(ok: free >= sol.computeH100e, text: "\(Fmt.int(Int(sol.computeH100e))) H100e in a facility accredited \(AdvancedProjects.facilityLevelName(sol.classification)) or higher (free: \(Fmt.int(Int(free))))")
                RequirementLine(ok: AdvancedProjects.freeSeats(s, sol.level) >= Double(sol.staffTotal), text: "\(sol.staffTotal) desks in an accredited secure lab")
                RequirementLine(ok: s.security.rawValue >= sol.level.requiredSL, text: "Weight security SL\(sol.level.requiredSL) (you: SL\(s.security.rawValue))")
            } else {
                RequirementLine(ok: true, text: "\(Fmt.int(Int(sol.computeH100e))) H100e of cloud compute, billed to the contract")
            }
            if let k = sol.templateDef?.facility {
                let free = AdvancedProjects.facilityFree(s, k, level: sol.level)
                RequirementLine(ok: free >= 1, text: "A \(k.short) accredited \(AdvancedProjects.facilityLevelName(AdvancedProjects.spaceLevel(sol.level))) or higher (free: \(Fmt.int(Int(free))))")
            }
        }
    }
}

/// The earliest a programme could start if you began everything today, track by track, against the agency's deadline.
private struct MobilisationPlanView: View {
    let plan: AdvancedProjects.MobPlan
    var compact = false

    private var verdict: String {
        let months = Fmt.trim(plan.months, 1)
        if !plan.feasible { return "Can't be ready in time: about \(months) months to get ready" }
        if plan.months < 0.05 { return "Ready to start" }
        return plan.tight ? "Tight: about \(months) months to get ready" : "About \(months) months to get ready"
    }

    private var tone: Tone {
        if !plan.feasible { return .bad }
        return plan.tight ? .warning : .good
    }

    private func timing(_ st: AdvancedProjects.MobStep) -> String {
        var t = "\(Fmt.trim(st.months, 1)) mo"
        if st.cost > 0 { t += " · " + Fmt.money(st.cost) }
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                ToneLabel(text: verdict, tone: tone, font: .caption.weight(.semibold))
                Spacer()
                Text("Allowed: \(Fmt.trim(max(0, plan.deadline), 1)) months").font(.caption2).foregroundStyle(.secondary)
            }
            if !compact {
                ForEach(Array(plan.steps.enumerated()), id: \.offset) { _, st in
                    HStack(alignment: .top) {
                        RequirementLine(ok: st.done, text: st.title)
                        Spacer()
                        if !st.done {
                            Text(timing(st)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                if plan.cost > 0 {
                    Text("Getting ready costs about \(Fmt.money(plan.cost)); the tracks run in parallel. Investigations take 75–125% of the usual time and some people can't be cleared, so put forward a spare.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Marketplace

private enum MarketSort: String, CaseIterable, Identifiable {
    case closing = "Closing soon", value = "Value", odds = "Win odds"
    var id: String { rawValue }
}

private struct MarketplaceSection: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var type: ContractType? = nil
    @State private var maxLevel: Classification = .topSecret
    @State private var region: Region? = nil
    @State private var topic: String? = nil
    @State private var biddable = false
    @State private var sort: MarketSort = .closing
    @State private var proposal: Solicitation? = nil

    var body: some View {
        let s = state
        let all = s.advanced.solicitations
        var list = all.filter { sol in
            (type == nil || sol.type == type) && sol.level <= maxLevel && (region == nil || sol.agencyDef?.region == region)
                && (topic == nil || sol.templateDef?.topic == topic)
                && (!biddable || sol.bid != nil || AdvancedProjects.blockers(sol, s).isEmpty)
        }
        switch sort {
        case .closing: list.sort { ($0.closes, $0.id) < ($1.closes, $1.id) }
        case .value: list.sort { $0.ceiling > $1.ceiling }
        case .odds: list.sort { AdvancedProjects.odds($0, s, price: AdvStyle.defaultPrice($0.type)).p > AdvancedProjects.odds($1, s, price: AdvStyle.defaultPrice($1.type)).p }
        }
        return VStack(alignment: .leading, spacing: 14) {
            Card {
                HStack(spacing: 14) {
                    Picker("Type", selection: $type) {
                        Text("All types").tag(ContractType?.none)
                        ForEach(ContractType.allCases) { t in Text(t.title).tag(ContractType?.some(t)) }
                    }
                    .frame(maxWidth: 220)
                    Picker("Up to", selection: $maxLevel) {
                        ForEach(Classification.allCases, id: \.self) { c in Text(c.title).tag(c) }
                    }
                    .frame(maxWidth: 220)
                    Picker("Region", selection: $region) {
                        Text("Everywhere").tag(Region?.none)
                        ForEach(Region.allCases) { r in Text(r.title).tag(Region?.some(r)) }
                    }
                    .frame(maxWidth: 220)
                    Picker("Topic", selection: $topic) {
                        Text("All topics").tag(String?.none)
                        ForEach(Array(Set(AgencyCatalog.templates.map(\.topic))).sorted(), id: \.self) { t in Text(t).tag(String?.some(t)) }
                    }
                    .frame(maxWidth: 240)
                    Picker("Sort", selection: $sort) {
                        ForEach(MarketSort.allCases) { m in Text(m.rawValue).tag(m) }
                    }
                    .frame(maxWidth: 200)
                    Toggle("Only ones I can bid on", isOn: $biddable)
                }
                .font(.callout)
                Text("Agencies post new work at the start of each month, more when they have budget left this year (awards to you and to rival labs draw it down). Bids are decided on the closing date with a seeded roll against the odds shown; rival labs are scored on the models they have at the close, and work you don't bid on goes to one of them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if list.isEmpty {
                Card {
                    EmptyStateView(symbol: "tray", title: all.isEmpty ? "No solicitations yet" : "Nothing matches the filters",
                                   message: all.isEmpty ? "Agencies post work at the start of each month." : "Loosen the filters to see more.")
                }
            }
            LazyVGrid(columns: Theme.columns(min: 420), alignment: .leading, spacing: Theme.gap) {
                ForEach(list) { sol in SolicitationCard(sol: sol, state: s, onPropose: { proposal = sol }) }
            }
            if !s.advanced.bids.isEmpty {
                Card {
                    CardHeader("Recent decisions", symbol: "clock.arrow.circlepath")
                    ForEach(Array(s.advanced.bids.prefix(8).enumerated()), id: \.offset) { _, b in
                        HStack {
                            Image(systemName: b.won ? "checkmark.seal.fill" : "xmark.seal").foregroundStyle(b.won ? Theme.good : .secondary)
                                .accessibilityLabel(b.won ? "Won" : "Lost")
                            Text(b.title).font(.callout)
                            Text(AgencyCatalog.byID[b.agency]?.short ?? b.agency).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(b.won ? "Won at \(Fmt.pct(b.odds, decimals: 0)) odds" : "Lost to \(b.winner) (\(Fmt.pct(b.odds, decimals: 0)))").font(.caption).foregroundStyle(.secondary)
                            Text(b.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .sheet(item: $proposal) { sol in ProposalSheet(solID: sol.id) }
    }
}

private struct SolicitationCard: View {
    @Environment(GameStore.self) private var store
    let sol: Solicitation
    let state: GameState
    let onPropose: () -> Void
    @State private var confirmWithdraw = false

    var body: some View {
        let s = state
        let a = sol.agencyDef
        let price = sol.bid?.price ?? AdvStyle.defaultPrice(sol.type)
        let o = AdvancedProjects.odds(sol, s, price: price)
        Card {
            HStack(alignment: .top) {
                Image(systemName: a?.symbol ?? "building.columns").font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sol.title).font(.headline)
                    Text("\(a?.name ?? sol.agency) · \(a?.homeShort ?? "")").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.money(sol.ceiling)).font(.title3.weight(.semibold).monospacedDigit())
                    Text("\(sol.months) months").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Pill(text: sol.type.title, color: AdvStyle.color(sol.type), symbol: sol.type.symbol)
                Pill(text: sol.level.title, color: AdvStyle.color(sol.level), symbol: "lock.fill")
                Pill(text: sol.ip.short, color: .secondary)
                if sol.followOn { Pill("Follow-on", tone: .good) }
                if sol.phase > 0 { Pill(text: "Phase \(AdvancedProjects.roman(sol.phase))", color: .secondary) }
                if let t = sol.templateDef, !t.topic.isEmpty { Pill(text: t.topic, color: .secondary) }
                if !AdvancedProjects.openToYou(sol, s) { Pill(text: "Not open to you", color: .red, symbol: "nosign") }
            }
            Text(sol.templateDef?.objective ?? "").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            RequirementsList(sol: sol, state: s)
            if sol.level > .unclassified || !o.plan.feasible { MobilisationPlanView(plan: o.plan, compact: true) }
            HStack {
                Text("\(o.rivals.count) rival bid\(o.rivals.count == 1 ? "" : "s") expected · \(sol.basis.label.lowercased()) · closes \(sol.closes.gameShort)")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                if let bid = sol.bid {
                    Label("Bid in: \(sol.type == .costPlus ? "fee \(Fmt.pct(bid.price, decimals: 0))" : (sol.type == .prize ? "entry" : "\(Fmt.pct(bid.price, decimals: 0)) of ceiling")) · odds now \(Fmt.pct(o.p, decimals: 0))",
                          systemImage: "paperplane.fill").font(.callout).foregroundStyle(.blue)
                    Spacer()
                    // 3.9: the proposal cost is sunk, and bidding again pays it again; say so before the bid goes.
                    Button("Withdraw…") { confirmWithdraw = true }.buttonStyle(.link)
                        .confirmationDialog("Withdraw your bid on \(sol.title)?", isPresented: $confirmWithdraw, titleVisibility: .visible) {
                            Button("Withdraw bid", role: .destructive) { store.act("Bid withdrawn") { $0.withdrawProposal(sol.id) } }
                            Button("Keep the bid", role: .cancel) {}
                        } message: {
                            Text("The \(Fmt.money(bid.proposalCost)) you spent writing the proposal is not refunded. Bidding again before it closes on \(sol.closes.gameShort) costs another \(Fmt.money(AdvancedProjects.proposalCost(sol))).")
                        }
                } else {
                    if o.acceptable {
                        OddsBar(probability: o.p, label: "Win odds", good: 0.4, warning: 0.2)
                            .frame(maxWidth: 260)
                    } else {
                        ToneLabel(text: o.blockers.first ?? "Not eligible", tone: .warning, font: .caption).lineLimit(2)
                    }
                    Spacer()
                    Button("Prepare proposal…", action: onPropose).buttonStyle(.borderedProminent).disabled(!o.acceptable)
                }
            }
        }
    }
}

/// The proposal: price, odds and why, the cost breakdown, payments, risks and terms.
private struct ProposalSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let solID: String
    @State private var price: Double = -1

    var body: some View {
        let s = store.game
        if let sol = s.advanced.solicitations.first(where: { $0.id == solID }) {
            content(sol, s)
        } else {
            VStack(spacing: 12) {
                Text("This solicitation has closed.")
                Button("Close") { dismiss() }
            }
            .padding(30)
        }
    }

    @ViewBuilder
    private func content(_ sol: Solicitation, _ s: GameState) -> some View {
        let p = price < 0 ? AdvStyle.defaultPrice(sol.type) : price
        let o = AdvancedProjects.odds(sol, s, price: p)
        let e = AdvancedProjects.estimate(sol)
        let value: Double = {
            switch sol.type {
            case .fixedPrice, .grant: return sol.ceiling * p
            case .costPlus: return sol.estCost * (1 + p)
            case .prize: return sol.ceiling
            }
        }()
        let cashMargin = value - e.cash - e.proposal
        let fullMargin = value - e.total - e.proposal
        let outlook = AdvancedProjects.outlook(sol, s, price: p)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proposal: \(sol.title)").font(.title2.weight(.bold))
                        Text("\(sol.agencyDef?.name ?? sol.agency) · \(sol.type.title) · \(sol.level.title) · \(sol.ip.title)").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                }
                Text(sol.templateDef?.objective ?? "").font(.callout).fixedSize(horizontal: false, vertical: true)
                CardGrid(minWidth: 340, maxColumns: 2) {
                    Card {
                        CardHeader("Your price", symbol: "tag.fill")
                        switch sol.type {
                        case .fixedPrice, .grant:
                            HStack {
                                Text("\(Fmt.pct(p, decimals: 0)) of the \(Fmt.money(sol.ceiling)) ceiling")
                                Spacer()
                                Text(Fmt.money(value)).font(.body.monospacedDigit().weight(.semibold))
                            }
                            Slider(value: Binding(get: { p }, set: { price = ($0 * 100).rounded() / 100 }), in: 0.6...1.0)
                                .accessibilityLabel("Price as a share of the ceiling")
                                .accessibilityValue(Fmt.pct(p, decimals: 0))
                        case .costPlus:
                            HStack {
                                Text("Fee \(Fmt.pct(p, decimals: 0)) on a \(Fmt.money(sol.estCost)) target cost")
                                Spacer()
                                Text(Fmt.money(sol.estCost * p)).font(.body.monospacedDigit().weight(.semibold))
                            }
                            Slider(value: Binding(get: { p }, set: { price = ($0 * 100).rounded() / 100 }), in: 0.02...0.15)
                                .accessibilityLabel("Fee rate")
                                .accessibilityValue(Fmt.pct(p, decimals: 0))
                        case .prize:
                            Text("Prize challenges have no price: the first complete entry takes the \(Fmt.money(sol.ceiling)) purse.").font(.callout)
                        }
                        Divider()
                        OddsBar(probability: o.p, label: "Win odds", good: 0.4, warning: 0.2)
                        ForEach(Array(o.parts.enumerated()), id: \.offset) { _, part in
                            SpecRow(label: part.0, value: Fmt.trim(part.1, 1))
                        }
                        SpecRow(label: "Your score", value: Fmt.trim(o.score, 1))
                        ForEach(Array(o.rivals.enumerated()), id: \.offset) { _, r in
                            SpecRow(label: "Rival: \(r.0)", value: Fmt.trim(r.1, 1))
                        }
                        Text("Odds are your share of exp(score ÷ 5) against the rivals', times the agency's confidence you can do the work (falls fast more than 5 points under the bars), capped at 95%. Evaluation: \(sol.basis.label.lowercased()).")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        ForEach(o.blockers, id: \.self) { b in RequirementLine(ok: false, text: b) }
                    }
                    Card {
                        CardHeader("Cost breakdown", symbol: "list.bullet.rectangle")
                        SpecRow(label: "People (already on payroll)", value: Fmt.money(e.labour))
                        SpecRow(label: e.classified ? "Compute (your cleared facility)" : "Compute (cloud, cash)", value: Fmt.money(e.compute))
                        SpecRow(label: "Materials & test campaigns", value: Fmt.money(e.materials))
                        SpecRow(label: "Compliance & security", value: Fmt.money(e.compliance))
                        SpecRow(label: "Government estimate", value: Fmt.money(sol.estCost))
                        SpecRow(label: "Writing the proposal", value: Fmt.money(e.proposal))
                        Divider()
                        SpecRow(label: "Contract value", value: Fmt.money(value))
                        SpecRow(label: "Cash margin if on plan", value: AdvancedProjects.signed(cashMargin), tone: Tone.sign(cashMargin))
                        SpecRow(label: "Full-cost margin if on plan", value: AdvancedProjects.signed(fullMargin), tone: Tone.sign(fullMargin))
                        Text("Cash margin counts only new spending; full cost also charges your seconded staff and facility running costs.")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                CardGrid(minWidth: 340, maxColumns: 2) {
                    Card {
                        CardHeader("What usually happens", symbol: "chart.line.uptrend.xyaxis")
                        SpecRow(label: "Expected trial failures", value: Fmt.trim(outlook.failures, 1))
                        SpecRow(label: "Expected rework", value: "about \(Fmt.trim(outlook.reworkMonths, 1)) months")
                        SpecRow(label: "Expected cost growth", value: "+\(Fmt.pct(outlook.growth, decimals: 0))", tone: outlook.growth > 0.15 ? .warning : nil)
                        SpecRow(label: "Cash margin at expected growth", value: AdvancedProjects.signed(outlook.cashMargin), tone: Tone.sign(outlook.cashMargin))
                        SpecRow(label: "Full-cost margin at expected growth", value: AdvancedProjects.signed(outlook.fullMargin), tone: Tone.sign(outlook.fullMargin))
                        if sol.type == .grant { SpecRow(label: "Your share of the full cost (co-funding)", value: Fmt.pct(outlook.costShare, decimals: 0)) }
                        Text(riskProfile(sol.type, outlook))
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Card {
                        CardHeader("Getting ready", symbol: "figure.walk.departure")
                        MobilisationPlanView(plan: o.plan)
                    }
                }
                CardGrid(minWidth: 340, maxColumns: 2) {
                    Card {
                        CardHeader("Payment schedule", symbol: "calendar")
                        if sol.type == .costPlus {
                            Text("Costs reimbursed monthly up to \(Fmt.money(sol.estCost * 1.25)); the fee is paid at milestones:").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(Array(AdvancedProjects.milestones(sol.type).enumerated()), id: \.offset) { _, m in
                            SpecRow(label: m.0.title, value: "\(Fmt.pct(m.1, decimals: 0)) · \(Fmt.money((sol.type == .costPlus ? sol.estCost * p : value) * m.1))")
                        }
                    }
                    Card {
                        CardHeader("Requirements", symbol: "checklist")
                        RequirementsList(sol: sol, state: s)
                    }
                }
                Card {
                    CardHeader("Risks & terms", symbol: "exclamationmark.triangle")
                    Text(sol.type.risk).font(.callout).fixedSize(horizontal: false, vertical: true)
                    SpecRow(label: "Technical risk per trial", value: "\(Fmt.pct(sol.risk, decimals: 0)) base (lower with a bigger margin over the bars)")
                    SpecRow(label: "IP", value: sol.ip.title)
                    SpecRow(label: "Publication", value: sol.level.publication)
                    SpecRow(label: "Agents", value: sol.level.agentsAllowed ? "Agent swarms may help" : "Not allowed on classified networks")
                    ForEach(AdvancedProjects.conditions(sol), id: \.self) { c in Label(c, systemImage: "doc.text").font(.caption).foregroundStyle(.secondary) }
                    if let t = sol.templateDef {
                        SpecRow(label: "Leaves behind", value: t.reward)
                        ForEach(t.legacy.map { $0.describe() }, id: \.self) { l in Label("Lasting: \(l)", systemImage: "arrow.forward.circle").font(.caption).foregroundStyle(.secondary) }
                        if let k = t.facility { SpecRow(label: "Needs", value: "\(k.title) (one \(k.short))") }
                        if t.discovery != nil {
                            SpecRow(label: "Discovery", value: sol.level >= .secret ? "Patented under a secrecy order; you choose later whether to seek approval, rebuild, license, partner, retain it internally or keep it classified" : "Patented and published; licensees pay royalties")
                        }
                    }
                }
                Button {
                    if store.act("Proposal submitted", { $0.submitProposal(sol.id, price: p) }) { dismiss() }
                } label: {
                    Label("Submit proposal (\(Fmt.money(e.proposal)))", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!o.acceptable)
            }
            .padding(22)
        }
        .frame(width: 920, height: 760)
    }

    /// Who carries an overrun under each contract type, in numbers from the outlook.
    private func riskProfile(_ t: ContractType, _ o: AdvancedProjects.Outlook) -> String {
        switch t {
        case .fixedPrice: return "Fixed price: every overrun is yours. Expected failures and cost growth move the full-cost margin to \(AdvancedProjects.signed(o.fullMargin))."
        case .costPlus: return "Cost-plus: overruns are reimbursed up to 125% of the target cost and your fee is fixed, so growth costs you little until the ceiling — and audits can disallow part of what you bill."
        case .grant: return "Grant: it pays about 85% of the government's estimate, so you co-fund the rest — about \(Fmt.pct(o.costShare, decimals: 0)) of the full cost at the expected growth. Losing money on a full-cost basis is the price of keeping most of the rights."
        case .prize: return "Prize: nothing is paid unless you deliver first; a rival or an outside team may beat you, and the challenge closes at twice its planned length."
        }
    }
}

// MARK: - Programmes

private struct ProgrammesSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let active = s.advanced.programmes.filter { $0.status == .active }
        let done = s.advanced.programmes.filter { $0.status != .active }.sorted { ($0.ended ?? $0.awarded) > ($1.ended ?? $1.awarded) }
        VStack(alignment: .leading, spacing: 16) {
            if active.isEmpty {
                Card { EmptyStateView(symbol: "building.columns", title: "No active programmes", message: "Win a contract on the marketplace. Seedling studies are the easiest way in.") }
            }
            ForEach(active) { p in ProgrammeCard(programme: p, state: s) }
            if !done.isEmpty {
                Text("Finished").font(.headline)
                ForEach(done) { p in FinishedProgrammeRow(programme: p) }
            }
        }
    }
}

/// The stages as a timeline on the shared `StageStrip`, with the current one highlighted.
private struct StageTimeline: View {
    let programme: Programme

    var body: some View {
        let p = programme
        let stages = ProgrammeStage.allCases.filter { $0 != .proposal && ($0 != .commercialisation || p.stage == .commercialisation) }
        StageStrip(steps: stages.map { st in
            let done = st < p.stage || (p.status == .completed && st <= p.stage)
            let current = st == p.stage && p.status == .active
            return StageStep(id: "\(st)", title: st.short, status: done ? .done : (current ? .current : .upcoming))
        })
    }
}

private struct ProgrammeCard: View {
    @Environment(GameStore.self) private var store
    let programme: Programme
    let state: GameState
    @State private var showLog = false
    @State private var confirmAbandon = false

    var body: some View {
        let s = state
        let p = programme
        let sol = p.sol
        let f = AdvancedProjects.factors(p, s)
        let team = s.employees.filter { p.staff.contains($0.id) }
        let behind = AdvancedProjects.slip(p)
        let eac = AdvancedProjects.eac(p, s)
        let walkCost = AdvancedProjects.walkAwayCost(p)
        Card {
            HStack(alignment: .top) {
                Image(systemName: sol.agencyDef?.symbol ?? "building.columns").font(.title2).foregroundStyle(Color.accentColor).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sol.title).font(.headline)
                    Text("\(sol.agencyDef?.name ?? sol.agency) · awarded \(p.awarded.gameShort) · month \(p.months) of \(sol.months)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Pill(text: sol.type.title, color: AdvStyle.color(sol.type), symbol: sol.type.symbol)
                Pill(text: sol.level.title, color: AdvStyle.color(sol.level), symbol: "lock.fill")
                if sol.phase > 0 { Pill(text: "Phase \(AdvancedProjects.roman(sol.phase))", color: .secondary) }
                if p.cureNotice { Pill("Cure notice", tone: .bad) }
                if p.stopWork { Pill("Stop-work", tone: .bad) }
            }
            StageTimeline(programme: p)
            HStack {
                Text("\(p.stage.title) · stage \(Fmt.pct(min(1, p.progress), decimals: 0)) · overall \(Fmt.pct(p.completion, decimals: 0))").font(.callout)
                Spacer()
                if p.stage == .award {
                    ToneLabel(text: "Mobilising: month \(p.mobilisingMonths) of \(AdvancedProjects.mobilisationGrace(sol)) allowed", tone: .warning, font: .caption.weight(.semibold))
                } else {
                    ToneLabel(text: scheduleText(behind), tone: behind > 0.08 ? .warning : .good, font: .caption.weight(.semibold))
                }
            }
            Meter(value: p.completion, tint: behind > 0.08 ? Theme.warning : Theme.good)
            if p.stage == .award { MobilisationPlanView(plan: AdvancedProjects.mobilisationPlan(sol, s, programme: p)) }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pace this month").font(.caption.weight(.semibold))
                    SpecRow(label: "Team (skill vs need)", value: "×\(Fmt.trim(f.staffing, 2))")
                    SpecRow(label: "Cleared compute", value: "×\(Fmt.trim(f.compute, 2))")
                    SpecRow(label: "Model margin over bars", value: "×\(Fmt.trim(f.capability, 2))")
                    SpecRow(label: "Agents", value: "×\(Fmt.trim(f.agents, 2))")
                    SpecRow(label: "Overall (1 = on plan)", value: "×\(Fmt.trim(f.total, 2))")
                    if p.stage.hasTrial {
                        OddsBar(probability: AdvancedProjects.failChance(p, s), label: "Next trial failure odds", risk: true)
                    } else {
                        SpecRow(label: "Next trial failure odds", value: "—")
                    }
                    ForEach(f.missing, id: \.self) { m in RequirementLine(ok: false, text: m) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget").font(.caption.weight(.semibold))
                    SpecRow(label: "Contract value", value: Fmt.money(p.value))
                    SpecRow(label: "Received", value: Fmt.money(p.contractRevenue))
                    SpecRow(label: "Direct spend", value: Fmt.money(p.direct))
                    SpecRow(label: "Staff & facility (allocated)", value: Fmt.money(p.allocated))
                    SpecRow(label: "Cost growth found", value: Fmt.signedPct(eac.growthSoFar), tone: eac.growthSoFar > 0.1 ? .warning : nil)
                    if p.audits > 0 { SpecRow(label: "Audits", value: auditText(p), tone: p.findings > 0 ? .warning : nil) }
                    if p.disallowed > 0 { SpecRow(label: "Disallowed or repaid", value: Fmt.money(p.disallowed), tone: .bad) }
                    SpecRow(label: "P&L so far", value: AdvancedProjects.signed(p.profit), tone: Tone.sign(p.profit))
                    SpecRow(label: "Estimate at completion", value: Fmt.money(eac.atCompletion))
                    SpecRow(label: "Projected margin", value: AdvancedProjects.signed(eac.margin), tone: Tone.sign(eac.margin))
                    BurnChart(books: p.books)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Milestones").font(.caption.weight(.semibold))
                    ForEach(Array(AdvancedProjects.milestones(sol.type).enumerated()), id: \.offset) { _, m in
                        let paid = p.paid.contains(m.0.rawValue)
                        HStack {
                            Image(systemName: paid ? "checkmark.circle.fill" : "circle").foregroundStyle(paid ? Theme.good : .secondary)
                                .accessibilityLabel(paid ? "Paid" : "Not yet paid")
                            Text(m.0.title).font(.caption)
                            Spacer()
                            Text(Fmt.money((sol.type == .costPlus ? p.fee : p.value) * m.1)).font(.caption.monospacedDigit())
                        }
                    }
                    if let r = p.rivalFinish {
                        ToneLabel(text: "\(AdvancedProjects.rivalName(p.rivalLab)) could finish around \(r.gameShort).", tone: .warning, font: .caption2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Team (\(team.count) of \(sol.staffTotal))").font(.caption.weight(.semibold))
                        Spacer()
                        Button("Auto-staff") { store.act("Team assigned") { $0.autoStaffProgramme(p.id) } }.buttonStyle(.link).font(.caption)
                        if sol.level > .unclassified {
                            Button("Start clearances") { store.act("Investigations started") { $0.clearTeamFor(p.id) } }.buttonStyle(.link).font(.caption)
                        }
                        AddStaffMenu(programme: p, state: s)
                    }
                    ForEach(team) { e in
                        HStack {
                            Text(e.name).font(.caption)
                            Text("\(e.role.title) · skill \(Int(e.skill))").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button { store.act { $0.assignToProgramme(p.id, employee: e.id, on: false) } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).help("Take off the programme")
                        }
                    }
                    Text("People on a programme work for it alone: no research points, and they don't count toward training, safety or chip design while they're on it. The contract pays for them.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    if sol.level > .unclassified {
                        let free = AdvancedProjects.freeCompute(s, sol.level, excluding: p.id)
                        Text("Cleared compute: \(Fmt.int(Int(p.compute))) of \(Fmt.int(Int(sol.computeH100e))) H100e").font(.caption.weight(.semibold))
                        // 3.9: snap to 8s without overshooting what's free, so dragging to the end doesn't raise an error.
                        let top = min(free, sol.computeH100e * 1.5)
                        Slider(value: Binding(get: { p.compute }, set: { v in store.act { $0.setProgrammeCompute(p.id, min(top, (v / 8).rounded() * 8)) } }),
                               in: 0...max(8, top))
                            .accessibilityLabel("Cleared compute")
                            .accessibilityValue("\(Fmt.int(Int(p.compute))) H100e")
                        Text("\(Fmt.int(Int(free))) H100e free in accredited facilities.").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Compute: \(Fmt.int(Int(sol.computeH100e))) H100e rented in the cloud, billed to the contract.").font(.caption).foregroundStyle(.secondary)
                    }
                    if sol.level.agentsAllowed {
                        Picker("Agent swarm", selection: Binding(get: { p.swarm }, set: { id in store.act { $0.setProgrammeSwarm(p.id, id) } })) {
                            Text("None").tag(UUID?.none)
                            ForEach(s.swarms.filter { $0.orgID == nil }) { sw in Text("\(sw.name) (\(Fmt.count(sw.active)) agents)").tag(UUID?.some(sw.id)) }
                        }
                        .font(.caption)
                        if p.swarm != nil {
                            Text("While it's on the programme the swarm earns nothing for its own mission.").font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Agents aren't allowed on \(sol.level.title) networks.").font(.caption2).foregroundStyle(.secondary)
                    }
                    let leak = sol.level >= .secret && s.publication == .open
                    if leak {
                        ToneLabel(text: "Publication: \(sol.level.publication). Your open-science policy risks disclosure findings.", tone: .warning, font: .caption2)
                    } else {
                        Text("Publication: \(sol.level.publication).").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            DisclosureGroup(isExpanded: $showLog) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(p.history.reversed().enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .top) {
                            Text(e.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 80, alignment: .leading)
                            Text(e.text).font(.caption).foregroundStyle(e.tone < 0 ? .orange : (e.tone > 0 ? .primary : .secondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } label: {
                Text("Programme log (\(p.history.count))").font(.caption.weight(.semibold))
            }
            Button("Walk away from this programme…", role: .destructive) { confirmAbandon = true }
                .buttonStyle(.link).font(.caption)
                .confirmationDialog("Walk away from \(sol.title)?", isPresented: $confirmAbandon) {
                    Button(walkAwayLabel(sol.type), role: .destructive) {
                        store.mutate { $0.abandonProgramme(p.id) }
                    }
                    Button("Keep going", role: .cancel) {}
                } message: {
                    Text(walkAwayMessage(p, cost: walkCost))
                }
        }
    }

    private func walkAwayLabel(_ t: ContractType) -> String {
        t == .grant || t == .prize ? "Walk away (it lapses)" : "Walk away (counts as default)"
    }

    private func scheduleText(_ behind: Double) -> String {
        if behind > 0.08 { return "Behind schedule" }
        return behind < -0.05 ? "Ahead of schedule" : "On schedule"
    }

    private func auditText(_ p: Programme) -> String {
        let findings = p.findings == 1 ? "1 finding" : "\(p.findings) findings"
        return "\(p.audits), \(findings)"
    }

    /// What walking away costs under the contract's terms, and what (if anything) you keep.
    private func walkAwayMessage(_ p: Programme, cost: Double) -> String {
        let keep = p.sol.level >= .secret ? "Nothing from unfinished classified work can be used." : "You keep a little of what was learned (in proportion to the work done)."
        switch p.sol.type {
        case .fixedPrice: return "Termination for default: about \(Fmt.money(cost)) repaid (a fifth of the payments so far plus re-procurement costs), record −4 with \(p.sol.agencyDef?.short ?? "the agency"). \(keep)"
        case .costPlus: return "Termination for default: the fee paid so far is forfeited and re-procurement costs charged, about \(Fmt.money(cost)); record −4. \(keep)"
        case .grant: return "The grant lapses: \(Fmt.money(cost)) of unspent money goes back; record −1.5. \(keep)"
        case .prize: return "You leave the challenge; nothing is paid. \(keep)"
        }
    }
}

private struct AddStaffMenu: View {
    @Environment(GameStore.self) private var store
    let programme: Programme
    let state: GameState

    var body: some View {
        let s = state
        let p = programme
        let roles = Set(p.sol.staff.keys)
        let pool = s.employees.filter { roles.contains($0.role.rawValue) && !s.advanced.seconded.contains($0.id) }.sorted { $0.skill > $1.skill }
        Menu("Add…") {
            ForEach(pool.prefix(30)) { e in
                let ok = AdvancedProjects.clearanceLevel(s, e.id) >= p.sol.classification
                Button("\(e.name) — \(e.role.title), skill \(Int(e.skill))\(ok ? "" : " (needs clearance)")") {
                    store.act { $0.assignToProgramme(p.id, employee: e.id, on: true) }
                }
                .disabled(!ok)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .font(.caption)
    }
}

/// Monthly spend and income, last twelve months.
private struct BurnChart: View {
    let books: [ProgrammeMonth]

    var body: some View {
        let recent = Array(books.suffix(12))
        let top = max(1, recent.map { max($0.revenue, $0.direct + $0.allocated) }.max() ?? 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(recent.enumerated()), id: \.offset) { _, m in
                HStack(alignment: .bottom, spacing: 1) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.green.opacity(0.8)).frame(width: 5, height: max(1, 34 * m.revenue / top))
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.orange.opacity(0.8)).frame(width: 5, height: max(1, 34 * (m.direct + m.allocated) / top))
                }
            }
        }
        .frame(height: 36, alignment: .bottom)
        .help("Green: received. Orange: spent (direct and allocated).")
    }
}

private struct FinishedProgrammeRow: View {
    let programme: Programme

    var body: some View {
        let p = programme
        Card(padding: 12) {
            HStack {
                Image(systemName: p.status == .completed ? "checkmark.seal.fill" : "xmark.octagon").foregroundStyle(p.status == .completed ? Theme.good : Theme.warning)
                    .accessibilityLabel(p.status.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.sol.title).font(.callout.weight(.semibold))
                    Text("\(p.sol.agencyDef?.short ?? "") · \(p.status.title) \(p.ended?.gameShort ?? "") · \(p.months) months · \(p.reworks) reworks\(p.secrecy == .none ? "" : " · \(p.secrecy.title)")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("P&L \(AdvancedProjects.signed(p.profit))").font(TypeRamp.tableNumber).foregroundStyle(p.profit >= 0 ? Theme.good : Theme.bad)
                    Text("Research effects in use: \(Fmt.pct(p.effectScale, decimals: 0))\(p.secrecy == .retained ? " (internal only)" : "")\(p.royaltyMonthsLeft > 0 ? " · \(Fmt.money(p.royaltyMonthly))/mo royalties" : "")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Facilities & clearances

private struct FacilitiesSection: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var kind: FacilityKind = .secureLab
    @State private var level = 1
    @State private var closing: UUID? = nil
    @State private var sizeIndex = 0
    @State private var siteID: UUID? = nil
    @State private var roleFilter: Role? = nil

    var body: some View {
        let s = state
        let sizes = AdvancedProjects.sizes(kind, s.year)
        let capacity = sizes[min(sizeIndex, sizes.count - 1)]
        let q = AdvancedProjects.quote(kind, level: level, capacity: capacity, s.year)
        // A confidential science annex goes on one of your science labs; everything else on a site.
        let annex = kind == .confidentialScience
        let sites = AdvancedProjects.sitesFor(kind, s, level: level)
        let labs = AdvancedProjects.labsFor(s, level: level)
        let site = sites.first { $0.id == siteID } ?? sites.first
        let lab = labs.first { $0.id == siteID } ?? labs.first
        let target: UUID? = annex ? lab?.id : site?.id
        let insideSite = site.map { kind.isCompute || $0.kind == .datacenter || $0.kind == .colo } ?? false
        let freeKW = site.map { $0.capacityKW - Economy.siteLoadKW(s, $0.id) } ?? 0
        let powerMonth: Double = {
            guard q.kw > 0 else { return 0 }
            if annex, let lab { return q.kw * 0.6 * 1.3 * 24 * 30.4 * CountryCatalog.get(Science.site(lab.site).country).power }
            guard let site else { return 0 }
            return q.kw * 0.6 * site.pue * 24 * 30.4 * site.powerPrice
        }()
        VStack(alignment: .leading, spacing: Theme.gap) {
            CardGrid(minWidth: 380, maxColumns: 2) {
                Card {
                    CardHeader("Your facilities", symbol: "lock.rectangle.stack.fill")
                    if s.advanced.facilities.isEmpty {
                        Text("None yet. Classified programmes need desks in a secure lab and compute in an accredited centre or hall.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(s.advanced.facilities) { f in
                        let kw = AdvancedProjects.facilityKW(f)
                        HStack(alignment: .top) {
                            Photo(key: f.kind.image, illustrative: true).frame(width: 64, height: 44).clipShape(.rect(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name).font(.callout.weight(.semibold))
                                Text(facilityLine(f, kw: kw)).font(.caption).foregroundStyle(.secondary)
                                if !f.isReady(s.date) {
                                    Text("Accreditation \(f.ready.gameShort) · \(Fmt.money(f.capex)) spent").font(.caption2).foregroundStyle(.secondary)
                                } else if !f.suspension.isEmpty {
                                    ToneLabel(text: "Suspended: \(f.suspension)", tone: .warning, font: .caption2)
                                } else if !f.isUsable(s.date) {
                                    ToneLabel(text: "Certification suspended until \(f.suspendedUntil?.gameShort ?? "")", tone: .warning, font: .caption2)
                                } else {
                                    Text(accreditedLine(f)).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            // 3.9: closing loses the build cost and can strip running programmes; confirm with both spelled out.
                            Button(f.isReady(s.date) ? "Close…" : "Cancel build…") { closing = f.id }.buttonStyle(.link).font(.caption)
                                .confirmationDialog("Close \(f.name)?", isPresented: Binding(get: { closing == f.id }, set: { if !$0 { closing = nil } }),
                                                    titleVisibility: .visible) {
                                    Button(f.isReady(s.date) ? "Close it" : "Cancel the build", role: .destructive) {
                                        let refund = AdvancedProjects.closeRefund(s, f)
                                        store.mutate { $0.closeFacility(f.id) }
                                        store.show(refund > 0 ? "\(f.name) cancelled; \(Fmt.money(refund)) back" : "\(f.name) closed")
                                    }
                                    Button("Keep it", role: .cancel) {}
                                } message: {
                                    Text(AdvancedProjects.closeWarning(s, f.id))
                                }
                        }
                    }
                    Divider()
                    ForEach(1...3, id: \.self) { l in
                        let c = Classification(rawValue: l) ?? .controlled
                        let spaces = FacilityKind.allCases.filter(\.isProgrammeSpace).compactMap { k -> String? in
                            let n = AdvancedProjects.facilityFree(s, k, level: c)
                            return n > 0 ? "\(Fmt.int(Int(n))) \(k.unit)" : nil
                        }
                        SpecRow(label: AdvancedProjects.facilityLevelName(l) + " or higher",
                                value: "\(Fmt.int(Int(AdvancedProjects.freeCompute(s, c)))) H100e · \(Fmt.int(Int(AdvancedProjects.freeSeats(s, c)))) desks\(spaces.isEmpty ? "" : " · " + spaces.joined(separator: " · ")) free")
                    }
                    if !s.advanced.facilities.isEmpty {
                        SpecRow(label: "Power this month (estimate)", value: Fmt.money(AdvancedProjects.facilityPowerDay(s) * 30.4))
                    }
                    Text("Photos are illustrative stand-ins (a small server room, datacenter halls and aisles, a workshop bench, a teaching lab), not your facilities and not any real classified site.")
                        .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                }
                Card {
                    CardHeader("Build a facility", symbol: "hammer.fill")
                    Picker("Kind", selection: $kind) {
                        ForEach(FacilityKind.allCases) { k in Text(k.title).tag(k) }
                    }
                    .onChange(of: kind) { _, _ in sizeIndex = 0; siteID = nil }
                    Text(kind.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Picker("Accreditation", selection: $level) {
                        ForEach(1...3, id: \.self) { l in Text(AdvancedProjects.facilityLevelName(l)).tag(l) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: level) { _, _ in siteID = nil }
                    Picker("Size", selection: $sizeIndex) {
                        ForEach(Array(sizes.enumerated()), id: \.offset) { i, c in Text("\(Fmt.int(Int(c))) \(kind.unit)").tag(i) }
                    }
                    .pickerStyle(.segmented)
                    if annex {
                        Picker("Science lab", selection: Binding(get: { lab?.id }, set: { siteID = $0 })) {
                            if labs.isEmpty { Text("No suitable lab").tag(UUID?.none) }
                            ForEach(labs) { l in Text("\(l.name) (\(Science.siteName(l.site)))").tag(UUID?.some(l.id)) }
                        }
                    } else {
                        Picker("Site", selection: Binding(get: { site?.id }, set: { siteID = $0 })) {
                            if sites.isEmpty { Text("No suitable site").tag(UUID?.none) }
                            ForEach(sites) { st in Text("\(st.name) (\(st.kind.rawValue))").tag(UUID?.some(st.id)) }
                        }
                    }
                    Text(sitingNote(s)).font(.caption2).foregroundStyle(.secondary)
                    SpecRow(label: "Build cost", value: Fmt.money(q.capex))
                    SpecRow(label: "Upkeep", value: "\(Fmt.money(q.opex))/mo")
                    if q.kw > 0 {
                        SpecRow(label: "Power", value: "\(Fmt.watts(q.kw * 1000)) · about \(Fmt.money(powerMonth))/mo")
                        if insideSite {
                            SpecRow(label: "Site power free", value: Fmt.watts(max(0, freeKW) * 1000), tone: freeKW >= q.kw ? nil : .bad)
                        }
                    }
                    SpecRow(label: "Accreditation in", value: "\(Fmt.trim(q.months, 1)) months")
                    Text(buildNote(insideSite: insideSite)).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    let blockers = AdvancedProjects.facilityBlockers(kind, level: level, s)
                    ForEach(blockers, id: \.self) { b in RequirementLine(ok: false, text: b) }
                    Button("Build for \(Fmt.money(q.capex))") {
                        if let id = target { store.act("Construction started") { $0.buildFacility(kind, level: level, capacity: capacity, site: id) } }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(target == nil || s.cash < q.capex || !blockers.isEmpty || (insideSite && q.kw > freeKW))
                }
            }
            ClearancesCard(state: s, roleFilter: $roleFilter)
        }
    }

    private func facilityLine(_ f: SecureFacility, kw: Double) -> String {
        var t = "\(f.kind.title) · \(AdvancedProjects.facilityLevelName(f.level)) · \(Fmt.int(Int(f.capacity))) \(f.kind.unit)"
        if kw > 0 { t += " · " + Fmt.watts(kw * 1000) }
        return t
    }

    private func accreditedLine(_ f: SecureFacility) -> String {
        var t = "Accredited · \(Fmt.money(f.opex))/mo upkeep plus power"
        if f.kind == .certified {
            t += " · \(f.audits) audit" + (f.audits == 1 ? "" : "s")
            t += ", \(f.auditFindings) finding" + (f.auditFindings == 1 ? "" : "s")
        }
        return t
    }

    private func sitingNote(_ s: GameState) -> String {
        if level >= 2 { return "Secret and TS/SCI facilities must be in \(HQ.country(s).name), on a site you run yourself." }
        return "Controlled (CUI) facilities may be anywhere among your allies."
    }

    private func buildNote(insideSite: Bool) -> String {
        let officers = AdvancedProjects.officersRequired(kind, level: level)
        let clearance = Classification(rawValue: level)?.clearance ?? ""
        var t = "Power is billed with your datacenter power at the site's price"
        if insideSite { t += " and comes out of the site's capacity (no GPUs in that space)" }
        t += ". Once accredited it needs \(officers) staff cleared \(clearance) as security officer" + (officers == 1 ? "" : "s") + ", or it's suspended."
        if kind.isProgrammeSpace {
            t += " Upkeep includes the \(AdvancedProjects.facilityLevelName(level)) premium (×\(Fmt.trim(AdvancedProjects.levelPremium[level - 1], 1)))."
        }
        return t
    }
}

private struct ClearancesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @Binding var roleFilter: Role?

    private func investigationLine(_ c: Clearance, ready: Date) -> String {
        let what = c.renewal ? "Reinvestigation" : (Classification(rawValue: c.target)?.clearance ?? "") + " investigation"
        return what + " · " + ready.gameShort
    }

    var body: some View {
        let s = state
        let people = s.employees.filter { roleFilter == nil || $0.role == roleFilter }.sorted { ($0.role.rawValue, -$0.skill) < ($1.role.rawValue, -$1.skill) }
        Card {
            CardHeader(title: "Clearances", symbol: "person.badge.shield.checkmark.fill",
                       subtitle: "Background investigations take months and cost money; some people can't be cleared. Costs: public trust \(Fmt.money(AdvancedProjects.clearanceCost(1, s.year))), Secret \(Fmt.money(AdvancedProjects.clearanceCost(2, s.year))), TS/SCI \(Fmt.money(AdvancedProjects.clearanceCost(3, s.year))). Cleared staff earn a premium (3%, 8%, 12%), are likelier to be poached, and are reinvestigated every five years.") {
                Picker("Role", selection: $roleFilter) {
                    Text("All roles").tag(Role?.none)
                    ForEach(Role.allCases) { r in Text(r.plural).tag(Role?.some(r)) }
                }
                .frame(maxWidth: 200)
            }
            ForEach(people.prefix(60)) { e in
                let c = s.advanced.clearances.first { $0.employee == e.id }
                let level = c?.level ?? 0
                HStack {
                    Text(e.name).font(.callout).frame(width: 170, alignment: .leading)
                    Text("\(e.role.title) · skill \(Int(e.skill))").font(.caption).foregroundStyle(.secondary).frame(width: 190, alignment: .leading)
                    Pill(text: Classification(rawValue: level)?.clearance ?? "None", color: level > 0 ? AdvStyle.color(Classification(rawValue: level) ?? .controlled) : .secondary)
                    if s.advanced.seconded.contains(e.id) { Pill(text: "On a programme", color: .indigo) }
                    if let c, let ready = c.ready {
                        Text(investigationLine(c, ready: ready)).font(.caption).foregroundStyle(.secondary)
                    } else if let c, c.deniedAt > 0 {
                        ToneLabel(text: "Denied at \(Classification(rawValue: c.deniedAt)?.clearance ?? "")", tone: .warning, font: .caption)
                    } else if let c, c.level > 0, let g = c.granted {
                        Text("Reinvestigation due \(GameCalendar.addMonths(g, 60).gameShort)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if c?.ready == nil {
                        ForEach(1...3, id: \.self) { l in
                            if level < l && (c?.deniedAt ?? 0 == 0 || (c?.deniedAt ?? 0) > l) {
                                Button(Classification(rawValue: l)?.short ?? "") {
                                    store.act("Investigation started") { $0.requestClearance(e.id, level: l) }
                                }
                                .buttonStyle(.bordered).controlSize(.small)
                                .help("\(Fmt.money(AdvancedProjects.clearanceCost(l, s.year))), about \(Int(AdvancedProjects.clearanceMonths(l))) months")
                            }
                        }
                    }
                }
            }
            if people.count > 60 { Text("+\(people.count - 60) more — filter by role.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

// MARK: - Agencies & record

private struct AgenciesSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let home = AdvancedProjects.homeRegion(s)
        let country = AdvancedProjects.homeCountry(s)
        let legacies = AdvancedProjects.legacyLines(s)
        VStack(alignment: .leading, spacing: Theme.gap) {
            if !legacies.isEmpty {
                Card {
                    CardHeader("What your programmes left behind", symbol: "arrow.forward.circle.fill")
                    ForEach(legacies, id: \.self) { l in Label(l, systemImage: "checkmark.circle").font(.callout) }
                }
            }
            Text("Each agency spends from a yearly budget that follows the year, public concern, its region's rules and the economy (growth below trend cuts it). Every award — yours or a rival lab's — draws it down: a busy agency posts less and smaller work, and one whose budget falls below its commitments cancels programmes. Top Secret work goes only to labs an agency already trusts with Secret work.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Theme.columns(min: 380), alignment: .leading, spacing: Theme.gap) {
                ForEach(AgencyCatalog.all) { a in
                    let rating = AdvancedProjects.rating(s, a.id)
                    let levels = Classification.allCases.filter { AdvancedProjects.eligible(home: home, country: country, agency: a, level: $0) }
                    let done = s.advanced.programmes.filter { $0.sol.agency == a.id }
                    Card {
                        HStack(alignment: .top) {
                            Image(systemName: a.symbol).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.name).font(.headline)
                                Text("\(a.short) · \(a.kind.label) · \(a.homeName)\(a.country.isEmpty ? "" : " (\(a.region.short))")").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Fmt.money(AdvancedProjects.agencyBudget(a, s)) + "/yr").font(.callout.monospacedDigit())
                        }
                        Text(a.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        let budget = AdvancedProjects.agencyBudget(a, s)
                        let committed = AdvancedProjects.obligations(a, s)
                        let trust = AdvancedProjects.trust(s, a.id)
                        let rivals = s.advanced.rivalProgrammes.filter { $0.agency == a.id }
                        SpecRow(label: "Committed this year", value: committedText(committed, budget), tone: committedTone(committed, budget))
                        SpecRow(label: "Your record", value: rating == 0 ? "None yet" : Fmt.signed(rating, 1), tone: rating == 0 ? nil : Tone.sign(rating))
                        if trust != 0 || levels.contains(.secret) {
                            SpecRow(label: "Trust with classified work", value: trust == 0 ? "None yet" : Fmt.signed(trust, 1), tone: trust == 0 ? nil : Tone.sign(trust))
                        }
                        if let until = s.advanced.commercialised[a.id], until > s.date {
                            SpecRow(label: "Classified bids marked down", value: "until \(until.gameShort)", tone: .warning)
                        }
                        SpecRow(label: "Standing with \(a.region.short) government", value: Fmt.trim(AdvancedProjects.standing(s, a.region), 0))
                        SpecRow(label: "Work open to you", value: levels.isEmpty ? "None" : levels.map(\.short).joined(separator: ", "))
                        if let l = a.lever { SpecRow(label: "Budget follows", value: "\(a.region.short) \(l.phrase) (and its sovereign-AI programme)") }
                        if AdvancedProjects.recessionFactor(s, a.region) < 0.995 {
                            SpecRow(label: "Cut for a slow economy", value: Fmt.signedPct(AdvancedProjects.recessionFactor(s, a.region) - 1), tone: .warning)
                        }
                        if !done.isEmpty {
                            Text("Programmes: " + done.map { "\($0.sol.title) (\($0.status.title.lowercased()))" }.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                        }
                        if !rivals.isEmpty {
                            Text(rivalLine(rivals)).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func committedText(_ committed: Double, _ budget: Double) -> String {
        "\(Fmt.money(committed)) (\(Fmt.pct(committed / max(1, budget), decimals: 0)) of budget)"
    }

    private func committedTone(_ committed: Double, _ budget: Double) -> Tone? {
        if committed > budget { return .bad }
        return committed > 0.8 * budget ? .warning : nil
    }

    private func rivalLine(_ rivals: [RivalProgramme]) -> String {
        var parts: [String] = []
        for r in rivals.suffix(4) {
            let state = r.active ? "running" : (r.status == "completed" ? "delivered" : "terminated")
            parts.append("\(CompetitorCatalog.def(r.lab).name), \(r.title) (\(state))")
        }
        return "Rival contracts: " + parts.joined(separator: " · ")
    }
}

// MARK: - Discoveries & patents

private struct DiscoveriesSection: View {
    let state: GameState

    private func discoveryLine(_ d: ProgrammeDiscovery) -> String {
        var t = "\(AgencyCatalog.byID[d.agency]?.short ?? d.agency) · \(Classification(rawValue: d.level)?.title ?? "") · \(d.date.gameShort)"
        if d.published {
            t += " · published"
        } else if d.secrecyOrder {
            t += " · no publication"
        } else if let until = d.reviewUntil {
            t += " · paper in pre-publication review until \(until.gameShort)"
        }
        return t
    }

    var body: some View {
        let s = state
        let list = s.advanced.discoveries.sorted { $0.date > $1.date }
        let history = AdvancedProjects.historyEntries(s).reversed()
        VStack(alignment: .leading, spacing: Theme.gap) {
            Card {
                CardHeader("Discoveries and patents", symbol: "doc.badge.gearshape",
                           subtitle: "Open work is patented and published when it's delivered. Classified work is patented under a secrecy order: no licensees, no papers, until it's cleared for commercial use (approval, a clean-room rebuild, a licence or an authorised partner). Kept classified or retained internally, it stays sealed.")
                if list.isEmpty {
                    Text("No discoveries yet. Programmes that list a discovery under “Leaves behind” produce one when delivered.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(list) { d in
                    HStack(alignment: .top) {
                        Image(systemName: d.secrecyOrder ? "lock.doc.fill" : "doc.text.fill").foregroundStyle(d.secrecyOrder ? Color.orange : Color.accentColor)
                            .accessibilityLabel(d.secrecyOrder ? "Under a secrecy order" : "Open patent")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.title).font(.callout.weight(.semibold))
                            Text(discoveryLine(d))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(d.secrecyOrder ? "Patent under secrecy order" : "\(d.licensees) licensee\(d.licensees == 1 ? "" : "s") · \(Fmt.money(d.lastMonth))/mo").font(.caption)
                            Text("Lifetime \(Fmt.money(d.lifetime))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !history.isEmpty {
                Card {
                    CardHeader("Programme history", symbol: "clock.arrow.circlepath")
                    ForEach(Array(history.prefix(40))) { e in
                        HStack {
                            Image(systemName: e.symbol).frame(width: 20).foregroundStyle(.secondary).accessibilityHidden(true)
                            Text(e.title).font(.callout)
                            Text(e.detail).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(e.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Dashboard card

/// Self-contained dashboard card: active programmes with their stage and next payment, bids waiting, and openings.
struct AdvancedProjectsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let active = s.advanced.programmes.filter { $0.status == .active }
        let pending = s.advanced.solicitations.filter { $0.bid != nil }
        let open = s.advanced.solicitations.filter { $0.bid == nil && AdvancedProjects.blockers($0, s).isEmpty }
        Card {
            CardHeader(title: "Advanced Projects", symbol: "building.columns.circle") {
                Button("Advanced Projects") { store.open(.advancedProjects) }.buttonStyle(.link)
            }
            if active.isEmpty && pending.isEmpty {
                Text(open.isEmpty ? "No government work you can bid on right now." : "\(open.count) solicitation\(open.count == 1 ? "" : "s") you could bid on, up to \(Fmt.money(open.map(\.ceiling).max() ?? 0)).")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(active.prefix(3)) { p in
                let next = AdvancedProjects.milestones(p.sol.type).first { !p.paid.contains($0.0.rawValue) && $0.0 >= p.stage }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(p.sol.title).font(.callout.weight(.semibold)).lineLimit(1)
                        Pill(text: p.sol.level.short, color: AdvStyle.color(p.sol.level))
                        if p.cureNotice { Pill("Cure notice", tone: .bad) }
                        Spacer()
                        Text(p.stage.title).font(.caption).foregroundStyle(.secondary)
                    }
                    Meter(value: p.completion, tint: p.cureNotice ? Theme.warning : .indigo)
                    if let next {
                        Text("Next payment at \(next.0.title.lowercased()): \(Fmt.money((p.sol.type == .costPlus ? p.fee : p.value) * next.1)) · P&L so far \(AdvancedProjects.signed(p.profit))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if !pending.isEmpty {
                Text("\(pending.count) bid\(pending.count == 1 ? "" : "s") waiting: " + pending.map { "\($0.title) (\($0.closes.gameShort))" }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
