import Foundation

/// 3.7: nations. Each region runs a national AI strategy — seven dials from compute subsidies to energy policy — that
/// it reviews every January against the state of the world: public mood and safety concern, recent incidents, jobs lost
/// to automation, strained grids, which country's lab holds the frontier, how close its own labs are, and how it sees
/// your lab. Each region also keeps a small economy (growth, AI's share of GDP, AI investment, automation
/// unemployment). Strategies have concrete, explained effects: chip and cloud prices at home, datacenter power by
/// region, candidates on the job market, agency budgets, enterprise demand, and a gentle pull on world adoption.
/// Nothing here draws from the game's random numbers (hashed rolls only).
enum Nations {
    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("nations|\(s.lifecycleSalt)|\(key)") }

    // MARK: Character

    /// Each region's dials (NationLever order) in 2017, before AI was a national priority, and once it is.
    static func anchors(_ r: Region) -> (before: [Double], after: [Double]) {
        switch r {
        //                subsidy sovereign exports data safety visas energy
        case .us: ([15, 10, 25, 20, 12, 55, 40], [42, 35, 72, 30, 34, 48, 62])
        case .eu: ([25, 15, 10, 55, 25, 40, 35], [52, 50, 25, 78, 72, 52, 45])
        case .uk: ([20, 10, 15, 40, 20, 50, 35], [45, 40, 35, 50, 55, 58, 50])
        case .china: ([40, 45, 15, 55, 25, 15, 55], [78, 88, 45, 65, 48, 22, 75])
        case .gulf: ([25, 20, 5, 25, 8, 60, 65], [80, 82, 15, 30, 18, 78, 90])
        case .india: ([15, 10, 5, 30, 10, 20, 40], [55, 62, 12, 48, 25, 30, 55])
        case .japanKorea: ([25, 15, 25, 45, 15, 25, 40], [55, 52, 45, 52, 38, 38, 50])
        }
    }

    /// How much AI is a national priority (0–1): a side issue before 2022, everyone's priority after the chat boom.
    static func salience(_ y: Double) -> Double {
        interpolate([(2016, 0.05), (2020, 0.15), (2022.9, 0.3), (2023.5, 0.65), (2025, 0.9), (2027, 1.0)], at: y)
    }

    static func baseline(_ r: Region, _ y: Double) -> [Double] {
        let (b, a) = anchors(r)
        let k = salience(y)
        return zip(b, a).map { $0 + ($1 - $0) * k }
    }

    /// How much automation costs jobs there (workforce mix and safety nets).
    static func exposure(_ r: Region) -> Double {
        switch r {
        case .us: 1.1
        case .eu: 0.8
        case .uk: 1.0
        case .china: 1.15
        case .gulf: 0.6
        case .india: 1.3
        case .japanKorea: 1.0
        }
    }

    /// How much of the economy turns into AI business there (relative to the world).
    static func aiIntensity(_ r: Region) -> Double {
        switch r {
        case .us: 1.3
        case .eu: 0.8
        case .uk: 1.0
        case .china: 1.05
        case .gulf: 0.9
        case .india: 0.55
        case .japanKorea: 0.95
        }
    }

    /// Trend GDP growth without AI (%).
    static func baseGrowth(_ r: Region, _ y: Double) -> Double {
        switch r {
        case .us: interpolate([(2016, 2.2), (2030, 2.0)], at: y)
        case .eu: interpolate([(2016, 1.7), (2030, 1.2)], at: y)
        case .uk: interpolate([(2016, 1.8), (2030, 1.3)], at: y)
        case .china: interpolate([(2016, 6.8), (2024, 5.0), (2030, 3.8), (2036, 3.2)], at: y)
        case .gulf: interpolate([(2016, 2.5), (2030, 3.0)], at: y)
        case .india: interpolate([(2016, 7.0), (2030, 6.3)], at: y)
        case .japanKorea: interpolate([(2016, 1.3), (2030, 0.8)], at: y)
        }
    }

    /// A region's people as an adjective ("American", "European").
    static func adjective(_ r: Region) -> String {
        switch r {
        case .us: "American"
        case .eu: "European"
        case .uk: "British"
        case .china: "Chinese"
        case .gulf: "Gulf"
        case .india: "Indian"
        case .japanKorea: "Japanese and Korean"
        }
    }

    /// What a lever is called there when it favours something ("EU research grants").
    static func programme(_ r: Region, _ l: NationLever) -> String {
        switch l {
        case .subsidy: "\(r.short) research grants and compute subsidies"
        case .sovereign: "\(r.short)'s sovereign-AI programme"
        case .exports: "\(r.short) export controls"
        case .data: "\(r.short) data rules"
        case .safety: "\(r.short)'s safety regime"
        case .visas: "\(r.short) talent visas"
        case .energy: "\(r.short) energy policy"
        }
    }

    // MARK: What a nation sees

    struct Inputs {
        var y: Double
        var concern = 25.0
        var sentiment = 50.0
        var incident: String? = nil
        var grid = 0.0
        /// Automation unemployment and AI share of GDP by region (Region order).
        var automation: [Double] = Array(repeating: 0, count: Region.allCases.count)
        var aiShare: [Double] = Array(repeating: 0, count: Region.allCases.count)
        /// Where the frontier model comes from, and whose it is.
        var leaderRegion: Region = .us
        var leaderName = ""
        /// Months behind the frontier for each region's best lab (nil: no lab there), and its name.
        var homeGap: [Double?] = Array(repeating: nil, count: Region.allCases.count)
        var homeName: [String] = Array(repeating: "", count: Region.allCases.count)
        /// Your lab: where it's based, whether it's a top-two lab, your standing with each government.
        var playerRegion: Region = .us
        var playerTop = false
        var playerName = ""
        var standing: [Double] = Array(repeating: 50, count: Region.allCases.count)
        /// US export controls as they stood going into the review.
        var usExports = 25.0
    }

    /// What the world looks like to a strategy review on `date`. Live reviews read today's world; the replay at set-up
    /// reads the world's monthly history and the labs' releases up to that date.
    static func inputs(_ s: GameState, at date: Date, live: Bool) -> Inputs {
        let y = date.decimalYear
        var i = Inputs(y: y)
        let w = s.world
        if live {
            i.concern = w.concern
            i.sentiment = w.sentiment
            i.grid = w.gridStress
        } else if let snap = w.history.last(where: { $0.month <= date }) ?? w.history.first {
            i.concern = snap.concern
            i.sentiment = snap.sentiment
            i.grid = 0
        }
        if !w.incident.isEmpty, let d = w.incidentDate, d <= date, GameCalendar.daysBetween(d, date) <= 365 { i.incident = w.incident }
        for r in Region.allCases {
            let e = s.nations.economy(r)
            i.automation[r.index] = e.automation
            i.aiShare[r.index] = e.aiShare
            i.standing[r.index] = w.government(r)
        }
        i.usExports = s.nations.level(.us, .exports)
        // Who holds the frontier, and how far each region's best lab is behind it.
        var best: [(name: String, region: Region, c: Double)] = []
        for c in s.competitors where c.alive && c.def.founded.date <= date {
            guard let m = (c.models + c.openModels).filter({ $0.date <= date }).max(by: { $0.c < $1.c }) else { continue }
            best.append((c.def.name, AdvancedProjects.labRegion(c.id), m.c))
        }
        i.playerRegion = HQ.region(s)
        i.playerName = s.companyName
        let mine = s.models.filter { $0.released && ($0.releaseDate ?? $0.created) <= date }.map(\.c).max()
        if live, let mine { best.append((s.companyName, i.playerRegion, mine)) }
        guard let top = best.max(by: { $0.c < $1.c }) else { return i }
        i.leaderRegion = top.region
        i.leaderName = top.name
        let perMonth = RivalStrategy.frontierPerMonth(y)
        for r in Region.allCases {
            if let b = best.filter({ $0.region == r }).max(by: { $0.c < $1.c }) {
                i.homeGap[r.index] = max(0, top.c - b.c) / perMonth
                i.homeName[r.index] = b.name
            }
        }
        if live, let mine {
            let ahead = best.filter { $0.c > mine }.count
            i.playerTop = ahead <= 1
        }
        return i
    }

    /// One pressure on one dial, with the reason a newspaper would give.
    struct Push {
        var lever: NationLever
        var delta: Double
        var why: String
    }

    /// Where a region's dials want to be this year, and the pressures behind it.
    static func target(_ r: Region, _ i: Inputs, _ s: GameState) -> (levels: [Double], pushes: [Push]) {
        var levels = baseline(r, i.y)
        var pushes: [Push] = []
        func push(_ l: NationLever, _ d: Double, _ why: String) {
            guard abs(d) >= 0.5 else { return }
            levels[l.index] += d
            pushes.append(Push(lever: l, delta: d, why: why))
        }
        let resp = r.responsiveness
        let k = salience(i.y)
        // Fear and incidents tighten safety and data rules.
        let fear = i.concern - 30
        if fear > 4 {
            push(.safety, 0.35 * fear * resp, "safety concern at \(Int(i.concern.rounded()))")
            push(.data, 0.15 * fear * resp, "safety concern at \(Int(i.concern.rounded()))")
        }
        if let inc = i.incident { push(.safety, 6 * resp, "after \(inc)") }
        // A warm public backs spending; a sour one wants rules.
        let mood = i.sentiment - 50
        if abs(mood) > 3 { push(.subsidy, 0.3 * mood * k, mood > 0 ? "a public warm to AI" : "a public sour on AI") }
        if i.sentiment < 42 { push(.safety, (42 - i.sentiment) * 0.3 * resp, "a public sour on AI") }
        // Jobs lost to automation close the door to foreign talent and add rules.
        let auto = i.automation[r.index]
        if auto > 0.8 {
            let why = "\(Fmt.trim(auto, 1))% of workers out of work to automation"
            push(.visas, -min(15, 6 * (auto - 0.8)), why)
            push(.safety, min(8, 3 * (auto - 0.8)), why)
        }
        // Strained grids bring permitting reform and new generation.
        if i.grid > 45, [Region.us, .eu, .uk, .japanKorea].contains(r) {
            push(.energy, min(15, (i.grid - 45) * 0.4), "strained grids (stress \(Int(i.grid.rounded())))")
        }
        // Whoever holds the frontier, everyone else wants their own.
        if i.leaderRegion != r && !i.leaderName.isEmpty {
            let why = "the frontier is held by \(i.leaderName) (\(i.leaderRegion.short))"
            push(.sovereign, 8 * k, why)
            push(.subsidy, (r == .us ? 8 : 4) * k, why)
            if r == .us { push(.exports, 6 * k, why) }
        }
        // A home lab near the frontier becomes a national champion.
        if let gap = i.homeGap[r.index], gap <= 6, i.leaderRegion != r || i.homeName[r.index] != i.leaderName {
            push(.subsidy, 4 * k, "\(i.homeName[r.index]) is \(Int(max(1, gap.rounded()))) months from the frontier")
        }
        // The US guards its lead against Chinese labs; China answers with self-reliance; allies follow the US.
        if r == .us, let gap = i.homeGap[Region.china.index], gap <= 9 {
            push(.exports, min(20, (9 - gap) * 2.5), "\(i.homeName[Region.china.index]) is \(Int(max(1, gap.rounded()))) months from the frontier")
        }
        if r == .china, i.usExports > 55 {
            let d = (i.usExports - 55) * 0.35
            push(.sovereign, d, "US export controls at \(Int(i.usExports.rounded()))")
            push(.subsidy, d, "US export controls at \(Int(i.usExports.rounded()))")
        }
        if r == .japanKorea || r == .uk || r == .eu, i.usExports > 55 {
            push(.exports, (i.usExports - 55) * (r == .eu ? 0.15 : 0.3), "aligning with US chip controls")
        }
        // A big AI economy wants more of it.
        let share = i.aiShare[r.index]
        if share > 3 { push(.subsidy, min(10, (share - 3) * 2), "AI is \(Fmt.trim(share, 1))% of GDP") }
        // How it sees you.
        let g = i.standing[r.index]
        if i.playerTop && g >= 65 {
            push(.data, -4, "courting \(i.playerName)")
            push(.visas, 3, "courting \(i.playerName)")
        } else if i.playerTop && g <= 35 {
            push(.safety, 4, "wary of labs like \(i.playerName)")
        }
        if i.playerTop && i.playerRegion == r && i.leaderName == i.playerName {
            push(.subsidy, 5 * k, "\(i.playerName) is a national champion")
        }
        // A little of each year's politics nobody models.
        let year = Int(i.y)
        for l in NationLever.allCases {
            levels[l.index] = clamp(levels[l.index] + (roll(s, "\(r.rawValue)|\(l.rawValue)|\(year)") - 0.5) * 6, 0, 100)
        }
        return (levels, pushes)
    }

    static func stance(_ v: [Double]) -> String {
        func l(_ x: NationLever) -> Double { v.indices.contains(x.index) ? v[x.index] : 40 }
        if l(.sovereign) >= 70 && l(.subsidy) >= 65 { return "Sovereign build-out" }
        if l(.safety) >= 62 && l(.data) >= 62 { return "Rules first" }
        if l(.exports) >= 65 { return "Tech fortress" }
        if l(.subsidy) >= 58 { return "Compute race" }
        if l(.visas) >= 62 && l(.energy) >= 65 { return "Open for builders" }
        if l(.safety) <= 25 && l(.data) <= 35 { return "Light touch" }
        return "Balanced"
    }

    // MARK: Set-up

    /// New games and older saves: replays each region's yearly reviews from 2017 (or a few years before the save)
    /// to this year, then sizes the economies. Idempotent.
    static func bootstrap(_ s: inout GameState) {
        guard !s.nations.ready else { return }
        var n = NationsState()
        n.ready = true
        n.strategies = Region.allCases.map { NationStrategy(levels: baseline($0, 2016.5), stance: "", reasons: [], reviewed: 2016) }
        n.economies = Region.allCases.map { _ in NationEconomy() }
        s.nations = n
        let now = s.date.ym.year
        for year in max(2017, now - 6)...now {
            let d = GameCalendar.date(year, 1, 1)
            updateEconomies(&s, at: d, live: false)
            review(&s, year: year, at: d, live: false)
        }
        updateEconomies(&s, at: s.date, live: false)
        // Rivals: where you lead now counts from today (they haven't seen it yet), and each lab starts on its natural specialty.
        refreshLeads(&s)
        s.nations.seenScores = s.labDomains["player"]?.v ?? []
        s.nations.seenAt = s.date
        for c in s.competitors where active(c, s) { pickInitialFocus(&s, c.id) }
        for m in s.models where m.released { s.nations.answered.insert("m|\(m.id.uuidString)") }
        for p in s.productLines { s.nations.answered.insert("p|\(p.id)") }
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        guard s.gameOver == nil else { return }
        guard s.world.ready else { return }
        guard s.nations.ready else { bootstrap(&s); return }
        let ym = s.date.ym
        updateEconomies(&s, at: s.date, live: true)
        if ym.month == 1 && s.nations.strategies.first.map({ $0.reviewed < ym.year }) ?? true {
            review(&s, year: ym.year, at: s.date, live: true)
        }
        rivalsMonthly(&s)
    }

    /// The national economies: AI's share of GDP follows adoption and policy, investment follows the market, automation
    /// follows the world's job losses; growth adds what AI brings and takes away what automation costs.
    static func updateEconomies(_ s: inout GameState, at date: Date, live: Bool) {
        let y = date.decimalYear
        let ym = date.ym
        let w = s.world
        var adoption = w.averageAdoption
        var pressure = w.jobPressure
        if !live, let snap = w.history.last(where: { $0.month <= date }) {
            adoption = snap.adoption.isEmpty ? adoption : snap.adoption.reduce(0, +) / Double(snap.adoption.count) / 100
            pressure = snap.looking / Sector.totalWorkforce * 100
        }
        // Adoption a year earlier, for how fast AI's share of the economy is growing.
        let yearAgo = GameCalendar.addMonths(date, -12)
        let before = w.history.last(where: { $0.month <= yearAgo }).map { $0.adoption.isEmpty ? 0 : $0.adoption.reduce(0, +) / Double($0.adoption.count) / 100 } ?? adoption
        if s.nations.economies.count != Region.allCases.count { s.nations.economies = Region.allCases.map { _ in NationEconomy() } }
        for r in Region.allCases {
            let st = s.nations.strategy(r)
            var e = s.nations.economies[r.index]
            let policy = 1 + 0.15 * (st.level(.subsidy) - 40) / 60 + 0.08 * (st.level(.sovereign) - 40) / 60 - 0.06 * (st.level(.data) - 50) / 50
            func share(_ a: Double) -> Double { (0.15 + 11 * pow(max(0, a), 1.25)) * aiIntensity(r) * policy }
            let shareTarget = share(adoption)
            let first = e.aiShare == 0
            e.aiShareYearAgo = share(before)
            e.aiShare = first || !live ? shareTarget : e.aiShare + (shareTarget - e.aiShare) * 0.15
            e.aiInvestment = Macro.marketSize(y) * 2.2 * r.weight * (1 + 0.35 * (st.level(.subsidy) - 40) / 60 + 0.25 * (st.level(.sovereign) - 40) / 60)
                * clamp(s.market.hype / 1.3, 0.6, 1.8)
            let autoTarget = pressure * exposure(r)
            e.automation = first || !live ? autoTarget : e.automation + (autoTarget - e.automation) * 0.2
            let shock = (roll(s, "gdp|\(r.rawValue)|\(ym.year)") - 0.5) * 0.6
            e.gdpGrowth = baseGrowth(r, y) + 0.6 * clamp(e.aiShare - e.aiShareYearAgo, -1, 4) - 0.25 * e.automation + shock
            s.nations.economies[r.index] = e
        }
    }

    /// January: every region reviews its strategy. Dials move part of the way to where the world pushes them (at most
    /// 14 points a year); each move of 3 points or more keeps its main reason.
    static func review(_ s: inout GameState, year: Int, at date: Date, live: Bool) {
        let i = inputs(s, at: date, live: live)
        var lines: [(region: Region, text: String, size: Double)] = []
        for r in Region.allCases {
            var st = s.nations.strategy(r)
            let (goal, pushes) = target(r, i, s)
            if st.levels.count != NationLever.allCases.count { st.levels = goal }
            var reasons: [(String, Double)] = []
            for l in NationLever.allCases {
                let old = st.levels[l.index]
                let new = clamp(old + clamp((goal[l.index] - old) * 0.6, -14, 14), 0, 100)
                st.levels[l.index] = new
                let d = new - old
                guard abs(d) >= 3 else { continue }
                let why = pushes.filter { $0.lever == l && ($0.delta > 0) == (d > 0) }.max { abs($0.delta) < abs($1.delta) }?.why
                    ?? (salience(i.y) < 0.95 && d > 0 ? "AI rising up the national agenda" : "settling back to its usual course")
                reasons.append(("\(l.title) \(Int(old.rounded())) → \(Int(new.rounded())): \(why)", abs(d)))
            }
            reasons.sort { $0.1 > $1.1 }
            let oldStance = st.stance
            st.stance = stance(st.levels)
            st.reasons = reasons.map(\.0)
            st.reviewed = year
            s.nations.strategies[r.index] = st
            let e = s.nations.economy(r)
            s.nations.years.append(NationYear(year: year, region: r.rawValue, levels: st.levels.map { ($0 * 10).rounded() / 10 },
                                              gdpGrowth: (e.gdpGrowth * 100).rounded() / 100, aiShare: (e.aiShare * 100).rounded() / 100,
                                              aiInvestment: e.aiInvestment, automation: (e.automation * 100).rounded() / 100, stance: st.stance))
            let text = (oldStance != st.stance && !oldStance.isEmpty ? "\(r.short) turns to \(st.stance.lowercased()). " : "")
                + (reasons.isEmpty ? "\(r.short) keeps its course (\(st.stance.lowercased()))." : reasons.prefix(2).map(\.0).joined(separator: "; ") + ".")
            note(&s, NationNote(date: date, who: r.rawValue, text: text, kind: "strategy"))
            lines.append((r, text, reasons.first?.1 ?? 0))
        }
        let keep = Region.allCases.count * 40
        if s.nations.years.count > keep { s.nations.years.removeFirst(s.nations.years.count - keep) }
        guard live else { return }
        // One news story a year: home first, then the biggest move elsewhere.
        let home = HQ.region(s)
        var picked = lines.filter { $0.region == home }
        if let other = lines.filter({ $0.region != home && $0.size >= 6 }).max(by: { $0.size < $1.size }) { picked.append(other) }
        guard !picked.isEmpty else { return }
        let big = (lines.first { $0.region == home }?.size ?? 0) >= 8
        Sim.news(&s, "National AI strategies for \(year)",
                 picked.map { "\($0.region.title): \($0.text)" }.joined(separator: " ") + " See Nations for what it means for you.",
                 .policy, important: big)
    }

    static func note(_ s: inout GameState, _ n: NationNote) {
        s.nations.timeline.insert(n, at: 0)
        s.nations.timeline.sort { $0.date > $1.date }
        if s.nations.timeline.count > 140 { s.nations.timeline.removeLast(s.nations.timeline.count - 140) }
    }

    // MARK: Effects on you

    /// Chips and cloud at home: subsidies make them cheaper; export controls aimed at your country make them dearer.
    static func chipFactor(_ s: GameState) -> Double {
        guard s.nations.ready else { return 1 }
        let home = HQ.region(s)
        var f = 1 - 0.08 * (s.nations.level(home, .subsidy) - 45) / 60
        let us = s.nations.level(.us, .exports)
        if home == .china { f += 0.15 * max(0, us - 40) / 60 } else if home != .us { f += 0.04 * max(0, us - 65) / 35 }
        return clamp(f, 0.9, 1.15)
    }

    /// Datacenter power in a location's region: energy policy sets how cheap and available it is.
    static func powerFactor(_ s: GameState, location: String) -> Double {
        guard s.nations.ready, let r = Region.of(location: location) else { return 1 }
        return clamp(1 - 0.1 * (s.nations.level(r, .energy) - 55) / 50, 0.88, 1.12)
    }

    /// Candidates on the job market at home: talent visas widen or narrow the pool.
    static func candidateFactor(_ s: GameState) -> Double {
        guard s.nations.ready else { return 1 }
        return clamp(1 + 0.25 * (s.nations.level(HQ.region(s), .visas) - 50) / 50, 0.8, 1.2)
    }

    /// Agency AI budgets in a region: sovereign-AI programmes spend more.
    static func agencyFactor(_ s: GameState, _ r: Region) -> Double {
        guard s.nations.ready else { return 1 }
        return clamp(1 + 0.3 * (s.nations.level(r, .sovereign) - 40) / 60, 0.85, 1.3)
    }

    /// Enterprise leads at home: a growing economy buys more.
    static func dealFactor(_ s: GameState) -> Double {
        guard s.nations.ready else { return 1 }
        let home = HQ.region(s)
        let e = s.nations.economy(home)
        return clamp(1 + 0.04 * (e.gdpGrowth - baseGrowth(home, s.year)), 0.92, 1.08)
    }

    /// A gentle pull on world adoption from all strategies together (−4% … +4% of the target).
    static func adoptionPull(_ s: GameState) -> Double {
        guard s.nations.ready else { return 0 }
        var sum = 0.0
        for r in Region.allCases {
            let st = s.nations.strategy(r)
            sum += r.weight * (0.05 * (st.level(.subsidy) - 55) / 60 + 0.03 * (st.level(.sovereign) - 55) / 60 - 0.04 * (st.level(.data) - 50) / 50)
        }
        return clamp(sum, -0.04, 0.04)
    }

    /// What the strategies do to you right now, one line each.
    static func effectsOnYou(_ s: GameState) -> [(title: String, value: String, why: String, good: Bool?)] {
        guard s.nations.ready else { return [] }
        let home = HQ.region(s)
        var out: [(String, String, String, Bool?)] = []
        func pct(_ f: Double) -> String { abs(f - 1) < 0.005 ? "no change" : "\(f < 1 ? "−" : "+")\(Fmt.trim(abs(f - 1) * 100, 0))%" }
        let chips = chipFactor(s)
        out.append(("Chips & cloud", pct(chips), "\(programme(home, .subsidy).prefix(1).uppercased() + programme(home, .subsidy).dropFirst()) at \(Int(s.nations.level(home, .subsidy).rounded()))"
                    + (home != .us ? "; US export controls at \(Int(s.nations.level(.us, .exports).rounded()))" : ""), chips < 0.995 ? true : (chips > 1.005 ? false : nil)))
        let cand = candidateFactor(s)
        out.append(("Candidates", pct(cand), "\(home.short) talent visas at \(Int(s.nations.level(home, .visas).rounded()))", cand > 1.005 ? true : (cand < 0.995 ? false : nil)))
        let regions = Set(s.sites.compactMap { Region.of(location: $0.locationID) })
        for r in Region.allCases where regions.contains(r) {
            let f = powerFactor(s, location: r.locations.first ?? "")
            out.append(("Power \(r.inPlace)", pct(f), "\(r.short) energy policy at \(Int(s.nations.level(r, .energy).rounded()))", f < 0.995 ? true : (f > 1.005 ? false : nil)))
        }
        let ag = agencyFactor(s, home)
        out.append(("Agency budgets at home", pct(ag), "\(programme(home, .sovereign).prefix(1).uppercased() + programme(home, .sovereign).dropFirst()) at \(Int(s.nations.level(home, .sovereign).rounded()))", ag > 1.005 ? true : (ag < 0.995 ? false : nil)))
        let deals = dealFactor(s)
        out.append(("Enterprise leads", pct(deals), "\(home.short) growth \(Fmt.trim(s.nations.economy(home).gdpGrowth, 1))% against a \(Fmt.trim(baseGrowth(home, s.year), 1))% trend", deals > 1.005 ? true : (deals < 0.995 ? false : nil)))
        let pull = adoptionPull(s)
        out.append(("World AI adoption", abs(pull) < 0.002 ? "no change" : "\(pull > 0 ? "+" : "−")\(Fmt.trim(abs(pull) * 100, 1))%", "Subsidies and sovereign programmes speed it; strict data rules slow it", pull > 0.002 ? true : (pull < -0.002 ? false : nil)))
        return out
    }
}

