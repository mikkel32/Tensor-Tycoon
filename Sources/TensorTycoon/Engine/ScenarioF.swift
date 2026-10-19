import Foundation

/// Scenario F: classified research from preparation to permitted use. A US lab (2026 era, played forward by the bot
/// until it can afford it) raises weight security to SL3, clears a team and facility security officers to Secret,
/// builds a Secret secure lab and a restricted compute centre at its own datacenter, then a certified environment,
/// bids on Secret secure-communications work, staffs it, gives it cleared compute and runs it month by month to
/// delivery, then decides what it may do with the classified discovery. Checks the work is real all the way: stages
/// advance, milestones pay (booked as contract revenue), costs and trials show up, seconded staff stop working for the
/// rest of the company, facility power sits on the site's load and power bill, and what the lab may use follows the
/// secrecy decision (side branches on copies: walking away from Secret work, and a government-IP product unlock).
extension ScenarioHarness {
    static func scenarioF() -> Report {
        var r = Report(id: "F", title: all.first { $0.id == "F" }?.title ?? "F")
        var s = newGame(era: "2026", hq: "us", seed: 7, name: "Scenario F Labs")
        var bot = PTBot()

        // 1. Play the company forward until it can afford a classified division (or three years pass).
        var waited = 0
        while s.cash < 6e8 && waited < 36 * 30 && s.gameOver == nil {
            play(&s, &bot, days: 30)
            waited += 30
        }
        r.note("\(s.date.gameShort): \(Fmt.money(s.cash)) cash, \(s.employees.count) staff, security SL\(s.security.rawValue) after \(waited / 30) months of play")
        r.expect("the lab can afford classified work", s.cash >= 3e8, Fmt.money(s.cash))

        // A team big enough to clear: hire into the roles secure-communications work needs.
        for role in [Role.mlEngineer, .infra, .researcher] {
            var tries = 0
            while s.employees.filter({ $0.role == role }).count < 8 && tries < 8 {
                tries += 1
                guard let c = s.candidates.filter({ $0.role == role }).max(by: { ($0.skill, $1.id.uuidString) < ($1.skill, $0.id.uuidString) }), s.hire(c.id) == nil else { break }
            }
        }

        // 2. Weight security to SL3.
        var secMonths = 0
        while s.security < .sl3 && secMonths < 24 {
            if s.securityTarget <= s.security.rawValue { _ = s.upgradeSecurity() }
            play(&s, &bot, days: 30)
            secMonths += 1
        }
        r.expect("weight security reached SL3", s.security >= .sl3, "SL\(s.security.rawValue) after \(secMonths) months")

        // 3. The work to prepare for: Secret secure-communications for OADR (made now, posted once the lab is ready, so
        // the scenario doesn't wait on the market). Before any preparation it can't be bid: nothing could be ready in time.
        guard let t = AgencyCatalog.templateByID["securecomms"], let oadr = AgencyCatalog.byID["oadr"] else { r.expect("catalogue", false); return r }
        var sol = AdvancedProjects.make(t, oadr, s, key: "scenarioF", followOn: false)
        sol.id = "scenF-securecomms"
        let cold = AdvancedProjects.mobilisationPlan(sol, s)
        r.note("cold plan: about \(Fmt.trim(cold.months, 1)) months against \(Fmt.trim(cold.deadline, 1)) allowed (to the close plus the grace) · " + cold.steps.filter { !$0.done }.map(\.title).joined(separator: "; "))
        // The same work closing today leaves only the mobilisation grace: an unprepared lab can't make it, so it can't bid.
        var rushed = sol
        rushed.closes = s.date
        let rushedPlan = AdvancedProjects.mobilisationPlan(rushed, s)
        r.expect("unprepared, a Secret bid that can't mobilise in time is blocked", rushedPlan.months > rushedPlan.deadline
                    ? AdvancedProjects.blockers(rushed, s, plan: rushedPlan).contains { $0.hasPrefix("Can't mobilise in time") } && AdvancedProjects.odds(rushed, s, price: 0.95).p == 0
                    : false, "\(Fmt.trim(rushedPlan.months, 1)) months needed, \(Fmt.trim(rushedPlan.deadline, 1)) allowed")
        r.note("solicitation: \(sol.title) · \(sol.type.title) · \(Fmt.money(sol.ceiling)) · \(sol.staffTotal) staff · \(Fmt.int(Int(sol.computeH100e))) H100e · \(sol.months) months")

        // 4. Clearances (the team, a spare per role, security officers) and a datacenter of our own, in parallel.
        var started = 0
        for (k, n) in sol.staff.sorted(by: { $0.key < $1.key }) { if let role = Role(rawValue: k) { started += s.clearPeople(role, n + 1, level: 2) } }
        r.expect("Secret investigations started", started >= sol.staffTotal, "\(started) for a team of \(sol.staffTotal)")
        let campusKW = ((sol.computeH100e * World.kwPerH100e(s.year) * 1.3 + 3_000) / 1_000).rounded(.up) * 1_000
        let siteErr = s.buildSite(kind: .datacenter, locationID: "texas", capacityKW: campusKW, cooling: .air, power: .grid, name: "Abilene Secure Campus")
        r.expect("datacenter site under construction", siteErr == nil, siteErr ?? "")
        let siteID = s.sites.last { $0.name == "Abilene Secure Campus" }?.id
        var wait = 0
        while wait < 30 && (s.advanced.clearances.contains { $0.ready != nil } || !(siteID.flatMap { id in s.sites.first { $0.id == id } }?.isReady(s.date) ?? false)) {
            play(&s, &bot, days: 30)
            wait += 1
        }
        let secretCleared = s.employees.filter { AdvancedProjects.clearanceLevel(s, $0.id) >= 2 }.count
        r.note("\(s.date.gameShort): \(secretCleared) staff cleared Secret; \(s.advanced.clearances.filter { $0.deniedAt > 0 }.count) turned down")
        r.expect("Secret clearances granted", secretCleared >= sol.staffTotal, "\(secretCleared)")
        r.expect("cleared staff are paid a premium", s.advanced.lastPremium > 0, Fmt.money(s.advanced.lastPremium))

        // 5. Facilities: a Secret lab and restricted compute at the campus (sized to the work), then a certified environment.
        guard let site = siteID else { r.expect("datacenter site exists", false); return r }
        let loadBefore = Economy.siteLoadKW(s, site)
        let computeSize = AdvancedProjects.sizes(.restrictedCompute, s.year).first { $0 >= sol.computeH100e } ?? (sol.computeH100e / 32).rounded(.up) * 32
        let desks = AdvancedProjects.sizes(.secureLab, s.year).first { $0 >= Double(sol.staffTotal) } ?? 120
        let e1 = s.buildFacility(.secureLab, level: 2, capacity: desks, site: site)
        let e2 = s.buildFacility(.restrictedCompute, level: 2, capacity: computeSize, site: site)
        r.expect("secure lab and restricted compute started", e1 == nil && e2 == nil, [e1, e2].compactMap { $0 }.joined(separator: "; "))
        let facilityKW = AdvancedProjects.siteFacilityKW(s, site: site)
        r.expect("restricted compute takes its power from the site's load", facilityKW > 0 && Economy.siteLoadKW(s, site) >= loadBefore + facilityKW - 1,
                 "load \(Fmt.watts(loadBefore * 1000)) → \(Fmt.watts(Economy.siteLoadKW(s, site) * 1000)), facility \(Fmt.watts(facilityKW * 1000))")
        if let st = s.sites.first(where: { $0.id == site }) {
            // A hall needing more than the site has left is refused: the restricted compute's kW are spoken for.
            let free = st.capacityKW - Economy.siteLoadKW(s, site)
            let err = s.buildFacility(.clearedHall, level: 2, capacity: ((free + 100) / World.kwPerH100e(s.year)).rounded(.up), site: site)
            r.expect("the facility's kW can't also be filled", err?.contains("free") ?? false, err ?? "built")
        }
        if let uae = LocationCatalog.byID["uae"] {
            let abroad = Site(name: "Probe", kind: .datacenter, locationID: uae.id, capacityKW: 1_000, cooling: .air, powerDeal: .grid, opened: s.date, ready: s.date, capex: 0, monthlyFee: 0)
            r.expect("no Secret facility abroad", AdvancedProjects.sitingBlocker(abroad, level: 2, s) != nil)
        }
        let e3 = s.buildFacility(.certified, level: 2, capacity: 1, site: site)
        r.expect("certified environment started (3 officers cleared Secret, a Secret lab on the books)", e3 == nil, e3 ?? "")
        wait = 0
        while wait < 24 && s.advanced.facilities.contains(where: { !$0.isReady(s.date) }) {
            play(&s, &bot, days: 30)
            wait += 1
        }
        r.expect("facilities accredited and in use", s.advanced.facilities.count == 3 && s.advanced.facilities.allSatisfy { $0.isUsable(s.date) },
                 s.advanced.facilities.map { "\($0.name): \($0.suspension.isEmpty ? "ok" : $0.suspension)" }.joined(separator: "; "))
        let powerDay = AdvancedProjects.facilityPowerDay(s)
        r.expect("facility power is on the power bill", powerDay > 0, "\(Fmt.money(powerDay))/day")

        // 6. Post it and bid.
        sol.posted = s.date
        sol.closes = GameCalendar.addMonths(s.date, 2)
        s.advanced.solicitations.append(sol)
        let plan = AdvancedProjects.mobilisationPlan(sol, s)
        r.note("mobilisation plan: about \(Fmt.trim(plan.months, 1)) months against \(Fmt.trim(plan.deadline, 1)) allowed; " + plan.steps.map { "\($0.done ? "✓" : "·") \($0.title)" }.joined(separator: "; "))
        r.expect("mobilisation plan is feasible once prepared", plan.feasible)
        let price = sol.type == .costPlus ? 0.08 : 0.95
        let o = AdvancedProjects.odds(sol, s, price: price)
        let bidErr = s.submitProposal(sol.id, price: price)
        r.expect("Secret bid accepted", bidErr == nil, bidErr ?? "")
        r.note("bid: \(sol.title) · \(sol.type.title) · \(Fmt.money(sol.ceiling)) · \(sol.staffTotal) staff · \(Fmt.int(Int(sol.computeH100e))) H100e · odds \(Fmt.pct(o.p, decimals: 0))")
        wait = 0
        while wait < 4 && s.advanced.solicitations.contains(where: { $0.id == sol.id }) {
            play(&s, &bot, days: 30)
            wait += 1
        }
        var pid = s.advanced.programmes.first { $0.sol.id == sol.id }?.id
        if pid == nil, let bid = s.advanced.bids.first(where: { $0.title == sol.title }) {
            // The honest bid lost: award it anyway so the rest of the lifecycle can be checked (noted, not a failure).
            r.note("the honest bid lost (odds \(Fmt.pct(bid.odds, decimals: 0)), winner \(bid.winner)); awarding it directly to run the lifecycle")
            var forced = sol
            forced.bid = ProposalBid(price: price, submitted: s.date, proposalCost: AdvancedProjects.proposalCost(sol), odds: bid.odds)
            AdvancedProjects.award(&s, forced, bid: forced.bid!, margin: AdvancedProjects.margin(sol, AdvancedProjects.playerScores(s)))
            pid = s.advanced.programmes.last?.id
        }
        guard let id = pid, s.advanced.programmes.contains(where: { $0.id == id }) else { r.expect("programme awarded", false); return r }
        r.expect("programme awarded", true)

        // 7. Staff it and give it compute; seconded staff stop working for the company.
        let rpBefore = Sim.researchRate(s, s.bonuses)
        let mlBefore = s.workforce(.mlEngineer), infraBefore = s.workforce(.infra)
        _ = s.autoStaffProgramme(id)
        _ = s.setProgrammeCompute(id, sol.computeH100e)
        let team = s.advanced.programmes.first { $0.id == id }?.staff.count ?? 0
        r.expect("team assigned and cleared", team >= Int(0.6 * Double(sol.staffTotal)), "\(team) of \(sol.staffTotal)")
        r.expect("seconded engineers no longer count for the company", s.workforce(.mlEngineer) < mlBefore && s.workforce(.infra) < infraBefore,
                 "ML \(Fmt.trim(mlBefore, 1)) → \(Fmt.trim(s.workforce(.mlEngineer), 1)), infra \(Fmt.trim(infraBefore, 1)) → \(Fmt.trim(s.workforce(.infra), 1))")
        if sol.staff["researcher"] != nil {
            r.expect("seconded researchers no longer produce research points", Sim.researchRate(s, s.bonuses) < rpBefore,
                     "\(Fmt.trim(rpBefore, 1)) → \(Fmt.trim(Sim.researchRate(s, s.bonuses), 1)) RP/day")
        }
        r.expect("cleared compute assigned", (s.advanced.programmes.first { $0.id == id }?.compute ?? 0) >= 0.5 * sol.computeH100e)
        // While the Secret work runs, your science labs can't publish in its field; the agency's budget carries it.
        if let paper = ScienceCatalog.projects.first(where: { $0.field == .software }) {
            r.expect("Secret work in a field takes 'publish' off that field's discoveries", !Science.choices(s, paper).contains(.publish))
        }
        r.expect("the award draws down OADR's budget", AdvancedProjects.obligations(oadr, s) >= (s.advanced.programmes.first { $0.id == id }?.value ?? 0) / Double(sol.months) * 12 - 1,
                 "\(Fmt.money(AdvancedProjects.obligations(oadr, s))) committed of \(Fmt.money(AdvancedProjects.agencyBudget(oadr, s)))")
        mechanics(s, oadr, &r)

        // 8. Month by month to delivery.
        var maxStage = ProgrammeStage.award, months = 0, contractRevenue = 0.0, paidSeen = 0
        var decision: Decision? = nil
        var walked = false
        while months < 70 && decision == nil {
            // Side branch (copies), once the work is well under way: walking away from Secret work leaves nothing usable
            // and costs repayment; the same programme unclassified would leave a share in proportion to the work done.
            if !walked, let wi = s.advanced.programmes.firstIndex(where: { $0.id == id }), s.advanced.programmes[wi].completion >= 0.4 {
                walked = true
                let done = s.advanced.programmes[wi].completion
                var walk = s
                walk.abandonProgramme(id)
                let wp = walk.advanced.programmes[wi]
                r.expect("walking away from Secret work at \(Fmt.pct(done, decimals: 0)): no effects, no secrecy decision, repayment charged",
                         wp.status == .terminated && wp.effectScale == 0 && wp.secrecy == .none && wp.disallowed > 0,
                         "\(wp.status.title), effect \(wp.effectScale), repaid \(Fmt.money(wp.disallowed))")
                var open = s
                open.advanced.programmes[wi].sol.classification = 0
                open.abandonProgramme(id)
                let op = open.advanced.programmes[wi]
                let expected = 0.15 * op.sol.ip.commercialShare * done
                r.expect("walking away from the same work unclassified keeps 15% × IP share × work done", abs(op.effectScale - expected) < 0.01,
                         "\(Fmt.trim(op.effectScale, 3)) vs \(Fmt.trim(expected, 3))")
            }
            var day = 0
            while day < 30 && decision == nil && s.gameOver == nil {
                Sim.advanceDay(&s)
                day += 1
                if let d = s.decisions.first(where: { $0.kind == AdvancedProjects.secrecyKind && $0.ref.hasPrefix(id.uuidString) }) { decision = d; break }
                PTPlay.resolve(&s, &bot)
                PTPlay.act(&s, &bot)
            }
            months += 1
            guard let p = s.advanced.programmes.first(where: { $0.id == id }) else { break }
            maxStage = max(maxStage, p.stage)
            paidSeen = max(paidSeen, p.paid.count)
            if p.status != .active { break }
            if p.compute < p.sol.computeH100e { _ = s.setProgrammeCompute(id, p.sol.computeH100e) }
            _ = s.autoStaffProgramme(id)
        }
        guard let p = s.advanced.programmes.first(where: { $0.id == id }) else { r.expect("programme still on the books", false); return r }
        // This lab has no other government work: every dollar of contract revenue in its books is this programme's.
        contractRevenue = s.history.reduce(0) { $0 + $1.revContracts } + s.month.revContracts
        r.note("\(s.date.gameShort): \(p.status.title) at \(p.stage.title) after \(p.months) months (\(p.mobilisingMonths) mobilising), \(p.reworks) reworks · revenue \(Fmt.money(p.revenue)) · direct \(Fmt.money(p.direct)) · allocated \(Fmt.money(p.allocated)) · P&L \(AdvancedProjects.signed(p.profit)) · growth \(AdvancedProjects.signedPct(p.growth - 1))")
        for e in p.history.suffix(14) { r.note("  log \(e.date.gameShort): \(e.text)") }
        r.expect("stages advanced to delivery", maxStage >= .completion && p.status == .completed, "reached \(maxStage.title), \(p.status.title)")
        r.expect("milestones paid", paidSeen >= AdvancedProjects.milestones(p.sol.type).count, "\(paidSeen) of \(AdvancedProjects.milestones(p.sol.type).count)")
        r.expect("contract payments booked as contract revenue", p.contractRevenue > 0.5 * p.value && abs(contractRevenue - p.contractRevenue) < 1,
                 "books \(Fmt.money(contractRevenue)), programme \(Fmt.money(p.contractRevenue)) of \(Fmt.money(p.value))")
        r.expect("costs charged as the work went", p.direct > 0 && p.allocated > 0 && p.books.count >= 6)
        r.expect("trials ran (pass or fail in the log)", p.history.contains { $0.text.contains("passed (roll") || $0.text.contains("failed (roll") })
        r.expect("cost growth from failed trials matches the rework count", p.reworks == 0 ? p.trialGrowth == 0 : p.trialGrowth > 0, "\(p.reworks) reworks, +\(Fmt.pct(p.trialGrowth, decimals: 1))")

        // 9. The classified discovery: nothing is usable or handed over until the decision.
        let disc = s.advanced.discoveries.first { $0.programme == id }
        r.expect("secrecy decision waiting", decision != nil && p.secrecy == .pending)
        r.expect("before the decision: no effects, nothing handed over, patent under a secrecy order",
                 p.effectScale == 0 && !p.handedOver && (disc?.secrecyOrder ?? false))
        let trustBefore = AdvancedProjects.trust(s, "oadr")
        if let d = decision {
            let retain = AdvancedProjects.botSecrecyChoice(d)
            r.expect("retain-internally is offered", d.options.indices.contains(retain) && d.options[retain].label.hasPrefix("Retain"))
            // Side branch (a copy): licensing the permitted parts marks down classified bids for three years.
            var lic = s
            if let li = d.ref.split(separator: "|").last?.split(separator: ",").firstIndex(of: "3") {
                lic.resolveDecision(d.id, option: li)
                let lp = lic.advanced.programmes.first { $0.id == id }
                let sec = AdvancedProjects.secrecyRecord(sol, lic)
                r.expect("licensing: a fifth of the effect, royalties, classified bids marked down", lp?.secrecy == .licensed && lp?.effectScale == 0.2 && sec < 0,
                         "secrecy record \(Fmt.trim(sec, 1))")
            }
            s.resolveDecision(d.id, option: retain)
        }
        let done = s.advanced.programmes.first { $0.id == id }
        r.expect("retained: half the internal effects, handed over, still sealed",
                 done?.secrecy == .retained && done?.effectScale == AdvancedProjects.retainedScale && done?.handedOver == true
                    && (s.advanced.discoveries.first { $0.programme == id }?.secrecyOrder ?? false))
        r.expect("retained work feeds internal effects only", AdvancedProjects.bonusSources(s).contains { $0.0 == AdvancedProjects.internalPrefix + "securecomms" }
                    && !AdvancedProjects.bonusSources(s).contains { $0.0 == AdvancedProjects.bonusPrefix + "securecomms" })
        r.expect("OADR trusts the lab more", AdvancedProjects.trust(s, "oadr") > trustBefore, "\(Fmt.trim(trustBefore, 1)) → \(Fmt.trim(AdvancedProjects.trust(s, "oadr"), 1))")
        r.expect("seconded staff released after delivery", !s.advanced.programmes.contains { $0.id == id && !$0.staff.isEmpty } || done?.status == .active)

        // Side branch (a copy, as a lab that hasn't researched Air-Gapped Sovereign Deployment yet): a government-IP Secret
        // programme never hands over research that opens a product line, before or after the decision.
        if let sov = AgencyCatalog.templateByID["sovereignllm"], let unlock = sov.unlock {
            var g = s
            g.researched.remove(unlock)
            g.researchProgress[unlock] = 0
            var gs = AdvancedProjects.make(sov, oadr, g, key: "scenarioF-gov", followOn: false)
            gs.id = "scenF-sovereign"
            AdvancedProjects.award(&g, gs, bid: ProposalBid(price: 0.95, submitted: g.date, proposalCost: 0, odds: 0.5), margin: 5)
            let gi = g.advanced.programmes.count - 1
            g.advanced.programmes[gi].stage = .completion
            let before = g.researchProgress[unlock] ?? 0
            AdvancedProjects.complete(&g, gi)
            let held = (g.researchProgress[unlock] ?? 0) == before
            if let gd = g.decisions.first(where: { $0.ref.hasPrefix(g.advanced.programmes[gi].id.uuidString) }) { g.resolveDecision(gd.id, option: AdvancedProjects.botSecrecyChoice(gd)) }
            r.expect("government IP: the product-opening research isn't handed over (before or after the decision)",
                     held && (g.researchProgress[unlock] ?? 0) == before && g.advanced.programmes[gi].handedOver)
        }
        sanity(s, &r)
        return r
    }

