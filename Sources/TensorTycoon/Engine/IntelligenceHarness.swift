import Foundation

/// `TensorTycoon --intelligence`: gameplay checks for model intelligence, families, launches, markets and rival books
/// (3.8). Each check plays or edits a copy of a real game and looks at what the simulation did with it — demand,
/// prices, scores, money — not merely that the code ran. Exits 1 when any check fails.
enum IntelligenceHarness {
    static func main() -> Int32 {
        var r = ScenarioHarness.Report(id: "intelligence", title: "Deeper intelligence, families, launches, markets, rivals")
        let start = Date()
        // A lab two years into the agent era: models, research and a family to work with.
        var s = ScenarioHarness.newGame(era: "2024", seed: 21, name: "Harness Labs")
        var bot = PTBot()
        ScenarioHarness.play(&s, &bot, days: 540)
        ScenarioHarness.sanity(s, &r)
        let live = s.models.filter { $0.released && !$0.retired }
        r.note("2024 game played to \(s.date.gameShort): \(live.count) live models, \(s.researched.count) techniques")
        guard let best = live.max(by: { $0.index < $1.index }) else {
            r.expect("the bot released a model", false)
            return report(r, start)
        }
        thinking(s, best, &r)
        knowHow(s, &r)
        students(s, best, &r)
        retirement(s, &r)
        pricing(s, best, &r)
        tiers(s, best, &r)
        specialists(s, best, &r)
        launchesMoveMarkets(s, best, &r)
        renewals(s, best, &r)
        rivals(&r)
        return report(r, start)
    }

    static func report(_ r: ScenarioHarness.Report, _ start: Date) -> Int32 {
        let bad = r.failed
        print("\(bad.isEmpty ? "PASS" : "FAIL") · \(r.title) · \(r.checks.count - bad.count)/\(r.checks.count) checks · \(Fmt.trim(Date().timeIntervalSince(start), 1)) s")
        for n in r.notes { print("    · \(n)") }
        for c in r.checks { print("    \(c.ok ? "✓" : "✗") \(c.name)\(c.detail.isEmpty ? "" : ": \(c.detail)")") }
        print(bad.isEmpty ? "OK" : "FAILED: \(bad.count) checks")
        return bad.isEmpty ? 0 : 1
    }

    /// A copy of `m` as a new, unreleased model (same weights and know-how).
    static func clone(_ s: inout GameState, _ m: AIModel, name: String) -> Int {
        var c = Families.forked(m, name: name, date: s.date)
        c.id = StableID.next()
        c.teacherID = nil
        c.knowHow = Capabilities.knowHow(m, s)
        s.models.append(c)
        let i = s.models.count - 1
        s.domainScores[c.id.uuidString] = Capabilities.playerScores(c, research: c.knowHow)
        return i
    }

    // MARK: 1. Thinking tokens and reasoning effort

