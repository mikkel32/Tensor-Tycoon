import Foundation

struct LabTrait {
    var signature: String
    var reasoning = 0.0
    var agent = 0.0
    var chat = 0.0
    var lang = 0.0
    var longctx = 0.0
    var vis = 0.0
    var safety = 0.0
    var audio = true
}

enum Competitors {
    /// Each lab's long-standing specialty.
    static func trait(_ id: String) -> LabTrait {
        switch id {
        case "prometheus": LabTrait(signature: "Deliberative RL at scale & consumer polish", reasoning: 0.05, chat: 0.08)
        case "deepgrove": LabTrait(signature: "TPU co-design & native multimodality", lang: 0.15, longctx: 0.15, vis: 0.15)
        case "halcyon": LabTrait(signature: "Constitutional training & agentic coding", agent: 0.12, chat: 0.05, safety: 15)
        case "xenon": LabTrait(signature: "100K-GPU synchronous clusters, built in months", chat: -0.05, safety: -18, audio: true)
        case "openweights": LabTrait(signature: "Open weights at frontier scale", lang: 0.1, safety: -5)
        case "dragonlake": LabTrait(signature: "MLA + FP8 + fine-grained MoE efficiency stack", reasoning: 0.05, lang: 0.1, safety: -15, audio: false)
        case "sirocco": LabTrait(signature: "Compact multilingual models", lang: 0.25, safety: -5, audio: false)
        case "aletheia": LabTrait(signature: "Straight-shot superintelligence research", reasoning: 0.1, agent: 0.05, safety: 10, audio: false)
        default: LabTrait(signature: "")
        }
    }

    /// Combined effect of a lab's unique breakthroughs that exist by year `y`.
    static func boost(_ s: GameState, _ id: String, at y: Double) -> RivalBoost {
        var out = RivalBoost()
        for tech in s.rivalTech[id] ?? [] {
            guard let item = ResearchCatalog.byID[tech], let r = item.rival, item.year <= y + 0.3 else { continue }
            out.c += r.c
            out.reasoning += r.reasoning
            out.code += r.code
            out.agent += r.agent
            out.chat += r.chat
            out.lang += r.lang
            out.longctx += r.longctx
            out.tps *= r.tps
            out.price *= r.price
        }
        // Breakthroughs you published openly: everyone reproduces them, at about half the effect.
        for (tech, when) in s.publishedTech where !(s.rivalTech[id] ?? []).contains(tech) {
            guard let r = ResearchCatalog.byID[tech]?.rival, when.decimalYear + 0.5 <= y else { continue }
            out.c += r.c * 0.5
            out.reasoning += r.reasoning * 0.5
            out.code += r.code * 0.5
            out.agent += r.agent * 0.5
            out.chat += r.chat * 0.5
            out.lang += r.lang * 0.5
            out.longctx += r.longctx * 0.5
            out.tps *= pow(r.tps, 0.5)
            out.price *= pow(r.price, 0.5)
        }
        return out
    }

    /// Hand out the unique breakthroughs at the start of a game: a few for you, a couple for every rival, some for nobody.
    static func assignExotics(_ s: inout GameState) {
        var pool = ResearchCatalog.exotic.map(\.id)
        pool.shuffle(using: &s.rng)
        let y = s.year
        // Make sure two of yours are reachable within a few years.
        var mine = Array(pool.filter { (ResearchCatalog.byID[$0]?.year ?? 3000) <= y + 2.5 }.prefix(2))
        // And that you hold both halves of at least one fusion.
        if let anchor = mine.first(where: { Breakthroughs.partner(of: $0) != nil }), let partner = Breakthroughs.partner(of: anchor),
           !mine.contains(partner) {
            mine.append(partner)
        }
        for id in pool where mine.count < 5 && !mine.contains(id) { mine.append(id) }
        pool.removeAll { mine.contains($0) }
        s.exoticOwned = mine
        var rivals: [String: [String]] = [:]
        for def in CompetitorCatalog.all {
            rivals[def.id] = Array(pool.prefix(2))
            pool.removeFirst(min(2, pool.count))
        }
        s.rivalTech = rivals
    }

