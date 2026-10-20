import Foundation

// MARK: - 3.5: semiconductors — the month, supply shocks, customer orders, decisions, advice and player actions

extension Semis {
    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        guard s.semi.engaged else { return }
        // Close the month's books.
        var m = s.semi.month
        if m.month == nil { m.month = GameCalendar.addMonths(s.date, -1) }
        s.semi.history.insert(m, at: 0)
        if s.semi.history.count > 24 { s.semi.history.removeLast(s.semi.history.count - 24) }
        let c = GameCalendar.components(s.date)
        s.semi.month = SemiMonth(month: GameCalendar.date(c.year, c.month, 1))
        for i in s.semi.fabs.indices { s.semi.fabs[i].foundryRevenue = 0 }
        for i in s.semi.designs.indices {
            s.semi.designs[i].lastMade = s.semi.designs[i].monthMade
            s.semi.designs[i].monthMade = [0, 0, 0]
        }
        // Buyers forget a late order after a while.
        s.semi.repHit *= 0.93
        expire(&s)
        shocks(&s)
        orders(&s)
    }

    static func expire(_ s: inout GameState) {
        let today = s.date
        let monthAgo = GameCalendar.addMonths(today, -1)
        for bk in s.semi.bookings where bk.end <= today && bk.end > monthAgo {
            let f = SemiCatalog.foundryByID[bk.foundry]?.name ?? bk.foundry
            log(&s, "Wafer booking ended: \(Fmt.count(bk.wafersMonth))/month of \(SemiCatalog.node(bk.node).short) at \(f).")
            Sim.news(&s, "Wafer booking ended at \(f)", "\(Fmt.count(bk.wafersMonth)) \(SemiCatalog.node(bk.node).short) wafers a month. Book again on the Semiconductors page if you still need them.", .hardware)
        }
        s.semi.bookings.removeAll { $0.end <= today }
        for c in s.semi.supply where !c.own && c.end <= today && c.end > monthAgo {
            log(&s, "\(SemiCatalog.supplierByID[c.supplier]?.name ?? c.supplier) contract ended (\(Fmt.count(c.units)) \(c.kind == "pack" ? "packaging slots" : "HBM stacks")/month).")
        }
        s.semi.supply.removeAll { !$0.own && $0.end <= today }
        for sh in s.semi.shocks where sh.end <= today && sh.end > monthAgo {
            log(&s, "Recovered: \(sh.title).", tone: 1)
        }
        s.semi.shocks.removeAll { $0.end <= GameCalendar.addMonths(today, -6) }
    }

    // MARK: Supply shocks

    struct ShockKind {
        let id: String
        let p: Double
        let months: (Int, Int)
    }

    /// Something in the world breaks: earthquakes, fab contamination, gas and substrate shortages, HBM problems,
    /// export rules, droughts. Rolled monthly (hashed) once you're in the business.
    static func shocks(_ s: inout GameState) {
        let y = s.year
        let ym = s.date.ym
        let key = "\(ym.year)-\(ym.month)"
        let kinds: [ShockKind] = [
            ShockKind(id: "quake", p: 0.02, months: (1, 2)),
            ShockKind(id: "contamination", p: 0.025, months: (1, 1)),
            ShockKind(id: "gas", p: 0.018, months: (2, 4)),
            ShockKind(id: "substrate", p: 0.022, months: (2, 3)),
            ShockKind(id: "hbm", p: 0.015 + 0.03 * tightness("hbm", y), months: (2, 4)),
            ShockKind(id: "export", p: y >= 2019 ? 0.012 : 0, months: (6, 12)),
            ShockKind(id: "drought", p: 0.018, months: (2, 3)),
        ]
        for k in kinds where !s.semi.shocks.contains(where: { $0.kind == k.id && $0.active(s.date) }) {
            guard roll(s, "shock|\(k.id)|\(key)") < k.p else { continue }
            let len = k.months.0 + Int(roll(s, "len|\(k.id)|\(key)") * Double(k.months.1 - k.months.0 + 1)) % max(1, k.months.1 - k.months.0 + 1)
            var sh = SupplyShock(kind: k.id, title: "", body: "", start: s.date, end: GameCalendar.addMonths(s.date, max(1, len)))
            switch k.id {
            case "quake":
                sh.title = "Earthquake near Hsinchu"
                sh.body = "A magnitude-7 quake shook Taiwan's fab belt. Wafers in the tools were scrapped and lines are being recalibrated: Formosa's output and packaging are cut, and fabs on fault lines everywhere stop to check."
                sh.foundry = "fsw"; sh.wafers = 0.55; sh.packaging = 0.6
            case "contamination":
                let used = Array(Set(s.semi.bookings.map(\.foundry))).sorted()
                let pool = used.isEmpty ? SemiCatalog.foundries.map(\.id) : used
                let f = pool[Int(roll(s, "which|\(key)") * Double(pool.count)) % pool.count]
                sh.foundry = f; sh.wafers = 0.6
                sh.title = "Contamination at \(SemiCatalog.foundryByID[f]?.name ?? f)"
                sh.body = "A bad batch of photoresist got into a production line. Weeks of wafers are scrap while the line is cleaned and requalified."
            case "gas":
                sh.title = "Specialty-gas shortage"
                sh.body = "Neon and helium supplies are disrupted. Every foundry rations lithography time: wafer output is down across the industry."
                sh.wafers = 0.85
            case "substrate":
                sh.title = "Packaging-substrate shortage"
                sh.body = "The build-up film every advanced package needs is short. Packaging lines everywhere run below capacity."
                sh.packaging = 0.75
            case "hbm":
                sh.title = "HBM yield problems"
                sh.body = "The newest HBM stacks are failing qualification at the memory makers. Deliveries are cut while they fix their stacking process."
                sh.hbm = 0.7
            case "export":
                sh.title = "Export rules tighten"
                sh.body = "New export rules cover AI accelerators and the tools to make them: no sales to China, licences (and delays) for the Gulf, and new orders at Chinese foundries frozen for foreign companies."
                sh.export = true
            default:
                sh.title = "Drought hits fab regions"
                sh.body = "A dry season leaves fabs in water-stressed regions trucking in water. Taiwan's foundries and your fabs in dry places run below capacity."
                sh.foundry = "fsw"; sh.wafers = 0.9; sh.drought = 0.75
            }
            s.semi.shocks.append(sh)
            log(&s, "\(sh.title) (until \(sh.end.gameShort)).", tone: -1)
            let exposure = shockExposure(sh, s)
            Sim.news(&s, sh.title, sh.body + (exposure > 0 ? " About \(Fmt.money(exposure)) of your monthly supply is affected." : " Your supply chain isn't exposed."),
                     .hardware, image: "wafer", important: exposure > 0, good: exposure > 0 ? false : nil)
            if exposure > 0 && !sh.export && !s.decisions.contains(where: { $0.kind == shockKind }) {
                let cost = rerouteCost(sh, exposure)
                Events.addDecision(&s, kind: shockKind, title: sh.title,
                                   body: "\(sh.body) Until \(sh.end.gameShort), about \(Fmt.money(exposure)) a month of what you pay for is affected.",
                                   image: "wafer",
                                   options: [DecisionOption(label: "Absorb it", detail: "Take the lost output and rely on stock and the die bank."),
                                             DecisionOption(label: "Pay to re-route", detail: "Expedite fees, air freight and spot capacity elsewhere: \(Fmt.money(cost)) recovers half the lost capacity.")],
                                   amount: cost, ref: sh.id.uuidString)
            }
        }
    }

    /// Monthly spend on inputs a shock touches.
    static func shockExposure(_ sh: SupplyShock, _ s: GameState) -> Double {
        var v = 0.0
        if sh.wafers < 1 || sh.export {
            for bk in s.semi.bookings where bk.end > s.date && (sh.foundry.isEmpty || sh.foundry == bk.foundry || (sh.export && bk.foundry == "pearl")) {
                v += bk.wafersMonth * bk.price * (sh.export ? 1 : 1 - sh.wafers)
            }
        }
        if sh.packaging < 1 {
            for c in s.semi.supply where c.kind == "pack" && (sh.foundry.isEmpty || c.supplier.hasPrefix(sh.foundry)) { v += c.units * c.price * (1 - sh.packaging) }
        }
        if sh.hbm < 1 { for c in s.semi.supply where c.kind == "hbm" { v += c.units * c.price * (1 - sh.hbm) } }
        if sh.drought < 1 || sh.kind == "quake" {
            for f in s.semi.fabs where f.open(s.date) {
                let site = SemiCatalog.siteByID[f.site]
                if (sh.drought < 1 && (site?.water ?? 0) >= 0.5) || (sh.kind == "quake" && (site?.quake ?? 0) >= 0.5) {
                    v += f.wafersMonth * SemiCatalog.node(f.node).waferPrice * 0.3
                }
            }
        }
        return v
    }

    static func rerouteCost(_ sh: SupplyShock, _ exposure: Double) -> Double {
        let months = max(1, Double(GameCalendar.daysBetween(sh.start, sh.end)) / 30.4)
        return (exposure * months * 0.6 / 1e5).rounded() * 1e5
    }

    static func resolveShock(_ s: inout GameState, _ d: Decision, option: Int) {
        guard option == 1, let i = s.semi.shocks.firstIndex(where: { $0.id.uuidString == d.ref }) else { return }
        spend(&s, d.amount)
        s.semi.month.penalties += d.amount
        s.semi.shocks[i].mitigated = true
        log(&s, "Paid \(Fmt.money(d.amount)) to re-route around: \(s.semi.shocks[i].title).")
    }

    // MARK: Customer orders

    /// Chips of one bin finished last month (after packaging and HBM, the real output).
    static func monthlyOutput(_ d: SemiDesign, bin b: Int, _ s: GameState) -> Double {
        d.lastMade.indices.contains(b) ? d.lastMade[b] : 0
    }

    /// Big orders from clouds and sovereigns, and blocks rival labs ask for, while you have chips on sale.
    static func orders(_ s: inout GameState) {
        let ym = s.date.ym
        let key = "\(ym.year)-\(ym.month)"
        guard s.decisions.filter({ $0.kind == orderKind || $0.kind == rivalKind }).isEmpty, s.decisions.count < 5 else { return }
        let selling = s.semi.designs.filter { $0.inProduction && $0.onSale.contains(true) }
        guard let d = selling.max(by: { monthlyOutput($0, bin: 0, s) < monthlyOutput($1, bin: 0, s) }) else { return }
        let b = d.onSale[0] ? 0 : (d.onSale[1] ? 1 : 2)
        let out = monthlyOutput(d, bin: b, s)
        guard out > 200, d.chipIDs.indices.contains(b), let chip = HardwareCatalog.get(d.chipIDs[b]) else { return }
        let list = d.prices[b]
        let open = buyers(s).filter { $0.blocked == nil && !$0.rival }
        if !open.isEmpty && roll(s, "order|\(key)") < 0.3 {
            let w = open.reduce(0) { $0 + $1.weight }
            var u = roll(s, "who|\(key)") * w, pick = open[0]
            for c in open { u -= c.weight; if u <= 0 { pick = c; break } }
            let units = max(500, (out * (0.8 + 1.5 * roll(s, "size|\(key)")) / 500).rounded() * 500)
            let premium = 1.03 + 0.12 * roll(s, "prem|\(key)")
            let price = (list * premium / 100).rounded() * 100
            let promised = s.semi.contracts.filter { !$0.closed && $0.designID == d.id && $0.bin == b }.reduce(0) { $0 + $1.remaining }
            let canMake = max(0, d.stockSale[b] + out * (1 - s.semi.keepShare) * 3 - promised)
            let counterOdds = clamp(0.75 - 2 * (premium - 1), 0.35, 0.75)
            // Buyers don't bother asking a supplier who plainly can't deliver.
            guard canMake >= units * 0.3 else { return }
            Events.addDecision(&s, kind: orderKind, title: "\(pick.name) wants \(Fmt.count(units)) \(chip.name)",
                               body: "A firm order at \(Fmt.money(price)) a chip (\(Fmt.pct(premium - 1, decimals: 0)) over your list) — \(Fmt.money(units * price)) — delivered within 90 days. "
                                 + "You have \(Fmt.count(d.stockSale[b])) in customer stock\(promised > 0 ? " (\(Fmt.count(promised)) already promised to other orders)" : "") and made \(Fmt.count(out)) last month, \(Fmt.pct(1 - s.semi.keepShare, decimals: 0)) of it for customers: "
                                 + "at that pace you'd ship about \(Fmt.count(min(units, canMake))) (\(Fmt.pct(min(1, canMake / units), decimals: 0))) in time. A late order pays 15% of what's missing — or keep less for yourself to fill it.",
                               image: "wafer",
                               options: [DecisionOption(label: "Accept", detail: "Deliveries come out of customer stock before spot sales."),
                                         DecisionOption(label: "Counter at +10%", detail: "\(Fmt.pct(counterOdds, decimals: 0)) chance they agree; otherwise they walk."),
                                         DecisionOption(label: "Decline", detail: "Keep the chips for spot buyers and your own fleet.")],
                               amount: price, ref: "\(d.id.uuidString)|\(b)|\(pick.id)|\(Int(units))|\(counterOdds)")
            return
        }
        // A rival lab asks for a block, at a premium, whether or not you sell to rivals.
        let rules = exportRules(s)
        let rivals = s.competitors.filter { !$0.acquired && !$0.bankrupt && $0.exitNote.isEmpty && s.year >= $0.def.founded.decimal && $0.cash > 1e9
            && !(rules.china && AdvancedProjects.labRegion($0.id) == .china) }
        guard !rivals.isEmpty, roll(s, "rival|\(key)") < 0.22 else { return }
        let r = rivals[Int(roll(s, "rwho|\(key)") * Double(rivals.count)) % rivals.count]
        let units = max(500, (out * (1 + 2 * roll(s, "rsize|\(key)")) / 500).rounded() * 500)
        let price = (list * (1.2 + 0.2 * roll(s, "rprem|\(key)")) / 100).rounded() * 100
        guard units * price < r.cash * 0.3 else { return }
        let promised = s.semi.contracts.filter { !$0.closed && $0.designID == d.id && $0.bin == b }.reduce(0) { $0 + $1.remaining }
        let canMake = max(0, d.stockSale[b] + out * (1 - s.semi.keepShare) * 3 - promised)
        guard canMake >= units * 0.3 else { return }
        let h100e = units * chip.bf16 / HardwareCatalog.h100.bf16
        let before = log10(1 + r.armedH100e / max(1, r.computeH100e))
        let after = log10(1 + (r.armedH100e + h100e) / max(1, r.computeH100e))
        Events.addDecision(&s, kind: rivalKind, title: "\(r.def.name) wants to buy \(Fmt.count(units)) of your chips",
                           body: "\(r.def.name) offers \(Fmt.money(price)) a chip (\(Fmt.pct(price / max(1, list) - 1, decimals: 0)) over list) — \(Fmt.money(units * price)) — delivered within 90 days. "
                             + "At your current pace you'd ship about \(Fmt.pct(min(1, canMake / units), decimals: 0)) of it in time. "
                             + "That's \(Fmt.count(h100e)) H100-equivalents: \(Fmt.pct(h100e / max(1, r.computeH100e), decimals: 1)) of their fleet, worth about +\(Fmt.trim(after - before, 3)) capability to their next models. Money now, a stronger rival later.",
                           image: "wafer",
                           options: [DecisionOption(label: "Sell to them", detail: "\(Fmt.money(units * price)) as you deliver; they get stronger."),
                                     DecisionOption(label: "Refuse", detail: "Keep your silicon edge to yourself.")],
                           amount: price, ref: "\(d.id.uuidString)|\(b)|\(r.id)|\(Int(units))|0")
    }

    static func resolveOrder(_ s: inout GameState, _ d: Decision, option: Int) {
        let parts = d.ref.split(separator: "|").map(String.init)
        guard parts.count >= 5, let did = UUID(uuidString: parts[0]), let b = Int(parts[1]), let units = Double(parts[3]) else { return }
        let who = parts[2]
        let name = customerName(who)
        let rival = d.kind == rivalKind
        var price = d.amount
        if rival {
            guard option == 0 else {
                log(&s, "Refused to sell \(Fmt.count(units)) chips to \(name).")
                return
            }
        } else {
            if option == 2 { return }
            if option == 1 {
                let odds = Double(parts[4]) ?? 0.5
                let r = roll(s, "counter|\(d.id)")
                guard r < odds else {
                    log(&s, "\(name) walked away from your counter-offer (odds \(Fmt.pct(odds, decimals: 0)), roll \(Fmt.trim(r, 2))).", tone: -1)
                    Sim.news(&s, "\(name) walked away", "They wouldn't pay 10% more (your odds were \(Fmt.pct(odds, decimals: 0))).", .hardware, good: false)
                    return
                }
                price = (price * 1.1 / 100).rounded() * 100
            }
        }
        s.semi.contracts.append(ChipContract(customer: who, designID: did, bin: b, units: units, price: price, signed: s.date, deadline: GameCalendar.addDays(s.date, 90)))
        log(&s, "Signed: \(Fmt.count(units)) chips for \(name) at \(Fmt.money(price)), due \(GameCalendar.addDays(s.date, 90).gameShort).", tone: 1)
    }

    // MARK: Chief of Staff and briefing

    static func advisorItems(_ s: GameState) -> [AdvisorItem] {
        guard s.semi.engaged else { return [] }
        var out: [AdvisorItem] = []
        for d in s.semi.designs where d.inProduction {
            if sources(d, s).isEmpty {
                out.append(AdvisorItem(id: "semi-supply-\(d.id)", level: .warning, symbol: "circle.grid.cross.fill", title: "\(d.name) has no wafers",
                                       detail: "It's qualified but nothing makes it. Book wafers at a foundry or assign a fab.", screen: .semiconductors))
            }
        }
        // 3.8: customer stock that can't sell because no bin is on sale.
        for d in s.semi.designs where d.inProduction && !d.onSale.contains(true) && d.stockSale.reduce(0, +) >= 1_000 {
            let n = d.stockSale.reduce(0, +)
            out.append(AdvisorItem(id: "semi-offsale-\(d.id)", level: .warning, symbol: "tag.slash.fill", title: "\(Fmt.count(n)) \(d.name) chips are unsold: nothing is on sale",
                                   detail: "They're in customer stock but no bin is on sale, so nobody can buy them. Put them on sale, or move the stock to your own fleet.",
                                   screen: .semiconductors, fix: .chipsOnSale(d.id), fixLabel: "Put on sale"))
        }
        let last = s.semi.history.first
        if let last, last.chips > 0, last.bottleneck == "packaging" || last.bottleneck == "HBM" {
            out.append(AdvisorItem(id: "semi-bottleneck", level: .info, symbol: "shippingbox.fill", title: "Chip output is limited by \(last.bottleneck)",
                                   detail: "Good dies are piling up in the die bank. Sign more \(last.bottleneck == "HBM" ? "HBM" : "packaging") capacity, or make fewer dies.", screen: .semiconductors))
        }
        // 3.8: a die bank that only grows costs money and loses value.
        for d in s.semi.designs where (d.inProduction || d.phase == .retired) && d.dieBank.reduce(0, +) > 1_000 {
            let days = dieBankDays(d, s)
            guard days > dieBankTargetDays else { continue }
            let bank = d.dieBank.reduce(0, +)
            let carry = bank * dieCost(d, s) * dieCarryMonthly
            let loss = dieLossMonthly(d, s)
            let held = days.isFinite ? "\(Fmt.trim(days / 30.4, 1)) months of packaging" : "nothing is packaging them"
            out.append(AdvisorItem(id: "semi-diebank-\(d.id)", level: days > 180 ? .warning : .info, symbol: "square.stack.3d.up.fill",
                                   title: "\(Fmt.count(bank)) \(d.name) dies waiting (\(held))",
                                   detail: "Holding them costs \(Fmt.money(carry))/month and \(Fmt.pct(loss, decimals: 0)) of them age out a month\(superseded(d, s) ? " — a newer generation is out" : ""). Sign more packaging, give the fab's spare wafers to foundry customers"
                                       + (s.semi.holdExcessDies ? ", or sell the surplus to other packagers as known-good die (about \(Fmt.money(kgdPrice(d, s))) a die)." : "; the surplus beyond two months sells to other packagers at about \(Fmt.money(kgdPrice(d, s))) a die."),
                                   screen: .semiconductors))
        }
        for f in s.semi.fabs {
            guard let want = suggestedFabShare(f, s), let d = s.semi.designs.first(where: { $0.id == f.designID }) else { continue }
            let fs = foundryServicePrice(f, s)
            let extra = f.wafersMonth * fabRamp(f, s) * ownFabFactor(s, f) * (f.productShare - want) * fs.fill * fs.price
            out.append(AdvisorItem(id: "semi-fabshare-\(f.id)", level: .info, symbol: "slider.horizontal.3",
                                   title: "Set \(f.name) to \(Fmt.pct(want, decimals: 0)) for \(d.name)",
                                   detail: "Packaging only takes about \(Fmt.count(diesPackedDay(d, s) * 30.4)) dies a month. The rest of the wafers would earn about \(Fmt.money(extra))/month as foundry service instead of piling up in the die bank.",
                                   screen: .semiconductors, fix: .fabShare(f.id, want), fixLabel: "Set \(Fmt.pct(want, decimals: 0))"))
        }
        for bk in s.semi.bookings where bk.end > s.date && GameCalendar.daysBetween(s.date, bk.end) <= 45 {
            out.append(AdvisorItem(id: "semi-book-\(bk.id)", level: .info, symbol: "calendar.badge.clock",
                                   title: "Wafer booking at \(SemiCatalog.foundryByID[bk.foundry]?.name ?? bk.foundry) ends \(bk.end.gameShort)",
                                   detail: "Book again with enough lead time, or output stops.", screen: .semiconductors))
        }
        for bk in s.semi.bookings where bk.active(s.date) && !(s.semi.designs.first { $0.id == bk.designID }?.inProduction ?? false) {
            out.append(AdvisorItem(id: "semi-idle-\(bk.id)", level: .warning, symbol: "exclamationmark.triangle.fill",
                                   title: "Paying for idle wafers at \(SemiCatalog.foundryByID[bk.foundry]?.name ?? bk.foundry)",
                                   detail: "\(Fmt.money(bk.wafersMonth * bk.price))/month of wafers go to no product in production. Assign them or cancel.", screen: .semiconductors))
        }
        for t in s.semi.teams where Semis.teamBusy(s, t.id) == nil {
            out.append(AdvisorItem(id: "semi-team-\(t.id)", level: .info, symbol: "person.3.fill", title: "\(t.name) has no design",
                                   detail: "\(t.engineers) engineers cost \(Fmt.money(Double(t.engineers) * engineerCost(s.year)))/yr. Start the next generation, or shrink the team.", screen: .semiconductors))
        }
        if let last, last.hbmCost > 0, last.bottleneck != "HBM" {
            let use = s.semi.designs.filter(\.inProduction).reduce(0.0) { $0 + $1.lastMade.reduce(0, +) * Double($1.stacks) }
            if s.semi.hbmStock > max(50_000, 3 * use) {
                out.append(AdvisorItem(id: "semi-hbm-pile", level: .info, symbol: "memorychip.fill", title: "\(Fmt.count(s.semi.hbmStock)) HBM stacks sitting in stock",
                                       detail: "You use about \(Fmt.count(use)) a month. Cancel or shrink an HBM contract.", screen: .semiconductors))
            }
        }
        for c in s.semi.contracts where !c.closed && GameCalendar.daysBetween(s.date, c.deadline) <= 30 && c.remaining > 0 {
            out.append(AdvisorItem(id: "semi-late-\(c.id)", level: .warning, symbol: "clock.badge.exclamationmark",
                                   title: "\(customerName(c.customer)) order due \(c.deadline.gameShort)", detail: "\(Fmt.count(c.remaining)) chips still to deliver. Lower what you keep for yourself to ship it.",
                                   screen: .semiconductors))
        }
        return out
    }

    static func briefingLines(_ s: GameState) -> [BriefingLine] {
        guard s.semi.engaged, let m = s.semi.history.first else { return [] }
        var out: [BriefingLine] = []
        if m.chips > 0 || m.revenue > 0 {
            var t = "Semiconductors: made \(Fmt.count(m.chips)) chips from \(Fmt.count(m.wafers)) wafers, sold \(Fmt.count(m.sold)) for \(Fmt.money(m.revenue))"
            if m.taken > 0 { t += ", kept \(Fmt.count(m.taken)) for your fleet" }
            t += "."
            if !m.bottleneck.isEmpty && m.bottleneck != "wafers" { t += " Output was held back by \(m.bottleneck)." }
            out.append(BriefingLine(text: t, good: m.revenue + m.foundryRevenue >= m.costs, screen: Screen.semiconductors.rawValue))
        }
        for sh in activeShocks(s).prefix(1) where shockExposure(sh, s) > 0 {
            out.append(BriefingLine(text: "\(sh.title) cuts your supply until \(sh.end.gameShort).", good: false, screen: Screen.semiconductors.rawValue))
        }
        return out
    }

    // MARK: Research effects

    static let virtualItems: [ResearchItem] = [
        ResearchItem(id: "semi:codesign", name: "Hardware–software co-design", category: .systems, year: 0, cost: 0, prereqs: [],
                     effects: [.mfu(0.03), .throughput(0.03)], blurb: "Your kernels and compilers are written alongside your own chips."),
        ResearchItem(id: "semi:fab", name: "Fab know-how", category: .systems, year: 0, cost: 0, prereqs: [],
                     effects: [.chipDesign(0.12)], blurb: "Running your own fab teaches your designers what the process can really do."),
    ]

    static func bonusSources(_ s: GameState) -> [(String, Double)] {
        guard !s.semi.designs.isEmpty || !s.semi.fabs.isEmpty else { return [] }
        var out: [(String, Double)] = []
        let qualified = s.semi.designs.filter { $0.qualified != nil }.count
        if qualified > 0 { out.append(("semi:codesign", min(1, Double(qualified) / 2))) }
        if s.semi.fabs.contains(where: { $0.open(s.date) }) { out.append(("semi:fab", 1)) }
        return out
    }
}

