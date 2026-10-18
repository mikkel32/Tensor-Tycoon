import Foundation

/// 3.5: fun systems. Things to chase and moments to enjoy, layered on top of the simulation with small, visible effects:
///  • Conferences: five venues a year. Your lab is invited to submit (an inbox decision; open-science labs submit
///    automatically, secretive labs stay home). Papers are accepted, given orals and sometimes win best paper; rivals
///    publish too, and the biggest lab of the year gives the Meridian keynote.
///  • Challenges: seven public challenges, each tied to a capability domain. Every lab's best model enters
///    automatically; the winner takes the purse, and beating the bar claims a one-off grand prize (then the bar rises).
///  • Hackathons: spend a week of research for a shot at an idea, a viral demo or a paid pilot.
///  • Scenarios: challenge-mode starts with a goal, a deadline and a score.
/// Rolls are hashed (never the game's RNG), and nothing here stops the clock: decisions wait in the inbox.
enum Fun {
    static func roll(_ s: GameState, _ key: String) -> Double { Cast.roll(s, "fun|\(key)") }

    static func daily(_ s: inout GameState) {
        let (y, m, d) = GameCalendar.components(s.date)
        Conferences.daily(&s, year: y)
        Contests.daily(&s, year: y, month: m, day: d)
        Hackathons.daily(&s)
        if s.fun.firstNo1 == nil && s.monthsAtTop > 0 { s.fun.firstNo1 = s.date }
        if !s.fun.scenarioID.isEmpty && s.fun.scenarioOutcome == nil { Scenarios.daily(&s, firstOfMonth: d == 1) }
    }

    /// Inbox decisions from these systems.
    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch d.kind {
        case Conferences.cfpKind: Conferences.resolveCFP(&s, d, option: option)
        case Conferences.keynoteKind: Conferences.resolveKeynote(&s, d, option: option)
        default: break
        }
    }

    // MARK: Small shared helpers

    static func researchers(_ s: GameState) -> [Employee] { s.employees.filter { $0.role == .researcher } }

    static func lift(_ s: inout GameState, morale: Double, researchersOnly: Bool = false) {
        for i in s.employees.indices where !researchersOnly || s.employees[i].role == .researcher {
            s.employees[i].morale = clamp(s.employees[i].morale + morale, 0, 100)
        }
    }

    static func brand(_ s: inout GameState, _ v: Double) { s.brand = clamp(s.brand + v, 0, 100) }

    static func payPrize(_ s: inout GameState, _ amount: Double) {
        s.cash += amount
        s.month.oneOffIncome += amount
        s.fun.prizeMoney += amount
    }

    /// A lab's best released model by index (name), or nil.
    static func bestModelName(_ s: GameState, lab: String) -> String? {
        if lab == "player" { return s.releasedModels.max { $0.c < $1.c }?.name }
        return s.competitors.first { $0.id == lab }?.models.max { $0.index < $1.index }?.name
    }

    static func labName(_ s: GameState, _ lab: String, short: Bool = false) -> String {
        lab == "player" ? s.companyName : (short ? Cast.short(lab) : CompetitorCatalog.def(lab).name)
    }

    /// Your best released model's lab rank on the Intelligence Index (99 if none). `openOnly` counts open weights only.
    static func playerRank(_ s: GameState, openOnly: Bool = false) -> Int {
        let board = Leaderboard.entries(s, includeUnreleased: false)
        guard let mine = board.filter({ $0.isPlayer && (!openOnly || $0.open) }).max(by: { $0.index < $1.index }) else { return 99 }
        return Leaderboard.labRank(index: mine.index, board: board, gone: Leaderboard.goneLabs(s))
    }

    static func post(_ s: inout GameState, _ event: String, labs: [String], vars: [String: String], key: String, importance: Double, count: Int) {
        var v = Voices.base(s)
        v.merge(vars) { _, b in b }
        Pulse.react(&s, event, labs: labs, vars: v, key: "fun|\(key)", importance: importance, count: count)
    }
}

// MARK: - Conferences

enum Conferences {
    static let cfpKind = "fun_cfp"
    static let keynoteKind = "fun_keynote"
    /// Days before the conference that the call for papers lands, and that reviews come back.
    static let cfpLead = 45
    static let reviewLead = 14

    static func date(_ v: VenueDef, _ year: Int) -> Date { GameCalendar.date(year, v.month, v.day) }

