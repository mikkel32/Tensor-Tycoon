import Foundation

/// 3.9: grand challenges — prize competitions with real stakes, on top of the yearly public challenges (Contests).
/// Each edition is announced with a task, a purse, entry rules and a deadline. You enter (standard or all-in, for a
/// cash budget) or pass; rival labs that care about the field enter too, along with strong outside teams. Halfway, a
/// public leaderboard shows where you stand (and pays any milestone awards); you can push harder. On results day the
/// standings come from each team's real capability on the task's domain mix, the know-how behind it (research, science
/// discoveries, the right lab), effort and a little luck. Clearing the bar claims a one-off grand prize.
/// Luck is a hashed roll keyed to the game's salt and the edition (like Science and Fun): the same seed gives the
/// same results, and a challenge never shifts the random numbers every other system draws.
enum GrandChallenges {
    static let entryKind = "challenge_entry"
    static let pushKind = "challenge_push"
    /// An edition announced up to this many days before today still opens (a save loaded mid-window).
    static let lateDays = 20
    static let entryDays = 28
    static let allInBonus = 4.0
    static let pushBonus = 2.5
    static let luck = 3.0

    // MARK: Schedule

    static func month(_ d: ChallengeDef) -> Int { Int(((d.first - floor(d.first)) * 12).rounded(.down)) + 1 }

    static func announceDate(_ d: ChallengeDef, year: Int) -> Date { GameCalendar.date(year, month(d), 1) }

    /// Years in which an edition is announced.
    static func editionYears(_ d: ChallengeDef) -> [Int] {
        let y0 = Int(d.first)
        guard d.cadence > 0 else { return [y0] }
        return Array(stride(from: y0, through: d.last, by: d.cadence))
    }

    /// The bar a new edition asks for: the challenge's own until it's cleared; after that, recurring challenges move to
    /// harder targets (protein complexes, longer forecasts) and the bar sits just above where the field stands.
    static func currentBar(_ d: ChallengeDef, _ s: GameState, results: Date? = nil) -> Double {
        // Challenges without a grand prize set each season's targets against the field from the start.
        guard d.grandPrize == 0 || (!d.endsOnGrand && s.challenges.claimed[d.id] != nil) else { return d.bar }
        // Where the field will be by results day (`field` projects most of the frontier's progress; this adds the rest).
        let ahead = results.map { 2 * max(0, Macro.frontier($0.decimalYear) - Macro.frontier(s.year)) } ?? 0
        return max(d.bar, ((field(d, s, at: results).first?.score ?? d.bar) + ahead + 6).rounded())
    }

    static func barFor(_ e: ChallengeEdition) -> Double { e.bar > 0 ? e.bar : (e.def?.bar ?? 0) }

    static func retired(_ d: ChallengeDef, _ s: GameState) -> Bool { d.endsOnGrand && s.challenges.claimed[d.id] != nil }

    /// The next announcement on or after `date` (nil when the challenge has run its course).
    static func nextAnnouncement(_ d: ChallengeDef, after date: Date, _ s: GameState) -> Date? {
        guard !retired(d, s) else { return nil }
        return editionYears(d).map { announceDate(d, year: $0) }.first { $0 >= date }
    }

    static func editionID(_ d: ChallengeDef, year: Int) -> String { "\(d.id)|\(year)" }

    static func label(_ e: ChallengeEdition) -> String { "\(e.def?.short ?? e.challenge) \(e.results.ym.year)" }

    // MARK: Scores

    /// Points your research adds.
    static func knowhow(_ d: ChallengeDef, _ s: GameState) -> Double {
        d.knowhow.reduce(0) { $0 + (s.researched.contains($1.0) ? $1.1 : 0) }
    }

    /// Points a rival's know-how adds: it picks up each technique a quarter after its real date (at once when it
    /// specialises in the field).
    static func rivalKnowhow(_ d: ChallengeDef, _ s: GameState, specialist: Bool, at year: Double? = nil) -> Double {
        let y = year ?? s.year
        return d.knowhow.reduce(0) { sum, k in
            guard let item = ResearchCatalog.byID[k.0] else { return sum }
            return y >= item.year + (specialist ? 0 : 0.25) ? sum + k.1 : sum
        }
    }

