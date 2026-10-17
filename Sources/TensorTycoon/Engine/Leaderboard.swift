import Foundation

enum Leaderboard {
    struct Entry: Identifiable, Equatable {
        var id: String
        var lab: String
        var labID: String
        var model: String
        var date: Date
        var c: Double
        var profile: ModelProfile
        var index: Double
        var arena: Double
        var horizon: Double
        var price: Double?
        var tps: Double?
        var open: Bool
        var isPlayer: Bool
        var reasoning: Bool
        var released: Bool
        var paramsB: Double?

        func score(_ b: Benchmark) -> Double { BenchmarkCatalog.cachedScore(b, profile) }
        /// Capability on the fixed scale (GPT-4 = 100, +10 = 10× effective compute): comparable across years.
        var capability: Double { BenchmarkCatalog.capability(profile) }
    }

    // MARK: Profiles

    static func profile(_ m: AIModel) -> ModelProfile {
        ModelProfile(key: m.id.uuidString, c: m.c, reasoning: m.reasoningBoost, code: m.codeBoost, agent: m.agentBoost,
                     vision: m.design.vision, contextK: m.design.contextK, tuning: m.tuned ? 1 : 0,
                     chat: m.chatSkill, safety: m.safety, lang: m.langSkill, longctx: m.longctxSkill, vis: m.visSkill, audio: m.design.audio)
    }

    /// The profile of a frontier lab's model at a given date (also used to calibrate benchmarks).
    static func frontierProfile(_ y: Double, key: String, c: Double, reasoningModel: Bool) -> ModelProfile {
        // After mid-2025 the labs keep researching too: their skills keep growing (to about 70% of what a lab that
        // researched everything published would have — a strong player's level), instead of freezing at 2025 levels
        // while yours keep climbing.
        let late = max(0, y - 2025.4)
        let reasoning = (reasoningModel ? 0.6 : (y > 2022.1 ? 0.1 : 0))
            + (reasoningModel ? interpolate([(0, 0), (0.6, 0.45), (1.6, 1.2), (2.6, 1.6), (4.6, 1.9), (10, 2.1)], at: late) : 0)
        let code = (y > 2024.5 ? 0.15 : 0) + (y > 2025.2 ? 0.15 : 0) + interpolate([(0, 0), (1.6, 0.2), (10, 0.25)], at: late)
        let agent = (y > 2025.0 ? 0.3 : (y > 2023.5 ? 0.1 : 0))
            + interpolate([(0, 0), (0.6, 0.35), (1.6, 0.7), (2.6, 1.0), (4.6, 1.25), (10, 1.4)], at: late)
        let chat = (y < 2022.0 ? -0.6 : (y < 2022.9 ? 0.3 : (y < 2024.0 ? 0.8 : (y < 2025.0 ? 1.0 : 1.2))))
            + interpolate([(0, 0), (2, 0.05)], at: late)
        let safety = interpolate([(2016, 20), (2022.9, 50), (2024, 60), (2026, 70), (2030, 78)], at: y)
        let lang = interpolate([(2016, 0), (2023, 0.15), (2025, 0.3), (2030, 0.4)], at: y)
        let longctx = y < 2024.1 ? 0 : (y < 2025 ? 0.1 : 0.2)
        let ctx = y > 2025 ? 1000 : (y > 2024 ? 128 : (y > 2023 ? 32 : (y > 2020 ? 2 : 1)))
        return ModelProfile(key: key, c: c, reasoning: reasoning, code: code, agent: agent, vision: y > 2023.2, contextK: ctx, tuning: 0,
                            chat: chat, safety: safety, lang: lang, longctx: longctx, vis: y < 2023.95 ? 0 : 0.1, audio: y > 2024.37)
    }

    /// The world frontier as a model: the curve's capability with a frontier lab's skills that year. The yardstick the
    /// index set and new benchmarks are pitched against (it doesn't move when one lab races ahead).
    static func frontierReference(_ y: Double) -> ModelProfile {
        frontierProfile(y, key: "frontier-reference", c: Macro.frontier(y), reasoningModel: y >= 2024.7)
    }

