import Foundation

/// Brings saves from older versions up to date, and checks that a save loads and plays.
enum SaveMigration {
    static func migrate(_ s: inout GameState) {
        // Labs founded during the game (3.4) must resolve before anything reads their definitions.
        CompetitorCatalog.register(s.customLabs)
        if s.agentPrice <= 0 { s.agentPrice = 100 }
        // Saves from before traits: a generalist lab with points for what it already achieved.
        if !s.traitsInitialized {
            s.traitsInitialized = true
            s.doctrineID = LabDoctrine.balanced.rawValue
            s.backgroundID = FounderBackground.none.rawValue
            s.culturePoints = 2 + s.achievements.count
            s.boardConfidence = 60
            Board.refill(&s)
        }
        // Saves from before the research director (3.3): turn it on, keeping whatever was already queued.
        if s.researchFocus.isEmpty {
            s.researchFocus = ResearchFocus.balanced.rawValue
            s.autoResearch = true
        }
        // Saves from before alerts (3.4): pause on the important ones; waiting offers get a deadline.
        if !s.pauseConfigured {
            s.pauseConfigured = true
            s.pauseKinds = Alerts.defaultPauseKinds
        }
        for i in s.decisions.indices where !Alerts.isUrgent(s.decisions[i]) && s.decisions[i].deadline == nil {
            s.decisions[i].deadline = GameCalendar.addDays(s.date, Alerts.inboxDays(s.decisions[i].kind))
        }
        // Unique breakthroughs researched before mastery existed start at mastery I.
        for id in s.exoticOwned where s.researched.contains(id) && s.exoticMastery[id] == nil { s.exoticMastery[id] = 1 }
        // Old labs choose their signature secret on the Research page (signatureLevel stays 0 until they do).
        if s.signatureLevel > 0 && s.signatureShare <= 0 { s.signatureShare = SignatureSecret.defaultShare }
        // Chips added to the catalog after this save was made: treat anything older than a month as old news.
        let cutoff = GameCalendar.addMonths(s.date, -1).ym
        for a in HardwareCatalog.all {
            if a.announced <= cutoff { s.announcedHardware.insert(a.id) }
            if a.available <= cutoff { s.availableHardware.insert(a.id) }
        }
        Competitors.migrate(&s)
        // Labs' books (3.3): real rounds so far, cash and staff.
        RivalEconomy.bootstrap(&s)
        // Rival Watch (3.3): the run behind each lab's next release.
        RivalIntel.bootstrap(&s)
        // The people of AI (3.4): the cast as it stands today.
        Cast.migrate(&s)
        // Catch up benchmarks added to the catalog after this save was made (idempotent for the rest).
        BenchLife.replayHistory(&s)
        BenchLife.refreshIndexes(&s)
        // The world outside the labs (3.4): replayed from 2016 to the save's date; your standing from your record.
        World.bootstrap(&s)
        // 3.4: score every model and credit the milestones already reached.
        if !s.capsReady { Capabilities.bootstrap(&s) }
        // 3.5: saves from before headquarters were founded in the US.
        if s.hqCountry.isEmpty || CountryCatalog.byID[s.hqCountry] == nil { s.hqCountry = "us" }
        if s.hqCity.isEmpty || !CountryCatalog.get(s.hqCountry).cities.contains(where: { $0.id == s.hqCity }) {
            s.hqCity = CountryCatalog.get(s.hqCountry).cities[0].id
        }
        // 3.5: alien programs in progress get unstuck and existing alien chips get their fab line.
        AlienFab.migrate(&s)
    }

    /// Decodes a save, migrates it and plays 90 days on a copy, resolving decisions with their first option.
    /// Returns a one-line report and whether the save is current.
    static func check(_ data: Data, name: String) throws -> (report: String, current: Bool) {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        var s = try dec.decode(GameState.self, from: data)
        StableID.resume(s)   // 3.7: the save keeps its ID stream, so a check plays the same way every time
        migrate(&s)
        BenchmarkCatalog.resetCache()
        HardwareCatalog.register(s.customChips)
        let start = s.date
        for _ in 0..<90 where s.gameOver == nil {
            for _ in 0..<10 {
                guard let d = s.decisions.first else { break }
                s.resolveDecision(d.id, option: 0)
            }
            Sim.advanceDay(&s)
        }
        let report = "OK \(name): \(s.companyName), \(start.gameShort) → \(s.date.gameShort), save v\(s.version), "
            + "cash \(Fmt.money(s.cash)), valuation \(Fmt.money(s.valuation)), \(s.models.count) models\(s.gameOver.map { " (game over: \($0))" } ?? "")"
        return (report, s.version >= GameState.currentVersion)
    }
}
