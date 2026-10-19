import Foundation

/// Scenario G: a custom semiconductor programme, end to end (goal part 9). A frontier lab in 2026 hires a design team
/// and a compiler team, designs a training accelerator on a node a foundry offers, tapes it out, brings up first
/// silicon (a respin if the roll says so), qualifies it, makes it with deliberately short packaging until packaging
/// binds, adds packaging, designs the next generation on a newer node, scales wafers, takes chips for its own fleet and
/// trains on them, sells the rest (rival labs included, and paying), and compares what its compute costs with the best
/// merchant part. Then it checks the organisation scaling laws (goal part 10). Every check reads the simulation's own
/// numbers.
extension ScenarioHarness {
    static func scenarioG() -> Report {
        var r = Report(id: "G", title: all.first { $0.id == "G" }?.title ?? "G")
        var (s, _) = BalanceHarness.frontierLab(year: 2026, chips: 20_000, seed: 21)
        s.researched.insert("custom_silicon")
        s.researched.insert("fp8_training")
        var respinsSeen = 0
        var bugs: [String] = []
        // Deposits returned, summed as each chip month closes (the books keep only the last 24 months).
        var depositsBack = 0.0, closedMonths = Set<Date>()
        func tally(_ s: GameState) {
            guard let m = s.semi.history.first, let month = m.month, closedMonths.insert(month).inserted else { return }
            depositsBack += m.depositsBack
        }

        /// Plays `days`, answering decisions the way a careful chip programme would: a full respin for a bug, accept
        /// customers' orders, refuse rival blocks, absorb shocks, decline buyers for the company.
        func step(_ s: inout GameState, _ days: Int, until done: ((GameState) -> Bool)? = nil) {
            for _ in 0..<days where s.gameOver == nil {
                for _ in 0..<10 {
                    guard let d = s.decisions.first else { break }
                    let option: Int
                    switch d.kind {
                    case Semis.bugKind: option = 1; respinsSeen += 1; bugs.append(d.title)
                    case Semis.rivalKind: option = 1
                    case "acquisition": option = d.options.count - 1
                    default: option = 0
                    }
                    s.resolveDecision(d.id, option: option)
                    if s.decisions.first?.id == d.id { s.decisions.removeFirst() }
                }
                Sim.advanceDay(&s)
                tally(s)
                if let done, done(s) { return }
            }
        }
        func design(_ s: GameState, _ id: UUID) -> SemiDesign? { s.semi.designs.first { $0.id == id } }

        // MARK: Teams, and the rules a design must follow
        r.expect("research and money in place", s.bonuses.has(.customSilicon) && s.cash > 1e10, "cash \(Fmt.money(s.cash))")
        var young = s
        young.progression.stage = CompanyStage.scaleUp.rawValue
        r.expect("chip design teams open at Frontier Lab", young.hireChipTeam(engineers: 600)?.contains("Frontier Lab") == true)
        r.expect("hire a 600-engineer design team", s.hireChipTeam(engineers: 600) == nil)
        r.expect("hire a second team (for the dummy and the port checks)", s.hireChipTeam(engineers: 100) == nil)
        r.expect("hire a 150-engineer compiler team", s.setCompilerTeam(engineers: 150) == nil)
        let teamA = s.semi.teams[0].id, teamB = s.semi.teams[1].id
        let badStacks = s.startChipDesign(node: "n3", die: "quad", stacks: 0, focus: .training, verification: 1, teamID: teamA)
        r.expect("0 HBM stacks is refused (no division by zero later)", badStacks != nil, badStacks ?? "accepted")
        // A cheap design that never qualifies must not inflate the next generation.
        r.expect("a dummy 5 nm design starts", s.startChipDesign(node: "n5", die: "mid", stacks: 4, focus: .training, verification: 0, teamID: teamB) == nil)
        let dummy = s.semi.designs.last!.id
        let portEarly = s.startChipDesign(node: "n3", die: "quad", stacks: 8, focus: .training, verification: 1, teamID: teamA, portOf: dummy)
        r.expect("porting a design that never qualified is refused", portEarly != nil, portEarly ?? "accepted")
        let errA = s.startChipDesign(node: "n3", die: "quad", stacks: 8, focus: .training, verification: 1, teamID: teamA)
        r.expect("design A starts on 3 nm (four chiplets, 8 HBM stacks, scale-up switch)", errA == nil, errA ?? "")
        guard errA == nil, let idA = s.semi.designs.last?.id else { return r }
        r.expect("design A is generation 1 although a dummy design exists", design(s, idA)?.generation == 1, "gen \(design(s, idA)?.generation ?? 0) with \(s.semi.designs.count) designs")
        _ = s.cancelChipDesign(dummy)
        let plan = Semis.plan(node: "n3", verification: 1, team: s.semi.teams.first, derived: false, s)
        r.note("A: \(Int(plan.months)) months and \(Fmt.money(plan.total)) to production planned, respin odds \(Fmt.pct(plan.respin, decimals: 0))")

        // MARK: Design → tape-out
        step(&s, 900) { s in (design(s, idA)?.phase.rawValue ?? 0) >= SemiPhase.tapeout.rawValue }
        guard let tA = design(s, idA), tA.phase.rawValue >= SemiPhase.tapeout.rawValue else {
            r.expect("design A tapes out", false, "phase \(design(s, idA)?.phase.title ?? "?")")
            return r
        }
        r.expect("design A taped out: architecture and HBM generation locked", tA.arch > 0 && tA.tapeoutYear > 0, "arch \(Fmt.trim(tA.arch, 2)), taped out \(Fmt.trim(tA.tapeoutYear, 2))")
        let peakA = Semis.peakBF16(arch: tA.arch, node: tA.node, die: tA.die, erratum: false)
        r.note("A taped out \(s.date.gameShort): arch \(Fmt.trim(tA.arch, 2)), \(Fmt.count(peakA)) TF BF16 from \(Fmt.trim(SemiCatalog.node("n3").tfmm, 1)) TF/mm² × \(Int(SemiCatalog.die("quad").siliconArea)) mm²")
        // Supply for when A qualifies: 400 wafers a month, HBM for all of it, but packaging for only 40% — and packaging
        // starting a month after the wafers, so dies wait in the bank before anything is packaged.
        let fsw = SemiCatalog.foundryByID["fsw"]!
        let toQualify = tA.phaseDaysLeft + 75
        let waferDelay = max(0, Int((toQualify - Double(Semis.leadDays(fsw.leadDays, "wafer", s))) / 30.4))
        r.expect("book 400 wafers a month at Formosa for 24 months, timed for qualification",
                 s.bookWafers(foundry: "fsw", node: tA.node, wafersMonth: 400, months: 24, startDelayMonths: waferDelay, designID: idA) == nil)
        let y0 = Semis.previewYield(node: tA.node, die: tA.die, foundry: fsw, s, at: s.year + toQualify / 365)
        let chipsMonth = 400 * y0.diesPerWafer * y0.good / 4
        let needSlots = chipsMonth * Semis.slotsPerChip(tA), needHBM = chipsMonth * Double(tA.stacks)
        r.note("expected \(Fmt.count(chipsMonth)) chips a month: \(Fmt.count(needSlots)) packaging slots (\(Fmt.trim(Semis.slotsPerChip(tA), 2)) a chip) and \(Fmt.count(needHBM)) HBM stacks")
        r.expect("sign HBM for all of it", s.signSupply(supplier: "hanseong_mem", units: (needHBM * 1.1 / 100).rounded() * 100, months: 24) == nil)

        // MARK: Bring-up → qualification
        let packSignDay = max(0, Int(toQualify) + 30 - Semis.leadDays(SemiCatalog.supplierByID["fsw_pack"]!.leadDays, "pack", s))
        step(&s, packSignDay)
        let packErr = s.signSupply(supplier: "fsw_pack", units: (needSlots * 0.4 / 100).rounded() * 100, months: 24)
        r.expect("sign packaging for only 40% of the dies", packErr == nil, packErr ?? "")
        step(&s, 700) { s in design(s, idA)?.inProduction ?? false }
        guard let qA = design(s, idA), qA.inProduction, qA.chipIDs.count == 3, let ultraA = HardwareCatalog.get(qA.chipIDs[0]) else {
            r.expect("design A qualifies", false, "phase \(design(s, idA)?.phase.title ?? "?")")
            return r
        }
        let qualifiedA = s.date
        r.expect("A qualified with three bins registered in the hardware catalogue", true, "\(qualifiedA.gameShort), \(qA.respins) respins, \(qA.metalFixes) metal fixes, roll \(Fmt.trim(qA.lastRoll, 2)) vs odds \(Fmt.pct(qA.respinOdds, decimals: 0))")
        if respinsSeen > 0 { r.note("bring-up found: \(bugs.joined(separator: "; ")) — a full respin each time") }
        r.expect("Ultra compute is the silicon's, not the date's", abs(ultraA.bf16 - peakA * (qA.erratum ? 0.88 : 1)) < 1, "\(Fmt.count(ultraA.bf16)) TF vs \(Fmt.count(peakA)) at tape-out")
        r.expect("interconnect and scale-up come from the design", ultraA.scaleUp == Semis.spec(qA, s).scaleUp && ultraA.interconnectGBs == Semis.spec(qA, s).icGBs && ultraA.interconnectGBs != 1_800,
                 "\(ultraA.interconnect), \(ultraA.scaleUp)-chip domains, \(Fmt.count(ultraA.interconnectGBs)) GB/s")
        let mfuAtQualify = ultraA.baseMFU
        let softwareAtQualify = s.semi.software
        r.note("A Ultra: \(Fmt.count(ultraA.bf16)) TF BF16 · \(Fmt.count(ultraA.fp8)) FP8 · \(Int(ultraA.tdpW)) W · \(Fmt.memory(ultraA.memoryGB)) \(ultraA.memoryType) · MFU \(Fmt.pct(ultraA.baseMFU, decimals: 1)) at software maturity \(Fmt.pct(s.semi.software, decimals: 0)) · \(Semis.perfLabel(ultraA.bf16, s))")

        // MARK: Production constrained by packaging; the die bank keeps what packaging will take
        var sawPackBound = false, kgdBeforePacking = -1.0, bankAtPackStart = 0.0, targetAtPackStart = 0.0
        for _ in 0..<150 {
            step(&s, 1)
            guard let d = design(s, idA) else { break }
            if s.semi.month.packDays > 0 || s.semi.history.first?.bottleneck == "packaging" { sawPackBound = true }
            if kgdBeforePacking < 0, s.semi.supply.contains(where: { $0.kind == "pack" && $0.active(s.date) }) {
                kgdBeforePacking = d.kgdSold
                bankAtPackStart = d.dieBank.reduce(0, +)
                targetAtPackStart = Semis.dieBankTarget(d, s)
            }
        }
        guard let pA = design(s, idA) else { return r }
        r.expect("wafers turned into dies (\(Fmt.count(pA.wafersDone)) wafers so far)", pA.wafersDone > 0 && pA.made.reduce(0, +) > 0, "made \(Fmt.count(pA.made.reduce(0, +))) chips")
        r.expect("packaging binds with 40% of the slots", sawPackBound, "bottlenecks: \(s.semi.history.prefix(5).map { $0.bottleneck }.joined(separator: ", "))")
        r.expect("dies made before packaging started were kept for it, not dumped", kgdBeforePacking >= 0 && kgdBeforePacking < 0.05 * max(1, bankAtPackStart),
                 "bank \(Fmt.count(bankAtPackStart)) dies (target \(Fmt.count(targetAtPackStart))) when packaging started, \(Fmt.count(max(0, kgdBeforePacking))) sold as known-good die")
        let bankNow = pA.dieBank.reduce(0, +), target = Semis.dieBankTarget(pA, s)
        r.expect("with packaging short, the bank holds about two months of packaging and sells the rest", bankNow <= target * 1.6 + 30.4 * Semis.dieUseDay(pA, s) && pA.kgdSold > 0,
                 "bank \(Fmt.count(bankNow)) dies vs target \(Fmt.count(target)); \(Fmt.count(pA.kgdSold)) sold to other packagers")
        let boundMonth = s.semi.history.first?.chips ?? 0
        // Fix the constraint: more packaging (a six-month contract, whose deposit comes back when it ends).
        let extra = (needSlots * 0.9 / 100).rounded() * 100
        var extraErr = s.signSupply(supplier: "pacific_pack", units: extra, months: 6)
        if extraErr != nil { extraErr = s.signSupply(supplier: "columbia_pack", units: extra, months: 6) }
        r.expect("sign more packaging (six months)", extraErr == nil, extraErr ?? "")
        let extraDeposit = s.semi.supply.last?.deposit ?? 0

        // MARK: Deploy internally: chips from your own stock into the fleet, then a training run on them
        step(&s, 120)
        guard let dA = design(s, idA) else { return r }
        r.expect("output rises once packaging is added", (s.semi.history.first?.chips ?? 0) > boundMonth * 1.3,
                 "\(Fmt.count(boundMonth)) → \(Fmt.count(s.semi.history.first?.chips ?? 0)) chips a month")
        let take = Int(min(dA.stockMine[0], 4_096) / 64) * 64
        r.expect("chips in your own stock to take", take >= 256, "\(Fmt.count(dA.stockMine[0])) Ultra in your stock")
        let takeErr = s.orderOwnChips(ultraA.id, count: take)
        r.expect("take \(take) Ultra for the fleet", takeErr == nil, takeErr ?? "")
        step(&s, Semis.shipDays + 1)
        let pool = Economy.pools(s).first { $0.accel.id == ultraA.id }
        r.expect("they arrive in your compute pools", (pool?.owned ?? 0) >= take, "\(pool?.owned ?? 0) owned")
        let sysCost = Semis.systemCost(s), silicon = Semis.siliconCost(ultraA.id, s)
        let daily = Economy.chipDailyCost(HardwareCatalog.get(ultraA.id)!, count: 1, state: s)
        r.expect("running cost amortises the silicon too, not just the server", silicon > 0 && daily > (ultraA.price ?? 0) / (4 * 365) + silicon / (4 * 365) * 0.99,
                 "\(Fmt.money(daily))/day; silicon \(Fmt.money(silicon)) + server \(Fmt.money(sysCost))")
        var md = ModelDesign()
        md.name = "Own-Silicon-1"
        md.paramsB = 8
        md.tokensT = 0.5
        md.instruct = false
        md.accelID = ultraA.id
        md.chips = min(pool?.free ?? 0, 1_024)
        md.precision = s.bonuses.has(.fp8Training) ? .fp8 : .bf16
        let trainErr = s.startTraining(md)
        r.expect("start a training run on your own chips", trainErr == nil, trainErr ?? "")
        if trainErr == nil, let ri = s.runs.indices.last {
            let before = s.runs[ri].flopsDone
            let accel = HardwareCatalog.get(ultraA.id)!
            let expected = Double(md.chips) * accel.trainTFLOPS(md.precision) * 1e12 * Physics.runMFU(md, accel: accel, coverage: 0, state: s, bonuses: s.bonuses) * 86_400
            step(&s, 1)
            let got = s.runs[ri].flopsDone - before
            r.expect("the run trains at the chip's own MFU (\(Fmt.pct(accel.baseMFU, decimals: 1)) base, training factor \(Fmt.trim(s.customChips.first { $0.id == accel.id }?.trainFactor ?? 0, 2)))",
                     got > 0 && abs(got / max(1, expected) - 1) < 0.35, "\(Fmt.count(got)) FLOPs in a day vs \(Fmt.count(expected)) expected")
            r.expect("its MFU is the chip's mfu × training factor (×0.85, the catalogue's convention)",
                     abs(accel.baseMFU - (s.customChips.first { $0.id == accel.id }.map { $0.mfu * $0.trainFactor * 0.85 } ?? 0)) < 1e-9)
        }

        // MARK: The training / inference trade-off, on the same silicon
        var twin = dA
        twin.focus = .inference
        var twins = Semis.makeChips(twin, s)
        for i in twins.indices { twins[i].id = "semi_twin_\(i)" }
        HardwareCatalog.register(s.customChips + twins)
        if let tr = HardwareCatalog.get(ultraA.id), let inf = HardwareCatalog.get("semi_twin_0") {
            let b = s.bonuses
            var dz = md
            dz.chips = 1_024
            dz.accelID = tr.id
            let trainFlops = Physics.flopsPerDay(dz, state: s)
            dz.accelID = inf.id
            let infFlops = Physics.flopsPerDay(dz, state: s)
            r.expect("an inference layout of the same silicon trains much slower at FP8", infFlops < trainFlops * 0.75,
                     "\(Fmt.count(infFlops)) vs \(Fmt.count(trainFlops)) FLOPs/day on 1,024 chips")
            r.expect("…but serves more FP4 per watt and decodes faster", inf.inferTFLOPS(.fp4) / inf.tdpW > tr.inferTFLOPS(.fp4) / tr.tdpW && inf.decodeEff > tr.decodeEff && inf.scaleUp < tr.scaleUp,
                     "FP4/W \(Fmt.trim(inf.inferTFLOPS(.fp4) / inf.tdpW, 1)) vs \(Fmt.trim(tr.inferTFLOPS(.fp4) / tr.tdpW, 1)); decode \(Fmt.trim(inf.decodeEff, 2)) vs \(Fmt.trim(tr.decodeEff, 2)); domains \(inf.scaleUp) vs \(tr.scaleUp)")
            r.expect("and a training MFU well below the training part", Physics.mfu(accel: inf, chips: 1_024, state: s, bonuses: b) < Physics.mfu(accel: tr, chips: 1_024, state: s, bonuses: b))
        }
        HardwareCatalog.register(s.customChips)
        // Memory bandwidth is hard to make: more HBM stacks take more packaging and lose more packages.
        var wide = dA
        wide.stacks = 12
        r.expect("12 HBM stacks take more packaging and assemble worse than 8", Semis.slotsPerChip(wide) > Semis.slotsPerChip(dA) && Semis.assemblyYield(wide, s) < Semis.assemblyYield(dA, s),
                 "\(Fmt.trim(Semis.slotsPerChip(wide), 2)) vs \(Fmt.trim(Semis.slotsPerChip(dA), 2)) slots; yield \(Fmt.pct(Semis.assemblyYield(wide, s), decimals: 1)) vs \(Fmt.pct(Semis.assemblyYield(dA, s), decimals: 1))")

        // MARK: Sell externally (rival labs too): revenue once, buyers charged, stock down by what sold
        r.expect("put Ultra and Standard on sale", s.setChipPrice(idA, bin: 0, onSale: true) == nil && s.setChipPrice(idA, bin: 1, onSale: true) == nil)
        s.setSemiPolicy(allowRivals: true)
        do {
            var t = s
            let cash0 = t.competitors.reduce(0) { $0 + $1.cash }
            let stock0 = t.semi.designs.reduce(0) { $0 + $1.stockSale.reduce(0, +) }
            let sold0 = t.semi.designs.reduce(0) { $0 + $1.sold.reduce(0, +) }
            let rev0 = t.semi.designs.reduce(0) { $0 + $1.revenue }, rivalRev0 = t.semi.month.rivalRevenue, myCash0 = t.cash
            let list = Semis.offers(t)
            let v = Semis.vendorDemand(t, offers: list)
            Semis.sell(&t)
            let sold = t.semi.designs.reduce(0) { $0 + $1.sold.reduce(0, +) } - sold0
            let stockDrop = stock0 - t.semi.designs.reduce(0) { $0 + $1.stockSale.reduce(0, +) }
            let rev = t.semi.designs.reduce(0) { $0 + $1.revenue } - rev0
            let rivalsPaid = cash0 - t.competitors.reduce(0) { $0 + $1.cash }
            r.expect("one vendor share across \(list.count) SKUs (≤ 35%), split by value", v.share <= 0.35 && abs(v.split.reduce(0, +) - 1) < 1e-9, "share \(Fmt.pct(v.share, decimals: 2))")
            r.expect("a day of sales: stock falls by exactly what sold", sold > 0 && abs(stockDrop - sold) < 1e-6, "\(Fmt.count(sold)) sold, stock −\(Fmt.count(stockDrop))")
            r.expect("revenue is booked once", abs((t.cash - myCash0) - rev) < 1, "cash +\(Fmt.money(t.cash - myCash0)) vs revenue \(Fmt.money(rev))")
            r.expect("rival labs pay for what they buy", rivalsPaid > 0 && abs(rivalsPaid - (t.semi.month.rivalRevenue - rivalRev0)) < 1,
                     "rivals paid \(Fmt.money(rivalsPaid)), booked \(Fmt.money(t.semi.month.rivalRevenue - rivalRev0))")
            // An exclusive-supply promise keeps every chip from rivals.
            var x = s
            x.exclusiveSupplyUntil = GameCalendar.addDays(x.date, 365)
            r.expect("an exclusive-supply promise blocks rival buyers", Semis.buyers(x).filter { $0.rival }.allSatisfy { $0.blocked != nil } && x.setSemiPolicy(allowRivals: true) != nil)
            let xr = x.semi.month.rivalRevenue
            Semis.sell(&x)
            r.expect("…and no rival buys while it lasts", x.semi.month.rivalRevenue == xr)
            // Retiring with open orders: refused while stock can't cover them; once retired, orders still ship.
            var y = s
            let owed = y.semi.designs.first { $0.id == idA }!.stockSale[0] + 1_000
            y.semi.contracts.append(ChipContract(customer: "nimbus", designID: idA, bin: 0, units: owed, price: 20_000, signed: y.date, deadline: GameCalendar.addDays(y.date, 90)))
            r.expect("retiring with more promised than in stock is refused", y.retireChipDesign(idA) != nil)
            y.semi.contracts[y.semi.contracts.count - 1].units = max(1, y.semi.designs.first { $0.id == idA }!.stockSale[0] * 0.5)
            r.expect("retiring with the orders covered works", y.retireChipDesign(idA) == nil)
            let delivered0 = y.semi.contracts.last!.delivered
            Semis.sell(&y)
            r.expect("a retired product still delivers its orders", y.semi.contracts.last!.delivered > delivered0)
        }
        s.setSemiPolicy(allowRivals: false)

        // MARK: Improve the design: the next generation on a newer node, and the rules for a port
        let newer = SemiCatalog.nodes.filter { Semis.offered($0, fsw, s) && Semis.nodeIndex($0.id) > Semis.nodeIndex(dA.node) }.last
        r.expect("a newer node is open at Formosa", newer != nil, "\(Fmt.trim(s.year, 1))")
        guard let nodeB = newer else { return r }
        let open = Semis.designable(s).map(\.id)
        let far = SemiCatalog.nodes.first { n in Semis.nodeStep(n.id, dA.node) >= 2 && open.contains(n.id) }
        if let far {
            let farErr = s.startChipDesign(node: far.id, die: "quad", stacks: 8, focus: .training, verification: 1, teamID: teamB, portOf: idA)
            r.expect("a port can't jump two nodes (\(SemiCatalog.node(dA.node).short) → \(far.short))", farErr != nil, farErr ?? "accepted")
        }
        let otherFocus = s.startChipDesign(node: nodeB.id, die: "quad", stacks: 8, focus: .inference, verification: 1, teamID: teamB, portOf: idA)
        r.expect("a port keeps its parent's focus", otherFocus != nil, otherFocus ?? "accepted")
        let portArch = Semis.archQuality(generation: 1, team: s.semi.teams.first { $0.id == teamB }, port: dA, node: nodeB.id, s).value
        r.expect("a port's architecture is at most its parent's", portArch <= dA.arch, "\(Fmt.trim(portArch, 2)) vs \(Fmt.trim(dA.arch, 2))")
        let errB = s.startChipDesign(node: nodeB.id, die: "quad", stacks: 8, focus: .training, verification: 1, teamID: teamA)
        r.expect("design B starts on \(nodeB.short)", errB == nil, errB ?? "")
        guard errB == nil, let idB = s.semi.designs.last?.id else { return r }
        r.expect("B is generation 2: one past the newest qualified training chip", design(s, idB)?.generation == dA.generation + 1, "gen \(design(s, idB)?.generation ?? 0)")
        let softwareBeforeB = s.semi.software
        // Supply for B as it tapes out: more wafers than A had, packaging and HBM to match.
        step(&s, 1_000) { s in (design(s, idB)?.phase.rawValue ?? 0) >= SemiPhase.tapeout.rawValue }
        guard let tB = design(s, idB), tB.phase.rawValue >= SemiPhase.tapeout.rawValue else {
            r.expect("design B tapes out", false, design(s, idB)?.phase.title ?? "?")
            return r
        }
        let toQB = tB.phaseDaysLeft + 75
        let fB = SemiCatalog.foundries.first { Semis.offered(SemiCatalog.node(nodeB.id), $0, s) } ?? fsw
        let capB = Semis.waferCap(fB, SemiCatalog.node(nodeB.id), s).value - Semis.waferBooked(s, foundry: fB.id, node: nodeB.id)
        let wafersB = (min(1_000, capB) / 100).rounded(.down) * 100
        r.expect("scale: book \(Int(wafersB)) wafers a month for B (A had 400)", wafersB > 400 && s.bookWafers(foundry: fB.id, node: nodeB.id, wafersMonth: wafersB, months: 24,
                 startDelayMonths: max(0, Int((toQB - Double(Semis.leadDays(fB.leadDays, "wafer", s))) / 30.4)), designID: idB) == nil, "cap \(Fmt.count(capB))")
        let yB = Semis.previewYield(node: tB.node, die: tB.die, foundry: fB, s, at: s.year + toQB / 365)
        let chipsB = wafersB * yB.diesPerWafer * yB.good / 4
        for (kind, need) in [("pack", chipsB * Semis.slotsPerChip(tB) * 1.1), ("hbm", chipsB * Double(tB.stacks) * 1.1)] {
            var left = need
            for sup in SemiCatalog.suppliers where sup.kind == kind && sup.from <= s.year && left >= 100 {
                let room = Semis.supplyCap(sup, s) - Semis.supplyBooked(s, supplier: sup.id)
                let n = (min(left, room) / 100).rounded(.down) * 100
                if n >= 100, s.signSupply(supplier: sup.id, units: n, months: 24) == nil { left -= n }
            }
        }
        var softwareEve = 0.0
        step(&s, 700) { s in
            let done = design(s, idB)?.inProduction ?? false
            if !done { softwareEve = s.semi.software }
            return done
        }
        guard let qB = design(s, idB), qB.inProduction, let ultraB = HardwareCatalog.get(qB.chipIDs[0]) else {
            r.expect("design B qualifies", false, design(s, idB)?.phase.title ?? "?")
            return r
        }
        r.expect("B is a better chip: more compute on the newer node", ultraB.bf16 > ultraA.bf16 && qB.arch > dA.arch,
                 "\(Fmt.count(ultraB.bf16)) vs \(Fmt.count(ultraA.bf16)) TF; arch \(Fmt.trim(qB.arch, 2)) vs \(Fmt.trim(dA.arch, 2))")
        r.expect("a new architecture costs the compiler some maturity", s.semi.software < softwareEve, "\(Fmt.pct(softwareEve, decimals: 1)) → \(Fmt.pct(s.semi.software, decimals: 1)) (it was \(Fmt.pct(softwareBeforeB, decimals: 0)) when B started)")
        r.note("B Ultra (\(SemiCatalog.node(qB.node).short), gen \(qB.generation)): \(Fmt.count(ultraB.bf16)) TF · \(Int(ultraB.tdpW)) W · \(Semis.perfLabel(ultraB.bf16, s)) · qualified \(s.date.gameShort)")
        let aMonths = s.semi.history.filter { $0.chips > 0 }.map(\.chips)
        let bestA = aMonths.max() ?? 0
        step(&s, 150)
        r.expect("scaled output: more chips a month than A ever made", (s.semi.history.first?.chips ?? 0) > bestA, "\(Fmt.count(s.semi.history.first?.chips ?? 0)) vs A's best \(Fmt.count(bestA))")
        r.expect("the six-month packaging deposit came back when it ended", depositsBack >= extraDeposit * 0.999 && extraDeposit > 0,
                 "deposit \(Fmt.money(extraDeposit)), returned \(Fmt.money(depositsBack))")
        // The generation rule again: the old part is superseded and its dies are worth less.
        r.expect("A is superseded by B", Semis.superseded(design(s, idA)!, s))

        // MARK: Compute economics and the software stack
        let ec = Semis.computeEconomics(s, s.bonuses)
        let mine = ec.mine.min { $0.trainCost < $1.trainCost }
        if let mine, let m = ec.train {
            r.expect("own silicon trains cheaper per delivered PFLOP-day than any merchant part", mine.trainCost < m.trainCost,
                     "\(Fmt.money(mine.trainCost)) (\(mine.name)) vs \(Fmt.money(m.trainCost)) (\(m.name), \(m.how))")
        } else {
            r.expect("compute economics available", false)
        }
        if let ms = ec.mine.min(by: { $0.serveCost < $1.serveCost }), let m = ec.serve {
            r.note("serving $/PFLOP-day: yours \(Fmt.money(ms.serveCost)) (\(ms.name)) vs \(Fmt.money(m.serveCost)) (\(m.name), \(m.how))")
        }
        let ultraNow = HardwareCatalog.get(ultraA.id)!
        r.expect("compiler maturity rose with the compiler team and chips in use", s.semi.software > softwareAtQualify || s.semi.software > 0.5,
                 "\(Fmt.pct(softwareAtQualify, decimals: 0)) at A's qualification → \(Fmt.pct(s.semi.software, decimals: 0)) now; rate \(Fmt.trim(Semis.softwareRate(s), 2))/yr")
        r.expect("…and the chips were re-registered with it (A's MFU \(Fmt.pct(mfuAtQualify, decimals: 1)) → \(Fmt.pct(ultraNow.baseMFU, decimals: 1)))", ultraNow.baseMFU > mfuAtQualify)
        r.expect("A's spec never moved with the calendar", abs(Semis.spec(design(s, idA)!, s).bf16 - ultraA.bf16) < 1)
        r.note("lifetime: \(Fmt.count(s.semi.designs.reduce(0) { $0 + $1.made.reduce(0, +) })) chips made, \(Fmt.count(s.semi.shipped)) sold for \(Fmt.money(s.semi.designs.reduce(0) { $0 + $1.revenue })), \(Fmt.count(s.semi.designs.reduce(0) { $0 + $1.taken.reduce(0, +) })) kept")

        // MARK: Saves: the chip business round-trips, and a save missing the newer keys decodes to their real defaults
        saveRepair(&r, s)

        // MARK: Organisations scale with sharply diminishing returns, and splitting never beats pooling
        orgScaling(&r, s)
        sanity(s, &r)
        return r
    }