    static func reasoningStart(_ id: String) -> Double {
        switch id {
        case "prometheus": 2024.7
        case "deepgrove": 2024.95
        case "dragonlake": 2025.05
        case "xenon": 2025.1
        case "halcyon": 2025.15
        case "openweights": 2025.3
        default: 2025.4
        }
    }

    /// Rough algorithmic-efficiency gain baked into the frontier curve (used only to back out parameter counts).
    static func algoGain(_ y: Double) -> Double {
        interpolate([(2017, 0), (2020, 0.2), (2023, 0.8), (2025, 1.2), (2027, 1.5), (2030, 2.0)], at: y)
    }

    /// Display-only parameter estimate (total params incl. MoE experts), anchored on GPT-2 / GPT-3 / GPT-4-era figures.
    static func displayParams(c: Double) -> Double {
        pow(10, interpolate([(-1.0, -0.93), (0.3, 0.18), (2.8, 2.24), (5.1, 3.26), (8.0, 3.7), (11.0, 4.2)], at: c, extrapolate: true))
    }

    static func setup(_ s: inout GameState) {
        s.competitors = CompetitorCatalog.all.map { def in
            CompetitorState(id: def.id, nextRelease: def.releases.first?.0.date ?? def.firstModel.date, brand: def.brand)
        }
        // Back-fill releases that happened before the game starts.
        let start = s.date
        for i in s.competitors.indices {
            let def = s.competitors[i].def
            while s.competitors[i].nextRelease < start {
                let when = s.competitors[i].nextRelease
                let model = makeModel(&s, compIndex: i, date: when)
                s.competitors[i].models.append(model)
                s.competitors[i].releaseCount += 1
                s.competitors[i].nextRelease = nextReleaseDate(def, count: s.competitors[i].releaseCount, after: when, jitter: 1)
            }
            refreshFinancials(&s, i)
            if s.year < 2022.9 { s.competitors[i].brand = def.brand * 0.5 }
        }
        addIncumbents(&s)
    }

    /// Put the pre-LLM incumbents that existed by now on the board (deterministic: no random draws).
    static func addIncumbents(_ s: inout GameState) {
        for inc in CompetitorCatalog.incumbents where inc.date.date <= s.date {
            guard let i = s.competitors.firstIndex(where: { $0.id == inc.lab }),
                  !s.competitors[i].models.contains(where: { $0.name == inc.name }) else { continue }
            let def = s.competitors[i].def
            let when = GameCalendar.addDays(inc.date.date, 14)
            let y = when.decimalYear
            let c = Macro.frontier(y) + inc.delta
            let price = Macro.referencePrice(c: c, y: y) * def.priceMult
            let m = CompetitorModel(name: inc.name, date: when, c: c, reasoning: false, scores: [:], index: 0,
                                    price: (price * 1000).rounded() / 1000, open: inc.open, tps: def.tps * 0.6,
                                    paramsB: max(0.05, displayParams(c: c)))
            s.competitors[i].models.append(m)
            s.competitors[i].models.sort { $0.date < $1.date }
        }
    }

    static func nextReleaseDate(_ def: CompetitorDef, count: Int, after: Date, jitter: Double) -> Date {
        if count < def.releases.count {
            // Historical schedule (mid-month release)
            return GameCalendar.addDays(def.releases[count].0.date, 14)
        }
        return GameCalendar.addDays(after, Int(def.cadenceMonths * 30.4 * jitter))
    }

    static func modelName(_ def: CompetitorDef, count: Int) -> String {
        if count < def.releases.count { return def.releases[count].1 }
        let v = def.nextVersion + 0.5 * Double(count - def.releases.count)
        return "\(def.prefix)\(Fmt.trim(v, 1))"
    }

