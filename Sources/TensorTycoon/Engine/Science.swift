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
    var id = UUID()
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
    var id = UUID()
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
    var id = UUID()
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
    var id = UUID()
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
    var id = UUID()
    var lab: String
    var def: String
    var date: Date
    /// It beat one of your running projects to the result.
    var scoopedYou = false
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
        var speed = staffFactor(lab, active: active(lab, s).count) * automationSpeed(s)
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
            s.science.projects[i].progress = 0
            s.science.projects[i].stageStarted = s.date
            let rerunCost = stageCost(p, st, s) * 0.7
            s.science.projects[i].spent += rerunCost
            book(&s, rerunCost)
            Sim.news(&s, "\(d.name): \(stageName.lowercased()) failed, rerunning",
                     "\(rerunWhy(st, d, key: key)) The team reruns it (attempt \(p.attempts + 2), \(Fmt.money(rerunCost))). Odds were \(Int((o * 100).rounded()))%.",
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
            s.science.discoveries[k].level = max(s.science.discoveries[k].level, levels[st] ?? s.science.discoveries[k].level)
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
        let f = ScienceCatalog.field(d.field)
        var disc = SciDiscovery(def: d.id, project: p.id, date: s.date, title: d.headline)
        disc.scooped = p.scooped
        bumpMomentum(&s, d.field, 0.04)
        disc.report = report(s, d, scooped: p.scooped, project: p)
        let options = choices(s, d)
        var opts: [DecisionOption] = []
        for c in options { opts.append(DecisionOption(label: c.label, detail: choiceDetail(c, d, s, scooped: !p.scooped.isEmpty))) }
        let ref = "\(disc.id.uuidString)|" + options.map(\.rawValue).joined(separator: ",")
        Events.addDecision(&s, kind: decisionKind, title: "Discovery: \(d.headline)",
                           body: "\(f.name), \(p.labName(s)). \(disc.report.significance) What next? The full report is on the Science page.",
                           image: p.labImage(s), options: opts, ref: ref)
        disc.decision = s.decisions.last?.id
        s.science.discoveries.append(disc)
        s.science.projects[i].discovery = disc.id
        s.brand = min(100, s.brand + (d.speculative ? 1.5 : 0.5))
        Stakeholders.move(&s, ["researchers": d.speculative ? 2 : 1], "A reproduced discovery: \(d.headline)")
        Sim.news(&s, "🔬 Discovery: \(d.headline)", "\(disc.report.significance) \(disc.report.commercial)", .research, image: p.labImage(s), important: true, good: true)
        Alerts.raise(&s, .milestone, key: "sci|disc|\(disc.id)", title: "Discovery: \(d.headline)", body: "Read the report and choose what to do with it.",
                     screen: .science, celebrate: true, cooldown: 0)
    }

    static func commercialise(_ s: inout GameState, _ i: Int) {
        let p = s.science.projects[i]
        guard let d = p.projectDef else { return }
        s.science.projects[i].status = .done
        s.science.projects[i].ended = s.date
        if let disc = p.discovery, let k = s.science.discoveries.firstIndex(where: { $0.id == disc }) {
            s.science.discoveries[k].level = 1
            s.science.discoveries[k].commercialised = s.date
        }
        s.brand = min(100, s.brand + 1)
        Sim.news(&s, "Commercialised: \(d.headline)",
                 "\(d.name) made it through all \(stages(d.field).count) stages in \(GameCalendar.daysBetween(p.started, s.date)) days and \(Fmt.money(p.spent)). Its effects now apply in full: \(effectLines(ScienceCatalog.field(d.field).effect, strength: d.size, s).joined(separator: "; ")).",
                 .research, image: p.labImage(s), important: true, good: true)
        Alerts.raise(&s, .milestone, key: "sci|comm|\(p.id)", title: "Commercialised: \(d.headline)", body: "\(d.name) is in production.",
                     screen: .science, celebrate: true, cooldown: 0)
    }

    static func bumpMomentum(_ s: inout GameState, _ f: SciField, _ v: Double) {
        s.science.momentum[f.rawValue] = min(0.12, (s.science.momentum[f.rawValue] ?? 0) + v)
    }

    /// The follow-ups on offer for a discovery (patent first: it's what happens if you don't answer).
    static func choices(_ s: GameState, _ d: SciProjectDef) -> [SciChoice] {
        var out: [SciChoice] = [.patent, .secret, .publish, .spinout]
        if feedable(s, d) != nil { out.append(.moonshot) }
        return out
    }

    /// A running or offered moonshot this result can feed.
    static func feedable(_ s: GameState, _ d: SciProjectDef) -> String? {
        let ids = ScienceCatalog.field(d.field).moonshots
        return s.moonshots.first { ids.contains($0.id) && ($0.status == .running || $0.status == .offered) }?.id
    }

    /// Monthly royalties a patent on this result would earn today.
    static func royalty(_ d: SciProjectDef, level: Double, _ s: GameState, scooped: Bool) -> Double {
        120_000 * eraScale(s.year) * d.size * level * (scooped ? 0.5 : 1)
    }

    static func spinoutCash(_ d: SciProjectDef, _ s: GameState, scooped: Bool) -> Double {
        royalty(d, level: 1, s, scooped: scooped) * 14
    }

    static func choiceDetail(_ c: SciChoice, _ d: SciProjectDef, _ s: GameState, scooped: Bool) -> String {
        let f = ScienceCatalog.field(d.field)
        switch c {
        case .patent:
            return "About \(Fmt.money(royalty(d, level: 0.35, s, scooped: scooped)))/month in licence fees now, rising to \(Fmt.money(royalty(d, level: 1, s, scooped: scooped))) if it's commercialised. Rivals license it or design around it in a few years."
        case .secret:
            return scooped ? "A rival has already published it: secrecy buys little now." : "Keep the edge to yourself: its effects are 20% stronger until a rival gets there on its own (typically 1½–3½ years). No licence income."
        case .publish:
            return "Submit it to the next conference: researchers' respect and brand up, a shot at best paper. Everyone can build on it; you can't patent it."
        case .spinout:
            if let p = ProductLines.byID[f.product] {
                return "A spin-out builds products on it with you: \(Fmt.money(spinoutCash(d, s, scooped: scooped))) for the licence, and \(p.name) opens sooner and sells better."
            }
            return "A venture-backed spin-out licenses it exclusively: \(Fmt.money(spinoutCash(d, s, scooped: scooped))) up front."
        case .moonshot:
            let m = feedable(s, d).flatMap { MoonshotCatalog.byID[$0] }
            return "Hand it to the \(m?.name ?? "moonshot") team: its odds improve by about \(Int((0.1 * d.size * 100).rounded())) points of every hundred. No licence income."
        }
    }

    // MARK: The report

    static func report(_ s: GameState, _ d: SciProjectDef, scooped: String, project p: SciProject) -> SciReport {
        let f = ScienceCatalog.field(d.field)
        var r = SciReport()
        let reruns = p.log.filter { $0.outcome == "rerun" }.count
        let days = GameCalendar.daysBetween(p.started, s.date)
        r.significance = "\(d.headline). \(d.pitch) It reproduced after \(days) days\(reruns > 0 ? " and \(reruns) rerun\(reruns == 1 ? "" : "s")" : " with no reruns"). \(d.basis)"
        if !scooped.isEmpty { r.significance += " \(labName(s, scooped)) published the same result first, so the priority is theirs." }
        let now = effectLines(f.effect, strength: d.size * 0.35, s)
        let full = effectLines(f.effect, strength: d.size, s)
        r.commercial = "Now, at lab scale: \(now.joined(separator: "; ")). If it makes it through prototype, validation\(f.computational ? "" : ", manufacturing") and commercialisation: \(full.joined(separator: "; "))."
        // Impact on your other work.
        var impact: [String] = []
        let same = s.science.projects.filter { $0.status == .running && $0.id != p.id && $0.projectDef?.field == d.field }
        if !same.isEmpty { impact.append("Builds on itself: +4 points on every stage of \(same.compactMap { $0.projectDef?.name }.joined(separator: ", ")).") }
        else { impact.append("Your next \(f.name.lowercased()) project starts with +4 points on every stage.") }
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
            r.competitors = "\(names) work\(rivals.count == 1 ? "s" : "") in this field. If you publish, they'll reproduce it within months; if you patent it, expect licence talks — or a design-around in three to five years; if you keep it secret, they'll likely get there on their own in two or three."
        }
        return r
    }

    static func labName(_ s: GameState, _ lab: String) -> String {
        ScienceCatalog.rivalLabs.first { $0.lab == lab }?.arm ?? s.competitors.first { $0.id == lab }?.def.name ?? lab
    }

    // MARK: Follow-up decisions

    static func resolve(_ s: inout GameState, _ dec: Decision, option: Int) {
        let parts = dec.ref.split(separator: "|").map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[0]) else { return }
        let codes = parts[1].split(separator: ",").compactMap { SciChoice(rawValue: String($0)) }
        guard codes.indices.contains(option) else { return }
        apply(&s, discovery: id, codes[option])
    }

    static func apply(_ s: inout GameState, discovery id: UUID, _ c: SciChoice) {
        guard let k = s.science.discoveries.firstIndex(where: { $0.id == id }), s.science.discoveries[k].choice.isEmpty,
              let d = s.science.discoveries[k].projectDef else { return }
        let f = ScienceCatalog.field(d.field)
        let scooped = !s.science.discoveries[k].scooped.isEmpty
        s.science.discoveries[k].choice = c.rawValue
        s.science.discoveries[k].choiceDate = s.date
        let key = "\(id)"
        let rivals = ScienceCatalog.rivalLabs.filter { r in r.fields.contains(d.field) && s.competitors.contains { $0.id == r.lab && $0.alive } }
        let rival = rivals.isEmpty ? "" : rivals[Int(roll(s, "who|\(key)") * Double(rivals.count)) % rivals.count].lab
        switch c {
        case .patent:
            let n = 2 + Int(roll(s, "licensees|\(key)") * 4)
            s.science.patents.append(SciPatent(discovery: id, title: d.headline, field: d.field, filed: s.date,
                                               expires: GameCalendar.addMonths(s.date, 240), licensees: n))
            s.science.discoveries[k].rivalDate = GameCalendar.addMonths(s.date, 36 + Int(roll(s, "around|\(key)") * 24))
            s.science.discoveries[k].rivalLab = rival
            Sim.news(&s, "Patent filed: \(d.headline)", "\(n) companies take licences. About \(Fmt.money(royalty(d, level: s.science.discoveries[k].level, s, scooped: scooped)))/month now; more if it's commercialised.",
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
        case .spinout:
            let cash = spinoutCash(d, s, scooped: scooped)
            s.cash += cash
            s.month.oneOffIncome += cash
            s.science.spinoutCash += cash
            let p = ProductLines.byID[f.product]
            Sim.news(&s, "Spin-out: \(d.headline)", "A new company licenses it for \(Fmt.money(cash))\(p.map { " and builds \($0.name.lowercased()) products on it with you" } ?? "").",
                     .finance, good: true)
        case .moonshot:
            if let m = feedable(s, d) {
                s.science.discoveries[k].moonshot = m
                Sim.news(&s, "\(d.headline) joins the \(MoonshotCatalog.byID[m]?.name ?? "moonshot") programme",
                         "Your lab hands its result and its people to the moonshot team. Odds up by about \(Int((0.1 * d.size * 100).rounded())) points of every hundred.",
                         .research, good: true)
            }
        }
    }

    /// Submit a discovery to the next conference that can still review it.
    /// Submit a discovery to a conference whose call for papers has closed for everyone else (so it never collides
    /// with the paper the team sends through the call) and whose reviews are still ahead; otherwise it waits for the
    /// next such window (checked daily).
    @discardableResult
    static func publish(_ s: inout GameState, _ d: SciProjectDef, title: String) -> Bool {
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
        // Experience: staff get better at what they do.
        for i in s.science.labs.indices where !active(s.science.labs[i], s).isEmpty {
            s.science.labs[i].skill = min(92, s.science.labs[i].skill + 0.35)
        }
        payRoyalties(&s)
        rivalsCatchUp(&s)
        rivalScience(&s)
    }

    static func payRoyalties(_ s: inout GameState) {
        var total = 0.0
        for i in s.science.patents.indices where s.science.patents[i].expires > s.date {
            let p = s.science.patents[i]
            guard let disc = s.science.discoveries.first(where: { $0.id == p.discovery }), let d = disc.projectDef else { continue }
            let r = royalty(d, level: disc.level, s, scooped: !disc.scooped.isEmpty) * (p.designedAround ? 0.5 : 1)
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
            guard roll(s, "rival|\(key)") < 0.035 * r.appetite else { continue }
            let mine = Set(s.science.discoveries.map(\.def))
            let theirs = Set(s.science.rivals.map(\.def))
            let running = s.science.projects.filter { $0.status == .running && $0.stage <= SciStage.reproduction.rawValue && $0.scooped.isEmpty }
                .compactMap { $0.projectDef }.filter { r.fields.contains($0.field) && !theirs.contains($0.id) }
            var pick: SciProjectDef? = nil
            if !running.isEmpty && roll(s, "race|\(key)") < 0.5 {
                pick = running[Int(roll(s, "racepick|\(key)") * Double(running.count)) % running.count]
            } else {
                let pool = ScienceCatalog.projects.filter { r.fields.contains($0.field) && $0.year <= s.year - 0.5 && !mine.contains($0.id) && !theirs.contains($0.id) }
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
    //   power bill            Sim.dailyCosts and Power.settle multiply by `powerFactor`
    //   battery storage capex Power.quote multiplies battery upfront by `storageCapexFactor`
    //   fusion availability   PowerKind.available / EnergySource.available move earlier by `fusionPullIn` years
    //   chips, serving, R&D   virtual research items "sci:chips", "sci:serving", "sci:quantum" (bonuses: chipDesign,
    //                         throughput + thinkingEfficiency, rp) via `bonusSources`
    //   model domains         Capabilities.researchDomains adds `domainKnowHow`
    //   product lines         ProductLines.status (bars) and updateShares (pull) use `productRelief` / `productPull`
    //   moonshots             Moonshots.chance multiplies by `moonshotFactor`

    /// A discovery's strength today: its size × how far it got × secrecy and priority.
    static func strength(_ d: SciDiscovery) -> Double {
        guard let def = d.projectDef else { return 0 }
        let secret = d.sciChoice == .secret && !d.rivalCaughtUp ? 1.2 : 1
        return def.size * d.level * secret * (d.scooped.isEmpty ? 1 : 0.8)
    }

    /// Total strength of your discoveries with an effect kind.
    static func total(_ s: GameState, _ e: SciEffect) -> Double {
        var t = 0.0
        for d in s.science.discoveries {
            guard let def = d.projectDef, ScienceCatalog.field(def.field).effect == e || (e == .power && def.id == "rt_superconductor") || (e == .chips && def.id == "rt_superconductor") else { continue }
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
        var e = [Double](repeating: 0, count: CapDomain.count)
        let m = total(s, .reasoning), r = total(s, .robotics), a = total(s, .automation), med = total(s, .medical), q = total(s, .quantum)
        e[CapDomain.math.index] += 0.12 * m + 0.04 * q
        e[CapDomain.reasoning.index] += 0.05 * m
        e[CapDomain.robotics.index] += 0.15 * r + 0.04 * a
        e[CapDomain.science.index] += 0.06 * med + 0.04 * q
        // At most four points per domain: discoveries sharpen models, they don't replace training them.
        return CapDomain.allCases.compactMap { d in e[d.index] > 0 ? (d, min(0.4, e[d.index])) : nil }
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
        switch e {
        case .storage: return ["battery storage −\(pct(min(0.3, 0.1 * st))) capex", "power bill −\(pct(min(0.1, 0.008 * st)))"]
        case .power: return ["datacenter power bill −\(pct(min(0.1, 0.02 * st)))"]
        case .fusion: return ["commercial fusion available \(Fmt.trim(min(2, 0.8 * st) * 12, 0)) months sooner"]
        case .chips: return ["custom-chip design +\(pct(0.06 * st)) speed and quality"]
        case .reasoning: return ["Mathematics +\(Fmt.trim(1.2 * st, 1)) and Reasoning +\(Fmt.trim(0.5 * st, 1)) on new models"]
        case .robotics: return ["Robotics +\(Fmt.trim(1.5 * st, 1)) on new models", "Robotics Brain bars −\(Fmt.trim(3 * st, 1)) points, pull ×\(Fmt.trim(1 + 0.08 * st, 2))"]
        case .serving: return ["inference throughput +\(pct(0.04 * st))", "thinking tokens −\(pct(0.02 * st))"]
        case .medical: return ["Science +\(Fmt.trim(0.6 * st, 1)) on new models", "Healthcare and Discovery Service bars −\(Fmt.trim(2.1 * st, 1)) points"]
        case .automation: return ["your labs +\(pct(min(0.15, 0.05 * st))) faster", "Computer-Use Operator pull ×\(Fmt.trim(1 + 0.048 * st, 2))", "Robotics +\(Fmt.trim(0.4 * st, 1))"]
        case .quantum: return ["Mathematics and Science +\(Fmt.trim(0.4 * st, 1)) on new models", "research +\(pct(0.02 * st))"]
        case .aerospace: return ["Government & Defence bars −\(Fmt.trim(3 * st, 1)) points, pull ×\(Fmt.trim(1 + 0.08 * st, 2))"]
        case .superconductor: return ["power bill −\(pct(min(0.1, 0.02 * st)))", "custom-chip design +\(pct(0.06 * st))"]
        }
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

    /// The company history: training firsts and science results, oldest first.
    static func companyHistory(_ s: GameState) -> [HistoryEntry] {
        var out: [HistoryEntry] = []
        for f in s.trainingFirsts where !f.quiet {
            out.append(HistoryEntry(id: "t|\(f.id)", date: f.date, title: f.title, detail: f.model.isEmpty ? f.detail : "\(f.model)\(f.detail.isEmpty ? "" : " · \(f.detail)")", symbol: f.symbol, kind: "training"))
        }
        for d in s.science.discoveries {
            let f = d.projectDef.map { ScienceCatalog.field($0.field) }
            out.append(HistoryEntry(id: "d|\(d.id)", date: d.date, title: "Discovery: \(d.title)", detail: f?.name ?? "", symbol: f?.symbol ?? "atom", kind: "discovery"))
            if let c = d.commercialised {
                out.append(HistoryEntry(id: "c|\(d.id)", date: c, title: "Commercialised: \(d.title)", detail: f?.name ?? "", symbol: "shippingbox.fill", kind: "commercial"))
            }
        }
        for lab in s.science.labs {
            out.append(HistoryEntry(id: "l|\(lab.id)", date: lab.ready, title: "Opened the \(lab.name)", detail: siteName(lab.site), symbol: lab.def.symbol, kind: "lab"))
        }
        return out.filter { $0.date <= s.date }.sorted { $0.date < $1.date }
    }

    /// Projects a lab could start now (by field fit, then difficulty).
    static func available(_ lab: SciLab, _ s: GameState) -> [SciProjectDef] {
        let taken = Set(s.science.projects.filter { $0.status == .running || $0.status == .done || $0.status == .stalled }.map(\.def))
        return ScienceCatalog.projects.filter { lab.def.runs($0.field) && $0.year <= s.year && !taken.contains($0.id) && retryBlocker($0.id, s) == nil }
            .sorted { (lab.def.primary.contains($0.field) ? 0 : 1, $0.difficulty) < (lab.def.primary.contains($1.field) ? 0 : 1, $1.difficulty) }
    }

    /// After a dead end the team needs new ideas before trying the same thing again (180 days).
    static func retryBlocker(_ id: String, _ s: GameState) -> Date? {
        guard let last = s.science.projects.filter({ $0.def == id && $0.status == .failed }).compactMap(\.ended).max() else { return nil }
        let ok = GameCalendar.addDays(last, 180)
        return ok > s.date ? ok : nil
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
        guard d.year <= year else { return "\(d.name) isn't possible before \(Int(d.year))." }
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

    mutating func setProjectSupport(_ id: UUID, agents: Int, compute: Int) {
        guard let i = science.projects.firstIndex(where: { $0.id == id }) else { return }
        science.projects[i].agents = clamp(agents, 0, Science.agentMax)
        science.projects[i].compute = clamp(compute, 0, 3)
    }

    mutating func cancelScienceProject(_ id: UUID) {
        guard let i = science.projects.firstIndex(where: { $0.id == id }), science.projects[i].status == .running else { return }
        science.projects[i].status = science.projects[i].discovery == nil ? .cancelled : .stalled
        science.projects[i].ended = date
        if let disc = science.projects[i].discovery, let k = science.discoveries.firstIndex(where: { $0.id == disc }) {
            science.discoveries[k].labScaleOnly = true
        }
    }

    /// Answer a discovery's follow-up from the report (resolves its inbox item).
    mutating func chooseDiscoveryFollowUp(_ id: UUID, _ c: SciChoice) {
        guard let d = science.discoveries.first(where: { $0.id == id }) else { return }
        if let dec = d.decision.flatMap({ did in decisions.first { $0.id == did } }) {
            let codes = dec.ref.split(separator: "|").last.map { $0.split(separator: ",").map(String.init) } ?? []
            if let option = codes.firstIndex(of: c.rawValue) { resolveDecision(dec.id, option: option); return }
        }
        Science.apply(&self, discovery: id, c)
    }
}
