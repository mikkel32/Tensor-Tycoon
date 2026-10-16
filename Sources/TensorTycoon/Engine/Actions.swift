import Foundation

/// Player actions. Each returns an error message, or nil on success.
extension GameState {
    // MARK: Hardware

    mutating func buyHardware(_ accelID: String, count: Int, siteID: UUID) -> String? {
        guard let a = HardwareCatalog.get(accelID), count > 0 else { return "Unknown hardware." }
        guard Economy.canBuy(a, self), let unit = Economy.price(a, self) else { return "\(a.name) isn't for sale right now." }
        if let why = Partners.blocker(a, self) { return why }
        guard let site = sites.first(where: { $0.id == siteID }) else { return "Pick a site." }
        if a.tdpW > site.maxChipTDP { return "\(site.name) can't power or cool \(Int(a.tdpW)) W parts. Use a colocation cage or datacenter." }
        if a.liquid && !site.cooling.supportsLiquidChips { return "\(a.name) needs liquid cooling. \(site.name) is air-cooled." }
        if a.minOrder > 1 && count % a.minOrder != 0 { return "\(a.name) ships in racks of \(a.minOrder). Order a multiple of \(a.minOrder)." }
        let limit = Economy.allocationLimit(a, self)
        if count > limit { return "\(a.vendor.rawValue) will only allocate \(Fmt.int(limit)) units to a company your size right now. A supply agreement raises this." }
        let needKW = Economy.chipKW(a) * Double(count)
        let freeKW = site.capacityKW - Economy.siteLoadKW(self, siteID)
        if needKW > freeKW + 0.01 { return "Not enough power at \(site.name): needs \(Fmt.watts(needKW * 1000)), \(Fmt.watts(max(0, freeKW) * 1000)) free." }
        let total = unit * Double(count)
        if total > cash { return "That costs \(Fmt.money(total)); you have \(Fmt.money(cash))." }
        cash -= total
        month.capex += total
        if let di = supplyDeals.firstIndex(where: { $0.vendor == a.vendor.rawValue }) { supplyDeals[di].spentThisYear += total }
        Partners.recordSpend(&self, accel: a, amount: total, purchase: true)
        if a.cls == .tpu { Achievements.unlock(&self, "tpu_owner") }
        let days = Economy.leadTimeDays(a, self)
        orders.append(HardwareOrder(accelID: accelID, count: count, siteID: siteID, unitCost: unit, ordered: date,
                                    arrives: GameCalendar.addDays(date, days)))
        Sim.news(&self, "Ordered \(Fmt.int(count))× \(a.name)", "\(Fmt.money(total)) paid. Delivery in about \(days) days to \(site.name).", .company, image: a.image)
        return nil
    }

    mutating func sellHardware(batchID: UUID, count: Int) -> String? {
        guard let i = owned.firstIndex(where: { $0.id == batchID }), let a = HardwareCatalog.get(owned[i].accelID) else { return "Not found." }
        let n = min(count, owned[i].count)
        let free = Economy.pool(self, a.id)?.free ?? 0
        if n > free { return "Only \(free) of these chips are unallocated. Free some up first." }
        let unit = Economy.resaleValue(a, self, unitCost: owned[i].unitCost, purchased: owned[i].purchased)
        cash += unit * Double(n)
        owned[i].count -= n
        owned.removeAll { $0.count <= 0 }
        Sim.news(&self, "Sold \(n)× \(a.name)", "Raised \(Fmt.money(unit * Double(n))) on the secondary market.", .company)
        return nil
    }

    mutating func rentHardware(_ accelID: String, count: Int, term: RentalTerm) -> String? {
        guard let a = HardwareCatalog.get(accelID), count > 0 else { return "Unknown hardware." }
        guard Economy.canRent(a, self), let rate = Economy.rent(a, self) else { return "\(a.name) isn't rentable right now." }
        if let why = Partners.blocker(a, self) { return why }
        let limit = Economy.rentalLimit(a, self)
        let existing = rentals.filter { $0.accelID == accelID }.reduce(0) { $0 + $1.count }
        if existing + count > limit { return "\(a.cloudProvider) caps you at \(Fmt.int(limit)) \(a.name) for now. Grow your valuation to unlock more." }
        let hourly = rate * term.discount
        let firstDay = hourly * 24 * Double(count)
        if firstDay > cash + cloudCredits { return "You can't afford even a day of this (\(Fmt.money(firstDay)))." }
        let end = term.months.map { GameCalendar.addMonths(date, $0) }
        rentals.append(Rental(accelID: accelID, count: count, hourly: hourly, term: term, start: date, end: end))
        Sim.news(&self, "Rented \(Fmt.int(count))× \(a.name)", "\(term.rawValue) at \(Fmt.price(hourly))/chip-hour (\(Fmt.money(hourly * 24 * 30.4 * Double(count)))/month).",
                 .company, image: a.image)
        return nil
    }

