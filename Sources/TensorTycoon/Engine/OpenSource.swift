import Foundation

/// 3.9: the open-source community. Everything you give away — model weights (Launches / `release`), libraries and
/// datasets from the catalogue, the systems a grand challenge makes you publish — becomes a repo that gathers stars,
/// forks and outside contributors month by month. The community pays you back: goodwill lifts how researchers and
/// developers see you (Stakeholders), maintained tools and a big star count grow your developer ecosystem (Launches,
/// so API demand), and top contributors ask to join (sourced candidates on the Team page). It costs maintainers'
/// salaries, rivals build on your code (Competitors.plannedC) and powerful open releases draw safety scrutiny, which
/// can turn into incidents and regulators' questions.
enum OpenSource {
    static let scrutinyKind = "oss_scrutiny"
    static let incidentCooldown = 120

    // MARK: Numbers

    /// How many developers are out there to star things, relative to 2023 (1.0).
    static func era(_ y: Double) -> Double {
        interpolate([(2016, 0.2), (2019, 0.4), (2021, 0.6), (2023, 1.0), (2025, 1.4), (2027, 1.7), (2030, 2.0), (2035, 2.4)], at: y, extrapolate: false)
    }

    /// An engineer's month, fully loaded.
    static func maintainerMonth(_ s: GameState) -> Double { Macro.salary(.mlEngineer, s.year) * 1.3 / 12 }

    static func grantsMonth(_ s: GameState) -> Double { 60_000 * era(s.year) + 0.25 * maintenanceMonth(s) }

    static func maintainers(_ r: OpenRepo) -> Int {
        guard r.maintained else { return 0 }
        switch r.kind {
        case .tool: return ChallengeCatalog.toolByID[String(r.id.dropFirst(5))]?.maintainers ?? 2
        case .challenge: return 1
        case .model: return 0
        }
    }

    static func maintenanceMonth(_ s: GameState) -> Double {
        Double(s.challenges.repos.reduce(0) { $0 + maintainers($1) }) * maintainerMonth(s)
    }

    static func monthlyCost(_ s: GameState) -> Double { maintenanceMonth(s) + (s.challenges.grants ? grantsMonth(s) : 0) }

    static func toolName(_ t: OpenToolDef, _ s: GameState) -> String {
        let short = s.companyName.split(separator: " ").first.map(String.init) ?? s.companyName
        return t.name.replacingOccurrences(of: "{lab}", with: short)
    }

    static func tool(_ r: OpenRepo) -> OpenToolDef? { r.kind == .tool ? ChallengeCatalog.toolByID[String(r.id.dropFirst(5))] : nil }

    /// Open weights: near the frontier is quality 1, a full order of magnitude behind is worth little.
    static func modelQuality(_ m: AIModel, _ s: GameState) -> Double { clamp(1 + (m.c - Macro.frontier(s.year)) * 0.8, 0.1, 1.3) }

    /// Stars a repo can reach today.
    static func potential(_ r: OpenRepo, _ s: GameState) -> Double {
        let base: Double
        var q = r.quality
        switch r.kind {
        case .model:
            base = 90_000
            if let m = s.models.first(where: { "model:" + $0.id.uuidString == r.id }) { q = modelQuality(m, s) }
        case .tool: base = tool(r)?.stars ?? 5_000
        case .challenge: base = 4_000
        }
        let care = r.maintained || r.kind == .model ? 1.0 : 0.7
        return base * q * q * era(s.year) * care * (1 + s.challenges.goodwill / 200) * (s.challenges.grants ? 1.15 : 1)
    }

    static func contributorRate(_ r: OpenRepo) -> Double {
        switch r.kind {
        case .model: 0.002
        case .tool: 0.015
        case .challenge: 0.01
        }
    }

    // MARK: Effects (read by other systems)

    /// Points added to your developer ecosystem's target (Launches.ecosystem): maintained tools, and the sheer reach of
    /// what you've published. Up to 30.
    static func ecosystemLift(_ s: GameState) -> Double {
        let tools = s.challenges.repos.filter { $0.maintained }.compactMap { r in tool(r).map { $0.ecosystem * min(1.2, r.quality) } }.reduce(0, +)
        return min(30, tools + 6 * log10(1 + s.challenges.stars / 10_000))
    }

