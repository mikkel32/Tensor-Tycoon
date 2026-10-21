import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(Updater.self) private var updater

    var body: some View {
        @Bindable var updater = updater
        @Bindable var store = store
        ZStack(alignment: .bottom) {
            if store.state != nil {
                GameShell()
            } else {
                MainMenuView()
                    // Help ▸ Photo Credits without a game (in a game it opens the Credits screen).
                    .sheet(isPresented: $store.showPhotoCredits) { PhotoCreditsSheet() }
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

/// The one sheet the shell shows, most important first: a decision that can't wait, an inbox offer you opened,
/// a finished run's report, a briefing.
enum ShellSheet: Identifiable {
    case decision(Decision)
    case palette
    case era
    case report(UUID)
    case briefing(UUID)
    case launchReport(UUID)   // 3.7

    var id: String {
        switch self {
        case .decision(let d): "decision-\(d.id)"
        case .palette: "palette"
        case .era: "era"
        case .report(let id): "report-\(id)"
        case .briefing(let id): "briefing-\(id)"
        case .launchReport(let id): "launch-\(id)"
        }
    }
}

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
                    .overlay(alignment: .topTrailing) {
                        AlertBanners().padding(14)
                    }
            }
        }
        .toolbar { GameToolbar() }
        .toolbar(removing: .title)
        .sheet(item: Binding(get: { sheet }, set: { new in if new == nil { dismissed() } })) { item in
            switch item {
            case .decision(let d):
                DecisionSheet(decision: d)
                    .interactiveDismissDisabled(Alerts.isUrgent(d))
            case .palette:
                CommandPalette()
            case .era:
                EraIntroSheet()
            case .report(let id):
                RunReportSheet(runID: id)
            case .briefing(let id):
                BriefingSheet(id: id)
            case .launchReport(let id):
                LaunchReportSheet(recordID: id)   // 3.7
            }
        }
        .sheet(isPresented: Binding(get: { store.state?.gameOver != nil }, set: { _ in })) {
            EpilogueSheet()   // 3.9: the epilogue replaces the plain game-over card
                .interactiveDismissDisabled()
        }
        .overlay {
            // 3.4: a landmark first's moment, oldest first.
            if let id = store.state?.ceremonies.first, let first = store.state?.trainingFirsts.first(where: { $0.id == id }) {
                FirstCeremony(first: first) { store.mutate { $0.ceremonies.removeAll { $0 == id } } }
                    .transition(.opacity)
            }
        }
    }

    private var sheet: ShellSheet? {
        guard let s = store.state, s.gameOver == nil else { return nil }
        if let d = s.decisions.first(where: Alerts.isUrgent) { return .decision(d) }
        if store.showPalette { return .palette }
        if let id = store.openDecisionID, let d = s.decisions.first(where: { $0.id == id }) { return .decision(d) }
        if store.showEraIntro { return .era }
        if let r = store.reportRunID { return .report(r) }
        if let b = store.briefingID { return .briefing(b) }
        if let l = store.launchReportID { return .launchReport(l) }
        return nil
    }

    /// The player closed the sheet (Escape or a Close button): forget what it showed.
    private func dismissed() {
        switch sheet {
        case .decision(let d): if !Alerts.isUrgent(d) { store.openDecisionID = nil }
        case .palette: store.showPalette = false
        case .era: store.showEraIntro = false
        case .report: store.reportRunID = nil
        case .briefing: store.briefingID = nil
        case .launchReport: store.launchReportID = nil
        case nil: break
        }
    }
}

struct ScreenRouter: View {
    @Environment(GameStore.self) private var store
    let screen: Screen

