import Foundation

// MARK: - 3.4: the AI milestones race

/// A first that the whole field races for. Reached when one released model meets every threshold (domain scores on the
/// capability scale). `year` is when it happened in the real world, or when forecasters expect it.
struct MilestoneDef: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let year: Double
    /// Happened in the real world (by `year`); otherwise a projection.
    let real: Bool
    let needs: [(CapDomain, Double)]
    /// 1: notable, 2: headline, 3: historic. Sets news prominence and the brand bump.
    let tier: Int
    let symbol: String

    var whenLabel: String {
        let y = Int(year)
        let m = min(12, max(1, Int(((year - Double(y)) * 12).rounded(.down)) + 1))
        return GameCalendar.date(y, m, 1).gameMonth
    }
}

enum MilestoneCatalog {
    private static func m(_ id: String, _ title: String, _ year: Double, real: Bool = true, tier: Int = 1, _ symbol: String,
                          _ needs: [(CapDomain, Double)], _ detail: String) -> MilestoneDef {
        MilestoneDef(id: id, title: title, detail: detail, year: year, real: real, needs: needs, tier: tier, symbol: symbol)
    }

    static let all: [MilestoneDef] = [
        // MARK: 2018–2020
        m("reading_parity", "Reads better than people", 2018.05, "text.book.closed.fill", [(.knowledge, 39)],
          "Answers questions about Wikipedia passages more accurately than the human testers."),
        m("translation_parity", "Human-parity translation", 2018.2, "globe", [(.knowledge, 39.2)],
          "Translates Chinese news into English as well as professional translators, judged blind."),
        m("convincing_article", "Writes a convincing news article", 2019.15, tier: 2, "newspaper.fill", [(.social, 50.5)],
          "Readers can't reliably tell its articles from ones written by journalists."),
        m("science_exam", "Passes an 8th-grade science exam", 2019.7, "graduationcap.fill", [(.science, 54)],
          "Scores over 90% on a state 8th-grade science exam, diagrams and all."),
        m("few_shot", "Learns a task from a few examples", 2020.4, tier: 2, "sparkles", [(.reasoning, 74.5)],
          "Picks up translation, arithmetic and word games from a handful of examples in the prompt, with no training."),
        // MARK: 2021–2023
        m("code_from_spec", "Writes working code from a spec", 2021.55, tier: 2, "chevron.left.forwardslash.chevron.right", [(.coding, 78)],
          "Turns a plain-English description into a function that passes its unit tests most of the time."),
        m("grade_math", "Solves grade-school word problems", 2022.45, "function", [(.math, 87.5)],
          "Gets four out of five multi-step arithmetic word problems right."),
        m("open_conversation", "Holds an open conversation", 2022.9, tier: 3, "bubble.left.and.bubble.right.fill", [(.social, 94.5), (.knowledge, 92.5)],
          "Good enough that a hundred million people talk to it every week as a general assistant."),
        m("medical_exam", "Passes the medical licensing exam", 2022.95, tier: 2, "cross.case.fill", [(.science, 93.5), (.knowledge, 92.5)],
          "Clears the pass mark on licensing-exam questions for doctors."),
        m("bar_exam", "Passes the bar exam", 2023.2, tier: 2, "building.columns.fill", [(.knowledge, 99), (.reasoning, 99)],
          "Scores around the 90th percentile of human takers on the bar exam, essays included."),
        m("sees_images", "Understands photos and charts", 2023.2, "eye.fill", [(.vision, 98.5)],
          "Explains a meme, reads a chart and describes what's in a photo."),
        m("reads_novel", "Reads a whole novel at once", 2023.4, "books.vertical.fill", [(.memory, 92)],
          "Answers detailed questions about a 300-page book held entirely in its context."),
        // MARK: 2024
        m("video_minute", "Generates a minute of realistic video", 2024.15, tier: 2, "film.fill", [(.vision, 107)],
          "A one-minute clip from a text prompt that holds together from shot to shot."),
        m("realtime_voice", "Talks in real time", 2024.37, tier: 2, "waveform", [(.voice, 110)],
          "Holds a spoken conversation with natural timing, interruptions and emotion."),
        m("imo_silver", "Silver medal at the Math Olympiad", 2024.55, tier: 2, "medal", [(.math, 105)],
          "Solves enough International Mathematical Olympiad problems for a silver medal."),
        m("phd_science", "Beats PhDs on PhD-level science", 2024.7, tier: 2, "atom", [(.science, 116)],
          "Outscores domain PhDs on search-proof biology, chemistry and physics questions."),
        m("half_of_issues", "Fixes half of real GitHub issues", 2024.85, "wrench.and.screwdriver.fill", [(.coding, 114)],
          "Resolves half of a set of verified, real-world software issues, end to end."),
        m("novel_puzzles", "Human-level on novel puzzles", 2024.97, tier: 2, "puzzlepiece.extension.fill", [(.reasoning, 115)],
          "Matches typical human scores on visual puzzles it has never seen before."),
        // MARK: 2025
        m("hour_task", "Finishes an hour-long task on its own", 2025.2, "timer", [(.agents, 123)],
          "Succeeds half the time at software tasks that take a skilled engineer an hour."),
        m("tidies_home", "Tidies a home it has never seen", 2025.3, "house.fill", [(.robotics, 98.5)],
          "Drives a robot through a stranger's kitchen and bedroom, putting things away, start to finish."),
        m("turing_test", "Passes a Turing test", 2025.25, tier: 2, "person.fill.questionmark", [(.social, 124.5)],
          "Judged human more often than the actual humans in five-minute text conversations."),
        m("out_persuades", "Out-persuades people", 2025.35, "megaphone.fill", [(.social, 127)],
          "Changes people's minds more often than human debaters given the same brief."),
        m("diagnosis", "Out-diagnoses doctors", 2025.5, tier: 2, "stethoscope", [(.science, 127.5), (.knowledge, 118)],
          "Solves hard published clinical cases far more often than experienced physicians working alone."),
        m("imo_gold", "Gold medal at the Math Olympiad", 2025.55, tier: 3, "medal.fill", [(.math, 126)],
          "Solves five of six International Mathematical Olympiad problems, in natural language, inside the time limit."),
        m("icpc_gold", "Wins the world programming finals", 2025.7, tier: 2, "trophy.fill", [(.coding, 133)],
          "Solves more problems than any human team at the world programming championship finals."),
        m("open_problem", "Settles an open math problem", 2025.85, tier: 2, "lightbulb.max.fill", [(.math, 135.5), (.reasoning, 130)],
          "Resolves a problem from a famous list of open questions that had stood for decades."),
        // MARK: 2026 and on
        m("computer_human", "Uses a computer as well as a person", 2026.15, tier: 2, "macwindow", [(.agents, 146), (.vision, 139)],
          "Matches human success at everyday tasks across real desktop apps."),
        m("workday_task", "An autonomous 8-hour software task", 2026.4, tier: 2, "clock.fill", [(.agents, 151), (.coding, 143)],
          "Succeeds half the time at tasks that take a skilled engineer a full working day."),
        m("runs_business", "Runs a small business for a month", 2026.75, real: false, tier: 2, "storefront.fill", [(.agents, 158), (.social, 145)],
          "Stocks, prices and sells from a real shop for a month — and ends it in profit."),
        m("superforecaster", "Superhuman forecasting", 2027.0, real: false, tier: 2, "chart.line.uptrend.xyaxis", [(.reasoning, 150.5), (.knowledge, 135)],
          "Beats teams of the best human forecasters on live questions about world events."),
        m("week_project", "Delivers a week-long software project", 2027.3, real: false, tier: 2, "calendar", [(.agents, 164), (.coding, 153.5)],
          "Builds a working product from a spec — a week of senior-engineer work — with nobody watching."),
        m("drug_to_trial", "Designs a drug that reaches human trials", 2027.6, real: false, tier: 2, "pills.fill", [(.science, 162)],
          "A molecule it designed, with no chemist in the loop, is dosed in a clinical trial."),
        m("factory_shift", "Works a full factory shift", 2027.8, real: false, tier: 2, "gearshape.2.fill", [(.robotics, 130)],
          "A humanoid it controls works an 8-hour production shift with no human help."),
        m("year_memory", "Remembers a year of your life", 2027.9, real: false, "archivebox.fill", [(.memory, 157)],
          "Recalls and reasons over a year of conversations, documents and meetings without forgetting."),
        m("remote_worker", "Does a remote worker's job", 2028.2, real: false, tier: 3, "laptopcomputer", [(.agents, 178), (.coding, 164), (.social, 158)],
          "Delivers most real freelance projects — design, code, analysis, video — at client quality."),
        m("feature_film", "Makes a feature film", 2028.5, real: false, tier: 2, "film.stack.fill", [(.vision, 158), (.social, 160)],
          "Writes, generates, edits and scores a 90-minute film that audiences pay to see."),
        m("ai_scientist", "An autonomous AI scientist", 2028.7, real: false, tier: 3, "flask.fill", [(.science, 180), (.agents, 186)],
          "Runs a research programme for months — hypotheses, experiments, papers — that experts rate as strong PhD work."),
        m("month_project", "A month of autonomous work", 2029.0, real: false, tier: 2, "calendar.badge.clock", [(.agents, 188)],
          "Runs a month-long engineering project with no human help and ships it."),
        m("ai_researcher", "Automates AI research", 2029.4, real: false, tier: 3, "cpu.fill", [(.coding, 175), (.reasoning, 178), (.agents, 191)],
          "Does the work of a frontier lab's best research engineers, end to end."),
        m("major_conjecture", "Proves a major open conjecture", 2029.7, real: false, tier: 3, "infinity", [(.math, 194)],
          "Settles a famous conjecture mathematicians worked on for decades, with a machine-checked proof."),
        m("household_robot", "A household robot", 2030.2, real: false, tier: 3, "house.and.flag.fill", [(.robotics, 173), (.social, 173.5)],
          "Does laundry, dishes and tidying in any home, safely, for weeks at a time."),
        m("robot_surgeon", "Operates on its own", 2031.0, real: false, tier: 2, "cross.case.fill", [(.robotics, 180), (.science, 206)],
          "Performs a routine operation on a patient with the surgeon only watching."),
        m("expert_everywhere", "Expert-level at everything", 2031.3, real: false, tier: 3, "graduationcap.fill",
          [(.knowledge, 166), (.reasoning, 188), (.science, 205), (.coding, 185), (.social, 180), (.vision, 182)],
          "Matches a top human expert in every field tested, from law and surgery to physics and poetry."),
        m("nobel_discovery", "A Nobel-calibre discovery", 2032.0, real: false, tier: 3, "star.fill", [(.science, 209), (.reasoning, 191)],
          "Makes a scientific discovery of the kind that wins Nobel prizes, credited to the model."),
        m("superhuman_all", "Superhuman in every domain", 2034.0, real: false, tier: 3, "sparkles",
          [(.knowledge, 178), (.reasoning, 200.5), (.math, 215), (.science, 218), (.coding, 197), (.agents, 217), (.memory, 201),
           (.vision, 194), (.voice, 194.5), (.social, 192), (.robotics, 195.5)],
          "Better than the best humans at everything anyone has thought to test."),
    ]

    static let byID: [String: MilestoneDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
