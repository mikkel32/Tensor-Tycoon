import Foundation

// 3.6: data economy — the kinds of training data, their quality, and what's for sale.

/// A kind of training data. Each has a world stock that grows by year and a relevance to each capability domain.
enum DataKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case web, reference, books, papers, code, math, expert, preferences, images, video, audio, speech, robotics, spatial, industrial, synthetic, specialist

    var id: String { rawValue }

    var label: String {
        switch self {
        case .web: "Web text"
        case .reference: "Reference"
        case .books: "Books"
        case .papers: "Scientific papers"
        case .code: "Code"
        case .math: "Math reasoning"
        case .expert: "Expert demonstrations"
        case .preferences: "Human preferences"
        case .images: "Images"
        case .video: "Video"
        case .audio: "Audio"
        case .speech: "Speech"
        case .robotics: "Robotics trajectories"
        case .spatial: "Spatial & 3D"
        case .industrial: "Industrial"
        case .synthetic: "Validated synthetic"
        case .specialist: "Specialist research"
        }
    }

    var symbol: String {
        switch self {
        case .web: "globe"
        case .reference: "books.vertical.fill"
        case .books: "book.closed.fill"
        case .papers: "doc.richtext.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .math: "function"
        case .expert: "person.fill.checkmark"
        case .preferences: "hand.thumbsup.fill"
        case .images: "photo.fill"
        case .video: "film.fill"
        case .audio: "music.note"
        case .speech: "waveform"
        case .robotics: "gearshape.2.fill"
        case .spatial: "cube.transparent.fill"
        case .industrial: "gauge.with.dots.needle.50percent"
        case .synthetic: "wand.and.stars"
        case .specialist: "atom"
        }
    }

    /// Text-like data counts toward the unique tokens a language model can train on; media trains its modality.
    var isText: Bool {
        switch self {
        case .images, .video, .audio, .speech, .robotics, .spatial: false
        default: true
        }
    }

    /// The modality a model needs to learn from it (nil: any model).
    var needs: CapDomain? {
        switch self {
        case .images, .video: .vision
        case .audio, .speech: .voice
        default: nil
        }
    }

    /// Bytes stored per token (text ~4; media far more), for storage and transfer bills.
    var bytesPerToken: Double {
        switch self {
        case .images: 30
        case .video: 60
        case .audio, .speech: 20
        case .robotics, .spatial, .industrial: 24
        default: 4
        }
    }

    /// Roughly how many tokens of this kind exist in the world (trillions) — the scale everything else is judged by.
    func worldTokensT(_ y: Double) -> Double {
        let pts: [(Double, Double)]
        switch self {
        case .web: pts = [(2016, 10), (2020, 60), (2024, 200), (2030, 500)]
        case .reference: pts = [(2016, 0.05), (2030, 0.12)]
        case .books: pts = [(2016, 3), (2030, 6)]
        case .papers: pts = [(2016, 0.2), (2030, 0.7)]
        case .code: pts = [(2016, 0.5), (2022, 2), (2030, 8)]
        case .math: pts = [(2016, 0.01), (2024, 0.08), (2030, 0.4)]
        case .expert: pts = [(2016, 0.0001), (2024, 0.004), (2030, 0.05)]
        case .preferences: pts = [(2018, 0.00001), (2024, 0.005), (2030, 0.06)]
        case .images: pts = [(2016, 50), (2030, 600)]
        case .video: pts = [(2016, 200), (2030, 6000)]
        case .audio: pts = [(2016, 20), (2030, 250)]
        case .speech: pts = [(2016, 10), (2030, 120)]
        case .robotics: pts = [(2016, 0.001), (2024, 0.05), (2030, 1.5)]
        case .spatial: pts = [(2016, 0.01), (2030, 3)]
        case .industrial: pts = [(2016, 0.1), (2030, 6)]
        case .synthetic: pts = [(2020, 0.01), (2024, 5), (2030, 200)]
        case .specialist: pts = [(2016, 0.05), (2030, 0.6)]
        }
        return interpolateLog(pts, at: y)
    }

    /// How much one token of this kind teaches each capability domain (CapDomain order), before quality.
    var relevance: [Double] {
        //            know  reas  math  sci   code  agent mem   vis   voice soc   robot
        switch self {
        case .web:         [0.50, 0.08, 0.02, 0.04, 0.04, 0.03, 0.05, 0.00, 0.00, 0.25, 0.00]
        case .reference:   [1.00, 0.10, 0.05, 0.15, 0.02, 0.00, 0.10, 0.00, 0.00, 0.05, 0.00]
        case .books:       [0.70, 0.15, 0.03, 0.08, 0.00, 0.00, 0.30, 0.00, 0.00, 0.30, 0.00]
        case .papers:      [0.40, 0.30, 0.40, 1.00, 0.05, 0.00, 0.10, 0.00, 0.00, 0.00, 0.00]
        case .code:        [0.05, 0.25, 0.10, 0.05, 1.00, 0.30, 0.05, 0.00, 0.00, 0.00, 0.00]
        case .math:        [0.05, 0.70, 1.00, 0.25, 0.10, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00]
        case .expert:      [0.30, 0.70, 0.40, 0.50, 0.40, 0.40, 0.00, 0.00, 0.00, 0.10, 0.00]
        case .preferences: [0.05, 0.05, 0.00, 0.00, 0.05, 0.10, 0.00, 0.00, 0.10, 1.00, 0.00]
        case .images:      [0.10, 0.00, 0.00, 0.02, 0.00, 0.00, 0.00, 1.00, 0.00, 0.00, 0.10]
        case .video:       [0.05, 0.02, 0.00, 0.02, 0.00, 0.05, 0.05, 1.00, 0.10, 0.05, 0.25]
        case .audio:       [0.02, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 1.00, 0.10, 0.00]
        case .speech:      [0.05, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 1.00, 0.30, 0.00]
        case .robotics:    [0.00, 0.05, 0.00, 0.02, 0.00, 0.40, 0.00, 0.20, 0.00, 0.00, 1.00]
        case .spatial:     [0.02, 0.05, 0.05, 0.05, 0.00, 0.10, 0.00, 0.40, 0.00, 0.00, 0.60]
        case .industrial:  [0.15, 0.10, 0.05, 0.30, 0.05, 0.25, 0.00, 0.05, 0.00, 0.00, 0.35]
        case .synthetic:   [0.20, 0.40, 0.30, 0.20, 0.30, 0.20, 0.00, 0.00, 0.00, 0.00, 0.00]
        case .specialist:  [0.30, 0.20, 0.20, 1.00, 0.05, 0.05, 0.00, 0.00, 0.00, 0.00, 0.05]
        }
    }

    /// The domains this kind of data is really for (its specialist coverage scales these).
    var primary: [CapDomain] {
        switch self {
        case .web, .reference, .books: [.knowledge]
        case .papers, .specialist: [.science]
        case .code: [.coding]
        case .math: [.math]
        case .expert: [.reasoning]
        case .preferences: [.social]
        case .images, .video: [.vision]
        case .audio, .speech: [.voice]
        case .robotics, .spatial: [.robotics]
        case .industrial: [.robotics, .science]
        case .synthetic: [.reasoning]
        }
    }
}

