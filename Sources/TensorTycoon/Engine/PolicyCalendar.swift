import Foundation

/// A dated policy moment: the real ones to 2026, projected ones after.
struct PolicyEvent: Identifiable, Sendable {
    let id: String
    let date: Date
    let title: String
    /// "US", "EU", "UK", "World".
    let place: String
    /// One line for the calendar.
    let summary: String
}

/// 3.9: the policy calendar. On real dates (executive orders, the EU AI Act's phases, safety summits, California's
/// bills, export rules) the game asks where your lab stands, if the moment concerns you; answers move standing,
/// make promises, cost money or schedule consequences. Events from before your lab existed are history.
enum PolicyCalendar {
    static func d(_ y: Int, _ m: Int, _ day: Int) -> Date { GameCalendar.date(y, m, day) }

    static let all: [PolicyEvent] = [
        PolicyEvent(id: "us_ai_initiative", date: d(2019, 2, 11), title: "An executive order launches the American AI Initiative", place: "US",
                    summary: "NIST is told to write technical standards for AI, with industry input."),
        PolicyEvent(id: "eu_ethics", date: d(2019, 4, 8), title: "EU experts publish Ethics Guidelines for Trustworthy AI", place: "EU",
                    summary: "Seven requirements and an assessment list companies can pilot."),
        PolicyEvent(id: "oecd", date: d(2019, 5, 22), title: "OECD countries adopt the first intergovernmental AI principles", place: "World",
                    summary: "42 countries sign up to principles for trustworthy AI."),
        PolicyEvent(id: "eu_whitepaper", date: d(2020, 2, 19), title: "The European Commission's white paper on AI opens for comment", place: "EU",
                    summary: "Binding rules for high-risk AI, or voluntary codes? Brussels asks."),
        PolicyEvent(id: "eu_act_proposal", date: d(2021, 4, 21), title: "The Commission proposes the AI Act", place: "EU",
                    summary: "Risk tiers, banned uses, conformity checks — the first big AI law takes shape."),
        PolicyEvent(id: "nairr_tf", date: d(2021, 6, 10), title: "A task force starts designing a National AI Research Resource", place: "US",
                    summary: "Shared compute and data for academic AI research."),
        PolicyEvent(id: "senate_2023", date: d(2023, 5, 16), title: "The Senate holds its first hearing on overseeing AI", place: "US",
                    summary: "Lab founders testify; licensing and an AI agency are floated."),
        PolicyEvent(id: "wh_commitments", date: d(2023, 7, 21), title: "The White House asks frontier labs for voluntary commitments", place: "US",
                    summary: "Red-teaming, weight security, watermarking and information sharing."),
        PolicyEvent(id: "eo_14110", date: d(2023, 10, 30), title: "Executive order: report frontier runs and red-team results", place: "US",
                    summary: "Runs above 10^26 FLOP must be reported to the Commerce Department."),
        PolicyEvent(id: "bletchley", date: d(2023, 11, 1), title: "The first AI Safety Summit meets at Bletchley Park", place: "UK",
                    summary: "28 countries sign a declaration; labs agree to pre-deployment testing."),
        PolicyEvent(id: "eu_act_adopted", date: d(2024, 3, 13), title: "The European Parliament adopts the AI Act", place: "EU",
                    summary: "Bans from February 2025, general-purpose AI duties from August 2025."),
        PolicyEvent(id: "seoul", date: d(2024, 5, 21), title: "AI Seoul Summit: the Frontier AI Safety Commitments", place: "World",
                    summary: "Labs pledge to publish safety frameworks before the next summit."),
        PolicyEvent(id: "sb1047", date: d(2024, 8, 29), title: "California's SB 1047 heads to the governor", place: "US",
                    summary: "Safety testing and a shutdown capability for the largest models."),
        PolicyEvent(id: "sb1047_veto", date: d(2024, 9, 29), title: "The governor vetoes SB 1047", place: "US",
                    summary: "Too broad, says the veto message; a narrower bill is promised."),
        PolicyEvent(id: "dc_veu", date: d(2024, 9, 30), title: "Commerce opens a fast lane for trusted datacenters abroad", place: "US",
                    summary: "Validated End User status lets advanced chips ship without case-by-case licences."),
        PolicyEvent(id: "eo_revoked", date: d(2025, 1, 21), title: "The 2023 executive order on AI is revoked", place: "US",
                    summary: "Reporting duties end; voluntary testing is up to each lab."),
        PolicyEvent(id: "eu_bans", date: d(2025, 2, 2), title: "The AI Act's bans take effect", place: "EU",
                    summary: "Social scoring, manipulative AI and emotion recognition at work are outlawed."),
        PolicyEvent(id: "gpai_code", date: d(2025, 7, 10), title: "The EU publishes its Code of Practice for general-purpose AI", place: "EU",
                    summary: "Transparency, copyright and safety chapters; signing is voluntary."),
        PolicyEvent(id: "sb53", date: d(2025, 9, 29), title: "California signs SB 53, the frontier AI transparency law", place: "US",
                    summary: "Large frontier developers publish safety frameworks and report critical incidents."),
        PolicyEvent(id: "preempt_eo", date: d(2025, 12, 11), title: "An executive order targets state AI laws", place: "US",
                    summary: "A federal task force is told to challenge state rules on AI."),
        PolicyEvent(id: "testing_eo", date: d(2026, 6, 2), title: "Executive order: voluntary 30-day pre-release testing", place: "US",
                    summary: "Labs may hand frontier models to federal evaluators before release."),
        PolicyEvent(id: "eu_legacy", date: d(2027, 8, 2), title: "Deadline: older general-purpose models must meet the AI Act", place: "EU",
                    summary: "Models on sale before August 2025 lose their grace period."),
        PolicyEvent(id: "eu_highrisk", date: d(2027, 12, 2), title: "EU high-risk AI rules apply", place: "EU",
                    summary: "AI in hiring, credit, health and education needs conformity assessments."),
        PolicyEvent(id: "cluster_rule", date: d(2028, 4, 10), title: "Compute rules 2.0: big clusters need a licence", place: "World",
                    summary: "Any cluster over 100,000 accelerators must be licensed and audited. (Projected)"),
        PolicyEvent(id: "un_convention", date: d(2030, 10, 1), title: "The UN adopts a framework convention on frontier AI", place: "World",
                    summary: "Shared evaluations, 72-hour incident reports and inspections of the largest runs. (Projected)"),
    ]

