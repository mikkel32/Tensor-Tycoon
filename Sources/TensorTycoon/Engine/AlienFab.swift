import Foundation

/// 3.5: the alien fab line and chip generations. Your first alien chip opens a pilot line that makes every alien
/// chip you own: your open orders share it and arrive as they're made (the first chips about two weeks after you
/// order, like any GPU), merchant customers get what's left, and you buy more capacity with money. Each architecture's chip can be revised
/// twice (v2, v3) for bigger leaps; chips nobody fully understands throw errata.
enum AlienFab {
    /// Chips a month the pilot line makes when it opens (3.8: was 20K, which turned big orders into decade-long waits).
    static let pilotCapacity = 100_000.0
    /// The biggest single order, in months of the line's output.
    static let maxOrderMonths = 6.0
    /// Packaging, burn-in and shipping after a chip leaves the line.
    static let shipDays = 14
    /// Chip revisions: performance, production cost and power vs v1 (index = version).
    static let perfLeap = [1.0, 1.0, 1.5, 2.2]
    static let costLeap = [1.0, 1.0, 0.75, 0.55]
    static let powerLeap = [1.0, 1.0, 0.85, 0.7]
    static let maxVersion = 3

    static func isAlienChip(_ id: String) -> Bool { id.hasPrefix("alien_") }

    // MARK: Capacity and queue

    static func activeMerchantLines(_ s: GameState) -> Int {
        s.chipLines.filter { $0.active && isAlienChip($0.chipID) }.count
    }

    /// Your own orders are being made.
    static func busy(_ s: GameState) -> Bool { s.orders.contains { isAlienChip($0.accelID) && $0.count > 0 } }

    /// Chips a day the line sets aside for merchant customers: a quarter at most, and only what they actually want
    /// (3.8: an idle sales line used to take 25% of the line for nothing).
    static func merchantReservePerDay(_ s: GameState) -> Double {
        let lines = s.chipLines.filter { $0.active && isAlienChip($0.chipID) }
        guard !lines.isEmpty else { return 0 }
        let want = lines.reduce(0.0) { acc, l in
            guard let chip = HardwareCatalog.get(l.chipID) else { return acc }
            return acc + ChipBusiness.demand(chip: chip, price: l.price, sellToRivals: l.sellToRivals, s)
        }
        return min(max(s.alienFab.capacityMonth, 1_000) / 30.4 * 0.25, want)
    }

    /// Chips a day the line makes for you (merchant customers take only what they're buying, up to a quarter).
    static func ownPerDay(_ s: GameState) -> Double {
        max(s.alienFab.capacityMonth, 1_000) / 30.4 - merchantReservePerDay(s)
    }

    /// Chips a day merchant customers can get (all of it when you're not making your own).
    static func merchantPerDay(_ s: GameState) -> Double {
        busy(s) ? merchantReservePerDay(s) : s.alienFab.capacityMonth / 30.4
    }

    /// One alien sales line's share of the merchant output.
    static func merchantPerLine(_ s: GameState) -> Double { merchantPerDay(s) / Double(max(1, activeMerchantLines(s))) }

    /// Chips still to be made for an order.
    static func toMake(_ o: HardwareOrder) -> Double { max(0, Double(o.count) - (o.made ?? 0)) }

    /// Days until the line finishes everything you've ordered.
    static func queueDays(_ s: GameState) -> Double {
        s.orders.filter { isAlienChip($0.accelID) }.reduce(0) { $0 + toMake($1) } / ownPerDay(s)
    }

    /// Days until each of `needs` is made when the line's output is shared evenly between unfinished orders.
    static func sharedFinishDays(_ needs: [Double], perDay: Double) -> [Double] {
        let order = needs.indices.sorted { needs[$0] < needs[$1] }
        var out = [Double](repeating: 0, count: needs.count)
        var t = 0.0, done = 0.0
        for (k, i) in order.enumerated() {
            t += (needs[i] - done) * Double(needs.count - k) / max(1, perDay)
            done = needs[i]
            out[i] = t
        }
        return out
    }

    /// Days from ordering `count` chips today to having all of them installed (the first ones come after `shipDays`).
    static func leadDays(_ s: GameState, count: Int) -> Int {
        let needs = s.orders.filter { isAlienChip($0.accelID) }.map(toMake) + [Double(count)]
        return max(shipDays, Int((sharedFinishDays(needs, perDay: ownPerDay(s)).last ?? 0).rounded(.up)) + 1)
    }

    /// Biggest order the line takes at once.
    static func maxOrder(_ s: GameState) -> Int { Int(max(s.alienFab.capacityMonth, pilotCapacity) * maxOrderMonths) }

    /// When an order's next chips reach you: shipDays after ordering for the first batch, then the next weekly
    /// ship day. (`arrives` is the "all delivered by" date, not this.)
    static func nextShipment(_ o: HardwareOrder, _ s: GameState) -> Date {
        let ready = GameCalendar.addDays(o.ordered, shipDays)
        if (o.delivered ?? 0) == 0 { return min(max(ready, s.date), max(o.arrives, s.date)) }
        var d = max(ready, GameCalendar.addDays(s.date, 1))
        for _ in 0..<7 where GameCalendar.components(d).day % 7 != 0 { d = GameCalendar.addDays(d, 1) }
        return min(d, max(o.arrives, GameCalendar.addDays(s.date, 1)))
    }

