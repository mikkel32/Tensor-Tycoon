import Foundation

/// `--public-check [years]`: government AI-branch careers for every mandate in two eras, played by the scenario bot.
/// Checks the public model holds (no rounds, holdings, founder wealth, equity or private exits), appropriations and
/// missions actually flow, saves round-trip, the same seed plays the same, and startups are untouched.
enum PublicProgramHarness {
    static func main(_ args: [String]) -> Int32 {
        let years = args.first.flatMap(Double.init) ?? 4
        var failures = 0
        var delivered = 0, paidInFull = true
        func expect(_ name: String, _ ok: Bool, _ detail: String = "") {
            if !ok { failures += 1 }
            print("  \(ok ? "✓" : "✗") \(name)\(detail.isEmpty ? "" : ": \(detail)")")
        }

        for era in ["2017", "2022"] {
            for mandate in PublicMandate.allCases {
                let seed: UInt64 = era == "2017" ? 41 : 42
                print("== \(era) · \(mandate.title)")
                let a = run(era: era, mandate: mandate, seed: seed, years: years)
                let p = a.publicProgram
                if ProcessInfo.processInfo.environment["PUBLIC_MISSIONS"] != nil {
                    for m in p.missions { print("     \(m.status.rawValue) \(m.kind.rawValue): \(m.title) · issued \(m.issued.gameShort) due \(m.due.gameShort) · progress \(Int(m.progress * 100))% (target \(Fmt.trim(m.target, 2)), capability ≥ \(Fmt.trim(m.capabilityMin, 2)))") }
                    for h in a.history.suffix(36).enumerated().filter({ $0.offset % 6 == 5 }).map(\.element) {
                        print("     \(h.month.gameMonth): rev \(Fmt.money(h.revenue)) · payroll \(Fmt.money(h.costPayroll)) · power \(Fmt.money(h.costPower)) · sites \(Fmt.money(h.costSites)) · rent \(Fmt.money(h.costRent)) · data \(Fmt.money(h.costData)) · mkt \(Fmt.money(h.costMarketing)) · other \(Fmt.money(h.costOther + h.costChips + h.costGroup)) · capex \(Fmt.money(h.capex)) · rentals in other")
                    }
                    for c in p.commissions {
                        let best = Commissions.candidatesModels(c, a).first
                        print("     commission \(c.status.rawValue) \(c.agency) (\(c.domain.rawValue) \(Commissions.signed(c.domainEdgeMin))+, c ≥ \(Fmt.trim(c.capabilityMin, 2))\(c.internalOnly ? ", internal" : "")\(c.openWeights ? ", open" : "")\(c.securityMin > 0 ? ", SL\(c.securityMin)" : "")\(c.needsEvaluation ? ", evaluated" : "")) · paid \(Fmt.money(c.paid))"
                              + (best.map { m in " · best " + m.name + ": " + Commissions.checks(c, m, a).map { "\($0.met ? "✓" : "✗")\($0.label) \($0.detail)" }.joined(separator: ", ") } ?? ""))
                    }
                    for r in a.publicProgram.grants.reversed() { print("     request \(r.issued.gameShort) \(r.title) → \(r.status.rawValue) · tasks " + r.tasks.map { "\($0.done ? "✓" : "✗")\($0.title)" }.joined(separator: ", ")) }
                    print("     facility \(Fmt.watts(GovRequests.capacityKW(a) * 1000)), \(Fmt.int(GovRequests.fleet(a))) GPUs, \(Fmt.watts(GovRequests.committedKW(a) * 1000)) used")
                    print("     staff \(a.employees.count), best model c \(Fmt.trim(a.models.map(\.c).max() ?? 0, 2)), safety \(Int(a.safetyScore)), SL\(a.securityRaw), budget \(Fmt.money(PublicProgram.authorisedBudget(a)))/yr")
                }
                print("   level \(p.level) (\(PublicProgram.levelNames[clamp(p.level, 1, 4)])) · missions \(p.completedMissions) delivered, \(p.failedMissions) missed · oversight \(Int(p.oversight)) · received \(Fmt.money(p.totalReceived)) · cash \(Fmt.money(a.cash))\(a.gameOver.map { " · GAME OVER: \($0)" } ?? "")")
                expect("programme active", a.isPublicProgram)
                expect("no funding rounds or investor holdings", a.rounds.isEmpty && a.holdings.isEmpty, "\(a.rounds.count) rounds, \(a.holdings.count) holdings")
                expect("no founder wealth", a.founderNetWorth == 0)
                expect("no equity on staff", a.employees.allSatisfy { $0.equity == 0 }, "\(a.employees.filter { $0.equity > 0 }.count) with equity")
                expect("no partner equity", a.partnerships.allSatisfy { $0.equity == 0 })
                expect("no convertible notes", !a.corp.debts.contains { $0.kind == .convertible })
                expect("no private-exit decisions waiting", !a.decisions.contains { ["acquisition", "rival_round"].contains($0.kind) })
                expect("no board goals (missions replace them)", a.objectives.isEmpty)
                expect("appropriations arrived", p.totalReceived > 0, Fmt.money(p.totalReceived))
                expect("missions are issued", p.missions.contains { $0.status == .active } || a.gameOver != nil)
                expect("history stays bounded", p.missions.count <= PublicProgram.maxMissions && p.history.count <= PublicProgram.maxHistory)
                // 3.10: funding requests and agency commissions.
                expect("agencies send orders", !p.commissions.isEmpty || p.commissionSequence > 0, "\(p.commissionSequence) orders")
                expect("the national facility runs", GovRequests.capacityKW(a) >= GovRequests.facilityKW && GovRequests.fleet(a) >= 2_048,
                       "\(Fmt.watts(GovRequests.capacityKW(a) * 1000)), \(Fmt.int(GovRequests.fleet(a))) GPUs")
                expect("requests were granted, each with tasks", !p.grants.isEmpty && p.grants.allSatisfy { $0.tasks.count >= 2 },
                       "\(p.grantSequence) requests, \(p.grantsCompleted) met, \(p.grantsFailed) missed")
                expect("never more than \(GovRequests.maxOpen) requests open", GovRequests.open(a).count <= GovRequests.maxOpen)
                expect("commission and request records stay bounded", p.commissions.filter { ![.offered, .active, .inService].contains($0.status) }.count <= Commissions.maxRecord
                       && p.grants.filter { $0.status != .active }.count <= 12)
                delivered += p.commissionsDelivered
                paidInFull = paidInFull && p.commissions.filter { $0.delivered != nil && $0.status != .cancelled }.allSatisfy { $0.paid >= $0.value - 1 }
                print("     agency models: \(p.commissionsDelivered) delivered, \(p.commissionsFailed) missed")

                // Save round trip.
                let enc = JSONEncoder()
                enc.dateEncodingStrategy = .secondsSince1970
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .secondsSince1970
                if let data = try? enc.encode(a), let back = try? dec.decode(GameState.self, from: data) {
                    expect("save round trip keeps the programme", back.publicProgram == a.publicProgram)
                } else {
                    expect("save round trip keeps the programme", false, "encode/decode failed")
                }

                // Same seed, same game.
                let b = run(era: era, mandate: mandate, seed: seed, years: min(years, 1.5))
                let c = run(era: era, mandate: mandate, seed: seed, years: min(years, 1.5))
                expect("same seed, same programme", b.publicProgram == c.publicProgram && b.cash == c.cash)
            }
        }

        expect("agency models go into service and are paid in full", delivered > 0 && paidInFull, "\(delivered) delivered")

        print("== requests are granted with the tasks the page showed")
        var fresh = run(era: "2022", mandate: .digitalServices, seed: 9, years: 0)
        expect("a government game opens with a 100 MW facility full of GPUs", GovRequests.capacityKW(fresh) == GovRequests.facilityKW && GovRequests.fleet(fresh) == 8_192
               && fresh.sites.count == 1 && fresh.sites[0].stateFunded, "\(Fmt.watts(GovRequests.capacityKW(fresh) * 1000)), \(Fmt.int(GovRequests.fleet(fresh))) \(fresh.owned.first?.accelID ?? "")")
        let powerBefore = fresh.month.costPower
        Sim.advanceDay(&fresh)
        expect("the ministry pays the facility's power", fresh.month.costPower - powerBefore < 1, Fmt.money(fresh.month.costPower - powerBefore))
        let cash0 = fresh.cash
        let ask = (GovRequests.fundingRange(fresh).upperBound / 4 / 100_000).rounded() * 100_000
        let preview = GovRequests.tasks(fresh, tier: GovRequests.fundingTier(ask, fresh)).map(\.title)
        let granted = fresh.requestGovernmentFunding(ask)
        expect("funding is paid the day you ask", granted == nil && abs(fresh.cash - cash0 - ask) < 1, granted ?? Fmt.money(fresh.cash - cash0))
        expect("it carries the tasks the page previewed", fresh.publicProgram.grants.first?.tasks.map(\.title) == preview, preview.joined(separator: "; "))
        let oversight0 = fresh.publicProgram.oversight
        fresh.publicProgram.grants[0].due = GameCalendar.addDays(fresh.date, -1)
        GovRequests.daily(&fresh)
        expect("missed tasks cost oversight and withhold 30% of the money", fresh.publicProgram.grants[0].status == .failed && fresh.publicProgram.oversight < oversight0
               && abs(fresh.publicProgram.clawback - ask * GovRequests.clawbackShare) < 1, Fmt.money(fresh.publicProgram.clawback))
        let tranche = PublicProgram.nextTranche(fresh), held = fresh.publicProgram.clawback, cash1 = fresh.cash
        PublicProgram.payTranche(&fresh)
        expect("the withheld money comes off the next budget", abs(fresh.cash - cash1 - (tranche - min(held, tranche * 0.5))) < 1 && fresh.publicProgram.clawback < held)
        let fleet0 = GovRequests.fleet(fresh)
        expect("GPUs can be requested", fresh.requestGovernmentChips(1_024) == nil)
        if let i = fresh.publicProgram.grants.firstIndex(where: { $0.kind == .chips }) { fresh.publicProgram.grants[i].arrives = fresh.date }
        GovRequests.daily(&fresh)
        expect("granted GPUs arrive at the facility", GovRequests.fleet(fresh) == fleet0 + 1_024, "\(Fmt.int(GovRequests.fleet(fresh) - fleet0)) arrived")
        expect("more power waits until the facility is half full", GovRequests.powerBlocker(fresh) != nil && fresh.requestGovernmentPower(100_000) != nil)
        _ = fresh.requestGovernmentFunding(ask)
        _ = fresh.requestGovernmentFunding(ask)
        expect("a fourth open request is refused", GovRequests.open(fresh).count == GovRequests.maxOpen && fresh.requestGovernmentFunding(ask) != nil)
        let ids = Set(Commissions.agencies.map(\.name))
        expect("every agency is distinct", ids.count == Commissions.agencies.count)

        print("== startup unaffected")
        var st = ScenarioHarness.newGame(era: "2022", seed: 7)
        expect("a startup has no programme", !st.isPublicProgram && !st.rounds.isEmpty && st.founderNetWorth > 0)
        ScenarioHarness.idle(&st, days: 120)
        expect("still no programme after 120 days", !st.isPublicProgram && st.publicProgram.missions.isEmpty)

        print(failures == 0 ? "OK: public programme checks passed" : "FAILED: \(failures) checks")
        return failures == 0 ? 0 : 1
    }

