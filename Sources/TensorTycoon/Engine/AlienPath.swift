import Foundation

/// 3.5: the alien-tech path as a timeline — search, tape-out, fab line, deploy, train, sell or license, next
/// generation — each with its status, an ETA, what's blocking it and the action that moves it on.
enum AlienPath {
    enum Status: String { case done, active, ready, blocked, locked }

    enum Action: Equatable {
        case swarms, tapeOut(UUID), expandFab, leaseCage(String), order(String), modelLab, chipSales, license(UUID), revise(UUID), study
    }

    struct Stage: Identifiable {
        let id: String
        let title: String
        let symbol: String
        var status: Status
        var detail: String
        var eta: Date? = nil
        var blocker: String? = nil
        var action: Action? = nil
        var actionTitle: String? = nil
        /// 0–1 for stages under way.
        var progress: Double? = nil
    }

    static func eta(_ s: GameState, days: Double) -> Date? {
        guard days.isFinite, days >= 0, days < 365 * 30 else { return nil }
        return GameCalendar.addDays(s.date, Int(days.rounded(.up)))
    }

    /// Why the alien search isn't producing insight, or nil if it is.
    static func searchBlocker(_ s: GameState) -> String? {
        if s.xenoInsightToday > 0 { return nil }
        let xenoSwarms = s.swarms.filter { $0.mission == .xeno }
        if xenoSwarms.contains(where: { !$0.paused && $0.missionDays == 0 }) { return nil }   // started today
        let rsi = s.rsiRuns.contains { $0.status == .running && $0.target == .architecture }
        if xenoSwarms.isEmpty && !rsi {
            return "No search running. Point an agent swarm running your best model at \"Alien architecture search\", or aim a self-improvement run at Architecture search."
        }
        if !xenoSwarms.isEmpty && xenoSwarms.allSatisfy(\.paused) && !rsi {
            if xenoSwarms.contains(where: { $0.chips < 1 }) { return "Your search swarm lost its chips. Retune it with free chips on the Agent Swarms page." }
            if xenoSwarms.contains(where: { sw in s.models.first { $0.id == sw.modelID }?.retired ?? true }) {
                return "Your search swarm's model was retired. Disband it and start one on your current best model."
            }
            return "Your search swarm is paused. Resume it on the Agent Swarms page."
        }
        return "Your searchers are too weak to find anything: only near-frontier agents (or a self-improving model at the frontier) see alien designs. Run the swarm on your best model."
    }

