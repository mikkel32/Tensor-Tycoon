import SwiftUI

struct MainMenuView: View {
    @Environment(GameStore.self) private var store
    @Environment(Updater.self) private var updater
    @State private var settings = NewGameSettings()
    @State private var saves: [GameStore.SaveInfo] = []

    var body: some View {
        ZStack {
            Photo(key: "supercomputer", thumb: false)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.55))
                .overlay(LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                .blur(radius: 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    UpdateBanner()
                    HStack(alignment: .top, spacing: 22) {
                        newCompanyCard
                        if !saves.isEmpty { continueCard.frame(width: 340) }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 52)
                .padding(.bottom, 36)
                .frame(maxWidth: 1400)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { saves = GameStore.listSaves() }
        .animation(.spring(duration: 0.4), value: updater.updateAvailable)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                CompanyLogo(symbol: "brain.head.profile", color: .indigo, size: 54)
                Text("TENSOR TYCOON")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
            }
            Text("Found an AI lab. Buy GPUs and rent TPUs. Train frontier models, win the benchmarks, and out-raise the giants.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
            UpdateStatusLine()
        }
    }

    private var newCompanyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New company").font(.title2.weight(.bold))

            HStack(spacing: 16) {
                LabeledField(label: "Company name") {
                    TextField("Company", text: $settings.companyName).textFieldStyle(.roundedBorder)
                }
                LabeledField(label: "Your name") {
                    TextField("Founder", text: $settings.founderName).textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Starting era").font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(Era.all) { era in
                        EraCard(era: era, selected: settings.eraID == era.id, difficulty: settings.difficulty) {
                            settings.eraID = era.id
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty").font(.subheadline.weight(.semibold))
                    Picker("Difficulty", selection: $settings.difficulty) {
                        ForEach(Difficulty.allCases) { d in Text(d.rawValue).tag(d) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text(settings.difficulty.blurb).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Home region").font(.subheadline.weight(.semibold))
                    Picker("Region", selection: $settings.locationID) {
                        ForEach(LocationCatalog.all) { l in Text("\(l.name)").tag(l.id) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                    Text("Where your garage is. Datacenters can go anywhere later.").font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Logo").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(NewGame.logoSymbols, id: \.self) { sym in
                        Button {
                            settings.logoSymbol = sym
                        } label: {
                            CompanyLogo(symbol: sym, color: settings.logoSymbol == sym ? Theme.logoColor(settings.logoColor) : .gray, size: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(sym)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(Theme.logoColors.indices, id: \.self) { i in
                        Button {
                            settings.logoColor = i
                        } label: {
                            Circle().fill(Theme.logoColors[i].gradient)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(.white, lineWidth: settings.logoColor == i ? 2.5 : 0))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(i + 1)")
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    store.newGame(settings)
                } label: {
                    Label("Found \(settings.companyName.isEmpty ? "company" : settings.companyName)", systemImage: "sparkles")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .environment(\.colorScheme, .dark)
    }

    private var continueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue").font(.title2.weight(.bold))
            ForEach(saves) { save in
                HStack {
                    Button {
                        store.load(save.url)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(save.company).font(.headline)
                                if save.over { Pill(text: "Ended", color: .red) }
                            }
                            Text("\(save.date.gameShort) · \(Fmt.money(save.cash)) cash · \(Fmt.money(save.valuation)) valuation")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        GameStore.deleteSave(save.url)
                        saves = GameStore.listSaves()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Move save to Trash")
                }
            }
        }
        .padding(22)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .environment(\.colorScheme, .dark)
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            content
        }
    }
}

private struct EraCard: View {
    let era: Era
    let selected: Bool
    let difficulty: Difficulty
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Photo(key: era.image)
                    .frame(height: 96)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text(era.subtitle)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: .capsule)
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                VStack(alignment: .leading, spacing: 6) {
                    Text(era.title).font(.headline).lineLimit(1)
                    Text(era.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(4, reservesSpace: true)
                    Text("Start with \(Fmt.money(era.cash * difficulty.cashMultiplier))")
                        .font(.caption.weight(.semibold)).foregroundStyle(.green)
                }
                .padding(10)
            }
            .background(.background.secondary.opacity(0.6))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Color.accentColor : .white.opacity(0.1), lineWidth: selected ? 3 : 1))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