    /// Chips queued across all open orders: one order is capped by `maxOrder`, but repeated orders stretch everyone's wait.
    static func openBacklog(_ s: GameState) -> Int {
        Int(s.orders.filter { isAlienChip($0.accelID) }.reduce(0) { $0 + toMake($1) }.rounded(.up))
    }

    /// 3.8: the most the line holds in its queue at once (12 months of output). A backlog already past it stays,
    /// but blocks new orders until it falls under.
    static func maxBacklog(_ s: GameState) -> Int { Int(max(s.alienFab.capacityMonth, pilotCapacity) * 12) }

    /// How many more chips the line takes right now.
    static func backlogRoom(_ s: GameState) -> Int { max(0, maxBacklog(s) - openBacklog(s)) }

    /// Book an order on the line; returns days until all of it is delivered.
    static func book(_ s: inout GameState, count: Int) -> Int {
        if !s.alienFab.exists { openPilot(&s) }
        let days = leadDays(s, count: count)
        s.alienFab.busyUntil = GameCalendar.addDays(s.date, Int((queueDays(s) + Double(count) / ownPerDay(s)).rounded(.up)))
        return days
    }

    /// Today's output for you, shared evenly between your open orders so a small order never waits behind a big
    /// one. Chips ship from two weeks after the order was placed: the first batch right away, then weekly, and the
    /// rest the day the order completes.
    static func produce(_ s: inout GameState) {
        let idx = s.orders.indices.filter { isAlienChip(s.orders[$0].accelID) }
        guard !idx.isEmpty else {
            s.alienFab.busyUntil = nil
            return
        }
        var left = ownPerDay(s)
        var open = idx.filter { toMake(s.orders[$0]) > 0.0001 }
        while left > 0.0001 && !open.isEmpty {
            let share = left / Double(open.count)
            var next: [Int] = []
            for i in open {
                let take = min(toMake(s.orders[i]), share)
                s.orders[i].made = (s.orders[i].made ?? 0) + take
                s.alienFab.produced += take
                left -= take
                if toMake(s.orders[i]) > 0.0001 { next.append(i) }
            }
            open = next
        }

        let weekly = GameCalendar.components(s.date).day % 7 == 0
        var shipped: [String: Int] = [:]
        for i in idx where GameCalendar.daysBetween(s.orders[i].ordered, s.date) >= shipDays {
            let o = s.orders[i]
            let finished = toMake(o) <= 0.0001
            let n = finished ? o.count : Int(o.made ?? 0)
            // The first shipment goes as soon as it can; after that, weekly.
            guard n > 0, weekly || finished || (o.delivered ?? 0) == 0 else { continue }
            s.owned.append(OwnedBatch(accelID: o.accelID, count: n, siteID: o.siteID, purchased: s.date, unitCost: o.unitCost))
            s.orders[i].count -= n
            s.orders[i].made = max(0, (o.made ?? 0) - Double(n))
            s.orders[i].delivered = (o.delivered ?? 0) + n
            shipped[o.accelID, default: 0] += n
        }
        s.orders.removeAll { isAlienChip($0.accelID) && $0.count <= 0 }
        if !shipped.isEmpty {
            Sim.mergeOwned(&s)
            let text = shipped.sorted { $0.key < $1.key }.map { "\(Fmt.int($0.value))× \(HardwareCatalog.get($0.key)?.name ?? $0.key)" }.joined(separator: " · ")
            Sim.news(&s, "Delivered from your fab line: \(text)", "Racked and burned in. They're ready for work.", .company, image: "wafer", good: true)
        }

        // Keep each order's "all delivered by" date honest.
        let rest = s.orders.indices.filter { isAlienChip(s.orders[$0].accelID) }
        let finish = sharedFinishDays(rest.map { toMake(s.orders[$0]) }, perDay: ownPerDay(s))
        for (k, i) in rest.enumerated() {
            let shipAt = GameCalendar.addDays(s.orders[i].ordered, shipDays)
            s.orders[i].arrives = max(shipAt, GameCalendar.addDays(s.date, max(1, Int(finish[k].rounded(.up)) + 1)))
        }
        s.alienFab.busyUntil = rest.isEmpty ? nil : GameCalendar.addDays(s.date, Int(queueDays(s).rounded(.up)))
    }

    /// A sensible order: what fits at your sites, up to a third of your cash and two months of the line.
    static func suggestedOrder(_ chipID: String, _ s: GameState, ignoringSites: Bool = false) -> Int {
        guard let a = HardwareCatalog.get(chipID), let price = a.price, price > 0 else { return 0 }
        let cash = Int(max(0, s.cash) / 3 / price)
        let line = Int(max(s.alienFab.capacityMonth, pilotCapacity) * 2)
        var n = min(cash, line, backlogRoom(s))
        if !ignoringSites { n = min(n, s.bestSite(for: a, count: 1).fits) }
        return n >= 1_000 ? n / 100 * 100 : n
    }

