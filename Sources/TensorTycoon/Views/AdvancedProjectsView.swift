import SwiftUI

// MARK: - 3.5: Advanced Projects — government contracts, classified facilities and clearances

enum AdvancedTab: String, CaseIterable, Identifiable {
    case market = "Marketplace"
    case programmes = "Programmes"
    case facilities = "Facilities & Clearances"
    case agencies = "Agencies & Record"
    var id: String { rawValue }
}

struct AdvancedProjectsView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: AdvancedTab = .market

    var body: some View {
        let s = store.game
        let a = s.advanced
        let active = a.programmes.filter { $0.status == .active }
        let backlog = active.reduce(0.0) { $0 + max(0, $1.value - ($1.sol.type == .costPlus ? 0 : $1.revenue)) }
        let lifetime = a.programmes.reduce(0.0) { $0 + $1.revenue }
        let cleared = a.clearances.filter { $0.level > 0 }.count
        Page(title: "Advanced Projects",
             subtitle: "Government research contracts. Agencies post solicitations; you bid against rival labs, then deliver with cleared people, cleared compute and accredited facilities. Classified work pays in standing and access — and sometimes in discoveries you may or may not be allowed to use.", screen: .advancedProjects) {
            HeroBanner(image: "supercomputer", height: 150) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Advanced Projects division").font(.title2.weight(.bold))
                    Text("\(active.count) active programme\(active.count == 1 ? "" : "s") · \(a.solicitations.filter { $0.bid == nil }.count) open solicitations · home: \(AdvancedProjects.homeRegion(s).title)")
                        .font(.callout)
                    PhotoPill(text: "Illustrative photo — not a real facility", symbol: "photo")
                }
            }
            KPIRow {
                StatTile(title: "Active programmes", value: "\(active.count)", detail: active.isEmpty ? "Win a contract on the marketplace" : "\(Fmt.money(backlog)) still to bill",
                         symbol: "building.columns.fill", tint: .indigo)
                StatTile(title: "Contract revenue", value: Fmt.money(lifetime), detail: "Booked as other revenue", symbol: "dollarsign.circle.fill", tint: .green)
                StatTile(title: "Cleared staff", value: "\(cleared)", detail: "\(a.clearances.filter { $0.ready != nil }.count) investigations under way",
                         symbol: "person.badge.shield.checkmark.fill", tint: .teal)
                StatTile(title: "Cleared compute", value: "\(Fmt.int(Int(AdvancedProjects.computeCapacity(s, atLeast: 1)))) H100e",
                         detail: "\(Fmt.int(Int(AdvancedProjects.seatCapacity(s, atLeast: 1)))) secure desks · \(Fmt.money(a.lastOpex))/mo", symbol: "lock.rectangle.stack.fill", tint: .orange)
            }
            SectionTabs(selection: $tab, options: AdvancedTab.allCases)
            switch tab {
            case .market: MarketplaceSection(state: s)
            case .programmes: ProgrammesSection(state: s)
            case .facilities: FacilitiesSection(state: s)
            case .agencies: AgenciesSection(state: s)
            }
        }
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
    @State private var biddable = false
    @State private var sort: MarketSort = .closing
    @State private var proposal: Solicitation? = nil

    var body: some View {
        let s = state
        let all = s.advanced.solicitations
        var list = all.filter { sol in
            (type == nil || sol.type == type) && sol.level <= maxLevel && (region == nil || sol.agencyDef?.region == region)
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
                    Picker("Sort", selection: $sort) {
                        ForEach(MarketSort.allCases) { m in Text(m.rawValue).tag(m) }
                    }
                    .frame(maxWidth: 200)
                    Toggle("Only ones I can bid on", isOn: $biddable)
                }
                .font(.callout)
                Text("Agencies post new work at the start of each month, more when their budgets grow (budgets follow the year, public concern and each region's rules). Bids are decided on the closing date with a seeded roll against the odds shown.")
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
                    Text("\(a?.name ?? sol.agency) · \(a?.region.short ?? "")").font(.caption).foregroundStyle(.secondary)
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
                if sol.followOn { Pill(text: "Follow-on", color: .green, symbol: "arrow.turn.down.right") }
            }
            Text(sol.templateDef?.objective ?? "").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            RequirementsList(sol: sol, state: s)
            HStack {
                Text("\(sol.bidders.count) rival bid\(sol.bidders.count == 1 ? "" : "s") expected · \(sol.basis.label.lowercased()) · closes \(sol.closes.gameShort)")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                if let bid = sol.bid {
                    Label("Bid in: \(sol.type == .costPlus ? "fee \(Fmt.pct(bid.price, decimals: 0))" : (sol.type == .prize ? "entry" : "\(Fmt.pct(bid.price, decimals: 0)) of ceiling")) · odds now \(Fmt.pct(o.p, decimals: 0))",
                          systemImage: "paperplane.fill").font(.callout).foregroundStyle(.blue)
                    Spacer()
                    Button("Withdraw") { store.mutate { $0.withdrawProposal(sol.id) } }.buttonStyle(.link)
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
                        case .costPlus:
                            HStack {
                                Text("Fee \(Fmt.pct(p, decimals: 0)) on a \(Fmt.money(sol.estCost)) target cost")
                                Spacer()
                                Text(Fmt.money(sol.estCost * p)).font(.body.monospacedDigit().weight(.semibold))
                            }
                            Slider(value: Binding(get: { p }, set: { price = ($0 * 100).rounded() / 100 }), in: 0.02...0.15)
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
                        Text("Cash margin counts only new spending; full cost also charges your seconded staff and facility running costs. Rework and slow progress add months of spending — on fixed-price work that comes out of your margin.")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
                    if let t = sol.templateDef { SpecRow(label: "Leaves behind", value: t.reward) }
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
        let behind = Double(p.months) / Double(max(1, sol.months)) - p.completion
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
                if p.cureNotice { Pill(text: "Cure notice", color: .red, symbol: "exclamationmark.triangle.fill") }
                if p.stopWork { Pill(text: "Stop-work", color: .red, symbol: "hand.raised.fill") }
            }
            StageTimeline(programme: p)
            HStack {
                Text("\(p.stage.title) · stage \(Fmt.pct(min(1, p.progress), decimals: 0)) · overall \(Fmt.pct(p.completion, decimals: 0))").font(.callout)
                Spacer()
                ToneLabel(text: behind > 0.08 ? "Behind schedule" : (behind < -0.05 ? "Ahead of schedule" : "On schedule"),
                          tone: behind > 0.08 ? .warning : .good, font: .caption.weight(.semibold))
            }
            Meter(value: p.completion, tint: behind > 0.08 ? Theme.warning : Theme.good)
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
                    SpecRow(label: "Received", value: Fmt.money(p.revenue))
                    SpecRow(label: "Direct spend", value: Fmt.money(p.direct))
                    SpecRow(label: "Staff & facility (allocated)", value: Fmt.money(p.allocated))
                    SpecRow(label: "P&L so far", value: AdvancedProjects.signed(p.profit), tone: Tone.sign(p.profit))
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
                        Text("A rival team could finish around \(r.gameShort).").font(.caption2).foregroundStyle(.orange)
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
                    Text("People on a programme don't produce research points for your lab while they're on it.").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    if sol.level > .unclassified {
                        let free = AdvancedProjects.freeCompute(s, sol.level, excluding: p.id)
                        Text("Cleared compute: \(Fmt.int(Int(p.compute))) of \(Fmt.int(Int(sol.computeH100e))) H100e").font(.caption.weight(.semibold))
                        Slider(value: Binding(get: { p.compute }, set: { v in store.act { $0.setProgrammeCompute(p.id, (v / 8).rounded() * 8) } }),
                               in: 0...max(8, min(free, sol.computeH100e * 1.5)))
                        Text("\(Fmt.int(Int(free))) H100e free in accredited facilities.").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Compute: \(Fmt.int(Int(sol.computeH100e))) H100e rented in the cloud, billed to the contract.").font(.caption).foregroundStyle(.secondary)
                    }
                    if sol.level.agentsAllowed {
                        Picker("Agent swarm", selection: Binding(get: { p.swarm }, set: { id in store.act { $0.setProgrammeSwarm(p.id, id) } })) {
                            Text("None").tag(UUID?.none)
                            ForEach(s.swarms) { sw in Text("\(sw.name) (\(Fmt.count(sw.active)) agents)").tag(UUID?.some(sw.id)) }
                        }
                        .font(.caption)
                    } else {
                        Text("Agents aren't allowed on \(sol.level.title) networks.").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("Publication: \(sol.level.publication).\(sol.level >= .secret && s.publication == .open ? " Your open-science policy risks disclosure findings." : "")")
                        .font(.caption2).foregroundStyle(sol.level >= .secret && s.publication == .open ? .orange : .secondary)
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
                    Button("Walk away (counts as default)", role: .destructive) { store.mutate { $0.abandonProgramme(p.id) } }
                    Button("Keep going", role: .cancel) {}
                }
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
                    Text("Research effects in use: \(Fmt.pct(p.effectScale, decimals: 0))\(p.royaltyMonthsLeft > 0 ? " · \(Fmt.money(p.royaltyMonthly))/mo royalties" : "")")
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
    @State private var sizeIndex = 0
    @State private var siteID: UUID? = nil
    @State private var roleFilter: Role? = nil

    var body: some View {
        let s = state
        let sizes = AdvancedProjects.sizes(kind, s.year)
        let capacity = sizes[min(sizeIndex, sizes.count - 1)]
        let q = AdvancedProjects.quote(kind, level: level, capacity: capacity, s.year)
        let sites = AdvancedProjects.sitesFor(kind, s)
        let site = sites.first { $0.id == siteID } ?? sites.first
        VStack(alignment: .leading, spacing: Theme.gap) {
            CardGrid(minWidth: 380, maxColumns: 2) {
                Card {
                    CardHeader("Your facilities", symbol: "lock.rectangle.stack.fill")
                    if s.advanced.facilities.isEmpty {
                        Text("None yet. Classified programmes need desks in a secure lab and compute in an accredited centre or hall.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(s.advanced.facilities) { f in
                        HStack(alignment: .top) {
                            Photo(key: f.kind.image).frame(width: 64, height: 44).clipShape(.rect(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name).font(.callout.weight(.semibold))
                                Text("\(f.kind.title) · \(AdvancedProjects.facilityLevelName(f.level)) · \(Fmt.int(Int(f.capacity))) \(f.kind.unit)").font(.caption).foregroundStyle(.secondary)
                                Text(f.isReady(s.date) ? "Accredited · \(Fmt.money(f.opex))/mo" : "Accreditation \(f.ready.gameShort) · \(Fmt.money(f.capex)) spent")
                                    .font(.caption2).foregroundStyle(f.isReady(s.date) ? Color.secondary : Color.orange)
                            }
                            Spacer()
                            Button("Close") { store.mutate { $0.closeFacility(f.id) } }.buttonStyle(.link).font(.caption)
                        }
                    }
                    Divider()
                    ForEach(1...3, id: \.self) { l in
                        SpecRow(label: AdvancedProjects.facilityLevelName(l) + " or higher",
                                value: "\(Fmt.int(Int(AdvancedProjects.freeCompute(s, Classification(rawValue: l) ?? .controlled)))) H100e · \(Fmt.int(Int(AdvancedProjects.freeSeats(s, Classification(rawValue: l) ?? .controlled)))) desks free")
                    }
                    Text("Photos are generic server rooms and datacenters, for illustration only.").font(.caption2).foregroundStyle(.tertiary)
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
                    Picker("Size", selection: $sizeIndex) {
                        ForEach(Array(sizes.enumerated()), id: \.offset) { i, c in Text("\(Fmt.int(Int(c))) \(kind.unit)").tag(i) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Site", selection: Binding(get: { site?.id }, set: { siteID = $0 })) {
                        if sites.isEmpty { Text("No suitable site").tag(UUID?.none) }
                        ForEach(sites) { st in Text("\(st.name) (\(st.kind.rawValue))").tag(UUID?.some(st.id)) }
                    }
                    SpecRow(label: "Build cost", value: Fmt.money(q.capex))
                    SpecRow(label: "Running cost", value: "\(Fmt.money(q.opex))/mo")
                    SpecRow(label: "Accreditation in", value: "\(Fmt.trim(q.months, 1)) months")
                    if q.kw > 0 { SpecRow(label: "Power", value: Fmt.watts(q.kw * 1000)) }
                    Button("Build for \(Fmt.money(q.capex))") {
                        if let id = site?.id { store.act("Construction started") { $0.buildFacility(kind, level: level, capacity: capacity, site: id) } }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(site == nil || s.cash < q.capex)
                }
            }
            ClearancesCard(state: s, roleFilter: $roleFilter)
        }
    }
}

private struct ClearancesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @Binding var roleFilter: Role?

    var body: some View {
        let s = state
        let people = s.employees.filter { roleFilter == nil || $0.role == roleFilter }.sorted { ($0.role.rawValue, -$0.skill) < ($1.role.rawValue, -$1.skill) }
        Card {
            CardHeader(title: "Clearances", symbol: "person.badge.shield.checkmark.fill",
                       subtitle: "Background investigations take months and cost money; some people can't be cleared. Costs: public trust \(Fmt.money(AdvancedProjects.clearanceCost(1, s.year))), Secret \(Fmt.money(AdvancedProjects.clearanceCost(2, s.year))), TS/SCI \(Fmt.money(AdvancedProjects.clearanceCost(3, s.year))).") {
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
                        Text("\(Classification(rawValue: c.target)?.clearance ?? "") investigation · \(ready.gameShort)").font(.caption).foregroundStyle(.blue)
                    } else if let c, c.deniedAt > 0 {
                        ToneLabel(text: "Denied at \(Classification(rawValue: c.deniedAt)?.clearance ?? "")", tone: .warning, font: .caption)
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
        LazyVGrid(columns: Theme.columns(min: 380), alignment: .leading, spacing: Theme.gap) {
            ForEach(AgencyCatalog.all) { a in
                let rating = AdvancedProjects.rating(s, a.id)
                let levels = Classification.allCases.filter { AdvancedProjects.eligible(home: home, agency: a.region, level: $0) }
                let done = s.advanced.programmes.filter { $0.sol.agency == a.id }
                Card {
                    HStack(alignment: .top) {
                        Image(systemName: a.symbol).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name).font(.headline)
                            Text("\(a.short) · \(a.kind.label) · \(a.region.title)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.money(AdvancedProjects.agencyBudget(a, s)) + "/yr").font(.callout.monospacedDigit())
                    }
                    Text(a.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    SpecRow(label: "Your record", value: rating == 0 ? "None yet" : Fmt.signed(rating, 1), tone: rating == 0 ? nil : Tone.sign(rating))
                    SpecRow(label: "Standing with \(a.region.short) government", value: Fmt.trim(AdvancedProjects.standing(s, a.region), 0))
                    SpecRow(label: "Work open to you", value: levels.isEmpty ? "None" : levels.map(\.short).joined(separator: ", "))
                    if !done.isEmpty {
                        Text("Programmes: " + done.map { "\($0.sol.title) (\($0.status.title.lowercased()))" }.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
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