    /// Upcoming conferences from today (this year's that haven't happened, then next year's).
    static func upcoming(_ s: GameState, count: Int = 5) -> [(VenueDef, Date)] {
        let y = s.date.ym.year
        var out: [(VenueDef, Date)] = []
        for year in [y, y + 1] {
            for v in FunCatalog.venues where year >= v.opens {
                let d = date(v, year)
                if d >= s.date { out.append((v, d)) }
            }
        }
        return Array(out.sorted { $0.1 < $1.1 }.prefix(count))
    }

    static func daily(_ s: inout GameState, year: Int) {
        for v in FunCatalog.venues where year >= v.opens {
            let conf = date(v, year)
            let left = GameCalendar.daysBetween(s.date, conf)
            guard left == cfpLead || left == reviewLead || left == 0 else { continue }
            if left == cfpLead { callForPapers(&s, v, year) }
            if left == reviewLead { reviews(&s, v, year) }
            if left == 0 { hold(&s, v, year) }
        }
    }

    // MARK: Papers

    struct Candidate {
        var source: String
        var title: String
        var item: ResearchItem?
    }

    static func title(_ s: GameState, topic: String, key: String) -> String {
        let n = FunCatalog.titlePatterns.count
        let start = Int(Fun.roll(s, "title|\(key)") * Double(n)) % n
        // "Video Diffusion at Scale at Scale" and "Towards Reliable Reliable…" read badly: take the next pattern instead.
        for k in 0..<n {
            let p = FunCatalog.titlePatterns[(start + k) % n]
            let words = p.replacingOccurrences(of: "{n}", with: "").split(separator: " ").map { $0.lowercased() }
            if words.contains(where: { $0.count > 3 && topic.lowercased().contains($0) }) { continue }
            return p.replacingOccurrences(of: "{n}", with: topic)
        }
        return topic
    }

    /// Your best unpublished result for this venue: a recent research result of your own, or a technical report on your
    /// best released model.
    static func solidCandidate(_ s: GameState, _ v: VenueDef, key: String) -> Candidate? {
        var best: (ResearchItem, Double)? = nil
        for (id, r) in s.researchResults where !s.fun.writtenUp.contains(id) {
            guard let item = ResearchCatalog.byID[id], !item.isExotic, item.year >= s.year - 3 else { continue }
            let score = r + (v.likes.contains(item.category) ? 0.3 : 0) + (item.category == .frontier ? 0.2 : 0) + 0.05 * (item.year - s.year)
            if best.map({ score > $0.1 || (score == $0.1 && item.id < $0.0.id) }) ?? true { best = (item, score) }
        }
        if let (item, _) = best { return Candidate(source: item.id, title: title(s, topic: item.name, key: "\(key)|\(item.id)"), item: item) }
        if let m = s.releasedModels.filter({ !s.fun.writtenUp.contains("model:\($0.name)") }).max(by: { $0.c < $1.c }) {
            return Candidate(source: "model:\(m.name)", title: "The \(m.name) Technical Report", item: nil)
        }
        return nil
    }

    /// One of your unique breakthroughs that the world hasn't seen yet.
    static func revealCandidate(_ s: GameState, key: String) -> Candidate? {
        let ids = s.exoticOwned.filter { s.researched.contains($0) && s.publishedTech[$0] == nil && !s.fun.writtenUp.contains($0) }.sorted()
        guard let id = ids.first, let item = ResearchCatalog.byID[id] else { return nil }
        return Candidate(source: id, title: title(s, topic: item.name, key: "\(key)|\(id)"), item: item)
    }

    static func quality(_ s: GameState, _ c: Candidate, _ v: VenueDef, reveal: Bool, key: String) -> Double {
        var q = 0.3
        if let item = c.item {
            let r = s.researchResults[item.id] ?? 1
            q += 0.3 * clamp((r - 0.7) / 0.8, 0, 1)
            if item.year >= s.year - 1 { q += 0.08 }
            if item.category == .frontier { q += 0.08 }
            if v.likes.contains(item.category) { q += 0.08 }
        } else {
            q += 0.15
        }
        if reveal { q += 0.25 }
        let best = Fun.researchers(s).map(\.skill).max() ?? 45
        q += 0.12 * clamp((best - 50) / 50, 0, 1)
        if s.publication == .open { q += 0.04 }
        if v.id == "guardrails" { q += 0.1 * clamp((s.safetyScore - 50) / 50, -1, 1) }
        q += 0.16 * (Fun.roll(s, "quality|\(key)") - 0.5)
        return clamp(q, 0.05, 0.98)
    }

    static func acceptOdds(_ q: Double) -> Double { clamp(0.15 + 0.8 * q, 0.1, 0.93) }

