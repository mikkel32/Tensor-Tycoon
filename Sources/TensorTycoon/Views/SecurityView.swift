import SwiftUI

struct SecurityView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        Page(title: "Security & Policy", subtitle: "Protect the weights that make you valuable, and shape the laws that govern you. Security levels follow RAND's SL1–SL5 framework for securing frontier model weights.") {
            HeroBanner(image: "network", height: 150) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security level \(s.security.title)").font(.title.weight(.bold))
                        Text("Stops: \(s.security.stops.lowercased()) · \(s.attacksFoiled) attacks foiled · \(s.thefts) theft\(s.thefts == 1 ? "" : "s")")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Political capital").font(.caption).opacity(0.8)
                        Text("\(Int(s.politicalCapital))").font(.system(size: 34, weight: .bold).monospacedDigit())
                    }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                SecurityCard(state: s)
                ThreatCard(state: s)
            }
            LobbyCard(state: s)
            BillsCard(state: s)
        }
    }
}

private struct SecurityCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let next = SecurityLevel(rawValue: s.security.rawValue + 1)
        let upgrading = s.securityTarget > s.security.rawValue
        Card {
            CardHeader(title: "Weight security", symbol: "lock.shield.fill", subtitle: "Each level stops a more capable attacker — and costs more to run and work behind") { HelpButton(term: .securityLevels) }
            ForEach(SecurityLevel.allCases) { level in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: level <= s.security ? "checkmark.shield.fill" : (upgrading && level.rawValue == s.securityTarget ? "hammer.fill" : "shield"))
                        .foregroundStyle(level <= s.security ? .green : (upgrading && level.rawValue == s.securityTarget ? .orange : .secondary))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(level.title) — stops \(level.stops.lowercased())").font(.callout.weight(level == s.security ? .bold : .regular))
                        Text("Attacker: \(level.attacker)").font(.caption2).foregroundStyle(.tertiary)
                        Text(level.measures).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Fmt.money(SecurityOps.upkeep(level, s)))/mo").font(.caption.monospacedDigit())
                        if level.friction > 0 { Text("−\(Int(level.friction * 100))% research").font(.caption2).foregroundStyle(.orange) }
                    }
                }
            }
            Divider()
            if upgrading {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Building SL\(s.securityTarget): about \(Int(s.securityDaysLeft / 30.4) + 1) months left").font(.callout.weight(.semibold))
                    let total = Double(SecurityLevel(rawValue: s.securityTarget)?.upgradeMonths ?? 1) * 30.4
                    Meter(value: 1 - s.securityDaysLeft / max(1, total), tint: .orange, height: 8)
                }
            } else if let next {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to \(next.title)").font(.callout.weight(.semibold))
                        Text("\(Fmt.money(SecurityOps.upgradeCost(next, s))) and about \(next.upgradeMonths) months. Costs scale with your headcount and sites\(SecurityOps.discount(s) > 0 ? "; research saves you \(Int(SecurityOps.discount(s) * 100))%" : "").")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Start upgrade") { store.act("Security programme started") { $0.upgradeSecurity() } }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Text("You run the most secure AI lab on Earth.").font(.callout).foregroundStyle(.secondary)
            }
            Text("Levels and attacker profiles from RAND's \"Securing AI Model Weights\" (2024). RAND puts no price on defence; the costs here are estimates.")
                .font(.caption2).foregroundStyle(.tertiary)
            if s.security > .sl1 && !upgrading {
                Button("Relax to SL\(s.security.rawValue - 1)") { store.act("Security relaxed") { $0.downgradeSecurity() } }
                    .buttonStyle(.link).font(.caption)
            }
        }
    }
}

