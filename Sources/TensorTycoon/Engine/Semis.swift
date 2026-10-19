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

    /// The 2D-channel node (3.6: a science unlock can bring it forward).
    static let twoDNode = "x2d"

    /// When a node exists. Every node arrives on its industry date, except the 2D-channel node, which a lab that
    /// reproduces the 2D transistor (`Science.has(.twoDProcess)`) gets a year after its discovery.
    static func launch(_ n: ProcessNode, _ s: GameState) -> Double {
        guard n.id == twoDNode, let d = Science.unlockDate(.twoDProcess, s) else { return n.launch }
        return min(n.launch, d.decimalYear + 1)
    }

    /// When `node` opens at `f` (its lag behind the leading foundry).
    static func opens(_ n: ProcessNode, _ f: Foundry, _ s: GameState) -> Double { launch(n, s) + f.lag }

    static func offered(_ n: ProcessNode, _ f: Foundry, _ s: GameState) -> Bool { s.year >= opens(n, f, s) && s.year <= launch(n, s) + 16 }

    /// Nodes you can start a design on: open somewhere within two years, and not hopelessly old.
    static func designable(_ s: GameState) -> [ProcessNode] {
        let y = s.year
        let newest = SemiCatalog.nodes.filter { $0.launch <= y }.map(\.launch).max() ?? 2015
        return SemiCatalog.nodes.filter { launch($0, s) <= y + 2 && launch($0, s) >= newest - 6 }
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
        let dfm = AgentOrgs.defectFactor(s)   // 3.9: physical-design agents
        let d0 = ind * f.d0Factor * learn * AdvancedProjects.defectFactor(s) * dfm   // fab process-control programmes
        return yield(d0: d0, area: SemiCatalog.die(d.die).area, wafersDone: d.wafersDone,
                     why: "D0 \(Fmt.trim(d0, 3))/cm² = \(n.short) industry \(Fmt.trim(ind, 3)) × \(f.name) \(Fmt.trim(f.d0Factor, 2)) × your learning \(Fmt.trim(learn, 2)) (\(Fmt.count(d.wafersDone)) wafers so far)"
                        + (dfm < 1 ? " × design-for-manufacturing agents \(Fmt.trim(dfm, 2))" : ""))
    }

    /// The same at your own fab: a new fab starts with several times the defects and learns with every wafer.
    static func fabYield(_ d: SemiDesign, fab: SemiFab, _ s: GameState) -> Yield {
        let n = SemiCatalog.node(d.node)
        let ind = industryD0(n, s.year)
        let fabF = fabD0Factor(fab)
        let learn = 1 + exp(-d.wafersDone / 15_000)
        let dfm = AgentOrgs.defectFactor(s)   // 3.9: physical-design agents
        let d0 = ind * fabF * learn * AdvancedProjects.defectFactor(s) * dfm   // fab process-control programmes
        return yield(d0: d0, area: SemiCatalog.die(d.die).area, wafersDone: d.wafersDone,
                     why: "D0 \(Fmt.trim(d0, 3))/cm² = \(n.short) industry \(Fmt.trim(ind, 3)) × \(fab.name) ramp \(Fmt.trim(fabF, 2)) × your learning \(Fmt.trim(learn, 2))"
                        + (dfm < 1 ? " × design-for-manufacturing agents \(Fmt.trim(dfm, 2))" : ""))
    }

    static func fabD0Factor(_ f: SemiFab) -> Double { 1 + 2.5 * exp(-f.wafersDone / 40_000) }

    /// Expected yield of a design at a foundry if it went into production today (for planning).
    static func previewYield(node: String, die: String, foundry f: Foundry, _ s: GameState, at y: Double? = nil) -> Yield {
        let n = SemiCatalog.node(node)
        let yy = max(y ?? s.year, opens(n, f, s))
        let d0 = industryD0(n, yy) * f.d0Factor * 2 * AdvancedProjects.defectFactor(s) * AgentOrgs.defectFactor(s)   // fab process-control programmes; 3.9 agents
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

    static func link(_ d: SemiDesign) -> ChipLink { ChipLink(rawValue: d.link) ?? .switched }

    static func nodeIndex(_ id: String) -> Int { SemiCatalog.nodes.firstIndex { $0.id == id } ?? 1 }

    /// Node steps between two process nodes (a port may move one).
    static func nodeStep(_ a: String, _ b: String) -> Int { abs(nodeIndex(a) - nodeIndex(b)) }

    /// 3.9: the next generation of a focus is one past the newest design of that focus you have qualified. Designs that
    /// never shipped, and designs of the other focus, don't count; a port keeps its parent's generation.
    static func nextGeneration(_ focus: ChipFocus, _ s: GameState) -> Int {
        1 + (s.semi.designs.filter { $0.focus == focus && $0.qualified != nil }.map(\.generation).max() ?? 0)
    }

    /// Qualified designs a new design on `node` can port: the same focus, at most one node step away.
    static func portable(_ s: GameState, focus: ChipFocus, node: String) -> [SemiDesign] {
        s.semi.designs.filter { $0.qualified != nil && $0.focus == focus && nodeStep($0.node, node) <= 1 }
    }

    static func parent(_ d: SemiDesign, _ s: GameState) -> SemiDesign? { d.parentID.flatMap { id in s.semi.designs.first { $0.id == id } } }

    /// A port (new or from an older save, which only kept the parent's name).
    static func isPort(_ d: SemiDesign) -> Bool { d.parentID != nil || !d.derivedFrom.isEmpty }

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
    static func plan(node: String, verification v: Int, team: SemiTeam?, derived: Bool, link: ChipLink = .switched, _ s: GameState) -> Plan {
        let n = SemiCatalog.node(node)
        let eng = Double(team?.engineers ?? 300)
        let teamF = pow(300 / max(50, eng), 0.5)
        let sp = speedFactor(s)
        let days = n.designMonths * 30.4 * teamF * verificationTime[clamp(v, 0, 2)] * (derived ? 0.6 : 1) * sp.value
        let phases = [days * 0.2, days * 0.5, days * 0.3, n.fabDays, 75]
        let teamCost = eng * engineerCost(s.year) / 365 * days
        let ipCost = n.ipMonth * link.ipFactor * days / 30.4
        let exp = Double(min(team?.experience ?? 0, 4))
        let df = Silicon.designerFactor(s)
        let search = AgentOrgs.respinFactor(s)
        let models = Capabilities.respinFactor(s)   // 3.8: your models' hardware engineering
        var r = n.respin * verificationRisk[clamp(v, 0, 2)] * (1 - 0.1 * exp) * (1 - 0.25 * df) * (1 - 0.4 * s.swarmSilicon) * (derived ? 0.7 : 1) * search * models
            + link.respin
        r = clamp(r, 0.03, 0.85)
        var parts = ["\(n.short) first-pass \(Fmt.pct(n.respin, decimals: 0))", "\(verificationName(v).lowercased()) verification ×\(Fmt.trim(verificationRisk[clamp(v, 0, 2)], 2))"]
        if exp > 0 { parts.append("\(Int(exp)) tape-out\(exp == 1 ? "" : "s") of experience ×\(Fmt.trim(1 - 0.1 * exp, 2))") }
        if df > 0 { parts.append("chip designers ×\(Fmt.trim(1 - 0.25 * df, 2))") }
        if s.swarmSilicon > 0 { parts.append("agent swarms ×\(Fmt.trim(1 - 0.4 * s.swarmSilicon, 2))") }
        if derived { parts.append("port of a proven design ×0.7") }
        if search < 1 { parts.append("architecture-search agents ×\(Fmt.trim(search, 2))") }
        if abs(models - 1) > 0.005 { parts.append("your models' hardware engineering ×\(Fmt.trim(models, 2))") }
        if link.respin > 0 { parts.append("\(link.short) +\(Fmt.pct(link.respin, decimals: 0)) (new technology)") }
        var t = ["\(n.short) baseline \(Int(n.designMonths)) months for 300 engineers", "\(Int(eng)) engineers ×\(Fmt.trim(teamF, 2))",
                 "\(verificationName(v).lowercased()) verification ×\(Fmt.trim(verificationTime[clamp(v, 0, 2)], 2))"]
        if derived { t.append("port ×0.6") }
        if sp.value != 1 { t.append("speed ×\(Fmt.trim(sp.value, 2))" + (sp.why.isEmpty ? "" : " (\(sp.why.joined(separator: ", ")))")) }
        t.append("then tape-out \(Int(n.fabDays)) days and bring-up 75 days")
        return Plan(designDays: days, phaseDays: phases, teamCost: teamCost, ipCost: ipCost, maskCost: n.maskCost, respin: r,
                    respinWhy: parts.joined(separator: " · "), timeWhy: t.joined(separator: " · "))
    }

    /// Architecture quality (1.0 = as good as the best GPU maker's design on the same node). A port reuses its
    /// parent's architecture: no step up, and a little lost re-timing it for another node.
    static func archQuality(generation g: Int, team: SemiTeam?, port: SemiDesign? = nil, node: String = "", _ s: GameState) -> (value: Double, why: String) {
        if let p = port {
            let base = p.arch > 0 ? p.arch : 0.55
            let retime = node.isEmpty || node == p.node ? 0.0 : 0.02
            return (max(0.4, base - retime), "port of \(p.name): its architecture \(Fmt.trim(base, 2))" + (retime > 0 ? " − 0.02 re-timed for \(SemiCatalog.node(node).short)" : ""))
        }
        let df = Silicon.designerFactor(s)
        let bonus = s.traits.chipDesign + s.bonuses.chipDesign
        let exp = Double(min(team?.experience ?? 0, 5))
        let gen = Double(min(g - 1, 5))
        let search = AgentOrgs.archSearch(s)
        let cap = 1.2 + AgentOrgs.archCapBonus(s) + search
        let models = Capabilities.chipArchFactor(s)   // 3.8: your models' hardware engineering explores more of the design space
        var v = (0.55 + 0.07 * gen + 0.03 * exp + 0.08 * df + 0.1 * s.swarmSilicon + 0.25 * bonus + search) * models
        v = clamp(v, 0.4, cap)
        var parts = ["first design 0.55"]
        if gen > 0 { parts.append("generation \(g) +\(Fmt.trim(0.07 * gen, 2))") }
        if exp > 0 { parts.append("team experience +\(Fmt.trim(0.03 * exp, 2))") }
        if df > 0 { parts.append("chip designers +\(Fmt.trim(0.08 * df, 2))") }
        if s.swarmSilicon > 0 { parts.append("swarms +\(Fmt.trim(0.1 * s.swarmSilicon, 2))") }
        if bonus > 0 { parts.append("research & traits +\(Fmt.trim(0.25 * bonus, 2))") }
        if search > 0 { parts.append("architecture-search agents +\(Fmt.trim(search, 2))") }
        if abs(models - 1) > 0.005 { parts.append("your models' hardware engineering ×\(Fmt.trim(models, 2))") }
        parts.append("cap \(Fmt.trim(cap, 2))" + (cap > 1.2 ? " (raised by your silicon organisation)" : ""))
        return (v, parts.joined(separator: " · "))
    }

    // MARK: Chip specs (3.9)

    struct Spec {
        var bf16: Double
        var fp8: Double
        var fp4: Double
        var tdpW: Double
        var memoryGB: Double
        var bandwidthTBs: Double
        var scaleUp: Int
        var icGBs: Double
        var link: ChipLink
        /// Share of the peak that survives training (inference parts train badly).
        var trainFactor: Double
        /// Training MFU with a fully mature compiler, before your lab's own bonuses.
        var mfu: Double
        var why: String
    }

    /// Dense BF16 a design delivers: the node's TFLOPS per mm² × logic area × architecture (× an erratum). It is fixed
    /// when the design tapes out — the same silicon does the same work whenever it ships.
    static func peakBF16(arch: Double, node: String, die: String, erratum: Bool) -> Double {
        SemiCatalog.node(node).tfmm * SemiCatalog.die(die).siliconArea * arch * (erratum ? 0.88 : 1)
    }

    /// Scale-up domain and per-chip interconnect bandwidth of a link generation designed in `y`.
    static func domain(_ link: ChipLink, focus: ChipFocus, year y: Double) -> (size: Int, gbs: Double) {
        let nvl = interpolate([(2016, 300), (2020, 600), (2022, 900), (2024, 1_800), (2026, 3_600), (2028, 7_200), (2032, 14_400)], at: y)
        let train: Int
        let gbs: Double
        switch link {
        case .switched:
            train = y < 2024 ? 8 : (y < 2027.5 ? 72 : 144)
            gbs = nvl
        case .ethernet:
            train = 8
            gbs = nvl * 0.25
        case .optical:
            train = 576
            gbs = nvl * 2
        }
        return focus == .training ? (train, gbs) : (max(4, train / 4), gbs * 0.5)
    }

    /// What a design is, from its silicon alone: compute from the node, die and architecture; power from the node;
    /// memory and interconnect from the generation it taped out in. Training parts run every precision and big
    /// scale-up domains; inference parts give up high-precision area for FP4, lower power and more memory bandwidth per
    /// FLOP, and train badly on small domains.
    static func spec(node: String, die: String, stacks: Int, focus: ChipFocus, link: ChipLink, arch: Double, erratum: Bool, year y: Double,
                     bin b: Int = 0, _ s: GameState) -> Spec {
        let base = peakBF16(arch: arch, node: node, die: die, erratum: erratum) * binPerf[clamp(b, 0, 2)]
        let training = focus == .training
        let k = Double(b == 2 ? max(2, Int((Double(stacks) * 0.75).rounded())) : stacks)
        let dom = domain(link, focus: focus, year: y)
        let mfu = [0.44, 0.41, 0.45][link.rawValue]
        let n = SemiCatalog.node(node)
        let d = SemiCatalog.die(die)
        let why = "\(Fmt.trim(n.tfmm, 2)) TF/mm² on \(n.short) × \(Int(d.siliconArea)) mm² of logic × architecture \(Fmt.trim(arch, 2))"
            + (erratum ? " × erratum 0.88" : "") + (b > 0 ? " × \(SemiCatalog.binNames[b]) bin \(Fmt.trim(binPerf[b], 2))" : "")
            + (training ? "" : "; inference layout: BF16 ×0.55, FP4 6× BF16, 80% of the power, half the training efficiency")
        return Spec(bf16: base * (training ? 1 : 0.55), fp8: base * 2, fp4: base * (training ? 4 : 6),
                    tdpW: tdp(node: node, die: die) * binPower[clamp(b, 0, 2)] * (training ? 1 : 0.8 * AdvancedProjects.edgeChipPower(s)),   // edge AI hardware programmes
                    memoryGB: k * stackGB(y), bandwidthTBs: k * stackTBs(y), scaleUp: dom.size, icGBs: dom.gbs, link: link,
                    trainFactor: training ? 1 : 0.5, mfu: mfu, why: why)
    }

    /// The same for a design (its tape-out year, or for older designs the year it qualified).
    static func spec(_ d: SemiDesign, bin b: Int = 0, _ s: GameState) -> Spec {
        let y = d.tapeoutYear > 0 ? d.tapeoutYear : (d.qualified?.decimalYear ?? s.year)
        return spec(node: d.node, die: d.die, stacks: d.stacks, focus: d.focus, link: link(d), arch: d.arch > 0 ? d.arch : 0.55, erratum: d.erratum, year: y, bin: b, s)
    }

    /// "1.7× B300": a label against today's best merchant part (the spec itself never depends on it).
    static func perfLabel(_ bf16: Double, _ s: GameState) -> String {
        let ref = Silicon.reference(s)
        return "\(Fmt.trim(bf16 / max(1, ref.bf16), 2))× \(ref.name)"
    }

    /// Board power for the Ultra part: power per mm² rises with density, falls with each node's efficiency.
    static func tdp(node: String, die: String) -> Double {
        let n = SemiCatalog.node(node)
        let d = SemiCatalog.die(die)
        return (0.75 * Double(d.dies) * d.area * pow(n.power * n.density / 1.35, 0.7) / 10).rounded() * 10
    }

    /// Server, board and network share around one chip: what taking a chip for your own fleet costs once the silicon is
    /// paid. 3.9: a cost of its own (boards, host CPUs, NICs and cables get dearer slowly), no longer a share of the GPU
    /// makers' list price — the silicon is costed separately (`siliconCost`).
    static func systemCost(_ s: GameState) -> Double {
        (interpolate([(2016, 2_500), (2020, 3_500), (2024, 5_000), (2028, 7_000), (2032, 9_000)], at: s.year) / 100).rounded() * 100
    }

    /// 3.9: what the silicon in one of your chips costs to make today (wafer, packaging, HBM and test per good chip):
    /// added to the server around it when your fleet's chips are valued and their running cost is worked out, so a model
    /// served on your own chips pays for the silicon like one on bought chips. Zero for any other chip.
    static func siliconCost(_ chipID: String, _ s: GameState) -> Double {
        guard isSemiChip(chipID), let (i, _) = design(ofChip: chipID, s), let fsw = SemiCatalog.foundryByID["fsw"] else { return 0 }
        return unitCost(s.semi.designs[i], foundry: fsw, s).total
    }

    static func stacksFor(bin b: Int, _ d: SemiDesign) -> Int { b == 2 ? max(2, Int((Double(d.stacks) * 0.75).rounded())) : d.stacks }

    static let binPerf = [1.0, 0.88, 0.7]
    static let binPower = [1.0, 0.95, 0.8]

    // MARK: Software maturity (3.9)

    /// Training MFU your chips reach against a fully mature compiler: an immature stack leaves a third on the table.
    static func softwareMFU(_ m: Double) -> Double { 0.62 + 0.38 * clamp(m, 0, 1) }

    /// Serving throughput against a merchant part with the same peak (kernels, graph compiler, quantisation support).
    static func softwareServe(_ m: Double) -> Double { 0.7 + 0.35 * clamp(m, 0, 1) }

    /// Decode efficiency (share of memory bandwidth that turns into tokens): more bandwidth per FLOP decodes better,
    /// and a mature stack wastes less of it.
    static func decodeEff(focus: ChipFocus, bandwidthTBs: Double, bf16: Double, software m: Double) -> Double {
        let ratio = bandwidthTBs / max(1, bf16) / 0.0034
        return clamp((focus == .training ? 0.62 : 0.74) + 0.06 * log2(max(0.25, ratio)), 0.5, 0.92) * (0.85 + 0.15 * clamp(m, 0, 1))
    }

    /// Yearly cost of the compiler and kernel team.
    static func compilerCostYear(_ s: GameState) -> Double { Double(s.semi.compilerEngineers) * engineerCost(s.year) * 0.9 }

    /// How fast your software stack matures a year, by source (each year it closes that share of the gap to 1).
    /// Nothing to compile for until you have a design.
    static func softwareRates(_ s: GameState) -> [(why: String, rate: Double)] {
        guard !s.semi.designs.isEmpty else { return [] }
        var out: [(String, Double)] = []
        let e = Double(s.semi.compilerEngineers)
        if e > 0 { out.append(("\(Int(e)) compiler & kernel engineers", 0.45 * (e / 150).squareRoot())) }
        let used = s.semi.shipped + s.semi.designs.reduce(0) { $0 + $1.taken.reduce(0, +) }
        if used > 0 { out.append(("\(Fmt.count(used)) of your chips in use (bug reports, kernels, users)", 0.08 * log10(1 + used / 10_000))) }
        let org = AgentOrgs.compilerLevel(s)
        if org > 0 { out.append(("software organisation's compiler work", 0.8 * org)) }
        return out
    }

    static func softwareRate(_ s: GameState) -> Double { softwareRates(s).reduce(0) { $0 + $1.rate } }

    static func softwareDaily(_ s: inout GameState) {
        let cost = compilerCostYear(s) / 365
        spend(&s, cost)
        s.semi.month.softwareCost += cost
        let r = softwareRate(s)
        guard r > 0 else { return }
        s.semi.software = min(1, s.semi.software + (1 - s.semi.software) * r / 365)
    }

    /// The three chips (Ultra, Standard, Lite) a qualified design becomes.
    static func makeChips(_ d: SemiDesign, _ s: GameState) -> [CustomChip] {
        let y = d.tapeoutYear > 0 ? d.tapeoutYear : s.year
        let company = s.companyName.split(separator: " ").first.map(String.init) ?? "Custom"
        let m = s.semi.software
        return (0..<3).map { b in
            let sp = spec(d, bin: b, s)
            var c = CustomChip(
                id: "\(chipPrefix)\(d.id.uuidString.prefix(8).lowercased())_\(b)",
                name: "\(company) \(d.name) \(SemiCatalog.binNames[b])",
                focus: d.focus, available: s.date, process: SemiCatalog.node(d.node).name,
                memoryGB: sp.memoryGB, memoryType: hbmGeneration(y), bandwidthTBs: sp.bandwidthTBs,
                bf16: sp.bf16, fp8: sp.fp8, fp4: sp.fp4, tdpW: sp.tdpW, unitCost: systemCost(s),
                decodeEff: decodeEff(focus: d.focus, bandwidthTBs: sp.bandwidthTBs, bf16: sp.bf16, software: m),
                scaleUp: sp.scaleUp, generation: d.generation)
            c.mfu = sp.mfu * softwareMFU(m)
            c.trainFactor = sp.trainFactor
            c.serveFactor = softwareServe(m)
            c.icGBs = sp.icGBs
            c.link = sp.link.title
            return c
        }
    }

    /// Re-registers your chips with today's software maturity (training MFU, serving throughput, decode efficiency)
    /// and their interconnect. Their compute, memory and power never change.
    static func refreshChips(_ s: inout GameState) {
        let m = s.semi.software
        for ci in s.customChips.indices where isSemiChip(s.customChips[ci].id) {
            guard let (i, b) = design(ofChip: s.customChips[ci].id, s) else { continue }
            let sp = spec(s.semi.designs[i], bin: b, s)
            let c = s.customChips[ci]
            s.customChips[ci].mfu = sp.mfu * softwareMFU(m)
            s.customChips[ci].trainFactor = sp.trainFactor
            s.customChips[ci].serveFactor = softwareServe(m)
            s.customChips[ci].decodeEff = decodeEff(focus: c.focus, bandwidthTBs: c.bandwidthTBs, bf16: c.bf16, software: m)
            s.customChips[ci].icGBs = sp.icGBs
            s.customChips[ci].link = sp.link.title
            s.customChips[ci].scaleUp = sp.scaleUp
        }
        s.semi.softwareRegistered = m
        HardwareCatalog.register(s.customChips)
    }

    /// 3.9: save repair — the three-bin arrays an older or damaged save may hold short, and the chips' new fields.
    static func repair(_ s: inout GameState) {
        func pad<T>(_ a: [T], _ v: T) -> [T] { a.count >= 3 ? a : a + Array(repeating: v, count: 3 - a.count) }
        for i in s.semi.designs.indices {
            s.semi.designs[i].dieBank = pad(s.semi.designs[i].dieBank, 0)
            s.semi.designs[i].stockMine = pad(s.semi.designs[i].stockMine, 0)
            s.semi.designs[i].stockSale = pad(s.semi.designs[i].stockSale, 0)
            s.semi.designs[i].prices = pad(s.semi.designs[i].prices, 0)
            s.semi.designs[i].onSale = pad(s.semi.designs[i].onSale, false)
            s.semi.designs[i].made = pad(s.semi.designs[i].made, 0)
            s.semi.designs[i].monthMade = pad(s.semi.designs[i].monthMade, 0)
            s.semi.designs[i].lastMade = pad(s.semi.designs[i].lastMade, 0)
            s.semi.designs[i].sold = pad(s.semi.designs[i].sold, 0)
            s.semi.designs[i].taken = pad(s.semi.designs[i].taken, 0)
        }
        for i in s.semi.shocks.indices where s.semi.shocks[i].drought <= 0 { s.semi.shocks[i].drought = s.semi.shocks[i].kind == "drought" ? 0.75 : 1 }
        if s.customChips.contains(where: { isSemiChip($0.id) && $0.mfu <= 0 }) { refreshChips(&s) }
    }

    // MARK: Supply caps and prices

    /// Wafers a month a foundry will commit to you at a node: grows as the node matures and with your history there,
    /// shrinks when wafers are scarce.
    static func waferCap(_ f: Foundry, _ n: ProcessNode, _ s: GameState) -> (value: Double, why: String) {
        let y = s.year
        let age = y - opens(n, f, s)
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

    /// Export rules in force for your sales: the historical controls, any tightening shock, and (3.9) your home
    /// country's own export-control dial — strict enough and it stops sales to China, stricter still and the Gulf
    /// needs licences.
    static func exportRules(_ s: GameState) -> (china: Bool, gulfHalf: Bool) {
        let shock = activeShocks(s).contains { $0.export }
        let home = HQ.region(s)
        let dial = s.nations.ready ? s.nations.level(home, .exports) : 0
        let china = (s.market.exportControls || shock || dial >= 60) && home != .china
        return (china, (shock || dial >= 75) && home != .gulf)
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

    /// 3.9: where a fab's power comes from (the grid unless you signed a deal for it).
    static func fabPowerDeal(_ f: SemiFab) -> PowerDeal { PowerDeal(rawValue: f.powerDeal) ?? .grid }

    /// 3.9: what a fab pays per kWh, like a datacenter: the site's industrial rate × its power deal, grid strain on
    /// grid power, the region's energy policy, and the energy research and infrastructure teams that cut your
    /// datacenters' bill too.
    static func fabPowerPrice(_ f: SemiFab, _ s: GameState) -> Double {
        let site = SemiCatalog.siteByID[f.site]
        let deal = fabPowerDeal(f)
        var p = (site?.power ?? 0.08) * deal.priceMultiplier * (deal == .grid ? Power.gridMultiplier(s) : 1)
        if s.nations.ready, let r = site?.region { p *= clamp(1 - 0.1 * (s.nations.level(r, .energy) - 55) / 50, 0.88, 1.12) }   // 3.7: energy policy
        return p * max(0.5, 1 - s.traits.power) * XenoScience.powerFactor(s) * AgentOrgs.powerFactor(s) * Science.powerFactor(s) * AdvancedProjects.powerFactor(s)
    }

    /// Daily running cost of an open fab: staff and maintenance, consumables per wafer and power.
    static func fabOpexDay(_ f: SemiFab, _ s: GameState, wafersDay: Double) -> (fixed: Double, wafers: Double, power: Double) {
        let n = SemiCatalog.node(f.node)
        let power = fabMW(f, s) * 1_000 * 24 * fabPowerPrice(f, s)
        return (f.buildCost * 0.003 / 30.4, wafersDay * 0.22 * n.waferPrice, power)
    }

    /// What other chipmakers pay for a wafer from your fab, and how much spare capacity they'll take.
    static func foundryServicePrice(_ f: SemiFab, _ s: GameState) -> (price: Double, fill: Double) {
        let n = SemiCatalog.node(f.node)
        let market = waferPrice(n, SemiCatalog.foundryByID["fsw"]!, s.year)
        let age = s.year - launch(n, s)
        return (market * 0.6, 0.7 * clamp(1 - (age - 6) / 6, 0.2, 1))
    }

    // MARK: Production costs (planning)

    /// Packaging slots one chip takes: its die configuration, a bigger interposer for every HBM stack beyond four, and
    /// the interconnect's SerDes or optics.
    static func slotsPerChip(_ d: SemiDesign) -> Double {
        SemiCatalog.die(d.die).slots * (1 + 0.06 * Double(max(0, d.stacks - 4))) + link(d).slots
    }

    /// Share of packages that survive assembly: the packaging lines' yield, less for a crowded interposer (every stack
    /// beyond six is another chance to crack or misalign) and for optics on the package.
    static func assemblyYield(_ d: SemiDesign, _ s: GameState) -> Double {
        packYield(s) * (1 - 0.012 * Double(max(0, d.stacks - 6))) * link(d).yield
    }

    /// What one good chip costs to make today at a foundry, by input (per good chip, assembly losses included).
    static func unitCost(_ d: SemiDesign, foundry f: Foundry, _ s: GameState) -> (total: Double, wafer: Double, pack: Double, hbm: Double, test: Double) {
        let n = SemiCatalog.node(d.node)
        let die = SemiCatalog.die(d.die)
        let y = d.inProduction ? productYield(d, foundry: f, s) : previewYield(node: d.node, die: d.die, foundry: f, s)
        let packSup = SemiCatalog.supplierByID["fsw_pack"]!
        let assembly = max(0.5, packSup.yield * (1 - 0.012 * Double(max(0, d.stacks - 6))) * link(d).yield)
        let wafer = waferPrice(n, f, s.year) / max(0.01, y.diesPerWafer * y.good) * Double(die.dies) / assembly
        let pack = supplyPrice(packSup, s) * slotsPerChip(d) / assembly
        let hbm = supplyPrice(SemiCatalog.supplierByID["hanseong_mem"]!, s) * Double(d.stacks) / assembly
        let test = 150.0 * Double(die.dies)
        return (wafer + pack + hbm + test, wafer, pack, hbm, test)
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        guard s.semi.engaged else { return }
        teamsAndDesigns(&s)
        softwareDaily(&s)
        produce(&s)
        dieBank(&s)
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
                let ip = SemiCatalog.node(d.node).ipMonth * link(d).ipFactor / 30.4
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
        SemiCatalog.foundries.first { offered(n, $0, s) && foundryBlocker($0, n, s) == nil }
    }

    static func advance(_ s: inout GameState, _ i: Int) {
        let d = s.semi.designs[i]
        let p = plan(node: d.node, verification: d.verification, team: team(s, d.teamID), derived: isPort(d), link: link(d), s)
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
                s.semi.designs[i].waiting = "Ready to tape out; waiting for a foundry to open \(n.short) (first in \(Fmt.trim(launch(n, s), 1)))."
                s.semi.designs[i].phaseDaysLeft = 7
                return
            }
            let masks = n.maskCost * (isPort(d) ? 0.8 : 1)
            spend(&s, masks, capex: true)
            s.semi.month.designCost += masks
            s.semi.designs[i].spent += masks
            s.semi.designs[i].waiting = ""
            s.semi.designs[i].phaseRaw = SemiPhase.tapeout.rawValue
            s.semi.designs[i].phaseDays = n.fabDays
            s.semi.designs[i].phaseDaysLeft = n.fabDays
            s.semi.designs[i].arch = archQuality(generation: d.generation, team: team(s, d.teamID), port: parent(d, s), node: d.node, s).value
            s.semi.designs[i].tapeoutYear = s.year
            let sp = spec(s.semi.designs[i], s)
            note(&s, i, "Taped out at \(f.name): mask set \(Fmt.money(masks)). Architecture \(Fmt.trim(s.semi.designs[i].arch, 2)): \(Fmt.count(sp.bf16)) TFLOPS BF16 at \(Int(sp.tdpW)) W, \(Fmt.memory(sp.memoryGB)) \(hbmGeneration(s.year)). First wafers in about \(Int(n.fabDays / 30.4) + 1) months.", tone: 1)
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
        if d.arch <= 0 { d.arch = archQuality(generation: d.generation, team: team(s, d.teamID), port: parent(d, s), node: d.node, s).value }
        // 3.9: a new architecture is new work for the compiler (a port runs the code it already has).
        let newISA = !isPort(d) && s.semi.designs.contains { $0.id != d.id && $0.qualified != nil }
        if newISA && s.semi.software > 0.05 {
            s.semi.software *= 0.85
            log(&s, "\(d.name) is a new architecture: your compiler has to learn its new features (software maturity → \(Fmt.pct(s.semi.software, decimals: 0))).")
        }
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
        s.semi.softwareRegistered = s.semi.software
        note(&s, i, "Qualified for production: \(Fmt.count(ultra.bf16)) TFLOPS BF16, \(Fmt.trim(perf, 2))× \(ref.name) today (Ultra bin).", tone: 1)
        log(&s, "\(d.name) qualified: \(Fmt.count(ultra.bf16)) TFLOPS, \(Fmt.trim(perf, 2))× \(ref.name).", tone: 1)
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
        // Dies → packages: slots and HBM are shared across products in proportion to the dies waiting. Bigger
        // interposers (more HBM, optics) take more of each slot.
        let slots = packSlotsDay(s)
        var slotDemand = 0.0, hbmDemand = 0.0
        for d in s.semi.designs where d.inProduction {
            let die = SemiCatalog.die(d.die)
            for b in 0..<3 {
                let chips = d.dieBank[b] / Double(die.dies)
                slotDemand += chips * slotsPerChip(d)
                hbmDemand += chips * Double(stacksFor(bin: b, d))
            }
        }
        guard slotDemand > 0 else { return }
        let fSlots = min(1, slots / slotDemand)
        let fHBM = hbmDemand * fSlots > 0 ? min(1, s.semi.hbmStock / (hbmDemand * fSlots)) : 0
        let f = fSlots * fHBM
        if fSlots < 1 && fSlots <= fHBM { s.semi.month.packDays += 1 } else if fHBM < 1 { s.semi.month.hbmDays += 1 } else { s.semi.month.waferDays += 1 }
        guard f > 0 else { return }
        let slotPrice = averagePrice(s, kind: "pack"), stackPrice = averagePrice(s, kind: "hbm")
        var hbmUsed = 0.0
        for i in s.semi.designs.indices where s.semi.designs[i].inProduction {
            let d = s.semi.designs[i]
            let die = SemiCatalog.die(d.die)
            let py = assemblyYield(d, s)
            for b in 0..<3 {
                let chips = d.dieBank[b] / Double(die.dies) * f
                guard chips > 0 else { continue }
                s.semi.designs[i].dieBank[b] -= chips * Double(die.dies)
                hbmUsed += chips * Double(stacksFor(bin: b, d))
                s.semi.designs[i].cost += chips * (slotsPerChip(d) * slotPrice + Double(stacksFor(bin: b, d)) * stackPrice)
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

    // MARK: Die bank (3.8)

    /// Dies a day packaging actually takes for this product: last month's finished chips (this month's so far early on).
    static func diesPackedDay(_ d: SemiDesign, _ s: GameState) -> Double {
        let die = SemiCatalog.die(d.die)
        let py = max(0.5, assemblyYield(d, s))
        let last = d.lastMade.reduce(0, +) / 30.4
        let day = Double(max(1, GameCalendar.components(s.date).day))
        let now = d.monthMade.reduce(0, +) / day
        return max(last, now) * Double(die.dies) / py
    }

    /// 3.9: dies a day the packaging slots and HBM you've contracted can take for this product — contracts running or
    /// signed to start within two months — shared across your products by their wafer starts. It sizes the die bank, so
    /// dies made before packaging starts are kept for it rather than dumped.
    static func diesContractedDay(_ d: SemiDesign, _ s: GameState) -> Double {
        let horizon = GameCalendar.addDays(s.date, Int(dieBankTargetDays))
        let live = s.semi.supply.filter { $0.start <= horizon && ($0.own || $0.end > s.date) }
        let slots = live.filter { $0.kind == "pack" }.reduce(0) { $0 + $1.units } / 30.4
        let hbm = live.filter { $0.kind == "hbm" }.reduce(0) { $0 + $1.units * (SemiCatalog.supplierByID[$1.supplier]?.yield ?? 0.97) } / 30.4
        let chips = min(slots / max(0.1, slotsPerChip(d)), hbm / Double(max(1, d.stacks)))
        let products = s.semi.designs.filter(\.inProduction)
        let mine = sources(d, s).reduce(0) { $0 + $1.wafersDay }
        let all = products.reduce(0.0) { acc, p in acc + sources(p, s).reduce(0) { $0 + $1.wafersDay } }
        let share = all > 0 ? mine / all : 1 / Double(max(1, products.count))
        return chips * share * Double(SemiCatalog.die(d.die).dies)
    }

    /// Dies a day the bank is drawn down at: what packaging takes now, or what your contracts will take.
    static func dieUseDay(_ d: SemiDesign, _ s: GameState) -> Double { max(diesPackedDay(d, s), diesContractedDay(d, s)) }

    /// Days of packaging the die bank holds (infinite when nothing is being packaged or contracted).
    static func dieBankDays(_ d: SemiDesign, _ s: GameState) -> Double {
        let bank = d.dieBank.reduce(0, +)
        guard bank > 1 else { return 0 }
        let use = dieUseDay(d, s)
        return use > 0 ? bank / use : .infinity
    }

    /// Wafer cost of one good die (what a die in the bank cost to make).
    static func dieCost(_ d: SemiDesign, _ s: GameState) -> Double {
        let f = SemiCatalog.foundryByID["fsw"]!
        let n = SemiCatalog.node(d.node)
        let y = d.inProduction ? productYield(d, foundry: f, s) : previewYield(node: d.node, die: d.die, foundry: f, s)
        return waferPrice(n, f, s.year) / max(0.01, y.diesPerWafer * y.good)
    }

    /// A newer generation of yours is in production (old dies are worth less: nobody wants last year's part).
    static func superseded(_ d: SemiDesign, _ s: GameState) -> Bool {
        d.phase == .retired || s.semi.designs.contains { $0.inProduction && $0.generation > d.generation && $0.focus == d.focus }
    }

    /// Share of the die bank lost a month: 1% ages out; a generation behind 5%; a retired product 10%.
    static func dieLossMonthly(_ d: SemiDesign, _ s: GameState) -> Double {
        d.phase == .retired ? 0.10 : (superseded(d, s) ? 0.05 : 0.01)
    }

    /// Holding cost a month as a share of the bank's wafer cost (storage, retest, the capital tied up).
    static let dieCarryMonthly = 0.015
    /// Dies beyond this many days of packaging are surplus.
    static let dieBankTargetDays = 60.0

    /// Dies the bank should hold: two months of what packaging takes or your contracts will take.
    static func dieBankTarget(_ d: SemiDesign, _ s: GameState) -> Double { dieBankTargetDays * dieUseDay(d, s) }

    /// What other packagers pay per known-good die: well under its wafer cost (they take the packaging risk and the
    /// die is a part they never designed for) — about what the wafer would have earned as foundry service — and less
    /// once a newer generation is out.
    static func kgdPrice(_ d: SemiDesign, _ s: GameState) -> Double { dieCost(d, s) * (superseded(d, s) ? 0.25 : 0.4) }

    /// What the die bank is worth at known-good-die prices.
    static func dieBankValue(_ d: SemiDesign, _ s: GameState) -> Double { d.dieBank.reduce(0, +) * kgdPrice(d, s) }

    /// Daily: dies in the bank age (a generation behind they go faster), cost money to hold, and — unless you hold
    /// them — the surplus beyond two months of packaging (made or contracted) is sold to other packagers as known-good die.
    static func dieBank(_ s: inout GameState) {
        for i in s.semi.designs.indices {
            let d = s.semi.designs[i]
            let bank = d.dieBank.reduce(0, +)
            guard bank > 1, d.inProduction || d.phase == .retired else { continue }
            let cost = dieCost(d, s)
            let carry = bank * cost * dieCarryMonthly / 30.4
            spend(&s, carry, chips: true)
            s.semi.month.dieCarry += carry
            s.semi.designs[i].cost += carry
            let lost = bank * dieLossMonthly(d, s) / 30.4
            var sold = 0.0
            if !s.semi.holdExcessDies {
                let surplus = d.phase == .retired ? bank : bank - dieBankTarget(d, s)
                if surplus > 0 { sold = min(bank - lost, surplus * 0.5 / 30.4) }
            }
            let out = min(bank, lost + sold)
            let keep = bank > 0 ? 1 - out / bank : 1
            for b in 0..<3 { s.semi.designs[i].dieBank[b] *= keep }
            s.semi.designs[i].diesScrapped += lost
            s.semi.month.diesScrapped += lost
            guard sold > 0 else { continue }
            let rev = sold * kgdPrice(d, s)
            s.cash += rev
            s.month.revChips += rev
            s.lifetimeRevenue += rev
            s.semi.month.revenue += rev
            s.semi.month.kgdRevenue += rev
            s.semi.month.kgdDies += sold
            s.semi.designs[i].kgdSold += sold
            s.semi.designs[i].revenue += rev
        }
    }

    /// The share of a fab's wafers its product can use when packaging is the bottleneck: enough dies, with the
    /// bookings', to keep packaging busy (plus 10%). Nil when there's nothing to change.
    static func suggestedFabShare(_ fab: SemiFab, _ s: GameState) -> Double? {
        guard fab.open(s.date), let id = fab.designID, let d = s.semi.designs.first(where: { $0.id == id && $0.inProduction && $0.node == fab.node }) else { return nil }
        let use = dieUseDay(d, s)
        guard use > 0, dieBankDays(d, s) > 45 else { return nil }
        var booked = 0.0
        for src in sources(d, s) where src.price > 0 { booked += src.wafersDay * src.yield.diesPerWafer * src.yield.good }
        let y = fabYield(d, fab: fab, s)
        let full = fab.wafersMonth * fabRamp(fab, s) / 30.4 * ownFabFactor(s, fab) * y.diesPerWafer * y.good
        guard full > 0 else { return nil }
        let share = (clamp((use * 1.1 - booked) / full, 0, 1) * 20).rounded(.down) / 20
        return share < fab.productShare - 0.049 ? share : nil
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

    /// Your standing as a chip supplier: buyers trust vendors whose chips have shipped at volume — and whose software
    /// stack is mature enough to port their models to (3.9).
    static func reputation(_ s: GameState) -> Double {
        let shipped = s.semi.shipped + ChipBusiness.shippedTotal(s)
        return clamp(0.05 + 0.15 * log10(1 + shipped / 50_000) + 0.2 * s.semi.software - s.semi.repHit, 0.03, 1)
    }

    /// One of your SKUs buyers can order: a design's bin on sale at a price.
    struct Offer {
        var index: Int
        var bin: Int
        var chip: Accelerator
        var price: Double
        var value: Double
    }

    /// Everything on sale today (optionally with one bin's price replaced, for "what if" forecasts).
    static func offers(_ s: GameState, override: (id: UUID, bin: Int, price: Double)? = nil) -> [Offer] {
        var out: [Offer] = []
        for i in s.semi.designs.indices where s.semi.designs[i].inProduction {
            let d = s.semi.designs[i]
            for b in 0..<3 where d.chipIDs.indices.contains(b) {
                let forced = override.map { $0.id == d.id && $0.bin == b } ?? false
                guard d.onSale[b] || forced, let chip = HardwareCatalog.get(d.chipIDs[b]) else { continue }
                let price = forced ? override!.price : d.prices[b]
                guard price > 0 else { continue }
                out.append(Offer(index: i, bin: b, chip: chip, price: price, value: ChipBusiness.valueRatio(chip: chip, price: price, s)))
            }
        }
        return out
    }

    struct Demand {
        /// Your share of the market's accelerator spending, as one vendor.
        var share: Double
        var spendDay: Double
        var rep: Double
        /// Best value per dollar against a GPU, with the line-up's breadth.
        var value: Double
        /// Each offer's share of what buyers spend with you.
        var split: [Double]
        var why: String
    }

    /// 3.9: the market treats you as one vendor. Your best value per dollar (a little more for a broader line-up) and
    /// your reputation set the share of the year's accelerator spending you win; buyers then split it across your SKUs
    /// by value per dollar. Adding SKUs never adds a whole extra market share.
    static func vendorDemand(_ s: GameState, offers: [Offer]) -> Demand {
        let spendDay = ChipBusiness.acceleratorSpend(s.year) * clamp(s.market.hype / 1.3, 0.6, 1.6) / 365
        let rep = reputation(s)
        guard let best = offers.map(\.value).max(), best > 0 else { return Demand(share: 0, spendDay: spendDay, rep: rep, value: 0, split: [], why: "") }
        let v = best * (1 + 0.08 * Double(min(3, offers.count - 1)))
        let share = ChipBusiness.marketShare(value: v, reputation: rep)
        let w = offers.map { pow(max(0.01, $0.value), 3) }
        let total = w.reduce(0, +)
        return Demand(share: share, spendDay: spendDay, rep: rep, value: v, split: w.map { $0 / max(1e-12, total) },
                      why: "\(Fmt.money(spendDay * 365)) a year of accelerator spending × \(Fmt.pct(share, decimals: 2)) share for you as a vendor (best value \(Fmt.trim(best, 2))× a GPU per dollar\(offers.count > 1 ? " with \(offers.count) SKUs" : ""), supplier reputation \(Fmt.pct(rep, decimals: 0)))")
    }

    /// Chips a day the market would take of one bin at `price` (before export rules and who you sell to), with the
    /// rest of your line-up at its current prices.
    static func demand(_ id: UUID, bin b: Int, price: Double, _ s: GameState) -> (perDay: Double, why: String) {
        let list = offers(s, override: (id, b, price))
        let v = vendorDemand(s, offers: list)
        guard let k = list.firstIndex(where: { s.semi.designs[$0.index].id == id && $0.bin == b }) else { return (0, v.why) }
        let mult = max(0.3, 1 + s.traits.chipSales)
        return (v.spendDay * v.share * v.split[k] / max(price, 1) * mult,
                v.why + ", \(Fmt.pct(v.split[k], decimals: 0)) of it on this part ÷ \(Fmt.money(price))")
    }

    struct Buyer {
        var id: String
        var name: String
        var weight: Double
        var rival: Bool
        var blocked: String?
    }

    /// You promised a customer exclusive supply: no chips to rival labs until then.
    static func exclusiveUntil(_ s: GameState) -> Date? { s.exclusiveSupplyUntil.flatMap { $0 > s.date ? $0 : nil } }

    static func rivalAlive(_ c: CompetitorState, _ s: GameState) -> Bool {
        !c.acquired && !c.bankrupt && c.exitNote.isEmpty && s.year >= c.def.founded.decimal
    }

    /// What a rival lab will spend on your chips in a day: a sliver of its cash.
    static func rivalBudgetDay(_ s: GameState, _ id: String) -> Double {
        guard let c = s.competitors.first(where: { $0.id == id }), rivalAlive(c, s) else { return 0 }
        return max(0, c.cash) * 0.004
    }

    /// Who buys and in what shares: clouds, sovereigns and enterprises take three quarters of demand, rival labs a quarter
    /// (by compute) if you let them. Export rules, an exclusive-supply promise and your own policy block some.
    static func buyers(_ s: GameState) -> [Buyer] {
        let rules = exportRules(s)
        let exclusive = exclusiveUntil(s)
        let total = SemiCatalog.customers.reduce(0) { $0 + $1.weight }
        var out: [Buyer] = SemiCatalog.customers.map { c in
            var blocked: String? = nil
            if c.region == .china && rules.china { blocked = "export controls" }
            if c.kind == "sovereign" && !s.semi.allowSovereigns { blocked = "you don't sell to sovereigns" }
            let sovereign = c.kind == "sovereign" ? Nations.agencyFactor(s, c.region) : 1   // 3.7: sovereign-AI programmes
            let w = c.weight / total * 0.75 * (c.region == .gulf && rules.gulfHalf ? 0.5 : 1) * sovereign
            return Buyer(id: c.id, name: c.name, weight: w, rival: false, blocked: blocked)
        }
        let rivals = s.competitors.filter { rivalAlive($0, s) }
        let rtotal = rivals.reduce(0) { $0 + $1.def.computeShare }
        for r in rivals where rtotal > 0 {
            var blocked: String? = nil
            if !s.semi.allowRivals { blocked = "you don't sell to rivals" }
            if let until = exclusive { blocked = "exclusive supply promised until \(until.gameShort)" }
            if AdvancedProjects.labRegion(r.id) == .china && rules.china { blocked = "export controls" }
            out.append(Buyer(id: r.id, name: r.def.name, weight: 0.25 * r.def.computeShare / rtotal, rival: true, blocked: blocked))
        }
        return out
    }

    static func sell(_ s: inout GameState) {
        // Orders first, for every product with stock — a retired product still delivers what it promised.
        for i in s.semi.designs.indices where s.semi.designs[i].inProduction || s.semi.designs[i].phase == .retired {
            deliverOrders(&s, i)
        }
        let open = buyers(s).filter { $0.blocked == nil }
        let openW = open.reduce(0) { $0 + $1.weight }
        let list = offers(s)
        guard openW > 0, !list.isEmpty else { return }
        let v = vendorDemand(s, offers: list)
        let mult = max(0.3, 1 + s.traits.chipSales)
        let h100 = HardwareCatalog.h100.bf16
        for (k, o) in list.enumerated() {
            let want = v.spendDay * v.share * v.split[k] / max(o.price, 1) * mult * openW
            let units = min(want, s.semi.designs[o.index].stockSale[o.bin])
            guard units > 0 else { continue }
            var sold = 0.0
            for buyer in open {
                var u = units * buyer.weight / openW
                // A rival only buys what its cash can carry.
                if buyer.rival { u = min(u, rivalBudgetDay(s, buyer.id) / o.price) }
                guard u > 0 else { continue }
                record(&s, o.index, o.bin, units: u, price: o.price, buyer: buyer.id, h100e: u * o.chip.bf16 / h100)
                sold += u
            }
            // Only what was sold leaves stock.
            s.semi.designs[o.index].stockSale[o.bin] = max(0, s.semi.designs[o.index].stockSale[o.bin] - sold)
        }
    }

    /// Ship accepted orders for one product from customer stock. A rival that can no longer pay (or no longer exists)
    /// defaults: the order is cancelled without a penalty.
    static func deliverOrders(_ s: inout GameState, _ i: Int) {
        let d = s.semi.designs[i]
        let h100 = HardwareCatalog.h100.bf16
        for ci in s.semi.contracts.indices where !s.semi.contracts[ci].closed && s.semi.contracts[ci].designID == d.id {
            let c = s.semi.contracts[ci]
            let b = c.bin
            guard (0..<3).contains(b), d.chipIDs.indices.contains(b) else { continue }
            var n = min(c.remaining, s.semi.designs[i].stockSale[b])
            if let r = s.competitors.first(where: { $0.id == c.customer }) {
                let canPay = rivalAlive(r, s) ? max(0, r.cash) / max(1, c.price) : 0
                if canPay < 1 {
                    s.semi.contracts[ci].closed = true
                    log(&s, "\(r.def.name) can't pay for the rest of its order (\(Fmt.count(c.remaining)) chips): cancelled, no penalty.", tone: -1)
                    continue
                }
                n = min(n, canPay)
            }
            guard n > 0 else { continue }
            s.semi.designs[i].stockSale[b] -= n
            s.semi.contracts[ci].delivered += n
            let bf16 = HardwareCatalog.get(d.chipIDs[b])?.bf16 ?? 0
            record(&s, i, b, units: n, price: c.price, buyer: c.customer, h100e: n * bf16 / h100)
        }
    }

    /// Book a sale: cash, revenue, the buyer's tally — a rival lab pays from its own cash, and its fleet grows with
    /// your chips.
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
            s.competitors[ci].cash -= rev
            s.competitors[ci].armedH100e += h100e
            s.semi.month.toRivals += units
            s.semi.month.rivalRevenue += rev
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
