import Foundation

/// Who reached a milestone first, with which model, and when.
struct MilestoneWin: Codable, Hashable, Identifiable {
    /// The milestone's ID.
    var id: String
    /// "player" for you.
    var labID: String
    var lab: String
    var model: String
    var date: Date
    /// Reached before your game began (credited from history, no news or bump).
    @D var history: Bool = false

    var isPlayer: Bool { labID == "player" }
}

// MARK: - 3.4: the race for AI milestones

enum Milestones {
    /// How many capability points below a threshold count as 0% of the way there (25 points ≈ 300× effective compute,
    /// about three years of frontier progress).
    static let span = 25.0

    /// One released model that might cross a milestone.
    struct Contender {
        var labID: String
        var lab: String
        var model: String
        var date: Date
        var scores: DomainScores
    }

    static func won(_ s: GameState) -> Set<String> { Set(s.milestoneWins.map(\.id)) }

    static func meets(_ v: DomainScores, _ m: MilestoneDef) -> Bool {
        m.needs.allSatisfy { v[$0.0] >= $0.1 }
    }

    /// How close scores are to a milestone, 0–1 (the weakest requirement decides).
    static func closeness(_ v: DomainScores?, _ m: MilestoneDef) -> Double {
        guard let v else { return 0 }
        return m.needs.map { clamp(1 - ($0.1 - v[$0.0]) / span, 0, 1) }.min() ?? 0
    }

    /// Capability points still missing (the largest gap over the requirements).
    static func gap(_ v: DomainScores?, _ m: MilestoneDef) -> Double {
        guard let v else { return .infinity }
        return m.needs.map { max(0, $0.1 - v[$0.0]) }.max() ?? 0
    }

    /// Every released model, yours and the rivals', with its scores.
    static func contenders(_ s: GameState) -> [Contender] {
        var out: [Contender] = []
        for c in s.competitors {
            let name = c.def.name
            for m in c.models + c.openModels {
                guard let v = s.domainScores[m.id.uuidString] else { continue }
                out.append(Contender(labID: c.id, lab: name, model: m.name, date: m.date, scores: v))
            }
        }
        for m in s.models where m.released {
            guard let v = s.domainScores[m.id.uuidString] else { continue }
            out.append(Contender(labID: "player", lab: s.companyName, model: m.name, date: m.releaseDate ?? m.created, scores: v))
        }
        return out
    }

    /// Check the open milestones against released models (new rival models, and every model of yours — you have few).
    static func check(_ s: inout GameState, newModels: [String], announce: Bool) {
        let reached = won(s)
        let open = MilestoneCatalog.all.filter { !reached.contains($0.id) }
        guard !open.isEmpty else { return }
        let fresh = Set(newModels)
        var pool: [Contender] = []
        for c in s.competitors {
            let name = c.def.name
            for m in c.models + c.openModels where fresh.contains(m.id.uuidString) {
                guard let v = s.domainScores[m.id.uuidString] else { continue }
                pool.append(Contender(labID: c.id, lab: name, model: m.name, date: m.date, scores: v))
            }
        }
        for m in s.models where m.released {
            guard let v = s.domainScores[m.id.uuidString] else { continue }
            pool.append(Contender(labID: "player", lab: s.companyName, model: m.name, date: m.releaseDate ?? m.created, scores: v))
        }
        guard !pool.isEmpty else { return }
        pool.sort { $0.date != $1.date ? $0.date < $1.date : $0.labID < $1.labID }
        for ms in open {
            guard let first = pool.first(where: { meets($0.scores, ms) }) else { continue }
            record(&s, ms, first, history: false, announce: announce)
        }
    }

    /// New games and older saves: credit every milestone already reached to the first model that met it.
    static func replayHistory(_ s: inout GameState) {
        let reached = won(s)
        let pool = contenders(s).sorted { $0.date != $1.date ? $0.date < $1.date : $0.labID < $1.labID }
        for ms in MilestoneCatalog.all where !reached.contains(ms.id) {
            guard let first = pool.first(where: { meets($0.scores, ms) }) else { continue }
            s.milestoneWins.append(MilestoneWin(id: ms.id, labID: first.labID, lab: first.lab, model: first.model, date: first.date,
                                                history: first.date < s.startDate))
        }
        s.milestoneWins.sort { $0.date < $1.date }
    }

