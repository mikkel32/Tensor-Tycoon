import SwiftUI

extension GameAlert {
    var tint: Color {
        if celebrate { return .yellow }
        if critical { return .red }
        switch alertKind {
        case .rivalPassed, .rivalLaunch, .priceWar: return .orange
        case .inbox, .termSheet, .offerExpiring: return .blue
        case .briefing: return .indigo
        default: return .orange
        }
    }
}

/// The newest unread alerts, stacked in the corner of the screen. Critical ones stay until you deal with them;
/// the rest fade from the stack as newer ones arrive or after a month and a half of game time.
struct AlertBanners: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let unread = s.alerts.filter { !$0.seen && ($0.critical || GameCalendar.daysBetween($0.date, s.date) <= 45) }
        if !unread.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(unread.prefix(3)) { a in
                    AlertBanner(alert: a)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                if unread.count > 1 {
                    HStack(spacing: 10) {
                        if unread.count > 3 {
                            Text("+\(unread.count - 3) more").font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Dismiss all") { store.mutate { $0.markAlertsSeen() } }
                            .buttonStyle(.link).font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: .capsule)
                }
            }
            .animation(.spring(duration: 0.35), value: unread.map(\.id))
        }
    }
}

struct AlertBanner: View {
    @Environment(GameStore.self) private var store
    let alert: GameAlert

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alert.celebrate ? "star.circle.fill" : alert.alertKind.symbol)
                .font(.title3)
                .foregroundStyle(alert.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title).font(.callout.weight(.semibold)).lineLimit(2)
                Text(alert.body).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                HStack(spacing: 10) {
                    Button(goLabel) { store.follow(alert) }
                        .buttonStyle(.borderedProminent).controlSize(.small).tint(alert.tint)
                    Text(alert.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button {
                store.mutate { $0.dismissAlert(alert.id) }
            } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(12)
        .frame(width: 350, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(alert.tint.opacity(alert.critical || alert.celebrate ? 0.7 : 0.35), lineWidth: alert.critical ? 1.5 : 1))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    private var goLabel: String {
        switch alert.alertKind {
        case .inbox: "Answer"
        case .briefing: "Read"
        case .milestone: "See it"
        default: alert.target.map { "Open \($0.title)" } ?? "Open"
        }
    }
}

/// Toolbar bell: the alert history and what pauses the game.
struct AlertsToolbarButton: View {
    @Environment(GameStore.self) private var store
    @State private var open = false

    var body: some View {
        let unread = store.state?.alerts.filter { !$0.seen }.count ?? 0
        Button {
            open.toggle()
        } label: {
            Label("Alerts", systemImage: unread > 0 ? "bell.badge.fill" : "bell")
                .labelStyle(.iconOnly)
                .foregroundStyle(unread > 0 ? Color.orange : .secondary)
        }
        .help(unread > 0 ? "\(unread) unread alert\(unread == 1 ? "" : "s")" : "Alerts")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            AlertHistory { open = false }
        }
    }
}

struct AlertHistory: View {
    @Environment(GameStore.self) private var store
    var close: () -> Void

    var body: some View {
        let alerts = store.state?.alerts ?? []
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Alerts").font(.headline)
                Spacer()
                Button("Mark all read") { store.mutate { $0.markAlertsSeen() } }
                    .buttonStyle(.link).disabled(!alerts.contains { !$0.seen })
            }
            if alerts.isEmpty {
                Text("Nothing yet. Alerts appear when something needs you: cash trouble, stalled runs, rivals passing you, offers about to expire.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(alerts) { a in
                            Button {
                                store.follow(a)
                                close()
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: a.alertKind.symbol).foregroundStyle(a.tint).frame(width: 20)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(a.title).font(.callout.weight(a.seen ? .regular : .semibold)).lineLimit(1)
                                        Text(a.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer(minLength: 4)
                                    Text(a.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                                }
                                .padding(6)
                                .background(a.seen ? Color.clear : a.tint.opacity(0.07), in: .rect(cornerRadius: 8))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 380)
            }
            Divider()
            Button {
                store.open(.operations)
                close()
            } label: {
                Label("Choose what pauses the game…", systemImage: "pause.circle")
            }
            .buttonStyle(.link)
        }
        .padding(14)
        .frame(width: 400)
    }
}
