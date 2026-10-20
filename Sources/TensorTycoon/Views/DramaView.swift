import SwiftUI

// MARK: - 3.9: dramatic events on Events & Records

enum DramaStyle {
    static func tone(_ t: DramaTone) -> Tone {
        switch t {
        case .good: .good
        case .bad: .bad
        case .mixed: .neutral
        }
    }

    /// Lasting fixes an answer bought, in words.
    static let fixes: [(id: String, label: String, symbol: String)] = [
        ("fire_suppression", "Fire suppression", "flame.circle"),
        ("backup_power", "Backup power", "bolt.batteryblock"),
        ("priority_load", "Priority grid load", "powerplug"),
        ("ir_retainer", "Incident-response retainer", "lock.shield"),
        ("oncall", "On-call rotation", "person.badge.clock"),
        ("posting_policy", "Posting policy", "text.bubble"),
        ("watermarks", "Output watermarks", "seal"),
    ]

    static func followUpText(_ f: DramaFollowUp) -> String {
        let when = f.due.gameMonth
        switch f.kind {
        case "insurance": return "Insurance payout of about \(Fmt.money(f.amount)) (\(f.ref)), due around \(when)"
        case "trial": return "Copyright trial against \(f.ref.split(separator: "|").first.map(String.init) ?? "a publisher"): verdict around \(when)"
        case "celebrity": return "Your campaign with \(f.ref): the next headline lands around \(when)"
        case "clinical": return "Clinical pilot results around \(when)"
        default: return "Something lands around \(when)"
        }
    }
}

/// Headlines and crises: the dramatic events of this game, what you chose, and what came of it.
struct DramaCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var showAll = false

    var body: some View {
        let d = state.drama
        let seen = Set(d.log.map(\.event)).union(d.fired.keys)
        let pending = state.decisions.first { Drama.owns($0.kind) }
        Card {
            CardHeader("Headlines & crises", symbol: "flame.fill",
                       subtitle: "Fires, blackouts, leaks, lawsuits, scandals and lucky breaks — and how you answered. A few a year; ignored ones take the safe answer.")
            HStack(spacing: 8) {
                Pill(text: "\(d.count) this game", color: .orange, symbol: "bolt.fill")
                Pill(text: "\(d.answered) answered yourself", color: .blue, symbol: "hand.raised.fill")
                Pill(text: "\(seen.count) of \(Drama.catalog.count) kinds seen", color: .purple, symbol: "square.grid.3x3.fill")
                Spacer()
            }
            if let p = pending {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.title).font(.callout.weight(.semibold))
                        Text(p.deadline.map { "Waiting for your answer until \($0.gameShort). If you don't answer: \"\(p.options[Alerts.inboxDefault(p, state)].label)\"." } ?? "Waiting for your answer.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Answer") { store.openDecisionID = p.id }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.inset))
            }
            let fixes = DramaStyle.fixes.filter { d.hardened.contains($0.id) }
            if !fixes.isEmpty || !d.followUps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !fixes.isEmpty {
                        HStack(spacing: 6) {
                            Text("Lasting fixes:").font(.caption).foregroundStyle(.secondary)
                            ForEach(fixes.indices, id: \.self) { i in Pill(text: fixes[i].label, color: .green, symbol: fixes[i].symbol) }
                        }
                    }
                    ForEach(Array(d.followUps.sorted { $0.due < $1.due }.enumerated()), id: \.offset) { _, f in
                        Label(DramaStyle.followUpText(f), systemImage: "hourglass").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if d.log.isEmpty {
                Text("Nothing dramatic yet. It won't stay that way.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(d.log.prefix(showAll ? 40 : 6))) { r in
                DramaRow(record: r)
            }
            HStack {
                if d.log.count > 6 {
                    Button(showAll ? "Show fewer" : "Show all \(d.log.count)") { showAll.toggle() }.buttonStyle(.link)
                }
                Spacer()
            }
            DisclosureGroup("What can happen (\(Drama.catalog.count) kinds)") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], alignment: .leading, spacing: 6) {
                    ForEach(Drama.catalog, id: \.id) { def in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: seen.contains(def.id) ? "checkmark.seal.fill" : "questionmark.square.dashed")
                                .foregroundStyle(seen.contains(def.id) ? Color.orange : Color.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(def.name).font(.caption.weight(seen.contains(def.id) ? .semibold : .regular))
                                Text(def.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption)
        }
    }
}

struct DramaRow: View {
    let record: DramaRecord

    var body: some View {
        let def = Drama.byID[record.event]
        HStack(alignment: .top, spacing: 10) {
            Photo(key: def?.image ?? "network")
                .frame(width: 84, height: 60)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.title).font(.callout.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(record.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text(record.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if record.choice.isEmpty {
                    Pill(text: "Waiting in your inbox", color: .orange, symbol: "tray.full.fill")
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Pill(record.defaulted ? "Inbox default" : "You chose", tone: DramaStyle.tone(record.tone))
                        Text(record.choice).font(.caption.weight(.medium))
                    }
                    if !record.outcome.isEmpty {
                        Text(record.outcome).font(.caption).foregroundStyle(DramaStyle.tone(record.tone).color).lineLimit(3)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}