    static func profile(_ m: CompetitorModel, def: CompetitorDef, boost: RivalBoost = RivalBoost()) -> ModelProfile {
        let y = m.date.decimalYear
        var p = frontierProfile(y, key: m.id.uuidString, c: m.c, reasoningModel: m.reasoning)
        let trait = Competitors.trait(def.id)
        p.code += def.codeBonus + boost.code
        p.reasoning += boost.reasoning + (m.reasoning ? trait.reasoning : 0)
        p.agent += trait.agent + boost.agent
        p.chat += trait.chat + boost.chat
        p.lang += trait.lang + boost.lang
        p.longctx += trait.longctx + boost.longctx
        p.vis += trait.vis
        p.safety = clamp(p.safety + trait.safety, 0, 100)
        p.audio = p.audio && trait.audio
        return p
    }

    static func competitorArena(_ m: CompetitorModel) -> Double {
        let y = m.date.decimalYear
        let bonus: Double = y < 2022.0 ? -60 : (y < 2023.5 ? 55 : 85)
        return BenchmarkCatalog.arenaElo(c: m.c, bonus: bonus) + (BenchmarkCatalog.hashUnit(m.id.uuidString + "arena") - 0.5) * 20
    }

    static func playerArena(_ m: AIModel) -> Double {
        BenchmarkCatalog.arenaElo(c: m.c, bonus: m.arenaBonus) + (BenchmarkCatalog.hashUnit(m.id.uuidString + "arena") - 0.5) * 20
    }

    static func indexSet(_ s: GameState) -> [Benchmark] {
        BenchmarkCatalog.indexSet(s.benchmarks, date: s.date, saturated: s.benchSaturated)
    }

    // MARK: Entries

    static func entries(_ s: GameState, set: [Benchmark]? = nil, includeUnreleased: Bool = true) -> [Entry] {
        let set = set ?? indexSet(s)
        var out: [Entry] = []
        out.reserveCapacity(120)
        for comp in s.competitors {
            let def = comp.def
            for m in comp.models + comp.openModels {
                let p = profile(m, def: def, boost: Competitors.boost(s, comp.id, at: m.date.decimalYear))
                out.append(Entry(id: m.id.uuidString, lab: def.name, labID: comp.id, model: m.name, date: m.date, c: m.c, profile: p,
                                 index: BenchmarkCatalog.index(p, set: set), arena: competitorArena(m),
                                 horizon: BenchmarkCatalog.taskHorizonMinutes(p), price: m.price * (1 - comp.priceCut), tps: m.tps,
                                 open: m.open, isPlayer: false, reasoning: m.reasoning, released: true, paramsB: m.paramsB))
            }
        }
        for m in s.models where (includeUnreleased || m.released) && !m.preview || (m.preview && m.released) {
            let p = profile(m)
            out.append(Entry(id: m.id.uuidString, lab: s.companyName, labID: "player", model: m.name, date: m.created, c: m.c, profile: p,
                             index: BenchmarkCatalog.index(p, set: set), arena: playerArena(m),
                             horizon: BenchmarkCatalog.taskHorizonMinutes(p), price: m.released && m.api ? m.apiPrice : nil,
                             tps: m.tps > 0 ? m.tps : nil, open: m.openWeights, isPlayer: true, reasoning: m.reasoning,
                             released: m.released, paramsB: m.design.paramsB))
        }
        return out.sorted { $0.c > $1.c }
    }

    /// World rank of one of your models (see `labRank`).
    static func rank(of id: UUID, in s: GameState) -> Int {
        let all = entries(s)
        guard let me = all.first(where: { $0.id == id.uuidString }) else { return all.count + 1 }
        return labRank(index: me.index, board: all, gone: goneLabs(s))
    }

    // MARK: Labs

    /// Labs that have left the race (acquired or bankrupt): their models stay on the board, but they no longer rank.
    static func goneLabs(_ s: GameState) -> Set<String> {
        Set(s.competitors.filter { $0.acquired || $0.bankrupt }.map(\.id))
    }

