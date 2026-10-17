import Foundation

/// 3.4: things that follow from the state of the world rather than from a dice roll — a regulator answers a major
/// incident with a bill, job losses past a threshold bring protests, strikes and a robot-tax debate, AI's power draw
/// brings grid emergencies and moratoria, very capable AI brings an AGI debate and a summons to testify, and a run of
/// trust gains brings partnership offers. They are rare (at most one a month, two months apart, five a year), mostly
/// news and a banner that doesn't pause, and now and then an offer in the inbox that resolves itself if ignored.
enum Consequences {
    /// Days between any two consequences, and how many a year at most.
    static let gapDays = 60
    static let perYear = 5
    /// Share of the workers AI can reach who are out of work because of it (percent): protests, strikes, a robot tax.
    static let jobThresholds: [Double] = [0.8, 1.1, 1.3]

    static func monthly(_ s: inout GameState) {
        guard s.world.ready, s.gameOver == nil else { return }
        if s.world.jobPressure < jobThresholds[0] * 0.7 { s.world.levels["jobs"] = nil }
        if let last = s.world.lastConsequence, GameCalendar.daysBetween(last, s.date) < gapDays { return }
        let today = s.date
        let lastYear = s.world.consequences.filter { GameCalendar.daysBetween($0.date, today) < 365 }.count
        guard lastYear < perYear else { return }
        if regulator(&s) || jobs(&s) || energy(&s) || capability(&s) || partnership(&s) {
            s.world.lastConsequence = s.date
        }
    }

    // MARK: Helpers

    static func ready(_ s: GameState, _ key: String, days: Int) -> Bool {
        s.world.fired[key].map { GameCalendar.daysBetween($0, s.date) >= days } ?? true
    }

    /// Record a consequence: the World log, a news story and (unless an inbox offer carries it) a banner that doesn't pause.
    static func happen(_ s: inout GameState, _ key: String, _ title: String, _ body: String, category: NewsCategory = .policy,
                       image: String? = nil, good: Bool? = false, banner: Bool = true) {
        s.world.fired[key] = s.date
        s.world.consequences.insert(WorldNote(date: s.date, text: title, kind: "consequence"), at: 0)
        if s.world.consequences.count > 60 { s.world.consequences.removeLast(s.world.consequences.count - 60) }
        Sim.news(&s, title, body, category, image: image, important: true, good: good)
        if banner { Alerts.raise(&s, .world, key: key, title: title, body: body, screen: .world, cooldown: 30) }
    }

    /// A bill can still be introduced: not decided, not pending, and at most a year before its time (bills that only
    /// events introduce, like the robot tax, have no time).
    static func eligible(_ s: GameState, _ id: String) -> PolicyCatalog.Bill? {
        guard let bill = PolicyCatalog.byID[id], !s.lawsPassed.contains(id), !s.lawsFailed.contains(id),
              !s.bills.contains(where: { $0.id == id }), bill.earliest >= 9_000 || s.year >= bill.earliest - 1 else { return nil }
        return bill
    }

    static func setStrictness(_ s: inout GameState, _ r: Region, plus v: Double) {
        s.world.normalize()
        s.world.strictness[r.index] = clamp(s.world.strictness[r.index] + v, 0, 100)
    }

    // MARK: A regulator answers an incident

