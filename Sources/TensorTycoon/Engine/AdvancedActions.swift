import Foundation

// MARK: - 3.5: Advanced Projects — player actions

extension GameState {
    /// Employees in a role who work for the company: people seconded to a government programme work for the programme
    /// (and the contract pays for them), so they don't count toward MFU, safety, research and the rest while they're on it.
    func staff(_ role: Role) -> [Employee] {
        let away = Stars.away(self)   // 3.9: stars on sabbatical
        return advanced.seconded.isEmpty && away.isEmpty ? employees.filter { $0.role == role }
            : employees.filter { $0.role == role && !advanced.seconded.contains($0.id) && !away.contains($0.id) }
    }

    /// The same as a skill-weighted head count (a skill-50 employee counts as one).
    func workforce(_ role: Role) -> Double { staff(role).reduce(0.0) { $0 + $1.weight } }

    /// Submit a proposal. `price` is the share of the ceiling you bid (fixed-price, grant) or your fee rate (cost-plus).
    mutating func submitProposal(_ id: String, price: Double) -> String? {
        guard let i = advanced.solicitations.firstIndex(where: { $0.id == id }) else { return "That solicitation has closed." }
        let sol = advanced.solicitations[i]
        guard sol.bid == nil else { return "You've already bid." }
        guard sol.closes > date else { return "Bidding has closed." }
        let clamped = AdvancedProjects.clampPrice(sol.type, price)
        let o = AdvancedProjects.odds(sol, self, price: clamped)
        if let b = o.blockers.first { return b + "." }
        let cost = AdvancedProjects.proposalCost(sol)
        guard cash >= cost else { return "Writing the proposal costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.costOther += cost
        advanced.engaged = true
        advanced.solicitations[i].bid = ProposalBid(price: clamped, submitted: date, proposalCost: cost, odds: o.p)
        return nil
    }

    /// Take a bid back before the award. The proposal cost is spent either way (3.9: the view confirms first).
    mutating func withdrawProposal(_ id: String) -> String? {
        guard let i = advanced.solicitations.firstIndex(where: { $0.id == id }) else { return "That solicitation has closed." }
        guard advanced.solicitations[i].bid != nil else { return "You have no bid in on it." }
        advanced.solicitations[i].bid = nil
        return nil
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
        var short: [String] = []
        var blocked: String? = nil   // 3.9: the first refusal (no free desk, usually), so a gap says why
        for (k, n) in sol.staff.sorted(by: { $0.key < $1.key }) {
            guard let role = Role(rawValue: k) else { continue }
            var have = employees.filter { advanced.programmes[i].staff.contains($0.id) && $0.role == role }.count
            guard have < n else { continue }
            // Best people first, but those paid within the allowable-compensation cap before the stars the contract won't fully pay for.
            let cap = Macro.salary(role, year) * 1.5
            let pool = employees.filter { $0.role == role && !advanced.seconded.contains($0.id) && AdvancedProjects.clearanceLevel(self, $0.id) >= sol.classification }
                .sorted { ($0.salary > cap ? 1 : 0, -$0.skill, $0.id.uuidString) < ($1.salary > cap ? 1 : 0, -$1.skill, $1.id.uuidString) }
            for e in pool.prefix(n - have) {
                if let why = assignToProgramme(pid, employee: e.id, on: true) { blocked = blocked ?? why } else { added += 1; have += 1 }
            }
            if have < n { short.append("\(n - have) \(n - have == 1 ? role.title.lowercased() : role.plural.lowercased())") }
        }
        if sol.level > .unclassified && advanced.programmes[i].compute < sol.computeH100e {
            let free = AdvancedProjects.freeCompute(self, sol.level, excluding: pid)
            advanced.programmes[i].compute = min(sol.computeH100e, free)
        }
        guard !short.isEmpty else { return nil }
        // 3.9: say what's still missing and why, instead of "Team assigned" over a half-empty team or blaming staff for a desk shortage.
        let why = blocked.map { $0.prefix(1).lowercased() + $0.dropFirst() }
            ?? (sol.level > .unclassified ? "nobody else in those roles is free and cleared \(sol.level.clearance). Hire, or start clearances." : "nobody else in those roles is free. Hire more staff.")
        return "\(added > 0 ? "Assigned \(added); still" : "Still") short of \(short.joined(separator: ", ")): \(why)"
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

    /// Second an agent swarm to a programme (unclassified and CUI work only). While it's on the programme it works for the
    /// programme alone: no research points, labour revenue or other mission output.
    mutating func setProgrammeSwarm(_ pid: UUID, _ swarm: UUID?) -> String? {
        guard let i = advanced.programmes.firstIndex(where: { $0.id == pid }), advanced.programmes[i].status == .active else { return "That programme isn't active." }
        if let swarm {
            guard advanced.programmes[i].sol.level.agentsAllowed else { return "Agents aren't allowed on \(advanced.programmes[i].sol.level.title) networks." }
            guard let sw = swarms.first(where: { $0.id == swarm }) else { return "That swarm is gone." }
            if let oid = sw.orgID, orgs.contains(where: { $0.id == oid }) { return "\(sw.name) works inside an organisation: take it out first." }
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
        var short: [String] = []
        for (k, n) in p.sol.staff.sorted(by: { $0.key < $1.key }) {   // fixed order: who gets put forward depends on it
            guard let role = Role(rawValue: k) else { continue }
            started += clearPeople(role, n, level: p.sol.classification, for: p)
            let gap = clearanceGap(role, n, level: p.sol.classification, for: p)
            if gap > 0 { short.append("\(gap) \(gap == 1 ? role.title.lowercased() : role.plural.lowercased())") }
        }
        guard started == 0 else { return nil }
        // 3.9: say whether the team is covered or who's missing, instead of one message for both.
        if short.isEmpty { return "Everyone this programme needs is already cleared or under investigation." }
        if let why = Progression.blocker(self, .classified) { return why }
        let cost = AdvancedProjects.clearanceCost(p.sol.classification, year)
        if cash < cost { return "An investigation costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        return "No one else free to put forward. Hire \(short.joined(separator: ", ")) (people on other programmes don't count)."
    }

    /// People in a role who could join `programme`: everyone not seconded elsewhere (all staff when it's nil).
    private func clearanceCandidates(_ role: Role, for programme: Programme?) -> [Employee] {
        employees.filter { e in
            e.role == role && (programme == nil || !advanced.seconded.contains(e.id) || programme!.staff.contains(e.id))
        }
    }

    /// How many more people in a role need a clearance at `level` (held or under investigation) to reach `n`.
    private func clearanceGap(_ role: Role, _ n: Int, level: Int, for programme: Programme?) -> Int {
        let pending = Set(advanced.clearances.filter { $0.ready != nil && $0.target >= level }.map(\.employee))
        let ok = clearanceCandidates(role, for: programme).filter { e in AdvancedProjects.clearanceLevel(self, e.id) >= level || pending.contains(e.id) }.count
        return max(0, n - ok)
    }

    /// Put forward the best people in a role until `n` hold (or are being investigated for) a clearance at `level`.
    /// With `programme`, people seconded to another programme don't count and aren't put forward (3.9: matches the plan).
    /// Returns the number of investigations started.
    @discardableResult
    mutating func clearPeople(_ role: Role, _ n: Int, level: Int, for programme: Programme? = nil) -> Int {
        let need = clearanceGap(role, n, level: level, for: programme)
        guard need > 0 else { return 0 }
        let pool = clearanceCandidates(role, for: programme).filter { e in
            AdvancedProjects.clearanceLevel(self, e.id) < level
                && !(advanced.clearances.first { $0.employee == e.id }.map { $0.ready != nil || ($0.deniedAt > 0 && $0.deniedAt <= level) } ?? false)
        }.sorted { ($0.skill, $1.id.uuidString) > ($1.skill, $0.id.uuidString) }
        var started = 0
        for e in pool.prefix(need) where requestClearance(e.id, level: level) == nil { started += 1 }
        return started
    }

    /// Build a classified facility. `site` is a datacenter, colocation or other site — or, for a confidential science
    /// annex, the science lab it's added to.
    mutating func buildFacility(_ kind: FacilityKind, level: Int, capacity: Double, site: UUID) -> String? {
        let level = clamp(level, 1, 3)
        if let why = Progression.blocker(self, .classified) { return why }   // 3.8: Frontier Lab
        let q = AdvancedProjects.quote(kind, level: level, capacity: capacity, year)
        if let b = AdvancedProjects.facilityBlockers(kind, level: level, self).first { return "It needs \(b.prefix(1).lowercased() + b.dropFirst())." }
        var siteID: UUID? = site
        var labSite = ""
        var place = ""
        if kind == .confidentialScience {
            guard let lab = AdvancedProjects.labsFor(self, level: level).first(where: { $0.id == site }) else {
                return "Pick one of your science labs\(level >= 2 ? " in \(HQ.country(self).name)" : "")."
            }
            siteID = nil
            labSite = lab.site
            place = Science.city(Science.site(lab.site)).name
        } else {
            guard let st = sites.first(where: { $0.id == site }) else { return "That site is gone." }
            if let why = AdvancedProjects.sitingBlocker(st, level: level, self) { return why + "." }
            guard AdvancedProjects.sitesFor(kind, self, level: level).contains(where: { $0.id == site }) else { return "That site can't host a \(kind.title.lowercased())." }
            // Inside a datacenter or colocation site the facility's power comes out of the site's envelope.
            if q.kw > 0 && (kind.isCompute || st.kind == .datacenter || st.kind == .colo) {
                let free = st.capacityKW - Economy.siteLoadKW(self, st.id)
                guard free >= q.kw else { return "\(st.name) has \(Fmt.watts(max(0, free) * 1000)) free; the \(kind.short) needs \(Fmt.watts(q.kw * 1000))." }
            }
            place = st.name
        }
        guard cash >= q.capex else { return "It costs \(Fmt.money(q.capex))." }
        cash -= q.capex
        month.capex += q.capex
        advanced.engaged = true
        let n = advanced.facilities.filter { $0.kind == kind }.count + 1
        var f = SecureFacility(name: "\(place) \(kind.nameSuffix) \(n)", kind: kind, level: level, siteID: siteID, capacity: capacity, started: date,
                               ready: GameCalendar.addDays(date, Int(q.months * 30.4)), capex: q.capex, opex: q.opex)
        f.kw = q.kw
        f.labSite = labSite
        advanced.facilities.append(f)
        return nil
    }

    /// Close a facility; programmes using it lose their compute, desks or bay. A finished one refunds nothing; one still
    /// being built returns half of the unbuilt share of its cost (3.9). Returns the refund.
    @discardableResult
    mutating func closeFacility(_ id: UUID) -> Double {
        let refund = advanced.facilities.first { $0.id == id }.map { AdvancedProjects.closeRefund(self, $0) } ?? 0
        advanced.facilities.removeAll { $0.id == id }
        AdvancedProjects.clampCompute(&self)
        if refund > 0 {
            cash += refund
            month.capex -= refund
        }
        return refund
    }

    /// Hand a programme back. On a contract it counts as default (with the repayments its terms set out); a grant or prize
    /// lapses. Unfinished classified work leaves nothing you may use.
    mutating func abandonProgramme(_ pid: UUID) {
        guard let i = advanced.programmes.firstIndex(where: { $0.id == pid }), advanced.programmes[i].status == .active else { return }
        let lapse = advanced.programmes[i].sol.type == .grant || advanced.programmes[i].sol.type == .prize
        AdvancedProjects.terminate(&self, i, lapse ? .lapsed : .terminated, "you walked away from it")
        AdvancedProjects.syncSeconded(&self)
    }
}

// MARK: - 3.9: what closing a facility costs

extension AdvancedProjects {
    /// Cash back for closing a facility: half the share of its build cost not yet spent, while it's still being built.
    static func closeRefund(_ s: GameState, _ f: SecureFacility) -> Double {
        guard !f.isReady(s.date) else { return 0 }
        let total = f.ready.timeIntervalSince(f.started), left = f.ready.timeIntervalSince(s.date)
        return total > 0 ? f.capex * 0.5 * clamp(left / total, 0, 1) : 0
    }

    /// The confirmation text for closing a facility: the money lost and the active programmes that lose compute, desks or their bay.
    static func closeWarning(_ s: GameState, _ id: UUID) -> String {
        guard let f = s.advanced.facilities.first(where: { $0.id == id }) else { return "" }
        let refund = closeRefund(s, f)
        var out = refund > 0
            ? "It's still being built: \(Fmt.money(refund)) of the \(Fmt.money(f.capex)) build cost comes back, the rest is lost."
            : "The \(Fmt.money(f.capex)) build cost is not refunded."
        var after = s
        after.advanced.facilities.removeAll { $0.id == id }
        clampCompute(&after)
        var hit: [String] = []
        for p in s.advanced.programmes where p.status == .active {
            guard let q = after.advanced.programmes.first(where: { $0.id == p.id }) else { continue }
            var lose: [String] = []
            if q.compute < p.compute - 0.5 { lose.append("\(Fmt.int(Int(p.compute - q.compute))) H100e of compute") }
            if p.sol.level > .unclassified && !p.staff.isEmpty {
                let L = p.sol.classification
                let before = seatsAssigned(s, atLeast: L) - seatCapacity(s, atLeast: L)
                let now = seatsAssigned(after, atLeast: L) - seatCapacity(after, atLeast: L)
                if now > max(0, before) { lose.append("desks for \(Fmt.int(Int(now - max(0, before)))) staff") }
            }
            if p.template?.facility == f.kind && hasSpace(s, p) && !hasSpace(after, p) { lose.append("its \(f.kind.short.lowercased())") }
            if !lose.isEmpty { hit.append("\(p.sol.title) loses \(lose.joined(separator: " and "))") }
        }
        if !hit.isEmpty { out += " " + hit.joined(separator: "; ") + ". Work slows, and a programme far behind schedule can get a cure notice." }
        return out
    }
}

// MARK: - Playtest bot policy and economics report

extension AdvancedProjects {
    /// A simple policy for the playtest bot (flag `advproj`): one unclassified programme at a time, bid at 95% of the
    /// ceiling (8% fee on cost-plus), staff it with whoever fits, and keep going. With `classified` as well, it also gets
    /// ready for Secret work (`botPrepareClassified`) and runs one classified programme at a time alongside.
    static func botAct(_ s: inout GameState, classified: Bool = false) {
        let active = s.advanced.programmes.filter { $0.status == .active }
        for p in active {
            if p.sol.level > .unclassified {
                _ = s.clearTeamFor(p.id)
                botMobilise(&s, p)
            }
            _ = s.autoStaffProgramme(p.id)
        }
        if classified { botPrepareClassified(&s) }
        let pending = s.advanced.solicitations.filter { $0.bid != nil }
        let openLevels: [Bool] = [false, true].filter { secret in
            let busy = active.contains { ($0.sol.level >= .controlled) == secret } || pending.contains { ($0.level >= .controlled) == secret }
            return !busy && (!secret || classified)
        }
        guard !openLevels.isEmpty else { return }
        var best: (id: String, price: Double, score: Double)? = nil
        for sol in s.advanced.solicitations where sol.bid == nil && sol.closes > s.date && sol.type != .prize
            && openLevels.contains(sol.level >= .controlled)
            && (sol.templateDef?.facility.map { facilityFree(s, $0, level: sol.level) >= 1 } ?? true) {
            let price = sol.type == .costPlus ? 0.08 : 0.95
            let o = odds(sol, s, price: price)
            guard o.p >= 0.25, s.cash > 20 * proposalCost(sol) else { continue }
            if sol.level == .unclassified { guard staffReadiness(sol, s) >= 0.6 else { continue } }
            else {
                // Seconded people stop working for the company: take on classified work only if it leaves two thirds of
                // every role at home, and the facilities it still needs are cheap next to the cash pile.
                let roomy = sol.staff.allSatisfy { k, n in s.employees.filter { $0.role.rawValue == k }.count >= 3 * n }
                guard roomy, !o.plan.tight, o.plan.cost < s.cash * 0.05 else { continue }
            }
            let score = o.p * sol.ceiling
            if best == nil || score > best!.score { best = (sol.id, price, score) }
        }
        guard let pick = best else { return }
        _ = s.submitProposal(pick.id, price: pick.price)
    }

    /// The bot's road to Secret work, a step a month while it can afford it: raise weight security to SL3, clear a core
    /// team (and a security officer) to Secret, lease colocation at home if it has no suitable site, and build a small
    /// Secret secure lab and a restricted compute centre. It waits until all of it costs under 15% of its cash.
    static func botPrepareClassified(_ s: inout GameState) {
        guard s.year >= 2019, eligibleForSecret(s) else { return }
        let lab = quote(.secureLab, level: 2, capacity: 12, s.year)
        let computeSize = sizes(.restrictedCompute, s.year)[0]
        let centre = quote(.restrictedCompute, level: 2, capacity: computeSize, s.year)
        guard lab.capex + centre.capex < s.cash * 0.15 else { return }
        if s.security < .sl3, s.securityTarget <= s.security.rawValue, let next = SecurityLevel(rawValue: s.security.rawValue + 1),
           SecurityOps.upgradeCost(next, s) < s.cash * 0.1 {
            _ = s.upgradeSecurity()
        }
        // A core team cleared to Secret.
        for (role, n) in [(Role.researcher, 3), (.mlEngineer, 3), (.infra, 2), (.safety, 1), (.data, 1)] { s.clearPeople(role, n, level: 2) }
        let facilities = s.advanced.facilities
        if !facilities.contains(where: { $0.kind == .secureLab && $0.level >= 2 }) {
            if let site = sitesFor(.secureLab, s, level: 2).first { _ = s.buildFacility(.secureLab, level: 2, capacity: 12, site: site.id) }
        }
        if !facilities.contains(where: { $0.kind.isCompute && $0.level >= 2 }) {
            if let site = sitesFor(.restrictedCompute, s, level: 2).first(where: { $0.capacityKW - Economy.siteLoadKW(s, $0.id) >= centre.kw }) {
                _ = s.buildFacility(.restrictedCompute, level: 2, capacity: computeSize, site: site.id)
            } else if !s.sites.contains(where: { $0.kind == .colo && $0.name.hasSuffix("cleared colocation") }) {
                let loc = HQ.country(s).id == "us" ? "nova" : HQ.country(s).homeLocation
                _ = s.buildSite(kind: .colo, locationID: loc, capacityKW: (centre.kw * 1.25 / 50).rounded(.up) * 50, cooling: .air, power: .grid,
                                name: "\(s.companyName) cleared colocation")
            }
        }
    }

    /// The bot gives a classified programme what its mobilisation plan says is missing: desks in a secure lab and cleared
    /// compute at its level (leasing colocation at home when no site has the power).
    static func botMobilise(_ s: inout GameState, _ p: Programme) {
        let level = p.sol.level, L = p.sol.classification
        let building = s.advanced.facilities.filter { !$0.isReady(s.date) && $0.level >= L }
        let seats = freeSeats(s, level, excluding: p.id) + building.filter { $0.kind == .secureLab }.reduce(0) { $0 + $1.capacity }
        if seats < Double(p.sol.staffTotal), let site = sitesFor(.secureLab, s, level: L).first {
            let size = sizes(.secureLab, s.year).first { $0 >= Double(p.sol.staffTotal) - seats } ?? 120
            _ = s.buildFacility(.secureLab, level: L, capacity: size, site: site.id)
        }
        let compute = freeCompute(s, level, excluding: p.id) + building.filter(\.kind.isCompute).reduce(0) { $0 + $1.capacity }
        let short = p.sol.computeH100e - compute
        guard short > 0 else { return }
        let size = max(32, (short / 32).rounded(.up) * 32)
        let q = quote(.restrictedCompute, level: L, capacity: size, s.year)
        guard q.capex < s.cash * 0.3 else { return }
        if let site = sitesFor(.restrictedCompute, s, level: L).first(where: { $0.capacityKW - Economy.siteLoadKW(s, $0.id) >= q.kw }) {
            _ = s.buildFacility(.restrictedCompute, level: L, capacity: size, site: site.id)
        } else if !s.sites.contains(where: { $0.kind == .colo && $0.name.contains("cleared colocation") && !$0.isReady(s.date) }) {
            let loc = HQ.country(s).id == "us" ? "nova" : HQ.country(s).homeLocation
            let n = s.sites.filter { $0.name.contains("cleared colocation") }.count + 1
            _ = s.buildSite(kind: .colo, locationID: loc, capacityKW: (q.kw * 1.2 / 50).rounded(.up) * 50, cooling: .air, power: .grid,
                            name: "\(s.companyName) cleared colocation \(n)")
        }
    }

    /// The bot's answer to a classified discovery: retain it for internal use (the option with code 5), else keep it classified.
    static func botSecrecyChoice(_ d: Decision) -> Int {
        let parts = d.ref.split(separator: "|")
        let codes = parts.count > 1 ? parts[1].split(separator: ",").compactMap { Int($0) } : [0, 1, 2, 3, 4, 5]
        return codes.firstIndex(of: 5) ?? 0
    }

    /// Whether any agency's Secret work is open to your headquarters.
    static func eligibleForSecret(_ s: GameState) -> Bool {
        AgencyCatalog.all.contains { eligible(home: homeRegion(s), country: homeCountry(s), agency: $0, level: .secret) }
    }

    /// One line per contract: what it was, how it went and its P&L; then P&L by contract type and rivals' contracts.
    static func report(_ s: GameState) -> [String] {
        var out = ["Advanced Projects: \(s.advanced.bids.count) bids decided (\(s.advanced.bids.filter(\.won).count) won), \(s.advanced.programmes.count) programmes"]
        for b in s.advanced.bids.reversed() {
            out.append("  bid \(b.date.gameShort) \(b.title) (\(b.agency)) odds \(Fmt.pct(b.odds, decimals: 0)) → \(b.won ? "WON" : "lost to \(b.winner)")")
        }
        for p in s.advanced.programmes {
            out.append("  \(p.sol.title) [\(p.template?.topic ?? ""), \(p.sol.type.short), \(p.sol.level.short), \(p.sol.agencyDef?.short ?? "")] \(p.awarded.gameShort) → \(p.status.title)"
                       + " at \(p.stage.title) after \(p.months)/\(p.sol.months) mo, \(p.reworks) reworks · value \(Fmt.money(p.value)) · revenue \(Fmt.money(p.revenue))"
                       + " · direct \(Fmt.money(p.direct)) · allocated \(Fmt.money(p.allocated)) · bid \(Fmt.money(p.proposalCost))"
                       + " · P&L \(signed(p.profit)) (cash \(signed(p.cashProfit))) · growth \(AdvancedProjects.signedPct(p.growth - 1)) · effect \(Fmt.pct(p.effectScale, decimals: 0))"
                       + (p.secrecy == .none ? "" : " · \(p.secrecy.title)"))
        }
        for t in ContractType.allCases {
            let done = s.advanced.programmes.filter { $0.sol.type == t && $0.status != .active }
            guard !done.isEmpty else { continue }
            let full = done.reduce(0) { $0 + $1.profit }, cash = done.reduce(0) { $0 + $1.cashProfit }, value = done.reduce(0) { $0 + $1.value }
            out.append("  P&L \(t.short): \(done.count) finished · value \(Fmt.money(value)) · full-cost \(signed(full)) (\(Fmt.pct(value > 0 ? full / value : 0, decimals: 0)) of value) · cash \(signed(cash))")
        }
        let rivals = s.advanced.rivalProgrammes
        if !rivals.isEmpty {
            let done = rivals.filter { $0.status == "completed" }.count, failed = rivals.filter { $0.status == "terminated" }.count
            out.append("  Rival contracts: \(rivals.count) (\(rivals.filter(\.active).count) running, \(done) delivered, \(failed) terminated) · paid \(Fmt.money(rivals.reduce(0) { $0 + $1.paid }))")
        }
        if !s.advanced.facilities.isEmpty {
            out.append("  Facilities: " + s.advanced.facilities.map { "\($0.name) (\(facilityLevelName($0.level)), \(Fmt.int(Int($0.capacity))) \($0.kind.unit)\($0.suspension.isEmpty ? "" : ", suspended"))" }.joined(separator: "; "))
        }
        if !s.advanced.clearances.isEmpty {
            out.append("  Clearances: \(s.advanced.clearances.filter { $0.level >= 2 }.count) Secret+, \(s.advanced.clearances.filter { $0.level == 1 }.count) CUI · premium \(Fmt.money(s.advanced.lastPremium))/mo")
        }
        return out
    }
}