    static func thinking(_ base: GameState, _ best: AIModel, _ r: inout ScenarioHarness.Report) {
        var s = base
        var m = best
        m.reasoning = true
        m.design.reasoning = true
        var b0 = s.bonuses
        b0.thinkingEfficiency = 0
        var b5 = b0
        b5.thinkingEfficiency = 0.5
        let t0 = Families.thinkingTokens(m, b0), t5 = Families.thinkingTokens(m, b5)
        r.expect("thinking tokens: 2.2× before research, fewer with it", abs(t0 - 2.2) < 1e-9 && abs(t5 - 1.6) < 1e-9, "\(Fmt.trim(t0, 2))× → \(Fmt.trim(t5, 2))×")
        var hi = m, lo = m
        hi.effort = .high
        lo.effort = .low
        r.expect("effort sets the token multiplier", Families.thinkingTokens(lo, b0) < t0 && Families.thinkingTokens(hi, b0) > t0,
                 "low \(Fmt.trim(Families.thinkingTokens(lo, b0), 2))× · high \(Fmt.trim(Families.thinkingTokens(hi, b0), 2))×")
        var plain = m
        plain.reasoning = false
        let costR = Economy.servingCostPerM(m, s, bonuses: b0), costP = Economy.servingCostPerM(plain, s, bonuses: b0)
        r.expect("a reasoning model's API tokens cost its thinking to serve", costP > 0 && abs(costR / costP - t0) < 0.01,
                 "\(Fmt.price(costP)) → \(Fmt.price(costR)) per 1M sold")
        // Chat traffic on a reasoning model, at low and high effort.
        guard let i = s.models.firstIndex(where: { $0.id == best.id }), !s.models[i].deployments.isEmpty, s.consumerUsers > 1 else {
            r.note("no chat app on a deployed model to measure chat traffic")
            return
        }
        s.models[i].reasoning = true
        s.models[i].design.reasoning = true
        s.chatModelID = best.id
        var low = s, high = s
        _ = low.setReasoningEffort(best.id, .low)
        _ = high.setReasoningEffort(best.id, .high)
        Sim.advanceDay(&low)
        Sim.advanceDay(&high)
        let dl = low.models[i].demandTokensDay, dh = high.models[i].demandTokensDay
        r.expect("high effort needs more serving capacity than low", dh > dl * 1.3, "\(Fmt.count(dl)) → \(Fmt.count(dh)) tokens/day")
        let sl = low.domainScores[best.id.uuidString], sh = high.domainScores[best.id.uuidString]
        r.expect("high effort scores higher in maths and coding (test-time compute)", (sh?[.math] ?? 0) > (sl?[.math] ?? 0) && (sh?[.coding] ?? 0) > (sl?[.coding] ?? 0),
                 "maths \(Fmt.trim(sl?[.math] ?? 0, 1)) → \(Fmt.trim(sh?[.math] ?? 0, 1))")
        r.expect("effort leaves knowledge alone", abs((sh?[.knowledge] ?? 0) - (sl?[.knowledge] ?? 0)) < 0.11)
    }

    // MARK: 2. Know-how stays with the model

    static func knowHow(_ base: GameState, _ r: inout ScenarioHarness.Report) {
        var s = base
        guard let old = s.models.filter({ $0.released && !$0.retired && $0.design.instruct }).min(by: { $0.created < $1.created }),
              let i = s.models.firstIndex(where: { $0.id == old.id }) else { return }
        let before = s.domainScores[old.id.uuidString]
        // A decade of research lands overnight; then a cheap safety pass.
        for item in ResearchCatalog.all where !item.isExotic { s.researched.insert(item.id) }
        let job = ModelJob(kind: .postTrain, modelID: old.id, pass: PostTrainPass.safety.rawValue, accelID: "", chips: 0, flops: 0, started: s.date)
        Families.finishPass(&s, job)
        let after = s.domainScores[old.id.uuidString]
        let robotics = (after?[.robotics] ?? 0) - (before?[.robotics] ?? 0)
        let coding = (after?[.coding] ?? 0) - (before?[.coding] ?? 0)
        r.expect("a safety pass doesn't pick up later robotics or coding research", robotics <= 0.05 && coding <= 0.05,
                 "robotics \(CapStyleText.delta(robotics)), coding \(CapStyleText.delta(coding))")
        r.expect("…but does learn the published calibration techniques", (after?[.calibration] ?? 0) > (before?[.calibration] ?? 0),
                 "calibration \(Fmt.trim(before?[.calibration] ?? 0, 1)) → \(Fmt.trim(after?[.calibration] ?? 0, 1))")
        r.expect("the snapshot is kept on the model", s.models[i].knowHow.count == CapDomain.count)
        // A student distilled today learns what the teacher knew, not today's research.
        let t = s.models[i]
        let plan = Families.distillPlan(s, teacher: t, tier: .spark, data: .standard, accelID: t.design.accelID, chips: 8)
        var st = Families.student(s, teacher: t, plan: plan, name: "Harness Spark", accelID: t.design.accelID, chips: 8)
        st.id = StableID.next()
        let sv = Capabilities.playerScores(st, research: st.knowHow)
        let tv = s.domainScores[t.id.uuidString] ?? sv
        let beats = CapDomain.allCases.filter { sv[$0] > tv[$0] + 0.05 && $0 != .social && $0 != .reasoning && $0 != .math && $0 != .coding }
        r.expect("a student never beats its teacher in knowledge-heavy domains", beats.isEmpty, beats.map(\.short).joined(separator: ", "))
        r.expect("a student keeps the teacher's passes", st.passes == t.passes && !st.passes.isEmpty, "\(st.passes)")
    }