    static func regulator(_ s: inout GameState) -> Bool {
        guard ready(s, "regulator", days: 365) else { return false }
        let w = s.world
        let rise = w.history.count >= 3 ? w.concern - w.history[w.history.count - 3].concern : 0
        let recent = w.incidentDate.map { GameCalendar.daysBetween($0, s.date) <= 90 } ?? false
        guard (rise >= 6 || recent) && w.concern >= 25 else { return false }
        let cause = recent && !w.incident.isEmpty ? w.incident : "a run of AI incidents"
        let yours = recent && w.incident.contains(s.companyName)
        // Your own incident goes to your home lawmakers first, if they have a bill for it. Otherwise the jurisdiction
        // most likely to act answers: strict, responsive, not the one that answered last time, and — if it was your
        // incident — unimpressed with you.
        let bill = usBill(s, cause: cause)
        let r: Region = yours && bill != nil ? .us : ([Region.us, .eu, .uk, .japanKorea].max { a, b in
            score(s, a, yours: yours) < score(s, b, yours: yours)
        } ?? .eu)
        s.world.fired["regulator.\(r.rawValue)"] = s.date
        if r == .us, let bill {
            Policy.introduce(&s, bill, boost: 0.08)
            setStrictness(&s, .us, plus: 4)
            happen(&s, "regulator", "\(r.regulator) fast-tracks the \(bill.title) after \(cause)",
                   "Public concern about AI safety is at \(Int(w.concern))/100. The bill is in your inbox: back it, fight it or stay out.")
            return true
        }
        setStrictness(&s, r, plus: 6)
        let times = s.world.levels["regulator.\(r.rawValue)", default: 0]
        s.world.levels["regulator.\(r.rawValue)"] = times + 1
        let verbs = ["proposes emergency AI rules", "tightens its AI rules", "orders new safety checks on frontier models"]
        happen(&s, "regulator", "\(r.regulator) \(verbs[times % verbs.count]) after \(cause)",
               "Concern about AI safety is at \(Int(w.concern))/100. Rules in \(r.short) tighten to \(Int(s.world.strictness(r)))/100 (\(World.strictnessLabel(s.world.strictness(r)).lowercased())).")
        if yours && s.world.government(r) < 50 && Policy.isFrontierDeveloper(s) {
            let cost = max(1e6, Economy.runRate(s) * 0.002)
            Events.addDecision(&s, kind: "world_inquiry", title: "\(r.regulator) opens an inquiry into \(s.companyName)",
                               body: "After \(cause), officials \(r.inPlace) want your safety evaluations, incident logs and red-team reports. Your standing there is \(Int(s.world.government(r)))/100.",
                               image: "stock_exchange",
                               options: [DecisionOption(label: "Cooperate fully (\(Fmt.money(cost)))", detail: "Standing \(r.inPlace) +6, public trust +1, safety +1."),
                                         DecisionOption(label: "Give them the minimum", detail: "Standing \(r.inPlace) −2."),
                                         DecisionOption(label: "Refuse", detail: "Standing \(r.inPlace) −8, public trust −2, and they may fine you.")],
                               amount: cost, ref: r.rawValue)
        }
        return true
    }

    static func score(_ s: GameState, _ r: Region, yours: Bool) -> Double {
        let dislike = yours ? 1 + max(0, 60 - s.world.government(r)) / 100 : 1
        // A regulator that answered an incident in the last two years leaves the next one to someone else.
        let tired = ready(s, "regulator.\(r.rawValue)", days: 730) ? 1 : 0.35
        // The US acts through bills; with none left to introduce it mostly holds hearings, which other regions outdo.
        let tools = r == .us && usBill(s, cause: "") == nil ? 0.5 : 1
        return s.world.strictness(r) * r.responsiveness * dislike * tired * tools
            * (1 + 0.25 * World.roll(s, "reg|\(r.rawValue)|\(s.date.ym.year)-\(s.date.ym.month)"))
    }

    /// The US bill that answers this kind of incident.
    static func usBill(_ s: GameState, cause: String) -> PolicyCatalog.Bill? {
        let agents = ["swarm", "agent", "self-copying", "self-improving"].contains { cause.lowercased().contains($0) }
        let order = agents ? ["kill_switch", "agent_registry", "independent_auditors", "transparency", "liability", "compute_licensing"]
                           : ["transparency", "independent_auditors", "liability", "kill_switch", "agent_registry", "compute_licensing"]
        return order.lazy.compactMap { eligible(s, $0) }.first
    }

    // MARK: Job losses