    /// Mechanics checked on copies of the game: prizes, stage carry-over, cost-plus default terms, follow-ons, officers.
    static func mechanics(_ base: GameState, _ oadr: AgencyDef, _ r: inout Report) {
        // A prize whose rival finishes this month is lost, even if your team would also finish: no purse.
        if let t = AgencyCatalog.templateByID["mathprize"], let a = AgencyCatalog.byID["ukaia"] {
            var g = base
            var sol = AdvancedProjects.make(t, a, g, key: "scenF-prize", followOn: false)
            sol.id = "scenF-prize"
            sol.bidders = []
            AdvancedProjects.award(&g, sol, bid: ProposalBid(price: 1, submitted: g.date, proposalCost: 0, odds: 1), margin: 5)
            let i = g.advanced.programmes.count - 1
            r.expect("a prize with no rival bidders still has a deadline (an outside team)", g.advanced.programmes[i].rivalFinish != nil && g.advanced.programmes[i].rivalLab.isEmpty)
            g.advanced.programmes[i].stage = .completion
            g.advanced.programmes[i].progress = 0.99
            g.advanced.programmes[i].rivalFinish = g.date
            AdvancedProjects.step(&g, i)
            let p = g.advanced.programmes[i]
            r.expect("a rival finishing the same month takes the prize (only the 10% runner-up award is paid)",
                     p.status == .lost && !p.paid.contains(ProgrammeStage.completion.rawValue) && p.contractRevenue <= p.value * 0.1 + 1,
                     "\(p.status.title), received \(Fmt.money(p.contractRevenue)) of a \(Fmt.money(p.value)) purse")
        }
        // Work past the end of a stage carries into the next in the next stage's units (research 22% → experiments 20%).
        if let t = AgencyCatalog.templateByID["fusionsim"], let a = AgencyCatalog.byID["feso"] {
            var g = base
            let sol = AdvancedProjects.make(t, a, g, key: "scenF-carry", followOn: false)
            AdvancedProjects.award(&g, sol, bid: ProposalBid(price: 0.95, submitted: g.date, proposalCost: 0, odds: 1), margin: 5)
            let i = g.advanced.programmes.count - 1
            g.advanced.programmes[i].stage = .research
            g.advanced.programmes[i].progress = 1.5
            AdvancedProjects.finishStage(&g, i)
            let expected = 0.5 * AdvancedProjects.stageLength(sol, .research) / AdvancedProjects.stageLength(sol, .experimentation)
            r.expect("leftover progress converts between stages", g.advanced.programmes[i].stage == .experimentation && abs(g.advanced.programmes[i].progress - expected) < 1e-9,
                     "\(Fmt.trim(g.advanced.programmes[i].progress, 3)) vs \(Fmt.trim(expected, 3))")
        }
        // A failed trial sends the team back to rework and adds cost growth (risky work: try a few programmes for one).
        if let t = AgencyCatalog.templateByID["rover"], let a = AgencyCatalog.byID["naoa"] {
            var failed: Programme? = nil
            for k in 0..<12 where failed == nil {
                var g = base
                var sol = AdvancedProjects.make(t, a, g, key: "scenF-trial\(k)", followOn: false)
                sol.id = "scenF-trial\(k)"
                sol.risk = 0.6
                AdvancedProjects.award(&g, sol, bid: ProposalBid(price: 0.95, submitted: g.date, proposalCost: 0, odds: 1), margin: 0)
                let i = g.advanced.programmes.count - 1
                g.advanced.programmes[i].stage = .experimentation
                g.advanced.programmes[i].progress = 1
                if !AdvancedProjects.finishStage(&g, i) { failed = g.advanced.programmes[i] }
            }
            if let p = failed {
                r.expect("a failed trial: rework from 40% of the stage, cost growth added, logged", p.progress == 0.4 && p.reworks == 1 && p.trialGrowth > 0.05
                            && (p.history.last?.text.contains("failed (roll") ?? false), "growth +\(Fmt.pct(p.trialGrowth, decimals: 1))")
            } else {
                r.expect("a risky trial fails at least once in 12 tries", false)
            }
        }
        // Walking away from cost-plus: the fee paid so far goes back, with re-procurement costs.
        if let t = AgencyCatalog.templateByID["evalsuite"], let a = AgencyCatalog.byID["ncra"] {
            var g = base
            var sol = AdvancedProjects.make(t, a, g, key: "scenF-cp", followOn: false)
            sol.type = .costPlus
            AdvancedProjects.award(&g, sol, bid: ProposalBid(price: 0.1, submitted: g.date, proposalCost: 0, odds: 1), margin: 5)
            let i = g.advanced.programmes.count - 1
            g.advanced.programmes[i].stage = .research
            AdvancedProjects.payMilestone(&g, i, .research)
            g.advanced.programmes[i].stage = .experimentation
            let p = g.advanced.programmes[i]
            let owed = AdvancedProjects.feePaid(p) + AdvancedProjects.reprocurement(p)
            g.abandonProgramme(p.id)
            r.expect("walking away from cost-plus forfeits the fee paid and pays re-procurement costs", AdvancedProjects.feePaid(p) > 0 && abs(g.advanced.programmes[i].disallowed - owed) < 1,
                     "\(Fmt.money(g.advanced.programmes[i].disallowed)) repaid, \(Fmt.money(owed)) owed")
        }
        // A seedling's follow-on is Phase II of the programme it scouted, one classification level up at most.
        if let seed = AgencyCatalog.templateByID["seedling"] {
            var offered: Solicitation? = nil
            for k in 0..<12 where offered == nil {
                var g = base
                g.advanced.ratings[oadr.id] = 10
                let sol = AdvancedProjects.make(seed, oadr, g, key: "scenF-seed\(k)", followOn: false)
                guard let target = AgencyCatalog.templateByID[sol.target], target.classification >= 2 else { continue }
                AdvancedProjects.award(&g, sol, bid: ProposalBid(price: 0.95, submitted: g.date, proposalCost: 0, odds: 1), margin: 5)
                let before = g.advanced.solicitations.count
                AdvancedProjects.complete(&g, g.advanced.programmes.count - 1)
                if g.advanced.solicitations.count > before, let f = g.advanced.solicitations.last, f.followOn { offered = f }
            }
            if let f = offered {
                r.expect("seedling follow-on: Phase II of its subject, at most one level up", f.phase == 2 && f.title.hasSuffix("Phase II") && f.classification <= 1 && f.template != "seedling",
                         "\(f.title) (\(f.level.title))")
            } else {
                r.note("no classified-subject seedling follow-on was offered in 12 tries")
            }
        }
        // Facilities stop when their cleared security officers are gone.
        var g = base
        g.advanced.clearances = g.advanced.clearances.map { var c = $0; c.level = 0; return c }
        AdvancedProjects.checkFacilities(&g)
        r.expect("without cleared officers every facility is suspended and cleared compute drops to nothing",
                 g.advanced.facilities.allSatisfy { !$0.suspension.isEmpty } && AdvancedProjects.computeCapacity(g, atLeast: 1) == 0
                    && g.advanced.programmes.filter { $0.status == .active && $0.sol.level > .unclassified }.allSatisfy { $0.compute == 0 })
    }
}