    static func callForPapers(_ s: inout GameState, _ v: VenueDef, _ year: Int) {
        let key = "\(v.id)|\(year)"
        // The Meridian keynote goes to the lab of the year: #1 on the index, or the most valuable lab.
        if v.id == "meridian" && s.year >= 2018 && !s.releasedModels.isEmpty {
            let richest = s.competitors.filter(\.alive).map(\.valuation).max() ?? 0
            if s.monthsAtTop > 0 || s.valuation > richest {
                Events.addDecision(&s, kind: keynoteKind, title: "Meridian \(year) wants \(s.founderName) for the keynote",
                                   body: "Twenty thousand researchers in a hall in \(v.city) on \(date(v, year).gameShort), and a live stream everyone in the industry watches. The organisers want the lab of the year on stage.",
                                   image: "sf_skyline",
                                   options: [DecisionOption(label: "Give the keynote yourself", detail: "Brand and public trust up. Live demos can go wrong."),
                                             DecisionOption(label: "Send your best researcher", detail: "Researchers love it. Less of a splash."),
                                             DecisionOption(label: "Decline", detail: "Someone else gets the stage.")],
                                   ref: key)
            }
        }
        guard s.publication != .secret, let solid = solidCandidate(s, v, key: key) else { return }
        if s.publication == .open {
            // Open science: the team submits its best work as a matter of course.
            submit(&s, v, year, solid, reveal: false)
            return
        }
        let q = quality(s, solid, v, reveal: false, key: "\(key)|\(solid.source)")
        var options = [DecisionOption(label: "Submit \"\(solid.title)\"",
                                      detail: "About \(Int((acceptOdds(q) * 100).rounded()))% likely to be accepted. Good for your standing with researchers.")]
        var ref = "\(key)|\(solid.source)|"
        if let big = revealCandidate(s, key: key), let item = big.item {
            let bq = quality(s, big, v, reveal: true, key: "\(key)|\(big.source)")
            options.append(DecisionOption(label: "Reveal \(item.name)",
                                          detail: "Your unique breakthrough, written up: about \(Int((acceptOdds(bq) * 100).rounded()))% likely to be accepted and a real shot at best paper. Every rival will have reproduced it within about six months."))
            ref += big.source
        }
        options.append(DecisionOption(label: "Sit this one out", detail: "Nothing leaves the building."))
        Events.addDecision(&s, kind: cfpKind, title: "Call for papers: \(v.short) \(year)",
                           body: "\(v.name), \(v.city), \(date(v, year).gameShort). \(v.blurb) Your team has something worth sending.",
                           image: nil, options: options, ref: ref)
    }

    static func resolveCFP(_ s: inout GameState, _ d: Decision, option: Int) {
        let parts = d.ref.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4, let v = FunCatalog.venueByID[parts[0]], let year = Int(parts[1]) else { return }
        let skip = d.options.count - 1
        guard option < skip else {
            Sim.news(&s, "You skip \(v.short) \(year)", "Nothing goes out this round. The team will have more next time.", .research)
            return
        }
        let key = "\(v.id)|\(year)"
        let reveal = option == 1 && !parts[3].isEmpty
        let source = reveal ? parts[3] : parts[2]
        let c: Candidate
        if source.hasPrefix("model:") {
            c = Candidate(source: source, title: "The \(source.dropFirst(6)) Technical Report", item: nil)
        } else {
            guard let item = ResearchCatalog.byID[source] else { return }
            c = Candidate(source: source, title: title(s, topic: item.name, key: "\(key)|\(source)"), item: item)
        }
        submit(&s, v, year, c, reveal: reveal)
    }

    static func submit(_ s: inout GameState, _ v: VenueDef, _ year: Int, _ c: Candidate, reveal: Bool) {
        let key = "\(v.id)|\(year)|\(c.source)"
        let q = quality(s, c, v, reveal: reveal, key: key)
        s.fun.writtenUp.insert(c.source)
        s.fun.papers.insert(PaperRecord(venue: v.id, year: year, title: c.title, source: c.source, quality: (q * 100).rounded() / 100, reveal: reveal), at: 0)
        if s.fun.papers.count > 60 { s.fun.papers.removeLast(s.fun.papers.count - 60) }
        if reveal {
            // The preprint goes up with the submission: the secret is out whatever the reviewers say.
            s.publishedTech[c.source] = s.date
            Sim.news(&s, "You reveal \(c.item?.name ?? "a breakthrough") in a \(v.short) submission",
                     "\"\(c.title)\" is on the preprint server. Researchers are impressed; every rival lab is reading it too.", .research, good: true)
        } else {
            Sim.news(&s, "Submitted to \(v.short): \"\(c.title)\"", "Reviews come back two weeks before the conference.", .research)
        }
    }

