import SwiftUI

// MARK: - 3.9: Government contract marketplace — opportunities, pipeline, anchor contract, budget calendars and record

enum GovTab: String, CaseIterable, Identifiable {
    case opportunities = "Opportunities"
    case pipeline = "Pipeline"
    case anchor = "Anchor contract"
    case calendars = "Budget calendars"
    case record = "Record & debriefs"
    var id: String { rawValue }
}

struct GovMarketView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: GovTab = .opportunities

    var body: some View {
        let s = store.game
        let g = s.govMarket
        let open = g.opps.filter { $0.status == .open || $0.status == .notice }
        let pipeline = g.pipeline
        let weighted = pipeline.reduce(0.0) { $0 + GovMarket.currentOdds($1, s).p * $1.sol.ceiling }
        let next = pipeline.filter { $0.status == .submitted }.map(\.decisionDue).min()
        let rec = GovMarket.record(s)
        let home = GovMarket.fiscal(s, GovMarket.relevantCalendars(s).first ?? "us", at: s.date)
        Page(title: "Government Contracts",
             subtitle: "Small, unclassified public money a young lab can win: small-business awards, prototype agreements, task orders, compute allocations, EU calls and national grants. Proposals take people and time; budget calendars decide when the money moves. Won work runs on the Advanced Projects page and builds the record bigger bids are judged on.",
             screen: .govContracts) {
            HeroBanner(image: GovMarket.homeImage(s), height: 150) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Public buyers").font(.title2.weight(.bold))
                    Text("\(open.count) open · \(pipeline.count) in your pipeline · \(home.name): \(home.fyLabel), \(home.phase.title.lowercased())\(home.cycleLabel.isEmpty ? "" : " · \(home.cycleLabel.lowercased())")")
                        .font(.callout)
                    PhotoPill(text: GovStyle.photoCaption(GovMarket.homeImage(s)), symbol: "photo")
                }
            }
            KPIRow {
                StatTile(title: "Open opportunities", value: "\(open.count)", detail: "\(open.filter { $0.status == .notice }.count) sources-sought notices · \(GovMarket.slots(s)) writing slot\(GovMarket.slots(s) == 1 ? "" : "s")",
                         symbol: "tray.full.fill", tint: .indigo)
                StatTile(title: "Pipeline", value: Fmt.money(weighted), detail: pipeline.isEmpty ? "Odds-weighted value of bids out" : "\(pipeline.count) bid\(pipeline.count == 1 ? "" : "s") out\(next.map { " · next decision \($0.gameShort)" } ?? "")",
                         symbol: "chart.bar.doc.horizontal.fill", tint: .blue)
                StatTile(title: "Win rate", value: g.wins + g.losses == 0 ? "—" : Fmt.pct(Double(g.wins) / Double(g.wins + g.losses), decimals: 0),
                         detail: "\(g.wins) won · \(g.losses) lost · \(Fmt.money(g.awarded)) awarded", symbol: "rosette", tint: .green)
                StatTile(title: "Past performance", value: rec.text.components(separatedBy: ":").first ?? rec.text,
                         detail: "\(rec.delivered) delivered · \(g.assessments.count) rating\(g.assessments.count == 1 ? "" : "s")\(rec.defaults > 0 ? " · \(rec.defaults) default\(rec.defaults == 1 ? "" : "s")" : "")",
                         symbol: "checkmark.seal.fill", tint: .teal)
            }
            SectionTabs(selection: $tab, options: GovTab.allCases)
            switch tab {
            case .opportunities: GovOpportunitiesSection(state: s)
            case .pipeline: GovPipelineSection(state: s)
            case .anchor: GovAnchorSection(state: s)
            case .calendars: GovCalendarsSection(state: s)
            case .record: GovRecordSection(state: s)
            }
        }
    }
}

enum GovStyle {
    static func photoCaption(_ image: String) -> String {
        switch image {
        case "gov_capitol": "Photo: United States Capitol"
        case "gov_folketinget": "Photo: Christiansborg Palace, Copenhagen"
        case "gov_assemblee": "Photo: Palais Bourbon, Paris"
        case "gov_montecitorio": "Photo: Palazzo Montecitorio, Rome"
        default: "Photo: Berlaymont building, Brussels"
        }
    }

    static func tone(_ p: GovMarket.Phase) -> Tone {
        switch p {
        case .enacted: .good
        case .continuing, .provisional, .transition: .warning
        case .lapse: .bad
        }
    }

    static func statusTone(_ st: GovOppStatus) -> Tone {
        switch st {
        case .won: .good
        case .lost, .missed: .bad
        case .writing, .submitted: .info
        case .protesting, .held: .warning
        default: .neutral
        }
    }