    /// The capability a lab's next model would have if it shipped on `date`, before release-day noise.
    /// Rival Watch forecasts from this; makeModel adds the noise.
    static func plannedC(_ s: GameState, compIndex i: Int, date: Date) -> Double {
        let comp = s.competitors[i]
        let def = comp.def
        let y = date.decimalYear
        // Rivals answer your lead. They size their next runs against the lead you've held for a training cycle
        // (about six months before this release), copy part of what they can see today by distilling your API,
        // and build on anything you publish as open weights at once. Well-funded labs answer harder.
        let released = s.models.filter(\.released)
        let leadNow = max(0, (released.map(\.c).max() ?? -10) - Macro.frontier(y))
        let openLead = min(leadNow, max(0, (released.filter(\.openWeights).map(\.c).max() ?? -10) - Macro.frontier(y)))
        let held = min(leadNow + 0.2, leadAgo(s, before: date) ?? leadNow)
        let k = s.difficulty.rivalResponse * (0.75 + 0.25 * min(1.2, comp.funding))
        let copied = 0.3 * max(0, leadNow - held) * (1 - 0.6 * min(1, s.bonuses.distillGuard))
        let race = max(k * held + copied, 0.7 * openLead)
        var c = Macro.frontier(y) + def.offset(y) + s.difficulty.competitorBoost + race + boost(s, def.id, at: y).c
        // Money buys compute: well-funded labs train bigger, starved ones fall behind.
        c += 0.2 * log10(max(0.3, comp.funding))
        // Whatever you sold or licensed them — or they stole.
        c += Xeno.rivalC(s, def.id, at: date)
        if def.id == "dragonlake" {
            if s.lawsPassed.contains("chip_security") { c -= 0.1 }
            if s.lawsFailed.contains("chip_security") { c += 0.05 }
        }
        // A big lab that has watched you hold #1 for half a year bets a run on passing you — on the leaderboard, not just
        // in raw capability. The longer you lead, the more of their runs are that bet. Whether this one is, and by how
        // much, is fixed per release (hashed), so Rival Watch can see it coming.
        if s.monthsAtTop >= 6, y >= 2018, def.computeShare >= 0.15, let mine = released.map(\.index).max(), mine > 0 {
            let shift = s.difficulty == .hard ? 0.1 : (s.difficulty == .easy ? -0.1 : 0)
            let tries = clamp(0.25 + 0.03 * Double(s.monthsAtTop - 6) + shift, 0.1, 0.6)
            if RivalIntel.unit("\(def.id)|leap|\(comp.releaseCount)") < tries {
                let goal = mine + 1 + 4 * RivalIntel.unit("\(def.id)|leapsize|\(comp.releaseCount)")
                let set = Leaderboard.indexSet(s)
                func score(_ x: Double) -> Double { RivalIntel.index(s, i, c: x, on: date, set: set) }
                if score(c) < goal {
                    // The least capability that clears your best model's index by the goal (at most +1.5 over plan).
                    var lo = c, hi = c + 1.5
                    if score(hi) >= goal {
                        for _ in 0..<18 {
                            let mid = (lo + hi) / 2
                            if score(mid) >= goal { hi = mid } else { lo = mid }
                        }
                    }
                    c = hi
                }
            }
        }
        if y < 2017.4 { c -= 1.0 }
        // Rushed after a code red, or held back to train harder.
        if let p = comp.project, p.count == comp.releaseCount { c += p.cAdjust }
        return c
    }

    /// Your best released model's lead over the world frontier about six months before `date`, from the monthly
    /// records (nil when that's still in the future or wasn't recorded).
    static func leadAgo(_ s: GameState, before date: Date) -> Double? {
        let then = GameCalendar.addDays(date, -182)
        guard then < s.date, let r = s.history.last(where: { $0.month <= then }), r.bestC != 0 else { return nil }
        return max(0, r.bestC - Macro.frontier(r.month.decimalYear))
    }

