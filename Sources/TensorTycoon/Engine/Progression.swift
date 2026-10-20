import Foundation

// MARK: - 3.7: company stages

/// Garage → Startup → Scale-up → Frontier Lab → Hyperscaler → Civilisational. Each stage has four explicit criteria —
/// capability (your lab's rank), revenue and compute (as shares of the AI market and of the industry's compute, so they
/// mean the same in 2017 and 2030) and headcount — and unlocks one power inside a system the game already has, plus
/// (3.8) decisions you couldn't take before: term loans and subsidiaries, classified work, regional entities and chip
/// teams, your own fabs, science institutes and big AI organisations, the last moonshots. Each gated action says which
/// stage it needs. A promotion is a moment: a news story and a ceremony card, never a popup. Stages never go down. Older
/// saves get the stage their record earns, credited silently on load, and keep every gated feature they already used.
enum Progression {
    struct Criterion: Identifiable, Hashable {
        let id: String
        let label: String
        let have: String
        let need: String
        /// 0…1 toward the bar.
        let progress: Double
        var met: Bool { progress >= 1 }
    }

    struct Power: Hashable {
        let title: String
        let text: String
        let symbol: String
        let screen: Screen
    }

    struct Bar {
        /// Leaderboard rank of your best released model (99 = any released model).
        let rank: Int
        /// Revenue run-rate as a share of the AI market's annual revenue.
        let revenue: Double
        /// H100-equivalents as a share of the industry's compute.
        let compute: Double
        let headcount: Int
    }

    static func bar(_ st: CompanyStage) -> Bar? {
        switch st {
        case .garage: nil
        case .startup: Bar(rank: 99, revenue: 0.0001, compute: 0.0001, headcount: 5)
        case .scaleUp: Bar(rank: 10, revenue: 0.002, compute: 0.001, headcount: 20)
        case .frontierLab: Bar(rank: 3, revenue: 0.01, compute: 0.004, headcount: 60)
        case .hyperscaler: Bar(rank: 2, revenue: 0.03, compute: 0.01, headcount: 120)
        case .civilisational: Bar(rank: 1, revenue: 0.06, compute: 0.025, headcount: 220)
        }
    }

    /// The power each stage unlocks.
    static func power(_ st: CompanyStage) -> Power? {
        switch st {
        case .garage: nil
        case .startup: Power(title: "Enterprise sales desk", text: "Enterprise-first launches, and enterprise leads 15% more likely.", symbol: "briefcase.fill", screen: .market)
        case .scaleUp: Power(title: "Policy office", text: "Political capital builds 30% faster from your lobbying budget and fades more slowly.", symbol: "building.columns.fill", screen: .security)
        case .frontierLab: Power(title: "Sovereign desk", text: "Government-first launches, and sovereign AI deals offered 40% more often.", symbol: "globe.europe.africa.fill", screen: .world)
        case .hyperscaler: Power(title: "Own-fab discount", text: "Your own fabs cost 15% less to build: suppliers and governments line up for your volume.", symbol: "circle.grid.cross.fill", screen: .semiconductors)
        case .civilisational: Power(title: "Fusion first", text: "Fusion plants become available to you three years before everyone else.", symbol: "sun.max.fill", screen: .datacenters)
        }
    }

    static func has(_ s: GameState, _ st: CompanyStage) -> Bool { s.progression.stage >= st.rawValue }

    // MARK: Unlocks (3.8): decisions each stage opens

    /// Things you can't do until a stage: each gated action checks `blocker` and says which stage it needs.
    enum Feature: String, CaseIterable, Sendable {
        case termLoans, classified, regional, chipTeams, fabs, institutes, bigOrgs, lateMoonshots

        var stage: CompanyStage {
            switch self {
            case .termLoans: .scaleUp
            case .classified, .regional, .chipTeams: .frontierLab
            case .fabs, .institutes, .bigOrgs: .hyperscaler
            case .lateMoonshots: .civilisational
            }
        }

