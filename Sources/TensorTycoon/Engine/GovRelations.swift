import Foundation

/// 3.9: government relations. A public-affairs budget on top of lobbying (think tanks, a public campaign, super PAC
/// money) with real effects and real risks; public promises the game holds you to; rivals who remember what you said
/// about them; safety institutes asking to test your models; US export licences for advanced chips; and, in
/// Hearings and PolicyCalendar, testimony and dated policy decisions. Everything lands in systems that already exist:
/// stakeholder standing, political capital, bills, brand, safety and cash.
enum GovRelations {
    static let prefix = "gov_"

    // MARK: Hooks

    static func daily(_ s: inout GameState) {
        guard s.gameOver == nil else { return }
        PolicyCalendar.daily(&s)
        Hearings.daily(&s)
        licences(&s)
    }

    static func monthly(_ s: inout GameState) {
        guard s.gameOver == nil else { return }
        publicAffairs(&s)
        promises(&s)
        rivals(&s)
        audits(&s)
        askInstitutes(&s)
        Hearings.monthly(&s)
    }

    // MARK: Helpers

    static func note(_ s: inout GameState, _ text: String, kind: String) {
        s.gov.log.insert(GovNote(date: s.date, text: text, kind: kind), at: 0)
        if s.gov.log.count > 80 { s.gov.log.removeLast(s.gov.log.count - 80) }
    }

    /// Apply a bundle of moves once, with one cause. Keys are Stakeholders keys plus "gov" (the given region),
    /// "capital" (political capital), "brand", "safety" and "concern" (public concern about AI safety).
    static func apply(_ s: inout GameState, _ fx: [String: Double], region: Region?, why: String) {
        var moves: [String: Double] = [:]
        for (k, v) in fx {
            switch k {
            case "capital": s.politicalCapital = clamp(s.politicalCapital + v, 0, 100)
            case "brand": s.brand = clamp(s.brand + v, 0, 100)
            case "safety": s.safetyScore = clamp(s.safetyScore + v, 0, 100)
            case "concern", "cost": break
            case "gov": if let region { moves[region.rawValue, default: 0] += v }
            default: moves[k, default: 0] += v
            }
        }
        Stakeholders.move(&s, moves, why)
    }

    /// Pay for something: cash out, booked as an "other" cost (marketing for the public campaign).
    static func pay(_ s: inout GameState, _ amount: Double, marketing: Bool = false) {
        guard amount > 0 else { return }
        s.cash -= amount
        if marketing { s.month.costMarketing += amount } else { s.month.costOther += amount }
    }

    /// Big enough for lawmakers, summits and safety institutes to care: a model near the frontier, a large
    /// valuation, or a mass-market app.
    static func notable(_ s: GameState) -> Bool {
        if let best = s.releasedModels.map(\.c).max(), best >= Macro.frontier(s.year) - 0.5 { return true }
        return s.valuation >= max(1e9, Macro.frontierValuation(s.year) * 0.05) || s.consumerUsers >= 5e6
    }

    /// The rival lab with the strongest model: the one you get compared with.
    static func leadingRival(_ s: GameState) -> CompetitorState? {
        s.competitors.filter(\.alive).max { ($0.latest?.c ?? -9) < ($1.latest?.c ?? -9) }
    }

    static func usLinked(_ s: GameState) -> Bool { Policy.usPresence(s) || HQ.region(s) == .us }