    static func jobs(_ s: inout GameState) -> Bool {
        let p = s.world.jobPressure
        let h = s.world.history
        let before = h.count >= 6 ? h[h.count - 6].looking / Sector.totalWorkforce * 100 : p
        guard p > before else { return false }
        var crossed = 0
        for (k, t) in jobThresholds.enumerated() where p >= t { crossed = k + 1 }
        guard crossed > 0 else { return false }
        let reached = s.world.levels["jobs"] ?? 0
        // A threshold fires when it's first crossed; after that it comes back only if things keep getting worse.
        if crossed <= reached {
            guard p >= jobThresholds[crossed - 1] * 1.15, ready(s, "jobs.\(crossed)", days: 540) else { return false }
        }
        var level = crossed
        if level == 3 && eligible(s, "robot_tax") == nil {
            // The robot tax has had its debate: strikes instead, if there hasn't been one for a while.
            guard ready(s, "jobs.2", days: 540) else { return false }
            level = 2
        }
        s.world.levels["jobs"] = max(reached, crossed)
        let looking = Fmt.trim(s.world.looking, 0)
        let named = Stakeholders.automationShare(s) >= 0.12
        switch level {
        case 1:
            let cities = 20 + Int(World.roll(s, "protest|\(s.date.ym.year)") * 40)
            World.shock(&s, mood: -2, "Protests over AI job losses")
            if named { Stakeholders.move(&s, ["public": -2], "Protesters named you among the labs selling AI agents") }
            happen(&s, "jobs.1", "Protests over AI job losses in \(cities) cities",
                   "About \(looking)M people who lost work to AI are still looking. Marchers want limits on AI agents\(named ? " and name \(s.companyName) among the labs selling them" : "").",
                   category: .market, image: "sf_skyline")
        case 2:
            let unions = ["clerical workers' union", "teachers' federation", "logistics workers' union", "public-service union"]
            let union = unions[min(unions.count - 1, Int(World.roll(s, "strike|\(s.date.ym.year)") * Double(unions.count)))]
            World.shock(&s, concern: 1, mood: -3, "Strikes over AI agents")
            if named { Stakeholders.move(&s, ["public": -3, "investors": -1], "Strikers singled out your agents") }
            happen(&s, "jobs.2", "Strike: the \(union) walks out over AI agents",
                   "Members walked out demanding retraining money and limits on agents at work. \(looking)M people are out of work because of AI.",
                   category: .market, image: "sf_skyline")
        default:
            guard let bill = eligible(s, "robot_tax") else { return false }
            Policy.introduce(&s, bill, boost: 0.05)
            happen(&s, "jobs.3", "The robot tax debate reaches \(Region.us.regulator)",
                   "With \(looking)M people out of work because of AI, the \(bill.title) would levy 4% on revenue from AI agents to pay for retraining. It's in your inbox.",
                   category: .policy, image: "stock_exchange", good: nil)
        }
        return true
    }

    // MARK: Energy