    static func payout(_ k: GovKindDef) -> String {
        switch k.payout {
        case .programme: "Runs as a programme"
        case .compute: "GPU hours (cloud credits)"
        case .seat: "Contract seat"
        }
    }
}

// MARK: - Opportunities

private struct GovOpportunitiesSection: View {
    let state: GameState
    @State private var proposal: GovOpp? = nil

    var body: some View {
        let s = state
        let list = s.govMarket.opps.filter { $0.status == .open || $0.status == .notice || $0.status == .writing }
            .sorted { ($0.invited ? 0 : 1, $0.sol.closes, $0.id) < ($1.invited ? 0 : 1, $1.sol.closes, $1.id) }
        VStack(alignment: .leading, spacing: 14) {
            Card {
                Text("Agencies post on the 1st and the 15th — more in a year-end rush, fewer while a budget waits. Only work you may bid on is listed: some programmes are for companies at home, some for small companies only, task orders for seat holders. Odds below assume a standard proposal led by your best free researcher; open a card to choose.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if list.isEmpty {
                Card {
                    EmptyStateView(symbol: "tray", title: "Nothing open right now", message: "New solicitations arrive on the 1st and the 15th. Check Budget calendars for the next calls and cut-offs.")
                }
            }
            LazyVGrid(columns: Theme.columns(min: 420), alignment: .leading, spacing: Theme.gap) {
                ForEach(list) { o in GovOppCard(opp: o, state: s, onPropose: { proposal = o }) }
            }
            UpcomingCalls(state: s)
        }
        .sheet(item: $proposal) { o in GovProposalSheet(oppID: o.id) }
    }
}

private struct GovOppCard: View {
    @Environment(GameStore.self) private var store
    let opp: GovOpp
    let state: GameState
    let onPropose: () -> Void

    var body: some View {
        let s = state
        let o = opp
        let k = o.def
        let a = o.agencyDef
        let od = GovMarket.currentOdds(o, s)
        let f = a.map { GovMarket.fiscal(s, agency: $0) }
        let left = GameCalendar.daysBetween(s.date, o.sol.closes)
        Card {
            HStack(alignment: .top) {
                Image(systemName: a?.symbol ?? "building.columns").font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.sol.title).font(.headline)
                    Text("\(k?.title(s.year) ?? o.kind) · \(a?.name ?? o.sol.agency)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.money(o.sol.ceiling)).font(.title3.weight(.semibold).monospacedDigit())
                    Text(k?.payout == .programme ? "\(o.sol.months) months" : (k.map { GovStyle.payout($0) } ?? "")).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Pill(o.status.title, tone: GovStyle.statusTone(o.status))
                if o.invited { Pill("Invitation only", tone: .good) }
                if k?.payout == .programme { Pill(text: o.sol.type.short, color: AdvStyle.color(o.sol.type), symbol: o.sol.type.symbol) }
                Pill(text: o.sol.ip.short, color: .secondary)
                if let f, f.holdsNewStarts, k?.newStart ?? false, !o.invited { Pill(text: "\(f.phase == .enacted ? "Full-year CR" : f.phase.title): award may slip", color: .orange, symbol: "hourglass") }
                if let f, f.cycle > 1.2 { Pill(text: f.cycleLabel.components(separatedBy: ":").first ?? "", color: .yellow, symbol: "calendar.badge.clock") }
            }
            Text(k?.blurb ?? "").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 3) {
                if o.status == .notice, let r = o.release {
                    Label("Sources-sought notice: the solicitation is expected \(r.gameShort). Answering puts you in the agency's market research.", systemImage: "megaphone").font(.caption)
                }
                Label("Closes \(o.sol.closes.gameShort) (in \(left) day\(left == 1 ? "" : "s")) · decision expected about \(o.decisionDue.gameShort)", systemImage: "calendar").font(.caption)
                Label("Typically \(Fmt.pct(o.baseRate, decimals: 0)) funded · about \(o.field) other proposal\(o.field == 1 ? "" : "s")", systemImage: "person.3").font(.caption)
                if !o.sol.staff.isEmpty {
                    let short = GovMarket.staffShortfall(o, s)
                    Label("If won: \(GovMarket.staffText(o.sol.staff)) for \(o.sol.months) months (they leave your research while on it)\(short > 0 ? " — \(short) more than you can free today" : "")", systemImage: "person.badge.clock")
                        .font(.caption).foregroundStyle(short > 0 ? Theme.warning : .secondary)
                }
                if o.answeredNotice { Label("You answered the sources-sought notice", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.good) }
            }
            .foregroundStyle(.secondary)
            HStack {
                if o.status == .writing {
                    Label("Writing: ready \(o.writeDone?.gameShort ?? "?")", systemImage: "pencil.and.outline").font(.callout).foregroundStyle(.blue)
                    Spacer()
                } else {
                    if let why = od.blocker {
                        ToneLabel(text: why, tone: .warning, font: .caption).lineLimit(2)
                    } else {
                        OddsBar(probability: od.p, label: "Win odds (standard)", good: 0.35, warning: 0.15).frame(maxWidth: 240)
                    }
                    Spacer()
                    if o.status == .notice && !o.answeredNotice {
                        Button("Answer the notice") { store.act("Capability statement sent") { $0.answerGovNotice(o.id) } }.buttonStyle(.bordered)
                    }
                    Button("Write proposal…", action: onPropose).buttonStyle(.borderedProminent).disabled(o.status != .open || od.blocker != nil)
                }
            }
        }
    }
}