    /// Answers that need cash you don't have are greyed out (option 0 carries the cost in `amount`).
    static func optionBlocker(_ d: Decision, _ option: Int, _ s: GameState) -> String? {
        guard option == 0, d.amount > 0, d.amount > s.cash else { return nil }
        return "Needs \(Fmt.money(d.amount)) in cash; you have \(Fmt.money(max(0, s.cash)))."
    }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch d.kind {
        case "gov_invite", "gov_subpoena", "gov_hearing": Hearings.resolve(&s, d, option: option)
        case "gov_policy", "gov_policy0": PolicyCalendar.resolve(&s, d, option: option)
        case "gov_institute": resolveInstitute(&s, d, option: option)
        case "gov_scandal": resolveScandal(&s, d, option: option)
        default: break
        }
    }

    // MARK: Public affairs

    static func lg(_ x: Double, _ unit: Double) -> Double { log10(1 + max(0, x) / unit) }

    static func focusRegion(_ s: GameState) -> Region { Region(rawValue: s.gov.focus) ?? HQ.region(s) }

    /// Monthly public-affairs spend, lobbying included.
    static func monthlySpend(_ s: GameState) -> Double { s.lobbyBudget + s.gov.thinkTank + s.gov.campaign + s.gov.pac }

    /// Political capital a month from PAC money and policy research (lobbying's own gain is in Policy.monthly).
    static func capitalGain(_ s: GameState) -> Double { 1.8 * lg(s.gov.pac, 1e5) + 0.6 * lg(s.gov.thinkTank, 1e5) }

    /// Where your standing with a government settles, from public affairs, promises and the stands you've taken.
    static func standingBonus(_ s: GameState, _ r: Region) -> Double {
        var v = 0.0
        if r == focusRegion(s) { v += min(5, 1.6 * lg(s.gov.thinkTank, 1e5)) + min(3, lg(s.lobbyBudget, 1e5)) }
        if r == .us { v += min(5, 1.5 * lg(s.gov.pac, 1e5)) }
        v += promiseStanding(s, r)
        v += PolicyCalendar.standing(s, r)
        if let at = s.gov.lastScandal, GameCalendar.daysBetween(at, s.date) < 365 { v -= 2 }
        return clamp(v, -12, 12)
    }

    /// Where public trust settles from the campaign, PAC money people know about, scandals and promises.
    static func trustBonus(_ s: GameState) -> Double {
        var v = min(6, 2.2 * lg(s.gov.campaign, 2.5e5))
        if s.gov.pac > 0 { v -= min(5, 1.5 * lg(s.gov.pac, 1e5)) * min(1, s.gov.exposure / 50) }
        if let at = s.gov.lastScandal, GameCalendar.daysBetween(at, s.date) < 365 { v -= 3 }
        let recent = s.gov.commitments.filter { c in (c.closed.map { GameCalendar.daysBetween($0, s.date) < 1_095 } ?? true) }
        v += min(3, Double(recent.filter { $0.status == "kept" }.count))
        v -= min(6, 2 * Double(recent.filter { $0.status == "broken" }.count))
        return clamp(v, -12, 10)
    }

    /// What your promises add with the government you made them to (kept +1.5, outstanding +0.5, broken −3), for three years.
    static func promiseStanding(_ s: GameState, _ r: Region) -> Double {
        var v = 0.0
        for c in s.gov.commitments where c.region == r.rawValue {
            if let closed = c.closed, GameCalendar.daysBetween(closed, s.date) >= 1_095 { continue }
            v += c.status == "kept" ? 1.5 : (c.status == "broken" ? -3 : 0.5)
        }
        return clamp(v, -6, 4)
    }

    /// Exposure added a month: political money draws reporters, PAC money most of all.
    static func exposureGain(_ s: GameState) -> Double {
        2 * (lg(s.lobbyBudget, 1e5) + 0.6 * lg(s.gov.thinkTank, 1e5) + 1.2 * lg(s.gov.campaign, 1e5) + 3 * lg(s.gov.pac, 1e5))
    }

    /// Chance a month that a story about your political money breaks.
    static func scandalChance(_ s: GameState) -> Double { max(0, s.gov.exposure - 25) / 100 * 0.25 }

    static func publicAffairs(_ s: inout GameState) {
        // Foreign companies can't fund US campaigns; a US subsidiary (a US datacenter or office) can.
        if s.gov.pac > 0 && !usLinked(s) {
            s.gov.pac = 0
            Sim.news(&s, "PAC donations stopped", "With no US presence left, \(s.companyName) can't legally give to American campaigns.", .policy)
        }
        let cost = s.gov.thinkTank + s.gov.pac
        pay(&s, cost)
        pay(&s, s.gov.campaign, marketing: true)
        s.gov.spent += cost + s.gov.campaign + s.lobbyBudget
        s.politicalCapital = clamp(s.politicalCapital + capitalGain(s), 0, 100)
        s.gov.exposure = clamp(s.gov.exposure * 0.9 + exposureGain(s), 0, 100)
        let ym = "\(s.date.ym.year)-\(s.date.ym.month)"
        let quiet = s.gov.lastScandal.map { GameCalendar.daysBetween($0, s.date) >= 180 } ?? true
        if quiet, scandalChance(s) > 0, World.roll(s, "scandal|\(ym)") < scandalChance(s) {
            scandal(&s)
        } else if s.gov.campaign > 0, s.world.publicTrust < 40, s.gov.lastBacklash.map({ GameCalendar.daysBetween($0, s.date) >= 180 }) ?? true,
                  World.roll(s, "backlash|\(ym)") < 0.2 {
            s.gov.lastBacklash = s.date
            Stakeholders.move(&s, ["public": -1.5], "Your ad campaign drew mockery")
            Sim.news(&s, "\(World.possessive(s.companyName)) ad campaign draws mockery", "With trust in the lab at \(Int(s.world.publicTrust))/100, glossy ads about “AI for everyone” land badly. Late-night hosts have a new bit.", .company, good: false)
            note(&s, "Ad campaign backfired while trust was low", kind: "spend")
        }
    }

    /// The channel most likely to be the story: the one adding most exposure.
    static func loudestChannel(_ s: GameState) -> String {
        let parts: [(String, Double)] = [("lobby", lg(s.lobbyBudget, 1e5)), ("think", 0.6 * lg(s.gov.thinkTank, 1e5)),
                                         ("campaign", 1.2 * lg(s.gov.campaign, 1e5)), ("pac", 3 * lg(s.gov.pac, 1e5))]
        return parts.max { $0.1 < $1.1 }?.0 ?? "lobby"
    }

    static func scandal(_ s: inout GameState) {
        let ch = loudestChannel(s)
        s.gov.scandals += 1
        s.gov.lastScandal = s.date
        let title: String
        let body: String
        let cut: String
        switch ch {
        case "pac":
            title = "Your super PAC's attack ads backfire"
            body = "Reporters trace \(Fmt.money(s.gov.pac))/month from \(s.companyName) into a super PAC running attack ads against a lawmaker who wrote an AI safety bill. The lawmaker's fundraising triples overnight."
            cut = "stop the PAC money"
        case "campaign":
            title = "Reporters trace a “grassroots” AI group to your agency"
            body = "“Citizens for AI Progress” turns out to be run by \(World.possessive(s.companyName)) ad agency, with paid actors in its videos. Astroturf, say the papers."
            cut = "stop the campaign"
        case "think":
            title = "A think tank you fund repeats your talking points word for word"
            body = "A widely cited policy paper on AI regulation was drafted with \(World.possessive(s.companyName)) staff, and the think tank never said so. Its director resigns."
            cut = "end the think-tank funding"
        default:
            title = "Lobbying filings show record spending by \(s.companyName)"
            body = "Disclosures show \(Fmt.money(s.lobbyBudget * 12)) a year on lobbying and three former congressional staffers hired in a month. The revolving-door stories write themselves."
            cut = "cut the lobbying budget"
        }
        Stakeholders.move(&s, ["public": -2, "researchers": -1], "\(title)")
        Events.addDecision(&s, kind: "gov_scandal", title: title, body: "\(body) How do you respond?", image: "stock_exchange",
                           options: [DecisionOption(label: "Come clean: \(cut)", detail: "Exposure −30, public trust −1, \(focusRegion(s).short) standing +1. That spending stops."),
                                     DecisionOption(label: "Defend it as normal advocacy", detail: "Public trust −3, researchers −1, exposure −10. Lawmakers may want to ask about it."),
                                     DecisionOption(label: "Say nothing", detail: "Public trust −2, board −1, exposure −5. The story runs for a week.")],
                           ref: ch)
        Sim.news(&s, title, body, .policy, image: "stock_exchange", important: true, good: false)
        note(&s, title, kind: "scandal")
    }

    static func resolveScandal(_ s: inout GameState, _ d: Decision, option: Int) {
        switch option {
        case 0:
            switch d.ref {
            case "pac": s.gov.pac = 0
            case "campaign": s.gov.campaign = 0
            case "think": s.gov.thinkTank = 0
            default: s.lobbyBudget = 0
            }
            s.gov.exposure = max(0, s.gov.exposure - 30)
            Stakeholders.move(&s, ["public": -1, focusRegion(s).rawValue: 1], "Came clean about political spending")
            Sim.news(&s, "\(s.companyName) comes clean", "\(s.founderName) apologises and stops the spending. Critics call it overdue; most move on.", .policy)
        case 1:
            s.gov.exposure = max(0, s.gov.exposure - 10)
            Stakeholders.move(&s, ["public": -3, "researchers": -1], "Defended controversial political spending")
        default:
            s.gov.exposure = max(0, s.gov.exposure - 5)
            Stakeholders.move(&s, ["public": -2, "investors": -1], "Stayed silent about a political-spending story")
        }
    }

    // MARK: Promises

    /// Make a public promise (one of each at a time).
    static func promise(_ s: inout GameState, _ p: GovPromise, venue: String, region: Region) {
        guard !s.gov.commitments.contains(where: { $0.id == p.rawValue && $0.active }) else { return }
        var c = GovCommitment(id: p.rawValue, made: s.date, venue: venue)
        c.region = region.rawValue
        switch p {
        case .security: c.due = GameCalendar.addMonths(s.date, 18)
        case .framework: c.due = GameCalendar.addMonths(s.date, 9)
        default: break
        }
        s.gov.commitments.insert(c, at: 0)
        if s.gov.commitments.count > 30 { s.gov.commitments.removeLast(s.gov.commitments.count - 30) }
        note(&s, "Promised \(venue): \(p.title.lowercasedFirst)", kind: "promise")
    }

    static func close(_ s: inout GameState, _ i: Int, kept: Bool, why: String) {
        guard s.gov.commitments.indices.contains(i), s.gov.commitments[i].active, let p = s.gov.commitments[i].promise else { return }
        s.gov.commitments[i].status = kept ? "kept" : "broken"
        s.gov.commitments[i].closed = s.date
        s.gov.commitments[i].note = why
        let r = Region(rawValue: s.gov.commitments[i].region) ?? HQ.region(s)
        let venue = s.gov.commitments[i].venue
        if kept {
            Stakeholders.move(&s, [r.rawValue: 2, "public": 1, "researchers": 1], "Kept a promise made \(venue)")
            Sim.news(&s, "\(s.companyName) kept its word", "\(p.title) — promised \(venue). \(why)", .policy, good: true)
            note(&s, "Kept: \(p.title.lowercasedFirst)", kind: "promise")
        } else {
            Stakeholders.move(&s, [r.rawValue: -6, "public": -3, "researchers": -2], "Broke a promise made \(venue)")
            Sim.news(&s, "\(s.companyName) broke a promise made \(venue)", "\(p.title): \(why) Lawmakers who took \(s.founderName) at their word are furious.", .policy, important: true, good: false)
            Alerts.raise(&s, .world, key: "gov_broken_\(p.rawValue)", title: "You broke a public promise", body: "\(p.title) (\(venue)). \(why)", screen: .government, cooldown: 30)
            note(&s, "Broken: \(p.title.lowercasedFirst)", kind: "promise")
        }
    }

    static func promises(_ s: inout GameState) {
        let frontier = Macro.frontier(s.year)
        for i in s.gov.commitments.indices where s.gov.commitments[i].active {
            let c = s.gov.commitments[i]
            guard let p = c.promise else { continue }
            let age = GameCalendar.daysBetween(c.made, s.date)
            switch p {
            case .evals:
                if let m = s.releasedModels.first(where: { m in
                    guard let at = m.releaseDate, at > c.made, m.c >= frontier - 0.6 else { return false }
                    return GameCalendar.daysBetween(at, s.date) > 60 && !Evaluations.isEvaluated(s, m)
                }) {
                    close(&s, i, kept: false, why: "\(m.name) shipped without a dangerous-capability evaluation.")
                    continue
                }
            case .security:
                if s.security >= .sl3 { close(&s, i, kept: true, why: "Weight security reached \(s.security.title)."); continue }
                if let due = c.due, s.date > due { close(&s, i, kept: false, why: "The deadline passed with security at \(s.security.title)."); continue }
            case .framework:
                if s.researched.contains("evals_rsp") { close(&s, i, kept: true, why: "Your scaling policy with dangerous-capability evaluations is published."); continue }
                if let due = c.due, s.date > due {
                    // A safety team of two or more can write and publish one without the research.
                    let team = s.staff(.safety).count
                    close(&s, i, kept: team >= 2, why: team >= 2 ? "Your \(team)-person safety team published it." : "The deadline passed with no safety team to write it.")
                    continue
                }
            case .noPAC:
                if s.gov.pac > 0 { close(&s, i, kept: false, why: "\(Fmt.money(s.gov.pac))/month is going to a super PAC."); continue }
            case .safetyBills:
                if let b = s.bills.first(where: { $0.stance < 0 && (PolicyCatalog.byID[$0.id]?.safetyBill ?? false) }), let bill = PolicyCatalog.byID[b.id] {
                    close(&s, i, kept: false, why: "You lobbied against the \(bill.title)."); continue
                }
            case .institute:
                break   // broken when you refuse an institute (resolveInstitute)
            }
            if [.evals, .institute, .noPAC, .safetyBills].contains(p) && age >= 730 { close(&s, i, kept: true, why: "Two years without breaking it.") }
        }
    }

    // MARK: Rivals

    /// Grudges fade; a deep one comes back as a hostile bill a rival's lobbyists helped write.
    static func rivals(_ s: inout GameState) {
        let snap = s
        for (k, v) in s.gov.grudges { s.gov.grudges[k] = v * 0.94 - 0.5 < 1 ? nil : v * 0.94 - 0.5 }
        guard let top = s.gov.grudges.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key < $1.key) }), top.value >= 30,
              s.gov.lastRivalBill.map({ GameCalendar.daysBetween($0, s.date) >= 365 }) ?? true, usLinked(s), s.bills.count < 2,
              let rival = s.competitors.first(where: { $0.id == top.key && $0.alive }),
              let bill = ["liability", "independent_auditors", "transparency", "compute_licensing"].lazy.compactMap({ Consequences.eligible(snap, $0) }).first else { return }
        s.gov.lastRivalBill = s.date
        s.gov.grudges[top.key] = top.value - 20
        Policy.introduce(&s, bill, sponsor: rival.def.name, boost: 0.1)
        note(&s, "\(rival.def.name) pushed the \(bill.title) after your clash in public", kind: "policy")
    }

    // MARK: Safety institutes

    /// The institutes that would ask to test your models (fictional names, real kinds of body).
    static func institutes(_ s: GameState) -> [(name: String, region: Region)] {
        var out: [(String, Region)] = []
        if usLinked(s) && s.date >= GameCalendar.date(2024, 2, 8) { out.append(("the Federal AI Evaluation Center", .us)) }
        if s.date >= GameCalendar.date(2023, 11, 2) { out.append(("the Frontier Safety Institute", .uk)) }
        if s.date >= GameCalendar.date(2024, 8, 1) && HQ.region(s) == .eu { out.append(("the EU AI Office", .eu)) }
        return out
    }

    /// A new model near the frontier: the institutes ask to test it (once per model).
    static func askInstitutes(_ s: inout GameState) {
        let who = institutes(s)
        guard !who.isEmpty, !s.decisions.contains(where: { $0.kind == "gov_institute" }) else { return }
        let line = Macro.frontier(s.year) - 0.5
        guard let m = s.models.filter({ !$0.retired && $0.c >= line && !s.gov.asked.contains($0.id.uuidString) && GameCalendar.daysBetween($0.created, s.date) <= 120 })
            .max(by: { $0.c < $1.c }) else { return }
        s.gov.asked.insert(m.id.uuidString)
        let names = who.map(\.name)
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names.last! : names[0]
        let cost = Evaluations.cost(s, m) * 0.5
        let counts = Evaluations.isEvaluated(s, m) ? "" : " Their report would count as the model's external dangerous-capability evaluation."
        let promised = s.gov.commitments.contains { $0.id == GovPromise.institute.rawValue && $0.active } ? " You promised to give them pre-release access." : ""
        Events.addDecision(&s, kind: "gov_institute", title: "\(list.capitalizedFirst) \(names.count > 1 ? "ask" : "asks") to test \(m.name)",
                           body: "\(m.name) is close to the frontier. The evaluators want three weeks with the weights, logs and a red-team budget to test it for cyber, bio and autonomy risks.\(counts)\(promised)",
                           image: "network",
                           options: [DecisionOption(label: "Give full access (\(Fmt.money(cost)))", detail: "Safety +1, standing +3 with each institute's government, public trust +1, researchers +1. They may find something worth fixing."),
                                     DecisionOption(label: "API access only", detail: "Standing +1 with each. They test what they can from outside."),
                                     DecisionOption(label: "Decline", detail: "Standing −3 with each, researchers −1.\(promised.isEmpty ? "" : " Breaks your promise.")")],
                           amount: cost, ref: m.id.uuidString)
        note(&s, "\(list.capitalizedFirst) asked to test \(m.name)", kind: "institute")
    }

    static func resolveInstitute(_ s: inout GameState, _ d: Decision, option: Int) {
        let who = institutes(s)
        guard let i = s.models.firstIndex(where: { $0.id.uuidString == d.ref }) else { return }
        let name = s.models[i].name
        var moves: [String: Double] = [:]
        switch option {
        case 0:
            pay(&s, d.amount)
            for w in who { moves[w.region.rawValue, default: 0] += 3 }
            moves["public"] = 1
            moves["researchers"] = 1
            s.safetyScore = min(100, s.safetyScore + 1)
            s.gov.tested.insert(d.ref)
            var extra = ""
            if !Evaluations.isEvaluated(s, s.models[i]) {
                s.models[i].evaluated = true
                extra = " Their report counts as its dangerous-capability evaluation."
            }
            if World.roll(s, "inst|\(d.ref)") < 0.4 {
                s.models[i].safety = min(100, s.models[i].safety + 2)
                s.safetyScore = min(100, s.safetyScore + 1)
                extra += " They found a jailbreak that unlocked cyber-attack help; your team patched it before it spread."
            }
            Stakeholders.move(&s, moves, "Gave safety institutes full access to \(name)")
            Sim.news(&s, "Safety institutes finish testing \(name)", "Three weeks with the weights and the logs.\(extra)", .policy, good: true)
            note(&s, "Institutes tested \(name) with full access", kind: "institute")
        case 1:
            for w in who { moves[w.region.rawValue, default: 0] += 1 }
            Stakeholders.move(&s, moves, "Gave safety institutes API access to \(name)")
            note(&s, "Institutes got API access to \(name)", kind: "institute")
        default:
            for w in who { moves[w.region.rawValue, default: 0] -= 3 }
            moves["researchers"] = -1
            Stakeholders.move(&s, moves, "Refused safety institutes access to \(name)")
            if let j = s.gov.commitments.firstIndex(where: { $0.id == GovPromise.institute.rawValue && $0.active }) {
                close(&s, j, kept: false, why: "You refused to let the institutes test \(name).")
            }
            note(&s, "Refused the institutes access to \(name)", kind: "institute")
        }
    }

    // MARK: Export controls

    /// The 2022/2023 US rules key on "total processing performance": TOPS × bit width. 4,800 is the line (an A100 is ~5,000).
    static let tppLine = 4_800.0
    /// Advanced chips to the Gulf need a licence (Nvidia disclosed the requirement in August 2023).
    static let gulfRule = GameCalendar.date(2023, 8, 30)
    /// Projected: clusters over 100,000 accelerators need a licence and an audit, at home or abroad. Shipments still
    /// go through (the paperwork queues); an unlicensed cluster is fined every six months until it's licensed.
    static let clusterRule = GameCalendar.date(2028, 4, 10)
    static let clusterCap = 100_000

    static func tpp(_ a: Accelerator) -> Double { max(a.bf16 * 16, a.fp8 * 8, a.int8 * 8, a.fp4 * 4) }

    /// US-designed advanced accelerators the rules cover (your own and Huawei's chips aren't US exports).
    static func controlled(_ a: Accelerator) -> Bool {
        a.vendor != .custom && a.vendor != .huawei && a.cls != .consumer && a.cls != .workstation && tpp(a) >= tppLine
    }

    static func licensed(_ s: GameState, _ key: String) -> Bool { s.gov.licences[key].map { $0 > s.date } ?? false }

    /// Accelerators at a site, installed and on order.
    static func chipsAt(_ s: GameState, _ site: UUID) -> Int {
        s.owned.filter { $0.siteID == site }.reduce(0) { $0 + $1.count } + s.orders.filter { $0.siteID == site }.reduce(0) { $0 + $1.count }
    }

    static func siteKey(_ id: UUID) -> String { "site:\(id.uuidString)" }

    /// Why an order of advanced chips can't ship to this site, or nil.
    static func exportBlocker(_ a: Accelerator, count: Int, siteID: UUID, _ s: GameState) -> String? {
        guard controlled(a), let site = s.sites.first(where: { $0.id == siteID }) else { return nil }
        if Region.of(location: site.locationID) == .gulf && s.date >= gulfRule && !s.gov.veu && !licensed(s, "gulf") {
            let pending = s.gov.applications["gulf"].map { " Your application is due \($0.gameShort)." } ?? " Apply for one on the Government Relations page."
            return "US export rules: \(a.name) needs a Commerce licence to ship to the Gulf.\(pending)"
        }
        return nil
    }

    /// Unlicensed clusters past the line: a fine every six months, and Washington notices.
    static func audits(_ s: inout GameState) {
        guard s.date >= clusterRule else { return }
        for site in s.sites where chipsAt(s, site.id) > clusterCap {
            let key = siteKey(site.id)
            guard !licensed(s, key), s.gov.applications[key] == nil,
                  s.gov.audits[key].map({ GameCalendar.daysBetween($0, s.date) >= 182 }) ?? true else { continue }
            s.gov.audits[key] = s.date
            let fine = clamp(Economy.runRate(s) * 0.002, 2e6, 5e8) * Policy.fineFactor(s)
            pay(&s, fine)
            Stakeholders.move(&s, ["us": -2], "Fined for an unlicensed cluster at \(site.name)")
            Sim.news(&s, "Commerce fines \(s.companyName) \(Fmt.money(fine)) over \(site.name)", "\(Fmt.int(chipsAt(s, site.id))) accelerators and no cluster licence. The fine repeats every six months until you apply on the Government Relations page.",
                     .policy, image: "stock_exchange", important: true, good: false)
            note(&s, "Fined \(Fmt.money(fine)) for an unlicensed cluster at \(site.name)", kind: "export")
        }
    }

    /// Licence fees: lawyers, compliance officers and (for clusters) the audit.
    static func licenceFee(_ key: String, _ s: GameState) -> Double { key == "gulf" ? 250_000 : clamp(Economy.runRate(s) * 0.0005, 2e6, 2.5e7) }

    /// Days Commerce takes, and its odds: standing with Washington decides most of it.
    static func licenceOdds(_ s: GameState) -> Double { clamp((s.world.government(.us) - 25) / 40, 0.15, 0.95) }

    static func licences(_ s: inout GameState) {
        for (key, due) in s.gov.applications.sorted(by: { $0.key < $1.key }) where due <= s.date {
            s.gov.applications[key] = nil
            let name = key == "gulf" ? "Gulf datacenters" : (s.sites.first { siteKey($0.id) == key }?.name ?? "your cluster")
            if World.roll(s, "licence|\(key)|\(due.timeIntervalSince1970)") < licenceOdds(s) {
                s.gov.licences[key] = GameCalendar.addDays(s.date, key == "gulf" ? 730 : 1_095)
                Sim.news(&s, "Export licence granted: \(name)", "Commerce approved advanced-chip shipments to \(name) until \(s.gov.licences[key]!.gameShort), with conditions: no Chinese hardware on site and quarterly audits.", .policy, good: true)
                note(&s, "Licence granted for \(name)", kind: "export")
            } else {
                s.gov.denied[key] = GameCalendar.addDays(s.date, 90)
                Sim.news(&s, "Export licence denied: \(name)", "Commerce turned down the application. Officials cite \"diversion risk\"; insiders say your standing in Washington (\(Int(s.world.government(.us)))/100) didn't help. You can reapply in 90 days.", .policy, important: true, good: false)
                note(&s, "Licence denied for \(name)", kind: "export")
            }
        }
        if let due = s.gov.veuDue, due <= s.date {
            s.gov.veuDue = nil
            if World.roll(s, "veu|\(due.timeIntervalSince1970)") < licenceOdds(s) {
                s.gov.veu = true
                Sim.news(&s, "\(s.companyName) becomes a Validated End User", "Advanced chips can now ship to your datacenters in the Gulf without case-by-case licences.", .policy, good: true)
                note(&s, "Validated End User status granted", kind: "export")
            } else {
                Sim.news(&s, "Validated End User application rejected", "Commerce wants a longer compliance record first.", .policy, good: false)
                note(&s, "Validated End User status refused", kind: "export")
            }
        }
    }
}