// MARK: - Player actions

extension GameState {
    mutating func hireChipTeam(engineers: Int) -> String? {
        guard bonuses.has(.customSilicon) else { return "Research Custom Accelerator Design first." }
        let n = clamp(engineers, 50, 2_000)
        let fee = Double(n) * Semis.engineerCost(year) * 0.25
        if fee > cash { return "Recruiting \(n) engineers costs \(Fmt.money(fee)) up front." }
        Semis.engage(&self)
        cash -= fee
        month.costOther += fee
        semi.month.teamCost += fee
        semi.counter += 1
        let names = ["Silicon Team A", "Silicon Team B", "Silicon Team C", "Silicon Team D", "Silicon Team E"]
        let name = names[min(names.count - 1, semi.teams.count)]
        semi.teams.append(SemiTeam(name: name, engineers: n, hired: date))
        Semis.log(&self, "Hired \(name): \(n) chip engineers (\(Fmt.money(fee)) recruiting).")
        Sim.news(&self, "\(name) assembled", "\(n) chip architects, verification and physical-design engineers, at \(Fmt.money(Double(n) * Semis.engineerCost(year))) a year.", .company, image: "wafer_closeup")
        return nil
    }

    mutating func resizeChipTeam(_ id: UUID, engineers: Int) -> String? {
        guard let i = semi.teams.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let n = clamp(engineers, 50, 2_000)
        let old = semi.teams[i].engineers
        let cost = Double(abs(n - old)) * Semis.engineerCost(year) * 0.25
        if n > old && cost > cash { return "Hiring \(n - old) more costs \(Fmt.money(cost))." }
        cash -= cost
        month.costOther += cost
        semi.month.teamCost += cost
        semi.teams[i].engineers = n
        Semis.log(&self, "\(semi.teams[i].name): \(old) → \(n) engineers (\(n > old ? "recruiting" : "severance") \(Fmt.money(cost))).")
        return nil
    }