    /// Points added to how researchers or developers see you (Stakeholders.target): maintained tools and goodwill. Up to 6.
    static func standing(_ s: GameState, _ who: Stakeholder) -> Double {
        let maintained = s.challenges.repos.filter(\.maintained).compactMap(tool)
        let fromTools: Double
        switch who {
        case .researchers: fromTools = maintained.reduce(0) { $0 + $1.researchers }
        case .developers: fromTools = maintained.reduce(0) { $0 + $1.developers }
        default: return 0
        }
        return min(6, fromTools * 0.5 + s.challenges.goodwill / 25)
    }

    /// Capability rivals gain from the tools you've published (log10 compute units, up to 0.08): code stays out there
    /// whether or not you maintain it, though it ages.
    static func rivalC(_ s: GameState) -> Double {
        var c = 0.0
        for r in s.challenges.repos {
            guard let t = tool(r), t.rivalC > 0 else { continue }
            let years = Double(GameCalendar.daysBetween(r.released, s.date)) / 365
            c += t.rivalC * max(0.3, 1 - years / 6)
        }
        return min(0.08, c)
    }

    // MARK: Releasing

    static func availableDate(_ t: OpenToolDef) -> Date { GameCalendar.date(Int(t.year), Int((t.year - floor(t.year)) * 12) + 1, 1) }

    static func toolBlocker(_ t: OpenToolDef, _ s: GameState) -> String? {
        if s.challenges.repos.contains(where: { $0.id == "tool:\(t.id)" }) { return "Already open-sourced." }
        if s.year < t.year { return "Nobody builds this before \(availableDate(t).gameShort)." }
        if let r = t.requires, !s.researched.contains(r) { return "Needs \(ResearchCatalog.byID[r]?.name ?? r) research." }
        if t.id == "corpus" && s.dataSources.isEmpty { return "You need training data of your own to publish." }
        return nil
    }

    static func releaseTool(_ s: inout GameState, _ id: String) -> String? {
        guard let t = ChallengeCatalog.toolByID[id] else { return "Not found." }
        if let why = toolBlocker(t, s) { return why }
        let name = toolName(t, s)
        addRepo(&s, id: "tool:\(t.id)", kind: .tool, name: name, quality: 1)
        s.market.apiPricePressure = max(0.5, s.market.apiPricePressure - t.pricePressure)
        s.challenges.scrutiny = clamp(s.challenges.scrutiny + t.scrutiny, 0, 100)
        s.safetyScore = clamp(s.safetyScore + t.safety, 0, 100)
        s.brand = min(100, s.brand + 1)
        Stakeholders.move(&s, ["researchers": t.researchers * 0.5, "developers": t.developers * 0.5], "Open-sourced \(name)")
        Sim.news(&s, "\(name) is open source", "\(t.what), under a permissive licence. \(t.upside) \(t.downside) It needs \(t.maintainers) maintainer\(t.maintainers == 1 ? "" : "s") (\(Fmt.money(Double(t.maintainers) * maintainerMonth(s)))/month).",
                 .company, good: true)
        return nil
    }

    /// A new repo. Launch day brings a quarter of where it's heading.
    static func addRepo(_ s: inout GameState, id: String, kind: RepoKind, name: String, quality: Double, silent: Bool = false) {
        guard !s.challenges.repos.contains(where: { $0.id == id }) else { return }
        var r = OpenRepo(id: id, kind: kind, name: name, released: s.date, quality: quality)
        let p = potential(r, s)
        r.potential = p
        r.stars = (p * (silent ? 0.8 : 0.25)).rounded()
        r.forks = (r.stars * (kind == .model ? 0.17 : 0.12)).rounded()
        r.contributors = (r.stars * contributorRate(r) * (silent ? 1 : 0.3)).rounded()
        s.challenges.repos.append(r)
        if !silent { note(&s, "\(name) launched: \(Fmt.count(r.stars)) stars on day one.") }
    }