// MARK: - Rivals that specialise and respond

extension Nations {
    static func active(_ c: CompetitorState, _ s: GameState) -> Bool { RivalStrategy.isActive(c, s) }

    static func focus(_ s: GameState, _ lab: String) -> RivalFocus? { s.nations.focus[lab]?.rivalFocus }

    /// How naturally each specialisation comes to each lab (0–1).
    static func character(_ id: String) -> [RivalFocus: Double] {
        switch id {
        case "prometheus": return [.consumer: 0.9, .coding: 0.6, .enterprise: 0.5, .science: 0.3, .robotics: 0.3, .sovereign: 0.3, .openWeights: 0.1]
        case "deepgrove": return [.science: 0.9, .robotics: 0.7, .consumer: 0.6, .enterprise: 0.4, .coding: 0.4, .sovereign: 0.2, .openWeights: 0.3]
        case "halcyon": return [.coding: 0.9, .enterprise: 0.8, .science: 0.5, .sovereign: 0.3, .consumer: 0.2, .robotics: 0.1, .openWeights: 0]
        case "xenon": return [.consumer: 0.7, .robotics: 0.7, .sovereign: 0.6, .coding: 0.4, .science: 0.3, .enterprise: 0.2, .openWeights: 0.4]
        case "openweights": return [.openWeights: 1.0, .consumer: 0.6, .robotics: 0.4, .coding: 0.3, .science: 0.3, .enterprise: 0.2, .sovereign: 0.1]
        case "dragonlake": return [.openWeights: 0.9, .coding: 0.6, .sovereign: 0.5, .science: 0.4, .consumer: 0.4, .robotics: 0.3, .enterprise: 0.2]
        case "sirocco": return [.sovereign: 0.8, .enterprise: 0.7, .openWeights: 0.6, .coding: 0.4, .consumer: 0.3, .science: 0.3, .robotics: 0.1]
        case "aletheia": return [.science: 0.9, .coding: 0.4, .enterprise: 0.1, .sovereign: 0.1, .consumer: 0, .robotics: 0.1, .openWeights: 0]
        default:
            if let spec = CompetitorCatalog.spec(id) {
                let p = spec.personality
                if spec.kind == .sovereign {
                    return [.sovereign: 0.9, .enterprise: 0.4, .science: 0.4, .coding: 0.3, .openWeights: 0.3, .consumer: 0.2, .robotics: 0.2]
                }
                return [.consumer: p[RivalPlay.consumer.rawValue] ?? 0.3, .enterprise: p[RivalPlay.enterprise.rawValue] ?? 0.3,
                        .coding: p[RivalPlay.agents.rawValue] ?? 0.3, .openWeights: p[RivalPlay.openGambit.rawValue] ?? 0.2,
                        .science: 0.4, .robotics: 0.3, .sovereign: 0.2]
            }
            return [:]
        }
    }

