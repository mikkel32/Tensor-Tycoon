import SwiftUI

struct NewsView: View {
    @Environment(GameStore.self) private var store
    @State private var category: NewsCategory? = nil
    @State private var importantOnly = false
    @State private var compact = false
    @State private var search = ""

    var body: some View {
        let s = store.game
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let items = s.news.filter {
            (category == nil || $0.category == category) && (!importantOnly || $0.important)
                && (q.isEmpty || $0.title.lowercased().contains(q) || $0.body.lowercased().contains(q))
        }.prefix(300)
        // Month by month, newest first, each with that month's briefing headline.
        let months = Dictionary(grouping: items, by: { $0.date.ym }).sorted { $0.key > $1.key }
        Page(title: "News", subtitle: "Industry headlines, rival launches, hardware releases and your own company's milestones, month by month.", screen: .news) {
            HStack(spacing: 12) {
                Picker("Category", selection: $category) {
                    Text("All").tag(NewsCategory?.none)
                    ForEach(NewsCategory.allCases) { c in Label(c.rawValue, systemImage: c.symbol).tag(NewsCategory?.some(c)) }
                }
                .pickerStyle(.segmented)
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Toggle("Major only", isOn: $importantOnly).toggleStyle(.switch)
                Toggle("Compact", isOn: $compact).toggleStyle(.switch)
            }
            if items.isEmpty {
                Card {
                    EmptyStateView(symbol: "newspaper", title: "Nothing here", message: q.isEmpty ? "News appears as the world moves." : "No stories match \"\(search)\".")
                }
            }
            ForEach(months, id: \.key) { entry in
                let ym = entry.key
                let list = entry.value
                VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(GameCalendar.date(ym.year, ym.month, 1).gameMonth).font(.title3.weight(.bold))
                        Text("\(list.count) stor\(list.count == 1 ? "y" : "ies")\(list.contains(where: \.important) ? " · \(list.filter(\.important).count) major" : "")")
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                    }
                    if let b = s.briefings.first(where: { $0.month.ym == ym }) {
                        Button { store.openBriefing(b.id) } label: {
                            Label(b.headline, systemImage: "doc.text.magnifyingglass").font(.callout)
                        }
                        .buttonStyle(.link)
                    }
                    LazyVStack(spacing: compact ? 2 : 10) {
                        ForEach(list) { n in
                            if compact { CompactNewsRow(item: n) } else { NewsRow(item: n) }
                        }
                    }
                }
            }
        }
        .onAppear { store.mutate { $0.unreadNews = 0 } }
    }
}

/// One line per story, for scanning a busy month.
private struct CompactNewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: item.category.symbol)
                .font(.caption)
                .foregroundStyle(Theme.categoryColor(item.category))
                .frame(width: 16)
            Text(item.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 82, alignment: .leading)
            Text(item.title)
                .font(.callout.weight(item.important ? .semibold : .regular))
                .foregroundStyle(item.good == false ? Color.red : .primary)
                .lineLimit(1)
                .help(item.body)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
    }
}

private struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let img = item.image {
                Photo(key: img, illustrative: item.illustrative || ImagePicker.isIllustrative(img)).frame(width: 120, height: 76).clipShape(.rect(cornerRadius: 10))
            } else {
                Image(systemName: item.category.symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 76)
                    .background(Theme.categoryColor(item.category).gradient.opacity(0.85), in: .rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Pill(text: item.category.rawValue, color: Theme.categoryColor(item.category))
                    if item.important { Pill(text: "Major", color: .red, symbol: "flame.fill") }
                    Text(item.date.gameLong).font(.caption).foregroundStyle(.secondary)
                }
                Text(item.title).font(.headline)
                    .foregroundStyle(item.good == false ? Color.red : .primary)
                Text(item.body).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(item.important ? Color.orange.opacity(0.4) : .clear))
    }
}