    /// Points your science adds: discoveries in the challenge's fields (2 each, up to 6) and a lab of the right kind (3).
    static func science(_ d: ChallengeDef, _ s: GameState) -> Double {
        guard !d.fields.isEmpty || !d.labs.isEmpty else { return 0 }
        let found = s.science.discoveries.filter { disc in ScienceCatalog.projectByID[disc.def].map { d.fields.contains($0.field) } ?? false }.count
        let lab = s.science.labs.contains { d.labs.contains($0.kind) && $0.isReady(s.date) }
        return min(6, 2 * Double(found)) + (lab ? 3 : 0)
    }

    /// Your best model for the task: (name, raw mix score). `openOnly` counts released open weights only.
    static func bestModel(_ d: ChallengeDef, _ s: GameState, openOnly: Bool) -> (name: String, score: Double)? {
        var best: (String, Double)? = nil
        for m in s.models where !m.retired && (!openOnly || (m.released && m.openWeights)) {
            guard let v = s.domainScores[m.id.uuidString] else { continue }
            let x = v.mix(d.mix)
            if best == nil || x > best!.1 { best = (m.name, x) }
        }
        return best
    }

    /// The model you'd field and whether it's on the prize track: where prize money needs open weights, your best open
    /// model goes in for the money unless a closed one is more than 4 points better (then it's an exhibition).
    static func entryModel(_ d: ChallengeDef, _ s: GameState) -> (name: String, score: Double, exhibition: Bool)? {
        guard let any = bestModel(d, s, openOnly: false) else { return nil }
        guard d.openTrack else { return (any.name, any.score, false) }
        if let open = bestModel(d, s, openOnly: true), open.score >= any.score - 4 { return (open.name, open.score, false) }
        return (any.name, any.score, true)
    }

    /// Your expected score before luck, with this effort.
    static func expected(_ d: ChallengeDef, _ s: GameState, effort: ChallengeEffort, pushed: Bool = false) -> Double? {
        guard let m = entryModel(d, s) else { return nil }
        return m.score + knowhow(d, s) + science(d, s) + (effort == .allIn ? allInBonus : 0) + (pushed ? pushBonus : 0)
    }

    /// Rival labs and outside teams that would enter, with their expected scores (best first). Rival labs enter when
    /// they specialise in the field or rank in the top four on the task; outside teams start `outsideGap` behind the
    /// best lab but know the field (full know-how from its real dates). `at`: know-how as it will stand on that day
    /// (results day), so odds anticipate a technique the field will have by then.
    static func field(_ d: ChallengeDef, _ s: GameState, at date: Date? = nil) -> [ChallengeStanding] {
        let y = max(s.year, date?.decimalYear ?? s.year)
        // Rivals keep shipping until then: most of the frontier's progress, on the score scale.
        let growth = 8 * max(0, Macro.frontier(y) - Macro.frontier(s.year))
        var labs: [ChallengeStanding] = []
        let alive = s.competitors.filter { $0.alive && !$0.models.isEmpty }
        for c in alive {
            guard let v = s.labDomains[c.id], let model = Fun.bestModelName(s, lab: c.id) else { continue }
            let specialist = d.focus != nil && Nations.focus(s, c.id) == d.focus
            var x = v.mix(d.mix) + rivalKnowhow(d, s, specialist: specialist, at: y) + (specialist ? 4 : 0) + growth
            x += clamp(2 * log10(max(0.1, c.funding)), -2, 2)
            labs.append(ChallengeStanding(lab: c.id, team: Cast.short(c.id), model: model, score: x))
        }
        labs.sort { $0.score > $1.score || ($0.score == $1.score && $0.lab < $1.lab) }
        var out = labs.enumerated().filter { i, e in i < 4 || (d.focus != nil && Nations.focus(s, e.lab) == d.focus) }.map(\.element)
        let top = labs.first?.score ?? 60
        let know = rivalKnowhow(d, s, specialist: true, at: y)
        for (i, name) in d.outside.enumerated() {
            let base = top - rivalKnowhow(d, s, specialist: false, at: y) - d.outsideGap - 2 * Double(i)
            out.append(ChallengeStanding(lab: "outside:\(name)", team: name, model: "", score: base + know))
        }
        return out.sorted { $0.score > $1.score || ($0.score == $1.score && $0.lab < $1.lab) }
    }