    static let byID: [String: PolicyEvent] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    // MARK: Firing

    static func daily(_ s: inout GameState) {
        for e in all where e.date <= s.date && !s.gov.events.contains(e.id) {
            s.gov.events.insert(e.id)
            // Before your lab existed (or too long ago to matter): history, not a decision.
            guard e.date >= max(s.startDate, GameCalendar.addDays(s.date, -45)) else { continue }
            fire(&s, e)
        }
        followUps(&s)
    }

    /// What an event's decision says and offers, if it concerns you. The last option is the neutral one an
    /// unanswered decision takes, unless `defaultFirst`.
    struct Spec {
        let body: String
        let options: [(String, String)]
        var amount: Double = 0
        var defaultFirst = false
    }

    static func fire(_ s: inout GameState, _ e: PolicyEvent) {
        switch e.id {
        case "senate_2023":
            if GovRelations.notable(s) && (GovRelations.usLinked(s) || s.valuation >= 1e9) && s.gov.hearing == nil {
                Hearings.invite(&s, .senate, .frontier, reason: "Senators are holding their first hearing on how to oversee AI and want lab founders at the table.")
            }
            return
        case "sb1047_veto":
            guard let pick = s.gov.choices["sb1047"] else { return }
            let side = pick == 0 ? " You backed the bill and lost." : (pick == 1 ? " You lobbied against it and won." : "")
            if pick == 0 { s.politicalCapital = max(0, s.politicalCapital - 2) }
            if pick == 1 { s.politicalCapital = min(100, s.politicalCapital + 3) }
            Sim.news(&s, e.title, "\(e.summary)\(side)", .policy, image: "stock_exchange", good: pick == 1 ? true : (pick == 0 ? false : nil))
            GovRelations.note(&s, "SB 1047 vetoed.\(side)", kind: "policy")
            return
        default:
            break
        }
        guard let sp = spec(e.id, s) else { return }
        Events.addDecision(&s, kind: sp.defaultFirst ? "gov_policy0" : "gov_policy", title: e.title, body: sp.body, image: "stock_exchange",
                           options: sp.options.map { DecisionOption(label: $0.0, detail: $0.1) }, amount: sp.amount, ref: e.id)
        GovRelations.note(&s, e.title, kind: "policy")
    }

