import Foundation

enum People {
    static let bios: [Role: [String]] = [
        .researcher: ["Ex-DeepGrove scientist with three NeurIPS orals.", "Wrote a widely-cited paper on attention variants.",
                      "PhD in RL, trained agents that beat pros at strategy games.", "Former physicist who fell in love with scaling laws.",
                      "Led pre-training data work at a rival lab.", "Co-author of an influential optimizer paper."],
        .mlEngineer: ["Wrote fused CUDA kernels that are now in every framework.", "Kept a 10K-GPU run alive for 3 months.",
                      "Ex-compiler engineer who speaks fluent Triton.", "Built a distributed trainer from scratch at a startup."],
        .infra: ["Ran a 50 MW datacenter fleet at a hyperscaler.", "InfiniBand whisperer.", "Kubernetes contributor and on-call veteran.",
                 "Designed liquid-cooling loops for GPU racks."],
        .data: ["Built a web-scale dedup pipeline.", "Ran a 2,000-person labelling operation.", "Synthetic-data obsessive.",
                "Former librarian turned data-licensing negotiator."],
        .sales: ["Closed nine-figure cloud deals.", "Ex-enterprise SaaS sales leader.", "Knows every CIO in the Fortune 500.",
                 "Developer-relations star with a huge following."],
        .chipDesigner: ["Led a TPU tape-out at a hyperscaler.", "Matrix-unit architect with 40 patents.", "Verification lead who never missed a tape-out date.",
                        "Ex-GPU memory-subsystem designer, HBM specialist."],
        .safety: ["Alignment researcher focused on interpretability.", "Red-teamed frontier models for a government institute.",
                  "Wrote an influential responsible scaling policy.", "Former security engineer specialising in model abuse."],
    ]

    static func makeCandidate(_ s: inout GameState, role: Role? = nil, star: Bool? = nil) -> Candidate {
        var roles: [Role] = [.researcher, .researcher, .mlEngineer, .mlEngineer, .infra, .data, .sales, .safety]
        if s.bonuses.has(.customSilicon) && s.year > 2018 { roles.append(.chipDesigner) }
        roles += HQ.extraRoles(s)   // 3.5: what the local ecosystem produces
        let r = role ?? s.rng.pick(roles)
        let isStar = star ?? s.rng.chance(0.06)
        let pull = r == .researcher ? (s.publication == .open ? 4.0 : s.publication == .secret ? -5.0 : 0) : 0
        let skill = isStar ? s.rng.range(85, 99) : clamp(45 + pull + s.traits.hiring + HQ.skillBonus(s, r) + s.rng.gaussian() * 15, 15, 90)
        var salary = Macro.salary(r, s.year) * pow(skill / 50, 1.6) * HQ.salaryFactor(s, star: isStar)
        if isStar && s.year > 2024.5 && r == .researcher { salary *= s.rng.range(3, 12) }   // 2025 talent wars
        let equity = isStar ? s.rng.range(0.05, 0.6) : s.rng.range(0, 0.05)
        let name = "\(s.rng.pick(NameBank.first)) \(s.rng.pick(NameBank.last))"
        var c = Candidate(name: name, role: r, skill: skill.rounded(), salary: (salary / 1000).rounded() * 1000, equity: equity,
                          star: isStar, expires: GameCalendar.addDays(s.date, 45), bio: s.rng.pick(bios[r] ?? [""]))
        // Stars always bring something special; one in seven others do too.
        if isStar || s.rng.chance(0.15) {
            let t = s.rng.chance(isStar ? 0.5 : 0.3) ? TalentTrait.specialty(r) : s.rng.pick([TalentTrait.mentor, .workhorse, .loyal, .diva])
            c.trait = t.rawValue
            c.salary = (c.salary * (1 + (t.multiplier - 1) * 0.4) / 1000).rounded() * 1000
        }
        return c
    }

    static func refreshCandidates(_ s: inout GameState) {
        s.candidates.removeAll { $0.expires < s.date }
        let target = HQ.candidateTarget(s, 8 + min(8, s.employees.count / 20))
        while s.candidates.count < target { s.candidates.append(makeCandidate(&s)) }
    }

