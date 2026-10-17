import Foundation

/// Headless balance checks: `TensorTycoon --simulate [era]` prints calibration tables and a scripted playthrough.
enum BalanceHarness {
    /// Real frontier runs vs. what the forecast engine predicts for a lab with all public research of that year.
    static func forecastCheck() {
        struct Case { let name: String; let y: Double; let flops: Double; let ratio: Double; let moe: Double; let target: Double; let mmlu: Double? }
        let cases = [
            Case(name: "GPT-3 175B", y: 2020.4, flops: 3.1e23, ratio: 1.7, moe: 1, target: 2.78, mmlu: 43.9),
            Case(name: "Gopher 280B", y: 2021.9, flops: 5.0e23, ratio: 1.07, moe: 1, target: 3.5, mmlu: 60.0),
            Case(name: "Chinchilla 70B", y: 2022.25, flops: 5.8e23, ratio: 20, moe: 1, target: 3.83, mmlu: 67.6),
            Case(name: "PaLM 540B", y: 2022.3, flops: 2.5e24, ratio: 1.45, moe: 1, target: 3.9, mmlu: 69.3),
            Case(name: "LLaMA 65B", y: 2023.15, flops: 5.5e23, ratio: 21.5, moe: 1, target: 3.65, mmlu: 63.4),
            Case(name: "GPT-4 (MoE)", y: 2023.2, flops: 2.1e25, ratio: 46, moe: 0.125, target: 5.04, mmlu: 86.4),
            Case(name: "Llama 3 70B", y: 2024.3, flops: 6.3e24, ratio: 214, moe: 1, target: 4.65, mmlu: 82.0),
            Case(name: "Llama 3.1 405B", y: 2024.55, flops: 3.8e25, ratio: 38.5, moe: 1, target: 5.36, mmlu: 88.6),
            Case(name: "DeepSeek-V3 (MoE)", y: 2024.95, flops: 3.3e24, ratio: 400, moe: 0.055, target: 5.35, mmlu: 88.5),
            Case(name: "Kimi K2 (MoE, Muon)", y: 2025.5, flops: 3.0e24, ratio: 484, moe: 0.032, target: 5.6, mmlu: 89.5),
            Case(name: "Grok 4 (5e26)", y: 2025.5, flops: 5e26, ratio: 20, moe: 0.125, target: 7.0, mmlu: nil),
            Case(name: "Frontier 2026.8 (1e27)", y: 2026.8, flops: 1e27, ratio: 20, moe: 0.0625, target: 8.1, mmlu: nil),
        ]
        print("model                       year   raw    alloc  algo   data   c(pred)  target  Δ      σ")
        for k in cases {
            var s = NewGame.create(NewGameSettings(companyName: "Check", founderName: "Bot", eraID: "2017", difficulty: .normal), seed: 7)
            s.date = GameCalendar.date(Int(k.y), Int((k.y - Double(Int(k.y))) * 12) + 1, 15)
            s.researched = Set(ResearchCatalog.core.filter { $0.year <= k.y && $0.category != .frontier }.map(\.id))
            s.dataSources = ["web", "wiki", "code_open", "papers", "books_license"]
            var d = ModelDesign()
            d.activeFraction = k.moe
            // N_active from flops and tokens/param ratio: C = 6 N (ratio N)
            let nActive = sqrt(k.flops / (6 * k.ratio))
            d.paramsB = nActive / 1e9 / k.moe
            d.tokensT = k.ratio * nActive / 1e12
            let b = s.bonuses
            d.optimizer = k.name.contains("Muon") ? .muon : .adamw
            d.attention = b.has(.mla) ? .mla : (b.has(.gqa) ? .gqa : .mha)
            d.mtp = b.has(.mtp) && k.y > 2024.9
            d.anneal = b.has(.curriculum)
            d.instruct = b.has(.chat)
            let f = ForecastEngine.forecast(d, state: s, dataSources: Array(s.dataSources))
            print(String(format: "%-27@ %.2f  %5.2f  %5.2f  %5.2f  %5.2f  %6.2f   %5.2f  %+5.2f  %.2f",
                         k.name as NSString, k.y, f.rawC, f.allocation + f.repetition, f.algo, f.data, f.c, k.target, f.c - k.target, f.sigma))
        }
    }