    static func run(era: String, mandate: PublicMandate, seed: UInt64, years: Double) -> GameState {
        var settings = NewGameSettings()
        settings.companyName = "Public AI \(era)"
        settings.founderName = "Director"
        settings.eraID = era
        settings.origin = .government
        settings.publicMandate = mandate
        var s = NewGame.create(settings, seed: seed)
        var bot = PTBot()
        bot.flags = ["norent", "lean"]   // a branch on an appropriation trains on its own chips, not venture-scale cloud rentals
        for day in 0..<Int(years * 365) where s.gameOver == nil {
            ScenarioHarness.play(&s, &bot, days: 1)
            if day % 7 == 0 { missionBot(&s) }
        }
        return s
    }

    /// What a director would do for the active missions, on top of the startup-minded scenario bot: release or open a
    /// qualifying model, commission an evaluation, start the next security level, hire. Only with cash to spare.
    static func missionBot(_ s: inout GameState) {
        let reserve = PublicProgram.authorisedBudget(s) / 8
        // Agency orders: the scenario bot releases every model it trains, closed, so take only orders that allow that.
        for offer in Commissions.open(s) {
            if offer.internalOnly || offer.openWeights { s.declineCommission(offer.id) }
            else if Commissions.active(s).count < Commissions.maxActive { _ = s.acceptCommission(offer.id) }
        }
        for c in Commissions.active(s) {
            if let m = s.models.first(where: { Commissions.qualifies(c, $0, s) }) { _ = s.deliverCommission(c.id, modelID: m.id) }
        }
        // Requests: a modest top-up when reserves run low, GPUs while the facility has room, power once it's half full.
        let open = GovRequests.open(s)
        if open.count < 2 {
            if !open.contains(where: { $0.kind == .funding }), s.cash < PublicProgram.authorisedBudget(s) / 2 {
                _ = s.requestGovernmentFunding(PublicProgram.authorisedBudget(s) * 0.25)
            } else if !open.contains(where: { $0.kind == .chips }), GovRequests.chipRange(s).upperBound >= 512 {
                _ = s.requestGovernmentChips(min(2_048, GovRequests.chipRange(s).upperBound))
            } else if GovRequests.powerBlocker(s) == nil {
                _ = s.requestGovernmentPower(100_000)
            }
        }
        // Never release a model an agency runs internally.
        let internalModels = Set(s.publicProgram.commissions.filter { $0.internalOnly && ($0.status == .inService || $0.status == .active) }.compactMap(\.modelID))
        let wanted = Commissions.active(s).filter(\.internalOnly)
        for m in s.publicProgram.missions where m.status == .active {
            switch m.kind {
            case .release, .openWeights:
                let open = m.kind == .openWeights
                let free = s.models.filter { model in
                    !model.released && !model.retired && !model.preview && model.c >= m.capabilityMin && !internalModels.contains(model.id)
                        && !wanted.contains { c in model.created >= (c.accepted ?? c.offered) }
                }
                if let model = free.max(by: { $0.c < $1.c }) {
                    _ = s.release(model.id, api: true, openWeights: open)
                } else if open, let model = s.releasedModels.filter({ !$0.openWeights && $0.created >= m.issued && $0.c >= m.capabilityMin }).first {
                    _ = model   // already released closed: the next model will be opened
                }
            case .evaluate:
                if let model = s.models.filter({ $0.created >= m.issued && !$0.evaluated && $0.evalDue == nil }).max(by: { $0.c < $1.c }),
                   s.cash - Evaluations.cost(s, model) > reserve {
                    _ = s.evaluateModel(model.id)
                }
            case .security:
                if s.securityTarget <= s.security.rawValue, s.cash > reserve * 2 { _ = s.upgradeSecurity() }
            case .hire:
                if s.cash > reserve * 2, let c = s.candidates.min(by: { $0.salary < $1.salary }) { _ = s.hire(c.id) }
            default:
                break
            }
        }
    }
}
