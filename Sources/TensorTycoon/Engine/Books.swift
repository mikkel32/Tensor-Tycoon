import Foundation

// MARK: - 3.8: the books

/// Cash that moves without passing through the income statement, by what it was for. Each kind sits in one section of
/// the cash-flow statement. Raw values are stable codes: they are the keys of `MonthRecord.flows` in saves.
enum CashFlowKind: String, CaseIterable, Sendable {
    // Investing (capex is kept on its own, in `MonthRecord.capex`)
    /// Hardware, campuses and other assets sold (+).
    case assetSales
    /// Cash put into subsidiaries (−: start-ups, injections, buy-outs, acquisitions) or taken out of them (+: stake
    /// sales, what's left when one closes, the cash of one folded in).
    case subsidiaries
    /// Stakes in other labs bought (−), sold or paid out (+).
    case stakes
    /// Labs bought outright (−).
    case acquisitions
    // Financing
    /// Rounds, the IPO, offerings and strategic investments: the cash part only (cloud credits aren't cash) (+).
    case equity
    /// Loans and corporate debt drawn (+).
    case borrowing
    /// Principal repaid (−).
    case repayments
    case dividends
    case buybacks

    enum Section: String, Sendable { case investing, financing }

    var section: Section {
        switch self {
        case .assetSales, .subsidiaries, .stakes, .acquisitions: .investing
        case .equity, .borrowing, .repayments, .dividends, .buybacks: .financing
        }
    }

    var title: String {
        switch self {
        case .assetSales: "Assets sold"
        case .subsidiaries: "Subsidiaries"
        case .stakes: "Stakes in other labs"
        case .acquisitions: "Labs acquired"
        case .equity: "Equity raised"
        case .borrowing: "Debt drawn"
        case .repayments: "Debt repaid"
        case .dividends: "Dividends"
        case .buybacks: "Buybacks"
        }
    }
}

/// The company's books: every movement of cash is either on the income statement (`MonthRecord` revenue and cost
/// lines), capex, or a categorised flow posted here. At each month close the books are reconciled: cash at the end
/// less cash at the start must equal what they explain (`residual`). The cash-flow statement is built from these
/// flows, and depreciation of owned accelerators and datacenter shells is charged here as a non-cash cost.
enum Books {
    /// Straight-line lives.
    static let hardwareLifeYears = 4.0
    static let shellLifeYears = 20.0

    // MARK: Posting

    /// Records cash that moved outside the income statement (signed: + in, − out). Call it next to the `cash` change.
    static func post(_ s: inout GameState, _ kind: CashFlowKind, _ amount: Double) {
        guard amount != 0, amount.isFinite else { return }
        s.month.flows[kind.rawValue, default: 0] += amount
    }

    /// The month opens: remember the cash it starts with, so the close can reconcile against it.
    static func open(_ s: inout GameState) { s.month.opening = s.cash }

    // MARK: Reading

    static func flow(_ r: MonthRecord, _ kind: CashFlowKind) -> Double { r.flows[kind.rawValue] ?? 0 }

    /// Flows of one section, summed in a fixed order (so the total never depends on the dictionary's).
    static func total(_ r: MonthRecord, _ section: CashFlowKind.Section) -> Double {
        CashFlowKind.allCases.filter { $0.section == section }.reduce(0) { $0 + flow(r, $1) }
    }

    /// Cash from operations: net income with depreciation added back and gains on disposals taken out.
    static func operating(_ r: MonthRecord) -> Double { r.cashProfit }
    static func investing(_ r: MonthRecord) -> Double { -r.capex + total(r, .investing) }
    static func financing(_ r: MonthRecord) -> Double { total(r, .financing) }

    /// The change in cash the books explain.
    static func explained(_ r: MonthRecord) -> Double { operating(r) + investing(r) + financing(r) }

    /// Cash the books can't explain for a month (nil for months from before the ledger). `cashEnd` is the month's
    /// closing cash (for the open month, today's cash).
    static func residual(_ r: MonthRecord, cashEnd: Double) -> Double? {
        guard let start = r.opening else { return nil }
        return cashEnd - start - explained(r)
    }

    /// The last closed month's residual.
    static func residual(_ s: GameState) -> Double? {
        guard let r = s.history.last else { return nil }
        return residual(r, cashEnd: r.cashEnd)
    }

    /// The open month's residual so far.
    static func openResidual(_ s: GameState) -> Double? { residual(s.month, cashEnd: s.cash) }

