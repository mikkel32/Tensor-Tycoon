import Foundation

/// 3.9: government-relations lines for `--replay-save`. Args: `gov` (report), `gov:pick:<n>` (answer gov decisions with
/// option n, default 0), `gov:spend:<lobby>:<think>:<campaign>:<pac>` (monthly budgets), `gov:invite:<venue>:<topic>`
/// (call a hearing now), `gov:selftest` (scripted checks on a copy of the save).
enum GovHarness {
    nonisolated(unsafe) static var on = false
    nonisolated(unsafe) static var pick = 0
    nonisolated(unsafe) private static var seen = 0

    /// Handle a replay arg; true if it was ours.
    static func parse(_ t: String, _ s: inout GameState) -> Bool {
        guard t == "gov" || t.hasPrefix("gov:") else { return false }
        on = true
        let p = t.split(separator: ":").map(String.init)
        switch p.count > 1 ? p[1] : "" {
        case "pick": pick = Int(p.count > 2 ? p[2] : "0") ?? 0
        case "spend" where p.count == 6:
            s.setLobbyBudget(Double(p[2]) ?? 0)
            print("gov spend: \(s.setPublicAffairs(thinkTank: Double(p[3]) ?? 0, campaign: Double(p[4]) ?? 0, pac: Double(p[5]) ?? 0, focus: "") ?? "ok") → \(Fmt.money(GovRelations.monthlySpend(s)))/mo")
        case "invite" where p.count == 4:
            if let v = HearingVenue(rawValue: p[2]), let tp = HearingTopic(rawValue: p[3]) {
                Hearings.invite(&s, v, tp, reason: "(called by the replay harness)")
                print("gov invite: \(s.gov.hearing.map { "\($0.venue)/\($0.topic) on \($0.date.gameShort), questions \($0.questions)" } ?? "not invited")")
            }
        case "selftest": selftest(s)
        default: break
        }
        return true
    }

    /// Which option the replay gives a decision.
    static func option(_ d: Decision) -> Int { on && d.kind.hasPrefix(GovRelations.prefix) ? min(pick, d.options.count - 1) : 0 }

    static func decision(_ d: Decision, _ s: GameState) {
        guard on, d.kind.hasPrefix(GovRelations.prefix) else { return }
        let o = option(d)
        print("    GOV DECISION [\(d.kind)] \(d.title)\n      \(d.body.replacingOccurrences(of: "\n", with: " "))")
        for (i, x) in d.options.enumerated() { print("      \(i == o ? "→" : " ") \(i). \(x.label) — \(x.detail)") }
    }

    static func daily(_ s: GameState, dayNo: Int) {
        guard on else { return }
        for n in s.gov.log.prefix(max(0, s.gov.log.count - seen)).reversed() { print("    GOV LOG \(n.date.gameShort) [\(n.kind)] \(n.text)") }
        seen = s.gov.log.count
        guard dayNo % 30 == 0 else { return }
        let home = HQ.region(s)
        let regions = Array(Set([Region.us, .eu, .uk, home])).sorted { $0.index < $1.index }
        print("    GOV capital \(Fmt.trim(s.politicalCapital, 1)) · exposure \(Fmt.trim(s.gov.exposure, 1)) · trust \(Fmt.trim(s.world.publicTrust, 1)) (bonus \(Fmt.trim(GovRelations.trustBonus(s), 1)))"
              + " · standing " + regions.map { "\($0.short) \(Int(s.world.government($0)))→\(Int(Stakeholders.governmentTarget(s, $0).value))" }.joined(separator: " ")
              + " · spend \(Fmt.money(GovRelations.monthlySpend(s)))/mo · promises \(s.gov.commitments.map { "\($0.id):\($0.status)" }.joined(separator: ","))"
              + " · grudges \(s.gov.grudges.sorted { $0.key < $1.key }.map { "\($0.key) \(Int($0.value))" }.joined(separator: ","))"
              + " · hearing \(s.gov.hearing.map { "\($0.venue)/\($0.topic) \($0.date.gameShort) witness=\($0.witness)" } ?? "none")")
    }