    // MARK: 3. Distillation rule

    static func students(_ s: GameState, _ best: AIModel, _ r: inout ScenarioHarness.Report) {
        let b = s.bonuses
        let p = Families.distillPlan(s, teacher: best, tier: .core, data: .standard, accelID: best.design.accelID, chips: 8)
        let g = Families.distillGap(teacherParamsB: best.design.paramsB, studentParamsB: best.design.paramsB * 0.3, bonuses: b)
        // The Model Lab's distil mode, forecast for the same student.
        var lab = best.design
        lab.mode = .distill
        lab.baseModelRef = best.id.uuidString
        lab.paramsB = best.design.paramsB * 0.3
        let fc = ForecastEngine.forecast(lab, state: s, dataSources: s.dataSources.sorted())
        let labGap = -(fc.drivers.first { $0.name == "Distillation gap" }?.value ?? .nan)
        r.expect("Families and the Model Lab share one distillation gap", abs(p.gap - g) < 1e-12 && abs(labGap - g) < 1e-12,
                 "families \(Fmt.trim(p.gap, 3)) · Model Lab \(Fmt.trim(labGap, 3)) · rule \(Fmt.trim(g, 3))")
        let small = Families.distillGap(teacherParamsB: 100, studentParamsB: 1, bonuses: b), big = Families.distillGap(teacherParamsB: 100, studentParamsB: 30, bonuses: b)
        r.expect("a smaller student loses more", small > big, "1% size \(Fmt.trim(small, 2)) · 30% size \(Fmt.trim(big, 2))")
    }

    // MARK: 4. Retired models stop counting

    static func retirement(_ base: GameState, _ r: inout ScenarioHarness.Report) {
        var s = base
        guard let top = s.models.filter({ $0.released && !$0.retired }).max(by: { ($0.index, $0.id.uuidString) < ($1.index, $1.id.uuidString) }),
              s.models.filter({ $0.released && !$0.retired }).count >= 2 else { return }
        Capabilities.refreshLabs(&s)
        let was = s.labDomains["player"]
        s.retire(top.id)
        Capabilities.daily(&s)
        let now = s.labDomains["player"]
        let theirs = s.domainScores[top.id.uuidString]
        let dropped = CapDomain.allCases.contains { (now?[$0] ?? 0) < (was?[$0] ?? 0) - 0.05 }
        r.expect("retiring the best model lowers the lab's profile", dropped || theirs == nil, "best knowledge \(Fmt.trim(was?[.knowledge] ?? 0, 1)) → \(Fmt.trim(now?[.knowledge] ?? 0, 1))")
    }

    // MARK: 5. Pricing stances hold; hand-set prices come back

    static func pricing(_ base: GameState, _ best: AIModel, _ r: inout ScenarioHarness.Report) {
        var s = base
        let i = clone(&s, best, name: "Harness Undercut")
        s.models[i].deployments = best.deployments
        s.models[i].autoPrice = true
        let id = s.models[i].id
        _ = s.release(id, api: true, openWeights: false, plan: LaunchPlan(pricing: .undercut))
        for _ in 0..<40 { Sim.advanceDay(&s) }
        if let m = s.models.first(where: { $0.id == id }) {
            let ratio = m.apiPrice / (Treasury.marketPrice(m, s) * 0.85)
            r.expect("an undercut holds for its window under auto-pricing", ratio < 0.86 || m.apiPrice <= Treasury.minPrice(m, s) + 1e-6,
                     "price \(Fmt.price(m.apiPrice)) = \(Fmt.trim(ratio, 2))× the auto anchor after 40 days")
        }
        var t = base
        let j = clone(&t, best, name: "Harness Premium")
        t.models[j].autoPrice = false
        let manual = max(Treasury.minPrice(t.models[j], t), Treasury.tidy(Treasury.marketPrice(t.models[j], t)))
        t.models[j].apiPrice = manual
        let jid = t.models[j].id
        _ = t.release(jid, api: true, openWeights: false, plan: LaunchPlan(pricing: .premium))
        let launched = t.models.first { $0.id == jid }?.apiPrice ?? 0
        for _ in 0..<125 { Sim.advanceDay(&t) }
        let after = t.models.first { $0.id == jid }?.apiPrice ?? 0
        r.expect("a premium stance raises a hand-set price, then puts it back", launched > manual * 1.2 && abs(after - manual) < manual * 0.001,
                 "\(Fmt.price(manual)) → \(Fmt.price(launched)) → \(Fmt.price(after))")
    }