        var title: String {
            switch self {
            case .termLoans: "Covenanted term loans"
            case .classified: "Security clearances"
            case .regional: "Regional entities"
            case .chipTeams: "Chip design teams"
            case .fabs: "Fabs of your own"
            case .institutes: "Science institutes"
            case .bigOrgs: "AI organisations at scale"
            case .lateMoonshots: "The last moonshots"
            }
        }

        var text: String {
            switch self {
            case .termLoans: "Banks lend against your earnings: up to 3× EBITDA on a five-year term loan, cheaper than venture debt."
            case .classified: "Clear your staff, build secure facilities and bid on Controlled, Secret and Top Secret government work."
            case .regional: "Set up entities abroad that sell your models under local management and pay you a licence fee."
            case .chipTeams: "Hire teams of chip architects and design accelerators of your own."
            case .fabs: "Build fabs instead of booking foundry wafers."
            case .institutes: "Run a third science lab and beyond: a research institute across fields."
            case .bigOrgs: "AI organisations of more than \(Fmt.int(Progression.orgAgentCap)) agents."
            case .lateMoonshots: "Backers bring you the last grand challenges: a formally verified internet core, whole-cell simulation, reversing cellular aging."
            }
        }

        /// Completes "Reach <stage> to …".
        var verb: String {
            switch self {
            case .termLoans: "borrow on a covenanted term loan"
            case .classified: "clear staff and take on classified government work"
            case .regional: "set up a regional entity abroad"
            case .chipTeams: "hire a chip design team"
            case .fabs: "build a fab of your own"
            case .institutes: "run more than two science labs"
            case .bigOrgs: "run an AI organisation of more than \(Fmt.int(Progression.orgAgentCap)) agents"
            case .lateMoonshots: "be offered the last moonshots"
            }
        }

        var symbol: String {
            switch self {
            case .termLoans: "building.columns.fill"
            case .classified: "lock.shield.fill"
            case .regional: "globe.europe.africa.fill"
            case .chipTeams: "memorychip.fill"
            case .fabs: "circle.grid.cross.fill"
            case .institutes: "flask.fill"
            case .bigOrgs: "person.3.sequence.fill"
            case .lateMoonshots: "moon.stars.fill"
            }
        }

        var screen: Screen {
            switch self {
            case .termLoans, .regional: .corporate
            case .classified: .advancedProjects
            case .chipTeams, .fabs: .semiconductors
            case .institutes: .science
            case .bigOrgs: .swarms
            case .lateMoonshots: .research
            }
        }
    }

    /// Agents an AI organisation may have before the Hyperscaler stage.
    static let orgAgentCap = 1_000
    /// Moonshots first offered from this year are the very-late ones (Civilisational).
    static let lateMoonshotYear = 2031.5

    static func features(_ st: CompanyStage) -> [Feature] { Feature.allCases.filter { $0.stage == st } }

    /// Open at your stage, or already in use when stages started gating it (an older save keeps what it built).
    static func allows(_ s: GameState, _ f: Feature) -> Bool {
        has(s, f.stage) || s.progression.grandfathered.contains(f.rawValue)
    }

    /// Why a gated action isn't open yet (nil when it is).
    static func blocker(_ s: GameState, _ f: Feature) -> String? {
        allows(s, f) ? nil : "Reach \(f.stage.title) to \(f.verb)."
    }

    /// Subsidiaries you may run at once at each stage.
    static func slots(_ st: CompanyStage) -> Int {
        switch st {
        case .garage, .startup: 0
        case .scaleUp: 2
        case .frontierLab: 4
        case .hyperscaler: 8
        case .civilisational: 12
        }
    }

    /// Subsidiaries you may run at once: your stage's slots, or as many as an older save already ran.
    static func subsidiarySlots(_ s: GameState) -> Int { max(slots(s.progression.current), s.progression.grandfatheredSlots) }