    static func home(_ lab: String) -> Region { AdvancedProjects.labRegion(lab) }

    /// One reason behind a specialisation, and how much it weighed.
    struct Part {
        var weight: Double
        var text: String
    }

    /// Every specialisation the lab could pick, scored, with the reasons behind each.
    static func options(_ s: GameState, _ lab: String) -> [(focus: RivalFocus, score: Double, parts: [Part])] {
        let ch = character(lab)
        let v = s.labDomains[lab]
        let r = home(lab)
        let st = s.nations.strategy(r)
        let name = CompetitorCatalog.def(lab).name
        let current = focus(s, lab)
        let avg = v.map { $0.v.reduce(0, +) / Double(max(1, $0.v.count)) } ?? 0
        let seen = DomainScores(s.nations.seenScores)
        let seenAt = s.nations.seenAt ?? s.date
        var out: [(RivalFocus, Double, [Part])] = []
        for f in RivalFocus.allCases {
            var parts: [Part] = []
            let c = ch[f] ?? 0.15
            parts.append(Part(weight: 0.6 * c, text: c >= 0.7 ? "it's what \(name) is built for" : "it fits \(World.possessive(name)) character"))
            // Comparative advantage: its scores there against its own average.
            if let v {
                let here = f.domains.map { v[$0] }.reduce(0, +) / Double(f.domains.count)
                let edge = clamp((here - avg) / 4, -0.4, 0.5)
                if f == .openWeights {
                    if CompetitorCatalog.def(lab).openWeights { parts.append(Part(weight: 0.5, text: "it already ships open weights")) }
                } else if abs(edge) >= 0.05 {
                    let names = f.domains.map { $0.short.lowercased() }.joined(separator: " and ")
                    parts.append(Part(weight: edge, text: edge > 0 ? "it's strongest there (\(names) \(Int(here.rounded())) against \(Int(avg.rounded())) across the board)"
                                                         : "it's weaker there than elsewhere"))
                }
            }
            // The home nation's strategy.
            var hw: Double
            let ht: String
            switch f {
            case .science: hw = 0.4 * (st.level(.subsidy) - 40) / 60; ht = programme(r, .subsidy)
            case .sovereign: hw = 0.6 * (st.level(.sovereign) - 40) / 60; ht = programme(r, .sovereign)
            case .consumer: hw = -0.35 * (st.level(.data) - 50) / 50; ht = programme(r, .data)
            case .enterprise: hw = 0.3 * (st.level(.safety) - 40) / 60; ht = programme(r, .safety)
            case .openWeights:
                hw = -0.3 * (st.level(.safety) - 40) / 60 + (r == .china ? 0.2 * (s.nations.level(.us, .exports) - 50) / 50 : 0)
                ht = r == .china ? "US export controls (open weights route around them)" : programme(r, .safety)
            case .robotics: hw = 0.3 * (st.level(.energy) - 50) / 50 + 0.15 * (st.level(.subsidy) - 40) / 60; ht = "\(r.short) power and industrial subsidies"
            case .coding: hw = 0.3 * (st.level(.visas) - 50) / 50; ht = programme(r, .visas)
            }
            hw *= 1.5
            if abs(hw) >= 0.05 {
                let plural = ht.hasSuffix("s") || ht.hasSuffix(")")
                parts.append(Part(weight: hw, text: hw > 0 ? "\(ht) \(plural ? "favour" : "favours") it" : "\(ht) \(plural ? "work" : "works") against it"))
            }
            // You, as they saw you a quarter ago.
            if !s.nations.seenScores.isEmpty, let v {
                let d = f.domains[0]
                let gap = seen[d] - v[d]
                if let since = s.nations.leadSince[d.rawValue], since <= seenAt {
                    let quarters = GameCalendar.daysBetween(since, seenAt) / 91
                    if quarters >= 2 && gap <= 10 {
                        // Worth fighting for when the lab is close behind; the older your lead, the more it's worth.
                        let close = clamp(1 - gap / 12, 0.2, 1)
                        parts.append(Part(weight: 0.12 * Double(min(quarters, 5)) * close, text: "your \(d.label.lowercased()) lead is \(quarters) quarters old"))
                    } else if quarters >= 2 {
                        parts.append(Part(weight: -0.15, text: "your \(d.label.lowercased()) lead is too wide to fight"))
                    }
                } else if seen[d] + 3 < v[d] && !f.products.contains(where: { p in s.productLines.contains { $0.id == p } }) {
                    parts.append(Part(weight: 0.15, text: "you're weak in \(d.label.lowercased())"))
                }
            }
            if f == current { parts.append(Part(weight: 0.3, text: "it has built a team for it")) }
            let month = s.date.ym.year * 12 + s.date.ym.month
            let noise = (roll(s, "focus|\(lab)|\(month)|\(f.rawValue)") - 0.5) * 0.16
            out.append((f, parts.reduce(noise) { $0 + $1.weight }, parts))
        }
        return out.sorted { $0.1 > $1.1 }
    }