    /// Why you can't enter right now (empty when you can).
    static func blockers(_ d: ChallengeDef, _ s: GameState) -> [String] {
        var out: [String] = []
        guard let m = entryModel(d, s) else { return ["You need a trained model to enter."] }
        if m.score < d.minScore { out.append("Organisers want a model scoring at least \(Int(d.minScore)) on the task (your best: \(Int(m.score))).") }
        if let r = d.requires, !s.researched.contains(r) { out.append("Needs \(ResearchCatalog.byID[r]?.name ?? r) research.") }
        if d.minSafety > 0 && s.safetyScore < d.minSafety { out.append("Trial partners want a safety score of \(Int(d.minSafety)) (yours: \(Int(s.safetyScore))).") }
        return out
    }

    static func cost(_ d: ChallengeDef, _ effort: ChallengeEffort) -> Double {
        switch effort {
        case .none: 0
        case .standard: d.entryCost
        case .allIn: d.entryCost * 3
        }
    }

    static func pushCost(_ d: ChallengeDef) -> Double { d.entryCost * 0.5 }

    /// Your odds of each outcome with this effort, from 400 simulated results (a local RNG keyed to the edition, so
    /// the panel shows the same number every time and the game's random numbers are untouched).
    static func odds(_ d: ChallengeDef, _ s: GameState, effort: ChallengeEffort, pushed: Bool = false, key: String, at date: Date? = nil) -> (win: Double, podium: Double, grand: Double)? {
        guard let me = expected(d, s, effort: effort, pushed: pushed) else { return nil }
        let others = field(d, s, at: date ?? s.challenges.editions.first { $0.id == key }?.results)
        var rng = GameRNG(seed: UInt64(truncatingIfNeeded: stableHash(key)) | 1)
        var win = 0, podium = 0, grand = 0
        let n = 400
        let exhibition = entryModel(d, s)?.exhibition ?? false
        for _ in 0..<n {
            let mine = me + luck * rng.gaussian()
            var better = 0
            for o in others where o.score + sigma(o) * rng.gaussian() > mine { better += 1 }
            if better == 0 { win += 1 }
            if better < 3 { podium += 1 }
            if better == 0 && mine >= d.bar && d.grandPrize > 0 && s.challenges.claimed[d.id] == nil && !exhibition { grand += 1 }
        }
        return (Double(win) / Double(n), Double(podium) / Double(n), Double(grand) / Double(n))
    }

    static func sigma(_ e: ChallengeStanding) -> Double { e.lab.hasPrefix("outside:") ? 5 : luck }

    /// A stable string hash (Swift's `hashValue` changes between launches).
    static func stableHash(_ s: String) -> Int {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Int(truncatingIfNeeded: h >> 1)
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        if !s.challenges.started { start(&s) }
        for d in ChallengeCatalog.all { announceIfDue(&s, d) }
        for i in s.challenges.editions.indices where s.challenges.editions[i].status != .done {
            let e = s.challenges.editions[i]
            if e.status == .open && s.date >= e.entryCloses { closeEntries(&s, i) }
            if !s.challenges.editions[i].checkpointDone && s.date >= e.checkpoint { checkpoint(&s, i) }
            if s.date >= e.results { decide(&s, i) }
        }
    }

    /// First tick of a game (or of an older save): grand prizes claimed in our timeline before today stay claimed.
    static func start(_ s: inout GameState) {
        s.challenges.started = true
        for d in ChallengeCatalog.all where !d.historic.isEmpty && s.year > d.historicYear && s.challenges.claimed[d.id] == nil {
            s.challenges.claimed[d.id] = d.historic
        }
    }

    static func announceIfDue(_ s: inout GameState, _ d: ChallengeDef) {
        guard !retired(d, s) else { return }
        for y in editionYears(d) {
            let when = announceDate(d, year: y)
            guard when <= s.date, GameCalendar.daysBetween(when, s.date) <= lateDays else { continue }
            let id = editionID(d, year: y)
            guard !s.challenges.editions.contains(where: { $0.id == id }) else { continue }
            announce(&s, d, year: y, on: when)
        }
    }