    // MARK: 6. Family tiers aren't launches

    static func tiers(_ base: GameState, _ best: AIModel, _ r: inout ScenarioHarness.Report) {
        func gain(withTier: Bool) -> (Double, Double) {
            var s = base
            // Same IDs in both runs (benchmark noise is keyed on the model), so only the tier's release differs.
            StableID.seed(9_001)
            let f = clone(&s, best, name: "Harness Flagship")
            let k = clone(&s, best, name: "Harness Mote")
            if withTier { _ = s.release(s.models[k].id, api: true, openWeights: false, plan: LaunchPlan(), by: "family") }
            s.models[f].c += 0.6
            let fid = s.models[f].id
            s.models[f].index = BenchmarkCatalog.index(Leaderboard.profile(s.models[f]), set: Leaderboard.indexSet(s))
            _ = s.release(fid, api: true, openWeights: false, plan: LaunchPlan())
            let rec = s.launches.last { $0.modelID == fid }
            return (rec?.brandGain ?? 0, rec?.previousBest ?? 0)
        }
        let plain = gain(withTier: false), after = gain(withTier: true)
        r.expect("an auto-released tier doesn't halve the next flagship's brand gain", plain.0 > 0 && abs(after.0 - plain.0) < 1e-6,
                 "\(Fmt.trim(plain.0, 2)) vs \(Fmt.trim(after.0, 2)) (previous best \(Fmt.trim(plain.1, 2)) / \(Fmt.trim(after.1, 2)))")
    }

    // MARK: 7. Specialists win their segment

    static func specialists(_ base: GameState, _ best: AIModel, _ r: inout ScenarioHarness.Report) {
        var s = base
        guard best.design.instruct, !best.deployments.isEmpty else { return }
        let fi = Families.ensureFamily(&s, for: best)
        let job = ModelJob(kind: .fork, modelID: best.id, familyID: s.families.families[fi].id, name: "Harness Code", tier: FamilyTier.coder.rawValue,
                           pass: PostTrainPass.specCode.rawValue, accelID: best.deployments[0].accelID, chips: 0, flops: 0, started: s.date)
        let before = s.models.count
        Families.finishFork(&s, job)
        guard s.models.count == before + 1, let coder = s.models.last else {
            r.expect("a fork makes a new family member", false)
            return
        }
        r.expect("a fork makes a new family member and leaves its parent alone", Families.tier(of: coder.id, s) == .coder
                 && (s.models.first { $0.id == best.id }?.passes ?? []) == best.passes)
        if let ci = s.models.firstIndex(where: { $0.id == coder.id }) {
            s.models[ci].deployments = best.deployments
            s.models[ci].apiPrice = best.apiPrice
            s.models[ci].released = true
            s.models[ci].api = true
            s.models[ci].capacityTokensDay = max(1, best.capacityTokensDay)
            s.models[ci].tps = best.tps
        }
        let snap = Market.snapshot(s)
        let cp = snap.api.first { $0.modelID == coder.id }, fp = snap.api.first { $0.modelID == best.id }
        let k = APISegment.coding.rawValue, g = APISegment.general.rawValue
        let coderCoding = cp?.segShares[k] ?? 0, flagCoding = fp?.segShares[k] ?? 0
        r.expect("the coding specialist wins more coding traffic than its stronger generalist parent", coderCoding > flagCoding,
                 "coding share \(Fmt.pct(flagCoding, decimals: 1)) → \(Fmt.pct(coderCoding, decimals: 1))")
        r.expect("…and less general traffic", (cp?.segShares[g] ?? 1) < (fp?.segShares[g] ?? 0),
                 "general \(Fmt.pct(fp?.segShares[g] ?? 0, decimals: 1)) vs \(Fmt.pct(cp?.segShares[g] ?? 0, decimals: 1))")
        // Routing: with Model Routing the family sells through one endpoint and gains in every segment.
        var routed = s
        routed.researched.insert("model_routing")
        let rs = Market.snapshot(routed)
        let famShare = { (snap: MarketSnapshot) in snap.api.filter { $0.modelID == coder.id || $0.modelID == best.id }.reduce(0) { $0 + $1.share } }
        r.expect("Model Routing lifts a family's API share", famShare(rs) > famShare(snap), "\(Fmt.pct(famShare(snap), decimals: 1)) → \(Fmt.pct(famShare(rs), decimals: 1))")
    }