    static func reviews(_ s: inout GameState, _ v: VenueDef, _ year: Int) {
        guard let i = s.fun.papers.firstIndex(where: { $0.venue == v.id && $0.year == year && $0.outcome == .submitted }) else { return }
        let p = s.fun.papers[i]
        let key = "\(v.id)|\(year)|\(p.source)"
        if Fun.roll(s, "accept|\(key)") >= acceptOdds(p.quality) {
            s.fun.papers[i].outcome = .rejected
            Fun.lift(&s, morale: -2, researchersOnly: true)
            Sim.news(&s, "\(v.short) rejects \"\(p.title)\"", "Reviewer 2 was unconvinced. The team grumbles, fixes the experiments and aims for the next deadline.", .research, good: false)
            if Fun.roll(s, "rejectpost|\(key)") < 0.5 {
                Fun.post(&s, "fun.rejected", labs: ["player"], vars: ["venue": v.short], key: "rej|\(key)", importance: 0.2, count: 1)
            }
            return
        }
        let oral = p.quality + 0.12 * (Fun.roll(s, "oral|\(key)") - 0.5) > 0.8
        s.fun.papers[i].outcome = oral ? .oral : .poster
        Achievements.unlock(&s, "paper_accepted")
        Sim.news(&s, "\(v.short) accepts \"\(p.title)\"\(oral ? " as an oral" : "")",
                 oral ? "One of the few papers presented to the whole conference. Your researcher gets twenty minutes on the main stage." : "A poster slot. Expect a crowd and a lot of photos of your figures.",
                 .research, good: true)
    }

