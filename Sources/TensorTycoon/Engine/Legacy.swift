import Foundation

// MARK: - 3.9: New Game+ legacy perks

/// A small head start a finished company leaves to the next one. Each ending unlocks one; the new-game screen offers
/// the unlocked ones (one slot, two after three different endings, three after seven). They are one-off grants at
/// founding — cash, a veteran hire, standing, political capital — so the world the new company starts in is the same.
enum LegacyPerk: String, CaseIterable, Identifiable, Sendable {
    case pedigree, seat, trusted, oldMoney, notebooks, serial, cleared, scrappy, redTeam, charter, emeritus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pedigree: "Alignment Pedigree"
        case .seat: "Seat at the Table"
        case .trusted: "Trusted Name"
        case .oldMoney: "Old Money"
        case .notebooks: "Strange Notebooks"
        case .serial: "Serial Founder"
        case .cleared: "Old Clearances"
        case .scrappy: "Hard Lessons"
        case .redTeam: "Red-Team Veterans"
        case .charter: "Ironclad Charter"
        case .emeritus: "Emeritus Network"
        }
    }

    var detail: String {
        switch self {
        case .pedigree: "A veteran safety researcher (skill 86) joins at founding, and the safety record starts 5 points higher."
        case .seat: "Start with 25 political capital and +6 standing with your home government."
        case .trusted: "Brand +6 and public trust +6 from day one."
        case .oldMoney: "Your old investors come back: 25% more starting cash."
        case .notebooks: "Your first two research projects start half done."
        case .serial: "A cofounder who's done this before (ML engineer, skill 80) joins, and you get +1 culture point."
        case .cleared: "Start with 15 political capital and +4 standing with every government."
        case .scrappy: "+2 culture points and a credit score 40 points higher: you know what running out feels like."
        case .redTeam: "Model weights start at security level 2 and the safety record 3 points higher."
        case .charter: "A founder-friendly charter: board confidence +15 and 5% more of the shares are yours."
        case .emeritus: "Old colleagues open doors: board confidence +10 and brand +3."
        }
    }

    var symbol: String {
        switch self {
        case .pedigree: "checkmark.shield.fill"
        case .seat: "signature"
        case .trusted: "hand.thumbsup.fill"
        case .oldMoney: "banknote.fill"
        case .notebooks: "book.closed.fill"
        case .serial: "person.2.fill"
        case .cleared: "building.columns.fill"
        case .scrappy: "hammer.fill"
        case .redTeam: "lock.shield.fill"
        case .charter: "doc.text.fill"
        case .emeritus: "person.crop.circle.badge.checkmark"
        }
    }

    /// Endings that unlock it.
    var unlockedBy: [EndingKind] { EndingKind.allCases.filter { $0.perk == self } }
}

enum Legacy {
    /// Perks a new company may take, given how many different endings this player has reached.
    static func slots(endings: Int) -> Int { 1 + (endings >= 3 ? 1 : 0) + (endings >= 7 ? 1 : 0) }

    /// A deterministic name for a veteran hire (no draw from the game's RNG, so perks never change the world).
    static func veteranName(_ s: GameState, _ key: String) -> String {
        let f = NameBank.first, l = NameBank.last
        let a = Int(RivalIntel.unit("legacy|\(s.companyName)|\(key)|f") * Double(f.count)) % f.count
        let b = Int(RivalIntel.unit("legacy|\(s.companyName)|\(key)|l") * Double(l.count)) % l.count
        return "\(f[a]) \(l[b])"
    }

