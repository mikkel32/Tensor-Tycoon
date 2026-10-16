import SwiftUI

struct StrategyView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        Page(title: "Strategy & Traits", subtitle: "Who your lab is: the doctrine you founded it on, your own background, the culture you build with culture points — and the board that judges you.") {
            HeroBanner(image: "sf_skyline", height: 150) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(s.doctrine.title, systemImage: s.doctrine.symbol).font(.title.weight(.bold))
                        Text("\(s.background.title) founder · \(s.perks.count) culture perk\(s.perks.count == 1 ? "" : "s") · board \(Board.mood(s.boardConfidence).lowercased())")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Culture points").font(.caption).opacity(0.8)
                        Text("\(s.culturePoints)").font(.system(size: 34, weight: .bold).monospacedDigit())
                        Text("Earned from achievements, board goals and anniversaries").font(.caption2).opacity(0.8)
                    }
                }
            }

            HStack(alignment: .top, spacing: 16) {
                Card {
                    CardHeader("Doctrine", symbol: s.doctrine.symbol, subtitle: s.doctrine.tagline)
                    TraitLines(pros: s.doctrine.pros, cons: s.doctrine.cons)
                }
                Card {
                    CardHeader("Founder: \(s.founderName)", symbol: s.background.symbol, subtitle: s.background.title)
                    Text(s.background.blurb).font(.caption).foregroundStyle(.secondary)
                    TraitLines(pros: s.background.perks, cons: [])
                }
                BoardCard(state: s)
            }

            ObjectivesCard(state: s)
            CultureTree(state: s)
            TraitEffectsCard(traits: s.traits)
        }
    }
}