    /// "Halcyon is moving into science because your science lead is 2 quarters old and EU research grants favour it."
    static func explain(_ lab: String, _ f: RivalFocus, _ parts: [Part], moving: Bool) -> String {
        let name = CompetitorCatalog.def(lab).name
        let top = parts.filter { $0.weight > 0.02 && $0.text != "it has built a team for it" }.sorted { $0.weight > $1.weight }.prefix(2).map(\.text)
        let lead = moving ? "\(name) is moving into \(f.noun)" : "\(name) specialises in \(f.noun)"
        return top.isEmpty ? lead + "." : lead + " because " + top.joined(separator: " and ") + "."
    }

    static func pickInitialFocus(_ s: inout GameState, _ lab: String) {
        guard s.nations.focus[lab]?.rivalFocus == nil, let best = options(s, lab).first else { return }
        var st = RivalFocusState()
        st.focus = best.focus.rawValue
        st.since = s.date
        st.reason = explain(lab, best.focus, best.parts, moving: false)
        st.scores = Dictionary(uniqueKeysWithValues: options(s, lab).map { ($0.focus.rawValue, ($0.score * 100).rounded() / 100) })
        st.nextReview = GameCalendar.addMonths(s.date, 6 + Int(roll(s, "firstreview|\(lab)") * 4))
        s.nations.focus[lab] = st
    }