    static func stages(_ s: GameState) -> [Stage] {
        let b = s.bonuses
        var out: [Stage] = []
        let n = XenoScience.discoveries(s)
        let needed = XenoScience.insightNeeded(s)
        let rate = s.xenoInsightToday
        let left = max(0, needed - s.xenoInsight)

        // 1. Search
        var search = Stage(id: "search", title: n == 0 ? "Find an alien architecture" : "Keep searching", symbol: "scope",
                           status: n == 0 ? .active : .done,
                           detail: "\(Fmt.count(s.xenoInsight)) of \(Fmt.count(needed)) insight for discovery #\(n + 1) (\(XenoScience.nextKind(s).title.lowercased()))\(rate > 0 ? " · \(Fmt.trim(rate, 1))/day" : "")",
                           progress: s.xenoInsight / max(1, needed))
        if rate > 0 { search.eta = eta(s, days: left / rate) }
        if let why = searchBlocker(s) {
            if n == 0 { search.status = .blocked }
            search.blocker = why
            search.action = .swarms
            search.actionTitle = "Agent Swarms"
        }
        out.append(search)

        let arch = s.alienArchs.last { $0.chipID == nil } ?? s.alienArchs.max { $0.chipPerf < $1.chipPerf }
        let haveChip = s.customChips.contains(where: \.alien)

        // 2. Tape-out
        var tape = Stage(id: "tapeout", title: "Tape out the chip", symbol: "cpu", status: .locked, detail: "Needs an architecture first.")
        if let fabbing = s.alienArchs.first(where: \.fabbing) {
            let total = max(fabbing.fabTotal, fabbing.fabDaysLeft, 1)
            let p = clamp(1 - fabbing.fabDaysLeft / total, 0, 1)
            let phase = p < 0.35 ? "Masks and tape-out" : (p < 0.7 ? "First silicon" : (p < 0.9 ? "Bring-up" : "Volume ramp"))
            tape.status = .active
            tape.detail = "\(fabbing.name) v1 · \(phase)\(fabbing.fabRespins > 0 ? " · \(fabbing.fabRespins) respin\(fabbing.fabRespins == 1 ? "" : "s")" : "")"
            tape.eta = eta(s, days: fabbing.fabDaysLeft)
            tape.progress = p
        } else if let a = arch, a.chipID == nil {
            let cost = Xeno.fabCost(s)
            tape.status = cost > s.cash ? .blocked : .ready
            tape.detail = "\(a.name): \(Fmt.money(cost)), about \(Int(Xeno.fabDays(s, b) / 30) + 1) months. Respins get likelier the less of it you understand."
            tape.blocker = cost > s.cash ? "Needs \(Fmt.money(cost)) in cash (you have \(Fmt.money(s.cash)))." : nil
            tape.action = .tapeOut(a.id)
            tape.actionTitle = "Tape out"
        } else if haveChip {
            tape.status = .done
            let chips = s.customChips.filter(\.alien)
            tape.detail = "\(chips.count) alien chip\(chips.count == 1 ? "" : "s") in production: \(chips.map(\.name).suffix(3).joined(separator: ", "))"
        }
        out.append(tape)

        // 3. Fab line
        var fab = Stage(id: "fab", title: "Your alien fab line", symbol: "building.2.crop.circle", status: .locked,
                        detail: "Opens with your first alien chip: a pilot line making \(Fmt.count(AlienFab.pilotCapacity)) chips a month.")
        if s.alienFab.exists {
            fab.status = .done
            let q = AlienFab.queueDays(s)
            fab.detail = "\(Fmt.count(s.alienFab.capacityMonth)) chips/month · \(q > 0.5 ? "your orders fill it for \(Fmt.days(q))" : "idle for your orders") · \(Fmt.count(s.alienFab.produced)) made"
            if s.alienFab.pendingCapacity > 0, let r = s.alienFab.pendingReady {
                fab.status = .active
                fab.detail += " · +\(Fmt.count(s.alienFab.pendingCapacity))/month ramping"
                fab.eta = r
            } else {
                fab.action = .expandFab
                fab.actionTitle = "Expand"
            }
        }
        out.append(fab)

        // 4. Deploy
        let best = s.customChips.filter(\.alien).max { $0.bf16 < $1.bf16 }
        let ownedAlien = s.owned.filter { AlienFab.isAlienChip($0.accelID) }.reduce(0) { $0 + $1.count }
        let onOrder = s.orders.filter { AlienFab.isAlienChip($0.accelID) }
        var deploy = Stage(id: "deploy", title: "Install alien chips", symbol: "server.rack", status: .locked, detail: "Waiting for a chip.")
        if let chip = best, let a = HardwareCatalog.get(chip.id) {
            let (site, fits) = s.bestSite(for: a, count: 1)
            deploy.detail = "\(Fmt.int(ownedAlien)) installed\(onOrder.isEmpty ? "" : " · \(Fmt.int(onOrder.reduce(0) { $0 + $1.count })) on order") · \(Fmt.watts(Economy.chipKW(a) * 1000)) each, air-cooled"
            if let next = onOrder.map(\.arrives).min() { deploy.eta = next }
            if site == nil || fits < 1 {
                deploy.status = ownedAlien > 0 ? .done : .blocked
                deploy.blocker = site == nil ? "None of your sites can take \(Int(a.tdpW)) W parts (a garage or office can't). Lease a colocation cage — ready in 30 days."
                                             : "No free power at your sites for more alien chips. Lease a cage or add capacity on Datacenters & Power."
                deploy.action = .leaseCage(chip.id)
                deploy.actionTitle = "Lease a cage"
            } else {
                deploy.status = ownedAlien > 0 ? .done : (onOrder.isEmpty ? .ready : .active)
                deploy.detail += " · room for \(Fmt.int(fits)) more at \(site!.name)"
                deploy.action = .order(chip.id)
                deploy.actionTitle = "Order"
            }
        }
        out.append(deploy)

        // 5. Train
        var train = Stage(id: "train", title: "Train on alien silicon", symbol: "brain", status: .locked, detail: "Needs installed alien chips.")
        let running = s.runs.filter { AlienFab.isAlienChip($0.design.accelID) && ($0.status == .running || $0.status == .postTraining || $0.status == .paused) }
        let trained = s.models.filter { AlienFab.isAlienChip($0.design.accelID) }
        if let r = running.first {
            train.status = r.status == .paused ? .blocked : .active
            train.detail = "\(r.design.name) on \(Fmt.int(r.design.chips)) alien chips\(r.design.mixer == .alien ? " with the alien architecture" : "") · \(Int(r.progress * 100))%"
            train.progress = r.progress
            if r.status == .paused {
                train.blocker = "Paused: it lost chips it needs. It resumes by itself once at least half its \(Fmt.int(r.design.chips)) chips are free — order more alien chips or free some up."
                train.action = .order(r.design.accelID)
                train.actionTitle = "Order chips"
            }
            if r.status != .paused {
                train.action = .modelLab
                train.actionTitle = "Model Lab"
            }
        } else if !trained.isEmpty {
            train.status = .done
            train.detail = "\(trained.count) model\(trained.count == 1 ? "" : "s") trained on alien chips; best c \(Fmt.trim(trained.map(\.c).max() ?? 0, 2))"
            train.action = .modelLab
            train.actionTitle = "Model Lab"
        } else if ownedAlien > 0 {
            train.status = .ready
            train.detail = "Pick your alien chip as hardware and \"Alien (xeno)\" as the architecture in the Model Lab: ×\(Fmt.trim(Xeno.best(s)?.multiplier ?? 1, 1)) effective compute on chips that cost a few percent of a GPU."
            train.action = .modelLab
            train.actionTitle = "Model Lab"
        } else if !onOrder.isEmpty {
            train.status = .locked
            train.detail = "First alien chips arrive \(onOrder.map(\.arrives).min()!.gameShort)."
        }
        out.append(train)

        // 6. Sell or license
        var sell = Stage(id: "sell", title: "Sell chips or license the blueprint", symbol: "shippingbox", status: .locked, detail: "Optional. Needs a chip (to sell) or offers (to license).")
        let lines = s.chipLines.filter { AlienFab.isAlienChip($0.chipID) }
        let licenses = s.alienArchs.flatMap(\.licenses)
        let offers = s.alienArchs.reduce(0) { $0 + $1.offers.count }
        if !lines.isEmpty || !licenses.isEmpty || offers > 0 {
            let shipped = lines.reduce(0) { $0 + $1.shipped }
            let perDay = lines.reduce(0) { $0 + $1.unitsToday }
            var bits: [String] = []
            if !lines.isEmpty { bits.append("\(Fmt.count(shipped)) chips sold (\(Fmt.count(perDay * 30.4))/month)") }
            if !licenses.isEmpty { bits.append("\(licenses.count) license\(licenses.count == 1 ? "" : "s")") }
            if offers > 0 { bits.append("\(offers) offer\(offers == 1 ? "" : "s") waiting") }
            sell.detail = bits.joined(separator: " · ")
            sell.status = shipped > 0 || !licenses.isEmpty ? .done : .active
            if lines.contains(where: \.active) && perDay < 0.01 && s.alienFab.capacityMonth <= 0 {
                sell.blocker = "Your fab line has no capacity for customers. Expand it."
            } else if lines.contains(where: \.active) && perDay < 0.01 && AlienFab.busy(s) && lines.allSatisfy({ $0.demandToday < 0.01 }) {
                sell.blocker = "Buyers aren't biting at this price. Lower it in Chip & Cloud Sales."
            }
            if offers > 0 { sell.detail += " — accept or decline them on the architecture's card below" }
            sell.action = .chipSales
            sell.actionTitle = "Chip & Cloud Sales"
        } else if haveChip || !s.alienArchs.isEmpty {
            sell.status = .ready
            sell.detail = "Keep it exclusive (investors price the moat), sell the chips at a markup, or license the blueprint for fees and royalties. Whoever buys gets stronger."
            sell.action = haveChip ? .chipSales : arch.map { .license($0.id) }
            sell.actionTitle = haveChip ? "Chip & Cloud Sales" : "Invite license offers"
        }
        out.append(sell)

        // 7. Next generation
        var next = Stage(id: "nextgen", title: "Next-generation chip", symbol: "arrow.up.right.circle", status: .locked,
                         detail: "v2 (\(Fmt.trim(AlienFab.perfLeap[2], 1))× v1) and v3 (\(Fmt.trim(AlienFab.perfLeap[3], 1))×) once v1 is in production.")
        if let r = s.alienArchs.first(where: \.revising) {
            next.status = .active
            next.detail = "\(r.name) v\(r.chipVersion + 1) in design\(r.reviseRespins > 0 ? " (respun)" : "")"
            next.eta = eta(s, days: r.reviseDaysLeft)
            next.progress = clamp(1 - r.reviseDaysLeft / max(1, r.reviseTotal), 0, 1)
        } else if let a = s.alienArchs.filter({ $0.chipVersion >= 1 && $0.chipVersion < AlienFab.maxVersion }).max(by: { $0.chipPerf < $1.chipPerf }) {
            let why = AlienFab.revisionBlocker(a, s)
            next.status = why == nil ? .ready : .blocked
            next.detail = "\(a.name) v\(a.chipVersion + 1): \(Fmt.trim(AlienFab.perfLeap[a.chipVersion + 1] / AlienFab.perfLeap[a.chipVersion], 1))× v\(a.chipVersion), \(Fmt.money(AlienFab.revisionCost(a, s))), about \(Int(AlienFab.revisionDays(a, s, b) / 30) + 1) months · respin risk \(Int(AlienFab.respinChance(a, s) * 100))% (legibility \(Int(Xeno.legibility(a, s) * 100))%)"
            next.blocker = why
            next.action = .revise(a.id)
            next.actionTitle = "Design v\(a.chipVersion + 1)"
        } else if s.alienArchs.contains(where: { $0.chipVersion >= AlienFab.maxVersion }) {
            next.status = .done
            next.detail = "Every chip is at v\(AlienFab.maxVersion). The next leap is a new architecture."
        }
        out.append(next)
        return out
    }

    /// The first stage that needs the player, for dashboards and briefings.
    static func nextStep(_ s: GameState) -> Stage? {
        let st = stages(s)
        return st.first { $0.status == .blocked } ?? st.first { $0.status == .ready && $0.id != "sell" && $0.id != "nextgen" }
    }
}
