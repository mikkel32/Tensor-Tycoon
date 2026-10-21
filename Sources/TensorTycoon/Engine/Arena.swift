import Foundation

/// 3.9: the live model arena, in the style of LMArena (Chatbot Arena until 2025). Crowds compare two anonymous answers and
/// vote; every day a batch of battles runs between released models (yours and the rivals') in five categories. Each model
/// has a hidden strength per category from its real capability profile (domain scores, chat style, the static Elo the
/// leaderboard always showed), battles are noisy samples of it, and Elo-style updates chase it. Ratings are re-anchored
/// weekly so the scale stays put. A top rank is free marketing for your API and chat app; #1 makes news and the board
/// takes an interest.
enum Arena {
    static let pledgeKind = "arena_pledge"
    /// LMSYS opened Chatbot Arena in May 2023.
    static let realOpening = 2023.34
    static let feedSize = 60
    static let historySize = 52
    /// The arena caps private testing (the "Leaderboard Illusion" row of 2025): two unreleased models per lab at once.
    static let maxAnonymous = 2
    /// Your strongest released models on the board at once (the rest of a catalogue would only crowd it).
    static let playerSlots = 6
    static let maxEntries = 90
    /// A favourite losing by this many rating points is an upset.
    static let upsetGap = 40.0

    static func name(_ y: Double) -> String { y < 2025.05 ? "Chatbot Arena" : "LMArena" }

    /// May 2023 as it happened, or about five months after the chat moment if that came early (ChatGPT → Arena took 5).
    static func openingYear(_ s: GameState) -> Double { min(realOpening, (s.chatMoment ?? 99) + 0.43) }

    static func categoryOpen(_ c: ArenaCategory, _ s: GameState) -> Bool {
        guard let o = s.arena.opened else { return false }
        let r = c.opensAfter
        return r.years == 0 || s.year >= min(r.realYear, o.decimalYear + r.years)
    }

    static func openCategories(_ s: GameState) -> [ArenaCategory] { ArenaCategory.allCases.filter { categoryOpen($0, s) } }

    /// Votes in one battle batch: hundreds a day in 2023, thousands once the arena became the industry's scoreboard.
    static func baseVotes(_ y: Double) -> Double {
        interpolate([(2023.3, 400), (2024, 1_500), (2025, 3_500), (2027, 6_000), (2030, 9_000)], at: y)
    }