    /// Where you lead each domain, and since when; and (each quarter) the scores rivals have had time to read.
    static func refreshLeads(_ s: inout GameState) {
        guard let mine = s.labDomains["player"] else { s.nations.leadSince = [:]; return }
        let alive = Set(s.competitors.filter(\.alive).map(\.id))
        for d in CapDomain.allCases {
            var best = 0.0
            for (lab, v) in s.labDomains where lab != "player" && alive.contains(lab) { best = max(best, v[d]) }
            if mine[d] > best {
                if s.nations.leadSince[d.rawValue] == nil { s.nations.leadSince[d.rawValue] = s.date }
            } else {
                s.nations.leadSince[d.rawValue] = nil
            }
        }
    }

    static func rivalsMonthly(_ s: inout GameState) {
        refreshLeads(&s)
        if (s.date.ym.month - 1) % 3 == 0 || s.nations.seenAt == nil {
            s.nations.seenScores = s.labDomains["player"]?.v ?? []
            s.nations.seenAt = s.date
        }
        for c in s.competitors {
            guard active(c, s) else { continue }
            if s.nations.focus[c.id]?.rivalFocus == nil { pickInitialFocus(&s, c.id); continue }
            if let next = s.nations.focus[c.id]?.nextReview, next <= s.date, s.year >= 2020 { reviewFocus(&s, c.id) }
        }
        let gone = Set(s.competitors.filter { !$0.alive }.map(\.id))
        for id in gone { s.nations.focus[id] = nil }
        focusEffects(&s)
        queueReactions(&s)
        runReactions(&s)
        s.nations.pushes = s.nations.pushes.filter { $0.value > s.date }
    }