    /// The conference itself: talks, awards and the keynote.
    static func hold(_ s: inout GameState, _ v: VenueDef, _ year: Int) {
        let key = "\(v.id)|\(year)"
        var edition = ConfEdition(venue: v.id, year: year, bestLab: "", bestTitle: "")
        // Rivals' papers: the bigger the lab, the more it gets in.
        let labs = s.competitors.filter { $0.alive && !$0.models.isEmpty }
            .sorted { ($0.models.map(\.index).max() ?? 0) > ($1.models.map(\.index).max() ?? 0) }
        for (rank, c) in labs.prefix(10).enumerated() {
            let n = Int((Double(10 - rank) * 0.8 + 6 * Fun.roll(s, "papers|\(key)|\(c.id)")).rounded())
            if n > 0 { edition.accepted[c.id] = n }
        }
        // Your paper.
        var mine: PaperRecord? = nil
        if let i = s.fun.papers.firstIndex(where: { $0.venue == v.id && $0.year == year && ($0.outcome == .poster || $0.outcome == .oral) }) {
            let p = s.fun.papers[i]
            edition.accepted["player"] = 1
            let rivalBest = 0.74 + 0.2 * Fun.roll(s, "best|\(key)")
            if p.outcome == .oral && p.quality + 0.1 * (Fun.roll(s, "bestme|\(key)") - 0.5) > rivalBest {
                s.fun.papers[i].outcome = .best
            }
            mine = s.fun.papers[i]
        }
        if let p = mine {
            switch p.outcome {
            case .best:
                Fun.brand(&s, 3)
                Fun.lift(&s, morale: 6, researchersOnly: true)
                Fun.lift(&s, morale: 2)
                Stakeholders.move(&s, ["researchers": 3, "public": 0.5], "Best paper at \(v.short) \(year)")
                edition.bestLab = "player"
                edition.bestTitle = p.title
                Sim.news(&s, "Best paper at \(v.short)! \"\(p.title)\"", "The award goes to \(s.companyName). Applications to your research team double overnight. Brand +3.",
                         .research, image: "sf_skyline", important: true, good: true)
                Achievements.unlock(&s, "best_paper")
                Alerts.raise(&s, .milestone, key: "best|\(key)", title: "Best paper at \(v.short) \(year)", body: "\"\(p.title)\" wins the award.",
                             screen: .events, celebrate: true, cooldown: 0)
                Fun.post(&s, "fun.best.you", labs: ["player"], vars: ["venue": v.short, "title": p.title], key: "best|\(key)", importance: 0.7, count: 3)
            case .oral:
                Fun.brand(&s, 1.5)
                Fun.lift(&s, morale: 3, researchersOnly: true)
                Stakeholders.move(&s, ["researchers": 1.5], "An oral at \(v.short) \(year)")
                Fun.post(&s, "fun.oral.you", labs: ["player"], vars: ["venue": v.short, "title": p.title], key: "oral|\(key)", importance: 0.4, count: 1)
            default:
                Fun.brand(&s, 0.5)
                Stakeholders.move(&s, ["researchers": 0.5], "A poster at \(v.short) \(year)")
            }
        }
        // Best paper, if it isn't yours.
        if edition.bestLab.isEmpty, let lab = Cast.weighted(s, "fun|bestlab|\(key)", labs.prefix(8).enumerated().map { ($0.element.id, 1.0 / Double($0.offset + 2)) }) {
            let topic = FunCatalog.rivalTopics[Int(Fun.roll(s, "topic|\(key)") * Double(FunCatalog.rivalTopics.count)) % FunCatalog.rivalTopics.count]
            edition.bestLab = lab
            edition.bestTitle = title(s, topic: topic, key: "rival|\(key)")
            Sim.news(&s, "\(v.short) \(year): best paper to \(Fun.labName(s, lab))", "\"\(edition.bestTitle)\". \(edition.accepted.values.reduce(0, +)) papers from the big labs this year; \(mine == nil ? "none from you" : "one from you").",
                     .competitor)
            if Voices.cooled(&s, "fun.best.lab", days: 100) {
                var vars = Voices.labVars(s, lab)
                vars["venue"] = v.short
                vars["title"] = edition.bestTitle
                Fun.post(&s, "fun.best.lab", labs: [lab], vars: vars, key: "bestlab|\(key)", importance: 0.3, count: 1)
            }
        }
        // The keynote.
        if v.id == "meridian" {
            let plan = s.fun.keynotePlan
            s.fun.keynotePlan = ""
            if plan == "founder|\(year)" {
                s.fun.keynotes += 1
                edition.keynote = "player"
                let glitch = Fun.roll(s, "glitch|\(key)") < 0.25
                Fun.brand(&s, glitch ? 0.5 : 2)
                Stakeholders.move(&s, ["public": glitch ? 0.5 : 1.5, "researchers": 1], "\(s.founderName) gave the Meridian keynote")
                Achievements.unlock(&s, "keynote")
                Sim.news(&s, glitch ? "\(s.founderName)'s Meridian keynote: the demo froze" : "\(s.founderName) closes Meridian with the keynote",
                         glitch ? "Ninety seconds of a spinning wheel in front of twenty thousand people. The talk was good; the clip of the frozen screen is better known."
                                : "A packed hall, a demo that worked first time and a clip that does the rounds for a week. Brand +2.",
                         .company, image: "sf_skyline", important: !glitch, good: !glitch)
                Fun.post(&s, "fun.keynote", labs: ["player"], vars: [:], key: "keynote|\(key)", importance: 0.6, count: 2)
            } else if plan == "scientist|\(year)" {
                edition.keynote = "player"
                Fun.brand(&s, 0.5)
                Stakeholders.move(&s, ["researchers": 2], "Your lead researcher gave the Meridian keynote")
                Sim.news(&s, "Your lead researcher gives the Meridian keynote", "Less glamour, more substance. The research crowd loved it.", .research, good: true)
            }
            if edition.keynote.isEmpty, let lab = labs.first { edition.keynote = lab.id }
        }
        if Voices.cooled(&s, "fun.conf", days: 120) {
            Fun.post(&s, "fun.conf", labs: [], vars: ["venue": v.short], key: "conf|\(key)", importance: 0.2, count: 1)
        }
        s.fun.editions.insert(edition, at: 0)
        if s.fun.editions.count > 30 { s.fun.editions.removeLast(s.fun.editions.count - 30) }
    }

    static func resolveKeynote(_ s: inout GameState, _ d: Decision, option: Int) {
        let year = d.ref.split(separator: "|").last.map(String.init) ?? ""
        switch option {
        case 0: s.fun.keynotePlan = "founder|\(year)"
        case 1: s.fun.keynotePlan = "scientist|\(year)"
        default: Sim.news(&s, "You turn down the Meridian keynote", "Another lab's chief takes the stage.", .company)
        }
    }
}

// MARK: - Challenges

enum Contests {
    static func bar(_ c: ContestDef, _ s: GameState) -> Double { c.bar + c.barStep * Double(s.fun.grandClaims[c.id] ?? 0) }

    static func next(_ c: ContestDef, after date: Date) -> Date {
        let y = date.ym.year
        let d = GameCalendar.date(max(y, c.opens), c.month, c.day)
        return d >= date ? d : GameCalendar.date(max(y + 1, c.opens), c.month, c.day)
    }