    static func announce(_ s: inout GameState, _ d: ChallengeDef, year: Int, on when: Date) {
        let results = GameCalendar.addMonths(when, d.months)
        let checkpointDays = Int(Double(GameCalendar.daysBetween(when, results)) * d.checkpointShare)
        var e = ChallengeEdition(id: editionID(d, year: year), challenge: d.id, year: year, announced: when,
                                 entryCloses: GameCalendar.addDays(s.date, entryDays), checkpoint: GameCalendar.addDays(when, checkpointDays), results: results)
        e.bar = currentBar(d, s, results: results)
        let blocked = blockers(d, s)
        if !blocked.isEmpty { e.status = .watching }
        s.challenges.editions.append(e)
        let name = "\(d.short) \(results.ym.year)"
        let stakes = stakesLine(d, s)
        guard blocked.isEmpty, let m = entryModel(d, s) else {
            Sim.news(&s, "\(name) announced", "\(d.task) \(stakes) You can't enter this one: \(blocked.first ?? "no model yet.")", .research, image: d.photo)
            return
        }
        let std = odds(d, s, effort: .standard, key: e.id)
        let all = odds(d, s, effort: .allIn, key: e.id)
        func line(_ o: (win: Double, podium: Double, grand: Double)?) -> String {
            guard let o else { return "" }
            return "about \(Fmt.odds(o.win)) to win, \(Fmt.odds(o.podium)) to podium"
        }
        let track = m.exhibition ? " Your best open-weights model is well behind \(m.name), so it would go in as an exhibition: prestige, no prize money. Open the weights of a strong model before results day to compete for the money." : ""
        let projected = d.metricText(expected(d, s, effort: .standard) ?? 0, bar: e.bar)
        Events.addDecision(&s, kind: entryKind, title: "Grand challenge: \(name)",
                           body: "\(d.organiser.prefix(1).uppercased() + d.organiser.dropFirst()) invites entries. \(d.task) \(stakes) Results \(results.gameShort). With \(m.name) you'd score about \(projected).\(track)",
                           image: d.photo,
                           options: [DecisionOption(label: "Enter", detail: "\(Fmt.money(cost(d, .standard))) budget · \(line(std))."),
                                     DecisionOption(label: "Go all-in", detail: "\(Fmt.money(cost(d, .allIn))) budget, your best people on it (+\(Int(allInBonus)) points) · \(line(all))."),
                                     DecisionOption(label: "Pass", detail: "Watch from the sidelines; the field competes anyway.")],
                           amount: cost(d, .standard), ref: e.id)
    }

    /// Purse, grand prize and milestone awards in a sentence.
    static func stakesLine(_ d: ChallengeDef, _ s: GameState) -> String {
        var parts: [String] = []
        if let p = d.purse.first, p > 0 { parts.append("Prizes \(d.purse.filter { $0 > 0 }.map { Fmt.money($0) }.joined(separator: " / "))") }
        if d.grandPrize > 0 {
            parts.append(s.challenges.claimed[d.id] == nil ? "\(Fmt.money(d.grandPrize)) grand prize for: \(Cast.lowerFirst(d.grandGoal))"
                         : (d.endsOnGrand ? "grand prize already claimed" : "grand prize already claimed, so the organisers have moved to harder targets"))
        }
        if d.milestonePrize > 0 { parts.append("\(Fmt.money(d.milestonePrize)) milestone awards to the top \(d.milestoneTop) at the halfway mark") }
        if d.openTrack { parts.append("prize money only for open-weights entries") }
        if d.publishes { parts.append("finalists must open-source their systems") }
        return parts.isEmpty ? "" : parts.joined(separator: "; ") + "."
    }

    // MARK: Entering

