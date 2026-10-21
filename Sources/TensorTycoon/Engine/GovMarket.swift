import Foundation

/// 3.9: the government contract marketplace — small, unclassified public money that is open from the first month:
/// small-business innovation awards, prototype agreements, task orders on a multiple-award contract, compute
/// allocations, EU calls and national innovation grants. It runs on the budget calendars governments really keep (the
/// US fiscal year from 1 October, continuing resolutions and lapses, the late-summer spending rush; calendar-year
/// budgets with their December rush and the odd provisional budget in Europe), and on proposals that take time and
/// people to write. Win odds are shown and explained; losses come with the agency's debrief and, where it's worth it, a
/// protest. Won work runs as an Advanced Projects programme, so it builds the same record big programmes are judged on.
///
/// A founding offer — a funded multi-year agreement with a base period and options — arrives in the first days.
///
/// Every roll is hashed (`roll`), never drawn from the game's RNG, so the rest of the game plays out the same.
enum GovMarket {
    static let anchorKind = "gov_anchor"
    static let yearEndKind = "gov_yearend"
    static let protestKind = "gov_protest"
    /// Open opportunities listed at once, at most.
    static let maxOpen = 10

    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("gm|\(s.govMarket.salt)|\(key)") }

    static func dayKey(_ d: Date) -> String { let c = GameCalendar.components(d); return "\(c.year)-\(c.month)-\(c.day)" }

    // MARK: - Budget calendars

    enum Phase: String, Sendable {
        case enacted, continuing, lapse, provisional, transition

        var title: String {
            switch self {
            case .enacted: "Budget enacted"
            case .continuing: "Continuing resolution"
            case .lapse: "Lapse in appropriations"
            case .provisional: "Provisional budget"
            case .transition: "Programme not yet open"
            }
        }
    }

    struct Fiscal: Sendable {
        var calendar: String
        var name: String
        var fyLabel: String
        var fyStart: Date
        var fyEnd: Date
        var phase: Phase = .enacted
        /// When the phase ends (nil: not known yet or not applicable).
        var until: Date? = nil
        /// When it began (lapses).
        var since: Date? = nil
        /// Posting multiplier from the budget cycle (year-end rush, slow first weeks).
        var cycle: Double = 1
        var cycleLabel: String = ""
        var fullYearCR = false
        var note: String = ""

        /// New awards wait (no new starts under a continuing resolution or provisional budget; nothing in a lapse).
        var holdsNewStarts: Bool { phase != .enacted || fullYearCR }
    }

    /// The budget calendar an agency spends on.
    static func calendar(_ a: AgencyDef) -> String {
        if a.region == .us { return "us" }
        if !a.country.isEmpty { return a.country }
        switch a.region {
        case .eu: return "eu"
        case .uk: return "uk"
        case .japanKorea: return "jp"
        case .india: return "in"
        case .gulf: return "gulf"
        default: return "cn"
        }
    }

    static func calendarName(_ c: String) -> String {
        switch c {
        case "us": "US federal"
        case "eu": "European Union"
        case "uk": "United Kingdom"
        case "jp": "Japan"
        case "in": "India"
        case "gulf": "Gulf states"
        case "cn": "China"
        default: CountryCatalog.get(c).name
        }
    }

    /// A US fiscal year's appropriations: history for FY2017–2026, drawn per game after that (a continuing resolution
    /// nine years in ten, a lapse about one year in six).
    static func usYear(_ s: GameState, fy: Int) -> GovMarketCatalog.USYear {
        if let h = GovMarketCatalog.usHistory.first(where: { $0.fy == fy }) { return h }
        let start = GameCalendar.date(fy - 1, 10, 1)
        let u = { (tag: String) in roll(s, "usfy|\(fy)|\(tag)") }
        guard u("cr") < 0.92 else { return GovMarketCatalog.USYear(fy: fy, enacted: nil) }
        let lengths = [45, 60, 75, 80, 90, 120, 150, 170]
        var enacted = GameCalendar.addDays(start, lengths[min(lengths.count - 1, Int(u("len") * Double(lengths.count)))])
        var lapses: [(Date, Date)] = []
        if u("lapse") < 0.16 {
            let days = 3 + Int(u("lapselen") * 36)
            if u("lapsewhen") < 0.5 {
                lapses.append((start, GameCalendar.addDays(start, days)))
                enacted = GameCalendar.addDays(enacted, days)
            } else {
                lapses.append((enacted, GameCalendar.addDays(enacted, days)))
                enacted = GameCalendar.addDays(enacted, days)
            }
        }
        return GovMarketCatalog.USYear(fy: fy, enacted: enacted, lapses: lapses)
    }

    /// The budget situation of a calendar on a date. `bill` is the US appropriations bill (agencies on bills enacted
    /// on time skip the continuing resolution); `agency` lets the EU calendar show programme transitions.
    static func fiscal(_ s: GameState, _ cal: String, at date: Date, bill: String = "", agency: String = "") -> Fiscal {
        let c = GameCalendar.components(date)
        switch cal {
        case "us":
            let fy = c.month >= 10 ? c.year + 1 : c.year
            var f = Fiscal(calendar: cal, name: calendarName(cal), fyLabel: "FY\(fy) (Oct \(fy - 1) – Sep \(fy))",
                           fyStart: GameCalendar.date(fy - 1, 10, 1), fyEnd: GameCalendar.date(fy, 9, 30))
            switch c.month {
            case 8: f.cycle = 1.5; f.cycleLabel = "Year-end spending rush"
            case 9: f.cycle = 1.9; f.cycleLabel = "Year-end rush: unspent money expires on 30 September"
            case 10, 11: f.cycle = 0.7; f.cycleLabel = "New fiscal year: budgets not yet handed down"
            default: break
            }
            let y = usYear(s, fy: fy)
            if !bill.isEmpty && y.early.contains(bill) { f.note = "Its appropriations bill was enacted on time"; return f }
            if let lapse = y.lapses.first(where: { date >= $0.0 && date < $0.1 }) {
                f.phase = .lapse
                f.until = lapse.1
                f.since = lapse.0
                f.note = "No appropriations: agencies stop new work and contractors on stop-work orders can't bill"
                return f
            }
            var enacted = y.enacted
            if let late = y.late, !bill.isEmpty, late.0.contains(bill) { enacted = late.1 }
            if let e = enacted, date < e {
                f.phase = .continuing
                f.until = e
                f.note = "Funded at last year's rate: no new starts until full-year appropriations pass"
            } else if y.fullYearCR {
                f.fullYearCR = true
                f.note = "A full-year continuing resolution: last year's levels, few new starts"
            }
            return f
        case "uk", "jp", "in":
            let fy = c.month >= 4 ? c.year : c.year - 1
            var f = Fiscal(calendar: cal, name: calendarName(cal), fyLabel: "FY\(fy)–\(String(fy + 1).suffix(2)) (Apr \(fy) – Mar \(fy + 1))",
                           fyStart: GameCalendar.date(fy, 4, 1), fyEnd: GameCalendar.date(fy + 1, 3, 31))
            switch c.month {
            case 2: f.cycle = 1.4; f.cycleLabel = "Year-end spending"
            case 3: f.cycle = 1.6; f.cycleLabel = "Year-end rush: budgets close on 31 March"
            case 4, 5: f.cycle = 0.7; f.cycleLabel = "New financial year"
            default: break
            }
            return f
        default:
            var f = Fiscal(calendar: cal, name: calendarName(cal), fyLabel: "Budget year \(c.year)",
                           fyStart: GameCalendar.date(c.year, 1, 1), fyEnd: GameCalendar.date(c.year, 12, 31))
            if cal == "gulf" || cal == "cn" { return f }
            if cal == "eu" {
                switch c.month {
                case 12, 1: f.cycle = 1.4; f.cycleLabel = "New work programmes and calls"
                case 7, 8: f.cycle = 0.6; f.cycleLabel = "Summer: few calls open"
                default: break
                }
                // The framework programme changes every seven years and its first calls come months late.
                if agency == "ereo" || agency == "eiab" {
                    for (a, b, why) in [(GameCalendar.date(2021, 1, 1), GameCalendar.date(2021, 5, 15), "Horizon Europe's first work programme isn't adopted yet"),
                                        (GameCalendar.date(2028, 1, 1), GameCalendar.date(2028, 5, 15), "The next framework programme's first work programme isn't adopted yet (game estimate)")]
                    where date >= a && date < b {
                        f.phase = .transition
                        f.until = b
                        f.note = why
                    }
                }
                return f
            }
            // National calendar-year budgets: the December rush ("decemberfeber" in Danish ministries).
            switch c.month {
            case 11: f.cycle = 1.4; f.cycleLabel = "Year-end spending"
            case 12: f.cycle = 1.6; f.cycleLabel = "December rush: this year's money must be committed"
            case 1: f.cycle = 0.7; f.cycleLabel = "New budget year"
            default: break
            }
            var prov = GovMarketCatalog.provisional.first { $0.0 == cal && date >= $0.1 && date < $0.2 }.map { ($0.1, $0.2) }
            if prov == nil && c.year >= 2027 && roll(s, "prov|\(cal)|\(c.year)") < 0.08 {
                let a = GameCalendar.date(c.year, 1, 1), b = GameCalendar.addDays(a, 35 + Int(roll(s, "provlen|\(cal)|\(c.year)") * 40))
                if date >= a && date < b { prov = (a, b) }
            }
            if let p = prov {
                f.phase = .provisional
                f.until = p.1
                f.note = "No budget law yet: spending continues month by month at last year's level and new programmes wait"
            }
            return f
        }
    }

    static func fiscal(_ s: GameState, agency a: AgencyDef, at date: Date? = nil) -> Fiscal {
        let cal = calendar(a)
        return fiscal(s, cal, at: date ?? s.date, bill: cal == "us" ? GovMarketCatalog.usBill(a.id) : "", agency: a.id)
    }

    /// Calendars worth showing: home, the EU for a European lab, and every calendar your pipeline or anchor touches.
    static func relevantCalendars(_ s: GameState) -> [String] {
        var out = [HQ.country(s).id == "us" ? "us" : HQ.country(s).id]
        if HQ.region(s) == .eu { out.append("eu") }
        var agencies = s.govMarket.pipeline.map(\.sol.agency) + s.govMarket.opps.map(\.sol.agency)
        if let a = s.govMarket.anchor { agencies.append(a.agency) }
        for id in agencies.sorted() { if let a = AgencyCatalog.byID[id] { let c = calendar(a); if !out.contains(c) { out.append(c) } } }
        return out
    }

    /// A phase's end as the player may know it: history and enacted dates exactly, the rest as a rough month.
    static func untilText(_ f: Fiscal, _ s: GameState) -> String {
        guard let u = f.until else { return "until further notice" }
        if f.phase == .continuing && u > GameCalendar.addDays(s.date, 20) { return "expected to run to about \(u.gameMonth) (Congress hasn't agreed)" }
        if f.phase == .lapse { return "day \(1 + GameCalendar.daysBetween(f.since ?? s.date, s.date)) of the shutdown, until Congress passes funding" }
        return "until about \(u.gameShort)"
    }

    // MARK: - Eligibility

    static func homeRegion(_ s: GameState) -> Region { HQ.region(s) }

    /// Why you can't bid on this kind of work for this agency (nil if you can).
    static func blocker(_ k: GovKindDef, _ a: AgencyDef, _ s: GameState) -> String? {
        switch k.eligibility {
        case .country(let c):
            if HQ.country(s).id != c { return "Open to companies headquartered in \(CountryCatalog.get(c).name) only" }
        case .region(let r):
            if homeRegion(s) != r { return "Open to companies headquartered in \(r.title) only" }
        case .allied:
            let allies: [Region] = [.us, .uk, .eu, .japanKorea]
            if !allies.contains(homeRegion(s)) || !allies.contains(a.region) { return "\(a.short) works with companies from allied countries only" }
        case .vehicle:
            if !s.govMarket.seats.contains(where: { $0.agency == a.id && $0.ends > s.date }) { return "Only holders of a seat on \(a.short)'s AI & data services contract may bid" }
        }
        if k.payout == .seat && s.govMarket.seats.contains(where: { $0.agency == a.id && $0.ends > s.date }) { return "You already hold a seat on \(a.short)'s contract" }
        if k.smallOnly > 0 && s.employees.count >= k.smallOnly { return "Small companies only (under \(k.smallOnly) staff; you have \(s.employees.count))" }
        return nil
    }

    // MARK: - Money scales

    static func interp(_ table: [(Double, Double, Double)], _ y: Double) -> (Double, Double) {
        (interpolate(table.map { ($0.0, $0.1) }, at: y), interpolate(table.map { ($0.0, $0.2) }, at: y))
    }

    /// Prices and public budgets drift up over the years (bid-and-proposal costs, anchor contracts).
    static func era(_ y: Double) -> Double { interpolate([(2016, 0.94), (2019, 1), (2022, 1.12), (2024, 1.25), (2026, 1.38), (2030, 1.65), (2036, 2.1)], at: y) }

    static func bpCost(_ k: GovKindDef, _ e: CaptureEffort, _ y: Double) -> Double {
        max(500, (k.bp * e.costMult * era(y) / 500).rounded() * 500)
    }

    /// Writing slots: the founder writes one proposal at a time; every two business-development staff add one.
    static func slots(_ s: GameState) -> Int {
        1 + min(4, s.employees.filter { $0.role == .sales }.count / 2)
    }

    static func markup(_ t: ContractType) -> Double {
        switch t {
        case .fixedPrice: 1.18
        case .costPlus: 1.0
        case .grant: 0.85
        case .prize: 1.5
        }
    }

    // MARK: - Posting

    /// Agencies post on the 1st and the 15th: rolling programmes by chance (more in a rush, fewer while budgets wait),
    /// fixed-deadline calls on their schedule.
    static func post(_ s: inout GameState) {
        let today = s.date
        let c = GameCalendar.components(today)
        let y = s.year
        s.govMarket.opps.removeAll { ($0.status == .open || $0.status == .notice) && $0.sol.closes <= today }
        for k in GovMarketCatalog.kinds where !k.invite && k.active(y) {
            for id in k.issuers {
                guard let a = AgencyCatalog.byID[id], blocker(k, a, s) == nil else { continue }
                guard s.govMarket.opps.filter({ $0.status == .open || $0.status == .notice }).count < maxOpen else { return }
                guard !s.govMarket.opps.contains(where: { $0.kind == k.id && $0.sol.agency == id && ($0.status == .open || $0.status == .notice) }) else { continue }
                let f = fiscal(s, agency: a)
                if f.phase == .lapse || f.phase == .transition { continue }
                // A compute allocation runs a year: an agency doesn't take a new proposal from a lab whose allocation is fresh.
                if k.payout == .compute, (s.govMarket.opps + s.govMarket.history).contains(where: { $0.sol.agency == id && $0.status == .won && $0.def?.payout == .compute && ($0.decided.map { GameCalendar.daysBetween($0, today) < 300 } ?? false) }) { continue }
                var closes: Date? = nil
                if !k.cutoffs.isEmpty {
                    // Fixed cut-offs: the call is published about its window ahead of the cut-off (the 15th of the month).
                    guard c.day == 1 else { continue }
                    let lead = max(1, Int((Double(k.window) / 30.4).rounded()))
                    guard let m = k.cutoffs.first(where: { ($0 - c.month + 12) % 12 == lead }) else { continue }
                    closes = GameCalendar.date(c.year + (m < c.month ? 1 : 0), m, 15)
                } else {
                    let budget = clamp(AdvancedProjects.agencyBudget(a, s) / AdvancedProjects.budgetScale(y) / max(0.05, a.budget), 0.6, 1.5)
                    let hold = f.holdsNewStarts && k.newStart ? 0.6 : 1
                    let p = k.rate * f.cycle * budget * hold
                    guard roll(s, "post|\(k.id)|\(id)|\(dayKey(today))") < p else { continue }
                }
                let o = make(k, a, &s, key: "\(k.id)|\(id)|\(dayKey(today))", closes: closes)
                s.govMarket.opps.append(o)
            }
        }
    }

    /// A new opportunity, sized to the programme's real range and the year.
    static func make(_ k: GovKindDef, _ a: AgencyDef, _ s: inout GameState, key: String, closes fixed: Date? = nil, invited: Bool = false,
                     parent: Programme? = nil, valueOverride: Double? = nil, customer: String = "") -> GovOpp {
        let y = s.year
        let salt = s.govMarket.salt
        func r(_ tag: String) -> Double { RivalIntel.unit("gm|\(salt)|make|\(key)|\(tag)") }
        let t = AgencyCatalog.templateByID[k.template]
        let (lo, hi) = interp(k.value, y)
        var value = valueOverride ?? (lo + (hi - lo) * r("value"))
        if k.scalesWithLab && valueOverride == nil { value *= AdvancedProjects.companyScale(s) }
        value = value < 10_000 ? value : (value / 5_000).rounded() * 5_000
        let months = k.months.lowerBound + Int(r("months") * Double(k.months.count - 1) + 0.5)
        // Civilian research agencies pay their small-business awards as grants; defence ones as fixed-price contracts.
        let type: ContractType = k.id == "sbir1" && ["nfse", "nhri"].contains(a.id) ? .grant : k.type
        // Small software awards are mostly people: the government's estimate behind them is about half (fixed price) to
        // three fifths (grants, which also pay overhead) of the award, so cloud and travel stay a minority of the money.
        let est = value * (type == .grant ? 0.62 : 0.5)
        var staff: [String: Int] = [:]
        for (role, n) in k.staff { staff[role.rawValue, default: 0] += n }
        let share = t?.computeShare ?? 0.3
        let compute = max(8, (est * share / (AdvancedProjects.h100eMonthly(y) * Double(max(1, months))) / 8).rounded() * 8)
        let topics = GovMarketCatalog.topics[a.id] ?? ["Applied AI research"]
        // An agency doesn't post the same topic twice while you're still working on (or just won) the last one.
        let used = Set((s.govMarket.opps + s.govMarket.history.prefix(12)).filter { $0.sol.agency == a.id }.map(\.sol.title))
        let start = min(topics.count - 1, Int(r("topic") * Double(topics.count)))
        var title = topics[start]
        for j in 0..<topics.count where !used.contains(where: { $0.hasPrefix(topics[(start + j) % topics.count]) }) { title = topics[(start + j) % topics.count]; break }
        var cust = customer
        if k.id == "task" && cust.isEmpty {
            cust = GovMarketCatalog.customers[min(GovMarketCatalog.customers.count - 1, Int(r("customer") * Double(GovMarketCatalog.customers.count)))]
        }
        if !cust.isEmpty { title += " for \(cust)" }
        if let parent { title = parent.sol.title }
        if k.payout == .seat { title = "AI & data services multiple-award contract (on-ramp \(GameCalendar.components(s.date).year))" }
        s.govMarket.counter += 1
        let window = Int(Double(k.window) * (0.85 + 0.3 * r("window")))
        var close = fixed ?? GameCalendar.addDays(s.date, window)
        let f = fiscal(s, agency: a)
        // In the US year-end rush windows are short and decisions come before the money expires on 30 September.
        if fixed == nil && f.calendar == "us" && f.cycle > 1.2 { close = GameCalendar.addDays(s.date, max(10, window * 2 / 3)) }
        var sol = Solicitation(id: "gm\(s.govMarket.counter)-\(a.id)-\(k.id)", agency: a.id, template: k.template, title: title, type: type, ip: k.ip,
                               classification: 0, ceiling: value, estCost: (est / 1_000).rounded() * 1_000, months: months, domains: [:], research: [],
                               computeH100e: compute, staff: staff, risk: (t?.risk ?? 0.12) * (0.8 + 0.4 * r("risk")), basis: k.basis, posted: s.date, closes: close)
        sol.followOn = invited
        sol.phase = k.id == "sbir1" ? 1 : (k.id == "sbir2" ? 2 : 0)
        var due = GameCalendar.addDays(close, Int(Double(k.evaluation) * (0.85 + 0.3 * r("eval"))))
        if f.calendar == "us" && f.cycle > 1.2 {
            let fyEnd = GameCalendar.addDays(f.fyEnd, -2)
            if GameCalendar.daysBetween(close, fyEnd) >= 10 { due = min(due, fyEnd) }
        }
        let field = max(1, Int(((1 - k.baseRate) / k.baseRate).rounded()))
        var o = GovOpp(id: sol.id, kind: k.id, sol: sol, decisionDue: due, baseRate: k.baseRate, field: field)
        o.invited = invited
        o.parent = parent?.id
        o.customer = cust
        o.price = type == .grant ? 1.0 : 0.95
        if k.notice && !invited && fixed == nil && r("notice") < 0.6 {
            o.status = .notice
            o.release = GameCalendar.addDays(s.date, 21)
            o.sol.closes = GameCalendar.addDays(close, 21)
            o.decisionDue = GameCalendar.addDays(due, 21)
        }
        return o
    }

    // MARK: - Odds

    struct Odds: Sendable {
        var p = 0.0
        var base = 0.0
        var score = 0.0
        var parts: [(String, Double)] = []
        /// Competing proposals expected.
        var field = 0.0
        var blocker: String? = nil
    }

    /// Your record across government work: finished programmes (on time or late), terminations and yearly ratings.
    static func record(_ s: GameState) -> (score: Double, delivered: Int, defaults: Int, text: String) {
        var delivered = 0, defaults = 0
        for p in s.advanced.programmes {
            if p.status == .completed { delivered += 1 }
            if p.status == .terminated { defaults += 1 }
        }
        let good = s.govMarket.assessments.filter { $0.score >= 0.75 }.count
        let bad = s.govMarket.assessments.filter { $0.score < 0.5 }.count
        let score = clamp(0.7 * Double(delivered) + 0.5 * Double(good) - 1.5 * Double(defaults) - 1.0 * Double(bad), -4, 3)
        let text: String
        if delivered + good + defaults + bad == 0 { text = "Neutral: no government contracts on record" }
        else if score >= 2 { text = "Substantial confidence" }
        else if score >= 0.6 { text = "Satisfactory confidence" }
        else if score > -0.5 { text = "Limited record" }
        else { text = "Low confidence: defaults or poor ratings on record" }
        return (score, delivered, defaults, text)
    }

    /// The proposal's technical lead: a skill on 0–100 (no lead: founder-written boilerplate).
    static func leadQuality(_ effort: CaptureEffort, leadSkill: Double?, star: Bool = false) -> Double {
        guard let sk = leadSkill else { return effort == .light ? -0.5 : -1.5 }
        return clamp((sk - 60) / 12, -2, 2) + (star ? 0.6 : 0)
    }

    static func odds(_ o: GovOpp, _ s: GameState, effort: CaptureEffort, lead: UUID?, price: Double, written: Double = 1, leadSkill: Double? = nil) -> Odds {
        var out = Odds()
        guard let k = o.def, let a = o.agencyDef else { return out }
        out.base = o.baseRate
        let w = k.basis.weights
        let e = lead.flatMap { id in s.employees.first { $0.id == id } }
        let skill = e.map { $0.skill * ([.researcher, .mlEngineer].contains($0.role) ? 1 : 0.85) } ?? leadSkill
        let quality = effort.quality + leadQuality(effort, leadSkill: skill, star: e?.star ?? false) - 6 * max(0, 1 - written)
        out.parts.append(("Proposal quality (\(effort.title.lowercased())\(skill == nil ? ", no named lead" : ""))", quality))
        // A known lab with a working model reads as lower risk, but the panel scores the proposal, not the brand.
        let models = s.models.contains { $0.released && !$0.retired } ? 0.5 : 0
        let cred = clamp((s.brand - 40) / 30, -1, 1.0) + models + min(0.6, Double(s.researched.count) / 80)
        out.parts.append(("Technical credibility", cred))
        let rec = record(s)
        let past = (w.past / 0.5) * (rec.score + 0.5 * AdvancedProjects.rating(s, a.id))
        out.parts.append(("Past performance (\(rec.text.components(separatedBy: ":").first ?? rec.text))", past))
        var capture = 0.0
        if o.answeredNotice { capture += 1.5 }
        capture += min(1.6, 0.45 * Double(s.employees.filter { $0.role == .sales }.count))
        if let an = s.govMarket.anchor, an.status == .active, an.agency == a.id { capture += 1.2 }
        if s.govMarket.seats.contains(where: { $0.agency == a.id }) && k.id == "task" { capture += 0.5 * Double(min(4, s.govMarket.seats.first { $0.agency == a.id }?.orders ?? 0)) / 2 }
        out.parts.append(("Capture & relationship", capture))
        if k.payout == .programme {
            let pr = (0.95 - clamp(price, 0.75, 1.0)) * 30 * (w.price / 0.8)
            out.parts.append((o.sol.type == .grant ? "Funding requested" : "Price", pr))
        }
        let short = staffShortfall(o, s)
        if short > 0 { out.parts.append(("Staffing plan (\(short) short)", -min(2.5, 0.8 * Double(short)))) }
        out.score = out.parts.reduce(0) { $0 + $1.1 }
        var field = Double(o.field)
        let f = fiscal(s, agency: a, at: o.sol.posted)
        if f.cycle > 1.2 && f.calendar == "us" { field *= 0.75 }   // short year-end windows keep some competitors out
        out.field = field
        out.blocker = blocker(k, a, s)
        let mine = exp(out.score / 5)
        out.p = out.blocker == nil ? clamp(mine / (mine + field), 0.01, 0.85) : 0
        return out
    }

    /// People the work would need that you couldn't free today: everyone in the role who isn't already on a
    /// programme, the anchor contract or a proposal, less what your other bids under evaluation would take if won.
    /// Evaluators mark down a staffing plan that leans on hires not yet made.
    static func staffShortfall(_ o: GovOpp, _ s: GameState) -> Int {
        guard !o.sol.staff.isEmpty else { return 0 }
        let busy = s.advanced.seconded.union(committed(s))
        var pending: [String: Int] = [:]
        for p in s.advanced.programmes where p.status == .active && p.stage == .award {
            for (k, n) in p.sol.staff { pending[k, default: 0] += max(0, n - s.employees.filter { p.staff.contains($0.id) && $0.role.rawValue == k }.count) }
        }
        for x in s.govMarket.opps where x.id != o.id && (x.status == .submitted || x.status == .writing) {
            for (k, n) in x.sol.staff { pending[k, default: 0] += n }
        }
        var short = 0
        for (k, n) in o.sol.staff.sorted(by: { $0.key < $1.key }) {
            let free = s.employees.filter { $0.role.rawValue == k && !busy.contains($0.id) && o.lead != $0.id }.count - (pending[k] ?? 0)
            short += max(0, n - max(0, free))
        }
        return short
    }

    /// Odds for the proposal as it stands (or as you'd write it at a standard effort with your best free lead).
    static func currentOdds(_ o: GovOpp, _ s: GameState) -> Odds {
        if let e = o.effortLevel { return odds(o, s, effort: e, lead: o.lead, price: o.price, written: o.written, leadSkill: o.leadSkill) }
        return odds(o, s, effort: .standard, lead: bestLead(s)?.id, price: o.price)
    }

    /// Who could lead a proposal: researchers and ML engineers who aren't on a programme, the anchor contract or
    /// another proposal, best first.
    static func leads(_ s: GameState) -> [Employee] {
        let busy = s.advanced.seconded.union(committed(s))
        return s.employees.filter { [.researcher, .mlEngineer, .safety, .data].contains($0.role) && !busy.contains($0.id) }
            .sorted { ($0.skill, $0.id.uuidString) > ($1.skill, $1.id.uuidString) }
    }

    static func bestLead(_ s: GameState) -> Employee? { leads(s).first }

    /// People the marketplace keeps busy (Advanced Projects counts them as seconded).
    static func committed(_ s: GameState) -> Set<UUID> {
        var out = Set<UUID>()
        if let a = s.govMarket.anchor, a.status == .active { out.formUnion(a.assigned) }
        for o in s.govMarket.opps where o.status == .writing { if let l = o.lead { out.insert(l) } }
        return out
    }

    // MARK: - Daily

    static func daily(_ s: inout GameState) {
        if !s.govMarket.started { start(&s) }
        let c = GameCalendar.components(s.date)
        if c.day == 1 || c.day == 15 { post(&s) }
        if c.day == 1 { monthly(&s) }
        releaseNotices(&s)
        writing(&s)
        decide(&s)
        protests(&s)
        if c.day == 3 && c.month == 9 { yearEndOffers(&s, cal: "us") }
        if c.day == 20 && c.month == 11 { yearEndOffers(&s, cal: "national") }
        if c.day == 1 || c.day == 2 || c.day == 13 || c.day == 23 { fiscalNews(&s) }
    }

    static func start(_ s: inout GameState) {
        s.govMarket.started = true
        if s.govMarket.salt.isEmpty { s.govMarket.salt = String(s.rng.state ^ 0x60F_3A2C, radix: 36) }
        for cal in relevantCalendars(s) { s.govMarket.fiscal[cal] = fiscal(s, cal, at: s.date, agency: cal == "eu" ? "ereo" : "").phase.rawValue }
        post(&s)
        if anchorDue(s) { offerAnchor(&s) }
    }

    /// 3.9: the founding award (FoundingContracts) is the lab's first government contract; the anchor contract follows
    /// once that has run its course (finished, ended or declined), so a new lab isn't handed two at once.
    static func anchorDue(_ s: GameState) -> Bool {
        guard !s.govMarket.anchorOffered else { return false }
        guard let c = s.founding.current else { return true }
        return ![FCStatus.offered, .active, .stopWork].contains(c.status)
    }

    static func monthly(_ s: inout GameState) {
        if anchorDue(s) { offerAnchor(&s) }
        anchorMonth(&s)
        followOns(&s)
        // Decided opportunities move to the record.
        let done = s.govMarket.opps.filter { $0.status.decided }
        s.govMarket.opps.removeAll { $0.status.decided }
        s.govMarket.history.insert(contentsOf: done.reversed(), at: 0)
        if s.govMarket.history.count > 60 { s.govMarket.history.removeLast(s.govMarket.history.count - 60) }
    }

    static func releaseNotices(_ s: inout GameState) {
        for i in s.govMarket.opps.indices where s.govMarket.opps[i].status == .notice {
            guard let r = s.govMarket.opps[i].release, r <= s.date else { continue }
            s.govMarket.opps[i].status = .open
        }
    }

    /// Proposals that are finished go in; ones still unfinished at the deadline miss it.
    static func writing(_ s: inout GameState) {
        for i in s.govMarket.opps.indices where s.govMarket.opps[i].status == .writing {
            let o = s.govMarket.opps[i]
            if let done = o.writeDone, done <= s.date, o.sol.closes > s.date {
                submit(&s, i, written: 1)
            } else if o.sol.closes <= s.date {
                s.govMarket.opps[i].status = .missed
                s.govMarket.opps[i].decided = s.date
                release(&s, o.lead)
                Sim.news(&s, "Proposal missed the deadline: \(o.sol.title)", "It wasn't finished when \(o.agencyDef?.short ?? "the agency")'s window closed. The \(Fmt.money(o.bpCost)) of proposal effort is gone.",
                         .company, good: false)
            }
        }
    }

    static func release(_ s: inout GameState, _ lead: UUID?) {
        guard let lead, !s.advanced.programmes.contains(where: { $0.status == .active && $0.staff.contains(lead) }),
              !(s.govMarket.anchor?.assigned.contains(lead) ?? false) else { return }
        s.advanced.seconded.remove(lead)
    }

    static func submit(_ s: inout GameState, _ i: Int, written: Double) {
        var o = s.govMarket.opps[i]
        o.written = clamp(written, 0.3, 1)
        if let l = o.lead, let e = s.employees.first(where: { $0.id == l }) { o.leadSkill = e.skill }
        o.status = .submitted
        o.submitted = s.date
        o.oddsAtSubmit = currentOdds(o, s).p
        s.govMarket.opps[i] = o
        release(&s, o.lead)
        alert(&s, "sub|\(o.id)", "Proposal submitted: \(o.sol.title)",
              "\(o.agencyDef?.short ?? "The agency") expects to decide around \(o.decisionDue.gameShort). Odds when it went in: \(Fmt.pct(o.oddsAtSubmit, decimals: 0)).")
    }

    // MARK: - Decisions

    static func decide(_ s: inout GameState) {
        for i in s.govMarket.opps.indices where s.govMarket.opps[i].status == .submitted && s.govMarket.opps[i].decisionDue <= s.date {
            let o = s.govMarket.opps[i]
            guard let a = o.agencyDef, let k = o.def else { continue }
            // Budget holds: a lapse freezes everything; a continuing resolution or provisional budget holds new starts.
            let f = fiscal(s, agency: a)
            // (A framework-programme transition only stops new calls: the old programme's evaluations still finish.)
            if f.phase == .lapse || (f.holdsNewStarts && k.newStart && !o.invited && f.phase != .enacted && f.phase != .transition) {
                let next = GameCalendar.addDays(f.until ?? GameCalendar.addDays(s.date, 30), f.phase == .lapse ? 7 : 14)
                s.govMarket.opps[i].decisionDue = max(GameCalendar.addDays(s.date, 7), next)
                let why = f.phase == .lapse ? "the government is shut down (lapse in appropriations)" : "\(f.phase.title.lowercased()): no new starts until the budget passes"
                if !o.notes.contains(where: { $0.hasPrefix(f.phase.title) }) {
                    s.govMarket.opps[i].notes.append("\(f.phase.title): decision delayed to about \(s.govMarket.opps[i].decisionDue.gameShort) — \(why).")
                    alert(&s, "slip|\(o.id)|\(f.phase.rawValue)", "Award delayed: \(o.sol.title)", "\(a.short) can't award it yet: \(why). Expected now around \(s.govMarket.opps[i].decisionDue.gameShort).")
                }
                continue
            }
            evaluate(&s, i)
        }
    }

    static func evaluate(_ s: inout GameState, _ i: Int) {
        var o = s.govMarket.opps[i]
        guard let a = o.agencyDef, let k = o.def, let e = o.effortLevel else { return }
        let od = odds(o, s, effort: e, lead: nil, price: o.price, written: o.written, leadSkill: o.leadSkill)
        let r = roll(s, "award|\(o.id)")
        o.finalOdds = od.p
        o.roll = r
        o.decided = s.date
        let won = r < od.p
        o.winnerPrice = clamp(0.8 + 0.17 * roll(s, "wprice|\(o.id)"), 0.75, 0.99)
        if won {
            o.winner = s.companyName
        } else {
            let names = GovMarketCatalog.competitors[a.region == .us ? .us : .eu] ?? ["another bidder"]
            o.winner = names[min(names.count - 1, Int(roll(s, "winner|\(o.id)") * Double(names.count)))]
            // Bigger prototype and task-order lots sometimes go to a rival lab you know.
            let labs = s.competitors.filter { $0.alive && AdvancedProjects.labRegion($0.id) == a.region }.map(\.id).sorted()
            if o.sol.ceiling >= 3e6, !labs.isEmpty, roll(s, "rivalwin|\(o.id)") < 0.35 {
                o.winner = CompetitorCatalog.def(labs[min(labs.count - 1, Int(roll(s, "rivallab|\(o.id)") * Double(labs.count)))]).name
            }
        }
        o.debrief = debrief(o, od, won: won, s)
        s.govMarket.opps[i] = o
        if won {
            // A disappointed bidder may protest a contract award; the agency must stay performance while it's decided.
            let protestable = k.challenge == "protest" && k.payout != .compute && o.sol.ceiling >= 1e6 && !o.invited
            if protestable && roll(s, "rivalprotest|\(o.id)") < 0.1 {
                s.govMarket.opps[i].status = .held
                s.govMarket.opps[i].protestFiled = s.date
                s.govMarket.opps[i].protestDue = GameCalendar.addDays(s.date, 100)
                Sim.news(&s, "\(a.short) picks you for \(o.sol.title) — and a loser protests",
                         "\(a.name) chose your proposal (odds were \(Fmt.pct(od.p, decimals: 0))), but a losing bidder has filed a bid protest. Work can't start until it's decided, within 100 days. Most protests are denied.",
                         .company, image: GovMarketCatalog.templates.first?.image, important: true, good: true)
                return
            }
            award(&s, i)
        } else {
            s.govMarket.opps[i].status = .lost
            s.govMarket.losses += 1
            // A serious bid still earns the agency's notice (a little record, capped as Advanced Projects caps it).
            if od.p >= 0.2 {
                let credit = min(0.2, max(0, 1 - (s.advanced.lossCredit[a.id] ?? 0)))
                if credit > 0 {
                    s.advanced.ratings[a.id] = clamp(AdvancedProjects.rating(s, a.id) + credit, -10, 10)
                    s.advanced.lossCredit[a.id, default: 0] += credit
                }
            }
            Sim.news(&s, "\(a.short) awards \(o.sol.title) to \(o.winner)",
                     "Your proposal lost (odds \(Fmt.pct(od.p, decimals: 0)); the roll was \(Fmt.trim(r, 2))). \(o.debrief.first ?? "") The debrief is on the Gov Contracts page.",
                     .company, good: false)
            offerProtest(&s, i, odds: od.p)
        }
    }

    /// The agency's debrief (US), evaluation summary report (EU) or assessment letter (national funds).
    static func debrief(_ o: GovOpp, _ od: Odds, won: Bool, _ s: GameState) -> [String] {
        guard let k = o.def else { return [] }
        let part = { (name: String) in od.parts.first { $0.0.hasPrefix(name) }?.1 ?? 0 }
        let q = part("Proposal quality") + part("Technical credibility")
        var lines: [String] = []
        let rec = record(s)
        if k.challenge == "review" {
            // EU: three criteria out of five, threshold 10, a funding line set by the budget.
            let base = 9.6 + 0.35 * q + 0.25 * part("Past performance") + 0.2 * part("Capture")
            let ex = clamp(((base / 3 + 0.25 * part("Proposal quality")) * 2).rounded() / 2, 1, 5)
            let im = clamp(((base / 3 + 0.2 * part("Capture")) * 2).rounded() / 2, 1, 5)
            var impl = clamp(((base / 3 + 0.25 * part("Past performance") + 0.25 * part("Staffing")) * 2).rounded() / 2, 1, 5)
            let line = clamp(12.5 + 1.5 * (1 - o.baseRate * 4), 11.5, 14.5)
            // The panel's scores and the funding decision agree: implementation is the criterion that tips it.
            if won && ex + im + impl < line { impl = min(5, ((line - ex - im) * 2).rounded(.up) / 2) }
            if !won && ex + im + impl >= line { impl = max(1, ((line - 0.5 - ex - im) * 2).rounded(.down) / 2) }
            let total = ex + im + impl
            lines.append("Evaluation summary: excellence \(Fmt.trim(ex, 1))/5, impact \(Fmt.trim(im, 1))/5, implementation \(Fmt.trim(impl, 1))/5 — \(Fmt.trim(total, 1))/15 (threshold 10).")
            lines.append(won || total >= line ? "Above the funding line (\(Fmt.trim(line, 1))): invited to grant preparation." : (total >= 10 ? "Above threshold but below the funding line (\(Fmt.trim(line, 1))): not funded this time." : "Below threshold: not fundable as written."))
        } else {
            let tech = q >= 3 ? "Outstanding" : (q >= 1 ? "Good" : (q >= -1.5 ? "Acceptable" : "Marginal"))
            lines.append("Technical rating: \(tech). Past performance: \(rec.text).")
            if o.sol.type != .grant && k.payout == .programme {
                let gap = o.price - o.winnerPrice
                lines.append(won ? "Price: \(Fmt.pct(o.price, decimals: 0)) of the ceiling, judged fair and reasonable." :
                    "Price: you bid \(Fmt.pct(o.price, decimals: 0)) of the ceiling; the awardee \(Fmt.pct(o.winnerPrice, decimals: 0))\(gap > 0.03 ? " — a weakness" : "").")
            }
        }
        var strengths: [String] = [], weaknesses: [String] = []
        if part("Proposal quality") >= 1.5 { strengths.append("a well-argued technical volume with a credible test plan") }
        if part("Proposal quality") <= -1.5 { weaknesses.append(o.lead == nil && o.leadSkill == nil ? "no named principal investigator with relevant work" : "the technical volume was thin on evaluation and risks") }
        if o.written < 0.95 { weaknesses.append("sections looked unfinished (submitted at \(Fmt.pct(o.written, decimals: 0)))") }
        if part("Technical credibility") >= 1.2 { strengths.append("a team and track record the panel recognised") }
        if part("Past performance") >= 1 { strengths.append("relevant past performance") }
        if rec.delivered == 0 && s.govMarket.assessments.isEmpty { weaknesses.append("no government past performance (rated neutral)") }
        if !o.answeredNotice && (o.def?.notice ?? false) { weaknesses.append("the agency shaped the requirement with firms that answered its sources-sought notice") }
        if part("Capture") >= 1.5 { strengths.append("clear understanding of the customer's problem") }
        if part("Staffing") < 0 { weaknesses.append("the staffing plan depends on people not yet hired") }
        if !strengths.isEmpty { lines.append("Strengths: " + strengths.joined(separator: "; ") + ".") }
        if !weaknesses.isEmpty { lines.append("Weaknesses: " + weaknesses.joined(separator: "; ") + ".") }
        if !won { lines.append("Awardee: \(o.winner).") }
        return lines
    }

    /// Turn a win into what it pays: a programme Advanced Projects runs, GPU hours or a contract seat.
    static func award(_ s: inout GameState, _ i: Int) {
        var o = s.govMarket.opps[i]
        guard let k = o.def, let a = o.agencyDef else { return }
        o.status = .won
        s.govMarket.wins += 1
        s.govMarket.awarded += o.sol.ceiling * (k.payout == .programme && o.sol.type != .grant ? o.price : 1)
        switch k.payout {
        case .programme:
            var sol = o.sol
            sol.bidders = []
            s.advanced.engaged = true
            AdvancedProjects.award(&s, sol, bid: ProposalBid(price: o.sol.type == .grant ? clamp(o.price, 0.75, 1) : o.price, submitted: o.submitted ?? s.date,
                                                             proposalCost: o.bpCost, odds: o.oddsAtSubmit), margin: 10)
            o.programme = s.advanced.programmes.last?.id
        case .compute:
            s.cloudCredits += o.sol.ceiling
            s.govMarket.computeAwarded += o.sol.ceiling
            s.brand = min(100, s.brand + 0.5)
            s.advanced.ratings[a.id] = clamp(AdvancedProjects.rating(s, a.id) + 0.3, -10, 10)
            Stakeholders.move(&s, ["researchers": 1], "Won a public compute allocation from \(a.short)")
            Sim.news(&s, "Compute allocation: \(Fmt.money(o.sol.ceiling)) of GPU hours from \(a.short)",
                     "\(o.def?.title(s.year) ?? "The allocation") for \"\(o.sol.title)\": spent automatically on your rentals as cloud credits. You publish what you learn.",
                     .research, image: "supercomputer", good: true)
        case .seat:
            let seat = GovSeat(id: o.id, agency: a.id, name: "AI & data services multiple-award contract", awarded: s.date, ends: GameCalendar.addMonths(s.date, 60))
            s.govMarket.seats.append(seat)
            s.cash += o.sol.ceiling
            s.month.revContracts += o.sol.ceiling
            s.lifetimeRevenue += o.sol.ceiling
            s.advanced.ratings[a.id] = clamp(AdvancedProjects.rating(s, a.id) + 0.5, -10, 10)
            Sim.news(&s, "Seat won on \(a.short)'s AI & data services contract",
                     "Five years, with the \(Fmt.money(o.sol.ceiling)) guaranteed minimum paid. Task orders under it are competed among the holders only and will show up on the Gov Contracts page.",
                     .company, image: "gov_capitol", important: true, good: true)
        }
        s.govMarket.opps[i] = o
    }

    static func offerProtest(_ s: inout GameState, _ i: Int, odds p: Double) {
        let o = s.govMarket.opps[i]
        guard let k = o.def, let a = o.agencyDef, !k.challenge.isEmpty, k.payout != .compute else { return }
        let big = o.sol.ceiling >= (k.challenge == "review" ? 250_000 : 400_000)
        // Civilian task orders under $10M can't be protested; nobody protests a long shot.
        guard big, p >= 0.15, !(k.id == "task" && o.sol.ceiling < 1e7) else { return }
        let cost = protestCost(o)
        let (label, detail): (String, String)
        switch k.challenge {
        case "review": (label, detail) = ("Request an evaluation review", "Free. The review committee re-reads the evaluation; it rarely changes the result (a few per cent).")
        case "complaint": (label, detail) = ("Complain to the appeals board (\(Fmt.money(cost)))", "Legal fees \(Fmt.money(cost)). About one complaint in eight gets a new evaluation.")
        default: (label, detail) = ("File a bid protest (\(Fmt.money(cost)))", "Legal fees \(Fmt.money(cost)); a decision within 100 days. About a third of protests end in corrective action or a sustain; \(a.short) will remember a denied one.")
        }
        Events.addDecision(&s, kind: protestKind, title: "Lost: \(o.sol.title)",
                           body: "\(a.name) awarded it to \(o.winner). \(o.debrief.prefix(2).joined(separator: " "))",
                           image: "gov_capitol",
                           options: [DecisionOption(label: "Accept the debrief", detail: "Take the lessons into the next bid."),
                                     DecisionOption(label: label, detail: detail)],
                           amount: k.challenge == "review" ? 0 : cost, ref: o.id)
    }

    static func protestCost(_ o: GovOpp) -> Double {
        guard let k = o.def else { return 0 }
        if k.challenge == "review" { return 0 }
        let base = k.challenge == "complaint" ? 25_000 : 60_000
        return (min(300_000, Double(base) + o.sol.ceiling * 0.02) / 5_000).rounded() * 5_000
    }

    static func protests(_ s: inout GameState) {
        for i in s.govMarket.opps.indices {
            let o = s.govMarket.opps[i]
            guard let due = o.protestDue, due <= s.date, o.status == .held || o.status == .protesting else { continue }
            guard let a = o.agencyDef, let k = o.def else { continue }
            let u = roll(s, "protest|\(o.id)")
            if o.status == .held {
                // A competitor's protest: most are denied; corrective action re-evaluates.
                if u < 0.12 {
                    let keep = roll(s, "reeval|\(o.id)") < max(0.35, o.finalOdds)
                    s.govMarket.opps[i].protestOutcome = keep ? "Corrective action: re-evaluated, and your award stands." : "Corrective action: on re-evaluation \(a.short) picked another bidder."
                    if keep { award(&s, i) } else {
                        s.govMarket.opps[i].status = .lost
                        s.govMarket.losses += 1
                        Sim.news(&s, "Award overturned: \(o.sol.title)", "After a competitor's protest \(a.short) re-evaluated and picked another bidder.", .company, important: true, good: false)
                    }
                } else {
                    s.govMarket.opps[i].protestOutcome = "Protest denied: the award stands."
                    award(&s, i)
                }
                continue
            }
            // Yours.
            let close = o.finalOdds >= 0.3
            let sustain = k.challenge == "review" ? 0.03 : (k.challenge == "complaint" ? 0.12 : (close ? 0.32 : 0.2))
            if u < sustain {
                s.govMarket.protestsWon += 1
                let win = roll(s, "protestwin|\(o.id)") < min(0.8, o.finalOdds * 1.6)
                s.govMarket.opps[i].protestOutcome = win ? "Sustained: re-evaluated, and \(a.short) awards it to you." : "Corrective action: re-evaluated, but the original awardee keeps it."
                if win {
                    s.govMarket.losses = max(0, s.govMarket.losses - 1)
                    award(&s, i)
                    Sim.news(&s, "Protest won: \(o.sol.title)", "\(a.short) re-evaluated after your challenge and awarded you the work.", .company, important: true, good: true)
                } else {
                    s.govMarket.opps[i].status = .lost
                    Sim.news(&s, "Protest: re-evaluation keeps the award with \(o.winner)", "\(a.short) took corrective action, but the result held.", .company, good: false)
                }
            } else {
                s.govMarket.opps[i].status = .lost
                s.govMarket.opps[i].protestOutcome = k.challenge == "review" ? "Review complete: the evaluation stands." : "Denied: the evaluation was reasonable and followed the solicitation."
                if k.challenge != "review" { s.advanced.ratings[a.id] = clamp(AdvancedProjects.rating(s, a.id) - 0.3, -10, 10) }
                Sim.news(&s, k.challenge == "review" ? "Evaluation review: \(o.sol.title) stays unfunded" : (k.challenge == "complaint" ? "Complaint rejected: \(o.sol.title)" : "Protest denied: \(o.sol.title)"), "\(s.govMarket.opps[i].protestOutcome)\(k.challenge == "review" ? "" : " \(a.short) won't forget it in a hurry (record −0.3).")", .company, good: false)
            }
        }
    }

    // MARK: - Follow-ons and year-end money

    /// A finished Phase I or prototype earns an invitation to propose the next phase (most performers get one).
    static func followOns(_ s: inout GameState) {
        for p in s.advanced.programmes where p.status != .active && p.sol.template.hasPrefix("gm_") && !s.govMarket.followed.contains(p.id) {
            s.govMarket.followed.insert(p.id)
            guard p.status == .completed, let a = p.sol.agencyDef else { continue }
            let next: String? = p.sol.template == "gm_sbir1" ? "sbir2" : (p.sol.template == "gm_proto" ? "prod" : nil)
            guard let nk = next, let k = GovMarketCatalog.kind(nk) else { continue }
            let odds = clamp(0.6 + 0.04 * AdvancedProjects.rating(s, a.id), 0.3, 0.9)
            guard roll(s, "follow|\(p.id)") < odds else {
                Sim.news(&s, "No follow-on from \(a.short)", "\(p.sol.title) was delivered, but \(a.short) has no money for the next phase this year.", .company)
                continue
            }
            let value = nk == "prod" ? p.value * (3 + 2 * roll(s, "prodsize|\(p.id)")) : nil
            var o = make(k, a, &s, key: "follow|\(p.id)", invited: true, parent: p, valueOverride: value)
            o.field = nk == "prod" ? 0 : 1
            o.baseRate = k.baseRate
            s.govMarket.opps.append(o)
            Sim.news(&s, "\(a.short) invites you to propose \(k.title(s.year).lowercased())",
                     "After \(p.sol.title), \(a.name) asks for a proposal worth up to \(Fmt.money(o.sol.ceiling)). Invitation-only; it closes \(o.sol.closes.gameShort).",
                     .company, important: true, good: true)
            alert(&s, "follow|\(o.id)", "Invitation: \(k.title(s.year))", "\(a.short) wants a proposal by \(o.sol.closes.gameShort) — up to \(Fmt.money(o.sol.ceiling)).", celebrate: true)
        }
    }

    /// Money that would expire: in early September a US agency that knows you (or the vehicle you hold a seat on) may
    /// place a small sole-source order; in late November a national agency may do the same before its year closes.
    static func yearEndOffers(_ s: inout GameState, cal: String) {
        let y = GameCalendar.components(s.date).year
        let candidates = (AgencyCatalog.all + GovMarketCatalog.agencies).filter { a in
            let c = calendar(a)
            guard cal == "us" ? c == "us" : (c != "us" && c != "eu" && c.count == 2 && !["uk", "jp", "in", "cn"].contains(c)) else { return false }
            guard fiscal(s, agency: a).phase != .lapse else { return false }
            let known = AdvancedProjects.rating(s, a.id) >= 1.5 || s.govMarket.seats.contains { $0.agency == a.id } || (s.govMarket.anchor?.agency == a.id)
            let allowed = a.region == HQ.region(s) || (a.region == .us && [Region.uk, .eu, .japanKorea].contains(HQ.region(s)) && a.kind == .defence)
            return known && allowed && !s.govMarket.yearEnd.contains("\(a.id)|\(y)")
        }.sorted { (AdvancedProjects.rating(s, $0.id), $0.id) > (AdvancedProjects.rating(s, $1.id), $1.id) }
        guard let a = candidates.first, roll(s, "yearend|\(a.id)|\(y)") < 0.45 else { return }
        s.govMarket.yearEnd.insert("\(a.id)|\(y)")
        let value = ((150_000 + 600_000 * roll(s, "yesize|\(a.id)|\(y)")) * era(s.year) * min(2, AdvancedProjects.companyScale(s)) / 5_000).rounded() * 5_000
        let months = 4 + Int(roll(s, "yemonths|\(a.id)|\(y)") * 4)
        let topics = GovMarketCatalog.topics[a.id] ?? ["Applied AI support"]
        let topic = topics[min(topics.count - 1, Int(roll(s, "yetopic|\(a.id)|\(y)") * Double(topics.count)))]
        Events.addDecision(&s, kind: yearEndKind, title: "Year-end order from \(a.short): \(Fmt.money(value))",
                           body: "\(a.name) has money that expires \(cal == "us" ? "on 30 September" : "at the end of December") and a programme manager who knows your work. A sole-source order, no competition: \"\(topic)\", \(months) months, fixed price. It needs two people from your team.",
                           image: cal == "us" ? "gov_capitol" : homeImage(s),
                           options: [DecisionOption(label: "Decline", detail: "Keep the team on your own work."),
                                     DecisionOption(label: "Take the order", detail: "\(Fmt.money(value)), \(months) months. Runs as a programme on Advanced Projects: staff it within 4 months.")],
                           amount: value, ref: "\(a.id)|\(months)|\(topic)")
    }

    static func homeImage(_ s: GameState) -> String {
        switch HQ.country(s).id {
        case "us": "gov_capitol"
        case "dk": "gov_folketinget"
        case "fr": "gov_assemblee"
        case "it": "gov_montecitorio"
        default: "gov_eu_commission"
        }
    }

    // MARK: - Fiscal news

    static func fiscalNews(_ s: inout GameState) {
        for cal in relevantCalendars(s) {
            let f = fiscal(s, cal, at: s.date, agency: cal == "eu" ? "ereo" : "")
            let was = s.govMarket.fiscal[cal]
            guard was != f.phase.rawValue else { continue }
            s.govMarket.fiscal[cal] = f.phase.rawValue
            guard was != nil else { continue }
            let home = cal == HQ.country(s).id || (cal == "us" && HQ.country(s).id == "us")
            guard home || s.govMarket.engaged else { continue }
            let (title, body): (String, String)
            switch (f.phase, cal) {
            case (.continuing, _):
                title = "Congress passes a continuing resolution"
                body = "\(f.fyLabel) starts without full-year appropriations. Agencies keep spending at last year's rate, but new programmes can't start: awards that count as new starts wait. \(untilText(f, s).prefix(1).uppercased() + untilText(f, s).dropFirst())."
            case (.lapse, _):
                title = "US government shuts down"
                body = "Appropriations lapsed. Agencies send staff home, contracting officers stop awarding and contractors get stop-work orders: anything funded by an affected agency stops billing until it ends."
            case (.provisional, _):
                title = "\(calendarName(cal)) starts the year without a budget"
                body = "No budget law was passed in time, so spending continues month by month at last year's level. New programmes and grant decisions wait for the budget."
            case (.transition, _):
                title = "EU research calls pause between framework programmes"
                body = f.note + ": no new collaborative or accelerator calls until it is. Evaluations of calls already closed carry on."
            case (.enacted, "us"):
                title = was == Phase.lapse.rawValue ? "US government reopens" : "Congress passes full-year appropriations"
                body = was == Phase.lapse.rawValue ? "Funding is restored. Stop-work orders are lifted and delayed awards resume in the coming weeks." : "\(f.fyLabel) finally has its budget. Agencies can make new awards again; expect a burst of delayed decisions."
            case (.enacted, _):
                title = "\(calendarName(cal)) adopts its budget"
                body = "Delayed grant decisions and new programmes can go ahead."
            }
            Sim.news(&s, title, body, .policy, image: cal == "us" ? "gov_capitol" : (cal == "eu" ? "gov_eu_commission" : homeImage(s)), important: f.phase == .lapse, good: f.phase == .enacted)
        }
    }

    static func alert(_ s: inout GameState, _ key: String, _ title: String, _ body: String, critical: Bool = false, celebrate: Bool = false) {
        guard s.govMarket.engaged else { return }
        Alerts.raise(&s, .advanced, key: "gm|" + key, title: title, body: body, screen: .govContracts, critical: critical, celebrate: celebrate, cooldown: 0)
    }

    /// Sidebar badge: an anchor contract short of staff, and won work waiting for a team.
    static func badge(_ s: GameState) -> Int {
        let short = (s.govMarket.anchor.map { $0.status == .active && $0.underStaffedMonths > 0 } ?? false) ? 1 : 0
        let waiting = s.advanced.programmes.filter { $0.status == .active && $0.stage == .award && $0.sol.template.hasPrefix("gm_") }.count
        return short + waiting
    }
}