/// Fixed-deadline calls you can plan for: EU cut-offs, national competitions, compute access calls.
private struct UpcomingCalls: View {
    let state: GameState

    var body: some View {
        let s = state
        let rows = upcoming(s)
        if !rows.isEmpty {
            Card {
                CardHeader("Calls with fixed deadlines", symbol: "calendar.badge.plus")
                ForEach(Array(rows.prefix(8).enumerated()), id: \.offset) { _, r in
                    HStack {
                        Text(r.title).font(.callout)
                        Text(r.agency).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("opens about \(r.opens.gameShort) · deadline \(r.cutoff.gameShort)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Text("Fixed-deadline calls are published about their writing window ahead of the cut-off. Plan the team before they open.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func upcoming(_ s: GameState) -> [(title: String, agency: String, opens: Date, cutoff: Date)] {
        var out: [(String, String, Date, Date)] = []
        let c = GameCalendar.components(s.date)
        for k in GovMarketCatalog.kinds where !k.cutoffs.isEmpty && !k.invite && k.active(s.year) {
            for id in k.issuers {
                guard let a = AgencyCatalog.byID[id], GovMarket.blocker(k, a, s) == nil else { continue }
                let lead = max(1, Int((Double(k.window) / 30.4).rounded()))
                for m in k.cutoffs {
                    for yy in [c.year, c.year + 1] {
                        let cut = GameCalendar.date(yy, m, 15)
                        let opens = GameCalendar.addMonths(GameCalendar.date(yy, m, 1), -lead)
                        guard opens > s.date, GameCalendar.daysBetween(s.date, opens) < 400 else { continue }
                        out.append((k.title(s.year), a.short, opens, cut))
                    }
                }
            }
        }
        return out.sorted { $0.2 < $1.2 }.map { (title: $0.0, agency: $0.1, opens: $0.2, cutoff: $0.3) }
    }
}

/// Choose the effort, the lead and the price; see the odds and why.
private struct GovProposalSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let oppID: String
    @State private var effort: CaptureEffort = .standard
    @State private var lead: UUID? = nil
    @State private var price: Double = -1
    @State private var picked = false

    var body: some View {
        let s = store.game
        if let o = s.govMarket.opps.first(where: { $0.id == oppID }), let k = o.def {
            content(o, k, s)
        } else {
            VStack(spacing: 12) {
                Text("This opportunity has closed.")
                Button("Close") { dismiss() }
            }
            .padding(30)
        }
    }

    @ViewBuilder
    private func content(_ o: GovOpp, _ k: GovKindDef, _ s: GameState) -> some View {
        let leads = GovMarket.leads(s)
        let chosen = picked ? lead : leads.first?.id
        let p = price < 0 ? o.price : price
        let od = GovMarket.odds(o, s, effort: effort, lead: effort == .light ? nil : chosen, price: p)
        let days = k.days[effort.rawValue - 1]
        let ready = GameCalendar.addDays(s.date, days)
        let slack = GameCalendar.daysBetween(ready, o.sol.closes)
        let cost = GovMarket.bpCost(k, effort, s.year)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proposal: \(o.sol.title)").font(.title2.weight(.bold))
                        Text("\(o.agencyDef?.name ?? o.sol.agency) · \(k.title(s.year)) · \(Fmt.money(o.sol.ceiling))").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                }
                Text(k.blurb + " Evaluated on: " + k.criteria).font(.callout).fixedSize(horizontal: false, vertical: true)
                CardGrid(minWidth: 340, maxColumns: 2) {
                    Card {
                        CardHeader("How hard you work it", symbol: "pencil.and.list.clipboard")
                        Picker("Effort", selection: $effort) {
                            ForEach(CaptureEffort.allCases) { e in Text("\(e.title) · \(k.days[e.rawValue - 1]) days").tag(e) }
                        }
                        .pickerStyle(.segmented)
                        Text(effort.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if effort != .light {
                            Picker("Technical lead", selection: Binding(get: { chosen }, set: { lead = $0; picked = true })) {
                                Text("Nobody (founder writes it)").tag(UUID?.none)
                                ForEach(leads.prefix(25)) { e in Text("\(e.name) — \(e.role.title), skill \(Int(e.skill))\(e.star ? " ★" : "")").tag(UUID?.some(e.id)) }
                            }
                            Text("The lead writes full-time until it's in: they stop doing research meanwhile.").font(.caption2).foregroundStyle(.secondary)
                        }
                        if k.payout == .programme {
                            Divider()
                            HStack {
                                Text(o.sol.type == .grant ? "Funding requested: \(Fmt.pct(p, decimals: 0)) of the maximum" : "Price: \(Fmt.pct(p, decimals: 0)) of the ceiling")
                                Spacer()
                                Text(Fmt.money(o.sol.ceiling * p)).font(.body.monospacedDigit().weight(.semibold))
                            }
                            Slider(value: Binding(get: { p }, set: { price = ($0 * 100).rounded() / 100 }), in: 0.75...1.0)
                                .accessibilityLabel("Price as a share of the ceiling")
                                .accessibilityValue(Fmt.pct(p, decimals: 0))
                        }
                        Divider()
                        SpecRow(label: "Proposal cost", value: Fmt.money(cost))
                        SpecRow(label: "Ready", value: "\(ready.gameShort) (\(slack >= 0 ? "\(slack) days before the deadline" : "\(-slack) days too late"))", tone: slack < 1 ? .bad : (slack < 4 ? .warning : nil))
                        SpecRow(label: "Writing slots in use", value: "\(s.govMarket.opps.filter { $0.status == .writing }.count) of \(GovMarket.slots(s))")
                    }
                    Card {
                        CardHeader("Win odds", symbol: "percent")
                        OddsBar(probability: od.p, label: "Win odds", good: 0.35, warning: 0.15)
                        SpecRow(label: "Typical success rate", value: "\(Fmt.pct(od.base, decimals: 0)) · about \(Fmt.trim(od.field, 1)) other proposals")
                        ForEach(Array(od.parts.enumerated()), id: \.offset) { _, part in
                            SpecRow(label: part.0, value: (part.1 >= 0 ? "+" : "") + Fmt.trim(part.1, 1), tone: part.1 > 0.4 ? .good : (part.1 < -0.4 ? .warning : nil))
                        }
                        SpecRow(label: "Your score", value: Fmt.trim(od.score, 1))
                        Text("Odds are exp(score ÷ 5) against the field at the typical success rate: a score of 0 wins about as often as the typical proposal. A full capture, a strong lead, a past-performance record and answering the agency's sources-sought notice each move it.")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if let b = od.blocker { ToneLabel(text: b, tone: .warning, font: .caption) }
                    }
                }
                Card {
                    CardHeader("If you win", symbol: "flag.checkered")
                    switch k.payout {
                    case .programme:
                        Text("It runs as a programme on the Advanced Projects page: assign \(GovMarket.staffText(o.sol.staff)) within four months, then feasibility, research, a prototype and testing over \(o.sol.months) months, with \(o.sol.type == .grant ? "grant instalments" : "milestone payments").").font(.callout)
                        SpecRow(label: "Leaves behind", value: AgencyCatalog.templateByID[o.sol.template]?.reward ?? "")
                    case .compute:
                        Text("\(Fmt.money(o.sol.ceiling)) of GPU hours as cloud credits, spent automatically on your rentals. You publish the results.").font(.callout)
                    case .seat:
                        Text("A five-year seat on the multiple-award contract: task orders only seat holders can bid on. The guaranteed minimum is \(Fmt.money(o.sol.ceiling)).").font(.callout)
                    }
                    if let f = o.agencyDef.map({ GovMarket.fiscal(s, agency: $0) }), f.holdsNewStarts, k.newStart, !o.invited {
                        Label("\(f.name): \(f.phase == .enacted ? "full-year continuing resolution" : f.phase.title.lowercased()) — \(f.note.lowercased()). The award may slip.", systemImage: "hourglass").font(.caption).foregroundStyle(Theme.warning)
                    }
                }
                Button {
                    if store.act("Proposal under way", { $0.startGovProposal(o.id, effort: effort, lead: effort == .light ? nil : chosen, price: p) }) { dismiss() }
                } label: {
                    Label("Start writing (\(Fmt.money(cost)))", systemImage: "pencil").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(od.blocker != nil || slack < 1)
            }
            .padding(22)
        }
        .frame(width: 880, height: 720)
    }
}

// MARK: - Pipeline

private struct GovPipelineSection: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let g = s.govMarket
        let writing = g.opps.filter { $0.status == .writing }
        let out = g.opps.filter { $0.status == .submitted }.sorted { $0.decisionDue < $1.decisionDue }
        let protests = g.opps.filter { $0.status == .protesting || $0.status == .held }
        let won = (g.opps + g.history).filter { $0.status == .won }.sorted { ($0.decided ?? .distantPast) > ($1.decided ?? .distantPast) }
        VStack(alignment: .leading, spacing: 14) {
            if writing.isEmpty && out.isEmpty && protests.isEmpty && won.isEmpty {
                Card { EmptyStateView(symbol: "chart.bar.doc.horizontal", title: "Nothing in the pipeline", message: "Write a proposal from the Opportunities tab. Bids out, decisions due and awards show up here.") }
            }
            if !writing.isEmpty {
                Card {
                    CardHeader("Being written", symbol: "pencil.and.outline")
                    ForEach(writing) { o in
                        let total = max(1, GameCalendar.daysBetween(o.writeStart ?? s.date, o.writeDone ?? s.date))
                        let done = clamp(Double(GameCalendar.daysBetween(o.writeStart ?? s.date, s.date)) / Double(total), 0, 1)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(o.sol.title).font(.callout.weight(.semibold))
                                Text(o.agencyDef?.short ?? "").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(o.effortLevel?.title ?? "") · lead \(o.lead.flatMap { id in s.employees.first { $0.id == id }?.name } ?? "founder")").font(.caption).foregroundStyle(.secondary)
                            }
                            ProgressView(value: done).accessibilityLabel("Written").accessibilityValue(Fmt.pct(done, decimals: 0))
                            HStack {
                                Text("Ready \(o.writeDone?.gameShort ?? "?") · closes \(o.sol.closes.gameShort) · odds now \(Fmt.pct(GovMarket.currentOdds(o, s).p, decimals: 0))").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("Submit now") { store.act("Submitted early") { $0.submitGovProposalNow(o.id) } }.buttonStyle(.link).font(.caption)
                                Button("Stop") { store.act("Proposal dropped") { $0.abandonGovProposal(o.id) } }.buttonStyle(.link).font(.caption)
                            }
                        }
                        Divider()
                    }
                }
            }
            if !out.isEmpty {
                Card {
                    CardHeader("Under evaluation", symbol: "hourglass")
                    ForEach(out) { o in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(o.sol.title).font(.callout.weight(.semibold))
                                Text("\(o.agencyDef?.short ?? "") · \(Fmt.money(o.sol.ceiling))").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("decision about \(o.decisionDue.gameShort) · odds \(Fmt.pct(o.oddsAtSubmit, decimals: 0))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            ForEach(o.notes, id: \.self) { n in Label(n, systemImage: "hourglass").font(.caption).foregroundStyle(Theme.warning) }
                        }
                        Divider()
                    }
                }
            }
            if !protests.isEmpty {
                Card {
                    CardHeader("Protests", symbol: "exclamationmark.bubble.fill")
                    ForEach(protests) { o in
                        HStack {
                            Text(o.sol.title).font(.callout)
                            Spacer()
                            Text(o.status == .held ? "A competitor protested your award · decision by \(o.protestDue?.gameShort ?? "?")" : "Your protest (\(Fmt.money(o.protestCost))) · decision by \(o.protestDue?.gameShort ?? "?")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !won.isEmpty {
                Card {
                    CardHeader("Awards", symbol: "rosette")
                    ForEach(won.prefix(10)) { o in
                        let prog = o.programme.flatMap { id in s.advanced.programmes.first { $0.id == id } }
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.good).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(o.sol.title).font(.callout)
                                Text("\(o.agencyDef?.short ?? "") · \(o.def?.title(s.year) ?? "") · won \(o.decided?.gameShort ?? "")").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let prog {
                                if prog.status == .active && prog.stage == .award {
                                    Button("Assign the team") { store.act("Team assigned") { $0.autoStaffProgramme(prog.id) } }.buttonStyle(.bordered).font(.caption)
                                } else {
                                    Text(prog.status == .active ? "\(prog.stage.title) · \(Fmt.pct(prog.completion, decimals: 0))" : prog.status.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Button("Advanced Projects") { store.open(.advancedProjects) }.buttonStyle(.link).font(.caption)
                            } else {
                                Text(o.def.map { GovStyle.payout($0) } ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Anchor contract

private struct GovAnchorSection: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var confirmWalk = false

    var body: some View {
        let s = state
        let g = s.govMarket
        VStack(alignment: .leading, spacing: 14) {
            if let c = g.anchor {
                let a = AgencyCatalog.byID[c.agency]
                let d = GovMarket.delivery(c, s)
                let period = c.periodDelivery.isEmpty ? d : c.periodDelivery.reduce(0, +) / Double(c.periodDelivery.count)
                CardGrid(minWidth: 360, maxColumns: 2) {
                    Card {
                        CardHeader(c.title, symbol: a?.symbol ?? "building.columns", subtitle: a?.name)
                        Text(c.scope).font(.callout).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Pill(c.stopped ? "Stop-work order" : c.status.title, tone: c.stopped ? .bad : .good)
                            Pill(text: c.payment == .invoice ? "Invoiced monthly" : "Grant instalments", color: .secondary)
                            if c.defence { Pill(text: "Defence", color: .orange, symbol: "shield.fill") }
                        }
                        SpecRow(label: "Annual value", value: Fmt.money(c.annual))
                        SpecRow(label: c.payment == .invoice ? "Funded through" : "Current reporting period ends", value: c.periodEnd.gameShort)
                        SpecRow(label: c.payment == .invoice ? "Options left" : "Periods left after this one", value: "\(c.optionsLeft) of \(c.optionsTotal)")
                        SpecRow(label: "Earned · paid", value: "\(Fmt.money(c.earned)) · \(Fmt.money(c.paid))")
                        if c.payment == .tranche { SpecRow(label: "Grant total", value: Fmt.money(c.total)) }
                        OddsBar(probability: min(1, period), label: "Delivery this period (rating: \(GovMarket.rating(period)))", good: 0.9, warning: 0.75)
                        if c.awaitingOption { ToneLabel(text: "The next option waits for appropriations: no billing until it's exercised.", tone: .warning, font: .caption) }
                        if c.underStaffedMonths > 0 { ToneLabel(text: "Under-staffed for \(c.underStaffedMonths) month\(c.underStaffedMonths == 1 ? "" : "s"): four in a row and it's terminated for default.", tone: .bad, font: .caption) }
                        Text("Each month the team bills its share of the annual value (less if it's short of people). At the end of each period \(a?.short ?? "the agency") rates delivery: satisfactory or better and the next \(c.payment == .invoice ? "option is exercised" : "period is approved") — very good work earns a scope increase.")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Card {
                        CardHeader("The team", symbol: "person.3.fill")
                        Text("Needs \(GovMarket.staffText(c.staff)). People on it don't do research or other work.").font(.caption).foregroundStyle(.secondary)
                        ForEach(s.employees.filter { c.assigned.contains($0.id) }) { e in
                            HStack {
                                Text(e.name).font(.callout)
                                Text("\(e.role.title) · skill \(Int(e.skill))").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button { store.act { $0.assignAnchor(e.id, on: false) } } label: { Image(systemName: "minus.circle") }
                                    .buttonStyle(.borderless).accessibilityLabel("Take \(e.name) off the contract")
                            }
                        }
                        HStack {
                            Button("Auto-staff") { store.act("Team assigned") { $0.autoStaffAnchor() } }.buttonStyle(.bordered)
                            AnchorAddMenu(contract: c, state: s)
                            Spacer()
                            Button("End early…", role: .destructive) { confirmWalk = true }.buttonStyle(.link)
                        }
                        SpecRow(label: "Delivery with this team", value: Fmt.pct(d, decimals: 0), tone: d < 0.6 ? .bad : (d < 0.9 ? .warning : .good))
                    }
                }
                .confirmationDialog("End \(c.title) early?", isPresented: $confirmWalk, titleVisibility: .visible) {
                    Button("End the contract", role: .destructive) { store.mutate { $0.walkAwayAnchor() } }
                    Button("Keep it", role: .cancel) {}
                } message: {
                    Text("\(a?.short ?? "The agency") notes it on your record (−1)\(c.payment == .tranche ? " and you repay unearned pre-financing (\(Fmt.money(max(0, c.paid - c.earned))))" : "").")
                }
                Card {
                    CardHeader("Contract log", symbol: "list.bullet.rectangle")
                    ForEach(Array(c.history.suffix(14).reversed().enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .top) {
                            Text(e.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 90, alignment: .leading)
                            Text(e.text).font(.caption).foregroundStyle(e.tone < 0 ? Theme.warning : (e.tone > 0 ? .primary : .secondary)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Card {
                    if s.decisions.contains(where: { $0.kind == GovMarket.anchorKind }) {
                        EmptyStateView(symbol: "envelope.badge", title: "An offer is waiting in your inbox", message: "Two public buyers have offered a funded multi-year agreement. Answer it on the Dashboard.")
                    } else if g.anchorDeclined && g.pastAnchors.isEmpty {
                        EmptyStateView(symbol: "doc.text", title: "No anchor contract", message: "You passed on the founding offer. Win work on the marketplace instead: a delivered contract counts the same on your record.")
                    } else {
                        EmptyStateView(symbol: "doc.text", title: "No active anchor contract", message: "Your founding agreement has ended. Its ratings stay on your record.")
                    }
                }
            }
            if !g.pastAnchors.isEmpty {
                Card {
                    CardHeader("Earlier agreements", symbol: "clock.arrow.circlepath")
                    ForEach(g.pastAnchors) { c in
                        HStack {
                            Text(c.title).font(.callout)
                            Text(AgencyCatalog.byID[c.agency]?.short ?? c.agency).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(c.status.title) · \(Fmt.money(c.paid)) paid · \(c.start.gameShort)–\(c.ended?.gameShort ?? "")").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct AnchorAddMenu: View {
    @Environment(GameStore.self) private var store
    let contract: AnchorContract
    let state: GameState

    var body: some View {
        let s = state
        let roles = Set(contract.staff.keys)
        let busy = s.advanced.seconded.union(GovMarket.committed(s))
        let pool = s.employees.filter { roles.contains($0.role.rawValue) && !busy.contains($0.id) }.sorted { $0.skill > $1.skill }
        Menu("Add…") {
            ForEach(pool.prefix(30)) { e in
                Button("\(e.name) — \(e.role.title), skill \(Int(e.skill))") { store.act { $0.assignAnchor(e.id, on: true) } }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .font(.caption)
    }
}

// MARK: - Budget calendars

private struct GovCalendarsSection: View {
    let state: GameState

    var body: some View {
        let s = state
        var cals = GovMarket.relevantCalendars(s)
        for c in ["us", "eu"] where !cals.contains(c) { cals.append(c) }
        return VStack(alignment: .leading, spacing: 14) {
            Card {
                Text("Public money moves on budget calendars. The US fiscal year starts on 1 October; Congress rarely passes it on time, so most years start under a continuing resolution (last year's rate, no new starts) and some under a shutdown, when contractors stop billing. Unspent money expires on 30 September, so August and September bring a rush of awards. European budgets run with the calendar year: the EU's calls come with its work programmes, and national ministries rush to commit money before December ends.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: Theme.columns(min: 460), alignment: .leading, spacing: Theme.gap) {
                ForEach(cals, id: \.self) { cal in CalendarCard(cal: cal, state: s) }
            }
        }
    }
}

private struct CalendarCard: View {
    let cal: String
    let state: GameState

    var body: some View {
        let s = state
        let f = GovMarket.fiscal(s, cal, at: s.date, agency: cal == "eu" ? "ereo" : "")
        let months = (0..<12).map { GameCalendar.addMonths(f.fyStart, $0) }
        Card {
            CardHeader(f.name, symbol: cal == "us" ? "flag.fill" : (cal == "eu" ? "eurosign.circle.fill" : "building.columns.fill"), subtitle: f.fyLabel)
            HStack(spacing: 6) {
                Pill(f.phase.title, tone: GovStyle.tone(f.phase))
                if f.fullYearCR { Pill("Full-year CR", tone: .warning) }
                if !f.cycleLabel.isEmpty { Pill(text: f.cycleLabel.components(separatedBy: ":").first ?? "", color: f.cycle > 1 ? .yellow : .secondary, symbol: "calendar") }
            }
            if f.phase != .enacted { Text("\(f.note). \(GovMarket.untilText(f, s).prefix(1).uppercased() + GovMarket.untilText(f, s).dropFirst()).").font(.caption).fixedSize(horizontal: false, vertical: true) }
            else if !f.note.isEmpty { Text(f.note + ".").font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 3) {
                ForEach(Array(months.enumerated()), id: \.offset) { _, m in
                    let mid = GameCalendar.addDays(m, 14)
                    let past = mid <= s.date
                    // The future shows only the regular cycle: nobody knows yet whether Congress will be late.
                    let mf = GovMarket.fiscal(s, cal, at: past ? mid : m, agency: cal == "eu" ? "ereo" : "")
                    let color: Color = past && mf.phase == .lapse ? .red : (past && mf.phase != .enacted ? .orange : (mf.cycle > 1.2 ? .yellow : (mf.cycle < 0.9 ? .gray : .green)))
                    let current = m.ym == s.date.ym
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3).fill(color.opacity(past ? 0.75 : 0.35)).frame(height: 16)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(current ? Color.primary : .clear, lineWidth: 1.5))
                        Text(String(m.gameMonth.prefix(3))).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(m.gameMonth): \(past ? mf.phase.title : "regular cycle")\(mf.cycleLabel.isEmpty ? "" : ", \(mf.cycleLabel)")")
                }
            }
            HStack(spacing: 10) {
                LegendItem(color: .green, label: "Normal")
                LegendItem(color: .yellow, label: "Spending rush")
                LegendItem(color: .gray, label: "Slow start")
                LegendItem(color: .orange, label: "CR / provisional")
                LegendItem(color: .red, label: "Lapse")
            }
            .font(.caption2)
        }
    }
}

// MARK: - Record

private struct GovRecordSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let g = s.govMarket
        let rec = GovMarket.record(s)
        let decided = (g.opps + g.history).filter { $0.status == .won || $0.status == .lost || $0.status == .missed }
            .sorted { ($0.decided ?? .distantPast, $0.id) > ($1.decided ?? .distantPast, $1.id) }
        let known = (AgencyCatalog.all + GovMarketCatalog.agencies).filter { s.advanced.ratings[$0.id] != nil }.sorted { AdvancedProjects.rating(s, $0.id) > AdvancedProjects.rating(s, $1.id) }
        VStack(alignment: .leading, spacing: 14) {
            CardGrid(minWidth: 340, maxColumns: 2) {
                Card {
                    CardHeader("Past performance", symbol: "checkmark.seal")
                    SpecRow(label: "Evaluators see", value: rec.text)
                    SpecRow(label: "Programmes delivered", value: "\(rec.delivered)")
                    SpecRow(label: "Terminations for default", value: "\(rec.defaults)", tone: rec.defaults > 0 ? .bad : nil)
                    ForEach(Array(g.assessments.prefix(6).enumerated()), id: \.offset) { _, a in
                        SpecRow(label: "\(a.date.gameShort) · \(AgencyCatalog.byID[a.agency]?.short ?? a.agency)", value: a.rating, tone: a.score >= 0.75 ? .good : .warning)
                    }
                    Text("Every delivered programme and yearly rating counts in every evaluation; a default counts against you for years.").font(.caption2).foregroundStyle(.secondary)
                }
                Card {
                    CardHeader("Agencies that know you", symbol: "building.columns")
                    if known.isEmpty { Text("No record with any agency yet.").font(.caption).foregroundStyle(.secondary) }
                    ForEach(known.prefix(10)) { a in
                        SpecRow(label: a.name, value: (AdvancedProjects.rating(s, a.id) >= 0 ? "+" : "") + Fmt.trim(AdvancedProjects.rating(s, a.id), 1), tone: AdvancedProjects.rating(s, a.id) >= 0 ? nil : .warning)
                    }
                    ForEach(g.seats) { seat in
                        SpecRow(label: "Seat: \(seat.name)", value: "to \(seat.ends.gameShort)")
                    }
                    Divider()
                    SpecRow(label: "Proposal spending", value: Fmt.money(g.bpSpent))
                    SpecRow(label: "Compute allocations won", value: Fmt.money(g.computeAwarded))
                    SpecRow(label: "Protests filed · won", value: "\(g.protestsFiled) · \(g.protestsWon)")
                }
            }
            Card {
                CardHeader("Decisions and debriefs", symbol: "doc.text.magnifyingglass")
                if decided.isEmpty { Text("Decided bids, with the agency's debrief, appear here.").font(.caption).foregroundStyle(.secondary) }
                ForEach(decided.prefix(20)) { o in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(o.debrief, id: \.self) { l in Text(l).font(.caption).fixedSize(horizontal: false, vertical: true) }
                            if o.finalOdds > 0 { Text("Odds at the decision \(Fmt.pct(o.finalOdds, decimals: 0)); the roll was \(Fmt.trim(o.roll, 2)).").font(.caption2).foregroundStyle(.secondary) }
                            if !o.protestOutcome.isEmpty { Text("Protest: \(o.protestOutcome)").font(.caption).foregroundStyle(Theme.warning) }
                            ForEach(o.notes, id: \.self) { n in Text(n).font(.caption2).foregroundStyle(.secondary) }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack {
                            Image(systemName: o.status == .won ? "checkmark.seal.fill" : "xmark.seal").foregroundStyle(o.status == .won ? Theme.good : .secondary)
                                .accessibilityLabel(o.status.title)
                            Text(o.sol.title).font(.callout)
                            Text(o.agencyDef?.short ?? "").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(o.status == .missed ? "Missed the deadline" : (o.status == .won ? "Won · \(Fmt.money(o.sol.ceiling))" : "Lost to \(o.winner)")).font(.caption).foregroundStyle(.secondary)
                            Text(o.decided?.gameShort ?? "").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}