private struct ThreatCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let a = SecurityOps.attractiveness(s)
        Card {
            CardHeader("Threat assessment", symbol: "eye.trianglebadge.exclamationmark", subtitle: "Attackers want your weights as much as your best model is worth")
            HStack {
                Text("Value of your weights to attackers").font(.caption.weight(.semibold))
                Spacer()
                Text(a < 0.4 ? "Low" : (a < 1.0 ? "Moderate" : (a < 1.6 ? "High" : "Extreme"))).font(.caption.weight(.bold))
                    .foregroundStyle(a < 0.4 ? .green : (a < 1.0 ? .yellow : .red))
            }
            Meter(value: a / 2.2, tint: a < 1 ? .yellow : .red, height: 8)
            ForEach(SecurityOps.threats(s)) { t in
                HStack {
                    Image(systemName: s.security.rawValue >= t.tier ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(s.security.rawValue >= t.tier ? .green : .orange)
                        .frame(width: 20)
                    Text(t.who).font(.callout)
                    Spacer()
                    Text(t.monthlyChance > 0 ? "\(Fmt.trim(t.monthlyChance * 100, 1))%/mo" : "—").font(.caption.monospacedDigit())
                    Text(s.security.rawValue >= t.tier ? "blocked" : "can get in").font(.caption).foregroundStyle(s.security.rawValue >= t.tier ? .green : .orange)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            Text("Leaked weights undercut your API with free copies. Stolen weights put a rival on your level. Losing a model above the High capability line also brings penalties. Better containment also lowers the odds that an escaping model or swarm gets out.")
                .font(.caption2).foregroundStyle(.tertiary)
            if !s.stolenC.isEmpty {
                Text("Labs running your stolen weights: \(s.stolenC.keys.compactMap { CompetitorCatalog.byID[$0]?.name }.sorted().joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }
}

private struct LobbyCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var budgetLog = 5.0
    @State private var loaded = false

    var body: some View {
        let s = state
        let budget = budgetLog <= 4.01 ? 0 : (pow(10, budgetLog) / 1000).rounded() * 1000
        Card {
            CardHeader(title: "Government relations", symbol: "building.columns.fill", subtitle: "Lobbying builds political capital: better odds on bills, smaller fines, easier antitrust reviews") { HelpButton(term: .politicalCapital) }
            HStack {
                Text("Monthly lobbying")
                Slider(value: $budgetLog, in: 4...8)
                Text(budget > 0 ? "\(Fmt.money(budget))/mo" : "None").font(.callout.monospacedDigit().weight(.semibold)).frame(width: 100, alignment: .trailing)
                Button("Set") { store.mutate { $0.setLobbyBudget(budget) }; store.show(budget > 0 ? "Lobbying \(Fmt.money(budget))/mo" : "Lobbying stopped") }
            }
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Political capital \(Int(s.politicalCapital))/100").font(.caption.weight(.semibold))
                    Meter(value: s.politicalCapital / 100, tint: .purple, height: 8)
                    Text("Decays 5% a month; spending more has diminishing returns.").font(.caption2).foregroundStyle(.tertiary)
                    Text("For scale: in 2025 Meta spent $26M on federal lobbying, NVIDIA $4.9M, Anthropic $3.1M and OpenAI $3.0M. AI super PACs had put $43M into congressional races by June 2026.")
                        .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    SpecRow(label: "Fines & settlements", value: "×\(Fmt.trim(Policy.fineFactor(s), 2))")
                    SpecRow(label: "Current spend", value: s.lobbyBudget > 0 ? "\(Fmt.money(s.lobbyBudget))/mo" : "None")
                }
                .frame(width: 280)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            budgetLog = s.lobbyBudget > 0 ? log10(s.lobbyBudget) : 4
        }
    }
}

private struct BillsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("AI legislation", symbol: "doc.text.magnifyingglass", subtitle: "Pick a side on each bill here or when it arrives; the vote comes about four months later")
            if s.bills.isEmpty {
                Text("No bills pending. New ones arrive in your inbox; their vote dates show under Coming up on the dashboard.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(s.bills) { b in
                if let bill = PolicyCatalog.byID[b.id] {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "doc.text.fill").foregroundStyle(Color.accentColor).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.title).font(.callout.weight(.semibold))
                            Text(bill.summary).font(.caption).foregroundStyle(.secondary)
                            Text("If it passes: \(bill.ifPasses)").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Picker("Your stance", selection: Binding(get: { b.stance }, set: { v in store.act { $0.setBillStance(b.id, v) } })) {
                                Text("Back").tag(1)
                                Text("Stay out").tag(0)
                                Text("Oppose").tag(-1)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 210)
                            .help("Taking a side costs 5 political capital; stepping back costs 2; switching sides also costs brand.")
                            Text("\(Int(clamp(Policy.passChance(bill, stance: b.stance, s) + b.boost, 0.05, 0.95) * 100))% to pass · vote \(b.vote.gameShort)").font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            if !s.lawsPassed.isEmpty || !s.lawsFailed.isEmpty {
                Divider()
                Text("Laws in force").font(.caption.weight(.semibold))
                ForEach(s.lawsPassed.sorted(), id: \.self) { id in
                    if let bill = PolicyCatalog.byID[id] {
                        Label("\(bill.title): \(bill.ifPasses)", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(s.lawsFailed.sorted(), id: \.self) { id in
                    if let bill = PolicyCatalog.byID[id] {
                        Label("\(bill.title) failed: \(bill.ifFails)", systemImage: "xmark.seal").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