    mutating func cancelRental(_ id: UUID) -> String? {
        guard let i = rentals.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let r = rentals[i]
        let pool = Economy.pool(self, r.accelID)
        if (pool?.free ?? 0) < r.count { return "Free up \(r.count - (pool?.free ?? 0)) of these chips first." }
        if let end = r.end {
            let months = max(0, Double(GameCalendar.daysBetween(date, end)) / 30.4)
            let penalty = r.hourly * 24 * 30.4 * Double(r.count) * months * 0.5
            if penalty > cash { return "Breaking this reservation costs \(Fmt.money(penalty))." }
            cash -= penalty
            month.costRent += penalty
        }
        rentals.remove(at: i)
        return nil
    }

    // MARK: Sites

    mutating func buildSite(kind: SiteKind, locationID: String, capacityKW: Double, cooling: Cooling, power: PowerDeal, name: String) -> String? {
        guard let loc = LocationCatalog.byID[locationID] else { return "Pick a location." }
        let b = bonuses
        if cooling == .immersion && !b.has(.immersion) { return "Research Immersion Cooling first." }
        if power == .nuclear && year < PowerDeal.nuclear.availableFrom { return "Nuclear PPAs aren't available yet." }
        switch kind {
        case .garage, .office:
            return "You already have that."
        case .colo:
            let setup = loc.coloFee * capacityKW * (cooling == .air ? 1 : 1.35)
            if setup > cash { return "The first month's fee of \(Fmt.money(setup)) is more than your cash." }
            cash -= setup
            let ready = GameCalendar.addDays(date, 30)
            sites.append(Site(name: name, kind: .colo, locationID: locationID, capacityKW: capacityKW, cooling: cooling, powerDeal: power,
                              opened: date, ready: ready, capex: 0, monthlyFee: setup))
            Sim.news(&self, "Signed colocation lease: \(name)", "\(Fmt.watts(capacityKW * 1000)) in \(loc.name), ready in 30 days. \(Fmt.money(setup))/month.",
                     .company, image: loc.image)
        case .datacenter:
            let mw = capacityKW / 1000
            let capex = mw * cooling.capexPerMW * (year > 2024 ? 1.15 : 1)
            if capex > cash { return "Building this costs \(Fmt.money(capex)); you have \(Fmt.money(cash))." }
            if mw > loc.gridCapMW { return "\(loc.name)'s grid can only supply \(Int(loc.gridCapMW)) MW to one site." }
            let months = buildMonths(mw: mw, loc: loc, power: power)
            cash -= capex
            month.capex += capex
            let ready = GameCalendar.addDays(date, Int(months * 30.4))
            sites.append(Site(name: name, kind: .datacenter, locationID: locationID, capacityKW: capacityKW, cooling: cooling, powerDeal: power,
                              opened: date, ready: ready, capex: capex, monthlyFee: 0))
            Sim.news(&self, "Breaking ground: \(name)", "\(Fmt.trim(mw, 1)) MW \(cooling.rawValue.lowercased())-cooled campus in \(loc.name). \(Fmt.money(capex)), online \(ready.gameMonth).",
                     .company, image: "dc_construction", important: true)
        }
        return nil
    }

    func buildMonths(mw: Double, loc: Location, power: PowerDeal) -> Double {
        var m = (7 + min(22, mw * 0.025)) / loc.buildSpeed * market.buildDelay * Policy.buildFactor(self)
        if power == .gas { m *= 0.7 }
        return m
    }