    // MARK: 8. Launches move markets

    static func launchesMoveMarkets(_ base: GameState, _ best: AIModel, _ r: inout ScenarioHarness.Report) {
        var s = base
        let i = clone(&s, best, name: "Harness Frontier")
        let id = s.models[i].id
        s.models[i].c = (s.competitors.compactMap { $0.latest?.c }.max() ?? best.c) + 0.5
        s.models[i].index = BenchmarkCatalog.index(Leaderboard.profile(s.models[i]), set: Leaderboard.indexSet(s))
        for _ in 0..<6 where Leaderboard.rank(of: id, in: s) > 1 {
            s.models[i].c += 0.3
            s.models[i].reasoningBoost += 0.3
            s.models[i].codeBoost += 0.15
            s.models[i].index = BenchmarkCatalog.index(Leaderboard.profile(s.models[i]), set: Leaderboard.indexSet(s))
        }
        let leads = s.deals.filter { !$0.active }.count
        s.deals.removeAll { !$0.active }
        let rank = Leaderboard.rank(of: id, in: s)
        let board = Leaderboard.entries(s)
        let mine = board.first { $0.id == id.uuidString }?.index ?? 0
        let top = board.filter { !$0.isPlayer && $0.released }.max { $0.index < $1.index }
        r.note("leads check: ours \(Fmt.score(mine)) (c \(Fmt.trim(s.models[i].c, 2))) vs \(top?.model ?? "-") \(Fmt.score(top?.index ?? 0)) (c \(Fmt.trim(top?.c ?? 0, 2)))")
        let held = s.competitors.filter { $0.alive && ((($0.models + $0.openModels).map(\.index).max() ?? 0) < s.models[i].index) }.reduce(0) { $0 + $1.apiShare }
        _ = s.release(id, api: true, openWeights: false, plan: LaunchPlan())
        // Benchmarks saturate in this era (a rival's skills keep it ahead on the index), so when the release didn't top
        // the board, ask the market directly what a new #1 would win.
        let won = rank == 1 ? s.deals.filter { !$0.active }.count : Launches.winLeads(&s, s.models[i])
        r.expect("a new #1 turns weaker rivals' enterprise clients into leads", won > 0 && won <= 3, "\(won) leads (had \(leads) open before; rank \(rank), rivals beaten hold \(Fmt.pct(held, decimals: 1)) of the API)")
        let titles = s.deals.filter { !$0.active }.map(\.title)
        r.expect("…for the work it does best", titles.allSatisfy { t in
            Capabilities.dealFitPoints(s.models[i], title: t, s) >= (Launches.dealTitles(s.year).map { Capabilities.dealFitPoints(s.models[i], title: $0, s) }.sorted(by: >).dropFirst(2).first ?? -99)
        }, titles.joined(separator: ", "))
    }

    // MARK: 8b. Rivals notice loud launches

