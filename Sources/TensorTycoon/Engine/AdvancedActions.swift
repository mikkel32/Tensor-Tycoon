import Foundation

// MARK: - 3.5: Advanced Projects — player actions

extension GameState {
    /// Submit a proposal. `price` is the share of the ceiling you bid (fixed-price, grant) or your fee rate (cost-plus).
    mutating func submitProposal(_ id: String, price: Double) -> String? {
        guard let i = advanced.solicitations.firstIndex(where: { $0.id == id }) else { return "That solicitation has closed." }
        let sol = advanced.solicitations[i]
        guard sol.bid == nil else { return "You've already bid." }
        guard sol.closes > date else { return "Bidding has closed." }
        let o = AdvancedProjects.odds(sol, self, price: price)
        if let b = o.blockers.first { return b + "." }
        let cost = AdvancedProjects.proposalCost(sol)
        guard cash >= cost else { return "Writing the proposal costs \(Fmt.money(cost))." }
        cash -= cost
        month.costOther += cost
        advanced.engaged = true
        let clamped = sol.type == .costPlus ? clamp(price, 0.02, 0.15) : clamp(price, 0.6, 1.0)
        advanced.solicitations[i].bid = ProposalBid(price: clamped, submitted: date, proposalCost: cost, odds: o.p)
        return nil
    }

    mutating func withdrawProposal(_ id: String) {
        guard let i = advanced.solicitations.firstIndex(where: { $0.id == id }) else { return }
        advanced.solicitations[i].bid = nil
    }

    /// Put an employee on (or take them off) a programme.
    mutating func assignToProgramme(_ pid: UUID, employee: UUID, on: Bool) -> String? {
        guard let i = advanced.programmes.firstIndex(where: { $0.id == pid }), advanced.programmes[i].status == .active else { return "That programme isn't active." }
        if !on {
            advanced.programmes[i].staff.removeAll { $0 == employee }
            advanced.seconded.remove(employee)
            return nil
        }
        guard let e = employees.first(where: { $0.id == employee }) else { return "They've left the company." }
        let p = advanced.programmes[i]
        guard !advanced.seconded.contains(employee) else { return "\(e.name) is already on a programme." }
        guard AdvancedProjects.clearanceLevel(self, employee) >= p.sol.classification else {
            return "\(e.name) needs a \(p.sol.level.clearance) clearance first."
        }
        if p.sol.level > .unclassified && AdvancedProjects.freeSeats(self, p.sol.level) < 1 {
            return "No free desk in a facility accredited \(AdvancedProjects.facilityLevelName(p.sol.classification)) or higher."
        }
        advanced.programmes[i].staff.append(employee)
        advanced.seconded.insert(employee)
        return nil
    }

    /// Fill a programme's team with the best available people already cleared for it, role by role.
    mutating func autoStaffProgramme(_ pid: UUID) -> String? {
        guard let i = advanced.programmes.firstIndex(where: { $0.id == pid }), advanced.programmes[i].status == .active else { return "That programme isn't active." }
        let sol = advanced.programmes[i].sol
        var added = 0
        for (k, n) in sol.staff.sorted(by: { $0.key < $1.key }) {
            guard let role = Role(rawValue: k) else { continue }
            let have = employees.filter { advanced.programmes[i].staff.contains($0.id) && $0.role == role }.count
            guard have < n else { continue }
            // Best people first, but those paid within the allowable-compensation cap before the stars the contract won't fully pay for.
            let cap = Macro.salary(role, year) * 1.5
            let pool = employees.filter { $0.role == role && !advanced.seconded.contains($0.id) && AdvancedProjects.clearanceLevel(self, $0.id) >= sol.classification }
                .sorted { ($0.salary > cap ? 1 : 0, -$0.skill) < ($1.salary > cap ? 1 : 0, -$1.skill) }
            for e in pool.prefix(n - have) where assignToProgramme(pid, employee: e.id, on: true) == nil { added += 1 }
        }
        if sol.level > .unclassified && advanced.programmes[i].compute < sol.computeH100e {
            let free = AdvancedProjects.freeCompute(self, sol.level, excluding: pid)
            advanced.programmes[i].compute = min(sol.computeH100e, free)
        }
        return added == 0 && advanced.programmes[i].staff.isEmpty ? "Nobody suitable is free. Hire or clear more staff." : nil
    }

    /// Cleared compute for a programme (from accredited facilities at or above its classification).
    mutating func setProgrammeCompute(_ pid: UUID, _ amount: Double) -> String? {
        guard let i = advanced.programmes.firstIndex(where: { $0.id == pid }), advanced.programmes[i].status == .active else { return "That programme isn't active." }
        let p = advanced.programmes[i]
        guard p.sol.level > .unclassified else { return "Unclassified work runs on rented cloud compute, billed to the contract." }
        let free = AdvancedProjects.freeCompute(self, p.sol.level, excluding: pid)
        advanced.programmes[i].compute = max(0, min(amount, free))
        return amount > free + 0.5 ? "Only \(Fmt.int(Int(free))) H100e of suitable cleared compute is free." : nil
    }