    static func expected(_ a: Double, _ b: Double) -> Double { 1 / (1 + pow(10, (b - a) / 400)) }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        if s.arena.opened == nil {
            guard s.year >= openingYear(s) else { return }
            open(&s)
            return
        }
        var rng = GameRNG(seed: daySeed(s))
        sync(&s, &rng)
        play(&s, &rng)
        if let last = s.arena.lastWeekly, GameCalendar.daysBetween(last, s.date) < 7 { return }
        weekly(&s, &rng)
    }

    /// The day's battles are seeded from the game RNG's state and the date without advancing it, so the arena never
    /// shifts other systems' dice (an older save plays the rest of its game exactly as before) and the same seed still
    /// gives the same game.
    static func daySeed(_ s: GameState) -> UInt64 {
        let day = UInt64(bitPattern: Int64(GameCalendar.daysBetween(GameCalendar.date(2000, 1, 1), s.date)))
        return s.rng.state ^ (day &* 0x9E37_79B9_7F4A_7C15) ^ 0x00A2_E7A0_5EED_0001
    }

    static func open(_ s: inout GameState) {
        var rng = GameRNG(seed: daySeed(s) ^ 0x0BE7)
        // Already running when this game (or save) starts: place everyone from earlier public results, quietly.
        let late = s.year > openingYear(s) + 0.1
        if late {
            s.arena.opened = openingYear(s) == realOpening ? GameCalendar.date(2023, 5, 3)
                : GameCalendar.addDays(s.date, -Int(((s.year - openingYear(s)) * 365.25).rounded()))
        } else {
            s.arena.opened = s.date
        }
        sync(&s, &rng, settled: late, announce: false)
        if !late {
            Sim.news(&s, "\(name(s.year)) opens: the crowd ranks the models",
                     "A university team puts chat models side by side: anyone can ask a question, read two anonymous answers and vote. "
                         + "The votes become an Elo leaderboard that updates every day. \(s.arena.entries.filter(\.active).count) models are on it from day one.",
                     .market, important: true)
        }
        weekly(&s, &rng, quiet: true)
    }

    // MARK: Who plays

    enum Source { case rival(Int, Bool, Int), player(Int) }

    struct Candidate {
        var id: String
        var name: String
        var labID: String
        var lab: String
        var open: Bool
        var source: Source
    }

    /// The board today: each rival lab still in the race brings its two newest models and its open-weights release (for
    /// two years); you bring your strongest released models and any anonymous tests.
    static func candidates(_ s: GameState) -> [Candidate] {
        var out: [Candidate] = []
        for (ci, comp) in s.competitors.enumerated() where !comp.acquired && !comp.bankrupt {
            let def = comp.def
            for mi in comp.models.indices.suffix(2) {
                let m = comp.models[mi]
                out.append(Candidate(id: m.id.uuidString, name: m.name, labID: comp.id, lab: def.name, open: m.open, source: .rival(ci, false, mi)))
            }
            if let mi = comp.openModels.indices.last, GameCalendar.daysBetween(comp.openModels[mi].date, s.date) < 730 {
                let m = comp.openModels[mi]
                out.append(Candidate(id: m.id.uuidString, name: m.name, labID: comp.id, lab: def.name, open: true, source: .rival(ci, true, mi)))
            }
        }
        let live = s.models.indices.filter { s.models[$0].released && !s.models[$0].retired }
            .map { ($0, Leaderboard.playerArena(s.models[$0]), s.models[$0].id.uuidString) }
            .sorted { ($0.1, $0.2) > ($1.1, $1.2) }
        for (mi, _, _) in live.prefix(playerSlots) {
            let m = s.models[mi]
            out.append(Candidate(id: m.id.uuidString, name: m.name, labID: "player", lab: s.companyName, open: m.openWeights, source: .player(mi)))
        }
        let testing = Set(s.arena.entries.filter { $0.active && $0.anonymous }.map(\.id))
        for mi in s.models.indices where !s.models[mi].released && testing.contains(s.models[mi].id.uuidString) {
            let m = s.models[mi]
            out.append(Candidate(id: m.id.uuidString, name: m.name, labID: "player", lab: s.companyName, open: false, source: .player(mi)))
        }
        return out
    }

    /// Hidden strength per category. Centred on the model's static Elo (the leaderboard's "LMArena Elo"): a category
    /// rises with the domains it tests relative to the model's overall capability (7.2 points per capability point), and
    /// with chat style where voters care about it. A small fixed quirk per model and category keeps tables from being
    /// a straight copy of the index.
    static func strength(_ p: ModelProfile, scores: DomainScores, staticElo: Double, c: Double, key: String) -> (overall: Double, cats: [Double]) {
        let style = staticElo - BenchmarkCatalog.arenaElo(c: c, bonus: 0)
        let cap = BenchmarkCatalog.capability(p)
        let cats = ArenaCategory.allCases.map { cat -> Double in
            if cat == .vision && !p.vision { return 0 }
            let quirk = (BenchmarkCatalog.hashUnit(key, "arena-" + cat.rawValue) - 0.5) * 30
            return max(1, staticElo + 7.2 * (scores.mix(cat.domains) - cap) + (cat.style - 0.6) * style + quirk)
        }
        return (staticElo + (BenchmarkCatalog.hashUnit(key, "arena-overall") - 0.5) * 16, cats)
    }

    static func strength(_ s: GameState, _ c: Candidate) -> (overall: Double, cats: [Double]) {
        switch c.source {
        case let .rival(ci, isOpen, mi):
            let comp = s.competitors[ci]
            let m = isOpen ? comp.openModels[mi] : comp.models[mi]
            let p = Leaderboard.profile(m, def: comp.def, boost: Competitors.boost(s, comp.id, at: m.date.decimalYear))
            let sc = s.domainScores[m.id.uuidString] ?? Capabilities.rivalScores(s, m, lab: comp.id, def: comp.def)
            return strength(p, scores: sc, staticElo: Leaderboard.competitorArena(m), c: m.c, key: c.id)
        case let .player(mi):
            let m = s.models[mi]
            let sc = s.domainScores[m.id.uuidString] ?? Capabilities.playerScores(m, research: Capabilities.knowHow(m, s))
            return strength(Leaderboard.profile(m), scores: sc, staticElo: Leaderboard.playerArena(m), c: m.c, key: c.id)
        }
    }

    /// Keep the board in step with the world: reveal codenames that shipped, retire models that left, add newcomers.
    static func sync(_ s: inout GameState, _ rng: inout GameRNG, settled: Bool = false, announce: Bool = true) {
        for i in s.arena.entries.indices where s.arena.entries[i].anonymous && s.arena.entries[i].active {
            guard let m = s.models.first(where: { $0.id.uuidString == s.arena.entries[i].id }) else {
                s.arena.entries[i].codename = ""   // scrapped before launch
                s.arena.entries[i].active = false
                s.arena.entries[i].left = s.date
                continue
            }
            if m.released { reveal(&s, i, m) }
        }
        let cands = candidates(s)
        let ids = Set(cands.map(\.id))
        for i in s.arena.entries.indices where s.arena.entries[i].active && !ids.contains(s.arena.entries[i].id) {
            s.arena.entries[i].active = false
            s.arena.entries[i].left = s.date
        }
        var known: [String: Int] = [:]
        for (i, e) in s.arena.entries.enumerated() { known[e.id] = i }
        for c in cands {
            if let i = known[c.id] {
                if !s.arena.entries[i].active {
                    s.arena.entries[i].active = true
                    s.arena.entries[i].left = nil
                }
                continue
            }
            join(&s, c, &rng, settled: settled, announce: announce)
        }
        prune(&s)
    }

    static func join(_ s: inout GameState, _ c: Candidate, _ rng: inout GameRNG, settled: Bool, announce: Bool, codename: String = "") {
        let st = strength(s, c)
        // New models get a preliminary rating from their first few hundred votes; settled ones were rated long ago.
        let spread = settled ? 8.0 : 35.0
        var e = ArenaEntry(id: c.id, name: c.name, lab: c.lab, labID: c.labID, joined: s.date, open: c.open,
                           overall: st.overall + rng.gaussian() * spread,
                           ratings: st.cats.map { $0 > 0 ? $0 + rng.gaussian() * spread : 0 }, truth: st.cats, truthOverall: st.overall)
        e.seeded = settled
        e.codename = codename
        if settled {
            e.votes = (rng.range(8_000, 40_000) / 100).rounded() * 100
            e.history = [e.overall.rounded()]
        }
        s.arena.entries.append(e)
        guard announce, c.labID == "player", codename.isEmpty else { return }
        let place = 1 + s.arena.entries.filter { $0.active && $0.id != e.id && $0.overall > e.overall }.count
        Sim.news(&s, "\(c.name) joins \(name(s.year))",
                 "Early votes place it #\(place) overall at a preliminary \(Int(e.overall.rounded())). It takes about ten battles for the rating to settle.",
                 .company, good: place <= 3 ? true : nil)
    }

    static func prune(_ s: inout GameState) {
        guard s.arena.entries.count > maxEntries else { return }
        let gone = s.arena.entries.filter { !$0.active }
            .sorted { ($0.left ?? .distantPast, $0.id) < ($1.left ?? .distantPast, $1.id) }
            .prefix(s.arena.entries.count - maxEntries).map(\.id)
        let drop = Set(gone)
        s.arena.entries.removeAll { drop.contains($0.id) }
    }

    // MARK: Battles

    static func pick(_ items: [Int], _ w: [Double], _ rng: inout GameRNG) -> Int {
        let total = w.reduce(0, +)
        var r = rng.unit() * total
        for (k, x) in w.enumerated() {
            r -= x
            if r <= 0 { return items[k] }
        }
        return items[items.count - 1]
    }

    /// The day's battles: 6 to 16 depending on how crowded the board is. New and preliminary models are sampled more
    /// (as the real arena does), and opponents are picked near their own rating, where a vote tells the most.
    static func play(_ s: inout GameState, _ rng: inout GameRNG) {
        let active = s.arena.entries.indices.filter { s.arena.entries[$0].active }
        let cats = openCategories(s)
        guard active.count >= 3, !cats.isEmpty else { return }
        let n = min(16, 6 + active.count / 3)
        let base = baseVotes(s.year)
        for _ in 0..<n {
            let cat = cats[pick(Array(cats.indices), cats.map(\.mix), &rng)]
            let pool = active.filter { s.arena.entries[$0].plays(cat) }
            guard pool.count >= 2 else { continue }
            let a = pick(pool, pool.map { i in
                let e = s.arena.entries[i]
                return (e.provisional ? 4 : 1) * (GameCalendar.daysBetween(e.joined, s.date) < 45 ? 1.5 : 1)
            }, &rng)
            let ra = s.arena.entries[a].ratings[cat.index]
            let others = pool.filter { $0 != a }
            let b = pick(others, others.map { i in
                let e = s.arena.entries[i]
                return exp(-abs(e.ratings[cat.index] - ra) / 160) * (e.provisional ? 2 : 1)
            }, &rng)
            battle(&s, a, b, cat, base, &rng)
        }
    }

    static func battle(_ s: inout GameState, _ a: Int, _ b: Int, _ cat: ArenaCategory, _ base: Double, _ rng: inout GameRNG) {
        let A = s.arena.entries[a], B = s.arena.entries[b]
        let k = cat.index
        let p = expected(A.truth[k], B.truth[k])
        let votes = max(50, Int(base * rng.range(0.5, 1.5)))
        // Sampling noise from the vote count plus the luck of which prompts came up that day.
        let share = clamp(p + rng.gaussian() * (sqrt(p * (1 - p) / Double(votes)) + 0.02), 0.03, 0.97)
        let e = expected(A.ratings[k], B.ratings[k])
        let eo = expected(A.overall, B.overall)
        let kA = A.provisional ? 160.0 : 90, kB = B.provisional ? 160.0 : 90
        let dA = kA * (share - e)
        s.arena.entries[a].ratings[k] += dA
        s.arena.entries[b].ratings[k] -= kB * (share - e)
        // Overall moves with every battle, so it takes smaller steps than a single category.
        s.arena.entries[a].overall += 0.6 * kA * (share - eo)
        s.arena.entries[b].overall -= 0.6 * kB * (share - eo)
        for i in [a, b] {
            s.arena.entries[i].matches += 1
            s.arena.entries[i].catMatches[k] += 1
            s.arena.entries[i].votes += Double(votes)
        }
        if share > 0.505 { s.arena.entries[a].wins += 1 } else if share < 0.495 { s.arena.entries[b].wins += 1 }
        let gap = A.ratings[k] - B.ratings[k]
        let upset = (share > 0.505 && gap < -upsetGap) || (share < 0.495 && gap > upsetGap)
        s.arena.seq += 1
        s.arena.feed.insert(ArenaMatch(id: s.arena.seq, date: s.date, category: cat, a: A.id, b: B.id, aName: A.shownName, bName: B.shownName,
                                       aLab: A.labID, bLab: B.labID, votes: votes, shareA: share, ratingA: A.ratings[k], ratingB: B.ratings[k],
                                       delta: dA, upset: upset), at: 0)
        if s.arena.feed.count > feedSize { s.arena.feed.removeLast(s.arena.feed.count - feedSize) }
        s.arena.matchCount += 1
        s.arena.votes += Double(votes)
        // A giant-killing by one of your public models is a story; the reverse only shows in the feed.
        guard upset, abs(gap) >= 70 else { return }
        let (w, l, wShare) = share > 0.5 ? (A, B, share) : (B, A, 1 - share)
        guard w.isPlayer, !w.anonymous, !l.isPlayer else { return }
        if let last = s.arena.lastUpsetNews, GameCalendar.daysBetween(last, s.date) < 45 { return }
        s.arena.lastUpsetNews = s.date
        Sim.news(&s, "Upset on \(name(s.year)): \(w.name) beats \(l.name) at \(cat.title.lowercased())",
                 "\(w.name) took \(Fmt.pct(wShare, decimals: 0)) of \(Fmt.int(votes)) votes against \(Leaderboard.possessive(l.lab)) model, "
                     + "rated \(Int(abs(gap).rounded())) points higher in \(cat.title.lowercased()). Developers share the side-by-sides.",
                 .company, good: true)
    }

    // MARK: Weekly table

    static func weekly(_ s: inout GameState, _ rng: inout GameRNG, quiet: Bool = false) {
        s.arena.lastWeekly = s.date
        s.arena.weeks += 1
        refreshTruths(&s)
        recentre(&s)
        for i in s.arena.entries.indices where s.arena.entries[i].active {
            s.arena.entries[i].history.append(s.arena.entries[i].overall.rounded())
            if s.arena.entries[i].history.count > historySize { s.arena.entries[i].history.removeFirst(s.arena.entries[i].history.count - historySize) }
        }
        let order = s.arena.entries.indices.filter { s.arena.entries[$0].active }
            .sorted { (s.arena.entries[$0].overall, s.arena.entries[$0].id) > (s.arena.entries[$1].overall, s.arena.entries[$1].id) }
        var ranks: [String: Int] = [:]
        for (r, i) in order.enumerated() {
            ranks[s.arena.entries[i].id] = r + 1
            if s.arena.entries[i].peakRank == 0 || r + 1 < s.arena.entries[i].peakRank { s.arena.entries[i].peakRank = r + 1 }
        }
        var before: [String: Int] = [:]
        for t in s.arena.top10 { before[t.id] = t.rank }
        s.arena.top10 = order.prefix(10).enumerated().map { r, i in
            let e = s.arena.entries[i]
            return ArenaTopRow(id: e.id, name: e.shownName, labID: e.labID, lab: e.anonymous ? "Anonymous" : e.lab, rating: e.overall.rounded(),
                               rank: r + 1, prev: before[e.id] ?? 0, anonymous: e.anonymous)
        }
        s.arena.ranks = ranks
        standings(&s, order.map { s.arena.entries[$0] }, ranks: ranks, quiet: quiet)
        leaks(&s, &rng, ranks: ranks)
    }

    static func refreshTruths(_ s: inout GameState) {
        var byID: [String: Candidate] = [:]
        for c in candidates(s) { byID[c.id] = c }
        for i in s.arena.entries.indices where s.arena.entries[i].active {
            guard let c = byID[s.arena.entries[i].id] else { continue }
            let st = strength(s, c)
            s.arena.entries[i].truthOverall = st.overall
            for k in st.cats.indices {
                // A category the model can newly play starts at its strength; one it can't play is cleared.
                if st.cats[k] > 0 && s.arena.entries[i].ratings[k] <= 0 { s.arena.entries[i].ratings[k] = st.cats[k] }
                if st.cats[k] <= 0 { s.arena.entries[i].ratings[k] = 0 }
            }
            s.arena.entries[i].truth = st.cats
        }
    }

    /// Re-anchor every scale so the board's average rating equals its average strength (the real arena anchors to a
    /// reference model the same way). Differences between models are untouched.
    static func recentre(_ s: inout GameState) {
        let act = s.arena.entries.indices.filter { s.arena.entries[$0].active }
        guard act.count >= 2 else { return }
        let d = act.reduce(0.0) { $0 + s.arena.entries[$1].truthOverall - s.arena.entries[$1].overall } / Double(act.count)
        for i in act { s.arena.entries[i].overall += d }
        for c in ArenaCategory.allCases {
            let pl = act.filter { s.arena.entries[$0].plays(c) }
            guard pl.count >= 2 else { continue }
            let dc = pl.reduce(0.0) { $0 + s.arena.entries[$1].truth[c.index] - s.arena.entries[$1].ratings[c.index] } / Double(pl.count)
            for i in pl { s.arena.entries[i].ratings[c.index] += dc }
        }
    }

    /// Within four weeks (headline rate limits).
    static func recent(_ d: Date?, _ s: GameState) -> Bool { d.map { GameCalendar.daysBetween($0, s.date) < 28 } ?? false }

    /// News, brand and the board's goal from the weekly table.
    static func standings(_ s: inout GameState, _ order: [ArenaEntry], ranks: [String: Int], quiet: Bool) {
        guard let overallTop = order.first else { return }
        let arena = name(s.year)
        // Standings, #1 and the board's goal go by public models: an anonymous test of yours on top doesn't count (or cost you).
        let pub = order.filter { !$0.anonymous }
        let leader = pub.first ?? overallTop
        let mine = pub.first { $0.isPlayer }
        let myRank = mine.flatMap { m in pub.firstIndex { $0.id == m.id } }.map { $0 + 1 }
        let leaderIsMe = leader.isPlayer && !leader.anonymous
        let leaderKey = leader.labID
        let second = pub.dropFirst().first
        if !quiet && overallTop.anonymous && overallTop.isPlayer && s.arena.leaderModel != overallTop.codename {
            Sim.news(&s, "Mystery model “\(overallTop.codename)” tops \(arena)",
                     "An unreleased model nobody will claim leads the overall table at \(Int(overallTop.overall.rounded())). Forums argue about which lab is behind it; you know.",
                     .market, good: true)
        }
        let margin = second.map { Int((leader.overall - $0.overall).rounded()) } ?? 0
        if let r = myRank {
            if !quiet && r <= 10 && (s.arena.bestRank == 0 || s.arena.bestRank > 10) && !leaderIsMe {
                Sim.news(&s, "\(mine!.name) breaks into the \(arena) top 10",
                         "It sits #\(r) overall at \(Int(mine!.overall.rounded())). A top-10 spot puts it in front of every developer who checks the board before choosing a model.",
                         .company, good: true)
            }
            s.arena.bestRank = s.arena.bestRank == 0 ? r : min(s.arena.bestRank, r)
        }
        if leaderIsMe {
            s.arena.weeksAtTop += 1
            s.brand = min(100, s.brand + 0.2)
            // The first table only sets the stage: #1 is news once a week of real votes is in.
            if s.arena.leaderLab != "player" && !quiet {
                offerPledge(&s, model: leader.name)
                if s.arena.firstTop == nil { s.arena.firstTop = s.date }
                Achievements.unlock(&s, "arena")
            }
            if s.arena.leaderLab != "player" && !quiet && !recent(s.arena.lastTopNews, s) {
                s.arena.lastTopNews = s.date
                let rival = pub.first { !$0.isPlayer }.map { r -> String in
                    let gap = Int((leader.overall - r.overall).rounded())
                    return " The best rival, \(Leaderboard.possessive(r.lab)) \(r.name), is \(gap) point\(gap == 1 ? "" : "s") behind."
                } ?? ""
                Sim.news(&s, "\(leader.name) takes #1 on \(arena)",
                         "After \(Fmt.int(Int(leader.votes))) votes, \(leader.name) leads the overall table at \(Int(leader.overall.rounded())).\(rival) "
                             + "Developers, reporters and your own sales team will all be quoting it.",
                         .company, image: "sf_skyline", important: true, good: true)
                Alerts.raise(&s, .milestone, key: "arena_top_\(s.arena.weeks)", title: "#1 on \(arena)",
                             body: "\(leader.name) tops the overall table at \(Int(leader.overall.rounded())).", screen: .arena, celebrate: true, cooldown: 0)
            }
        } else if let r = myRank, r <= 3 {
            s.brand = min(100, s.brand + 0.1)
        }
        if !quiet && s.arena.leaderLab != leaderKey && !leaderIsMe && !recent(s.arena.lastLeaderNews, s) {
            if s.arena.leaderLab != "" { s.arena.lastLeaderNews = s.date }
            if s.arena.leaderLab == "player" {
                Sim.news(&s, "You lose #1 on \(arena)",
                         "\(Leaderboard.possessive(leader.lab)) \(leader.name) now leads at \(Int(leader.overall.rounded())); your \(mine?.name ?? "best model") is #\(myRank ?? 0). "
                             + "A stronger release, or more preference tuning, is how labs win it back.",
                         .competitor, important: true, good: false)
            } else if s.arena.leaderLab != "" {
                Sim.news(&s, "\(Leaderboard.possessive(leader.lab)) \(leader.name) takes #1 on \(arena)",
                         "It leads the overall table at \(Int(leader.overall.rounded()))\(margin > 0 ? ", \(margin) points clear" : "")."
                             + (myRank.map { " Your best model is #\($0)." } ?? ""),
                         .competitor)
            }
        }
        if !quiet { s.arena.leaderLab = leaderKey }
        s.arena.leaderModel = overallTop.shownName
        guard !quiet, var p = s.arena.pledge else { return }
        p.weeksSeen += 1
        if leaderIsMe { p.weeksHeld += 1 }
        if p.weeksHeld >= p.weeksNeeded {
            let paid = max(p.reward, Board.tranche(s) * 0.8)
            s.cash += paid
            s.month.oneOffIncome += paid
            s.culturePoints += 1
            s.boardConfidence = clamp(s.boardConfidence + p.confidence, 0, 100)
            s.arena.pledgesMet += 1
            s.arena.pledge = nil
            Sim.news(&s, "Board goal met: #1 on \(arena)",
                     "You topped \(p.weeksHeld) of the last \(p.weeksSeen) weekly tables. Investors release a \(Fmt.money(paid)) tranche; +1 culture point, board confidence up.",
                     .finance, important: true, good: true)
        } else if p.weeksSeen - p.weeksHeld > p.weeksTotal - p.weeksNeeded {
            s.boardConfidence = clamp(s.boardConfidence - 5, 0, 100)
            s.arena.pledgesMissed += 1
            s.arena.pledge = nil
            Sim.news(&s, "Missed a board goal: #1 on \(arena)",
                     "You've lost the top spot on too many weekly tables to make \(p.weeksNeeded) of \(p.weeksTotal). Board confidence falls 5 points.",
                     .finance, important: true, good: false)
        } else {
            s.arena.pledge = p
        }
    }

    /// Testers sometimes trace a codename to its lab from the way it answers (about once in 20 weeks).
    static func leaks(_ s: inout GameState, _ rng: inout GameRNG, ranks: [String: Int]) {
        for i in s.arena.entries.indices where s.arena.entries[i].active && s.arena.entries[i].anonymous && !s.arena.entries[i].leaked {
            guard rng.chance(0.05) else { continue }
            s.arena.entries[i].leaked = true
            let e = s.arena.entries[i]
            let r = ranks[e.id] ?? 99
            if r <= 5 { s.brand = min(100, s.brand + 1) } else if r > 15 { s.brand = max(0, s.brand - 0.5) }
            Sim.news(&s, "Testers trace “\(e.codename)” to \(s.companyName)",
                     "Arena regulars match its quirks to your public models. At #\(r) overall, "
                         + (r <= 5 ? "the speculation is free publicity for your next launch." : r > 15 ? "it reads as an underwhelming preview." : "it gets polite interest."),
                     .market, good: r <= 5 ? true : (r > 15 ? false : nil))
        }
    }

    /// A tested model ships: the codename comes off.
    static func reveal(_ s: inout GameState, _ i: Int, _ m: AIModel) {
        let e = s.arena.entries[i]
        s.arena.entries[i].codename = ""
        s.arena.entries[i].name = m.name
        let r = s.arena.ranks[e.id] ?? (1 + s.arena.entries.filter { $0.active && $0.id != e.id && $0.overall > e.overall }.count)
        if r <= 3 { s.brand = min(100, s.brand + 1.5) } else if r <= 10 { s.brand = min(100, s.brand + 0.5) }
        Sim.news(&s, "“\(e.codename)” was \(Leaderboard.possessive(s.companyName)) \(m.name)",
                 "The anonymous model that has played \(Fmt.int(e.matches)) battles on \(name(s.year)) ships under its real name, rated \(Int(e.overall.rounded())) (#\(r) overall)."
                     + (r <= 3 ? " A launch with a top-3 rating already proven: the coverage writes itself." : ""),
                 .company, good: r <= 10 ? true : nil)
    }

    // MARK: The board's goal

    static func offerPledge(_ s: inout GameState, model: String) {
        guard s.arena.pledge == nil, !s.decisions.contains(where: { $0.kind == pledgeKind }) else { return }
        if let last = s.arena.lastPledgeOffer, GameCalendar.daysBetween(last, s.date) < 180 { return }
        s.arena.lastPledgeOffer = s.date
        let reward = Board.tranche(s) * 0.8
        Events.addDecision(&s, kind: pledgeKind, title: "The board wants you to stay #1 on \(name(s.year))",
                           body: "\(model) tops the arena. The directors would like to see it stay there: a public #1 is the easiest story to sell to customers and the next round's investors.",
                           image: "sf_skyline",
                           options: [DecisionOption(label: "Make it a board goal",
                                                    detail: "Top \(name(s.year)) on 6 of the next 10 weekly tables: a \(Fmt.money(reward)) tranche, +6 board confidence and a culture point. Miss it: −5 confidence."),
                                     DecisionOption(label: "Enjoy it, promise nothing", detail: "No goal and no risk.")],
                           amount: reward, ref: model)
    }

    static func resolvePledge(_ s: inout GameState, _ d: Decision, option: Int) {
        guard option == 0, s.arena.pledge == nil else { return }
        s.arena.pledge = ArenaPledge(started: s.date, model: d.ref, weeksNeeded: 6, weeksTotal: 10, reward: d.amount, confidence: 6)
        Sim.news(&s, "Board goal: stay #1 on \(name(s.year))",
                 "Top the overall table on 6 of the next 10 weekly tables for a \(Fmt.money(d.amount)) tranche. Track it on the Arena page.", .finance)
    }

    // MARK: Effects and lookups

    /// How the arena sways buyers of one of your models (a brand multiplier in Market): a top spot is free marketing, a
    /// model far down the table looks dated. Modest: #1 is worth roughly 4% more pull (brand enters it to the 0.7), the bottom 1.5% less.
    static func pull(_ s: GameState, _ id: UUID) -> Double {
        guard var r = s.arena.ranks[id.uuidString] else { return 1 }
        // Buyers compare what they can buy: your own anonymous tests ahead of it don't push it down.
        r -= s.arena.entries.filter { $0.active && $0.anonymous && (s.arena.ranks[$0.id] ?? Int.max) < r }.count
        switch r {
        case 1: return 1.06
        case 2...3: return 1.04
        case 4...10: return 1.02
        case 11...20: return 1
        default: return 0.98
        }
    }

    /// Live overall ratings by model id (for the leaderboard's Elo column).
    static func liveRatings(_ s: GameState) -> [String: Double] {
        var out: [String: Double] = [:]
        for e in s.arena.entries { out[e.id] = e.overall }
        return out
    }

    /// A rating's 95% interval in points: wide while a model is new, about ±5 once settled.
    static func interval(_ e: ArenaEntry) -> Int {
        if e.seeded { return max(4, Int((14 - Double(e.matches) * 0.2).rounded())) }
        return max(4, Int((60 / sqrt(Double(max(1, e.matches)))).rounded()))
    }

    /// Current table for a category (nil: overall), active models only.
    static func table(_ s: GameState, _ c: ArenaCategory?) -> [ArenaEntry] {
        s.arena.entries.filter { e in e.active && (c.map { e.plays($0) } ?? true) }
            .sorted { ($0.rating(c), $0.id) > ($1.rating(c), $1.id) }
    }

    static let codenames = [
        "kingfisher", "quiet-lark", "moonhowler", "red-panda", "zephyr", "obsidian-fox", "paper-crane", "nightjar", "tundra", "copperhead",
        "lantern", "blue-heron", "saffron", "glacier-7", "wildcard", "nimbus", "ember-owl", "riverstone", "solstice", "magpie",
        "halfmoon", "basilisk", "cinder", "starling", "marigold", "polaris", "driftwood", "thornback", "aurora-9", "pebble",
    ]

    static func codename(_ s: inout GameState) -> String {
        let free = codenames.filter { !s.arena.usedCodenames.contains($0) }
        let pick = free.isEmpty ? "\(s.rng.pick(codenames))-\(s.arena.usedCodenames.count)" : s.rng.pick(free)
        s.arena.usedCodenames.insert(pick)
        return pick
    }

    // MARK: Harness

    /// Replay steps scheduled by `arena:release:<model>@<day>`.
    nonisolated(unsafe) static var harnessPlan: [(model: String, day: Int)] = []

    /// `arena:test:<model>` tests an unreleased model anonymously; `arena:preview:<model>` first adds an unreleased
    /// successor of a released model (a little stronger, as a fresh run would be) and tests that; `arena:release:<model>@<day>`
    /// releases it with the API on that replay day.
    static func harnessArg(_ s: inout GameState, _ t: String) {
        let p = t.split(separator: ":", maxSplits: 2).map(String.init)
        guard p.count == 3 else { print("use arena:test|preview|release:<model>"); return }
        // A save from before the update opens the arena on its first day; a test asked for up front needs it now.
        if s.arena.opened == nil && s.year >= openingYear(s) && p[1] != "release" { open(&s) }
        switch p[1] {
        case "test":
            guard let m = s.models.first(where: { $0.name == p[2] }) else { print("no model \(p[2])"); return }
            print("arena test \(m.name): \(s.arenaTestAnonymously(m.id) ?? "ok")")
        case "preview":
            guard var m = s.models.first(where: { $0.name == p[2] }) else { print("no model \(p[2])"); return }
            m.id = StableID.next()
            m.name = "\(p[2]) Next"
            m.c += 0.2
            m.chatSkill += 0.15
            m.arenaBonus += 11
            m.released = false
            m.releaseDate = nil
            m.retired = false
            m.deployments = []
            s.models.append(m)
            print("arena preview \(m.name) (c \(Fmt.trim(m.c, 2))): \(s.arenaTestAnonymously(m.id) ?? "ok")")
        case "release":
            let q = p[2].split(separator: "@").map(String.init)
            harnessPlan.append((q[0], q.count > 1 ? Int(q[1]) ?? 0 : 0))
        default:
            print("unknown \(t)")
        }
    }

    static func harnessDay(_ s: inout GameState, _ day: Int) {
        for step in harnessPlan where step.day == day {
            guard let m = s.models.first(where: { $0.name == step.model }) else { print("no model \(step.model)"); continue }
            print("arena release \(m.name): \(s.release(m.id, api: true, openWeights: false) ?? "ok")")
        }
    }

    /// REPLAY_ARENA lines: the weekly table when one is published, your battles and the day's arena headlines.
    static func report(_ s: GameState) {
        guard let opened = s.arena.opened else {
            print("    ARENA not open yet (opens \(Fmt.trim(openingYear(s), 2)))")
            return
        }
        if s.arena.lastWeekly == s.date {
            let mine = s.arena.entries.filter { $0.active && $0.isPlayer }.sorted { $0.overall > $1.overall }
            print("    ARENA week \(s.arena.weeks) (open since \(opened.gameShort), \(s.arena.entries.filter(\.active).count) models, \(Fmt.int(s.arena.matchCount)) battles, \(Fmt.count(s.arena.votes)) votes, categories \(openCategories(s).map(\.title).joined(separator: "/"))):")
            for t in s.arena.top10 {
                print("      #\(t.rank) \(t.prev == 0 ? "new" : (t.prev > t.rank ? "↑\(t.prev - t.rank)" : (t.prev < t.rank ? "↓\(t.rank - t.prev)" : "=")))  \(t.name) (\(t.lab)) \(Int(t.rating))\(t.labID == "player" ? "  ← YOU" : "")")
            }
            for e in mine {
                let cats = ArenaCategory.allCases.filter { e.plays($0) }.map { "\($0.title) \(Int(e.rating($0).rounded()))/\(Int(e.truth[$0.index].rounded()))" }.joined(separator: " ")
                print("      you: \(e.shownName)\(e.anonymous ? " [anon \(e.name)]" : "") #\(s.arena.ranks[e.id] ?? 0) overall \(Int(e.overall.rounded()))±\(interval(e)) (strength \(Int(e.truthOverall.rounded()))) · \(e.matches) battles \(e.wins) wins · pull ×\(Fmt.trim(pull(s, UUID(uuidString: e.id) ?? UUID()), 3)) · \(cats) · history \(e.history.suffix(6).map { String(Int($0)) }.joined(separator: ","))")
            }
            print("      best rank \(s.arena.bestRank) · weeks at #1 \(s.arena.weeksAtTop) · pledge \(s.arena.pledge.map { "\($0.weeksHeld)/\($0.weeksNeeded) held of \($0.weeksSeen)/\($0.weeksTotal)" } ?? "none") (met \(s.arena.pledgesMet), missed \(s.arena.pledgesMissed)) · brand \(Fmt.trim(s.brand, 1))")
        }
        for m in s.arena.feed where m.date == s.date && (m.aLab == "player" || m.bLab == "player" || m.upset) {
            print("    ARENA battle [\(m.category.title)] \(m.aName) \(Fmt.pct(m.shareA, decimals: 0))–\(Fmt.pct(1 - m.shareA, decimals: 0)) \(m.bName) · \(Fmt.int(m.votes)) votes · \(Int(m.ratingA))/\(Int(m.ratingB)) Δ\(Fmt.trim(m.delta, 1))\(m.upset ? " UPSET" : "")")
        }
        for n in s.news where n.date == s.date && (n.title.contains("Arena") || n.title.contains("arena") || n.title.contains("“")) {
            print("    ARENA news: \(n.title) — \(n.body)")
        }
    }
}