    /// How far off the books may be before it's a leak: a dollar, or a millionth of the cash pile (rounding over a
    /// month of daily postings on a large balance).
    static func tolerance(_ cash: Double) -> Double { max(1, 1e-6 * abs(cash)) }

    /// The largest residual over the closed months the ledger covers, with the month it happened in.
    static func worstResidual(_ s: GameState) -> (amount: Double, month: Date)? {
        var worst: (Double, Date)? = nil
        for r in s.history {
            guard let x = residual(r, cashEnd: r.cashEnd) else { continue }
            if abs(x) > abs(worst?.0 ?? 0) || worst == nil { worst = (x, r.month) }
        }
        return worst
    }

    // MARK: Asset values

    static func years(_ from: Date, _ to: Date) -> Double { Double(GameCalendar.daysBetween(from, to)) / 365.25 }

    /// Share of a straight-line life used up by a date.
    static func used(_ start: Date, _ at: Date, life: Double) -> Double { clamp(years(start, at) / life, 0, 1) }

    /// An owned batch at book value: what it cost less straight-line depreciation over four years.
    static func book(_ b: OwnedBatch, at d: Date) -> Double {
        b.unitCost * Double(b.count) * (1 - used(b.purchased, d, life: hardwareLifeYears))
    }

    /// The book value of `n` chips of a batch today (for the gain or loss when they're sold or seized).
    static func book(_ b: OwnedBatch, chips n: Int, at d: Date) -> Double {
        b.count > 0 ? book(b, at: d) * Double(min(n, b.count)) / Double(b.count) : 0
    }

    /// Owned accelerators at book value, plus chips paid for and still in transit at cost.
    static func hardwareBook(_ s: GameState) -> Double {
        s.owned.reduce(0) { $0 + book($1, at: s.date) } + s.orders.reduce(0) { $0 + $1.unitCost * Double($1.count) }
    }

    /// A datacenter at book value: its capex less the depreciation charged on it so far.
    static func siteBook(_ site: Site, _ s: GameState) -> Double {
        guard site.kind == .datacenter else { return 0 }
        return max(0, site.capex - (s.corp.siteDepreciation[site.id.uuidString] ?? 0))
    }

    static func sitesBook(_ s: GameState) -> Double { s.sites.reduce(0) { $0 + siteBook($1, s) } }

    // MARK: Disposals

    /// Books the gain or loss when assets carried at `book` leave for `proceeds` in cash (posted as an asset sale).
    static func disposed(_ s: inout GameState, proceeds: Double, book: Double) {
        s.month.assetGains += proceeds - book
        post(&s, .assetSales, proceeds)
    }

    /// A datacenter sold or written off: its remaining depreciation record goes with it.
    static func siteGone(_ s: inout GameState, _ site: Site, proceeds: Double) {
        let b = siteBook(site, s)
        s.corp.siteDepreciation[site.id.uuidString] = nil
        disposed(&s, proceeds: proceeds, book: b)
    }

    // MARK: Month close

    /// Charges the month's depreciation: each owned batch for the part of its four-year life used up since the month
    /// began (or since it arrived), each datacenter for the days it was in service, at 1/20 of its cost a year, until
    /// it's fully written down.
    static func depreciate(_ s: inout GameState) {
        let start = s.month.month
        let end = s.date
        var charge = 0.0
        for b in s.owned where b.count > 0 {
            let from = max(start, b.purchased)
            guard from < end else { continue }
            let cost = b.unitCost * Double(b.count)
            charge += cost * (used(b.purchased, end, life: hardwareLifeYears) - used(b.purchased, from, life: hardwareLifeYears))
        }
        for site in s.sites where site.kind == .datacenter && site.capex > 0 {
            let key = site.id.uuidString
            let from = max(start, site.ready)
            guard from < end else { continue }
            let done = s.corp.siteDepreciation[key] ?? 0
            let d = min(max(0, site.capex - done), site.capex * years(from, end) / shellLifeYears)
            guard d > 0 else { continue }
            s.corp.siteDepreciation[key] = done + d
            charge += d
        }
        // Records of sites that are gone (sold through paths that don't call `siteGone`) are dropped.
        let live = Set(s.sites.map { $0.id.uuidString })
        for k in s.corp.siteDepreciation.keys.sorted() where !live.contains(k) { s.corp.siteDepreciation[k] = nil }
        s.month.costDepreciation += charge
    }
}