extension GameState {
    /// Set the public-affairs budgets (lobbying has its own setter) and where the team works.
    mutating func setPublicAffairs(thinkTank: Double, campaign: Double, pac: Double, focus: String) -> String? {
        if pac > 0 && !GovRelations.usLinked(self) {
            return "Foreign companies can't give to US campaigns. You need a US headquarters or a US datacenter (a US subsidiary) first."
        }
        gov.thinkTank = max(0, thinkTank)
        gov.campaign = max(0, campaign)
        gov.pac = max(0, pac)
        if focus.isEmpty || Region(rawValue: focus) != nil { gov.focus = focus }
        return nil
    }

    /// File for a US export licence: "gulf", or a site's cluster licence (GovRelations.siteKey).
    mutating func applyExportLicence(_ key: String) -> String? {
        if GovRelations.licensed(self, key) { return "You already hold that licence." }
        if key == "gulf" && date < GovRelations.gulfRule { return "Advanced chips ship to the Gulf without a licence until August 2023." }
        if key != "gulf" && date < GameCalendar.addDays(GovRelations.clusterRule, -365) { return "Cluster licences don't exist yet." }
        if gov.applications[key] != nil { return "Your application is already with Commerce." }
        if let until = gov.denied[key], until > date { return "Denied recently: you can reapply on \(until.gameShort)." }
        let fee = GovRelations.licenceFee(key, self)
        if fee > cash { return "The application costs \(Fmt.money(fee)) in legal and audit fees; you have \(Fmt.money(cash))." }
        GovRelations.pay(&self, fee)
        let days = (key == "gulf" ? 60 : 75) + Int(World.roll(self, "licdays|\(key)|\(date.timeIntervalSince1970)") * 60)
        gov.applications[key] = GameCalendar.addDays(date, days)
        GovRelations.note(&self, "Applied for an export licence (\(key == "gulf" ? "Gulf" : "cluster")), answer in about \(days) days", kind: "export")
        return nil
    }

