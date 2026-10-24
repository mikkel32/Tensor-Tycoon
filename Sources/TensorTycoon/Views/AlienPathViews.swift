import SwiftUI

// 3.5: the alien-tech path as a timeline, your alien fab line, and chip generations.

/// Every stage from first search to v3 silicon, with its status, ETA, what's blocking it and the button that moves it on.
struct AlienPathCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let stages = AlienPath.stages(s)
        let next = AlienPath.nextStep(s)
        Card {
            CardHeader("Alien tech progress", symbol: "point.3.connected.trianglepath.dotted",
                       subtitle: next.map { "Next: \($0.title.lowercased())\($0.blocker != nil ? " — blocked" : "")" } ?? "Everything that can move is moving.")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { i, st in
                    AlienStageRow(stage: st, state: s, last: i == stages.count - 1)
                }
            }
        }
    }
}

private struct AlienStageRow: View {
    @Environment(GameStore.self) private var store
    let stage: AlienPath.Stage
    let state: GameState
    let last: Bool

    private var tint: Color {
        switch stage.status {
        case .done: .green
        case .active: .purple
        case .ready: .blue
        case .blocked: .orange
        case .locked: .secondary
        }
    }

    private var icon: String {
        switch stage.status {
        case .done: "checkmark.circle.fill"
        case .active: "circle.dotted.circle"
        case .ready: "arrow.right.circle.fill"
        case .blocked: "exclamationmark.triangle.fill"
        case .locked: "lock.circle"
        }
    }

    var body: some View {
        let st = stage
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 26, height: 26)
                if !last { Rectangle().fill(tint.opacity(0.35)).frame(width: 2).frame(maxHeight: .infinity) }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Label(st.title, systemImage: st.symbol).font(.callout.weight(.semibold))
                        .foregroundStyle(st.status == .locked ? .secondary : .primary)
                    if let eta = st.eta {
                        Pill(text: "ETA \(eta.gameShort)", color: tint, symbol: "clock")
                    }
                    Spacer(minLength: 0)
                }
                Text(st.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let p = st.progress, st.status == .active || (st.status == .blocked && p > 0) {
                    Meter(value: p, tint: tint, height: 6).frame(maxWidth: 360)
                }
                if let why = st.blocker {
                    Label(why, systemImage: "hand.raised.fill").font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, last ? 0 : 12)
            if let action = st.action, let title = st.actionTitle {
                actionButton(action, title: title)
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ action: AlienPath.Action, title: String) -> some View {
        let s = state
        switch action {
        case .swarms:
            Button(title) { store.open(.swarms) }
        case .expandFab:
            Button(title) { store.act("Fab expansion started") { $0.expandAlienFab(units: AlienFabCard.defaultExpansion(s)) } }
                .help("Add \(Fmt.count(AlienFabCard.defaultExpansion(s))) chips a month for \(Fmt.money(AlienFab.expansionCost(s, units: AlienFabCard.defaultExpansion(s)))). More options in the fab card below.")
                .disabled(AlienFab.expansionBlocker(s, units: AlienFabCard.defaultExpansion(s)) != nil)
        case .leaseCage(let id):
            let n = max(AlienFabCard.suggestedOrder(id, s, ignoringSites: true), 4_000)
            let fee = AlienFab.cageFee(id, chips: n, s)
            Button("\(title) (\(Fmt.money(fee))/mo)") { store.act("Cage leased — ready in 30 days") { $0.leaseAlienCage(for: id, chips: n) } }
                .buttonStyle(.borderedProminent)
                .help("A colocation cage sized for about \(Fmt.int(n)) chips at the cheapest location, ready in 30 days: \(Fmt.money(fee)) now and every month until you end it.")
        case .order(let id):
            let adv = AlienFab.orderAdvice(id, s)
            let n = adv.count
            Button(n > 0 ? "\(title) \(Fmt.count(Double(n)))" : title) { store.act("Order queued on your fab line") { $0.orderOwnChips(id, count: n) } }
                .buttonStyle(.borderedProminent)
                .disabled(n < 1)
                .help(n > 0 ? "From your fab line: the first chips in about \(AlienFab.shipDays) days, all \(Fmt.int(n)) in about \(AlienFab.leadDays(s, count: n)) days." : (adv.reason ?? ""))
        case .modelLab:
            Button(title) { store.open(title == "Training" ? .training : .lab) }
        case .chipSales:
            Button(title) { store.open(.chipSales) }
        case .license(let id):
            Button(title) {
                if s.alienArchs.first(where: { $0.id == id })?.policy != .license {
                    store.act("Open to license offers") { $0.setXenoPolicy(id, .license) }
                }
            }
        case .revise(let id):
            Button(title) { store.act("Next-generation design started") { $0.reviseAlienChip(id) } }
                .buttonStyle(.borderedProminent).disabled(stage.status == .blocked)
        case .study:
            Button(title) { store.open(.xeno) }
        }
    }
}

