import Foundation

// MARK: - 3.6: science labs
//
// Laboratories you build and staff run research projects through ten real stages (hypothesis → … → commercialisation).
// Each stage has odds driven by the lab's staff skill and equipment, your models' relevant domains, the agents and
// compute you assign, and what the field already knows. Stages fail: most failures are reruns (time and money), some
// are dead ends — a hypothesis falsified, a result that won't reproduce, a material that can't be made at scale.
//
// A project that survives reproduction is a discovery. Each discovery gets a report (significance, commercial
// consequences, impact on your other projects, competitors' likely response) and a follow-up decision in the inbox
// (patent and license, keep it secret, publish it at a conference, spin it out into a product line, feed it to a
// moonshot). Its effects reach the rest of the game through small hooks (see "Effects" below) and grow as the project
// goes on through prototype, validation, manufacturing and commercialisation.
//
// Randomness: every roll is hashed (RivalIntel.unit on "sci|<peopleSalt>|…" keys: the project's ID, the stage and the
// attempt number; rival labs on their ID and the month), so science never draws from the game's random numbers and a
// game without labs is exactly the game it was before. Everything here is neutral when you have no labs: no costs, no
// news, no effects.

/// A laboratory you've built.
struct SciLab: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var kind: LabKind
    /// Lab site (ScienceCatalog.sites / an HQ city).
    var site: String
    var built: Date
    var ready: Date
    /// Equipment level 1–5: better odds on bench stages, more capacity at 3 and 5.
    var equipment: Int = 1
    /// An equipment upgrade under way, and when it's done.
    @D var upgradeReady: Date? = nil
    /// Scientists and their average skill (40–95).
    var staff: Int = 0
    var skill: Double = 55
    /// Paid to build and equip it.
    var capex: Double = 0
    /// A short name ("Odense Robotics Lab").
    var name: String = ""

    var def: LabDef { ScienceCatalog.lab(kind) }
    func isReady(_ d: Date) -> Bool { d >= ready }
}

enum SciProjectStatus: String, Codable, Sendable {
    case running, done, failed, stalled, cancelled

    var label: String {
        switch self {
        case .running: "Running"
        case .done: "Commercialised"
        case .failed: "Dead end"
        case .stalled: "Stopped after discovery"
        case .cancelled: "Cancelled"
        }
    }
}

/// One attempt at one stage, for the timeline.
struct SciStageLog: Codable, Hashable {
    var stage: Int
    var date: Date
    var odds: Double
    /// "passed", "rerun" or "dead end".
    var outcome: String
    var days: Int
    var cost: Double
}

struct SciProject: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var def: String
    var lab: UUID
    var started: Date
    var stage: Int = 0
    /// Days of work done on the current stage.
    var progress: Double = 0
    /// Attempts at the current stage so far (0 = first attempt running).
    var attempts: Int = 0
    /// AI agents working on it, and its compute tier (0–3).
    var agents: Int = 0
    var compute: Int = 0
    var status: SciProjectStatus = .running
    var log: [SciStageLog] = []
    var discovery: UUID? = nil
    var spent: Double = 0
    /// The rival lab that published the same result first ("" = nobody).
    var scooped: String = ""
    var ended: Date? = nil
    /// Day the current attempt started.
    var stageStarted: Date

    var projectDef: SciProjectDef? { ScienceCatalog.projectByID[def] }
    var currentStage: SciStage { SciStage(rawValue: min(stage, SciStage.allCases.count - 1)) ?? .hypothesis }
}

/// The follow-up chosen for a discovery.
enum SciChoice: String, Codable, CaseIterable, Sendable {
    case patent, secret, publish, spinout, moonshot

    var label: String {
        switch self {
        case .patent: "Patent and license it"
        case .secret: "Keep it secret"
        case .publish: "Publish at a conference"
        case .spinout: "Spin it out"
        case .moonshot: "Feed it to a moonshot"
        }
    }

    var symbol: String {
        switch self {
        case .patent: "doc.badge.gearshape"
        case .secret: "lock.fill"
        case .publish: "megaphone.fill"
        case .spinout: "arrow.up.forward.app.fill"
        case .moonshot: "moon.stars.fill"
        }
    }
}

/// The discovery report: written once, when the result reproduces.
struct SciReport: Codable, Hashable {
    var significance: String = ""
    var commercial: String = ""
    var impact: String = ""
    var competitors: String = ""
}

struct SciDiscovery: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var def: String
    var project: UUID
    var date: Date
    var title: String
    /// How far the project took it: 0.35 at discovery, 1 when commercialised (see Science.levels).
    var level: Double = 0.35
    var commercialised: Date? = nil
    /// The project died at or after the prototype: lab-scale only.
    var labScaleOnly = false
    var choice: String = ""
    var choiceDate: Date? = nil
    /// The moonshot it fed.
    var moonshot: String = ""
    /// A rival lab published it first (worth less, can't be kept secret for long).
    var scooped: String = ""
    /// When rivals catch up with a secret, or design around a patent; and who.
    var rivalDate: Date? = nil
    var rivalLab: String = ""
    var rivalCaughtUp = false
    var report = SciReport()
    var decision: UUID? = nil

    var projectDef: SciProjectDef? { ScienceCatalog.projectByID[def] }
    var sciChoice: SciChoice? { SciChoice(rawValue: choice) }
}

struct SciPatent: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var discovery: UUID
    var title: String
    var field: SciField
    var filed: Date
    var expires: Date
    var licensees: Int
    var lastMonth: Double = 0
    var lifetime: Double = 0
    var designedAround = false
}

/// A result a rival lab's science arm announced.
struct RivalSciResult: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var lab: String
    var def: String
    var date: Date
    /// It beat one of your running projects to the result.
    var scoopedYou = false
    /// It reproduced a result you published.
    @D var reproduced: Bool = false
}

/// A unique AI breakthrough your research lab finished (ResearchLab), with a report like a lab discovery's and a
/// follow-up: publish it, keep it, or license it.
struct SciBreakthrough: Codable, Identifiable, Hashable {
    var id = StableID.next()
    /// The research item.
    var tech: String
    var title: String
    var date: Date
    var report = SciReport()
    /// "publish", "keep" or "license" ("" = undecided). Under an open-science policy it's published on completion.
    var choice: String = ""
    var choiceDate: Date? = nil
    var decision: UUID? = nil
    /// Who licensed it, and for how much up front.
    var licensee: String = ""
    var upfront: Double = 0
}

/// Everything the science labs remember (one field on GameState, so older saves load with it empty).
struct ScienceState: Codable, Hashable, DefaultValue {
    static var defaultValue: ScienceState { ScienceState() }

    @D var labs: [SciLab] = []
    @D var projects: [SciProject] = []
    @D var discoveries: [SciDiscovery] = []
    @D var patents: [SciPatent] = []
    @D var rivals: [RivalSciResult] = []
    /// Field → odds bonus from what's been learned lately (yours and rivals' results), decaying monthly.
    @D var momentum: [String: Double] = [:]
    /// Running totals, for the Science page and the harness.
    @D var spentBuild: Double = 0
    @D var spentRun: Double = 0
    @D var licensing: Double = 0
    @D var spinoutCash: Double = 0
    /// This month's and last month's running cost and licensing income.
    @D var costMonth: Double = 0
    @D var lastCost: Double = 0
    @D var incomeMonth: Double = 0
    @D var lastIncome: Double = 0
    /// Discoveries waiting for an open conference to submit to.
    @D var toPublish: [String] = []
    /// Field → how much more often rival science arms publish there (what you published openly), decaying monthly.
    @D var rivalMomentum: [String: Double] = [:]
    /// Rival reproductions of results you published, each due on its date.
    @D var reproductions: [RivalSciResult] = []
    /// Unique AI breakthroughs, with their reports.
    @D var breakthroughs: [SciBreakthrough] = []
}

enum Science {
    static let decisionKind = "sci_report"
    static let agentMax = 40
    /// Scientists a project needs for full speed.
    static let staffPerProject = 4.0
    static let maxEquipment = 5
    static let maxReruns = 3

    // MARK: Rolls