struct AchievementsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        Page(title: "Achievements", subtitle: "Milestones in your company's story; each one earns a culture point. \(s.achievements.count) of \(AchievementCatalog.all.count) unlocked.", screen: .achievements) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(AchievementCatalog.all) { a in
                    let done = s.achievements.contains(a.id)
                    HStack(spacing: 12) {
                        Image(systemName: a.symbol)
                            .font(.title2)
                            .foregroundStyle(done ? .white : .secondary)
                            .frame(width: 48, height: 48)
                            .background(done ? AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(.quaternary), in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title).font(.headline)
                            Text(a.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(.background.secondary, in: .rect(cornerRadius: 14))
                    .opacity(done ? 1 : 0.55)
                }
            }
        }
    }
}

struct CreditsView: View {
    var body: some View {
        Page(title: "Credits & Sources", subtitle: "Tensor Tycoon uses real hardware specs, real benchmarks and real photos. AI labs, CEOs, clients and investors are fictional.", screen: .credits) {
            Card {
                CardHeader("How the simulation works", symbol: "function")
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Training compute = 6 × active parameters × tokens. Time = compute ÷ (chips × dense TFLOPS × MFU × goodput).")
                    Text("• Forecasts use Epoch AI's refit of the Chinchilla law (Besiroglu et al. 2024): L = 1.8172 + 482.01/N^0.3478 + 2085.43/D^0.3658, converted to effective compute, with data-repetition penalties (Muennighoff et al. 2023) and algorithmic gains only from techniques you have researched. Replayed against GPT-3, Chinchilla, LLaMA, Llama 3, DeepSeek-V3 and Kimi K2, most land within ~0.1–0.4 capability units.")
                    Text("• Hardware failures follow Meta's Llama 3 report: 419 unexpected interruptions in 54 days on 16,384 H100s.")
                    Text("• Each benchmark is a sigmoid fitted to two dated real results (e.g. GPT-4 at the 90th percentile on the bar exam, o3 at 43.8% on VCT, Operator at 61% on Online-Mind2Web, InterCode-CTF saturating at 95% in Dec 2024).")
                    Text("• Safety thresholds are modelled on Anthropic's RSP (ASL-3 for Claude Opus 4, May 2025), OpenAI's Preparedness Framework and Google DeepMind's Frontier Safety Framework.")
                    Text("• Compute partnerships are modelled on announced deals: NVIDIA–OpenAI (Sep 2025), Anthropic–Google TPUs (Oct 2025), Amazon–Anthropic, Microsoft–NVIDIA–Anthropic (Nov 2025) and AMD–OpenAI with warrants (Oct 2025).")
                    Text("• Tokens/sec per user is memory-bandwidth bound; serving capacity is FLOP-bound (≈2 × active params per token).")
                    Text("• Market size, chat users, API prices and the Fed funds rate follow real-world history to 2026, then projections.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Card {
                CardHeader("Spec sources", symbol: "doc.text.magnifyingglass")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vendor datasheets and docs (NVIDIA, Google Cloud TPU docs & pricing, AMD Instinct, AWS Neuron docs, Intel Gaudi, Microsoft Maia 200 launch), plus coverage from Tom's Hardware, StorageReview, HPCwire, ServeTheHome, TechPowerUp and Epoch AI. Numbers are dense (non-sparse). Values marked \"est.\" are game estimates where nothing official is published (e.g. Rubin TDP, TPU 8t/8i FP8 & power, Feynman).")
                    Text("Cloud prices reflect public on-demand rates (e.g. Cloud TPU v5e $1.20, v6e $2.70, Ironwood $12.00 per chip-hour; H100 ≈ $2–4/hr, B200 ≈ $6–8/hr in late 2026) and decay as chips age.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Card {
                CardHeader("Model & benchmark sources", symbol: "books.vertical.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Technical reports: GPT-4, Llama 3 / 3.1, DeepSeek-V3 and R1, Kimi K2 and Moonlight (Muon), Gemini 2.5, Claude model cards, GPT-5 launch materials. Compute and algorithmic-progress estimates from Epoch AI.")
                    Text("Benchmark papers and leaderboards: MMLU, GPQA, HLE, FrontierMath, ARC Prize, SWE-bench (Verified, Pro, Multimodal), MathArena, METR, OSWorld, τ²-bench, Terminal-Bench, GDPval, Online-Mind2Web, WebVoyager, AppWorld, Remote Labor Index, SuperGPQA, Omni-MATH, BIG-Bench Extra Hard, ZebraLogic, MuSR, LegalBench (Vals AI), HealthBench, MedXpertQA, BIRD, MATH-Vision, VideoMMMU, ScreenSpot-Pro, MMAU / MMAU-Pro, XSTest, WMDP, Cybench, InterCode-CTF (Palisade Research) and VCT.")
                    Text("Scores in the game come from fitted curves, so individual numbers are approximations of the real trajectories, not quotes.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Card {
                CardHeader("Photos (Wikimedia Commons)", symbol: "photo.on.rectangle", subtitle: PhotoCreditsList.summary)
                PhotoCreditsList()
            }
        }
    }
}

/// Every bundled photo's credit, filterable. Used on the Credits screen and in the Photo Credits sheet.
struct PhotoCreditsList: View {
    @State private var filter = ""

    static var summary: String {
        "All \(ImageCredits.all.count) photos are freely licensed for any use, including commercial (CC0, public domain, CC BY or CC BY-SA), and each is credited below with what it shows. Bundled copies are resized and re-encoded; any crop is noted. Photos standing in for chips without a free photo, for future, custom or alien hardware, and for your own sites, offices, fabs, labs and deals are marked \"Illustrative\" or \"Similar hardware\". CREDITS.txt in the app's Resources folder lists the same credits as plain text."
    }

    private var shown: [ImageCredit] {
        let q = filter.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return ImageCredits.all }
        return ImageCredits.all.filter { c in
            [c.subject, c.author, c.license, c.title, c.restrictions].contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Filter by subject, author or licence", text: $filter)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                Text("\(shown.count) of \(ImageCredits.all.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 12)], spacing: 12) {
                ForEach(shown) { PhotoCreditRow(credit: $0) }
            }
        }
    }
}