    static func upcoming(_ s: GameState, count: Int = 7) -> [(ContestDef, Date)] {
        Array(FunCatalog.contests.map { ($0, next($0, after: s.date)) }.sorted { $0.1 < $1.1 }.prefix(count))
    }

    /// Who would enter today, and their scores before the luck of the day (best first).
    static func field(_ s: GameState, _ c: ContestDef) -> [ContestEntry] {
        var out: [ContestEntry] = []
        let alive = Set(s.competitors.filter { $0.alive && !$0.models.isEmpty }.map(\.id))
        for (lab, v) in s.labDomains where lab == "player" ? !s.releasedModels.isEmpty : alive.contains(lab) {
            guard let model = Fun.bestModelName(s, lab: lab) else { continue }
            out.append(ContestEntry(lab: lab, model: model, score: v[c.domain]))
        }
        return out.sorted { $0.score > $1.score || ($0.score == $1.score && $0.lab < $1.lab) }
    }

    static func daily(_ s: inout GameState, year: Int, month: Int, day: Int) {
        for c in FunCatalog.contests where c.month == month && c.day == day && year >= c.opens { run(&s, c, year) }
    }

    static func run(_ s: inout GameState, _ c: ContestDef, _ year: Int) {
        let key = "\(c.id)|\(year)"
        var entries = field(s, c).map { e -> ContestEntry in
            var e = e
            e.score = (e.score + 6 * (Fun.roll(s, "score|\(key)|\(e.lab)") - 0.5)) * 10
            e.score = e.score.rounded() / 10
            return e
        }
        guard entries.count >= 2 else { return }
        entries.sort { $0.score > $1.score || ($0.score == $1.score && $0.lab < $1.lab) }
        let top = entries[0]
        let theBar = bar(c, s)
        var result = ContestResult(contest: c.id, year: year, standings: Array(entries.prefix(8)), purse: c.purse, bar: theBar)
        result.grand = top.score >= theBar
        if result.grand { s.fun.grandClaims[c.id, default: 0] += 1 }
        let winner = Fun.labName(s, top.lab)
        let mine = entries.firstIndex { $0.lab == "player" }
        s.fun.contests.insert(result, at: 0)
        if s.fun.contests.count > 60 { s.fun.contests.removeLast(s.fun.contests.count - 60) }

        if top.lab == "player" {
            let prize = c.purse + (result.grand ? c.grandPrize : 0)
            Fun.payPrize(&s, prize)
            Fun.brand(&s, result.grand ? 4 : 1.5)
            Stakeholders.move(&s, ["public": result.grand ? 2 : 0.5, "developers": 1], "\(top.model) won \(c.name) \(year)")
            Achievements.unlock(&s, "contest_win")
            let wonThisYear = Set(s.fun.contests.filter { $0.year == year && $0.standings.first?.lab == "player" }.map(\.contest))
            if wonThisYear.count >= 3 { Achievements.unlock(&s, "hat_trick") }
            if result.grand {
                Achievements.unlock(&s, "grand_prize")
                Sim.news(&s, "🏆 \(top.model) claims the \(c.name) grand prize", "\(c.grandGoal): done, with a score of \(Fmt.trim(top.score, 1)) against a bar of \(Fmt.trim(theBar, 1)). \(Fmt.money(prize)) in prize money, and a clip the whole world shares. The organisers are already raising the bar.",
                         .company, image: "supercomputer", important: true, good: true)
                Alerts.raise(&s, .milestone, key: "grand|\(key)", title: "\(c.name): grand prize claimed", body: "\(top.model) did it: \(Cast.lowerFirst(c.grandGoal)).",
                             screen: .events, celebrate: true, cooldown: 0)
            } else {
                Sim.news(&s, "\(top.model) wins \(c.name) \(year)", "First of \(entries.count) labs (\(Fmt.trim(top.score, 1)); the grand prize needs \(Fmt.trim(theBar, 1))). \(Fmt.money(prize)) in prize money. Brand +1.5.",
                         .company, image: "supercomputer", good: true)
            }
            var vars: [String: String] = ["contest": c.name, "model": top.model, "prize": Fmt.money(prize), "labname": s.companyName, "grand": c.grandGoal]
            vars["lab"] = s.companyName
            Fun.post(&s, result.grand ? "fun.grand" : "fun.win.you", labs: ["player"], vars: vars, key: "win|\(key)", importance: result.grand ? 0.8 : 0.5,
                     count: result.grand ? 3 : 2)
            return
        }
        // Somebody else won.
        let placing = mine.map { " You came \(ordinal($0 + 1)) with \(entries[$0].model)." } ?? ""
        if let m = mine, m <= 2 {
            Fun.brand(&s, 0.5)
        }
        if result.grand {
            Sim.news(&s, "\(winner) claims the \(c.name) grand prize", "\(top.model): \(Cast.lowerFirst(c.grandGoal)), \(Fmt.trim(top.score, 1)) against a bar of \(Fmt.trim(theBar, 1)).\(placing)",
                     .competitor, image: "supercomputer", important: true, good: false)
            var vars = Voices.labVars(s, top.lab)
            vars["contest"] = c.name
            vars["model"] = top.model
            vars["labname"] = winner
            vars["grand"] = c.grandGoal
            Fun.post(&s, "fun.grand", labs: [top.lab], vars: vars, key: "grand|\(key)", importance: 0.6, count: 2)
        } else {
            Sim.news(&s, "\(c.name) \(year): \(top.model) wins for \(Fun.labName(s, top.lab, short: true))", "\(entries.count) labs entered.\(placing)", .competitor)
            if Voices.cooled(&s, "fun.win.lab", days: 60) {
                var vars = Voices.labVars(s, top.lab)
                vars["contest"] = c.name
                vars["model"] = top.model
                Fun.post(&s, "fun.win.lab", labs: [top.lab], vars: vars, key: "winlab|\(key)", importance: 0.3, count: 1)
            }
        }
    }