    /// Enter an open edition (from the inbox or the Challenges page). Too little cash keeps it open.
    static func enter(_ s: inout GameState, _ id: String, effort: ChallengeEffort) -> String? {
        guard let i = s.challenges.editions.firstIndex(where: { $0.id == id }), let d = s.challenges.editions[i].def else { return "Not found." }
        guard s.challenges.editions[i].status == .open else { return "Entries for \(label(s.challenges.editions[i])) are closed." }
        if let why = blockers(d, s).first { return why }
        let price = cost(d, effort)
        guard s.cash >= price else { return "An entry needs \(Fmt.money(price)); you have \(Fmt.money(max(0, s.cash)))." }
        s.cash -= price
        s.month.costOther += price
        let m = entryModel(d, s)
        s.challenges.editions[i].status = .entered
        s.challenges.editions[i].effort = effort
        s.challenges.editions[i].spent = price
        s.challenges.editions[i].model = m?.name ?? ""
        s.challenges.editions[i].exhibition = m?.exhibition ?? false
        s.decisions.removeAll { $0.kind == entryKind && $0.ref == id }
        Sim.news(&s, "\(s.companyName) enters \(label(s.challenges.editions[i]))",
                 "\(effort == .allIn ? "All in: your best people" : "A team") and \(Fmt.money(price)) behind \(m?.name ?? "your model")\(m?.exhibition == true ? " (an exhibition entry: no prize money without open weights)" : ""). Public leaderboard \(s.challenges.editions[i].checkpoint.gameShort), results \(s.challenges.editions[i].results.gameShort).",
                 .research, image: d.photo, good: true)
        return nil
    }

    static func pass(_ s: inout GameState, _ id: String) {
        guard let i = s.challenges.editions.firstIndex(where: { $0.id == id }), s.challenges.editions[i].status == .open else { return }
        s.challenges.editions[i].status = .watching
        s.decisions.removeAll { $0.kind == entryKind && $0.ref == id }
    }

    /// Spend half an entry budget again for a late push (once per edition, after the public leaderboard).
    static func push(_ s: inout GameState, _ id: String) -> String? {
        guard let i = s.challenges.editions.firstIndex(where: { $0.id == id }), let d = s.challenges.editions[i].def else { return "Not found." }
        let e = s.challenges.editions[i]
        guard e.status == .entered, e.checkpointDone, !e.pushed else { return "Nothing to push." }
        let price = pushCost(d)
        guard s.cash >= price else { return "A push needs \(Fmt.money(price)); you have \(Fmt.money(max(0, s.cash)))." }
        s.cash -= price
        s.month.costOther += price
        s.challenges.editions[i].pushed = true
        s.challenges.editions[i].spent += price
        s.decisions.removeAll { $0.kind == pushKind && $0.ref == id }
        Sim.news(&s, "Late push on \(label(e))", "Another \(Fmt.money(price)) for more compute and a fresh set of eyes (+\(Fmt.trim(pushBonus, 1)) points).", .research)
        return nil
    }

    static func closeEntries(_ s: inout GameState, _ i: Int) {
        guard s.challenges.editions[i].status == .open else { return }
        s.challenges.editions[i].status = .watching
        let id = s.challenges.editions[i].id
        s.decisions.removeAll { $0.kind == entryKind && $0.ref == id }
    }

    // MARK: Checkpoint and results

