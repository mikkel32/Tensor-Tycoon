import SwiftUI

// MARK: - New-game picker

/// Pick starting advantages from the founding-card catalog, within a points budget (or none in Sandbox and Genius).
struct FoundingKitPicker: View {
    @Binding var kit: [String]
    @Binding var mode: KitMode
    let difficulty: Difficulty
    var allowMoney = true
    @State private var category: KitCategory = .research

    var body: some View {
        let budget = FoundingKit.budget(difficulty)
        let spent = FoundingKit.cost(kit)
        let limited = mode == .standard
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Founding kit").font(.subheadline.weight(.semibold))
                Text("Starting advantages. Optional: an empty kit plays the classic game.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if limited {
                    Text("\(spent) / \(budget) points")
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(spent > budget ? .red : .green)
                } else {
                    Text("\(kit.count) card\(kit.count == 1 ? "" : "s")").font(.callout.weight(.semibold).monospacedDigit())
                }
                if !kit.isEmpty {
                    Button("Clear") { kit = [] }.buttonStyle(.link)
                }
            }
            HStack(spacing: 12) {
                Picker("Kit mode", selection: $mode) {
                    ForEach(KitMode.allCases) { m in Text(m.title).tag(m) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
                Text(mode.blurb).font(.caption).foregroundStyle(mode == .genius ? .purple : .secondary)
            }
            Picker("Category", selection: $category) {
                ForEach(KitCategory.allCases.filter { allowMoney || $0 != .money }) { c in Label(c.title, systemImage: c.symbol).tag(c) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 8)], spacing: 8) {
                ForEach(FoundingKit.all.filter { $0.category == category }) { card in
                    let chosen = kit.contains(card.id)
                    let affordable = !limited || chosen || spent + card.cost <= budget
                    Button {
                        if chosen { kit.removeAll { $0 == card.id } } else if affordable { kit.append(card.id) }
                    } label: {
                        FoundingCardTile(card: card, chosen: chosen, dimmed: !affordable)
                    }
                    .buttonStyle(.plain)
                    .disabled(!affordable)
                    .help(card.blurb)
                }
            }
            if !kit.isEmpty {
                Text("Chosen: " + FoundingKit.cards(kit).map(\.name).joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                let mult = FoundingKit.researchMultiplier(kit: kit, genius: mode == .genius)
                if mult > 1 {
                    Label("Research ×\(Fmt.trim(mult, 1))", systemImage: "bolt.fill").font(.caption.weight(.semibold)).foregroundStyle(.purple)
                }
            } else if mode == .genius {
                Label("Research ×\(Fmt.trim(FoundingKit.geniusMultiplier, 1))", systemImage: "bolt.fill").font(.caption.weight(.semibold)).foregroundStyle(.purple)
            }
        }
        .onAppear { if !allowMoney, category == .money { category = .research } }
        .onChange(of: allowMoney) { _, allowed in if !allowed, category == .money { category = .research } }
        .onChange(of: difficulty) { _, d in
            // A smaller budget drops the most recent picks until the kit fits.
            guard mode == .standard else { return }
            while FoundingKit.cost(kit) > FoundingKit.budget(d), !kit.isEmpty { kit.removeLast() }
        }
        .onChange(of: mode) { _, m in
            guard m == .standard else { return }
            while FoundingKit.cost(kit) > FoundingKit.budget(difficulty), !kit.isEmpty { kit.removeLast() }
        }
    }
}

/// One founding card: name, cost, what it gives and what it takes.
struct FoundingCardTile: View {
    let card: FoundingCard
    var chosen = false
    var dimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: card.symbol).foregroundStyle(chosen ? Color.accentColor : .secondary)
                Text(card.name).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                Text(card.cost >= 0 ? "\(card.cost) pt" : "+\(-card.cost) pt")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(card.isDrawback ? .orange : .secondary)
            }
            ForEach(card.pros, id: \.self) { p in
                Label(p, systemImage: "plus.circle.fill").font(.caption).foregroundStyle(.green)
            }
            ForEach(card.cons, id: \.self) { c in
                Label(c, systemImage: "minus.circle.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(chosen ? Color.accentColor.opacity(0.18) : Theme.insetFill, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(chosen ? Color.accentColor : .clear, lineWidth: 1.5))
        .opacity(dimmed ? 0.45 : 1)
        .contentShape(.rect)
    }
}

// MARK: - In game

/// The cards you founded the lab with, shown on the dashboard.
struct FoundingKitCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let cards = FoundingKit.cards(s.kit)
        let mult = FoundingKit.researchMultiplier(s)
        if !cards.isEmpty || mult > 1 {
            Card {
                CardHeader(title: "Your founding kit", symbol: "shippingbox.fill",
                           subtitle: s.kitMode == KitMode.genius.rawValue ? "Genius mode" : "\(cards.count) card\(cards.count == 1 ? "" : "s")") {
                    if mult > 1 { Pill(text: "Research ×\(Fmt.trim(mult, 1))", color: .purple, symbol: "bolt.fill") }
                }
                KitCardList(cards: cards)
                if s.rlLabLevel > 0 {
                    Label("RL lab level \(s.rlLabLevel) of \(FoundingKit.rlMaxLevel)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }
}

/// Compact list of founding cards (dashboard and era briefing).
struct KitCardList: View {
    let cards: [FoundingCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(cards) { card in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: card.symbol).foregroundStyle(card.isDrawback ? Color.orange : Color.accentColor).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.name).font(.callout.weight(.semibold))
                        Text((card.pros + card.cons).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// The RL lab on the Research page: its level, what it adds, and the next upgrade.
struct RLLabCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let level = s.rlLabLevel
        let mult = FoundingKit.researchMultiplier(s)
        Card {
            CardHeader(title: level > 0 ? "RL lab · level \(level) of \(FoundingKit.rlMaxLevel)" : "RL lab",
                       symbol: "arrow.triangle.2.circlepath",
                       subtitle: "Environments, reward models and the people who tune them. Sharpens reasoning and agents on every model you train.") {
                if mult > 1 { Pill(text: "Research ×\(Fmt.trim(mult, 1))", color: .purple, symbol: "bolt.fill") }
            }
            if level > 0 {
                Text("Now: " + FoundingKit.rlLabEffects(level: level).joined(separator: " · ")).font(.caption)
            }
            HStack {
                if level < FoundingKit.rlMaxLevel {
                    Text("Level \(level + 1): " + FoundingKit.rlLabEffects(level: level + 1).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Top level reached.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let cost = FoundingKit.rlLabCost(s) {
                    Button(level == 0 ? "Open RL lab (\(Fmt.money(cost)))" : "Upgrade (\(Fmt.money(cost)))") {
                        store.act(level == 0 ? "RL lab opened" : "RL lab upgraded") { $0.upgradeRLLab() }
                    }
                    .disabled(s.cash < cost)
                }
            }
        }
    }
}