    static func monthly(_ s: inout GameState) {
        refreshCandidates(&s)
        guard !s.employees.isEmpty else { return }
        // Morale: pay vs market, momentum, overcrowding
        let crowded = s.employees.count > Economy.officeCapacity(s)
        let momentum = (s.history.last?.revenue ?? 0) > (s.history.dropLast().last?.revenue ?? 0) ? 1.0 : -0.5
        var poached: [Employee] = []
        for i in s.employees.indices {
            let market = Macro.salary(s.employees[i].role, s.year) * pow(s.employees[i].skill / 50, 1.6) * HQ.salaryFactor(s, star: s.employees[i].star)
            let payRatio = s.employees[i].salary / max(market, 1)
            var m = s.employees[i].morale
            m += (payRatio - 1) * 6 + momentum + (crowded ? -4 : 0) + (s.cash < 0 ? -10 : 0)
            m += (70 - m) * 0.05
            s.employees[i].morale = clamp(m, 0, 100)
            // Rival labs poach unhappy, highly skilled people (never the loyal ones)
            var risk = (s.employees[i].skill / 100) * max(0, 0.6 - s.employees[i].morale / 100) * 0.12 + (s.employees[i].star ? 0.01 : 0)
            risk *= HQ.poachFactor(s)   // 3.5: big labs abroad recruit harder where pay is lower
            if s.employees[i].talent == .loyal { risk = 0 }
            if s.rng.chance(risk) { poached.append(s.employees[i]) }
        }
        // Mentors lift everyone; divas grate on their peers.
        let mentors = s.employees.filter { $0.talent == .mentor }.count
        let divaRoles = s.employees.filter { $0.talent == .diva }.map(\.role)
        for i in s.employees.indices {
            s.employees[i].morale += min(6, Double(mentors) * 1.5)
            let divas = divaRoles.filter { $0 == s.employees[i].role }.count - (s.employees[i].talent == .diva ? 1 : 0)
            s.employees[i].morale -= Double(max(0, divas)) * 2.5
            s.employees[i].morale = clamp(s.employees[i].morale, 0, 100)
        }
        for p in poached {
            s.employees.removeAll { $0.id == p.id }
            let rival = s.rng.pick(s.competitors.filter { s.year >= $0.def.founded.decimal }.map { $0.def.name } + ["a big-tech lab"])
            Sim.news(&s, "\(rival) poaches \(p.name)", "Your \(p.role.title.lowercased()) (skill \(Int(p.skill))) left for a bigger package. Keep pay competitive to hold on to talent.",
                     .company, important: p.skill > 75, good: false)
            if p.star || p.skill >= 75 { Cast.leftYou(&s, p, to: rival, why: "lured by a bigger offer") }   // 3.4
        }
        // Salaries drift with the market each January
        if GameCalendar.components(s.date).month == 1 {
            for i in s.employees.indices { s.employees[i].salary *= 1.04 }
        }
    }
}

enum Events {
    static func daily(_ s: inout GameState) {
        // Rare daily incidents
        let readySites = s.sites.filter { $0.isReady(s.date) && $0.kind != .garage }
        if !readySites.isEmpty && s.rng.chance(0.0015 * Double(readySites.count)) {
            let site = s.rng.pick(readySites)
            s.reliability *= 0.85
            for i in s.runs.indices where s.runs[i].status == .running {
                s.runs[i].flopsDone *= 0.995
            }
            Sim.news(&s, "Power outage at \(site.name)", "A grid fault knocked the site offline for hours. Training rolled back to the last checkpoint and users saw errors.",
                     .company, image: "generator", good: false)
        }
    }