    var body: some View {
        switch screen {
        case .dashboard: DashboardView()
        case .operations: OperationsView()
        case .strategy: StrategyView()
        case .security: SecurityView()
        case .lab: ModelLabView()
        case .training: TrainingView()
        case .models: ModelsView()
        case .leaderboard: LeaderboardView()
        case .rivals: RivalsHubView(tab: store.rivalsTab ?? .overview, lab: store.rivalsLab)
        case .rivalWatch: RivalsHubView(tab: .watch)
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
        case .industry: RivalsHubView(tab: .industry)
        case .competitors: RivalsHubView(tab: .labs)
        case .finance: FinanceView()
        case .funding: FundingView()
        case .news: NewsView()
        case .pulse: PulseView()   // 3.4
        case .achievements: AchievementsView()
        case .credits: CreditsView()
        case .help: HelpView()
        case .world: WorldView()   // 3.4: world and stakeholders
        case .milestones: MilestonesView()
        case .products: ProductLinesView()
        case .events: EventsView()   // 3.5
        case .advancedProjects: AdvancedProjectsView()   // 3.5
        case .corporate: CorporateView()   // 3.5
        case .semiconductors: SemiconductorsView()   // 3.5
        case .science: ScienceView()   // 3.6
        case .families: FamiliesView()   // 3.5: model families
        case .nations: NationsView()   // 3.7: national AI strategies and economies
        case .progression: ProgressionView()   // 3.7: company stages and launches
        case .legacy: LegacyView()   // 3.9: endings and legacy
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
        case .dashboard: s.decisions.filter { !Alerts.isUrgent($0) }.count + s.briefings.prefix(1).filter { !$0.seen }.count
        case .rivals: s.rumors.prefix(30).filter { $0.kind == "imminent" && GameCalendar.daysBetween($0.date, s.date) <= 10 }.count
        case .training: s.runs.filter { $0.status == .running || $0.status == .postTraining }.count
        case .models: s.models.filter { !$0.released && !$0.retired }.count
        case .market: s.deals.filter { !$0.active }.count
        case .funding: s.raiseOffers.count
        case .research: (s.researchQueue.isEmpty && !s.autoResearch) || s.signatureLevel == 0 ? 1 : 0
        case .rsi: s.rsiRuns.filter { $0.status == .running }.count
        case .swarms: s.swarms.filter { !$0.paused }.count
        case .strategy: s.culturePoints
        case .security: s.bills.filter { $0.stance == 0 }.count
        case .xeno: s.alienArchs.reduce(0) { $0 + $1.offers.count } + s.decisions.filter { $0.kind == "xeno_anomaly" || $0.kind == "alien_errata" }.count
        case .silicon: s.chipProjects.filter { !$0.done }.count
        case .partners: s.partnerships.count
        case .advancedProjects: s.advanced.programmes.filter { $0.status == .active && $0.stage == .award }.count   // 3.5: waiting for a team
        case .corporate: s.decisions.filter { $0.kind.hasPrefix("corp_") }.count   // 3.5
        case .semiconductors: s.decisions.filter { Semis.kinds.contains($0.kind) }.count   // 3.5
        case .science: Science.pending(s).count   // 3.6
        case .families: s.families.jobs.filter(\.paused).count   // 3.5: model families
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
                .help(i == 0 ? "Pause (⇧⌘P)" : "\(GameStore.speeds[i].label): \(Fmt.trim(GameStore.speeds[i].daysPerSecond, 1)) days per second (⌘\(i))")
                .foregroundStyle(store.speed == i ? Color.accentColor : .secondary)
            }
            Button { store.step() } label: { Label("Advance one day", systemImage: "forward.frame.fill").labelStyle(.iconOnly) }
                .help("Advance one day (⌘→)")
            if store.speed == 0, let reason = store.pauseReason {
                Button {
                    store.setSpeed(1)
                } label: {
                    Label("Paused: \(reason)", systemImage: "pause.circle.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: .capsule)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("The game paused itself: \(reason). Click to resume.")
            }
        }
        if updater.updateAvailable {
            ToolbarItem(placement: .primaryAction) { UpdateToolbarButton() }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { store.showPalette = true } label: { Label("Go to…", systemImage: "magnifyingglass").labelStyle(.iconOnly) }
                .help("Go to a screen or do something (⌘K)")
        }
        ToolbarItem(placement: .primaryAction) { AlertsToolbarButton() }
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
    @State private var remember = false

    var body: some View {
        let inbox = !Alerts.isUrgent(decision)
        let left = decision.deadline.map { GameCalendar.daysBetween(store.game.date, $0) }
        let fallback = Alerts.inboxDefault(decision, store.game)
        VStack(alignment: .leading, spacing: 0) {
            if let img = ImagePicker.illustrate(decision.image, title: decision.title, fill: false) {
                Photo(key: img, thumb: false, size: .banner, illustrative: ImagePicker.isIllustrative(img))
                    .frame(height: 170)
                    .clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 14) {
                if inbox {
                    Label("From your inbox\(left.map { " · \(max(0, $0)) day\($0 == 1 ? "" : "s") left" } ?? "")", systemImage: "tray.full.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.blue)
                } else {
                    Label("Decision required", systemImage: "exclamationmark.bubble.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
                Text(decision.title).font(.title2.weight(.bold))
                Text(decision.body).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(Array(decision.options.enumerated()), id: \.offset) { i, opt in
                        // 3.9: an option you can't carry out is greyed out with the reason (it used to throw the offer away).
                        let blocked = Events.optionBlocker(decision, i, store.game)
                        Button {
                            resolve(i)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(opt.label).font(.headline)
                                    if inbox && i == fallback {
                                        Pill(text: "If you don't answer", color: .secondary)
                                    }
                                }
                                Text(opt.detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                if let blocked {
                                    Label(blocked, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .buttonStyle(.bordered)
                        .tint(i == 0 ? .accentColor : .secondary)
                        .disabled(blocked != nil)
                    }
                }
                HStack {
                    if let name = Alerts.rememberable[decision.kind] {
                        Toggle("Always answer \(name.lowercased()) this way", isOn: $remember)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                            .help("The game picks the same option for you next time. Change it on the Operations page.")
                    }
                    Spacer()
                    if inbox {
                        Button("Decide later") { store.openDecisionID = nil }
                            .keyboardShortcut(.cancelAction)
                    }
                }
            }
            .padding(22)
        }
        .frame(width: 520)
    }

    /// Answer, then say what happened.
    private func resolve(_ option: Int) {
        if remember, decision.options.indices.contains(option) {
            let label = decision.options[option].label
            store.mutate { $0.setStandingAnswer(decision.kind, option, label: label) }
        }
        let before = store.game.news.first?.id
        store.mutate { $0.resolveDecision(decision.id, option: option) }
        if store.openDecisionID == decision.id { store.openDecisionID = nil }
        if let n = store.state?.news.first, n.id != before {
            store.show(n.title + (n.body.isEmpty ? "" : " — " + String(n.body.prefix(140))))
        }
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
                    GridRow { Text("Legacy score").foregroundStyle(.secondary); Text("\(Victory.legacyScore(s))").bold() }
                    if !s.victories.isEmpty {
                        GridRow { Text("Victories").foregroundStyle(.secondary); Text(s.victories.compactMap { VictoryPath(rawValue: $0)?.title }.sorted().joined(separator: ", ")) }
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
