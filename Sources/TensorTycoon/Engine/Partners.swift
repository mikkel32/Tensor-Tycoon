import Foundation

enum PartnerID: String, Codable, CaseIterable, Identifiable, Sendable {
    case nvidia, google, aws, microsoft, amd, oracle
    var id: String { rawValue }
}

struct PartnerDef: Sendable, Identifiable {
    let id: PartnerID
    let name: String
    let symbol: String
    let color: UInt32
    let kind: String
    /// Vendors you may still buy or rent from under an exclusive deal.
    let vendors: Set<Vendor>
    /// Whose new chips you get early access to.
    let earlyVendors: Set<Vendor>
    let precedent: String
    let pitch: String
    let minValuation: Double
    let exclusiveMinValuation: Double
    /// Share of the investment paid as cloud credits instead of cash.
    let creditsShare: Double
    /// AMD-style warrants: share of purchase spend that comes back as stock gains.
    let rebate: Double
    let exclusiveDiscount: Double
    let since: Double
    let image: String
}

struct Partnership: Codable, Identifiable, Hashable {
    var id = UUID()
    var partner: PartnerID
    var exclusive: Bool
    var start: Date
    var end: Date
    var invested: Double
    var equity: Double
    var credits: Double
    var discount: Double
    var earlyMonths: Int
    var mfuBonus: Double
    var allocationMult: Double
    var annualCommit: Double
    var spentThisYear: Double = 0
    var nextSettlement: Date

    var def: PartnerDef { PartnerCatalog.byID[partner]! }
}

struct PartnerTerms {
    var exclusive: Bool
    var years: Int
    var investment: Double
    var equity: Double
    var credits: Double
    var cash: Double
    var discount: Double
    var earlyMonths: Int
    var mfuBonus: Double
    var allocationMult: Double
    var annualCommit: Double
}

enum PartnerCatalog {
    static let all: [PartnerDef] = [
        PartnerDef(id: .nvidia, name: "NVIDIA", symbol: "cpu.fill", color: 0x76B900, kind: "GPU vendor",
                   vendors: [.nvidia], earlyVendors: [.nvidia],
                   precedent: "Like NVIDIA's Sep 2025 letter of intent with OpenAI — up to $100B invested as each of 10 gigawatts of NVIDIA systems comes online — and its up-to-$10B investment in Anthropic (Nov 2025).",
                   pitch: "Equity investment, first allocation of every new GPU generation, and NVIDIA engineers tuning your kernels.",
                   minValuation: 1e9, exclusiveMinValuation: 3e9, creditsShare: 0, rebate: 0, exclusiveDiscount: 0.15, since: 2016.5, image: "nvidia_hq"),
        PartnerDef(id: .google, name: "Google Cloud", symbol: "square.grid.3x3.fill", color: 0x4285F4, kind: "Cloud & TPUs",
                   vendors: [.google], earlyVendors: [.google],
                   precedent: "Like Anthropic's Oct 2025 deal for up to one million TPUs — well over a gigawatt in 2026 — on top of roughly $3B Google had invested.",
                   pitch: "TPU credits, deep discounts and early access to each new TPU generation (TPU 8t/8i previews).",
                   minValuation: 3e8, exclusiveMinValuation: 1e9, creditsShare: 0.6, rebate: 0, exclusiveDiscount: 0.30, since: 2018.5, image: "tpu_v4"),
        PartnerDef(id: .aws, name: "AWS", symbol: "cloud.fill", color: 0xFF9900, kind: "Cloud & Trainium",
                   vendors: [.aws], earlyVendors: [.aws],
                   precedent: "Like Amazon's $8B investment in Anthropic: AWS became its primary training partner and built Project Rainier — ~500,000 Trainium2 chips — for it (Oct 2025).",
                   pitch: "Investment plus Trainium capacity built for you, with Annapurna Labs co-designing the next chip.",
                   minValuation: 3e8, exclusiveMinValuation: 1e9, creditsShare: 0.5, rebate: 0, exclusiveDiscount: 0.30, since: 2023.0, image: "dc_rows"),
        PartnerDef(id: .microsoft, name: "Microsoft Azure", symbol: "square.split.2x2.fill", color: 0x00A4EF, kind: "Cloud (NVIDIA, AMD, Maia)",
                   vendors: [.microsoft, .nvidia, .amd], earlyVendors: [.microsoft],
                   precedent: "Like Microsoft's $13B partnership with OpenAI, with Azure as its exclusive cloud — and Anthropic's Nov 2025 commitment to buy $30B of Azure compute alongside up to $5B from Microsoft.",
                   pitch: "A giant investment paid largely in Azure credits, enterprise distribution and Maia access.",
                   minValuation: 1e9, exclusiveMinValuation: 3e9, creditsShare: 0.6, rebate: 0, exclusiveDiscount: 0.20, since: 2019.5, image: "hyperscale_campus"),
        PartnerDef(id: .amd, name: "AMD", symbol: "memorychip.fill", color: 0xED1C24, kind: "GPU vendor",
                   vendors: [.amd], earlyVendors: [.amd],
                   precedent: "Like the OpenAI–AMD deal (Oct 2025): 6 GW of Instinct GPUs starting with MI450, with warrants for up to 160M AMD shares (~10%) vesting as each gigawatt comes online.",
                   pitch: "Instinct GPUs at a steep discount, priority on MI400-class parts, and warrants that pay you back as you buy.",
                   minValuation: 5e8, exclusiveMinValuation: 1.5e9, creditsShare: 0, rebate: 0.18, exclusiveDiscount: 0.30, since: 2023.9, image: "amd_racks"),
        PartnerDef(id: .oracle, name: "Oracle Cloud", symbol: "building.columns.fill", color: 0xC74634, kind: "Cloud (NVIDIA, AMD)",
                   vendors: [.nvidia, .amd], earlyVendors: [],
                   precedent: "Like OpenAI's ~$300B, five-year compute contract with Oracle for Stargate (2025).",
                   pitch: "Gigawatt-scale campuses built to order, financed by Oracle, in exchange for a long take-or-pay contract.",
                   minValuation: 2e9, exclusiveMinValuation: 5e9, creditsShare: 0.5, rebate: 0, exclusiveDiscount: 0.25, since: 2023.5, image: "dc_construction"),
    ]