    mutating func expandSite(_ id: UUID, addKW: Double) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let site = sites[i]
        if site.expanding > 0 { return "An expansion is already under way." }
        switch site.kind {
        case .garage, .office:
            return "Upgrade your office from the Team page instead."
        case .colo:
            let fee = site.location.coloFee * addKW * (site.cooling == .air ? 1 : 1.35)
            sites[i].capacityKW += addKW
            sites[i].monthlyFee += fee
        case .datacenter:
            let mw = addKW / 1000
            if (site.capacityKW + addKW) / 1000 > site.location.gridCapMW { return "The local grid can't supply that much." }
            let capex = mw * site.cooling.capexPerMW * (year > 2024 ? 1.15 : 1)
            if capex > cash { return "This expansion costs \(Fmt.money(capex))." }
            cash -= capex
            month.capex += capex
            sites[i].capex += capex
            sites[i].expanding = addKW
            sites[i].expansionReady = GameCalendar.addDays(date, Int(buildMonths(mw: mw, loc: site.location, power: site.powerDeal) * 0.7 * 30.4))
        }
        return nil
    }

    mutating func setPowerDeal(_ id: UUID, _ deal: PowerDeal) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if year < deal.availableFrom { return "Not available yet." }
        if sites[i].kind == .garage || sites[i].kind == .office { return "Your landlord picks the power for you." }
        sites[i].powerDeal = deal
        if deal == .nuclear || deal == .solar || deal == .wind { brand = min(100, brand + 1) }
        return nil
    }

    // MARK: Training

    mutating func startTraining(_ d: ModelDesign, lr: LRSchedule = .standard, checkpointEvery: Double = 0.1, autoRollback: Bool = false) -> String? {
        guard let a = HardwareCatalog.get(d.accelID) else { return "Pick hardware." }
        let b = bonuses
        if d.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Name your model." }
        if d.chips <= 0 { return "Allocate some chips." }
        let free = Economy.freeChips(self, d.accelID)
        if d.chips > free { return "Only \(free) free \(a.name) chips. Buy, rent, or free some up." }
        if d.precision == .fp8 && !b.has(.fp8Training) { return "Research FP8 Training first." }
        if d.precision == .fp4 && !b.has(.fp4Training) { return "Research FP4 Training first." }
        if !a.supportsTraining(d.precision) { return "\(a.name) has no \(d.precision.short) tensor cores." }
        if d.isMoE && !b.has(.moe) { return "Research Mixture-of-Experts first." }
        if d.reasoning && !b.has(.reasoning) { return "Research RL for Reasoning first." }
        if d.rlhf && !b.has(.rlhf) { return "Research RLHF first." }
        if d.instruct && !b.has(.chat) { return "Research Instruction Tuning first (or train a base model)." }
        if d.vision && !b.has(.vision) { return "Research Vision-Language Models first." }
        if d.audio && !b.has(.audio) { return "Research Speech-to-Speech first." }
        if d.video && !b.has(.video) { return "Research Video Generation first." }
        if d.toolUse && !b.has(.toolUse) { return "Research Tool Use first." }
        if d.contextK >= 1000 && !b.has(.context1m) { return "Research 1M Context first." }
        if d.contextK >= 128 && !b.has(.context128k) { return "Research 128K Context first." }
        if d.contextK >= 32 && !b.has(.context32k) { return "Research RoPE & Context Extension first." }
        if d.mode == .distill && !b.has(.distillation) { return "Research Knowledge Distillation first." }
        if d.mode != .scratch && d.baseModelRef == nil { return "Pick a base model." }
        let mem = Physics.trainingMemory(d, accel: a, bonuses: b)
        if !mem.ok { return "Out of memory: needs \(Fmt.memory(mem.needGB)), you have \(Fmt.memory(mem.haveGB)). \(mem.note)" }
        if d.optimizer == .muon && !b.has(.muon) { return "Research the Muon optimizer first." }
        if d.optimizer == .shampoo && !b.has(.shampoo) { return "Research second-order preconditioning first." }
        if d.attention == .gqa && !b.has(.gqa) { return "Research grouped-query attention first." }
        if d.attention == .mla && !b.has(.mla) { return "Research multi-head latent attention first." }
        if d.mixer == .hybrid && !b.has(.ssmHybrid) { return "Research hybrid SSM architectures first." }
        if d.mixer == .diffusion && !b.has(.diffusionLM) { return "Diffusion LMs need your lab's unique breakthrough." }
        if d.mixer == .alien && alienArchs.isEmpty { return "Your agents haven't found an alien architecture yet (Agent Swarms → alien architecture search)." }
        if d.mtp && !b.has(.mtp) { return "Research multi-token prediction first." }
        if d.schedule == .wsd && !b.has(.wsd) { return "Research WSD schedules first." }
        if d.isMoE && d.activeFraction < 0.05 && !b.has(.fineMoE) { return "Research fine-grained experts for sparsity beyond 1/16." }
        if d.reasoning && d.effectiveRL == .extreme && !b.has(.extremeRL) { return "Research RL scaling infrastructure for extreme RL." }
        if d.agentRL && !b.has(.agents) { return "Research agentic RL first." }
        if d.syntheticShare > 0 && !b.has(.syntheticData) { return "Research synthetic data pipelines first." }
        let pre = Physics.pretrainFLOPs(d)
        var run = TrainingRun(design: d, started: date, flopsTotal: pre, dataSnapshot: Array(dataSources))
        run.lr = lr.rawValue
        run.checkpointEvery = checkpointEvery
        run.autoRollback = autoRollback
        Training.prepare(&run, state: &self)
        runs.append(run)
        // Compute-threshold regulation (real thresholds: US EO 14110 10^26, EU AI Act 10^25)
        if pre >= 1e26 && year >= 2023.83 && year < 2025.06 {
            cash -= 1_500_000
            month.costOther += 1_500_000
            Sim.news(&self, "Training run reported to the US government", "Runs above 10^26 FLOPs must be reported under the October 2023 executive order. Compliance cost: $1.5M.",
                     .policy, important: false)
        }
        if pre >= 1e26 && lawsPassed.contains("transparency") {
            cash -= 2_000_000
            month.costOther += 2_000_000
        }
        if pre >= 1e27 && lawsPassed.contains("compute_licensing") {
            cash -= 25_000_000
            month.costOther += 25_000_000
            Sim.news(&self, "Federal compute licence granted for \(d.name)", "Runs above 10^27 FLOP need a licence: $25M.", .policy)
        }
        if pre >= 1e25 && market.euAIAct && !researched.contains("evals_rsp") {
            Sim.news(&self, "EU flags \(d.name) as a systemic-risk model", "Above 10^25 FLOPs the EU AI Act requires model evaluations. Research Dangerous-Capability Evals before release or expect fines.",
                     .policy, important: true, good: false)
        }
        Sim.news(&self, "Training started: \(d.name)", "\(Fmt.params(d.paramsB)) params on \(Fmt.tokens(d.tokensT)) tokens using \(Fmt.int(d.chips))× \(a.name). \(Fmt.flops(pre)) FLOPs.",
                 .company, image: a.image)
        return nil
    }

    mutating func setRunStatus(_ id: UUID, _ status: RunStatus) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if status == .running && runs[i].status == .paused {
            let free = Economy.freeChips(self, runs[i].design.accelID)
            if free < runs[i].design.chips { return "Need \(runs[i].design.chips) free chips, have \(free)." }
            runs[i].status = runs[i].flopsDone >= runs[i].flopsTotal ? .postTraining : .running
            runs[i].note = "Resumed \(date.gameShort)."
            return nil
        }
        runs[i].status = status
        if status == .cancelled { runs[i].note = "Cancelled \(date.gameShort)." }
        return nil
    }

    mutating func resizeRun(_ id: UUID, chips: Int) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let current = runs[i].design.chips
        let active = runs[i].status == .running || runs[i].status == .postTraining
        let free = Economy.freeChips(self, runs[i].design.accelID) + (active ? current : 0)
        if chips > free { return "Only \(free) chips available." }
        if chips < 1 { return "A run needs at least one chip." }
        if let a = HardwareCatalog.get(runs[i].design.accelID) {
            var d = runs[i].design
            d.chips = chips
            if !Physics.trainingMemory(d, accel: a, bonuses: bonuses).ok { return "The model no longer fits in memory on \(chips) chips." }
        }
        runs[i].design.chips = chips
        return nil
    }

    /// A scaling ladder: several small proxy runs (~2% of the target compute) that validate a recipe.
    mutating func startLadder(_ d: ModelDesign) -> String? {
        let b = bonuses
        guard b.has(.proxyLadder) else { return "Research Predictable Scaling to run scaling ladders." }
        guard let a = HardwareCatalog.get(d.accelID) else { return "Pick hardware." }
        let free = Economy.freeChips(self, d.accelID)
        if d.chips > free { return "Only \(free) free \(a.name) chips." }
        let target = Physics.pretrainFLOPs(d)
        var ladder = d
        ladder.name = "\(d.name) ladder"
        var run = TrainingRun(design: ladder, started: date, flopsTotal: max(1e17, target * 0.02), dataSnapshot: Array(dataSources))
        run.kind = .proxy
        run.proxyCompute = target
        run.checkpointEvery = 1
        run.stages = [RunStage(name: "Proxy runs", flops: run.flopsTotal, isPre: true)]
        Training.runLogDirect(&run, date, "Five proxy runs from \(Fmt.flops(run.flopsTotal / 300)) to \(Fmt.flops(run.flopsTotal)) FLOPs.")
        runs.append(run)
        Sim.news(&self, "Scaling ladder started: \(d.name)", "Small proxy runs will fit the scaling curve for this recipe before you commit \(Fmt.flops(target)) FLOPs.", .research, image: "wafer_closeup")
        return nil
    }

    // MARK: Models & products

    static func keynoteCost(_ s: GameState) -> Double { clamp(s.valuation * 0.0005, 200_000, 50_000_000) }

    mutating func release(_ id: UUID, api: Bool, openWeights: Bool, launch: LaunchStyle = .standard) -> String? {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if !models[i].released {
            if launch == .keynote && GameState.keynoteCost(self) > cash { return "A keynote costs \(Fmt.money(GameState.keynoteCost(self)))." }
            models[i].released = true
            models[i].releaseDate = date
            var gain = max(1, 6 + 4 * (models[i].c - Macro.frontier(year)))
            switch launch {
            case .standard: break
            case .keynote:
                let cost = GameState.keynoteCost(self)
                cash -= cost
                month.costMarketing += cost
                gain *= 1.6
                market.hype += 0.02
            case .blitz:
                let rank = Leaderboard.rank(of: id, in: self)
                gain += rank == 1 ? 8 : (rank <= 3 ? 2 : -7)
            case .staged:
                gain *= 0.5
                models[i].safety = min(100, models[i].safety + 4)
                safetyScore = min(100, safetyScore + 2)
            }
            brand = clamp(brand + gain, 0, 100)
            let rank = Leaderboard.rank(of: id, in: self)
            Sim.news(&self, "\(companyName) releases \(models[i].name)", "Intelligence Index \(Fmt.score(models[i].index)) — #\(rank) on the leaderboard.",
                     .company, image: "sf_skyline", important: true, good: true)
            SafetyFramework.onRelease(&self, i)
        }
        models[i].api = api
        if openWeights && !models[i].openWeights {
            models[i].openWeights = true
            let gain = 8 * (1 + traits.openBrand)
            brand = min(100, brand + gain)
            Sim.news(&self, "\(models[i].name) weights released", "Developers worldwide are downloading your model. Brand +\(Int(gain)), but rivals can build on it too.", .company, good: true)
        }
        return nil
    }

    mutating func deploy(_ id: UUID, accelID: String, chips: Int) -> String? {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let current = models[i].deployments.first { $0.accelID == accelID }?.chips ?? 0
        let free = Economy.freeChips(self, accelID) + current
        if chips > free { return "Only \(free) chips available." }
        models[i].deployments.removeAll { $0.accelID == accelID }
        if chips > 0 { models[i].deployments.append(Deployment(accelID: accelID, chips: chips)) }
        return nil
    }

    mutating func setServingPrecision(_ id: UUID, _ p: Precision) {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return }
        models[i].servingPrecision = p
    }

    mutating func setAPIPrice(_ id: UUID, _ price: Double) {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return }
        models[i].apiPrice = max(0.001, price)
        models[i].autoPrice = false
    }

    mutating func retire(_ id: UUID) {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return }
        models[i].retired = true
        models[i].deployments = []
        if chatModelID == id { chatModelID = nil }
        for d in deals.indices where deals[d].modelID == id { deals[d].modelID = nil }
    }

    // MARK: Enterprise

    mutating func acceptDeal(_ id: UUID, modelID: UUID) -> String? {
        guard let i = deals.firstIndex(where: { $0.id == id }), let m = models.first(where: { $0.id == modelID }) else { return "Not found." }
        if m.index + 0.01 < deals[i].minIndex { return "\(deals[i].client) needs an Intelligence Index of \(Fmt.score(deals[i].minIndex))." }
        if safetyScore < deals[i].minSafety { return "\(deals[i].client) requires a safety score of \(Int(deals[i].minSafety))." }
        deals[i].active = true
        deals[i].modelID = modelID
        Sim.news(&self, "Signed: \(deals[i].client)", "\(Fmt.money(deals[i].monthly))/month for \(deals[i].months) months. Make sure \(m.name) has capacity.", .company, good: true)
        return nil
    }

    mutating func declineDeal(_ id: UUID) { deals.removeAll { $0.id == id } }

    // MARK: Research & data

    mutating func queueResearch(_ id: String) {
        guard !researched.contains(id), !researchQueue.contains(id), let item = ResearchCatalog.byID[id] else { return }
        if item.isExotic && !exoticOwned.contains(id) { return }
        if id.hasPrefix("xeno_") && alienArchs.isEmpty { return }
        researchQueue.append(id)
    }

    /// Techniques a rival lab is known to be working on that you could still hire your way into.
    func headhuntTargets(_ lab: String) -> [String] {
        (rivalTech[lab] ?? []).filter { id in
            !exoticOwned.contains(id) && !researched.contains(id) && (ResearchCatalog.byID[id]?.year ?? 3000) <= year + 1
        }
    }

    var headhuntFee: Double { (Macro.salary(.researcher, year) * 4 / 100_000).rounded() * 100_000 }

    func headhuntChance(_ lab: String) -> Double {
        let policy = publication == .open ? 0.1 : publication == .secret ? -0.1 : 0
        let rivalBrand = competitors.first { $0.id == lab }?.brand ?? 50
        return clamp(0.3 + brand / 250 + policy - (rivalBrand - 50) / 400, 0.1, 0.75)
    }

    var headhuntReadyOn: Date? {
        guard let last = lastHeadhunt else { return nil }
        let ready = GameCalendar.addDays(last, 120)
        return ready > date ? ready : nil
    }

    /// Recruit a senior researcher out of a rival to learn one of its secret techniques.
    mutating func headhunt(_ lab: String) -> String? {
        guard let comp = CompetitorCatalog.byID[lab] else { return "Unknown lab." }
        guard let tech = headhuntTargets(lab).first, let item = ResearchCatalog.byID[tech] else { return "\(comp.name) has nothing you can hire your way into yet." }
        if let ready = headhuntReadyOn { return "Your recruiters are still burned from the last attempt — try again after \(ready.gameShort)." }
        if employees.count >= Economy.officeCapacity(self) { return "Your office is full. Upgrade it on the Team page." }
        let fee = headhuntFee
        if fee > cash { return "A credible offer needs \(Fmt.money(fee)) up front." }
        cash -= fee
        month.costPayroll += fee
        lastHeadhunt = date
        if rng.chance(headhuntChance(lab)) {
            exoticOwned.append(tech)
            let salary = (Macro.salary(.researcher, year) * 2.2 / 1000).rounded() * 1000
            employees.append(Employee(name: "\(rng.pick(NameBank.first)) \(rng.pick(NameBank.last))", role: .researcher, skill: 84,
                                      salary: salary, morale: 85, hired: date, star: true, equity: 0.2))
            Sim.news(&self, "You poached a \(comp.name) researcher", "They know how \(item.name) works. It's now in your research tree.", .research, important: true, good: true)
            if rng.chance(0.15) {
                cash -= fee
                brand = max(0, brand - 2)
                Sim.news(&self, "\(comp.name) sues over trade secrets", "The lawsuit settles for \(Fmt.money(fee)). Talent wars are getting ugly.", .company, good: false)
            }
        } else {
            Sim.news(&self, "\(comp.name) counter-offered", "Their researcher stayed after a retention package. Your recruiting fee is gone.", .company, good: false)
            if rng.chance(0.3) {
                cash -= fee * 0.5
                brand = max(0, brand - 2)
                Sim.news(&self, "\(comp.name) accuses you of poaching", "A cease-and-desist and an awkward news cycle cost \(Fmt.money(fee * 0.5)) in legal fees.", .company, good: false)
            }
        }
        return nil
    }

    mutating func toggleData(_ id: String) -> String? {
        guard let src = DataCatalog.byID[id] else { return "Unknown." }
        if dataSources.contains(id) {
            dataSources.remove(id)
            return nil
        }
        if year < src.available { return "Not available until \(Int(src.available))." }
        if src.upfront > cash { return "Costs \(Fmt.money(src.upfront)) upfront." }
        cash -= src.upfront
        month.costData += src.upfront
        dataSources.insert(id)
        return nil
    }

    // MARK: People

    mutating func hire(_ candidateID: UUID) -> String? {
        guard let i = candidates.firstIndex(where: { $0.id == candidateID }) else { return "Not found." }
        if employees.count >= Economy.officeCapacity(self) { return "Your office is full. Upgrade it on the Team page." }
        let c = candidates[i]
        let bonus = c.salary * 0.15
        if bonus > cash { return "You can't afford the signing bonus (\(Fmt.money(bonus)))." }
        cash -= bonus
        month.costPayroll += bonus
        if c.equity > 0 {
            let shares = totalShares * c.equity / 100
            employeePoolShares += shares
        }
        var e = Employee(name: c.name, role: c.role, skill: c.skill, salary: c.salary, morale: 80, hired: date, star: c.star, equity: c.equity)
        e.trait = c.trait
        employees.append(e)
        candidates.remove(at: i)
        return nil
    }

    mutating func fire(_ id: UUID) {
        guard let e = employees.first(where: { $0.id == id }) else { return }
        cash -= e.salary * 0.25
        month.costPayroll += e.salary * 0.25
        employees.removeAll { $0.id == id }
        for i in employees.indices { employees[i].morale -= 2 }
    }

    /// Veterans (a year in, skill 65+) can be promoted into a trait of your choice.
    func canPromote(_ e: Employee) -> Bool {
        !e.promoted && e.skill >= 65 && GameCalendar.daysBetween(e.hired, date) >= 365
    }

    mutating func promote(_ id: UUID, to trait: TalentTrait) -> String? {
        guard let i = employees.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let e = employees[i]
        if !canPromote(e) { return "\(e.name) needs a year here and skill 65+ to be promoted (once)." }
        if !TalentTrait.promotions(e.role).contains(trait) { return "That isn't a path for a \(e.role.title.lowercased())." }
        employees[i].trait = trait.rawValue
        employees[i].promoted = true
        employees[i].salary *= 1.2
        employees[i].skill = min(100, e.skill + 3)
        employees[i].morale = min(100, e.morale + 15)
        Sim.news(&self, "\(e.name) promoted: \(trait.title)", "\(trait.detail) Salary +20%.", .company, good: true)
        return nil
    }

    mutating func giveRaise(_ id: UUID) {
        guard let i = employees.firstIndex(where: { $0.id == id }) else { return }
        employees[i].salary *= 1.15
        employees[i].morale = min(100, employees[i].morale + 15)
    }

    mutating func upgradeOffice() -> String? {
        guard officeLevel + 1 < Economy.officeLevels.count else { return "You already have the biggest campus." }
        let next = Economy.officeLevels[officeLevel + 1]
        let fitout = next.monthly * 3
        if fitout > cash { return "Fit-out costs \(Fmt.money(fitout))." }
        cash -= fitout
        month.capex += fitout
        officeLevel += 1
        Sim.news(&self, "Moved into: \(next.name)", "Room for \(Fmt.int(next.capacity)) people. Rent \(Fmt.money(next.monthly))/month.", .company, image: next.image, good: true)
        return nil
    }

    // MARK: Finance

    mutating func takeLoan(_ kind: LoanKind, amount: Double, months: Int) -> String? {
        guard let q = Economy.loanQuotes(self).first(where: { $0.kind == kind }), q.available else { return "Not available." }
        if amount <= 0 || amount > q.max + 1 { return "Max \(Fmt.money(q.max))." }
        let pay = Economy.monthlyPayment(principal: amount, annualRate: q.rate, months: months)
        loans.append(Loan(kind: kind, principal: amount, balance: amount, rate: q.rate, termMonths: months, monthsLeft: months, payment: pay, taken: date))
        cash += amount
        if kind == .venture { holdings.append(Holding(name: "Venture lender warrants", shares: totalShares * 0.005)) }
        Sim.news(&self, "Borrowed \(Fmt.money(amount))", "\(kind.rawValue) at \(Fmt.trim(q.rate, 2))% for \(months) months: \(Fmt.money(pay))/month.", .finance)
        return nil
    }

    mutating func repayLoan(_ id: UUID) -> String? {
        guard let i = loans.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if loans[i].balance > cash { return "Need \(Fmt.money(loans[i].balance))." }
        cash -= loans[i].balance
        loans.remove(at: i)
        return nil
    }

    mutating func startRaise(fraction: Double) -> String? {
        if raising { return "Already raising." }
        if isPublic { return "Public companies raise through secondary offerings." }
        if let last = lastRaise, GameCalendar.daysBetween(last, date) < 120 && !rounds.isEmpty && rounds.last!.date == last {
            return "Investors want to see progress — wait 4 months between rounds."
        }
        raising = true
        raiseFraction = fraction
        raiseOffers = []
        lastRaise = date
        Sim.news(&self, "Fundraising kicked off", "You're pitching investors to sell \(Fmt.pct(fraction, decimals: 0)) of the company. Term sheets usually arrive within weeks.", .finance)
        return nil
    }

    mutating func acceptOffer(_ id: UUID) -> String? {
        guard let o = raiseOffers.first(where: { $0.id == id }) else { return "Not found." }
        let post = o.preMoney + o.amount
        let newShares = totalShares * o.amount / o.preMoney
        holdings.append(Holding(name: o.investor, shares: newShares))
        let cashPart = o.amount - o.cloudCredits
        cash += cashPart
        cloudCredits += o.cloudCredits
        rounds.append(FundingRound(name: o.roundName, date: date, amount: o.amount, preMoney: o.preMoney, lead: o.investor, percent: o.amount / post))
        raising = false
        raiseOffers = []
        lastRaise = date
        valuation = post
        Sim.news(&self, "\(o.roundName): \(Fmt.money(o.amount)) at \(Fmt.money(post)) post-money", "Led by \(o.investor). You now own \(Fmt.pct(founderStake)).",
                 .finance, image: "sf_skyline", important: true, good: true)
        return nil
    }

    mutating func cancelRaise() {
        raising = false
        raiseOffers = []
    }

    mutating func ipo() -> String? {
        let (ok, why) = Economy.ipoEligible(self)
        if !ok { return why }
        let v = Finance.privateValue(self)
        let price = v / totalShares * 0.9
        let newShares = totalShares * 0.12 / 0.88
        let raised = newShares * price
        publicShares += newShares
        isPublic = true
        sharePrice = price * rng.range(1.0, 1.45)
        cash += raised
        stock = [StockPoint(date: date, price: price), StockPoint(date: date, price: sharePrice)]
        valuation = sharePrice * totalShares
        rounds.append(FundingRound(name: "IPO", date: date, amount: raised, preMoney: v * 0.9, lead: "Public markets", percent: 0.12))
        Sim.news(&self, "\(companyName) IPO raises \(Fmt.money(raised))", "Shares priced at \(Fmt.price(price)) and closed day one at \(Fmt.price(sharePrice)). Market cap \(Fmt.money(valuation)).",
                 .finance, image: "stock_exchange", important: true, good: true)
        return nil
    }

    mutating func secondaryOffering(fraction: Double) -> String? {
        guard isPublic else { return "Go public first." }
        let newShares = totalShares * fraction
        let raised = newShares * sharePrice * 0.95
        publicShares += newShares
        cash += raised
        sharePrice *= (1 - fraction * 0.5)
        Sim.news(&self, "Secondary offering raises \(Fmt.money(raised))", "Issued \(Fmt.count(newShares)) new shares.", .finance)
        return nil
    }

    mutating func resolveDecision(_ id: UUID, option: Int) {
        Events.resolve(&self, id, option: option)
    }

    // MARK: Training checkpoints

    mutating func setRunSettings(_ id: UUID, lr: LRSchedule, checkpointEvery: Double, autoRollback: Bool) {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return }
        runs[i].lr = lr.rawValue
        runs[i].checkpointEvery = checkpointEvery
        runs[i].autoRollback = autoRollback
    }

    mutating func rollbackRun(_ id: UUID, checkpoint: UUID) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }), let cp = runs[i].saved.first(where: { $0.id == checkpoint }) else { return "Not found." }
        Training.rollback(&self, i, to: cp)
        Training.runLog(&self, i, "Manually rolled back to the \(Int(cp.fraction * 100))% checkpoint.")
        return nil
    }

    /// Turn a mid-training checkpoint into a usable (under-trained) preview model.
    mutating func forkCheckpoint(_ id: UUID, checkpoint: UUID) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }), let ci = runs[i].saved.firstIndex(where: { $0.id == checkpoint }) else { return "Not found." }
        let cp = runs[i].saved[ci]
        if cp.forkedModelID != nil { return "Already forked." }
        let b = bonuses
        var d = runs[i].design
        d.tokensT = max(runs[i].design.tokensT * cp.fraction, 0.0001)
        d.name = "\(runs[i].design.name)-preview-\(Int(cp.fraction * 100))"
        d.reasoning = false
        let fc = ForecastEngine.forecast(d, state: self, dataSources: runs[i].dataSnapshot)
        var m = AIModel(name: d.name, design: d, created: date, c: cp.c, reasoning: false, reasoningBoost: fc.reasoning, codeBoost: fc.code,
                        arenaBonus: 75 * fc.chat, scores: [:], index: 0)
        m.chatSkill = fc.chat
        m.agentBoost = fc.agent
        m.langSkill = fc.lang
        m.longctxSkill = fc.longctx
        m.visSkill = fc.vis
        m.safety = fc.safety
        m.preview = true
        m.autoPrice = true
        m.apiPrice = max(0.01, (Macro.referencePrice(c: cp.c, y: year) * market.apiPricePressure * 0.85 * 1000).rounded() / 1000)
        m.servingPrecision = b.has(.int8Serving) ? .fp8 : .bf16
        m.index = BenchmarkCatalog.index(Leaderboard.profile(m), set: Leaderboard.indexSet(self))
        models.append(m)
        runs[i].saved[ci].forkedModelID = m.id
        Achievements.unlock(&self, "checkpoint_fork")
        Training.runLog(&self, i, "Forked the \(Int(cp.fraction * 100))% checkpoint into \(m.name).")
        Sim.news(&self, "Preview model ready: \(m.name)", "An early checkpoint, instruction-tuned and ready to ship while the full run keeps training.",
                 .company, image: "supercomputer", good: true)
        return nil
    }

    // MARK: Supply agreements

    mutating func signSupplyDeal(vendor: Vendor, annual: Double, years: Int) -> String? {
        if supplyDeals.contains(where: { $0.vendor == vendor.rawValue }) { return "You already have a \(vendor.rawValue) agreement." }
        let cap = max(valuation * 0.5, Economy.runRate(self) * 2, 20_000_000)
        if annual > cap { return "\(vendor.rawValue) won't sign more than \(Fmt.money(cap))/yr with a company your size." }
        if annual < 10_000_000 { return "Minimum commitment is $10M per year." }
        let discount = min(0.15, 0.03 + 0.02 * log10(annual / 1e7)) + Double(years - 1) * 0.005
        supplyDeals.append(SupplyDeal(vendor: vendor.rawValue, annualCommit: annual, yearsLeft: years, start: date,
                                      nextSettlement: GameCalendar.addMonths(date, 12), discount: discount))
        Sim.news(&self, "Supply agreement signed with \(vendor.rawValue)",
                 "\(Fmt.money(annual))/yr for \(years) years: \(Fmt.pct(discount, decimals: 0)) off, 4× allocation and half the lead time. Miss the commitment and you pay 50% of the shortfall.",
                 .hardware, image: "nvidia_hq", important: true, good: true)
        return nil
    }
}
