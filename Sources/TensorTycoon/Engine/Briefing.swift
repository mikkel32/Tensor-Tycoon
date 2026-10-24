import Foundation

/// One line of the monthly briefing: what happened, whether it was good for you, and where to act on it.
struct BriefingLine: Codable, Hashable {
    var text: String
    var good: Bool? = nil
    @D var screen: String = ""

    var target: Screen? { Screen(rawValue: screen) }
}

/// What changed last month and why: revenue moves with their causes, what rivals did, what's coming, and what to do.
struct MonthlyBriefing: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var month: Date
    var headline: String
    var revenue: Double
    /// Change in revenue per day against the month before (fraction).
    var revenueChange: Double
    var profit: Double
    var cash: Double
    /// Months of cash at last month's burn; nil when profitable.
    var runway: Double?
    var drivers: [BriefingLine]
    var rivals: [BriefingLine]
    var risks: [BriefingLine]
    var actions: [BriefingLine]
    @D var seen: Bool = false
}

enum Briefing {
    /// Market position at month end, recorded with the month so the next briefing can compare.
    static func snapshot(_ s: GameState, _ r: inout MonthRecord) {
        r.apiShare = s.apiShareNow
        r.consumerShare = s.consumerShare
        r.agentShare = s.agentShare
        let live = s.models.filter { $0.released && !$0.retired }
        let board = Leaderboard.entries(s, includeUnreleased: false)
        if let me = board.filter(\.isPlayer).max(by: { $0.index < $1.index }) {
            // Rank among labs, not models: one lab's back catalogue shouldn't push you down.
            r.rank = Leaderboard.labRank(index: me.index, board: board, gone: Leaderboard.goneLabs(s))
            r.myIndex = me.index
        }
        let api = live.filter { $0.api && $0.demandTokensDay > 0 }
        let tokens = api.reduce(0) { $0 + $1.demandTokensDay }
        r.apiPrice = tokens > 0 ? api.reduce(0) { $0 + $1.apiPrice * $1.demandTokensDay } / tokens : 0
        let demand = live.reduce(0) { $0 + $1.demandTokensDay }
        r.served = demand > 0 ? live.reduce(0) { $0 + min($1.servedTokensDay, $1.demandTokensDay) } / demand : 1
        r.contracts = s.deals.filter(\.active).count
        r.headcount = s.employees.count
        r.bestC = live.map(\.c).max() ?? 0
    }

