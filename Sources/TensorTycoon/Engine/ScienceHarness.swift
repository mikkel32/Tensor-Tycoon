import Foundation

// MARK: - 3.6: science labs and the data economy in the playtest bot
//
// `science` flag: the bot builds and staffs several kinds of lab and uses every follow-up choice. `data` flag: it buys
// curated data, commissions annotation, generates synthetic data and processes what it holds, and logs each training
// run's data plan at launch against what the finished model got. Without the flags the bot never touches either.

extension PTPlay {
    /// Labs a sensible player builds, in order: energy (power and grid), computing (maths, software, fusion control),
    /// materials (chips, superconductors), electronics (quantum). One at a time, each once it's small next to the cash
    /// pile and the labs before it are busy; staffed for their capacity; equipment upgraded while cheap; a project in
    /// every free slot (the lab's own fields first, easiest first) with agents once models can use them.
    static let labPlan: [LabKind] = [.energy, .computing, .materials, .electronics]

    /// What the labs' energy results saved over the game: cloud and colocation rebates, and the power bill.
    static var scienceSavings: (rent: Double, power: Double) = (0, 0)

    static func science(_ s: inout GameState) {
        if s.science.labs.isEmpty && s.science.spentBuild == 0 { scienceSavings = (0, 0) }   // a new game, no lab yet
        // Last month's savings (this runs on the 2nd): rentals at today's provider rebate, and the power bill.
        let rent = s.rentals.reduce(0) { $0 + $1.hourly * 24 * 30.4 * Double($1.count) }
        scienceSavings.rent += rent * (1 / Science.cloudFactor(s) - 1)
        if let last = s.history.last { scienceSavings.power += last.costPower * (1 / Science.powerFactor(s) - 1) }
        let site = ScienceCatalog.siteByID[s.hqCity] != nil ? s.hqCity : "sf"
        let busy = s.science.labs.allSatisfy { !$0.isReady(s.date) || !Science.active($0, s).isEmpty }
        if s.science.labs.count < labPlan.count, busy {
            let kind = labPlan[s.science.labs.count]
            if s.cash > 25 * Science.capex(kind, site: site, s) { _ = s.buildLab(kind, site: site, staff: 8) }
        }
        let agents = Science.agentScore(s) > 100 ? 8 : 0
        for lab in s.science.labs where lab.isReady(s.date) {
            let want = Int(Science.staffPerProject) * Science.capacity(lab)
            if lab.staff < want { _ = s.hireScientists(lab.id, want - lab.staff) }
            if lab.equipment < 3 && lab.upgradeReady == nil && s.cash > 40 * Science.upgradeCost(lab, s) { _ = s.upgradeLab(lab.id) }
            while let l = s.science.labs.first(where: { $0.id == lab.id }), Science.active(l, s).count < Science.capacity(l),
                  let next = Science.available(l, s).first(where: { l.def.primary.contains($0.field) }) ?? Science.available(l, s).first {
                if s.startScienceProject(next.id, lab: lab.id, agents: agents, compute: 1) != nil { break }
            }
        }
    }

    /// Every follow-up gets used: feed a moonshot that's running, spin out what feeds a product line, publish
    /// mathematics and software, keep speculative results secret, patent the rest. Unique breakthroughs: the policy's
    /// default (keep them, or leave them published), so the playtest's economy isn't swamped by licence windfalls
    /// (the summary prints the best offer each one drew; `--data-check` covers licensing).
    static func scienceChoice(_ dd: Decision, _ s: GameState) -> Int {
        if dd.ref.hasPrefix(Science.breakthroughPrefix) { return 0 }
        let parts = dd.ref.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let codes = parts.count >= 2 ? parts[1].split(separator: ",").map(String.init) : []
        guard let id = parts.first.flatMap({ UUID(uuidString: $0) }),
              let disc = s.science.discoveries.first(where: { $0.id == id }), let d = disc.projectDef else { return 0 }
        let f = ScienceCatalog.field(d.field)
        func pick(_ c: SciChoice) -> Int? { codes.firstIndex(of: c.rawValue) }
        if let i = pick(.moonshot), parts.count > 2, s.moonshots.contains(where: { $0.id == parts[2] && $0.status == .running }) { return i }
        if !f.product.isEmpty, let i = pick(.spinout) { return i }
        if d.field == .mathematics || d.field == .software, let i = pick(.publish) { return i }
        if d.speculative && disc.scooped.isEmpty, let i = pick(.secret) { return i }
        return pick(.patent) ?? 0
    }