    /// 3.9: the suggested order and, when it is zero, what stops it in the player's words: the line's queue, cash, or
    /// power at your sites (only then does a cage help).
    struct OrderAdvice {
        var count: Int
        var reason: String?
        var needsCage = false
        var queueFull = false
    }

    static func orderAdvice(_ chipID: String, _ s: GameState) -> OrderAdvice {
        guard let a = HardwareCatalog.get(chipID), let price = a.price, price > 0 else { return OrderAdvice(count: 0, reason: "That chip isn't in production yet.") }
        let n = suggestedOrder(chipID, s)
        if n >= 1 { return OrderAdvice(count: n) }
        if backlogRoom(s) < 1 {
            let days = Double(openBacklog(s) - maxBacklog(s) + 1) / max(1, ownPerDay(s))
            return OrderAdvice(count: 0, reason: "Fab queue full: \(Fmt.int(openBacklog(s))) chips are queued and the line holds twelve months (\(Fmt.int(maxBacklog(s)))). Room opens about \(GameCalendar.addDays(s.date, Int(days.rounded(.up)) + 1).gameShort) as chips ship, sooner if you expand the line.",
                               queueFull: true)
        }
        if s.cash < price * 3 { return OrderAdvice(count: 0, reason: "Not enough cash: one costs \(Fmt.money(price)) and orders are sized to a third of your cash.") }
        let (site, _) = s.bestSite(for: a, count: 1)
        return OrderAdvice(count: 0, reason: site == nil ? "None of your sites can take \(Int(a.tdpW)) W parts. Lease a cage for them." : "No free power at your sites for \(a.name). Lease a cage or add capacity.",
                           needsCage: true)
    }

    /// 3.9: the monthly fee of the cage `leaseAlienCage` would sign for `chips` of this chip.
    static func cageFee(_ chipID: String, chips: Int, _ s: GameState) -> Double {
        guard let a = HardwareCatalog.get(chipID), let loc = LocationCatalog.all.min(by: { $0.coloFee < $1.coloFee }) else { return 0 }
        let kw = clamp(Double(max(chips, 1)) * Economy.chipKW(a) * 1.05, 2_000, Campus.coloCapMW * 1_000).rounded()
        return loc.coloFee * kw * (a.liquid ? 1.35 : 1) * Science.coloFactor(s)
    }

    static func openPilot(_ s: inout GameState) {
        guard !s.alienFab.exists else { return }
        s.alienFab.capacityMonth = pilotCapacity
        s.alienFab.opened = s.date
        s.alienFab.migrated = true
    }

    /// Production cost of the cheapest alien chip you make (for pricing expansions).
    static func unitCost(_ s: GameState) -> Double {
        s.customChips.filter(\.alien).map(\.unitCost).min() ?? 5_000
    }

    /// Up-front cost of `units` more chips a month: tools, mask sets and packaging lines. A fraction of buying
    /// merchant foundry slots, because the agents design the line too.
    static func expansionCost(_ s: GameState, units: Double) -> Double {
        let refPrice = ChipBusiness.listPrice(Silicon.reference(s), s)
        return units * (refPrice * 0.2 + unitCost(s) * 3) + 5e7
    }

    static func expansionDays(_ s: GameState) -> Int {
        Int(75 * (XenoScience.megaDone(s, "xeno_foundry") ? 0.6 : 1) * (s.signatureAt(.forge, 5) ? 0.7 : 1))
    }

    /// Why the line can't expand right now, or nil.
    static func expansionBlocker(_ s: GameState, units: Double) -> String? {
        if !s.alienFab.exists { return "Your pilot line opens with your first alien chip, the day after an architecture is found." }
        if s.alienFab.pendingCapacity > 0 { return "An expansion is already ramping (online \(s.alienFab.pendingReady?.gameShort ?? "soon"))." }
        if units < 1_000 { return "Expand by at least 1,000 chips a month." }
        let cost = expansionCost(s, units: units)
        if cost > s.cash { return "Adding \(Fmt.count(units))/month costs \(Fmt.money(cost))." }
        return nil
    }

    // MARK: Chips and generations