    /// Second an agent swarm to a programme (unclassified and CUI work only).
    mutating func setProgrammeSwarm(_ pid: UUID, _ swarm: UUID?) -> String? {
        guard let i = advanced.programmes.firstIndex(where: { $0.id == pid }), advanced.programmes[i].status == .active else { return "That programme isn't active." }
        if let swarm {
            guard advanced.programmes[i].sol.level.agentsAllowed else { return "Agents aren't allowed on \(advanced.programmes[i].sol.level.title) networks." }
            guard swarms.contains(where: { $0.id == swarm }) else { return "That swarm is gone." }
            for j in advanced.programmes.indices where advanced.programmes[j].swarm == swarm { advanced.programmes[j].swarm = nil }
        }
        advanced.programmes[i].swarm = swarm
        return nil
    }

    /// Start a background investigation for an employee.
    mutating func requestClearance(_ employee: UUID, level: Int) -> String? {
        guard let e = employees.first(where: { $0.id == employee }) else { return "They've left the company." }
        if let why = Progression.blocker(self, .classified) { return why }   // 3.8: Frontier Lab
        let level = clamp(level, 1, 3)
        var c = advanced.clearances.first { $0.employee == employee } ?? Clearance(employee: employee)
        guard c.level < level else { return "\(e.name) already holds that clearance." }
        guard c.ready == nil else { return "An investigation for \(e.name) is already under way." }
        guard c.deniedAt == 0 || c.deniedAt > level else { return "\(e.name) was turned down for this level." }
        let cost = AdvancedProjects.clearanceCost(level, year)
        guard cash >= cost else { return "The investigation costs \(Fmt.money(cost))." }
        cash -= cost
        month.costOther += cost
        advanced.engaged = true
        let months = AdvancedProjects.clearanceMonths(level) * (0.75 + 0.5 * AdvancedProjects.roll(self, "cleartime|\(employee.uuidString)|\(level)"))
        c.target = level
        c.started = date
        c.ready = GameCalendar.addDays(date, Int(months * 30.4))
        c.cost += cost
        if let i = advanced.clearances.firstIndex(where: { $0.employee == employee }) { advanced.clearances[i] = c } else { advanced.clearances.append(c) }
        return nil
    }

    /// Start investigations for enough of the best people in each role a programme needs.
    mutating func clearTeamFor(_ pid: UUID) -> String? {
        guard let p = advanced.programmes.first(where: { $0.id == pid }) else { return "That programme is gone." }
        guard p.sol.level > .unclassified else { return "Unclassified work needs no clearances." }
        var started = 0
        for (k, n) in p.sol.staff {
            guard let role = Role(rawValue: k) else { continue }
            let level = p.sol.classification
            let pending = Set(advanced.clearances.filter { $0.ready != nil && $0.target >= level }.map(\.employee))
            let ok = employees.filter { e in e.role == role && (AdvancedProjects.clearanceLevel(self, e.id) >= level || pending.contains(e.id)) }.count
            guard ok < n else { continue }
            let pool = employees.filter { e in
                e.role == role && AdvancedProjects.clearanceLevel(self, e.id) < level
                    && !(advanced.clearances.first { $0.employee == e.id }.map { $0.ready != nil || ($0.deniedAt > 0 && $0.deniedAt <= level) } ?? false)
            }.sorted { $0.skill > $1.skill }
            for e in pool.prefix(n - ok) where requestClearance(e.id, level: level) == nil { started += 1 }
        }
        return started == 0 ? "No one else to put forward: hire more staff in the roles it needs." : nil
    }

    /// Build a classified facility.
    mutating func buildFacility(_ kind: FacilityKind, level: Int, capacity: Double, site: UUID) -> String? {
        guard let st = AdvancedProjects.sitesFor(kind, self).first(where: { $0.id == site }) else { return "That site can't host a \(kind.title.lowercased())." }
        if let why = Progression.blocker(self, .classified) { return why }   // 3.8: Frontier Lab
        let q = AdvancedProjects.quote(kind, level: level, capacity: capacity, year)
        if let b = AdvancedProjects.facilityBlockers(kind, level: clamp(level, 1, 3), self).first { return "It needs \(b.prefix(1).lowercased() + b.dropFirst())." }
        if kind == .clearedHall {
            let free = st.capacityKW - Economy.siteLoadKW(self, st.id) - AdvancedProjects.facilityKW(self, site: st.id)
            guard free >= q.kw else { return "\(st.name) has \(Fmt.watts(max(0, free) * 1000)) free; the hall needs \(Fmt.watts(q.kw * 1000))." }
        }
        guard cash >= q.capex else { return "It costs \(Fmt.money(q.capex))." }
        cash -= q.capex
        month.capex += q.capex
        advanced.engaged = true
        let n = advanced.facilities.filter { $0.kind == kind }.count + 1
        let name = "\(st.name) \(kind.nameSuffix) \(n)"
        advanced.facilities.append(SecureFacility(name: name, kind: kind, level: clamp(level, 1, 3), siteID: site, capacity: capacity, started: date,
                                                  ready: GameCalendar.addDays(date, Int(q.months * 30.4)), capex: q.capex, opex: q.opex))
        return nil
    }

