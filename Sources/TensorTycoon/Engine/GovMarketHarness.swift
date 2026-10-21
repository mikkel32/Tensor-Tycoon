import Foundation

/// 3.9: `--replay-save <save> <days> gov` prints what the government marketplace shows the player as a save plays on
/// (budget calendars, open work, the pipeline, the anchor contract, decisions and debriefs); `gov:auto` also plays it
/// the way an attentive player would: answers notices, writes the best proposals, staffs what it wins, signs the first
/// anchor offer and protests close losses.
enum GovMarketHarness {
    nonisolated(unsafe) private static var seenNews = Set<String>()
    nonisolated(unsafe) private static var seenDecisions = Set<UUID>()

    static let keywords = ["award", "Proposal", "proposal", "Contract", "contract", "Congress", "shuts down", "reopens", "budget", "Protest", "protest",
                           "invites", "Year-end", "Compute allocation", "Seat won", "rates your work", "Stop-work", "terminates", "lapse", "Programme delivered",
                           "Award", "follow-on", "pause", "adopts", "starts the year"]

    static func tick(_ s: inout GameState, auto: Bool) {
        // Decisions the marketplace raised today.
        for d in s.decisions where [GovMarket.anchorKind, GovMarket.yearEndKind, GovMarket.protestKind].contains(d.kind) && !seenDecisions.contains(d.id) {
            seenDecisions.insert(d.id)
            print("    GOV DECISION \(d.title): \(d.body)")
            for (i, o) in d.options.enumerated() { print("      [\(i)] \(o.label) — \(o.detail)") }
            if auto {
                let pick = d.kind == GovMarket.protestKind ? (d.amount <= max(0, s.cash) * 0.01 ? 1 : 0) : 1   // sign the first offer, take the order
                print("      -> auto: \(d.options[pick].label)")
                s.resolveDecision(d.id, option: pick)
            }
        }
        for n in s.news.prefix(12) where n.date == s.date && keywords.contains(where: { n.title.contains($0) }) {
            let key = "\(n.date.timeIntervalSince1970)|\(n.title)"
            guard !seenNews.contains(key) else { continue }
            seenNews.insert(key)
            print("    GOV NEWS: \(n.title) — \(n.body)")
        }
        // Slips (continuing resolutions, shutdowns) and the anchor contract's log, as the player reads them.
        for o in s.govMarket.opps { for n in o.notes where !seenNews.contains("note|\(o.id)|\(n)") { seenNews.insert("note|\(o.id)|\(n)"); print("    GOV NOTE \(o.sol.title): \(n)") } }
        if let c = s.govMarket.anchor { for e in c.history where e.date == s.date { print("    ANCHOR LOG: \(e.text)") } }
        if auto { play(&s) }
        if GameCalendar.components(s.date).day == 1 { summary(s) }
    }