    /// Stealth vs keynote: how often rivals with a run in post-training notice a big leap and answer it.
    static func answers(_ base: GameState, _ r: inout ScenarioHarness.Report) {
        guard let best = base.models.filter({ $0.released && !$0.retired }).max(by: { $0.index < $1.index }) else { return }
        var stealth = 0, keynote = 0
        for k in 0..<12 {
            for (plan, counter) in [(LaunchPlan(strategy: .stealth), 0), (LaunchPlan(strategy: .keynote), 1)] {
                var t = base
                for _ in 0..<(k * 9) { Sim.advanceDay(&t) }
                let j = clone(&t, best, name: "Harness Answer \(k)")
                t.models[j].c += 1.5
                t.models[j].index = BenchmarkCatalog.index(Leaderboard.profile(t.models[j]), set: Leaderboard.indexSet(t))
                let n0 = t.rumors.filter { $0.kind == "codered" || $0.kind == "hold" }.count
                _ = t.release(t.models[j].id, api: true, openWeights: false, plan: plan)
                let n = t.rumors.filter { $0.kind == "codered" || $0.kind == "hold" }.count - n0
                if counter == 0 { stealth += n } else { keynote += n }
            }
        }
        r.note("rival answers to a big leap over 12 launches: stealth \(stealth), keynote \(keynote)")
        r.expect("a stealth drop provokes far fewer rival answers than a keynote", keynote > 0 && stealth * 3 <= keynote, "stealth \(stealth) vs keynote \(keynote)")
    }

    // MARK: 9. Contracts churn at renewal

    static func renewals(_ base: GameState, _ best: AIModel, _ r: inout ScenarioHarness.Report) {
        var s = base
        // Contracts on a weak old model, each at its first renewal, for work rivals now do far better.
        guard let weak = s.models.filter({ $0.released }).min(by: { $0.index < $1.index }) else { return }
        for k in 0..<12 {
            s.deals.append(EnterpriseDeal(client: "Harness Client \(k)", title: "coding assistant rollout", monthly: 1e6, tokensPerDay: 1e6, months: 24, monthsLeft: 12,
                                          minIndex: 0, minSafety: 0, expires: s.date, modelID: weak.id, active: true))
        }
        let gap = (Capabilities.bestRivalFor(s, title: "coding assistant rollout")?.score ?? 0) - (s.domainScores[weak.id.uuidString]?.mix(Capabilities.dealDomains("coding assistant rollout")) ?? 0)
        let n0 = s.deals.count
        Launches.renewals(&s)
        let lost = n0 - s.deals.count
        r.expect("contracts on a model rivals beat by \(Int(gap)) points churn at renewal", gap <= Launches.churnGap || lost > 0, "\(lost) of 12 left")
    }

    // MARK: 10. Rival books add up

