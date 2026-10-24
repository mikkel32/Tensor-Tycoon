import Foundation

/// A government career is a parallel operating model: appropriations and measurable public value replace dilution and
/// investor milestones. All mission generation is deterministic and its storage is bounded.
enum PublicProgram {
    static let activeTarget = 2
    static let maxMissions = 24
    static let maxHistory = 40
    static let levelNames = ["", "Pilot unit", "National programme", "AI directorate", "National AI service"]
    static let promotionThresholds = [0, 3, 7, 12]
    static let budgetMultipliers = [1.0, 1.75, 3.0, 5.0]

    static func authorisedBudget(_ s: GameState) -> Double {
        let level = clamp(s.publicProgram.level, 1, 4)
        return s.publicProgram.annualBudget * budgetMultipliers[level - 1]
    }

    static func nextTranche(_ s: GameState) -> Double {
        let carry = max(0, s.cash) / max(1, authorisedBudget(s))
        let carryFactor = carry > 1.25 ? 0.7 : carry > 0.75 ? 0.85 : 1
        let performance = clamp(0.8 + s.publicProgram.oversight / 250, 0.85, 1.2)
        let probation = s.publicProgram.probation ? 0.75 : 1
        return authorisedBudget(s) / 4 * carryFactor * performance * probation
    }

    static func found(_ s: inout GameState, mandate: PublicMandate) {
        s.publicProgram.active = true
        s.publicProgram.mandate = mandate
        s.publicProgram.level = 1
        s.publicProgram.annualBudget = max(8_000_000, s.cash * 4)
        s.publicProgram.oversight = 70
        s.publicProgram.lastTranche = s.date
        s.publicProgram.lastReview = s.date
        s.boardConfidence = 70
        fillMissions(&s)
        note(&s, "Established under the \(mandate.title) mandate with two opening public missions.", good: true)
    }

    static func mission(_ s: GameState, sequence: Int) -> PublicMission? {
        let p = s.publicProgram
        let orders: [PublicMissionKind]
        switch p.mandate {
        case .digitalServices: orders = [.release, .train, .hire, .evaluate, .safety, .security]
        case .openScience: orders = [.openWeights, .research, .release, .safety, .train, .evaluate]
        case .nationalSecurity: orders = [.security, .train, .evaluate, .safety, .research, .release]
        }
        let active = Set(p.missions.filter { $0.status == .active }.map(\.kind))
        guard let kind = (0..<orders.count).lazy.map({ orders[(sequence + $0) % orders.count] }).first(where: { !active.contains($0) }) else { return nil }
        let id = "public-\(sequence + 1)"
        let level = clamp(p.level, 1, 4)
        let frontier = Macro.frontier(s.year)
        let capability = frontier - 1.8 + Double(level) * 0.15
        let days: Int
        let title: String
        let detail: String
        var target = 1.0
        var baseline = 0.0
        var researchID = ""
        switch kind {
        case .train:
            target = level >= 3 ? 2 : 1
            days = 180
            title = target == 1 ? "Train a public-interest model" : "Train two public-interest models"
            detail = "Complete \(Int(target)) new full model\(target == 1 ? "" : "s") at capability \(Fmt.trim(capability, 2)) or higher. Use the training workflow to make the result repeatable."
        case .release:
            days = 180
            title = "Put a model into public service"
            detail = "Release a new model at capability \(Fmt.trim(capability, 2)) or higher. A trained artefact alone does not complete this mission."
        case .evaluate:
            days = 150
            title = "Independently evaluate a new model"
            detail = "Complete a dangerous-capability evaluation for a model created after this mission was issued."
        case .research:
            let candidate = ResearchCatalog.core.filter {
                !s.researched.contains($0.id) && $0.year <= s.year + 1.5 && $0.prereqs.allSatisfy { s.researched.contains($0) }
            }.sorted { a, b in a.year != b.year ? a.year < b.year : a.id < b.id }.first
            guard let candidate else { return nil }
            researchID = candidate.id
            days = 240
            title = "Deliver research: \(candidate.name)"
            detail = "Finish \(candidate.name) and make the capability available to the programme."
        case .hire:
            target = Double(2 + level)
            baseline = Double(s.employees.count)
            days = 150
            title = "Build a public AI team"
            detail = "Hire \(Int(target)) additional people. Capability needs durable operational capacity, not only compute."
        case .openWeights:
            days = 210
            title = "Publish open weights"
            detail = "Release a new model with open weights so outside researchers can inspect and build on the work."
        case .safety:
            target = min(95, 55 + Double(level) * 5)
            days = 210
            title = "Raise the safety baseline to \(Int(target))"
            detail = "Reach a programme-wide safety score of \(Int(target)) before the deadline."
        case .security:
            target = Double(min(4, level + 1))
            days = 240
            title = "Accredit security level \(Int(target))"
            detail = "Raise the programme's security level to SL\(Int(target)) and protect public AI infrastructure."
        }
        let reward = max(1_000_000, authorisedBudget(s) * 0.025 * min(2, target))
        return PublicMission(id: id, kind: kind, title: title, detail: detail, issued: s.date,
                             due: GameCalendar.addDays(s.date, days), target: target, baseline: baseline,
                             capabilityMin: capability, researchID: researchID, reward: reward)
    }