    /// "#N worldwide" everywhere: 1 + the number of rival labs still in the race whose best released model beats this
    /// index. Labs, not models, so one lab's back catalogue doesn't push you down (the monthly briefing counts the same way).
    static func labRank(index: Double, board: [Entry], gone: Set<String>) -> Int {
        var ahead = Set<String>()
        for e in board where !e.isPlayer && e.released && e.index > index && !gone.contains(e.labID) { ahead.insert(e.labID) }
        return ahead.count + 1
    }

    /// One lab in the race.
    struct LabRow: Identifiable {
        var id: String { labID }
        var labID: String
        var lab: String
        var isPlayer: Bool
        /// Its best released model by Intelligence Index (yours: your best unreleased one until something ships).
        var flagship: Entry
        /// Every model of the lab on the board, newest first.
        var models: [Entry]
        /// Place among labs still in the race, by flagship index (0: not ranked, i.e. left the race or nothing released).
        var rank: Int
        /// Where its flagship of a quarter ago would rank today. Same yardstick, so only real releases move it.
        var rankQuarterAgo: Int?
        var capabilityQuarterAgo: Double?
        var lastRelease: Date?
        var gone: Bool
    }

    /// The board grouped into labs: one pass over entries the caller already has (no re-scoring), so views can call it per frame.
    static func labs(_ board: [Entry], state s: GameState) -> [LabRow] {
        let gone = goneLabs(s)
        let quarterAgo = GameCalendar.addDays(s.date, -91)
        var byLab: [String: [Entry]] = [:]
        var order: [String] = []
        for e in board {
            if byLab[e.labID] == nil { order.append(e.labID) }
            byLab[e.labID, default: []].append(e)
        }
        var rows: [LabRow] = []
        var then: [Double?] = []
        for id in order {
            let models = (byLab[id] ?? []).sorted { $0.date > $1.date }
            let released = models.filter(\.released)
            guard let flagship = released.max(by: { $0.index < $1.index }) ?? models.max(by: { $0.index < $1.index }) else { continue }
            let old = released.filter { $0.date <= quarterAgo }
            rows.append(LabRow(labID: id, lab: flagship.lab, isPlayer: flagship.isPlayer, flagship: flagship, models: models, rank: 0,
                               rankQuarterAgo: nil, capabilityQuarterAgo: old.map(\.capability).max(),
                               lastRelease: released.map(\.date).max(), gone: gone.contains(id)))
            then.append(old.map(\.index).max())
        }
        let racing = rows.indices.filter { !rows[$0].gone && rows[$0].flagship.released }
        for i in racing {
            rows[i].rank = 1 + racing.filter { rows[$0].flagship.index > rows[i].flagship.index }.count
            if let v = then[i] {
                rows[i].rankQuarterAgo = 1 + racing.filter { (then[$0] ?? -1) > v }.count
            }
        }
        return rows
    }
}

// MARK: - The race, for the leaderboard and dashboard (cheap: built from a board the caller already has)

extension Leaderboard {
    /// Leaderboard filters: open vs closed weights, reasoning models, and a price band set against frontier pricing that year.
    struct Filter: Equatable {
        enum Weights: String, CaseIterable, Identifiable {
            case any, open, closed
            var id: String { rawValue }
        }
        enum Band: String, CaseIterable, Identifiable {
            case any, budget, mid, premium
            var id: String { rawValue }
        }

        var weights: Weights = .any
        var reasoningOnly = false
        var band: Band = .any
        /// Budget is under `low`, premium from `high` (USD per 1M tokens): a quarter of, and the full, frontier price.
        var low: Double
        var high: Double

        init(weights: Weights = .any, reasoningOnly: Bool = false, band: Band = .any, year: Double) {
            self.weights = weights
            self.reasoningOnly = reasoningOnly
            self.band = band
            high = Macro.frontierPrice(year)
            low = high * 0.25
        }

        var isActive: Bool { weights != .any || reasoningOnly || band != .any }