    /// A lab re-reads its position. A better specialisation has to stay better for a quarter before it moves.
    static func reviewFocus(_ s: inout GameState, _ lab: String) {
        guard var st = s.nations.focus[lab], let cur = st.rivalFocus else { return }
        let opts = options(s, lab)
        st.scores = Dictionary(uniqueKeysWithValues: opts.map { ($0.focus.rawValue, ($0.score * 100).rounded() / 100) })
        let month = s.date.ym.year * 12 + s.date.ym.month
        guard let best = opts.first, let mine = opts.first(where: { $0.focus == cur }) else { return }
        let name = CompetitorCatalog.def(lab).name
        let count = s.competitors.first { $0.id == lab }?.releaseCount ?? 0
        if best.focus == cur || best.score - mine.score < 0.12 {
            st.considering = ""
            st.consideringSince = nil
            st.reason = explain(lab, cur, mine.parts, moving: false)
            st.nextReview = GameCalendar.addMonths(s.date, 6 + Int(roll(s, "review|\(lab)|\(month)") * 4))
        } else if st.considering == best.focus.rawValue, let since = st.consideringSince, GameCalendar.daysBetween(since, s.date) >= 80 {
            // The evidence held for a quarter: it commits.
            let why = explain(lab, best.focus, best.parts, moving: true)
            st.focus = best.focus.rawValue
            st.since = s.date
            st.reason = why
            st.considering = ""
            st.consideringSince = nil
            st.nextReview = GameCalendar.addMonths(s.date, 9 + Int(roll(s, "review|\(lab)|\(month)") * 4))
            s.nations.focus[lab] = st
            rivalNote(&s, lab, "\(why) It was \(cur.noun) before.", kind: "focus")
            if let i = s.competitors.firstIndex(where: { $0.id == lab }) {
                s.competitors[i].playLog.insert("\(s.date.gameMonth): Specialises in \(best.focus.noun) — \(why)", at: 0)
                if s.competitors[i].playLog.count > 8 { s.competitors[i].playLog.removeLast() }
            }
            let mineToo = best.focus.products.filter { p in s.productLines.contains { $0.id == p } }.map(ProductLines.name)
            Sim.news(&s, "\(name) moves into \(best.focus.noun)",
                     "\(why) \(best.focus.effect)\(mineToo.isEmpty ? "" : " Expect a fight for your \(mineToo.joined(separator: " and ")).")",
                     .competitor, important: !mineToo.isEmpty)
            return
        } else {
            // Weighing it: the rumour mill hears first.
            if st.considering != best.focus.rawValue {
                st.considering = best.focus.rawValue
                st.consideringSince = s.date
                RivalIntel.add(&s, lab, count, kind: "strategy", reliability: RivalIntel.quality(s) > 0.45 ? .credible : .speculative,
                               title: "\(name) is weighing a move into \(best.focus.noun)",
                               body: explain(lab, best.focus, best.parts, moving: false).replacingOccurrences(of: "specialises in", with: "would specialise in")
                                + " If the case still holds next quarter, it moves.")
            }
            st.nextReview = GameCalendar.addMonths(s.date, 3)
        }
        s.nations.focus[lab] = st
    }