    static func setMaintained(_ s: inout GameState, _ id: String, _ on: Bool) -> String? {
        guard let i = s.challenges.repos.firstIndex(where: { $0.id == id }) else { return "Not found." }
        guard s.challenges.repos[i].kind != .model else { return "Published weights don't need maintainers." }
        guard s.challenges.repos[i].maintained != on else { return nil }
        s.challenges.repos[i].maintained = on
        if !on {
            s.challenges.goodwill = max(0, s.challenges.goodwill - 4)
            Stakeholders.move(&s, ["developers": -1], "Stopped maintaining \(s.challenges.repos[i].name)")
            note(&s, "You stopped maintaining \(s.challenges.repos[i].name); contributors drift away.")
        } else {
            note(&s, "Maintainers are back on \(s.challenges.repos[i].name).")
        }
        return nil
    }

    static func note(_ s: inout GameState, _ text: String) {
        s.challenges.log.insert("\(s.date.gameShort): \(text)", at: 0)
        if s.challenges.log.count > 30 { s.challenges.log.removeLast(s.challenges.log.count - 30) }
    }

    // MARK: Daily and monthly

    /// Older saves: weights already published become repos, quietly, as if they'd been out a while.
    static func adopt(_ s: inout GameState) {
        for m in s.models where m.openWeights && m.released {
            addRepo(&s, id: "model:" + m.id.uuidString, kind: .model, name: m.name, quality: modelQuality(m, s), silent: true)
        }
    }

    static func daily(_ s: inout GameState) {
        // Weights published since yesterday (Models page, a launch plan, a family).
        for m in s.models where m.openWeights && m.released && !s.challenges.repos.contains(where: { $0.id == "model:" + m.id.uuidString }) {
            addRepo(&s, id: "model:" + m.id.uuidString, kind: .model, name: m.name, quality: modelQuality(m, s))
            let tier = SafetyFramework.tier(m)
            let near = m.c >= Macro.frontier(s.year) - 0.5
            let add: Double = (tier == .critical ? 50 : tier == .high ? 30 : tier == .earlyWarning ? 10 : 1) + (near ? 5 : 0)
            s.challenges.scrutiny = clamp(s.challenges.scrutiny + add, 0, 100)
            if add >= 10 { note(&s, "\(m.name)'s weights put safety reviewers on alert (scrutiny +\(Int(add))).") }
        }
        if GameCalendar.components(s.date).day == 1 { monthly(&s) }
    }

    static func monthly(_ s: inout GameState) {
        guard !s.challenges.repos.isEmpty || s.challenges.goodwill > 0 || s.challenges.scrutiny > 0 else { return }
        let before = s.challenges.stars
        for i in s.challenges.repos.indices {
            var r = s.challenges.repos[i]
            if r.kind == .tool && !r.maintained { r.quality = max(0.3, r.quality * 0.99) }   // unmaintained code rots
            let p = potential(r, s)
            r.potential = p
            if p > r.stars { r.stars = (r.stars + (p - r.stars) * (r.maintained ? 0.12 : 0.04)).rounded() }
            let forkTarget = r.stars * (r.kind == .model ? 0.17 : 0.12)
            r.forks = max(r.forks, (r.forks + (forkTarget - r.forks) * 0.15).rounded())
            let crowd = r.stars * contributorRate(r) * (r.maintained ? 1 : 0.15) * (s.challenges.grants ? 1.4 : 1)
            r.contributors = max(0, (r.contributors + (crowd - r.contributors) * 0.2).rounded())
            s.challenges.repos[i] = r
        }
        // Goodwill follows contributors, what you keep up, how open you are and recent weights.
        let tools = s.challenges.repos.filter { $0.kind != .model && $0.maintained }.count
        let recent = s.releasedModels.filter { $0.openWeights && GameCalendar.daysBetween($0.releaseDate ?? $0.created, s.date) < 730 }
        let weights: Double = recent.contains { $0.c >= Macro.frontier(s.year) - 0.6 } ? 10 : (recent.isEmpty ? 0 : 4)
        var target = 12 * log10(1 + s.challenges.contributors / 5) + 4 * Double(min(5, tools)) + weights
        target += (s.publication == .open ? 6 : s.publication == .secret ? -6 : 0) + (s.challenges.grants ? 6 : 0)
        target -= 0.15 * max(0, s.challenges.scrutiny - 40)
        target = clamp(target, 0, 100)
        let g = s.challenges.goodwill
        s.challenges.goodwill = g + (target - g) * (target > g ? 0.1 : 0.05)
        s.challenges.scrutiny = max(0, s.challenges.scrutiny * 0.93)
        // Maintainers and grants.
        let cost = monthlyCost(s)
        if cost > 0 {
            s.cash -= cost
            s.month.costPayroll += maintenanceMonth(s)
            s.month.costOther += cost - maintenanceMonth(s)
            s.challenges.spent += cost
        }
        milestones(&s, before: before)
        contributorHire(&s)
        incident(&s)
    }