    static func summary(_ s: GameState) {
        guard on else { return }
        print("GOV SUMMARY: \(s.gov.hearings.count) hearings, \(s.gov.events.count) calendar events reached, \(s.gov.choices.count) answered, promises \(s.gov.commitments.count) (\(s.gov.commitments.filter { $0.status == "kept" }.count) kept, \(s.gov.commitments.filter { $0.status == "broken" }.count) broken), scandals \(s.gov.scandals), spent \(Fmt.money(s.gov.spent))")
        for h in s.gov.hearings {
            print("  HEARING \(h.date.gameShort) \(h.venue)/\(h.topic) witness=\(h.witness) grade=\(h.grade) mood=\(Int(h.mood))\(h.clip.isEmpty ? "" : " CLIP: \(h.clip)")")
            for l in h.lines { print("    \(l)") }
            print("    effects: \(h.effects.sorted { $0.key < $1.key }.map { "\($0.key) \(Fmt.trim($0.value, 1))" }.joined(separator: ", "))")
        }
        for (id, label) in s.gov.answered.sorted(by: { $0.key < $1.key }) { print("  CALENDAR \(id): \(label)") }
    }

    /// Scripted checks on a copy: a hearing answered live, a policy chief, an empty chair, export licences, a scandal.
    static func selftest(_ base: GameState) {
        func run(_ label: String, _ pickAll: Int, witness: Int) {
            var s = base
            s.gov.hearing = nil
            s.decisions.removeAll()
            Hearings.invite(&s, .senate, .frontier, reason: "selftest")
            guard let inv = s.decisions.first(where: { $0.kind == "gov_invite" }) else { print("SELFTEST \(label): no invitation"); return }
            s.resolveDecision(inv.id, option: witness)
            var days = 0
            while s.gov.hearing != nil && days < 80 {
                Sim.advanceDay(&s)
                days += 1
                while let d = s.decisions.first(where: { $0.kind == "gov_hearing" || $0.kind == "gov_subpoena" }) { s.resolveDecision(d.id, option: d.kind == "gov_subpoena" ? 0 : pickAll) }
                s.decisions.removeAll { !$0.kind.hasPrefix("gov_") }
            }
            let r = s.gov.hearings.first
            print("SELFTEST \(label): grade \(r?.grade ?? "none") mood \(Int(r?.mood ?? 0)) after \(days) days · US \(Fmt.trim(base.world.government(.us), 1))→\(Fmt.trim(s.world.government(.us), 1)) · trust \(Fmt.trim(base.world.publicTrust, 1))→\(Fmt.trim(s.world.publicTrust, 1)) · capital \(Fmt.trim(base.politicalCapital, 1))→\(Fmt.trim(s.politicalCapital, 1)) · promises \(s.gov.commitments.map(\.id)) · grudges \(s.gov.grudges.mapValues { Int($0) })")
        }
        run("best answers", 0, witness: 0)
        run("measured answers", 1, witness: 0)
        run("worst answers", 2, witness: 0)
        run("head of policy", 0, witness: 1)
        run("declined", 0, witness: 2)
        // Export controls: an H100 order to a Gulf site.
        var e = base
        guard var uae = e.sites.last else { return }
        uae.id = UUID()   // harness only: not part of any game
        uae.name = "Selftest Abu Dhabi"
        uae.locationID = "uae"
        e.sites.append(uae)
        if let a = HardwareCatalog.get("h100_sxm") {
            print("SELFTEST export: H100 TPP \(Int(GovRelations.tpp(a))) controlled \(GovRelations.controlled(a)) → \(GovRelations.exportBlocker(a, count: 8, siteID: uae.id, e) ?? "allowed")")
            print("SELFTEST export: apply → \(e.applyExportLicence("gulf") ?? "filed, due \(e.gov.applications["gulf"]?.gameShort ?? "?")") · odds \(Int(GovRelations.licenceOdds(e) * 100))%")
            for _ in 0..<150 where e.gov.licences["gulf"] == nil && e.gov.denied["gulf"] == nil { Sim.advanceDay(&e) }
            print("SELFTEST export: after waiting → licence \(e.gov.licences["gulf"]?.gameShort ?? "none") denied \(e.gov.denied["gulf"]?.gameShort ?? "no") · blocker now: \(GovRelations.exportBlocker(a, count: 8, siteID: uae.id, e) ?? "allowed")")
        }
        if let l4 = HardwareCatalog.get("l4") { print("SELFTEST export: L4 TPP \(Int(GovRelations.tpp(l4))) controlled \(GovRelations.controlled(l4))") }
        // Political money: a big PAC (needs a US presence) for a year.
        var p = base
        p.setLobbyBudget(2e6)
        let why = p.setPublicAffairs(thinkTank: 5e5, campaign: 1e6, pac: 3e6, focus: "")
        print("SELFTEST spend: \(why ?? "ok") → \(Fmt.money(GovRelations.monthlySpend(p)))/mo, capital/mo +\(Fmt.trim(GovRelations.capitalGain(p), 1)), US bonus \(Fmt.trim(GovRelations.standingBonus(p, .us), 1)), trust bonus \(Fmt.trim(GovRelations.trustBonus(p), 1))")
        for m in 0..<12 {
            p.date = GameCalendar.addMonths(p.date, 1)
            GovRelations.monthly(&p)
            if let d = p.decisions.first(where: { $0.kind == "gov_scandal" }) {
                print("SELFTEST spend: month \(m + 1) exposure \(Int(p.gov.exposure)) — SCANDAL: \(d.title)")
                p.resolveDecision(d.id, option: 0)
                print("SELFTEST spend: came clean → pac \(Fmt.money(p.gov.pac)) campaign \(Fmt.money(p.gov.campaign)) lobby \(Fmt.money(p.lobbyBudget)) exposure \(Int(p.gov.exposure))")
                break
            }
            if m == 11 { print("SELFTEST spend: no scandal in 12 months, exposure \(Int(p.gov.exposure)), chance \(Fmt.trim(GovRelations.scandalChance(p) * 100, 1))%/mo") }
        }
        // A safety institute asks to test the newest frontier-class model.
        var q = base
        if q.date < GameCalendar.date(2024, 9, 1) { q.date = GameCalendar.date(2024, 9, 1) }   // after the first institutes open
        if let i = q.models.indices.max(by: { q.models[$0].c < q.models[$1].c }) {
            q.models[i].retired = false
            q.models[i].created = q.date
            q.models[i].c = max(q.models[i].c, Macro.frontier(q.year))
            q.gov.asked.remove(q.models[i].id.uuidString)
            q.decisions.removeAll()
            GovRelations.askInstitutes(&q)
            if let d = q.decisions.first(where: { $0.kind == "gov_institute" }) {
                print("SELFTEST institute: \(d.title) — \(d.options.map(\.label))")
                let before = (q.safetyScore, q.models[i].evaluated)
                q.resolveDecision(d.id, option: 0)
                print("SELFTEST institute: full access → safety \(Fmt.trim(before.0, 1))→\(Fmt.trim(q.safetyScore, 1)), evaluated \(before.1)→\(q.models[i].evaluated), news: \(q.news.first?.body ?? "")")
            } else { print("SELFTEST institute: no request (\(GovRelations.institutes(q).map(\.name)))") }
        }
        // Calendar specs that apply to this save today.
        let live = PolicyCalendar.all.filter { PolicyCalendar.spec($0.id, base) != nil }.map(\.id)
        print("SELFTEST calendar: events that would concern this lab today: \(live)")
        print("SELFTEST candidates: \(Hearings.candidates(base).map { "\($0.venue.rawValue)/\($0.topic.rawValue) w\($0.weight)" })")
    }
}
