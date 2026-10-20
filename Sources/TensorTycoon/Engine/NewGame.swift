import Foundation

struct NewGameSettings {
    var companyName = "Tensor Labs"
    var founderName = NewGameSettings.defaultFounder
    var eraID = "2022"
    var difficulty: Difficulty = .normal
    var locationID = "nova"
    var logoSymbol = "brain.head.profile"
    var logoColor = 0
    var doctrine: LabDoctrine = .balanced
    var background: FounderBackground = .researcher
    var signature: SignatureSecret = .cortex
    // 3.5: founding kit
    var kit: [String] = []
    var kitMode: KitMode = .standard
    var starterQuests = false
    /// 3.5: headquarters (CountryCatalog). The US / San Francisco default changes nothing.
    var hqCountry = "us"
    var hqCity = "sf"

    /// First name of the Mac's user account, so the founder defaults to the player.
    static var defaultFounder: String {
        let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Founder" : first
    }
}

enum NewGame {
    static let logoSymbols = ["brain.head.profile", "sparkles", "atom", "bolt.fill", "cube.transparent", "flame.fill",
                              "infinity", "hexagon.fill", "waveform", "circle.hexagongrid.fill", "star.fill", "aqi.medium"]

    static func create(_ settings: NewGameSettings, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) -> GameState {
        StableID.seed(seed)   // 3.7: the game's IDs come from its seed, so a seed always plays the same game
        return StableID.drawing { build(settings, seed: seed) }
    }