    /// Agents across one AI organisation's teams.
    static func orgAgents(_ s: GameState, _ orgID: UUID) -> Int { s.swarms.filter { $0.orgID == orgID }.reduce(0) { $0 + $1.agents } }

    static func isLateMoonshot(_ id: String) -> Bool { (MoonshotCatalog.byID[id]?.year ?? 0) >= lateMoonshotYear }

    /// Once per save: the gated features it already uses stay open (and the subsidiaries it already runs).
    static func grandfather(_ s: inout GameState) {
        guard !s.progression.gatesChecked else { return }
        s.progression.gatesChecked = true
        var g = Set<String>()
        if s.corp.debts.contains(where: { $0.kind == .termLoan }) { g.insert(Feature.termLoans.rawValue) }
        if !s.advanced.clearances.isEmpty || !s.advanced.facilities.isEmpty || s.advanced.programmes.contains(where: { $0.sol.level > .unclassified }) {
            g.insert(Feature.classified.rawValue)
        }
        if s.corp.subs.contains(where: { $0.live && $0.kind == .regional }) { g.insert(Feature.regional.rawValue) }
        if !s.semi.teams.isEmpty || !s.semi.designs.isEmpty { g.insert(Feature.chipTeams.rawValue) }
        if !s.semi.fabs.isEmpty { g.insert(Feature.fabs.rawValue) }
        if s.science.labs.count > 2 { g.insert(Feature.institutes.rawValue) }
        if s.orgs.contains(where: { orgAgents(s, $0.id) > orgAgentCap }) { g.insert(Feature.bigOrgs.rawValue) }
        if s.moonshots.contains(where: { isLateMoonshot($0.id) }) { g.insert(Feature.lateMoonshots.rawValue) }
        s.progression.grandfathered = g
        s.progression.grandfatheredSlots = s.corp.subs.filter(\.live).count
    }

    // MARK: Hooks into existing systems (exactly 1 below the stage)

    /// Policy: political capital gained from lobbying.
    static func lobbyFactor(_ s: GameState) -> Double { has(s, .scaleUp) ? 1.3 : 1 }
    /// Policy: monthly retention of political capital.
    static func capitalRetention(_ s: GameState) -> Double { has(s, .scaleUp) ? 0.96 : 0.95 }
    /// Semiconductors: fab construction cost.
    static func fabFactor(_ s: GameState) -> Double { has(s, .hyperscaler) ? 0.85 : 1 }
    /// Power: years fusion arrives early.
    static func fusionPullIn(_ s: GameState) -> Double { has(s, .civilisational) ? 3 : 0 }

    // MARK: Measuring

    /// Your lab's rank by its best released model (nil before anything ships).
    static func playerRank(_ s: GameState) -> Int? {
        let all = Leaderboard.entries(s, includeUnreleased: false)
        guard let best = all.filter({ $0.isPlayer && $0.released }).map(\.index).max() else { return nil }
        return Leaderboard.labRank(index: best, board: all, gone: Leaderboard.goneLabs(s))
    }