    /// Apply for Validated End User status (from October 2024: the data-center VEU programme).
    mutating func applyVEU() -> String? {
        if gov.veu { return "You're already a Validated End User." }
        if gov.veuDue != nil { return "Your application is under review." }
        if date < GameCalendar.date(2024, 9, 30) { return "Commerce opens the data-center VEU programme in September 2024." }
        let fee = 1_000_000.0
        if fee > cash { return "The application costs \(Fmt.money(fee)); you have \(Fmt.money(cash))." }
        GovRelations.pay(&self, fee)
        gov.veuDue = GameCalendar.addDays(date, 120)
        GovRelations.note(&self, "Applied for Validated End User status", kind: "export")
        return nil
    }

    /// Book mock hearings with former staffers for the next hearing (up to two rounds).
    mutating func prepareHearing() -> String? {
        guard let h = gov.hearing, !h.live else { return "There's no hearing coming up." }
        if gov.prep >= 2 { return "Your team has rehearsed every question they can think of." }
        let fee = GovRelations.prepFee(self)
        if fee > cash { return "Mock hearings cost \(Fmt.money(fee)); you have \(Fmt.money(cash))." }
        GovRelations.pay(&self, fee)
        gov.prep += 1
        GovRelations.note(&self, "Booked mock hearing round \(gov.prep)", kind: "hearing")
        return nil
    }
}

extension GovRelations {
    static func prepFee(_ s: GameState) -> Double { clamp(s.valuation * 0.00002, 50_000, 1_500_000) }
}
