import SwiftUI

/// 3.9: Government Relations — hearings, the public-affairs budget, promises, the policy calendar, export licences
/// and compliance in one place.
struct GovRelationsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        Page(title: "Government Relations", subtitle: "Testify, spend on public affairs, keep your promises and decide where you stand when the rules change. Every answer moves your standing with governments, the public, researchers, developers and your board.", screen: .government) {
            HeroBanner(image: "stock_exchange", height: 150) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline(s)).font(.title.weight(.bold))
                        Text("\(s.gov.hearings.count) hearing\(s.gov.hearings.count == 1 ? "" : "s") · \(s.gov.commitments.filter(\.active).count) open promise\(s.gov.commitments.filter(\.active).count == 1 ? "" : "s") · \(Fmt.money(GovRelations.monthlySpend(s)))/mo on public affairs")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Political capital").font(.caption).opacity(0.8)
                        Text("\(Int(s.politicalCapital))").font(TypeRamp.bannerMetric)
                    }
                }
            }
            StandingRow(state: s)
            HearingCard(state: s)
            CardGrid(minWidth: 380, maxColumns: 2) {
                PublicAffairsCard(state: s)
                PromisesCard(state: s)
            }
            CalendarCard(state: s)
            CardGrid(minWidth: 380, maxColumns: 2) {
                ExportCard(state: s)
                ComplianceCard(state: s)
            }
            CardGrid(minWidth: 380, maxColumns: 2) {
                RivalGrudgesCard(state: s)
                GovLogCard(state: s)
            }
        }
    }

    private func headline(_ s: GameState) -> String {
        if let h = s.gov.hearing, let v = HearingVenue(rawValue: h.venue) {
            return h.live ? "Testifying before the \(v.title(s))" : "Hearing on \(h.date.gameShort)"
        }
        if let last = s.gov.hearings.first { return "Last hearing: \(last.grade.lowercased())" }
        return "No hearings yet"
    }
}

/// Standing with the governments that matter most to you, public trust and your political-money exposure.
private struct StandingRow: View {
    let state: GameState

    var body: some View {
        let s = state
        let home = HQ.region(s)
        let regions = ([Region.us, .eu, .uk] + (home == .us || home == .eu || home == .uk ? [] : [home]))
        CardGrid(minWidth: 150, maxColumns: 6) {
            ForEach(regions) { r in
                StatTile(title: "\(r.short) government", value: "\(Int(s.world.government(r)))", detail: "settles at \(Int(Stakeholders.governmentTarget(s, r).value))",
                         symbol: "building.columns.fill", tint: s.world.government(r) >= 55 ? Theme.good : (s.world.government(r) < 40 ? Theme.bad : .blue))
            }
            StatTile(title: "Public trust", value: "\(Int(s.world.publicTrust))", detail: "public affairs \(signed(GovRelations.trustBonus(s)))", symbol: "person.3.fill", tint: .purple)
            StatTile(title: "Exposure", value: "\(Int(s.gov.exposure))", detail: "scandal risk \(Fmt.trim(GovRelations.scandalChance(s) * 100, 1))%/mo",
                     symbol: "eye.fill", tint: s.gov.exposure >= 40 ? Theme.bad : (s.gov.exposure >= 25 ? Theme.warning : .gray))
        }
    }
}

private func signed(_ v: Double) -> String { v >= 0 ? "+\(Fmt.trim(v, 1))" : "−\(Fmt.trim(-v, 1))" }

// MARK: Hearings