    private static func build(_ settings: NewGameSettings, seed: UInt64) -> GameState {
        let era = Era.all.first { $0.id == settings.eraID } ?? Era.all[2]
        let start = era.start
        var s = GameState(companyName: settings.companyName.isEmpty ? "Tensor Labs" : settings.companyName,
                          founderName: settings.founderName.isEmpty ? "Founder" : settings.founderName,
                          logoSymbol: settings.logoSymbol, logoColor: settings.logoColor,
                          difficulty: settings.difficulty, eraID: era.id, startDate: start, date: start,
                          cash: era.cash * settings.difficulty.cashMultiplier * settings.background.startCash * HQ.seedCash(settings), rng: GameRNG(seed: seed),
                          month: MonthRecord(month: GameCalendar.date(start.ym.year, start.ym.month, 1)))
        let y = start.decimalYear
        s.hqCountry = CountryCatalog.get(settings.hqCountry).id   // 3.5: headquarters
        s.hqCity = CountryCatalog.get(settings.hqCountry).city(settings.hqCity).id
        s.traitsInitialized = true
        s.doctrineID = settings.doctrine.rawValue
        s.backgroundID = settings.background.rawValue
        s.culturePoints = 2
        s.boardConfidence = 60
        // Your founding secret is live from day one, whatever the year.
        s.signatureID = settings.signature.rawValue
        s.signatureLevel = 1
        s.signatureShare = SignatureSecret.defaultShare
        s.autoResearch = true
        // 3.9: the chores that can't cost you anything start handed over (capacity, rental renewals, pay, leads); the rest is one click on Operations.
        s.ops.autoscale = true; s.ops.autoRenew = true; s.ops.autoRaises = true; s.ops.autoLeads = true
        s.directorQueueTracked = true
        s.researchFocus = ResearchFocus.balanced.rawValue
        s.pauseConfigured = true
        s.pauseKinds = Alerts.defaultPauseKinds

        // Public research is already known.
        for r in ResearchCatalog.core where r.year <= y - 0.05 && r.category != .frontier {
            s.researched.insert(r.id)
        }
        Competitors.assignExotics(&s)
        // Sensible first research picks
        let firstPicks = ResearchCatalog.core.filter { !s.researched.contains($0.id) && $0.category != .frontier }
            .sorted { $0.year < $1.year }.prefix(2).map(\.id)
        s.researchQueue = Array(firstPicks)

        // Historic events already in the past are not replayed (but recent ones show as news).
        for e in EventCatalog.historical where e.date < start {
            s.firedEvents.insert(e.id)
            for eff in e.effects {
                switch eff {
                case .exportControls: s.market.exportControls = true
                case .euAIAct: s.market.euAIAct = true
                case .chatMoment: s.chatMoment = 2022.91
                case .copyrightHeat(let v): s.market.copyrightHeat += v
                default: break
                }
            }
        }
        s.market.hype = EventCatalog.hypeBase(y)
        if era.id == "2026" {
            s.market.hardwarePrice = 1.12
            s.market.consumerGPUPrice = 1.15
        }
        for a in HardwareCatalog.all {
            if a.announced <= start.ym { s.announcedHardware.insert(a.id) }
            if a.available <= start.ym { s.availableHardware.insert(a.id) }
        }

        // The garage
        let garage = Site(name: "\(s.founderName)'s garage", kind: .garage, locationID: HQ.garageLocation(settings), capacityKW: 4,
                          cooling: .air, powerDeal: .grid, opened: start, ready: start, capex: 0, monthlyFee: 0)
        s.sites = [garage]

        // Starter hardware appropriate for the era
        let starter: (String, Int)
        switch era.id {
        case "2017": starter = ("p40", 4)
        case "2020": starter = ("titan_v", 4)
        case "2022": starter = ("rtx3090", 4)
        default: starter = ("rtx5090", 4)
        }
        if let a = HardwareCatalog.get(starter.0) {
            s.owned = [OwnedBatch(accelID: a.id, count: starter.1, siteID: garage.id, purchased: start, unitCost: a.price ?? 1000)]
        }

        // Founding team
        s.employees = [
            Employee(name: "\(s.rng.pick(NameBank.first)) \(s.rng.pick(NameBank.last))", role: .researcher, skill: 58,
                     salary: (Macro.salary(.researcher, y) * 0.8 * HQ.salaryFactor(s) / 1000).rounded() * 1000, morale: 85, hired: start, equity: 1.5),
            Employee(name: "\(s.rng.pick(NameBank.first)) \(s.rng.pick(NameBank.last))", role: .mlEngineer, skill: 52,
                     salary: (Macro.salary(.mlEngineer, y) * 0.8 * HQ.salaryFactor(s) / 1000).rounded() * 1000, morale: 85, hired: start, equity: 1.0),
        ]
        People.refreshCandidates(&s)

        FoundingKit.preSeed(&s, settings)   // 3.5: founding kit
        // Seed round that funded the starting cash
        s.founderShares = 9_000_000
        s.employeePoolShares = 1_000_000
        let seedPre = Macro.seedValuation(y) * 0.6 * HQ.investorFactor(s, value: 0)
        let raised = s.cash
        let newShares = 10_000_000 * raised / seedPre
        let lead = s.rng.pick(NameBank.investors.filter { !$0.contains("strategic") && !$0.contains("Sovereign") && !$0.contains("Mega") })
        s.holdings = [Holding(name: lead, shares: newShares)]
        s.rounds = [FundingRound(name: "Seed", date: start, amount: raised, preMoney: seedPre,
                                 lead: lead, percent: raised / (seedPre + raised))]
        s.lastRaise = start
        s.cloudCredits = 0

        BenchmarkCatalog.resetCache()
        HardwareCatalog.register([])
        s.agentPrice = 100
        Competitors.setup(&s)
        RivalEconomy.bootstrap(&s)
        RivalIntel.bootstrap(&s)
        BenchLife.replayHistory(&s)
        BenchLife.refreshIndexes(&s)
        Capabilities.bootstrap(&s)   // 3.4: domain scores, milestone history, rival product lines
        s.valuation = seedPre + raised
        s.brand = 8 + (settings.background == .policy ? 5 : 0)
        if settings.doctrine == .open { s.publication = .open }
        if settings.doctrine == .hardware {
            s.researched.insert("custom_silicon")
            s.researchQueue.removeAll { $0 == "custom_silicon" }
        }
        Board.refill(&s)
        Cast.seed(&s)   // 3.4: the people of AI
        s.market.interestRate = Macro.historicalRate(y) ?? 3.4
        World.bootstrap(&s)   // 3.4: the world as it stands on the start date
        Nations.bootstrap(&s)   // 3.7: national strategies to the start year; rivals' first specialties
        FoundingKit.setup(&s, settings)   // 3.5: founding kit and starter quests

        // Welcome news
        Sim.news(&s, "Project \(settings.signature.codename): your founding secret",
                 "\(settings.signature.blurb) Level 1 is already working for you; put research into it to unlock levels 2–5.",
                 .research, image: "wafer_closeup", important: true, good: true)
        Sim.news(&s, "Welcome to \(s.companyName)", "\(era.blurb) You have \(Fmt.money(s.cash)) from your \(s.rounds[0].name.lowercased()) round led by \(lead), a garage with \(starter.1)× \(HardwareCatalog.get(starter.0)?.name ?? "GPUs") and a tiny team. Build something people want.",
                 .company, image: era.image, important: true, good: true)
        for e in EventCatalog.historical where e.date < start && e.date > GameCalendar.addDays(start, -120) {
            s.news.append(NewsItem(date: e.date, title: e.title, body: e.body, category: e.category, image: ImagePicker.illustrate(e.image, title: e.title, category: e.category)))
        }
        let top = Leaderboard.entries(s).first
        if let top {
            s.news.append(NewsItem(date: start, title: "State of the art: \(top.model) by \(top.lab)",
                                   body: "The best model in the world scores \(Fmt.score(top.index)) on the Intelligence Index. That's the bar.",
                                   category: .competitor))
        }
        HQ.found(&s)   // 3.5
        Books.open(&s)   // 3.8: the first month reconciles against the cash the company starts with
        s.unreadNews = s.news.count
        return s
    }
}
