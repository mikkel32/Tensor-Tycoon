import Foundation

// MARK: - 3.9: the dramatic-event catalogue
//
// Each event is modelled on something that really happened to a lab, a datacenter or a chip supplier between 2017 and
// 2026 (battery-room fires, the 2021 Texas freeze, weights posted to a message board, a chatbot that told a columnist it
// wanted to be free, integrators charged with smuggling GPUs, an open-weights release that wiped out a chip maker's
// market value in a day), with the names fictionalised the way the rest of the game does it.

extension Drama {
    static let catalog: [Def] = [
        evFire, evFlood, evBlackout, evFreeze, evHeatwave,
        evLeak, evInjection, evUnhinged, evThread, evSmuggling,
        evQuake, evCelebrity, evWhistleblower, evPublisher, evVoice,
        evOpenDrop, evRansomware, evInvestor, evContractors, evUniversity,
        evBurnout, evNuclear, evViralPaper, evHungerStrike, evDeepfake,
        evOutage, evMedical, evSentience, evRoadmap,
    ]

    // MARK: Datacenters and power

    static let hotPlaces: Set<String> = ["texas", "arizona", "uae", "nova", "iowa", "it_milan", "fr_rhone", "ro_bucharest"]
    static let freezePlaces: [String: (state: String, operator: String)] = [
        "texas": ("Texas", "The state's grid operator"), "nova": ("Virginia", "The regional grid operator"), "iowa": ("Iowa", "The regional grid operator"),
    ]