    static func monthly(_ s: inout GameState) {
        let y = s.year
        let released = s.releasedModels
        let consumer = s.chatModelID != nil && s.consumerUsers > 1000

        // Startup cloud credits programme
        if !s.firedEvents.contains("credits") && s.rounds.count <= 2 && s.rng.chance(0.25) {
            s.firedEvents.insert("credits")
            let amt = y < 2021 ? 100_000.0 : 350_000.0
            s.cloudCredits += amt
            Sim.news(&s, "Startup programme: \(Fmt.money(amt)) in cloud credits", "A cloud provider's startup programme accepted you. Credits are spent automatically on rentals.",
                     .finance, image: "network", good: true)
        }

        // Viral moment
        if let m = released.max(by: { $0.c < $1.c }), m.c > Macro.frontier(y) - 0.6, s.rng.chance(0.12) {
            s.brand = min(100, s.brand + 6)
            Sim.news(&s, "\(m.name) demo goes viral", "A clip of \(m.name) solving a hard problem racks up 20M views. Sign-ups spike.",
                     .company, image: "sf_skyline", good: true)
        }

        // Jailbreak scandal → decision
        if consumer || !released.isEmpty {
            let unsafe = released.contains { $0.unsafeRelease }
            let p = 0.06 * (1 - s.safetyScore / 100) * (consumer ? 1.5 : 1) * (unsafe ? 2.5 : 1)
            if s.rng.chance(p), let m = (unsafe ? released.filter(\.unsafeRelease) : released).randomElement(using: &s.rng) {
                addDecision(&s, kind: "jailbreak", title: "\(m.name) jailbreak goes viral",
                            body: "Users found a prompt that makes \(m.name) produce dangerous instructions. Journalists are asking for comment.",
                            image: "network",
                            options: [DecisionOption(label: "Pull & patch", detail: "Pause API traffic for safety training. −10% reliability for a while, small brand hit."),
                                      DecisionOption(label: "Issue a statement", detail: "Promise improvements and move on. Bigger brand hit, regulators take note.")],
                            ref: m.id.uuidString)
            }
        }

        // Benchmark contamination
        if let m = released.first(where: { $0.tuned }), s.rng.chance(0.08) {
            s.brand = max(0, s.brand - 15)
            if let i = s.models.firstIndex(where: { $0.id == m.id }) { s.models[i].tuned = false }
            Sim.news(&s, "Researchers find benchmark contamination in \(m.name)", "Test questions were found in the training data. The press calls it \"benchmaxxing\". Brand −15.",
                     .company, important: true, good: false)
        }

        // Copyright lawsuit
        if y >= 2023, let m = released.first(where: { $0.usedShadowData && !$0.lawsuitResolved }),
           s.rng.chance(0.07 * s.market.copyrightHeat * (s.lawsPassed.contains("liability") ? 1.5 : 1)) {
            let rr = Economy.runRate(s)
            let fine = clamp(max(5e6, rr * 0.25), 5e6, 1.5e9) * (y > 2025.6 ? 1.5 : 1) * Policy.fineFactor(s)
            addDecision(&s, kind: "lawsuit", title: "Authors sue over pirated training data",
                        body: "A class action says \(m.name) was trained on shadow-library books. Lawyers estimate \(Fmt.money(fine)) to settle.",
                        image: "stock_exchange",
                        options: [DecisionOption(label: "Settle (\(Fmt.money(fine)))", detail: "Pay and move on."),
                                  DecisionOption(label: "Fight in court", detail: "60% chance to win; lose and pay double plus brand damage.")],
                        amount: fine, ref: m.id.uuidString)
        }

        // EU AI Act: near-frontier models without evals
        if s.market.euAIAct, !s.researched.contains("evals_rsp"),
           released.contains(where: { $0.c > Macro.frontier(y) - 0.4 }), s.rng.chance(0.2) {
            let fine = max(2e6, Economy.runRate(s) * 0.03) * Policy.fineFactor(s)
            s.cash -= fine
            s.month.costOther += fine
            Sim.news(&s, "EU fines \(s.companyName) \(Fmt.money(fine))", "Your general-purpose model shipped without the required risk evaluations. Research Dangerous-Capability Evals to comply.",
                     .policy, important: true, good: false)
        }

        // Hardware failures (bad batch)
        let owned = s.owned.reduce(0) { $0 + $1.count }
        if owned > 200 && s.rng.chance(0.06), let i = s.owned.indices.randomElement(using: &s.rng) {
            let n = max(1, Int(Double(s.owned[i].count) * s.rng.range(0.005, 0.02)))
            s.owned[i].count -= n
            let name = HardwareCatalog.get(s.owned[i].accelID)?.name ?? ""
            s.owned.removeAll { $0.count <= 0 }
            Sim.news(&s, "\(n)× \(name) failed in the field", "HBM errors took out a batch of accelerators. Out of warranty — they're gone.",
                     .company, image: "rack_rear", good: false)
        }

        // Heat waves for hot regions in summer
        let month = GameCalendar.components(s.date).month
        if (6...8).contains(month), s.sites.contains(where: { ["texas", "arizona", "uae"].contains($0.locationID) && $0.kind != .garage }), s.rng.chance(0.3) {
            let extra = s.sites.filter { ["texas", "arizona", "uae"].contains($0.locationID) }.reduce(0.0) { acc, site in
                acc + Economy.siteLoadKW(s, site.id) * 24 * 7 * site.powerPrice * 2
            }
            s.cash -= extra
            s.month.costPower += extra
            Sim.news(&s, "Heat wave: power prices spike", "Grid prices hit 3x for a week. Your hot-climate sites paid \(Fmt.money(extra)) extra.",
                     .market, image: "substation", good: false)
        }

        // Defense contract decision
        if !s.firedEvents.contains("defense") && released.contains(where: { $0.c > Macro.frontier(y) - 1.0 }) && y > 2023.5 && s.rng.chance(0.08) {
            s.firedEvents.insert("defense")
            let amt = max(20e6, Economy.runRate(s) * 0.15)
            addDecision(&s, kind: "defense", title: "Defense department offers a contract",
                        body: "A \(Fmt.money(amt)) one-year contract to deploy your models on classified networks. Some staff are uneasy.",
                        image: "supercomputer",
                        options: [DecisionOption(label: "Accept", detail: "+\(Fmt.money(amt)) over 12 months, −8 brand, safety team morale drops."),
                                  DecisionOption(label: "Decline", detail: "+3 brand with consumers.")],
                        amount: amt)
        }

        // Acquisition offer
        if !s.isPublic && s.valuation > 1.5e9 && s.rng.chance(0.04) {
            let price = s.valuation * s.rng.range(1.2, 1.7)
            addDecision(&s, kind: "acquisition", title: "Acquisition offer from a big-tech giant",
                        body: "They'll buy \(s.companyName) for \(Fmt.money(price)). Your \(Fmt.pct(s.founderStake)) stake would be worth \(Fmt.money(price * s.founderStake)).",
                        image: "nvidia_hq",
                        options: [DecisionOption(label: "Sell the company", detail: "Ends the game with a successful exit."),
                                  DecisionOption(label: "Stay independent", detail: "Keep building.")],
                        amount: price)
        }

        // A rival's researcher brings their lab's secret technique with them
        if s.rng.chance(0.012), let (lab, tech) = s.rivalTech.flatMap({ k, v in v.map { (k, $0) } })
            .filter({ !s.exoticOwned.contains($0.1) && !s.researched.contains($0.1) }).randomElement(using: &s.rng),
           let item = ResearchCatalog.byID[tech], let comp = CompetitorCatalog.byID[lab] {
            let salary = (Macro.salary(.researcher, y) * 2.2 / 1000).rounded() * 1000
            addDecision(&s, kind: "poach", title: "A \(comp.name) researcher wants to join",
                        body: "A senior researcher behind \(comp.name)'s \(item.name) work is unhappy and open to an offer. Hiring them would let you research it yourself.",
                        image: "sf_skyline",
                        options: [DecisionOption(label: "Hire them (\(Fmt.money(salary))/yr)", detail: "Unlocks \(item.name) in your research tree. About a 30% chance \(comp.name) sues within six months."),
                                  DecisionOption(label: "Pass", detail: "Poaching invites lawsuits.")],
                        amount: salary, ref: tech)
        }

        // Trade-secret suits from researchers you poached.
        for suit in s.pendingSuits where suit.due <= s.date {
            let name = CompetitorCatalog.byID[suit.lab]?.name ?? "A rival lab"
            let tech = ResearchCatalog.byID[suit.tech]?.name ?? "secret"
            addDecision(&s, kind: "trade_secret", title: "\(name) sues over trade secrets",
                        body: "\(name) says the researcher you hired walked out with its \(tech) work. Lawyers estimate \(Fmt.money(suit.amount)) to settle.",
                        image: "stock_exchange",
                        options: [DecisionOption(label: "Settle (\(Fmt.money(suit.amount)))", detail: "Pay, take a small brand hit (−2) and move on."),
                                  DecisionOption(label: "Fight in court", detail: "50% chance to win and pay only legal fees; lose and pay double, brand −6.")],
                        amount: suit.amount, ref: suit.lab)
        }
        let today = s.date
        s.pendingSuits.removeAll { $0.due <= today }

        // Superstar researcher on the market
        if s.rng.chance(0.08) {
            let c = People.makeCandidate(&s, role: .researcher, star: true)
            s.candidates.insert(c, at: 0)
            Sim.news(&s, "Superstar researcher \(c.name) is on the market", "Skill \(Int(c.skill)). \(c.bio) Asking \(Fmt.money(c.salary))/yr. Check the Team page.",
                     .company, good: true)
        }

        // Macro swings once the real timeline runs out
        if y > 2026.8 && s.rng.chance(0.05) {
            let up = s.rng.chance(0.55)
            s.market.hype = max(0.5, s.market.hype + (up ? 0.15 : -0.25))
            Sim.news(&s, up ? "AI stocks rally to new highs" : "AI bubble fears: tech stocks slide",
                     up ? "Investors pile back into anything with \"AI\" in the pitch. Fundraising just got easier."
                        : "A string of disappointing earnings rattles markets. Valuations and fundraising take a hit.",
                     .finance, image: "stock_exchange", important: true, good: up)
        }
        if y > 2026.8 && s.rng.chance(0.03) {
            s.market.hardwarePrice += 0.2
            s.market.leadTimeDays += 60
            Sim.news(&s, "Supply shock at a major foundry", "An earthquake halts advanced packaging lines for weeks. Accelerator prices and lead times jump.",
                     .hardware, image: "wafer", important: true, good: false)
        }
    }