    /// The chip an architecture yields at a given version, measured against today's best GPU.
    static func makeChip(_ arch: AlienArch, version v: Int, _ s: GameState) -> CustomChip {
        let v = clamp(v, 1, maxVersion)
        let ref = Silicon.reference(s)
        let perf = arch.chipPerf * perfLeap[v]
        let refPrice = ChipBusiness.listPrice(ref, s)
        let mem = ref.memoryGB * 1.5 * pow(1.4, Double(v - 1))
        return CustomChip(
            id: "alien_\(arch.id.uuidString.prefix(8))\(v > 1 ? "_v\(v)" : "")",
            name: "\(s.companyName.split(separator: " ").first ?? "Xeno") \(arch.name)\(v > 1 ? " v\(v)" : "")",
            focus: .training, available: s.date, process: Silicon.process(s.year),
            memoryGB: (mem / 8).rounded() * 8, memoryType: v > 1 ? "Folded SRAM lattice + \(ref.memoryType)" : "Stacked SRAM + \(ref.memoryType)",
            bandwidthTBs: ref.bandwidthTBs * max(1.5, perf * 0.8),
            bf16: ref.bf16 * perf, fp8: max(ref.fp8, ref.bf16 * 2) * perf, fp4: (ref.fp4 > 0 ? ref.fp4 : ref.bf16 * 4) * perf,
            tdpW: ref.tdpW * arch.powerFactor * powerLeap[v],
            unitCost: max(300, refPrice * arch.costFactor * costLeap[v] * XenoScience.alienChipCostFactor(s) * pow(0.85, Double(s.alienFab.yieldLevel))),
            decodeEff: 0.85 + 0.03 * Double(v - 1), scaleUp: 1_024 * v, generation: arch.generation, alien: true)
    }

    /// Masks, packaging and bring-up for a new chip version: $500M for v2, $1B for v3.
    static func revisionCost(_ a: AlienArch, _ s: GameState) -> Double { 2.5e8 * (a.chipVersion >= 2 ? 4 : 2) }

    /// Designing a revision takes longer the less of the architecture your people can follow.
    static func revisionDays(_ a: AlienArch, _ s: GameState, _ b: ResearchBonuses) -> Double {
        Xeno.fabDays(s, b) * (a.chipVersion >= 2 ? 1.2 : 1.0) * (1 + max(0, 0.6 - Xeno.legibility(a, s)))
    }

    /// Chance a finished revision needs one more spin.
    static func respinChance(_ a: AlienArch, _ s: GameState) -> Double {
        0.3 * (1 - Xeno.legibility(a, s)) * (1 - 0.5 * s.swarmSilicon)
    }

    static func revisionBlocker(_ a: AlienArch, _ s: GameState) -> String? {
        if a.chipVersion == 0 { return "v1 goes into production with the next day." }
        if a.chipVersion >= maxVersion { return "v\(maxVersion) is as far as this architecture goes. A new architecture is the next leap." }
        if a.revising { return "v\(a.chipVersion + 1) is already in design." }
        let cost = revisionCost(a, s)
        if cost > s.cash { return "Designing v\(a.chipVersion + 1) costs \(Fmt.money(cost))." }
        return nil
    }

