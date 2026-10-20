import Foundation

// MARK: - 3.9: dramatic events

/// Things that happen to a lab and won't wait: a battery fire, a blackout mid-run, leaked weights, a researcher's
/// thread, a smuggling scandal at your integrator, a celebrity who loves your app, a whistleblower, a lawsuit, a rival's
/// open-weights bombshell. Each one does its damage (or brings its luck) at once, then lands in the inbox with two or
/// three real answers wired into the systems they touch: chips, runs, orders, prices, people, standings, the world.
///
/// Pacing: at most one at a time, never two within `gapDays`, none in a new game's first `graceDays`, about three a
/// year (`dailyOdds`), each event with its own cooldown. Every event is gated by era and by what the lab has (a fire
/// needs a hall full of chips, a voice scandal needs a chat app with a million users). Ignored, an event resolves with
/// its safe answer, which never spends cash or destroys anything. Answers that cost money name the amount, are greyed
/// out when you can't pay, and fall back to the safe answer if the cash is gone by the time they run.
enum Drama {
    /// Decision kinds are "drama_<event id>".
    static let prefix = "drama_"
    static let gapDays = 45
    static let graceDays = 75
    static let dailyOdds = 0.013
    /// Harnesses: `TT_NO_DRAMA=1` switches dramatic events off, to compare a run with and without them.
    static let off = ProcessInfo.processInfo.environment["TT_NO_DRAMA"] != nil

    /// What an answer did: the news story and the log's colour.
    struct Outcome {
        var title: String
        var body: String
        var tone: DramaTone
        var category: NewsCategory = .company
    }

    /// One event in the catalogue (DramaEvents).
    struct Def {
        let id: String
        /// Name and one line for the Events & Records catalogue.
        let name: String
        let blurb: String
        /// Photo key (Resources/Images).
        let image: String
        /// The inbox default: the answer taken if you don't choose. Never one that spends cash or destroys assets.
        let safe: Int
        let cooldownDays: Int
        /// Days the decision waits in the inbox (crises are short, offers longer).
        let days: Int
        /// How likely it is to be the one that fires today; 0 when it can't happen in this game right now.
        let weight: (GameState) -> Double
        /// Does the immediate damage (or good) and posts the decision with `post`.
        let fire: (inout GameState, Def) -> Void
        let resolve: (inout GameState, Decision, Int) -> Outcome
    }

    static let byID: [String: Def] = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

    /// Merged into `Alerts.inboxDefaults`, so every dramatic event waits in the inbox with its safe answer.
    static let inboxDefaults: [String: Int] = Dictionary(uniqueKeysWithValues: catalog.map { (prefix + $0.id, $0.safe) })

