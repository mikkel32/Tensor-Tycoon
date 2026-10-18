import Foundation

/// 3.5: the semiconductor industry. Hire design teams, design accelerators for a process node and tape them out (with a
/// respin risk you can see), book wafers at foundries or build your own fab, buy advanced packaging and HBM, watch
/// defect density fall as you learn, bin dies into three SKUs, and sell them — to clouds, sovereigns and, if you dare, rival
/// labs — or keep them for your own fleet.
///
/// Every roll is hashed (`roll`), never drawn from the game's RNG, and nothing runs until you hire a team or book
/// capacity: a lab that ignores semiconductors plays exactly as before.
enum Semis {
    static let chipPrefix = "semi_"
    static let shipDays = 14
    static let orderKind = "semi_order"
    static let rivalKind = "semi_rival"
    static let shockKind = "semi_shock"
    static let bugKind = "semi_bug"
    static let kinds: Set<String> = [orderKind, rivalKind, shockKind, bugKind]

    // MARK: Basics

    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("semi|\(s.semi.salt)|\(key)") }

    static func isSemiChip(_ id: String) -> Bool { id.hasPrefix(chipPrefix) }

    static func engage(_ s: inout GameState) {
        if s.semi.salt.isEmpty { s.semi.salt = String(s.rng.state ^ 0x5E41_C0DE, radix: 36) }
        if !s.semi.engaged {
            s.semi.engaged = true
            s.semi.month = SemiMonth(month: GameCalendar.date(GameCalendar.components(s.date).year, GameCalendar.components(s.date).month, 1))
        }
    }

    static func log(_ s: inout GameState, _ text: String, tone: Int = 0) {
        s.semi.log.insert(SemiEvent(date: s.date, text: text, tone: tone), at: 0)
        if s.semi.log.count > 80 { s.semi.log.removeLast(s.semi.log.count - 80) }
    }

    static func note(_ s: inout GameState, _ i: Int, _ text: String, tone: Int = 0) {
        s.semi.designs[i].timeline.append(SemiEvent(date: s.date, text: text, tone: tone))
        if s.semi.designs[i].timeline.count > 40 { s.semi.designs[i].timeline.removeFirst() }
    }

    // MARK: Curves by year

    /// Fully loaded cost of one chip-design engineer a year.
    static func engineerCost(_ y: Double) -> Double {
        interpolate([(2016, 220_000), (2020, 260_000), (2023, 320_000), (2026, 380_000), (2030, 450_000), (2040, 600_000)], at: y)
    }

    /// One HBM stack: capacity (GB) and bandwidth (TB/s) of the generation shipping that year.
    static func stackGB(_ y: Double) -> Double {
        interpolate([(2016, 4), (2018, 8), (2020, 16), (2023, 24), (2024.5, 36), (2026, 48), (2028, 64), (2030, 96), (2035, 128)], at: y)
    }

    static func stackTBs(_ y: Double) -> Double {
        interpolate([(2016, 0.256), (2018, 0.307), (2020, 0.46), (2023, 0.82), (2024.5, 1.2), (2026, 2.0), (2028, 2.8), (2030, 4.0), (2035, 6)], at: y)
    }

    static func hbmGeneration(_ y: Double) -> String {
        switch y {
        case ..<2020: "HBM2"
        case ..<2023: "HBM2e"
        case ..<2024.5: "HBM3"
        case ..<2026: "HBM3e"
        case ..<2028.5: "HBM4"
        default: "HBM4e"
        }
    }

    /// HBM dollars per GB before shortages.
    static func hbmPerGB(_ y: Double) -> Double {
        interpolate([(2016, 20), (2020, 14), (2023, 12), (2025, 13), (2027, 10), (2030, 7), (2035, 4)], at: y)
    }

    /// One advanced-packaging slot (a chip on a silicon interposer) before shortages.
    static func packPrice(_ y: Double) -> Double {
        interpolate([(2016, 350), (2020, 500), (2023, 900), (2026, 1_100), (2030, 1_000), (2035, 800)], at: y)
    }

    /// How tight the world's supply of each input is (0 loose … 1 sold out), before shocks. The early-2020s chip
    /// shortage hit wafers; the AI boom made advanced packaging the bottleneck in 2023–24, then HBM in 2024–26.
    static func tightness(_ kind: String, _ y: Double) -> Double {
        switch kind {
        case "wafer": interpolate([(2016, 0.25), (2020.5, 0.3), (2021.3, 0.75), (2022.5, 0.7), (2023.3, 0.35), (2024.5, 0.55), (2026.5, 0.5), (2029, 0.35)], at: y)
        case "pack": interpolate([(2016, 0.15), (2022.5, 0.25), (2023.3, 0.95), (2024.5, 0.85), (2025.5, 0.65), (2026.5, 0.45), (2028, 0.3)], at: y)
        default: interpolate([(2016, 0.15), (2022.5, 0.25), (2023.5, 0.6), (2024.3, 0.9), (2025.8, 0.85), (2026.8, 0.6), (2028, 0.4)], at: y)
        }
    }

    static func tightWords(_ t: Double) -> String {
        switch t {
        case ..<0.3: "loose"
        case ..<0.55: "firm"
        case ..<0.8: "tight"
        default: "sold out"
        }
    }

    // MARK: Nodes

    /// When `node` opens at `f` (its lag behind the leading foundry).
    static func opens(_ n: ProcessNode, _ f: Foundry) -> Double { n.launch + f.lag }

    static func offered(_ n: ProcessNode, _ f: Foundry, _ y: Double) -> Bool { y >= opens(n, f) && y <= n.launch + 16 }

    /// Nodes you can start a design on: open somewhere within two years, and not hopelessly old.
    static func designable(_ s: GameState) -> [ProcessNode] {
        let y = s.year
        let newest = SemiCatalog.nodes.filter { $0.launch <= y }.map(\.launch).max() ?? 2015
        return SemiCatalog.nodes.filter { $0.launch <= y + 2 && $0.launch >= newest - 6 }
    }

    /// Defect density across the industry for a node in year `y`: five times the mature level at launch, falling as the
    /// world's fabs learn it.
    static func industryD0(_ n: ProcessNode, _ y: Double) -> Double {
        n.d0 * (1 + 4 * exp(-max(0, y - n.launch) / 0.9))
    }

    /// Wafer price at a foundry today: the node's launch price, cheaper as it matures, dearer when wafers are scarce.
    static func waferPrice(_ n: ProcessNode, _ f: Foundry, _ y: Double) -> Double {
        let mature = max(0.6, 1 - 0.06 * max(0, y - n.launch - 1))
        return n.waferPrice * f.priceFactor * mature * (1 + 0.4 * tightness("wafer", y))
    }

    /// The node the best merchant GPUs are made on this year (they trail the leading edge by about two years).
    static func refDensity(_ y: Double) -> Double {
        SemiCatalog.nodes.filter { $0.launch <= y - 2 }.last?.density ?? 0.35
    }

    static func refArea(_ y: Double) -> Double { y >= 2024.8 ? 1_600 : 814 }

    // MARK: Yields

    struct Yield {
        var d0: Double
        /// Average defects per die.
        var lambda: Double
        var diesPerWafer: Double
        /// Ultra, Standard, Lite and scrap shares of dies.
        var bins: [Double]
        var scrap: Double
        /// Share of perfect dies that reach the top clock.
        var speed: Double
        var why: String

        var good: Double { bins.reduce(0, +) }
    }

    /// Gross dies a 300 mm wafer holds for a die of `area` mm² (edge loss included).
    static func diesPerWafer(_ area: Double) -> Double {
        max(1, Double.pi * 150 * 150 / area - Double.pi * 300 / (2 * area).squareRoot())
    }

    /// Poisson yield: a die with λ defects on average is perfect with probability e^−λ. Perfect dies that clock high are
    /// Ultra; perfect-but-slow dies and dies with one defect in a spare compute block are Standard; dies with two defects
    /// can still be Lite with blocks fused off; the rest are scrap.
    static func yield(d0: Double, area: Double, wafersDone: Double, why: String) -> Yield {
        let lambda = d0 * area / 100
        let p0 = exp(-lambda), p1 = lambda * exp(-lambda), p2 = lambda * lambda / 2 * exp(-lambda)
        let speed = 0.45 + 0.3 * (1 - exp(-wafersDone / 20_000))
        let bins = [p0 * speed, p0 * (1 - speed) + p1 * 0.85, p1 * 0.15 + p2 * 0.5]
        return Yield(d0: d0, lambda: lambda, diesPerWafer: diesPerWafer(area), bins: bins, scrap: max(0, 1 - bins.reduce(0, +)), speed: speed, why: why)
    }

    /// The defect learning curve for one product: the node's industry density × the foundry's × your product's own learning.
    static func productYield(_ d: SemiDesign, foundry f: Foundry, _ s: GameState) -> Yield {
        let n = SemiCatalog.node(d.node)
        let ind = industryD0(n, s.year)
        let learn = 1 + exp(-d.wafersDone / 15_000)
        let d0 = ind * f.d0Factor * learn
        return yield(d0: d0, area: SemiCatalog.die(d.die).area, wafersDone: d.wafersDone,
                     why: "D0 \(Fmt.trim(d0, 3))/cm² = \(n.short) industry \(Fmt.trim(ind, 3)) × \(f.name) \(Fmt.trim(f.d0Factor, 2)) × your learning \(Fmt.trim(learn, 2)) (\(Fmt.count(d.wafersDone)) wafers so far)")
    }

    /// The same at your own fab: a new fab starts with several times the defects and learns with every wafer.
    static func fabYield(_ d: SemiDesign, fab: SemiFab, _ s: GameState) -> Yield {
        let n = SemiCatalog.node(d.node)
        let ind = industryD0(n, s.year)
        let fabF = fabD0Factor(fab)
        let learn = 1 + exp(-d.wafersDone / 15_000)
        let d0 = ind * fabF * learn
        return yield(d0: d0, area: SemiCatalog.die(d.die).area, wafersDone: d.wafersDone,
                     why: "D0 \(Fmt.trim(d0, 3))/cm² = \(n.short) industry \(Fmt.trim(ind, 3)) × \(fab.name) ramp \(Fmt.trim(fabF, 2)) × your learning \(Fmt.trim(learn, 2))")
    }

    static func fabD0Factor(_ f: SemiFab) -> Double { 1 + 2.5 * exp(-f.wafersDone / 40_000) }

    /// Expected yield of a design at a foundry if it went into production today (for planning).
    static func previewYield(node: String, die: String, foundry f: Foundry, _ s: GameState, at y: Double? = nil) -> Yield {
        let n = SemiCatalog.node(node)
        let yy = max(y ?? s.year, n.launch + f.lag)
        let d0 = industryD0(n, yy) * f.d0Factor * 2
        return yield(d0: d0, area: SemiCatalog.die(die).area, wafersDone: 0, why: "")
    }

    // MARK: Design

    static func team(_ s: GameState, _ id: UUID?) -> SemiTeam? { id.flatMap { tid in s.semi.teams.first { $0.id == tid } } }

    /// The design a team is busy with (architecture to physical design), if any.
    static func teamBusy(_ s: GameState, _ id: UUID, except: UUID? = nil) -> SemiDesign? {
        s.semi.designs.first { $0.teamID == id && $0.phase.rawValue <= SemiPhase.physical.rawValue && $0.id != except }
    }

    static func verificationName(_ v: Int) -> String { ["Lean", "Standard", "Thorough"][clamp(v, 0, 2)] }
    static let verificationTime = [0.8, 1.0, 1.25]
    static let verificationRisk = [1.5, 1.0, 0.55]

    /// Everything that speeds a chip team up (lower is faster), with the reasons.
    static func speedFactor(_ s: GameState) -> (value: Double, why: [String]) {
        var why: [String] = []
        let df = Silicon.designerFactor(s)
        let bonus = s.traits.chipDesign + s.bonuses.chipDesign
        var v = 1 - 0.3 * s.swarmSilicon - bonus - 0.15 * df
        if s.swarmSilicon > 0 { why.append("agent swarms −\(Fmt.pct(0.3 * s.swarmSilicon, decimals: 0))") }
        if bonus > 0 { why.append("research & traits −\(Fmt.pct(bonus, decimals: 0))") }
        if df > 0 { why.append("chip designers on staff −\(Fmt.pct(0.15 * df, decimals: 0))") }
        v = max(0.5, v)
        if s.signatureAt(.forge, 5) { v *= 0.7; why.append("Forge signature −30%") }
        return (v, why)
    }

    struct Plan {
        var designDays: Double
        var phaseDays: [Double]
        var teamCost: Double
        var ipCost: Double
        var maskCost: Double
        var respin: Double
        var respinWhy: String
        var timeWhy: String
        var total: Double { teamCost + ipCost + maskCost }
        var months: Double { phaseDays.reduce(0, +) / 30.4 }
    }

    /// Time, money and respin odds for a design before you commit.
    static func plan(node: String, verification v: Int, team: SemiTeam?, derived: Bool, _ s: GameState) -> Plan {
        let n = SemiCatalog.node(node)
        let eng = Double(team?.engineers ?? 300)
        let teamF = pow(300 / max(50, eng), 0.5)
        let sp = speedFactor(s)
        let days = n.designMonths * 30.4 * teamF * verificationTime[clamp(v, 0, 2)] * (derived ? 0.6 : 1) * sp.value
        let phases = [days * 0.2, days * 0.5, days * 0.3, n.fabDays, 75]
        let teamCost = eng * engineerCost(s.year) / 365 * days
        let ipCost = n.ipMonth * days / 30.4
        let exp = Double(min(team?.experience ?? 0, 4))
        let df = Silicon.designerFactor(s)
        var r = n.respin * verificationRisk[clamp(v, 0, 2)] * (1 - 0.1 * exp) * (1 - 0.25 * df) * (1 - 0.4 * s.swarmSilicon) * (derived ? 0.7 : 1)
        r = clamp(r, 0.03, 0.85)
        var parts = ["\(n.short) first-pass \(Fmt.pct(n.respin, decimals: 0))", "\(verificationName(v).lowercased()) verification ×\(Fmt.trim(verificationRisk[clamp(v, 0, 2)], 2))"]
        if exp > 0 { parts.append("\(Int(exp)) tape-out\(exp == 1 ? "" : "s") of experience ×\(Fmt.trim(1 - 0.1 * exp, 2))") }
        if df > 0 { parts.append("chip designers ×\(Fmt.trim(1 - 0.25 * df, 2))") }
        if s.swarmSilicon > 0 { parts.append("agent swarms ×\(Fmt.trim(1 - 0.4 * s.swarmSilicon, 2))") }
        if derived { parts.append("port of a proven design ×0.7") }
        var t = ["\(n.short) baseline \(Int(n.designMonths)) months for 300 engineers", "\(Int(eng)) engineers ×\(Fmt.trim(teamF, 2))",
                 "\(verificationName(v).lowercased()) verification ×\(Fmt.trim(verificationTime[clamp(v, 0, 2)], 2))"]
        if derived { t.append("port ×0.6") }
        if sp.value != 1 { t.append("speed ×\(Fmt.trim(sp.value, 2))" + (sp.why.isEmpty ? "" : " (\(sp.why.joined(separator: ", ")))")) }
        t.append("then tape-out \(Int(n.fabDays)) days and bring-up 75 days")
        return Plan(designDays: days, phaseDays: phases, teamCost: teamCost, ipCost: ipCost, maskCost: n.maskCost, respin: r,
                    respinWhy: parts.joined(separator: " · "), timeWhy: t.joined(separator: " · "))
    }

    /// Architecture quality (1.0 = as good as the best GPU maker's at the same node and area).
    static func archQuality(generation g: Int, team: SemiTeam?, derived: Bool, _ s: GameState) -> (value: Double, why: String) {
        let df = Silicon.designerFactor(s)
        let bonus = s.traits.chipDesign + s.bonuses.chipDesign
        let exp = Double(min(team?.experience ?? 0, 5))
        let gen = Double(min(g - 1, 5))
        var v = 0.55 + 0.07 * gen + 0.03 * exp + 0.08 * df + 0.1 * s.swarmSilicon + 0.25 * bonus + (derived ? 0.02 : 0)
        v = clamp(v, 0.4, 1.2)
        var parts = ["first design 0.55"]
        if gen > 0 { parts.append("generation \(g) +\(Fmt.trim(0.07 * gen, 2))") }
        if exp > 0 { parts.append("team experience +\(Fmt.trim(0.03 * exp, 2))") }
        if df > 0 { parts.append("chip designers +\(Fmt.trim(0.08 * df, 2))") }
        if s.swarmSilicon > 0 { parts.append("swarms +\(Fmt.trim(0.1 * s.swarmSilicon, 2))") }
        if bonus > 0 { parts.append("research & traits +\(Fmt.trim(0.25 * bonus, 2))") }
        return (v, parts.joined(separator: " · "))
    }

    /// Performance vs today's best merchant GPU, with how it was worked out.
    static func perfRatio(arch: Double, node: String, die: String, erratum: Bool, _ s: GameState) -> (value: Double, why: String) {
        let n = SemiCatalog.node(node)
        let d = SemiCatalog.die(die)
        let y = s.year
        let dens = pow(n.density / refDensity(y), 0.7)
        let area = pow(d.siliconArea / refArea(y), 0.9)
        let v = arch * dens * area * (erratum ? 0.88 : 1)
        return (v, "architecture \(Fmt.trim(arch, 2)) × node density \(Fmt.trim(dens, 2)) (\(n.short) vs the GPU makers' node) × silicon area \(Fmt.trim(area, 2)) (\(Int(d.siliconArea)) vs \(Int(refArea(y))) mm²)"
                + (erratum ? " × erratum 0.88" : ""))
    }

    /// Board power for the Ultra part: power per mm² rises with density, falls with each node's efficiency.
    static func tdp(node: String, die: String) -> Double {
        let n = SemiCatalog.node(node)
        let d = SemiCatalog.die(die)
        return (0.75 * Double(d.dies) * d.area * pow(n.power * n.density / 1.35, 0.7) / 10).rounded() * 10
    }

    /// Server, board and network share around one chip: what taking a chip for your own fleet costs once the silicon is paid.
    static func systemCost(_ s: GameState) -> Double {
        (ChipBusiness.listPrice(Silicon.reference(s), s) * 0.12 / 100).rounded() * 100 + 2_000
    }

    static func stacksFor(bin b: Int, _ d: SemiDesign) -> Int { b == 2 ? max(2, Int((Double(d.stacks) * 0.75).rounded())) : d.stacks }

    static let binPerf = [1.0, 0.88, 0.7]
    static let binPower = [1.0, 0.95, 0.8]

    /// The three chips (Ultra, Standard, Lite) a qualified design becomes.
    static func makeChips(_ d: SemiDesign, _ s: GameState) -> [CustomChip] {
        let ref = Silicon.reference(s)
        let perf = perfRatio(arch: d.arch, node: d.node, die: d.die, erratum: d.erratum, s).value
        let training = d.focus == .training
        let y = s.year
        let company = s.companyName.split(separator: " ").first.map(String.init) ?? "Custom"
        return (0..<3).map { b in
            let p = perf * binPerf[b]
            let stacks = Double(stacksFor(bin: b, d))
            let bw = stacks * stackTBs(y)
            return CustomChip(
                id: "\(chipPrefix)\(d.id.uuidString.prefix(8).lowercased())_\(b)",
                name: "\(company) \(d.name) \(SemiCatalog.binNames[b])",
                focus: d.focus, available: s.date, process: SemiCatalog.node(d.node).name,
                memoryGB: stacks * stackGB(y), memoryType: hbmGeneration(y), bandwidthTBs: bw,
                bf16: ref.bf16 * p * (training ? 1 : 0.75),
                fp8: (ref.fp8 > 0 ? ref.fp8 : ref.bf16 * 2) * p * (training ? 1 : 1.1),
                fp4: ref.fp4 > 0 ? ref.fp4 * p * (training ? 0.9 : 1.2) : 0,
                tdpW: tdp(node: d.node, die: d.die) * binPower[b] * (training ? 1 : 0.85),
                unitCost: systemCost(s),
                decodeEff: clamp((training ? 0.66 : 0.78) + 0.04 * log2(max(0.25, bw / max(0.1, ref.bandwidthTBs))), 0.5, 0.9),
                scaleUp: training ? 128 : 64, generation: d.generation)
        }
    }

    // MARK: Supply caps and prices

    /// Wafers a month a foundry will commit to you at a node: grows as the node matures and with your history there,
    /// shrinks when wafers are scarce.
    static func waferCap(_ f: Foundry, _ n: ProcessNode, _ s: GameState) -> (value: Double, why: String) {
        let y = s.year
        let age = y - opens(n, f)
        let ramp = clamp(0.3 + 0.35 * age, 0.3, 3)
        let tight = tightness("wafer", y)
        let rel = 1 + 0.5 * log10(1 + (s.semi.foundryWafers[f.id] ?? 0) / 10_000)
        let v = 2_000 * f.capFactor * ramp * (1.3 - tight) * rel
        return ((v / 100).rounded() * 100,
                "2,000 × \(f.name) share \(Fmt.trim(f.capFactor, 2)) × node ramp \(Fmt.trim(ramp, 2)) × market \(Fmt.trim(1.3 - tight, 2)) (\(tightWords(tight))) × relationship \(Fmt.trim(rel, 2))")
    }

    static func waferBooked(_ s: GameState, foundry: String, node: String) -> Double {
        s.semi.bookings.filter { $0.foundry == foundry && $0.node == node && $0.end > s.date }.reduce(0) { $0 + $1.wafersMonth }
    }

    static func supplyCap(_ sup: Supplier, _ s: GameState) -> Double {
        let t = tightness(sup.kind, s.year)
        let base = sup.kind == "pack" ? 8_000.0 : 60_000.0
        let growth = interpolate([(2016, 0.5), (2023, 1.0), (2026, 2.0), (2030, 4.0)], at: s.year)
        return (base * sup.capFactor * growth * (1.2 - t) / 100).rounded() * 100
    }

    static func supplyBooked(_ s: GameState, supplier: String) -> Double {
        s.semi.supply.filter { $0.supplier == supplier && !$0.own && $0.end > s.date }.reduce(0) { $0 + $1.units }
    }

    static func supplyPrice(_ sup: Supplier, _ s: GameState) -> Double {
        let t = tightness(sup.kind, s.year)
        let base = sup.kind == "pack" ? packPrice(s.year) : stackGB(s.year) * hbmPerGB(s.year)
        return base * sup.priceFactor * (1 + 0.6 * t)
    }

    static func leadDays(_ base: Double, _ kind: String, _ s: GameState) -> Int {
        Int(base * (1 + 0.5 * tightness(kind, s.year)))
    }

    // MARK: Shocks

    static func activeShocks(_ s: GameState) -> [SupplyShock] { s.semi.shocks.filter { $0.active(s.date) } }

    static func mitigatedFactor(_ f: Double, _ sh: SupplyShock) -> Double { sh.mitigated ? (1 + f) / 2 : f }

    static func waferFactor(_ s: GameState, foundry: String) -> Double {
        activeShocks(s).reduce(1.0) { acc, sh in
            var f = acc
            if sh.foundry.isEmpty || sh.foundry == foundry { f *= mitigatedFactor(sh.wafers, sh) }
            if sh.export && foundry == "pearl" && HQ.region(s) != .china { f *= 0 }
            return f
        }
    }

    static func ownFabFactor(_ s: GameState, _ fab: SemiFab) -> Double {
        let site = SemiCatalog.siteByID[fab.site]
        return activeShocks(s).reduce(1.0) { acc, sh in
            var f = acc
            if sh.drought < 1, (site?.water ?? 0) >= 0.5 { f *= mitigatedFactor(sh.drought, sh) }
            if sh.kind == "quake", (site?.quake ?? 0) >= 0.5 { f *= mitigatedFactor(sh.wafers, sh) }
            return f
        }
    }

    static func packFactor(_ s: GameState, supplier: String) -> Double {
        activeShocks(s).reduce(1.0) { acc, sh in
            (sh.foundry.isEmpty || supplier.hasPrefix(sh.foundry)) ? acc * mitigatedFactor(sh.packaging, sh) : acc
        }
    }

    static func hbmFactor(_ s: GameState) -> Double {
        activeShocks(s).reduce(1.0) { $0 * mitigatedFactor($1.hbm, $1) }
    }

    /// Export rules in force for your sales: the historical controls plus any tightening shock.
    static func exportRules(_ s: GameState) -> (china: Bool, gulfHalf: Bool) {
        let shock = activeShocks(s).contains { $0.export }
        let home = HQ.region(s)
        let china = (s.market.exportControls || shock) && home != .china
        return (china, shock && home != .gulf)
    }

    /// Why a foundry won't take your booking (export rules), or nil.
    static func foundryBlocker(_ f: Foundry, _ n: ProcessNode, _ s: GameState) -> String? {
        let home = HQ.region(s)
        if home == .china && s.market.exportControls && f.region != .china && n.density > 1.0 {
            return "Export controls: \(f.name) can't make chips finer than 7 nm for a Chinese company."
        }
        if f.id == "pearl" && home != .china && activeShocks(s).contains(where: { $0.export }) {
            return "Export rules froze new orders at \(f.name)."
        }
        return nil
    }

    // MARK: Fabs

    static func fabCost(_ n: ProcessNode, wafers: Double) -> Double { 2e9 + wafers * n.fabPerWafer }

    static func fabBuildDays(_ site: FabSite, wafers: Double) -> Int {
        Int((30 + wafers / 10_000 * 2) * 30.4 * site.buildFactor)
    }

    /// Share of a fab's capacity running: tools are installed and qualified over its first year.
    static func fabRamp(_ f: SemiFab, _ s: GameState) -> Double {
        guard f.open(s.date) else { return 0 }
        let months = Double(GameCalendar.daysBetween(f.opens, s.date)) / 30.4
        return clamp(0.15 + 0.85 * months / 12, 0.15, 1)
    }

    static func fabMW(_ f: SemiFab, _ s: GameState) -> Double {
        let n = SemiCatalog.node(f.node)
        return n.fabMW * f.wafersMonth / 1_000 * (f.open(s.date) ? 0.3 + 0.7 * fabRamp(f, s) : 0)
    }

    static func fabWater(_ f: SemiFab, _ s: GameState) -> Double {
        SemiCatalog.node(f.node).fabWater * f.wafersMonth / 1_000 * fabRamp(f, s)
    }

    /// Daily running cost of an open fab: staff and maintenance, consumables per wafer and power.
    static func fabOpexDay(_ f: SemiFab, _ s: GameState, wafersDay: Double) -> (fixed: Double, wafers: Double, power: Double) {
        let n = SemiCatalog.node(f.node)
        let power = fabMW(f, s) * 1_000 * 24 * (SemiCatalog.siteByID[f.site]?.power ?? 0.08)
        return (f.buildCost * 0.003 / 30.4, wafersDay * 0.22 * n.waferPrice, power)
    }

    /// What other chipmakers pay for a wafer from your fab, and how much spare capacity they'll take.
    static func foundryServicePrice(_ f: SemiFab, _ s: GameState) -> (price: Double, fill: Double) {
        let n = SemiCatalog.node(f.node)
        let market = waferPrice(n, SemiCatalog.foundryByID["fsw"]!, s.year)
        let age = s.year - n.launch
        return (market * 0.6, 0.7 * clamp(1 - (age - 6) / 6, 0.2, 1))
    }

    // MARK: Production costs (planning)

    /// What one good chip costs to make today at a foundry, by input.
    static func unitCost(_ d: SemiDesign, foundry f: Foundry, _ s: GameState) -> (total: Double, wafer: Double, pack: Double, hbm: Double, test: Double) {
        let n = SemiCatalog.node(d.node)
        let die = SemiCatalog.die(d.die)
        let y = d.inProduction ? productYield(d, foundry: f, s) : previewYield(node: d.node, die: d.die, foundry: f, s)
        let wafer = waferPrice(n, f, s.year) / max(0.01, y.diesPerWafer * y.good) * Double(die.dies)
        let packSup = SemiCatalog.supplierByID["fsw_pack"]!
        let pack = supplyPrice(packSup, s) * die.slots / packSup.yield
        let hbm = supplyPrice(SemiCatalog.supplierByID["hanseong_mem"]!, s) * Double(d.stacks)
        let test = 150.0 * Double(die.dies)
        return (wafer + pack + hbm + test, wafer, pack, hbm, test)
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        guard s.semi.engaged else { return }
        teamsAndDesigns(&s)
        produce(&s)
        sell(&s)
        contractsDue(&s)
        fabsDaily(&s)
    }

    static func spend(_ s: inout GameState, _ amount: Double, capex: Bool = false, chips: Bool = false) {
        guard amount > 0 else { return }
        s.cash -= amount
        if capex { s.month.capex += amount } else if chips { s.month.costChips += amount } else { s.month.costOther += amount }
    }

    static func teamsAndDesigns(_ s: inout GameState) {
        for t in s.semi.teams {
            let c = Double(t.engineers) * engineerCost(s.year) / 365
            spend(&s, c)
            s.semi.month.teamCost += c
        }
        for i in s.semi.designs.indices {
            let d = s.semi.designs[i]
            switch d.phase {
            case .architecture, .rtl, .physical:
                guard let t = team(s, d.teamID) else {
                    s.semi.designs[i].waiting = "No design team assigned."
                    continue
                }
                if let other = teamBusy(s, t.id, except: d.id), other.started < d.started {
                    s.semi.designs[i].waiting = "\(t.name) is busy with \(other.name)."
                    continue
                }
                s.semi.designs[i].waiting = ""
                let ip = SemiCatalog.node(d.node).ipMonth / 30.4
                spend(&s, ip)
                s.semi.month.designCost += ip
                s.semi.designs[i].spent += ip + Double(t.engineers) * engineerCost(s.year) / 365
                s.semi.designs[i].phaseDaysLeft -= 1
                if s.semi.designs[i].phaseDaysLeft <= 0 { advance(&s, i) }
            case .tapeout:
                s.semi.designs[i].phaseDaysLeft -= 1
                if s.semi.designs[i].phaseDaysLeft <= 0 { advance(&s, i) }
            case .bringup:
                guard !d.bugOpen else { continue }
                s.semi.designs[i].phaseDaysLeft -= 1
                if s.semi.designs[i].phaseDaysLeft <= 0 { bringupDone(&s, i) }
            case .production, .retired:
                continue
            }
        }
    }

    /// Where a node can be made right now (for tape-out).
    static func tapeoutFoundry(_ n: ProcessNode, _ s: GameState) -> Foundry? {
        SemiCatalog.foundries.first { offered(n, $0, s.year) && foundryBlocker($0, n, s) == nil }
    }

    static func advance(_ s: inout GameState, _ i: Int) {
        let d = s.semi.designs[i]
        let p = plan(node: d.node, verification: d.verification, team: team(s, d.teamID), derived: !d.derivedFrom.isEmpty, s)
        switch d.phase {
        case .architecture, .rtl:
            let next = d.phaseRaw + 1
            s.semi.designs[i].phaseRaw = next
            s.semi.designs[i].phaseDays = p.phaseDays[next]
            s.semi.designs[i].phaseDaysLeft = p.phaseDays[next]
            note(&s, i, "\(SemiPhase(rawValue: next)!.title) started.")
        case .physical:
            let n = SemiCatalog.node(d.node)
            guard let f = tapeoutFoundry(n, s) else {
                s.semi.designs[i].waiting = "Ready to tape out; waiting for a foundry to open \(n.short) (first in \(Fmt.trim(n.launch, 1)))."
                s.semi.designs[i].phaseDaysLeft = 7
                return
            }
            let masks = n.maskCost * (d.derivedFrom.isEmpty ? 1 : 0.8)
            spend(&s, masks, capex: true)
            s.semi.month.designCost += masks
            s.semi.designs[i].spent += masks
            s.semi.designs[i].waiting = ""
            s.semi.designs[i].phaseRaw = SemiPhase.tapeout.rawValue
            s.semi.designs[i].phaseDays = n.fabDays
            s.semi.designs[i].phaseDaysLeft = n.fabDays
            s.semi.designs[i].arch = archQuality(generation: d.generation, team: team(s, d.teamID), derived: !d.derivedFrom.isEmpty, s).value
            note(&s, i, "Taped out at \(f.name): mask set \(Fmt.money(masks)). First wafers in about \(Int(n.fabDays / 30.4) + 1) months.", tone: 1)
            Sim.news(&s, "\(d.name) taped out", "Your \(n.short) accelerator went to \(f.name) for its masks (\(Fmt.money(masks))). Respin odds at bring-up: \(Fmt.pct(p.respin, decimals: 0)).",
                     .hardware, image: "wafer")
        case .tapeout:
            s.semi.designs[i].phaseRaw = SemiPhase.bringup.rawValue
            s.semi.designs[i].phaseDays = 75
            s.semi.designs[i].phaseDaysLeft = 75
            if s.semi.designs[i].respinOdds <= 0 { s.semi.designs[i].respinOdds = p.respin }
            note(&s, i, "First silicon is back: bring-up started (respin odds \(Fmt.pct(s.semi.designs[i].respinOdds, decimals: 0))).")
        default:
            break
        }
    }

    static func bringupDone(_ s: inout GameState, _ i: Int) {
        let d = s.semi.designs[i]
        let r = roll(s, "bug|\(d.id)|\(d.respins)|\(d.metalFixes)")
        s.semi.designs[i].lastRoll = r
        if r < d.respinOdds {
            s.semi.designs[i].bugOpen = true
            let n = SemiCatalog.node(d.node)
            let metal = n.maskCost * 0.2, full = n.maskCost * 0.7
            note(&s, i, "Bring-up found a bug (odds were \(Fmt.pct(d.respinOdds, decimals: 0)), roll \(Fmt.trim(r, 2))).", tone: -1)
            let bug = ["a race condition in the matrix-unit scheduler", "a timing violation on the HBM interface at full speed",
                       "a cache-coherence deadlock under heavy collective traffic", "a power-delivery droop that crashes chips at peak clock"][Int(roll(s, "bugtext|\(d.id)|\(d.respins)") * 4) % 4]
            Events.addDecision(&s, kind: bugKind, title: "\(d.name) first silicon has a bug",
                               body: "Bring-up found \(bug). Chips work, but not at spec. Your engineers have three ways forward.",
                               image: "wafer_closeup",
                               options: [DecisionOption(label: "Metal-layer fix", detail: "Re-spin only the top metal masks: \(Fmt.money(metal)), about 2 months, 75% chance it fixes it."),
                                         DecisionOption(label: "Full respin", detail: "New base layers too: \(Fmt.money(full)), about \(Int(n.fabDays / 30.4) + 2) months, fixes it for good."),
                                         DecisionOption(label: "Ship with an erratum", detail: "Fuse off the broken path and lower clocks: production starts now at 12% less performance.")],
                               amount: metal, ref: d.id.uuidString)
            return
        }
        qualify(&s, i)
    }

    static func resolveBug(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let i = s.semi.designs.firstIndex(where: { $0.id.uuidString == d.ref }) else { return }
        let des = s.semi.designs[i]
        let n = SemiCatalog.node(des.node)
        s.semi.designs[i].bugOpen = false
        switch option {
        case 0:
            let c = n.maskCost * 0.2
            spend(&s, c, capex: true)
            s.semi.designs[i].spent += c
            s.semi.month.designCost += c
            s.semi.designs[i].metalFixes += 1
            s.semi.designs[i].respinOdds = 0.25
            s.semi.designs[i].phaseDays = 60
            s.semi.designs[i].phaseDaysLeft = 60
            note(&s, i, "Metal-layer fix: \(Fmt.money(c)), new chips in about 2 months (25% chance the bug survives).")
        case 1:
            let c = n.maskCost * 0.7
            spend(&s, c, capex: true)
            s.semi.designs[i].spent += c
            s.semi.month.designCost += c
            s.semi.designs[i].respins += 1
            s.semi.designs[i].respinOdds = max(0.03, des.respinOdds * 0.3)
            s.semi.designs[i].phaseRaw = SemiPhase.tapeout.rawValue
            s.semi.designs[i].phaseDays = n.fabDays + 30
            s.semi.designs[i].phaseDaysLeft = n.fabDays + 30
            note(&s, i, "Full respin: \(Fmt.money(c)) for new masks; bring-up again in about \(Int((n.fabDays + 30) / 30.4) + 1) months.", tone: -1)
        default:
            s.semi.designs[i].erratum = true
            note(&s, i, "Shipping with an erratum: 12% performance given up for time.", tone: -1)
            qualify(&s, i)
        }
    }

    static func qualify(_ s: inout GameState, _ i: Int) {
        var d = s.semi.designs[i]
        if d.arch <= 0 { d.arch = archQuality(generation: d.generation, team: team(s, d.teamID), derived: !d.derivedFrom.isEmpty, s).value }
        let chips = makeChips(d, s)
        s.customChips.removeAll { c in chips.contains { $0.id == c.id } }
        s.customChips += chips
        HardwareCatalog.register(s.customChips)
        d.chipIDs = chips.map(\.id)
        d.phaseRaw = SemiPhase.production.rawValue
        d.phaseDaysLeft = 0
        d.qualified = s.date
        d.waiting = ""
        for b in 0..<3 {
            if let a = HardwareCatalog.get(chips[b].id) { d.prices[b] = defaultPrice(a, s) }
        }
        s.semi.designs[i] = d
        if let ti = s.semi.teams.firstIndex(where: { $0.id == d.teamID }) { s.semi.teams[ti].experience += 1 }
        let ref = Silicon.reference(s)
        let ultra = chips[0]
        let perf = ultra.bf16 / max(1, ref.bf16)
        note(&s, i, "Qualified for production: \(Fmt.trim(perf, 2))× \(ref.name) (Ultra bin).", tone: 1)
        log(&s, "\(d.name) qualified: \(Fmt.trim(perf, 2))× \(ref.name).", tone: 1)
        Achievements.unlock(&s, "silicon")
        let supplied = s.semi.bookings.contains { $0.designID == d.id && $0.end > s.date } || s.semi.fabs.contains { $0.designID == d.id }
        Sim.news(&s, "\(d.name) is in production",
                 "Your \(SemiCatalog.node(d.node).short) chip qualified: the Ultra bin is \(Fmt.trim(perf, 2))× \(ref.name) at \(Int(ultra.tdpW)) W with \(Fmt.memory(ultra.memoryGB)) \(ultra.memoryType). Dies sort into Ultra, Standard and Lite parts."
                 + (supplied ? " Wafers you booked now become chips." : " Book wafers, packaging and HBM on the Semiconductors page to start making them."),
                 .hardware, image: "wafer", important: true, good: true)
        Alerts.raise(&s, .milestone, key: "semi|\(d.id)", title: "\(d.name) is in production", body: "\(Fmt.trim(perf, 2))× \(ref.name). Make and sell it on the Semiconductors page.",
                     screen: .semiconductors, celebrate: true, cooldown: 0)
    }

    static func defaultPrice(_ a: Accelerator, _ s: GameState) -> Double {
        let ref = Silicon.reference(s)
        let p = ChipBusiness.listPrice(ref, s) * a.best / max(ref.best, 1) * 0.8
        return max(2_000, (p / 100).rounded() * 100)
    }

    // MARK: Production

    struct Flow {
        var wafersDay = 0.0
        var dies = [0.0, 0.0, 0.0]
        var slotsDay = 0.0
        var hbmDay = 0.0
    }

    /// Wafer starts a day for each product, from bookings and your fabs (after shocks), and each source's yield.
    static func sources(_ d: SemiDesign, _ s: GameState) -> [(name: String, wafersDay: Double, yield: Yield, price: Double)] {
        var out: [(String, Double, Yield, Double)] = []
        for bk in s.semi.bookings where bk.designID == d.id && bk.active(s.date) {
            guard let f = SemiCatalog.foundryByID[bk.foundry] else { continue }
            out.append((f.name, bk.wafersMonth / 30.4 * waferFactor(s, foundry: f.id), productYield(d, foundry: f, s), bk.price))
        }
        for fab in s.semi.fabs where fab.designID == d.id && fab.open(s.date) && fab.node == d.node {
            out.append((fab.name, fab.wafersMonth * fabRamp(fab, s) * clamp(fab.productShare, 0, 1) / 30.4 * ownFabFactor(s, fab), fabYield(d, fab: fab, s), 0))
        }
        return out
    }

    static func packSlotsDay(_ s: GameState) -> Double {
        s.semi.supply.filter { $0.kind == "pack" && $0.active(s.date) }.reduce(0) { $0 + $1.units / 30.4 * packFactor(s, supplier: $1.supplier) * ($1.own ? ownLineRamp($1, s) : 1) }
    }

    /// What a packaging slot or HBM stack costs you on average across your active contracts.
    static func averagePrice(_ s: GameState, kind: String) -> Double {
        let act = s.semi.supply.filter { $0.kind == kind && $0.active(s.date) }
        let units = act.reduce(0) { $0 + $1.units }
        guard units > 0 else { return 0 }
        return act.reduce(0) { $0 + $1.units * $1.price } / units
    }

    static func ownLineRamp(_ c: SupplyContract, _ s: GameState) -> Double {
        clamp(0.3 + 0.7 * Double(GameCalendar.daysBetween(c.start, s.date)) / 182, 0.3, 1)
    }

    /// Assembly yield across your packaging contracts (weighted by capacity).
    static func packYield(_ s: GameState) -> Double {
        let act = s.semi.supply.filter { $0.kind == "pack" && $0.active(s.date) }
        let total = act.reduce(0) { $0 + $1.units }
        guard total > 0 else { return 0.97 }
        return act.reduce(0) { $0 + $1.units * (SemiCatalog.supplierByID[$1.supplier]?.yield ?? 0.97) } / total
    }

    static func hbmStacksDay(_ s: GameState) -> Double {
        let f = hbmFactor(s)
        return s.semi.supply.filter { $0.kind == "hbm" && $0.active(s.date) }.reduce(0) { $0 + $1.units / 30.4 * f * (SemiCatalog.supplierByID[$1.supplier]?.yield ?? 0.97) }
    }

    static func produce(_ s: inout GameState) {
        // Take-or-pay: every active booking and supply contract is paid whether or not you use it.
        for bk in s.semi.bookings where bk.active(s.date) {
            let c = bk.wafersMonth / 30.4 * bk.price
            spend(&s, c, chips: true)
            s.semi.month.wafersCost += c
            if let di = s.semi.designs.firstIndex(where: { $0.id == bk.designID }) { s.semi.designs[di].cost += c }
        }
        for c in s.semi.supply where c.active(s.date) {
            let v = c.units / 30.4 * c.price
            spend(&s, v, chips: true)
            if c.kind == "pack" { s.semi.month.packCost += v } else { s.semi.month.hbmCost += v }
        }
        s.semi.hbmStock += hbmStacksDay(s)
        // Wafers → good dies into each product's die bank.
        var anyProduct = false
        for i in s.semi.designs.indices where s.semi.designs[i].inProduction {
            anyProduct = true
            let d = s.semi.designs[i]
            for src in sources(d, s) where src.wafersDay > 0 {
                for b in 0..<3 { s.semi.designs[i].dieBank[b] += src.wafersDay * src.yield.diesPerWafer * src.yield.bins[b] }
                s.semi.designs[i].wafersDone += src.wafersDay
                s.semi.month.wafers += src.wafersDay
                s.semi.month.goodDies += src.wafersDay * src.yield.diesPerWafer * src.yield.good
            }
            for bk in s.semi.bookings where bk.designID == d.id && bk.active(s.date) {
                s.semi.foundryWafers[bk.foundry, default: 0] += bk.wafersMonth / 30.4 * waferFactor(s, foundry: bk.foundry)
            }
        }
        guard anyProduct else { return }
        // Dies → packages: slots and HBM are shared across products in proportion to the dies waiting.
        let slots = packSlotsDay(s)
        var slotDemand = 0.0, hbmDemand = 0.0
        for d in s.semi.designs where d.inProduction {
            let die = SemiCatalog.die(d.die)
            for b in 0..<3 {
                let chips = d.dieBank[b] / Double(die.dies)
                slotDemand += chips * die.slots
                hbmDemand += chips * Double(stacksFor(bin: b, d))
            }
        }
        guard slotDemand > 0 else { return }
        let fSlots = min(1, slots / slotDemand)
        let fHBM = hbmDemand * fSlots > 0 ? min(1, s.semi.hbmStock / (hbmDemand * fSlots)) : 0
        let f = fSlots * fHBM
        if fSlots < 1 && fSlots <= fHBM { s.semi.month.packDays += 1 } else if fHBM < 1 { s.semi.month.hbmDays += 1 } else { s.semi.month.waferDays += 1 }
        guard f > 0 else { return }
        let py = packYield(s)
        let slotPrice = averagePrice(s, kind: "pack"), stackPrice = averagePrice(s, kind: "hbm")
        var hbmUsed = 0.0
        for i in s.semi.designs.indices where s.semi.designs[i].inProduction {
            let d = s.semi.designs[i]
            let die = SemiCatalog.die(d.die)
            for b in 0..<3 {
                let chips = d.dieBank[b] / Double(die.dies) * f
                guard chips > 0 else { continue }
                s.semi.designs[i].dieBank[b] -= chips * Double(die.dies)
                hbmUsed += chips * Double(stacksFor(bin: b, d))
                s.semi.designs[i].cost += chips * (die.slots * slotPrice + Double(stacksFor(bin: b, d)) * stackPrice)
                let good = chips * py
                s.semi.designs[i].made[b] += good
                s.semi.designs[i].monthMade[b] += good
                s.semi.month.chips += good
                s.semi.designs[i].stockMine[b] += good * s.semi.keepShare
                s.semi.designs[i].stockSale[b] += good * (1 - s.semi.keepShare)
            }
        }
        s.semi.hbmStock = max(0, s.semi.hbmStock - hbmUsed)
    }

    static func fabsDaily(_ s: inout GameState) {
        for i in s.semi.supply.indices where s.semi.supply[i].own && s.semi.supply[i].unpaid > 0 {
            let days = max(1, GameCalendar.daysBetween(s.date, s.semi.supply[i].start))
            let pay = s.semi.supply[i].unpaid / Double(days)
            spend(&s, pay, capex: true)
            s.semi.supply[i].unpaid -= pay
            s.semi.month.fabCost += pay
        }
        for i in s.semi.fabs.indices {
            let fab = s.semi.fabs[i]
            if !fab.open(s.date) {
                // Construction is paid as it goes.
                let days = max(1, GameCalendar.daysBetween(s.date, fab.opens))
                let pay = fab.unpaid / Double(days)
                spend(&s, pay, capex: true)
                s.semi.fabs[i].unpaid -= pay
                s.semi.month.fabCost += pay
                continue
            }
            if GameCalendar.daysBetween(fab.opens, s.date) == 0 {
                Sim.news(&s, "\(fab.name) is open", "Your own \(SemiCatalog.node(fab.node).short) fab starts its first wafers. Tools qualify over the first year (15% → 100% of \(Fmt.count(fab.wafersMonth)) wafers a month) and defect density starts high — it falls with every wafer.",
                         .hardware, image: "wafer_closeup", important: true, good: true)
                Alerts.raise(&s, .milestone, key: "fab|\(fab.id)", title: "\(fab.name) is open", body: "Assign it to a product on the Semiconductors page.", screen: .semiconductors, celebrate: true, cooldown: 0)
                log(&s, "\(fab.name) opened.", tone: 1)
            }
            let wafersDay = fab.wafersMonth * fabRamp(fab, s) / 30.4 * ownFabFactor(s, fab)
            let product = fab.designID.flatMap { id in s.semi.designs.firstIndex { $0.id == id && $0.inProduction && $0.node == fab.node } }
            let share = product == nil ? 0 : clamp(fab.productShare, 0, 1)
            let ox = fabOpexDay(fab, s, wafersDay: wafersDay)
            let cost = ox.fixed + ox.wafers + ox.power
            s.cash -= cost
            s.month.costOther += ox.fixed + ox.wafers
            s.month.costPower += ox.power
            s.semi.month.fabCost += cost
            s.semi.fabs[i].wafersDone += wafersDay
            if let product { s.semi.designs[product].cost += cost * share }
            if share < 1 {
                let fs = foundryServicePrice(fab, s)
                let rev = wafersDay * (1 - share) * fs.fill * fs.price
                s.cash += rev
                s.month.revChips += rev
                s.lifetimeRevenue += rev
                s.semi.month.foundryRevenue += rev
                s.semi.fabs[i].foundryRevenue += rev
            }
        }
    }

    // MARK: Sales

    /// Your standing as a chip supplier: buyers trust vendors whose chips (and software) have shipped at volume.
    static func reputation(_ s: GameState) -> Double {
        let shipped = s.semi.shipped + ChipBusiness.shippedTotal(s)
        return clamp(0.05 + 0.15 * log10(1 + shipped / 50_000) - s.semi.repHit, 0.03, 1)
    }

    struct Demand {
        var perDay: Double
        var value: Double
        var share: Double
        var rep: Double
        var spendDay: Double
        var why: String
    }

    /// Chips a day the whole market would take at `price` (before export rules and who you sell to).
    static func demand(_ chip: Accelerator, price: Double, _ s: GameState) -> Demand {
        let spendDay = ChipBusiness.acceleratorSpend(s.year) * clamp(s.market.hype / 1.3, 0.6, 1.6) / 365
        let v = ChipBusiness.valueRatio(chip: chip, price: price, s)
        let rep = reputation(s)
        let share = ChipBusiness.marketShare(value: v, reputation: rep)
        let mult = max(0.3, 1 + s.traits.chipSales)
        let perDay = spendDay * share / max(price, 1) * mult
        return Demand(perDay: perDay, value: v, share: share, rep: rep, spendDay: spendDay,
                      why: "\(Fmt.money(spendDay * 365)) a year of accelerator spending × \(Fmt.pct(share, decimals: 2)) share (value \(Fmt.trim(v, 2))× a GPU per dollar, supplier reputation \(Fmt.pct(rep, decimals: 0))) ÷ \(Fmt.money(price))")
    }

    struct Buyer {
        var id: String
        var name: String
        var weight: Double
        var rival: Bool
        var blocked: String?
    }

    /// Who buys and in what shares: clouds, sovereigns and enterprises take three quarters of demand, rival labs a quarter
    /// (by compute) if you let them. Export rules and your own policy block some.
    static func buyers(_ s: GameState) -> [Buyer] {
        let rules = exportRules(s)
        let total = SemiCatalog.customers.reduce(0) { $0 + $1.weight }
        var out: [Buyer] = SemiCatalog.customers.map { c in
            var blocked: String? = nil
            if c.region == .china && rules.china { blocked = "export controls" }
            if c.kind == "sovereign" && !s.semi.allowSovereigns { blocked = "you don't sell to sovereigns" }
            let w = c.weight / total * 0.75 * (c.region == .gulf && rules.gulfHalf ? 0.5 : 1)
            return Buyer(id: c.id, name: c.name, weight: w, rival: false, blocked: blocked)
        }
        let rivals = s.competitors.filter { !$0.acquired && !$0.bankrupt && $0.exitNote.isEmpty && s.year >= $0.def.founded.decimal }
        let rtotal = rivals.reduce(0) { $0 + $1.def.computeShare }
        for r in rivals where rtotal > 0 {
            var blocked: String? = nil
            if !s.semi.allowRivals { blocked = "you don't sell to rivals" }
            if AdvancedProjects.labRegion(r.id) == .china && rules.china { blocked = "export controls" }
            out.append(Buyer(id: r.id, name: r.def.name, weight: 0.25 * r.def.computeShare / rtotal, rival: true, blocked: blocked))
        }
        return out
    }

    static func sell(_ s: inout GameState) {
        let buyerList = buyers(s)
        let open = buyerList.filter { $0.blocked == nil }
        let h100 = HardwareCatalog.h100.bf16
        for i in s.semi.designs.indices where s.semi.designs[i].inProduction {
            let d = s.semi.designs[i]
            for b in 0..<3 {
                guard d.chipIDs.indices.contains(b), let chip = HardwareCatalog.get(d.chipIDs[b]) else { continue }
                // Contracts first.
                for ci in s.semi.contracts.indices where !s.semi.contracts[ci].closed && s.semi.contracts[ci].designID == d.id && s.semi.contracts[ci].bin == b {
                    let n = min(s.semi.contracts[ci].remaining, s.semi.designs[i].stockSale[b])
                    guard n > 0 else { continue }
                    let c = s.semi.contracts[ci]
                    s.semi.designs[i].stockSale[b] -= n
                    s.semi.contracts[ci].delivered += n
                    record(&s, i, b, units: n, price: c.price, buyer: c.customer, h100e: n * chip.bf16 / h100)
                }
                guard d.onSale[b], d.prices[b] > 0, s.semi.designs[i].stockSale[b] > 0 else { continue }
                let dem = demand(chip, price: d.prices[b], s)
                let want = dem.perDay * open.reduce(0) { $0 + $1.weight }
                let units = min(want, s.semi.designs[i].stockSale[b])
                guard units > 0 else { continue }
                s.semi.designs[i].stockSale[b] -= units
                let totalW = max(1e-9, open.reduce(0) { $0 + $1.weight })
                for buyer in open {
                    var u = units * buyer.weight / totalW
                    if buyer.rival, let ci = s.competitors.firstIndex(where: { $0.id == buyer.id }) {
                        // A rival only buys what its cash can carry.
                        u = min(u, max(0, s.competitors[ci].cash) * 0.004 / d.prices[b])
                        s.competitors[ci].cash -= u * d.prices[b]
                    }
                    guard u > 0 else { continue }
                    record(&s, i, b, units: u, price: d.prices[b], buyer: buyer.id, h100e: u * chip.bf16 / h100)
                }
            }
        }
    }

    /// Book a sale: cash, revenue, the buyer's tally — and a rival's fleet grows with your chips.
    static func record(_ s: inout GameState, _ i: Int, _ b: Int, units: Double, price: Double, buyer: String, h100e: Double) {
        let rev = units * price
        s.cash += rev
        s.month.revChips += rev
        s.lifetimeRevenue += rev
        s.semi.designs[i].sold[b] += units
        s.semi.designs[i].revenue += rev
        s.semi.month.sold += units
        s.semi.month.revenue += rev
        s.semi.shipped += units
        s.semi.buyers[buyer, default: 0] += units
        if let ci = s.competitors.firstIndex(where: { $0.id == buyer }) {
            s.competitors[ci].armedH100e += h100e
            s.semi.month.toRivals += units
        }
    }

    static func contractsDue(_ s: inout GameState) {
        for ci in s.semi.contracts.indices where !s.semi.contracts[ci].closed {
            let c = s.semi.contracts[ci]
            let name = customerName(c.customer)
            if c.remaining <= 0.5 {
                s.semi.contracts[ci].closed = true
                log(&s, "Delivered \(Fmt.count(c.units)) chips to \(name) on time.", tone: 1)
                Sim.news(&s, "Order delivered: \(name)", "\(Fmt.count(c.units)) chips at \(Fmt.money(c.price)) each — \(Fmt.money(c.units * c.price)).", .hardware, good: true)
                continue
            }
            guard c.deadline <= s.date else { continue }
            s.semi.contracts[ci].closed = true
            let fine = c.remaining * c.price * c.penalty
            s.cash -= fine
            s.month.costOther += fine
            s.semi.month.penalties += fine
            s.semi.repHit = min(0.15, s.semi.repHit + 0.02)
            log(&s, "Missed the \(name) order: \(Fmt.count(c.remaining)) chips short, \(Fmt.money(fine)) penalty.", tone: -1)
            Sim.news(&s, "You missed \(name)'s chip order", "\(Fmt.count(c.remaining)) of \(Fmt.count(c.units)) chips never shipped. Penalty \(Fmt.money(fine)); buyers trust your supply a little less.",
                     .hardware, important: true, good: false)
        }
        let today = s.date
        s.semi.contracts.removeAll { $0.closed && GameCalendar.daysBetween($0.deadline, today) > 120 }
    }

    static func customerName(_ id: String) -> String {
        SemiCatalog.customerByID[id]?.name ?? CompetitorCatalog.byID[id]?.name ?? id
    }

    // MARK: Your own fleet

    static func design(ofChip id: String, _ s: GameState) -> (index: Int, bin: Int)? {
        guard isSemiChip(id), let b = Int(id.suffix(1)) else { return nil }
        guard let i = s.semi.designs.firstIndex(where: { $0.chipIDs.indices.contains(b) && $0.chipIDs[b] == id }) else { return nil }
        return (i, b)
    }

    /// Finished chips of this part you could take for your own fleet now.
    static func available(_ id: String, _ s: GameState) -> Int {
        guard let (i, b) = design(ofChip: id, s) else { return 0 }
        return Int(s.semi.designs[i].stockMine[b] + s.semi.designs[i].stockSale[b])
    }

    /// Take chips from stock (yours first) for a hardware order; returns days to delivery.
    static func take(_ s: inout GameState, _ id: String, count: Int) -> Int {
        guard let (i, b) = design(ofChip: id, s) else { return 45 }
        var n = Double(count)
        let mine = min(n, s.semi.designs[i].stockMine[b])
        s.semi.designs[i].stockMine[b] -= mine
        n -= mine
        s.semi.designs[i].stockSale[b] = max(0, s.semi.designs[i].stockSale[b] - n)
        s.semi.designs[i].taken[b] += Double(count)
        s.semi.month.taken += Double(count)
        return shipDays
    }
}