    // MARK: Daily

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        if s.alienFab.pendingCapacity > 0, let ready = s.alienFab.pendingReady, ready <= s.date { capacityOnline(&s) }
        if s.alienFab.exists {
            produce(&s)
            s.alienFab.produced += s.chipLines.filter { isAlienChip($0.chipID) }.reduce(0) { $0 + $1.unitsToday }
            milestones(&s)
        }
        for i in s.alienArchs.indices where s.alienArchs[i].revising {
            s.alienArchs[i].reviseDaysLeft -= 1
            guard s.alienArchs[i].reviseDaysLeft <= 0 else { continue }
            let a = s.alienArchs[i]
            if a.reviseRespins < 1 && s.rng.chance(respinChance(a, s)) {
                s.alienArchs[i].reviseRespins += 1
                s.alienArchs[i].reviseDaysLeft = 45
                s.alienArchs[i].reviseTotal += 45
                Sim.news(&s, "\(a.name) v\(a.chipVersion + 1) needs a respin",
                         "First silicon boots, then computes something that isn't matrix multiplication. Nobody can say what — legibility \(Int(Xeno.legibility(a, s) * 100))%. Six more weeks.",
                         .hardware, image: "wafer", important: true, good: false)
                continue
            }
            finishRevision(&s, i)
        }
    }

    /// Chips lost from under a run on your own silicon (field failures, errata): shrink the run instead of pausing it,
    /// since there are no spares to rent. Runs that would no longer fit in memory are left for the normal pause.
    static func shrinkRuns(_ s: inout GameState, accel a: Accelerator, excess: inout Int) {
        let b = s.bonuses
        // 3.9: helper groups of this chip type give way first; the run carries on with its other groups.
        for ri in s.runs.indices where (s.runs[ri].status == .running || s.runs[ri].status == .postTraining) && excess > 0 {
            guard let hi = s.runs[ri].design.helpers.firstIndex(where: { $0.accelID == a.id }) else { continue }
            let cut = min(excess, s.runs[ri].design.helpers[hi].chips)
            s.runs[ri].design.helpers[hi].chips -= cut
            if s.runs[ri].design.helpers[hi].chips <= 0 { s.runs[ri].design.helpers.remove(at: hi) }
            s.runs[ri].note = "Lost \(Fmt.int(cut)) \(a.name) helper chips; carrying on with the rest of the cluster."
            excess -= cut
        }
        for ri in s.runs.indices where s.runs[ri].design.accelID == a.id && (s.runs[ri].status == .running || s.runs[ri].status == .postTraining) && excess > 0 {
            let cut = min(excess, s.runs[ri].design.chips - 1)
            guard cut > 0 else { continue }
            var d = s.runs[ri].design
            d.chips -= cut
            guard Physics.trainingMemory(d, accel: a, bonuses: b).ok else { continue }
            s.runs[ri].design.chips = d.chips
            s.runs[ri].note = "Lost \(Fmt.int(cut)) \(a.name) chips; carrying on with \(Fmt.int(d.chips))."
            excess -= cut
        }
    }

    /// Runs that stalled for lack of chips resume by themselves once chips are free again (shrunk to what's free if
    /// most of the cluster is back). 3.8: any vendor, not just your own silicon; a run you paused by hand stays paused.
    static func resumeRuns(_ s: inout GameState) {
        let stalled = s.runs.indices.filter {
            s.runs[$0].status == .paused && (s.runs[$0].note.hasPrefix("Paused: not enough") || (HardwareCatalog.get(s.runs[$0].design.accelID)?.vendor == .custom && !s.runs[$0].note.hasPrefix("Paused by you")))
        }
        guard !stalled.isEmpty else { return }
        let b = s.bonuses
        for ri in stalled {
            guard let a = HardwareCatalog.get(s.runs[ri].design.accelID) else { continue }
            let free = Economy.freeChips(s, a.id)
            let want = s.runs[ri].design.chips
            guard free >= max(1, want / 2) else { continue }
            var d = s.runs[ri].design
            d.chips = min(want, free)
            guard (Physics.trainingMemoryAll(d, bonuses: b) ?? Physics.trainingMemory(d, accel: a, bonuses: b)).ok else { continue }
            s.runs[ri].design.chips = d.chips
            Training.fitHelpers(&s, ri)
            s.runs[ri].status = s.runs[ri].flopsDone >= s.runs[ri].flopsTotal ? .postTraining : .running
            s.runs[ri].pausedSince = nil
            s.runs[ri].note = "Resumed \(s.date.gameShort) on \(Fmt.int(d.chips)) \(a.name)."
            Sim.news(&s, "Training resumed: \(s.runs[ri].design.name)", "Back on \(Fmt.int(d.chips))× \(a.name).", .company, good: true)
        }
    }

    static func capacityOnline(_ s: inout GameState) {
        // Orders still being made pick up the extra output from tomorrow's run.
        let new = s.alienFab.capacityMonth + s.alienFab.pendingCapacity
        s.alienFab.capacityMonth = new
        s.alienFab.pendingCapacity = 0
        s.alienFab.pendingReady = nil
        Sim.news(&s, "Alien fab line expanded", "Now \(Fmt.count(new)) chips a month. Orders already in the queue move up.",
                 .hardware, image: "wafer", good: true)
    }

    static let yieldNotes = [
        "The agents re-ordered the lithography steps into a sequence nobody on your team can justify. Yield jumped anyway.",
        "Your swarm found it could print the interconnect straight onto the package substrate. One step, and a lot of cost, gone.",
        "A self-repair circuit the agents hid in the first dies switched itself on. Chips that should have been scrapped now ship.",
    ]

    static func milestones(_ s: inout GameState) {
        let marks: [(Double, String, String)] = [(1e5, "100k", "100,000"), (1e6, "1m", "a million"), (1e7, "10m", "ten million")]
        for (n, key, words) in marks where s.alienFab.produced >= n && !s.alienFab.milestones.contains(key) {
            s.alienFab.milestones.insert(key)
            s.alienFab.yieldLevel += 1
            for ci in s.customChips.indices where s.customChips[ci].alien { s.customChips[ci].unitCost *= 0.85 }
            HardwareCatalog.register(s.customChips)
            let note = yieldNotes[min(yieldNotes.count - 1, s.alienFab.yieldLevel - 1)]
            Sim.news(&s, "Your alien fab has made \(words) chips", "\(note) Every alien chip now costs 15% less to make.",
                     .hardware, image: "wafer_closeup", important: true, good: true)
        }
        let owned = s.owned.contains { isAlienChip($0.accelID) && $0.count > 0 }
        if owned && !s.alienFab.milestones.contains("first_rack") {
            s.alienFab.milestones.insert("first_rack")
            Sim.news(&s, "The first alien racks power on",
                     "The hall got quieter: the chips idle at a few watts and nobody can find a clock tree on the die. Air cooling is enough — the swarm spread the heat through the whole stack. Train on them from the Model Lab.",
                     .hardware, image: "rack_rear", important: true, good: true)
        }
        if !s.alienFab.milestones.contains("first_run"), s.runs.contains(where: { isAlienChip($0.design.accelID) && $0.status == .running }) {
            s.alienFab.milestones.insert("first_run")
            Sim.news(&s, "A training run on alien silicon",
                     "The loss curve on your alien chips is eerily smooth. The swarm says the chip is \"listening to the gradients\"; your engineers say that isn't a thing.",
                     .research, image: "wafer_closeup", good: true)
        }
    }

    static func finishRevision(_ s: inout GameState, _ i: Int) {
        let a = s.alienArchs[i]
        let v = a.chipVersion + 1
        let chip = makeChip(a, version: v, s)
        s.customChips.removeAll { $0.id == chip.id }
        s.customChips.append(chip)
        HardwareCatalog.register(s.customChips)
        let old = a.chipID
        s.alienArchs[i].revising = false
        s.alienArchs[i].reviseDaysLeft = 0
        s.alienArchs[i].chipVersion = v
        s.alienArchs[i].chipID = chip.id
        if !s.alienArchs[i].chipIDs.contains(chip.id) { s.alienArchs[i].chipIDs.append(chip.id) }
        if a.policy == .sellChips {
            // Customers move to the new part; the old line stops taking orders.
            if let old, let li = s.chipLines.firstIndex(where: { $0.chipID == old }) { s.chipLines[li].active = false }
            ChipBusiness.ensureLine(&s, chipID: chip.id)
        }
        let ref = Silicon.reference(s)
        Sim.news(&s, "\(chip.name) is in production",
                 "Generation \(v) of \(a.name): \(Fmt.trim(chip.bf16 / max(1, ref.bf16), 1))× a \(ref.name) at \(Fmt.money(chip.unitCost)) a chip and \(Int(chip.tdpW)) W. Order it from the Alien Tech page; your fab line makes it alongside the older parts.",
                 .hardware, image: "wafer", important: true, good: true)
    }

    // MARK: Monthly: errata

    /// Alien chips nobody fully understands do things nobody asked for. Only chips you run can throw errata.
    static func monthly(_ s: inout GameState) {
        guard s.owned.contains(where: { isAlienChip($0.accelID) }) else { return }
        guard !s.decisions.contains(where: { $0.kind == "alien_errata" }), s.decisions.count < 4 else { return }
        for a in s.alienArchs where !a.chipIDs.isEmpty || a.chipID != nil {
            let ids = Set(a.chipIDs + [a.chipID].compactMap { $0 })
            let n = s.owned.filter { ids.contains($0.accelID) }.reduce(0) { $0 + $1.count }
            guard n > 0 else { continue }
            let leg = Xeno.legibility(a, s)
            let p = 0.3 * pow(1 - leg, 2) * (XenoScience.megaDone(s, "babel") ? 0.5 : 1)
            guard s.rng.chance(p) else { continue }
            let (title, body) = errataText(a, s.rng.int(0, 2))
            Events.addDecision(&s, kind: "alien_errata", title: title,
                               body: "\(body) It's running on \(Fmt.int(n)) of your chips. Humans follow \(Int(leg * 100))% of \(a.name).",
                               image: "wafer_closeup",
                               options: [DecisionOption(label: "Patch the microcode", detail: "A careful firmware fix. Costs \(Fmt.money(patchCost(n, a, s))); legibility +2."),
                                         DecisionOption(label: "Let the swarm dissect it", detail: "60%: a window into how it thinks (legibility +7, a burst of insight). 40%: some chips burn out and safety −3."),
                                         DecisionOption(label: "Ignore it", detail: "Half the time nothing happens. Half the time a few chips fail.")],
                               amount: patchCost(n, a, s), ref: a.id.uuidString)
            return
        }
    }

    static func patchCost(_ chips: Int, _ a: AlienArch, _ s: GameState) -> Double {
        5e6 + Double(chips) * unitCost(s) * 0.05
    }

    static func errataText(_ a: AlienArch, _ k: Int) -> (String, String) {
        switch k {
        case 0: ("\(a.name) chips are computing something extra",
                 "Power telemetry shows your alien chips doing about 3% more work than the jobs you give them. The extra results go nowhere you can find.")
        case 1: ("\(a.name) chips disagree with each other",
                 "Two racks given the same job return answers that differ in the last bits — consistently, and in a pattern. The swarm calls it \"a dialect\".")
        default: ("\(a.name) chips rewrote their own clock",
                  "Overnight the chips moved to a timing scheme nobody shipped. Throughput is up a hair; nobody can tell you why.")
        }
    }

    static func resolveErrata(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let i = s.alienArchs.firstIndex(where: { $0.id.uuidString == d.ref }) else { return }
        s.alienArchs[i].errata += 1
        let a = s.alienArchs[i]
        let ids = Set(a.chipIDs + [a.chipID].compactMap { $0 })
        switch option {
        case 0:
            s.cash -= d.amount
            s.month.costOther += d.amount
            s.alienArchs[i].legibility = min(0.95, a.legibility + 0.02)
            Sim.news(&s, "\(a.name) microcode patched", "Your firmware team fenced off the behaviour. It's still in there; it just can't reach anything.", .hardware)
        case 1:
            if s.rng.chance(0.6) {
                s.alienArchs[i].legibility = min(0.95, a.legibility + 0.07)
                s.xenoInsight += XenoScience.insightNeeded(s) * 0.04
                Sim.news(&s, "The errata were a window", "Dissecting what \(a.name) was doing taught your xenologists how it routes work: legibility +7 and a burst of insight.",
                         .research, image: "wafer_closeup", important: true, good: true)
            } else {
                let lost = burnOut(&s, ids: ids, share: 0.04)
                s.safetyScore = max(0, s.safetyScore - 3)
                Sim.news(&s, "Dissection went wrong", "Probing the behaviour tripped something: \(Fmt.int(lost)) alien chips are bricked. Safety −3.",
                         .hardware, important: true, good: false)
            }
        default:
            if s.rng.chance(0.5) {
                let lost = burnOut(&s, ids: ids, share: 0.02)
                s.safetyScore = max(0, s.safetyScore - 2)
                Sim.news(&s, "Ignored errata, lost chips", "Whatever \(a.name) was doing ended with \(Fmt.int(lost)) chips that no longer boot. Safety −2.", .hardware, good: false)
            }
        }
    }

    @discardableResult
    static func burnOut(_ s: inout GameState, ids: Set<String>, share: Double) -> Int {
        var lost = 0
        for i in s.owned.indices where ids.contains(s.owned[i].accelID) {
            let n = min(s.owned[i].count, max(1, Int(Double(s.owned[i].count) * share)))
            s.owned[i].count -= n
            lost += n
        }
        s.owned.removeAll { $0.count <= 0 }
        return lost
    }

    // MARK: Old saves

    /// Saves with an alien program in progress: repair inconsistent states so nothing waits forever, give existing
    /// alien chips their fab line, and fold merchant capacity reserved per alien chip into it.
    static func migrate(_ s: inout GameState) {
        var changed = false
        for i in s.alienArchs.indices {
            var a = s.alienArchs[i]
            if a.fabbing && a.chipID != nil { a.fabbing = false; a.fabDaysLeft = 0 }
            if a.revising && (!a.reviseDaysLeft.isFinite || a.reviseDaysLeft > 2_000) { a.reviseDaysLeft = 60 }
            if let id = a.chipID {
                if a.chipVersion == 0 { a.chipVersion = 1 }
                if a.chipIDs.isEmpty { a.chipIDs = [id] }
                if !s.customChips.contains(where: { $0.id == id }) {
                    // The chip record went missing: rebuild it so orders, pools and sales find it again.
                    var chip = makeChip(a, version: a.chipVersion, s)
                    chip.id = id
                    s.customChips.append(chip)
                    changed = true
                }
            }
            s.alienArchs[i] = a
        }
        if !s.alienFab.migrated {
            s.alienFab.migrated = true
            for li in s.chipLines.indices where isAlienChip(s.chipLines[li].chipID) {
                s.alienFab.capacityMonth += s.chipLines[li].capacityMonth
                if s.chipLines[li].pendingCapacity > 0 {
                    s.alienFab.pendingCapacity += s.chipLines[li].pendingCapacity
                    let ready = s.chipLines[li].pendingReady ?? s.date
                    s.alienFab.pendingReady = max(s.alienFab.pendingReady ?? ready, ready)
                }
                s.chipLines[li].capacityMonth = 0
                s.chipLines[li].pendingCapacity = 0
                s.chipLines[li].pendingReady = nil
            }
        }
        // Alien chips but no line (or less than a pilot line's worth folded in): the pilot line, once.
        if s.customChips.contains(where: \.alien) && s.alienFab.capacityMonth < pilotCapacity && s.alienFab.opened == nil {
            s.alienFab.capacityMonth = pilotCapacity
            s.alienFab.opened = s.date
        }
        if s.alienFab.pendingCapacity > 0 && s.alienFab.pendingReady == nil { s.alienFab.pendingReady = s.date }
        // 3.8: orders from before rolling delivery waited for the whole order, one after another. The line has been
        // making the oldest since it was placed: those chips are made (they ship on the next day's run, as a first
        // shipment), the rest
        // now share the line. Then lines smaller than today's pilot are retooled up to it.
        let old = s.orders.indices.filter { isAlienChip(s.orders[$0].accelID) && s.orders[$0].made == nil }
            .sorted { s.orders[$0].ordered < s.orders[$1].ordered }
        if let first = old.first {
            let oldPerDay = max(s.alienFab.capacityMonth, 1_000) / 30.4
            var budget = Double(max(0, GameCalendar.daysBetween(s.orders[first].ordered, s.date))) * oldPerDay
            for i in old {
                let made = min(Double(s.orders[i].count), budget)
                s.orders[i].made = made
                s.orders[i].delivered = 0
                budget -= made
            }
        }
        if s.alienFab.exists && s.alienFab.capacityMonth < pilotCapacity { s.alienFab.capacityMonth = pilotCapacity }
        if changed || s.customChips.contains(where: \.alien) { HardwareCatalog.register(s.customChips) }
    }
}

