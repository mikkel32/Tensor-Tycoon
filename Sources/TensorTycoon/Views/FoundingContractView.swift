import SwiftUI

// MARK: - 3.9: the founding government contract — dashboard card and the Advanced Projects card

/// Shared read-outs for the two cards.
enum FoundingUI {
    static func tone(_ st: FCStatus) -> Tone {
        switch st {
        case .offered: .info
        case .active: .good
        case .stopWork, .terminated: .bad
        case .lapsed: .warning
        case .completed: .accent
        case .declined: .neutral
        }
    }

    static func ratingTone(_ r: Int) -> Tone { r >= 3 ? .good : (r == 2 ? .neutral : (r == 1 ? .warning : .bad)) }

    /// "Met 12 Mar", "Overdue 20 days", "Due in 34 days".
    static func when(_ m: FCMilestone, _ today: Date) -> (String, Tone) {
        if let met = m.met { return ("Met \(met.gameShort)\(met > m.due ? " (late)" : "")", met > m.due ? .warning : .good) }
        let d = GameCalendar.daysBetween(today, m.due)
        if d < 0 { return ("Overdue \(-d) days", .bad) }
        return (d == 0 ? "Due today" : "Due in \(d) days · \(m.due.gameShort)", d < 30 ? .warning : .neutral)
    }

    /// Where the player stands on a milestone, in the game's own numbers.
    static func hint(_ s: GameState, _ c: FoundingContract, _ m: FCMilestone) -> String? {
        guard m.met == nil else { return nil }
        switch m.kind {
        case .staffing:
            return "\(FoundingContracts.technicalStaff(s)) of \(Int(m.target)) technical staff — hire on the Team page."
        case .research:
            let cost = ResearchLab.entryCost(s, m.ref)
            let done = s.researchProgress[m.ref] ?? 0
            return "\(Fmt.pct(clamp(done / max(1, cost), 0, 1), decimals: 0)) researched" + (s.researchQueue.contains(m.ref) ? " · in your queue" : " · not queued yet")
        case .model, .release:
            let best = FoundingContracts.newModels(s, c).max { $0.c < $1.c }
            let run = s.runs.filter { $0.status == .running || $0.status == .postTraining }.compactMap(\.forecast).max { $0.c < $1.c }
            var t = "Bar: \(FoundingContracts.barText(s, m.target)). "
            t += best.map { "Best since the award: \($0.name), capability \(Fmt.trim($0.c, 2)) (index \(Fmt.score($0.index)))." } ?? "No model trained since the award yet."
            if let run { t += " In training: forecast capability \(Fmt.trim(run.c, 2))\(run.c >= m.target ? " — on track" : "")." }
            if m.kind == .release, let best, best.c >= m.target, !best.released { t += " Release \(best.name) to demonstrate it." }
            return t
        case .paper:
            let pending = s.fun.papers.filter { $0.outcome == .submitted }.count
            return "\(FoundingContracts.acceptedPapers(s) - c.papersAtStart) accepted since the award\(pending > 0 ? ", \(pending) under review" : ""). Submit when a conference calls for papers."
        case .safety:
            return m.target > 0 ? "Safety score \(Int(s.safetyScore)) of \(Int(m.target))." : (FoundingContracts.newModels(s, c).contains { $0.evalDue != nil } ? "Evaluation commissioned; the report is due." : "No evaluated model since the award.")
        case .final:
            let left = c.milestones.filter { $0.kind != .final && $0.met == nil }.count
            return left > 0 ? "Waits for the other \(left) milestone\(left == 1 ? "" : "s")." : "Being written: three weeks after the last milestone."
        default:
            return nil
        }
    }

    static func steps(_ s: GameState, _ c: FoundingContract) -> [StageStep] {
        let next = c.next(s.date)?.id
        return c.milestones.map { m in
            let status: StageStep.Status = m.met != nil ? .done : (m.due < s.date ? .failed : (m.id == next ? .current : .upcoming))
            return StageStep(id: m.id, title: FoundingContracts.title(m.kind), status: status, progress: m.met != nil ? 1 : nil,
                             note: m.met == nil && m.due < s.date ? "late" : nil, help: "\(m.title) — due \(m.due.gameShort)")
        }
    }

    static func elapsed(_ s: GameState, _ c: FoundingContract) -> Double {
        let total = max(1, GameCalendar.daysBetween(c.start, c.end))
        return clamp(Double(GameCalendar.daysBetween(c.start, s.date)) / Double(total), 0, 1)
    }
}