    static let byID: [PartnerID: PartnerDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Why a deal isn't available right now (nil if it is).
    static func blocker(_ def: PartnerDef, exclusive: Bool, state s: GameState) -> String? {
        if s.year < def.since { return "\(def.name) doesn't run a partner program yet." }
        if s.partnerships.contains(where: { $0.partner == def.id }) { return "You already have a deal with \(def.name)." }
        if exclusive, let ex = s.partnerships.first(where: \.exclusive) { return "You're exclusive with \(ex.def.name) until \(ex.end.gameMonth)." }
        if s.partnerships.contains(where: \.exclusive) { return "Your exclusive deal doesn't allow other compute partners." }
        let need = exclusive ? def.exclusiveMinValuation : def.minValuation
        if s.valuation < need { return "\(def.name) wants a \(Fmt.money(need)) valuation for \(exclusive ? "an exclusive" : "a preferred") deal (you're at \(Fmt.money(s.valuation)))." }
        return nil
    }

    static func terms(_ def: PartnerDef, exclusive: Bool, years: Int, state s: GameState) -> PartnerTerms {
        let v = max(s.valuation, def.minValuation)
        let investment = (exclusive ? 0.10 : 0.03) * v * (1 + 0.05 * Double(years - 2))
        let equity = investment / (v + investment) / (exclusive ? 1.6 : 1.3)
        let credits = investment * def.creditsShare
        return PartnerTerms(exclusive: exclusive, years: years, investment: investment, equity: equity, credits: credits,
                            cash: investment - credits,
                            discount: exclusive ? def.exclusiveDiscount : 0.10,
                            earlyMonths: def.earlyVendors.isEmpty ? 0 : (exclusive ? 6 : 2),
                            mfuBonus: exclusive ? 0.05 : 0.02,
                            allocationMult: exclusive ? 6 : 2.5,
                            annualCommit: max(2e7, investment * (exclusive ? 0.8 : 0.5)))
    }
}

enum Partners {
    static func active(_ s: GameState) -> [Partnership] { s.partnerships.filter { $0.end > s.date } }

