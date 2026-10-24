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
                    for r in a.publicProgram.requests.reversed() { print("     request \(r.date.gameShort) \(r.ask.rawValue) case \(Int(r.score)) → \(Fmt.pct(r.fraction, decimals: 0)) \(Fmt.money(r.amount))") }
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
                expect("a funding request was approved", !p.requests.isEmpty, "\(p.requests.count) approved")
                let gaps = zip(p.requests.dropFirst(), p.requests).map { GameCalendar.daysBetween($0.0.date, $0.1.date) }
                expect("one request a quarter", gaps.allSatisfy { abs($0) >= PublicFunding.cooldownDays }, gaps.map(String.init).joined(separator: ", "))
                expect("commission record stays bounded", p.commissions.filter { ![.offered, .active, .inService].contains($0.status) }.count <= Commissions.maxRecord
                       && p.requests.count <= 12)
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

        print("== funding requests show their answer first")
        var fresh = run(era: "2022", mandate: .digitalServices, seed: 9, years: 0)
        let cash0 = fresh.cash, budget0 = fresh.publicProgram.annualBudget
        let refused = fresh.requestPublicFunding(.moonshot)
        expect("a weak case is refused without cost", refused != nil && fresh.cash == cash0 && fresh.publicProgram.annualBudget == budget0 && fresh.publicProgram.lastRequest == nil, refused ?? "accepted")
        fresh.publicProgram.oversight = 90
        fresh.researched.formUnion(ResearchCatalog.core.prefix(12).map(\.id))
        let o = PublicFunding.outcome(.modest, fresh)
        let accepted = fresh.requestPublicFunding(.modest)
        expect("a case over the bar pays what the card said", accepted == nil && abs(fresh.cash - cash0 - o.amount) < 1, accepted ?? Fmt.money(fresh.cash - cash0))
        expect("a second request waits a quarter", fresh.requestPublicFunding(.modest) != nil)
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
        // Funding: the biggest ask the committee would grant in full, else a partial top-up.
        if PublicFunding.readyOn(s) == nil {
            if let ask = FundingAsk.allCases.reversed().first(where: { PublicFunding.outcome($0, s).fraction >= 1 }) ?? (PublicFunding.outcome(.modest, s).fraction > 0.5 ? .modest : nil) {
                _ = s.requestPublicFunding(ask)
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