    /// A hashed normal(0, 1) for one team on one day of one edition.
    static func gaussian(_ s: GameState, _ key: String) -> Double {
        let u1 = max(RivalIntel.unit("gc|\(s.peopleSalt)|\(key)|a"), 1e-12), u2 = RivalIntel.unit("gc|\(s.peopleSalt)|\(key)|b")
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    /// Today's standings with luck (`spread` scales it: 0.6 at the checkpoint, where the final result isn't known yet).
    static func roll(_ s: inout GameState, _ d: ChallengeDef, _ e: ChallengeEdition, spread: Double) -> [ChallengeStanding] {
        var out = field(d, s)
        let phase = spread < 1 ? "cp" : "final"
        for j in out.indices { out[j].score += sigma(out[j]) * spread * gaussian(s, "\(e.id)|\(phase)|\(out[j].lab)") }
        if e.status == .entered, let me = expected(d, s, effort: e.effort, pushed: e.pushed) {
            let m = entryModel(d, s)
            out.append(ChallengeStanding(lab: "player", team: s.companyName, model: m?.name ?? e.model, score: me + luck * spread * gaussian(s, "\(e.id)|\(phase)|player")))
        }
        for j in out.indices { out[j].score = (out[j].score * 10).rounded() / 10 }
        return out.sorted { $0.score > $1.score || ($0.score == $1.score && $0.lab < $1.lab) }
    }

    static func checkpoint(_ s: inout GameState, _ i: Int) {
        s.challenges.editions[i].checkpointDone = true
        let e = s.challenges.editions[i]
        guard let d = e.def else { return }
        let eb = barFor(e)
        let board = roll(&s, d, e, spread: 0.6)
        let place = (board.firstIndex { $0.lab == "player" } ?? -1) + 1
        s.challenges.editions[i].checkpointPlace = place
        let leader = board.first
        // Milestone awards: the top teams at the halfway mark.
        var award = ""
        if d.milestonePrize > 0 {
            let top = board.prefix(d.milestoneTop)
            if top.contains(where: { $0.lab == "player" }) {
                pay(&s, d.milestonePrize, i)
                award = " You're among the \(d.milestoneTop) teams taking a \(Fmt.money(d.milestonePrize)) milestone award."
            } else if e.status == .entered {
                award = " You missed the \(d.milestoneTop) milestone awards."
            }
            if d.publishes, top.contains(where: { $0.lab == "player" }) { award += " As a finalist, your system will be open-sourced after the final." }
        }
        guard e.status == .entered else {
            if let leader, !leader.lab.hasPrefix("outside:") || d.milestonePrize > 0 {
                Sim.news(&s, "\(label(e)) halfway: \(leader.team) leads", "Public leaderboard: \(top3(d, board, bar: eb)).", .competitor)
            }
            return
        }
        let mine = board.first { $0.lab == "player" }
        let gap = (leader?.score ?? 0) - (mine?.score ?? 0)
        var body = "You're \(Contests.ordinal(place)) of \(board.count) at \(mine.map { d.metricText($0.score, bar: eb) } ?? "?"). \(top3(d, board, bar: eb)).\(award)"
        if place > 1 { body += " \(leader?.team ?? "The leader") is \(Fmt.trim(gap, 1)) points ahead." }
        Sim.news(&s, "\(label(e)) public leaderboard: you're \(Contests.ordinal(place))", body, .research, image: d.photo, good: place <= 3)
        // Behind, and not already giving it everything: offer a late push.
        if place > 1 && !e.pushed {
            Events.addDecision(&s, kind: pushKind, title: "\(label(e)): push harder?",
                               body: body + " Results \(e.results.gameShort).",
                               image: d.photo,
                               options: [DecisionOption(label: "Push harder", detail: "\(Fmt.money(pushCost(d))) more for compute and people (+\(Fmt.trim(pushBonus, 1)) points)."),
                                         DecisionOption(label: "Hold course", detail: "Keep the budget; let the entry stand.")],
                               amount: pushCost(d), ref: e.id)
        }
    }

    static func top3(_ d: ChallengeDef, _ board: [ChallengeStanding], bar eb: Double) -> String {
        board.prefix(3).map { "\($0.team) \(d.metricText($0.score, bar: eb))" }.joined(separator: ", ")
    }

    static func pay(_ s: inout GameState, _ amount: Double, _ i: Int) {
        guard amount > 0 else { return }
        s.cash += amount
        s.month.oneOffIncome += amount
        s.challenges.prizeMoney += amount
        s.challenges.editions[i].prize += amount
    }

    static func isOpen(_ lab: String, _ s: GameState) -> Bool {
        if lab == "player" { return false }
        if lab.hasPrefix("outside:") { return true }
        return CompetitorCatalog.def(lab).openWeights
    }

    static func decide(_ s: inout GameState, _ i: Int) {
        let e = s.challenges.editions[i]
        guard let d = e.def else { s.challenges.editions[i].status = .done; return }
        let eb = barFor(e)
        s.decisions.removeAll { ($0.kind == pushKind || $0.kind == entryKind) && $0.ref == e.id }
        if e.status == .open { s.challenges.editions[i].status = .watching }
        let entered = e.status == .entered
        let board = roll(&s, d, e, spread: 1)
        s.challenges.editions[i].standings = Array(board.prefix(10))
        s.challenges.editions[i].status = .done
        guard let top = board.first else { return }
        // Who can take money: everyone, or only open-weights entries (your exhibition entry can't).
        let playerOpen = !(entryModel(d, s)?.exhibition ?? true)
        let eligible = board.filter { !d.openTrack || ($0.lab == "player" ? playerOpen : isOpen($0.lab, s)) }
        let place = (board.firstIndex { $0.lab == "player" } ?? -1) + 1
        s.challenges.editions[i].place = place
        if entered, let k = eligible.firstIndex(where: { $0.lab == "player" }), k < d.purse.count { pay(&s, d.purse[k], i) }
        // The grand prize: the best eligible entry, if it clears the bar and nobody has claimed it.
        var grandBy = ""
        if d.grandPrize > 0, s.challenges.claimed[d.id] == nil, let g = eligible.first, g.score >= d.bar {
            grandBy = g.lab
            s.challenges.claimed[d.id] = g.lab
            s.challenges.editions[i].grandBy = g.lab
            if g.lab == "player" { pay(&s, d.grandPrize, i); s.challenges.grandPrizes += 1 }
        }
        if entered && d.publishes && place > 0 && place <= max(3, d.milestoneTop) {
            OpenSource.addRepo(&s, id: "crs:\(e.id)", kind: .challenge, name: "\(s.companyName) \(d.short) system", quality: clamp(0.6 + 0.04 * ((board.first { $0.lab == "player" }?.score ?? 0) - d.bar + 10), 0.4, 1.3))
        }
        let name = label(e)
        let mineScore = board.first { $0.lab == "player" }?.score
        let result = top3(d, board, bar: eb)
        if entered {
            if place == 1 { s.challenges.wins += 1 }
            if place >= 1 && place <= 3 { s.challenges.podiums += 1 }
            prestige(&s, d, place: place, grand: grandBy == "player", exhibition: e.exhibition, name: name)
            let money = s.challenges.editions[i].prize
            if grandBy == "player" {
                Sim.news(&s, "🏆 \(name): grand prize claimed", "\(d.grandGoal): done, at \(d.metricText(mineScore ?? 0, bar: eb)). \(Fmt.money(money)) in prize money and the clip every science desk runs tonight. \(result).",
                         .research, image: d.photo, important: true, good: true)
                Alerts.raise(&s, .milestone, key: "grand|\(e.id)", title: "\(d.short): grand prize claimed", body: "\(e.model.isEmpty ? "Your entry" : e.model) did it: \(Cast.lowerFirst(d.grandGoal)).",
                             screen: .challenges, celebrate: true, cooldown: 0)
                Fun.post(&s, "fun.grand", labs: ["player"], vars: ["contest": d.short, "model": e.model, "prize": Fmt.money(money), "labname": s.companyName, "grand": d.grandGoal, "lab": s.companyName],
                         key: "gc|\(e.id)", importance: 0.8, count: 3)
            } else if place == 1 {
                Sim.news(&s, "\(s.companyName) wins \(name)", "First of \(board.count) at \(d.metricText(mineScore ?? 0, bar: eb))\(e.exhibition ? " (an exhibition entry: the money goes to the best open entry)" : "").\(money > 0 ? " \(Fmt.money(money)) in prize money." : "") \(result).",
                         .research, image: d.photo, important: true, good: true)
                Alerts.raise(&s, .milestone, key: "win|\(e.id)", title: "You won \(name)", body: "\(d.metricText(mineScore ?? 0, bar: eb)): first of \(board.count) teams.", screen: .challenges, celebrate: true, cooldown: 0)
                Fun.post(&s, "fun.win.you", labs: ["player"], vars: ["contest": d.short, "model": e.model, "prize": Fmt.money(money), "labname": s.companyName, "grand": d.grandGoal, "lab": s.companyName],
                         key: "gcw|\(e.id)", importance: 0.5, count: 2)
            } else {
                let winner = top.team
                Sim.news(&s, "\(name): you finish \(Contests.ordinal(place))", "\(winner) wins at \(d.metricText(top.score, bar: eb)); you scored \(d.metricText(mineScore ?? 0, bar: eb)).\(money > 0 ? " \(Fmt.money(money)) in prize money." : "")\(grandBy.isEmpty || grandBy == "player" ? "" : " \(teamName(grandBy, s)) claimed the grand prize.") \(result).",
                         .research, image: d.photo, important: place <= 3, good: place <= 3)
            }
        } else if !grandBy.isEmpty {
            Sim.news(&s, "\(teamName(grandBy, s)) claims the \(d.short) grand prize", "\(d.grandGoal), at \(d.metricText(board.first { $0.lab == grandBy }?.score ?? 0, bar: eb)). \(result).",
                     .competitor, image: d.photo, important: true, good: false)
        } else if !top.lab.hasPrefix("outside:") || d.purse.first ?? 0 >= 10_000_000 {
            Sim.news(&s, "\(name): \(top.team) wins", "\(d.metricText(top.score, bar: eb)) on the task. \(result).", .competitor)
        }
        // A closed model over the bar where the money needs open weights: the internet notices.
        if d.openTrack, let closed = board.first(where: { $0.score >= d.bar && !($0.lab == "player" ? playerOpen : isOpen($0.lab, s)) }), grandBy != closed.lab,
           !s.challenges.editions[i].standings.isEmpty {
            Sim.news(&s, "\(closed.team) scores gold, but keeps its weights", "\(closed.model.isEmpty ? "Its model" : closed.model) cleared the \(d.short) bar at \(d.metricText(closed.score, bar: eb)); the grand prize only goes to open weights\(s.challenges.claimed[d.id] == nil ? ", so it stays unclaimed" : "").",
                     .research)
        }
    }

    static func teamName(_ lab: String, _ s: GameState) -> String {
        if lab == "player" { return s.companyName }
        if lab.hasPrefix("outside:") { return String(lab.dropFirst(8)) }
        return Cast.short(lab)
    }

    /// Brand, standing, political capital and science momentum for a podium (a win in full, 2nd/3rd a third, the grand
    /// prize half again; an exhibition win counts as a win).
    static func prestige(_ s: inout GameState, _ d: ChallengeDef, place: Int, grand: Bool, exhibition: Bool, name: String) {
        guard place >= 1 && place <= 3 else { return }
        let f = (place == 1 ? 1 : 0.35) * (grand ? 1.5 : 1)
        s.brand = clamp(s.brand + d.brand * f, 0, 100)
        s.politicalCapital = min(100, s.politicalCapital + d.political * f)
        var moves: [String: Double] = ["researchers": d.researchers * f, "public": d.publicTrust * f, "developers": 0.5 * f]
        for (k, v) in d.regions { moves[k, default: 0] += v * f }
        Stakeholders.move(&s, moves, place == 1 ? "Won \(name)\(grand ? " and its grand prize" : "")" : "Finished \(Contests.ordinal(place)) in \(name)")
        if let field = d.fields.first { Science.bumpMomentum(&s, field, grand ? 0.08 : 0.04 * f) }
        for i in s.employees.indices where s.employees[i].role == .researcher { s.employees[i].morale = min(100, s.employees[i].morale + 3 * f) }
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, _ dec: Decision, option: Int) {
        switch dec.kind {
        case entryKind:
            guard option < 2 else { pass(&s, dec.ref); return }
            if let why = enter(&s, dec.ref, effort: option == 1 ? .allIn : .standard) {
                // Can't afford it: entries stay open on the Challenges page until they close.
                let until = s.challenges.editions.first { $0.id == dec.ref && $0.status == .open }.map { " You can still enter on the Challenges page until \($0.entryCloses.gameShort)." } ?? ""
                Sim.news(&s, "Couldn't enter: \(dec.title.replacingOccurrences(of: "Grand challenge: ", with: ""))", why + until, .company, good: false)
            }
        case pushKind:
            guard option == 0 else { return }
            if let why = push(&s, dec.ref) { Sim.news(&s, "No late push", why, .company, good: false) }
        default: break
        }
    }

    // MARK: Summary

    /// Editions still running (open or entered or watched, not decided), soonest result first.
    static func live(_ s: GameState) -> [ChallengeEdition] {
        s.challenges.editions.filter { $0.status != .done }.sorted { $0.results < $1.results }
    }

    /// The next announcements across all challenges.
    static func upcoming(_ s: GameState, count: Int = 6) -> [(ChallengeDef, Date)] {
        let known = Set(s.challenges.editions.map(\.id))
        var out: [(ChallengeDef, Date)] = []
        for d in ChallengeCatalog.all where !retired(d, s) {
            for y in editionYears(d) {
                let when = announceDate(d, year: y)
                if when > s.date && !known.contains(editionID(d, year: y)) { out.append((d, when)); break }
            }
        }
        return Array(out.sorted { $0.1 < $1.1 }.prefix(count))
    }
}