/// The eleven quality dimensions of a dataset, each 0–1. Duplication and contamination are bad when high.
struct DataQuality: Codable, Hashable, Sendable {
    var accuracy = 0.5
    var freshness = 0.5
    var duplication = 0.3
    var diversity = 0.5
    var language = 0.3
    var science = 0.3
    var specialist = 0.3
    var provenance = 0.8
    var licence = 0.8
    var contamination = 0.3
    var processing = 0.3

    init(acc: Double, fresh: Double, dup: Double, div: Double, lang: Double, sci: Double, spec: Double,
         prov: Double, lic: Double, contam: Double, proc: Double) {
        accuracy = acc; freshness = fresh; duplication = dup; diversity = div; language = lang; science = sci
        specialist = spec; provenance = prov; licence = lic; contamination = contam; processing = proc
    }

    /// How much a token of it is worth to training, 0–1. Provenance, licence and contamination don't make the data
    /// teach better or worse — they decide legal risk and benchmark contamination instead.
    var effective: Double {
        clamp(0.22 * accuracy + 0.08 * freshness + 0.15 * (1 - duplication) + 0.13 * diversity + 0.08 * science
              + 0.12 * specialist + 0.22 * processing, 0, 1)
    }

    /// Value weight of a quality-q token relative to a q = 0.5 one: curated data is worth many times raw crawl.
    static func weight(_ q: Double) -> Double { pow(10, 2.5 * (q - 0.5)) }