    static func fillMissions(_ s: inout GameState) {
        guard s.publicProgram.active else { return }
        var attempts = 0
        while s.publicProgram.missions.filter({ $0.status == .active }).count < activeTarget && attempts < 16 {
            attempts += 1
            let sequence = s.publicProgram.sequence
            s.publicProgram.sequence += 1
            if let mission = mission(s, sequence: sequence) { s.publicProgram.missions.append(mission) }
        }
        trim(&s)
    }

    /// Current value and normalised progress. Cumulative counts only include work delivered after issuance.
    static func measure(_ m: PublicMission, _ s: GameState) -> (value: Double, progress: Double) {
        let current: Double
        switch m.kind {
        case .train:
            current = Double(s.models.filter { $0.created >= m.issued && $0.c >= m.capabilityMin && !$0.preview }.count) - m.baseline
        case .release:
            current = Double(s.releasedModels.filter { ($0.releaseDate ?? $0.created) >= m.issued && $0.c >= m.capabilityMin }.count) - m.baseline
        case .evaluate:
            current = Double(s.models.filter { $0.created >= m.issued && $0.evaluated }.count) - m.baseline
        case .research:
            current = s.researched.contains(m.researchID) ? 1 : 0
        case .hire:
            current = Double(s.employees.count) - m.baseline
        case .openWeights:
            current = Double(s.releasedModels.filter { ($0.releaseDate ?? $0.created) >= m.issued && $0.openWeights }.count) - m.baseline
        case .safety:
            current = s.safetyScore
        case .security:
            current = Double(s.securityRaw)
        }
        return (current, clamp(current / max(0.0001, m.target), 0, 1))
    }

    static func daily(_ s: inout GameState) {
        guard s.publicProgram.active else { return }
        for i in s.publicProgram.missions.indices where s.publicProgram.missions[i].status == .active {
            let mission = s.publicProgram.missions[i]
            let measured = measure(mission, s)
            s.publicProgram.missions[i].progress = measured.progress
            if measured.progress >= 1 {
                complete(&s, i)
            } else if s.date > mission.due {
                fail(&s, i)
            }
        }
        fillMissions(&s)
        if let last = s.publicProgram.lastTranche, GameCalendar.daysBetween(last, s.date) >= 90 {
            payTranche(&s)
        }
        if s.publicProgram.lastTranche == nil { s.publicProgram.lastTranche = s.date }
        reviewIfNeeded(&s)
    }