    mutating func disbandChipTeam(_ id: UUID) -> String? {
        guard let i = semi.teams.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let d = Semis.teamBusy(self, id) { return "\(semi.teams[i].name) is designing \(d.name). Cancel it or wait for tape-out." }
        let cost = Double(semi.teams[i].engineers) * Semis.engineerCost(year) * 0.25
        cash -= cost
        month.costOther += cost
        Semis.log(&self, "Disbanded \(semi.teams[i].name) (severance \(Fmt.money(cost))).")
        semi.teams.remove(at: i)
        return nil
    }

    mutating func startChipDesign(node: String, die: String, stacks: Int, focus: ChipFocus, verification: Int, teamID: UUID?, derivedFrom: String = "") -> String? {
        guard let team = Semis.team(self, teamID) else { return "Pick a design team (hire one first)." }
        guard Semis.designable(self).contains(where: { $0.id == node }) else { return "That node isn't available to design for yet." }
        let d = SemiCatalog.die(die)
        if year < d.from { return "\(d.name) needs packaging that arrives around \(Int(d.from))." }
        if let busy = Semis.teamBusy(self, team.id) { return "\(team.name) is busy designing \(busy.name)." }
        let p = Semis.plan(node: node, verification: verification, team: team, derived: !derivedFrom.isEmpty, self)
        if p.ipCost / max(1, p.designDays / 30.4) * 3 > cash { return "Keep three months of EDA and IP licences (\(Fmt.money(p.ipCost / max(1, p.designDays / 30.4) * 3))) in cash to start." }
        // 3.8: a design that taped out years before any foundry offers the node sat on full pay and IP licences.
        let node_ = SemiCatalog.node(node)
        let open = SemiCatalog.foundries.map { Semis.opens(node_, $0) }.min() ?? node_.launch
        let tapeYear = year + (p.phaseDays[0] + p.phaseDays[1] + p.phaseDays[2]) / 365.25
        if tapeYear < open - 0.25 {
            let startYear = open - (p.phaseDays[0] + p.phaseDays[1] + p.phaseDays[2]) / 365.25
            return "This design would be ready to tape out about \(Int(((open - tapeYear) * 12).rounded())) months before any foundry offers \(node_.short) (from \(Fmt.trim(open, 1))), and the team and IP licences would be paid all that time. Start it around \(Fmt.trim(startYear, 1)), or pick a node that's open now."
        }
        Semis.engage(&self)
        let gen = semi.designs.count + 1
        let name = "\(SemiCatalog.codenames[(gen - 1) % SemiCatalog.codenames.count])-\(gen)"
        var des = SemiDesign(name: name, generation: gen, node: node, die: die, stacks: stacks, focus: focus, verification: clamp(verification, 0, 2),
                             teamID: team.id, started: date)
        des.derivedFrom = derivedFrom
        des.phaseDays = p.phaseDays[0]
        des.phaseDaysLeft = p.phaseDays[0]
        des.respinOdds = p.respin
        des.timeline = [SemiEvent(date: date, text: "Started on \(SemiCatalog.node(node).short), \(d.name.lowercased()), \(stacks) HBM stacks, \(Semis.verificationName(verification).lowercased()) verification. About \(Int(p.months)) months to production.")]
        semi.designs.append(des)
        Semis.log(&self, "Started \(name): \(SemiCatalog.node(node).short) \(focus.rawValue.lowercased()) chip, ~\(Int(p.months)) months.")
        Sim.news(&self, "Chip design started: \(name)",
                 "\(team.name) begins a \(SemiCatalog.node(node).short) \(focus.rawValue.lowercased()) accelerator: about \(Int(p.months)) months and \(Fmt.money(p.total)) to production, \(Fmt.pct(p.respin, decimals: 0)) respin odds.",
                 .company, image: "wafer", important: true)
        return nil
    }