/// One photo's credit: what it shows and who made it (two lines each, the full text on hover), the licence and its
/// deed, reuse restrictions, how the bundled copy was edited, and the Commons page.
struct PhotoCreditRow: View {
    let credit: ImageCredit

    var body: some View {
        let c = credit
        let byline = c.author + " · " + c.license
        let unrestricted = c.restrictions == "none"
        let restrictions: String = unrestricted ? "No restrictions" : c.restrictions.capitalizedFirst
        HStack(alignment: .top, spacing: 10) {
            Photo(key: c.id, size: .icon).frame(width: 72, height: 48).clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(c.subject).font(.caption.weight(.semibold)).lineLimit(2).help(c.subject)
                Text(byline).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    .help(byline + "\n" + c.title)
                Label(restrictions, systemImage: unrestricted ? "checkmark.circle" : "info.circle")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    .help("Reuse conditions: " + c.restrictions)
                if c.modified != "none" {
                    Label("Modified: " + c.modified, systemImage: "crop")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        .help("The bundled copy differs from the Commons original: " + c.modified + ".")
                }
                HStack(spacing: 10) {
                    if let url = URL(string: c.page) {
                        Link("Commons page", destination: url).help(c.attribution)
                    }
                    if let deed = c.licenseURL {
                        Link(PhotoCreditRow.shortURL(deed), destination: deed)
                            .help(c.license + " licence deed")
                    }
                }
                .font(.caption2)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    /// "creativecommons.org/licenses/by-sa/4.0/" for a deed link's visible text.
    static func shortURL(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "https://", with: "")
    }
}

/// The photo credits on their own, so they can be read from the app menu with or without a game open.
struct PhotoCreditsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Photo Credits", systemImage: "photo.on.rectangle").font(.title2.weight(.bold))
                Text(PhotoCreditsList.summary).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            Divider()
            ScrollView {
                PhotoCreditsList()
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 780, idealWidth: 940, minHeight: 560, idealHeight: 760)
    }
}