    static func monthly(_ s: inout GameState) {
        guard s.publicProgram.active else { return }
        var target = 45.0
        target += (s.safetyScore - 50) * 0.25
        target += s.publicProgram.deliveryStreak > 0 ? min(12, Double(s.publicProgram.deliveryStreak) * 2) : -4
        target += s.cash < 0 ? -15 : 4
        target += (s.world.publicTrust - 50) * 0.12
        if s.publicProgram.probation { target -= 5 }
        s.publicProgram.oversight = clamp(s.publicProgram.oversight + (clamp(target, 10, 90) - s.publicProgram.oversight) * 0.12, 0, 100)
        if s.publicProgram.oversight < 30 { s.publicProgram.probation = true }
        if s.publicProgram.oversight >= 45 { s.publicProgram.probation = false }
        s.boardConfidence = s.publicProgram.oversight
        checkPromotion(&s)
    }

    static func complete(_ s: inout GameState, _ i: Int) {
        let mission = s.publicProgram.missions[i]
        s.publicProgram.missions[i].status = .completed
        s.publicProgram.missions[i].closed = s.date
        s.publicProgram.missions[i].progress = 1
        s.publicProgram.completedMissions += 1
        s.publicProgram.deliveryStreak += 1
        s.publicProgram.oversight = clamp(s.publicProgram.oversight + 4, 0, 100)
        s.cash += mission.reward
        s.month.revContracts += mission.reward
        s.publicProgram.totalReceived += mission.reward
        s.culturePoints += 1
        note(&s, "Mission delivered: \(mission.title). \(Fmt.money(mission.reward)) results payment and +1 culture point.", good: true)
        Stakeholders.move(&s, ["public": 1.5, "researchers": mission.kind == .openWeights || mission.kind == .research ? 1 : 0],
                          "Public mission delivered: \(mission.title)")
        Sim.news(&s, "Public mission delivered", "\(mission.title). Oversight releases \(Fmt.money(mission.reward)) in results funding; confidence rises and the programme earns a culture point.",
                 .policy, image: "gov_capitol", important: true, good: true)
        checkPromotion(&s)
    }

    static func fail(_ s: inout GameState, _ i: Int) {
        let mission = s.publicProgram.missions[i]
        s.publicProgram.missions[i].status = .failed
        s.publicProgram.missions[i].closed = s.date
        s.publicProgram.failedMissions += 1
        s.publicProgram.deliveryStreak = 0
        s.publicProgram.oversight = clamp(s.publicProgram.oversight - 8, 0, 100)
        note(&s, "Mission missed: \(mission.title). Oversight confidence fell by 8.", good: false)
        Sim.news(&s, "Public mission missed", "\(mission.title). The deadline passed; oversight confidence falls and the next authorisation may be tighter.",
                 .policy, important: true, good: false)
    }

    static func payTranche(_ s: inout GameState) {
        let amount = nextTranche(s)
        s.publicProgram.lastTranche = s.date
        s.cash += amount
        s.month.revContracts += amount
        s.publicProgram.totalReceived += amount
        note(&s, "Quarterly appropriation received: \(Fmt.money(amount)).", good: true)
        Sim.news(&s, "Quarterly appropriation: \(Fmt.money(amount))",
                 "The \(levelNames[clamp(s.publicProgram.level, 1, 4)]) receives its quarterly tranche. Delivery, oversight, existing reserves and probation all affect the release.",
                 .policy, image: "gov_capitol", good: true)
    }

    static func reviewIfNeeded(_ s: inout GameState) {
        guard s.publicProgram.oversight < 45, s.gameOver == nil else { return }
        if let last = s.publicProgram.lastReview, GameCalendar.daysBetween(last, s.date) < 120 { return }
        s.publicProgram.lastReview = s.date
        Events.addDecision(&s, kind: "public_review", title: "Oversight review of \(s.companyName)",
                           body: "Confidence is \(Int(s.publicProgram.oversight))/100. The committee wants a credible response before the next appropriation.",
                           image: "gov_capitol",
                           options: [DecisionOption(label: "Accept an independent audit", detail: "Oversight +10; active mission deadlines move out 30 days while the audit runs."),
                                     DecisionOption(label: "Commit to a delivery plan", detail: "Oversight +5 immediately; no deadline extension."),
                                     DecisionOption(label: "Reorganise the programme", detail: "Oversight +7; replace both active missions and lose 5 days on their deadlines.")])
    }