        func includes(_ e: Entry) -> Bool {
            if weights == .open && !e.open { return false }
            if weights == .closed && e.open { return false }
            if reasoningOnly && !e.reasoning { return false }
            guard band != .any else { return true }
            guard let p = e.price else { return false }
            switch band {
            case .any: return true
            case .budget: return p < low
            case .mid: return p >= low && p < high
            case .premium: return p >= high
            }
        }

        func label(_ b: Band) -> String {
            switch b {
            case .any: "Any price"
            case .budget: "Under \(Fmt.price(low))/M"
            case .mid: "\(Fmt.price(low))–\(Fmt.price(high))/M"
            case .premium: "\(Fmt.price(high))/M and up"
            }
        }
    }

    /// Where you stand, in words: the headline of the leaderboard.
    struct Standing {
        /// Your lab's place (nil until you release something).
        var rank: Int?
        /// Labs in the race, you included.
        var labs: Int
        var headline: String
        var detail: String
        /// An unreleased model of yours that would rank higher than what's out.
        var ready: String?
    }

    /// "Prometheus Labs'", "Halcyon AI's".
    static func possessive(_ name: String) -> String { name.hasSuffix("s") ? "\(name)'" : "\(name)'s" }

    static func capabilityText(_ gap: Double) -> String {
        let g = abs(gap)
        return g >= 9.95 ? "\(Int(g.rounded())) capability points" : "\(Fmt.trim(g, 1)) capability points"
    }