    /// Encodes the game, strips keys older saves lack (or that a damaged save lost), and decodes it again.
    static func saveRepair(_ r: inout Report, _ s: GameState) {
        guard let data = try? SaveCoding.encoder().encode(s), let back = try? SaveCoding.decoder().decode(GameState.self, from: data) else {
            r.expect("the chip business saves and loads", false)
            return
        }
        r.expect("the chip business saves and loads unchanged", back.semi == s.semi && back.customChips == s.customChips)
        guard var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], var semi = root["semi"] as? [String: Any],
              var designs = semi["designs"] as? [[String: Any]], !designs.isEmpty else { return }
        semi["keepShare"] = nil
        semi["allowSovereigns"] = nil
        for k in ["dieBank", "stockMine", "stockSale", "prices", "onSale", "made", "sold", "taken"] { designs[0][k] = nil }
        designs[0]["stockSale"] = [Double]()   // present but short: padded on load
        semi["designs"] = designs
        root["semi"] = semi
        guard let stripped = try? JSONSerialization.data(withJSONObject: root),
              var old = try? SaveCoding.decoder().decode(GameState.self, from: stripped) else {
            r.expect("a save missing the newer chip keys still decodes", false)
            return
        }
        SaveMigration.migrate(&old)
        let d = old.semi.designs[0]
        r.expect("missing keys decode to their real defaults (keep 50%, sovereigns allowed, three bins)",
                 old.semi.keepShare == 0.5 && old.semi.allowSovereigns && d.dieBank.count == 3 && d.onSale.count == 3 && d.stockSale.count == 3,
                 "keep \(old.semi.keepShare), sovereigns \(old.semi.allowSovereigns), bins \(d.dieBank.count)/\(d.onSale.count)/\(d.stockSale.count)")
        var t = old
        Semis.daily(&t)
        r.expect("…and the business runs a day on it", t.cash.isFinite)
    }

    /// Pure checks of the organisation pool (supervised frontier agents, 10% verification, fully funded).
    static func orgScaling(_ r: inout Report, _ s: GameState) {
        let b = s.bonuses
        func raw(_ e: Double, q: Double = 2, eps: Double = 0.01, teams: Int = 1) -> (org: AgentOrg, raw: AgentOrgs.Eval) {
            var o = AgentOrg(name: "probe", kind: .research, objective: "", founded: s.date)
            o.budgetMonthly = 1e18
            var v = AgentOrgs.Eval()
            v.effective = e
            v.specialists = e
            v.perAgent = q
            v.errorRate = eps
            v.verification = 0.1
            v.working = e * 0.9
            v.supervision = 1
            v.caught = AgentOrgs.caught(0.1, supervision: 1)
            v.specialistTeams = teams
            return (o, v)
        }
        func w(_ list: [(org: AgentOrg, raw: AgentOrgs.Eval)], coordination: Double? = nil) -> Double {
            AgentOrgs.pool(.research, orgs: list, solo: AgentOrgs.SoloBlock(), s, b, coordination: coordination).evals.reduce(0) { $0 + $1.workforce }
        }
        let w3 = w([raw(1e3)]), w6 = w([raw(1e6)]), w9 = w([raw(1e9)])
        r.note("organisation output (q = 2, supervised, coordination \(Fmt.trim(Swarms.coordination(b, s), 2))): 10³ agents → \(Fmt.count(w3)), 10⁶ → \(Fmt.count(w6)) (×\(Fmt.trim(w6 / max(1, w3), 0))), 10⁹ → \(Fmt.count(w9)) (×\(Fmt.trim(w9 / max(1, w6), 0)) more)")
        r.expect("1,000× the agents gives at most 500× the output from 10³ to 10⁶", w6 / w3 >= 100 && w6 / w3 <= 500, "×\(Fmt.trim(w6 / w3, 0))")
        let l3 = w([raw(1e3)], coordination: 0.95), l6 = w([raw(1e6)], coordination: 0.95), l9 = w([raw(1e9)], coordination: 0.95)
        r.expect("with coordination research complete (0.95) it's 250–500×, as documented", l6 / l3 >= 250 && l6 / l3 <= 500, "×\(Fmt.trim(l6 / l3, 0)), then ×\(Fmt.trim(l9 / l6, 0)) to 10⁹")
        r.expect("…and much less from 10⁶ to 10⁹ (diminishing returns)", w9 / w6 < w6 / w3 * 0.6 && l9 / l6 < l6 / l3 * 0.6, "×\(Fmt.trim(w9 / w6, 0)) (×\(Fmt.trim(l9 / l6, 0)) late)")
        r.expect("a billion agents do nowhere near a billion agents' work", l9 / 2 < 1e8, "\(Fmt.count(l9 / 2)) agent-equivalents at best")
        let ten = w(Array(repeating: raw(1e8), count: 10))
        r.expect("ten organisations of 10⁸ don't beat one of 10⁹", ten <= w9, "\(Fmt.count(ten)) vs \(Fmt.count(w9))")
        let eight = w([raw(1e9, teams: 8)])
        r.expect("…nor eight teams in one", eight <= w9)
        // Verification pays in a deep organisation even with frontier agents (coordination error grows with depth).
        let deep = AgentOrgs.pool(.research, orgs: [raw(1e9)], solo: AgentOrgs.SoloBlock(), s, b).evals[0]
        r.expect("verification pays at 10⁹ agents with frontier models", AgentOrgs.bestVerification(deep) >= 0.05, "best \(Fmt.pct(AgentOrgs.bestVerification(deep), decimals: 0)) at \(Fmt.pct(deep.errorEff, decimals: 0)) errors")
        // Stronger agents unlock new kinds of work.
        let acts = SwarmMission.silicon.activities
        let open1 = AgentOrgs.activityShares(acts, best: 1, focus: 0).filter { $0 > 0 }.count
        let open3 = AgentOrgs.activityShares(acts, best: 3, focus: 0).filter { $0 > 0 }.count
        let open9 = AgentOrgs.activityShares(acts, best: 9, focus: 0).filter { $0 > 0 }.count
        r.expect("research-lead and superhuman agents unlock new silicon work", open1 == 1 && open3 == 2 && open9 == 3, "\(open1) / \(open3) / \(open9) activities")
    }
}