    static func runRate(_ s: GameState) -> Double { Economy.runRate(s) }

    static func spec(_ id: String, _ s: GameState) -> Spec? {
        let us = GovRelations.usLinked(s)
        let notable = GovRelations.notable(s)
        let shipped = !s.releasedModels.isEmpty
        let eu = HQ.region(s) == .eu
        switch id {
        case "us_ai_initiative":
            guard us else { return nil }
            return Spec(body: "The order tells NIST to draft technical standards for AI and asks industry for comments. A short filing gets \(s.companyName) into the room early.",
                        options: [("File comments with NIST ($25K)", "US standing +2, political capital +2."), ("Skip it", "No change.")], amount: 25_000)
        case "eu_ethics":
            guard eu || shipped else { return nil }
            return Spec(body: "Brussels' expert group wants companies to pilot its assessment list for trustworthy AI: human oversight, robustness, privacy, transparency, fairness, wellbeing and accountability.",
                        options: [("Join the assessment pilot ($50K)", "EU standing +3, researchers +1."), ("Skip it", "No change.")], amount: 50_000)
        case "oecd":
            guard shipped || notable else { return nil }
            return Spec(body: "OECD members and partners sign the first intergovernmental principles for trustworthy AI. A public endorsement costs nothing and signals you'll play by the rules.",
                        options: [("Endorse them publicly", "Public trust +1; standing +1 in the EU, UK and Japan/Korea."), ("No comment", "No change.")])
        case "eu_whitepaper":
            guard eu || shipped else { return nil }
            return Spec(body: "The Commission's white paper floats binding rules for high-risk AI and asks industry for views. What you file becomes part of the record the AI Act is built on.",
                        options: [("Back binding rules for high-risk AI", "EU standing +4, public trust +1, board −1."),
                                  ("Argue for voluntary codes", "EU standing −2, board +1, political capital +1."),
                                  ("Skip the consultation", "No change.")])
        case "eu_act_proposal":
            guard eu || shipped else { return nil }
            return Spec(body: "The Commission's draft sorts AI by risk: banned uses, high-risk systems that need conformity checks, and lighter duties for the rest. Industry is already lobbying over general-purpose models.",
                        options: [("Support the risk-based approach", "EU standing +4, public trust +1."),
                                  ("Lobby for a general-purpose AI carve-out", "EU standing −3, board +2, political capital −2. EU rules end up a little looser."),
                                  ("Stay out of it", "No change.")])
        case "nairr_tf":
            guard us else { return nil }
            let cost = clamp(s.cash * 0.002, 100_000, 5_000_000)
            return Spec(body: "A federal task force is designing a shared research cloud for universities. Labs that donate credits to the pilot get a seat at the table.",
                        options: [("Donate compute credits (\(Fmt.money(cost)))", "Researchers +3, US standing +3."), ("Not now", "No change.")], amount: cost)
        case "wh_commitments":
            guard notable && us else { return nil }
            return Spec(body: "The White House asks the leading labs to sign eight voluntary commitments: internal and external red-teaming, securing model weights, watermarking, sharing safety information and more.",
                        options: [("Sign all eight", "Promises: evaluate frontier models before release and reach SL3 within 18 months. US standing +5, public trust +2, researchers +1."),
                                  ("Sign the testing commitments only", "Promise: evaluate frontier models before release. US standing +2."),
                                  ("Decline", "US standing −4, board +1.")])
        case "eo_14110":
            guard us && (notable || s.models.contains(where: { $0.c >= Macro.frontier(s.year) - 1 })) else { return nil }
            return Spec(body: "Runs above 10^26 FLOP must now be reported to the Commerce Department, with red-team results. Some labs plan to challenge the order; others will brief officials early.",
                        options: [("Brief Commerce early ($250K)", "US standing +4, political capital +2, safety +1."),
                                  ("Back the industry challenge", "US standing −3, developers +2, board +1."),
                                  ("Comply with the letter", "No change.")], amount: 250_000)
        case "bletchley":
            guard notable else { return nil }
            return Spec(body: "Twenty-eight countries meet at Bletchley Park. Labs that attend are expected to let the new safety institutes test their models before release.",
                        options: [("Attend and sign up for pre-deployment testing", "Promise: give safety institutes pre-release access. UK standing +6, US +2, EU +2, public trust +1."),
                                  ("Stay home", "UK standing −2."),
                                  ("Send a delegate", "UK standing +1.")])
        case "eu_act_adopted":
            guard shipped else { return nil }
            let cost = clamp(runRate(s) * 0.003, 300_000, 20_000_000)
            return Spec(body: "The AI Act passes. Bans apply from February 2025 and duties for general-purpose models from August 2025. Labs that staff up now will have an easier time with the AI Office.",
                        options: [("Build an EU compliance team now (\(Fmt.money(cost)))", "EU standing +4 now and +2 more until 2028."), ("Wait for the guidance", "No change.")], amount: cost)
        case "seoul":
            guard notable else { return nil }
            return Spec(body: "At the Seoul summit, frontier labs are asked to publish a safety framework — when a model is too dangerous to deploy, and what they'd do about it — before the next summit in Paris.",
                        options: [("Sign the commitments", "Promise: publish a frontier safety framework within 9 months. Japan/Korea standing +4, UK +3, public trust +1."),
                                  ("Decline", "UK and Japan/Korea standing −2.")])
        case "sb1047":
            guard us else { return nil }
            let rival = GovRelations.leadingRival(s)?.def.name ?? "Rival labs"
            return Spec(body: "California's SB 1047 would require safety testing and a shutdown capability for models costing over $100M to train. \(rival) is lobbying against it; safety researchers back it.",
                        options: [("Back it publicly", "Public trust +2, researchers +2, US standing +1, board −2. \(rival) won't like it."),
                                  ("Oppose it", "Developers +3, board +2, public trust −2, researchers −2."),
                                  ("Stay out", "No change.")])
        case "dc_veu":
            let tier2 = s.sites.contains { ["uae", "iceland", "ro_bucharest"].contains($0.locationID) && $0.kind != .garage }
            guard tier2 || HQ.country(s).diffusionTier >= 2 else { return nil }
            return Spec(body: "Commerce's new data-center Validated End User programme lets vetted companies receive advanced chips abroad without case-by-case licences. You have sites, or a home, where that may matter.",
                        options: [("Apply for VEU status ($1M)", "Decision in about four months; odds depend on your standing in Washington."), ("Not now", "No change.")], amount: 1_000_000)
        case "eo_revoked":
            let promised = s.gov.commitments.contains { ($0.id == GovPromise.evals.rawValue || $0.id == GovPromise.institute.rawValue) && $0.active }
            guard us && promised else { return nil }
            return Spec(body: "The order behind federal reporting and testing is gone. Nothing now requires you to keep the testing promises you made — except your word.",
                        options: [("Keep honouring your testing promises", "Public trust +1, researchers +2."),
                                  ("Quietly drop them", "Breaks your testing promises. Board +1, developers +1.")], defaultFirst: true)
        case "eu_bans":
            guard s.consumerUsers >= 100_000 || s.agentSeats > 0 else { return nil }
            let cost = clamp(runRate(s) * 0.001, 100_000, 5_000_000)
            return Spec(body: "From today the EU bans social scoring, manipulative AI and emotion recognition in workplaces and schools. Your products have a lot of features nobody has reviewed against the list.",
                        options: [("Audit your products (\(Fmt.money(cost)))", "EU standing +2. Nothing slips through."),
                                  ("Assume you're fine", "No cost now. If the AI Office finds a banned feature later, it fines you.")], amount: cost)
        case "gpai_code":
            guard shipped else { return nil }
            return Spec(body: "The EU's code of practice spells out how general-purpose model providers meet the AI Act: transparency, copyright and — for the largest models — safety and security. Signing is voluntary; signatories get the benefit of the doubt.",
                        options: [("Sign all three chapters", "Promise: evaluate frontier models before release. EU standing +6 (and +3 while it stands), public trust +1, developers −1."),
                                  ("Refuse to sign", "EU standing −6 (and −4 while it stands), developers +2, board +1. The European Parliament may want a word."),
                                  ("Sign only the safety and security chapter", "EU standing +2 (and +1 while it stands).")])
        case "sb53":
            guard us && Policy.isFrontierDeveloper(s) && runRate(s) >= 5e8 else { return nil }
            return Spec(body: "California's SB 53 makes large frontier developers publish safety frameworks and report critical incidents to the state within 15 days, with protections for whistleblowers.",
                        options: [("Publish a framework and an incident process ($1M)", "Promise: publish a frontier safety framework. US standing +2, public trust +1."),
                                  ("Challenge it in court", "US standing −3, public trust −1, board +1."),
                                  ("Minimum compliance", "No change.")], amount: 1_000_000)
        case "preempt_eo":
            guard us else { return nil }
            return Spec(body: "A new executive order sets up a federal task force to challenge state AI laws and pushes Congress toward a single national standard.",
                        options: [("Back federal preemption", "Political capital +3, board +2, public trust −2, researchers −1."),
                                  ("Defend the states' right to regulate", "Public trust +2, researchers +1, US standing −2."),
                                  ("Stay out", "No change.")])
        case "testing_eo":
            guard us && notable else { return nil }
            return Spec(body: "Labs may now hand frontier models to federal evaluators for 30 days before release. It's voluntary — and everyone will see who opts in.",
                        options: [("Opt in", "Promise: give safety institutes pre-release access. US standing +4, public trust +1."),
                                  ("Decline", "US standing −2."),
                                  ("Decide later", "No change.")])
        case "eu_legacy":
            let old = legacyModels(s)
            guard !old.isEmpty else { return nil }
            let cost = old.reduce(0) { $0 + Evaluations.cost(s, $1) }
            return Spec(body: "\(old.count) of your models went on sale before August 2025 and were never evaluated: \(old.prefix(4).map(\.name).joined(separator: ", ")). Their grace period ends today.",
                        options: [("Commission evaluations for all of them (\(Fmt.money(cost)))", "Each is evaluated within three weeks. EU standing +2."),
                                  ("Take the risk", "No cost now; the AI Office may fine you.")], amount: cost)
        case "eu_highrisk":
            guard s.consumerUsers >= 1e6 || s.deals.contains(where: \.active) else { return nil }
            let cost = clamp(runRate(s) * 0.002, 500_000, 50_000_000)
            return Spec(body: "AI used in hiring, credit, health and education now needs conformity assessments, logs and human oversight in the EU. Some of your customers use your models exactly that way.",
                        options: [("Certify your products (\(Fmt.money(cost)))", "EU standing +3, public trust +1."),
                                  ("Accept the risk", "No cost now; regulators may fine you.")], amount: cost)
        case "cluster_rule":
            let big = bigSites(s)
            guard !big.isEmpty else { return nil }
            let fee = big.reduce(0) { $0 + GovRelations.licenceFee(GovRelations.siteKey($1.id), s) }
            return Spec(body: "From today any cluster over 100,000 accelerators needs a licence and an audit. \(big.map(\.name).joined(separator: ", ")) \(big.count == 1 ? "is" : "are") close to the line or past it: an unlicensed cluster is fined every six months.",
                        options: [("Apply for licences now (\(Fmt.money(fee)))", "Commerce answers in two to four months; odds depend on your US standing."),
                                  ("Wait", "No cost now. Past 100,000 accelerators, fines every six months.")], amount: fee)
        case "un_convention":
            guard notable else { return nil }
            return Spec(body: "The convention commits signatory states to shared dangerous-capability evaluations, incident reports within 72 hours and inspections of the largest training runs. Governments want the big labs to back it.",
                        options: [("Back it and open your runs to inspection", "Promises: evaluate frontier models and give institutes access. Standing +3 everywhere (and +2 while it stands), public trust +2, board −2."),
                                  ("Lobby against it", "Standing −2 everywhere (and −2 while it stands), public trust −2, board +1, political capital −3."),
                                  ("Back it with reservations", "Standing +1 everywhere.")])
        default:
            return nil
        }
    }