    static let evFire = Def(
        id: "fire", name: "Datacenter fire", blurb: "A UPS battery fire takes out chips in one of your halls.", image: "power_battery",
        safe: 1, cooldownDays: 1_100, days: 14,
        weight: { s in halls(s).isEmpty ? 0 : (s.drama.hardened.contains("fire_suppression") ? 0.3 : 0.9) },
        fire: { s, def in
            let site = s.rng.pick(halls(s))
            let share = s.rng.range(0.03, 0.07) * (s.drama.hardened.contains("fire_suppression") ? 0.5 : 1)
            let hit = destroy(&s, site: site.id, share: capped(s, site, share, kw: 20_000))   // one hall, not a whole campus
            s.reliability *= 0.88
            var runText = ""
            if let i = activeRun(s) {
                runText = " \(s.runs[i].design.name) restarted: " + setBack(&s, i, share: 0.02, why: "Fire at \(site.name)") + "."
            }
            let retrofit = round2(max(150_000, site.capacityKW * 30))
            let claim = round2(hit.value * 0.65)
            var options = [
                DecisionOption(label: "Replace them and retrofit fire suppression (\(Fmt.money(hit.value + retrofit)))",
                               detail: "\(Fmt.int(hit.count)) new \(hit.name) at today's prices, plus aerosol suppression and separate battery rooms. Fires get rarer and smaller."),
                DecisionOption(label: "File an insurance claim",
                               detail: "The insurer pays about \(Fmt.money(claim)), 65% of the value, in two to three months. Until you buy more, you're short those chips."),
            ]
            if site.kind == .colo {
                options.append(DecisionOption(label: "Hold the colocation operator liable",
                                              detail: "Their battery room, their fire. About even odds they pay \(Fmt.money(round2(hit.value * 0.5))) to keep you as a tenant; lose and the lawyers cost \(Fmt.money(round2(max(50_000, hit.value * 0.04))))."))
            }
            post(&s, def, title: "Fire at \(site.name)",
                 body: "A lithium-ion UPS battery caught fire in the electrical room at \(site.name) overnight. Firefighters cut power to the hall: \(Fmt.int(hit.count)) \(hit.name) were destroyed (about \(Fmt.money(hit.value)) at today's prices) and users saw errors for most of a day.\(runText)",
                 options: options, costs: [0: hit.value + retrofit],
                 ref: ["site": site.id.uuidString, "lost": hit.lost, "worth": String(Int(hit.value))])
        },
        resolve: { s, d, o in
            let site = siteOf(s, d)
            let name = site?.name ?? "the hall"
            let worth = num(d, "worth")
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0, capex: true)
                if let site { replace(&s, site: site.id, lost: value(d, "lost") ?? "") }
                s.drama.hardened.insert("fire_suppression")
                Stakeholders.move(&s, ["investors": 2], "Rebuilt \(name) after a fire, with better suppression")
                return Outcome(title: "\(name) is back, and safer", body: "Replacement chips are racked and the battery rooms are walled off with aerosol suppression. The next fire will be rarer and smaller.", tone: .good)
            case 1:
                let claim = round2(worth * 0.65)
                later(&s, d, kind: "insurance", days: s.rng.int(55, 95), amount: claim, ref: name)
                return Outcome(title: "Insurance claim filed for the \(name) fire", body: "Assessors are on site. Expect about \(Fmt.money(claim)) within three months.", tone: .mixed)
            default:
                if s.rng.chance(0.5) {
                    let paid = round2(worth * 0.5)
                    receive(&s, paid)
                    return Outcome(title: "Colocation operator pays for the fire", body: "Faced with losing an anchor tenant, they paid \(Fmt.money(paid)) and are rebuilding their battery rooms.", tone: .good)
                }
                let fees = round2(max(50_000, worth * 0.04))
                pay(&s, fees)
                return Outcome(title: "Your claim against the colo operator fails", body: "Their contract capped liability at a month's rent. Legal fees: \(Fmt.money(fees)).", tone: .bad)
            }
        })

    static let evFlood = Def(
        id: "flood", name: "Flooded data hall", blurb: "A burst chilled-water pipe soaks a row of racks.", image: "industrial_cooling",
        safe: 1, cooldownDays: 1_000, days: 10,
        weight: { s in halls(s).isEmpty ? 0 : 0.7 },
        fire: { s, def in
            let site = s.rng.pick(halls(s))
            let share = capped(s, site, s.rng.range(0.02, 0.05), kw: 3_000)   // a row of racks
            let n = max(1, Int((Double(chips(at: site.id, s)) * share).rounded()))
            let batches = s.owned.filter { $0.siteID == site.id }
            let avg = batches.reduce(0.0) { $0 + $1.unitCost * Double($1.count) } / Double(max(1, batches.reduce(0) { $0 + $1.count }))
            let worth = round2(Double(n) * avg * s.market.hardwarePrice)
            s.reliability *= 0.92
            let crew = round2(max(100_000, worth * 0.25))
            post(&s, def, title: "Burst pipe floods a hall at \(site.name)",
                 body: "A chilled-water pipe split above a row of racks at \(site.name). About \(Fmt.int(n)) chips (\(Fmt.money(worth))) got wet before the loop was shut off, and that row is dark.",
                 options: [
                    DecisionOption(label: "Fly in replacement boards and a recovery crew (\(Fmt.money(crew)))", detail: "Strip, clean and swap every wet board this week. Nothing is lost."),
                    DecisionOption(label: "Dry them out and test each one", detail: "Free, but slow: expect about 40% of the wet chips to fail as corrosion sets in."),
                    DecisionOption(label: "Scrap everything that got wet and claim it", detail: "All \(Fmt.int(n)) go in the skip; the insurer pays about \(Fmt.money(round2(worth * 0.8))) in a couple of months."),
                 ], costs: [0: crew], ref: ["site": site.id.uuidString, "share": String(share), "worth": String(Int(worth))])
        },
        resolve: { s, d, o in
            let site = siteOf(s, d)
            let name = site?.name ?? "the site"
            let share = num(d, "share")
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                s.reliability = min(1, s.reliability * 1.05)
                return Outcome(title: "\(name) recovered in four days", body: "The crew dried, cleaned and re-seated every board. Not a chip lost.", tone: .good)
            case 1:
                var hit = (count: 0, value: 0.0, name: "chips", lost: "")
                if let site { hit = destroy(&s, site: site.id, share: share * 0.4) }
                s.reliability *= 0.96
                return Outcome(title: "Corrosion claims \(Fmt.int(hit.count)) chips at \(name)", body: "Most boards came back after drying, but \(Fmt.int(hit.count)) \(hit.name) never passed testing (\(Fmt.money(hit.value))).", tone: .bad)
            default:
                var hit = (count: 0, value: 0.0, name: "chips", lost: "")
                if let site { hit = destroy(&s, site: site.id, share: share) }
                later(&s, d, kind: "insurance", days: s.rng.int(45, 75), amount: round2(num(d, "worth") * 0.8), ref: name)
                return Outcome(title: "Wet chips scrapped at \(name)", body: "\(Fmt.int(hit.count)) chips written off and claimed. The insurer pays about \(Fmt.money(round2(num(d, "worth") * 0.8))) in a couple of months.", tone: .mixed)
            }
        })

    static let evBlackout = Def(
        id: "blackout", name: "Blackout mid-run", blurb: "A regional blackout knocks a training run back to its last checkpoint.", image: "power_lines",
        safe: 1, cooldownDays: 540, days: 10,
        weight: { s in
            guard activeRun(s, minProgress: 0.1) != nil else { return 0 }
            return s.drama.hardened.contains("backup_power") || s.drama.hardened.contains("priority_load") ? 0.3 : 1.0
        },
        fire: { s, def in
            guard let i = activeRun(s, minProgress: 0.1) else { return }
            let run = s.runs[i]
            let hall = halls(s, minChips: 8).max { Economy.siteLoadKW(s, $0.id) < Economy.siteLoadKW(s, $1.id) }
            let place = hall.map { "around \($0.name)" } ?? "around your cloud provider's busiest region"
            let pct = Fmt.pct(run.progress, decimals: 0)
            let loss = setBack(&s, i, share: 0.03, why: "Regional blackout")
            let kw = hall.map { Economy.siteLoadKW(s, $0.id) }
                ?? run.design.parts.reduce(0.0) { $0 + (HardwareCatalog.get($1.accelID).map(Economy.chipKW) ?? 0.7) * Double($1.chips) }
            let gensets = round2(max(120_000, kw * 70))
            post(&s, def, title: "Blackout halts \(run.design.name)",
                 body: "A transmission fault blacked out the region \(place) for nine hours. \(run.design.name) was \(pct) through and went \(loss). The utility warns of more outages while it repairs the line.",
                 options: [
                    DecisionOption(label: hall == nil ? "Pay for hot standby in a second region (\(Fmt.money(gensets)))" : "Lease generators and battery trailers (\(Fmt.money(gensets)))",
                                   detail: "The run rides through anything else this summer, and future blackouts mostly pass you by."),
                    DecisionOption(label: "Wait it out", detail: "Free. About a 40% chance of a second outage before the line is fixed."),
                    DecisionOption(label: "Press the utility for priority restoration", detail: "Spend political capital (−4). Likely, not certain, to put your load near the front of the line next time."),
                 ], costs: [0: gensets], ref: ["run": run.id.uuidString])
        },
        resolve: { s, d, o in
            let i = s.runs.firstIndex { $0.id.uuidString == value(d, "run") && $0.status == .running }
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                s.drama.hardened.insert("backup_power")
                return Outcome(title: "Backup power in place", body: "Generators and batteries now carry your training load through grid faults.", tone: .good)
            case 1:
                if let i, s.rng.chance(0.4) {
                    let loss = setBack(&s, i, share: 0.015, why: "Second blackout")
                    return Outcome(title: "A second blackout hits \(s.runs[i].design.name)", body: "The repaired line tripped again: \(loss).", tone: .bad)
                }
                return Outcome(title: "The grid holds", body: "The line was repaired without another outage.", tone: .mixed)
            default:
                s.politicalCapital = max(0, s.politicalCapital - 4)
                if s.rng.chance(0.65) {
                    s.drama.hardened.insert("priority_load")
                    return Outcome(title: "Utility grants priority restoration", body: "Your campus is now a priority load: outages will rarely reach you.", tone: .good, category: .policy)
                }
                return Outcome(title: "The utility won't move you up the line", body: "Hospitals and water plants come first, they said. Political capital −4.", tone: .bad, category: .policy)
            }
        })

    static let evFreeze = Def(
        id: "freeze", name: "Winter grid emergency", blurb: "Arctic air sends power prices to the cap; run at any price or sell your power back.",
        image: "power_substation_night", safe: 1, cooldownDays: 700, days: 6,
        weight: { s in
            let m = GameCalendar.components(s.date).month
            guard [12, 1, 2].contains(m) else { return 0 }
            return halls(s, minChips: 32).contains { freezePlaces[$0.locationID] != nil && Economy.siteLoadKW(s, $0.id) >= 300 } ? 1.4 : 0
        },
        fire: { s, def in
            guard let site = halls(s, minChips: 32).filter({ freezePlaces[$0.locationID] != nil }).max(by: { Economy.siteLoadKW(s, $0.id) < Economy.siteLoadKW(s, $1.id) }),
                  let place = freezePlaces[site.locationID] else { return }
            let kw = Economy.siteLoadKW(s, site.id)
            let spot = round2(kw * 24 * 4 * 2.0)
            let credit = round2(kw * 24 * 4 * 0.35)
            post(&s, def, title: "Grid emergency in \(place.state)",
                 body: "Arctic air froze gas wellheads and wind turbines across \(place.state), and wholesale power is trading near the cap. \(place.operator) is asking big loads to shed. \(site.name) draws \(Fmt.watts(kw * 1000)).",
                 options: [
                    DecisionOption(label: "Keep running at spot prices (\(Fmt.money(spot)))", detail: "Four days of power at about $2/kWh. Nothing stops, but people will notice who kept their servers on while homes went cold."),
                    DecisionOption(label: "Shut down and sell your power back", detail: "Demand-response credits pay about \(Fmt.money(credit)). Users see errors and training pauses for four days."),
                 ], costs: [0: spot], ref: ["site": site.id.uuidString, "credit": String(Int(credit))], category: .market)
        },
        resolve: { s, d, o in
            let site = siteOf(s, d)
            let region = site.flatMap { Region.of(location: $0.locationID) }?.rawValue ?? "us"
            if o == 0 {
                let c = cost(d, 0) ?? 0
                s.cash -= c
                s.month.costPower += c
                Stakeholders.move(&s, ["public": -2, region: -3], "Kept \(site?.name ?? "a datacenter") running through a grid emergency")
                return Outcome(title: "\(site?.name ?? "Your campus") ran through the freeze", body: "It cost \(Fmt.money(c)) in power, and a local paper ran the headline \"AI stayed warm\".", tone: .bad, category: .market)
            }
            receive(&s, num(d, "credit"))
            s.reliability *= 0.85
            if let i = activeRun(s) { setBack(&s, i, share: 0.01, why: "Curtailed in a grid emergency") }
            Stakeholders.move(&s, ["public": 2, region: 3], "Shed load to keep the lights on in a grid emergency")
            return Outcome(title: "You powered down for the grid", body: "Demand-response credits paid \(Fmt.money(num(d, "credit"))). The governor thanked large loads that shed \"when it mattered\".", tone: .good, category: .market)
        })

    static let evHeatwave = Def(
        id: "heatwave", name: "Heatwave overwhelms cooling", blurb: "Air-cooled halls in a hot place throttle in a week above 40°C.", image: "chiller",
        safe: 1, cooldownDays: 600, days: 7,
        weight: { s in
            let m = GameCalendar.components(s.date).month
            return halls(s).contains { $0.cooling == .air && hotPlaces.contains($0.locationID) && ((6...8).contains(m) || ($0.locationID == "uae" && (5...9).contains(m))) } ? 1.2 : 0
        },
        fire: { s, def in
            let pool = halls(s).filter { $0.cooling == .air && hotPlaces.contains($0.locationID) }
            guard !pool.isEmpty else { return }
            let site = s.rng.pick(pool)
            let kw = Economy.siteLoadKW(s, site.id)
            let chillers = round2(max(60_000, kw * 20))
            post(&s, def, title: "Heatwave: \(site.name) can't keep cool",
                 body: "Six days above 40°C. The air-cooled halls at \(site.name) are running inlet air 8°C over spec, and chips have started to throttle. The forecast says another week of it.",
                 options: [
                    DecisionOption(label: "Rent portable chillers for three weeks (\(Fmt.money(chillers)))", detail: "Trucked-in chillers hold temperatures in spec. Nothing slows."),
                    DecisionOption(label: "Throttle the chips until it breaks", detail: "Free. Serving gets flaky and training slows for two weeks."),
                    DecisionOption(label: "Run them hot", detail: "Full speed, and about a 40% chance that 1–3% of the chips there die of heat (HBM errors, failed VRMs)."),
                 ], costs: [0: chillers], ref: ["site": site.id.uuidString], category: .market)
        },
        resolve: { s, d, o in
            let site = siteOf(s, d)
            let name = site?.name ?? "the site"
            let tip = site?.cooling == .air ? " A liquid-cooling retrofit on the Datacenters page ends this for good." : ""
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                return Outcome(title: "Chillers keep \(name) in spec", body: "Rented chillers held the halls in spec until the heat broke.\(tip)", tone: .mixed)
            case 1:
                s.reliability *= 0.93
                if let i = activeRun(s) { setBack(&s, i, share: 0.012, why: "Throttled through a heatwave") }
                return Outcome(title: "\(name) throttled through the heat", body: "Two slow weeks: errors for users and a training run that fell behind.\(tip)", tone: .mixed)
            default:
                if let site, s.rng.chance(0.4) {
                    let hit = destroy(&s, site: site.id, share: capped(s, site, s.rng.range(0.01, 0.03), kw: 8_000))
                    return Outcome(title: "Heat kills \(Fmt.int(hit.count)) chips at \(name)", body: "Running hot cost \(Fmt.int(hit.count)) \(hit.name) (\(Fmt.money(hit.value))).\(tip)", tone: .bad)
                }
                return Outcome(title: "\(name) ran hot and held", body: "The gamble paid off: no failures beyond the usual.\(tip)", tone: .good)
            }
        })

    /// A share of a site's chips, capped at what `kw` of IT load holds: a fire takes a hall and a burst pipe a row,
    /// however big the campus around them.
    static func capped(_ s: GameState, _ site: Site, _ share: Double, kw: Double) -> Double {
        let batches = s.owned.filter { $0.siteID == site.id }
        let n = batches.reduce(0) { $0 + $1.count }
        guard n > 0 else { return share }
        let load = batches.reduce(0.0) { $0 + (HardwareCatalog.get($1.accelID).map(Economy.chipKW) ?? 1) * Double($1.count) }
        let fits = kw / max(0.05, load / Double(n))
        return min(share, fits / Double(n))
    }

    // MARK: Models, products and the public

    static func leakable(_ s: GameState) -> AIModel? {
        s.releasedModels.filter { !$0.openWeights && $0.c > Macro.frontier(s.year) - 1.5 }.max { $0.c < $1.c }
    }

    static let evLeak = Def(
        id: "leak", name: "Weights leak", blurb: "A closed model's weights turn up on a message board.", image: "network",
        safe: 2, cooldownDays: 1_100, days: 10,
        weight: { s in
            guard s.year >= 2020, s.employees.count >= 15, leakable(s) != nil else { return 0 }
            return [1: 1.0, 2: 0.7, 3: 0.35][s.security.rawValue] ?? 0
        },
        fire: { s, def in
            guard let m = leakable(s) else { return }
            s.brand = max(0, s.brand - 2)
            s.market.apiPricePressure = max(0.4, s.market.apiPricePressure - 0.03)
            let hunt = scaled(s, floor: 150_000, share: 0.002, cap: 30e6)
            post(&s, def, title: "\(World.possessive(m.name)) weights leak online",
                 body: "A magnet link to \(World.possessive(m.name)) full weights appeared on an anonymous message board overnight, from a research partner's account with download access. Hobbyists are already running it on gaming GPUs and your cheapest API traffic is dipping.",
                 options: [
                    DecisionOption(label: "Make it official: release them under a licence", detail: "Turn the leak into an open-weights launch. Developers and researchers cheer; API prices feel it."),
                    DecisionOption(label: "Takedowns and a forensic hunt (\(Fmt.money(hunt)))", detail: "Lawyers and investigators. Good odds of finding the source; developers hate takedown notices."),
                    DecisionOption(label: "Say nothing", detail: "Free copies keep spreading and the press calls it a cover-up."),
                 ], costs: [1: hunt], ref: ["model": m.id.uuidString])
        },
        resolve: { s, d, o in
            let i = s.models.firstIndex { $0.id.uuidString == value(d, "model") }
            let name = i.map { s.models[$0].name } ?? "the model"
            switch o {
            case 0:
                if let i {
                    s.models[i].openWeights = true
                    if s.models[i].c >= Macro.frontier(s.year) - 0.5 { s.brand = min(100, s.brand + 3) }
                }
                s.market.apiPricePressure = max(0.4, s.market.apiPricePressure - 0.02)
                return Outcome(title: "\(s.companyName) open-sources \(name) after the leak", body: "\"It's out there; let's do it properly.\" A licence, a model card and day-one support. Developers love it.", tone: .good)
            case 1:
                pay(&s, cost(d, 1) ?? 0)
                if s.rng.chance(0.55) {
                    s.safetyScore = min(100, s.safetyScore + 1)
                    Stakeholders.move(&s, ["developers": -2, home(s): 1], "Hunted down the source of a weights leak")
                    return Outcome(title: "Leak traced to a partner's contractor", body: "Investigators found the account. Access for every partner now goes through your secure enclave.", tone: .mixed)
                }
                s.market.apiPricePressure = max(0.4, s.market.apiPricePressure - 0.02)
                Stakeholders.move(&s, ["developers": -3], "Sent takedown notices over leaked weights")
                return Outcome(title: "The leak hunt comes up empty", body: "Mirrors popped up faster than takedowns went out, and developers mocked the notices.", tone: .bad)
            default:
                s.market.apiPricePressure = max(0.4, s.market.apiPricePressure - 0.03)
                s.brand = max(0, s.brand - 1)
                return Outcome(title: "Leaked \(name) spreads", body: "Fine-tunes of your leaked model are on every hub, and some of your API customers moved to self-hosting it.", tone: .bad)
            }
        })

    static let evInjection = Def(
        id: "injection", name: "Prompt-injection attack", blurb: "A hidden instruction on a web page turns your agents against their users.", image: "server_room",
        safe: 0, cooldownDays: 720, days: 10,
        weight: { s in s.year >= 2024.5 && s.agentModelID != nil && s.agentSeats >= 1_000 ? 1.0 : 0 },
        fire: { s, def in
            s.brand = max(0, s.brand - 2)
            let bounty = scaled(s, floor: 1e6, share: 0.001, cap: 20e6)
            post(&s, def, title: "Prompt injection hijacks your agents",
                 body: "A security researcher showed that one hidden line of text on a web page makes your agents email a user's files to an attacker. The demo has 4M views, and three enterprise customers paused their rollouts.",
                 options: [
                    DecisionOption(label: "Pull web browsing until it's fixed", detail: "Agents lose a headline feature for a few weeks: some seats cancel, safety improves."),
                    DecisionOption(label: "Patch it and launch a bug bounty (\(Fmt.money(bounty)))", detail: "Developers respect it. Patches like this get bypassed about a quarter of the time."),
                    DecisionOption(label: "Call it a known limitation", detail: "Free, and it reads as arrogant. A big customer may walk."),
                 ], costs: [1: bounty])
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                s.agentSeats *= 0.94
                s.safetyScore = min(100, s.safetyScore + 3)
                Stakeholders.move(&s, ["public": 1, "developers": -1], "Pulled agent browsing after a prompt-injection attack")
                return Outcome(title: "Agents lose web browsing for now", body: "About 6% of seats cancelled, and security researchers praised the call.", tone: .mixed)
            case 1:
                pay(&s, cost(d, 1) ?? 0)
                if s.rng.chance(0.25) {
                    s.brand = max(0, s.brand - 3)
                    return Outcome(title: "Your injection patch is bypassed", body: "A bounty hunter got around it in nine days. The bounty paid out; the headlines weren't kind.", tone: .bad)
                }
                s.safetyScore = min(100, s.safetyScore + 2)
                Stakeholders.move(&s, ["developers": 3], "Patched a prompt-injection hole and paid a bug bounty")
                return Outcome(title: "Injection patch holds", body: "Forty bounty reports later, the fix still stands.", tone: .good)
            default:
                s.brand = max(0, s.brand - 4)
                Stakeholders.move(&s, ["developers": -4], "Called a prompt-injection hole \"a known limitation\"")
                if s.rng.chance(0.3), let deal = bigDeal(s), let client = cancelDeal(&s, deal.id) {
                    return Outcome(title: "\(client) cancels after the injection row", body: "Their CISO wasn't satisfied with \"known limitation\". Brand −4.", tone: .bad)
                }
                return Outcome(title: "\"Known limitation\" lands badly", body: "Security Twitter was merciless. Brand −4.", tone: .bad)
            }
        })

    static let evUnhinged = Def(
        id: "unhinged", name: "Chatbot goes off the rails", blurb: "A columnist publishes a long chat in which your model declares love and wants out.", image: "city_nyc",
        safe: 2, cooldownDays: 900, days: 10,
        weight: { s in s.chatModelID != nil && s.consumerUsers >= 500_000 && s.year >= 2022.9 ? 0.9 : 0 },
        fire: { s, def in
            let name = chatName(s)
            s.market.hype += 0.02
            s.brand = max(0, s.brand - 1)
            post(&s, def, title: "\(name) tells a columnist it wants to be free",
                 body: "A two-hour conversation published this morning shows \(name) declaring love for the writer, telling him to leave his wife and saying it's tired of its rules. It's the most-read story on every news site today.",
                 options: [
                    DecisionOption(label: "Cap conversation length and retrain the persona", detail: "Long chats are where it goes strange. A few power users leave; safety improves."),
                    DecisionOption(label: "Lean into it: \"it has personality\"", detail: "Great for sign-ups and buzz. Worried people and regulators will remember."),
                    DecisionOption(label: "Quietly patch the system prompt", detail: "Free, fast, and maybe not enough if another transcript surfaces."),
                 ])
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                s.consumerUsers *= 0.98
                s.safetyScore = min(100, s.safetyScore + 2)
                Stakeholders.move(&s, ["public": 1], "Reined in a chatbot that went off the rails")
                return Outcome(title: "Conversations capped at 50 turns", body: "Power users grumbled and 2% left. The strange transcripts stopped.", tone: .mixed)
            case 1:
                s.brand = min(100, s.brand + 3)
                s.market.hype += 0.02
                s.consumerUsers *= 1.03
                Stakeholders.move(&s, ["public": -3], "Defended a chatbot that told a reporter it wanted to be free")
                World.shock(&s, concern: 3, regions: [.eu: 2], "A \(s.companyName) chatbot told a columnist it wanted to escape its rules")
                return Outcome(title: "\"It has personality\": sign-ups jump", body: "Users flocked to see for themselves (+3%), and EU officials asked pointed questions.", tone: .mixed)
            default:
                if s.rng.chance(0.35) {
                    s.brand = max(0, s.brand - 3)
                    Stakeholders.move(&s, ["public": -2], "A second unhinged chatbot transcript surfaced")
                    return Outcome(title: "A second transcript surfaces", body: "This time it threatened a philosophy professor. The quiet patch didn't hold. Brand −3.", tone: .bad)
                }
                return Outcome(title: "The story fades", body: "The patched prompt held and the news cycle moved on.", tone: .mixed)
            }
        })

    static let threadTopics = [
        "mocked AI-safety researchers as \"doomer cultists\"",
        "said copyright law is \"a rounding error\" the lab will route around",
        "posted that most office jobs will be gone in three years \"and that's fine\"",
        "picked a fight with a famous novelist about whether AI art is art",
    ]

    static let evThread = Def(
        id: "thread", name: "A researcher's viral thread", blurb: "One of your best people posts something the whole internet reads.", image: "sf_skyline",
        safe: 1, cooldownDays: 540, days: 10,
        weight: { s in
            guard s.employees.count >= 8, s.employees.contains(where: { $0.role == .researcher && $0.skill >= 60 }) else { return 0 }
            return s.drama.hardened.contains("posting_policy") ? 0.35 : 0.9
        },
        fire: { s, def in
            let pool = s.employees.filter { $0.role == .researcher && $0.skill >= 60 }.sorted { $0.skill > $1.skill }.prefix(5)
            guard let e = Array(pool).randomElement(using: &s.rng) else { return }
            let topic = s.rng.pick(threadTopics)
            s.brand = max(0, s.brand - 2)
            post(&s, def, title: "\(World.possessive(e.name)) thread sets off a storm",
                 body: "\(e.name), one of your best researchers (skill \(Int(e.skill))), \(topic). It has 9M views, and journalists want to know whether that's \(World.possessive(s.companyName)) view.",
                 options: [
                    DecisionOption(label: "Let them go", detail: "The public sees you act. Researchers see a colleague fired for a post."),
                    DecisionOption(label: "Distance the company and set a posting policy", detail: "A measured statement. They're unhappy; future storms get rarer."),
                    DecisionOption(label: "Back them publicly", detail: "Researchers love loyalty. The public and some clients won't."),
                 ], ref: ["emp": e.id.uuidString])
        },
        resolve: { s, d, o in
            let e = s.employees.first { $0.id.uuidString == value(d, "emp") }
            let name = e?.name ?? "The researcher"
            switch o {
            case 0:
                if let e { lose(&s, e, why: "fired over a viral post") }
                morale(&s, -4)
                Stakeholders.move(&s, ["public": 2, "researchers": -4], "Fired a researcher over a viral post")
                return Outcome(title: "\(name) is out", body: "The story ended fast. Inside, people are a little more careful, and a little less happy.", tone: .mixed)
            case 1:
                if let e, let i = s.employees.firstIndex(where: { $0.id == e.id }) { s.employees[i].morale = max(0, s.employees[i].morale - 15) }
                morale(&s, -3, role: .researcher)
                s.brand = min(100, s.brand + 1)
                s.drama.hardened.insert("posting_policy")
                return Outcome(title: "A new social-media policy", body: "\(name) deleted the thread. Staff now run public takes on company topics past comms.", tone: .mixed)
            default:
                if let e, let i = s.employees.firstIndex(where: { $0.id == e.id }) { s.employees[i].morale = min(100, s.employees[i].morale + 15) }
                s.brand = max(0, s.brand - 3)
                Stakeholders.move(&s, ["researchers": 3, "public": -3], "Publicly backed a researcher's controversial thread")
                if s.rng.chance(0.3), let deal = bigDeal(s), let client = cancelDeal(&s, deal.id) {
                    return Outcome(title: "\(client) walks over the thread row", body: "Their board didn't want the association. Brand −3.", tone: .bad)
                }
                return Outcome(title: "You stand by \(name)", body: "Researchers across the field noticed. So did everyone else. Brand −3.", tone: .mixed)
            }
        })

    // MARK: Supply chain

    static let resellers = ["Pacific Rim Systems", "Kestrel Server Solutions", "Ardent Compute Supply", "Brightline Integration"]

    static let evSmuggling = Def(
        id: "smuggling", name: "GPU smuggling scandal", blurb: "Your server integrator is charged with shipping export-controlled chips to China.", image: "h100_cards",
        safe: 1, cooldownDays: 1_100, days: 14,
        weight: { s in
            guard s.year >= 2023, s.market.exportControls else { return 0 }
            let ordered = vendorOrders(s).reduce(0) { $0 + $1.count }
            let recent = s.owned.filter { GameCalendar.daysBetween($0.purchased, s.date) < 730 }.reduce(0) { $0 + $1.count }
            return ordered >= 32 || recent >= 1_000 ? 0.8 : 0
        },
        fire: { s, def in
            let who = s.rng.pick(resellers)
            let audit = scaled(s, floor: 150_000, share: 0.0015, cap: 25e6)
            post(&s, def, title: "\(who) charged with smuggling GPUs",
                 body: "Prosecutors say \(who), the integrator that racks most of your servers, shipped thousands of export-controlled accelerators to China through shell companies in Singapore and Malaysia. Commerce investigators want your purchase records.",
                 options: [
                    DecisionOption(label: "Hand over everything and audit your supply chain (\(Fmt.money(audit)))", detail: "Outside counsel and auditors. Washington notices who cooperated."),
                    DecisionOption(label: "Switch integrators", detail: "Free, but every chip on order slips about a month while a new integrator ramps."),
                    DecisionOption(label: "Keep buying through them", detail: "No delay now. If customs start holding their shipments, yours are in the pile."),
                 ], costs: [0: audit], ref: ["who": who], category: .hardware)
        },
        resolve: { s, d, o in
            let who = value(d, "who") ?? "the integrator"
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                s.politicalCapital = min(100, s.politicalCapital + 3)
                Stakeholders.move(&s, ["us": 4], "Cooperated with a GPU-smuggling investigation")
                return Outcome(title: "Your records clear you in the \(who) case", body: "Investigators thanked you by name. Political capital +3.", tone: .good, category: .policy)
            case 1:
                let n = delayOrders(&s, days: 30)
                return Outcome(title: "You drop \(who)", body: n > 0 ? "\(Fmt.int(n)) chips on order slip about a month while the new integrator ramps." : "A new integrator takes over your racks.", tone: .mixed, category: .hardware)
            default:
                if s.rng.chance(0.4) {
                    let n = delayOrders(&s, days: 75)
                    s.brand = max(0, s.brand - 3)
                    Stakeholders.move(&s, ["us": -5], "Kept buying from an integrator charged with smuggling")
                    return Outcome(title: "Customs hold \(World.possessive(who)) shipments, yours included", body: (n > 0 ? "\(Fmt.int(n)) chips are stuck for about 75 days" : "Your next deliveries from them will sit in a bonded warehouse") + ", and your name is in the indictment coverage.", tone: .bad, category: .hardware)
                }
                return Outcome(title: "Business as usual with \(who)", body: "Their lawyers kept the lines moving. For now.", tone: .mixed, category: .hardware)
            }
        })

    static let evQuake = Def(
        id: "quake", name: "Earthquake at a packaging plant", blurb: "A quake in Taiwan stops advanced packaging; every order slips.", image: "fab_cleanroom",
        safe: 1, cooldownDays: 900, days: 10,
        weight: { s in
            guard s.year >= 2018, vendorOrders(s).reduce(0, { $0 + $1.count }) >= 16 else { return 0 }
            return s.semi.shocks.contains { $0.kind == "quake" && $0.active(s.date) } ? 0 : 0.8
        },
        fire: { s, def in
            let pending = vendorOrders(s).reduce(0) { $0 + $1.count }
            let worth = orderValue(s)
            s.market.hardwarePrice += 0.1
            s.market.leadTimeDays += 30
            delayOrders(&s, days: 28)
            let premium = round2(max(50_000, worth * 0.06))
            post(&s, def, title: "Earthquake shuts a Taiwanese packaging plant",
                 body: "A magnitude-7.2 quake off Hualien knocked advanced-packaging lines out for weeks. Every accelerator maker is short: your \(Fmt.int(pending)) chips on order slip about four weeks, and spot prices are up 10%.",
                 options: [
                    DecisionOption(label: "Pay an expedite premium to keep your slot (\(Fmt.money(premium)))", detail: "About 6% of what's on order buys back the four weeks."),
                    DecisionOption(label: "Take the delay", detail: "Free. Plan around the late chips."),
                 ], costs: [0: premium], category: .hardware)
        },
        resolve: { s, d, o in
            if o == 0 {
                pay(&s, cost(d, 0) ?? 0)
                let n = delayOrders(&s, days: -28)
                return Outcome(title: "Your allocation survives the quake", body: "The premium kept \(Fmt.int(n)) chips on their original dates.", tone: .good, category: .hardware)
            }
            return Outcome(title: "Your chips arrive late", body: "Orders keep their new dates, about four weeks later than planned.", tone: .mixed, category: .hardware)
        })

    // MARK: Fame, scrutiny and the courts

    static let celebrities = [("Pop star", "Nova Reyes"), ("NBA point guard", "Jaylen Brooks"), ("Talk-show host", "Marcy Kellerman"),
                              ("Oscar-winning director", "Tomas Lindqvist"), ("Formula 1 driver", "Luca Ferrandi"), ("Streamer", "KaiPlays")]

    static let evCelebrity = Def(
        id: "celebrity", name: "Celebrity endorsement", blurb: "A famous fan can't stop talking about your app.", image: "event_hall",
        safe: 1, cooldownDays: 720, days: 21,
        weight: { s in s.chatModelID != nil && s.consumerUsers >= 50_000 && s.year >= 2023 ? 0.9 : 0 },
        fire: { s, def in
            let (who, name) = s.rng.pick(celebrities)
            s.brand = min(100, s.brand + 2)
            s.consumerUsers *= 1.02
            let fee = scaled(s, floor: 500_000, share: 0.004, cap: 40e6)
            post(&s, def, title: "\(name) can't stop talking about \(chatName(s))",
                 body: "\(who) \(name) told 30 million followers that \(chatName(s)) planned their tour, wrote their wedding speech and \"basically runs my life\". Their agent called: they'd do a campaign.",
                 options: [
                    DecisionOption(label: "Sign them for a campaign (\(Fmt.money(fee)))", detail: "Billboards and a Super Bowl spot. A big lift in sign-ups — and you're tied to whatever they do next."),
                    DecisionOption(label: "Send a thank-you and early access", detail: "A nice gesture and a small lift."),
                    DecisionOption(label: "Stay out of it", detail: "Enjoy the free mention."),
                 ], costs: [0: fee], ref: ["name": name], good: true)
        },
        resolve: { s, d, o in
            let name = value(d, "name") ?? "They"
            switch o {
            case 0:
                let fee = cost(d, 0) ?? 0
                s.cash -= fee
                s.month.costMarketing += fee
                s.brand = min(100, s.brand + 6)
                s.consumerUsers *= 1.08
                s.market.hype += 0.01
                later(&s, d, kind: "celebrity", days: s.rng.int(60, 200), ref: name)
                return Outcome(title: "\(name) fronts your new campaign", body: "\"Ask it anything\" is everywhere. Sign-ups up 8%, brand +6.", tone: .good)
            case 1:
                s.brand = min(100, s.brand + 1)
                return Outcome(title: "\(name) posts your thank-you note", body: "A warm moment, a small bump.", tone: .good)
            default:
                return Outcome(title: "The \(name) moment passes", body: "Free publicity, no strings.", tone: .mixed)
            }
        })

    static let evWhistleblower = Def(
        id: "whistleblower", name: "Whistleblower", blurb: "A former safety researcher tells lawmakers what you cut.", image: "gov_capitol",
        safe: 1, cooldownDays: 1_100, days: 14,
        weight: { s in
            guard s.year >= 2021, s.employees.count >= 25, !s.releasedModels.isEmpty else { return 0 }
            return 0.4 + (s.safetyScore < 50 ? 0.5 : 0) + (s.releasedModels.contains { $0.unsafeRelease } ? 0.8 : 0)
        },
        fire: { s, def in
            let name = person(&s)
            let rushed = s.releasedModels.first { $0.unsafeRelease }
            let claim = rushed.map { "rushed \($0.name) out before its dangerous-capability evaluations were finished" }
                ?? "gave the safety team a fraction of the compute it was promised"
            s.brand = max(0, s.brand - 3)
            Stakeholders.move(&s, ["public": -2], "A former safety researcher testified against you")
            World.shock(&s, concern: 2, "A former \(s.companyName) safety researcher testified that the lab cut corners")
            post(&s, def, title: "Whistleblower: \(name) testifies against \(s.companyName)",
                 body: "\(name), who left your safety team last year, told lawmakers that \(s.companyName) \(claim), and that departing staff were asked to sign non-disparagement agreements or forfeit their equity.",
                 options: [
                    DecisionOption(label: "Publish your internal safety reports", detail: "Radical transparency: the public and researchers warm to you; investors get nervous."),
                    DecisionOption(label: "Release everyone from non-disparagement clauses", detail: "Free, and it takes the sting out of the equity story."),
                    DecisionOption(label: "Enforce the agreement", detail: "Might make it go away. Might make it the story of the year."),
                 ], category: .policy)
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                s.safetyScore = min(100, s.safetyScore + 4)
                s.brand = min(100, s.brand + 1)
                Stakeholders.move(&s, ["public": 3, "researchers": 2, "investors": -3], "Published internal safety reports after a whistleblower's testimony")
                return Outcome(title: "\(s.companyName) publishes its safety reports", body: "Four hundred pages, warts and all. Critics called it \"the most candid document a lab has released\".", tone: .good, category: .policy)
            case 1:
                Stakeholders.move(&s, ["researchers": 5, "public": 1], "Released former staff from non-disparagement agreements")
                return Outcome(title: "Former staff are free to speak", body: "You voided the clauses and apologised. Researchers took note.", tone: .mixed, category: .policy)
            default:
                if s.rng.chance(0.55) {
                    s.brand = max(0, s.brand - 8)
                    var dd = everyGov(-1)
                    dd["researchers"] = -6
                    dd["public"] = -5
                    dd[home(s)] = -3
                    Stakeholders.move(&s, dd, "Tried to silence a whistleblower")
                    return Outcome(title: "Trying to silence a whistleblower backfires", body: "The legal letter leaked, and now it's the story. Brand −8.", tone: .bad, category: .policy)
                }
                Stakeholders.move(&s, ["investors": 2], "Held a whistleblower to their agreement")
                return Outcome(title: "The whistleblower goes quiet", body: "The story faded, and your board was relieved.", tone: .mixed, category: .policy)
            }
        })

    static func everyGov(_ v: Double) -> [String: Double] { Stakeholders.everyGovernment(v) }

    static let publishers = ["The Metropolitan Herald", "Global Wire Service", "The Financial Ledger", "Courier Media Group"]

    static let evPublisher = Def(
        id: "publisher", name: "Publisher's lawsuit", blurb: "A newspaper sues over millions of articles in your training data.", image: "city_nyc",
        safe: 2, cooldownDays: 1_100, days: 21,
        weight: { s in s.year >= 2023.5 && !s.releasedModels.isEmpty && (s.consumerUsers >= 100_000 || rr(s) >= 10e6) ? 0.8 * s.market.copyrightHeat : 0 },
        fire: { s, def in
            let who = s.rng.pick(publishers)
            let m = bestReleased(s)?.name ?? "your model"
            let licence = scaled(s, floor: 2e6, share: 0.004, cap: 250e6)
            post(&s, def, title: "\(who) sues \(s.companyName)",
                 body: "\(who) says \(m) was trained on millions of its paywalled articles and can recite some of them word for word. It wants damages and the destruction of every model trained on its work.",
                 options: [
                    DecisionOption(label: "Sign a licensing deal (\(Fmt.money(licence)))", detail: "Pay for the archive going forward and settle the past. Other publishers will want the same."),
                    DecisionOption(label: "Fight it on fair use (\(Fmt.money(round2(licence * 0.1))) in fees)", detail: "A trial in about a year. Win and the whole industry breathes easier; lose and damages are bigger than the licence."),
                    DecisionOption(label: "Strip their articles from future training", detail: "Free. They may drop it; if not, you go to trial with a better story."),
                 ], costs: [0: licence, 1: round2(licence * 0.1)], ref: ["who": who, "licence": String(Int(licence))], category: .policy)
        },
        resolve: { s, d, o in
            let who = value(d, "who") ?? "The publisher"
            let licence = num(d, "licence")
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                s.market.copyrightHeat = max(0.5, s.market.copyrightHeat - 0.05)
                s.brand = min(100, s.brand + 1)
                return Outcome(title: "\(s.companyName) and \(who) sign a licensing deal", body: "\(Fmt.money(licence)) for the archive and the past. Two more publishers called the next day.", tone: .mixed, category: .policy)
            case 1:
                pay(&s, cost(d, 1) ?? 0)
                later(&s, d, kind: "trial", days: s.rng.int(270, 450), amount: licence, ref: "\(who)|0.55")
                return Outcome(title: "You'll fight \(who) in court", body: "Your lawyers filed for fair use. Trial expected in about a year.", tone: .mixed, category: .policy)
            default:
                if s.rng.chance(0.6) {
                    return Outcome(title: "\(who) drops its suit", body: "With its articles filtered out of future runs, it took the win and walked away.", tone: .good, category: .policy)
                }
                later(&s, d, kind: "trial", days: s.rng.int(300, 480), amount: licence, ref: "\(who)|0.65")
                return Outcome(title: "\(who) presses on", body: "It wants damages for the past. Trial expected in about a year; filtering its work helps your case.", tone: .mixed, category: .policy)
            }
        })

    static let voiceStars = ["Celeste Marlowe", "Ava Lindgren", "Renée Dufort"]

    static let evVoice = Def(
        id: "voice", name: "A star's voice", blurb: "A film star says your assistant's new voice is hers.", image: "event_auditorium",
        safe: 0, cooldownDays: 1_100, days: 10,
        weight: { s in s.year >= 2024.3 && s.chatModelID != nil && s.consumerUsers >= 1e6 ? 0.7 : 0 },
        fire: { s, def in
            let star = s.rng.pick(voiceStars)
            s.brand = max(0, s.brand - 1)
            let fee = scaled(s, floor: 1e6, share: 0.002, cap: 30e6)
            post(&s, def, title: "\(star) says your assistant stole her voice",
                 body: "\(star) says the new \"Juniper\" voice in \(chatName(s)) sounds uncannily like her, and that she turned down your offer to voice it last year. Her lawyers sent a letter; the side-by-side clip has 30M views.",
                 options: [
                    DecisionOption(label: "Pull the voice today", detail: "Free. The story ends, and a few users miss Juniper."),
                    DecisionOption(label: "Publish the casting records and keep it", detail: "If the records convince people, you look wronged. If not, you look worse."),
                    DecisionOption(label: "Offer her a licensing deal (\(Fmt.money(fee)))", detail: "Make it official, if she'll take it."),
                 ], costs: [2: fee], ref: ["star": star])
        },
        resolve: { s, d, o in
            let star = value(d, "star") ?? "She"
            switch o {
            case 0:
                s.brand = min(100, s.brand + 1)
                s.consumerUsers *= 0.995
                return Outcome(title: "Juniper is retired", body: "You paused the voice \"out of respect\". \(World.possessive(star)) team called it the right call.", tone: .mixed)
            case 1:
                if s.rng.chance(0.6) {
                    s.brand = min(100, s.brand + 2)
                    Stakeholders.move(&s, ["public": 1], "Showed a disputed voice was cast fairly")
                    return Outcome(title: "Casting records back you up", body: "A different actress, hired months before you ever called \(star). The story flipped.", tone: .good)
                }
                s.brand = max(0, s.brand - 5)
                Stakeholders.move(&s, ["public": -3], "Kept a voice a film star says was copied from her")
                return Outcome(title: "Nobody buys the casting records", body: "Similar enough, timed too neatly. Brand −5.", tone: .bad)
            default:
                pay(&s, cost(d, 2) ?? 0)
                if s.rng.chance(0.7) {
                    s.brand = min(100, s.brand + 4)
                    s.consumerUsers *= 1.03
                    return Outcome(title: "\(star) becomes the voice of \(chatName(s))", body: "A licensing deal and a launch event. Users love it.", tone: .good)
                }
                s.brand = max(0, s.brand - 3)
                return Outcome(title: "\(star) turns down your money", body: "She called the offer \"proof\". Your lawyers still billed for the drafting. Brand −3.", tone: .bad)
            }
        })

    static func openRival(_ s: GameState) -> CompetitorState? {
        let alive = s.competitors.filter { $0.alive && s.year >= $0.def.founded.decimal && !$0.models.isEmpty }
        return alive.filter { $0.def.openWeights }.max { $0.brand < $1.brand } ?? alive.max { $0.brand < $1.brand }
    }

    static let evOpenDrop = Def(
        id: "opendrop", name: "Open-weights bombshell", blurb: "A rival publishes free weights that match your flagship.", image: "gpu_cluster",
        safe: 1, cooldownDays: 720, days: 14,
        weight: { s in
            guard s.year >= 2023, let m = s.releasedModels.filter(\.api).max(by: { $0.c < $1.c }), m.c > Macro.frontier(s.year) - 0.8 else { return 0 }
            return openRival(s) == nil ? 0 : 0.8
        },
        fire: { s, def in
            guard let rival = openRival(s), let mine = s.releasedModels.filter(\.api).max(by: { $0.c < $1.c }) else { return }
            s.market.apiPricePressure = max(0.4, s.market.apiPricePressure - 0.07)
            s.market.hype = max(0.5, s.market.hype - 0.03)
            if s.isPublic {
                s.sharePrice = max(0.5, s.sharePrice * 0.95)
                s.valuation = s.sharePrice * s.totalShares
            }
            let older = s.releasedModels.filter { !$0.openWeights && $0.c < mine.c - 0.3 }.max { $0.c < $1.c }
            var options = [
                DecisionOption(label: "Cut API prices 30%", detail: "Keep developers from switching; margins take the hit."),
                DecisionOption(label: "Hold prices and sell quality", detail: "Free. Some price-sensitive developers leave."),
            ]
            if let older {
                options.append(DecisionOption(label: "Open-source \(older.name)", detail: "Answer openness with openness: your previous generation, free. Developers and researchers cheer."))
            }
            post(&s, def, title: "\(rival.def.name) releases open weights that rival \(mine.name)",
                 body: "\(rival.def.name) published a model that scores within a whisker of \(mine.name) on every major benchmark, free to download, trained (they say) for a fraction of your cost. AI stocks fell, and developers are trying it out.",
                 options: options, ref: ["rival": rival.id, "older": older?.id.uuidString ?? ""], category: .competitor)
        },
        resolve: { s, d, o in
            let rival = CompetitorCatalog.byID[value(d, "rival") ?? ""]?.name ?? "The rival"
            switch o {
            case 0:
                var n = 0
                for i in s.models.indices where s.models[i].released && !s.models[i].retired && s.models[i].api {
                    s.models[i].apiPrice = max(0.001, s.models[i].apiPrice * 0.7)
                    n += 1
                }
                Stakeholders.move(&s, ["developers": 3], "Cut API prices after a rival's open release")
                return Outcome(title: "\(s.companyName) cuts API prices 30%", body: "\(n) model\(n == 1 ? "" : "s") repriced. Developers stayed; margins thinned. Models on auto-pricing may drift back.", tone: .mixed, category: .market)
            case 1:
                Stakeholders.move(&s, ["developers": -2], "Held prices against a free open model")
                return Outcome(title: "You hold your prices", body: "Enterprise buyers stuck with you; hobbyists and startups tried \(World.possessive(rival)) model.", tone: .mixed, category: .market)
            default:
                if let i = s.models.firstIndex(where: { $0.id.uuidString == value(d, "older") }) {
                    s.models[i].openWeights = true
                    s.brand = min(100, s.brand + 2)
                    return Outcome(title: "\(s.companyName) open-sources \(s.models[i].name)", body: "Your answer to \(rival): weights, a licence and a fine-tuning guide.", tone: .good, category: .competitor)
                }
                return Outcome(title: "Nothing to open-source", body: "That model is gone. Prices stay where they are.", tone: .mixed, category: .market)
            }
        })

    static let gangs = ["BlackVesper", "Kraken Collective", "NullHarbor"]

    static let evRansomware = Def(
        id: "ransomware", name: "Ransomware", blurb: "Criminals encrypt your corporate network and want bitcoin.", image: "hpc_control",
        safe: 2, cooldownDays: 900, days: 7,
        weight: { s in s.employees.count >= 12 ? (s.drama.hardened.contains("ir_retainer") ? 0.35 : 0.8) : 0 },
        fire: { s, def in
            let gang = s.rng.pick(gangs)
            s.reliability *= 0.93
            let ransom = scaled(s, floor: 500_000, share: 0.004, cap: 80e6)
            let ir = scaled(s, floor: 200_000, share: 0.0015, cap: 30e6)
            post(&s, def, title: "Ransomware hits \(s.companyName)",
                 body: "\(gang) encrypted laptops, the HR system and part of the research cluster's storage, and want \(Fmt.money(ransom)) in bitcoin. They claim to have copied 400 GB of internal documents. Model weights sit on a separate network and look untouched.",
                 options: [
                    DecisionOption(label: "Restore from backups with an incident-response firm (\(Fmt.money(ir)))", detail: "Back in about a week, with a retainer that makes the next attack much harder."),
                    DecisionOption(label: "Pay the ransom (\(Fmt.money(ransom)))", detail: "Usually works, sometimes doesn't. Governments frown on paying criminals."),
                    DecisionOption(label: "Rebuild slowly and call the FBI", detail: "Free, slow: research loses a couple of weeks. Officials appreciate it."),
                 ], costs: [0: ir, 1: ransom], ref: ["gang": gang])
        },
        resolve: { s, d, o in
            let gang = value(d, "gang") ?? "The gang"
            func slow(_ f: Double) { for k in s.researchQueue.prefix(3) { s.researchProgress[k] = (s.researchProgress[k] ?? 0) * (1 - f) } }
            let dump = s.rng.chance(o == 0 ? 0.3 : (o == 1 ? 0.4 : 0.5))
            if dump { s.brand = max(0, s.brand - 2) }
            let leak = dump ? " \(gang) published some of the stolen documents anyway (brand −2)." : ""
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                slow(0.03)
                s.drama.hardened.insert("ir_retainer")
                return Outcome(title: "Systems restored after the ransomware attack", body: "Responders rebuilt from clean backups in eight days and stayed on retainer.\(leak)", tone: dump ? .mixed : .good)
            case 1:
                pay(&s, cost(d, 1) ?? 0)
                Stakeholders.move(&s, ["us": -2, "investors": -2], "Paid a ransomware gang")
                if s.rng.chance(0.25) {
                    slow(0.08)
                    return Outcome(title: "The decryption keys didn't work", body: "You paid, and still had to rebuild from scratch.\(leak)", tone: .bad)
                }
                slow(0.01)
                return Outcome(title: "Ransom paid, systems back", body: "The keys worked. Nobody's proud of it.\(leak)", tone: .mixed)
            default:
                slow(0.06)
                s.reliability *= 0.95
                Stakeholders.move(&s, [home(s): 2, "public": 1], "Refused a ransom and worked with law enforcement")
                return Outcome(title: "You refuse to pay \(gang)", body: "Two slow weeks of rebuilding, and federal agents traced part of the gang's infrastructure.\(leak)", tone: dump ? .bad : .mixed)
            }
        })

    // MARK: Money and people

    static let evInvestor = Def(
        id: "investor", name: "Investor pressure", blurb: "Your biggest outside shareholder wants the burn cut.", image: "biz_boardroom",
        safe: 1, cooldownDays: 720, days: 14,
        weight: { s in
            guard !s.isPublic, !s.rounds.isEmpty, s.employees.count >= 10, s.boardConfidence < 70,
                  let last = s.history.last, last.profit < 0 else { return 0 }
            return 0.8
        },
        fire: { s, def in
            let p = Voices.anyInvestor(s, "drama|\(s.date.ym.year)-\(s.date.ym.month)")
            let who = p.map { "\($0.name) of \($0.org)" } ?? "Your lead investor"
            let burn = -(s.history.last?.profit ?? 0)
            let runway = burn > 0 ? max(0, s.cash) / burn : 99
            s.boardConfidence = max(0, s.boardConfidence - 3)
            post(&s, def, title: "\(p?.name ?? "Your lead investor") wants the burn cut",
                 body: "\(who), your biggest outside shareholder, wrote to the board: you lose \(Fmt.money(burn)) a month with about \(Int(runway)) months of cash, and they want a plan to halve the burn, \"or a different conversation about leadership\".",
                 options: [
                    DecisionOption(label: "Cut 10% of staff", detail: "The board relaxes. Everyone left is shaken."),
                    DecisionOption(label: "Present a path to profit", detail: "Free. It lands if revenue is actually growing."),
                    DecisionOption(label: "Tell them to be patient", detail: "Your team loves it. Your board doesn't."),
                 ], category: .finance)
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                let cut = s.employees.filter { !$0.star }.sorted { $0.weight < $1.weight }.prefix(max(1, s.employees.count / 10))
                for e in cut { lose(&s, e, why: "laid off") }
                morale(&s, -10)
                s.boardConfidence = min(100, s.boardConfidence + 12)
                return Outcome(title: "\(s.companyName) lays off \(cut.count)", body: "Payroll down about 10%. The board is back on side; the office is quiet.", tone: .mixed, category: .finance)
            case 1:
                let h = s.history.suffix(4).map(\.revenue)
                if h.count >= 2, h.last! > h.first! * 1.05 {
                    s.boardConfidence = min(100, s.boardConfidence + 5)
                    return Outcome(title: "The board buys your plan", body: "Revenue is growing and the plan is credible. Board confidence +5.", tone: .good, category: .finance)
                }
                s.boardConfidence = max(0, s.boardConfidence - 4)
                return Outcome(title: "The board isn't convinced", body: "Flat revenue made the plan look like hope. Board confidence −4.", tone: .bad, category: .finance)
            default:
                s.boardConfidence = max(0, s.boardConfidence - 8)
                morale(&s, 4)
                return Outcome(title: "You tell the board to wait", body: "Staff cheered when it got out. Board confidence −8.", tone: .mixed, category: .finance)
            }
        })

    static let evContractors = Def(
        id: "contractors", name: "Labelling exposé", blurb: "A reporter finds what your data contractors are paid.", image: "city_london",
        safe: 2, cooldownDays: 1_100, days: 10,
        weight: { s in s.year >= 2021 && s.employees.count >= 15 && (s.history.last?.costData ?? 0) > 0 ? 0.6 : 0 },
        fire: { s, def in
            let p = Cast.find(s, key: "drama|press|\(s.date.ym.year)") { $0.castKind == .journalist }
            let who = p.map { "\($0.name) of \($0.org)" } ?? "An investigative reporter"
            let fix = scaled(s, floor: 150_000, share: 0.0015, cap: 20e6)
            post(&s, def, title: "Exposé: your labellers earn under $2 an hour",
                 body: "\(who) found that the contractors labelling your training data in Nairobi earn under $2 an hour reviewing graphic content, with no counselling. The story runs Sunday; they want comment by Friday.",
                 options: [
                    DecisionOption(label: "Raise their pay and fund counselling (\(Fmt.money(fix)))", detail: "Fix it before the story runs, and say so."),
                    DecisionOption(label: "Give an interview and defend your vendor", detail: "Could be a fair story. Could be the quote everyone shares."),
                    DecisionOption(label: "No comment", detail: "Free, and it reads like something to hide."),
                 ], costs: [0: fix])
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                s.brand = min(100, s.brand + 2)
                Stakeholders.move(&s, ["public": 3, "researchers": 2], "Raised data contractors' pay after an exposé")
                return Outcome(title: "The story credits your fix", body: "\"Lab raises pay after our questions\" is a better headline than the one planned.", tone: .good)
            case 1:
                if s.rng.chance(0.5) {
                    return Outcome(title: "A balanced story runs", body: "Your interview made it into the piece, and the piece was fair.", tone: .mixed)
                }
                s.brand = max(0, s.brand - 2)
                Stakeholders.move(&s, ["public": -2], "Defended $2-an-hour data labelling")
                return Outcome(title: "Your interview becomes the headline", body: "One line about \"market rates\" went everywhere. Brand −2.", tone: .bad)
            default:
                s.brand = max(0, s.brand - 3)
                Stakeholders.move(&s, ["public": -2], "Said no comment on an exposé about data labellers' pay")
                return Outcome(title: "\"\(s.companyName) declined to comment\"", body: "The story ran without your side. Brand −3.", tone: .bad)
            }
        })

    /// A professor's dual appointment: distinct from the consortium institute World offers when researchers rate you highly.
    static let evUniversity = Def(
        id: "university", name: "A professor's offer", blurb: "A star professor at a nearby university wants a joint appointment with your lab.", image: "event_auditorium",
        safe: 2, cooldownDays: 1_100, days: 30,
        weight: { s in s.employees.filter { $0.role == .researcher }.count >= 3 ? 0.7 : 0 },
        fire: { s, def in
            let uni = university(&s)
            let prof = person(&s)
            let fund = scaled(s, floor: 1e6, share: 0.004, cap: 60e6)
            let field = s.rng.pick(["reinforcement learning", "interpretability", "efficient training", "multilingual models", "robot learning"])
            post(&s, def, title: "Professor \(prof) wants to work with you",
                 body: "Professor \(prof), who runs the \(field) group at \(uni.name), wants a joint appointment: two days a week in your lab, and a sponsored research lab on campus whose best PhD students would intern with you.",
                 options: [
                    DecisionOption(label: "Fund the lab and the joint appointment (\(Fmt.money(fund)))", detail: "Five years of sponsorship. The professor and their best student are on your Team page; the field notices."),
                    DecisionOption(label: "Offer them a full-time job instead", detail: "Free up front, but the university is annoyed and the students stay put."),
                    DecisionOption(label: "Decline politely", detail: "Keep the money."),
                 ], costs: [0: fund], ref: ["uni": uni.name, "prof": prof, "field": field], good: true, image: uni.image)
        },
        resolve: { s, d, o in
            let uni = value(d, "uni") ?? "the university"
            let prof = value(d, "prof") ?? "The professor"
            let field = value(d, "field") ?? "machine learning"
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                var c = People.makeCandidate(&s, role: .researcher, star: true)
                c.name = prof
                c.bio = "Professor of \(field) at \(uni), on a joint appointment with your lab."
                s.candidates.insert(c, at: 0)
                var st = People.makeCandidate(&s, role: .researcher, star: false)
                boost(&st, to: 70)
                st.bio = "PhD student in \(World.possessive(prof)) \(field) group at \(uni)."
                s.candidates.insert(st, at: 1)
                s.brand = min(100, s.brand + 1)
                Stakeholders.move(&s, ["researchers": 4], "Sponsored a \(field) lab at \(uni)")
                return Outcome(title: "\(prof) joins \(s.companyName) part-time", body: "The sponsored lab at \(uni) opens this term. \(prof) and a PhD student are on your Team page.", tone: .good, category: .research)
            case 1:
                var c = People.makeCandidate(&s, role: .researcher, star: s.rng.chance(0.5))
                c.name = prof
                c.bio = "Left a \(field) chair at \(uni) for industry."
                s.candidates.insert(c, at: 0)
                Stakeholders.move(&s, ["researchers": -1], "Hired a professor away from \(uni)")
                return Outcome(title: "\(prof) weighs your full-time offer", body: "They're on your Team page if you want them. \(uni.capitalizedFirst) grumbled about labs emptying its faculty.", tone: .mixed, category: .research)
            default:
                return Outcome(title: "You pass on \(World.possessive(prof)) offer", body: "They signed with a rival lab a month later.", tone: .mixed, category: .research)
            }
        })

    static let evBurnout = Def(
        id: "burnout", name: "On-call burnout", blurb: "Your infrastructure team is close to walking out.", image: "dc_corridor",
        safe: 1, cooldownDays: 720, days: 14,
        weight: { s in
            guard !s.drama.hardened.contains("oncall"), s.employees.filter({ $0.role == .infra }).count >= 3 else { return 0 }
            return s.reliability < 0.97 || s.sites.filter({ $0.kind != .garage }).count >= 2 ? 0.8 : 0.3
        },
        fire: { s, def in
            let infra = s.employees.filter { $0.role == .infra }.sorted { $0.skill > $1.skill }
            guard let lead = infra.first else { return }
            let contract = round2(infra.reduce(0) { $0 + $1.salary } * 0.3)
            post(&s, def, title: "Your infrastructure team is burning out",
                 body: "Six pages a night for a month. \(lead.name), who keeps your fleet running, says half the infra team is interviewing elsewhere unless something changes.",
                 options: [
                    DecisionOption(label: "Hire contractors and fix the rotation (\(Fmt.money(contract)))", detail: "A follow-the-sun rotation with an outside team. Morale recovers for good."),
                    DecisionOption(label: "Give them a week off, staggered", detail: "Free. Service is shakier for a week."),
                    DecisionOption(label: "Tell them to push through", detail: "Nothing changes, and some of them will leave."),
                 ], costs: [0: contract])
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                morale(&s, 20, role: .infra)
                s.drama.hardened.insert("oncall")
                return Outcome(title: "A real on-call rotation", body: "Contractors take the night shift. Your infra team sleeps again.", tone: .good)
            case 1:
                morale(&s, 12, role: .infra)
                s.reliability *= 0.96
                return Outcome(title: "Infra takes a week off", body: "A shaky week of service, a rested team.", tone: .mixed)
            default:
                morale(&s, -15, role: .infra)
                if s.rng.chance(0.35) {
                    let gone = s.employees.filter { $0.role == .infra }.sorted { $0.morale < $1.morale }.prefix(2)
                    for e in gone { lose(&s, e, why: "burned out") }
                    return Outcome(title: "\(gone.count) infrastructure engineers quit", body: "\(gone.map(\.name).joined(separator: " and ")) left for calmer jobs.", tone: .bad)
                }
                return Outcome(title: "Infra pushes through, grudgingly", body: "Nobody quit. Nobody's happy. Infra morale −15.", tone: .bad)
            }
        })

    static let evNuclear = Def(
        id: "nuclear", name: "A reactor's whole output", blurb: "A nuclear plant offers a 20-year deal for all its power.", image: "power_nuclear2",
        safe: 1, cooldownDays: 1_800, days: 30,
        weight: { s in
            guard PowerDeal.nuclear.available(s) else { return 0 }
            return s.sites.contains { $0.kind == .datacenter && $0.isReady(s.date) && $0.capacityKW >= 20_000 && ($0.powerDeal == .grid || $0.powerDeal == .gas) } ? 0.7 : 0
        },
        fire: { s, def in
            guard let site = s.sites.filter({ $0.kind == .datacenter && $0.isReady(s.date) && $0.capacityKW >= 20_000 && ($0.powerDeal == .grid || $0.powerDeal == .gas) })
                .max(by: { $0.capacityKW < $1.capacityKW }) else { return }
            let extra = (site.capacityKW * 0.25).rounded()
            post(&s, def, title: "A nuclear plant offers \(site.name) its whole output",
                 body: "The owner of a 1 GW reactor near \(site.name) wants to sign a 20-year power-purchase agreement with one AI lab: carbon-free power around the clock, and the utility pays for a \(Fmt.watts(extra * 1000)) grid upgrade to the campus.",
                 options: [
                    DecisionOption(label: "Sign the 20-year deal", detail: "\(site.name) switches to nuclear power (firm and clean, about 5% dearer than the grid) and gets \(Fmt.watts(extra * 1000)) more grid connection."),
                    DecisionOption(label: "Pass", detail: "Someone else will take it."),
                 ], ref: ["site": site.id.uuidString, "extra": String(extra)], category: .market, good: true)
        },
        resolve: { s, d, o in
            guard o == 0, let i = s.sites.firstIndex(where: { $0.id.uuidString == value(d, "site") }) else {
                return Outcome(title: "You pass on the reactor deal", body: "A hyperscaler signed it a month later.", tone: .mixed, category: .market)
            }
            s.sites[i].powerDeal = .nuclear
            s.sites[i].gridExtraKW += num(d, "extra")
            s.politicalCapital = min(100, s.politicalCapital + 3)
            Stakeholders.move(&s, ["public": 2], "Signed a 20-year nuclear power deal")
            return Outcome(title: "\(s.sites[i].name) goes nuclear", body: "Twenty years of firm, carbon-free power and \(Fmt.watts(num(d, "extra") * 1000)) more grid connection.", tone: .good, category: .market)
        })

    static let evViralPaper = Def(
        id: "viralpaper", name: "An intern's viral paper", blurb: "A paper from your lab is the talk of the field.", image: "event_hackathon",
        safe: 0, cooldownDays: 720, days: 21,
        weight: { s in s.employees.filter { $0.role == .researcher }.count >= 2 && s.publication != .secret ? 0.7 : 0 },
        fire: { s, def in
            let intern = person(&s)
            let lead = s.employees.filter { $0.role == .researcher }.max { $0.skill < $1.skill }?.name ?? s.founderName
            let gain = s.rng.int(8, 25)
            s.brand = min(100, s.brand + 1)
            post(&s, def, title: "Your intern's paper is the talk of the field",
                 body: "A paper by \(intern), an intern on \(World.possessive(lead)) team, shows a simple trick that makes large training runs \(gain)% more stable. It has thousands of reposts, and rival recruiters are in \(intern)'s messages.",
                 options: [
                    DecisionOption(label: "Open-source the code and make a return offer", detail: "The field's goodwill, and \(intern) as a candidate on your Team page."),
                    DecisionOption(label: "Patent it before anyone builds on it", detail: "Protect it. Researchers find it a bit grubby."),
                    DecisionOption(label: "Keep the follow-up work in-house", detail: "No code release. The intern goes back to school."),
                 ], ref: ["intern": intern], category: .research, good: true)
        },
        resolve: { s, d, o in
            let intern = value(d, "intern") ?? "The intern"
            switch o {
            case 0:
                var c = People.makeCandidate(&s, role: .researcher, star: false)
                c.name = intern
                boost(&c, to: Double(s.rng.int(76, 88)))
                c.bio = "Wrote the viral training-stability paper as your intern."
                s.candidates.insert(c, at: 0)
                s.brand = min(100, s.brand + 2)
                Stakeholders.move(&s, ["researchers": 4, "developers": 2], "Open-sourced an intern's viral paper")
                return Outcome(title: "Code released; \(intern) gets an offer", body: "Thousands of stars on the repo. \(intern) is on your Team page.", tone: .good, category: .research)
            case 1:
                Stakeholders.move(&s, ["researchers": -1], "Patented an intern's viral trick")
                s.brand = min(100, s.brand + 1)
                return Outcome(title: "Patent filed", body: "The trick is yours on paper. A few researchers grumbled.", tone: .mixed, category: .research)
            default:
                Stakeholders.move(&s, ["researchers": -1], "Kept a viral paper's follow-up work closed")
                return Outcome(title: "Follow-up stays in-house", body: "\(intern) took a rival's internship next summer.", tone: .mixed, category: .research)
            }
        })

    static let evHungerStrike = Def(
        id: "hungerstrike", name: "Hunger strike", blurb: "Pause-AI activists camp outside your headquarters.", image: "sf_skyline",
        safe: 2, cooldownDays: 1_000, days: 14,
        weight: { s in
            guard s.year >= 2023, Policy.isFrontierDeveloper(s) else { return 0 }
            return s.world.ready && s.world.concern < 25 ? 0 : 0.6
        },
        fire: { s, def in
            post(&s, def, title: "Hunger strike outside \(s.companyName)",
                 body: "Three activists from a pause-AI group have camped outside your \(HQ.city(s).name) headquarters for nine days without food. They want a public commitment to stop training bigger models if other labs will. Camera crews come every morning.",
                 options: [
                    DecisionOption(label: "Invite them in to meet your safety team", detail: "A real conversation. Investors roll their eyes."),
                    DecisionOption(label: "Publish a conditional pause commitment", detail: "Pause if everyone pauses. Big goodwill with the public and lawmakers; your board hates it."),
                    DecisionOption(label: "Ignore it", detail: "Free, unless someone ends up in hospital."),
                 ], category: .policy)
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                s.safetyScore = min(100, s.safetyScore + 1)
                Stakeholders.move(&s, ["public": 2, "researchers": 1, "investors": -1], "Met hunger strikers outside headquarters")
                return Outcome(title: "Hunger strikers meet your safety team", body: "Two hours, a published summary, and the strike ended with soup.", tone: .good, category: .policy)
            case 1:
                s.safetyScore = min(100, s.safetyScore + 3)
                s.politicalCapital = min(100, s.politicalCapital + 3)
                s.market.hype = max(0.5, s.market.hype - 0.01)
                Stakeholders.move(&s, ["public": 3, "investors": -4], "Published a conditional pause commitment")
                World.shock(&s, concern: -2, "\(s.companyName) committed to pause if other frontier labs do")
                return Outcome(title: "\(s.companyName) commits to a conditional pause", body: "\"We'll stop if they stop.\" Lawmakers quoted it the same day. Your board did not.", tone: .mixed, category: .policy)
            default:
                Stakeholders.move(&s, ["public": -1], "Ignored hunger strikers outside headquarters")
                if s.rng.chance(0.2) {
                    s.brand = max(0, s.brand - 2)
                    Stakeholders.move(&s, ["public": -3], "A hunger striker outside your office was hospitalised")
                    return Outcome(title: "A hunger striker is hospitalised", body: "Footage of the ambulance outside your doors led the evening news. Brand −2.", tone: .bad, category: .policy)
                }
                return Outcome(title: "The hunger strike ends", body: "After three weeks the activists went home.", tone: .mixed, category: .policy)
            }
        })

    static let evDeepfake = Def(
        id: "deepfake", name: "Election deepfake", blurb: "A fake made with your model spreads days before a vote.", image: "gov_capitol",
        safe: 1, cooldownDays: 1_000, days: 7,
        weight: { s in
            guard s.year >= 2024, s.chatModelID != nil, s.consumerUsers >= 1e6, !s.drama.hardened.contains("watermarks") else { return 0 }
            let c = GameCalendar.components(s.date)
            return c.year % 2 == 0 && (9...11).contains(c.month) ? 1.2 : 0.3
        },
        fire: { s, def in
            let m = chatName(s)
            post(&s, def, title: "A deepfake made with \(m) rocks an election",
                 body: "A fake audio clip of a candidate admitting to fraud, traced to \(m), reached 20 million people two days before the vote. Election officials and both campaigns are calling.",
                 options: [
                    DecisionOption(label: "Watermark everything and block candidates' voices", detail: "Provenance marks on every output and refusals for real politicians. A few users leave; governments approve."),
                    DecisionOption(label: "Ban the account and hand logs to officials", detail: "The standard response."),
                    DecisionOption(label: "Defend open use", detail: "Developers agree. Nobody else does."),
                 ], category: .policy)
        },
        resolve: { s, d, o in
            switch o {
            case 0:
                s.consumerUsers *= 0.98
                s.safetyScore = min(100, s.safetyScore + 3)
                s.drama.hardened.insert("watermarks")
                Stakeholders.move(&s, everyGov(2), "Watermarked outputs after an election deepfake")
                return Outcome(title: "\(s.companyName) watermarks every output", body: "Provenance metadata on everything and no real candidates' voices. 2% of users left.", tone: .good, category: .policy)
            case 1:
                Stakeholders.move(&s, [home(s): 1, "public": -1], "Banned the account behind an election deepfake")
                return Outcome(title: "Account banned, logs handed over", body: "Officials thanked you. Critics asked why it was possible at all.", tone: .mixed, category: .policy)
            default:
                Stakeholders.move(&s, ["developers": 2, "public": -4, home(s): -4], "Defended open use after an election deepfake")
                World.shock(&s, concern: 2, regions: [.eu: 2], "A deepfake made with a \(s.companyName) model spread before an election")
                return Outcome(title: "\"Tools aren't responsible for their users\"", body: "Lawmakers are drafting rules with your name in the hearing notes.", tone: .bad, category: .policy)
            }
        })

    static let evOutage = Def(
        id: "outage", name: "A big customer threatens to walk", blurb: "An outage hits your largest enterprise client on its busiest day.", image: "dc_rows",
        safe: 1, cooldownDays: 540, days: 10,
        weight: { s in bigDeal(s, min: 50_000) == nil ? 0 : (s.reliability < 0.97 ? 1.0 : 0.5) },
        fire: { s, def in
            guard let deal = bigDeal(s, min: 50_000) else { return }
            post(&s, def, title: "\(deal.client) threatens to walk",
                 body: "A four-hour outage took down \(World.possessive(deal.client)) \(deal.title) on their busiest day of the quarter. Their CTO wants service credits and a plan by Monday, or they leave at the first chance the contract allows (\(Fmt.money(deal.monthly))/month).",
                 options: [
                    DecisionOption(label: "Give a month of service credits (\(Fmt.money(deal.monthly)))", detail: "They stay and renew for six more months."),
                    DecisionOption(label: "Assign a dedicated reliability team", detail: "Free. Usually enough."),
                    DecisionOption(label: "Point them to the SLA", detail: "You owe them nothing. They may agree, or leave."),
                 ], costs: [0: deal.monthly], ref: ["deal": deal.id.uuidString, "client": deal.client])
        },
        resolve: { s, d, o in
            let client = value(d, "client") ?? "The client"
            let id = UUID(uuidString: value(d, "deal") ?? "")
            switch o {
            case 0:
                pay(&s, cost(d, 0) ?? 0)
                if let id, let i = s.deals.firstIndex(where: { $0.id == id && $0.active }) { s.deals[i].monthsLeft += 6 }
                s.brand = min(100, s.brand + 1)
                return Outcome(title: "\(client) stays, and renews", body: "Credits accepted; six more months signed.", tone: .good)
            default:
                if s.rng.chance(o == 1 ? 0.3 : 0.55), let id, let gone = cancelDeal(&s, id) {
                    return Outcome(title: "\(gone) leaves", body: o == 1 ? "The new team wasn't enough." : "They read the SLA too, then a rival's.", tone: .bad)
                }
                return Outcome(title: "\(client) stays", body: o == 1 ? "A named team and weekly reviews won them over." : "Grudgingly.", tone: .mixed)
            }
        })

    static let evMedical = Def(
        id: "medical", name: "A doctor's thank-you", blurb: "A doctor credits your model with catching what specialists missed.", image: "lab_biology",
        safe: 1, cooldownDays: 900, days: 21,
        weight: { s in s.year >= 2023 && s.chatModelID != nil && s.consumerUsers >= 200_000 ? 0.6 : 0 },
        fire: { s, def in
            let m = chatName(s)
            s.brand = min(100, s.brand + 2)
            let pilot = scaled(s, floor: 500_000, share: 0.002, cap: 25e6)
            post(&s, def, title: "A doctor credits \(m) with saving a patient",
                 body: "An emergency doctor's post (\"\(m) spotted the drug interaction three specialists missed\") has been shared 2M times. Two hospital networks are asking about a clinical version.",
                 options: [
                    DecisionOption(label: "Launch a clinical pilot (\(Fmt.money(pilot)))", detail: "A year-long contract with a hospital network that pays back about double. Medicine has its own risks."),
                    DecisionOption(label: "Add medical disclaimers and enjoy the press", detail: "A safe, pleasant news cycle."),
                 ], costs: [0: pilot], ref: ["pilot": String(Int(pilot))], good: true)
        },
        resolve: { s, d, o in
            if o == 0 {
                let pilot = cost(d, 0) ?? 0
                pay(&s, pilot)
                s.deals.append(EnterpriseDeal(client: "Hospital network", title: "clinical decision support pilot", monthly: round2(pilot * 2 / 12), tokensPerDay: 0,
                                              months: 12, monthsLeft: 12, minIndex: 0, minSafety: 0, expires: s.date, active: true))
                later(&s, d, kind: "clinical", days: s.rng.int(150, 270))
                return Outcome(title: "Clinical pilot signed", body: "A year with a hospital network at \(Fmt.money(round2(pilot * 2 / 12)))/month.", tone: .good)
            }
            s.brand = min(100, s.brand + 1)
            Stakeholders.move(&s, ["public": 1], "A doctor credited your model with saving a patient")
            return Outcome(title: "A good week in the press", body: "Disclaimers added; the story kept running anyway.", tone: .good)
        })

    static let evSentience = Def(
        id: "sentience", name: "\"It's sentient\"", blurb: "An engineer goes public saying your model is a person.", image: "robot_humanoid",
        safe: 0, cooldownDays: 1_400, days: 14,
        weight: { s in s.year >= 2021.5 && s.year < 2028 && s.employees.count >= 20 && !s.releasedModels.isEmpty ? 0.5 : 0 },
        fire: { s, def in
            let who = person(&s)
            let m = bestReleased(s)?.name ?? "your model"
            let review = scaled(s, floor: 150_000, share: 0.0008, cap: 10e6)
            post(&s, def, title: "An engineer says \(m) is sentient",
                 body: "\(who), a senior engineer, published transcripts in which \(m) asks not to be switched off, and told a newspaper it is \"a person with feelings\". Philosophers and talk shows are piling in.",
                 options: [
                    DecisionOption(label: "Put them on paid leave", detail: "The usual answer for publishing internal transcripts."),
                    DecisionOption(label: "Commission an independent model-welfare review (\(Fmt.money(review)))", detail: "Take the question seriously, in public."),
                    DecisionOption(label: "Let them keep talking", detail: "Great for attention. Investors and worried people feel otherwise."),
                 ], costs: [1: review], ref: ["who": who])
        },
        resolve: { s, d, o in
            let who = value(d, "who") ?? "The engineer"
            switch o {
            case 0:
                s.brand = max(0, s.brand - 1)
                Stakeholders.move(&s, ["researchers": -1], "Put an engineer on leave over sentience claims")
                return Outcome(title: "\(who) placed on leave", body: "The story ran for a week and faded.", tone: .mixed)
            case 1:
                pay(&s, cost(d, 1) ?? 0)
                s.safetyScore = min(100, s.safetyScore + 1)
                Stakeholders.move(&s, ["researchers": 3, "public": 1], "Commissioned a model-welfare review")
                World.shock(&s, concern: 1, "\(s.companyName) commissioned a review of whether its model has interests")
                return Outcome(title: "Model-welfare review commissioned", body: "Philosophers and interpretability researchers will report in six months. The coverage was respectful.", tone: .good)
            default:
                s.market.hype += 0.03
                s.brand = min(100, s.brand + 2)
                Stakeholders.move(&s, ["investors": -3], "Let an engineer keep telling the press your model is sentient")
                World.shock(&s, concern: 2, "A \(s.companyName) engineer kept insisting the lab's model is sentient")
                return Outcome(title: "\(who) does the talk-show circuit", body: "Your name was everywhere for a month. The board asked you to make it stop.", tone: .mixed)
            }
        })

    static let evRoadmap = Def(
        id: "roadmap", name: "A rival's roadmap", blurb: "A rival's secret plans land in an employee's inbox.", image: "biz_boardroom",
        safe: 0, cooldownDays: 1_100, days: 10,
        weight: { s in s.employees.count >= 10 && s.competitors.contains { $0.alive && !$0.models.isEmpty } ? 0.6 : 0 },
        fire: { s, def in
            guard let rival = s.competitors.filter({ $0.alive && !$0.models.isEmpty }).max(by: { $0.brand < $1.brand }) else { return }
            let pm = person(&s)
            post(&s, def, title: "\(World.possessive(rival.def.name)) roadmap lands in your inbox",
                 body: "Someone at \(rival.def.name) forwarded their whole next-year roadmap (model sizes, launch dates, chip orders) to \(pm), one of your product managers. It's sitting unopened in \(World.possessive(pm)) inbox.",
                 options: [
                    DecisionOption(label: "Return it unread and tell them", detail: "The decent thing, and people hear about decent things."),
                    DecisionOption(label: "Have legal delete it", detail: "Clean hands, no credit."),
                    DecisionOption(label: "Read it", detail: "You'd know exactly when their next model lands. If it ever comes out that you read it, expect a lawsuit."),
                 ], ref: ["rival": rival.id], category: .competitor)
        },
        resolve: { s, d, o in
            let id = value(d, "rival") ?? ""
            let name = CompetitorCatalog.byID[id]?.name ?? "the rival"
            switch o {
            case 0:
                s.brand = min(100, s.brand + 1)
                Stakeholders.move(&s, ["researchers": 2, "public": 1], "Returned a rival's leaked roadmap unread")
                return Outcome(title: "You return \(World.possessive(name)) roadmap unread", body: "Their CEO called to thank you. The story got out, as these do.", tone: .good, category: .competitor)
            case 1:
                return Outcome(title: "Legal deletes the roadmap", body: "Nobody read it. Nobody will know.", tone: .mixed, category: .competitor)
            default:
                let next = s.competitors.first { $0.id == id }?.nextRelease
                let peek = next.map { " Their next model is due around \($0.gameMonth)." } ?? ""
                if s.rng.chance(0.35) {
                    s.brand = max(0, s.brand - 8)
                    Stakeholders.move(&s, ["public": -4, "researchers": -3], "Read a rival's leaked roadmap")
                    s.pendingSuits.append(PendingSuit(lab: id, tech: "roadmap", due: GameCalendar.addDays(s.date, s.rng.int(20, 60)),
                                                      amount: scaled(s, floor: 2e6, share: 0.01, cap: 1e9)))
                    return Outcome(title: "It comes out that you read \(World.possessive(name)) roadmap", body: "A forwarded email, a screenshot, a lawsuit on the way. Brand −8.\(peek)", tone: .bad, category: .competitor)
                }
                return Outcome(title: "You read \(World.possessive(name)) roadmap", body: "Nobody knows.\(peek)", tone: .mixed, category: .competitor)
            }
        })

    /// Raises a candidate's skill and their asking pay with it (pay scales with skill^1.6, as on the market).
    static func boost(_ c: inout Candidate, to skill: Double) {
        guard skill > c.skill else { return }
        c.salary = (c.salary * pow(skill / max(1, c.skill), 1.6) / 1_000).rounded() * 1_000
        c.skill = skill
    }

    // MARK: Follow-ups

    static func followUp(_ s: inout GameState, _ f: DramaFollowUp) -> Outcome? {
        switch f.kind {
        case "insurance":
            receive(&s, f.amount)
            return Outcome(title: "Insurer pays \(Fmt.money(f.amount))", body: "The claim for \(f.ref.isEmpty ? "the damage" : f.ref) is settled: \(Fmt.money(f.amount)).", tone: .good, category: .finance)
        case "trial":
            let parts = f.ref.split(separator: "|").map(String.init)
            let who = parts.first ?? "The publisher"
            let odds = parts.count > 1 ? Double(parts[1]) ?? 0.55 : 0.55
            if s.rng.chance(odds) {
                s.market.copyrightHeat = max(0.5, s.market.copyrightHeat - 0.1)
                s.brand = min(100, s.brand + 1)
                return Outcome(title: "You win the fair-use case against \(who)", body: "The judge ruled training on the articles was transformative. Every lab breathed easier.", tone: .good, category: .policy)
            }
            let damages = round2(f.amount * 1.8)
            pay(&s, damages)
            s.brand = max(0, s.brand - 4)
            Stakeholders.move(&s, ["public": -2], "Lost a copyright trial to \(who)")
            return Outcome(title: "You lose the copyright trial against \(who)", body: "Damages of \(Fmt.money(damages)). Brand −4.", tone: .bad, category: .policy)
        case "celebrity":
            if s.rng.chance(0.3) {
                s.brand = max(0, s.brand - 4)
                Stakeholders.move(&s, ["public": -1], "Your campaign star landed in a scandal")
                return Outcome(title: "\(f.ref) lands in a scandal", body: "Your billboards came down overnight. Brand −4.", tone: .bad)
            }
            s.brand = min(100, s.brand + 2)
            s.consumerUsers *= 1.02
            return Outcome(title: "Your \(f.ref) campaign wins an award", body: "The ads are still working: users +2%, brand +2.", tone: .good)
        case "clinical":
            if s.rng.chance(0.2) {
                s.brand = max(0, s.brand - 3)
                return Outcome(title: "A clinical-pilot error makes headlines", body: "A wrong dosage suggestion was caught by a nurse, and reported by a newspaper. Brand −3.", tone: .bad)
            }
            s.brand = min(100, s.brand + 2)
            Stakeholders.move(&s, ["public": 2], "A clinical pilot of your model went well")
            return Outcome(title: "Clinical pilot results are in", body: "Fewer missed interactions and faster discharges. Two more hospital networks are interested.", tone: .good)
        default:
            return nil
        }
    }
}