    /// Dimensions for the radar and tables: label, value, and whether a high value is good.
    var dims: [(String, Double, Bool)] {
        [("Accuracy", accuracy, true), ("Freshness", freshness, true), ("Duplication", duplication, false),
         ("Diversity", diversity, true), ("Languages", language, true), ("Sci. reliability", science, true),
         ("Specialist", specialist, true), ("Provenance", provenance, true), ("Licence terms", licence, true),
         ("Contamination", contamination, false), ("Processing", processing, true)]
    }
}

/// How a dataset can be acquired.
enum DataTerm: String, Codable, CaseIterable, Identifiable, Sendable {
    case buy, licence, perRun, exclusive, partnership
    var id: String { rawValue }
    var label: String {
        switch self {
        case .buy: "Buy outright"
        case .licence: "Time-limited licence"
        case .perRun: "Per-run licence"
        case .exclusive: "Exclusive contract"
        case .partnership: "Partnership"
        }
    }
}

/// A dataset on the market (or, if `rare`, one that only ever comes up at auction).
struct DatasetDef: Identifiable, Sendable {
    let id: String
    let name: String
    let kind: DataKind
    let seller: String
    let available: Double
    /// Size in trillions of tokens (token-equivalents for media) when it comes to market.
    let tokensT: Double
    let quality: DataQuality
    /// Outright price; licences are priced per month, per-run licences per training run.
    let price: Double
    let monthly: Double
    let perRun: Double
    let terms: [DataTerm]
    /// How much rival labs lean on it (log10 capability they lose if you lock it up exclusively).
    let rivalValue: Double
    let rare: Bool
    /// The domain it specialises in, if narrower than its kind's.
    let focus: CapDomain?
    let blurb: String

    init(_ id: String, _ name: String, _ kind: DataKind, seller: String, from: Double, tokensT: Double, q: DataQuality,
         price: Double = 0, monthly: Double = 0, perRun: Double = 0, terms: [DataTerm], rivalValue: Double = 0,
         rare: Bool = false, focus: CapDomain? = nil, _ blurb: String) {
        self.id = id; self.name = name; self.kind = kind; self.seller = seller; available = from; self.tokensT = tokensT
        quality = q; self.price = price; self.monthly = monthly; self.perRun = perRun; self.terms = terms
        self.rivalValue = rivalValue; self.rare = rare; self.focus = focus; self.blurb = blurb
    }

    /// Licence length for time-limited and exclusive deals.
    var licenceMonths: Int { rare ? 0 : 24 }
    /// Runs a per-run licence covers.
    var runs: Int { 2 }
}

/// A vendor that produces data to order: preference labels, expert demonstrations, teleoperation.
struct AnnotationVendor: Identifiable, Sendable {
    let id: String
    let name: String
    let kind: DataKind
    let focus: CapDomain?
    let available: Double
    /// Monthly cost at the base tier, and the trillions of tokens produced per month.
    let monthly: Double
    let throughputT: Double
    let quality: DataQuality
    let blurb: String
}

enum DataMarketCatalog {
    private static func q(_ acc: Double, _ fresh: Double, _ dup: Double, _ div: Double, _ lang: Double, _ sci: Double, _ spec: Double,
                          _ prov: Double, _ lic: Double, _ contam: Double, _ proc: Double) -> DataQuality {
        DataQuality(acc: acc, fresh: fresh, dup: dup, div: div, lang: lang, sci: sci, spec: spec, prov: prov, lic: lic, contam: contam, proc: proc)
    }