    static func energy(_ s: inout GameState) -> Bool {
        guard ready(s, "energy", days: 420) else { return false }
        let w = s.world
        let month = GameCalendar.components(s.date).month
        guard w.gridStress >= ([1, 2, 7, 8].contains(month) ? 45 : 55) else { return false }
        let share = Fmt.pct(w.aiShare, decimals: 1)
        let today = s.date
        let campuses = s.sites.filter { $0.kind == .datacenter && $0.isReady(today) }.map { ($0, Economy.siteLoadKW(s, $0.id)) }
        let big = campuses.filter { $0.1 >= 50_000 }.max { $0.1 < $1.1 }
        if let (site, kw) = big, World.roll(s, "grid|\(s.date.ym.year)-\(month)") < 0.6 {
            let extra = kw * 24 * 7 * site.powerPrice * 1.5
            s.cash -= extra
            s.month.costPower += extra
            s.world.gridShock -= 10
            if let r = Region.of(location: site.locationID) {
                Stakeholders.move(&s, [r.rawValue: -2, "public": -1], "\(site.name) strained the grid during an emergency")
            }
            happen(&s, "energy", "Grid emergency near \(site.location.name): AI campuses curtailed",
                   "The grid operator cut large loads for a week; AI now draws \(share) of the world's electricity. \(site.name) paid \(Fmt.money(extra)) extra for power.",
                   category: .market, image: "substation")
            return true
        }
        if let bill = eligible(s, "dc_moratorium"), s.year >= 2026 {
            Policy.introduce(&s, bill, boost: 0.1)
            s.world.gridShock -= 6
            happen(&s, "energy", "Grid strain: lawmakers propose a freeze on hyperscale datacenters",
                   "AI campuses draw \(Fmt.trim(w.powerGW, 0)) GW, \(share) of the world's electricity. The \(bill.title) is in your inbox.",
                   category: .market, image: "dc_construction")
            return true
        }
        s.market.buildDelay += 0.05
        s.world.gridShock -= 6
        let gw = Fmt.trim(w.powerGW, 0)
        let stories = [
            ("Counties pause datacenter permits as grids strain",
             "AI draws \(gw) GW worldwide, \(share) of all electricity. New campuses take a little longer to permit and connect for a while."),
            ("Grid operators ration new connections for AI campuses",
             "Interconnection queues for large loads are frozen while utilities catch up; AI now draws \(gw) GW, \(share) of the world's power. New sites take a little longer."),
            ("Rolling blackouts blamed on AI datacenters",
             "A cold snap and \(gw) GW of AI load were too much for two regional grids. Regulators slow permits for new campuses while the inquiry runs."),
        ]
        let told = s.world.levels["energy", default: 0]
        s.world.levels["energy"] = told + 1
        let story = stories[told % stories.count]
        happen(&s, "energy", story.0, story.1, category: .market, image: "dc_construction")
        return true
    }

    // MARK: Very capable AI

    static func capability(_ s: inout GameState) -> Bool {
        let c = World.capability(s)
        let level = s.world.levels["agi"] ?? 0
        if level < 1 && c >= 9.6 {
            s.world.levels["agi"] = 1
            World.shock(&s, concern: 4, mood: -1, "The AGI debate goes mainstream")
            happen(&s, "agi.1", "The AGI debate goes mainstream",
                   "Models now match experts at most desk work. Talk shows, churches and parliaments argue about what comes next, and concern about AI safety rises.",
                   category: .research, image: "sf_skyline", good: nil)
            return true
        }
        if level < 2 && c >= 11.0 {
            s.world.levels["agi"] = 2
            World.shock(&s, concern: 5, regions: [.us: 3, .eu: 3, .uk: 3, .japanKorea: 3, .china: 2, .india: 2, .gulf: 1],
                        "Parliaments hold hearings on superintelligence")
            happen(&s, "agi.2", "Parliaments hold hearings on superintelligence",
                   "Lawmakers on three continents question lab leaders about systems smarter than any person. Rules tighten everywhere.",
                   category: .policy, image: "stock_exchange", good: nil)
            return true
        }
        // A summons: you lead the world with a model above the High danger line.
        guard ready(s, "summons", days: 1_095), let mine = s.releasedModels.max(by: { $0.c < $1.c }), mine.c >= 8.4,
              SafetyFramework.tier(mine) >= .high else { return false }
        let rivals = s.competitors.filter(\.alive).compactMap { $0.latest?.c }.max() ?? -10
        guard mine.c >= rivals + 0.05 else { return false }
        Events.addDecision(&s, kind: "world_summons", title: "\(Region.us.regulator) summons \(s.founderName) to testify",
                           body: "\(mine.name) is the most capable model in the world. Senators want to hear how \(s.companyName) tests it, who can use it and what you'd do if it went wrong.",
                           image: "stock_exchange",
                           options: [DecisionOption(label: "Testify and commit to pre-release testing", detail: "US standing +6, political capital +4, public trust +2. Safety concern eases a little."),
                                     DecisionOption(label: "Send your policy chief", detail: "US standing −2."),
                                     DecisionOption(label: "Decline", detail: "US standing −8, public trust −3. It looks like you have something to hide.")],
                           ref: mine.id.uuidString)
        let again = s.world.fired["summons"] != nil
        happen(&s, "summons", again ? "Congress calls \(s.founderName) back to testify over \(mine.name)" : "Congress summons \(s.founderName) over \(mine.name)",
               "Lawmakers want the head of the lab with the world's most capable model to testify.", banner: false)
        return true
    }