    /// Build the briefing for the month that just closed (`cur`), against the one before it.
    static func build(_ s: inout GameState, _ cur: MonthRecord) {
        guard let prev = s.history.last else { return }
        let start = cur.month
        let end = s.date
        func inMonth(_ d: Date?) -> Bool { d.map { $0 >= start && $0 < end } ?? false }
        // Compare per day so a 28-day February doesn't read as a slump.
        let curDays = Double(GameCalendar.daysInMonth(cur.month))
        let prevDays = Double(GameCalendar.daysInMonth(prev.month))
        func rate(_ now: Double, _ before: Double) -> Double {
            let a = now / curDays, b = before / prevDays
            return b > 0 ? a / b - 1 : (a > 0 ? 1 : 0)
        }
        let myName = s.models.filter { $0.released && !$0.retired }.max { $0.index < $1.index }?.name ?? "your best model"

        // What rivals did this month.
        var rivals: [BriefingLine] = []
        var rivalReleases: [(lab: String, model: String, index: Double)] = []
        var newPlays: [(lab: String, play: RivalPlay)] = []
        for c in s.competitors where !c.acquired {
            for m in c.models where inMonth(m.date) {
                rivalReleases.append((c.def.name, m.name, m.index))
                let ahead = cur.myIndex > 0 && m.index > cur.myIndex
                rivals.append(BriefingLine(text: "\(c.def.name) shipped \(m.name): index \(Fmt.score(m.index))"
                                           + (cur.myIndex > 0 ? (ahead ? ", ahead of \(myName) (\(Fmt.score(cur.myIndex)))." : ", behind \(myName) (\(Fmt.score(cur.myIndex))).") : "."),
                                           good: cur.myIndex > 0 ? !ahead : nil, screen: Screen.rivalWatch.rawValue))
            }
            for m in c.openModels where inMonth(m.date) {
                rivals.append(BriefingLine(text: "\(c.def.name) open-sourced \(m.name): free weights at index \(Fmt.score(m.index)) pull API prices down.",
                                           good: false, screen: Screen.rivalWatch.rawValue))
            }
            if inMonth(c.playSince), let play = RivalPlay(rawValue: c.play) {
                newPlays.append((c.def.name, play))
                let hurts: Bool? = [.priceWar, .talentRaid, .lobby, .race, .openGambit].contains(play) ? false : nil
                rivals.append(BriefingLine(text: "\(c.def.name) switched to \(play.title.lowercased()): \(c.playReason)", good: hurts, screen: Screen.competitors.rawValue))
            }
        }
        // What's coming: rumoured launches in the next ~two months that would beat you.
        let set = Leaderboard.indexSet(s)
        for row in RivalIntel.rows(s, set: set).filter({ $0.threat == .passYou && GameCalendar.daysBetween(end, $0.outlook.low) <= 60 }).prefix(2) {
            rivals.append(BriefingLine(text: "Coming: \(row.lab)'s \(row.project.codename) is rumoured for \(row.outlook.low.gameShort)–\(row.outlook.high.gameShort) at about index \(Fmt.score(row.outlook.index)).",
                                       good: false, screen: Screen.rivalWatch.rawValue))
        }

        // Your own launches this month.
        let launches = s.models.filter { inMonth($0.releaseDate) }

        // Revenue streams that moved, biggest first, each with its likely causes.
        let streams: [(name: String, now: Double, before: Double, screen: Screen)] = [
            ("API", cur.revAPI, prev.revAPI, .market),
            ("Chat subscriptions", cur.revConsumer, prev.revConsumer, .market),
            ("Enterprise contracts", cur.revEnterprise, prev.revEnterprise, .market),
            ("Agent seats", cur.revAgents, prev.revAgents, .market),
            ("Cloud leasing", cur.revCloud, prev.revCloud, .chipSales),
            ("Chip sales", cur.revChips, prev.revChips, .chipSales),
            ("Licensing", cur.revLicensing, prev.revLicensing, .industry),
            ("Agent labour", cur.revLabor, prev.revLabor, .swarms),
            ("Product lines", cur.revOther, prev.revOther, .products),
            ("Government contracts", cur.revContracts, prev.revContracts, .advancedProjects),   // 3.8: milestone payments, kept apart
        ]
        let total = max(cur.revenue, prev.revenue)
        let moved = streams.map { st -> (name: String, now: Double, before: Double, screen: Screen, delta: Double) in
            (st.name, st.now, st.before, st.screen, st.now - st.before * curDays / prevDays)
        }
        .filter { abs($0.delta) >= max(1_000, total * 0.03) }
        .sorted { abs($0.delta) > abs($1.delta) }
        .prefix(3)

        var drivers: [BriefingLine] = []
        var topCause = ""
        for st in moved {
            var causes: [String] = []
            switch st.name {
            case "API":
                if abs(cur.apiShare - prev.apiShare) >= 0.01 {
                    causes.append("API share \(Fmt.pct(prev.apiShare, decimals: 0)) → \(Fmt.pct(cur.apiShare, decimals: 0))")
                }
                if prev.apiPrice > 0 && cur.apiPrice > 0 && abs(cur.apiPrice / prev.apiPrice - 1) >= 0.05 {
                    causes.append("average price \(Fmt.price(prev.apiPrice)) → \(Fmt.price(cur.apiPrice))/M")
                }
            case "Chat subscriptions":
                if prev.paidUsers > 0 && abs(cur.paidUsers / prev.paidUsers - 1) >= 0.03 {
                    causes.append("paying users \(Fmt.count(prev.paidUsers)) → \(Fmt.count(cur.paidUsers))")
                }
                if abs(cur.consumerShare - prev.consumerShare) >= 0.01 {
                    causes.append("chat share \(Fmt.pct(prev.consumerShare, decimals: 0)) → \(Fmt.pct(cur.consumerShare, decimals: 0))")
                }
            case "Agent seats":
                if abs(cur.agentShare - prev.agentShare) >= 0.01 {
                    causes.append("agent share \(Fmt.pct(prev.agentShare, decimals: 0)) → \(Fmt.pct(cur.agentShare, decimals: 0))")
                }
            case "Enterprise contracts":
                if cur.contracts != prev.contracts {
                    causes.append("\(cur.contracts > prev.contracts ? "signed" : "lost") \(abs(cur.contracts - prev.contracts)) contract\(abs(cur.contracts - prev.contracts) == 1 ? "" : "s")")
                }
            default:
                break
            }
            if ["API", "Chat subscriptions", "Agent seats", "Enterprise contracts"].contains(st.name) {
                // Nothing on sale is the biggest cause you control.
                if st.delta < 0 && cur.bestC == 0 && prev.bestC > 0 {
                    causes.insert("no model was on sale at month end", at: 0)
                }
                // Turning users away is the cause you control: name it first.
                if st.delta < 0 && (cur.served < 0.85 || (cur.served < 0.95 && cur.served < prev.served - 0.03)) {
                    causes.insert("you served only \(Fmt.pct(cur.served, decimals: 0)) of demand", at: 0)
                }
                if st.delta < 0, let r = rivalReleases.filter({ $0.index > cur.myIndex }).max(by: { $0.index < $1.index }) {
                    causes.append("\(r.lab) shipped \(r.model)")
                }
                if st.delta < 0, st.name == "API", let p = newPlays.first(where: { $0.play == .priceWar }) {
                    causes.append("\(p.lab)'s price war")
                }
                if st.delta > 0, let m = launches.max(by: { $0.index < $1.index }) {
                    causes.append("you launched \(m.name)")
                }
            }
            let pct = st.before > 0 ? st.delta / (st.before * curDays / prevDays) : 1
            let head = "\(st.name) \(st.delta >= 0 ? "+" : "−")\(Fmt.money(abs(st.delta)))"
                + (st.before > 0 ? " (\(st.delta >= 0 ? "+" : "−")\(Fmt.pct(abs(pct), decimals: 0)))" : "")
            if topCause.isEmpty, let c = causes.first { topCause = c }
            drivers.append(BriefingLine(text: head + (causes.isEmpty ? "." : ": " + causes.joined(separator: ", ") + "."), good: st.delta >= 0, screen: st.screen.rawValue))
        }
        // Costs that jumped.
        let costLines: [(String, Double, Double)] = [
            ("cloud rent", cur.costRent, prev.costRent), ("power", cur.costPower, prev.costPower),
            ("datacenters", cur.costSites, prev.costSites), ("payroll", cur.costPayroll, prev.costPayroll),
            ("data", cur.costData, prev.costData), ("marketing", cur.costMarketing, prev.costMarketing),
            ("interest", cur.costInterest, prev.costInterest),
        ]
        if let jump = costLines.map({ ($0.0, $0.1 - $0.2 * curDays / prevDays) }).max(by: { $0.1 < $1.1 }),
           jump.1 > max(5_000, cur.opex * 0.08) {
            var why = ""
            if jump.0 == "payroll" && cur.headcount != prev.headcount { why = " (\(cur.headcount - prev.headcount >= 0 ? "+" : "")\(cur.headcount - prev.headcount) people)" }
            drivers.append(BriefingLine(text: "Costs: \(jump.0) +\(Fmt.money(jump.1))\(why).", good: false, screen: Screen.finance.rawValue))
        }
        for m in launches {
            drivers.append(BriefingLine(text: "You launched \(m.name) (index \(Fmt.score(m.index))).", good: true, screen: Screen.models.rawValue))
        }
        if cur.rank > 0 && prev.rank > 0 && cur.rank != prev.rank {
            drivers.append(BriefingLine(text: "You're now the #\(cur.rank) lab by your best model (was #\(prev.rank)).", good: cur.rank < prev.rank,
                                        screen: Screen.leaderboard.rawValue))
        }

        // Risks.
        var risks: [BriefingLine] = []
        let burn = Treasury.netBurn(s)   // 3.9: the same burn as the Cash tile and the runway alert (capex included)
        let runway = Treasury.runwayMonths(s)
        if let r = runway, r < 9 {
            risks.append(BriefingLine(text: "\(Fmt.trim(r, 1)) months of cash at the current burn (\(Fmt.money(burn))/month, hardware spending included).", good: false, screen: Screen.funding.rawValue))
        }
        if cur.bestC == 0 && s.models.contains(where: \.released) {
            risks.insert(BriefingLine(text: "No model is on sale, so revenue is heading to zero. Bring one back on the Models page.", good: false, screen: Screen.models.rawValue), at: 0)
        }
        if cur.served < 0.9 {
            risks.append(BriefingLine(text: "You turned away \(Fmt.pct(1 - cur.served, decimals: 0)) of demand. Unserved users churn and reliability falls.",
                                      good: false, screen: Screen.models.rawValue))
        }
        // 3.8: demand your go-to-market couldn't book, and why; a crisis that started this month.
        if let line = Commercial.explanation(cur, s), cur.revUnbooked > max(1_000, cur.commercialRevenue * 0.1) {
            risks.append(BriefingLine(text: line, good: false, screen: Screen.finance.rawValue))
        }
        for c in s.corp.cycle.active where c.start >= start && c.start <= end {   // crises start at the month close
            risks.append(BriefingLine(text: "\(c.kind.title) under way until about \(c.end.gameMonth): \(c.cause)", good: false, screen: Screen.finance.rawValue))
        }
        for r in s.rentals {
            guard let e = r.end, GameCalendar.daysBetween(end, e) <= 45 else { continue }
            risks.append(BriefingLine(text: "\(Fmt.int(r.count))× \(HardwareCatalog.get(r.accelID)?.name ?? r.accelID) reservation ends \(e.gameShort).",
                                      good: false, screen: Screen.compute.rawValue))
        }
        for b in s.bills where b.stance == 0 && GameCalendar.daysBetween(end, b.vote) <= 45 && GameCalendar.daysBetween(end, b.vote) >= 0 {
            risks.append(BriefingLine(text: "\(PolicyCatalog.byID[b.id]?.title ?? b.id) goes to a vote \(b.vote.gameShort) and you haven't taken a side.",
                                      good: nil, screen: Screen.security.rawValue))
        }
        let waiting = s.decisions.filter { !Alerts.isUrgent($0) }.count
        if waiting > 0 {
            risks.append(BriefingLine(text: "\(waiting) offer\(waiting == 1 ? "" : "s") waiting in your inbox.", good: nil, screen: Screen.dashboard.rawValue))
        }
        // 3.4: world and stakeholders — at most two lines, only when something moved a lot.
        for line in World.briefingLines(s) { if line.good == true { drivers.append(line) } else { risks.insert(line, at: min(1, risks.count)) } }
        for line in Corporate.briefingLines(s) { if line.good == false { risks.append(line) } else { drivers.append(line) } }   // 3.5: corporate
        for line in Semis.briefingLines(s) { if line.good == false { risks.append(line) } else { drivers.append(line) } }   // 3.5: semiconductors

        // What to do: the Chief of Staff's top fixes.
        let actions = Advisor.items(s, pools: Economy.pools(s), set: set)
            .filter { $0.level >= .warning || $0.fix != nil }
            .prefix(4)
            .map { BriefingLine(text: $0.title + ($0.fix != nil && !$0.fixLabel.isEmpty ? " → \($0.fixLabel)" : ""), good: nil, screen: $0.screen.rawValue) }

        // Headline.
        let change = rate(cur.revenue, prev.revenue)
        var headline: String
        if cur.revenue < 1_000 && prev.revenue < 1_000 {
            headline = burn > 0 ? "Pre-revenue: \(Fmt.money(burn)) spent\(runway.map { ", \(Fmt.trim($0, 1)) months of runway" } ?? "")." : "Pre-revenue."
        } else if change >= 0.05 {
            headline = "Revenue up \(Fmt.pct(change, decimals: 0)) to \(Fmt.money(cur.revenue))" + (topCause.isEmpty ? "." : ": \(topCause).")
        } else if change <= -0.05 {
            headline = "Revenue down \(Fmt.pct(-change, decimals: 0)) to \(Fmt.money(cur.revenue))" + (topCause.isEmpty ? "." : ": \(topCause).")
        } else {
            headline = "Revenue steady at \(Fmt.money(cur.revenue))."
        }
        if let r = rivalReleases.filter({ $0.index > cur.myIndex && cur.myIndex > 0 }).max(by: { $0.index < $1.index }), change > -0.05 {
            headline += " \(r.lab)'s \(r.model) now leads you."
        } else if let m = launches.max(by: { $0.index < $1.index }), topCause.isEmpty {
            headline += " You launched \(m.name)."
        }

        let brief = MonthlyBriefing(month: cur.month, headline: headline, revenue: cur.revenue, revenueChange: change, profit: cur.profit,
                                    cash: s.cash, runway: runway, drivers: drivers, rivals: Array(rivals.prefix(6)), risks: Array(risks.prefix(6)),
                                    actions: Array(actions))
        s.briefings.insert(brief, at: 0)
        if s.briefings.count > 12 { s.briefings.removeLast(s.briefings.count - 12) }
        // Only a month worth reading gets a banner; the briefing is always on the dashboard.
        let notable = abs(change) >= 0.08 || rivalReleases.contains { $0.index > cur.myIndex && cur.myIndex > 0 }
            || (runway ?? 99) < 6 || cur.served < 0.85 || cur.rank != prev.rank || !launches.isEmpty
        if notable {
            Alerts.raise(&s, .briefing, title: "\(cur.month.gameMonth) briefing", body: headline, screen: .dashboard, cooldown: 0)
        }
    }
}

