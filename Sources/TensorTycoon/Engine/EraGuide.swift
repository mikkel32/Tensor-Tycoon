import Foundation

/// What the world looks like when a game starts, what's about to happen, and how to open in this era.
/// Shown once at the start of a new game; the dashboard's "Next steps" use the same opening plan.
enum EraGuide {
    struct Step: Identifiable {
        var id: String { title }
        var title: String
        var detail: String
        var screen: Screen
        var done: Bool
    }

    struct Intro {
        var title: String
        var date: String
        var image: String
        var blurb: String
        /// The state of the world, one fact per line.
        var world: [String]
        /// Scripted history coming up in the next two years.
        var coming: [(date: Date, title: String)]
        var plan: String
        var steps: [Step]
    }

    static func intro(_ s: GameState) -> Intro {
        let era = Era.all.first { $0.id == s.eraID } ?? Era.all[0]
        let y = s.year
        var world: [String] = []
        let board = Leaderboard.entries(s, includeUnreleased: false).filter { !$0.isPlayer }
        if let top = board.max(by: { $0.index < $1.index }) {
            world.append("The best model in the world is \(top.lab)'s \(top.model) (Intelligence Index \(Fmt.score(top.index))).")
        } else {
            world.append("No lab has a language model worth the name yet: the leaderboard is yours to claim.")
        }
        world.append("All AI model providers together earn about \(Fmt.money(Macro.marketSize(y))) a year.")
        let users = Macro.chatUsers(y, chatMoment: s.chatMoment)
        world.append(users > 1e6 ? "\(Fmt.count(users)) people use AI chat assistants every week." : "Almost nobody chats with an AI yet: the consumer market doesn't exist.")
        let labs = s.competitors.filter { !$0.models.isEmpty }.count
        world.append("\(labs) rival lab\(labs == 1 ? " has" : "s have") released models; \(s.competitors.count - labs) more will appear.")
        let chips = HardwareCatalog.all.filter { Economy.canRent($0, s) || Economy.canBuy($0, s) }
            .filter { $0.cls == .datacenter || $0.cls == .tpu }.sorted { $0.bf16 > $1.bf16 }.prefix(2)
        if !chips.isEmpty {
            world.append("The best accelerators you can get: " + chips.map(\.name).joined(separator: " and ") + ".")
        }
        let soon = EventCatalog.historical.filter { $0.date > s.date && $0.date < GameCalendar.addMonths(s.date, 24) }
            .prefix(5).map { (date: $0.date, title: $0.title) }
        return Intro(title: era.title, date: era.subtitle, image: era.image, blurb: era.blurb, world: world, coming: Array(soon),
                     plan: plan(era.id), steps: steps(s))
    }

    /// How to open in each era.
    static func plan(_ era: String) -> String {
        switch era {
        case "2017":
            "The market is tiny and investors don't believe in language models yet, so money is your constraint. Research the Transformer first, train small models on rented GPUs, and raise once you have a model that beats the incumbents. Keep burn low until the scaling era opens the market."
        case "2020":
            "A 175B-parameter model is about to show what scale does, and an API business is about to exist. Get a large model out on rented A100s before the market wakes up, and raise while rates are near zero."
        case "2022":
            "A chatbot launches on 30 November and reaches 100M users in two months. Have an instruction-tuned chat model out before then and you can ride the consumer boom instead of chasing it. H100s ship in volume next year."
        default:
            "Labs measure clusters in gigawatts and the top three spend more than whole countries. Pick a niche you can win (agents, enterprise, open weights, a specialist) or raise big and build a campus. Rival Watch shows who is about to ship what."
        }
    }

    /// The opening checklist, in the order that makes sense for this era.
    static func steps(_ s: GameState) -> [Step] {
        let y = s.year
        var out: [Step] = [
            Step(title: "Queue research", detail: "The research director keeps it full; pick a focus.",
                 screen: .research, done: !s.researchQueue.isEmpty || s.researched.count > 15),
            Step(title: "Train your first model", detail: "Design it in the Model Lab; the forecast tells you what you'll get.",
                 screen: .lab, done: !s.runs.isEmpty),
            Step(title: "Release & deploy it", detail: "Give it servers and an API price. Turn on the capacity delegate to keep it served.",
                 screen: .models, done: s.models.contains { $0.released && !$0.deployments.isEmpty }),
        ]
        // A chat app only pays once people chat with AI (late 2022, or whenever you trigger it).
        if y >= 2022.6 || s.chatMoment != nil || s.bonuses.has(.chat) {
            out.append(Step(title: "Launch a chat app", detail: "Pick the model that powers your consumer product.",
                            screen: .market, done: s.chatModelID != nil))
        }
        out.append(Step(title: "Hire your team", detail: "Researchers speed up research; infra engineers keep big clusters alive.",
                        screen: .team, done: s.employees.count >= 5))
        out.append(Step(title: "Scale compute", detail: y < 2021 ? "Rent GPUs by the month; buy only when you're sure." : "Rent cloud capacity now; plan a datacenter for later.",
                        screen: .hardware, done: Economy.totalChips(s) > 64))
        out.append(Step(title: "Hand off the chores", detail: "Delegates run serving, launches, renewals and hiring on your best model.",
                        screen: .operations, done: s.ops.anyOn))
        out.append(Step(title: "Raise money", detail: "Sell equity or borrow to fund bigger runs.",
                        screen: .funding, done: s.rounds.count > 1 || !s.loans.isEmpty))
        return out
    }
}