    mutating func cancelChipDesign(_ id: UUID) -> String? {
        guard let i = semi.designs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let d = semi.designs[i]
        if d.inProduction || d.phase == .retired { return "Retire it instead." }
        decisions.removeAll { $0.kind == Semis.bugKind && $0.ref == d.id.uuidString }
        Semis.log(&self, "Cancelled \(d.name) after \(Fmt.money(d.spent)).", tone: -1)
        semi.designs.remove(at: i)
        for bi in semi.bookings.indices where semi.bookings[bi].designID == id { semi.bookings[bi].designID = nil }
        return nil
    }

    /// Wafer bookings still running for a design, and what cancelling them all costs.
    func designContracts(_ id: UUID) -> (bookings: [WaferBooking], fee: Double) {
        let b = semi.bookings.filter { $0.designID == id && $0.end > date }
        return (b, b.reduce(0) { $0 + bookingCancelFee($1) })
    }

    /// `cancelContracts` nil: refuse while the design still has wafer bookings (they keep billing after retirement);
    /// true: cancel them (fee); false: retire and leave them unassigned.
    mutating func retireChipDesign(_ id: UUID, cancelContracts: Bool? = nil) -> String? {
        guard let i = semi.designs.firstIndex(where: { $0.id == id }), semi.designs[i].inProduction else { return "Only products in production can be retired." }
        let tied = designContracts(id)
        if !tied.bookings.isEmpty && cancelContracts == nil {
            return "\(semi.designs[i].name) still has \(tied.bookings.count) wafer booking\(tied.bookings.count == 1 ? "" : "s") that keep billing after it retires. Retire and cancel them (\(Fmt.money(tied.fee)) fee), or retire and keep them for another product."
        }
        if cancelContracts == true { for b in tied.bookings { _ = cancelBooking(b.id) } }
        semi.designs[i].phaseRaw = SemiPhase.retired.rawValue
        semi.designs[i].onSale = [false, false, false]
        for bi in semi.bookings.indices where semi.bookings[bi].designID == id { semi.bookings[bi].designID = nil }
        Semis.note(&self, i, "Retired. Stock already made can still be taken for your fleet.")
        Semis.log(&self, "Retired \(semi.designs[i].name).")
        return nil
    }