    static func run(era: String) {
        print("== Frontier calibration (frontier-lab profile) ==")
        let ids = ["mmlu", "mmlu_pro", "gpqa", "swe", "swe_pro", "aime", "hle", "arc2", "arc3", "osworld", "gdpval", "frontiermath"]
        print("year   c     " + ids.map { $0.padding(toLength: 7, withPad: " ", startingAt: 0) }.joined(separator: "") + " horizon")
        for y in stride(from: 2018.0, through: 2031.0, by: 1.0) {
            let c = Macro.frontier(y)
            let p = ModelProfile(key: "cal\(y)", c: c, reasoning: y >= 2024.7 ? 0.6 : (y > 2022.1 ? 0.1 : 0),
                                 code: (y > 2024.5 ? 0.15 : 0) + (y > 2025.2 ? 0.15 : 0), agent: y > 2025 ? 0.3 : (y > 2023.5 ? 0.1 : 0),
                                 vision: true, contextK: 1000, tuning: 0)
            let cols = ids.map { id -> String in
                let b = BenchmarkCatalog.realByID[id]!
                return String(format: "%-7.1f", b.score(p, noise: false))
            }.joined()
            print(String(format: "%.0f  %5.2f ", y, c) + cols + " " + BenchmarkCatalog.formatHorizon(BenchmarkCatalog.taskHorizonMinutes(p)))
        }

        var s = NewGame.create(NewGameSettings(companyName: "Bot Labs", founderName: "Bot", eraID: era, difficulty: .normal), seed: 42)
        print("\n== Leaderboard at start (\(s.date.gameShort)) ==")
        for e in Leaderboard.entries(s).prefix(8) {
            print(String(format: "%-24@ %-18@ c=%5.2f idx=%5.1f price=$%.3f params≈%@", e.model as NSString, e.lab as NSString, e.c, e.index, e.price ?? 0,
                         Fmt.params(e.paramsB ?? 0) as NSString))
        }

        // Scripted strategy
        let starter = s.owned.first!.accelID
        var design = ModelDesign()
        design.name = "Bot-1"
        design.accelID = starter
        design.chips = 4
        design.paramsB = 0.3
        design.tokensT = 0.006
        design.instruct = s.bonuses.has(.chat)
        print("\nStarter: \(starter) — first run estimate:")
        if let est = Physics.estimate(design, state: s) {
            print("  flops \(Fmt.flops(est.flops)) days \(Fmt.trim(est.days, 1)) mfu \(Fmt.trim(est.mfu, 2)) c \(Fmt.trim(est.forecast.c, 2)) ± \(Fmt.trim(est.forecast.sigma, 2)) mem ok \(est.memory.ok)")
        }
        if let err = s.startTraining(design) { print("  start error: \(err)") }

        var lastYear = 0
        var modelN = 1
        for day in 0..<(365 * 5) {
            Sim.advanceDay(&s)
            if s.gameOver != nil { print("GAME OVER: \(s.gameOver!)"); break }
            // Resolve decisions with option 0 (except acquisitions)
            for d in s.decisions { s.resolveDecision(d.id, option: d.kind == "acquisition" ? 1 : 0) }
            // Hire a researcher each quarter when affordable
            if day % 90 == 0, let c = s.candidates.first(where: { $0.role == .researcher && $0.salary < s.cash / 20 }) { _ = s.hire(c.id) }
            if day % 120 == 30, let c = s.candidates.first(where: { $0.role == .mlEngineer && $0.salary < s.cash / 20 }) { _ = s.hire(c.id) }
            // Keep research queue going
            if s.researchQueue.isEmpty {
                if let next = ResearchCatalog.all.filter({ !s.researched.contains($0.id) && $0.category != .frontier })
                    .min(by: { Sim.researchCost($0, year: s.year) < Sim.researchCost($1, year: s.year) }) {
                    s.queueResearch(next.id)
                }
            }
            // Release & deploy finished models
            for m in s.models where !m.released {
                _ = s.release(m.id, api: true, openWeights: false)
                if s.bonuses.has(.chat) { s.chatModelID = m.id }
            }
            // Price the chat app at what its users will pay (revenue peaks there).
            s.chatPrice = max(5, Market.chatWTP(s).rounded())
            for m in s.models where m.released && !m.retired {
                // Re-allocate all free chips of the best type to the newest model
                for p in Economy.pools(s) where p.free > 0 && m.id == s.models.last?.id {
                    let cur = m.deployments.first { $0.accelID == p.accel.id }?.chips ?? 0
                    _ = s.deploy(m.id, accelID: p.accel.id, chips: cur + p.free / 2)
                }
            }
            // Raise money when runway is short
            if s.cash < 3e6 && !s.raising && s.raiseOffers.isEmpty { _ = s.startRaise(fraction: 0.2) }
            if let o = s.raiseOffers.first { _ = s.acceptOffer(o.id) }
            // Rent more compute and train a bigger model when nothing is training
            if !s.runs.contains(where: { $0.status == .running || $0.status == .postTraining }) && s.cash > 5e6 {
                let rentable = HardwareCatalog.all.filter { Economy.canRent($0, s) && $0.cls == .datacenter }
                if let best = rentable.max(by: { $0.trainTFLOPS(.bf16) / (Economy.rent($0, s) ?? 99) < $1.trainTFLOPS(.bf16) / (Economy.rent($1, s) ?? 99) }) {
                    let budget = s.cash * 0.3
                    let perChipMonth = (Economy.rent(best, s) ?? 1) * 24 * 30
                    let want = max(8, min(Economy.rentalLimit(best, s), Int(budget / perChipMonth / 2)))
                    let have = Economy.freeChips(s, best.id)
                    if have < want { _ = s.rentHardware(best.id, count: want - have, term: .onDemand) }
                    let chips = Economy.freeChips(s, best.id)
                    guard chips >= 8 else { continue }
                    modelN += 1
                    var d = ModelDesign()
                    d.name = "Bot-\(modelN)"
                    d.accelID = best.id
                    d.chips = chips
                    let perDay = Double(d.chips) * best.trainTFLOPS(.bf16) * 1e12 * 0.35 * 86_400
                    let C = perDay * 45
                    let N = sqrt(C / 120)
                    d.paramsB = max(0.1, N / 1e9)
                    d.tokensT = max(0.001, 20 * N / 1e12)
                    d.instruct = s.bonuses.has(.chat)
                    d.rlhf = s.bonuses.has(.rlhf)
                    d.reasoning = s.bonuses.has(.reasoning)
                    let memCap = Double(chips) * best.memoryGB / 17.6
                    if s.bonuses.has(.moe) && d.paramsB * 8 < memCap { d.activeFraction = 1.0 / 8; d.paramsB *= 8 }
                    d.paramsB = min(d.paramsB, memCap * 0.95)
                    if let err = s.startTraining(d) { print("  [\(s.date.gameShort)] start error: \(err)") }
                }
            }
            let y = s.date.ym.year
            if y != lastYear && s.date.ym.month == 1 || day == 365 * 5 - 1 {
                lastYear = y
                let best = s.models.max { $0.c < $1.c }
                let top = Leaderboard.entries(s).first
                print(String(format: "[%@] cash %@ val %@ rr %@ users %@ chips %d | best %@ c=%.2f idx=%.1f | world #1 %@ idx=%.1f | brand %.0f rel %.2f RP/d %.1f",
                             s.date.gameShort as NSString, Fmt.money(s.cash) as NSString, Fmt.money(s.valuation) as NSString,
                             Fmt.money(Economy.runRate(s)) as NSString, Fmt.count(s.consumerUsers) as NSString, Economy.totalChips(s),
                             (best?.name ?? "-") as NSString, best?.c ?? 0, best?.index ?? 0, (top?.model ?? "-") as NSString, top?.index ?? 0,
                             s.brand, s.reliability, s.rpToday))
                if let h = s.history.last {
                    print(String(format: "     last month: rev %@ (api %@ cons %@ ent %@) | rent %@ power %@ payroll %@ sites %@ data %@",
                                 Fmt.money(h.revenue) as NSString, Fmt.money(h.revAPI) as NSString, Fmt.money(h.revConsumer) as NSString,
                                 Fmt.money(h.revEnterprise) as NSString, Fmt.money(h.costRent) as NSString, Fmt.money(h.costPower) as NSString,
                                 Fmt.money(h.costPayroll) as NSString, Fmt.money(h.costSites) as NSString, Fmt.money(h.costData) as NSString))
                }
                for m in s.models.suffix(2) {
                    print(String(format: "     model %@ c=%.2f idx %.1f price $%.3f cap %@/d demand %@/d tps %.0f rev/d %@", m.name as NSString, m.c, m.index, m.apiPrice,
                                 Fmt.count(m.capacityTokensDay) as NSString, Fmt.count(m.demandTokensDay) as NSString, m.tps, Fmt.money(m.revenueDay) as NSString))
                }
            }
        }
        print("\nNews sample:")
        for n in s.news.prefix(12) { print("  \(n.date.gameShort) [\(n.category.rawValue)] \(n.title)") }
        benchReport(s)
        rsiTest(s)
        siliconTest(s)
    }