    static func resolveReview(_ s: inout GameState, option: Int) {
        guard s.publicProgram.active else { return }
        switch option {
        case 0:
            s.publicProgram.oversight = clamp(s.publicProgram.oversight + 10, 0, 100)
            for i in s.publicProgram.missions.indices where s.publicProgram.missions[i].status == .active {
                s.publicProgram.missions[i].due = GameCalendar.addDays(s.publicProgram.missions[i].due, 30)
            }
            note(&s, "Independent audit accepted: oversight +10; active deadlines extended 30 days.", good: true)
        case 1:
            s.publicProgram.oversight = clamp(s.publicProgram.oversight + 5, 0, 100)
            note(&s, "Delivery plan accepted: oversight +5.", good: true)
        default:
            s.publicProgram.oversight = clamp(s.publicProgram.oversight + 7, 0, 100)
            for i in s.publicProgram.missions.indices where s.publicProgram.missions[i].status == .active {
                s.publicProgram.missions[i].status = .replaced
                s.publicProgram.missions[i].closed = s.date
            }
            fillMissions(&s)
            for i in s.publicProgram.missions.indices where s.publicProgram.missions[i].status == .active {
                s.publicProgram.missions[i].due = GameCalendar.addDays(s.publicProgram.missions[i].due, -5)
            }
            note(&s, "Programme reorganised: oversight +7 and both missions replaced.", good: nil)
        }
        s.boardConfidence = s.publicProgram.oversight
    }

    static func checkPromotion(_ s: inout GameState) {
        let next = s.publicProgram.level + 1
        guard next <= 4 else { return }
        let required = promotionThresholds[next - 1]
        let oversightRequired = [0.0, 0, 55, 60, 65][next]
        let safetyRequired = [0.0, 0, 50, 55, 60][next]
        guard s.publicProgram.completedMissions >= required,
              s.publicProgram.oversight >= oversightRequired,
              s.safetyScore >= safetyRequired else { return }
        s.publicProgram.level = next
        s.culturePoints += 2
        grantSupport(&s, level: next)
        note(&s, "Promoted to \(levelNames[next]): larger authorisation, infrastructure support and +2 culture points.", good: true)
        Sim.news(&s, "Programme expanded: \(levelNames[next])",
                 "After \(required) delivered missions, the mandate expands. Annual authorisation is now \(Fmt.money(authorisedBudget(s))); new compute and facilities support arrives.",
                 .policy, image: "gov_capitol", important: true, good: true)
    }

    static func grantSupport(_ s: inout GameState, level: Int) {
        guard var site = s.sites.first else { return }
        let power = [0.0, 0, 24, 64, 160][level]
        let chips = [0, 0, 8, 16, 32][level]
        site.capacityKW += power
        s.sites[0] = site
        let available = HardwareCatalog.all.filter {
            $0.purchasable && $0.available <= s.date.ym && ($0.discontinued.map { $0 > s.date.ym } ?? true)
        }.sorted { a, b in a.bf16 != b.bf16 ? a.bf16 < b.bf16 : a.id < b.id }
        if let accelerator = available.last {
            s.owned.append(OwnedBatch(accelID: accelerator.id, count: chips, siteID: site.id,
                                      purchased: s.date, unitCost: 0))
            Sim.mergeOwned(&s)
        }
    }

    static func trim(_ s: inout GameState) {
        guard s.publicProgram.missions.count > maxMissions else { return }
        let excess = s.publicProgram.missions.count - maxMissions
        let closedIDs = Set(s.publicProgram.missions.filter { $0.status != .active }.prefix(excess).map(\.id))
        s.publicProgram.missions.removeAll { closedIDs.contains($0.id) }
        if s.publicProgram.missions.count > maxMissions {
            s.publicProgram.missions.removeFirst(s.publicProgram.missions.count - maxMissions)
        }
    }

