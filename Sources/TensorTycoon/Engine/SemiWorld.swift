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
        // 3.9: your chips run as well as your compiler lets them; re-register them as it matures.
        if abs(s.semi.software - s.semi.softwareRegistered) >= 0.005 && s.customChips.contains(where: { isSemiChip($0.id) }) { refreshChips(&s) }
        expire(&s)
        shocks(&s)
        orders(&s)
    }

    static func expire(_ s: inout GameState) {
        let today = s.date
        let monthAgo = GameCalendar.addMonths(today, -1)
        // 3.9: the month paid up front when each booking and contract was signed comes back when it ends.
        for bk in s.semi.bookings where bk.end <= today {
            let f = SemiCatalog.foundryByID[bk.foundry]?.name ?? bk.foundry
            refund(&s, bk.deposit)
            log(&s, "Wafer booking ended: \(Fmt.count(bk.wafersMonth))/month of \(SemiCatalog.node(bk.node).short) at \(f). Deposit of \(Fmt.money(bk.deposit)) returned.")
            if bk.end > monthAgo {
                Sim.news(&s, "Wafer booking ended at \(f)", "\(Fmt.count(bk.wafersMonth)) \(SemiCatalog.node(bk.node).short) wafers a month. Your \(Fmt.money(bk.deposit)) deposit is back. Book again on the Semiconductors page if you still need them.", .hardware)
            }
        }
        s.semi.bookings.removeAll { $0.end <= today }
        for c in s.semi.supply where !c.own && c.end <= today {
            refund(&s, c.deposit)
            log(&s, "\(SemiCatalog.supplierByID[c.supplier]?.name ?? c.supplier) contract ended (\(Fmt.count(c.units)) \(c.kind == "pack" ? "packaging slots" : "HBM stacks")/month). Deposit of \(Fmt.money(c.deposit)) returned.")
        }
        s.semi.supply.removeAll { !$0.own && $0.end <= today }
        for sh in s.semi.shocks where sh.end <= today && sh.end > monthAgo {
            log(&s, "Recovered: \(sh.title).", tone: 1)
        }
        s.semi.shocks.removeAll { $0.end <= GameCalendar.addMonths(today, -6) }
    }

    /// A deposit comes back as cash: set against this month's chip spending (any rest is a one-off receipt).
    static func refund(_ s: inout GameState, _ amount: Double) {
        guard amount > 0 else { return }
        s.cash += amount
        let offset = min(amount, max(0, s.month.costChips))
        s.month.costChips -= offset
        s.month.oneOffIncome += amount - offset
        s.semi.month.depositsBack += amount
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
        // A rival lab asks for a block, at a premium, whether or not you sell to rivals — unless you promised a
        // customer exclusive supply.
        guard exclusiveUntil(s) == nil else { return }
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
            if let until = exclusiveUntil(s) {
                log(&s, "Couldn't sell to \(name): you promised exclusive supply until \(until.gameShort).", tone: -1)
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
        if s.semi.designs.contains(where: { $0.qualified != nil }) && s.semi.software < 0.4 && s.semi.compilerEngineers == 0 {
            out.append(AdvisorItem(id: "semi-software", level: .warning, symbol: "chevron.left.forwardslash.chevron.right",
                                   title: "Your chips' software is immature (\(Fmt.pct(s.semi.software, decimals: 0)))",
                                   detail: "Training on them reaches only \(Fmt.pct(softwareMFU(s.semi.software), decimals: 0)) of the MFU a mature compiler gets, serving \(Fmt.pct(softwareServe(s.semi.software), decimals: 0)) of the throughput, and buyers trust them less. Hire a compiler team.",
                                   screen: .semiconductors))
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

    /// 3.9: hardware–software co-design is no longer a lab-wide bonus on every accelerator: it lives in your own chips'
    /// training MFU and serving throughput, through the software maturity of their stack (`softwareMFU`).
    static let virtualItems: [ResearchItem] = [
        ResearchItem(id: "semi:fab", name: "Fab know-how", category: .systems, year: 0, cost: 0, prereqs: [],
                     effects: [.chipDesign(0.12)], blurb: "Running your own fab teaches your designers what the process can really do."),
    ]

    static func bonusSources(_ s: GameState) -> [(String, Double)] {
        guard !s.semi.fabs.isEmpty else { return [] }
        return s.semi.fabs.contains(where: { $0.open(s.date) }) ? [("semi:fab", 1)] : []
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

    mutating func startChipDesign(node: String, die: String, stacks: Int, focus: ChipFocus, verification: Int, teamID: UUID?,
                                   link: ChipLink = .switched, portOf: UUID? = nil) -> String? {
        guard let team = Semis.team(self, teamID) else { return "Pick a design team (hire one first)." }
        guard Semis.designable(self).contains(where: { $0.id == node }) else { return "That node isn't available to design for yet." }
        guard SemiCatalog.dieByID[die] != nil else { return "Pick a die configuration." }
        guard SemiCatalog.stackChoices.contains(stacks) else { return "Pick \(SemiCatalog.stackChoices.map(String.init).joined(separator: ", ")) HBM stacks." }
        let d = SemiCatalog.die(die)
        if year < d.from { return "\(d.name) needs packaging that arrives around \(Int(d.from))." }
        if year < link.from { return "\(link.title) can't be designed in before \(Int(link.from))." }
        if let busy = Semis.teamBusy(self, team.id) { return "\(team.name) is busy designing \(busy.name)." }
        // 3.9: a port reuses a qualified design of the same focus, at most one node step away.
        var port: SemiDesign? = nil
        if let pid = portOf {
            guard let p = semi.designs.first(where: { $0.id == pid }), p.qualified != nil else { return "Only a design that reached production can be ported." }
            if p.focus != focus { return "A port keeps its parent's focus: \(p.name) is a \(p.focus.rawValue.lowercased()) chip." }
            if Semis.nodeStep(p.node, node) > 1 { return "A port can move one node at most: \(p.name) is on \(SemiCatalog.node(p.node).short)." }
            port = p
        }
        let p = Semis.plan(node: node, verification: verification, team: team, derived: port != nil, link: link, self)
        if p.ipCost / max(1, p.designDays / 30.4) * 3 > cash { return "Keep three months of EDA and IP licences (\(Fmt.money(p.ipCost / max(1, p.designDays / 30.4) * 3))) in cash to start." }
        Semis.engage(&self)
        // 3.9: one past the newest qualified design of this focus; a port stays in its parent's generation.
        let gen = port?.generation ?? Semis.nextGeneration(focus, self)
        let name = "\(SemiCatalog.codenames[semi.counter % SemiCatalog.codenames.count])-\(gen)"
        semi.counter += 1
        var des = SemiDesign(name: name, generation: gen, node: node, die: die, stacks: stacks, focus: focus, verification: clamp(verification, 0, 2),
                             teamID: team.id, started: date)
        des.derivedFrom = port?.name ?? ""
        des.parentID = port?.id
        des.link = link.rawValue
        des.phaseDays = p.phaseDays[0]
        des.phaseDaysLeft = p.phaseDays[0]
        des.respinOdds = p.respin
        des.timeline = [SemiEvent(date: date, text: "Started on \(SemiCatalog.node(node).short), \(d.name.lowercased()), \(stacks) HBM stacks, \(link.short), \(Semis.verificationName(verification).lowercased()) verification\(port.map { ", porting \($0.name)" } ?? ""). About \(Int(p.months)) months to production.")]
        semi.designs.append(des)
        Semis.log(&self, "Started \(name): \(SemiCatalog.node(node).short) \(focus.rawValue.lowercased()) chip, generation \(gen), ~\(Int(p.months)) months.")
        Sim.news(&self, "Chip design started: \(name)",
                 "\(team.name) begins a \(SemiCatalog.node(node).short) \(focus.rawValue.lowercased()) accelerator\(port.map { " (a port of \($0.name))" } ?? ""): about \(Int(p.months)) months and \(Fmt.money(p.total)) to production, \(Fmt.pct(p.respin, decimals: 0)) respin odds.",
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

    mutating func retireChipDesign(_ id: UUID) -> String? {
        guard let i = semi.designs.firstIndex(where: { $0.id == id }), semi.designs[i].inProduction else { return "Only products in production can be retired." }
        // 3.9: a retired product makes nothing more, so its open orders must already be in customer stock.
        for b in 0..<3 {
            let owed = semi.contracts.filter { !$0.closed && $0.designID == id && $0.bin == b }.reduce(0) { $0 + $1.remaining }
            if owed > semi.designs[i].stockSale[b] + 0.5 {
                return "\(semi.designs[i].name) still owes \(Fmt.count(owed)) \(SemiCatalog.binNames[b]) chips on open orders and has \(Fmt.count(semi.designs[i].stockSale[b])) in customer stock. Make or move enough first, or the late orders pay penalties."
            }
        }
        semi.designs[i].phaseRaw = SemiPhase.retired.rawValue
        semi.designs[i].onSale = [false, false, false]
        Semis.note(&self, i, "Retired. Open orders still ship from customer stock; stock already made can still be taken for your fleet.")
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
        if deposit > cash { return "The deposit (one month, \(Fmt.money(deposit))) is more than your cash." }
        if let designID, let d = semi.designs.first(where: { $0.id == designID }), d.node != node { return "\(d.name) is a \(SemiCatalog.node(d.node).short) design." }
        Semis.engage(&self)
        cash -= deposit
        month.costChips += deposit
        semi.month.wafersCost += deposit
        let lead = Semis.leadDays(f.leadDays, "wafer", self)
        let start = GameCalendar.addDays(date, max(lead, startDelayMonths * 30))
        semi.bookings.append(WaferBooking(foundry: foundry, node: node, wafersMonth: wafersMonth, price: price, start: start,
                                          end: GameCalendar.addMonths(start, max(6, months)), designID: designID))
        Semis.log(&self, "Booked \(Fmt.count(wafersMonth)) \(n.short) wafers/month at \(f.name) for \(months) months from \(start.gameShort) at \(Fmt.money(price)) each.")
        Sim.news(&self, "Wafers booked at \(f.name)", "\(Fmt.count(wafersMonth)) \(n.short) wafers a month from \(start.gameShort), \(Fmt.money(wafersMonth * price))/month take-or-pay.", .hardware, image: "wafer")
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
        Semis.refund(&self, bk.deposit)   // 3.9: the deposit comes back against the fee
        semi.bookings.removeAll { $0.id == id }
        Semis.log(&self, "Cancelled a wafer booking at \(SemiCatalog.foundryByID[bk.foundry]?.name ?? bk.foundry): \(Fmt.money(fee)) fee, \(Fmt.money(bk.deposit)) deposit returned.", tone: -1)
        return nil
    }

    mutating func signSupply(supplier: String, units: Double, months: Int) -> String? {
        guard let sup = SemiCatalog.supplierByID[supplier] else { return "Unknown supplier." }
        if year < sup.from { return "\(sup.name) doesn't offer this until \(Int(sup.from))." }
        let cap = Semis.supplyCap(sup, self) - Semis.supplyBooked(self, supplier: supplier)
        if units < 100 { return "The minimum is 100 a month." }
        if units > cap { return "\(sup.name) can commit only \(Fmt.count(max(0, cap))) more a month to you." }
        let price = Semis.supplyPrice(sup, self) * (months >= 24 ? 0.92 : 1)
        let deposit = units * price
        if deposit > cash { return "The deposit (one month, \(Fmt.money(deposit))) is more than your cash." }
        Semis.engage(&self)
        cash -= deposit
        month.costChips += deposit
        if sup.kind == "pack" { semi.month.packCost += deposit } else { semi.month.hbmCost += deposit }
        let start = GameCalendar.addDays(date, Semis.leadDays(sup.leadDays, sup.kind, self))
        semi.supply.append(SupplyContract(kind: sup.kind, supplier: supplier, units: units, price: price, start: start, end: GameCalendar.addMonths(start, max(6, months))))
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
        Semis.refund(&self, c.deposit)   // 3.9: the deposit comes back against the fee
        semi.supply.removeAll { $0.id == id }
        Semis.log(&self, "Cancelled a \(SemiCatalog.supplierByID[c.supplier]?.name ?? c.supplier) contract: \(Fmt.money(fee)) fee, \(Fmt.money(c.deposit)) deposit returned.", tone: -1)
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

    @discardableResult
    mutating func setSemiPolicy(keepShare: Double? = nil, allowRivals: Bool? = nil, allowSovereigns: Bool? = nil, holdExcessDies: Bool? = nil) -> String? {
        if allowRivals == true, let until = Semis.exclusiveUntil(self) { return "You promised exclusive supply until \(until.gameShort)." }
        if let keepShare { semi.keepShare = clamp(keepShare, 0, 1) }
        if let holdExcessDies { semi.holdExcessDies = holdExcessDies }
        if let allowRivals { semi.allowRivals = allowRivals }
        if let allowSovereigns { semi.allowSovereigns = allowSovereigns }
        return nil
    }

    /// 3.9: hire, grow or shrink the compiler and kernel team (0 lets it go). Recruiting and severance cost a quarter
    /// of a year's pay for the engineers who join or leave.
    mutating func setCompilerTeam(engineers: Int) -> String? {
        guard bonuses.has(.customSilicon) else { return "Research Custom Accelerator Design first." }
        let n = engineers <= 0 ? 0 : clamp(engineers, 25, 1_500)
        let old = semi.compilerEngineers
        let cost = Double(abs(n - old)) * Semis.engineerCost(year) * 0.9 * 0.25
        if n > old && cost > cash { return "Hiring \(n - old) compiler engineers costs \(Fmt.money(cost)) up front." }
        Semis.engage(&self)
        cash -= cost
        month.costOther += cost
        semi.month.softwareCost += cost
        semi.compilerEngineers = n
        Semis.log(&self, n == 0 ? "Let the compiler team go (severance \(Fmt.money(cost)))." : "Compiler team: \(old) → \(n) engineers (\(n > old ? "recruiting" : "severance") \(Fmt.money(cost))).")
        return nil
    }

    /// 3.9: where a fab buys its power, as for a datacenter.
    mutating func setFabPower(_ id: UUID, deal: PowerDeal) -> String? {
        guard let i = semi.fabs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if !deal.available(self) { return "\(deal.rawValue) isn't available yet." }
        let before = Semis.fabPowerDeal(semi.fabs[i])
        semi.fabs[i].powerDeal = deal == .grid ? "" : deal.rawValue
        if deal != before && deal.green >= 1 { brand = min(100, brand + 1) }
        Semis.log(&self, "\(semi.fabs[i].name) now runs on \(deal.rawValue.lowercased()).")
        return nil
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

// MARK: - 3.9: compute economics

extension Semis {
    /// What one accelerator's compute costs: a day of the chip (four-year amortisation and power, or rent) over the
    /// PFLOPS it really delivers — training at the MFU your lab reaches on it, serving at your serving utilisation.
    struct Economics {
        var name: String
        var own: Bool
        /// "bought", "rented" or "made".
        var how: String
        var dayCost: Double
        var trainPF: Double
        var servePF: Double
        var trainCost: Double { trainPF > 0 ? dayCost / trainPF : .infinity }
        var serveCost: Double { servePF > 0 ? dayCost / servePF : .infinity }
    }

    /// Power, cooling and the building around one chip for a day at your main site.
    static func chipPowerDay(_ a: Accelerator, _ s: GameState) -> Double {
        let site = s.sites.first { $0.kind != .garage } ?? s.sites.first
        return Economy.chipKW(a) * (site?.pue ?? 1.4) * 24 * (site?.powerPrice ?? 0.1)
    }

    static func economics(_ a: Accelerator, rent: Bool, _ s: GameState, _ b: ResearchBonuses) -> Economics? {
        let own = isSemiChip(a.id)
        let day: Double
        if rent {
            guard let r = Economy.rent(a, s) else { return nil }
            day = r * 24
        } else {
            guard let p = Economy.price(a, s) else { return nil }
            day = (p + siliconCost(a.id, s)) / (4 * 365) + chipPowerDay(a, s)
        }
        let mfu = Physics.mfu(accel: a, chips: 1_024, state: s, bonuses: b)
        let train = a.trainTFLOPS(.fp8) * mfu / 1_000
        let serve = a.inferTFLOPS(.fp8) * Physics.servingUtilization(b) * a.serveFactor / 1_000
        return Economics(name: a.name, own: own, how: own ? "made" : (rent ? "rented" : "bought"), dayCost: day, trainPF: train, servePF: serve)
    }

    /// Your chips against the cheapest merchant compute you could buy or rent today, for training and for serving
    /// ($ per PFLOP-day actually delivered).
    static func computeEconomics(_ s: GameState, _ b: ResearchBonuses) -> (mine: [Economics], train: Economics?, serve: Economics?) {
        var mine: [Economics] = []
        for d in s.semi.designs where d.inProduction || d.phase == .retired {
            for id in d.chipIDs.prefix(2) {
                if let a = HardwareCatalog.get(id), let e = economics(a, rent: false, s, b) { mine.append(e) }
            }
        }
        var merchant: [Economics] = []
        for a in HardwareCatalog.all where a.cls == .datacenter || a.cls == .tpu || a.cls == .custom {
            if Economy.canBuy(a, s), let e = economics(a, rent: false, s, b) { merchant.append(e) }
            if Economy.canRent(a, s), let e = economics(a, rent: true, s, b) { merchant.append(e) }
        }
        let train = merchant.filter { $0.trainPF > 0 }.min { $0.trainCost != $1.trainCost ? $0.trainCost < $1.trainCost : $0.name < $1.name }
        let serve = merchant.filter { $0.servePF > 0 }.min { $0.serveCost != $1.serveCost ? $0.serveCost < $1.serveCost : $0.name < $1.name }
        return (mine, train, serve)
    }
}

// MARK: - 3.9: the playtest bot's chip business (`--playtest … semis`)

extension Semis {
    /// A sensible player's semiconductor programme, run monthly: research custom silicon, hire a design team once rich,
    /// design a training chip on a node a foundry offers now, hire a compiler team, book wafers, packaging and HBM in
    /// time for qualification, take chips for the fleet, sell the rest, and start the next generation.
    static func botAct(_ s: inout GameState) {
        if !s.bonuses.has(.customSilicon) {
            if s.cash > 2e9 { s.queueResearch("custom_silicon") }
            return
        }
        if s.semi.teams.isEmpty {
            guard s.cash > 4e9 else { return }
            _ = s.hireChipTeam(engineers: 400)
            return
        }
        if s.semi.compilerEngineers == 0 && !s.semi.designs.isEmpty && s.cash > 2e9 { _ = s.setCompilerTeam(engineers: 150) }
        // A design whenever the team is free and nothing newer than the last qualified chip is under way.
        if let t = s.semi.teams.first, teamBusy(s, t.id) == nil,
           !s.semi.designs.contains(where: { $0.phase.rawValue < SemiPhase.production.rawValue }),
           let fsw = SemiCatalog.foundryByID["fsw"],
           let node = SemiCatalog.nodes.filter({ offered($0, fsw, s.year) && foundryBlocker(fsw, $0, s) == nil }).last {
            let newest = s.semi.designs.filter { $0.qualified != nil }.max { $0.qualified! < $1.qualified! }
            if newest == nil || (s.year - (newest?.qualified?.decimalYear ?? 0) > 1.0 && s.cash > 3e9) {
                let die = s.year >= 2025 ? "quad" : (s.year >= 2021 ? "dual" : "large")
                _ = s.startChipDesign(node: node.id, die: die, stacks: 8, focus: .training, verification: 1, teamID: t.id)
            }
        }
        // The newest design past tape-out gets the supply; once it's in production, older ones retire.
        let newest = s.semi.designs.indices.filter { s.semi.designs[$0].phase.rawValue >= SemiPhase.tapeout.rawValue && s.semi.designs[$0].phase != .retired }
            .max { s.semi.designs[$0].generation < s.semi.designs[$1].generation }
        if let n = newest, s.semi.designs[n].inProduction {
            for d in s.semi.designs where d.inProduction && d.id != s.semi.designs[n].id { _ = s.retireChipDesign(d.id) }
        }
        for i in s.semi.designs.indices {
            let d = s.semi.designs[i]
            // Book supply when the design tapes out, timed for qualification.
            if i == newest, !s.semi.bookings.contains(where: { $0.designID == d.id && $0.end > GameCalendar.addDays(s.date, 60) }) {
                botBook(&s, i)
            }
            guard d.inProduction else { continue }
            if !d.onSale[0] || !d.onSale[1] {
                _ = s.setChipPrice(d.id, bin: 0, onSale: true)
                _ = s.setChipPrice(d.id, bin: 1, onSale: true)
            }
            // Take a batch for the fleet whenever enough is in your own stock.
            for b in 0..<2 where d.chipIDs.indices.contains(b) && d.stockMine[b] >= 1_000 {
                guard let a = HardwareCatalog.get(d.chipIDs[b]) else { continue }
                var fits = s.bestSite(for: a, count: Int(d.stockMine[b])).fits
                // No room for them: lease a liquid-cooled cage at the cheapest location, as a player would.
                if fits < 512, s.cash > 2e9, let loc = LocationCatalog.all.min(by: { $0.coloFee < $1.coloFee }) {
                    let kw = clamp(d.stockMine[b] * Economy.chipKW(a) * 1.05, 2_000, Campus.coloCapMW * 1_000)
                    let n = s.sites.filter { $0.name.hasPrefix("Silicon cage") }.count + 1
                    if s.buildSite(kind: .colo, locationID: loc.id, capacityKW: kw.rounded(), cooling: .liquid, power: .grid, name: "Silicon cage \(n)") == nil {
                        fits = s.bestSite(for: a, count: Int(d.stockMine[b])).fits
                    }
                }
                let n = min(Int(d.stockMine[b]), fits) / 64 * 64
                // What doesn't fit at your sites goes to customers instead of sitting in stock.
                if n < 64 || s.orderOwnChips(d.chipIDs[b], count: n) != nil { s.moveChipStock(d.id, bin: b, toMine: false) }
            }
        }
        // Wafers going to a retired or superseded product move to the newest one on the same node.
        for bi in s.semi.bookings.indices {
            guard let d = s.semi.designs.first(where: { $0.id == s.semi.bookings[bi].designID }), d.phase == .retired else { continue }
            if let next = s.semi.designs.filter({ $0.node == d.node && $0.phase != .retired }).last { s.semi.bookings[bi].designID = next.id }
        }
    }

    /// Wafers at the leading foundry starting about when the chip qualifies, sized — as a careful player would — to the
    /// packaging and HBM still to be had (no point making dies nobody can package), and those contracts signed.
    static func botBook(_ s: inout GameState, _ i: Int) {
        let d = s.semi.designs[i]
        guard let f = SemiCatalog.foundries.first(where: { offered(SemiCatalog.node(d.node), $0, s.year) && foundryBlocker($0, SemiCatalog.node(d.node), s) == nil }) else { return }
        let n = SemiCatalog.node(d.node)
        let toQualify = d.inProduction ? 0.0 : d.phaseDaysLeft + (d.phase == .tapeout ? 75 : 0)
        let y = previewYield(node: d.node, die: d.die, foundry: f, s, at: s.year + toQualify / 365)
        let chipsPerWafer = y.diesPerWafer * y.good / Double(SemiCatalog.die(d.die).dies)
        let packable = min(supplyRoom("pack", s) / slotsPerChip(d), supplyRoom("hbm", s) / Double(d.stacks))
        let cap = waferCap(f, n, s).value - waferBooked(s, foundry: f.id, node: n.id)
        let wafers = (min(3_000, cap, packable / max(0.01, chipsPerWafer)) / 100).rounded(.down) * 100
        guard wafers >= 100 else { return }
        let delay = max(0, Int(toQualify / 30.4) - Int(Double(f.leadDays) / 30.4))
        guard s.bookWafers(foundry: f.id, node: n.id, wafersMonth: wafers, months: 24, startDelayMonths: delay, designID: d.id) == nil else { return }
        let chips = wafers * chipsPerWafer
        for (kind, need) in [("pack", chips * slotsPerChip(d)), ("hbm", chips * Double(d.stacks))] {
            var left = need
            for sup in SemiCatalog.suppliers where sup.kind == kind && sup.from <= s.year && left >= 100 {
                let free = supplyCap(sup, s) - supplyBooked(s, supplier: sup.id)
                let take = (min(left, free) / 100).rounded(.down) * 100
                guard take >= 100, s.signSupply(supplier: sup.id, units: take, months: 24) == nil else { continue }
                left -= take
            }
        }
    }

    /// Packaging slots or HBM stacks a month all suppliers together could still sign you for.
    static func supplyRoom(_ kind: String, _ s: GameState) -> Double {
        SemiCatalog.suppliers.filter { $0.kind == kind && $0.from <= s.year }.reduce(0) { $0 + max(0, supplyCap($1, s) - supplyBooked(s, supplier: $1.id)) }
    }

    /// Summary lines for the playtest (`semis` flag).
    static func report(_ s: GameState) -> [String] {
        guard s.semi.engaged else { return ["  semis: never engaged (no team hired)"] }
        var out: [String] = []
        let made = s.semi.designs.reduce(0) { $0 + $1.made.reduce(0, +) }
        let sold = s.semi.designs.reduce(0) { $0 + $1.sold.reduce(0, +) }
        let taken = s.semi.designs.reduce(0) { $0 + $1.taken.reduce(0, +) }
        let rev = s.semi.designs.reduce(0) { $0 + $1.revenue }
        let cost = s.semi.designs.reduce(0) { $0 + $1.cost }
        out.append("  semis: \(s.semi.designs.count) designs · made \(Fmt.count(made)) chips, sold \(Fmt.count(sold)), kept \(Fmt.count(taken)) · product revenue \(Fmt.money(rev)) vs production cost \(Fmt.money(cost)) · software \(Fmt.pct(s.semi.software, decimals: 0)) (\(s.semi.compilerEngineers) compiler engineers) · reputation \(Fmt.pct(reputation(s), decimals: 0))")
        for d in s.semi.designs {
            let ultra = d.chipIDs.first.flatMap { HardwareCatalog.get($0) }
            out.append("    \(d.name) gen \(d.generation) \(SemiCatalog.node(d.node).short) \(d.die) \(d.focus.rawValue.lowercased()) · \(d.phase.title)\(d.respins + d.metalFixes > 0 ? " · \(d.respins) respins \(d.metalFixes) metal fixes" : "")"
                       + (ultra.map { " · \(Fmt.count($0.bf16)) TF \(Int($0.tdpW)) W MFU \(Fmt.pct($0.baseMFU, decimals: 0)) (\(perfLabel($0.bf16, s)))" } ?? "")
                       + " · made \(Fmt.count(d.made.reduce(0, +))) sold \(Fmt.count(d.sold.reduce(0, +))) kept \(Fmt.count(d.taken.reduce(0, +))) bank \(Fmt.count(d.dieBank.reduce(0, +)))")
        }
        let ec = computeEconomics(s, s.bonuses)
        if let best = ec.mine.min(by: { $0.trainCost < $1.trainCost }), let m = ec.train {
            out.append("    $/PFLOP-day training: yours \(Fmt.money(best.trainCost)) (\(best.name)) vs best merchant \(Fmt.money(m.trainCost)) (\(m.name), \(m.how))")
        }
        let toRivals = s.semi.history.reduce(0) { $0 + $1.toRivals }
        out.append("    last 24 months: wafers \(Fmt.count(s.semi.history.reduce(0) { $0 + $1.wafers })), chips \(Fmt.count(s.semi.history.reduce(0) { $0 + $1.chips })), to rivals \(Fmt.count(toRivals)), packaging-bound months \(s.semi.history.filter { $0.bottleneck == "packaging" }.count), HBM-bound \(s.semi.history.filter { $0.bottleneck == "HBM" }.count)")
        return out
    }
}