    static func covering(_ a: Accelerator, _ s: GameState) -> Partnership? {
        active(s).first { $0.def.vendors.contains(a.vendor) }
    }

    /// nil if allowed; otherwise why an exclusive deal blocks this chip.
    static func blocker(_ a: Accelerator, _ s: GameState) -> String? {
        guard let ex = active(s).first(where: \.exclusive), !ex.def.vendors.contains(a.vendor) else { return nil }
        let allowed = ex.def.vendors.map(\.rawValue).sorted().joined(separator: " / ")
        return "Your exclusive deal with \(ex.def.name) only allows \(allowed) hardware until \(ex.end.gameMonth)."
    }

    static func earlyMonths(_ a: Accelerator, _ s: GameState) -> Int {
        active(s).filter { $0.def.earlyVendors.contains(a.vendor) }.map(\.earlyMonths).max() ?? 0
    }

    static func discount(_ a: Accelerator, _ s: GameState) -> Double {
        covering(a, s)?.discount ?? 0
    }

    static func mfuBonus(_ a: Accelerator, _ s: GameState) -> Double {
        active(s).filter { $0.def.earlyVendors.contains(a.vendor) || $0.def.vendors.contains(a.vendor) }.map(\.mfuBonus).max() ?? 0
    }

    static func allocationMult(_ a: Accelerator, _ s: GameState) -> Double {
        covering(a, s)?.allocationMult ?? 1
    }

    /// Track spend against the commitment (and AMD-style warrant gains).
    static func recordSpend(_ s: inout GameState, accel a: Accelerator, amount: Double, purchase: Bool) {
        guard let i = s.partnerships.firstIndex(where: { $0.end > s.date && $0.def.vendors.contains(a.vendor) }) else { return }
        s.partnerships[i].spentThisYear += amount
        let rebate = s.partnerships[i].def.rebate
        if purchase && rebate > 0 {
            let gain = amount * rebate
            s.cash += gain
            s.month.revOther += gain
        }
    }

    static func monthly(_ s: inout GameState) {
        for i in s.partnerships.indices where s.partnerships[i].nextSettlement <= s.date {
            let p = s.partnerships[i]
            let shortfall = max(0, p.annualCommit - p.spentThisYear)
            if shortfall > 0 {
                let fee = shortfall * 0.5
                s.cash -= fee
                s.month.costOther += fee
                Sim.news(&s, "\(p.def.name) commitment shortfall", "You spent \(Fmt.money(p.spentThisYear)) of your \(Fmt.money(p.annualCommit)) annual commitment. Take-or-pay: you owe \(Fmt.money(fee)).",
                         .finance, important: true, good: false)
            }
            s.partnerships[i].spentThisYear = 0
            s.partnerships[i].nextSettlement = GameCalendar.addMonths(p.nextSettlement, 12)
        }
        let ended = s.partnerships.filter { $0.end <= s.date }
        for p in ended {
            Sim.news(&s, "\(p.def.name) partnership ended", "Your \(p.exclusive ? "exclusive" : "preferred") agreement has run its course. You can negotiate a new one from the Partners page.", .finance)
        }
        s.partnerships.removeAll { $0.end <= s.date }
        outreach(&s)
    }