    static let all: [DatasetDef] = [
        // Web & reference
        DatasetDef("web_refined", "Refined web crawl", .web, seller: "an open-data foundation", from: 2019.5, tokensT: 3.0,
                   q: q(0.6, 0.6, 0.15, 0.8, 0.35, 0.3, 0.2, 0.75, 0.85, 0.45, 0.65), price: 2_500_000, terms: [.buy],
                   "Common Crawl, deduplicated and model-filtered (FineWeb-style). Far fewer tokens than the raw crawl, worth more each."),
        DatasetDef("web_bulk", "Bulk crawl extension", .web, seller: "a crawl broker", from: 2017, tokensT: 6.0,
                   q: q(0.35, 0.7, 0.55, 0.7, 0.5, 0.15, 0.1, 0.45, 0.5, 0.65, 0.15), price: 1_500_000, terms: [.buy],
                   "Six trillion raw tokens from deeper crawls: lots of unique text, lots of junk, unclear provenance."),
        DatasetDef("web_multilingual", "Multilingual web (100+ languages)", .web, seller: "a regional data consortium", from: 2020, tokensT: 4.0,
                   q: q(0.5, 0.6, 0.25, 0.9, 0.95, 0.2, 0.2, 0.7, 0.75, 0.35, 0.5), price: 9_000_000, monthly: 900_000, terms: [.buy, .licence],
                   "Native-language web from a hundred countries, not machine translation. The fix for an English-only model."),
        DatasetDef("ref_curated", "Curated encyclopedias & reference", .reference, seller: "reference publishers", from: 2016, tokensT: 0.04,
                   q: q(0.93, 0.5, 0.05, 0.7, 0.4, 0.5, 0.3, 0.95, 0.95, 0.6, 0.8), price: 3_000_000, terms: [.buy],
                   "Edited reference works and almanacs. Tiny, dense and accurate."),
        DatasetDef("news_firehose", "Real-time news firehose", .reference, seller: "a wire-service group", from: 2023, tokensT: 0.05,
                   q: q(0.8, 1.0, 0.2, 0.6, 0.5, 0.3, 0.2, 0.95, 0.9, 0.3, 0.6), monthly: 2_000_000, terms: [.licence, .partnership],
                   "Every story as it is filed. Freshness that never decays while the partnership runs."),
        DatasetDef("legal_corpus", "Case law & contracts", .specialist, seller: "a legal-research company", from: 2019, tokensT: 0.05,
                   q: q(0.9, 0.6, 0.15, 0.4, 0.2, 0.3, 0.85, 0.9, 0.85, 0.2, 0.7), price: 7_000_000, perRun: 2_000_000, terms: [.buy, .perRun],
                   focus: .knowledge, "Court opinions, statutes and annotated contracts. Lawyers' models live on this."),
        // Books & papers
        DatasetDef("textbooks", "Textbook corpus", .books, seller: "educational publishers", from: 2021, tokensT: 0.08,
                   q: q(0.92, 0.5, 0.1, 0.6, 0.3, 0.75, 0.6, 0.95, 0.85, 0.5, 0.75), price: 60_000_000, monthly: 3_000_000,
                   terms: [.buy, .licence, .exclusive], rivalValue: 0.012,
                   "University and school textbooks: the 'textbooks are all you need' data. Rivals would hate to lose it."),
        DatasetDef("fiction", "Fiction & long-form catalogue", .books, seller: "a trade-publishing group", from: 2022, tokensT: 0.3,
                   q: q(0.75, 0.5, 0.1, 0.9, 0.5, 0.1, 0.2, 0.95, 0.75, 0.2, 0.6), monthly: 4_000_000, perRun: 9_000_000,
                   terms: [.licence, .perRun, .exclusive], rivalValue: 0.008,
                   "Novels, memoirs and long-form writing. Long-context coherence and a better voice."),
        DatasetDef("journals", "Full-text journal archive", .papers, seller: "a scientific publisher", from: 2020, tokensT: 0.15,
                   q: q(0.9, 0.8, 0.1, 0.6, 0.3, 0.95, 0.7, 0.95, 0.85, 0.3, 0.7), monthly: 2_500_000,
                   terms: [.licence, .partnership, .exclusive], rivalValue: 0.012,
                   "Peer-reviewed full text, figures and supplements. A partnership keeps it current."),
        DatasetDef("patents", "Patents & technical standards", .papers, seller: "a patent-data vendor", from: 2018, tokensT: 0.12,
                   q: q(0.85, 0.6, 0.3, 0.5, 0.6, 0.6, 0.5, 0.95, 0.95, 0.2, 0.55), price: 8_000_000, terms: [.buy],
                   focus: .science, "Every patent and engineering standard: dry, precise and full of how things are actually built."),
        // Code & math
        DatasetDef("code_curated", "Curated code with tests", .code, seller: "a developer-tools company", from: 2020, tokensT: 0.06,
                   q: q(0.93, 0.7, 0.05, 0.7, 0.3, 0.4, 0.95, 0.9, 0.9, 0.25, 0.85), price: 12_000_000, perRun: 4_000_000,
                   terms: [.buy, .perRun, .exclusive], rivalValue: 0.01, focus: .coding,
                   "Small: sixty billion tokens of reviewed code, each file paired with passing tests and commit history."),
        DatasetDef("code_enterprise", "Enterprise code licence", .code, seller: "an enterprise-software vendor", from: 2023, tokensT: 0.4,
                   q: q(0.8, 0.7, 0.2, 0.6, 0.2, 0.3, 0.75, 0.9, 0.7, 0.2, 0.6), monthly: 4_000_000, perRun: 15_000_000,
                   terms: [.licence, .perRun, .exclusive], rivalValue: 0.015, focus: .coding,
                   "Private codebases from big companies, with their issue trackers. Real software, not tutorials."),
        DatasetDef("code_bulk", "Bulk repository mirror", .code, seller: "a repo-mirroring site", from: 2018, tokensT: 2.0,
                   q: q(0.45, 0.6, 0.6, 0.7, 0.2, 0.2, 0.5, 0.35, 0.4, 0.5, 0.15), price: 3_000_000, terms: [.buy],
                   "Every public repository, licences unchecked. Huge — and a lawsuit waiting to happen."),
        DatasetDef("math_proofs", "Competition math & formal proofs", .math, seller: "a maths-olympiad foundation", from: 2021, tokensT: 0.01,
                   q: q(0.95, 0.6, 0.1, 0.6, 0.3, 0.9, 0.95, 0.95, 0.9, 0.6, 0.8), price: 6_000_000, terms: [.buy, .exclusive], rivalValue: 0.008,
                   "Olympiad problems with worked solutions and machine-checked proofs. Watch the benchmark overlap."),
        // Expert
        DatasetDef("clinical_cases", "Clinical case reasoning", .expert, seller: "a hospital network", from: 2023, tokensT: 0.002,
                   q: q(0.9, 0.7, 0.05, 0.5, 0.3, 0.85, 0.95, 0.85, 0.6, 0.1, 0.7), perRun: 20_000_000, terms: [.perRun, .exclusive], rivalValue: 0.006,
                   focus: .science, "De-identified case notes with diagnoses and doctors' reasoning. Licensed run by run."),
        // Media
        DatasetDef("images_licensed", "Licensed stock image library", .images, seller: "a stock-photo agency", from: 2020, tokensT: 2.0,
                   q: q(0.85, 0.5, 0.1, 0.7, 0.5, 0.1, 0.3, 0.95, 0.9, 0.1, 0.7), monthly: 3_000_000, terms: [.licence, .exclusive], rivalValue: 0.006,
                   "Hundreds of millions of captioned, model-released photos."),
        DatasetDef("images_scraped", "Scraped image-text pairs", .images, seller: "an open dataset project", from: 2021, tokensT: 20,
                   q: q(0.4, 0.6, 0.4, 0.9, 0.6, 0.05, 0.1, 0.25, 0.3, 0.2, 0.2), price: 500_000, terms: [.buy],
                   "Billions of alt-text pairs from the web (LAION-style). Cheap, enormous, legally shaky."),
        DatasetDef("video_creators", "Creator video licensing", .video, seller: "a creator-rights collective", from: 2023, tokensT: 30,
                   q: q(0.75, 0.8, 0.2, 0.9, 0.6, 0.1, 0.2, 0.9, 0.75, 0.1, 0.5), monthly: 6_000_000, terms: [.licence, .exclusive], rivalValue: 0.01,
                   "Licensed footage from independent creators, with transcripts. The fuel for video models."),
        DatasetDef("music_library", "Music & sound library", .audio, seller: "a music label", from: 2022, tokensT: 2.0,
                   q: q(0.85, 0.5, 0.1, 0.7, 0.4, 0.05, 0.3, 0.95, 0.7, 0.05, 0.7), monthly: 2_000_000, terms: [.licence], rivalValue: 0.003,
                   "Stems, recordings and sound effects, licensed for training."),
        DatasetDef("speech_corpus", "Multilingual speech corpus", .speech, seller: "a speech-tech company", from: 2020, tokensT: 1.5,
                   q: q(0.8, 0.5, 0.1, 0.8, 0.9, 0.05, 0.3, 0.9, 0.9, 0.1, 0.6), price: 10_000_000, terms: [.buy],
                   "Transcribed conversational speech in 60 languages. Voice models that understand accents."),
        // Physical world
        DatasetDef("robot_teleop", "Teleoperation trajectory pool", .robotics, seller: "a robotics consortium", from: 2024, tokensT: 0.02,
                   q: q(0.85, 0.8, 0.1, 0.6, 0.2, 0.3, 0.9, 0.9, 0.8, 0.05, 0.6), monthly: 3_000_000, terms: [.partnership, .exclusive], rivalValue: 0.006,
                   "Shared robot-arm and humanoid demonstrations. Partners add new trajectories every month."),
        DatasetDef("spatial_scans", "3D scans & spatial maps", .spatial, seller: "a mapping company", from: 2023, tokensT: 0.3,
                   q: q(0.85, 0.6, 0.2, 0.7, 0.2, 0.3, 0.7, 0.9, 0.85, 0.05, 0.6), price: 25_000_000, terms: [.buy],
                   "Lidar scans, floor plans and street-level 3D. Spatial understanding for robots and agents."),
        DatasetDef("industrial_logs", "Industrial sensor & process logs", .industrial, seller: "an industrial conglomerate", from: 2024, tokensT: 0.5,
                   q: q(0.8, 0.7, 0.4, 0.4, 0.2, 0.5, 0.8, 0.9, 0.7, 0.05, 0.4), monthly: 2_000_000, terms: [.licence, .exclusive], rivalValue: 0.004,
                   "Decades of plant telemetry, maintenance logs and process recipes."),
        // Specialist research
        DatasetDef("bio_archive", "Protein & genomics archive", .specialist, seller: "a research institute", from: 2021, tokensT: 0.05,
                   q: q(0.9, 0.8, 0.2, 0.5, 0.2, 0.95, 0.95, 0.95, 0.9, 0.1, 0.7), monthly: 1_500_000, terms: [.partnership],
                   "Structures, sequences and assay results, with the institute's scientists annotating new releases."),
        DatasetDef("materials_notebooks", "Materials & chemistry lab notebooks", .specialist, seller: "a chemicals company", from: 2024, tokensT: 0.02,
                   q: q(0.85, 0.7, 0.1, 0.4, 0.2, 0.9, 0.95, 0.85, 0.7, 0.05, 0.6), perRun: 6_000_000, terms: [.perRun, .exclusive], rivalValue: 0.005,
                   "Synthesis recipes, failed experiments included. Failures are what models never see."),

        // Rare collections: only ever at auction or as a one-off offer.
        DatasetDef("rare_library", "A national library's digitised archive", .books, seller: "a national library", from: 2019, tokensT: 0.6,
                   q: q(0.9, 0.3, 0.1, 0.95, 0.85, 0.4, 0.4, 0.95, 0.9, 0.1, 0.7), price: 80_000_000, terms: [.exclusive], rivalValue: 0.015, rare: true,
                   "Three centuries of books, newspapers and manuscripts in dozens of languages, scanned and sold once."),
        DatasetDef("rare_monorepo", "A defunct tech giant's monorepo", .code, seller: "a bankruptcy trustee", from: 2022, tokensT: 0.3,
                   q: q(0.88, 0.6, 0.1, 0.8, 0.2, 0.3, 0.9, 0.85, 0.8, 0.1, 0.75), price: 120_000_000, terms: [.exclusive], rivalValue: 0.018, rare: true,
                   focus: .coding, "Twenty years of production code, design docs and code review from a company that no longer exists."),
        DatasetDef("rare_pharma", "A pharma giant's 40 years of lab notebooks", .specialist, seller: "a pharmaceutical company", from: 2024, tokensT: 0.03,
                   q: q(0.92, 0.5, 0.05, 0.6, 0.3, 0.97, 0.97, 0.9, 0.85, 0.05, 0.7), price: 150_000_000, terms: [.exclusive], rivalValue: 0.012, rare: true,
                   "Every compound, assay and failed trial. The kind of data discovery models are built on."),
        DatasetDef("rare_fleet", "A robotaxi fleet's driving logs", .robotics, seller: "a liquidated robotaxi company", from: 2025, tokensT: 0.2,
                   q: q(0.85, 0.6, 0.3, 0.7, 0.2, 0.2, 0.9, 0.9, 0.85, 0.05, 0.6), price: 200_000_000, terms: [.exclusive], rivalValue: 0.01, rare: true,
                   "Billions of miles of multi-camera driving with interventions labelled."),
        DatasetDef("rare_proofs", "A mathematician's unpublished proofs", .math, seller: "a mathematician's estate", from: 2018, tokensT: 0.0005,
                   q: q(0.97, 0.4, 0.0, 0.5, 0.2, 1.0, 1.0, 0.95, 0.9, 0.0, 0.6), price: 20_000_000, terms: [.exclusive], rivalValue: 0.004, rare: true,
                   "Forty years of notebooks and drafts nobody has ever seen. Zero contamination: these problems are on no benchmark."),
    ]