    // MARK: Trust pays off

    static func partnership(_ s: inout GameState) -> Bool {
        guard ready(s, "partnership", days: 365), let best = s.releasedModels.max(by: { $0.c < $1.c }) else { return false }
        let h = s.world.history.filter { $0.standing.count == 5 }
        guard h.count >= 6 else { return false }
        let then = h[h.count - 6]
        let w = s.world
        if w.publicTrust >= 62 && w.publicTrust - then.standing[0] >= 6 {
            let sector = [Sector.healthcare, .education, .government][min(2, Int(World.roll(s, "pilot|\(s.date.ym.year)") * 3))]
            let partner = sector == .healthcare ? "A national health service" : (sector == .education ? "A state university system" : "A national tax agency")
            let monthly = max(2e6, Economy.runRate(s) * 0.008)
            Events.addDecision(&s, kind: "world_partnership", title: "\(partner) wants to pilot your models",
                               body: "Public trust in \(s.companyName) is \(Int(w.publicTrust))/100 and rising. They offer \(Fmt.money(monthly))/month for two years to run \(best.name) in \(sector.title.lowercased()), under strict privacy terms.",
                               image: "sf_skyline",
                               options: [DecisionOption(label: "Sign the pilot", detail: "+\(Fmt.money(monthly * 24)) over two years. Public trust +2; \(sector.title.lowercased()) adopts AI a little faster."),
                                         DecisionOption(label: "Not now", detail: "No change.")],
                               amount: monthly, ref: "pilot|\(sector.rawValue)")
            happen(&s, "partnership", "\(partner) asks \(s.companyName) for a pilot", "A run of rising public trust opens doors.", category: .company, good: true, banner: false)
            return true
        }
        let buyers: [Region] = [.eu, .uk, .gulf, .india, .japanKorea]
        if let r = buyers.max(by: { w.government($0) < w.government($1) }), w.government(r) >= 66, w.governmentAverage - then.standing[4] >= 4 {
            let monthly = max(5e6, Economy.runRate(s) * 0.02)
            let country: String
            switch r {
            case .gulf: country = "a Gulf state"
            case .eu: country = "a European government"
            case .uk: country = "the UK government"
            case .india: country = "the Indian government"
            default: country = "the Japanese government"
            }
            Events.addDecision(&s, kind: "sovereign_deal", title: "Sovereign AI deal with \(country)",
                               body: "Your standing in \(r.title) is \(Int(w.government(r)))/100. They want a national model built on \(best.name): \(Fmt.money(monthly))/month for 3 years, hosted in-country with strict safety terms.",
                               image: "substation",
                               options: [DecisionOption(label: "Sign it", detail: "+\(Fmt.money(monthly * 36)) over 3 years. Critics may object depending on the client."),
                                         DecisionOption(label: "Decline", detail: "Stay out of geopolitics.")],
                               amount: monthly, ref: "world|\(r.rawValue)")
            happen(&s, "partnership", "\(r.title) courts \(s.companyName)", "Rising standing with governments opens a sovereign AI offer.", category: .company, good: true, banner: false)
            return true
        }
        if w.researchers >= 68 && w.researchers - then.standing[1] >= 6 {
            let cost = max(2e6, s.cash * 0.002)
            Events.addDecision(&s, kind: "world_partnership", title: "Universities want a joint AI institute with \(s.companyName)",
                               body: "Researchers rate your lab \(Int(w.researchers))/100. A consortium of universities offers to co-found an institute: shared fellows, open seminars and a first look at their best students.",
                               image: "sf_skyline",
                               options: [DecisionOption(label: "Fund it (\(Fmt.money(cost)))", detail: "Researchers' respect +4 and a culture point."),
                                         DecisionOption(label: "Not now", detail: "No change.")],
                               amount: cost, ref: "institute")
            happen(&s, "partnership", "Universities court \(s.companyName)", "Researchers' respect opens a joint institute offer.", category: .research, good: true, banner: false)
            return true
        }
        return false
    }