    static func makeModel(_ s: inout GameState, compIndex i: Int, date: Date) -> CompetitorModel {
        let def = s.competitors[i].def
        let y = date.decimalYear
        let boost = boost(s, def.id, at: y)
        var c = plannedC(s, compIndex: i, date: date) + s.rng.gaussian() * 0.05
        if let stolen = s.stolenC[def.id] { c = max(c, stolen + s.rng.gaussian() * 0.03) }
        let reasoning = y >= reasoningStart(def.id)
        let name = modelName(def, count: s.competitors[i].releaseCount)
        let price = Macro.referencePrice(c: c, y: y) * def.priceMult * s.market.apiPricePressure * boost.price
        let tps = def.tps * s.rng.range(0.85, 1.15) * (1 + max(0, y - 2023) * 0.06) * boost.tps
        var params = displayParams(c: c)
        if def.openWeights { params *= 0.45 }
        params = max(0.1, params)
        return CompetitorModel(name: name, date: date, c: c, reasoning: reasoning, scores: [:],
                               index: 0, price: (price * 1000).rounded() / 1000,
                               open: def.openWeights, tps: tps, paramsB: params)
    }

    static func daily(_ s: inout GameState) {
        for i in s.competitors.indices where !s.competitors[i].acquired && s.date >= s.competitors[i].nextRelease {
            let def = s.competitors[i].def
            let prevTopC = max(s.competitors.flatMap(\.models).map(\.c).max() ?? -10, s.models.filter(\.released).map(\.c).max() ?? -10)
            let call = RivalIntel.outlook(s, i)
            var model = makeModel(&s, compIndex: i, date: s.date)
            model.index = BenchmarkCatalog.index(Leaderboard.profile(model, def: def, boost: boost(s, def.id, at: s.year)), set: Leaderboard.indexSet(s))
            s.competitors[i].models.append(model)
            s.competitors[i].releaseCount += 1
            let jitter = s.rng.range(0.8, 1.25) * (s.lawsPassed.contains("compute_licensing") ? 1.15 : 1) * RivalStrategy.cadence(s.competitors[i])
            s.competitors[i].nextRelease = nextReleaseDate(def, count: s.competitors[i].releaseCount, after: s.date, jitter: jitter)
            s.competitors[i].brand = min(100, s.competitors[i].brand + 2)
            let isTop = prevTopC < model.c
            let set = Leaderboard.indexSet(s)
            let p = Leaderboard.profile(model, def: def, boost: boost(s, def.id, at: s.year))
            let idx = BenchmarkCatalog.index(p, set: set)
            let details = set.prefix(2).map { "\($0.name) \(Fmt.score(BenchmarkCatalog.cachedScore($0, p)))%" }
            let openNote = model.open ? " Weights are openly downloadable — API prices across the industry come under pressure." : ""
            if model.open && model.c > Macro.frontier(s.year) - 0.5 {
                s.market.apiPricePressure = max(0.5, s.market.apiPricePressure - 0.05)
            }
            Sim.news(&s, "\(def.name) releases \(model.name)\(isTop ? " — new #1" : "")",
                     "Intelligence Index \(Fmt.score(idx))\(details.isEmpty ? "" : " · " + details.joined(separator: " · ")). API price \(Fmt.price(model.price))/M tokens.\(openNote)",
                     .competitor, image: nil, important: isTop)
            RivalIntel.released(&s, i, model: model, index: idx, outlook: call)
            // Tell the player when this release puts the lab ahead of their best model.
            let labBefore = s.competitors[i].models.dropLast().map(\.index).max() ?? 0
            if let mine = s.models.filter({ $0.released && !$0.retired }).max(by: { $0.index < $1.index }),
               model.index > mine.index, labBefore <= mine.index {
                // Losing #1 stops the clock (by default); being passed while another lab is already ahead is a banner.
                let gone = Leaderboard.goneLabs(s)
                let othersAhead = s.competitors.contains { c in
                    c.id != def.id && !gone.contains(c.id) && (c.models + c.openModels).contains { $0.index > mine.index }
                }
                if othersAhead {
                    Alerts.raise(&s, .rivalLaunch, key: def.id, title: "\(def.name)'s \(model.name) beats \(mine.name)",
                                 body: "Index \(Fmt.score(model.index)) vs your \(Fmt.score(mine.index)). Users and API customers drift to it until you ship something better.",
                                 screen: .rivalWatch, cooldown: 30)
                } else {
                    Alerts.raise(&s, .rivalPassed, key: def.id, title: "\(def.name) takes #1 with \(model.name)",
                                 body: "Index \(Fmt.score(model.index)) vs \(Fmt.score(mine.index)) for your \(mine.name). Users and API customers drift to it until you ship something better.",
                                 screen: .rivalWatch, cooldown: 30)
                }
            }
        }
    }