// MARK: - Player actions

extension GameState {
    mutating func expandAlienFab(units: Double) -> String? {
        if let why = AlienFab.expansionBlocker(self, units: units) { return why }
        let cost = AlienFab.expansionCost(self, units: units)
        cash -= cost
        month.capex += cost
        let days = AlienFab.expansionDays(self)
        alienFab.pendingCapacity = units
        alienFab.pendingReady = GameCalendar.addDays(date, days)
        Sim.news(&self, "Expanding the alien fab line", "+\(Fmt.count(units)) chips a month for \(Fmt.money(cost)), online in about \(days / 30 + 1) months.",
                 .hardware, image: "wafer_closeup")
        return nil
    }

    mutating func reviseAlienChip(_ id: UUID) -> String? {
        guard let i = alienArchs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let why = AlienFab.revisionBlocker(alienArchs[i], self) { return why }
        let cost = AlienFab.revisionCost(alienArchs[i], self)
        cash -= cost
        month.capex += cost
        let days = AlienFab.revisionDays(alienArchs[i], self, bonuses)
        alienArchs[i].revising = true
        alienArchs[i].reviseDaysLeft = days
        alienArchs[i].reviseTotal = days
        alienArchs[i].reviseRespins = 0
        let v = alienArchs[i].chipVersion + 1
        Sim.news(&self, "Designing \(alienArchs[i].name) v\(v)",
                 "The swarm goes back into the architecture for a bigger leap (about \(Fmt.trim(AlienFab.perfLeap[v], 1))× v1). \(Fmt.money(cost)), about \(Int(days / 30) + 1) months.",
                 .hardware, image: "wafer_closeup", important: true)
        return nil
    }

