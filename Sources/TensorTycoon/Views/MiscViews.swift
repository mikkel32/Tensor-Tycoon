import SwiftUI

struct NewsView: View {
    @Environment(GameStore.self) private var store
    @State private var category: NewsCategory? = nil
    @State private var importantOnly = false

    var body: some View {
        let s = store.game
        let items = s.news.filter { (category == nil || $0.category == category) && (!importantOnly || $0.important) }.prefix(250)
        Page(title: "News", subtitle: "Industry headlines, rival launches, hardware releases and your own company's milestones.") {
            HStack {
                Picker("Category", selection: $category) {
                    Text("All").tag(NewsCategory?.none)
                    ForEach(NewsCategory.allCases) { c in Label(c.rawValue, systemImage: c.symbol).tag(NewsCategory?.some(c)) }
                }
                .pickerStyle(.segmented)
                Toggle("Important only", isOn: $importantOnly).toggleStyle(.switch)
            }
            LazyVStack(spacing: 10) {
                ForEach(Array(items)) { n in NewsRow(item: n) }
            }
        }
        .onAppear { store.mutate { $0.unreadNews = 0 } }
    }
}

private struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let img = item.image {
                Photo(key: img).frame(width: 120, height: 76).clipShape(.rect(cornerRadius: 10))
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
        Page(title: "Achievements", subtitle: "\(s.achievements.count) of \(AchievementCatalog.all.count) unlocked") {
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
        Page(title: "Credits & Sources", subtitle: "Tensor Tycoon uses real hardware specs, real benchmarks and real photos. AI labs, CEOs, clients and investors are fictional.") {
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
                CardHeader("Photos (Wikimedia Commons)", symbol: "photo.on.rectangle", subtitle: "All freely licensed. Some chips without free photos use a representative image of the same family.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 12)], spacing: 12) {
                    ForEach(ImageCredits.all) { c in
                        HStack(spacing: 10) {
                            Photo(key: c.id).frame(width: 72, height: 48).clipShape(.rect(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.title).font(.caption.weight(.semibold)).lineLimit(1)
                                Text("\(c.author) · \(c.license)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                if let url = URL(string: c.page) {
                                    Link("View on Commons", destination: url).font(.caption2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