    static func addDecision(_ s: inout GameState, kind: String, title: String, body: String, image: String?,
                            options: [DecisionOption], amount: Double = 0, ref: String = "") {
        var d = Decision(kind: kind, title: title, body: body, image: image, options: options, date: s.date, amount: amount, ref: ref)
        // Low-stakes offers wait in the inbox with a deadline instead of stopping the clock.
        if !Alerts.isUrgent(d) {
            d.deadline = GameCalendar.addDays(s.date, Alerts.inboxDays(kind))
            let fallback = options.indices.contains(Alerts.inboxDefaults[kind] ?? 0) ? options[Alerts.inboxDefaults[kind] ?? 0].label : options.last?.label ?? "nothing"
            Alerts.raise(&s, .inbox, key: d.id.uuidString, title: title,
                         body: "Waiting in your inbox for \(Alerts.inboxDays(kind)) days. If you don't answer: \"\(fallback)\".",
                         screen: .dashboard, cooldown: 0)
        }
        s.decisions.append(d)
    }

    static func resolve(_ s: inout GameState, _ id: UUID, option: Int) {
        guard let idx = s.decisions.firstIndex(where: { $0.id == id }) else { return }
        let d = s.decisions.remove(at: idx)
        switch (d.kind, option) {
        case ("jailbreak", 0):
            s.reliability *= 0.85
            s.brand = max(0, s.brand - 3)
            s.safetyScore = min(100, s.safetyScore + 3)
            Sim.news(&s, "Model patched", "You paused, retrained the refusal behaviour and relaunched. Users grumbled, regulators approved.", .company)
        case ("jailbreak", _):
            s.brand = max(0, s.brand - 10)
            s.safetyScore = max(0, s.safetyScore - 5)
            Sim.news(&s, "Backlash grows", "Your statement didn't land. Brand −10.", .company, good: false)
        case ("lawsuit", 0):
            s.cash -= d.amount
            s.month.costOther += d.amount
            markLawsuit(&s, d.ref)
            Sim.news(&s, "Copyright case settled for \(Fmt.money(d.amount))", "Expensive, but it's behind you.", .policy)
        case ("lawsuit", _):
            if s.rng.chance(0.6) {
                markLawsuit(&s, d.ref)
                Sim.news(&s, "You won the copyright case", "The judge ruled training was fair use. Legal fees: \(Fmt.money(d.amount * 0.05)).", .policy, good: true)
                s.cash -= d.amount * 0.05
            } else {
                s.cash -= d.amount * 2
                s.month.costOther += d.amount * 2
                s.brand = max(0, s.brand - 8)
                markLawsuit(&s, d.ref)
                Sim.news(&s, "You lost the copyright case", "Damages of \(Fmt.money(d.amount * 2)). Brand −8.", .policy, important: true, good: false)
            }
        case ("defense", 0):
            s.deals.append(EnterpriseDeal(client: "Department of Defense", title: "classified deployment", monthly: d.amount / 12, tokensPerDay: 0,
                                          months: 12, monthsLeft: 12, minIndex: 0, minSafety: 0, expires: s.date, active: true))
            s.brand = max(0, s.brand - 8)
            for i in s.employees.indices where s.employees[i].role == .safety { s.employees[i].morale -= 20 }
        case ("defense", _):
            s.brand = min(100, s.brand + 3)
        case ("loss_spike", _), ("train_bug", _), ("contamination", _), ("data_mix", _), ("fault_storm", _), ("sycophancy", _), ("reward_hack", _):
            Training.resolve(&s, kind: d.kind, ref: d.ref, option: option)
        case ("partner_offer", 2):
            break
        case ("partner_offer", 1):
            Sim.news(&s, "Partner talks open", "Compare every partner's terms on the Partners page before you commit.", .finance)
        case ("partner_offer", _):
            Partners.resolveOffer(&s, ref: d.ref, option: option)
        case ("poach", 0):
            if !s.exoticOwned.contains(d.ref) { s.exoticOwned.append(d.ref) }
            s.employees.append(Employee(name: "\(s.rng.pick(NameBank.first)) \(s.rng.pick(NameBank.last))", role: .researcher, skill: 82,
                                        salary: d.amount, morale: 80, hired: s.date, equity: 0.2))
            Sim.news(&s, "New hire brings \(ResearchCatalog.byID[d.ref]?.name ?? "a secret technique")", "You can now research it on the Research page.", .research, good: true)
            // Their old lab may come after you for it.
            if s.rng.chance(0.3), let lab = s.rivalTech.first(where: { $0.value.contains(d.ref) })?.key {
                let amount = clamp(max(d.amount * 4, s.valuation * 0.001), 2e6, 1e9)
                s.pendingSuits.append(PendingSuit(lab: lab, tech: d.ref, due: GameCalendar.addDays(s.date, s.rng.int(30, 180)), amount: amount))
            }
        case ("poach", _):
            break
        case ("trade_secret", 0):
            s.cash -= d.amount
            s.month.costOther += d.amount
            s.brand = max(0, s.brand - 2)
            Sim.news(&s, "Trade-secret suit settled for \(Fmt.money(d.amount))", "Expensive, and the talent wars look uglier. Brand −2.", .policy, good: false)
        case ("trade_secret", _):
            if s.rng.chance(0.5) {
                s.cash -= d.amount * 0.1
                s.month.costOther += d.amount * 0.1
                Sim.news(&s, "You won the trade-secret case", "The court found no misappropriation. Legal fees: \(Fmt.money(d.amount * 0.1)).", .policy, good: true)
            } else {
                s.cash -= d.amount * 2
                s.month.costOther += d.amount * 2
                s.brand = max(0, s.brand - 6)
                Sim.news(&s, "You lost the trade-secret case", "Damages of \(Fmt.money(d.amount * 2)). Brand −6.", .policy, important: true, good: false)
            }
        case ("hq_grant", _), ("hq_partner", _), ("hq_contract", _):   // 3.5: headquarters
            HQ.resolve(&s, d, option: option)
        case ("data_auction", _), ("data_collection", _), ("data_lawsuit", _):   // 3.6: data economy
            DataEconomy.resolve(&s, d, option: option)
        case ("rsi_resource", _), ("rsi_exfil", _):
            RSI.resolve(&s, kind: d.kind, option: option, ref: d.ref)
        case ("swarm_collusion", _), ("swarm_escape", _):
            Swarms.resolve(&s, kind: d.kind, option: option, ref: d.ref)
        case ("policy_bill", _):
            Policy.resolve(&s, d, option: option)
        case ("xeno_anomaly", _):
            XenoScience.resolveAnomaly(&s, d, option: option)
        case ("alien_errata", _):   // 3.5: alien fab
            AlienFab.resolveErrata(&s, d, option: option)
        case ("rival_round", _):
            RivalEconomy.resolveStake(&s, d, option: option)
        case ("fire_sale", _):
            RivalEconomy.resolveFireSale(&s, d, option: option)
        case ("victory", _):
            Victory.resolve(&s, d, option: option)
        case ("moonshot", _): Moonshots.resolve(&s, d, option: option)   // 3.4: late game
        case ("fun_cfp", _), ("fun_keynote", _): Fun.resolve(&s, d, option: option)   // 3.5: fun systems
        case (AdvancedProjects.secrecyKind, _): AdvancedProjects.resolveSecrecy(&s, d, option: option)   // 3.5
        case ("board_ouster", _), ("exclusive_supply", _), ("swarm_audit", _), ("merger_offer", _), ("spinoff", _), ("sovereign_deal", _), ("talent_raid", _),
             ("distill_campaign", _), ("eval_escape", _), ("insider_caught", _):
            StrategyEvents.resolve(&s, d, option: option)
        case ("acquisition", 0):
            s.exitValue = d.amount
            s.gameOver = "Acquired for \(Fmt.money(d.amount)) on \(s.date.gameShort). Your stake: \(Fmt.money(d.amount * s.founderStake))."
            Sim.news(&s, "\(s.companyName) acquired for \(Fmt.money(d.amount))", s.gameOver!, .finance, important: true, good: true)
        default:
            break
        }
    }

