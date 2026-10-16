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
    }

    // MARK: Profiles

    static func profile(_ m: AIModel) -> ModelProfile {
        ModelProfile(key: m.id.uuidString, c: m.c, reasoning: m.reasoningBoost, code: m.codeBoost, agent: m.agentBoost,
                     vision: m.design.vision, contextK: m.design.contextK, tuning: m.tuned ? 1 : 0,
                     chat: m.chatSkill, safety: m.safety, lang: m.langSkill, longctx: m.longctxSkill, vis: m.visSkill, audio: m.design.audio)
    }

    /// The profile of a frontier lab's model at a given date (also used to calibrate benchmarks).
    static func frontierProfile(_ y: Double, key: String, c: Double, reasoningModel: Bool) -> ModelProfile {
        let reasoning = reasoningModel ? 0.6 : (y > 2022.1 ? 0.1 : 0)
        let code = (y > 2024.5 ? 0.15 : 0) + (y > 2025.2 ? 0.15 : 0)
        let agent = y > 2025.0 ? 0.3 : (y > 2023.5 ? 0.1 : 0)
        let chat = y < 2022.0 ? -0.6 : (y < 2022.9 ? 0.3 : (y < 2024.0 ? 0.8 : (y < 2025.0 ? 1.0 : 1.2)))
        let safety = interpolate([(2016, 20), (2022.9, 50), (2024, 60), (2026, 70), (2030, 78)], at: y)
        let lang = interpolate([(2016, 0), (2023, 0.15), (2025, 0.3), (2030, 0.4)], at: y)
        let longctx = y < 2024.1 ? 0 : (y < 2025 ? 0.1 : 0.2)
        let ctx = y > 2025 ? 1000 : (y > 2024 ? 128 : (y > 2023 ? 32 : (y > 2020 ? 2 : 1)))
        return ModelProfile(key: key, c: c, reasoning: reasoning, code: code, agent: agent, vision: y > 2023.2, contextK: ctx, tuning: 0,
                            chat: chat, safety: safety, lang: lang, longctx: longctx, vis: y < 2023.95 ? 0 : 0.1, audio: y > 2024.37)
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
            for m in comp.models {
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

    /// World rank by Intelligence Index among released rival models (your own models don't push each other down).
    static func rank(of id: UUID, in s: GameState) -> Int {
        let all = entries(s)
        guard let me = all.first(where: { $0.id == id.uuidString }) else { return all.count + 1 }
        return all.filter { !$0.isPlayer && $0.released && $0.index > me.index }.count + 1
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
    }

    static func contenders(_ s: GameState, until date: Date? = nil) -> [Contender] {
        var out: [Contender] = []
        for comp in s.competitors {
            for m in comp.models where date == nil || m.date <= date! {
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

    /// Weekly: mark saturated benchmarks and spawn harder successors.
    /// Re-score every model's stored Intelligence Index against today's index set
    /// (like Artificial Analysis re-scoring old models when the index changes).
    static func refreshIndexes(_ s: inout GameState) {
        let set = Leaderboard.indexSet(s)
        for i in s.models.indices {
            s.models[i].index = BenchmarkCatalog.index(Leaderboard.profile(s.models[i]), set: set)
        }
        for ci in s.competitors.indices {
            let def = s.competitors[ci].def
            for mi in s.competitors[ci].models.indices {
                let m = s.competitors[ci].models[mi]
                s.competitors[ci].models[mi].index = BenchmarkCatalog.index(Leaderboard.profile(m, def: def, boost: Competitors.boost(s, s.competitors[ci].id, at: m.date.decimalYear)), set: set)
            }
        }
    }

    static func weekly(_ s: inout GameState) {
        defer { refreshIndexes(&s) }
        let all = s.benchmarks
        let pool = contenders(s)
        guard !pool.isEmpty else { return }
        for b in all where b.isActive(s.date, saturated: s.benchSaturated) {
            var best: Contender? = nil
            var bestScore = -1.0
            var bestX = -100.0
            for c in pool {
                let v = BenchmarkCatalog.cachedScore(b, c.profile)
                if v > bestScore { bestScore = v; best = c }
                if let x = b.x(c.profile) { bestX = max(bestX, x) }
            }
            guard let top = best, bestScore >= b.saturation else { continue }
            s.benchSaturated[b.id] = s.date
            s.benchSaturatedBy[b.id] = "\(top.name) (\(top.lab))"
            Sim.news(&s, "\(b.name) is saturated", "\(top.name) by \(top.lab) scored \(Fmt.score(bestScore))%. The benchmark no longer separates frontier models and drops out of the Intelligence Index.",
                     .research, image: "wafer_closeup", important: false)
            if top.isPlayer { Achievements.unlock(&s, "bench_breaker") }
            spawnSuccessor(&s, for: b, all: s.benchmarks, bestX: bestX, date: s.date, announce: true)
        }
    }

    static func spawnSuccessor(_ s: inout GameState, for b: Benchmark, all: [Benchmark], bestX: Double, date: Date, announce: Bool) {
        let members = all.filter { $0.family == b.family }
        let stillOpen = members.contains { $0.id != b.id && s.benchSaturated[$0.id] == nil }
        guard !stillOpen, let succ = BenchmarkCatalog.makeSuccessor(of: b, family: members, worldBestX: bestX, date: date),
              !s.generatedBenchmarks.contains(where: { $0.id == succ.id }) else { return }
        s.generatedBenchmarks.append(succ)
        if announce {
            Sim.news(&s, "New benchmark announced: \(succ.name)",
                     "\(succ.about) Today's best models are expected to score in single digits. Launches \(succ.introduced.label).",
                     .research, image: "wafer", important: true)
        }
    }

    /// At game start, replay benchmark history silently so saturation matches the starting year.
    static func replayHistory(_ s: inout GameState) {
        var changed = true
        var guardCount = 0
        while changed && guardCount < 40 {
            changed = false
            guardCount += 1
            let pool = contenders(s).sorted { $0.date < $1.date }
            for b in s.benchmarks where s.benchSaturated[b.id] == nil && b.introduced <= s.date.ym {
                var bestX = -100.0
                for c in pool {
                    if let x = b.x(c.profile) { bestX = max(bestX, x) }
                    let v = BenchmarkCatalog.cachedScore(b, c.profile)
                    if v >= b.saturation {
                        let when = max(c.date, b.introduced.date)
                        s.benchSaturated[b.id] = when
                        s.benchSaturatedBy[b.id] = "\(c.name) (\(c.lab))"
                        spawnSuccessor(&s, for: b, all: s.benchmarks, bestX: bestX, date: when, announce: false)
                        changed = true
                        break
                    }
                }
            }
        }
    }
}