    /// A hashed roll in [0, 1): never touches the game's random numbers (key documented at each call).
    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("sci|\(s.peopleSalt)|\(key)") }

    // MARK: Money

    /// Prices grow with the era (2026 = 1).
    static func eraScale(_ y: Double) -> Double {
        interpolate([(2016, 0.45), (2020, 0.6), (2023, 0.85), (2026, 1), (2030, 1.4), (2035, 2)], at: y, extrapolate: false)
    }

    static func site(_ id: String) -> LabSite { ScienceCatalog.siteByID[id] ?? ScienceCatalog.sites[0] }
    static func country(_ site: LabSite) -> HQCountry { CountryCatalog.get(site.country) }
    static func city(_ site: LabSite) -> HQCity { country(site).city(site.id) }
    static func siteName(_ id: String) -> String { let st = site(id); return "\(city(st).name), \(country(st).name)" }
    static func siteImage(_ id: String) -> String { city(site(id)).image }

    /// A lab in your home country gets home incentives and partners (never in the US default: neutral).
    static func isHome(_ siteID: String, _ s: GameState) -> Bool { !HQ.isDefault(s) && site(siteID).country == s.hqCountry }

    /// Build cost relative to the 2026 Bay Area: local construction, and home incentives.
    static func buildFactor(_ siteID: String, _ s: GameState) -> Double {
        let st = site(siteID)
        var f = 0.7 + 0.3 * city(st).office
        if isHome(siteID, s) { f *= country(st).buildCost * 0.9 }
        return f
    }

    static func capex(_ k: LabKind, site: String, _ s: GameState) -> Double {
        (ScienceCatalog.lab(k).capex * eraScale(s.year) * buildFactor(site, s) / 1e4).rounded() * 1e4
    }

    /// One scientist's yearly cost at a site, with employer on-costs.
    static func salary(_ siteID: String, _ s: GameState) -> Double {
        let st = site(siteID)
        let c = country(st)
        let local = c.id == "us" ? 1 : c.salary * city(st).salary * (1 + c.employerCost)
        return 230_000 * eraScale(s.year) * local
    }

    static func upgradeCost(_ lab: SciLab, _ s: GameState) -> Double {
        (lab.def.capex * eraScale(s.year) * buildFactor(lab.site, s) * 0.3 * Double(lab.equipment) / 1e4).rounded() * 1e4
    }

    /// Facility, consumables and maintenance per month (staff aside).
    static func facilityMonth(_ lab: SciLab, _ s: GameState) -> Double {
        lab.def.capex * eraScale(s.year) * buildFactor(lab.site, s) * (0.008 + 0.002 * Double(lab.equipment))
    }

    static func staffMonth(_ lab: SciLab, _ s: GameState) -> Double { Double(lab.staff) * salary(lab.site, s) / 12 }

    static func agentDay(_ s: GameState) -> Double { 150 * eraScale(s.year) }
    static func computeMonth(_ tier: Int, _ s: GameState) -> Double { 120_000 * Double(tier) * eraScale(s.year) }

    /// What one attempt at a stage costs.
    static func stageCost(_ p: SciProject, _ st: SciStage, _ s: GameState) -> Double {
        guard let d = p.projectDef else { return 0 }
        let f = ScienceCatalog.field(d.field)
        let def = ScienceCatalog.stage(st)
        let bench = f.computational && def.kind == .physical ? 0.25 : 1
        return def.cost * bench * (0.8 + 0.6 * d.difficulty + 0.2 * d.size) * eraScale(s.year)
    }

    /// Running cost of everything per month, today.
    static func runningMonth(_ s: GameState) -> Double {
        var t = 0.0
        for lab in s.science.labs { t += facilityMonth(lab, s) + staffMonth(lab, s) }
        for p in s.science.projects where p.status == .running {
            t += Double(p.agents) * agentDay(s) * 30.4 + computeMonth(p.compute, s)
        }
        return t
    }

    // MARK: Labs

    static func capacity(_ lab: SciLab) -> Int { lab.def.capacity + (lab.equipment >= 3 ? 1 : 0) + (lab.equipment >= 5 ? 1 : 0) }
    static func active(_ lab: SciLab, _ s: GameState) -> [SciProject] { s.science.projects.filter { $0.lab == lab.id && $0.status == .running } }
    static func staffCap(_ lab: SciLab) -> Int { 6 * capacity(lab) + 4 }

    /// Skill a new hire brings at this site: local strengths, and your home's specialists in research.
    static func hireSkill(_ lab: SciLab, _ s: GameState, n: Int) -> Double {
        let local = site(lab.site).strengths[lab.kind] ?? 0
        let jitter = 10 * (roll(s, "hire|\(lab.id)|\(lab.staff)|\(n)") - 0.5)
        return clamp(54 + local + jitter, 40, 88)
    }

    /// Speed from staffing: 4 scientists per running project is full speed (up to +25% with more).
    static func staffFactor(_ lab: SciLab, active: Int) -> Double {
        clamp(Double(lab.staff) / (staffPerProject * Double(max(1, active))), 0.2, 1.25)
    }

    // MARK: Models and agents

    /// Your best model (released or in-house) on a field's domain mix.
    static func modelQuality(_ f: FieldDef, _ s: GameState) -> Double {
        Capabilities.playerBest(s, releasedOnly: false)?.mix(f.mix) ?? 0
    }

    static func agentScore(_ s: GameState) -> Double { Capabilities.playerBest(s, releasedOnly: false)?[.agents] ?? 0 }

    /// Odds your models add: nothing below a score of 90, +12 points at 170.
    static func modelBoost(_ q: Double) -> Double { 0.12 * clamp((q - 90) / 80, 0, 1) }

    /// Odds agents add: more agents help with diminishing returns, if your models can act on their own.
    static func agentBoost(_ n: Int, score: Double) -> Double {
        guard n > 0 else { return 0 }
        return 0.07 * (1 - exp(-Double(n) / 8)) * clamp((score - 90) / 70, 0, 1)
    }

    // MARK: Odds and time

    struct Odds {
        var p: Double
        var parts: [(String, Double)]
    }

    static func fit(_ lab: SciLab, _ f: SciField) -> Double { lab.def.primary.contains(f) ? 0.04 : -0.04 }

    /// Stage kind as this field runs it: computational fields do everything but the market at the keyboard.
    static func stageKind(_ st: SciStage, _ f: FieldDef) -> SciStage.Kind {
        let k = ScienceCatalog.stage(st).kind
        return f.computational && k == .physical ? .computational : k
    }

    static func stageName(_ st: SciStage, _ f: SciField) -> String {
        let d = ScienceCatalog.stage(st)
        return ScienceCatalog.field(f).computational ? d.compName : d.name
    }

    /// Stages a field goes through (computational fields skip manufacturing).
    static func stages(_ f: SciField) -> [SciStage] {
        ScienceCatalog.field(f).computational ? SciStage.allCases.filter { $0 != .manufacturing } : SciStage.allCases
    }

    static func odds(_ p: SciProject, _ st: SciStage, _ s: GameState, quality: Double? = nil, agentScore aScore: Double? = nil) -> Odds {
        guard let d = p.projectDef, let lab = s.science.labs.first(where: { $0.id == p.lab }) else { return Odds(p: 0, parts: []) }
        let f = ScienceCatalog.field(d.field)
        let def = ScienceCatalog.stage(st)
        let kind = stageKind(st, f)
        var parts: [(String, Double)] = [("Base odds", def.odds), ("Difficulty", -d.difficulty)]
        if d.speculative { parts.append(("Speculative", -0.1)) }
        parts.append((lab.def.primary.contains(d.field) ? "Lab built for it" : "Lab not built for it", fit(lab, d.field)))
        parts.append(("Staff skill \(Int(lab.skill.rounded()))", 0.25 * (lab.skill - 60) / 100))
        let wBench = kind == .physical ? 1.0 : (kind == .market ? 0.3 : 0.5)
        let wModel = kind == .computational ? 1.0 : (kind == .market ? 0.3 : 0.5)
        if lab.equipment > 1 { parts.append(("Equipment level \(lab.equipment)", 0.035 * Double(lab.equipment - 1) * wBench)) }
        let q = quality ?? modelQuality(f, s)
        let mb = modelBoost(q) * wModel
        if mb > 0 { parts.append(("Your models (\(Int(q.rounded())))", mb)) }
        let ab = agentBoost(p.agents, score: aScore ?? agentScore(s)) * wModel
        if ab > 0 { parts.append(("\(p.agents) agents", ab)) }
        if p.compute > 0 { parts.append(("Compute tier \(p.compute)", 0.025 * Double(p.compute) * wModel)) }
        let mom = s.science.momentum[d.field.rawValue] ?? 0
        if mom > 0 { parts.append(("What the field has learned", mom)) }
        // Research-data partnerships (journals, institutes, robot fleets) put fresh results and raw data in front of the team.
        let partners = DataEconomy.researchPartners(s, field: d.field)
        if !partners.isEmpty { parts.append(("Data partnership\(partners.count == 1 ? "" : "s"): \(partners.joined(separator: ", "))", min(0.04, 0.02 * Double(partners.count)))) }
        if kind == .market, let product = ProductLines.byID[f.product], s.productLines.contains(where: { $0.id == product.id }) {
            parts.append(("You sell \(product.name)", 0.06))
        }
        if kind == .market && isHome(lab.site, s) { parts.append(("Home partners", 0.04)) }
        if kind != .computational, !f.product.isEmpty {
            let st = site(lab.site)
            if let a = (city(st).affinities + country(st).affinities).first(where: { $0.product == f.product }) {
                parts.append(("Local partners: \(a.partner)", 0.03))
            }
        }
        if !p.scooped.isEmpty && st.rawValue > SciStage.reproduction.rawValue { parts.append(("Published by a rival: methods known", 0.03)) }
        let total = clamp(parts.reduce(0) { $0 + $1.1 }, 0.08, 0.93)
        return Odds(p: total, parts: parts)
    }

    /// Days a stage takes at today's speed.
    static func stageDays(_ p: SciProject, _ st: SciStage, _ s: GameState, quality: Double? = nil) -> Double {
        guard let d = p.projectDef, let lab = s.science.labs.first(where: { $0.id == p.lab }) else { return 30 }
        let f = ScienceCatalog.field(d.field)
        let kind = stageKind(st, f)
        var speed = staffFactor(lab, active: active(lab, s).count) * automationSpeed(s) * AgentOrgs.scienceBoost(s)   // discovery organisations speed the labs
        let q = quality ?? modelQuality(f, s)
        if kind == .computational {
            speed *= 1 + 2 * modelBoost(q) + 0.08 * Double(p.compute) + 0.25 * (1 - exp(-Double(p.agents) / 10))
        } else if kind == .physical {
            speed *= 1 + 0.06 * Double(lab.equipment - 1)
            if lab.kind == .autolab { speed *= 1.3 }
        }
        return max(5, ScienceCatalog.stage(st).days * (1 + d.difficulty) / speed)
    }

    /// Chance of making it from the current stage to commercialisation (reruns allowed, dead ends not).
    static func chanceToEnd(_ p: SciProject, _ s: GameState) -> Double {
        guard let d = p.projectDef else { return 0 }
        var c = 1.0
        for st in stages(d.field) where st.rawValue >= p.stage {
            let o = odds(p, st, s).p
            let dead = deadShare(st, d)
            // Each failure is a dead end with `dead`, else a rerun; after maxReruns reruns the team gives up.
            var pass = 0.0, reach = 1.0
            for _ in 0...maxReruns {
                pass += reach * o
                reach *= (1 - o) * (1 - dead)
            }
            c *= pass
        }
        return c
    }

    static func deadShare(_ st: SciStage, _ d: SciProjectDef) -> Double {
        min(0.7, ScienceCatalog.stage(st).deadShare + (d.speculative ? 0.12 : 0))
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        guard !s.science.labs.isEmpty || !s.science.discoveries.isEmpty else { return }
        if GameCalendar.components(s.date).day == 1 { monthly(&s) }
        labsDaily(&s)
        projectsDaily(&s)
        if let id = s.science.toPublish.first, let d = ScienceCatalog.projectByID[id] { publish(&s, d, title: d.headline) }
    }

    static func book(_ s: inout GameState, _ cost: Double) {
        guard cost > 0 else { return }
        s.cash -= cost
        s.month.costOther += cost
        s.science.spentRun += cost
        s.science.costMonth += cost
    }

    static func labsDaily(_ s: inout GameState) {
        var cost = 0.0
        for i in s.science.labs.indices {
            let lab = s.science.labs[i]
            cost += (facilityMonth(lab, s) + staffMonth(lab, s)) / 30.4
            if GameCalendar.daysBetween(lab.ready, s.date) == 0 {
                Sim.news(&s, "\(lab.name) opens", "\(lab.def.blurb) \(lab.staff) \(lab.def.staffTitle) on staff; room for \(capacity(lab)) projects at once.",
                         .research, image: lab.def.image, good: true)
                Alerts.raise(&s, .milestone, key: "sci|open|\(lab.id)", title: "\(lab.name) is open", body: "Start a research project on the Science page.",
                             screen: .science, cooldown: 0)
            }
            if let up = lab.upgradeReady, up <= s.date {
                s.science.labs[i].upgradeReady = nil
                s.science.labs[i].equipment = min(maxEquipment, lab.equipment + 1)
                Sim.news(&s, "\(lab.name): equipment upgraded to level \(lab.equipment + 1)",
                         "New instruments are calibrated and running. Bench work is faster and more reliable\(lab.equipment + 1 == 3 || lab.equipment + 1 == 5 ? ", and the lab can run one more project at once" : "").",
                         .research, image: lab.def.image, good: true)
            }
        }
        book(&s, cost)
    }

    static func projectsDaily(_ s: inout GameState) {
        guard s.science.projects.contains(where: { $0.status == .running }) else { return }
        var cache: [SciField: Double] = [:]
        let aScore = agentScore(s)
        var cost = 0.0
        for i in s.science.projects.indices where s.science.projects[i].status == .running {
            let p = s.science.projects[i]
            guard let d = p.projectDef, let lab = s.science.labs.first(where: { $0.id == p.lab }), lab.isReady(s.date) else { continue }
            cost += Double(p.agents) * agentDay(s) + computeMonth(p.compute, s) / 30.4
            let q = cache[d.field] ?? modelQuality(ScienceCatalog.field(d.field), s)
            cache[d.field] = q
            let st = p.currentStage
            let need = stageDays(p, st, s, quality: q)
            s.science.projects[i].progress += 1
            guard s.science.projects[i].progress >= need else { continue }
            finishStage(&s, i, st, odds: odds(p, st, s, quality: q, agentScore: aScore).p)
        }
        book(&s, cost)
    }

    /// The end of an attempt: pass, rerun or dead end, on hashed rolls keyed by project, stage and attempt.
    static func finishStage(_ s: inout GameState, _ i: Int, _ st: SciStage, odds o: Double) {
        let p = s.science.projects[i]
        guard let d = p.projectDef else { return }
        let key = "\(p.id)|\(st.rawValue)|\(p.attempts)"
        let r = roll(s, "stage|\(key)")
        let days = GameCalendar.daysBetween(p.stageStarted, s.date)
        let attemptCost = stageCost(p, st, s) * (p.attempts > 0 ? 0.7 : 1)
        let stageName = stageName(st, d.field)
        if r < o {
            s.science.projects[i].log.append(SciStageLog(stage: st.rawValue, date: s.date, odds: o, outcome: "passed", days: days, cost: attemptCost))
            advance(&s, i, from: st)
            return
        }
        let dead = roll(s, "dead|\(key)") < deadShare(st, d) || p.attempts >= maxReruns
        if dead {
            s.science.projects[i].log.append(SciStageLog(stage: st.rawValue, date: s.date, odds: o, outcome: "dead end", days: days, cost: attemptCost))
            deadEnd(&s, i, at: st)
        } else {
            s.science.projects[i].log.append(SciStageLog(stage: st.rawValue, date: s.date, odds: o, outcome: "rerun", days: days, cost: attemptCost))
            s.science.projects[i].attempts += 1
            s.science.projects[i].progress = p.progress * 0.5   // 3.8: half the stage's work carries over to the rerun
            s.science.projects[i].stageStarted = s.date
            let rerunCost = stageCost(p, st, s) * 0.7
            s.science.projects[i].spent += rerunCost
            book(&s, rerunCost)
            Sim.news(&s, "\(d.name): \(stageName.lowercased()) failed, rerunning",
                     "\(rerunWhy(st, d, key: key)) The team reruns it from the half-way point (attempt \(p.attempts + 2), \(Fmt.money(rerunCost)) charged now). Odds were \(Int((o * 100).rounded()))%.",
                     .research, good: false)
        }
    }

    static func rerunWhy(_ st: SciStage, _ d: SciProjectDef, key: String) -> String {
        let comp = ScienceCatalog.field(d.field).computational
        let options: [String]
        switch st {
        case .hypothesis: options = ["The first estimates don't hold up; the idea needs reframing.", "A literature search turns up a reason it shouldn't work — the team thinks it can get around it."]
        case .simulation: options = comp ? ["The search stalls in a local optimum.", "The numerical runs disagree with each other."] : ["The simulations don't converge.", "The model's predictions disagree with known results; the potentials need refitting."]
        case .design: options = ["The first plan needs instruments you don't have; the team redesigns.", "Reviewers find a confound in the design."]
        case .testing: options = comp ? ["The proof checker rejects a key lemma.", "Verification finds a counterexample to one step."] : ["The samples crack.", "The test rig drifts and a week of data is unusable.", "A contaminated batch spoils the run."]
        case .measurement: options = ["The error bars are too wide to claim anything.", "The control group misbehaves."]
        case .reproduction: options = ["The second team can't get the same numbers.", "The effect is half the size the second time."]
        case .prototype: options = ["The prototype fails its first real task.", "It works on the bench and not in the box."]
        case .validation: options = ["It fails the ageing tests.", "It doesn't survive the thermal cycles."]
        case .manufacturing: options = ["Yields at pilot scale are too low.", "A key input is too expensive at volume."]
        case .commercialisation: options = ["The first customer pilot slips.", "Certification asks for another round of tests."]
        }
        let k = Int(RivalIntel.unit("why|\(key)") * Double(options.count)) % options.count
        return options[k]
    }

    static func advance(_ s: inout GameState, _ i: Int, from st: SciStage) {
        guard let d = s.science.projects[i].projectDef else { return }
        let list = stages(d.field)
        let idx = list.firstIndex(of: st) ?? 0
        if st == .reproduction { discover(&s, i) }
        if let disc = s.science.projects[i].discovery, let k = s.science.discoveries.firstIndex(where: { $0.id == disc }) {
            let before = s.science.discoveries[k].level
            s.science.discoveries[k].level = max(before, levels[st] ?? before)
            spinoutMilestone(&s, k, from: before)
        }
        guard idx + 1 < list.count else {
            commercialise(&s, i)
            return
        }
        let next = list[idx + 1]
        s.science.projects[i].stage = next.rawValue
        s.science.projects[i].progress = 0
        s.science.projects[i].attempts = 0
        s.science.projects[i].stageStarted = s.date
        let c = stageCost(s.science.projects[i], next, s)
        s.science.projects[i].spent += c
        book(&s, c)
    }

    /// Effect strength by the last stage passed (discovery at reproduction; full effect when commercialised).
    static let levels: [SciStage: Double] = [.reproduction: 0.35, .prototype: 0.5, .validation: 0.62, .manufacturing: 0.8, .commercialisation: 1]

    static func deadEnd(_ s: inout GameState, _ i: Int, at st: SciStage) {
        let p = s.science.projects[i]
        guard let d = p.projectDef else { return }
        s.science.projects[i].ended = s.date
        let name = stageName(st, d.field)
        bumpMomentum(&s, d.field, 0.02)
        if let disc = p.discovery, let k = s.science.discoveries.firstIndex(where: { $0.id == disc }) {
            // A real result that can't be turned into a product: it stays a lab-scale result.
            s.science.projects[i].status = .stalled
            s.science.discoveries[k].labScaleOnly = true
            s.science.discoveries[k].level = min(s.science.discoveries[k].level, 0.5)
            let why = st == .manufacturing ? "The science is real, but it can't be made at volume at a price anyone would pay." : "The result holds, but it won't become a product as it stands."
            Sim.news(&s, "\(d.name) stops at \(name.lowercased())",
                     "\(why) The discovery stays yours at lab scale (half its full effect); what the team learned helps your next \(ScienceCatalog.field(d.field).name.lowercased()) project.",
                     .research, image: p.labImage(s), important: true, good: false)
        } else {
            s.science.projects[i].status = .failed
            let why: String
            switch st {
            case .hypothesis: why = "The hypothesis is falsified."
            case .reproduction: why = "The result doesn't reproduce: the first measurements were an artefact."
            default: why = p.attempts >= maxReruns ? "After \(p.attempts + 1) attempts the team calls it." : "The approach is a dead end."
            }
            Sim.news(&s, "Dead end: \(d.name)", "\(why) \(Fmt.money(s.science.projects[i].spent)) spent. Negative results still count: odds on the next \(ScienceCatalog.field(d.field).name.lowercased()) project are a little better.",
                     .research, image: p.labImage(s), good: false)
        }
    }

    // MARK: Discoveries

    static func discover(_ s: inout GameState, _ i: Int) {
        let p = s.science.projects[i]
        guard let d = p.projectDef else { return }
        var disc = SciDiscovery(def: d.id, project: p.id, date: s.date, title: d.headline)
        disc.scooped = p.scooped
        let before = s.science.momentum[d.field.rawValue] ?? 0
        bumpMomentum(&s, d.field, 0.04)
        let bump = (s.science.momentum[d.field.rawValue] ?? 0) - before
        disc.report = report(s, d, scooped: p.scooped, project: p, momentum: bump)
        s.science.discoveries.append(disc)
        s.science.projects[i].discovery = disc.id
        offerChoices(&s, disc.id)
        // The lab notebooks, failures included, become training data in the field.
        DataEconomy.addLabNotebooks(&s, discovery: disc.id, project: s.science.projects[i], def: d)
        s.brand = min(100, s.brand + (d.speculative ? 1.5 : 0.5))
        Stakeholders.move(&s, ["researchers": d.speculative ? 2 : 1], "A reproduced discovery: \(d.headline)")
        Sim.news(&s, "🔬 Discovery: \(d.headline)", "\(disc.report.significance) \(disc.report.commercial)", .research, image: p.labImage(s), important: true, good: true)
        // 3.4: the lab's first result that a second team reproduced is a landmark in its history.
        TrainingExperience.recordFirst(&s, id: "verified_discovery", title: "First independently verified discovery",
                                       detail: "\(d.headline): a second team got the same result.",
                                       model: s.science.labs.first { $0.id == p.lab }.map { $0.name.isEmpty ? $0.def.name : $0.name } ?? "Your science lab", symbol: "checkmark.seal.fill")
        if let u = ScienceCatalog.unlock(d.id) {
            Sim.news(&s, "New technology: \(u.title)", u.detail, .research, image: p.labImage(s), important: true, good: true)
        }
        Alerts.raise(&s, .milestone, key: "sci|disc|\(disc.id)", title: "Discovery: \(d.headline)", body: "Read the report and choose what to do with it.",
                     screen: .science, celebrate: true, cooldown: 0)
    }

    static func commercialise(_ s: inout GameState, _ i: Int) {
        let p = s.science.projects[i]
        guard let d = p.projectDef else { return }
        s.science.projects[i].status = .done
        s.science.projects[i].ended = s.date
        var joined = 0
        if let disc = p.discovery, let k = s.science.discoveries.firstIndex(where: { $0.id == disc }) {
            let before = s.science.discoveries[k].level
            s.science.discoveries[k].level = 1
            s.science.discoveries[k].commercialised = s.date
            spinoutMilestone(&s, k, from: before)
            // A patented result in production draws more licensees.
            if let j = s.science.patents.firstIndex(where: { $0.discovery == disc && $0.expires > s.date }) {
                joined = 1 + Int(roll(s, "joined|\(disc)") * 3)
                s.science.patents[j].licensees += joined
            }
        }
        s.brand = min(100, s.brand + 1)
        Sim.news(&s, "Commercialised: \(d.headline)",
                 "\(d.name) made it through all \(stages(d.field).count) stages in \(GameCalendar.daysBetween(p.started, s.date)) days and \(Fmt.money(p.spent)). Its effects now apply in full: \(effectLines(ScienceCatalog.effect(d), strength: d.size, s).joined(separator: "; "))\(joined > 0 ? ". \(joined) more compan\(joined == 1 ? "y takes" : "ies take") a licence on the patent" : "").",
                 .research, image: p.labImage(s), important: true, good: true)
        Alerts.raise(&s, .milestone, key: "sci|comm|\(p.id)", title: "Commercialised: \(d.headline)", body: "\(d.name) is in production.",
                     screen: .science, celebrate: true, cooldown: 0)
    }

    static func bumpMomentum(_ s: inout GameState, _ f: SciField, _ v: Double) {
        s.science.momentum[f.rawValue] = min(0.12, (s.science.momentum[f.rawValue] ?? 0) + v)
    }

    /// Put a discovery's follow-up decision in the inbox, with the choices open today (the report sheet offers exactly
    /// these). The ref is "<discovery>|<choices>|<moonshot it would feed>".
    static func offerChoices(_ s: inout GameState, _ id: UUID) {
        guard let k = s.science.discoveries.firstIndex(where: { $0.id == id }), let d = s.science.discoveries[k].projectDef,
              let p = s.science.projects.first(where: { $0.id == s.science.discoveries[k].project }) else { return }
        let f = ScienceCatalog.field(d.field)
        let scooped = !s.science.discoveries[k].scooped.isEmpty
        let options = choices(s, d)
        let opts = options.map { DecisionOption(label: $0.label, detail: choiceDetail($0, d, s, scooped: scooped, level: s.science.discoveries[k].level)) }
        let ref = "\(id.uuidString)|" + options.map(\.rawValue).joined(separator: ",") + "|" + (feedable(s, d) ?? "")
        Events.addDecision(&s, kind: decisionKind, title: "Discovery: \(d.headline)",
                           body: "\(f.name), \(p.labName(s)). \(s.science.discoveries[k].report.significance) What next? The full report is on the Science page.",
                           image: p.labImage(s), options: opts, ref: ref)
        s.science.discoveries[k].decision = s.decisions.last?.id
    }

    /// The follow-ups on offer for a discovery (patent first: it's what happens if you don't answer).
    static func choices(_ s: GameState, _ d: SciProjectDef) -> [SciChoice] {
        var out: [SciChoice] = [.patent, .secret, .publish, .spinout]
        if AdvancedProjects.publicationBlock(s, d.field) != nil { out.removeAll { $0 == .publish } }   // 3.8: Secret government work in the field
        if feedable(s, d) != nil { out.append(.moonshot) }
        return out
    }

    /// The choices a discovery's open decision offers (what the report sheet shows), or today's if it has none.
    static func offered(_ s: GameState, _ disc: SciDiscovery) -> [SciChoice] {
        if let dec = disc.decision.flatMap({ id in s.decisions.first { $0.id == id } }) {
            let parts = dec.ref.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if parts.count >= 2 { return parts[1].split(separator: ",").compactMap { SciChoice(rawValue: String($0)) } }
        }
        return disc.projectDef.map { choices(s, $0) } ?? []
    }

    /// Why a choice can't be taken now (nil = it can).
    static func blocker(_ s: GameState, _ disc: SciDiscovery, _ c: SciChoice, moonshot: String? = nil) -> String? {
        guard disc.choice.isEmpty else { return "Already decided: \(disc.sciChoice?.label.lowercased() ?? disc.choice)." }
        guard let d = disc.projectDef else { return "Unknown discovery." }
        if c == .moonshot {
            let target = moonshot ?? feedable(s, d)
            guard let m = target, let ms = s.moonshots.first(where: { $0.id == m }), ms.status == .running || ms.status == .offered else {
                return "No moonshot this result can feed is running or on offer any more."
            }
        }
        return nil
    }

    /// A running or offered moonshot this result can feed.
    static func feedable(_ s: GameState, _ d: SciProjectDef) -> String? {
        let ids = ScienceCatalog.field(d.field).moonshots
        return s.moonshots.first { ids.contains($0.id) && ($0.status == .running || $0.status == .offered) }?.id
    }

    /// What one licensee pays a month for a patent on this result today: more the further the work got.
    static func royaltyPerLicensee(_ d: SciProjectDef, level: Double, _ s: GameState, scooped: Bool) -> Double {
        40_000 * eraScale(s.year) * d.size * level * (scooped ? 0.5 : 1)
    }

    /// Who wants a licence: energy results sell to every utility and datacenter operator, the rest to a few specialists.
    static func licenseeRange(_ d: SciProjectDef) -> (low: Int, high: Int) {
        switch ScienceCatalog.effect(d) {
        case .power, .storage, .superconductor: (4, 9)
        default: (2, 5)
        }
    }

    /// Monthly royalties a patent on this result would earn today with a typical number of licensees.
    static func royalty(_ d: SciProjectDef, level: Double, _ s: GameState, scooped: Bool) -> Double {
        let r = licenseeRange(d)
        return royaltyPerLicensee(d, level: level, s, scooped: scooped) * Double(r.low + r.high) / 2
    }

    /// What a spin-out pays for an exclusive licence: priced on how far the work has got, with a milestone payment each
    /// time the project gets further (the total at commercialisation is the same).
    static func spinoutCash(_ d: SciProjectDef, level: Double, _ s: GameState, scooped: Bool) -> Double {
        120_000 * eraScale(s.year) * d.size * level * (scooped ? 0.5 : 1) * 14
    }

    /// A spun-out discovery that gets further pays its milestone.
    static func spinoutMilestone(_ s: inout GameState, _ k: Int, from before: Double) {
        let disc = s.science.discoveries[k]
        guard disc.sciChoice == .spinout, disc.level > before + 1e-9, let d = disc.projectDef else { return }
        let cash = spinoutCash(d, level: disc.level - before, s, scooped: !disc.scooped.isEmpty)
        s.cash += cash
        s.month.oneOffIncome += cash
        s.science.spinoutCash += cash
        s.science.incomeMonth += cash
        Sim.news(&s, "Spin-out milestone: \(d.headline)", "The work reached \(Int((disc.level * 100).rounded()))% of its full effect, and the spin-out pays its milestone: \(Fmt.money(cash)).",
                 .finance, good: true)
    }

    static func choiceDetail(_ c: SciChoice, _ d: SciProjectDef, _ s: GameState, scooped: Bool, level: Double = 0.35) -> String {
        let f = ScienceCatalog.field(d.field)
        let r = licenseeRange(d)
        switch c {
        case .patent:
            return "\(r.low)–\(r.high) companies license it at about \(Fmt.money(royaltyPerLicensee(d, level: level, s, scooped: scooped)))/month each now, rising to \(Fmt.money(royaltyPerLicensee(d, level: 1, s, scooped: scooped))) each if it's commercialised (when more join). Rivals license it or design around it in a few years."
        case .secret:
            return scooped ? "A rival has already published it: secrecy buys little now." : "Keep the edge to yourself: its effects are 20% stronger until a rival gets there on its own (typically 1½–3½ years). No licence income."
        case .publish:
            let arms = ScienceCatalog.rivalLabs.filter { x in x.fields.contains(d.field) && s.competitors.contains { $0.id == x.lab && $0.alive } }.map(\.arm)
            return "Submit it to the next conference: researchers' respect and brand up, a shot at best paper. Everyone builds on it — \(arms.isEmpty ? "the field" : arms.joined(separator: ", ")) reproduce\(arms.count == 1 ? "s" : "") it within months and rival models gain the know-how; you can't patent it."
        case .spinout:
            let now = spinoutCash(d, level: level, s, scooped: scooped), full = spinoutCash(d, level: 1, s, scooped: scooped)
            if let p = ProductLines.byID[f.product] {
                return "A spin-out builds products on it with you: \(Fmt.money(now)) for the licence now and milestones up to \(Fmt.money(full)) in all if it's commercialised, and \(p.name) opens sooner and sells better."
            }
            return "A venture-backed spin-out licenses it exclusively: \(Fmt.money(now)) up front, milestones up to \(Fmt.money(full)) in all if it's commercialised."
        case .moonshot:
            let m = feedable(s, d).flatMap { MoonshotCatalog.byID[$0] }
            return "Hand it to the \(m?.name ?? "moonshot") team: its odds rise about \(Int((0.1 * d.size * 100).rounded()))%, more as the work matures. No licence income."
        }
    }

    // MARK: The report

    static func report(_ s: GameState, _ d: SciProjectDef, scooped: String, project p: SciProject, momentum bump: Double = 0.04) -> SciReport {
        let f = ScienceCatalog.field(d.field)
        var r = SciReport()
        let reruns = p.log.filter { $0.outcome == "rerun" }.count
        let days = GameCalendar.daysBetween(p.started, s.date)
        r.significance = "\(d.headline). \(d.pitch) It reproduced after \(days) days\(reruns > 0 ? " and \(reruns) rerun\(reruns == 1 ? "" : "s")" : " with no reruns"). \(d.basis)"
        if !scooped.isEmpty { r.significance += " \(labName(s, scooped)) published the same result first, so the priority is theirs." }
        let effect = ScienceCatalog.effect(d)
        let now = effectLines(effect, strength: d.size * 0.35, s)
        let full = effectLines(effect, strength: d.size, s)
        r.commercial = "Now, at lab scale: \(now.joined(separator: "; ")). If it makes it through prototype, validation\(f.computational ? "" : ", manufacturing") and commercialisation: \(full.joined(separator: "; "))."
        if let u = ScienceCatalog.unlock(d.id) { r.commercial += " New technology: \(u.title) — \(u.detail)" }
        // Impact on your other work.
        var impact: [String] = []
        let points = Int((bump * 100).rounded())
        let fade = Int((bump / 0.005).rounded())
        let same = s.science.projects.filter { $0.status == .running && $0.id != p.id && $0.projectDef?.field == d.field }
        if points <= 0 { impact.append("What the field has learned is already at its ceiling: no extra odds for your \(f.name.lowercased()) projects.") }
        else if !same.isEmpty { impact.append("Builds on itself: +\(points) point\(points == 1 ? "" : "s") on every stage of \(same.compactMap { $0.projectDef?.name }.joined(separator: ", ")), fading over about \(fade) months.") }
        else { impact.append("Your \(f.name.lowercased()) projects get +\(points) point\(points == 1 ? "" : "s") on every stage, fading over about \(fade) months.") }
        impact.append("Its lab notebooks — every attempt, failures included — join your training data as a small specialist dataset.")
        if let m = feedable(s, d), let md = MoonshotCatalog.byID[m] { impact.append("It's relevant to the \(md.name) moonshot you're \(s.moonshots.first { $0.id == m }?.status == .running ? "running" : "being offered").") }
        if let prod = ProductLines.byID[f.product] {
            impact.append(s.productLines.contains { $0.id == prod.id } ? "Your \(prod.name) line gets better as it matures." : "It brings \(prod.name) closer.")
        }
        r.impact = impact.joined(separator: " ")
        // Competitors.
        let rivals = ScienceCatalog.rivalLabs.filter { x in x.fields.contains(d.field) && s.competitors.contains { $0.id == x.lab && $0.alive } }.prefix(2)
        if rivals.isEmpty {
            r.competitors = "No rival lab is known to work on this. Expect specialists and universities to follow within a couple of years."
        } else {
            let names = rivals.map { $0.arm }.joined(separator: " and ")
            r.competitors = "\(names) work\(rivals.count == 1 ? "s" : "") in this field. If you publish, they'll reproduce it within three to nine months and their models gain the know-how; if you patent it, expect licence talks — or a design-around in three to five years; if you keep it secret, they'll likely get there on their own in one and a half to three and a half."
        }
        return r
    }

    static func labName(_ s: GameState, _ lab: String) -> String {
        ScienceCatalog.rivalLabs.first { $0.lab == lab }?.arm ?? s.competitors.first { $0.id == lab }?.def.name ?? lab
    }

    // MARK: Follow-up decisions

    static func resolve(_ s: inout GameState, _ dec: Decision, option: Int) {
        if dec.ref.hasPrefix(breakthroughPrefix) { resolveBreakthrough(&s, dec, option: option); return }
        let parts = dec.ref.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, let id = UUID(uuidString: parts[0]) else { return }
        let codes = parts[1].split(separator: ",").compactMap { SciChoice(rawValue: String($0)) }
        guard codes.indices.contains(option) else { return }
        let target = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
        if let why = apply(&s, discovery: id, codes[option], moonshot: target) {
            // The inbox can't refuse: say why, and ask again with the choices open today.
            guard let k = s.science.discoveries.firstIndex(where: { $0.id == id }), s.science.discoveries[k].choice.isEmpty else { return }
            Sim.news(&s, "Choose again: \(s.science.discoveries[k].title)", "\(why) The report is back in your inbox with today's options.", .research, good: false)
            offerChoices(&s, id)
        }
    }

    /// Apply a follow-up. Returns why it can't be taken (nothing changes then).
    @discardableResult
    static func apply(_ s: inout GameState, discovery id: UUID, _ c: SciChoice, moonshot target: String? = nil) -> String? {
        guard let k = s.science.discoveries.firstIndex(where: { $0.id == id }), let d = s.science.discoveries[k].projectDef else { return "Unknown discovery." }
        if let why = blocker(s, s.science.discoveries[k], c, moonshot: target) { return why }
        let f = ScienceCatalog.field(d.field)
        let scooped = !s.science.discoveries[k].scooped.isEmpty
        s.science.discoveries[k].choice = c.rawValue
        s.science.discoveries[k].choiceDate = s.date
        let key = "\(id)"
        let rivals = ScienceCatalog.rivalLabs.filter { r in r.fields.contains(d.field) && s.competitors.contains { $0.id == r.lab && $0.alive } }
        let rival = rivals.isEmpty ? "" : rivals[Int(roll(s, "who|\(key)") * Double(rivals.count)) % rivals.count].lab
        switch c {
        case .patent:
            let range = licenseeRange(d)
            let n = range.low + Int(roll(s, "licensees|\(key)") * Double(range.high - range.low + 1))
            s.science.patents.append(SciPatent(discovery: id, title: d.headline, field: d.field, filed: s.date,
                                               expires: GameCalendar.addMonths(s.date, 240), licensees: n))
            s.science.discoveries[k].rivalDate = GameCalendar.addMonths(s.date, 36 + Int(roll(s, "around|\(key)") * 24))
            s.science.discoveries[k].rivalLab = rival
            let each = royaltyPerLicensee(d, level: s.science.discoveries[k].level, s, scooped: scooped)
            Sim.news(&s, "Patent filed: \(d.headline)", "\(n) companies take licences at about \(Fmt.money(each))/month each (\(Fmt.money(each * Double(n)))/month); more if it's commercialised.",
                     .research, good: true)
        case .secret:
            s.science.discoveries[k].rivalDate = GameCalendar.addMonths(s.date, scooped ? 3 : 18 + Int(roll(s, "catchup|\(key)") * 24))
            s.science.discoveries[k].rivalLab = rival
            Sim.news(&s, "Kept in-house: \(d.headline)", "No paper, no patent. The edge is yours until someone else gets there.", .research)
        case .publish:
            publish(&s, d, title: d.headline)
            s.brand = min(100, s.brand + 1)
            Stakeholders.move(&s, ["researchers": 2], "Published a discovery openly: \(d.headline)")
            for other in SciField.allCases where other != d.field && ScienceCatalog.field(other).effect == f.effect { bumpMomentum(&s, other, 0.01) }
            published(&s, d, key: key)
        case .spinout:
            let cash = spinoutCash(d, level: s.science.discoveries[k].level, s, scooped: scooped)
            s.cash += cash
            s.month.oneOffIncome += cash
            s.science.spinoutCash += cash
            s.science.incomeMonth += cash
            let p = ProductLines.byID[f.product]
            Sim.news(&s, "Spin-out: \(d.headline)", "A new company licenses it for \(Fmt.money(cash)) now, with milestone payments as the work gets further\(p.map { ", and builds \($0.name.lowercased()) products on it with you" } ?? "").",
                     .finance, good: true)
        case .moonshot:
            guard let m = target ?? feedable(s, d) else { return "No moonshot to feed." }
            s.science.discoveries[k].moonshot = m
            Sim.news(&s, "\(d.headline) joins the \(MoonshotCatalog.byID[m]?.name ?? "moonshot") programme",
                     "Your lab hands its result and its people to the moonshot team. Its odds rise about \(Int((0.1 * d.size * 100).rounded()))%, more as the work matures.",
                     .research, good: true)
        }
        return nil
    }

    /// Everyone builds on a published result: rival science arms in the field reproduce it within three to nine months,
    /// publish more in the field for a while, and every rival lab's models gain its know-how six months on
    /// (`rivalKnowHow`).
    static func published(_ s: inout GameState, _ d: SciProjectDef, key: String) {
        s.science.rivalMomentum[d.field.rawValue] = min(1.5, (s.science.rivalMomentum[d.field.rawValue] ?? 0) + 0.6)
        for r in ScienceCatalog.rivalLabs where r.fields.contains(d.field) {
            guard s.competitors.contains(where: { $0.id == r.lab && $0.alive }),
                  !s.science.rivals.contains(where: { $0.lab == r.lab && $0.def == d.id }),
                  !s.science.reproductions.contains(where: { $0.lab == r.lab && $0.def == d.id }) else { continue }
            let due = GameCalendar.addMonths(s.date, 3 + Int(roll(s, "repro|\(key)|\(r.lab)") * 7))
            s.science.reproductions.append(RivalSciResult(lab: r.lab, def: d.id, date: due, reproduced: true))
        }
    }

    /// Submit a discovery to the next conference that can still review it.
    /// Submit a discovery to a conference whose call for papers has closed for everyone else (so it never collides
    /// with the paper the team sends through the call) and whose reviews are still ahead; otherwise it waits for the
    /// next such window (checked daily).
    @discardableResult
    static func publish(_ s: inout GameState, _ d: SciProjectDef, title: String) -> Bool {
        // 3.8: classified work in the field holds the paper (Secret: until it ends; controlled: pre-publication review).
        if AdvancedProjects.paperHeld(&s, key: d.id, field: d.field) {
            s.science.toPublish.removeAll { $0 == d.id }
            s.science.toPublish.append(d.id)   // to the back of the queue: other papers go first
            return false
        }
        for (v, date) in Conferences.upcoming(s, count: 6) {
            let left = GameCalendar.daysBetween(s.date, date)
            guard left > Conferences.reviewLead + 1, left < Conferences.cfpLead else { continue }
            let y = GameCalendar.components(date).year
            guard !s.fun.papers.contains(where: { $0.venue == v.id && $0.year == y }),
                  !s.decisions.contains(where: { $0.kind == Conferences.cfpKind && $0.ref.hasPrefix("\(v.id)|\(y)|") }) else { continue }
            Conferences.submit(&s, v, y, Conferences.Candidate(source: "sci:\(d.id)", title: title, item: nil), reveal: false)
            s.science.toPublish.removeAll { $0 == d.id }
            return true
        }
        if !s.science.toPublish.contains(d.id) {
            s.science.toPublish.append(d.id)
            Sim.news(&s, "Paper in preparation: \(title)", "The preprint is up; the team will submit it at the next conference whose deadline is open.", .research, good: true)
        }
        return false
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        s.science.lastCost = s.science.costMonth
        s.science.costMonth = 0
        s.science.lastIncome = s.science.incomeMonth
        s.science.incomeMonth = 0
        for (k, v) in s.science.momentum { s.science.momentum[k] = max(0, v - 0.005) }
        for (k, v) in s.science.rivalMomentum { s.science.rivalMomentum[k] = v < 0.02 ? nil : v * 0.85 }
        // Experience: staff get better at what they do.
        for i in s.science.labs.indices where !active(s.science.labs[i], s).isEmpty {
            s.science.labs[i].skill = min(92, s.science.labs[i].skill + 0.35)
        }
        payRoyalties(&s)
        rivalsCatchUp(&s)
        rivalReproductions(&s)
        rivalScience(&s)
    }

    /// Rival science arms reproduce what you published, on schedule.
    static func rivalReproductions(_ s: inout GameState) {
        let today = s.date
        guard s.science.reproductions.contains(where: { $0.date <= today }) else { return }
        let due = s.science.reproductions.filter { $0.date <= today }
        s.science.reproductions.removeAll { $0.date <= today }
        for var r in due {
            guard let c = s.competitors.first(where: { $0.id == r.lab }), c.alive, let d = ScienceCatalog.projectByID[r.def] else { continue }
            r.date = s.date
            s.science.rivals.insert(r, at: 0)
            bumpMomentum(&s, d.field, 0.01)
            Sim.news(&s, "\(labName(s, r.lab)) reproduces your \(d.headline.lowercased())",
                     "\(c.def.name) built on the result you published: their next models get the know-how, and the field moves faster.", .competitor)
        }
        if s.science.rivals.count > 60 { s.science.rivals.removeLast(s.science.rivals.count - 60) }
    }

    static func payRoyalties(_ s: inout GameState) {
        var total = 0.0
        for i in s.science.patents.indices where s.science.patents[i].expires > s.date {
            let p = s.science.patents[i]
            guard let disc = s.science.discoveries.first(where: { $0.id == p.discovery }), let d = disc.projectDef else { continue }
            let r = royaltyPerLicensee(d, level: disc.level, s, scooped: !disc.scooped.isEmpty) * Double(max(0, p.licensees)) * (p.designedAround ? 0.5 : 1)
            s.science.patents[i].lastMonth = r
            s.science.patents[i].lifetime += r
            total += r
        }
        guard total > 0 else { return }
        s.cash += total
        s.month.revLicensing += total
        s.lifetimeRevenue += total
        s.science.licensing += total
        s.science.incomeMonth += total
    }

    /// Secrets leak and patents get designed around.
    static func rivalsCatchUp(_ s: inout GameState) {
        for k in s.science.discoveries.indices where !s.science.discoveries[k].rivalCaughtUp {
            guard let when = s.science.discoveries[k].rivalDate, when <= s.date, let d = s.science.discoveries[k].projectDef else { continue }
            s.science.discoveries[k].rivalCaughtUp = true
            let who = s.science.discoveries[k].rivalLab.isEmpty ? "A university group" : labName(s, s.science.discoveries[k].rivalLab)
            switch s.science.discoveries[k].sciChoice {
            case .secret:
                Sim.news(&s, "\(who) gets there too: \(d.headline)", "Your secret is out — they published the same result. Your edge from it shrinks to the ordinary.", .competitor, good: false)
            case .patent:
                if let i = s.science.patents.firstIndex(where: { $0.discovery == s.science.discoveries[k].id }) { s.science.patents[i].designedAround = true }
                Sim.news(&s, "\(who) designs around your patent", "\(d.headline): a workaround halves what your licensees pay.", .competitor, good: false)
            default: break
            }
        }
    }

    /// Rival science arms announce results now and then (only once you're in the game yourself, so a lab-less game
    /// is unchanged). A result in a project you're still running before reproduction scoops you.
    static func rivalScience(_ s: inout GameState) {
        guard !s.science.labs.isEmpty else { return }
        let ym = s.date.ym
        for r in ScienceCatalog.rivalLabs {
            guard let c = s.competitors.first(where: { $0.id == r.lab }), c.alive else { continue }
            let key = "\(r.lab)|\(ym.year)-\(ym.month)"
            // What you published lately in their fields gets them going (rivalMomentum).
            let hot = r.fields.filter { (s.science.rivalMomentum[$0.rawValue] ?? 0) > 0.05 }
            let boost = r.fields.map { s.science.rivalMomentum[$0.rawValue] ?? 0 }.max() ?? 0
            guard roll(s, "rival|\(key)") < 0.035 * r.appetite * (1 + boost) else { continue }
            let mine = Set(s.science.discoveries.map(\.def))
            let theirs = Set(s.science.rivals.map(\.def))
            let running = s.science.projects.filter { $0.status == .running && $0.stage <= SciStage.reproduction.rawValue && $0.scooped.isEmpty }
                .compactMap { $0.projectDef }.filter { r.fields.contains($0.field) && !theirs.contains($0.id) }
            var pick: SciProjectDef? = nil
            if !running.isEmpty && roll(s, "race|\(key)") < 0.5 {
                pick = running[Int(roll(s, "racepick|\(key)") * Double(running.count)) % running.count]
            } else {
                var pool = ScienceCatalog.projects.filter { r.fields.contains($0.field) && $0.year <= s.year - 0.5 && !mine.contains($0.id) && !theirs.contains($0.id) }
                let warm = pool.filter { hot.contains($0.field) }
                if !warm.isEmpty && roll(s, "hot|\(key)") < 0.6 { pool = warm }
                if !pool.isEmpty { pick = pool[Int(roll(s, "pick|\(key)") * Double(pool.count)) % pool.count] }
            }
            guard let d = pick else { continue }
            var res = RivalSciResult(lab: r.lab, def: d.id, date: s.date)
            bumpMomentum(&s, d.field, 0.02)
            if let i = s.science.projects.firstIndex(where: { $0.def == d.id && $0.status == .running && $0.stage <= SciStage.reproduction.rawValue && $0.scooped.isEmpty }) {
                res.scoopedYou = true
                s.science.projects[i].scooped = r.lab
                Sim.news(&s, "Scooped: \(r.arm) publishes \(d.headline.lowercased())",
                         "They beat your \(d.name.lowercased()) project to it. If yours reproduces it's still yours to use, but it's worth half as much in licences and harder to keep secret.",
                         .competitor, important: true, good: false)
                Alerts.raise(&s, .milestone, key: "sci|scoop|\(d.id)", title: "Scooped by \(r.arm)", body: d.headline, screen: .science, cooldown: 0)
            } else {
                Sim.news(&s, "\(r.arm): \(d.headline.lowercased())", "\(c.def.name)'s science arm reports a result in \(ScienceCatalog.field(d.field).name.lowercased()). \(d.speculative ? "If it holds up, it's a big deal." : "Solid work; the field moves on.")",
                         .competitor)
            }
            s.science.rivals.insert(res, at: 0)
            if s.science.rivals.count > 60 { s.science.rivals.removeLast(s.science.rivals.count - 60) }
        }
    }

    // MARK: Effects
    //
    // Hooks elsewhere (all exactly neutral without discoveries):
    //   power bill            Power.billFactor (Sim.dailyCosts, Power.settle) multiplies by `powerFactor`
    //   battery storage capex Power.quote multiplies battery upfront by `storageCapexFactor`
    //   fusion availability   PowerKind.available / EnergySource.available move earlier by `fusionPullIn` years, or
    //                         open outright with the burning-plasma unlock (`has(.fusionPower)`)
    //   renting               Economy.rent multiplies by `cloudFactor`; DCMarket's colocation quote by `coloFactor`
    //   building              GameState.buildMonths multiplies by `buildFactor`; Power.queueMonths by `queueFactor`;
    //                         new campuses get `newSitePUEGain` (room-temperature superconductor)
    //   chips, serving, R&D   virtual research items "sci:chips", "sci:serving", "sci:quantum" (bonuses: chipDesign,
    //                         throughput + thinkingEfficiency, rp) via `bonusSources`
    //   model domains         Capabilities.researchDomains adds `domainKnowHow`; Capabilities.rivalDomains adds
    //                         `rivalKnowHow` (rival science results and what you published)
    //   product lines         ProductLines.status (bars) and updateShares (pull) use `productRelief` / `productPull`
    //   moonshots             Moonshots.chance multiplies by `moonshotFactor`
    //   semiconductors        `has(.twoDProcess)`: the 2D-channel process node (for the semiconductor catalog)

    /// A discovery's strength today: its size × how far it got × secrecy and priority.
    static func strength(_ d: SciDiscovery) -> Double {
        guard let def = d.projectDef else { return 0 }
        let secret = d.sciChoice == .secret && !d.rivalCaughtUp ? 1.2 : 1
        return def.size * d.level * secret * (d.scooped.isEmpty ? 1 : 0.8)
    }

    /// Total strength of your discoveries with an effect kind (a superconductor counts as power and as chips).
    static func total(_ s: GameState, _ e: SciEffect) -> Double {
        var t = 0.0
        for d in s.science.discoveries {
            guard let def = d.projectDef else { continue }
            let fx = ScienceCatalog.effect(def)
            guard fx == e || (fx == .superconductor && (e == .power || e == .chips)) else { continue }
            t += strength(d)
        }
        return t
    }

    static func powerFactor(_ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        return 1 - min(0.1, 0.02 * total(s, .power) + 0.008 * total(s, .storage))
    }

    static func storageCapexFactor(_ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        return 1 - min(0.3, 0.1 * total(s, .storage))
    }

    /// Years sooner commercial fusion is available to you.
    static func fusionPullIn(_ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 0 }
        return min(2, 0.8 * total(s, .fusion))
    }

    // Energy results reach people who rent, too: cloud providers and colocation landlords run them under licence
    // and pass part of the saving on, and they shorten the wait for new capacity.

    /// Cloud rentals: power and cooling are about an eighth of a GPU-hour, so they pass on 12% of the power saving.
    static func cloudFactor(_ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        return 1 - 0.12 * (1 - powerFactor(s))
    }

    /// Colocation fees are mostly power and cooling: landlords pass on half the saving.
    static func coloFactor(_ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        return 1 - 0.5 * (1 - powerFactor(s))
    }

    /// Building a campus: better power gear and grid studies (up to 15% faster).
    static func buildFactor(_ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        return 1 - min(0.15, 0.04 * total(s, .power))
    }

    /// The grid-interconnection queue: a campus that can shift its load (learned dispatch, batteries) gets connected
    /// sooner, as flexible load did on real grids (up to 25% shorter).
    static func queueFactor(_ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        return 1 - min(0.25, 0.06 * total(s, .power) + 0.03 * total(s, .storage))
    }

    // MARK: Technology unlocks

    /// Whether a discovery has opened a new technology (see `ScienceCatalog.unlocks`).
    static func has(_ u: SciUnlock, _ s: GameState) -> Bool { unlockDate(u, s) != nil }

    /// When a technology opened: the day its discovery reproduced.
    static func unlockDate(_ u: SciUnlock, _ s: GameState) -> Date? {
        guard !s.science.discoveries.isEmpty, let id = ScienceCatalog.unlocks.first(where: { $0.unlock == u })?.project else { return nil }
        return s.science.discoveries.filter { $0.def == id }.map(\.date).min()
    }

    /// PUE points new campuses save with lossless superconducting power delivery and cryo-free cooling loops (up to
    /// 0.1, growing as the superconductor gets through prototype, validation and manufacturing).
    static func newSitePUEGain(_ s: GameState) -> Double {
        guard has(.losslessPower, s) else { return 0 }
        let level = s.science.discoveries.filter { $0.def == "rt_superconductor" }.map(\.level).max() ?? 0
        return 0.1 * level
    }

    /// A project a discovery opened before its year (logical qubits open quantum chemistry).
    static func openedEarly(_ id: String, _ s: GameState) -> Bool {
        ScienceCatalog.unlocks.contains { $0.opensProject == id && has($0.unlock, s) }
    }

    static func automationSpeed(_ s: GameState) -> Double { 1 + min(0.15, 0.05 * total(s, .automation)) }

    static let chipsID = "sci:chips"
    static let servingID = "sci:serving"
    static let quantumID = "sci:quantum"

    static var virtualItems: [ResearchItem] {
        [ResearchItem(id: chipsID, name: "Materials and semiconductor discoveries", category: .science, year: 0, cost: 0, prereqs: [],
                      effects: [.chipDesign(0.06)], blurb: "Your science labs' results in materials and chips."),
         ResearchItem(id: servingID, name: "Scientific-software discoveries", category: .science, year: 0, cost: 0, prereqs: [],
                      effects: [.throughput(0.04), .thinkingEfficiency(0.02)], blurb: "Your science labs' inference results."),
         ResearchItem(id: quantumID, name: "Quantum-computing discoveries", category: .science, year: 0, cost: 0, prereqs: [],
                      effects: [.rp(0.02)], blurb: "Your science labs' quantum results.")]
    }

    static func bonusSources(_ s: GameState) -> [(String, Double)] {
        guard !s.science.discoveries.isEmpty else { return [] }
        var out: [(String, Double)] = []
        let chips = min(4, total(s, .chips)), serving = min(4, total(s, .serving)), quantum = min(4, total(s, .quantum))
        if chips > 0 { out.append((chipsID, chips)) }
        if serving > 0 { out.append((servingID, serving)) }
        if quantum > 0 { out.append((quantumID, quantum)) }
        return out
    }

    /// Domain know-how your discoveries add (log10 compute units: 0.1 = one point on the domain's score).
    static func domainKnowHow(_ s: GameState) -> [(CapDomain, Double)] {
        guard !s.science.discoveries.isEmpty else { return [] }
        // At most four points per domain: discoveries sharpen models, they don't replace training them.
        return knowHow({ total(s, $0) }, cap: 0.4)
    }

    /// Domain know-how from effect strengths.
    static func knowHow(_ t: (SciEffect) -> Double, cap: Double) -> [(CapDomain, Double)] {
        var e = [Double](repeating: 0, count: CapDomain.count)
        let m = t(.reasoning), r = t(.robotics), a = t(.automation), med = t(.medical), q = t(.quantum)
        e[CapDomain.math.index] += 0.12 * m + 0.04 * q
        e[CapDomain.reasoning.index] += 0.05 * m
        e[CapDomain.robotics.index] += 0.15 * r + 0.04 * a
        e[CapDomain.science.index] += 0.06 * med + 0.04 * q
        return CapDomain.allCases.compactMap { d in e[d.index] > 0 ? (d, min(cap, e[d.index])) : nil }
    }

    /// Domain know-how a rival lab's models have from science by year `y`: its own science arm's results (lab scale),
    /// results of yours it caught up with on its own, and — for every lab, six months after you chose to publish —
    /// half of what you published. Nothing without your labs (rival science only starts once you have one).
    static func rivalKnowHow(_ s: GameState, lab: String, at y: Double) -> [(CapDomain, Double)] {
        guard !s.science.labs.isEmpty || !s.science.discoveries.isEmpty else { return [] }
        var t: [SciEffect: Double] = [:]
        for r in s.science.rivals where r.lab == lab && r.date.decimalYear <= y {
            guard let d = ScienceCatalog.projectByID[r.def] else { continue }
            t[ScienceCatalog.effect(d), default: 0] += d.size * 0.35
        }
        for d in s.science.discoveries {
            guard let def = d.projectDef else { continue }
            if d.sciChoice == .publish, let when = d.choiceDate, when.decimalYear + 0.5 <= y {
                t[ScienceCatalog.effect(def), default: 0] += 0.5 * strength(d)
            } else if d.rivalCaughtUp && d.rivalLab == lab, let when = d.rivalDate, when.decimalYear <= y {
                t[ScienceCatalog.effect(def), default: 0] += def.size * 0.35
            }
        }
        guard !t.isEmpty else { return [] }
        return knowHow({ t[$0] ?? 0 }, cap: 0.25)
    }

    /// Strength behind each product line: discoveries in fields that feed it, and spin-outs.
    static func productStrength(_ productID: String, _ s: GameState) -> Double {
        var t = 0.0
        for d in s.science.discoveries {
            guard let def = d.projectDef else { continue }
            let f = ScienceCatalog.field(def.field)
            var w = 0.0
            switch (f.effect, productID) {
            case (.robotics, "robotics"): w = 1
            case (.automation, "robotics"): w = 0.4
            case (.automation, "operator"): w = 0.6
            case (.medical, "health"), (.medical, "science"): w = 0.7
            case (.chips, "science") where def.field == .materials: w = 0.3
            case (.aerospace, "government"): w = 1
            default: break
            }
            if d.sciChoice == .spinout && f.product == productID { w += 0.6 }
            t += w * strength(d)
        }
        return t
    }

    /// Domain points a product's bars drop by.
    static func productRelief(_ p: ProductDef, _ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 0 }
        return min(8, 3 * productStrength(p.id, s))
    }

    /// Extra pull with buyers.
    static func productPull(_ p: ProductDef, _ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        return 1 + min(0.3, 0.08 * productStrength(p.id, s))
    }

    static func moonshotFactor(_ id: String, _ s: GameState) -> Double {
        guard !s.science.discoveries.isEmpty else { return 1 }
        let t = s.science.discoveries.filter { $0.moonshot == id }.reduce(0) { $0 + strength($1) }
        return 1 + min(0.3, 0.1 * t / 0.35)
    }

    /// What an effect does at a strength, in words with today's numbers.
    static func effectLines(_ e: SciEffect, strength st: Double, _ s: GameState) -> [String] {
        func pct(_ v: Double) -> String { "\(Fmt.trim(v * 100, 1))%" }
        // What renters get: providers pass on a share of the power saving (see `cloudFactor`, `coloFactor`).
        func renters(_ cut: Double) -> String { "cloud rentals −\(pct(0.12 * cut)), colocation −\(pct(0.5 * cut))" }
        switch e {
        case .storage:
            let cut = min(0.1, 0.008 * st)
            return ["battery storage −\(pct(min(0.3, 0.1 * st))) capex", "power bill −\(pct(cut))", renters(cut),
                    "grid-queue waits −\(pct(min(0.25, 0.03 * st)))"]
        case .power:
            let cut = min(0.1, 0.02 * st)
            return ["datacenter power bill −\(pct(cut))", renters(cut), "new campuses built \(pct(min(0.15, 0.04 * st))) faster",
                    "grid-queue waits −\(pct(min(0.25, 0.06 * st)))"]
        case .fusion: return ["commercial fusion available \(Fmt.trim(min(2, 0.8 * st) * 12, 0)) months sooner"]
        case .chips: return ["custom-chip design +\(pct(0.06 * st)) speed and quality"]
        case .reasoning: return ["Mathematics +\(Fmt.trim(1.2 * st, 1)) and Reasoning +\(Fmt.trim(0.5 * st, 1)) on new models"]
        case .robotics: return ["Robotics +\(Fmt.trim(1.5 * st, 1)) on new models", "Robotics Brain bars −\(Fmt.trim(3 * st, 1)) points, pull ×\(Fmt.trim(1 + 0.08 * st, 2))"]
        case .serving: return ["inference throughput +\(pct(0.04 * st))", "thinking tokens −\(pct(0.02 * st))"]
        case .medical: return ["Science +\(Fmt.trim(0.6 * st, 1)) on new models", "Healthcare and Discovery Service bars −\(Fmt.trim(2.1 * st, 1)) points"]
        case .automation: return ["your labs +\(pct(min(0.15, 0.05 * st))) faster", "Computer-Use Operator pull ×\(Fmt.trim(1 + 0.048 * st, 2))", "Robotics +\(Fmt.trim(0.4 * st, 1))"]
        case .quantum: return ["Mathematics and Science +\(Fmt.trim(0.4 * st, 1)) on new models", "research +\(pct(0.02 * st))"]
        case .aerospace: return ["Government & Defence bars −\(Fmt.trim(3 * st, 1)) points, pull ×\(Fmt.trim(1 + 0.08 * st, 2))"]
        case .superconductor:
            let cut = min(0.1, 0.02 * st)
            return ["power bill −\(pct(cut))", renters(cut), "custom-chip design +\(pct(0.06 * st))",
                    "new campuses: PUE −\(Fmt.trim(0.1 * min(1, st / 2.2), 2)) from lossless power delivery"]
        }
    }

    // MARK: Unique breakthroughs

    /// Decision refs for breakthrough reports start with this ("bt|<breakthrough>|<choices>").
    static let breakthroughPrefix = "bt|"

    /// A unique AI breakthrough just finished in your research lab (hook: ResearchLab): write its report and ask what
    /// to do with it — publish (under an open-science policy it's already out), keep it, or license it.
    static func breakthroughFinished(_ s: inout GameState, tech: String) {
        guard let item = ResearchCatalog.byID[tech], item.isExotic, !s.science.breakthroughs.contains(where: { $0.tech == tech }) else { return }
        var b = SciBreakthrough(tech: tech, title: item.name, date: s.date)
        b.report = breakthroughReport(s, item)
        let open = s.publishedTech[tech] != nil
        if open { b.choice = "publish"; b.choiceDate = s.date }
        s.science.breakthroughs.append(b)
        let codes = breakthroughCodes(s, tech: tech, open: open)
        guard !codes.isEmpty else { return }
        let opts = codes.map { DecisionOption(label: breakthroughLabel($0, s), detail: breakthroughDetail($0, tech: tech, s)) }
        Events.addDecision(&s, kind: decisionKind, title: "Breakthrough report: \(item.name)",
                           body: "\(b.report.significance) What next? The full report is on the Science page.",
                           image: "wafer_closeup", options: opts, ref: breakthroughPrefix + "\(b.id.uuidString)|" + codes.joined(separator: ","))
        if let k = s.science.breakthroughs.firstIndex(where: { $0.id == b.id }) { s.science.breakthroughs[k].decision = s.decisions.last?.id }
    }

    /// The follow-ups on offer, the policy's default first: keep (selective, secretive) or nothing more (open).
    static func breakthroughCodes(_ s: GameState, tech: String, open: Bool) -> [String] {
        var out = open ? ["published"] : ["keep", "publish"]
        if let buyer = ResearchLab.licenseBuyers(s, tech: tech).first(where: { !$0.rival }) ?? ResearchLab.licenseBuyers(s, tech: tech).first {
            out.append("license:\(buyer.id)")
        }
        return out.count > 1 ? out : []
    }

    static func breakthroughLabel(_ code: String, _ s: GameState) -> String {
        switch code {
        case "keep": return "Keep it in-house"
        case "publish": return "Publish it"
        case "published": return "It's published: no licence"
        default:
            let id = String(code.dropFirst("license:".count))
            let name = s.competitors.first { $0.id == id }?.def.name ?? BigPlayerCatalog.neutral.first { $0.id == id }?.name ?? id
            return "License it to \(name)"
        }
    }

    static func breakthroughDetail(_ code: String, tech: String, _ s: GameState) -> String {
        switch code {
        case "keep": return "Yours alone: rivals only get it if one of your researchers leaves for them. No licence income."
        case "publish": return "Brand and researchers' respect up; every rival lab reproduces it within about six months (half its effect in their models)."
        case "published": return "Your open-science policy put it out already: rivals will have it in about six months."
        default:
            let id = String(code.dropFirst("license:".count))
            guard let b = ResearchLab.licenseBuyers(s, tech: tech).first(where: { $0.id == id }) else { return "No longer interested." }
            return "\(Fmt.money(b.upfront)) up front and \(Fmt.money(b.royalty))/month for three years.\(b.rival ? " A rival: their next models will use it." : " Not an AI lab: no rival gets it.")"
        }
    }

    /// What the breakthrough means, what it's worth, what it does for your work and how rivals will respond.
    static func breakthroughReport(_ s: GameState, _ item: ResearchItem) -> SciReport {
        var r = SciReport()
        let result = s.researchResults[item.id] ?? 1
        let rarity = Breakthroughs.rarity(item.id)
        r.significance = "\(item.name) (\(rarity.title.lowercased())): \(item.blurb) Your implementation came in at \(Fmt.trim(result, 2))× the idea\(result >= 1.3 ? " — an exceptional result" : (result < 0.8 ? ", below what it could be" : ""))."
        let buyers = ResearchLab.licenseBuyers(s, tech: item.id)
        let effects = item.effectSummary(result: result * Breakthroughs.masteryMultiplier(1)).prefix(3).joined(separator: "; ")
        r.commercial = "For your models: \(effects). \(buyers.isEmpty ? "Nobody is in a position to license it yet." : "\(buyers.count) labs and companies would license it; the best offer is \(Fmt.money(buyers[0].upfront)) up front and \(Fmt.money(buyers[0].royalty))/month for three years.")"
        var impact = ["Every model you train from now on uses it.", "Your team can refine it to mastery II and III on the Research page."]
        if let partner = Breakthroughs.partner(of: item.id), let other = ResearchCatalog.byID[partner] {
            impact.append(s.researched.contains(partner) ? "With \(other.name) it completes a fusion." : "It's half of a fusion: \(other.name) would complete it.")
        }
        r.impact = impact.joined(separator: " ")
        let holders = s.rivalTech.filter { $0.value.contains(item.id) }.keys.sorted().compactMap { id in s.competitors.first { $0.id == id }?.def.name }
        r.competitors = (holders.isEmpty ? "No rival lab has it." : "\(holders.joined(separator: ", ")) \(holders.count == 1 ? "has" : "have") it too.")
            + " Publish it and every rival reproduces it within about six months at half the effect; keep it and it stays yours unless a researcher defects; license it to a rival and their next models use it."
        return r
    }

    static func breakthroughChoiceLabel(_ b: SciBreakthrough) -> String {
        switch b.choice {
        case "publish": "Published"
        case "keep": "Kept in-house"
        case "license": "Licensed to \(b.licensee)"
        default: "Undecided"
        }
    }

    static func resolveBreakthrough(_ s: inout GameState, _ dec: Decision, option: Int) {
        let parts = dec.ref.dropFirst(breakthroughPrefix.count).split(separator: "|").map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[0]) else { return }
        let codes = parts[1].split(separator: ",").map(String.init)
        guard codes.indices.contains(option) else { return }
        if let why = applyBreakthrough(&s, id, codes[option]) {
            Sim.news(&s, "Breakthrough follow-up didn't go through", "\(why) It stays in-house.", .research, good: false)
            if let k = s.science.breakthroughs.firstIndex(where: { $0.id == id }), s.science.breakthroughs[k].choice.isEmpty {
                s.science.breakthroughs[k].choice = "keep"
                s.science.breakthroughs[k].choiceDate = s.date
            }
        }
    }

    /// Apply a breakthrough follow-up. Returns why it can't be done.
    @discardableResult
    static func applyBreakthrough(_ s: inout GameState, _ id: UUID, _ code: String) -> String? {
        guard let k = s.science.breakthroughs.firstIndex(where: { $0.id == id }) else { return "Unknown breakthrough." }
        let b = s.science.breakthroughs[k]
        switch code {
        case "published":
            return nil
        case "keep":
            guard b.choice.isEmpty else { return "Already decided." }
            s.science.breakthroughs[k].choice = "keep"
        case "publish":
            guard b.choice.isEmpty else { return "Already decided." }
            s.publishedTech[b.tech] = s.date
            s.brand = min(100, s.brand + 1.5)
            Stakeholders.move(&s, ["researchers": 2], "Published a unique breakthrough: \(b.title)")
            s.science.breakthroughs[k].choice = "publish"
            Sim.news(&s, "Your \(b.title) paper goes viral", "Open science wins you fans — and every rival lab will have reproduced it within about six months.", .research, good: true)
        default:
            guard code.hasPrefix("license:") else { return "Unknown choice." }
            let buyer = String(code.dropFirst("license:".count))
            let offer = ResearchLab.licenseBuyers(s, tech: b.tech).first { $0.id == buyer }
            if let why = s.licenseExotic(b.tech, to: buyer) { return why }
            s.science.breakthroughs[k].licensee = offer?.name ?? buyer
            s.science.breakthroughs[k].upfront = offer?.upfront ?? 0
            if s.science.breakthroughs[k].choice.isEmpty { s.science.breakthroughs[k].choice = "license" }
        }
        s.science.breakthroughs[k].choiceDate = s.date
        return nil
    }

    // MARK: Views and history

    struct HistoryEntry: Identifiable {
        var id: String
        var date: Date
        var title: String
        var detail: String
        var symbol: String
        var kind: String
    }

    /// Kinds of company-history entry, for the timeline's filters and colours.
    static let historyKinds: [(kind: String, label: String)] = [
        ("company", "Company"), ("launch", "Launches"), ("training", "Training"), ("milestone", "Milestones"),
        ("discovery", "Discoveries"), ("breakthrough", "Breakthroughs"), ("programme", "Programmes"), ("finance", "Deals"),
    ]

    /// The company's history, oldest first: one timeline merged from what the game already records — company stages,
    /// funding rounds, the IPO and acquisitions; model launches that set a new best; training firsts; milestones you
    /// reached first; lab discoveries, commercialisations and technologies unlocked; unique AI breakthroughs; government
    /// programmes (`AdvancedProjects.historyEntries`). Entries are deduplicated by ID, so a source merged twice shows once.
    static func companyHistory(_ s: GameState) -> [HistoryEntry] {
        var out: [HistoryEntry] = []
        // The company
        for (stage, date) in s.progression.reached.sorted(by: { $0.key < $1.key }) where stage > 0 && !s.progression.credited.contains(stage) {
            guard let st = CompanyStage(rawValue: stage) else { continue }
            out.append(HistoryEntry(id: "st|\(stage)", date: date, title: "Became a \(st.title.lowercased()) company", detail: st.blurb, symbol: st.symbol, kind: "company"))
        }
        for r in s.rounds where r.amount > 0 {
            let ipo = r.name == "IPO"
            out.append(HistoryEntry(id: "r|\(r.id)", date: r.date, title: ipo ? "Went public: \(Fmt.money(r.amount)) raised" : "Raised \(Fmt.money(r.amount)) (\(r.name))",
                                    detail: ipo ? "Valued at \(Fmt.money(r.preMoney + r.amount))" : "Led by \(r.lead) at \(Fmt.money(r.preMoney)) pre-money",
                                    symbol: ipo ? "bell.fill" : "banknote.fill", kind: "finance"))
        }
        for c in s.competitors where c.acquiredBy == "player" {
            guard let when = c.exitDate else { continue }
            out.append(HistoryEntry(id: "acq|\(c.id)", date: when, title: "Acquired \(c.def.name)", detail: "Its people, models and techniques are yours", symbol: "building.2.fill", kind: "finance"))
        }
        // Models
        for l in s.launches where l.previousBest.map({ l.index > $0 }) ?? true {
            out.append(HistoryEntry(id: "ln|\(l.id)", date: l.date, title: l.previousBest == nil ? "First launch: \(l.modelName)" : "Launched \(l.modelName)",
                                    detail: "#\(l.rank) worldwide, Intelligence Index \(Fmt.score(l.index))\(l.previousBest.map { " (+\(Fmt.trim(l.index - $0, 1)) on your best)" } ?? "")",
                                    symbol: l.rank == 1 ? "crown.fill" : "paperplane.fill", kind: "launch"))
        }
        for f in s.trainingFirsts where !f.quiet {
            out.append(HistoryEntry(id: "t|\(f.id)", date: f.date, title: f.title, detail: f.model.isEmpty ? f.detail : "\(f.model)\(f.detail.isEmpty ? "" : " · \(f.detail)")", symbol: f.symbol, kind: "training"))
        }
        for w in s.milestoneWins where w.labID == "player" && !w.history {
            let m = MilestoneCatalog.byID[w.id]
            out.append(HistoryEntry(id: "ms|\(w.id)", date: w.date, title: "First to \(m?.title.lowercased() ?? w.id)", detail: w.model, symbol: m?.symbol ?? "flag.fill", kind: "milestone"))
        }
        // Science
        for d in s.science.discoveries {
            let f = d.projectDef.map { ScienceCatalog.field($0.field) }
            out.append(HistoryEntry(id: "d|\(d.id)", date: d.date, title: "Discovery: \(d.title)", detail: f?.name ?? "", symbol: f?.symbol ?? "atom", kind: "discovery"))
            if let c = d.commercialised {
                out.append(HistoryEntry(id: "c|\(d.id)", date: c, title: "Commercialised: \(d.title)", detail: f?.name ?? "", symbol: "shippingbox.fill", kind: "discovery"))
            }
        }
        for u in ScienceCatalog.unlocks {
            guard let when = unlockDate(u.unlock, s) else { continue }
            out.append(HistoryEntry(id: "u|\(u.unlock.rawValue)", date: when, title: "New technology: \(u.title)", detail: u.detail, symbol: "lock.open.fill", kind: "discovery"))
        }
        for lab in s.science.labs {
            out.append(HistoryEntry(id: "l|\(lab.id)", date: lab.ready, title: "Opened the \(lab.name)", detail: siteName(lab.site), symbol: lab.def.symbol, kind: "discovery"))
        }
        for b in s.science.breakthroughs {
            out.append(HistoryEntry(id: "bt|\(b.id)", date: b.date, title: "Unique breakthrough: \(b.title)",
                                    detail: b.choice.isEmpty ? "Report waiting for a decision" : breakthroughChoiceLabel(b), symbol: "sparkles", kind: "breakthrough"))
        }
        // Government programmes (their contracts, deliveries, discoveries and clearances file under one kind here)
        for var e in AdvancedProjects.historyEntries(s) {
            e.kind = "programme"
            out.append(e)
        }
        var seen = Set<String>()
        return out.filter { $0.date <= s.date && seen.insert($0.id).inserted }.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    /// Projects a lab could start now (by field fit, then difficulty), including ones a discovery opened early.
    static func available(_ lab: SciLab, _ s: GameState) -> [SciProjectDef] {
        let taken = Set(s.science.projects.filter { $0.status == .running || $0.status == .done || $0.status == .stalled }.map(\.def))
        return ScienceCatalog.projects.filter { lab.def.runs($0.field) && ($0.year <= s.year || openedEarly($0.id, s)) && !taken.contains($0.id) && retryBlocker($0.id, s) == nil }
            .sorted { (lab.def.primary.contains($0.field) ? 0 : 1, $0.difficulty) < (lab.def.primary.contains($1.field) ? 0 : 1, $1.difficulty) }
    }

    /// After a dead end the team needs new ideas before trying the same thing again (180 days).
    static func retryBlocker(_ id: String, _ s: GameState) -> Date? {
        guard let last = s.science.projects.filter({ $0.def == id && $0.status == .failed }).compactMap(\.ended).max() else { return nil }
        let ok = GameCalendar.addDays(last, 180)
        return ok > s.date ? ok : nil
    }

    /// 3.8: a project stopped after its discovery can be restarted at the stage it stopped at, after the same 180 days.
    static func resumeBlocker(_ p: SciProject, _ s: GameState) -> Date? {
        guard p.status == .stalled, let ended = p.ended else { return nil }
        let ok = GameCalendar.addDays(ended, 180)
        return ok > s.date ? ok : nil
    }

    /// Stalled projects of this def that are waiting to be resumed.
    static func stalledProject(_ defID: String, _ s: GameState) -> SciProject? {
        s.science.projects.last { $0.def == defID && $0.status == .stalled }
    }

    /// Discoveries waiting for a follow-up decision.
    static func pending(_ s: GameState) -> [SciDiscovery] { s.science.discoveries.filter { $0.choice.isEmpty } }
}