// MARK: - Player actions

extension GameState {
    /// Put a trained, unreleased model on the arena under a codename: you learn where it really stands before launch.
    mutating func arenaTestAnonymously(_ id: UUID) -> String? {
        guard arena.opened != nil else { return "The arena hasn't opened yet." }
        guard let mi = models.firstIndex(where: { $0.id == id }) else { return "Model not found." }
        let m = models[mi]
        if m.released { return "\(m.name) is already public: it plays under its own name." }
        if arena.entries.contains(where: { $0.id == id.uuidString && $0.active }) { return "\(m.name) is already on the arena." }
        if arena.entries.filter({ $0.active && $0.anonymous }).count >= Arena.maxAnonymous {
            return "The arena tests at most \(Arena.maxAnonymous) unreleased models per lab at a time. Withdraw one first."
        }
        let code = Arena.codename(&self)
        if let i = arena.entries.firstIndex(where: { $0.id == id.uuidString }) {
            arena.entries[i].active = true
            arena.entries[i].left = nil
            arena.entries[i].codename = code
        } else {
            var r = GameRNG(seed: rng.next())
            Arena.join(&self, Arena.Candidate(id: id.uuidString, name: m.name, labID: "player", lab: companyName, open: false, source: .player(mi)),
                       &r, settled: false, announce: false, codename: code)
        }
        Sim.news(&self, "\(m.name) goes on \(Arena.name(year)) as “\(code)”",
                 "Voters will meet it anonymously. You'll see its real rating within a couple of weeks; the codename comes off when you release it.", .company)
        return nil
    }

    mutating func arenaWithdraw(_ id: UUID) -> String? {
        guard let i = arena.entries.firstIndex(where: { $0.id == id.uuidString && $0.active && $0.anonymous }) else { return "It isn't on the arena." }
        arena.entries[i].active = false
        arena.entries[i].left = date
        arena.entries[i].codename = ""
        arena.ranks.removeValue(forKey: id.uuidString)
        return nil
    }
}