    static func rivals(_ r: inout ScenarioHarness.Report) {
        var s = ScenarioHarness.newGame(era: "2026", seed: 5, name: "Harness Rivals")
        var bot = PTBot()
        var parentCash: [Double] = []
        for year in 0..<5 {
            ScenarioHarness.play(&s, &bot, days: 365)
            parentCash.append(s.competitors.first { $0.id == "deepgrove" }?.cash ?? 0)
            if year == 0 { answers(s, &r) }   // rivals' runs are their own after October 2026
        }
        ScenarioHarness.sanity(s, &r)
        r.expect("a parent-funded lab's cash moves (it isn't a frozen $0)", Set(parentCash.map { Int($0 / 1e6) }).count >= 3, parentCash.map { Fmt.money($0) }.joined(separator: " → "))
        let alive = s.competitors.filter { $0.alive && !$0.models.isEmpty }
        let rich = alive.filter { $0.revenueRun > 5e8 }
        let worst = rich.map { $0.valuation / $0.revenueRun }.max() ?? 0
        r.expect("rival valuations stay within 100× revenue", worst <= 100, "highest \(Int(worst))×")
        let snap = Market.snapshot(s)
        let ent = s.competitors.filter { !$0.acquired }.reduce(0) { $0 + RivalEconomy.enterpriseRevenue($1, snap, s) }
        r.expect("rivals' enterprise revenue fits in the enterprise pool", ent <= snap.enterprisePool / 12 * 1.0001, "\(Fmt.money(ent)) of \(Fmt.money(snap.enterprisePool / 12)) a month")
        let techs = s.rivalBooks.values.reduce(0) { $0 + $1.techniques }
        r.note("rival R&D: \(techs) proprietary techniques in five years; pivots: \(s.marketMoves.lastPivot.map { $0.gameShort } ?? "none")")
        r.expect("rivals' R&D spending buys techniques over time", techs > 0, "\(techs)")
        // A runaway leader: the strongest unspecialised rival pivots to where you're weakest.
        var p = s
        p.marketMoves.lastPivot = nil
        p.monthsAtTop = 12
        if let bi = p.models.indices.filter({ p.models[$0].released && !p.models[$0].retired }).max(by: { p.models[$0].c < p.models[$1].c }) {
            p.models[bi].c = (p.competitors.compactMap { $0.latest?.c }.max() ?? p.models[bi].c) + 0.5
            Capabilities.refreshLabs(&p)
            let before = Dictionary(uniqueKeysWithValues: p.competitors.map { ($0.id, Nations.focus(p, $0.id)) })
            RivalStrategy.pivot(&p)
            let moved = p.competitors.filter { Nations.focus(p, $0.id) != before[$0.id] ?? nil }
            r.expect("a rival pivots when your lead is wide and long-held", moved.count == 1 && RivalStrategy.capabilityFocuses.contains(Nations.focus(p, moved[0].id) ?? .consumer),
                     moved.map { "\($0.def.name) → \(Nations.focus(p, $0.id)?.noun ?? "-")" }.joined(separator: ", "))
            r.expect("…and the news says why", p.news.prefix(3).contains { $0.title.contains("pivots to") && $0.body.contains("led for 12 months") })
        }
        // Compute commitments need leased capacity, cost the rival cash and give it compute.
        var t = s
        t.leases = [:]
        t.computeCommitments = []
        r.expect("no leased chips, no compute commitment", RivalEconomy.commitmentOffer(t, invest: 1e9) == nil)
        // The bot rents its chips; give the lab some of its own to lease out.
        if let site = t.sites.first?.id {
            t.owned.append(OwnedBatch(accelID: HardwareCatalog.h100.id, count: 2_000, siteID: site, purchased: t.date, unitCost: 25_000))
        }
        if let p = Economy.pools(t).first(where: { $0.accel.id == HardwareCatalog.h100.id && $0.owned > 0 }), let lab = alive.first {
            t.leases[p.accel.id] = p.owned / 2
            let leasedH = Double(p.owned / 2) * RivalEconomy.h100e(p.accel)
            // A cheque whose two-for-one commitment is twice what the leased chips can carry.
            let invest = leasedH * RivalEconomy.commitRate(p.accel, t) * 24
            r.expect("a big enough cheque comes with a commitment once you lease chips", RivalEconomy.commitmentOffer(t, invest: invest) != nil)
            if let offer = RivalEconomy.commitmentOffer(t, invest: invest) {
                r.expect("a commitment is capped by your leased capacity", offer.h100e <= leasedH + 1e-6, "\(Fmt.count(offer.h100e)) of \(Fmt.count(leasedH)) H100e")
                var c = ComputeCommitment(labID: lab.id, labName: lab.def.name, monthly: offer.monthly, monthsLeft: 24)
                c.accelID = offer.accelID
                c.h100e = offer.h100e
                t.computeCommitments = [c]
                let li = t.competitors.firstIndex { $0.id == lab.id }!
                let cash0 = t.competitors[li].cash, compute0 = t.competitors[li].computeH100e, mine0 = t.cash
                RivalEconomy.commitments(&t)
                r.expect("the rival pays from its own cash and gains the compute", t.competitors[li].cash < cash0 - offer.monthly * 0.99 && t.competitors[li].computeH100e > compute0,
                         "cash −\(Fmt.money(cash0 - t.competitors[li].cash)), compute +\(Fmt.count(t.competitors[li].computeH100e - compute0)) H100e")
                r.expect("you aren't paid twice (it arrives as lease income)", abs(t.cash - mine0) < 1, "\(Fmt.money(t.cash - mine0))")
                var open = t
                open.computeCommitments = []
                ChipBusiness.leases(&open)
                ChipBusiness.leases(&t)
                r.expect("committed chips earn at full occupancy", t.leaseRevenueToday > open.leaseRevenueToday,
                         "\(Fmt.money(open.leaseRevenueToday))/day on the open market → \(Fmt.money(t.leaseRevenueToday))/day with the commitment")
            }
        }
    }
}

/// Signed point changes for harness lines (CapStyle lives in the views).
enum CapStyleText {
    static func delta(_ d: Double) -> String { d >= 0 ? "+\(Fmt.trim(d, 1))" : "−\(Fmt.trim(-d, 1))" }
}