private struct TraitLines: View {
    let pros: [String]
    let cons: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(pros, id: \.self) { p in Label(p, systemImage: "plus.circle.fill").font(.caption).foregroundStyle(.green) }
            ForEach(cons, id: \.self) { c in Label(c, systemImage: "minus.circle.fill").font(.caption).foregroundStyle(.orange) }
            if pros.isEmpty && cons.isEmpty { Text("No special effects.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct BoardCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let c = s.boardConfidence
        let tint: Color = c >= 60 ? .green : (c >= 35 ? .yellow : .red)
        Card {
            CardHeader("Board of directors", symbol: "person.3.fill", subtitle: s.founderControls ? "You hold a majority — they can't remove you" : "Investors control the board")
            HStack {
                Text("Confidence").font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(c))/100 · \(Board.mood(c))").font(.caption.monospacedDigit()).foregroundStyle(tint)
            }
            Meter(value: c / 100, tint: tint, height: 8)
            SpecRow(label: "Effect on round pricing", value: "×\(Fmt.trim(Board.valuationFactor(s), 2))")
            SpecRow(label: "Your stake", value: Fmt.pct(s.founderStake))
            SpecRow(label: "Goals met / missed", value: "\(s.objectivesCompleted) / \(s.objectivesFailed)")
            if !s.founderControls && c < 30 {
                Label("Below 20 confidence the board may move to replace you.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            Text("Confidence follows revenue growth, how close you are to the frontier and your runway. Hitting goals helps most.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

private struct ObjectivesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let active = s.objectives.filter { !$0.done && !$0.failed }
        let closed = s.objectives.filter { $0.done || $0.failed }.suffix(5).reversed()
        Card {
            CardHeader("Board goals", symbol: "flag.checkered", subtitle: "Hit them for a milestone tranche, culture points and board confidence. Checked at month end.")
            if active.isEmpty {
                Text("The board will set new goals at the end of the month.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(active) { o in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: o.kind.symbol).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(o.title).font(.callout.weight(.semibold))
                        Text("\(o.detail) Due \(o.deadline.gameShort).").font(.caption).foregroundStyle(.secondary)
                        Meter(value: Board.progress(o, s), tint: .accentColor, height: 6)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(Fmt.money(o.rewardCash))").font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(.green)
                        Text("+\(o.rewardPoints) CP · +\(Int(o.rewardConfidence)) confidence").font(.caption2).foregroundStyle(.secondary)
                        Button("Ask for another") { store.act("New goal set") { $0.rerollObjective(o.id) } }
                            .buttonStyle(.link).font(.caption)
                            .help("Costs 4 board confidence.")
                    }
                    .frame(width: 200, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
            if !closed.isEmpty {
                Divider()
                ForEach(Array(closed)) { o in
                    HStack {
                        Image(systemName: o.done ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(o.done ? .green : .red)
                        Text(o.title).font(.caption)
                        Spacer()
                        Text(o.deadline.gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

private struct CultureTree: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("Culture", symbol: "theatermasks.fill", subtitle: "Spend culture points on perks. Each branch unlocks in order; tier N costs N points. \(s.culturePoints) available.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 6), spacing: 10) {
                ForEach(CultureBranch.allCases) { branch in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(branch.rawValue, systemImage: branch.symbol).font(.headline)
                        ForEach(CultureCatalog.all.filter { $0.branch == branch }) { p in
                            PerkTile(perk: p, state: s)
                        }
                    }
                }
            }
        }
    }
}

private struct PerkTile: View {
    @Environment(GameStore.self) private var store
    let perk: CulturePerk
    let state: GameState

    var body: some View {
        let s = state
        let owned = s.perks.contains(perk.id)
        let prev = CultureCatalog.all.first { $0.branch == perk.branch && $0.tier == perk.tier - 1 }
        let unlocked = prev.map { s.perks.contains($0.id) } ?? true
        let affordable = s.culturePoints >= perk.cost
        Button {
            store.act("Adopted \(perk.name)") { $0.adoptPerk(perk.id) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tier \(perk.tier)").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Spacer()
                    if owned {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    } else if !unlocked {
                        Image(systemName: "lock.fill").foregroundStyle(.secondary)
                    } else {
                        Text("\(perk.cost) CP").font(.caption2.weight(.bold)).foregroundStyle(affordable ? Color.accentColor : .secondary)
                    }
                }
                Text(perk.name).font(.callout.weight(.semibold)).lineLimit(2, reservesSpace: true)
                Text(perk.effect).font(.caption2).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(owned ? Color.green.opacity(0.12) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(owned ? Color.green.opacity(0.6) : (unlocked && affordable ? Color.accentColor.opacity(0.6) : .clear), lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(owned || !unlocked)
        .opacity(owned || unlocked ? 1 : 0.55)
    }
}

private struct TraitEffectsCard: View {
    let traits: TraitBonuses

    /// Effects where a negative number is good news.
    private static let lowerIsBetter: Set<String> = ["Hardware & rentals", "Lead times", "Power costs", "Loss spikes", "Alignment drift",
                                                     "Payroll", "Fines & settlements", "Loan rates"]

    var body: some View {
        let rows = TraitEffectsCard.rows(traits)
        Card {
            CardHeader("All trait effects", symbol: "list.bullet.rectangle", subtitle: "Doctrine + background + culture, combined")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], alignment: .leading, spacing: 4) {
                ForEach(rows, id: \.name) { r in
                    HStack {
                        Text(r.name).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(r.value).font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(r.value.hasPrefix("−") && !TraitEffectsCard.lowerIsBetter.contains(r.name) ? Color.orange : Color.primary)
                    }
                }
            }
        }
    }

    struct Row {
        let name: String
        let value: String
    }

    static func rows(_ t: TraitBonuses) -> [Row] {
        var out: [Row] = []
        func add(_ name: String, _ value: String) { if !value.isEmpty { out.append(Row(name: name, value: value)) } }
        func pct(_ v: Double) -> String {
            guard abs(v) > 0.0001 else { return "" }
            return "\(v > 0 ? "+" : "−")\(Int((abs(v) * 100).rounded()))%"
        }
        func num(_ v: Double, _ suffix: String = "", digits: Int = 1) -> String {
            guard abs(v) > 0.0001 else { return "" }
            return "\(v > 0 ? "+" : "−")\(Fmt.trim(abs(v), digits))\(suffix)"
        }
        add("Research speed", pct(t.rp))
        add("Frontier research", pct(t.frontierRP))
        add("Founder research", num(t.founderRP, " researcher"))
        add("Effective training compute", t.algo != 0 ? "×\(Fmt.trim(pow(10, t.algo), 2))" : "")
        add("Hardware & rentals", pct(-t.hardware))
        add("Lead times", pct(-t.leadTime))
        add("Vendor allocation", pct(t.allocation))
        add("Training MFU", num(t.mfu * 100, " pts", digits: 0))
        add("Power costs", pct(-t.power))
        add("Loss spikes", pct(-t.spikes))
        add("Safety", num(t.safety, digits: 0))
        add("Alignment drift", pct(-t.drift))
        add("Consumer demand", pct(t.consumer))
        add("API demand", pct(t.api))
        add("Enterprise deals", pct(t.enterprise))
        add("Agent seats", pct(t.agentSeats))
        add("Brand / month", num(t.brand))
        add("Open-weights brand", pct(t.openBrand))
        add("Round valuations", pct(t.valuation))
        add("Payroll", pct(t.payroll))
        add("Hiring skill", num(t.hiring, digits: 0))
        add("Chip design speed", pct(t.chipDesign))
        add("Chip-sales demand", pct(t.chipSales))
        add("Agent quality", pct(t.swarm))
        add("Swarm coordination", num(t.coordination, digits: 2))
        add("Alien insight", pct(t.insight))
        add("Digital-workforce market", pct(t.labor))
        add("Self-improvement gains", pct(t.rsi))
        add("Loan rates", num(-t.loanRate, " pts"))
        add("Cash yield", num(t.yield, " pts"))
        add("Fines & settlements", pct(-t.fines))
        add("Board confidence / month", num(t.confidence))
        return out
    }
}