    mutating func bookWafers(foundry: String, node: String, wafersMonth: Double, months: Int, startDelayMonths: Int, designID: UUID?) -> String? {
        guard let f = SemiCatalog.foundryByID[foundry] else { return "Unknown foundry." }
        let n = SemiCatalog.node(node)
        guard Semis.offered(n, f, year) else { return "\(f.name) doesn't offer \(n.short) yet (from \(Fmt.trim(Semis.opens(n, f), 1)))." }
        if let why = Semis.foundryBlocker(f, n, self) { return why }
        if wafersMonth < 100 { return "Foundries won't book fewer than 100 wafers a month." }
        let cap = Semis.waferCap(f, n, self).value - Semis.waferBooked(self, foundry: foundry, node: node)
        if wafersMonth > cap { return "\(f.name) can commit only \(Fmt.count(max(0, cap))) more \(n.short) wafers a month to you." }
        let price = Semis.waferPrice(n, f, year) * (months >= 24 ? 0.92 : 1)
        let deposit = wafersMonth * price
        if months < 6 { return "Foundries book at least 6 months. Pick a longer term." }
        if deposit > cash { return "The deposit (one month, \(Fmt.money(deposit))) is more than your cash." }
        if let designID, let d = semi.designs.first(where: { $0.id == designID }), d.node != node { return "\(d.name) is a \(SemiCatalog.node(d.node).short) design." }
        Semis.engage(&self)
        cash -= deposit
        month.costChips += deposit
        semi.month.wafersCost += deposit
        let lead = Semis.leadDays(f.leadDays, "wafer", self)
        let start = GameCalendar.addDays(date, max(lead, startDelayMonths * 30))
        semi.bookings.append(WaferBooking(foundry: foundry, node: node, wafersMonth: wafersMonth, price: price, start: start,
                                          end: GameCalendar.addMonths(start, months), designID: designID, deposit: deposit))
        Semis.log(&self, "Booked \(Fmt.count(wafersMonth)) \(n.short) wafers/month at \(f.name) for \(months) months from \(start.gameShort) at \(Fmt.money(price)) each.")
        Sim.news(&self, "Wafers booked at \(f.name)", "\(Fmt.count(wafersMonth)) \(n.short) wafers a month from \(start.gameShort), \(Fmt.money(wafersMonth * price))/month take-or-pay. The \(Fmt.money(deposit)) deposit comes off your last month.\(designID.flatMap { id in semi.designs.first { $0.id == id } }.map { $0.inProduction ? "" : " Billing waits until \($0.name) is in production." } ?? "")", .hardware, image: "wafer")
        return nil
    }