    static func standing(_ labs: [LabRow], board: [Entry], gone: Set<String>) -> Standing {
        let racing = labs.filter { $0.rank > 0 }
        guard let me = labs.first(where: \.isPlayer) else {
            return Standing(rank: nil, labs: racing.count + 1, headline: "You haven't entered the race yet",
                            detail: "Train a model in the Model Lab and release it: it lands here, ranked against every lab's flagship.", ready: nil)
        }
        let mine = me.models.filter(\.released).max { $0.index < $1.index }
        var ready: String? = nil
        if let u = me.models.filter({ !$0.released }).max(by: { $0.index < $1.index }), u.index > (mine?.index ?? -1) {
            ready = "Ready to ship: \(u.model) would rank #\(labRank(index: u.index, board: board, gone: gone)) "
                + "(index \(Fmt.score(u.index)), capability \(Int(u.capability.rounded())))."
        }
        guard let mine, me.rank > 0 else {
            return Standing(rank: nil, labs: racing.count + 1, headline: "Nothing released yet",
                            detail: "Release a model to take your place in the race.", ready: ready)
        }
        let rivals = racing.filter { !$0.isPlayer }
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.flagship.capability > $1.flagship.capability }
        let n = racing.count
        guard let first = rivals.first else {
            return Standing(rank: me.rank, labs: n, headline: "You're the only lab in the race", detail: "No rival has a model out yet.", ready: ready)
        }
        if me.rank == 1 {
            let lead = mine.capability - first.flagship.capability
            let mult = BenchmarkCatalog.formatMultiple(BenchmarkCatalog.computeMultiple(capabilityGap: max(0, lead)))
            let detail: String
            if lead >= 0.5 {
                detail = "\(mine.model) is \(capabilityText(lead)) ahead of \(possessive(first.lab)) \(first.flagship.model): about \(mult) its effective compute."
            } else if lead > -0.5 {
                detail = "\(mine.model) is level on capability with \(possessive(first.lab)) \(first.flagship.model); you edge it on today's benchmarks."
            } else {
                detail = "You top the index, but \(possessive(first.lab)) \(first.flagship.model) is \(capabilityText(lead)) ahead overall: "
                    + "your edge is the mix of skills today's benchmarks test."
            }
            return Standing(rank: 1, labs: n, headline: "You lead the race", detail: detail, ready: ready)
        }
        let leader = racing.filter { $0.rank == 1 }.max { $0.flagship.capability < $1.flagship.capability } ?? first
        let gap = leader.flagship.capability - mine.capability
        var detail: String
        if gap >= 0.5 {
            let mult = BenchmarkCatalog.formatMultiple(BenchmarkCatalog.computeMultiple(capabilityGap: gap))
            detail = "\(possessive(leader.lab)) \(leader.flagship.model) leads, \(capabilityText(gap)) ahead of your \(mine.model): about \(mult) the effective compute. "
                + "Closing it takes a training run about \(mult) bigger, a better recipe, or stronger post-training (reasoning and agentic RL add capability without more pre-training)."
        } else {
            detail = "\(possessive(leader.lab)) \(leader.flagship.model) tops the index, yet your \(mine.model) is about as capable overall: "
                + "its edge is the skills today's benchmarks weigh most."
        }
        if me.rank > 2, let next = rivals.filter({ $0.rank < me.rank }).max(by: { $0.rank < $1.rank }) {
            let g = next.flagship.capability - mine.capability
            detail += " Next up: #\(next.rank) \(next.lab), " + (g > 0 ? "\(capabilityText(g)) ahead." : "within reach on capability.")
        }
        return Standing(rank: me.rank, labs: n, headline: "#\(me.rank) of \(n) labs", detail: detail, ready: ready)
    }

    /// One point of a lab's flagship-capability line.
    struct RacePoint: Identifiable, Equatable {
        var id: Int
        var date: Date
        var labID: String
        var lab: String
        var capability: Double
        var isPlayer: Bool
    }

    struct RaceSeries: Identifiable, Equatable {
        var id: String
        var lab: String
        var isPlayer: Bool
        var capability: Double
    }

    /// The best capability each leading lab (and you) had released, as step lines over the last `months`.
    static func race(_ labs: [LabRow], today: Date, months: Int = 48, top: Int = 5) -> (points: [RacePoint], series: [RaceSeries]) {
        let from = GameCalendar.addMonths(today, -months)
        var chosen = Array(labs.filter { $0.rank > 0 && !$0.isPlayer }.sorted { $0.rank < $1.rank }.prefix(top))
        if let me = labs.first(where: \.isPlayer), me.models.contains(where: \.released) { chosen.append(me) }
        var points: [RacePoint] = []
        var series: [RaceSeries] = []
        for r in chosen {
            let released = r.models.filter(\.released).sorted { $0.date < $1.date }
            func add(_ d: Date, _ v: Double) {
                points.append(RacePoint(id: points.count, date: d, labID: r.labID, lab: r.lab, capability: v, isPlayer: r.isPlayer))
            }
            var best = released.filter { $0.date < from }.map(\.capability).max()
            if let b = best { add(from, b) }
            for e in released where e.date >= from && e.capability > (best ?? -.infinity) {
                best = e.capability
                add(e.date, e.capability)
            }
            if let b = best {
                add(today, b)
                series.append(RaceSeries(id: r.labID, lab: r.lab, isPlayer: r.isPlayer, capability: b))
            }
        }
        return (points, series)
    }

    static func ago(_ d: Date, now: Date) -> String {
        let days = GameCalendar.daysBetween(d, now)
        if days < 1 { return "today" }
        if days < 60 { return "\(days) d ago" }
        if days < 730 { return "\(Int((Double(days) / 30.44).rounded())) mo ago" }
        return "\(Fmt.trim(Double(days) / 365.25, 1)) yrs ago"
    }
}

extension Leaderboard.LabRow {
    /// Places gained (+) or lost (−) over the last quarter; nil if the lab had nothing out then.
    var rankChange: Int? { rank > 0 ? rankQuarterAgo.map { $0 - rank } : nil }
    /// The most capable model the lab has released.
    var bestCapability: Double { models.filter(\.released).map(\.capability).max() ?? flagship.capability }
    /// Capability gained over the last quarter (nil if the lab had nothing out then).
    var capabilityGain: Double? { capabilityQuarterAgo.map { bestCapability - $0 } }

    /// Its flagship under a filter: the best released model that passes (yours may be unreleased while nothing is out).
    func shown(_ f: Leaderboard.Filter) -> Leaderboard.Entry? {
        guard f.isActive else { return flagship }
        return models.filter { ($0.released || isPlayer) && f.includes($0) }.max { $0.index < $1.index }
    }
}