    static func rivalNote(_ s: inout GameState, _ lab: String, _ text: String, kind: String) {
        s.nations.rivalLog.insert(NationNote(date: s.date, who: lab, text: text, kind: kind), at: 0)
        if s.nations.rivalLog.count > 60 { s.nations.rivalLog.removeLast(s.nations.rivalLog.count - 60) }
    }

    /// Ongoing effects of specialisations on the market: open-weights specialists keep prices down, consumer
    /// specialists build their brands.
    static func focusEffects(_ s: inout GameState) {
        var open = 0
        for i in s.competitors.indices where active(s.competitors[i], s) {
            switch focus(s, s.competitors[i].id) {
            case .openWeights: open += 1
            case .consumer: s.competitors[i].brand = min(100, s.competitors[i].brand + 0.15)
            default: break
            }
        }
        if open > 0 { s.market.apiPricePressure = max(0.5, s.market.apiPricePressure - 0.001 * Double(min(2, open))) }
    }

    // MARK: Hooks

    /// How much keener a lab is to launch a product in its specialty.
    static func appetiteFactor(_ s: GameState, lab: String, product: String) -> Double {
        (focus(s, lab)?.products.contains(product) ?? false) ? 1.4 : 1
    }

    /// Extra quality (domain points) a specialist puts into its product, ramping up over its first months, plus any
    /// push it made to answer one of your launches.
    static func productBonus(_ s: GameState, lab: String, product: String) -> Double {
        var b = 0.0
        if let st = s.nations.focus[lab], let f = st.rivalFocus, f.products.contains(product) {
            let months = Double(GameCalendar.daysBetween(st.since ?? s.date, s.date)) / 30.4
            b += min(1.5, 0.5 + months * 0.2)
        }
        if let until = s.nations.pushes["\(lab)|\(product)"], until > s.date { b += 1 }
        return b
    }

    /// Extra interest and technical score when a lab bids for an agency's work.
    static func bidBoost(_ s: GameState, lab: String, agency: AgencyDef) -> (interest: Double, tech: Double) {
        switch focus(s, lab) {
        case .sovereign: home(lab) == agency.region ? (0.3, 2) : (0.05, 0)
        case .enterprise: (0.08, 0.5)
        case .science: [.health, .research, .nationalLab, .energy].contains(agency.kind) ? (0.12, 1) : (0, 0)
        case .coding: [.cyber, .digital].contains(agency.kind) ? (0.1, 1) : (0, 0)
        default: (0, 0)
        }
    }

    // MARK: Answers to your launches

    /// New launches of yours get an answer from the specialist they threaten — weeks later, never the same day.
    static func queueReactions(_ s: inout GameState) {
        guard s.year >= 2021 else { return }
        // Models: the first lab whose specialty your model now leads answers it.
        for m in s.models where m.released && !m.retired && !s.nations.answered.contains("m|\(m.id.uuidString)") {
            s.nations.answered.insert("m|\(m.id.uuidString)")
            let when = m.releaseDate ?? m.created
            guard GameCalendar.daysBetween(when, s.date) <= 60, let v = s.domainScores[m.id.uuidString] else { continue }
            var best: (lab: String, edge: Double, domain: CapDomain)? = nil
            for c in s.competitors where active(c, s) && ready(s, c.id) {
                guard let f = focus(s, c.id), let theirs = s.labDomains[c.id] else { continue }
                let d = f.domains[0]
                let edge = v[d] - theirs[d]
                guard edge > 0, best.map({ edge > $0.edge }) ?? true else { continue }
                best = (c.id, edge, d)
            }
            guard let b = best, let c = s.competitors.first(where: { $0.id == b.lab }) else { continue }
            let researchers = s.employees.filter { $0.role == .researcher && $0.talent != .loyal }.count
            let rich = c.cash > 1e9 || RivalEconomy.parent(c, s) != nil
            let kind: String
            if c.latest != nil && !RivalStrategy.controlsPrice(c) && (c.latest?.price ?? 0) > 0 && b.edge > 0 {
                kind = researchers >= 6 && rich && roll(s, "poach|\(m.id.uuidString)") < 0.35 ? "poach" : "price"
            } else {
                kind = "follow"
            }
            schedule(&s, RivalReaction(lab: b.lab, kind: kind, due: due(s, key: m.id.uuidString, from: when), ref: b.domain.rawValue,
                                       launch: m.name, launched: when))
        }
        // Product lines: the keenest specialist in that line answers.
        for p in s.productLines where !s.nations.answered.contains("p|\(p.id)") {
            s.nations.answered.insert("p|\(p.id)")
            guard GameCalendar.daysBetween(p.launched, s.date) <= 60 else { continue }
            let labs = s.competitors.filter { active($0, s) && ready(s, $0.id) && (focus(s, $0.id)?.products.contains(p.id) ?? false) }
            guard let lab = labs.max(by: { $0.brand < $1.brand }) else { continue }
            schedule(&s, RivalReaction(lab: lab.id, kind: "follow", due: due(s, key: "p|\(p.id)", from: p.launched), ref: p.id,
                                       launch: ProductLines.name(p.id), launched: p.launched, product: p.id))
        }
    }

