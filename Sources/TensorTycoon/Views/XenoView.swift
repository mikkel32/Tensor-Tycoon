import SwiftUI

struct XenoView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        Page(title: "Alien Tech", subtitle: "Architectures your agents found where no human would look: a model design worth several times the training compute, and a chip that costs a few percent of an NVIDIA part to make. Keep it, sell the chips, or license the blueprint.") {
            HeroBanner(image: "wafer_closeup", height: 160) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alien architectures").font(.title.weight(.bold))
                    Text(s.alienArchs.isEmpty ? "None found yet." : "\(s.alienArchs.count) discovered · moat worth \(Fmt.money(Xeno.moatValue(s))) to investors")
                        .font(.callout).opacity(0.9)
                }
            }
            XenoProgressCard(state: s)
            if s.alienArchs.isEmpty {
                Card {
                    EmptyStateView(symbol: "atom", title: "Nothing alien yet",
                                   message: "Point an agent swarm at \"Alien architecture search\" (needs Agentic RL and a near-frontier model), or run a self-improvement run on Architecture search. Bigger swarms of smarter agents find it faster.",
                                   actionTitle: "Agent Swarms") { store.open(.swarms) }
                }
            } else {
                ForEach(s.alienArchs.reversed()) { a in AlienArchCard(arch: a, state: s) }
                ArmedRivalsCard(state: s)
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
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
                Button("Order for yourself") { store.open(.hardware) }
                    .buttonStyle(.borderedProminent)
            }
        } else if a.fabbing {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Taping out the \(a.name) chip").font(.callout.weight(.semibold))
                    if a.fabRespins > 0 { Pill(text: "\(a.fabRespins) respin\(a.fabRespins == 1 ? "" : "s")", color: .orange) }
                    Spacer()
                    Text("~\(Int(a.fabDaysLeft / 30) + 1) months left").font(.caption.monospacedDigit())
                }
                Meter(value: 1 - a.fabDaysLeft / max(1, Xeno.fabDays(s, store.derived.bonuses)), tint: .purple, height: 8)
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("The chip exists only as RTL").font(.callout.weight(.semibold))
                    Text("Tape it out for \(Fmt.money(Xeno.fabCost(s))) — about \(Int(Xeno.fabDays(s, store.derived.bonuses) / 30) + 1) months. A chip-design swarm makes it faster.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Tape out") { store.act("Tape-out started") { $0.fabAlienChip(a.id) } }
                    .buttonStyle(.borderedProminent)
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
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: symbol).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))
    }
}
