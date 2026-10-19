import SwiftUI

struct XenoView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let n = XenoScience.discoveries(s)
        let ventures = s.xenoArtifacts.reduce(0) { $0 + $1.ventureRevenue }
        Page(title: "Alien Tech", subtitle: "Designs your agents found where no human would look. Architectures and chips, optimizers and codecs that make every run cheaper, superconductors, mathematics, biology — and minds unlike ours. Study them to unlock their full power, build businesses on them, and attempt the mega-projects they make possible.", screen: .xeno) {
            HeroBanner(image: "wafer_closeup", height: 160) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Xenoscience").font(.title.weight(.bold))
                        Text(n == 0 ? "Nothing found yet." : "\(n) discover\(n == 1 ? "y" : "ies") · moat worth \(Fmt.money(Xeno.moatValue(s))) to investors")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    if ventures > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Alien ventures have earned").font(.caption).opacity(0.8)
                            Text(Fmt.money(ventures)).font(TypeRamp.bannerMetric)
                        }
                    }
                }
            }
            AlienPathCard(state: s)   // 3.5: the whole path, with ETAs and blockers
            XenoSearchCard(state: s)
            if n == 0 {
                Card {
                    EmptyStateView(symbol: "atom", title: "Nothing alien yet",
                                   message: "Point an agent swarm at \"Alien architecture search\" (needs Agentic RL and a near-frontier model), or run a self-improvement run on Architecture search. Bigger swarms of smarter agents find it faster. The first discovery is always an architecture; after that you choose what to look for.",
                                   actionTitle: "Agent Swarms") { store.open(.swarms) }
                }
            } else {
                XenoStudyCard(state: s)
                if s.alienFab.exists { AlienFabCard(state: s) }
                ForEach(s.alienArchs.reversed()) { a in AlienArchCard(arch: a, state: s) }
                ForEach(s.xenoArtifacts.reversed()) { a in ArtifactCard(artifact: a, state: s) }
                MegaProjectsCard(state: s)
                ArmedRivalsCard(state: s)
            }
        }
    }
}

// MARK: - Search and study

private struct XenoSearchCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let needed = XenoScience.insightNeeded(s)
        let rate = s.xenoInsightToday
        let left = max(0, needed - s.xenoInsight)
        let next = XenoScience.nextKind(s)
        Card {
            CardHeader(title: "Alien search", symbol: "scope",
                       subtitle: "Next: \(next.title.lowercased()) — \(next.summary)") {
                Button("Agent Swarms") { store.open(.swarms) }.buttonStyle(.link)
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Meter(value: s.xenoInsight / max(1, needed), tint: .purple, height: 10)
                    Text("\(Fmt.count(s.xenoInsight)) of \(Fmt.count(needed)) insight for discovery #\(XenoScience.discoveries(s) + 1). Each one needs 2.2× the last.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(rate > 0 ? "\(Fmt.trim(rate, 1))/day" : "Idle").font(.callout.monospacedDigit().weight(.semibold))
                    Text(rate > 0 ? "~\(Fmt.days(left / rate)) to go" : "No search running").font(.caption).foregroundStyle(.secondary)
                }
                .frame(width: 150, alignment: .trailing)
            }
            if let why = AlienPath.searchBlocker(s) {
                Label(why, systemImage: "hand.raised.fill").font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if XenoScience.discoveries(s) > 0 {
                Text("Search target").font(.caption.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(XenoKind.allCases) { k in
                        let owned = s.xenoArtifacts.filter { $0.kind == k }.count + (k == .architecture ? s.alienArchs.count : 0)
                        Button { store.mutate { $0.setXenoTarget(k) } } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Image(systemName: k.symbol).foregroundStyle(s.xenoTargetKind == k ? Color.purple : .secondary)
                                    Text(k.title).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                }
                                Text(owned == 0 ? "Not found yet" : "\(owned) found · next is gen \(owned + 1)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(s.xenoTargetKind == k ? Color.purple.opacity(0.15) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(s.xenoTargetKind == k ? Color.purple : .clear, lineWidth: 1.5))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .help(k.summary)
                    }
                }
            }
        }
    }
}