    /// Applies the chosen perks to a company being founded (NewGame), after the world is set up.
    static func apply(_ s: inout GameState, _ ids: [String]) {
        let perks = ids.compactMap(LegacyPerk.init(rawValue:))
        guard !perks.isEmpty else { return }
        let y = s.date.decimalYear
        s.endings.perks = perks.map(\.rawValue)
        for p in perks {
            switch p {
            case .pedigree:
                s.employees.append(Employee(name: veteranName(s, "safety"), role: .safety, skill: 86,
                                            salary: (Macro.salary(.safety, y) * HQ.salaryFactor(s) / 1000).rounded() * 1000, morale: 90, hired: s.date, equity: 0.5))
                s.safetyAdjust += 5
                s.safetyScore = min(100, s.safetyScore + 5)
            case .seat:
                s.politicalCapital = max(s.politicalCapital, 25)
                Stakeholders.move(&s, [HQ.region(s).rawValue: 6], "Legacy: a seat at the table from your last company")
            case .trusted:
                s.brand = min(100, s.brand + 6)
                Stakeholders.move(&s, ["public": 6], "Legacy: a trusted name from your last company")
            case .oldMoney:
                // The extra cash comes in the seed round, on the same terms.
                let extra = s.cash * 0.25
                s.cash += extra
                if !s.rounds.isEmpty { s.rounds[0].amount += extra }
                s.valuation += extra
            case .notebooks:
                for e in s.researchQueue.prefix(2) { s.researchProgress[e] = max(s.researchProgress[e] ?? 0, ResearchLab.entryCost(s, e) * 0.5) }
            case .serial:
                s.employees.append(Employee(name: veteranName(s, "cofounder"), role: .mlEngineer, skill: 80,
                                            salary: (Macro.salary(.mlEngineer, y) * 0.8 * HQ.salaryFactor(s) / 1000).rounded() * 1000, morale: 90, hired: s.date, equity: 1.0))
                s.culturePoints += 1
            case .cleared:
                s.politicalCapital = max(s.politicalCapital, 15)
                Stakeholders.move(&s, Stakeholders.everyGovernment(4), "Legacy: old clearances from your last company")
            case .scrappy:
                s.culturePoints += 2
                s.creditScore = min(850, s.creditScore + 40)
            case .redTeam:
                s.securityRaw = max(s.securityRaw, 2)
                s.securityTarget = max(s.securityTarget, 2)
                s.safetyAdjust += 3
                s.safetyScore = min(100, s.safetyScore + 3)
            case .charter:
                s.boardConfidence = min(100, s.boardConfidence + 15)
                // 5% of the company moves from the employee pool to the founder, keeping the total.
                let move = min(s.employeePoolShares, s.totalShares * 0.05)
                s.employeePoolShares -= move
                s.founderShares += move
            case .emeritus:
                s.boardConfidence = min(100, s.boardConfidence + 10)
                s.brand = min(100, s.brand + 3)
            }
        }
        Sim.news(&s, "Legacy: \(perks.map(\.title).joined(separator: ", "))",
                 "What your last company left you: " + perks.map { "\($0.title) — \($0.detail)" }.joined(separator: " "), .company, important: true, good: true)
    }
}

/// 3.9: endings reached and perks unlocked across every game, kept in the app's preferences (never in a save), like
/// the Hall of Fame. The epilogue records the game the first time it's shown.
struct LegacyVault: Codable {
    struct Record: Codable, Hashable {
        var company: String
        var date: Date
        var score: Int
        var game: String
    }

    /// EndingKind raw value → the best game that reached it.
    var endings: [String: Record] = [:]
    /// Games already recorded (HallOfFame.gameKey), so reopening an ended save doesn't count twice.
    var games: [String] = []
    /// Ending reached by each recorded game, newest last, capped.
    var log: [Record] = []

    static let key = "legacyVault.v1"

    var unlocked: Set<LegacyPerk> { Set(endings.keys.compactMap { EndingKind(rawValue: $0)?.perk }) }
    var slots: Int { Legacy.slots(endings: endings.count) }

    /// Folds a finished game in. Returns the perks it newly unlocked.
    mutating func note(_ s: GameState) -> [LegacyPerk] {
        guard s.gameOver != nil else { return [] }
        let game = HallOfFame.gameKey(s)
        guard !games.contains(game) else { return [] }
        games.append(game)
        if games.count > 300 { games.removeFirst(games.count - 300) }
        let k = Endings.classify(s)
        let before = unlocked
        let score = s.endings.finalScore > 0 ? s.endings.finalScore : Endings.score(s, k).total
        let rec = Record(company: s.companyName, date: s.endings.endedOn ?? s.date, score: score, game: game)
        if endings[k.rawValue].map({ score > $0.score }) ?? true { endings[k.rawValue] = rec }
        log.append(Record(company: "\(s.companyName) — \(k.title)", date: rec.date, score: score, game: game))
        if log.count > 100 { log.removeFirst(log.count - 100) }
        return LegacyPerk.allCases.filter { unlocked.contains($0) && !before.contains($0) }
    }

    static func load(_ defaults: UserDefaults = .standard) -> LegacyVault {
        guard let data = defaults.data(forKey: key), let v = try? JSONDecoder().decode(LegacyVault.self, from: data) else { return LegacyVault() }
        return v
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    /// Notes the finished game and saves. Returns the perks just unlocked.
    static func record(_ s: GameState) -> [LegacyPerk] {
        var v = load()
        let new = v.note(s)
        v.save()
        return new
    }
}