    /// A lab answers at most one launch every five months, and has one answer in hand at a time.
    static func ready(_ s: GameState, _ lab: String) -> Bool {
        if s.nations.reactions.contains(where: { $0.lab == lab }) { return false }
        guard let last = s.nations.focus[lab]?.lastReaction else { return true }
        return GameCalendar.daysBetween(last, s.date) >= 150
    }

    static func due(_ s: GameState, key: String, from: Date) -> Date {
        GameCalendar.addDays(from, 40 + Int(roll(s, "react|\(key)") * 50))
    }

    static func schedule(_ s: inout GameState, _ r: RivalReaction) {
        s.nations.reactions.append(r)
        let today = s.date
        s.nations.focus[r.lab]?.lastReaction = today
    }

    /// Answers that are due land, one a month at most (the rest wait their turn).
    static func runReactions(_ s: inout GameState) {
        let alive = Set(s.competitors.filter(\.alive).map(\.id))
        s.nations.reactions.removeAll { !alive.contains($0.lab) }
        guard let k = s.nations.reactions.indices.filter({ s.nations.reactions[$0].due <= s.date }).min(by: { s.nations.reactions[$0].due < s.nations.reactions[$1].due }) else { return }
        let r = s.nations.reactions.remove(at: k)
        guard let i = s.competitors.firstIndex(where: { $0.id == r.lab }), let f = focus(s, r.lab) else { return }
        let name = s.competitors[i].def.name
        let weeks = max(1, GameCalendar.daysBetween(r.launched, s.date) / 7)
        let since = s.nations.focus[r.lab]?.since.map { " since \($0.gameMonth)" } ?? ""
        let domain = CapDomain(rawValue: r.ref).map { " beat its best \($0.label.lowercased()) score" } ?? " went straight at it"
        let why = "\(f.title) is \(World.possessive(name)) specialty\(since), and your \(r.launch)\(r.product.isEmpty ? domain : " went straight at it")."
        var headline = ""
        switch r.kind {
        case "price":
            s.competitors[i].priceCut = min(0.45, max(s.competitors[i].priceCut, 0.05) + 0.08)
            headline = "\(name) cuts API prices to answer \(r.launch)"
            Sim.news(&s, headline, "\(weeks) weeks after you shipped \(r.launch), \(name) cut its API prices by about 8%. \(why) Its customers are cheaper to keep than to win back.",
                     .competitor)
        case "poach":
            headline = "\(name) goes after one of your researchers"
            poach(&s, i, launch: r.launch, why: why)
        default:
            if !r.product.isEmpty, let p = ProductLines.byID[r.product] {
                if !s.rivalProducts.contains(where: { $0.lab == r.lab && $0.product == p.id }), let v = s.labDomains[r.lab],
                   p.needs.allSatisfy({ v[$0.0] >= $0.1 - 6 }) {
                    s.rivalProducts.append(RivalProduct(lab: r.lab, product: p.id, launched: s.date, quality: ProductLines.quality(p, v)))
                    headline = "\(name) fast-follows with \(ProductLines.rivalProductName(p, lab: r.lab))"
                    Sim.news(&s, headline, "\(weeks) weeks after your \(p.name) launch, \(name) shipped its own. \(why)", .competitor, important: true)
                } else {
                    headline = "\(name) doubles down on \(p.name)"
                    Sim.news(&s, headline, "\(weeks) weeks after your launch, \(name) moved more engineers onto its \(ProductLines.rivalProductName(p, lab: r.lab)) for the next year. \(why)", .competitor)
                }
                s.nations.pushes["\(r.lab)|\(p.id)"] = GameCalendar.addMonths(s.date, 12)
            } else {
                for p in f.products { s.nations.pushes["\(r.lab)|\(p)"] = GameCalendar.addMonths(s.date, 9) }
                headline = "\(name) answers \(r.launch)"
                Sim.news(&s, headline, "\(weeks) weeks after you shipped \(r.launch), \(name) put its best team on \(f.noun)\(f.products.isEmpty ? "" : ": its \(f.products.map(ProductLines.name).joined(separator: " and ")) products get stronger for the next nine months"). \(why)",
                         .competitor)
            }
        }
        rivalNote(&s, r.lab, "\(headline). \(why)", kind: "reaction")
        s.competitors[i].playLog.insert("\(s.date.gameMonth): Answered your \(r.launch) — \(headline.replacingOccurrences(of: "\(name) ", with: ""))", at: 0)
        if s.competitors[i].playLog.count > 8 { s.competitors[i].playLog.removeLast() }
    }

    static let poachKind = "rival_poach"

    /// One researcher gets an offer; you can match it (inbox, never stops the clock).
    static func poach(_ s: inout GameState, _ i: Int, launch: String, why: String) {
        let lab = s.competitors[i]
        guard s.decisions.count < 3, !s.decisions.contains(where: { $0.kind == poachKind }),
              let target = s.employees.filter({ $0.role == .researcher && $0.talent != .loyal }).max(by: { $0.skill < $1.skill }) else { return }
        let raise = (target.salary * 0.35 / 1000).rounded() * 1000
        Events.addDecision(&s, kind: poachKind, title: "\(lab.def.name) offers \(target.name) a job",
                           body: "\(why) It wants the people behind \(launch): \(target.name) (skill \(Int(target.skill))) has an offer at 35% more pay.",
                           image: nil,
                           options: [DecisionOption(label: "Match it (+\(Fmt.money(raise))/yr)", detail: "\(target.name) stays, a little happier."),
                                     DecisionOption(label: "Let them go", detail: "Lose \(target.name). \(lab.def.name)'s team gets stronger.")],
                           amount: raise, ref: target.id.uuidString + "|" + lab.id)
    }

    static func resolvePoach(_ s: inout GameState, _ d: Decision, option: Int) {
        let parts = d.ref.split(separator: "|").map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[0]), let e = s.employees.firstIndex(where: { $0.id == id }) else { return }
        let lab = CompetitorCatalog.def(parts[1]).name
        if option == 0 {
            s.employees[e].salary += d.amount
            s.employees[e].morale = min(100, s.employees[e].morale + 8)
            Sim.news(&s, "\(s.employees[e].name) stays", "You matched \(lab)'s offer.", .company, good: true)
        } else {
            let who = s.employees[e].name
            s.employees.remove(at: e)
            if let i = s.competitors.firstIndex(where: { $0.id == parts[1] }) { s.competitors[i].brand = min(100, s.competitors[i].brand + 1) }
            Sim.news(&s, "\(who) joins \(lab)", "You let the offer stand.", .company, good: false)
        }
    }
}