private struct XenoStudyCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var share = 0.0
    @State private var loaded = false

    var body: some View {
        let s = state
        Card {
            CardHeader("Xenology", symbol: "eye.trianglebadge.exclamationmark",
                       subtitle: "Put research into understanding what you found. Legibility unlocks more of each discovery's power and makes anomalies rarer.")
            HStack {
                Text("Share of research").font(.caption.weight(.semibold))
                Slider(value: $share, in: 0...0.6, step: 0.05).frame(maxWidth: 240)
                Text("\(Int((share * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                Button("Set") { store.mutate { $0.setXenoStudyShare(share) } }
                    .disabled(abs(share - s.xenoStudyShare) < 0.001)
                Spacer()
                Text(s.studyRPToday > 0 ? "\(Fmt.trim(s.studyRPToday, 1)) RP/day" : "Nobody is studying").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ForEach(s.alienArchs) { a in legibilityRow(a.name, symbol: "atom", value: Xeno.legibility(a, s)) }
            ForEach(s.xenoArtifacts) { a in legibilityRow(a.name, symbol: a.kind.symbol, value: a.legibility) }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            share = s.xenoStudyShare
        }
    }

    private func legibilityRow(_ name: String, symbol: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.purple).frame(width: 20)
            Text(name).font(.callout).frame(width: 200, alignment: .leading).lineLimit(1)
            Meter(value: value, tint: value >= 0.75 ? .green : (value >= 0.4 ? .yellow : .red), height: 8)
            Text("\(Int(value * 100))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Artifacts

private struct ArtifactCard: View {
    @Environment(GameStore.self) private var store
    let artifact: XenoArtifact
    let state: GameState

    var body: some View {
        let a = artifact
        let s = state
        let active = a.active(on: s.date)
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: a.kind.symbol).font(.title2).foregroundStyle(.purple)
                        Text(a.name).font(.title2.weight(.bold))
                        Pill(text: "\(a.kind.title) · gen \(a.generation)", color: .purple)
                        if !active, let until = a.quarantinedUntil {
                            Pill(text: "Quarantined until \(until.gameShort)", color: .red, symbol: "lock.fill")
                        }
                        if a.anomalies > 0 { Pill(text: "\(a.anomalies) anomal\(a.anomalies == 1 ? "y" : "ies")", color: .orange, symbol: "exclamationmark.triangle.fill") }
                    }
                    Text("Discovered \(a.discovered.gameShort) · \(a.kind.summary)").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            EqualColumns(minWidth: 120, spacing: 10, maxColumns: 3) {
                XenoStat(label: "Potency", value: "×\(Fmt.trim(a.potency, 2))", symbol: "bolt.fill", tint: .purple)
                XenoStat(label: "Legibility", value: "\(Int(a.legibility * 100))%", symbol: "eye.trianglebadge.exclamationmark", tint: a.legibility >= 0.5 ? .green : .red)
                XenoStat(label: "Usable strength", value: "×\(Fmt.trim(XenoScience.strength(a), 2))", symbol: "gauge.with.dots.needle.67percent", tint: .orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(XenoCatalog.effectText(a.kind), id: \.self) { line in
                    Label(line, systemImage: "arrow.up.right").font(.caption).foregroundStyle(.green)
                }
                Text("Each unit of usable strength gives the effect above. Study it to raise legibility and strength.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if a.kind.hasVenture {
                Divider()
                venture(a, s)
            }
        }
    }

    @ViewBuilder
    private func venture(_ a: XenoArtifact, _ s: GameState) -> some View {
        if a.venture.isEmpty {
            let offer = XenoScience.licenseOffer(a, s)
            let capex = XenoScience.inhouseCapex(a, s)
            let monthly = XenoCatalog.inhouseShare(a.kind) * Macro.frontierValuation(s.year) * XenoScience.strength(a) * XenoScience.ventureBoost(a.kind, s)
            Text("Build a business on it").font(.headline)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("License it", systemImage: "doc.text.fill").font(.callout.weight(.semibold))
                    Text("\(Fmt.money(offer.upfront)) now plus \(Fmt.money(offer.monthly))/month for four years.").font(.caption).foregroundStyle(.secondary)
                    Menu("Choose a partner") {
                        ForEach(XenoCatalog.partners(a.kind), id: \.self) { partner in
                            Button(partner) { store.act("Licensed to \(partner)") { $0.licenseArtifact(a.id, partner: partner) } }
                        }
                    }
                    .fixedSize()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
                VStack(alignment: .leading, spacing: 4) {
                    Label("Build it yourself", systemImage: "building.2.fill").font(.callout.weight(.semibold))
                    Text("\(Fmt.money(capex)) and \(XenoCatalog.inhouseMonths(a.kind)) months, then about \(Fmt.money(monthly))/month that grows with the market.").font(.caption).foregroundStyle(.secondary)
                    Button("Build it") { store.act("Venture started") { $0.buildVenture(a.id) } }
                        .disabled(s.cash < capex)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
            }
        } else {
            let ready = a.ventureReady ?? s.date
            HStack {
                Image(systemName: a.venture == "inhouse" ? "building.2.fill" : "doc.text.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.venture == "inhouse" ? "Your own business" : "Licensed to \(a.venturePartner)").font(.callout.weight(.semibold))
                    if ready > s.date {
                        Text("Opens \(ready.gameShort)").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(Fmt.money(a.ventureMonthly))/month\(a.venture == "license" ? " · \(a.ventureMonthsLeft) months left" : "")").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("Earned \(Fmt.money(a.ventureRevenue))").font(.callout.monospacedDigit())
            }
        }
    }
}

// MARK: - Mega-projects

private struct MegaProjectsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("Mega-projects", symbol: "building.columns.fill", subtitle: "Giant programmes only alien tech makes possible.")
            ForEach(XenoCatalog.megaProjects) { m in
                let running = s.megaProjects.first { $0.id == m.id }
                let blocker = XenoScience.megaBlocker(m.id, s)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: m.symbol).font(.title3)
                        .foregroundStyle(running?.done == true ? Color.green : .purple)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(m.name).font(.callout.weight(.semibold))
                            if running?.done == true { Pill(text: "Complete", color: .green, symbol: "checkmark.seal.fill") }
                        }
                        Text(m.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text(m.effect).font(.caption).foregroundStyle(.green).fixedSize(horizontal: false, vertical: true)
                        if let r = running, !r.done {
                            Meter(value: 1 - r.daysLeft / max(1, r.totalDays), tint: .purple, height: 6)
                            Text("About \(Int(r.daysLeft / 30.4) + 1) months left").font(.caption2).foregroundStyle(.secondary)
                        } else if running == nil {
                            Text("Needs \(m.requirement.lowercased()) · \(Fmt.money(XenoScience.megaCost(m, s))) · about \(Int(m.days / 30.4)) months")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if running == nil {
                        Button("Begin") { store.act("\(m.name) begins") { $0.startMegaProject(m.id) } }
                            .disabled(blocker != nil)
                            .help(blocker ?? "Start the project.")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct AlienArchCard: View {
    @Environment(GameStore.self) private var store
    let arch: AlienArch
    let state: GameState

    var body: some View {
        let a = arch
        let s = state
        let chip = a.chipID.flatMap { HardwareCatalog.get($0) }
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "atom").font(.title2).foregroundStyle(.purple)
                        Text(a.name).font(.title2.weight(.bold))
                        Pill(text: "Gen \(a.generation)", color: .purple)
                        Pill(text: a.policy.rawValue, color: a.policy == .exclusive ? .indigo : (a.policy == .sellChips ? .green : .orange), symbol: a.policy.symbol)
                        if a.licensedOnce { Pill(text: "Blueprint is out", color: .orange, symbol: "lock.open.fill") }
                    }
                    Text("Discovered \(a.discovered.gameShort) · humans follow about \(Int(Xeno.legibility(a, s) * 100))% of it").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            EqualColumns(minWidth: 120, spacing: 10, maxColumns: 5) {
                XenoStat(label: "Model efficiency", value: "×\(Fmt.trim(a.multiplier, 2)) compute", symbol: "cpu", tint: .purple)
                XenoStat(label: "Chip throughput", value: "\(Fmt.trim(a.chipPerf, 1))× best GPU", symbol: "bolt.fill", tint: .orange)
                XenoStat(label: "Production cost", value: "\(Int((a.costFactor * 100).rounded()))% of a GPU", symbol: "dollarsign.circle", tint: .green)
                XenoStat(label: "Power", value: "\(Int((a.powerFactor * 100).rounded()))% of a GPU", symbol: "powerplug.fill", tint: .yellow)
                XenoStat(label: "Legibility", value: "\(Int(Xeno.legibility(a, s) * 100))%", symbol: "eye.trianglebadge.exclamationmark", tint: Xeno.legibility(a, s) >= 0.5 ? .green : .red)
            }
            Text("Models on the alien architecture: pick **Alien (xeno)** as the architecture in the Model Lab. They train as if they had ×\(Fmt.trim(a.multiplier, 1)) the compute, serve cheaper, and lose up to \(Int(25 * (1 - Xeno.legibility(a, s)))) safety points because nobody can fully audit them.")
                .font(.caption).foregroundStyle(.secondary)

            Divider()
            chipSection(a, chip: chip, s)
            if a.chipVersion >= 1 { AlienChipGenerations(arch: a, state: s) }
            Divider()

            Text("What do you do with it?").font(.headline)
            HStack(spacing: 10) {
                ForEach(XenoPolicy.allCases) { p in
                    Button {
                        store.act(p == .license ? "Open to license offers" : (p == .sellChips ? "Selling the chips" : "Kept exclusive")) { $0.setXenoPolicy(a.id, p) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: p.symbol).foregroundStyle(a.policy == p ? Color.accentColor : .secondary)
                                Text(p.rawValue).font(.callout.weight(.semibold))
                            }
                            Text(p.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(4, reservesSpace: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(a.policy == p ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(a.policy == p ? Color.accentColor : .clear, lineWidth: 1.5))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            if a.policy == .license || !a.licenses.isEmpty {
                licensing(a, s)
            }
            if a.policy == .sellChips, let id = a.chipID, let line = s.chipLines.first(where: { $0.chipID == id }) {
                HStack {
                    Text("\(Fmt.count(line.shipped)) chips shipped · \(Fmt.money(line.revenue)) revenue · \(Fmt.count(line.capacityMonth))/month capacity")
                        .font(.callout)
                    Spacer()
                    Button("Manage sales") { store.open(.chipSales) }
                }
            }
        }
    }

    @ViewBuilder
    private func chipSection(_ a: AlienArch, chip: Accelerator?, _ s: GameState) -> some View {
        if let chip {
            HStack(alignment: .center, spacing: 12) {
                Photo(key: chip.image).frame(width: 64, height: 44).clipShape(.rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(chip.name).font(.headline)
                    Text("\(Fmt.tflops(chip.best)) \(chip.bestPrecisionLabel) · \(Fmt.memory(chip.memoryGB)) · \(Int(chip.tdpW)) W · \(Fmt.money(chip.price ?? 0)) to make")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                let n = AlienFabCard.suggestedOrder(chip.id, s)
                if n > 0 {
                    Button("Order \(Fmt.count(Double(n)))") { store.act("Order queued on your fab line") { $0.orderOwnChips(chip.id, count: n) } }
                        .buttonStyle(.borderedProminent)
                        .help("Arrives in about \(AlienFab.leadDays(s, count: n)) days from your alien fab line.")
                } else {
                    Button("Lease a cage") { store.act("Cage leased — ready in 30 days") { $0.leaseAlienCage(for: chip.id, chips: max(4_000, AlienFabCard.suggestedOrder(chip.id, s, ignoringSites: true))) } }
                        .help("No site has free power for these chips. Lease a colocation cage sized for them (ready in 30 days).")
                }
                Button("In the store") { store.focusAccelID = chip.id; store.open(.hardware) }
                    .buttonStyle(.link)
            }
        } else if a.fabbing {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Taping out the \(a.name) chip").font(.callout.weight(.semibold))
                    if a.fabRespins > 0 { Pill(text: "\(a.fabRespins) respin\(a.fabRespins == 1 ? "" : "s")", color: .orange) }
                    Spacer()
                    Text("~\(Int(a.fabDaysLeft / 30) + 1) months left").font(.caption.monospacedDigit())
                }
                Meter(value: 1 - a.fabDaysLeft / max(1, a.fabTotal > 0 ? a.fabTotal : Xeno.fabDays(s, store.derived.bonuses)), tint: .purple, height: 8)
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("The chip exists only as RTL").font(.callout.weight(.semibold))
                    Text("Tape it out for \(Fmt.money(Xeno.fabCost(s))) — about \(Int(Xeno.fabDays(s, store.derived.bonuses) / 30) + 1) months. A chip-design swarm makes it faster; the better you understand it, the fewer respins.\(s.alienFab.exists ? "" : " Your first alien chip opens your own fab line.")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Tape out") { store.act("Tape-out started") { $0.fabAlienChip(a.id) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(Xeno.fabCost(s) > s.cash)
                    .help(Xeno.fabCost(s) > s.cash ? "Needs \(Fmt.money(Xeno.fabCost(s))) in cash." : "Send the swarm's RTL to the foundry.")
            }
        }
    }

    @ViewBuilder
    private func licensing(_ a: AlienArch, _ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Licensing").font(.headline)
            if a.offers.isEmpty && a.policy == .license {
                Text("Waiting for offers — big players come to you over the next few months.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(a.offers) { o in
                HStack {
                    Image(systemName: BigPlayerCatalog.isRival(o.buyerID) ? "flag.2.crossed.fill" : "building.2.fill")
                        .foregroundStyle(BigPlayerCatalog.isRival(o.buyerID) ? .orange : .teal)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(o.buyerName).font(.callout.weight(.semibold))
                        Text("\(Fmt.money(o.upfront)) upfront + \(Fmt.money(o.royaltyMonthly))/month for \(o.monthsLeft) months\(BigPlayerCatalog.isRival(o.buyerID) ? " · a rival lab: their models get stronger" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let exp = o.expires { Text("expires \(exp.gameShort)").font(.caption).foregroundStyle(.tertiary) }
                    Button("Decline") { store.mutate { $0.declineLicense(a.id, offer: o.id) } }
                    Button("Accept") { store.act("License signed") { $0.acceptLicense(a.id, offer: o.id) } }
                        .buttonStyle(.borderedProminent)
                }
            }
            if !a.licenses.isEmpty {
                Text("Licensees").font(.caption.weight(.semibold)).padding(.top, 4)
                ForEach(a.licenses) { l in
                    HStack {
                        Text(l.buyerName).font(.callout)
                        Spacer()
                        Text(l.monthsLeft > 0 ? "\(Fmt.money(l.royaltyMonthly))/mo · \(l.monthsLeft) mo left" : "Royalties ended")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(l.effective <= s.date ? "In use" : "Integrating until \(l.effective.gameShort)")
                            .font(.caption).foregroundStyle(l.effective <= s.date ? .orange : .secondary)
                            .frame(width: 190, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct ArmedRival: Identifiable {
    let id: String
    let name: String
    let color: UInt32
    let gain: Double
}

private struct ArmedRivalsCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let armed = s.competitors.map { ArmedRival(id: $0.id, name: $0.def.name, color: $0.def.color, gain: Xeno.rivalC(s, $0.id, at: s.date)) }
            .filter { $0.gain > 0.005 }.sorted { $0.gain > $1.gain }
        Card {
            CardHeader("Rivals running on your tech", symbol: "flag.2.crossed.fill", subtitle: "Capability they gained from your licenses and chips")
            if armed.isEmpty {
                Text("None. Everything you found is still yours.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(armed) { r in
                    HStack {
                        Circle().fill(Theme.competitorColor(r.color)).frame(width: 10, height: 10)
                        Text(r.name).font(.callout.weight(.semibold))
                        Spacer()
                        Text("+\(Fmt.trim(r.gain, 2)) capability (×\(Fmt.trim(pow(10, r.gain), 2)) compute)").font(.callout.monospacedDigit()).foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

private struct XenoStat: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        MetricTile(label: label, value: value, symbol: symbol, tint: tint)
    }
}