    /// Partners reach out once you're big enough to matter to them.
    static func outreach(_ s: inout GameState) {
        guard s.decisions.isEmpty, s.partnerships.isEmpty else { return }
        for def in PartnerCatalog.all where s.partnerContacted[def.id.rawValue] == nil {
            let exclusive = PartnerCatalog.blocker(def, exclusive: true, state: s) == nil
            guard PartnerCatalog.blocker(def, exclusive: false, state: s) == nil, s.rng.chance(0.25) else { continue }
            s.partnerContacted[def.id.rawValue] = s.date
            let t = PartnerCatalog.terms(def, exclusive: exclusive, years: 4, state: s)
            let what = exclusive ? "an exclusive partnership" : "a preferred partnership"
            Events.addDecision(&s, kind: "partner_offer", title: "\(def.name) wants \(what)",
                               body: "\(def.pitch) Their opening offer: \(Fmt.money(t.investment)) for \(Fmt.pct(t.equity, decimals: 1)) of the company\(t.credits > 0 ? " (\(Fmt.money(t.credits)) as credits)" : ""), \(Int(t.discount * 100))% off, \(t.earlyMonths > 0 ? "\(t.earlyMonths)-month early access, " : "")and a \(Fmt.money(t.annualCommit))/yr spending commitment\(exclusive ? " — and you'd use only their hardware for 4 years" : "").",
                               image: def.image,
                               options: [DecisionOption(label: "Sign the \(exclusive ? "exclusive " : "")deal", detail: "4 years. Details on the Partners page."),
                                         DecisionOption(label: "Negotiate on the Partners page", detail: "Look at every partner's terms first."),
                                         DecisionOption(label: "Not now", detail: "Stay independent.")],
                               ref: "\(def.id.rawValue)|\(exclusive ? 1 : 0)")
            return
        }
    }

    static func resolveOffer(_ s: inout GameState, ref: String, option: Int) {
        let parts = ref.split(separator: "|")
        guard let id = parts.first.flatMap({ PartnerID(rawValue: String($0)) }) else { return }
        let exclusive = parts.count > 1 && parts[1] == "1"
        if option == 0 {
            if let err = s.signPartnership(id, exclusive: exclusive, years: 4) {
                Sim.news(&s, "Couldn't sign with \(PartnerCatalog.byID[id]?.name ?? "partner")", err, .finance, good: false)
            }
        }
    }
}

extension GameState {
    mutating func signPartnership(_ id: PartnerID, exclusive: Bool, years: Int) -> String? {
        guard let def = PartnerCatalog.byID[id] else { return "Unknown partner." }
        if let why = PartnerCatalog.blocker(def, exclusive: exclusive, state: self) { return why }
        let t = PartnerCatalog.terms(def, exclusive: exclusive, years: years, state: self)
        let newShares = totalShares * t.equity / max(0.01, 1 - t.equity)
        holdings.append(Holding(name: "\(def.name) (strategic)", shares: newShares))
        cash += t.cash
        cloudCredits += t.credits
        valuation += t.investment
        partnerships.append(Partnership(partner: id, exclusive: exclusive, start: date, end: GameCalendar.addMonths(date, years * 12),
                                        invested: t.investment, equity: t.equity, credits: t.credits, discount: t.discount,
                                        earlyMonths: t.earlyMonths, mfuBonus: t.mfuBonus, allocationMult: t.allocationMult,
                                        annualCommit: t.annualCommit, nextSettlement: GameCalendar.addMonths(date, 12)))
        partnerContacted[id.rawValue] = date
        Achievements.unlock(&self, "partner")
        Sim.news(&self, "\(exclusive ? "Exclusive" : "Strategic") partnership with \(def.name)",
                 "\(def.name) invests \(Fmt.money(t.investment)) for \(Fmt.pct(t.equity, decimals: 1)) of \(companyName)\(t.credits > 0 ? ", \(Fmt.money(t.credits)) of it as cloud credits" : ""). You get \(Int(t.discount * 100))% off, \(t.earlyMonths > 0 ? "\(t.earlyMonths)-month early access to new chips, " : "")\(Fmt.trim(t.allocationMult, 1))× allocation and co-engineering support\(exclusive ? " — in exchange for using only their hardware for \(years) years" : "").",
                 .finance, image: def.image, important: true, good: true)
        return nil
    }

    mutating func terminatePartnership(_ id: UUID) -> String? {
        guard let i = partnerships.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let p = partnerships[i]
        let penalty = p.invested * 0.25 + max(0, p.annualCommit - p.spentThisYear) * 0.5
        if penalty > cash { return "Breaking the deal costs \(Fmt.money(penalty)) — you have \(Fmt.money(cash))." }
        cash -= penalty
        month.costOther += penalty
        partnerships.remove(at: i)
        brand = max(0, brand - 4)
        Sim.news(&self, "\(companyName) breaks with \(p.def.name)", "Ending the agreement early cost \(Fmt.money(penalty)). \(p.def.name) keeps its equity.",
                 .finance, important: true, good: false)
        return nil
    }
}