extension SciProject {
    func labName(_ s: GameState) -> String { s.science.labs.first { $0.id == lab }?.name ?? "your lab" }
    func labImage(_ s: GameState) -> String? { s.science.labs.first { $0.id == lab }?.def.image }
}

// MARK: - Player actions

extension GameState {
    /// Build a laboratory. Returns an error message, or nil on success.
    mutating func buildLab(_ kind: LabKind, site: String, staff: Int = 8) -> String? {
        guard ScienceCatalog.siteByID[site] != nil else { return "Pick a city." }
        if science.labs.count >= 2, let why = Progression.blocker(self, .institutes) { return why }   // 3.8: Hyperscaler
        let def = ScienceCatalog.lab(kind)
        let cost = Science.capex(kind, site: site, self)
        let hires = Double(staff) * Science.salary(site, self) * 0.15
        guard cash >= cost + hires else { return "The \(def.name) costs \(Fmt.money(cost)) to build and \(Fmt.money(hires)) to recruit its first team; you have \(Fmt.money(cash))." }
        let city = Science.city(Science.site(site)).name
        let days = Int(Double(def.buildDays) * (Science.isHome(site, self) ? 0.9 : 1))
        var lab = SciLab(kind: kind, site: site, built: date, ready: GameCalendar.addDays(date, days), capex: cost, name: "\(city) \(def.name)")
        let same = science.labs.filter { $0.kind == kind && $0.site == site }.count
        if same > 0 { lab.name += " \(same + 1)" }
        var skill = 0.0
        for n in 0..<staff { skill += Science.hireSkill(lab, self, n: n) }
        lab.staff = staff
        lab.skill = staff > 0 ? skill / Double(staff) : 55
        cash -= cost + hires
        month.capex += cost
        month.costOther += hires
        science.spentBuild += cost + hires
        science.labs.append(lab)
        Sim.news(&self, "Construction starts: \(lab.name)", "\(Fmt.money(cost))\(Science.isHome(site, self) ? " (home incentives and partners included)" : ""). \(staff) \(def.staffTitle) hired; the lab opens \(lab.ready.gameMonth).",
                 .research, image: def.image, good: true)
        return nil
    }

