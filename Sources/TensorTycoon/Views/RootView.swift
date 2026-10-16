import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(Updater.self) private var updater

    var body: some View {
        @Bindable var updater = updater
        ZStack(alignment: .bottom) {
            if store.state != nil {
                GameShell()
            } else {
                MainMenuView()
            }
            if let toast = store.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { store.toast = nil }
            }
        }
        .animation(.spring(duration: 0.35), value: store.toast)
        .sheet(isPresented: $updater.showSheet) { UpdateSheet() }
        .sheet(item: $updater.whatsNew, onDismiss: resumeAfterUpdate) { info in
            WhatsNewSheet(info: info) { updater.whatsNew = nil }
        }
    }

    /// After an update relaunch, reopen the game that was running.
    private func resumeAfterUpdate() {
        if store.state == nil, let url = updater.takeResumeSave() { store.load(url) }
    }
}

// MARK: - Game shell

struct GameShell: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            if store.state != nil {
                ScreenRouter(screen: store.screen)
                    .id(store.screen)
            }
        }
        .toolbar { GameToolbar() }
        .toolbar(removing: .title)
        .sheet(item: Binding(get: { store.state?.decisions.first }, set: { _ in })) { d in
            DecisionSheet(decision: d)
                .interactiveDismissDisabled()
        }
        .sheet(item: Binding(get: { store.state?.decisions.isEmpty == false ? nil : store.reportRunID.map(RunReportID.init) },
                             set: { if $0 == nil { store.reportRunID = nil } })) { r in
            RunReportSheet(runID: r.id)
        }
        .sheet(isPresented: Binding(get: { store.state?.gameOver != nil }, set: { _ in })) {
            GameOverSheet()
                .interactiveDismissDisabled()
        }
    }
}

struct ScreenRouter: View {
    let screen: Screen

    var body: some View {
        switch screen {
        case .dashboard: DashboardView()
        case .strategy: StrategyView()
        case .security: SecurityView()
        case .lab: ModelLabView()
        case .training: TrainingView()
        case .models: ModelsView()
        case .leaderboard: LeaderboardView()
        case .benchmarks: BenchmarksView()
        case .rsi: RSIView()
        case .swarms: SwarmView()
        case .xeno: XenoView()
        case .chipSales: ChipSalesView()
        case .silicon: SiliconView()
        case .partners: PartnersView()
        case .hardware: HardwareStoreView()
        case .compute: ComputeView()
        case .datacenters: DatacentersView()
        case .research: ResearchView()
        case .team: TeamView()
        case .data: DataView()
        case .market: MarketView()
        case .competitors: CompetitorsView()
        case .finance: FinanceView()
        case .funding: FundingView()
        case .news: NewsView()
        case .achievements: AchievementsView()
        case .credits: CreditsView()
        }
    }
}