    static func scienceSummary(_ s: GameState, seed: UInt64) {
        let sc = s.science
        var byStatus: [String: Int] = [:]
        for p in sc.projects { byStatus[p.status.rawValue, default: 0] += 1 }
        let reruns = sc.projects.reduce(0) { $0 + $1.log.filter { $0.outcome == "rerun" }.count }
        print("SCIENCE seed \(seed): " + sc.labs.map { "\($0.name) eq\($0.equipment) staff \($0.staff) skill \(Int($0.skill))" }.joined(separator: ", "))
        print("  projects \(sc.projects.count): " + byStatus.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " ") + " · reruns \(reruns)")
        print("  spent: build \(m(sc.spentBuild)), running \(m(sc.spentRun)) · income: licences \(m(sc.licensing)), spin-outs \(m(sc.spinoutCash)) · last month cost \(m(sc.lastCost)), income \(m(sc.lastIncome))")
        for p in sc.projects {
            let d = p.projectDef
            let trail = p.log.map { "\(String(Science.stageName(SciStage(rawValue: $0.stage) ?? .hypothesis, d?.field ?? .energy).prefix(4)))\($0.outcome == "passed" ? "✓" : ($0.outcome == "rerun" ? "↺" : "✗"))" }.joined(separator: " ")
            print("  \(d?.name ?? p.def) [\(p.status.rawValue)] \(p.started.gameShort)→\(p.ended?.gameShort ?? "…") \(m(p.spent)): \(trail)")
        }
        for d in sc.discoveries {
            let patent = sc.patents.first { $0.discovery == d.id }
            print("  ★ \(d.date.gameShort) \(d.title) · level \(Fmt.trim(d.level, 2)) · \(d.choice.isEmpty ? "pending" : d.choice)\(patent.map { " (\($0.licensees) licensees, \(m($0.lifetime)))" } ?? "")\(d.scooped.isEmpty ? "" : " · scooped by \(d.scooped)")\(d.commercialised.map { " · commercialised \($0.gameShort)" } ?? "")\(d.labScaleOnly ? " · lab scale" : "")")
        }
        for b in sc.breakthroughs { print("  ✦ \(b.date.gameShort) unique breakthrough \(b.title) · \(Science.breakthroughChoiceLabel(b))\(b.upfront > 0 ? " (\(m(b.upfront)))" : "")") }
        for u in ScienceCatalog.unlocks { if let when = Science.unlockDate(u.unlock, s) { print("  ⚑ \(when.gameShort) unlocked: \(u.title)") } }
        if let last = s.history.last, Science.powerFactor(s) < 1 {
            let without = last.costPower / Science.powerFactor(s)
            print("  power bill last month \(m(last.costPower)) (≈ \(m(without)) without the discoveries: saving \(m(without - last.costPower))/month)")
        }
        // What renting costs less: last month's cloud bill at today's provider rebate.
        let rent = s.rentals.reduce(0) { $0 + $1.hourly * 24 * 30.4 * Double($1.count) }
        let rebate = rent * (1 / Science.cloudFactor(s) - 1)
        let costs = sc.spentBuild + sc.spentRun, income = sc.licensing + sc.spinoutCash
        let saved = scienceSavings.rent + scienceSavings.power
        print("  P&L: costs \(m(costs)), licences and spin-outs \(m(income)), savings \(m(saved)) (rentals \(m(scienceSavings.rent)), power \(m(scienceSavings.power))) → \(m(income + saved - costs)) · today: cloud ×\(Fmt.trim(Science.cloudFactor(s), 4)) ≈ \(m(rebate))/month on \(m(rent))/month of rentals, colocation ×\(Fmt.trim(Science.coloFactor(s), 3))")
        let offers = sc.breakthroughs.compactMap { b in ResearchLab.licenseBuyers(s, tech: b.tech).first.map { "\(b.title) \(m($0.upfront))" } }
        if !offers.isEmpty { print("  unique breakthroughs kept (best licence offer today): " + offers.joined(separator: ", ")) }
        print("  effects: power bill ×\(Fmt.trim(Science.powerFactor(s), 3)) (all factors ×\(Fmt.trim(Power.billFactor(s), 3))) · battery capex ×\(Fmt.trim(Science.storageCapexFactor(s), 3)) · build ×\(Fmt.trim(Science.buildFactor(s), 3)) · grid queue ×\(Fmt.trim(Science.queueFactor(s), 3)) · fusion \(Fmt.trim(Science.fusionPullIn(s), 2)) yr sooner · rival results \(sc.rivals.count) (scooped you \(sc.rivals.filter(\.scoopedYou).count), reproduced yours \(sc.rivals.filter(\.reproduced).count))")
        let rivalKnow = s.competitors.filter(\.alive).map { c in (c.def.name, Science.rivalKnowHow(s, lab: c.id, at: s.year).reduce(0) { $0 + $1.1 }) }.filter { $0.1 > 0 }
        if !rivalKnow.isEmpty { print("  rival know-how from science: " + rivalKnow.map { "\($0.0) +\(Fmt.trim($0.1 * 10, 1)) pts" }.joined(separator: ", ")) }
        let history = Science.companyHistory(s)
        print("  company history: \(history.count) entries · " + Dictionary(grouping: history, by: \.kind).map { "\($0.key) \($0.value.count)" }.sorted().joined(separator: " "))
    }

    // MARK: Data economy (the `data` flag)

    /// Each training run's data plan when the bot first saw it running (≈ launch), for the summary.
    static var dataPlans: [UUID: (name: String, plan: DataPlanSummary)] = [:]

    /// Buy one curated dataset in the bot's field (code), keep a labelling pilot running for RLHF, generate verified
    /// synthetic code with its best model about once a year, and run the pipeline (dedup, filter, verify) on what it
    /// holds — each only when it's small next to the cash pile. Logs every run's data plan as it starts.
    static func dataBot(_ s: inout GameState) {
        if s.runs.isEmpty { dataPlans = [:] }   // a new game
        for r in s.runs where r.status == .running && r.kind == .full && dataPlans[r.id] == nil {
            dataPlans[r.id] = (r.design.name, r.dataPlan ?? DataEconomy.freeze(r.design, state: s, sources: r.dataSnapshot))
        }
        guard GameCalendar.components(s.date).day == 2 else { return }
        let held = Set(s.dataEco.holdings.filter(\.active).map(\.source))
        // Curated data for the domains the bot leans on (code, then maths and textbooks).
        for id in ["code_curated", "math_proofs", "textbooks"] {
            guard !held.contains(id), let def = DataMarketCatalog.byID[id], s.year >= def.available else { continue }
            let term: DataTerm = def.terms.contains(.buy) ? .buy : .licence
            let p = DataEconomy.price(def, term)
            if s.cash > 20 * (p.upfront + p.monthly * 12) { _ = DataEconomy.acquire(&s, id, term: term); break }
        }
        // Preference labels: a crowd pilot as soon as there's RLHF to feed.
        if s.bonuses.has(.rlhf), !s.dataEco.annotation.contains(where: { $0.id == "crowd_prefs" }),
           let v = DataMarketCatalog.vendorByID["crowd_prefs"], s.year >= v.available, s.cash > 50 * v.monthly {
            _ = DataEconomy.setAnnotation(&s, vendor: v.id, tier: 1)
        }
        // Synthetic code from the best model, verified, about once a year.
        let lastSynth = s.dataEco.holdings.filter(\.synthetic).map(\.acquired).max()
        if s.bonuses.has(.syntheticData), s.dataEco.synth.isEmpty, lastSynth.map({ GameCalendar.daysBetween($0, s.date) > 330 }) ?? true,
           let best = s.models.filter({ !$0.preview && !$0.retired }).max(by: { $0.c < $1.c }) {
            let size = DataEconomy.synthRoom(s).room >= 0.2 ? 0.2 : 0.05
            if DataEconomy.synthCost(s, model: best, tokensT: size, verified: true).cost * 30 < s.cash {
                _ = DataEconomy.startSynth(&s, model: best.id, focus: .coding, tokensT: size, verified: true)
            }
        }
        // The pipeline: dedup, filter, verify — one job at a time, the curated and bought data first.
        if s.dataEco.jobs.isEmpty {
            for t in DataEconomy.targets(s) where !t.id.hasPrefix("an:") {
                guard let st = [DataStage.dedup, .filter, .verify].first(where: { st in
                    !s.dataEco.applied[t.id, default: []].contains(st.rawValue) && (st.research.map { s.researched.contains($0) } ?? true)
                }) else { continue }
                let c = DataEconomy.jobCost(s, tokensT: t.tokensT, stage: st)
                if c.cost * 40 < s.cash { _ = DataEconomy.startJob(&s, target: t.id, stage: st) }
                break
            }
        }
    }

    static func dataSummary(_ s: GameState, seed: UInt64) {
        let e = s.dataEco
        print("DATA seed \(seed): spent \(m(e.spent)) · settlements \(m(e.settlements)) · auctions won \(e.auctionsWon), lost \(e.auctionsLost) · book value \(m(DataEconomy.assetValue(s))) · data bill \(m(DataEconomy.monthlyCost(s)))/mo")
        for h in e.holdings.sorted(by: { $0.acquired < $1.acquired }) {
            print("  \(h.name) [\(h.term.rawValue)\(h.active ? "" : ", inactive")] \(Fmt.tokens(h.tokensT)) Q\(Int(h.quality.effective * 100)) noise \(Int(h.quality.noise * 100))% dup \(Int(h.quality.duplication * 100))% · stages \(e.applied[h.id, default: []].joined(separator: "+"))")
        }
        let synthetic = e.holdings.filter(\.synthetic).reduce(0) { $0 + $1.tokensT }
        let extra = DataEconomy.extraUniqueT(s)
        let filtered = s.dataSources.filter { DataMarketCatalog.legacyProfile($0).kind.isText }
            .reduce(0) { $0 + DataEconomy.legacyTokensT(s, $1, processed: false) - DataEconomy.legacyTokensT(s, $1, processed: true) } * (1 + s.bonuses.dataTokens)
        print("  synthetic held \(Fmt.tokens(synthetic)) · unique tokens the datasets add today \(extra < 0 ? "−" : "+")\(Fmt.tokens(abs(extra))) (filtering the original sources removed \(Fmt.tokens(filtered)))")
        // Each run: the plan frozen at launch vs what the finished model got.
        for r in s.runs where r.kind == .full {
            guard let logged = dataPlans[r.id] else { continue }
            let p = logged.plan
            var line = "  \(logged.name): plan at launch data \(String(format: "%+.3f", p.dData)) code \(String(format: "%+.3f", p.dCode)) reasoning \(String(format: "%+.3f", p.dReasoning)) science \(String(format: "%+.2f", 10 * p.domain(.science))) pts · synthetic \(Int(p.syntheticShare * 100))% · RLHF shortfall \(Int(p.preferenceShortfall * 100))%"
            if let id = r.modelID, let model = s.models.first(where: { $0.id == id }) {
                let now = DataEconomy.plan(r.design, state: s, sources: r.dataSnapshot)
                line += " → finished: code skill \(Fmt.trim(model.codeBoost, 3)), reasoning \(Fmt.trim(model.reasoningBoost, 3)); its data recomputed today: code \(String(format: "%+.3f", now.dCode)) reasoning \(String(format: "%+.3f", now.dReasoning))\(abs(now.dCode - p.dCode) > 0.001 || abs(now.dReasoning - p.dReasoning) > 0.001 ? " (differs from launch)" : "")"
            } else {
                line += " → \(r.status.rawValue)"
            }
            print(line)
        }
    }

    // MARK: Worked data-value comparison (`--data-value <year>`)

    /// What datasets are worth to a coding model: each alone on top of the original sources, for a coding-objective
    /// design in `year` (70B dense, 15T tokens). Prints the gains in each step of the chain and the coding points.
    static func dataValue(year: Int) {
        var base = NewGame.create(NewGameSettings(companyName: "Data Check", founderName: "Pat", eraID: "2022"), seed: 1)
        base.date = GameCalendar.date(year, 6, 1)
        var d = ModelDesign()
        d.name = "Coder"
        d.objective = .coding
        d.dataMix = .code
        d.mixShift = .code
        d.paramsB = 70
        d.tokensT = 15
        d.rlhf = true
        let student = DataEconomy.studentC(d, base)
        func holding(_ id: String) -> DataHolding {
            let def = DataMarketCatalog.byID[id]!
            return DataHolding(id: "chk:" + id, name: def.name, kind: def.kind, focus: def.focus, source: id, tokensT: def.tokensT, quality: def.quality,
                               term: .buy, acquired: base.date, refreshed: base.date, value: def.price)
        }
        func synthetic(_ tokensT: Double, teacher: Double) -> DataHolding {
            let job = SynthJob(modelID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, modelName: "Teacher", focus: .coding, tokensT: tokensT,
                               quality: 0.88 + 0.07, verified: true, started: base.date, done: base.date, cost: 0, teacherC: teacher)
            return DataEconomy.synthHolding(job, date: base.date)
        }
        let cases: [(String, [DataHolding], String)] = [
            ("code_curated (0.06T Q85, $12M)", [holding("code_curated")], "$12M"),
            ("code_bulk (2T Q41, $3M)", [holding("code_bulk")], "$3M"),
            ("web_bulk (6T Q40, $1.5M)", [holding("web_bulk")], "$1.5M"),
            ("1T synthetic code, teacher +0.3 ahead", [synthetic(1, teacher: student + 0.3)], "gen."),
            ("1T synthetic code, teacher level with design", [synthetic(1, teacher: student)], "gen."),
            ("1T synthetic code, teacher 0.2 behind design", [synthetic(1, teacher: student - 0.2)], "gen."),
            ("10T synthetic code, teacher +0.3 ahead", [synthetic(10, teacher: student + 0.3)], "gen."),
            ("code_curated + 1T synthetic (+0.3)", [holding("code_curated"), synthetic(1, teacher: student + 0.3)], "$12M+gen."),
        ]
        print("== Data value for a coding model in \(year): 70B dense, 15T tokens, code mix and shift, coding objective ==")
        print("  design forecast c ≈ \(Fmt.trim(student, 2)); original sources: \(base.dataSources.sorted().joined(separator: ", "))")
        for (name, hs, cost) in cases {
            var s = base
            s.dataEco.holdings = hs
            let p = DataEconomy.plan(d, state: s, sources: s.dataSources.sorted())
            let ci = CapDomain.coding.index
            let points = 10 * (p.dData + p.dCode + 0.6 * p.dReasoning)
            print("  \(name.padding(toLength: 46, withPad: " ", startingAt: 0)) \(cost.padding(toLength: 10, withPad: " ", startingAt: 0)) E_code \(Fmt.trim(p.baseEffective[ci], 2))→\(Fmt.trim(p.effective[ci], 2)) g_code \(String(format: "%+.3f", p.gains[ci])) dCode \(String(format: "%+.3f", p.dCode)) dReas \(String(format: "%+.3f", p.dReasoning)) dData \(String(format: "%+.3f", p.dData)) → coding \(String(format: "%+.2f", points)) pts · +\(Fmt.tokens(p.extraUniqueT + p.syntheticUniqueT)) unique · synthetic \(Int(p.syntheticShare * 100))%\(p.syntheticCapped ? " (capped by real data)" : "")\(p.restricted.isEmpty ? "" : " · research-only licence")")
        }
    }

    // MARK: Mechanics check (`--data-check`)

    /// Scripted checks of the data economy and science rules: each sets up a small situation and checks the outcome.
    /// Prints one line per check and returns the number that failed.
    static func dataCheck() -> Int {
        var failed = 0
        func check(_ name: String, _ ok: Bool, _ detail: String) {
            if !ok { failed += 1 }
            print("  \(ok ? "OK  " : "FAIL") \(name): \(detail)")
        }
        func fresh(_ year: Int) -> GameState {
            var s = NewGame.create(NewGameSettings(companyName: "Check Labs", founderName: "Pat", eraID: "2022"), seed: 7)
            s.date = GameCalendar.date(year, 3, 2)
            s.cash = 5e9
            return s
        }
        func tick(_ s: inout GameState, days: Int) { for _ in 0..<days { s.date = GameCalendar.addDays(s.date, 1); DataEconomy.daily(&s); Science.daily(&s) } }
        var d = ModelDesign()
        d.objective = .coding
        d.dataMix = .code
        d.paramsB = 70
        d.tokensT = 15
        d.rlhf = true
        print("== Data economy and science: mechanics check ==")

        // 1. Runs freeze their data: a run started with nothing never picks up data bought later.
        do {
            var s = fresh(2025)
            let snap = DataEconomy.snapshot(&s)
            _ = DataEconomy.acquire(&s, "code_curated", term: .buy)
            let p = DataEconomy.plan(d, state: s, sources: snap)
            let summary = DataEconomy.freeze(d, state: s, sources: s.dataSources.sorted())
            let json = try? JSONEncoder().encode(summary)
            let back = json.flatMap { try? JSONDecoder().decode(DataPlanSummary.self, from: $0) }
            check("frozen plan", snap.contains(DataEconomy.marker) && !p.datasets && back == summary && summary.dCode > 0,
                  "snapshot has the marker: \(snap.contains(DataEconomy.marker)); data bought later in that run's plan: \(p.datasets); summary round-trips: \(back == summary), dCode \(Fmt.trim(summary.dCode, 3))")
        }
        // 1b. A run forecasts (and finishes) on the plan frozen at launch, whatever is bought or dropped later.
        do {
            var s = fresh(2025)
            _ = DataEconomy.acquire(&s, "code_curated", term: .buy)
            var run = TrainingRun(design: d, started: s.date, flopsTotal: 1e24, dataSnapshot: DataEconomy.snapshot(&s))
            run.dataPlan = DataEconomy.freeze(d, state: s, sources: run.dataSnapshot)
            let atLaunch = Training.forecast(d, run, s).code
            s.dataEco.holdings = []   // sold off mid-run
            let today = ForecastEngine.forecast(d, state: s, dataSources: run.dataSnapshot).code
            let frozen = Training.forecast(d, run, s).code
            check("run keeps its launch data", abs(frozen - atLaunch) < 1e-12 && today < atLaunch,
                  "code skill at launch \(Fmt.trim(atLaunch, 3)), mid-run on the frozen plan \(Fmt.trim(frozen, 3)), priced on today's data \(Fmt.trim(today, 3))")
        }
        // 2. Same-day re-buy while a run still uses the old copy: unique IDs; the new copy can be processed again; a job on
        //    a vanished target records nothing.
        do {
            var s = fresh(2025)
            _ = DataEconomy.acquire(&s, "code_bulk", term: .buy)
            let first = s.dataEco.holdings.last!.id
            DataEconomy.finish(&s, DataJob(target: first, name: "x", stage: .dedup, started: s.date, done: s.date, cost: 0))
            s.runs.append(TrainingRun(design: d, started: s.date, flopsTotal: 1e24, dataSnapshot: DataEconomy.snapshot(&s)))
            _ = DataEconomy.drop(&s, first)
            _ = DataEconomy.acquire(&s, "code_bulk", term: .buy)
            let second = s.dataEco.holdings.last!.id
            let unique = Set(s.dataEco.holdings.map(\.id)).count == s.dataEco.holdings.count
            let canDedup = DataEconomy.startJob(&s, target: second, stage: .dedup) == nil
            DataEconomy.finish(&s, DataJob(target: "ds:gone", name: "gone", stage: .filter, started: s.date, done: s.date, cost: 0))
            check("re-buy and reprocess", first != second && unique && canDedup && s.dataEco.applied["ds:gone"] == nil,
                  "IDs \(first) / \(second), all unique: \(unique); dedup the new copy: \(canDedup); stage recorded on a missing target: \(s.dataEco.applied["ds:gone"] != nil)")
        }
        // 3. Settle-and-purge, then buy again: the new copy can be sued.
        do {
            var s = fresh(2025)
            _ = DataEconomy.acquire(&s, "code_bulk", term: .buy)
            let id = s.dataEco.holdings.last!.id
            s.dataEco.sued.insert(id)
            DataEconomy.resolve(&s, Decision(kind: "data_lawsuit", title: "", body: "", image: nil, options: [], date: s.date, amount: 1e6, ref: id), option: 1)
            tick(&s, days: 1)
            _ = DataEconomy.acquire(&s, "code_bulk", term: .buy)
            let again = s.dataEco.holdings.last!.id
            check("purge then re-buy", again != id && !s.dataEco.sued.contains(again) && !s.dataEco.holdings.contains { $0.id == id },
                  "purged copy gone: \(!s.dataEco.holdings.contains { $0.id == id }); new copy \(again) open to suits: \(!s.dataEco.sued.contains(again))")
        }
        // 4. An expired licence stays renewable (processing kept) for 90 days, then goes.
        do {
            var s = fresh(2025)
            _ = DataEconomy.acquire(&s, "web_multilingual", term: .licence)
            let id = s.dataEco.holdings.last!.id
            DataEconomy.finish(&s, DataJob(target: id, name: "x", stage: .filter, started: s.date, done: s.date, cost: 0))
            s.dataEco.holdings[s.dataEco.holdings.count - 1].expires = GameCalendar.addDays(s.date, 1)
            tick(&s, days: 30)
            let lapsed = s.dataEco.holdings.first { $0.id == id }
            let renewed = DataEconomy.renew(&s, id) == nil
            let after = s.dataEco.holdings.first { $0.id == id }
            var t = fresh(2025)
            _ = DataEconomy.acquire(&t, "web_multilingual", term: .licence)
            t.dataEco.holdings[t.dataEco.holdings.count - 1].expires = GameCalendar.addDays(t.date, 1)
            tick(&t, days: 100)
            check("licence renewal window", lapsed?.active == false && renewed && after?.active == true && after?.quality.processing == lapsed?.quality.processing && t.dataEco.holdings.isEmpty,
                  "after 30 days lapsed and stored: \(lapsed != nil); renewed with its filter kept: \(renewed && after?.quality.processing == lapsed?.quality.processing); after 100 days unrenewed: \(t.dataEco.holdings.isEmpty ? "deleted" : "still there")")
        }
        // 5. Private sales and auctions count the transfer fee.
        do {
            var s = fresh(2025)
            let def = DataMarketCatalog.byID["rare_fleet"]!
            s.cash = def.price + DataEconomy.transferCost(def, s) * 0.5
            DataEconomy.resolve(&s, Decision(kind: "data_collection", title: "", body: "", image: nil, options: [], date: s.date, amount: def.price, ref: def.id), option: 0)
            check("transfer fee counted", s.cash >= 0 && !s.dataEco.holdings.contains { $0.source == def.id },
                  "cash short of price + transfer: not bought, cash left \(Fmt.money(s.cash))")
        }
        // 6. RLHF needs fresh preference labels: a sliver is not enough, and the penalty scales with the shortfall.
        do {
            let s = fresh(2025)
            func with(_ delivered: [Double]) -> GameState {
                var t = s
                var h = DataHolding(id: "an:crowd_prefs", name: "Crowd", kind: .preferences, source: "crowd_prefs", tokensT: 0.0012,
                                    quality: DataMarketCatalog.vendorByID["crowd_prefs"]!.quality, term: .buy, acquired: t.date, refreshed: t.date)
                h.delivered = delivered
                t.dataEco.holdings = [h]
                return t
            }
            func short(_ delivered: [Double]) -> Double { DataEconomy.plan(d, state: with(delivered), sources: s.dataSources.sorted()).preferenceShortfall }
            let fresh2 = with([0.0002]), stale = with([0.0002] + [Double](repeating: 0, count: 12))
            let gap = ForecastEngine.forecast(d, state: fresh2, dataSources: s.dataSources.sorted()).chat - ForecastEngine.forecast(d, state: stale, dataSources: s.dataSources.sorted()).chat
            check("fresh preference data", short([0.00001]) > 0.9 && abs(short([0.0001]) - 0.5) < 0.01 && short([0.0002]) < 0.01 && short([0.0002] + [Double](repeating: 0, count: 12)) > 0.99 && abs(gap - 0.2) < 0.001,
                  "shortfall: 10M labels \(Fmt.trim(short([0.00001]), 2)), 100M \(Fmt.trim(short([0.0001]), 2)), 200M \(Fmt.trim(short([0.0002]), 2)), 200M over a year ago \(Fmt.trim(short([0.0002] + [Double](repeating: 0, count: 12)), 2)); chat fresh vs stale \(String(format: "%+.3f", gap))")
        }
        // 7. Synthetic data: bounded by real data, by its generator, by duplication; one share with the slider.
        do {
            var s = fresh(2025)
            let student = DataEconomy.studentC(d, s)
            func syn(_ t: Double, _ teacher: Double) -> DataHolding {
                DataEconomy.synthHolding(SynthJob(modelID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, modelName: "T", focus: .coding, tokensT: t, quality: 0.95,
                                                  verified: true, started: s.date, done: s.date, cost: 0, teacherC: teacher), date: s.date)
            }
            s.dataEco.holdings = [syn(1, student + 0.5)]
            let one = DataEconomy.plan(d, state: s, sources: s.dataSources.sorted())
            s.dataEco.holdings = [syn(1, student + 0.5), syn(1, student + 0.5), syn(1, student + 0.5)]
            let three = DataEconomy.plan(d, state: s, sources: s.dataSources.sorted())
            s.dataEco.holdings = [syn(1, student - 0.2)]
            let weak = DataEconomy.plan(d, state: s, sources: s.dataSources.sorted())
            let real = Physics.availableTokensT(s.dataSources.sorted(), y: s.year, bonuses: s.bonuses)
            var dd = d
            dd.syntheticShare = 0.5
            s.researched.insert("synthetic_data")
            s.dataEco.holdings = [syn(1, student + 0.5)]
            let both = DataEconomy.plan(dd, state: s, sources: s.dataSources.sorted())
            let big = DataEconomy.startSynth(&s, model: UUID(), focus: .coding, tokensT: 5, verified: true) != nil
            check("synthetic bounds", three.dCode < one.dCode * 1.3 && one.gains[CapDomain.coding.index] <= log10(1.5) * 2.34 + 1e-6 && weak.dCode < 0.01
                  && one.syntheticUniqueT < real && both.syntheticShare > one.syntheticShare && both.collapseFactor < 1 && big,
                  "1T dCode \(Fmt.trim(one.dCode, 3)), 3T \(Fmt.trim(three.dCode, 3)) (bounded), generator behind the design \(Fmt.trim(weak.dCode, 3)); synthetic unique \(Fmt.tokens(one.syntheticUniqueT)) < real \(Fmt.tokens(real)); slider 50% + 1T: \(Int(both.syntheticShare * 100))% → collapse ×\(Fmt.trim(both.collapseFactor, 2)); 5T job refused: \(big)")
        }
        // 8. Quality beats size against relevant bulk; research-only licences block open weights.
        do {
            var s = fresh(2025)
            _ = DataEconomy.acquire(&s, "code_curated", term: .buy)
            let curated = DataEconomy.plan(d, state: s, sources: s.dataSources.sorted()).dCode
            s.dataEco.holdings = []
            _ = DataEconomy.acquire(&s, "code_bulk", term: .buy)
            let bulk = DataEconomy.plan(d, state: s, sources: s.dataSources.sorted()).dCode
            var run = TrainingRun(design: d, started: s.date, flopsTotal: 1e24, dataSnapshot: DataEconomy.snapshot(&s))
            let model = AIModel(name: "Bulk", design: d, created: s.date, c: 3, reasoning: false, reasoningBoost: 0, codeBoost: 0, arenaBonus: 0, scores: [:], index: 0)
            run.modelID = model.id
            s.runs.append(run)
            s.models.append(model)
            let blocked = s.release(model.id, api: true, openWeights: true)
            check("quality and licence", curated > 1.5 * bulk && blocked != nil && s.models.last?.openWeights == false,
                  "dCode curated \(Fmt.trim(curated, 3)) vs bulk \(Fmt.trim(bulk, 3)); open-weights release of a model trained on bulk code: \(blocked ?? "allowed")")
        }
        // 9. Science: stopping is never better than a dead end; moonshot choices are checked; publishing helps rivals.
        do {
            var s = fresh(2027)
            s.science.labs = [SciLab(kind: .computing, site: "sf", built: s.date, ready: s.date)]
            let lab = s.science.labs[0].id
            var p = SciProject(def: "matmul", lab: lab, started: s.date, stageStarted: s.date)
            p.stage = SciStage.validation.rawValue
            var disc = SciDiscovery(def: "matmul", project: p.id, date: s.date, title: "x")
            disc.level = 0.62
            p.discovery = disc.id
            s.science.projects = [p]
            s.science.discoveries = [disc]
            s.cancelScienceProject(p.id)
            let stopped = s.science.discoveries[0].level
            // A moonshot choice whose moonshot ended is refused, and the report comes back.
            s.science.discoveries[0].choice = ""
            let ref = "\(disc.id.uuidString)|patent,moonshot|millennium_proof"
            let before = s.decisions.count
            Science.resolve(&s, Decision(kind: Science.decisionKind, title: "", body: "", image: nil, options: [], date: s.date, ref: ref), option: 1)
            let refused = s.science.discoveries[0].choice.isEmpty && s.decisions.count == before + 1
            // Publishing: rival arms in mathematics reproduce it, and rival models gain the know-how.
            if let k = s.decisions.indices.last { s.decisions.remove(at: k) }
            _ = Science.apply(&s, discovery: disc.id, .publish)
            let scheduled = s.science.reproductions.count
            tick(&s, days: 400)
            let lab2 = ScienceCatalog.rivalLabs.first { $0.fields.contains(.mathematics) }!.lab
            let know = Science.rivalKnowHow(s, lab: lab2, at: s.year).reduce(0) { $0 + $1.1 }
            check("science rules", stopped <= 0.5 && refused && scheduled > 0 && s.science.rivals.contains { $0.reproduced } && know > 0,
                  "cancelled at validation → level \(Fmt.trim(stopped, 2)); moonshot that isn't running refused and re-asked: \(refused); published: \(scheduled) reproductions scheduled, done \(s.science.rivals.filter(\.reproduced).count), \(CompetitorCatalog.def(lab2).name) +\(Fmt.trim(know * 10, 2)) pts")
        }
        // 10. Royalties scale with licensees; energy discoveries reach renters; burning plasma opens fusion; lab notebooks.
        do {
            var s = fresh(2030)
            s.science.labs = [SciLab(kind: .energy, site: "sf", built: s.date, ready: s.date)]
            var a = SciDiscovery(def: "sic_power", project: UUID(), date: s.date, title: "a")
            a.level = 1
            a.choice = "patent"
            var b = SciDiscovery(def: "sic_power", project: UUID(), date: s.date, title: "b")
            b.level = 1
            b.choice = "patent"
            s.science.discoveries = [a, b]
            s.science.patents = [SciPatent(discovery: a.id, title: "a", field: .energy, filed: s.date, expires: GameCalendar.addMonths(s.date, 240), licensees: 2),
                                 SciPatent(discovery: b.id, title: "b", field: .energy, filed: s.date, expires: GameCalendar.addMonths(s.date, 240), licensees: 6)]
            Science.payRoyalties(&s)
            let ratio = s.science.patents[1].lastMonth / max(1, s.science.patents[0].lastMonth)
            let a100 = HardwareCatalog.all.first { Economy.rent($0, s) != nil }
            let rentWith = a100.flatMap { Economy.rent($0, s) } ?? 0
            let fusionBefore = PowerKind.fusion.available(s)
            s.science.discoveries.append(SciDiscovery(def: "burning_plasma", project: UUID(), date: s.date, title: "c"))
            let proj = SciProject(def: "plasma_rl", lab: s.science.labs[0].id, started: s.date, stageStarted: s.date)
            DataEconomy.addLabNotebooks(&s, discovery: UUID(), project: proj, def: ScienceCatalog.projectByID["plasma_rl"]!)
            var none = s
            none.science.discoveries = []
            let rentWithout = a100.flatMap { Economy.rent($0, none) } ?? 0
            check("royalties, renters, unlocks", abs(ratio - 3) < 0.01 && rentWith < rentWithout && !fusionBefore && PowerKind.fusion.available(s)
                  && s.dataEco.holdings.contains { $0.id.hasPrefix("lab:") } && Power.billFactor(s) >= 0.1,
                  "6 vs 2 licensees pay ×\(Fmt.trim(ratio, 2)); cloud price ×\(Fmt.trim(rentWith / max(1e-9, rentWithout), 4)) with the energy results; fusion before/after burning plasma: \(fusionBefore)/\(PowerKind.fusion.available(s)); lab notebooks held: \(s.dataEco.holdings.contains { $0.id.hasPrefix("lab:") })")
        }
        print(failed == 0 ? "  OK: all checks passed" : "  FAILED: \(failed) check\(failed == 1 ? "" : "s")")
        return failed
    }
}