private struct HearingCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("Hearings", symbol: "person.wave.2.fill", subtitle: "Committees call you when you matter: a leading model, an incident, millions of users, a scandal. Four questions, answered live.")
            if let h = s.gov.hearing, let venue = HearingVenue(rawValue: h.venue), let topic = HearingTopic(rawValue: h.topic) {
                upcoming(s, h, venue, topic)
            } else {
                Text("No hearing scheduled.").font(.callout).foregroundStyle(.secondary)
                let c = Hearings.candidates(s)
                if c.isEmpty {
                    Text("Nothing about your lab is drawing lawmakers' attention yet. That changes with a model near the frontier, a mass-market app, an incident or a scandal.")
                        .font(.caption).foregroundStyle(.tertiary)
                } else {
                    Text("What could bring an invitation").font(.caption.weight(.semibold))
                    ForEach(Array(c.prefix(5).enumerated()), id: \.offset) { _, x in
                        Label("\(x.venue.title(s)): \(x.topic.phrase) — \(x.reason)", systemImage: "exclamationmark.bubble")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !s.gov.hearings.isEmpty {
                Divider()
                Text("On the record").font(.caption.weight(.semibold))
                ForEach(Array(s.gov.hearings.prefix(8).enumerated()), id: \.offset) { _, r in
                    RecordRow(state: s, record: r)
                }
            }
        }
    }

    @ViewBuilder
    private func upcoming(_ s: GameState, _ h: Hearing, _ venue: HearingVenue, _ topic: HearingTopic) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: h.live ? "mic.fill" : "calendar.badge.clock").font(.title2).foregroundStyle(h.live ? Theme.bad : Color.accentColor).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(venue.title(s)): \(topic.title)").font(.headline)
                Text("\(venue.committee(s).capitalizedFirst) · \(h.live ? "in session now" : "sits \(h.date.gameShort)")").font(.caption).foregroundStyle(.secondary)
                if !h.reason.isEmpty { Text(h.reason).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if let d = s.decisions.first(where: { $0.kind == "gov_invite" || $0.kind == "gov_subpoena" || $0.kind == "gov_hearing" }) {
                Button(d.kind == "gov_hearing" ? "Answer the question" : "Answer the invitation") { store.openDecisionID = d.id }
                    .buttonStyle(.borderedProminent)
            }
        }
        let mood = h.live ? h.mood : Hearings.startMood(s, h)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(h.live ? "The room: \(Hearings.moodWord(mood))" : "The room will start \(Hearings.moodWord(mood))").font(.caption.weight(.semibold))
                Spacer()
                Text(h.live ? "Question \(min(h.answers.count + 1, h.questions.count)) of \(h.questions.count)" : witness(h)).font(.caption.monospacedDigit())
            }
            Meter(value: mood / 100, tint: mood >= 55 ? Theme.good : (mood >= 40 ? Theme.warning : Theme.bad), height: 8)
            Text("The committee's mood starts from your standing with the \(venue.region(s).short) government, your preparation and any promises you broke. Above 72 at the end is a reassuring hearing; under 40 a disaster.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        if !h.live {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mock hearings: \(s.gov.prep) of 2 booked").font(.callout.weight(.semibold))
                    Text("Former committee staff grill \(s.founderName) for a day: the room starts 5 points warmer and bad answers hurt 20% less, per round.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Book a round (\(Fmt.money(GovRelations.prepFee(s))))") { store.act("Mock hearing booked") { $0.prepareHearing() } }
                    .disabled(s.gov.prep >= 2)
            }
        }
        if h.live && !h.lines.isEmpty {
            ForEach(Array(h.lines.enumerated()), id: \.offset) { _, l in Text(l).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func witness(_ h: Hearing) -> String {
        switch h.witness {
        case "founder": "You're testifying"
        case "policy": "Your head of policy goes"
        case "declined": "You declined"
        default: "Invitation unanswered"
        }
    }
}

private struct RecordRow: View {
    let state: GameState
    let record: HearingRecord
    @State private var open = false

    var body: some View {
        let s = state
        let r = record
        let tone: Tone = r.grade == "Reassuring" ? .good : (r.grade == "Steady" ? .info : (r.grade == "Bruising" ? .warning : .bad))
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(r.lines.enumerated()), id: \.offset) { _, l in Text(l).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                if !r.clip.isEmpty { Label(r.clip, systemImage: "play.rectangle.fill").font(.caption).foregroundStyle(.orange) }
                let fx = r.effects.filter { abs($0.value) >= 0.5 }.sorted { $0.key < $1.key }
                if !fx.isEmpty {
                    Text(fx.map { "\(label($0.key, s, r)) \(signed($0.value))" }.joined(separator: " · ")).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 4)
        } label: {
            HStack {
                Pill(r.grade, tone: tone)
                Text("\(HearingVenue(rawValue: r.venue)?.title(s) ?? r.venue): \(HearingTopic(rawValue: r.topic)?.title ?? r.topic)").font(.callout)
                Spacer()
                Text("\(r.witness == "founder" ? "You" : (r.witness == "policy" ? "Head of policy" : "Nobody")) · \(r.date.gameShort)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func label(_ k: String, _ s: GameState, _ r: HearingRecord) -> String {
        switch k {
        case "gov": "\((HearingVenue(rawValue: r.venue)?.region(s).short) ?? "") standing"
        case "public": "public trust"
        case "investors": "board"
        case "capital": "political capital"
        default: Region(rawValue: k).map { "\($0.short) standing" } ?? k
        }
    }
}

// MARK: Public affairs

private struct PublicAffairsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var lobby = 4.0
    @State private var think = 4.0
    @State private var campaign = 4.0
    @State private var pac = 4.0
    @State private var focus = ""
    @State private var loaded = false

    private func amount(_ v: Double) -> Double { v <= 4.01 ? 0 : (pow(10, v) / 1000).rounded() * 1000 }
    private func slider(_ v: Double) -> Double { v > 0 ? log10(v) : 4 }

    var body: some View {
        let s = state
        var probe = s
        probe.lobbyBudget = amount(lobby)
        probe.gov.thinkTank = amount(think)
        probe.gov.campaign = amount(campaign)
        probe.gov.pac = amount(pac)
        probe.gov.focus = focus
        let r = GovRelations.focusRegion(probe)
        let lobbyGain = probe.lobbyBudget > 0 ? 2.5 * log10(1 + probe.lobbyBudget / 50_000) * Progression.lobbyFactor(probe) : 0
        let steady = GovRelations.exposureGain(probe) * 10
        let canPAC = GovRelations.usLinked(s)
        let changed = probe.lobbyBudget != s.lobbyBudget || probe.gov.thinkTank != s.gov.thinkTank || probe.gov.campaign != s.gov.campaign || probe.gov.pac != s.gov.pac || focus != s.gov.focus
        return Card {
            CardHeader("Public affairs", symbol: "megaphone.fill", subtitle: "Lobbying is one tool. Policy research, a public campaign and political money each do something different, and each can blow up.")
            row("Lobbying", "Political capital: better odds on bills, smaller fines", $lobby)
            row("Think tanks & policy research", "Standing with the government you focus on; a little political capital", $think)
            row("Public campaign", "Public trust (ads, op-eds, town halls); mocked when trust is low", $campaign)
            row("Super PAC", canPAC ? "Big political capital and US standing; the public turns on it once it's noticed" : "Needs a US presence: foreign companies can't fund US campaigns", $pac)
                .disabled(!canPAC)
            HStack {
                Text("Team works in").font(.callout)
                Picker("Focus", selection: $focus) {
                    Text("Home (\(HQ.region(s).short))").tag("")
                    ForEach(Region.allCases.filter { $0 != HQ.region(s) }) { x in Text(x.title).tag(x.rawValue) }
                }
                .labelsHidden()
                .frame(width: 200)
                Spacer()
                Button("Apply") {
                    store.mutate { $0.setLobbyBudget(amount(lobby)) }
                    store.act("Public affairs: \(Fmt.money(GovRelations.monthlySpend(probe)))/mo") { $0.setPublicAffairs(thinkTank: amount(think), campaign: amount(campaign), pac: amount(pac), focus: focus) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!changed)
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                SpecRow(label: "Monthly spend", value: "\(Fmt.money(GovRelations.monthlySpend(probe)))/mo")
                SpecRow(label: "Political capital a month", value: "+\(Fmt.trim(lobbyGain + GovRelations.capitalGain(probe), 1)) (fades 5%/mo)")
                SpecRow(label: "\(r.short) standing settles", value: signed(GovRelations.standingBonus(probe, r)))
                if r != .us && probe.gov.pac > 0 { SpecRow(label: "US standing settles", value: signed(GovRelations.standingBonus(probe, .us))) }
                SpecRow(label: "Public trust settles", value: signed(GovRelations.trustBonus(probe)))
                SpecRow(label: "Exposure heads toward", value: "\(Int(min(100, steady)))/100 · scandal risk \(Fmt.trim(max(0, min(100, steady) - 25) / 100 * 25, 1))%/mo")
            }
            Text("For scale: Meta spent about $26M on US lobbying in 2025, OpenAI and Anthropic about $3M each; AI industry super PACs raised over $100M for the 2026 midterms. A story about your political money breaks more often the more of it there is.")
                .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            lobby = slider(s.lobbyBudget)
            think = slider(s.gov.thinkTank)
            campaign = slider(s.gov.campaign)
            pac = slider(s.gov.pac)
            focus = s.gov.focus
        }
    }

    private func row(_ title: String, _ detail: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.callout.weight(.semibold))
                Spacer()
                Text(amount(value.wrappedValue) > 0 ? "\(Fmt.money(amount(value.wrappedValue)))/mo" : "None").font(.callout.monospacedDigit())
            }
            Slider(value: value, in: 4...8)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: Promises

private struct PromisesCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("Public promises", symbol: "hand.raised.fill", subtitle: "What you've promised in hearings and pledges. Kept promises build trust for years; broken ones cost far more.")
            if s.gov.commitments.isEmpty {
                Text("No promises yet. Hearings, summits and pledges will ask for them.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(s.gov.commitments.prefix(10).enumerated()), id: \.offset) { _, c in
                if let p = c.promise {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: p.symbol).foregroundStyle(c.status == "broken" ? Theme.bad : (c.status == "kept" ? Theme.good : Color.accentColor)).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(p.title).font(.callout.weight(.semibold))
                                Spacer()
                                Pill(c.status.capitalized, tone: c.status == "broken" ? .bad : (c.status == "kept" ? .good : .info))
                            }
                            Text("Made \(c.venue), \(c.made.gameShort)\(c.due.map { c.active ? " · due \($0.gameShort)" : "" } ?? "")").font(.caption).foregroundStyle(.secondary)
                            Text(c.active ? p.rule : c.note).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: Policy calendar

private struct CalendarCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var showPast = false

    var body: some View {
        let s = state
        let events = PolicyCalendar.all.filter { e in showPast || e.date >= GameCalendar.addDays(s.date, -365) || s.decisions.contains { $0.ref == e.id } }
        Card {
            CardHeader(title: "Policy calendar", symbol: "calendar", subtitle: "Real dates to 2026, projected after. When a moment concerns your lab, you choose where you stand.") {
                Toggle("Show all", isOn: $showPast).toggleStyle(.switch).controlSize(.small)
            }
            ForEach(events) { e in
                HStack(alignment: .top, spacing: 10) {
                    Text(e.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 82, alignment: .leading)
                    Pill(text: e.place, color: e.place == "US" ? .blue : (e.place == "EU" ? .indigo : (e.place == "UK" ? .teal : .gray)))
                        .frame(width: 52, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title).font(.callout.weight(e.date > s.date ? .regular : .semibold))
                        Text(e.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    status(s, e)
                }
                .opacity(e.date > s.date ? 0.75 : 1)
            }
        }
    }

    @ViewBuilder
    private func status(_ s: GameState, _ e: PolicyEvent) -> some View {
        if let d = s.decisions.first(where: { $0.ref == e.id && $0.kind.hasPrefix("gov_policy") }) {
            Button("Decide") { store.openDecisionID = d.id }.buttonStyle(.borderedProminent).controlSize(.small)
        } else if let label = s.gov.answered[e.id] {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor).frame(maxWidth: 200, alignment: .trailing).multilineTextAlignment(.trailing)
        } else if e.date > s.date {
            Text("in \(max(1, GameCalendar.daysBetween(s.date, e.date) / 30)) mo").font(.caption).foregroundStyle(.tertiary)
        } else if e.date < s.startDate {
            Text("Before your lab").font(.caption).foregroundStyle(.tertiary)
        } else {
            Text("Didn't involve you").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

// MARK: Export controls

private struct ExportCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let gulfSites = s.sites.filter { Region.of(location: $0.locationID) == .gulf && $0.kind != .garage }
        let controlled = HardwareCatalog.all.filter { GovRelations.controlled($0) && Economy.canBuy($0, s) }
        Card {
            CardHeader("Export controls", symbol: "shippingbox.and.arrow.backward.fill", subtitle: "US rules on advanced accelerators (4,800+ TPP: an A100 or better) decide where your chips may go.")
            if controlled.isEmpty {
                Text("None of the chips on sale today is fast enough to be controlled.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Controlled chips on sale: \(controlled.prefix(5).map(\.name).joined(separator: ", "))\(controlled.count > 5 ? " and \(controlled.count - 5) more" : "").")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ruleRow(title: "Gulf datacenters need a licence", detail: s.date >= GovRelations.gulfRule ? "Since August 2023." : "From August 2023.",
                    key: "gulf", applies: !gulfSites.isEmpty || s.gov.licences["gulf"] != nil, s)
            if s.date >= GovRelations.clusterRule || s.year >= 2027.5 {
                let big = s.sites.filter { GovRelations.chipsAt(s, $0.id) >= 60_000 }
                Text("Clusters over \(Fmt.int(GovRelations.clusterCap)) accelerators need a licence \(s.date >= GovRelations.clusterRule ? "(since April 2028)" : "(from April 2028, projected)").").font(.callout.weight(.semibold))
                if big.isEmpty { Text("None of your sites is near the line.").font(.caption).foregroundStyle(.secondary) }
                ForEach(big) { site in
                    ruleRow(title: "\(site.name): \(Fmt.int(GovRelations.chipsAt(s, site.id))) accelerators", detail: "", key: GovRelations.siteKey(site.id), applies: true, s)
                }
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Validated End User: \(s.gov.veu ? "yes" : (s.gov.veuDue != nil ? "under review (\(s.gov.veuDue!.gameShort))" : "no"))").font(.callout.weight(.semibold))
                    Text("Vetted companies receive advanced chips in the Gulf without case-by-case licences.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !s.gov.veu && s.gov.veuDue == nil && s.date >= GameCalendar.date(2024, 9, 30) {
                    Button("Apply ($1M)") { store.act("VEU application filed") { $0.applyVEU() } }
                }
            }
            Text("Approval odds follow your standing in Washington: \(Int(GovRelations.licenceOdds(s) * 100))% today. Renting cloud capacity abroad isn't covered — the \"remote access\" gap lawmakers keep debating. Tier 2 rationing under the 2025 diffusion rule is on the Nations page.")
                .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func ruleRow(title: String, detail: String, key: String, applies: Bool, _ s: GameState) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(key == "gulf" ? .semibold : .regular))
                let st = statusText(key, s, applies: applies)
                Text(detail.isEmpty ? st : "\(detail) \(st)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if applies && !GovRelations.licensed(s, key) && s.gov.applications[key] == nil && !(key == "gulf" && s.gov.veu) && (key != "gulf" || s.date >= GovRelations.gulfRule) {
                Button("Apply (\(Fmt.money(GovRelations.licenceFee(key, s))))") { store.act("Licence application filed") { $0.applyExportLicence(key) } }
                    .disabled(s.gov.denied[key].map { $0 > s.date } ?? false)
            }
        }
    }

    private func statusText(_ key: String, _ s: GameState, applies: Bool) -> String {
        if key == "gulf" && s.gov.veu { return "Covered by your VEU status." }
        if let until = s.gov.licences[key], until > s.date { return "Licensed until \(until.gameShort)." }
        if let due = s.gov.applications[key] { return "Application with Commerce: answer by \(due.gameShort)." }
        if let until = s.gov.denied[key], until > s.date { return "Denied; you can reapply \(until.gameShort)." }
        if key != "gulf" { return applies ? "No licence: past \(Fmt.int(GovRelations.clusterCap)) accelerators, Commerce fines you every six months." : "" }
        return applies ? "No licence: orders of controlled chips there are refused." : "You have no datacenter there."
    }
}

// MARK: Compliance

private struct ComplianceCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let biggest = s.runs.map(\.flopsTotal).max() ?? 0
        let unevaluated = s.releasedModels.filter { $0.c >= Macro.frontier(s.year) - 0.6 && !Evaluations.isEvaluated(s, $0) }
        let phases: [(Date, String)] = [(GameCalendar.date(2024, 8, 1), "AI Act in force"), (GameCalendar.date(2025, 2, 2), "Banned uses outlawed"),
                                        (GameCalendar.date(2025, 8, 2), "General-purpose model duties"), (GameCalendar.date(2027, 8, 2), "Older models must comply"),
                                        (GameCalendar.date(2027, 12, 2), "High-risk rules (delayed from 2026)")]
        Card {
            CardHeader("Compliance", symbol: "checkmark.seal.fill", subtitle: "Compute thresholds, the EU AI Act's phases and the safety institutes testing your models.")
            SpecRow(label: "Your largest run", value: biggest > 0 ? Fmt.flops(biggest) : "None yet")
            Label("EU AI Act: above 10²⁵ FLOP a model has systemic risk and needs evaluations\(biggest >= 1e25 ? " — yours qualify" : "").", systemImage: biggest >= 1e25 ? "exclamationmark.circle.fill" : "circle")
                .font(.caption).foregroundStyle(biggest >= 1e25 ? .orange : .secondary)
            Label("US: runs above 10²⁶ FLOP were reportable from October 2023 until January 2025\(s.lawsPassed.contains("transparency") ? "; the Transparency Act makes them reportable again" : "").", systemImage: "circle")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            ForEach(Array(phases.enumerated()), id: \.offset) { _, p in
                HStack {
                    Image(systemName: p.0 <= s.date ? "checkmark.circle.fill" : "circle").foregroundStyle(p.0 <= s.date ? Theme.good : .secondary)
                    Text(p.1).font(.caption)
                    Spacer()
                    Text(p.0.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Divider()
            let who = GovRelations.institutes(s)
            Text(who.isEmpty ? "No safety institute exists yet (the first opens in November 2023)." : "Safety institutes: \(who.map(\.name).joined(separator: ", ")).")
                .font(.caption).foregroundStyle(.secondary)
            SpecRow(label: "Models they've tested", value: "\(s.gov.tested.count) of \(s.gov.asked.count) requested")
            if !unevaluated.isEmpty {
                Label("Unevaluated near-frontier models: \(unevaluated.map(\.name).joined(separator: ", ")). Commission evaluations on the Models page.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

// MARK: Rivals and the log

private struct RivalGrudgesCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let rows = s.gov.grudges.sorted { $0.value > $1.value }
        Card {
            CardHeader("Rivals' view of you", symbol: "flag.2.crossed.fill", subtitle: "What you say about rivals in public, they remember. A deep grudge comes back as a bill their lobbyists wrote.")
            if rows.isEmpty { Text("No rival holds a grudge.").font(.callout).foregroundStyle(.secondary) }
            ForEach(rows, id: \.key) { row in
                let v = row.value
                HStack {
                    Text(CompetitorCatalog.def(row.key).name).font(.callout)
                    Meter(value: v / 100, tint: v >= 30 ? Theme.bad : Theme.warning, height: 6)
                    Text(v >= 30 ? "may back a bill against you" : "annoyed").font(.caption).foregroundStyle(.secondary).frame(width: 170, alignment: .trailing)
                }
            }
        }
    }
}

private struct GovLogCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("Recent", symbol: "list.bullet.rectangle", subtitle: "Government relations, newest first")
            if s.gov.log.isEmpty { Text("Nothing yet.").font(.callout).foregroundStyle(.secondary) }
            ForEach(Array(s.gov.log.prefix(12).enumerated()), id: \.offset) { _, n in
                HStack(alignment: .top) {
                    Text(n.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 82, alignment: .leading)
                    Text(n.text).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// On Security & Policy: where the rest of government relations lives.
struct GovRelationsLinkCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            HStack {
                CardHeader("Hearings, promises and the policy calendar", symbol: "building.columns", subtitle: s.gov.hearing.map { "Hearing on \($0.date.gameShort)" }
                    ?? "\(s.gov.hearings.count) hearings · \(s.gov.commitments.filter(\.active).count) open promises · exposure \(Int(s.gov.exposure))/100")
                Button("Government Relations") { store.open(.government) }.buttonStyle(.borderedProminent)
            }
        }
    }
}