    static func criteria(_ s: GameState, for st: CompanyStage, rank: Int?) -> [Criterion] {
        guard let b = bar(st) else { return [] }
        let y = s.year
        let market = Macro.marketSize(y)
        let industry = CompetitorCatalog.industryCompute(y)
        let rev = Economy.runRate(s)
        let compute = Economy.h100e(s)
        let staff = s.employees.count
        var out: [Criterion] = []
        if b.rank >= 99 {
            out.append(Criterion(id: "cap", label: "Capability", have: rank.map { "#\($0) lab" } ?? "Nothing released",
                                 need: "Release a model", progress: rank == nil ? 0 : 1))
        } else {
            let p: Double = rank.map { $0 <= b.rank ? 1 : clamp(Double(b.rank) / Double($0), 0, 0.99) } ?? 0
            out.append(Criterion(id: "cap", label: "Capability", have: rank.map { "#\($0) lab" } ?? "Nothing released",
                                 need: b.rank == 1 ? "#1 lab" : "Top \(b.rank) lab", progress: p))
        }
        let needRev = market * b.revenue
        out.append(Criterion(id: "rev", label: "Revenue", have: "\(Fmt.money(rev))/yr",
                             need: "\(Fmt.money(needRev))/yr (\(share(b.revenue)) of the AI market)", progress: clamp(rev / max(1, needRev), 0, 1)))
        let needCompute = industry * b.compute
        out.append(Criterion(id: "compute", label: "Compute", have: "\(Fmt.count(compute)) H100e",
                             need: "\(Fmt.count(needCompute)) H100e (\(share(b.compute)) of the industry)", progress: clamp(compute / max(1e-6, needCompute), 0, 1)))
        out.append(Criterion(id: "staff", label: "Headcount", have: "\(Fmt.int(staff))", need: "\(Fmt.int(b.headcount)) people",
                             progress: clamp(Double(staff) / Double(b.headcount), 0, 1)))
        return out
    }

    static func share(_ v: Double) -> String { Fmt.pct(v, decimals: v < 0.0001 ? 3 : (v < 0.001 ? 2 : (v < 0.01 ? 1 : 0))) }

    static func qualifies(_ s: GameState, for st: CompanyStage, rank: Int?) -> Bool {
        criteria(s, for: st, rank: rank).allSatisfy(\.met)
    }

    // MARK: Promotions

    /// The stage your record earns today, without ceremony (new games and older saves).
    static func bootstrap(_ s: inout GameState) {
        grandfather(&s)   // 3.8: once per save, before any gate is checked
        guard !s.progression.ready else { return }
        s.progression.ready = true
        let rank = playerRank(s)
        var st = CompanyStage.garage
        while let n = st.next, qualifies(s, for: n, rank: rank) { st = n }
        s.progression.stage = st.rawValue
        s.progression.rank = rank ?? 0
        if st.rawValue >= 1 {
            for v in 1...st.rawValue {
                s.progression.reached[v] = s.date
                s.progression.credited.insert(v)
            }
        }
    }

    /// Weekly: promote one stage when every criterion of the next is met.
    static func weekly(_ s: inout GameState) {
        guard s.progression.ready else { bootstrap(&s); return }
        let rank = playerRank(s)
        s.progression.rank = rank ?? 0
        guard let next = s.progression.current.next else { return }
        guard qualifies(s, for: next, rank: rank) else { return }
        promote(&s, to: next)
    }

    static func promote(_ s: inout GameState, to st: CompanyStage) {
        s.progression.stage = st.rawValue
        s.progression.reached[st.rawValue] = s.date
        s.progression.lastPromotion = s.date
        s.brand = min(100, s.brand + 2)
        Stakeholders.move(&s, ["investors": 3], "\(s.companyName) became a \(st.title.lowercased())")
        let p = power(st)
        let opened = features(st).map(\.title) + (slots(st) > slots(CompanyStage(rawValue: st.rawValue - 1) ?? .garage) ? ["\(slots(st)) subsidiaries"] : [])
        let body = "\(st.blurb) Brand +2, board confidence +3."
            + (p.map { " New power — \($0.title): \($0.text)" } ?? "")
            + (opened.isEmpty ? "" : " Now open: \(opened.joined(separator: ", ")).")
            + (st.next.map { " Next: \($0.title)." } ?? " There is no stage beyond this one.")
        Sim.news(&s, "\(s.companyName) is now a \(st.title)", body, .company, image: "sf_skyline", important: true, good: true)
    }

    /// True for 30 days after a promotion (the ceremony card).
    static func celebrating(_ s: GameState) -> Bool {
        guard let d = s.progression.lastPromotion else { return false }
        return GameCalendar.daysBetween(d, s.date) <= 30
    }
}