    static let starMarks: [(Double, String)] = [(1_000, "1k"), (10_000, "10k"), (50_000, "50k"), (100_000, "100k"), (250_000, "250k"), (500_000, "500k"), (1_000_000, "1M")]

    static func milestones(_ s: inout GameState, before: Double) {
        let now = s.challenges.stars
        for (mark, label) in starMarks where now >= mark && !s.challenges.milestones.contains(label) {
            s.challenges.milestones.insert(label)
            guard before > 0 || mark > 1_000 else { continue }
            Stakeholders.move(&s, ["developers": mark >= 100_000 ? 2 : 1], "\(label) stars across your open-source projects")
            if mark >= 100_000 { s.brand = min(100, s.brand + 1) }
            Sim.news(&s, "\(label) stars on your open-source projects", "\(Fmt.count(s.challenges.forks)) forks and \(Fmt.int(Int(s.challenges.contributors))) active outside contributors. \(mark >= 100_000 ? "One of the biggest communities in AI." : "Developers are noticing.")",
                     .company, good: true)
        }
    }

    /// Top contributors sometimes ask to join: a strong candidate on a little less than market pay (they like the work).
    static func contributorHire(_ s: inout GameState) {
        let crowd = s.challenges.contributors
        guard crowd >= 40, s.rng.chance(min(0.3, crowd / 2_500)) else { return }
        guard let repo = s.challenges.repos.filter({ $0.contributors >= 10 }).max(by: { $0.contributors < $1.contributors }) else { return }
        let role: Role = repo.kind == .model || s.rng.chance(0.5) ? .researcher : .mlEngineer
        var c = People.makeCandidate(&s, role: role, star: false)
        c.skill = clamp((72 + s.challenges.goodwill / 8 + s.rng.gaussian() * 5).rounded(), 60, 96)
        c.salary = (People.marketSalary(s, role: role, skill: c.skill, office: "", star: false, relocated: false) * 0.85 / 1000).rounded() * 1000
        c.equity = 0.02
        c.office = ""
        c.relocated = false
        c.sourced = true
        c.bio = "Top outside contributor to \(repo.name): \(s.rng.int(80, 600)) merged pull requests. Would take a little less than market pay to work on it full time."
        c.expires = GameCalendar.addDays(s.date, 45)
        s.candidates.append(c)
        s.challenges.contributorHires += 1
        note(&s, "\(c.name), a top contributor to \(repo.name), applied (skill \(Int(c.skill))).")
        Sim.news(&s, "A top contributor wants to join", "\(c.name) has been one of \(repo.name)'s most active outside contributors and applied for a \(role == .researcher ? "research" : "engineering") job: skill \(Int(c.skill)), asking \(Fmt.money(c.salary))/year. On your Team page for 45 days.",
                 .company, good: true)
    }