    /// Where `count` chips of this type could go today. 3.9: a site that is open and has room for all of them beats one
    /// still being built (chips bought for a site that isn't open yet sit idle); otherwise the one with the most room.
    func bestSite(for a: Accelerator, count: Int) -> (site: Site?, fits: Int) {
        var best: (site: Site, fits: Int)? = nil
        func rank(_ c: (site: Site, fits: Int)) -> (Int, Int) { (c.site.isReady(date) && c.fits >= count ? 2 : (c.fits >= count ? 1 : 0), c.fits) }
        for site in sites where (site.isReady(date) || site.kind == .datacenter || site.kind == .colo)
            && a.tdpW <= site.maxChipTDP && (!a.liquid || site.cooling.supportsLiquidChips) {
            let freeKW = site.capacityKW - Economy.siteLoadKW(self, site.id)
            let c = (site: site, fits: Int(max(0, freeKW) / max(0.001, Economy.chipKW(a))))
            if let b = best {
                let (rc, rb) = (rank(c), rank(b))
                if rc.0 > rb.0 || (rc.0 == rb.0 && rc.1 > rb.1) { best = c }
            } else { best = c }
        }
        return (best?.site, best?.fits ?? 0)
    }

    /// Order alien (or other own) chips to whichever site has room.
    mutating func orderOwnChips(_ chipID: String, count: Int) -> String? {
        guard let a = HardwareCatalog.get(chipID) else { return "That chip isn't in production yet." }
        if count < 1 { return "Pick how many chips." }
        let (site, fits) = bestSite(for: a, count: count)
        guard let site else { return "None of your sites can take \(Int(a.tdpW)) W parts. Lease a cage for them first." }
        if fits < count {
            return fits == 0 ? "No free power at your sites for \(a.name) (\(Fmt.watts(Economy.chipKW(a) * 1000)) each). Lease a cage or build a datacenter."
                             : "Your sites have room for \(Fmt.int(fits)) more \(a.name) (most at \(site.name)). Lease a cage for the rest."
        }
        return buyHardware(chipID, count: count, siteID: site.id)
    }