    static let byID: [String: DatasetDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static var market: [DatasetDef] { all.filter { !$0.rare } }
    static var rare: [DatasetDef] { all.filter(\.rare) }

    static let vendors: [AnnotationVendor] = [
        AnnotationVendor(id: "crowd_prefs", name: "Crowd preference labelling", kind: .preferences, focus: nil, available: 2019, monthly: 600_000, throughputT: 0.0002,
                         quality: q(0.6, 0.8, 0.2, 0.7, 0.5, 0.1, 0.2, 1, 1, 0.05, 0.5),
                         blurb: "Thousands of crowd workers compare model answers. Cheap, fast and noisy."),
        AnnotationVendor(id: "pro_prefs", name: "Professional raters", kind: .preferences, focus: nil, available: 2022, monthly: 2_500_000, throughputT: 0.0003,
                         quality: q(0.82, 0.8, 0.1, 0.7, 0.6, 0.3, 0.4, 1, 1, 0.05, 0.7),
                         blurb: "Trained, vetted raters with rubrics and inter-rater checks."),
        AnnotationVendor(id: "expert_code", name: "Senior engineers", kind: .expert, focus: .coding, available: 2023, monthly: 5_000_000, throughputT: 0.0002,
                         quality: q(0.92, 0.8, 0.05, 0.6, 0.2, 0.4, 0.9, 1, 1, 0.05, 0.8),
                         blurb: "Staff engineers writing worked fixes, reviews and agent traces at $150 an hour."),
        AnnotationVendor(id: "expert_math", name: "Mathematicians & olympiad coaches", kind: .expert, focus: .math, available: 2023.5, monthly: 4_000_000, throughputT: 0.0001,
                         quality: q(0.94, 0.8, 0.05, 0.6, 0.2, 0.9, 0.9, 1, 1, 0.1, 0.8),
                         blurb: "Original problems with full solutions, written to stay off the benchmarks."),
        AnnotationVendor(id: "expert_science", name: "PhD scientists", kind: .expert, focus: .science, available: 2024, monthly: 6_000_000, throughputT: 0.0001,
                         quality: q(0.92, 0.8, 0.05, 0.6, 0.2, 0.95, 0.9, 1, 1, 0.05, 0.8),
                         blurb: "Biologists, chemists and physicists explaining experiments step by step."),
        AnnotationVendor(id: "teleop", name: "Robot teleoperation crews", kind: .robotics, focus: .robotics, available: 2024.5, monthly: 6_000_000, throughputT: 0.002,
                         quality: q(0.85, 0.9, 0.1, 0.6, 0.2, 0.2, 0.9, 1, 1, 0.0, 0.6),
                         blurb: "Operators drive your robots through household and factory tasks, logging every motion."),
    ]

    static let vendorByID: [String: AnnotationVendor] = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0) })

    /// The new-system profile of each original data source (`DataCatalog`), so they appear in the inventory with
    /// quality like any other dataset. Their training effects stay exactly as before unless you process them.
    static func legacyProfile(_ id: String) -> (kind: DataKind, quality: DataQuality, tokensT: Double) {
        switch id {
        case "web": return (.web, q(0.4, 0.7, 0.45, 0.85, 0.4, 0.2, 0.1, 0.6, 0.6, 0.55, 0.3), 0)
        case "wiki": return (.reference, q(0.88, 0.7, 0.05, 0.6, 0.6, 0.4, 0.2, 0.95, 0.95, 0.6, 0.6), 0)
        case "code_open": return (.code, q(0.6, 0.7, 0.4, 0.7, 0.2, 0.2, 0.5, 0.85, 0.85, 0.4, 0.4), 0)
        case "papers": return (.papers, q(0.8, 0.8, 0.1, 0.6, 0.2, 0.75, 0.5, 0.95, 0.9, 0.4, 0.5), 0)
        case "shadow_books": return (.books, q(0.8, 0.4, 0.25, 0.9, 0.4, 0.3, 0.2, 0.05, 0.0, 0.2, 0.4), 0)
        case "books_license": return (.books, q(0.8, 0.4, 0.15, 0.85, 0.4, 0.3, 0.2, 0.95, 0.85, 0.2, 0.5), 0)
        case "news_license": return (.reference, q(0.8, 0.9, 0.2, 0.6, 0.4, 0.2, 0.2, 0.95, 0.85, 0.3, 0.5), 0)
        case "forum_license": return (.web, q(0.55, 0.9, 0.2, 0.8, 0.4, 0.2, 0.3, 0.9, 0.8, 0.4, 0.4), 0)
        case "code_license": return (.code, q(0.75, 0.7, 0.2, 0.6, 0.2, 0.3, 0.6, 0.9, 0.85, 0.3, 0.5), 0)
        case "science_license": return (.papers, q(0.88, 0.7, 0.1, 0.6, 0.2, 0.9, 0.6, 0.95, 0.85, 0.3, 0.6), 0)
        case "human_feedback": return (.preferences, q(0.65, 0.8, 0.2, 0.6, 0.4, 0.1, 0.2, 1, 1, 0.05, 0.5), 0.0005)
        case "expert_data": return (.expert, q(0.9, 0.8, 0.05, 0.6, 0.2, 0.8, 0.85, 1, 1, 0.1, 0.7), 0.002)
        case "video_license": return (.video, q(0.75, 0.6, 0.2, 0.8, 0.5, 0.1, 0.2, 0.9, 0.8, 0.1, 0.5), 0)
        default: return (.web, q(0.5, 0.5, 0.3, 0.5, 0.3, 0.3, 0.3, 0.8, 0.8, 0.3, 0.3), 0)
        }
    }
}