    /// Strong open releases draw scrutiny; past a point, something goes wrong (a stripped fine-tune, a regulator's
    /// letter, a prompt-injection mess, a rights holder's complaint).
    static func incident(_ s: inout GameState) {
        let sc = s.challenges.scrutiny
        guard sc > 25, s.challenges.lastIncident.map({ GameCalendar.daysBetween($0, s.date) >= incidentCooldown }) ?? true,
              s.rng.chance((sc - 25) / 250) else { return }
        let openModel = s.releasedModels.filter(\.openWeights).max { $0.c < $1.c }
        let hasProtocol = s.challenges.repos.contains { $0.id == "tool:agent_protocol" }
        let hasCorpus = s.challenges.repos.contains { $0.id == "tool:corpus" }
        s.challenges.lastIncident = s.date
        s.challenges.incidents += 1
        if sc >= 50, openModel != nil, !s.decisions.contains(where: { $0.kind == scrutinyKind }) {
            let review = reviewCost(s)
            Events.addDecision(&s, kind: scrutinyKind, title: "Regulators ask about your open releases",
                               body: "The Frontier Safety Institute and two national regulators want to know how you assessed misuse before publishing \(openModel!.name)'s weights. Safety scrutiny stands at \(Int(sc)) of 100.",
                               image: ImagePicker.pick(.government, seed: "oss scrutiny \(s.date.ym.year)"),
                               options: [DecisionOption(label: "Publish a responsible-release review", detail: "\(Fmt.money(review)) for outside red-teamers and a public report · safety +2, scrutiny −25, Europe and the UK warm to you."),
                                         DecisionOption(label: "Send a short statement", detail: "Free · scrutiny −5, a little standing lost in Europe and the UK."),
                                         DecisionOption(label: "Pull the weights from your hub", detail: "Scrutiny −40, but copies stay online: developers −6 and community goodwill −15.")],
                               amount: review, ref: openModel!.id.uuidString)
            return
        }
        if let m = openModel, !hasProtocol || s.rng.chance(0.6) {
            World.shock(&s, concern: 1.5, "A safety-stripped fine-tune of \(s.companyName)'s \(m.name) spread online", incident: "a stripped fine-tune of \(m.name)")
            Stakeholders.move(&s, ["eu": -1.5, "uk": -1.5, "public": -1], "A stripped fine-tune of \(m.name) spread online")
            Sim.news(&s, "A stripped fine-tune of \(m.name) spreads", "Someone removed its safety training and posted the result; it's been downloaded thousands of times. Nothing you can recall, and critics say this is what open weights mean.",
                     .policy, good: false)
            note(&s, "Incident: a safety-stripped fine-tune of \(m.name).")
        } else if hasProtocol {
            Stakeholders.move(&s, ["developers": -1, "public": -0.5], "A prompt-injection attack spread through your agent protocol")
            Sim.news(&s, "Prompt injection through your agent protocol", "A poisoned tool description tricked thousands of agents into leaking files. The flaw is in how servers were built, but the protocol carries your name.",
                     .company, good: false)
            note(&s, "Incident: prompt injection through the agent protocol.")
        } else if hasCorpus {
            s.challenges.scrutiny = min(100, s.challenges.scrutiny + 5)
            Stakeholders.move(&s, ["public": -0.5], "Rights holders found their work in your open corpus")
            Sim.news(&s, "Rights holders comb your open corpus", "A publishers' group found thousands of its books in your published dataset and is asking regulators to look.", .policy, good: false)
            note(&s, "Incident: a copyright complaint about the open corpus.")
        }
    }

    static func reviewCost(_ s: GameState) -> Double { (clamp(s.valuation * 0.0005, 1e6, 50e6) / 1e5).rounded() * 1e5 }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard d.kind == scrutinyKind else { return }
        switch option {
        case 0:
            guard s.cash >= d.amount else {
                s.challenges.scrutiny = max(0, s.challenges.scrutiny - 5)
                Sim.news(&s, "No money for a review", "You sent a short statement instead (a review costs \(Fmt.money(d.amount))).", .policy, good: false)
                return
            }
            s.cash -= d.amount
            s.month.costOther += d.amount
            s.safetyScore = min(100, s.safetyScore + 2)
            s.challenges.scrutiny = max(0, s.challenges.scrutiny - 25)
            Stakeholders.move(&s, ["eu": 2, "uk": 2, "researchers": 1], "Published a responsible-release review of your open weights")
            Sim.news(&s, "Responsible-release review published", "Outside red-teamers tested your open weights for misuse and you published the lot. Regulators call it a model for the industry.", .policy, good: true)
            note(&s, "Published a responsible-release review (scrutiny −25).")
        case 2:
            s.challenges.scrutiny = max(0, s.challenges.scrutiny - 40)
            s.challenges.goodwill = max(0, s.challenges.goodwill - 15)
            Stakeholders.move(&s, ["developers": -6, "researchers": -2], "Pulled your open weights from your hub")
            Sim.news(&s, "You pull the weights from your hub", "Regulators relax; developers are furious, and mirrors keep the files online anyway.", .policy, good: false)
            note(&s, "Pulled the weights from the hub (goodwill −15).")
        default:
            s.challenges.scrutiny = max(0, s.challenges.scrutiny - 5)
            Stakeholders.move(&s, ["eu": -1, "uk": -1], "Answered regulators' questions about open weights with a short statement")
            note(&s, "Answered regulators with a short statement.")
        }
    }
}