    mutating func assignBooking(_ id: UUID, to designID: UUID?) -> String? {
        guard let i = semi.bookings.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let designID, let d = semi.designs.first(where: { $0.id == designID }), d.node != semi.bookings[i].node { return "\(d.name) is made on \(SemiCatalog.node(d.node).short)." }
        semi.bookings[i].designID = designID
        return nil
    }

    /// Cancelling costs half of what's left of the commitment.
    func bookingCancelFee(_ bk: WaferBooking) -> Double {
        let left = Double(max(0, GameCalendar.daysBetween(max(date, bk.start), bk.end))) / 30.4
        return bk.wafersMonth * bk.price * left * 0.5
    }

    mutating func cancelBooking(_ id: UUID) -> String? {
        guard let bk = semi.bookings.first(where: { $0.id == id }) else { return "Not found." }
        let fee = bookingCancelFee(bk)
        cash -= fee
        month.costOther += fee
        semi.month.penalties += fee
        semi.bookings.removeAll { $0.id == id }
        Semis.log(&self, "Cancelled a wafer booking at \(SemiCatalog.foundryByID[bk.foundry]?.name ?? bk.foundry): \(Fmt.money(fee)) fee.", tone: -1)
        return nil
    }

    mutating func signSupply(supplier: String, units: Double, months: Int) -> String? {
        guard let sup = SemiCatalog.supplierByID[supplier] else { return "Unknown supplier." }
        if year < sup.from { return "\(sup.name) doesn't offer this until \(Int(sup.from))." }
        let cap = Semis.supplyCap(sup, self) - Semis.supplyBooked(self, supplier: supplier)
        if units < 100 { return "The minimum is 100 a month." }
        if months < 6 { return "Supply contracts run at least 6 months. Pick a longer term." }
        if units > cap { return "\(sup.name) can commit only \(Fmt.count(max(0, cap))) more a month to you." }
        let price = Semis.supplyPrice(sup, self) * (months >= 24 ? 0.92 : 1)
        let deposit = units * price
        if deposit > cash { return "The deposit (one month, \(Fmt.money(deposit))) is more than your cash." }
        Semis.engage(&self)
        cash -= deposit
        month.costChips += deposit
        if sup.kind == "pack" { semi.month.packCost += deposit } else { semi.month.hbmCost += deposit }
        let start = GameCalendar.addDays(date, Semis.leadDays(sup.leadDays, sup.kind, self))
        semi.supply.append(SupplyContract(kind: sup.kind, supplier: supplier, units: units, price: price, start: start, end: GameCalendar.addMonths(start, months), deposit: deposit))
        let what = sup.kind == "pack" ? "packaging slots" : "HBM stacks"
        Semis.log(&self, "Signed \(sup.name): \(Fmt.count(units)) \(what)/month from \(start.gameShort) at \(Fmt.money(price)).")
        return nil
    }