/// Your alien fab line: capacity, queue, volume milestones, ordering and expansion.
struct AlienFabCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var expandLog = 4.3
    @State private var qty: [String: Int] = [:]

    static func defaultExpansion(_ s: GameState) -> Double {
        max(5_000, (s.alienFab.capacityMonth * 0.5 / 1_000).rounded() * 1_000)
    }

    static func suggestedOrder(_ chipID: String, _ s: GameState, ignoringSites: Bool = false) -> Int {
        AlienFab.suggestedOrder(chipID, s, ignoringSites: ignoringSites)
    }

    var body: some View {
        let s = state
        let f = s.alienFab
        let units = (pow(10, expandLog) / 1_000).rounded() * 1_000
        let chips = s.customChips.filter(\.alien).sorted { $0.bf16 > $1.bf16 }
        Card {
            CardHeader(title: "Your alien fab line", symbol: "building.2.crop.circle",
                       subtitle: "One line makes every alien chip you own. Your open orders share it and ship weekly as they're made — no world allocation caps — and merchant customers get what's left (a quarter while you're ordering).") {
                if f.yieldLevel > 0 { Pill(text: "Yield level \(f.yieldLevel)", color: .green, symbol: "sparkles") }
            }
            KPIRow(minWidth: 170) {
                StatTile(title: "Capacity", value: "\(Fmt.count(f.capacityMonth))/mo",
                         detail: f.pendingCapacity > 0 ? "+\(Fmt.count(f.pendingCapacity)) on \(f.pendingReady?.gameShort ?? "")" : "Your own line", symbol: "gearshape.2.fill", tint: .purple)
                StatTile(title: "Your queue", value: AlienFab.queueDays(s) > 0.5 ? Fmt.days(AlienFab.queueDays(s)) : "Empty",
                         detail: "\(Fmt.count(AlienFab.ownPerDay(s) * 30.4))/mo for you", symbol: "tray.full.fill", tint: .indigo)
                StatTile(title: "For customers", value: "\(Fmt.count(AlienFab.merchantPerDay(s) * 30.4))/mo",
                         detail: AlienFab.activeMerchantLines(s) > 0 ? "\(AlienFab.activeMerchantLines(s)) sales line\(AlienFab.activeMerchantLines(s) == 1 ? "" : "s")" : "No sales line open", symbol: "shippingbox.fill", tint: .green)
                StatTile(title: "Chips made", value: Fmt.count(f.produced), detail: nextMilestone(f.produced), symbol: "cpu.fill", tint: .orange)
            }
            ForEach(chips) { c in orderRow(c, s) }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Expand the line").font(.headline)
                HStack {
                    Slider(value: $expandLog, in: 3...5.7)
                    Text("+\(Fmt.count(units))/mo").font(.callout.monospacedDigit().weight(.semibold)).frame(width: 100, alignment: .trailing)
                    Button("Expand") { store.act("Fab expansion started") { $0.expandAlienFab(units: units) } }
                        .disabled(AlienFab.expansionBlocker(s, units: units) != nil)
                        .help(AlienFab.expansionBlocker(s, units: units) ?? "Start the expansion.")
                }
                Text("\(Fmt.money(AlienFab.expansionCost(s, units: units))) up front, online in about \(AlienFab.expansionDays(s) / 30 + 1) months. Orders already queued move up when it does.\(AlienFab.expansionBlocker(s, units: units).map { " \($0)" } ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func nextMilestone(_ produced: Double) -> String {
        guard let n = [1e5, 1e6, 1e7].first(where: { $0 > produced }) else { return "Every milestone reached" }
        return "Next yield discovery at \(Fmt.count(n))"
    }

    @ViewBuilder
    private func orderRow(_ c: CustomChip, _ s: GameState) -> some View {
        // 3.9: the picker stays within what one order can be: the line's per-order cap, room in its queue and power at one site.
        let fits = HardwareCatalog.get(c.id).map { s.bestSite(for: $0, count: 1).fits } ?? 0
        let most = min(AlienFab.maxOrder(s), AlienFab.backlogRoom(s), fits)
        let n = clamp(qty[c.id] ?? AlienFabCard.suggestedOrder(c.id, s), 1, max(1, most))
        let why: String? = most >= 1 ? nil : (AlienFab.backlogRoom(s) < 1 ? AlienFab.orderAdvice(c.id, s).reason
            : "No free power at your sites for \(c.name). Lease a cage or add capacity.")
        let owned = s.owned.filter { $0.accelID == c.id }.reduce(0) { $0 + $1.count }
        let onOrder = s.orders.filter { $0.accelID == c.id }.reduce(0) { $0 + $1.count }
        let ref = Silicon.reference(s)
        HStack(spacing: 10) {
            Image(systemName: "atom").foregroundStyle(.purple).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(.callout.weight(.semibold))
                Text("\(Fmt.trim(c.bf16 / max(1, ref.bf16), 1))× a \(ref.name) · \(Fmt.money(c.unitCost)) · \(Int(c.tdpW)) W, air-cooled · \(Fmt.int(owned)) installed\(onOrder > 0 ? ", \(Fmt.int(onOrder)) coming" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                if let why { Text(why).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer()
            QuantityPicker(value: Binding(get: { n }, set: { qty[c.id] = $0 }), range: 1...max(1, most), presets: [1_000, 4_000, 16_000, 64_000, 256_000])
            VStack(alignment: .trailing, spacing: 1) {
                Button("Order") { store.act("Order queued on your fab line") { $0.orderOwnChips(c.id, count: n) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(why != nil)
                Text("~\(AlienFab.leadDays(s, count: n)) days · \(Fmt.money(c.unitCost * Double(n)))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }
}

/// Chip versions and the next-generation design for one architecture.
struct AlienChipGenerations: View {
    @Environment(GameStore.self) private var store
    let arch: AlienArch
    let state: GameState

    var body: some View {
        let a = arch
        let s = state
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Chip generations").font(.caption.weight(.semibold))
                ForEach(1...AlienFab.maxVersion, id: \.self) { v in
                    Pill(text: "v\(v) · \(Fmt.trim(AlienFab.perfLeap[v], 1))×", color: v <= a.chipVersion ? .purple : .secondary,
                         symbol: v <= a.chipVersion ? "checkmark" : (a.revising && v == a.chipVersion + 1 ? "hammer.fill" : nil))
                }
                if a.errata > 0 { Pill(text: "\(a.errata) errat\(a.errata == 1 ? "um" : "a")", color: .orange, symbol: "ladybug.fill") }
                Spacer()
            }
            if a.revising {
                HStack {
                    Text("Designing v\(a.chipVersion + 1)\(a.reviseRespins > 0 ? " (respun)" : "")").font(.caption)
                    Meter(value: 1 - a.reviseDaysLeft / max(1, a.reviseTotal), tint: .purple, height: 6)
                    Text("~\(Int(a.reviseDaysLeft / 30) + 1) mo").font(.caption.monospacedDigit())
                }
            } else if a.chipVersion >= 1 && a.chipVersion < AlienFab.maxVersion {
                let why = AlienFab.revisionBlocker(a, s)
                HStack {
                    Text("v\(a.chipVersion + 1): \(Fmt.trim(AlienFab.perfLeap[a.chipVersion + 1] / AlienFab.perfLeap[a.chipVersion], 1))× faster than v\(a.chipVersion), cheaper and cooler. \(Fmt.money(AlienFab.revisionCost(a, s))), about \(Int(AlienFab.revisionDays(a, s, store.derived.bonuses) / 30) + 1) months; \(Int(AlienFab.respinChance(a, s) * 100))% respin risk at this legibility.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Design v\(a.chipVersion + 1)") { store.act("Next-generation design started") { $0.reviseAlienChip(a.id) } }
                        .disabled(why != nil).help(why ?? "Start the design.")
                }
            }
        }
    }
}