    static func refreshFinancials(_ s: inout GameState, _ i: Int) {
        let def = s.competitors[i].def
        let y = s.year
        guard y >= def.founded.decimal else {
            s.competitors[i].valuation = 0
            s.competitors[i].computeH100e = 0
            return
        }
        // How much compute a lab runs follows its share of the industry, scaled by how well funded it is.
        var compute = CompetitorCatalog.industryCompute(y) * def.computeShare * s.competitors[i].funding
        if def.id == "dragonlake" && s.market.exportControls { compute *= 0.6 }
        s.competitors[i].computeH100e = compute * s.rng.range(0.95, 1.05)
        // Valuations come from RivalEconomy once a lab's books exist; this is only the opening estimate.
        guard !s.competitors[i].econReady else { return }
        var v = Macro.frontierValuation(y) * exp(2.2 * def.offset(y))
        if def.id == "deepgrove" || def.id == "openweights" { v *= 0.4 }   // valued as a division of a giant
        s.competitors[i].valuation = v * s.market.hype / 1.3 * s.rng.range(0.9, 1.1)
    }

    /// Make sure saves from older versions include newly added labs.
    static func migrate(_ s: inout GameState) {
        for def in CompetitorCatalog.all where !s.competitors.contains(where: { $0.id == def.id }) {
            var st = CompetitorState(id: def.id, nextRelease: def.releases.first?.0.date ?? def.firstModel.date, brand: def.brand)
            st.releaseCount = 0
            s.competitors.append(st)
            let i = s.competitors.count - 1
            while s.competitors[i].nextRelease < s.date {
                let when = s.competitors[i].nextRelease
                let model = makeModel(&s, compIndex: i, date: when)
                s.competitors[i].models.append(model)
                s.competitors[i].releaseCount += 1
                s.competitors[i].nextRelease = nextReleaseDate(def, count: s.competitors[i].releaseCount, after: when, jitter: 1)
            }
            refreshFinancials(&s, i)
        }
        addIncumbents(&s)
    }

    static func monthly(_ s: inout GameState) {
        addIncumbents(&s)
        for i in s.competitors.indices { refreshFinancials(&s, i) }
        RivalEconomy.monthly(&s)
        RivalStrategy.monthly(&s)
        // Price war: if you grab API share, rivals cut prices; otherwise they slowly restore them.
        // Labs in distress raise prices instead (RivalEconomy sets that).
        let playerShare = Market.snapshot(s).api.filter(\.isPlayer).reduce(0) { $0 + $1.share }
        for i in s.competitors.indices where s.competitors[i].distressMonths == 0 && !RivalStrategy.controlsPrice(s.competitors[i]) {
            let before = s.competitors[i].priceCut
            if playerShare > 0.08 {
                s.competitors[i].priceCut = min(0.45, before + 0.03 * (playerShare / 0.08))
            } else {
                s.competitors[i].priceCut = max(0, before - 0.02)
            }
            if before < 0.15 && s.competitors[i].priceCut >= 0.15 && !s.competitors[i].models.isEmpty {
                Sim.news(&s, "\(s.competitors[i].def.name) slashes API prices", "Your growing market share triggered a price war: \(s.competitors[i].def.name) cut prices by \(Int(s.competitors[i].priceCut * 100))%.",
                         .market, important: true, good: false)
            }
        }
        // Consolidation now comes from the labs' finances: see RivalEconomy (distress, fire sales, bankruptcies).
        // Brand drift toward base
        for i in s.competitors.indices {
            let base = s.competitors[i].def.brand * (s.year > 2022.9 ? 1.2 : 0.6)
            s.competitors[i].brand += (base - s.competitors[i].brand) * 0.05
        }
    }
}