/// Benchmark lifecycle: saturation, retirement and harder successors.
enum BenchLife {
    struct Contender {
        var name: String
        var lab: String
        var isPlayer: Bool
        var date: Date
        var profile: ModelProfile

        /// One key per lab: a benchmark saturates when two different labs get there.
        var labKey: String { isPlayer ? "\u{1}you" : lab }
    }

    static func contenders(_ s: GameState, until date: Date? = nil) -> [Contender] {
        var out: [Contender] = []
        for comp in s.competitors {
            for m in comp.models + comp.openModels where date == nil || m.date <= date! {
                out.append(Contender(name: m.name, lab: comp.def.name, isPlayer: false, date: m.date,
                                     profile: Leaderboard.profile(m, def: comp.def, boost: Competitors.boost(s, comp.id, at: m.date.decimalYear))))
            }
        }
        for m in s.models where m.released {
            let d = m.releaseDate ?? m.created
            if date == nil || d <= date! {
                out.append(Contender(name: m.name, lab: s.companyName, isPlayer: true, date: d, profile: Leaderboard.profile(m)))
            }
        }
        return out
    }

    /// Re-score every model's stored Intelligence Index against today's index set
    /// (like Artificial Analysis re-scoring old models when the index changes).
    static func refreshIndexes(_ s: inout GameState) {
        let set = Leaderboard.indexSet(s)
        for i in s.models.indices {
            s.models[i].index = BenchmarkCatalog.index(Leaderboard.profile(s.models[i]), set: set)
        }
        for ci in s.competitors.indices {
            let def = s.competitors[ci].def
            let id = s.competitors[ci].id
            for mi in s.competitors[ci].models.indices {
                let m = s.competitors[ci].models[mi]
                s.competitors[ci].models[mi].index = BenchmarkCatalog.index(Leaderboard.profile(m, def: def, boost: Competitors.boost(s, id, at: m.date.decimalYear)), set: set)
            }
            for mi in s.competitors[ci].openModels.indices {
                let m = s.competitors[ci].openModels[mi]
                s.competitors[ci].openModels[mi].index = BenchmarkCatalog.index(Leaderboard.profile(m, def: def, boost: Competitors.boost(s, id, at: m.date.decimalYear)), set: set)
            }
        }
    }

    /// Where the field stands on what `b` tests: the best rival model so far, or the world frontier if the rivals lag it.
    /// Your own models don't count: new benchmarks are pitched at the field, not at a runaway leader.
    static func fieldX(_ b: Benchmark, _ pool: [Contender], at date: Date) -> Double {
        var x = b.x(Leaderboard.frontierReference(date.decimalYear)) ?? -100
        for c in pool where !c.isPlayer && c.date <= date {
            if let v = b.x(c.profile) { x = max(x, v) }
        }
        return x
    }

    /// Weekly: retire what the field has saturated, commission harder successors and keep enough live benchmarks around,
    /// then re-score every model on today's index set.
    static func weekly(_ s: inout GameState) {
        defer { refreshIndexes(&s) }
        let all = s.benchmarks
        let pool = contenders(s)
        guard !pool.isEmpty else { return }
        for b in all where b.isActive(s.date, saturated: s.benchSaturated) {
            var labs: [String: (score: Double, who: Contender)] = [:]
            for c in pool {
                let v = BenchmarkCatalog.cachedScore(b, c.profile)
                if v > (labs[c.labKey]?.score ?? -1) { labs[c.labKey] = (v, c) }
            }
            let ranked = labs.values.sorted { $0.score != $1.score ? $0.score > $1.score : $0.who.labKey < $1.who.labKey }
            // Saturated once a second lab gets there: one runaway lab doesn't retire a test the rest of the field still needs.
            guard ranked.count >= 2, ranked[1].score >= b.saturation else { continue }
            let top = ranked[0], second = ranked[1]
            s.benchSaturated[b.id] = s.date
            s.benchSaturatedBy[b.id] = "\(top.who.name) (\(top.who.lab))"
            Sim.news(&s, "\(b.name) is saturated",
                     "\(second.who.name) by \(second.who.lab) scored \(b.format(second.score)), joining \(top.who.name) (\(b.format(top.score))). "
                     + "The benchmark no longer separates frontier models and rotates out of the Intelligence Index once a successor is ready.",
                     .research, image: "wafer_closeup", important: false)
            if top.who.isPlayer { Achievements.unlock(&s, "bench_breaker") }
            spawnSuccessor(&s, for: b, all: s.benchmarks, fieldX: fieldX(b, pool, at: s.date), date: s.date, announce: true)
        }
        stockLivePool(&s, pool: pool)
    }