    static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(n)th"
        }
    }
}

// MARK: - Hackathons

enum Hackathons {
    static let days = 7
    /// Days between the starts of two hackathons.
    static let cooldown = 90

    static let demos = [
        "a voice assistant that argues with you about films", "an agent that plans the whole office party", "a bedtime-story cartoon generator",
        "a model that reviews pull requests in pirate speak", "a spreadsheet that explains itself", "a chess coach that trash-talks politely",
        "a recipe bot that works from a photo of your fridge", "a tour guide for any street on the map", "a song generator for birthday cards",
        "a tutor that teaches calculus with football", "an inbox that answers its own email", "a game master for tabletop campaigns",
    ]

    static func running(_ s: GameState) -> Hackathon? { s.fun.hackathons.first.flatMap { $0.done ? nil : $0 } }

    /// Why a hackathon can't start now, or nil.
    static func blocker(_ s: GameState) -> String? {
        if running(s) != nil { return "A hackathon is already running." }
        if s.employees.count < 2 { return "Hire at least two people first." }
        if let last = s.fun.hackathons.first, GameCalendar.daysBetween(last.started, s.date) < cooldown {
            return "The team needs a break: next one from \(GameCalendar.addDays(last.started, cooldown).gameShort)."
        }
        return nil
    }

    /// A week of research, in points.
    static func cost(_ s: GameState) -> Double { s.rpToday * Double(days) }
    static func cashCost(_ s: GameState) -> Double { 1_500 * Double(s.employees.count) }

    static func start(_ s: inout GameState, _ theme: HackTheme) -> String? {
        if let b = blocker(s) { return b }
        let rp = cost(s)
        if let head = s.researchQueue.first { s.researchProgress[head] = max(0, (s.researchProgress[head] ?? 0) - rp) }
        let cash = cashCost(s)
        s.cash -= cash
        s.month.costOther += cash
        s.fun.hackathons.insert(Hackathon(theme: theme, started: s.date, ends: GameCalendar.addDays(s.date, days), people: s.employees.count), at: 0)
        if s.fun.hackathons.count > 20 { s.fun.hackathons.removeLast(s.fun.hackathons.count - 20) }
        Sim.news(&s, "Hackathon week: \(theme.title.lowercased())", "Normal work stops for a week. \(theme.blurb) Pizza budget: \(Fmt.money(cash)).", .company)
        return nil
    }

    static func daily(_ s: inout GameState) {
        guard let h = running(s), h.ends <= s.date else { return }
        finish(&s, h)
    }