    private static func record(_ s: inout GameState, _ ms: MilestoneDef, _ c: Contender, history: Bool, announce: Bool) {
        s.milestoneWins.append(MilestoneWin(id: ms.id, labID: c.labID, lab: c.lab, model: c.model, date: c.date, history: history))
        s.milestoneWins.sort { $0.date < $1.date }
        guard announce else { return }
        let bump = [0, 0.5, 1.0, 2.0][min(3, max(1, ms.tier))]
        if ms.tier >= 3 { s.market.hype += 0.01 }
        let real = ms.real ? " In the real world this happened in \(ms.whenLabel)." : " Forecasters had expected it around \(Int(ms.year))."
        if c.labID == "player" {
            s.brand = min(100, s.brand + bump)
            Sim.news(&s, "First to a milestone: \(ms.title)",
                     "\(c.model) is the first AI to get there: \(ms.detail.prefix(1).lowercased() + ms.detail.dropFirst())\(real) The press notices (+\(Fmt.trim(bump, 1)) brand).",
                     .company, image: nil, important: true, good: true)
            Alerts.raise(&s, .milestone, key: "ms|\(ms.id)", title: "First to: \(ms.title)", body: "\(c.model) got there before any rival.",
                         screen: .milestones, celebrate: true, cooldown: 0)
            Achievements.unlock(&s, "milestone_first")
            if ms.tier >= 3 && ms.year >= 2027 { Achievements.unlock(&s, "milestone_historic") }
        } else {
            if let i = s.competitors.firstIndex(where: { $0.id == c.labID }) {
                s.competitors[i].brand = min(100, s.competitors[i].brand + bump)
            }
            Sim.news(&s, "\(c.lab) reaches a milestone: \(ms.title)",
                     "\(c.lab)'s \(c.model) is the first AI to get there: \(ms.detail.prefix(1).lowercased() + ms.detail.dropFirst())\(real)",
                     .competitor, image: nil, important: ms.tier >= 2, good: nil)
        }
    }

    // MARK: For views

    /// The open milestones nearest to being reached (by the closest lab), then by when they're expected.
    static func nextUp(_ s: GameState, count: Int = 6) -> [MilestoneDef] {
        let reached = won(s)
        let open = MilestoneCatalog.all.filter { !reached.contains($0.id) }
        let alive = Set(s.competitors.filter(\.alive).map(\.id)).union(["player"])
        let racing = s.labDomains.filter { alive.contains($0.key) }.map(\.value)
        let best = open.map { ms in (ms, racing.map { closeness($0, ms) }.max() ?? 0) }
        return best.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.year < $1.0.year }.prefix(count).map(\.0)
    }

    /// Labs nearest to a milestone: (lab ID, name, closeness 0–1), you included when you have a model out.
    static func field(_ s: GameState, _ ms: MilestoneDef, limit: Int = 5) -> [(lab: String, name: String, closeness: Double)] {
        var rows: [(String, String, Double)] = []
        for (lab, v) in s.labDomains {
            if lab == "player" {
                rows.append((lab, s.companyName, closeness(v, ms)))
            } else if let c = s.competitors.first(where: { $0.id == lab }), c.alive {
                rows.append((lab, c.def.name, closeness(v, ms)))
            }
        }
        rows.sort { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
        var out = Array(rows.prefix(limit))
        if !out.contains(where: { $0.0 == "player" }), let me = rows.first(where: { $0.0 == "player" }) { out.append(me) }
        return out.map { (lab: $0.0, name: $0.1, closeness: $0.2) }
    }

    /// Milestones each lab reached first (lab ID → count).
    static func tally(_ s: GameState) -> [String: Int] {
        var out: [String: Int] = [:]
        for w in s.milestoneWins { out[w.labID, default: 0] += 1 }
        return out
    }

    /// Open milestones a set of scores would reach (for the Model Lab's forecast).
    static func reachable(_ s: GameState, _ v: DomainScores) -> [MilestoneDef] {
        let reached = won(s)
        return MilestoneCatalog.all.filter { !reached.contains($0.id) && meets(v, $0) }
    }
}
