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
        /// 3.5: starter-quest key (FoundingKit.questReward); rewards are paid only in games with quests on.
        var key: String = ""
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
        /// 3.5: the founding cards you chose (empty without a kit).
        var kit: [FoundingCard] = []
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
        // 3.5: the time traveller's notes see twice as far ahead.
        let foresight = s.kit.contains("time_traveller")
        let soon = EventCatalog.historical.filter { $0.date > s.date && $0.date < GameCalendar.addMonths(s.date, foresight ? 48 : 24) }
            .prefix(foresight ? 10 : 5).map { (date: $0.date, title: $0.title) }
        return Intro(title: era.title, date: era.subtitle, image: era.image, blurb: era.blurb, world: world, coming: Array(soon),
                     plan: s.isPublicProgram ? publicPlan : plan(era.id), steps: steps(s), kit: FoundingKit.cards(s.kit))
    }

    /// 3.10: how to open as a government AI branch, in any era.
    static let publicPlan = "You run a government AI branch: no investors and no shares. You start with a 100 MW national compute facility full of GPUs, its power paid by the ministry, and a budget every quarter. Deliver the two public missions for payments and promotions, build models for the agencies that order them, and when you need more money, GPUs or power, ask the government on Funding & Commissions: it's granted on the spot, with tasks to deliver."

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
        if s.isPublicProgram { return publicSteps(s) }
        let y = s.year
        var out: [Step] = [
            Step(title: "Queue research", detail: "The research director keeps it full; pick a focus.",
                 screen: .research, done: !s.researchQueue.isEmpty || s.researched.count > 15, key: "research"),
            Step(title: "Train your first model", detail: "Design it in the Model Lab; the forecast tells you what you'll get.",
                 screen: .lab, done: !s.runs.isEmpty, key: "train"),
            Step(title: "Ship an API", detail: "Release a model, give it servers and an API price. Turn on the capacity delegate to keep it served.",
                 screen: .models, done: s.models.contains { $0.released && !$0.deployments.isEmpty }, key: "ship"),
        ]
        // A chat app only pays once people chat with AI (late 2022, or whenever you trigger it).
        if y >= 2022.6 || s.chatMoment != nil || s.bonuses.has(.chat) {
            out.append(Step(title: "Launch a chat app", detail: "Pick the model that powers your consumer product.",
                            screen: .market, done: s.chatModelID != nil, key: "chat"))
        }
        out.append(Step(title: "Hire your team", detail: "Researchers speed up research; infra engineers keep big clusters alive.",
                        screen: .team, done: s.employees.count >= 5, key: "hire"))
        out.append(Step(title: "Scale compute", detail: y < 2021 ? "Rent GPUs by the month; buy only when you're sure." : "Rent cloud capacity now; plan a datacenter for later.",
                        screen: .hardware, done: Economy.totalChips(s) > 64, key: "compute"))
        out.append(Step(title: "Hand off the chores", detail: "Delegates run serving, launches, renewals and hiring on your best model.",
                        screen: .operations, done: s.ops.anyOn, key: "ops"))
        out.append(Step(title: "Raise money", detail: "Sell equity or borrow to fund bigger runs.",
                        screen: .funding, done: s.rounds.count > 1 || !s.loans.isEmpty, key: "raise"))
        // 3.5: starter quests add a few goals past the basics.
        if FoundingKit.questsActive(s) {
            out.append(Step(title: "Open an RL lab", detail: "Reinforcement learning sharpens reasoning and agents. Build it on the Research page.",
                            screen: .research, done: s.rlLabLevel > 0, key: "rl"))
            out.append(Step(title: "First $1M month", detail: "Earn a million dollars of revenue in one month.",
                            screen: .finance, done: s.history.contains { $0.revenue >= 1e6 }, key: "million"))
            out.append(Step(title: "Break into the top 10", detail: "Release a model that ranks in the world's top ten.",
                            screen: .leaderboard, done: s.history.contains { $0.rank > 0 && $0.rank <= 10 }, key: "top10"))
            out.append(Step(title: "First profitable month", detail: "Revenue beats running costs for a whole month.",
                            screen: .finance, done: s.history.contains { $0.revenue > 0 && $0.revenue > $0.opex }, key: "profit"))
        }
        return out
    }

    /// 3.10: a government branch's opening: research, a model, missions, an agency order and its first funding request.
    static func publicSteps(_ s: GameState) -> [Step] {
        let p = s.publicProgram
        var out: [Step] = [
            Step(title: "Queue research", detail: "Finished research is the first thing the committee looks for. Pick a focus.",
                 screen: .research, done: !s.researchQueue.isEmpty || s.researched.count > 15, key: "research"),
            Step(title: "Train your first model", detail: "Design it in the Model Lab; the forecast tells you what you'll get.",
                 screen: .lab, done: !s.runs.isEmpty, key: "train"),
            Step(title: "Grow the team", detail: "Researchers speed up research; ML engineers make training cheaper.",
                 screen: .team, done: s.employees.count >= 6, key: "hire"),
            Step(title: "Accept an agency order", detail: "Ministries order models built for them, paid to build and to run.",
                 screen: .publicFunding, done: p.commissions.contains { $0.accepted != nil }, key: "commission"),
            Step(title: "Deliver a public mission", detail: "The Public Programme page shows your two missions and what each needs.",
                 screen: .publicProgram, done: p.completedMissions > 0, key: "mission"),
            Step(title: "Ask the government", detail: "Request funding, GPUs or power on Funding & Commissions; it comes with tasks.",
                 screen: .publicFunding, done: !p.grants.isEmpty, key: "bid"),
        ]
        if FoundingKit.questsActive(s) {
            out.append(Step(title: "Open an RL lab", detail: "Reinforcement learning sharpens reasoning and agents. Build it on the Research page.",
                            screen: .research, done: s.rlLabLevel > 0, key: "rl"))
            out.append(Step(title: "Deliver an agency model", detail: "Hand a model that clears the bar to the agency that ordered it.",
                            screen: .publicFunding, done: p.commissionsDelivered > 0, key: "agency"))
            out.append(Step(title: "Become a National programme", detail: "Three delivered missions, with oversight and safety high enough, expands the programme.",
                            screen: .publicProgram, done: p.level >= 2, key: "level2"))
        }
        return out
    }
}