    mutating func cancelSupply(_ id: UUID) -> String? {
        guard let c = semi.supply.first(where: { $0.id == id }) else { return "Not found." }
        if c.own { return "You can't cancel your own line." }
        let left = Double(max(0, GameCalendar.daysBetween(max(date, c.start), c.end))) / 30.4
        let fee = c.units * c.price * left * 0.5
        cash -= fee
        month.costOther += fee
        semi.month.penalties += fee
        semi.supply.removeAll { $0.id == id }
        Semis.log(&self, "Cancelled a \(SemiCatalog.supplierByID[c.supplier]?.name ?? c.supplier) contract: \(Fmt.money(fee)) fee.", tone: -1)
        return nil
    }

    mutating func buildPackagingLine(slots: Double) -> String? {
        let cost = 1e9 + slots * 80_000
        if cost * 0.3 > cash { return "A \(Fmt.count(slots))-slot line costs \(Fmt.money(cost)); you need 30% (\(Fmt.money(cost * 0.3))) up front." }
        if semi.supply.contains(where: { $0.own && $0.start > date }) { return "A packaging line is already being built." }
        Semis.engage(&self)
        cash -= cost * 0.3
        month.capex += cost * 0.3
        semi.month.fabCost += cost * 0.3
        let start = GameCalendar.addMonths(date, 15)
        var c = SupplyContract(kind: "pack", supplier: "own_pack", units: slots, price: 300, start: start, end: start, own: true, buildCost: cost)
        c.end = GameCalendar.addMonths(start, 600)
        // The rest is paid as the line is built.
        c.unpaid = cost * 0.7
        semi.supply.append(c)
        Semis.log(&self, "Building your own advanced-packaging line: \(Fmt.count(slots)) slots/month, \(Fmt.money(cost)), ready \(start.gameShort).")
        Sim.news(&self, "Building an advanced-packaging line", "\(Fmt.count(slots)) interposer slots a month of your own, \(Fmt.money(cost)), online about \(start.gameShort).", .hardware, image: "wafer_closeup")
        return nil
    }