    @discardableResult
    static func spawnSuccessor(_ s: inout GameState, for b: Benchmark, all: [Benchmark], fieldX: Double, date: Date, announce: Bool,
                               force: Bool = false) -> Bool {
        let members = all.filter { $0.family == b.family }
        let stillOpen = members.contains { $0.id != b.id && s.benchSaturated[$0.id] == nil }
        guard !stillOpen, let succ = BenchmarkCatalog.makeSuccessor(of: b, family: members, fieldX: fieldX, date: date, force: force),
              !s.generatedBenchmarks.contains(where: { $0.id == succ.id }) else { return false }
        s.generatedBenchmarks.append(succ)
        if announce {
            Sim.news(&s, "New benchmark announced: \(succ.name)",
                     "\(succ.about) The field's best models are expected to start around 10%. Launches \(succ.introduced.label).",
                     .research, image: "wafer", important: true)
        }
        return true
    }

    /// If saturation outpaces new releases (or one lab tears through a whole era's tests), commission a successor for the
    /// family that saturated most recently, even one that doesn't usually regenerate: at most one a week, until enough
    /// unsaturated text benchmarks are out or announced for the index to rotate through.
    static func stockLivePool(_ s: inout GameState, pool: [Contender]) {
        let all = s.benchmarks
        let soon = s.date.ym.adding(months: 3)
        let open = all.filter { $0.kind.inIndex && s.benchSaturated[$0.id] == nil && $0.introduced <= soon }.count
        guard open < BenchmarkCatalog.minLiveBenchmarks else { return }
        let retired = all.filter { $0.kind.inIndex && s.benchSaturated[$0.id] != nil }
            .sorted { (s.benchSaturated[$0.id] ?? .distantPast, $0.id) > (s.benchSaturated[$1.id] ?? .distantPast, $1.id) }
        var families = Set<String>()
        for b in retired where families.insert(b.family).inserted {
            if spawnSuccessor(&s, for: b, all: all, fieldX: fieldX(b, pool, at: s.date), date: s.date, announce: true, force: true) { return }
        }
    }

    /// At game start (and when an older save loads), replay benchmark history silently so saturation matches the date.
    static func replayHistory(_ s: inout GameState) {
        var changed = true
        var guardCount = 0
        while changed && guardCount < 40 {
            changed = false
            guardCount += 1
            let pool = contenders(s).sorted { $0.date < $1.date }
            for b in s.benchmarks where s.benchSaturated[b.id] == nil && b.introduced <= s.date.ym {
                var crossed = Set<String>()
                var first: Contender? = nil
                for c in pool where !crossed.contains(c.labKey) && BenchmarkCatalog.cachedScore(b, c.profile) >= b.saturation {
                    crossed.insert(c.labKey)
                    if first == nil { first = c }
                    guard crossed.count >= 2, let leader = first else { continue }
                    let when = max(c.date, b.introduced.date)
                    s.benchSaturated[b.id] = when
                    s.benchSaturatedBy[b.id] = "\(leader.name) (\(leader.lab))"
                    spawnSuccessor(&s, for: b, all: s.benchmarks, fieldX: fieldX(b, pool, at: when), date: when, announce: false)
                    changed = true
                    break
                }
            }
        }
    }
}