/// The dashboard's card: the founding award as the player's first goal.
struct FoundingContractDashboardCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        if let c = s.founding.current, show(c, s) {
            Card {
                CardHeader(title: c.phase == 1 && c.status != .completed ? "First goal: your government award" : "Government award",
                           symbol: "seal.fill", subtitle: "\(c.agencyShort) · \(c.programme)") {
                    Button("Details") { store.open(.advancedProjects) }.buttonStyle(.link)
                }
                HStack(spacing: 6) {
                    Text(c.title).font(.callout.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 4)
                    Pill(c.status.title, tone: FoundingUI.tone(c.status))
                }
                if c.status == .offered {
                    Text("\(Fmt.money(c.budget)) over \(c.months) months, \(c.terms.short.lowercased()). Sign it to start the clock; if you don't answer by \(c.offerExpires?.gameShort ?? "the deadline"), the standard scope is signed for you.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let d = s.decisions.first(where: { $0.ref == c.id }) {
                        Button("Review the offer") { store.openDecisionID = d.id }.buttonStyle(.borderedProminent).controlSize(.small)
                    }
                } else if c.status.live {
                    StageStrip(steps: FoundingUI.steps(s, c), tint: .indigo)
                    if let m = c.next(s.date) {
                        let w = FoundingUI.when(m, s.date)
                        ToneLabel(text: "Next: \(m.title) — \(w.0)", tone: w.1, font: .caption.weight(.semibold))
                        if let h = FoundingUI.hint(s, c, m) { Text(h).font(.caption2).foregroundStyle(.secondary).lineLimit(3) }
                    }
                    HStack(spacing: Theme.Space.s) {
                        MetricTile(label: "Budget", value: Fmt.money(c.budget), style: .plain)
                        MetricTile(label: "Received", value: Fmt.money(c.paid), tint: Theme.good, style: .plain)
                        MetricTile(label: c.terms == .fixedPrice ? "Your cost" : "Charged", value: Fmt.money(c.charged), style: .plain)
                        MetricTile(label: "Ends", value: c.end.gameShort, style: .plain)
                    }
                    if let cure = c.cureUntil { ToneLabel(text: "Cure notice: deliver the overdue work by \(cure.gameShort)", tone: .warning, font: .caption.weight(.semibold)) }
                    if c.status == .stopWork, let u = c.stopUntil { ToneLabel(text: "Stop-work order: payments held; terminated \(u.gameShort) unless the overdue work is in", tone: .bad, font: .caption.weight(.semibold)) }
                } else {
                    Text(summary(c)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Shown while it's on offer or running, and for three months after it ends.
    private func show(_ c: FoundingContract, _ s: GameState) -> Bool {
        if c.status == .offered || c.status.live { return true }
        return c.ended.map { GameCalendar.daysBetween($0, s.date) < 90 } ?? false
    }

    private func summary(_ c: FoundingContract) -> String {
        switch c.status {
        case .completed: "Completed and rated \(FCRating.title(c.finalRating ?? 2)): \(Fmt.money(c.paid)) received. Your record with \(c.agencyShort) counts on the Advanced Projects marketplace."
        case .lapsed: "Closed out incomplete: \(Fmt.money(c.paid)) received, rated \(FCRating.title(c.finalRating ?? 1))."
        case .terminated: "Terminated for default. \(c.agencyShort) will remember."
        case .declined: "You declined the award."
        default: ""
        }
    }
}

/// The Advanced Projects page's card: the whole award — statement of work, money, review, audit and history.
struct FoundingContractCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var showHistory = false

    var body: some View {
        let s = state
        if let c = s.founding.current {
            Card {
                CardHeader(title: "Founding award: \(c.agencyDef?.name ?? c.agency)", symbol: "seal.fill", subtitle: "\(c.programme) · \(c.number)") {
                    Pill(c.status.title, tone: FoundingUI.tone(c.status))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.title).font(.headline)
                    Text(c.objective).font(.callout).foregroundStyle(.secondary)
                    Label(FoundingContracts.termsLine(c), systemImage: c.terms.symbol).font(.caption).foregroundStyle(.secondary)
                }
                if c.status == .offered {
                    offered(c, s)
                } else {
                    money(c, s)
                    if c.status.live {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Period of performance").font(.caption.weight(.semibold))
                                Spacer()
                                Text("\(c.start.gameShort) – \(c.end.gameShort)\(c.extensionMonths > 0 ? " (extended \(c.extensionMonths) months)" : "")").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Meter(value: FoundingUI.elapsed(s, c), tint: .indigo, height: 6)
                        }
                        StageStrip(steps: FoundingUI.steps(s, c), tint: .indigo)
                    }
                    milestones(c, s)
                    oversight(c, s)
                    actions(c, s)
                }
                DisclosureGroup(isExpanded: $showHistory) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(s.founding.contracts.flatMap { k in k.history.map { (k.phase, $0) } }.sorted { $0.1.date > $1.1.date }.prefix(40).enumerated()), id: \.offset) { _, e in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(e.1.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 74, alignment: .leading)
                                Image(systemName: e.1.tone > 0 ? "checkmark.circle.fill" : (e.1.tone < 0 ? "exclamationmark.triangle.fill" : "circle"))
                                    .font(.caption2).foregroundStyle(e.1.tone > 0 ? Theme.good : (e.1.tone < 0 ? Theme.warning : .secondary)).accessibilityHidden(true)
                                Text(e.1.text).font(.caption)
                            }
                        }
                    }
                } label: {
                    Text("History and reports").font(.caption.weight(.semibold))
                }
                let past = s.founding.contracts.dropFirst()
                if !past.isEmpty {
                    ForEach(Array(past)) { p in
                        Text("Earlier: \(p.programme) — \(p.status.title)\(p.finalRating.map { ", rated \(FCRating.title($0))" } ?? ""), \(Fmt.money(p.paid)) received.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder private func offered(_ c: FoundingContract, _ s: GameState) -> some View {
        HStack(spacing: Theme.Space.s) {
            MetricTile(label: "Award", value: Fmt.money(c.budget), symbol: "dollarsign.circle")
            MetricTile(label: "Period", value: "\(c.months) months", symbol: "calendar")
            MetricTile(label: "Terms", value: c.terms.short, symbol: c.terms.symbol)
        }
        Text("Signing starts the period of performance. Unanswered by \(c.offerExpires?.gameShort ?? "the deadline"), the standard scope is signed for you.")
            .font(.caption).foregroundStyle(.secondary)
        if let d = s.decisions.first(where: { $0.ref == c.id }) {
            Button("Review the offer") { store.openDecisionID = d.id }.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private func money(_ c: FoundingContract, _ s: GameState) -> some View {
        let spentLabel = c.terms == .fixedPrice ? "Your cost so far" : (c.terms == .grant ? "Eligible costs claimed" : "Costs charged")
        HStack(spacing: Theme.Space.s) {
            MetricTile(label: c.terms == .costPlus ? "Ceiling (incl. fee)" : (c.terms == .grant ? "Maximum grant" : "Price"), value: Fmt.money(c.budget), symbol: "banknote")
            MetricTile(label: "Received", value: Fmt.money(c.paid), symbol: "arrow.down.circle", tint: Theme.good)
            MetricTile(label: spentLabel, value: Fmt.money(c.charged), symbol: "chart.bar.fill")
            MetricTile(label: "Still to come", value: Fmt.money(c.status.live ? c.remaining : 0), symbol: "hourglass")
        }
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Budget drawn").font(.caption)
                Spacer()
                Text("\(Fmt.pct(c.paid / max(1, c.budget), decimals: 0)) of \(Fmt.money(c.budget))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Meter(value: c.paid / max(1, c.budget), tint: .green, height: 6)
            Text(moneyNote(c, s)).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func moneyNote(_ c: FoundingContract, _ s: GameState) -> String {
        switch c.terms {
        case .fixedPrice:
            let margin = c.paid - c.charged
            return "Each accepted milestone pays its slice of the price. What you've spent on the work so far against what you've been paid: \(margin >= 0 ? "+" : "−")\(Fmt.money(abs(margin)))."
        case .costPlus:
            return "Fee \(Fmt.money(c.fee)) (\(Fmt.money(c.feePaid)) paid) · cost ceiling \(Fmt.money(c.costCeiling)) · indirect rate \(Fmt.pct(c.indirectRate, decimals: 0))\(c.voucher > 0 ? " · voucher of \(Fmt.money(c.voucher)) due next month" : "")."
        case .grant:
            let earned = FoundingContracts.grantEarned(c) * c.budget
            let planned = c.budget / max(0.1, c.fundingRate)
            return "Accepted work has earned \(Fmt.money(earned)) of the grant; \(Fmt.money(c.paid)) received (the advance is cleared first, \(Fmt.pct(c.retention, decimals: 0)) waits for the final report). The grant covers \(Fmt.pct(c.fundingRate, decimals: 0)) of a planned \(Fmt.money(planned)) cost; you've spent \(Fmt.money(c.charged)) on the work."
        }
    }

    @ViewBuilder private func milestones(_ c: FoundingContract, _ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statement of work").font(.caption.weight(.semibold))
            ForEach(c.milestones) { m in
                let w = FoundingUI.when(m, s.date)
                let pays = m.met != nil ? m.paid : (c.terms == .grant ? m.share * c.budget : FoundingContracts.milestonePayment(c, m))
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: m.met != nil ? "checkmark.circle.fill" : m.kind.symbol)
                        .foregroundStyle(m.met != nil ? Theme.good : (w.1 == .bad ? Theme.bad : .secondary))
                        .frame(width: 18).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(m.title).font(.callout.weight(.medium))
                            Spacer(minLength: 6)
                            if pays > 0.5 { Text(m.met != nil ? "paid \(Fmt.money(pays))" : (c.terms == .grant ? "earns \(Fmt.money(pays))" : "pays \(Fmt.money(pays))")).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                            ToneLabel(text: w.0, tone: w.1, font: .caption)
                        }
                        Text(m.detail).font(.caption).foregroundStyle(.secondary)
                        if let h = FoundingUI.hint(s, c, m) { Text(h).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private func oversight(_ c: FoundingContract, _ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Oversight").font(.caption.weight(.semibold))
            SpecRow(label: "Programme manager · \(c.terms == .grant ? "grant" : "contracting") officer", value: "\(c.manager) · \(c.officer)")
            if let r = c.reviewRating {
                SpecRow(label: "Mid-term review", value: FCRating.title(r), tone: FoundingUI.ratingTone(r))
            } else if c.status.live {
                let r = FoundingContracts.rating(FoundingContracts.progressScore(s, c))
                SpecRow(label: "Mid-term review \(c.midterm.gameShort) · tracking", value: FCRating.title(r), tone: FoundingUI.ratingTone(r))
            }
            if let r = c.finalRating { SpecRow(label: "Final rating", value: FCRating.title(r), tone: FoundingUI.ratingTone(r)) }
            SpecRow(label: "Reports filed", value: "\(c.reports) quarterly")
            if c.audited { SpecRow(label: "Closeout audit", value: c.disallowed > 0 ? "\(Fmt.money(c.disallowed)) disallowed" : "Clean", tone: c.disallowed > 0 ? .warning : .good) }
            SpecRow(label: "No-cost extension", value: c.extensionMonths > 0 ? "\(c.extensionMonths) months granted" : (c.extensionAsked ? "Not taken" : "Available once"))
            SpecRow(label: "Your record with \(c.agencyShort)", value: Fmt.trim(AdvancedProjects.rating(s, c.agency), 1))
            if let cure = c.cureUntil { ToneLabel(text: "Cure notice: deliver the overdue work by \(cure.gameShort), or work stops", tone: .warning, font: .caption.weight(.semibold)) }
            if c.status == .stopWork, let u = c.stopUntil { ToneLabel(text: "Stop-work order: payments held; terminated for default on \(u.gameShort) unless the overdue work is in", tone: .bad, font: .caption.weight(.semibold)) }
        }
    }

    @ViewBuilder private func actions(_ c: FoundingContract, _ s: GameState) -> some View {
        if c.status.live {
            HStack(spacing: Theme.Space.s) {
                if let m = c.milestones.first(where: { $0.kind == .research && $0.met == nil }), !s.researchQueue.contains(m.ref) {
                    Button("Queue \(ResearchCatalog.byID[m.ref]?.name ?? "the research")") { store.act("Queued") { $0.queueFoundingResearch() } }
                }
                if c.milestones.contains(where: { ($0.kind == .model || $0.kind == .release) && $0.met == nil }) {
                    Button("Model Lab") { store.open(.lab) }
                }
                if c.milestones.contains(where: { $0.kind == .staffing && $0.met == nil }) {
                    Button("Hire") { store.open(.team) }
                }
                Spacer()
                if c.extensionMonths == 0 && FoundingContracts.needsMoreTime(c) && s.date >= c.midterm {
                    Button("Request a \(FoundingContracts.extensionMonths(c))-month no-cost extension") { store.act("Extension granted") { $0.requestFoundingExtension() } }
                }
            }
            .controlSize(.small)
        }
    }
}