    static func siliconTest(_ start: GameState) {
        var s = start
        s.gameOver = nil
        s.decisions.removeAll()
        s.cash = max(s.cash, 2e9)
        s.researched.insert("custom_silicon")
        print("\n== Silicon test from \(s.date.gameShort) ==")
        for (partner, focus) in [(ChipPartner.broadcom, ChipFocus.training), (.inHouse, .inference)] {
            var t = s
            if let e = t.startChipProject(partner: partner, focus: focus, budget: 5e8) { print("  start error: \(e)"); continue }
            var day = 0
            while t.customChips.isEmpty && day < 1200 {
                Sim.advanceDay(&t)
                for d in t.decisions { t.resolveDecision(d.id, option: d.kind == "acquisition" ? 1 : 0) }
                t.gameOver = nil
                day += 1
            }
            if let c = t.customChips.last, let p = t.chipProjects.last {
                print(String(format: "  %@ %@: %d days, %d respins, spent %@ -> %@ bf16 %.0f fp8 %.0f fp4 %.0f %.0fGB %.1fTB/s %.0fW $%.0f",
                             partner.rawValue as NSString, focus.rawValue as NSString, day, p.respins, Fmt.money(p.spent) as NSString,
                             c.name as NSString, c.bf16, c.fp8, c.fp4, c.memoryGB, c.bandwidthTBs, c.tdpW, c.unitCost))
                print("     store sees it: \(HardwareCatalog.get(c.id).map { "\($0.name), buyable \(Economy.canBuy($0, t))" } ?? "missing")")
                // Sell it to other companies for a year.
                if let e = t.openChipLine(c.id) ?? t.addFabCapacity(c.id, units: 20_000) { print("     sales error: \(e)"); continue }
                let price = t.chipLines.first?.price ?? 0
                let cash0 = t.cash
                for _ in 0..<365 {
                    Sim.advanceDay(&t)
                    for d in t.decisions { t.resolveDecision(d.id, option: d.kind == "acquisition" ? 1 : 0) }
                    t.gameOver = nil
                }
                if let line = t.chipLines.first {
                    print(String(format: "     sold 1y at $%.0f: %@ chips, revenue %@, profit %@ (capacity cost incl. in cash Δ %@), reputation %.2f",
                                 price, Fmt.count(line.shipped) as NSString, Fmt.money(line.revenue) as NSString, Fmt.money(line.profit) as NSString,
                                 Fmt.money(t.cash - cash0) as NSString, ChipBusiness.reputation(t)))
                }
            } else {
                print("  \(partner.rawValue): no chip after \(day) days")
            }
        }
    }