    static func owns(_ kind: String) -> Bool { kind.hasPrefix(prefix) }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        guard s.gameOver == nil, !off else { return }
        followUps(&s)
        let today = s.date
        guard GameCalendar.daysBetween(s.startDate, today) >= graceDays,
              s.drama.last.map({ GameCalendar.daysBetween($0, today) >= gapDays }) ?? true,
              s.decisions.count < 3, !s.decisions.contains(where: { owns($0.kind) }) else { return }
        let pace: Double = s.difficulty == .easy ? 0.8 : (s.difficulty == .hard ? 1.2 : 1)
        guard s.rng.chance(dailyOdds * pace) else { return }
        fireOne(&s)
    }

    /// Picks one eligible event (weighted) and fires it. Returns its ID.
    @discardableResult
    static func fireOne(_ s: inout GameState, only: String? = nil) -> String? {
        let today = s.date
        let pool: [(Def, Double)] = catalog.compactMap { d in
            if let only, d.id != only { return nil }
            if let last = s.drama.fired[d.id], GameCalendar.daysBetween(last, today) < d.cooldownDays, only == nil { return nil }
            let w = d.weight(s)
            return w > 0 ? (d, w) : nil
        }
        let total = pool.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var x = s.rng.range(0, total)
        for (d, w) in pool {
            x -= w
            if x <= 0 || d.id == pool.last?.0.id {
                d.fire(&s, d)
                return d.id
            }
        }
        return nil
    }

    // MARK: Posting and resolving

    /// Posts an event's decision to the inbox, its story to the news and a record to the log. `costs` maps an option
    /// to the cash it spends (shown greyed out when you can't pay); `ref` carries what the answer needs to find again.
    static func post(_ s: inout GameState, _ def: Def, title: String, body: String, options: [DecisionOption],
                     costs: [Int: Double] = [:], ref: [String: String] = [:], headline: String? = nil,
                     category: NewsCategory = .company, good: Bool? = false, image: String? = nil) {
        var r = ref
        for (k, v) in costs { r["c\(k)"] = String(v.rounded()) }
        var d = Decision(kind: prefix + def.id, title: title, body: body, image: image ?? def.image, options: options, date: s.date,
                         amount: costs.values.max() ?? 0, ref: encode(r))
        d.deadline = GameCalendar.addDays(s.date, def.days)
        let fallback = options[max(0, min(def.safe, options.count - 1))].label
        Alerts.raise(&s, .inbox, key: d.id.uuidString, title: title,
                     body: "Waiting in your inbox for \(def.days) days. If you don't answer: \"\(fallback)\".", screen: .dashboard, cooldown: 0)
        s.decisions.append(d)
        Sim.news(&s, headline ?? title, body, category, image: image ?? def.image, important: true, good: good)
        s.drama.log.insert(DramaRecord(event: def.id, date: s.date, title: title, summary: body, decision: d.id), at: 0)
        if s.drama.log.count > 40 { s.drama.log.removeLast(s.drama.log.count - 40) }
        s.drama.fired[def.id] = s.date
        s.drama.last = s.date
        s.drama.count += 1
    }

    /// The decision was answered (or expired into its safe answer).
    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let def = byID[String(d.kind.dropFirst(prefix.count))], !d.options.isEmpty else { return }
        let expired = d.deadline.map { $0 <= s.date } ?? false
        var o = max(0, min(option, d.options.count - 1))
        var note = ""
        // The cash may be gone by the time the answer runs (a harness, a standing answer): take the safe one instead.
        if let c = cost(d, o), c > max(0, s.cash) {
            note = "You couldn't cover \(Fmt.money(c)), so you went with \"\(d.options[def.safe].label)\". "
            o = def.safe
        }
        let out = def.resolve(&s, d, o)
        Sim.news(&s, out.title, note + out.body, out.category, image: def.image, important: out.tone != .mixed,
                 good: out.tone == .good ? true : (out.tone == .bad ? false : nil))
        if let i = s.drama.index(of: d.id) {
            s.drama.log[i].choice = d.options[o].label
            s.drama.log[i].outcome = note + out.body
            s.drama.log[i].tone = out.tone
            s.drama.log[i].defaulted = expired
        }
        if !expired { s.drama.answered += 1 }
    }

    /// The playtest bot's answer: the safe one, unless a cheap fix (under 0.5% of cash) is on offer as the first option.
    static func botChoice(_ d: Decision, _ s: GameState) -> Int {
        guard let def = byID[String(d.kind.dropFirst(prefix.count))] else { return 0 }
        if let c = cost(d, 0), c <= max(0, s.cash) * 0.005 { return 0 }
        return def.safe
    }

    /// Why an option can't be taken now (not enough cash), or nil (`Events.optionBlocker`).
    static func blocker(_ d: Decision, _ option: Int, _ s: GameState) -> String? {
        guard let c = cost(d, option), c > max(0, s.cash) else { return nil }
        return "Needs \(Fmt.money(c)); you have \(Fmt.money(max(0, s.cash)))."
    }

    static func cost(_ d: Decision, _ option: Int) -> Double? {
        let v = num(d, "c\(option)")
        return v > 0 ? v : nil
    }

    // MARK: Follow-ups

    static func later(_ s: inout GameState, _ d: Decision, kind: String, days: Int, amount: Double = 0, ref: String = "") {
        let record = s.drama.index(of: d.id).map { s.drama.log[$0].id }
        s.drama.followUps.append(DramaFollowUp(kind: kind, due: GameCalendar.addDays(s.date, days), ref: ref, amount: amount, record: record))
    }

    static func followUps(_ s: inout GameState) {
        let today = s.date
        let due = s.drama.followUps.filter { $0.due <= today }
        guard !due.isEmpty else { return }
        s.drama.followUps.removeAll { $0.due <= today }
        for f in due {
            guard let out = followUp(&s, f) else { continue }
            Sim.news(&s, out.title, out.body, out.category, image: nil, important: true,
                     good: out.tone == .good ? true : (out.tone == .bad ? false : nil))
            if let rid = f.record, let i = s.drama.log.firstIndex(where: { $0.id == rid }) {
                s.drama.log[i].outcome += (s.drama.log[i].outcome.isEmpty ? "" : " ") + "Later: " + out.body
                if out.tone != .mixed { s.drama.log[i].tone = out.tone }
            }
        }
    }

    // MARK: Helpers

    static func encode(_ pairs: [String: String]) -> String {
        pairs.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
    }

    static func value(_ d: Decision, _ key: String) -> String? {
        for part in d.ref.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0] == key { return String(kv[1]) }
        }
        return nil
    }

    static func num(_ d: Decision, _ key: String) -> Double { value(d, key).flatMap(Double.init) ?? 0 }

    /// Annualised revenue (0 before any).
    static func rr(_ s: GameState) -> Double { max(0, Economy.runRate(s)) }

    /// A cost that scales with the business: `floor`, or `share` of a year's revenue, at most `cap`, rounded to two figures.
    static func scaled(_ s: GameState, floor: Double, share: Double, cap: Double = 5e9) -> Double {
        round2(min(cap, max(floor, rr(s) * share)))
    }

    static func round2(_ v: Double) -> Double {
        guard v > 0 else { return 0 }
        let mag = pow(10, floor(log10(v)) - 1)
        return (v / mag).rounded() * mag
    }

    static func pay(_ s: inout GameState, _ v: Double, capex: Bool = false) {
        guard v > 0 else { return }
        s.cash -= v
        if capex { s.month.capex += v } else { s.month.costOther += v }
    }

    static func receive(_ s: inout GameState, _ v: Double) {
        guard v > 0 else { return }
        s.cash += v
        s.month.oneOffIncome += v
    }

    static func home(_ s: GameState) -> String { HQ.region(s).rawValue }

    /// Chips installed at a site.
    static func chips(at site: UUID, _ s: GameState) -> Int { s.owned.filter { $0.siteID == site }.reduce(0) { $0 + $1.count } }

    /// Big, open sites with chips in them (garages and office closets don't have battery rooms and chillers).
    static func halls(_ s: GameState, minChips: Int = 64) -> [Site] {
        s.sites.filter { ($0.kind == .colo || $0.kind == .datacenter) && $0.isReady(s.date) && chips(at: $0.id, s) >= minChips }
    }

    static func siteOf(_ s: GameState, _ d: Decision) -> Site? { s.sites.first { $0.id.uuidString == value(d, "site") } }

    /// Destroys a share of the chips at a site. Returns chips lost, their value at today's prices, the main chip's name
    /// and the lost batches encoded for `replace` ("accel:count:unitCost,…").
    @discardableResult
    static func destroy(_ s: inout GameState, site: UUID, share: Double) -> (count: Int, value: Double, name: String, lost: String) {
        // At least one chip, taken from the biggest batches first (a hall of many small batches still loses chips).
        var left = max(1, Int((Double(chips(at: site, s)) * share).rounded()))
        var lost = 0, value = 0.0, name = "", parts: [String] = []
        let order = s.owned.indices.filter { s.owned[$0].siteID == site }.sorted { s.owned[$0].count > s.owned[$1].count }
        for i in order where left > 0 {
            let n = min(left, s.owned[i].count, max(1, Int((Double(s.owned[i].count) * share).rounded(.up))))
            s.owned[i].count -= n
            left -= n
            lost += n
            value += Double(n) * s.owned[i].unitCost * s.market.hardwarePrice
            parts.append("\(s.owned[i].accelID):\(n):\(Int(s.owned[i].unitCost))")
            if name.isEmpty { name = HardwareCatalog.get(s.owned[i].accelID)?.name ?? s.owned[i].accelID }
        }
        s.owned.removeAll { $0.count <= 0 }
        return (lost, value, name, parts.joined(separator: ","))
    }

    /// Puts replacement chips back at a site: the batches `destroy` took, bought again at today's prices.
    static func replace(_ s: inout GameState, site: UUID, lost: String) {
        for p in lost.split(separator: ",") {
            let f = p.split(separator: ":").map(String.init)
            guard f.count == 3, let n = Int(f[1]), n > 0, let unit = Double(f[2]), HardwareCatalog.get(f[0]) != nil else { continue }
            s.owned.append(OwnedBatch(accelID: f[0], count: n, siteID: site, purchased: s.date, unitCost: unit * s.market.hardwarePrice))
        }
    }

    /// The training run most worth hurting: the biggest one still in pre-training.
    static func activeRun(_ s: GameState, minProgress: Double = 0.05) -> Int? {
        s.runs.indices.filter { s.runs[$0].status == .running && !s.runs[$0].toy && s.runs[$0].progress >= minProgress && s.runs[$0].progress < 0.97 }
            .max { s.runs[$0].flopsTotal < s.runs[$1].flopsTotal }
    }

    /// Sets a run back: to its last checkpoint if that's close, otherwise by `share` of the run (the in-memory
    /// snapshot). Returns what it cost, in words.
    @discardableResult
    static func setBack(_ s: inout GameState, _ i: Int, share: Double, why: String) -> String {
        let run = s.runs[i]
        if let cp = run.saved.filter({ $0.flopsDone < run.flopsDone }).max(by: { $0.flopsDone < $1.flopsDone }),
           (run.flopsDone - cp.flopsDone) / max(1, run.flopsTotal) <= share * 2 {
            let lost = (run.flopsDone - cp.flopsDone) / max(1, run.flopsTotal)
            Training.rollback(&s, i, to: cp)
            Training.runLog(&s, i, "\(why): rolled back to the \(Int(cp.fraction * 100))% checkpoint.")
            return "back to its \(Int(cp.fraction * 100))% checkpoint (\(Fmt.pct(lost)) of the run lost)"
        }
        let lost = min(run.flopsDone, run.flopsTotal * share)
        TrainingExperience.rewound(&s, i, lost)
        s.runs[i].flopsDone -= lost
        Training.runLog(&s, i, "\(why): \(Fmt.pct(lost / max(1, run.flopsTotal))) of the run lost.")
        return "\(Fmt.pct(lost / max(1, run.flopsTotal))) of the run lost"
    }

    /// Vendor orders still to arrive (your own fab's rolling orders are excluded).
    static func vendorOrders(_ s: GameState) -> [HardwareOrder] { s.orders.filter { $0.made == nil && $0.arrives > s.date } }

    static func orderValue(_ s: GameState) -> Double { vendorOrders(s).reduce(0) { $0 + Double($1.count) * $1.unitCost } }

    /// Pushes every vendor order back (or forward, for negative days, never before tomorrow). Returns chips moved.
    @discardableResult
    static func delayOrders(_ s: inout GameState, days: Int) -> Int {
        var n = 0
        let tomorrow = GameCalendar.addDays(s.date, 1)
        for i in s.orders.indices where s.orders[i].made == nil && s.orders[i].arrives > s.date {
            s.orders[i].arrives = max(tomorrow, GameCalendar.addDays(s.orders[i].arrives, days))
            n += s.orders[i].count
        }
        return n
    }

    static func morale(_ s: inout GameState, _ delta: Double, role: Role? = nil) {
        for i in s.employees.indices where role == nil || s.employees[i].role == role {
            s.employees[i].morale = clamp(s.employees[i].morale + delta, 0, 100)
        }
    }

    /// Someone leaves because of an event: the people log, the stakeholder bookkeeping, and the cast if they're notable.
    static func lose(_ s: inout GameState, _ e: Employee, why: String) {
        s.employees.removeAll { $0.id == e.id }
        Stakeholders.letGo(&s, e)
        if e.star || e.skill >= 75 { Cast.leftYou(&s, e, to: "", why: why, pulse: false) }
    }

    /// Cancels an enterprise contract (gone, not back among the leads).
    static func cancelDeal(_ s: inout GameState, _ id: UUID) -> String? {
        guard let i = s.deals.firstIndex(where: { $0.id == id && $0.active }) else { return nil }
        s.deals[i].active = false
        s.deals[i].expires = .distantPast
        return s.deals[i].client
    }

    /// The biggest active contract.
    static func bigDeal(_ s: GameState, min: Double = 0) -> EnterpriseDeal? {
        s.deals.filter { $0.active && $0.monthly >= min }.max { $0.monthly < $1.monthly }
    }

    static func bestReleased(_ s: GameState) -> AIModel? { s.releasedModels.max { $0.c < $1.c } }

    static func chatName(_ s: GameState) -> String { s.models.first { $0.id == s.chatModelID }?.name ?? "your chat app" }

    static func person(_ s: inout GameState) -> String { "\(s.rng.pick(NameBank.first)) \(s.rng.pick(NameBank.last))" }

    /// A university near headquarters (real institutions, as the city catalogue names them) and a photo of it.
    static func university(_ s: inout GameState) -> (name: String, image: String) {
        switch s.hqCity {
        case "bucharest": ("the University of Bucharest", "ro_univ_bucharest")
        case "cluj": ("Babeș-Bolyai University", "ro_ubb_cluj")
        case "milan": ("Politecnico di Milano", "hq_milan")
        case "rome": ("Sapienza University of Rome", "it_sapienza")
        case "turin": ("Politecnico di Torino", "it_turin_lingotto")
        case "paris": ("École Polytechnique", "hq_paris")
        case "lyon": ("the University of Lyon", "hq_lyon")
        case "grenoble": ("Université Grenoble Alpes", "fr_grenoble_science")
        case "copenhagen": ("the Technical University of Denmark", "dk_dtu")
        case "aarhus": ("Aarhus University", "dk_aarhus_uni")
        case "odense": ("the University of Southern Denmark", "dk_sdu_odense")
        case "aalborg": ("Aalborg University", "hq_aalborg")
        default: (s.rng.pick(["Stanford", "UC Berkeley", "Carnegie Mellon"]), "event_auditorium")
        }
    }
}