    /// Close a facility (no refund; programmes using it lose their compute or desks).
    mutating func closeFacility(_ id: UUID) {
        advanced.facilities.removeAll { $0.id == id }
        for i in advanced.programmes.indices where advanced.programmes[i].status == .active && advanced.programmes[i].sol.level > .unclassified {
            let free = AdvancedProjects.freeCompute(self, advanced.programmes[i].sol.level, excluding: advanced.programmes[i].id)
            advanced.programmes[i].compute = min(advanced.programmes[i].compute, free)
        }
    }

    /// Hand a programme back (counts as default on contracts).
    mutating func abandonProgramme(_ pid: UUID) {
        guard let i = advanced.programmes.firstIndex(where: { $0.id == pid }), advanced.programmes[i].status == .active else { return }
        let lapse = advanced.programmes[i].sol.type == .grant || advanced.programmes[i].sol.type == .prize
        AdvancedProjects.terminate(&self, i, lapse ? .lapsed : .terminated, "you walked away from it")
        AdvancedProjects.syncSeconded(&self)
    }
}

// MARK: - Playtest bot policy and economics report

extension AdvancedProjects {
    /// A simple policy for the playtest bot (flag `advproj`): one unclassified programme at a time, bid at 95% of the
    /// ceiling (8% fee on cost-plus), staff it with whoever fits, and keep going.
    static func botAct(_ s: inout GameState) {
        let active = s.advanced.programmes.filter { $0.status == .active }
        for p in active {
            if p.sol.level > .unclassified { _ = s.clearTeamFor(p.id) }
            _ = s.autoStaffProgramme(p.id)
        }
        guard active.isEmpty, !s.advanced.solicitations.contains(where: { $0.bid != nil }) else { return }
        var best: (id: String, price: Double, score: Double)? = nil
        for sol in s.advanced.solicitations where sol.bid == nil && sol.closes > s.date && sol.level == .unclassified && sol.type != .prize
            && (sol.templateDef?.facility.map { facilityFree(s, $0, level: sol.level) >= 1 } ?? true) {
            let price = sol.type == .costPlus ? 0.08 : 0.95
            let p = odds(sol, s, price: price).p
            guard p >= 0.25, s.cash > 20 * proposalCost(sol), staffReadiness(sol, s) >= 0.6 else { continue }
            let score = p * sol.ceiling
            if best == nil || score > best!.score { best = (sol.id, price, score) }
        }
        guard let pick = best else { return }
        _ = s.submitProposal(pick.id, price: pick.price)
    }

    /// One line per contract: what it was, how it went and its P&L.
    static func report(_ s: GameState) -> [String] {
        var out = ["Advanced Projects: \(s.advanced.bids.count) bids decided (\(s.advanced.bids.filter(\.won).count) won), \(s.advanced.programmes.count) programmes"]
        for b in s.advanced.bids.reversed() {
            out.append("  bid \(b.date.gameShort) \(b.title) (\(b.agency)) odds \(Fmt.pct(b.odds, decimals: 0)) → \(b.won ? "WON" : "lost to \(b.winner)")")
        }
        for p in s.advanced.programmes {
            out.append("  \(p.sol.title) [\(p.template?.topic ?? ""), \(p.sol.type.short), \(p.sol.level.short), \(p.sol.agencyDef?.short ?? "")] \(p.awarded.gameShort) → \(p.status.title)"
                       + " at \(p.stage.title) after \(p.months)/\(p.sol.months) mo, \(p.reworks) reworks · value \(Fmt.money(p.value)) · revenue \(Fmt.money(p.revenue))"
                       + " · direct \(Fmt.money(p.direct)) · allocated \(Fmt.money(p.allocated)) · bid \(Fmt.money(p.proposalCost))"
                       + " · P&L \(signed(p.profit)) (cash \(signed(p.cashProfit))) · effect \(Fmt.pct(p.effectScale, decimals: 0))")
        }
        return out
    }
}