    static func benchReport(_ s: GameState) {
        print("\n== Benchmarks at \(s.date.gameShort) ==")
        print("tracked \(s.benchmarks.count) · saturated \(s.benchSaturated.count) · generated \(s.generatedBenchmarks.count)")
        for g in s.generatedBenchmarks { print("  + \(g.name) [\(g.family)] intro \(g.introduced.label) mid \(Fmt.trim(g.mid, 2))") }
        let set = Leaderboard.indexSet(s)
        let top = Leaderboard.entries(s, set: set).filter(\.released).max { $0.index < $1.index }
        print("index set: " + set.map { b in "\(b.name) \(Fmt.score(top.map { $0.score(b) } ?? 0))" }.joined(separator: " · "))
    }

    static func rsiTest(_ start: GameState) {
        var s = start
        for id in ["continual_learning", "world_models", "auto_research", "unified_arch", "rsi", "tool_use", "agents"] { s.researched.insert(id) }
        guard let base = s.models.max(by: { $0.c < $1.c }) else { print("RSI test: no model"); return }
        // Free chips: pull them from inference
        for i in s.models.indices { s.models[i].deployments.removeAll() }
        guard let pool = Economy.pools(s).max(by: { Double($0.free) * $0.accel.bf16 < Double($1.free) * $1.accel.bf16 }), pool.free > 0 else { print("RSI test: no chips"); return }
        print("\n== RSI test on \(base.name) c=\(Fmt.trim(base.c, 2)) with \(pool.free)× \(pool.accel.name) ==")
        for (autonomy, oversight) in [(1, 0.2), (2, 0.05)] {
            var t = s
            t.gameOver = nil
            t.decisions.removeAll()
            t.cash = max(t.cash, 1e10)
            if let e = t.startRSI(baseModelID: base.id, target: .capabilities, autonomy: autonomy, oversight: oversight, checkpointEvery: 2,
                                  accelID: pool.accel.id, chips: pool.free) { print("  start error: \(e)"); continue }
            for day in 0..<540 {
                Sim.advanceDay(&t)
                for d in t.decisions { t.resolveDecision(d.id, option: d.kind == "acquisition" ? 1 : 0) }
                if t.gameOver != nil { print("  GAME OVER day \(day): \(t.gameOver!)"); break }
            }
            if let r = t.rsiRuns.last {
                print("  autonomy \(autonomy) oversight \(oversight): gen \(r.generation) status \(r.status.rawValue) c \(Fmt.trim(r.cStart, 2))→\(Fmt.trim(r.c, 2)) measured \(Fmt.trim(r.cMeasured, 2)) align \(Int(r.alignment)) (measured \(Int(r.alignmentMeasured))) cps \(r.checkpoints.count) cost \(Fmt.money(r.cost))")
                for line in r.log.prefix(6) { print("     \(line)") }
            }
        }
    }
}