    static func summary(_ s: GameState) {
        let g = s.govMarket
        let cals = GovMarket.relevantCalendars(s).map { c -> String in
            let f = GovMarket.fiscal(s, c, at: s.date)
            return "\(f.name) \(f.fyLabel): \(f.phase.title)\(f.until.map { " to \($0.gameShort)" } ?? "")\(f.cycleLabel.isEmpty ? "" : " [\(f.cycleLabel)]")"
        }.joined(separator: "; ")
        print("  GOV \(s.date.gameShort) · \(cals)")
        let open = g.opps.filter { $0.status == .open || $0.status == .notice }
        print("    open \(open.count): " + open.prefix(8).map { o in
            "\(o.def?.title(s.year) ?? o.kind) / \(o.agencyDef?.short ?? "") \"\(o.sol.title)\" \(Fmt.money(o.sol.ceiling)) closes \(o.sol.closes.gameShort) odds \(Fmt.pct(GovMarket.currentOdds(o, s).p, decimals: 0))\(o.status == .notice ? " (notice)" : "")"
        }.joined(separator: " | "))
        let pipe = g.pipeline
        if !pipe.isEmpty {
            print("    pipeline: " + pipe.map { "\($0.status.title): \($0.sol.title) (\($0.agencyDef?.short ?? ""), \(Fmt.money($0.sol.ceiling)), due \($0.status == .writing ? ($0.writeDone?.gameShort ?? "") : $0.decisionDue.gameShort), odds \(Fmt.pct($0.status == .writing ? GovMarket.currentOdds($0, s).p : $0.oddsAtSubmit, decimals: 0)))" }.joined(separator: " | "))
        }
        if let c = g.anchor {
            let team = s.employees.filter { c.assigned.contains($0.id) }.map { "\($0.name) (\($0.role.title), \(Int($0.skill)))" }.joined(separator: ", ")
            print("    anchor \(AgencyCatalog.byID[c.agency]?.short ?? c.agency) \"\(c.title)\": \(Fmt.money(c.annual))/yr · period to \(c.periodEnd.gameShort) · options left \(c.optionsLeft) · earned \(Fmt.money(c.earned)) paid \(Fmt.money(c.paid)) · delivery \(Fmt.pct(GovMarket.delivery(c, s), decimals: 0))\(c.stopped ? " · STOP-WORK" : "") · team: \(team)")
        }
        let progs = s.advanced.programmes.filter { $0.sol.template.hasPrefix("gm_") }
        if !progs.isEmpty {
            print("    programmes: " + progs.map { "\($0.sol.title) [\($0.status == .active ? $0.stage.title : $0.status.title) \(Fmt.pct($0.completion, decimals: 0)), paid \(Fmt.money($0.contractRevenue)) of \(Fmt.money($0.value))]" }.joined(separator: " | "))
        }
        let rated = (AgencyCatalog.all + GovMarketCatalog.agencies).filter { s.advanced.ratings[$0.id] != nil }.map { "\($0.short) \(Fmt.trim(AdvancedProjects.rating(s, $0.id), 1))" }
        print("    record: \(GovMarket.record(s).text) · won \(g.wins) lost \(g.losses) · awarded \(Fmt.money(g.awarded)) · B&P \(Fmt.money(g.bpSpent)) · compute \(Fmt.money(g.computeAwarded)) · seats \(g.seats.count) · ratings: \(rated.joined(separator: ", "))")
        for o in g.history.prefix(3) where o.decided.map({ GameCalendar.daysBetween($0, s.date) <= 31 }) ?? false {
            print("    debrief \(o.sol.title) (\(o.status.title)): " + o.debrief.joined(separator: " "))
        }
    }

    /// An attentive player: answer notices, write the most valuable proposals the team can carry, staff the wins.
    static func play(_ s: inout GameState) {
        for o in s.govMarket.opps where o.status == .notice && !o.answeredNotice { _ = s.answerGovNotice(o.id) }
        var ranked: [(value: Double, opp: GovOpp)] = []
        for o in s.govMarket.opps where o.status == .open {
            let od = GovMarket.currentOdds(o, s)
            if od.blocker == nil { ranked.append((od.p * o.sol.ceiling, o)) }
        }
        ranked.sort { ($0.value, $0.opp.id) > ($1.value, $1.opp.id) }
        for (_, o) in ranked where GovMarket.staffShortfall(o, s) == 0 {
            guard let k = o.def, GovMarket.slots(s) > s.govMarket.opps.filter({ $0.status == .writing }).count else { break }
            let left = GameCalendar.daysBetween(s.date, o.sol.closes)
            let effort: CaptureEffort = k.days[2] < left && o.sol.ceiling >= 400_000 ? .full : (k.days[1] < left ? .standard : .light)
            guard k.days[effort.rawValue - 1] < left else { continue }
            let price = o.sol.type == .grant ? 0.95 : 0.9
            if let why = s.startGovProposal(o.id, effort: effort, lead: GovMarket.bestLead(s)?.id, price: price) {
                print("    auto: couldn't start \(o.sol.title): \(why)")
            } else {
                print("    auto: writing \(o.sol.title) (\(effort.title), \(Fmt.pct(GovMarket.currentOdds(s.govMarket.opps.first { $0.id == o.id } ?? o, s).p, decimals: 0)))")
            }
        }
        for p in s.advanced.programmes where p.status == .active && p.stage == .award && p.sol.template.hasPrefix("gm_") {
            if let why = s.autoStaffProgramme(p.id) { if GameCalendar.components(s.date).day == 1 { print("    auto-staff \(p.sol.title): \(why)") } }
        }
        if let c = s.govMarket.anchor, c.status == .active, GovMarket.delivery(c, s) < 0.9 { _ = s.autoStaffAnchor() }
    }
}