    mutating func buildFab(site: String, node: String, wafersMonth: Double) -> String? {
        guard let st = SemiCatalog.siteByID[site] else { return "Pick a site." }
        let n = SemiCatalog.node(node)
        if n.launch > year { return "Nobody can build a \(n.short) fab before the node exists (\(Fmt.trim(n.launch, 1)))." }
        if HQ.region(self) == .china && market.exportControls && st.region != .china && n.density > 1.0 { return "Export controls: tool makers won't ship leading-edge tools to a Chinese company's fab abroad." }
        if HQ.region(self) == .china && market.exportControls && n.density > 1.8 { return "Export controls: you can't buy EUV tools for anything finer than 5 nm." }
        let cost = Semis.fabCost(n, wafers: wafersMonth) * Progression.fabFactor(self)   // 3.7: Hyperscaler stage
        let net = cost * (1 - st.subsidy)
        if net * 0.15 > cash { return "A fab like this costs \(Fmt.money(cost)) (\(Fmt.money(net)) after \(Fmt.pct(st.subsidy, decimals: 0)) incentives); you need 15% (\(Fmt.money(net * 0.15))) to break ground." }
        Semis.engage(&self)
        cash -= net * 0.15
        month.capex += net * 0.15
        semi.month.fabCost += net * 0.15
        let opens = GameCalendar.addDays(date, Semis.fabBuildDays(st, wafers: wafersMonth))
        let name = "\(st.name.components(separatedBy: ",").first ?? st.name) Fab \(semi.fabs.count + 1)"
        semi.fabs.append(SemiFab(name: name, site: site, node: node, wafersMonth: wafersMonth, buildCost: cost, started: date, opens: opens, unpaid: net * 0.85, designID: nil))
        Semis.log(&self, "Broke ground on \(name): \(n.short), \(Fmt.count(wafersMonth)) wafers/month, \(Fmt.money(cost)) (\(Fmt.money(cost - net)) from incentives), opens \(opens.gameShort).", tone: 1)
        Sim.news(&self, "Breaking ground on \(name)",
                 "Your own \(n.short) fab in \(st.name): \(Fmt.count(wafersMonth)) wafers a month, \(Fmt.money(cost)) (incentives cover \(Fmt.pct(st.subsidy, decimals: 0))). It needs about \(Int(Semis.fabMWFull(n, wafersMonth))) MW of power and \(Fmt.count(n.fabWater * wafersMonth / 1_000)) m³ of water a day. Opens \(opens.gameShort).",
                 .hardware, image: "dc_construction", important: true)
        return nil
    }

    mutating func assignFab(_ id: UUID, to designID: UUID?) -> String? {
        guard let i = semi.fabs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let designID, let d = semi.designs.first(where: { $0.id == designID }), d.node != semi.fabs[i].node {
            return "\(semi.fabs[i].name) runs \(SemiCatalog.node(semi.fabs[i].node).short); \(d.name) is a \(SemiCatalog.node(d.node).short) design."
        }
        semi.fabs[i].designID = designID
        return nil
    }

    mutating func setFabShare(_ id: UUID, share: Double) {
        guard let i = semi.fabs.firstIndex(where: { $0.id == id }) else { return }
        semi.fabs[i].productShare = clamp(share, 0, 1)
    }

    mutating func setChipPrice(_ id: UUID, bin: Int, price: Double? = nil, onSale: Bool? = nil) -> String? {
        guard let i = semi.designs.firstIndex(where: { $0.id == id }), (0..<3).contains(bin) else { return "Not found." }
        if let price {
            if price < 500 { return "That's below what the package alone costs." }
            semi.designs[i].prices[bin] = (price / 10).rounded() * 10
        }
        if let onSale { semi.designs[i].onSale[bin] = onSale }
        return nil
    }

    mutating func setSemiPolicy(keepShare: Double? = nil, allowRivals: Bool? = nil, allowSovereigns: Bool? = nil, holdExcessDies: Bool? = nil) {
        if let keepShare { semi.keepShare = clamp(keepShare, 0, 1) }
        if let holdExcessDies { semi.holdExcessDies = holdExcessDies }
        if let allowRivals { semi.allowRivals = allowRivals }
        if let allowSovereigns { semi.allowSovereigns = allowSovereigns }
    }

    /// Move finished chips between your stock and customer stock.
    mutating func moveChipStock(_ id: UUID, bin: Int, toMine: Bool) {
        guard let i = semi.designs.firstIndex(where: { $0.id == id }), (0..<3).contains(bin) else { return }
        if toMine {
            semi.designs[i].stockMine[bin] += semi.designs[i].stockSale[bin]
            semi.designs[i].stockSale[bin] = 0
        } else {
            semi.designs[i].stockSale[bin] += semi.designs[i].stockMine[bin]
            semi.designs[i].stockMine[bin] = 0
        }
    }
}

extension Semis {
    static func fabMWFull(_ n: ProcessNode, _ wafers: Double) -> Double { n.fabMW * wafers / 1_000 }
}
