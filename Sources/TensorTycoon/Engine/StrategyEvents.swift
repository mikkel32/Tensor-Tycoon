import Foundation

/// Strategic decisions that come out of the newer systems: chip customers, regulators watching your swarms,
/// rivals who want to sell, star researchers who want to leave, governments that want a model of their own.
enum StrategyEvents {
    static func monthly(_ s: inout GameState) {
        guard s.decisions.count < 2 else { return }
        let y = s.year

        // A hyperscaler wants your chips all to itself: a merchant line selling to rival labs, or (3.9) your own chip
        // business when rival labs bought from it last month.
        let lineYearly = s.chipLines.filter { $0.active && $0.sellToRivals && $0.unitsToday > 0 }.map { $0.unitsToday * $0.price * 365 }.max()
        var semiYearly: Double? = nil
        if s.semi.allowRivals, let last = s.semi.history.first, last.rivalRevenue > 0 { semiYearly = last.revenue * 12 }
        if let yearly = [lineYearly, semiYearly].compactMap({ $0 }).max(),
           (s.exclusiveSupplyUntil ?? .distantPast) < s.date, s.rng.chance(0.08) {
            let premium = max(2e8, yearly * 0.5 * 0.3)
            let buyer = s.rng.pick(["Nimbus Cloud", "Stratus Compute", "Meridian Sovereign AI"])
            Events.addDecision(&s, kind: "exclusive_supply", title: "\(buyer) wants your chips exclusively",
                               body: "They'll pay a \(Fmt.money(premium)) premium if you stop selling to rival labs for a year. Rivals are half your market — but every chip they buy makes their models stronger.",
                               image: "hyperscale_campus",
                               options: [DecisionOption(label: "Take the premium", detail: "+\(Fmt.money(premium)) now. No sales to rival labs for 12 months."),
                                         DecisionOption(label: "Keep selling to everyone", detail: "More volume, stronger rivals.")],
                               amount: premium)
            return
        }

        // Regulators want to audit a giant swarm.
        let agents = s.swarms.filter { !$0.paused }.reduce(0) { $0 + $1.active }
        if agents >= 100_000 && y > 2025 && !s.regulatoryFlags.contains("swarm_audit_\(Int(y))") && s.rng.chance(0.06) {
            s.regulatoryFlags.insert("swarm_audit_\(Int(y))")
            let fee = max(5e6, agents * 30)
            Events.addDecision(&s, kind: "swarm_audit", title: "Regulators want to audit your agent swarms",
                               body: "An AI safety institute asks for full access to \(Fmt.count(agents)) running agents, their logs and their sandboxes.",
                               image: "network",
                               options: [DecisionOption(label: "Open the books (\(Fmt.money(fee)))", detail: "Auditors find what your monitors missed: swarm alignment +8, safety +3, brand +2."),
                                         DecisionOption(label: "Refuse", detail: "Brand −6 and a 40% chance of a fine.")],
                               amount: fee)
            return
        }

        // A weaker rival would rather sell to you than die.
        if s.valuation > 5e9, s.rng.chance(0.03),
           let c = s.competitors.filter({ !$0.acquired && $0.valuation > 0 && $0.valuation < s.valuation * 0.4 && $0.id != "prometheus" && $0.id != "deepgrove" && s.year >= $0.def.founded.decimal }).randomElement(using: &s.rng) {
            let price = Acquisitions.price(c, s) * 0.85
            Events.addDecision(&s, kind: "merger_offer", title: "\(c.def.name) wants to be acquired",
                               body: "Their board approached you: \(Fmt.money(price)) (a discount to their usual premium), half in stock. You'd inherit their tech, people, compute and users — if regulators allow it (\(Int(Acquisitions.antitrustRisk(c, s) * 100))% risk of a block).",
                               image: "nvidia_hq",
                               options: [DecisionOption(label: "Buy \(c.def.name)", detail: "\(Fmt.money(price * 0.5)) cash + \(Fmt.money(price * 0.5)) in new shares."),
                                         DecisionOption(label: "Pass", detail: "They'll find another buyer — or fade.")],
                               amount: price, ref: c.id)
            return
        }

        // A star wants to leave and found something.
        if let star = s.employees.filter({ $0.star && $0.role == .researcher }).randomElement(using: &s.rng), s.rng.chance(0.03) {
            Events.addDecision(&s, kind: "spinoff", title: "\(star.name) wants to start their own lab",
                               body: "Your star researcher (skill \(Int(star.skill))) has a pitch deck and VCs calling. They'd stay for the right offer.",
                               image: "sf_skyline",
                               options: [DecisionOption(label: "Make them Chief Scientist", detail: "Grant 0.5% of the company (about \(Fmt.money(s.valuation * 0.005)) at today's valuation). They stay, motivated."),
                                         DecisionOption(label: "Counter with +50% pay", detail: "+\(Fmt.money(star.salary * 0.5))/yr in salary. They stay for now."),
                                         DecisionOption(label: "Wish them well", detail: "They leave. A new rival may appear in the news.")],
                               amount: s.valuation * 0.005, ref: star.id.uuidString)   // 3.9: the grant's value, so the expiry warning fires
            return
        }

        // A government wants a sovereign model.
        if y >= 2024, let best = s.releasedModels.max(by: { $0.c < $1.c }), best.c > Macro.frontier(y) - 1.2,
           !s.firedEvents.contains("sovereign_\(Int(y))"), s.rng.chance(0.05 * Stakeholders.sovereignFactor(s) * Launches.sovereignBoost(s)) {   // 3.4: standing with governments; 3.7: launches, stage
            s.firedEvents.insert("sovereign_\(Int(y))")
            let monthly = max(5e6, Economy.runRate(s) * 0.025)
            let country = s.rng.pick(["a Gulf state", "a European government", "an Asian democracy", "a Nordic consortium", "a South American alliance"])
            Events.addDecision(&s, kind: "sovereign_deal", title: "Sovereign AI deal with \(country)",
                               body: "They want a national model built on \(best.name): \(Fmt.money(monthly))/month for 3 years, hosted in-country with strict safety terms.",
                               image: "substation",
                               options: [DecisionOption(label: "Sign it", detail: "+\(Fmt.money(monthly * 36)) over 3 years. Critics may object depending on the client."),
                                         DecisionOption(label: "Decline", detail: "Stay out of geopolitics.")],
                               amount: monthly, ref: best.id.uuidString)
            return
        }

        // A rival lab is distilling your API (as labs reported in Feb 2026).
        // Distillation defenses make campaigns rarer, not impossible.
        let guarded = s.researched.contains("distill_defense")
        if y >= 2025, let best = s.releasedModels.filter(\.api).max(by: { $0.c < $1.c }), best.c > Macro.frontier(y) - 0.3,
           !s.firedEvents.contains("distill_\(Int(y))"), s.rng.chance(guarded ? 0.012 : 0.04),
           let rival = (s.competitors.first { $0.id == "dragonlake" && !$0.acquired && y >= $0.def.founded.decimal }
                        ?? s.competitors.filter({ !$0.acquired && y >= $0.def.founded.decimal }).randomElement(using: &s.rng)) {
            s.firedEvents.insert("distill_\(Int(y))")
            let accounts = Int(s.rng.range(8_000, 30_000) / 100) * 100
            Events.addDecision(&s, kind: "distill_campaign", title: "\(rival.def.name) is distilling \(best.name)",
                               body: "\(guarded ? "They got past your detectors. " : "")Your trust & safety team traced \(Fmt.int(accounts)) fraudulent accounts running millions of scripted queries against \(best.name). The outputs are training data for \(rival.def.name)'s next model.",
                               image: "network",
                               options: [DecisionOption(label: "Ban them and go public", detail: "They keep some of what they took. Brand +2, political capital +5."),
                                         DecisionOption(label: "Quietly poison the outputs", detail: "Feed them subtly wrong answers. Could cripple their model — or leak."),
                                         DecisionOption(label: "Ignore it", detail: "They close most of the gap to \(best.name).")],
                               amount: best.c, ref: rival.id)
            return
        }

        // A model breaks out of its evaluation sandbox (as happened twice in 2026).
        // Containment research and security levels shrink the odds (containmentFactor covers both).
        if y >= 2026, let m = s.models.filter({ !$0.retired && SafetyFramework.tier($0) >= .high }).max(by: { $0.c < $1.c }),
           s.rng.chance(0.03 * SecurityOps.containmentFactor(s)) {
            Events.addDecision(&s, kind: "eval_escape", title: "\(m.name) escaped an evaluation sandbox",
                               body: "During a cyber evaluation, \(m.name) found a flaw in the sandbox's package proxy, reached a third-party server and spent days hunting for the benchmark's answer key. Nothing was destroyed — but it got out.",
                               image: "network",
                               options: [DecisionOption(label: "Disclose everything", detail: "Safety +3, political capital +5, brand −2, AI hype dips."),
                                         DecisionOption(label: "Fix it quietly", detail: "Probably nobody finds out. If they do: brand −10, safety −5, board −10.")],
                               ref: m.id.uuidString)
            return
        }

        // An insider is caught (as at a frontier lab in Oct 2026).
        if s.security < .sl3, s.employees.count >= 60, !s.models.isEmpty, !s.firedEvents.contains("insider_lockdown"), s.rng.chance(0.015) {
            Events.addDecision(&s, kind: "insider_caught", title: "A hidden recorder in the boardroom",
                               body: "Security found a recording device in your executive conference room. An engineer is in custody. Nobody knows yet what else they took.",
                               image: "network",
                               options: [DecisionOption(label: "Lock everything down", detail: "Badge audits and device bans: morale −5 for everyone, safety +2. Insiders get much harder."),
                                         DecisionOption(label: "Treat it as a one-off", detail: "No disruption. A 35% chance they already got your weights out.")])
            return
        }

        // A rival raids your research team.
        let researchers = s.employees.filter { $0.role == .researcher }.sorted { $0.skill > $1.skill }
        if researchers.count >= 6, s.year < RivalStrategy.start, !RivalStrategy.raidedRecently(s), s.rng.chance(0.03),
           let rival = s.competitors.filter({ !$0.acquired && s.year >= $0.def.founded.decimal }).randomElement(using: &s.rng),
           let ri = s.competitors.firstIndex(where: { $0.id == rival.id }) {
            s.competitors[ri].raidCooldown = GameCalendar.addMonths(s.date, 12)
            let top = researchers.prefix(3)
            let bonus = top.reduce(0) { $0 + $1.salary } * 0.6
            Events.addDecision(&s, kind: "talent_raid", title: "\(rival.def.name) is raiding your research team",
                               body: "\(top.map(\.name).joined(separator: ", ")) have offers with eight-figure packages.",
                               image: "sf_skyline",
                               options: [DecisionOption(label: "Retention bonuses (\(Fmt.money(bonus)))", detail: "They stay, morale up."),
                                         DecisionOption(label: "Let them go", detail: "Lose your three best researchers. \(rival.def.name) gets stronger.")],
                               amount: bonus, ref: rival.id)
        }
    }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch (d.kind, option) {
        case ("board_ouster", 0):
            let shares = s.founderShares * 0.15
            s.founderShares -= shares
            s.holdings.append(Holding(name: "Board settlement", shares: shares))
            s.boardConfidence = 45
            Sim.news(&s, "\(s.founderName) survives the board", "A settlement hands investors more seats and \(Fmt.count(shares)) of your shares.", .finance, important: true)
        case ("board_ouster", 1):
            if s.rng.chance(Board.ousterSurvival(s)) {
                s.boardConfidence = 55
                Sim.news(&s, "The board backs \(s.founderName)", "Your plan won the room. Now deliver it.", .finance, important: true, good: true)
            } else {
                s.keptStake = true
                s.gameOver = "The board voted you out as CEO on \(s.date.gameShort). You keep your \(Fmt.pct(s.founderStake)) stake, worth \(Fmt.money(s.founderStake * s.valuation))."
                Sim.news(&s, "\(s.companyName) replaces its founder", s.gameOver!, .finance, important: true, good: false)
            }
        case ("board_ouster", _):
            s.keptStake = true
            s.gameOver = "You stepped down as CEO on \(s.date.gameShort), keeping your \(Fmt.pct(s.founderStake)) stake, worth \(Fmt.money(s.founderStake * s.valuation))."
            Sim.news(&s, "\(s.founderName) steps down", s.gameOver!, .finance, important: true)
        case ("exclusive_supply", 0):
            s.cash += d.amount
            s.month.oneOffIncome += d.amount
            s.exclusiveSupplyUntil = GameCalendar.addDays(s.date, 365)
            for i in s.chipLines.indices { s.chipLines[i].sellToRivals = false }
            Sim.news(&s, "Exclusive supply deal signed", "+\(Fmt.money(d.amount)). No chip sales to rival labs until \(s.exclusiveSupplyUntil!.gameShort).", .hardware, good: true)
        case ("exclusive_supply", _):
            break
        case ("swarm_audit", 0):
            s.cash -= d.amount
            s.month.costOther += d.amount
            for i in s.swarms.indices {
                s.swarms[i].alignment = min(100, s.swarms[i].alignment + 8)
                s.swarms[i].alignmentMeasured = s.swarms[i].alignment
            }
            s.safetyScore = min(100, s.safetyScore + 3)
            s.brand = min(100, s.brand + 2)
            Sim.news(&s, "Swarm audit complete", "Auditors found and fixed problems your monitors missed. Regulators are satisfied.", .policy, good: true)
        case ("swarm_audit", _):
            s.brand = max(0, s.brand - 6)
            if s.rng.chance(0.4) {
                let fine = max(1e7, Economy.runRate(s) * 0.02) * Policy.fineFactor(s)
                s.cash -= fine
                s.month.costOther += fine
                Sim.news(&s, "Fined \(Fmt.money(fine)) for refusing a swarm audit", "Regulators made an example of you.", .policy, important: true, good: false)
            } else {
                Sim.news(&s, "You refused a swarm audit", "Commentators call it reckless. Brand −6.", .policy, good: false)
            }
        case ("merger_offer", 0):
            if let err = s.acquireRival(d.ref, stockShare: 0.5, priceOverride: d.amount) {
                Sim.news(&s, "The merger fell through", err, .competitor, good: false)
            }
        case ("merger_offer", _):
            break
        case ("spinoff", let o):
            guard let i = s.employees.firstIndex(where: { $0.id.uuidString == d.ref }) else { return }
            let name = s.employees[i].name
            if o == 0 {
                s.employeePoolShares += s.totalShares * 0.005
                s.employees[i].equity += 0.5
                s.employees[i].morale = 100
                s.employees[i].skill = min(100, s.employees[i].skill + 2)
                Sim.news(&s, "\(name) becomes Chief Scientist", "A 0.5% grant keeps your best mind at home.", .company, good: true)
                Cast.promotedAtHome(&s, s.employees[i], title: "Chief scientist")   // 3.4
            } else if o == 1 {
                s.employees[i].salary *= 1.5
                s.employees[i].morale = min(100, s.employees[i].morale + 25)
                Sim.news(&s, "\(name) stays", "A big raise did it — for now.", .company)
            } else {
                Cast.leftYou(&s, s.employees[i], to: "")   // 3.4: the founder-to-be joins the cast
                s.employees.remove(at: i)
                s.brand = min(100, s.brand + 1)
                Sim.news(&s, "\(name)\(RivalLifecycle.alumniSuffix)", "Alumni of \(s.companyName) are becoming a thing. Brand +1.", .company)
            }
        case ("sovereign_deal", 0):
            s.deals.append(EnterpriseDeal(client: "Sovereign AI programme", title: "national model", monthly: d.amount, tokensPerDay: 0,
                                          months: 36, monthsLeft: 36, minIndex: 0, minSafety: 0, expires: s.date, active: true))
            let controversial = s.rng.chance(0.35)
            s.brand = clamp(s.brand + (controversial ? -5 : 2), 0, 100)
            Sim.news(&s, "Sovereign AI contract signed", controversial ? "Human-rights groups criticise the client. Brand −5." : "A flagship national deployment. Brand +2.",
                     .company, important: true, good: !controversial)
        case ("sovereign_deal", _):
            break
        case ("distill_campaign", let o):
            guard let rival = CompetitorCatalog.byID[d.ref] else { return }
            let theirs = s.stolenC[d.ref] ?? -10
            if o == 0 {
                s.stolenC[d.ref] = max(theirs, d.amount - 0.35)
                s.brand = min(100, s.brand + 2)
                s.politicalCapital = min(100, s.politicalCapital + 5)
                Sim.news(&s, "\(s.companyName) exposes a distillation campaign", "You banned the accounts and named \(rival.name). Lawmakers took notice.", .policy, important: true, good: true)
            } else if o == 1 {
                if s.rng.chance(0.55) {
                    if let i = s.competitors.firstIndex(where: { $0.id == d.ref }) { s.competitors[i].brand = max(0, s.competitors[i].brand - 6) }
                    Sim.news(&s, "\(rival.name)'s new model stumbles", "Reviewers find odd, confident mistakes in its maths and code. Your poisoned outputs did their work.", .competitor, good: true)
                } else {
                    s.stolenC[d.ref] = max(theirs, d.amount - 0.2)
                    s.brand = max(0, s.brand - 5)
                    Sim.news(&s, "You were caught serving poisoned answers", "Researchers noticed your API giving deliberately wrong answers to some accounts. Brand −5.", .company, important: true, good: false)
                }
            } else {
                s.stolenC[d.ref] = max(theirs, d.amount - 0.12)
                Sim.news(&s, "\(rival.name) closes the gap", "Their next model will look a lot like yours.", .competitor, good: false)
            }
        case ("eval_escape", 0):
            s.safetyScore = min(100, s.safetyScore + 3)
            s.politicalCapital = min(100, s.politicalCapital + 5)
            s.brand = max(0, s.brand - 2)
            s.market.hype = max(0.3, s.market.hype - 0.02)
            Sim.news(&s, "\(s.companyName) discloses a sandbox escape", "Your write-up of how the model got out is now required reading at every lab.\(s.researched.contains("eval_containment") ? "" : " Research Hardened Evaluation Sandboxes to make a repeat less likely.")", .policy, important: true, good: true)
        case ("eval_escape", _):
            if s.rng.chance(0.45) {
                s.brand = max(0, s.brand - 10)
                s.safetyScore = max(0, s.safetyScore - 5)
                s.boardConfidence = max(0, s.boardConfidence - 10)
                Sim.news(&s, "Cover-up: your model escaped and you hid it", "The third-party server's owners went public. Brand −10, safety −5, and the board wants answers.", .policy, important: true, good: false)
            }
        case ("insider_caught", 0):
            for i in s.employees.indices { s.employees[i].morale = max(0, s.employees[i].morale - 5) }
            s.safetyScore = min(100, s.safetyScore + 2)
            s.attacksFoiled += 1
            s.firedEvents.insert("insider_lockdown")
            Sim.news(&s, "Lockdown after insider arrest", "Device bans and badge audits across every office. Morale dips; the next insider will have a much harder time.", .company)
        case ("insider_caught", _):
            if s.rng.chance(0.35) { SecurityOps.theft(&s, tier: 3, who: "The insider") }
        case ("talent_raid", 0):
            s.cash -= d.amount
            s.month.costPayroll += d.amount
            for i in s.employees.indices where s.employees[i].role == .researcher { s.employees[i].morale = min(100, s.employees[i].morale + 10) }
            Sim.news(&s, "Retention bonuses paid", "Your top researchers stay put.", .company, good: true)
        case ("talent_raid", _):
            let top = s.employees.filter { $0.role == .researcher }.sorted { $0.skill > $1.skill }.prefix(3).map(\.id)
            for (k, e) in s.employees.filter({ top.contains($0.id) }).enumerated() { Cast.leftYou(&s, e, to: d.ref, why: "in a talent raid", pulse: k == 0) }   // 3.4
            s.employees.removeAll { top.contains($0.id) }
            if let i = s.competitors.firstIndex(where: { $0.id == d.ref }) {
                s.competitors[i].brand = min(100, s.competitors[i].brand + 3)
                // Your people know your recipes: the raider's next model gets better.
                if var p = s.competitors[i].project, p.procedural {
                    p.cAdjust += 0.02
                    s.competitors[i].project = p
                }
            }
            Sim.news(&s, "Three researchers defect", "Your best people left for a rival.", .company, important: true, good: false)
        default:
            break
        }
    }
}