    /// Released models that went on sale before the AI Act's general-purpose duties and were never evaluated.
    static func legacyModels(_ s: GameState) -> [AIModel] {
        s.releasedModels.filter { ($0.releaseDate ?? $0.created) < d(2025, 8, 2) && !Evaluations.isEvaluated(s, $0) }
    }

    /// Sites with 60,000 or more accelerators installed or on order.
    static func bigSites(_ s: GameState) -> [Site] {
        s.sites.filter { GovRelations.chipsAt(s, $0.id) >= 60_000 && !GovRelations.licensed(s, GovRelations.siteKey($0.id)) }
    }

    // MARK: Answers

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let e = byID[d.ref] else { return }
        s.gov.choices[e.id] = option
        if d.options.indices.contains(option) { s.gov.answered[e.id] = d.options[option].label }
        let every = Stakeholders.everyGovernment
        func fx(_ m: [String: Double]) { GovRelations.apply(&s, m, region: nil, why: e.title) }
        func promise(_ p: GovPromise, _ r: Region, _ venue: String) { GovRelations.promise(&s, p, venue: venue, region: r) }
        // Option 0 carries the cost, except applications that charge their own fees.
        if option == 0 && d.amount > 0 && e.id != "dc_veu" && e.id != "cluster_rule" { GovRelations.pay(&s, d.amount) }
        switch (e.id, option) {
        case ("us_ai_initiative", 0): fx(["us": 2, "capital": 2])
        case ("eu_ethics", 0): fx(["eu": 3, "researchers": 1])
        case ("oecd", 0): fx(["public": 1, "eu": 1, "uk": 1, "jk": 1])
        case ("eu_whitepaper", 0): fx(["eu": 4, "public": 1, "investors": -1])
        case ("eu_whitepaper", 1): fx(["eu": -2, "investors": 1, "capital": 1])
        case ("eu_act_proposal", 0): fx(["eu": 4, "public": 1])
        case ("eu_act_proposal", 1):
            fx(["eu": -3, "investors": 2, "capital": -2])
            Consequences.setStrictness(&s, .eu, plus: -2)
        case ("nairr_tf", 0): fx(["researchers": 3, "us": 3])
        case ("wh_commitments", 0):
            fx(["us": 5, "public": 2, "researchers": 1])
            promise(.evals, .us, "to the White House")
            promise(.security, .us, "to the White House")
        case ("wh_commitments", 1):
            fx(["us": 2])
            promise(.evals, .us, "to the White House")
        case ("wh_commitments", _): fx(["us": -4, "investors": 1])
        case ("eo_14110", 0): fx(["us": 4, "capital": 2, "safety": 1])
        case ("eo_14110", 1): fx(["us": -3, "developers": 2, "investors": 1])
        case ("bletchley", 0):
            fx(["uk": 6, "us": 2, "eu": 2, "public": 1])
            promise(.institute, .uk, "at the Bletchley Park summit")
        case ("bletchley", 1): fx(["uk": -2])
        case ("bletchley", _): fx(["uk": 1])
        case ("eu_act_adopted", 0): fx(["eu": 4])
        case ("seoul", 0):
            fx(["jk": 4, "uk": 3, "public": 1])
            promise(.framework, .japanKorea, "at the Seoul summit")
        case ("seoul", _): fx(["uk": -2, "jk": -2])
        case ("sb1047", 0):
            fx(["public": 2, "researchers": 2, "us": 1, "investors": -2])
            if let r = GovRelations.leadingRival(s) { s.gov.grudges[r.id] = min(100, (s.gov.grudges[r.id] ?? 0) + 8) }
        case ("sb1047", 1):
            fx(["developers": 3, "investors": 2, "public": -2, "researchers": -2])
            if let i = s.gov.commitments.firstIndex(where: { $0.id == GovPromise.safetyBills.rawValue && $0.active }) {
                GovRelations.close(&s, i, kept: false, why: "You lobbied against California's SB 1047.")
            }
        case ("dc_veu", 0):
            if let why = s.applyVEU() { Sim.news(&s, "VEU application not filed", why, .policy) }
        case ("eo_revoked", 0): fx(["public": 1, "researchers": 2])
        case ("eo_revoked", _):
            fx(["investors": 1, "developers": 1])
            for p in [GovPromise.evals, .institute] {
                if let i = s.gov.commitments.firstIndex(where: { $0.id == p.rawValue && $0.active }) {
                    GovRelations.close(&s, i, kept: false, why: "You dropped it the week the executive order was revoked.")
                }
            }
        case ("eu_bans", 0): fx(["eu": 2])
        case ("eu_bans", _): s.gov.followUps["eubans"] = GameCalendar.addDays(s.date, 120 + Int(World.roll(s, "eubans") * 120))
        case ("gpai_code", 0):
            fx(["eu": 6, "public": 1, "developers": -1])
            promise(.evals, .eu, "to the EU AI Office")
        case ("gpai_code", 1): fx(["eu": -6, "developers": 2, "investors": 1])
        case ("gpai_code", _): fx(["eu": 2])
        case ("sb53", 0):
            fx(["us": 2, "public": 1])
            promise(.framework, .us, "to California regulators")
        case ("sb53", 1): fx(["us": -3, "public": -1, "investors": 1])
        case ("preempt_eo", 0): fx(["capital": 3, "investors": 2, "public": -2, "researchers": -1])
        case ("preempt_eo", 1): fx(["public": 2, "researchers": 1, "us": -2])
        case ("testing_eo", 0):
            fx(["us": 4, "public": 1])
            promise(.institute, .us, "to the White House")
        case ("testing_eo", 1): fx(["us": -2])
        case ("eu_legacy", 0):
            for m in legacyModels(s) {
                if let i = s.models.firstIndex(where: { $0.id == m.id }), s.models[i].evalDue == nil { s.models[i].evalDue = GameCalendar.addDays(s.date, Evaluations.days) }
            }
            fx(["eu": 2])
        case ("eu_legacy", _): s.gov.followUps["legacy"] = GameCalendar.addDays(s.date, 90 + Int(World.roll(s, "legacy") * 110))
        case ("eu_highrisk", 0): fx(["eu": 3, "public": 1])
        case ("eu_highrisk", _): s.gov.followUps["highrisk"] = GameCalendar.addDays(s.date, 120 + Int(World.roll(s, "highrisk") * 150))
        case ("cluster_rule", 0):
            for site in bigSites(s) { _ = s.applyExportLicence(GovRelations.siteKey(site.id)) }
        case ("un_convention", 0):
            var m = every(3)
            m["public"] = 2
            m["investors"] = -2
            fx(m)
            promise(.evals, HQ.region(s), "under the UN convention")
            promise(.institute, HQ.region(s), "under the UN convention")
        case ("un_convention", 1):
            var m = every(-2)
            m["public"] = -2
            m["investors"] = 1
            m["capital"] = -3
            fx(m)
        case ("un_convention", _): fx(every(1))
        default:
            break
        }
        GovRelations.note(&s, "\(e.title): \(d.options.indices.contains(option) ? d.options[option].label.lowercasedFirst : "answered")", kind: "policy")
    }

    /// Lasting standing from the stands you took (a signed code, a compliance team, a convention).
    static func standing(_ s: GameState, _ r: Region) -> Double {
        var v = 0.0
        let c = s.gov.choices
        if r == .eu {
            if s.year < 2030 { v += [0: 3.0, 1: -4, 2: 1][c["gpai_code"] ?? -1] ?? 0 }
            if c["eu_act_adopted"] == 0 && s.year < 2028 { v += 2 }
        }
        if r == .us && s.year < 2027 { v += [0: 2.0, 1: 1][c["wh_commitments"] ?? -1] ?? 0 }
        if r == .uk && c["bletchley"] == 0 && s.year < 2027 { v += 2 }
        v += [0: 2.0, 1: -2][c["un_convention"] ?? -1] ?? 0
        return v
    }

    // MARK: Consequences that come later

    static func followUps(_ s: inout GameState) {
        for (key, due) in s.gov.followUps.sorted(by: { $0.key < $1.key }) where due <= s.date {
            s.gov.followUps[key] = nil
            guard World.roll(s, "follow|\(key)|\(due.timeIntervalSince1970)") < 0.35 else {
                GovRelations.note(&s, "The gamble on \(key == "eubans" ? "the AI Act's bans" : (key == "legacy" ? "legacy models" : "high-risk rules")) paid off: no fine", kind: "policy")
                continue
            }
            let fine = clamp(Economy.runRate(s) * 0.01, 1e6, 5e8) * Policy.fineFactor(s)
            GovRelations.pay(&s, fine)
            Stakeholders.move(&s, ["eu": -4, "public": -1], "Fined under the EU AI Act")
            let what: String
            switch key {
            case "eubans": what = "An emotion-recognition feature in one of your workplace tools falls under the AI Act's bans."
            case "legacy": what = "Older general-purpose models on sale without the required evaluations."
            default: what = "A customer used your model to screen job applicants without the required conformity assessment."
            }
            Sim.news(&s, "EU fines \(s.companyName) \(Fmt.money(fine))", "\(what) The AI Office's first big case against a lab.", .policy, image: "stock_exchange", important: true, good: false)
            GovRelations.note(&s, "Fined \(Fmt.money(fine)) under the AI Act", kind: "policy")
        }
    }
}