struct Sidebar: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let s = store.state { list(s) }
    }

    private func list(_ s: GameState) -> some View {
        @Bindable var store = store
        return List(selection: $store.screen) {
            HStack(spacing: 10) {
                CompanyLogo(symbol: s.logoSymbol, color: Theme.logoColor(s.logoColor), size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.companyName).font(.headline).lineLimit(1)
                    Text("CEO \(s.founderName)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
            .selectionDisabled()

            ForEach(Screen.sections, id: \.0) { section in
                Section(section.0) {
                    ForEach(section.1) { screen in
                        Label(screen.title, systemImage: screen.symbol)
                            .badge(badge(for: screen, s))
                            .tag(screen)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func badge(for screen: Screen, _ s: GameState) -> Int {
        switch screen {
        case .news: s.unreadNews
        case .training: s.runs.filter { $0.status == .running || $0.status == .postTraining }.count
        case .models: s.models.filter { !$0.released && !$0.retired }.count
        case .market: s.deals.filter { !$0.active }.count
        case .funding: s.raiseOffers.count
        case .research: s.researchQueue.isEmpty ? 1 : 0
        case .rsi: s.rsiRuns.filter { $0.status == .running }.count
        case .swarms: s.swarms.filter { !$0.paused }.count
        case .strategy: s.culturePoints
        case .security: s.bills.filter { $0.stance == 0 }.count
        case .xeno: s.alienArchs.reduce(0) { $0 + $1.offers.count }
        case .silicon: s.chipProjects.filter { !$0.done }.count
        case .partners: s.partnerships.count
        default: 0
        }
    }
}

struct GameToolbar: ToolbarContent {
    @Environment(GameStore.self) private var store
    @Environment(Updater.self) private var updater

    var body: some ToolbarContent {
        // Optional reads: the toolbar can be re-evaluated while the window tears down after quitting to the menu.
        let s = store.state
        let cash = s?.cash ?? 0
        let credits = s?.cloudCredits ?? 0
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(s?.date.gameLong ?? "")
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 8)
        }
        // One toolbar item per control so each keeps its own accessibility label.
        ToolbarItemGroup(placement: .principal) {
            ForEach(0..<GameStore.speeds.count, id: \.self) { i in
                Button {
                    store.setSpeed(i)
                } label: {
                    Label(i == 0 ? "Pause" : "Speed \(GameStore.speeds[i].label)", systemImage: speedSymbol(i))
                        .labelStyle(.iconOnly)
                        .frame(width: 26)
                }
                .help(GameStore.speeds[i].label)
                .foregroundStyle(store.speed == i ? Color.accentColor : .secondary)
            }
            Button { store.step() } label: { Label("Advance one day", systemImage: "forward.frame.fill").labelStyle(.iconOnly) }
                .help("Advance one day")
        }
        if updater.updateAvailable {
            ToolbarItem(placement: .primaryAction) { UpdateToolbarButton() }
        }
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 14) {
                ToolbarStat(label: "Cash", value: Fmt.money(cash), tint: cash < 0 ? .red : .primary)
                if credits > 0 {
                    ToolbarStat(label: "Credits", value: Fmt.money(credits), tint: .teal)
                }
                ToolbarStat(label: "Run-rate", value: Fmt.money(store.derived.runRate), tint: .primary)
                ToolbarStat(label: "Valuation", value: Fmt.money(s?.valuation ?? 0), tint: .primary)
            }
            .padding(.horizontal, 8)
        }
    }

    private func speedSymbol(_ i: Int) -> String {
        switch i {
        case 0: "pause.fill"
        case 1: "play.fill"
        case 2: "forward.fill"
        case 3: "forward.end.alt.fill"
        case 4: "hare.fill"
        default: "bolt.fill"
        }
    }
}

struct ToolbarStat: View {
    let label: String
    let value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            Text(value).font(.callout.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Decisions & game over

struct DecisionSheet: View {
    @Environment(GameStore.self) private var store
    let decision: Decision

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let img = decision.image {
                Photo(key: img, thumb: false)
                    .frame(height: 170)
                    .clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 14) {
                Label("Decision required", systemImage: "exclamationmark.bubble.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                Text(decision.title).font(.title2.weight(.bold))
                Text(decision.body).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(Array(decision.options.enumerated()), id: \.offset) { i, opt in
                        Button {
                            store.mutate { $0.resolveDecision(decision.id, option: i) }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(opt.label).font(.headline)
                                Text(opt.detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .buttonStyle(.bordered)
                        .tint(i == 0 ? .accentColor : .secondary)
                    }
                }
            }
            .padding(22)
        }
        .frame(width: 520)
    }
}

struct GameOverSheet: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        // The sheet can re-render while it dismisses after the game is closed.
        if let s = store.state { content(s) }
    }

    @ViewBuilder
    private func content(_ s: GameState) -> some View {
        let exit = s.exitValue != nil
        VStack(spacing: 0) {
            Photo(key: exit ? "sf_skyline" : "stock_exchange")
                .frame(height: 200)
                .clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    Text(exit ? "Exit!" : "Game Over")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(20)
                }
            VStack(alignment: .leading, spacing: 12) {
                Text(s.gameOver ?? "").font(.title3)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow { Text("Days in business").foregroundStyle(.secondary); Text("\(GameCalendar.daysBetween(s.startDate, s.date))") }
                    GridRow { Text("Lifetime revenue").foregroundStyle(.secondary); Text(Fmt.money(s.lifetimeRevenue)) }
                    GridRow { Text("Best model").foregroundStyle(.secondary); Text(s.bestModel.map { "\($0.name) (index \(Fmt.score($0.index)))" } ?? "—") }
                    GridRow { Text("Compute used").foregroundStyle(.secondary); Text("\(Fmt.flops(s.lifetimeFLOPs)) FLOPs") }
                    GridRow { Text("Achievements").foregroundStyle(.secondary); Text("\(s.achievements.count) / \(AchievementCatalog.all.count)") }
                    if let v = s.exitValue {
                        GridRow { Text("Your payout").foregroundStyle(.secondary); Text(Fmt.money(v * s.founderStake)).bold() }
                    }
                    if s.founderCash > 0 {
                        GridRow { Text("Cashed out before").foregroundStyle(.secondary); Text(Fmt.money(s.founderCash)) }
                    }
                    GridRow {
                        Text("Founder net worth").foregroundStyle(.secondary)
                        Text(Fmt.money(s.founderCash + s.founderStake * (s.exitValue ?? ((s.keptStake || s.gameOver == nil) ? s.valuation : 0)))).bold()
                    }
                }
                HStack {
                    Button("Main Menu") { store.quitToMenu() }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(22)
        }
        .frame(width: 520)
    }
}