    static func markLawsuit(_ s: inout GameState, _ ref: String) {
        for i in s.models.indices where s.models[i].usedShadowData { s.models[i].lawsuitResolved = true }
    }
}

enum Achievements {
    static func unlock(_ s: inout GameState, _ id: String) {
        guard !s.achievements.contains(id), let a = AchievementCatalog.byID[id] else { return }
        s.achievements.insert(id)
        s.culturePoints += 1
        Sim.news(&s, "🏆 Achievement: \(a.title)", a.detail, .company, important: true, good: true)
        Alerts.raise(&s, .milestone, key: id, title: a.title, body: a.detail, screen: .achievements, celebrate: true, cooldown: 0)
        Pulse.milestone(&s, id)   // 3.4: the industry notices
    }

    static func check(_ s: inout GameState) {
        if !s.models.isEmpty { unlock(&s, "first_model") }
        if !s.releasedModels.isEmpty { unlock(&s, "first_release") }
        if s.lifetimeRevenue > 1 { unlock(&s, "first_revenue") }
        if s.lifetimeRevenue > 1e6 { unlock(&s, "million") }
        if s.models.contains(where: { $0.c >= 2.8 }) { unlock(&s, "gpt3") }
        if s.models.contains(where: { $0.c >= 5.1 }) { unlock(&s, "gpt4") }
        if s.releasedModels.contains(where: { $0.reasoning }) { unlock(&s, "reasoner") }
        if s.releasedModels.contains(where: { $0.openWeights }) { unlock(&s, "open") }
        if s.isPublic { unlock(&s, "ipo") }
        if s.date.ym.month != 0 && GameCalendar.components(s.date).day % 7 == 1 {
            let set = Leaderboard.indexSet(s)
            let arc3 = s.benchmarks.first { $0.id == "arc3" }
            let hle = s.benchmarks.first { $0.id == "hle" }
            for m in s.models where m.c > 9 {
                let p = Leaderboard.profile(m)
                if BenchmarkCatalog.index(p, set: set) >= 90,
                   let a = arc3, BenchmarkCatalog.cachedScore(a, p) >= 85,
                   let h = hle, BenchmarkCatalog.cachedScore(h, p) >= 90 {
                    unlock(&s, "superintelligence")
                }
            }
        }
        // Cheaper checks once a week
        guard GameCalendar.components(s.date).day % 7 == 0 else { return }
        let rr = Economy.runRate(s)
        if rr > 1e9 { unlock(&s, "billion_rr") }
        if rr > 1e11 { unlock(&s, "hundred_billion_rr") }
        if s.valuation > 1e9 { unlock(&s, "unicorn") }
        if s.valuation > 1e10 { unlock(&s, "decacorn") }
        if s.valuation > 1e12 { unlock(&s, "trillion") }
        let chips = Economy.totalChips(s)
        if chips >= 1_000 { unlock(&s, "chips_1k") }
        if chips >= 100_000 { unlock(&s, "chips_100k") }
        if chips >= 1_000_000 { unlock(&s, "chips_1m") }
        let mw = s.sites.filter { $0.kind == .datacenter && $0.isReady(s.date) }.reduce(0) { $0 + $1.capacityKW } / 1000
        if mw >= 1000 { unlock(&s, "gigawatt") }
        if s.employees.filter({ $0.role == .researcher }).count >= 100 { unlock(&s, "researchers") }
        let tpus = s.rentals.filter { HardwareCatalog.get($0.accelID)?.cls == .tpu }.reduce(0) { $0 + $1.count }
        if tpus >= 1000 { unlock(&s, "tpu") }
        guard !s.achievements.contains("frontier") || !s.achievements.contains("arena") else { return }
        let board = Leaderboard.entries(s, includeUnreleased: false)
        if board.first?.isPlayer == true { unlock(&s, "frontier") }
        if let top = board.max(by: { $0.arena < $1.arena }), top.isPlayer { unlock(&s, "arena") }
    }
}