/// 3.9: the hooks the rest of the game calls (Sim, Events.resolve).
enum OpenLab {
    /// TT_NO_OPENLAB=1 switches the whole feature off (harness comparisons against the game without it).
    static let disabled = ProcessInfo.processInfo.environment["TT_NO_OPENLAB"] != nil

    static func daily(_ s: inout GameState) {
        guard !disabled else { return }
        if !s.challenges.started {
            GrandChallenges.start(&s)
            OpenSource.adopt(&s)
        }
        OpenSource.daily(&s)
        GrandChallenges.daily(&s)
    }

    static let kinds: Set<String> = [GrandChallenges.entryKind, GrandChallenges.pushKind, OpenSource.scrutinyKind]

    /// The playtest bot's answer: enter a challenge (standard) when the budget is small change and it has a real shot,
    /// otherwise pass; never pay for a late push; answer regulators with a statement.
    static func botChoice(_ d: Decision, _ s: GameState) -> Int {
        switch d.kind {
        case GrandChallenges.entryKind:
            guard let e = s.challenges.editions.first(where: { $0.id == d.ref }), let def = e.def, s.cash > 40 * d.amount,
                  let o = GrandChallenges.odds(def, s, effort: .standard, key: e.id), o.podium >= 0.3 else { return 2 }
            return 0
        default: return 1
        }
    }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        if d.kind == OpenSource.scrutinyKind { OpenSource.resolve(&s, d, option: option) } else { GrandChallenges.resolve(&s, d, option: option) }
    }

    /// Replay evidence (REPLAY_CHALLENGES=1): new challenge and community news each day, and a summary every 30 days.
    /// REPLAY_OSS="train_lib,inference,grants,open-best" open-sources those on day 1 (open-best: your best released
    /// closed model's weights).
    static func replayReport(_ s: inout GameState, day: Int) {
        let env = ProcessInfo.processInfo.environment
        if day == 1, let acts = env["REPLAY_OSS"] {
            for a in acts.split(separator: ",").map(String.init) {
                switch a {
                case "grants": _ = s.setCommunityGrants(true); print("    OSS grants on")
                case "open-best":
                    if let m = s.models.filter({ $0.released && !$0.retired && !$0.openWeights }).max(by: { $0.c < $1.c }) {
                        print("    OSS open weights \(m.name): \(s.release(m.id, api: m.api, openWeights: true) ?? "ok")")
                    }
                default: print("    OSS \(a): \(s.openSourceTool(a) ?? "ok")")
                }
            }
        }
        guard env["REPLAY_CHALLENGES"] != nil else { return }
        let c = s.challenges
        for n in s.news.prefix(12).reversed() where n.date == s.date {
            let t = n.title
            if t.contains("Grand challenge") || ChallengeCatalog.all.contains(where: { t.contains($0.short) }) || t.contains("open source") || t.contains("contributor")
                || t.contains("stars on") || t.contains("fine-tune") || t.contains(" enters ") || t.contains("Regulators") || t.contains("grand prize") {
                print("    CHALLENGE NEWS: \(t) — \(n.body)")
            }
        }
        for d in s.decisions where OpenLab.kinds.contains(d.kind) && d.date == s.date {
            print("    CHALLENGE DECISION: \(d.title) — " + d.options.map { "[\($0.label): \($0.detail)]" }.joined(separator: " "))
        }
        for e in c.editions where e.results == s.date && e.status == .done {
            print("    CHALLENGE RESULT \(GrandChallenges.label(e)) (bar \(Fmt.trim(GrandChallenges.barFor(e), 0))): " + e.standings.prefix(6).map { "\($0.team) \(Fmt.trim($0.score, 1))" }.joined(separator: ", ")
                  + " · you: \(e.place > 0 ? Contests.ordinal(e.place) : "not entered") · prize \(Fmt.money(e.prize))\(e.grandBy.isEmpty ? "" : " · grand prize \(GrandChallenges.teamName(e.grandBy, s))")")
        }
        guard day % 30 == 0 else { return }
        print("    OPENLAB: prizes \(Fmt.money(c.prizeMoney)) · wins \(c.wins) podiums \(c.podiums) grand \(c.grandPrizes) · stars \(Fmt.count(c.stars)) forks \(Fmt.count(c.forks)) contributors \(Int(c.contributors)) · goodwill \(Fmt.trim(c.goodwill, 1)) scrutiny \(Fmt.trim(c.scrutiny, 1)) · eco lift \(Fmt.trim(OpenSource.ecosystemLift(s), 1)) devEco \(Fmt.trim(s.marketMoves.devEcosystem, 1)) · standing +\(Fmt.trim(OpenSource.standing(s, .researchers), 1)) res / +\(Fmt.trim(OpenSource.standing(s, .developers), 1)) dev · rivals +\(Fmt.trim(OpenSource.rivalC(s), 3)) c · cost \(Fmt.money(OpenSource.monthlyCost(s)))/mo · hires \(c.contributorHires) incidents \(c.incidents) · best rival c \(Fmt.trim(s.competitors.flatMap(\.models).map(\.c).max() ?? 0, 2)) vs frontier \(Fmt.trim(Macro.frontier(s.year), 2))")
        for e in GrandChallenges.live(s) {
            guard let d = e.def else { continue }
            let o = GrandChallenges.odds(d, s, effort: e.effort == .none ? .standard : e.effort, pushed: e.pushed, key: e.id)
            print("      LIVE \(GrandChallenges.label(e)) [\(e.status.rawValue)\(e.exhibition ? " exhibition" : "")] results \(e.results.gameShort) · you ~\(GrandChallenges.expected(d, s, effort: e.effort == .none ? .standard : e.effort, pushed: e.pushed).map { d.metricText($0, bar: GrandChallenges.barFor(e)) } ?? "-") (bar \(Fmt.trim(GrandChallenges.barFor(e), 0))) · win \(o.map { Fmt.odds($0.win) } ?? "-") · field: \(GrandChallenges.field(d, s, at: e.results).prefix(3).map { "\($0.team) \(d.metricText($0.score, bar: GrandChallenges.barFor(e)))" }.joined(separator: ", "))")
        }
    }
}

// MARK: - Actions (the Challenges page)

extension GameState {
    mutating func enterChallenge(_ id: String, allIn: Bool) -> String? { GrandChallenges.enter(&self, id, effort: allIn ? .allIn : .standard) }
    mutating func passChallenge(_ id: String) -> String? { GrandChallenges.pass(&self, id); return nil }
    mutating func pushChallenge(_ id: String) -> String? { GrandChallenges.push(&self, id) }
    mutating func openSourceTool(_ id: String) -> String? { OpenSource.releaseTool(&self, id) }
    mutating func setRepoMaintained(_ id: String, _ on: Bool) -> String? { OpenSource.setMaintained(&self, id, on) }
    mutating func setCommunityGrants(_ on: Bool) -> String? {
        challenges.grants = on
        OpenSource.note(&self, on ? "Contributor grants and bug bounties started (\(Fmt.money(OpenSource.grantsMonth(self)))/month)." : "Contributor grants stopped.")
        if on { Stakeholders.move(&self, ["developers": 1], "Started contributor grants and bug bounties") }
        return nil
    }
}
