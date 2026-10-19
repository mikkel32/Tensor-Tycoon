import Foundation

extension ScenarioHarness {
    /// H: a technology empire (goal part 26). A Paris lab from 2026 plays seven years with every bot system on
    /// (government programmes, science labs, the data economy, a chip business, AI organisations) and, as it grows, does
    /// what an empire does beyond the bot: offices and a campus abroad, subsidiaries, specialist models in a family, and
    /// national technology partnerships. At the end each system must really be running, every month's books must
    /// reconcile, valuations must move sanely, and a simulated year must stay quick to compute.
    static func scenarioH() -> Report {
        var r = Report(id: "H", title: all.first { $0.id == "H" }?.title ?? "H")
        var s = newGame(era: "2026", hq: "fr", city: "paris", seed: 31, name: "Empire Labs")
        var bot = PTBot()
        bot.flags = ["advproj", "science", "data", "semis", "orgs"]
        let start = s.date
        let t0 = ProcessInfo.processInfo.systemUptime
        var subsTried: [String] = [], forks: [String] = [], partnerships: [String] = [], campus: UUID? = nil
        var worstJump = 1.0, jumpMonth = "", roundJump = 1.0, peakAgents = 0

        let kinds: [(SubsidiaryKind, String)] = [(.robotics, "fr"), (.consulting, "us"), (.energy, "fr"), (.cloud, "us")]
        for _ in 0..<(7 * 12) where s.gameOver == nil {
            let before = s.valuation, rounds = s.rounds.count
            play(&s, &bot, days: 30)
            if before > 1e8 && s.valuation > 0 {
                // A priced round or the IPO re-marks the company at once; between them the mark moves gradually.
                let jump = max(s.valuation / before, before / s.valuation)
                if s.rounds.count > rounds { roundJump = max(roundJump, jump) }
                else if jump > worstJump { worstJump = jump; jumpMonth = s.date.gameMonth }
            }
            peakAgents = max(peakAgents, s.orgs.reduce(0) { $0 + Progression.orgAgents(s, $1.id) })

            // Offices abroad: San Francisco, then Copenhagen.
            for (country, city) in [("us", "sf"), ("dk", "copenhagen")] where !s.hq.satellites.contains(where: { $0.city == city })
                && s.cash > 50 * HQ.satelliteOpenCost(s, country: country, city: city) {
                _ = s.openSatellite(country: country, city: city)
                break
            }

            // Subsidiaries, one at a time, as the stage allows and the cash can carry them.
            if let (kind, country) = kinds.first(where: { k in !s.corp.subs.contains { $0.kind == k.0 } }),
               s.subsidiaryBlocker(kind, country: country) == nil {
                let seed = Corporate.minSeed(kind, s, country: country) * 1.5
                if s.cash > 25 * seed, s.startSubsidiary(kind, country: country, seed: seed) == nil { subsTried.append(kind.title) }
            }

            // Specialists forked from the flagship, on rented chips if none are free.
            if forks.count < 2, let flagship = s.releasedModels.filter({ !$0.preview && $0.design.instruct && $0.c > Macro.frontier(s.year) - 1 })
                .max(by: { $0.c < $1.c }) {
                for pass in [PostTrainPass.specCode, .specScience] where Families.forkBlocker(s, flagship, pass) == nil && !forks.contains(pass.label) {
                    let a = Silicon.reference(s)
                    let chips = 256
                    if Economy.freeChips(s, a.id) < chips { _ = s.rentHardware(a.id, count: chips, term: .onDemand) }
                    if s.startFork(flagship.id, pass: pass, accelID: a.id, chips: chips) == nil { forks.append(pass.label) }
                    break
                }
            }

            // National technology partnerships: France's compute centre, then a Danish university chair.
            for (kind, country, city) in [(PartnershipKind.computeCentre, "fr", "paris"), (.universityChair, "dk", "copenhagen")]
            where !partnerships.contains(kind.title) && s.cash > 40 * Nations.partnershipCost(kind, s) {
                if s.signNationalPartnership(kind, country: country, city: city) == nil { partnerships.append(kind.title) }
            }

            // A large campus abroad once the company is big enough to fill it.
            if campus == nil, s.year >= 2028, s.cash > 4 * 200 * Campus.capexPerMW(.liquid, s, location: "texas") {
                if s.buildSite(kind: .datacenter, locationID: "texas", capacityKW: 200_000, cooling: .liquid, power: .grid, name: "Empire Texas") == nil {
                    campus = s.sites.last?.id
                }
            }
        }
        let seconds = ProcessInfo.processInfo.systemUptime - t0
        let years = Double(GameCalendar.daysBetween(start, s.date)) / 365.25
        r.note("ended \(s.date.gameShort) as a \(s.progression.current.title): staff \(s.employees.count), valuation \(Fmt.money(s.valuation)), revenue \(Fmt.money(s.history.last?.revenue ?? 0))/mo, rank #\(Leaderboard.rank(of: s.releasedModels.max { $0.index < $1.index }?.id ?? UUID(), in: s))")
        r.expect("the empire survives seven years", s.gameOver == nil && years > 6.8, s.gameOver.map { "game over: \($0)" } ?? "\(Fmt.trim(years, 1)) years")

        // An international company.
        let abroad = s.sites.filter { site in
            let country = AdvancedProjects.locationCountry(site.locationID)
            return !country.isEmpty && country != s.hqCountry
        }
        r.expect("offices abroad", !s.hq.satellites.isEmpty, s.hq.satellites.map { "\($0.city), \($0.country)" }.joined(separator: "; "))
        r.expect("datacenters abroad", !abroad.isEmpty, "\(abroad.count) sites outside \(HQ.country(s).name)")
        if let id = campus, let site = s.sites.first(where: { $0.id == id }) {
            r.expect("a large campus (200 MW) is built and running", site.isReady(s.date) && site.capacityKW >= 200_000, "\(Fmt.watts(site.capacityKW * 1000)), ready \(site.isReady(s.date))")
        } else {
            r.expect("a large campus (200 MW) is built and running", false, "never affordable")
        }

        // Subsidiaries.
        let live = s.corp.subs.filter(\.live)
        r.note("subsidiaries: " + live.map { "\($0.name) (\(Fmt.money($0.valuation)), revenue \(Fmt.money($0.revenue))/mo)" }.joined(separator: "; "))
        r.expect("several subsidiaries run at once", live.count >= 2, "\(live.count) live; started \(subsTried.joined(separator: ", "))")
        r.expect("subsidiaries earn and pay licence fees", live.contains(where: { $0.revenue > 0 }) && Corporate.feeRunRate(s) > 0,
                 "fees \(Fmt.money(Corporate.feeRunRate(s)))/yr")

        // Specialist models.
        let specialists: [AIModel] = s.families.families.flatMap(\.members).filter { $0.tier.isSpecialist }
            .compactMap { m in s.models.first { $0.id == m.modelID } }
        r.expect("specialist models trained and released", specialists.filter(\.released).count >= 2,
                 specialists.map { "\($0.name)\($0.released ? "" : " (unreleased)")" }.joined(separator: ", ") + " · forks started: \(forks.joined(separator: ", "))")

        // Science.
        r.expect("science labs run research", s.science.labs.count >= 2 && s.science.discoveries.count >= 3,
                 "\(s.science.labs.count) labs, \(s.science.discoveries.count) discoveries")

        // Autonomous agents.
        let agents = s.orgs.reduce(0) { $0 + Progression.orgAgents(s, $1.id) }
        r.expect("AI organisations at work", !s.orgs.isEmpty && peakAgents > 0,
                 "\(s.orgs.count) organisations, \(Fmt.int(peakAgents)) agents at the peak, \(Fmt.int(agents)) at the end")

        // Custom silicon.
        let qualified = s.semi.designs.filter(\.inProduction)
        let fleet = s.owned.filter { HardwareCatalog.get($0.accelID)?.vendor == .custom }.reduce(0) { $0 + $1.count }
        r.expect("own silicon in production", !qualified.isEmpty, qualified.map(\.name).joined(separator: ", "))
        r.expect("own chips in the fleet", fleet > 0, "\(Fmt.int(fleet)) chips")

        // International technology programmes.
        let programmes = s.advanced.programmes.filter { $0.status == .active || $0.status == .completed }
        r.expect("national technology partnerships", !s.hq.partners.isEmpty, partnerships.joined(separator: ", "))
        r.expect("government programmes won", !programmes.isEmpty, "\(programmes.count) programmes, \(Fmt.money(s.history.reduce(0) { $0 + $1.revContracts })) contract revenue")

        // Economic consistency.
        let worst = Books.worstResidual(s)
        r.expect("every month's books reconcile", worst.map { abs($0.amount) <= Books.tolerance(s.cash) } ?? true,
                 worst.map { "worst \(Fmt.money($0.amount)) in \($0.month.gameMonth)" } ?? "none unexplained")
        r.expect("between rounds, valuation moves sanely month to month (under ×2)", worstJump < 2, "largest move ×\(Fmt.trim(worstJump, 2)) (\(jumpMonth))")
        r.expect("a priced round re-marks at most 6×", roundJump <= 6.05, "largest re-mark ×\(Fmt.trim(roundJump, 2))")
        r.expect("revenue lines are never negative", s.history.allSatisfy { $0.revenue >= 0 && $0.revAPI >= 0 && $0.revEnterprise >= 0 })
        r.expect("subsidiary books are finite", s.corp.subs.allSatisfy { $0.cash.isFinite && $0.valuation.isFinite })

        // Performance.
        let perYear = seconds / max(years, 0.1)
        r.note("simulated \(Fmt.trim(years, 1)) years in \(Fmt.trim(seconds, 1)) s (bot included)")
        r.expect("a simulated year stays quick (under 15 s with the bot)", perYear < 15, "\(Fmt.trim(perYear, 2)) s per year")
        sanity(s, &r)
        return r
    }
}