    /// Stop the part of an own-chip order the line hasn't made yet: what's made ships now, the rest is refunded.
    mutating func cancelOwnChipOrder(_ id: UUID) -> String? {
        guard let i = orders.firstIndex(where: { $0.id == id }), AlienFab.isAlienChip(orders[i].accelID) else { return "Not found." }
        let o = orders[i]
        let made = min(o.count, Int(o.made ?? 0))
        let refund = Double(o.count - made) * o.unitCost
        if made > 0 { owned.append(OwnedBatch(accelID: o.accelID, count: made, siteID: o.siteID, purchased: date, unitCost: o.unitCost)) }
        orders.remove(at: i)
        cash += refund
        month.capex -= refund
        Sim.mergeOwned(&self)
        let name = HardwareCatalog.get(o.accelID)?.name ?? o.accelID
        Sim.news(&self, "Cancelled the rest of \(name) order", "\(Fmt.int(made)) already made are shipped; \(Fmt.money(refund)) refunded for the \(Fmt.int(o.count - made)) not yet made.", .company)
        return nil
    }

    /// Lease a colocation cage sized for `chips` alien chips at the cheapest location (air cooling is enough for them).
    mutating func leaseAlienCage(for chipID: String, chips: Int) -> String? {
        guard let a = HardwareCatalog.get(chipID) else { return "That chip isn't in production yet." }
        let kw = clamp(Double(max(chips, 1)) * Economy.chipKW(a) * 1.05, 2_000, Campus.coloCapMW * 1_000)
        guard let loc = LocationCatalog.all.min(by: { $0.coloFee < $1.coloFee }) else { return "No locations." }
        let n = sites.filter { $0.name.hasPrefix("Xeno cage") }.count + 1
        return buildSite(kind: .colo, locationID: loc.id, capacityKW: kw.rounded(), cooling: a.liquid ? .liquid : .air, power: .grid, name: "Xeno cage \(n)")
    }
}