    static func finish(_ s: inout GameState, _ h: Hackathon) {
        // Keyed to the start day and theme: reloading and trying again the same day gives the same week.
        let key = "hack|\(RivalIntel.dayIndex(h.started))|\(h.theme.rawValue)"
        let morale = s.employees.isEmpty ? 70 : s.employees.reduce(0) { $0 + $1.morale } / Double(s.employees.count)
        let best = s.employees.map(\.skill).max() ?? 50
        let quality = 0.25 + 0.2 * clamp(log10(Double(max(1, h.people))) / 3, 0, 1) + morale / 500 + 0.12 * best / 100
        let score = quality * 0.7 + 0.6 * Fun.roll(s, key)
        let tier = score < 0.62 ? 0 : (score < 0.9 ? 1 : 2)
        var head = "", detail = ""
        let demo = demos[Int(Fun.roll(s, "\(key)|demo") * Double(demos.count)) % demos.count]
        Fun.lift(&s, morale: tier == 0 ? 2 : 4)
        switch (h.theme, tier) {
        case (.wild, 0):
            head = "Hackathon: lots of ideas, nothing that works yet"
            detail = "Forty notebooks, three whiteboards and one very long thread. Everyone had fun; nothing ships."
        case (.wild, 1):
            let rp = s.rpToday * 6
            if let q = s.researchQueue.first { s.researchProgress[q, default: 0] += rp }
            head = "Hackathon: a promising shortcut"
            detail = "One team found a trick that saves real time on your current research project (about six days of work)."
        case (.wild, _):
            let rp = s.rpToday * 20
            if let q = s.researchQueue.first { s.researchProgress[q, default: 0] += rp }
            s.eurekas += 1
            head = "Hackathon eureka: an idea that changes the plan"
            detail = "Two engineers and an intern cracked something the research team had been stuck on for months: about twenty days of research in a week."
        case (.demo, 0):
            head = "Hackathon: the demos didn't land"
            detail = "Fun to build, awkward to watch. Nobody posts anything."
        case (.demo, 1):
            Fun.brand(&s, 1)
            Stakeholders.move(&s, ["public": 0.5, "developers": 0.5], "A hackathon demo went round the internet")
            head = "Hackathon demo gets noticed: \(demo)"
            detail = "A few hundred thousand views and a lot of \"how did they do that\". Brand +1."
        case (.demo, _):
            Fun.brand(&s, 4)
            Stakeholders.move(&s, ["public": 2, "developers": 1.5], "A hackathon demo went viral")
            head = "Viral: \(demo)"
            detail = "Built in five days, watched by millions. Your sign-ups spike and journalists want the story. Brand +4."
            Fun.post(&s, "fun.hack", labs: ["player"], vars: ["demo": demo], key: key, importance: 0.5, count: 2)
        case (.prototype, 0):
            head = "Hackathon: prototypes, no buyers"
            detail = "The prototypes work on the happy path. Customers liked the slides more."
        case (.prototype, let t):
            let base = max(40_000, (s.history.last.map { $0.revAPI + $0.revConsumer + $0.revEnterprise + $0.revAgents } ?? 0) * 0.01)
            let monthly = (min(5e6, base * (t >= 2 ? 2 : 1)) / 1000).rounded() * 1000
            let months = t >= 2 ? 12 : 6
            let client = ["regional bank", "logistics firm", "hospital network", "games studio", "law firm", "city council"][Int(Fun.roll(s, "\(key)|client") * 6) % 6]
            s.deals.append(EnterpriseDeal(client: "Pilot: \(client.prefix(1).uppercased() + client.dropFirst())", title: "hackathon prototype", monthly: monthly, tokensPerDay: 0, months: months, monthsLeft: months,
                                          minIndex: 0, minSafety: 0, expires: s.date, active: true))
            Stakeholders.move(&s, ["developers": t >= 2 ? 1.5 : 0.5], "A hackathon prototype became a paid pilot")
            head = t >= 2 ? "Hackathon prototype sells: a \(client) signs for a year" : "Hackathon prototype becomes a pilot"
            detail = "\(Cast.article(client).capitalized) \(client) pays \(Fmt.money(monthly)) a month for \(months) months to try it."
        }
        if tier == 2 {
            Achievements.unlock(&s, "hack_hit")
            Alerts.raise(&s, .milestone, key: key, title: head, body: detail, screen: .events, celebrate: true, cooldown: 0)
        }
        if let i = s.fun.hackathons.firstIndex(where: { $0.id == h.id }) {
            s.fun.hackathons[i].done = true
            s.fun.hackathons[i].tier = tier
            s.fun.hackathons[i].headline = head
            s.fun.hackathons[i].detail = detail
        }
        Sim.news(&s, head, detail, .company, image: tier == 2 ? "garage" : nil, important: tier == 2, good: tier > 0)
    }
}

// MARK: - Player actions

extension GameState {
    mutating func startHackathon(_ theme: HackTheme) -> String? { Hackathons.start(&self, theme) }
}