    mutating func upgradeLab(_ id: UUID) -> String? {
        guard let i = science.labs.firstIndex(where: { $0.id == id }) else { return "No such lab." }
        let lab = science.labs[i]
        guard lab.upgradeReady == nil else { return "An upgrade is already under way." }
        guard lab.equipment < Science.maxEquipment else { return "Already at the best equipment money can buy." }
        let cost = Science.upgradeCost(lab, self)
        guard cash >= cost else { return "The upgrade costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.capex += cost
        science.spentBuild += cost
        science.labs[i].capex += cost
        science.labs[i].upgradeReady = GameCalendar.addDays(max(date, lab.ready), 75)
        return nil
    }

    mutating func hireScientists(_ id: UUID, _ n: Int) -> String? {
        guard let i = science.labs.firstIndex(where: { $0.id == id }) else { return "No such lab." }
        let lab = science.labs[i]
        let room = Science.staffCap(lab) - lab.staff
        guard room > 0 else { return "\(lab.name) is full (\(lab.staff) people)." }
        let k = min(n, room)
        let fee = Double(k) * Science.salary(lab.site, self) * 0.15
        guard cash >= fee else { return "Recruiting costs \(Fmt.money(fee)); you have \(Fmt.money(cash))." }
        var total = lab.skill * Double(lab.staff)
        for j in 0..<k { total += Science.hireSkill(lab, self, n: lab.staff + j) }
        cash -= fee
        month.costOther += fee
        science.spentRun += fee
        science.labs[i].staff += k
        science.labs[i].skill = total / Double(lab.staff + k)
        return nil
    }

    mutating func releaseScientists(_ id: UUID, _ n: Int) {
        guard let i = science.labs.firstIndex(where: { $0.id == id }) else { return }
        let k = min(n, science.labs[i].staff)
        guard k > 0 else { return }
        let severance = Double(k) * Science.salary(science.labs[i].site, self) / 4
        cash -= severance
        month.costOther += severance
        science.spentRun += severance
        science.labs[i].staff -= k
    }

    mutating func closeLab(_ id: UUID) {
        guard let i = science.labs.firstIndex(where: { $0.id == id }) else { return }
        let lab = science.labs[i]
        for j in science.projects.indices where science.projects[j].lab == id && science.projects[j].status == .running {
            science.projects[j].status = science.projects[j].discovery == nil ? .cancelled : .stalled
            science.projects[j].ended = date
            Science.stopAtLabScale(&self, project: science.projects[j])
        }
        let severance = Double(lab.staff) * Science.salary(lab.site, self) / 4
        cash -= severance
        month.costOther += severance
        science.labs.remove(at: i)
        Sim.news(&self, "\(lab.name) closes", "Its \(lab.staff) \(lab.def.staffTitle) leave with \(Fmt.money(severance)) in severance. Discoveries and patents stay yours.", .research, good: false)
    }

    /// Start a research project in a lab. Returns an error message, or nil on success.
    mutating func startScienceProject(_ defID: String, lab id: UUID, agents: Int = 0, compute: Int = 0) -> String? {
        guard let d = ScienceCatalog.projectByID[defID] else { return "Unknown project." }
        guard let lab = science.labs.first(where: { $0.id == id }) else { return "No such lab." }
        guard lab.isReady(date) else { return "\(lab.name) opens \(lab.ready.gameMonth)." }
        guard lab.def.runs(d.field) else { return "The \(lab.def.name) can't do \(ScienceCatalog.field(d.field).name.lowercased())." }
        guard d.year <= year || Science.openedEarly(defID, self) else { return "\(d.name) isn't possible before \(Int(d.year))." }
        guard !science.projects.contains(where: { $0.def == defID && ($0.status == .running || $0.status == .done || $0.status == .stalled) }) else { return "You've already done or are doing \(d.name)." }
        if let when = Science.retryBlocker(defID, self) { return "\(d.name) hit a dead end; the team needs new ideas before \(when.gameShort)." }
        guard Science.active(lab, self).count < Science.capacity(lab) else { return "\(lab.name) is running \(Science.capacity(lab)) projects already; upgrade its equipment for more room." }
        var p = SciProject(def: defID, lab: id, started: date, agents: clamp(agents, 0, Science.agentMax), compute: clamp(compute, 0, 3), stageStarted: date)
        let c = Science.stageCost(p, .hypothesis, self)
        guard cash >= c else { return "The first stage costs \(Fmt.money(c)); you have \(Fmt.money(cash))." }
        p.spent = c
        Science.book(&self, c)
        science.projects.append(p)
        Sim.news(&self, "Project started: \(d.name)", "\(d.pitch) In the \(lab.name). \(d.speculative ? "Speculative: expect dead ends." : "")", .research, image: lab.def.image)
        return nil
    }

    /// 3.8: restart a stalled project at its stage, in `lab` (or its old lab). Costs the stage again.
    mutating func resumeScienceProject(_ id: UUID, lab labID: UUID? = nil) -> String? {
        guard let i = science.projects.firstIndex(where: { $0.id == id }), science.projects[i].status == .stalled else { return "Nothing to resume." }
        let p = science.projects[i]
        guard let d = p.projectDef else { return "Unknown project." }
        if let when = Science.resumeBlocker(p, self) { return "The team needs new ideas before restarting \(d.name): \(when.gameShort)." }
        guard let lab = science.labs.first(where: { $0.id == (labID ?? p.lab) }) ?? science.labs.first(where: { $0.id == p.lab }) else {
            return "Pick a lab to run it in."
        }
        guard lab.isReady(date) else { return "\(lab.name) opens \(lab.ready.gameMonth)." }
        guard lab.def.runs(d.field) else { return "The \(lab.def.name) can't do \(ScienceCatalog.field(d.field).name.lowercased())." }
        guard Science.active(lab, self).count < Science.capacity(lab) else { return "\(lab.name) is running \(Science.capacity(lab)) projects already; upgrade its equipment for more room." }
        let c = Science.stageCost(p, p.currentStage, self)
        guard cash >= c else { return "Restarting costs \(Fmt.money(c)); you have \(Fmt.money(cash))." }
        science.projects[i].status = .running
        science.projects[i].lab = lab.id
        science.projects[i].ended = nil
        science.projects[i].progress = 0
        science.projects[i].attempts = 0
        science.projects[i].stageStarted = date
        science.projects[i].spent += c
        if let disc = p.discovery, let k = science.discoveries.firstIndex(where: { $0.id == disc }) { science.discoveries[k].labScaleOnly = false }
        Science.book(&self, c)
        Sim.news(&self, "Project resumed: \(d.name)", "Back at \(Science.stageName(p.currentStage, d.field).lowercased()) in the \(lab.name), with fresh ideas. The stage costs \(Fmt.money(c)) again.", .research, image: lab.def.image)
        return nil
    }

    mutating func setProjectSupport(_ id: UUID, agents: Int, compute: Int) {
        guard let i = science.projects.firstIndex(where: { $0.id == id }) else { return }
        science.projects[i].agents = clamp(agents, 0, Science.agentMax)
        science.projects[i].compute = clamp(compute, 0, 3)
    }

    /// Stop a project. After a discovery it stays a lab-scale result — never better than a dead end at the same point.
    mutating func cancelScienceProject(_ id: UUID) {
        guard let i = science.projects.firstIndex(where: { $0.id == id }), science.projects[i].status == .running else { return }
        science.projects[i].status = science.projects[i].discovery == nil ? .cancelled : .stalled
        science.projects[i].ended = date
        Science.stopAtLabScale(&self, project: science.projects[i])
    }

    /// Answer a discovery's follow-up from the report (resolves its inbox item). Returns why it can't be taken.
    mutating func chooseDiscoveryFollowUp(_ id: UUID, _ c: SciChoice) -> String? {
        guard let d = science.discoveries.first(where: { $0.id == id }) else { return "Unknown discovery." }
        if let dec = d.decision.flatMap({ did in decisions.first { $0.id == did } }) {
            let parts = dec.ref.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            let codes = parts.count >= 2 ? parts[1].split(separator: ",").map(String.init) : []
            let target = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
            guard let option = codes.firstIndex(of: c.rawValue) else { return "That isn't one of this report's options." }
            if let why = Science.blocker(self, d, c, moonshot: target) { return why }
            resolveDecision(dec.id, option: option)
            return nil
        }
        return Science.apply(&self, discovery: id, c)
    }

    /// Answer a unique breakthrough's report ("keep", "publish" or "license:<buyer>").
    mutating func chooseBreakthrough(_ id: UUID, _ code: String) -> String? {
        guard let b = science.breakthroughs.first(where: { $0.id == id }) else { return "Unknown breakthrough." }
        if let dec = b.decision.flatMap({ did in decisions.first { $0.id == did } }) {
            let codes = dec.ref.dropFirst(Science.breakthroughPrefix.count).split(separator: "|").last.map { $0.split(separator: ",").map(String.init) } ?? []
            guard let option = codes.firstIndex(of: code) else { return "That isn't one of this report's options." }
            if code.hasPrefix("license:"), !ResearchLab.licenseBuyers(self, tech: b.tech).contains(where: { "license:\($0.id)" == code }) { return "They're no longer interested." }
            resolveDecision(dec.id, option: option)
            return nil
        }
        return Science.applyBreakthrough(&self, id, code)
    }
}

extension Science {
    /// A project stopped after its discovery (cancelled, or its lab closed): lab scale only, capped at half the full
    /// effect like a dead end at prototype — and without the dead end's lessons for the field.
    static func stopAtLabScale(_ s: inout GameState, project p: SciProject) {
        guard let disc = p.discovery, let k = s.science.discoveries.firstIndex(where: { $0.id == disc }) else { return }
        s.science.discoveries[k].labScaleOnly = true
        s.science.discoveries[k].level = min(s.science.discoveries[k].level, 0.5)
    }
}