// MARK: - 3.8: why profit moved

/// One line of the profit bridge between two closed months: how much it moved profit and why.
struct ProfitMover: Identifiable, Hashable {
    var id: String { name }
    let name: String
    /// Effect on profit (+ helped, − hurt).
    let delta: Double
    let cause: String
    let screen: Screen
}

extension Briefing {
    /// Every income-statement line's change from `prev` to `cur`, signed by its effect on profit (a cost that rose is
    /// negative), biggest first, each with the cause the month records show. The lines add up to the change in profit.
    static func profitMovers(prev: MonthRecord, cur: MonthRecord) -> [ProfitMover] {
        func pct(_ a: Double, _ b: Double) -> String { b > 0 ? " (\(a >= b ? "+" : "−")\(Fmt.pct(abs(a / b - 1), decimals: 0)))" : "" }
        let heads = cur.headcount - prev.headcount
        let chips = cur.chips - prev.chips
        var lines: [(String, Double, String, Screen)] = []
        func rev(_ name: String, _ a: Double, _ b: Double, _ why: String, _ sc: Screen) { lines.append((name, a - b, why, sc)) }
        func cost(_ name: String, _ a: Double, _ b: Double, _ why: String, _ sc: Screen) { lines.append((name, -(a - b), why, sc)) }

        var api = "API share \(Fmt.pct(prev.apiShare, decimals: 1)) → \(Fmt.pct(cur.apiShare, decimals: 1))"
        if prev.apiPrice > 0 && cur.apiPrice > 0 { api += ", average price \(Fmt.price(prev.apiPrice)) → \(Fmt.price(cur.apiPrice))/M" }
        if cur.revUnbooked > prev.revUnbooked * 1.2 && cur.revUnbooked > 1_000 { api += ", \(Fmt.money(cur.revUnbooked)) of demand unbooked" }
        rev("API", cur.revAPI, prev.revAPI, api, .market)
        rev("Chat subscriptions", cur.revConsumer, prev.revConsumer, "paying users \(Fmt.count(prev.paidUsers)) → \(Fmt.count(cur.paidUsers))", .market)
        rev("Enterprise contracts", cur.revEnterprise, prev.revEnterprise, "contracts \(prev.contracts) → \(cur.contracts)", .market)
        rev("Agent seats", cur.revAgents, prev.revAgents, "agent share \(Fmt.pct(prev.agentShare, decimals: 1)) → \(Fmt.pct(cur.agentShare, decimals: 1))", .market)
        rev("Compute leasing", cur.revCloud, prev.revCloud, "leases you run" + pct(cur.revCloud, prev.revCloud), .chipSales)
        rev("Chip sales", cur.revChips, prev.revChips, "chips sold" + pct(cur.revChips, prev.revChips), .chipSales)
        rev("Licensing", cur.revLicensing, prev.revLicensing, "royalties and subsidiaries' licence fees", .corporate)
        rev("Agent labour", cur.revLabor, prev.revLabor, "digital workforce contracts", .swarms)
        rev("Product lines", cur.revOther, prev.revOther, "product line sales", .products)
        rev("Government contracts", cur.revContracts, prev.revContracts, "programme milestones are paid in lumps, not every month", .advancedProjects)
        rev("Folded-in divisions", cur.revGroup, prev.revGroup, "divisions' sales", .corporate)
        cost("Cloud rent", cur.costRent, prev.costRent, "rented chips; your fleet is \(Fmt.int(Int(prev.chips))) → \(Fmt.int(Int(cur.chips))) chips", .compute)
        cost("Power", cur.costPower, prev.costPower, chips != 0 ? "\(chips > 0 ? "+" : "")\(Fmt.int(Int(chips))) chips" : "utilisation and power prices", .datacenters)
        cost("Payroll", cur.costPayroll, prev.costPayroll, heads != 0 ? "\(heads > 0 ? "+" : "")\(heads) people (\(cur.headcount) now)" : "raises, bonuses and recruiting", .team)
        cost("Datacenters and offices", cur.costSites, prev.costSites, "leases, fees and upkeep", .datacenters)
        cost("Data", cur.costData, prev.costData, "data licences", .data)
        cost("Marketing", cur.costMarketing, prev.costMarketing, "marketing budget and launches", .market)
        cost("Chips made for sale", cur.costChips, prev.costChips, "cost of the chips you sold", .chipSales)
        cost("Other costs", cur.costOther, prev.costOther, "fines, fees, legal costs and one-off spending", .finance)
        cost("Divisions' costs", cur.costGroup, prev.costGroup, "folded-in divisions", .corporate)
        cost("Depreciation", cur.costDepreciation, prev.costDepreciation, "hardware written off over 4 years, datacenter shells over 20 (no cash)", .finance)
        cost("Interest on debt", cur.costInterest, prev.costInterest, "what you owe and its rates", .finance)
        cost("Tax", cur.taxes, prev.taxes, cur.taxes <= 0 && prev.taxes > 0 ? "no taxable profit after losses carried forward" : "taxable profit after losses carried forward and credits", .corporate)
        rev("Interest on cash", cur.interestIncome, prev.interestIncome, "cash balance and the policy rate", .finance)
        rev("One-off income", cur.oneOffIncome, prev.oneOffIncome, "upfront licence fees and other one-offs", .finance)
        rev("Gains on disposals", cur.assetGains, prev.assetGains, "assets and stakes sold against what they were carried at", .finance)
        return lines.filter { abs($0.1) >= 0.5 }
            .sorted { abs($0.1) != abs($1.1) ? abs($0.1) > abs($1.1) : $0.0 < $1.0 }
            .map { ProfitMover(name: $0.0, delta: $0.1, cause: $0.2, screen: $0.3) }
    }
}

extension GameState {
    mutating func markBriefingSeen(_ id: UUID) {
        if let i = briefings.firstIndex(where: { $0.id == id }) { briefings[i].seen = true }
    }
}