    static func note(_ s: inout GameState, _ text: String, good: Bool?) {
        s.publicProgram.logSequence += 1
        let record = PublicAuditRecord(id: "public-log-\(s.publicProgram.logSequence)", date: s.date, text: text, good: good)
        s.publicProgram.history.insert(record, at: 0)
        if s.publicProgram.history.count > maxHistory {
            s.publicProgram.history.removeLast(s.publicProgram.history.count - maxHistory)
        }
    }
}

extension GameState {
    var isPublicProgram: Bool { publicProgram.active }

    mutating func publishPublicTransparency() -> String? {
        guard isPublicProgram else { return "Only a government AI branch publishes programme transparency reports." }
        if let last = publicProgram.lastTransparency, GameCalendar.daysBetween(last, date) < 60 {
            return "The last report is still being reviewed. Try again after \(GameCalendar.addDays(last, 60).gameShort)."
        }
        let cost = max(250_000, PublicProgram.authorisedBudget(self) * 0.002)
        guard cash >= cost else { return "A credible report costs \(Fmt.money(cost)); the programme does not have enough cash." }
        cash -= cost
        month.costOther += cost
        publicProgram.lastTransparency = date
        publicProgram.oversight = clamp(publicProgram.oversight + 5, 0, 100)
        boardConfidence = publicProgram.oversight
        Stakeholders.move(&self, ["public": 2, "researchers": 1], "Public AI transparency report")
        PublicProgram.note(&self, "Transparency report published for \(Fmt.money(cost)): oversight +5 and public trust improved.", good: true)
        Sim.news(&self, "Public AI transparency report", "Model evaluations, mission delivery and programme spending are now on the public record.", .policy, good: true)
        return nil
    }

    mutating func requestPublicSupplement() -> String? {
        guard isPublicProgram else { return "Only a government AI branch can request an appropriation supplement." }
        let year = GameCalendar.components(date).year
        guard publicProgram.supplementalYear != year else { return "A supplemental request was already made this calendar year." }
        guard publicProgram.oversight >= 35 else { return "Oversight will not consider a supplement below 35 confidence." }
        let amount = PublicProgram.authorisedBudget(self) * 0.12 * clamp(publicProgram.oversight / 70, 0.6, 1.25)
        publicProgram.supplementalYear = year
        publicProgram.lastSupplemental = date
        publicProgram.oversight = clamp(publicProgram.oversight - 6, 0, 100)
        boardConfidence = publicProgram.oversight
        cash += amount
        month.revContracts += amount
        publicProgram.totalReceived += amount
        PublicProgram.note(&self, "Supplemental appropriation approved: \(Fmt.money(amount)); oversight -6.", good: true)
        Sim.news(&self, "Supplemental appropriation approved", "\(Fmt.money(amount)) is released for urgent programme needs. Using this annual exception costs oversight confidence.", .policy, good: true)
        return nil
    }

    mutating func rerollPublicMission(_ id: String) -> String? {
        guard isPublicProgram else { return "No public programme." }
        if let last = publicProgram.lastReroll, GameCalendar.daysBetween(last, date) < 45 {
            return "Mission priorities can be renegotiated again after \(GameCalendar.addDays(last, 45).gameShort)."
        }
        guard publicProgram.oversight >= 12 else { return "Oversight is too low to renegotiate the mandate." }
        guard let i = publicProgram.missions.firstIndex(where: { $0.id == id && $0.status == .active }) else { return "Mission not found or already closed." }
        publicProgram.missions[i].status = .replaced
        publicProgram.missions[i].closed = date
        publicProgram.lastReroll = date
        publicProgram.oversight = clamp(publicProgram.oversight - 3, 0, 100)
        boardConfidence = publicProgram.oversight
        PublicProgram.note(&self, "Mission renegotiated: oversight -3 and a replacement was issued.", good: nil)
        PublicProgram.fillMissions(&self)
        return nil
    }
}
