import Charts
import SwiftUI

struct MarketView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let snap = store.derived.snapshot
        Page(title: "Market & Products", subtitle: "Four ways to make money: a consumer chat app, an API priced per token, coding/computer-use agents sold per seat, and enterprise contracts.", screen: .market) {
            ScreenHint(.market)
            KPIRow(minWidth: 200) {
                StatTile(title: "AI model market", value: "\(Fmt.money(snap.marketSize))/yr", detail: "All providers, all segments", symbol: "globe", tint: .blue)
                StatTile(title: "API demand", value: "\(Fmt.count(snap.apiTokenPool))/day", detail: "Tokens across the industry", symbol: "bolt.horizontal.fill", tint: .teal)
                StatTile(title: "Chat users worldwide", value: Fmt.count(snap.consumerUsersPool), detail: s.chatMoment == nil ? "The consumer boom hasn't started" : "Weekly actives", symbol: "person.3.fill", tint: .pink)
                StatTile(title: "Hype index", value: Fmt.trim(s.market.hype, 2), detail: "Investor & customer sentiment", symbol: "flame.fill", tint: .orange)
                StatTile(title: "Frontier API price", value: "\(Fmt.price(Macro.frontierPrice(s.year) * s.market.apiPricePressure))/M", detail: "Blended input/output", symbol: "tag.fill", tint: .purple)
            }

            HStack(alignment: .top, spacing: 16) {
                ChatProductCard(state: s)
                Card {
                    CardHeader("Marketing", symbol: "megaphone.fill", subtitle: "Brand drives every segment")
                    HStack {
                        Text("Monthly budget")
                        Spacer()
                        Text(Fmt.money(s.marketingBudget)).font(.headline.monospacedDigit())
                    }
                    Slider(value: Binding(get: { log10(max(s.marketingBudget, 1)) }, set: { v in store.mutate { $0.marketingBudget = v < 3.05 ? 0 : pow(10, v) } }),
                           in: 3...9)
                    Text("Brand \(Int(s.brand))/100. Brand grows with users, revenue, leaderboard wins and marketing, and decays slowly.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    SpecRow(label: "Reliability (served/demanded)", value: Fmt.pct(s.reliability, decimals: 0))
                    SpecRow(label: "Safety score", value: "\(Int(s.safetyScore))/100")
                }
                .frame(width: 380)
            }

            HStack(alignment: .top, spacing: Theme.gap) {
                AgentProductCard(state: s, seatPool: snap.agentSeatsPool)
                ShareChart(title: "Agent seat share", products: snap.agents, state: s)
                    .frame(width: 420)
            }

            CardGrid(minWidth: 340, maxColumns: 2) {
                ShareChart(title: "API token share", products: snap.api, state: s)
                ShareChart(title: "Chat app share", products: snap.consumer, state: s)
            }

            HStack(alignment: .top, spacing: Theme.gap) {
                APISegmentsCard(state: s, snap: snap)   // 3.8
                MarketMovesCard(state: s)
                    .frame(width: 380)
            }

            DealsCard(state: s)

            Card {
                CardHeader("API price list", symbol: "list.number", subtitle: "What the market sees today")
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        Text("Product").font(.caption.weight(.semibold))
                        Text("Lab").font(.caption.weight(.semibold))
                        Text("Quality gap").font(.caption.weight(.semibold))
                        Text("$/1M").font(.caption.weight(.semibold))
                        Text("Tok/s").font(.caption.weight(.semibold))
                        Text("Share").font(.caption.weight(.semibold))
                    }
                    ForEach(snap.api.sorted { $0.share > $1.share }.prefix(16)) { p in
                        GridRow {
                            Text(p.name).fontWeight(p.isPlayer ? .bold : .regular)
                            Text(p.labName).foregroundStyle(.secondary)
                            Text(Fmt.trim(p.c - Macro.frontier(s.year), 2)).monospacedDigit()
                            Text(Fmt.price(p.price)).monospacedDigit()
                            Text("\(Int(p.tps))").monospacedDigit()
                            Text(Fmt.pct(p.share)).monospacedDigit()
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }
}

private struct ChatProductCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let chatModels = s.releasedModels.filter { $0.design.instruct }
        let wtp = Market.chatWTP(s)
        let conv = Market.paidConversion(price: s.chatPrice, freeTier: s.freeTier, wtp: wtp)
        Card {
            CardHeader("\(s.companyName) Chat", symbol: "bubble.left.and.bubble.right.fill", subtitle: "Consumer subscription app")
            if chatModels.isEmpty {
                NextStep("Release an instruction-tuned model to launch a chat app.", action: "Models & Serving", screen: .models)
            } else {
                Picker("Powered by", selection: Binding(get: { s.chatModelID }, set: { id in store.mutate { $0.chatModelID = id } })) {
                    Text("Not launched").tag(UUID?.none)
                    ForEach(chatModels) { m in Text("\(m.name) (index \(Fmt.score(store.derived.entry(m.id)?.index ?? m.index)))").tag(UUID?.some(m.id)) }
                }
                HStack {
                    Text("Subscription")
                    Slider(value: Binding(get: { s.chatPrice }, set: { v in store.mutate { $0.chatPrice = (v).rounded() } }), in: 5...200, step: 1)
                    Text("$\(Int(s.chatPrice))/mo").font(.headline.monospacedDigit()).frame(width: 80, alignment: .trailing)
                        .help("Users would pay about $\(Int(wtp))/month for this app. Revenue peaks near that price; above it, paying users fall away fast.")
                }
                Toggle("Free tier (more users, much more compute)", isOn: Binding(get: { s.freeTier }, set: { v in store.mutate { $0.freeTier = v } }))
                    .toggleStyle(.switch)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    MiniStat(label: "Weekly users", value: Fmt.count(s.consumerUsers))
                    MiniStat(label: "Paying", value: "\(Fmt.count(s.paidUsers)) (\(Fmt.pct(conv)))")
                    MiniStat(label: "Revenue / mo", value: Fmt.money(s.paidUsers * s.chatPrice))
                    MiniStat(label: "Market share", value: Fmt.pct(s.consumerShare))
                    MiniStat(label: "Tokens / user / day", value: Fmt.count(Macro.tokensPerUserDay(s.year)))
                    MiniStat(label: "Requests served", value: Fmt.pct(s.consumerServedFraction, decimals: 0))
                }
                if s.chatMoment == nil {
                    Label("Consumer AI hasn't taken off yet. A chat model at GPT-3.5 level with RLHF could start the boom early.", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct AgentProductCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let seatPool: Double

    var body: some View {
        let s = state
        let b = store.derived.bonuses
        let eligible = s.releasedModels.filter { $0.design.toolUse && !$0.retired }
        // Seats beyond what today's price supports aren't billed: revenue is what this month actually collected, run-rated.
        let days = max(1, GameCalendar.components(s.date).day)
        let monthly = s.month.revAgents / Double(days) * 30.4
        let worth = Market.agentWTP(s)
        Card {
            CardHeader("\(s.companyName) Agent", symbol: "terminal.fill", subtitle: "Coding & computer-use agents, sold per seat (think Claude Code, Codex, Cursor)")
            if !b.has(.toolUse) {
                Label("Research Tool Use to build agent products. The agent market opens around 2025.", systemImage: "lock.fill")
                    .font(.callout).foregroundStyle(.secondary)
            } else if eligible.isEmpty {
                NextStep("Release a model trained with tool use enabled (Model Lab → Capabilities) to launch an agent.", action: "Open Model Lab", screen: .lab)
            } else {
                Picker("Powered by", selection: Binding(get: { s.agentModelID }, set: { id in store.mutate { $0.agentModelID = id } })) {
                    Text("Not launched").tag(UUID?.none)
                    ForEach(eligible) { m in
                        Text("\(m.name) (horizon \(BenchmarkCatalog.formatHorizon(BenchmarkCatalog.taskHorizonMinutes(Leaderboard.profile(m)))))").tag(UUID?.some(m.id))
                    }
                }
                HStack {
                    Text("Seat price")
                    Slider(value: Binding(get: { log10(max(s.agentPrice, 10)) }, set: { v in store.mutate { $0.agentPrice = (pow(10, v) / 5).rounded() * 5 } }), in: 1.3...3.3)
                    Text("$\(Int(s.agentPrice))/mo").font(.headline.monospacedDigit()).frame(width: 90, alignment: .trailing)
                        .help(worth.map { "A seat of your agent is worth about $\(Int($0))/month to buyers: the wage of the work it does. Revenue plateaus around there." } ?? "Pick the model that powers your agent product.")
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    MiniStat(label: "Seats", value: Fmt.count(s.agentSeats))
                    MiniStat(label: "Seat share", value: Fmt.pct(s.agentShare))
                    MiniStat(label: "Revenue / mo", value: Fmt.money(monthly))
                    MiniStat(label: "Seats worldwide", value: Fmt.count(seatPool))
                    MiniStat(label: "Tokens / seat / day", value: Fmt.count(Macro.tokensPerSeatDay(s.year)))
                    MiniStat(label: "Tokens / day", value: Fmt.count(s.agentSeats * Macro.tokensPerSeatDay(s.year)))
                }
                Text("Agents are judged on agentic skill — SWE-bench, Terminal-Bench, OSWorld and long task horizons — not chat quality. They burn a lot of tokens, so deploy enough inference chips or seats will churn.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MiniStat: View {
    let label: String
    let value: String
    var body: some View {
        MetricTile(label: label, value: value, style: .plain)
    }
}

private struct ShareChart: View {
    let title: String
    let products: [MarketProduct]
    let state: GameState

    var body: some View {
        var byLab: [String: (String, Double, Bool)] = [:]
        for p in products {
            let cur = byLab[p.lab] ?? (p.labName, 0, p.isPlayer)
            byLab[p.lab] = (cur.0, cur.1 + p.share, cur.2)
        }
        let other = max(0, 1 - byLab.values.reduce(0) { $0 + $1.1 })
        var rows = byLab.map { (lab: $0.value.0, share: $0.value.1, player: $0.value.2) }.sorted { $0.share > $1.share }
        if other > 0.001 { rows.append((lab: "Others", share: other, player: false)) }
        return Card {
            CardHeader(title, symbol: "chart.pie.fill")
            if products.isEmpty {
                Text("No products in this market yet.").font(.callout).foregroundStyle(.secondary).frame(height: 200)
            } else {
                HStack(spacing: 16) {
                    Chart(rows, id: \.lab) { r in
                        SectorMark(angle: .value("Share", r.share), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(color(r.lab, r.player))
                            .opacity(r.player ? 1 : 0.85)
                    }
                    .frame(width: 180, height: 180)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(rows.prefix(9), id: \.lab) { r in
                            HStack {
                                Circle().fill(color(r.lab, r.player)).frame(width: 8, height: 8)
                                Text(r.lab).fontWeight(r.player ? .bold : .regular).lineLimit(1)
                                Spacer()
                                Text(Fmt.pct(r.share)).monospacedDigit()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }
}

extension ShareChart {
    func color(_ lab: String, _ player: Bool) -> Color {
        if player { return Theme.logoColor(state.logoColor) }
        if let def = CompetitorCatalog.all.first(where: { $0.name == lab }) { return Theme.competitorColor(def.color) }
        return .gray.opacity(0.5)
    }
}

private struct DealsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    /// Picker tag for "no model".
    static let none = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    @State private var chosen: [UUID: UUID] = [:]

    var body: some View {
        let s = state
        let offers = s.deals.filter { !$0.active }
        let active = s.deals.filter(\.active)
        let models = s.releasedModels
        Card {
            CardHeader(title: "Enterprise", symbol: "briefcase.fill", subtitle: "Sales staff and brand bring in leads. Contracts reserve capacity on a model — breach the SLA and they walk.") { HelpButton(term: .sla) }
            if offers.isEmpty && active.isEmpty {
                NextStep(s.releasedModels.isEmpty ? "No enterprise leads yet. Leads come once you have a model released." : "No enterprise leads yet. Sales & Partnerships staff and a stronger brand bring them in.",
                         action: s.releasedModels.isEmpty ? "Models & Serving" : "Hire sales staff", screen: s.releasedModels.isEmpty ? .models : .team)
            }
            ForEach(offers) { d in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(d.client) — \(d.title)").font(.callout.weight(.semibold))
                        Text("\(Fmt.money(d.monthly))/mo × \(d.months) months · \(Fmt.count(d.tokensPerDay)) tokens/day · needs index ≥ \(Fmt.score(d.minIndex)), safety ≥ \(Int(d.minSafety)) · expires \(d.expires.gameShort)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Model", selection: Binding(get: { chosen[d.id] ?? models.max { $0.index < $1.index }?.id ?? UUID() }, set: { chosen[d.id] = $0 })) {
                        ForEach(models) { m in Text(m.name).tag(m.id) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    Button("Sign") {
                        guard let mid = chosen[d.id] ?? models.max(by: { $0.index < $1.index })?.id else { return }
                        store.act("Contract signed") { $0.acceptDeal(d.id, modelID: mid) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Decline") { store.mutate { $0.declineDeal(d.id) } }
                }
                Divider()
            }
            if !active.isEmpty {
                Text("Active contracts · \(Fmt.money(active.reduce(0) { $0 + $1.monthly }))/mo").font(.caption.weight(.semibold))
                ForEach(active) { d in
                    HStack {
                        Image(systemName: d.modelID == nil ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(d.modelID == nil ? .orange : .green)
                        Text("\(d.client) — \(d.title)").font(.callout)
                        if d.modelID == nil {
                            Text("no model meets its bar — it breaches daily").font(.caption).foregroundStyle(.orange)
                        }
                        Spacer()
                        Picker("Served by", selection: Binding(get: { d.modelID ?? DealsCard.none }, set: { id in
                            if id != DealsCard.none { store.act("Contract moved") { $0.reassignDeal(d.id, modelID: id) } }
                        })) {
                            if d.modelID == nil { Text("Pick a model…").tag(DealsCard.none) }
                            ForEach(models.filter { $0.index + 0.01 >= d.minIndex }) { m in Text(m.name).tag(m.id) }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        Text("\(Fmt.money(d.monthly))/mo · \(d.monthsLeft) months left\(d.breaches > 0 ? " · ⚠️ \(d.breaches) SLA misses" : "")")
                            .font(.caption.monospacedDigit()).foregroundStyle(d.breaches > 0 ? .orange : .secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 3.8: API segments and market moves

/// API buyers by kind of work: each segment's weight, your share of it and who leads it, so a specialist's pull shows.
private struct APISegmentsCard: View {
    let state: GameState
    let snap: MarketSnapshot

    var body: some View {
        let s = state
        let weights = APISegment.weights(s)
        let mine = Market.playerSegments(snap)
        Card {
            CardHeader("API segments", symbol: "square.grid.3x2.fill",
                       subtitle: "Buyers pick models on the domains their work needs: coding traffic goes to the best coder, not the best average.")
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Segment"); Text("Of API spend"); Text("Your share"); Text("Leader")
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(APISegment.allCases) { seg in
                    let leader = snap.api.filter { seg.rawValue < $0.segShares.count }.max { $0.segShares[seg.rawValue] < $1.segShares[seg.rawValue] }
                    GridRow {
                        Label(seg.label, systemImage: seg.symbol).font(.callout)
                        Text(Fmt.pct(weights[seg.rawValue], decimals: 0)).font(.callout.monospacedDigit())
                        HStack(spacing: 6) {
                            Text(Fmt.pct(mine[seg.rawValue], decimals: 1)).font(.callout.monospacedDigit())
                            Meter(value: mine[seg.rawValue], tint: Tone.accent.color, height: 5).frame(width: 60)
                        }
                        Text(leader.map { "\($0.name) (\($0.labName))" } ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Text("General work goes half by overall capability and half by knowledge, reasoning and conversation; the others by coding, agents and reliability, languages, or vision and voice. A 10-point edge in a segment's domains is 4.5× the pull. Multilingual demand follows where the world's AI money is (\(Fmt.pct(weights[APISegment.languages.rawValue], decimals: 0)) of API spending today).")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What launches leave behind: the developer ecosystem, investors' read of your rank, contracts won and lost.
private struct MarketMovesCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let mm = s.marketMoves
        Card {
            CardHeader("After launch", symbol: "arrow.triangle.branch", subtitle: "How the market keeps moving once a model ships")
            SpecRow(label: "Developer ecosystem", value: "\(Int(mm.devEcosystem.rounded()))/100 · API demand +\(Fmt.pct(Launches.ecosystemFactor(s) - 1, decimals: 1))")
            Meter(value: mm.devEcosystem / 100, tint: Tone.info.color, height: 6)
            Text("Developers build on near-frontier open weights, a big API share and good standing with them. It builds a tenth of the way each month and fades slowly when you stop feeding it.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            SpecRow(label: "Investor momentum", value: "\(mm.rankMomentum >= 0 ? "+" : "−")\(Fmt.trim(abs(mm.rankMomentum), 2)) (rank #\(mm.lastRank > 0 ? "\(mm.lastRank)" : "—"))",
                    tone: mm.rankMomentum > 0.05 ? .good : (mm.rankMomentum < -0.05 ? .bad : nil))
            SpecRow(label: "Leads won from rivals", value: "\(mm.leadsWon)")
            SpecRow(label: "Contracts lost at renewal", value: "\(mm.churned)", tone: mm.churned > 0 ? .warning : nil)
            if !mm.log.isEmpty {
                Divider()
                ForEach(mm.log.prefix(5), id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }
}
