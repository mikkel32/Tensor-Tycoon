import SwiftUI

/// The first thing a new game shows: the world as it is, what's about to happen, and how to open in this era.
struct EraIntroSheet: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let s = store.state { content(EraGuide.intro(s)) }
    }

    private func content(_ intro: EraGuide.Intro) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Photo(key: intro.image, thumb: false)
                .frame(height: 150)
                .clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(intro.date).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85)).textCase(.uppercase)
                        Text(intro.title).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    }
                    .padding(18)
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(intro.blurb).font(.callout).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("The world today", systemImage: "globe").font(.headline)
                        ForEach(intro.world, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.secondary)
                                Text(line).font(.callout).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if !intro.coming.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Coming up", systemImage: "calendar.badge.clock").font(.headline)
                            ForEach(Array(intro.coming.enumerated()), id: \.offset) { _, e in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(e.date.gameMonth).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                                    Text(e.title).font(.callout)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("How to open", systemImage: "flag.checkered").font(.headline)
                        Text(intro.plan).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("First steps", systemImage: "checklist").font(.headline)
                        ForEach(intro.steps.prefix(4)) { step in
                            Button {
                                close()
                                store.open(step.screen)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color.accentColor)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(step.title).font(.callout.weight(.semibold))
                                        Text(step.detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Text("The game is paused. Press play (or ⌘1) when you're ready.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Let's go") { close() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 620, height: 680)
    }

    private func close() {
        store.showEraIntro = false
    }
}