    // MARK: Answers

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch (d.kind, option) {
        case ("world_summons", 0):
            s.politicalCapital = min(100, s.politicalCapital + 4)
            Stakeholders.move(&s, ["us": 6, "public": 2, "researchers": 1], "\(s.founderName) testified before Congress")
            World.shock(&s, concern: -2, "\(s.founderName) testified before Congress")
            Sim.news(&s, "\(s.founderName) testifies before Congress", "Hours of questions about testing, access and shutdown plans. Most senators leave reassured.", .policy, good: true)
        case ("world_summons", 1):
            Stakeholders.move(&s, ["us": -2], "Sent the policy chief to a congressional summons")
        case ("world_summons", _):
            Stakeholders.move(&s, ["us": -8, "public": -3], "Declined to testify before Congress")
            World.shock(&s, concern: 2, "\(s.companyName) declined to testify")
            Sim.news(&s, "\(s.founderName) declines to testify", "An empty chair at the hearing makes the evening news.", .policy, good: false)
        case ("world_inquiry", 0):
            guard let r = Region(rawValue: d.ref) else { return }
            s.cash -= d.amount
            s.month.costOther += d.amount
            s.safetyScore = min(100, s.safetyScore + 1)
            Stakeholders.move(&s, [r.rawValue: 6, "public": 1], "Cooperated fully with an inquiry \(r.inPlace)")
        case ("world_inquiry", 1):
            guard let r = Region(rawValue: d.ref) else { return }
            Stakeholders.move(&s, [r.rawValue: -2], "Gave an inquiry \(r.inPlace) the minimum")
        case ("world_inquiry", _):
            guard let r = Region(rawValue: d.ref) else { return }
            Stakeholders.move(&s, [r.rawValue: -8, "public": -2], "Refused an inquiry \(r.inPlace)")
            if World.roll(s, "fine|\(d.id.uuidString)") < 0.4 {
                let fine = max(5e6, Economy.runRate(s) * 0.01) * Policy.fineFactor(s)
                s.cash -= fine
                s.month.costOther += fine
                Sim.news(&s, "\(r.short) fines \(s.companyName) \(Fmt.money(fine))", "Regulators made an example of a lab that refused their inquiry.", .policy, important: true, good: false)
            }
        case ("world_partnership", 0):
            if d.ref == "institute" {
                s.cash -= d.amount
                s.month.costOther += d.amount
                s.culturePoints += 1
                Stakeholders.move(&s, ["researchers": 4], "Co-founded a university AI institute")
                Sim.news(&s, "\(s.companyName) co-founds a university AI institute", "Fellows, seminars and a pipeline of students. +1 culture point.", .research, good: true)
            } else if d.ref.hasPrefix("pilot|") {
                let sector = Sector(rawValue: String(d.ref.dropFirst(6))) ?? .healthcare
                let partner = d.title.replacingOccurrences(of: " wants to pilot your models", with: "")
                s.deals.append(EnterpriseDeal(client: partner, title: "\(sector.title.lowercased()) pilot", monthly: d.amount, tokensPerDay: 0,
                                              months: 24, monthsLeft: 24, minIndex: 0, minSafety: 0, expires: s.date, active: true))
                s.world.normalize()
                s.world.boosts[sector.index] += 0.01
                Stakeholders.move(&s, ["public": 2], "Signed a \(sector.title.lowercased()) pilot with \(partner.prefix(1).lowercased() + partner.dropFirst())")
                Sim.news(&s, "Pilot signed: \(partner)", "\(Fmt.money(d.amount))/month for two years.", .company, good: true)
            }
        default:
            break
        }
    }
}
