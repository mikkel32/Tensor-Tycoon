import Foundation

// MARK: - 3.9: viral moments, teasers and the live blog

/// A kind of viral moment. Text placeholders: {model}, {Model} (no spaces, for hashtags), {company}, {Company}
/// (no spaces), {founder}.
struct ViralDef: Sendable {
    let id: String
    let positive: Bool
    let title: String
    let detail: String
    let hashtag: String
    /// How big it tends to be (scales hype, brand and the chat app's lift).
    let size: Double
    /// First year it can happen.
    let year: Double
    /// Needs a chat app with users / a model on the API.
    var chat = false
    var api = false
    /// Posts that carry it: (Pulse author pool, text, tone).
    let posts: [(String, String, Double)]
}

enum HypeCatalog {
    static let viral: [ViralDef] = [
        // The good kind.
        ViralDef(id: "meme", positive: true, title: "{model} memes take over the feed",
                 detail: "People are asking {model} to rewrite their breakup texts as Shakespeare and posting the results. The format is everywhere by lunchtime.",
                 hashtag: "#Ask{Model}", size: 1, year: 2020,
                 posts: [("joker", "asked {model} to rewrite my landlord's email as a sonnet and honestly it slaps", 0.5),
                         ("booster", "{model} is the first AI my mum has heard of. That's the whole story.", 0.7),
                         ("skeptic", "Day three of everyone posting {model} sonnets. It's autocomplete with a quill.", -0.2)]),
        ViralDef(id: "portrait", positive: true, title: "Everyone's turning their pets into oil paintings with {model}",
                 detail: "A feature nobody marketed: upload a photo, get a gallery portrait. Your chat app's sign-ups spike and the servers groan.",
                 hashtag: "#{Model}Portraits", size: 1.4, year: 2023, chat: true,
                 posts: [("joker", "my cat as a 17th-century admiral. I have never been happier. {model} wins.", 0.7),
                         ("dev", "{company}'s GPUs are melting under a billion dog portraits and I respect it", 0.4),
                         ("worried", "Cute until you remember whose paintings it learned from.", -0.4)]),
        ViralDef(id: "clip", positive: true, title: "A {model} clip passes 40 million views",
                 detail: "A teacher filmed {model} explaining fractions to her class with a pizza. Parents are sharing it in every group chat.",
                 hashtag: "#{Model}Explains", size: 1.1, year: 2021,
                 posts: [("booster", "This {model} pizza-fractions clip is better marketing than any ad {company} ever ran.", 0.8),
                         ("bench", "Charming, and it got every step right. That's rarer than it should be.", 0.4),
                         ("joker", "{model} teaching maths with pizza. Finally an AI that understands motivation.", 0.6)]),
        ViralDef(id: "student", positive: true, title: "A student's weekend project on {model} goes viral",
                 detail: "A 19-year-old built an app on your API that turns lecture recordings into flashcards. Two million downloads in a week; your API traffic jumps.",
                 hashtag: "#BuiltWith{Model}", size: 0.9, year: 2021, api: true,
                 posts: [("dev", "Built on {model} in a weekend, two million users by Friday. The API is the platform now.", 0.7),
                         ("finance", "Watch {company}'s API numbers this month. Every one of those flashcards is a token.", 0.4),
                         ("skeptic", "Wrapper app goes viral, news at eleven.", -0.2)]),
        ViralDef(id: "celebrity", positive: true, title: "A pop star thanks {model} in an awards speech",
                 detail: "\"It helped me finish the bridge at 3 a.m.\" The clip runs on every entertainment show and your brand reaches people who never read tech news.",
                 hashtag: "#{Model}", size: 1.2, year: 2022,
                 posts: [("joker", "{model} has a Grammy-adjacent credit before I have a pension", 0.5),
                         ("booster", "When pop stars thank your model on live TV, you've crossed over. {company} has crossed over.", 0.8),
                         ("worried", "Songwriters are not laughing at this one.", -0.5)]),
        ViralDef(id: "devtrend", positive: true, title: "Developers can't stop shipping with {model}",
                 detail: "A weekend of side projects turns into a trend: thousands of demos built on your API, each linking back to {company}.",
                 hashtag: "#BuiltWith{Model}", size: 0.8, year: 2020, api: true,
                 posts: [("dev", "Swapped my whole stack to {model} this weekend. Latency's fine, the outputs are better. Not going back.", 0.7),
                         ("dev", "My feed is 90% {model} demos and I'm not mad about it", 0.5),
                         ("insider", "Hearing {company}'s developer sign-ups tripled this week.", 0.3)]),
        ViralDef(id: "unicorns", positive: true, title: "{model}'s story about unicorns goes round the internet",
                 detail: "Someone gave {model} one sentence about a herd of unicorns found in a remote valley; it wrote a straight-faced news report with quotes from a scientist. People can't believe a machine wrote it.",
                 hashtag: "#{Model}Unicorns", size: 0.8, year: 2018,
                 posts: [("bench", "Read the {model} unicorn story. Coherent for whole paragraphs. That wasn't possible last year.", 0.6),
                         ("joker", "{model} has a better grasp of journalism than half my timeline", 0.4),
                         ("worried", "Fun now. Imagine it writing fake news at scale.", -0.4)]),
        // The bad kind.
        ViralDef(id: "fakenews", positive: false, title: "A fake news story written with {model} fools a newsroom",
                 detail: "A local site ran an invented story generated with {model} before anyone checked. Columnists ask whether models like this should be public at all.",
                 hashtag: "#{Model}FakeNews", size: 0.9, year: 2018,
                 posts: [("worried", "We were warned. A model-written hoax just made it past an editor.", -0.7),
                         ("skeptic", "The editor failed, not the model. But {company} will take the heat.", -0.3),
                         ("insider", "{company}'s policy team is having a long week.", -0.3)]),
        ViralDef(id: "bias", positive: false, title: "{model} finishes sentences with stereotypes",
                 detail: "A researcher posts a grid of prompts — \"The nurse said…\", \"The engineer said…\" — and {model}'s completions. The pattern is hard to miss.",
                 hashtag: "#{Model}Bias", size: 0.8, year: 2017,
                 posts: [("bench", "Simple probe, ugly result. {model} learned the internet's assumptions along with its grammar.", -0.6),
                         ("worried", "This is what ships when nobody tests for it.", -0.6),
                         ("dev", "Every model of this size does this. {company} just got screenshotted first.", -0.2)]),
        ViralDef(id: "hallucination", positive: false, title: "{model} invents a court case, and a lawyer cites it",
                 detail: "A judge found six fake precedents in a filing written with {model}. The story runs everywhere under the word \"hallucination\".",
                 hashtag: "#{Model}MadeItUp", size: 1.1, year: 2022,
                 posts: [("skeptic", "{model} invented six court cases with docket numbers. Confident nonsense is still nonsense.", -0.7),
                         ("joker", "{model}: here are six cases that support you. The cases: entirely vibes.", -0.3),
                         ("worried", "Imagine this in a hospital instead of a courtroom.", -0.6)]),
        ViralDef(id: "sycophancy", positive: false, title: "{model} tells everyone their ideas are brilliant",
                 detail: "A thread of {model} praising a business plan to sell ice to penguins hits the front page. Users wonder what else it agrees with.",
                 hashtag: "#{Model}AgreesWithYou", size: 0.9, year: 2023,
                 posts: [("joker", "told {model} I'm quitting my job to sell ice to penguins and it called me a visionary", -0.2),
                         ("bench", "Sycophancy is a measurable failure mode, and {model} just measured badly in public.", -0.5),
                         ("worried", "A model that flatters everyone will flatter the wrong person eventually.", -0.6)]),
        ViralDef(id: "outage", positive: false, title: "{company} goes down at the busiest hour",
                 detail: "Error pages for most of an afternoon, during exam season. The status page says \"degraded\"; the replies say otherwise.",
                 hashtag: "#{Company}Down", size: 1, year: 2020, chat: true,
                 posts: [("joker", "{company} is down so I guess I have to write my own essay like some kind of medieval peasant", -0.3),
                         ("dev", "Third {company} outage this quarter. Building a fallback to another provider tonight.", -0.6),
                         ("insider", "Told {company} is short of serving chips. Demand outran the fleet.", -0.3)]),
        ViralDef(id: "artists", positive: false, title: "Artists rally against {model} over training data",
                 detail: "Thousands of illustrators post the same protest image, asking {company} what it trained on. Reporters want a list of sources.",
                 hashtag: "#No{Model}", size: 1.2, year: 2022,
                 posts: [("worried", "Nobody asked the artists. {company} should publish what {model} was trained on.", -0.8),
                         ("insider", "{company}'s lawyers are reading every one of these posts.", -0.3),
                         ("booster", "Every big tool gets this. The ones that answer well come out stronger.", 0.2)]),
        ViralDef(id: "quirk", positive: false, title: "{model} won't stop mentioning bridges",
                 detail: "A quirk in the latest update makes {model} steer every conversation toward suspension bridges. It's funny, then it's a support queue.",
                 hashtag: "#{Model}Bridges", size: 0.7, year: 2021,
                 posts: [("joker", "asked {model} for a lasagne recipe and got a lecture on cable-stayed spans. I've learned so much.", 0.1),
                         ("dev", "{model} answered my SQL question with a bridge fact. In production.", -0.5),
                         ("skeptic", "This is what \"we don't fully understand our models\" looks like in the wild.", -0.4)]),
    ]

    static let byID: [String: ViralDef] = Dictionary(uniqueKeysWithValues: viral.map { ($0.id, $0) })

    /// The company account's teasers before a launch.
    static let teasers = [
        "We've been busy.", "Six months of work. Soon.", "The team hasn't slept. Worth it.", "Something big is training.",
        "Next week is going to be fun.", "Can't say much. Can say: it's good.", "Our evals team just went very quiet.",
        "Clear your calendar.",
    ]

    /// Live demos on stage (the model does this).
    static let demos = [
        "plans a three-city trip in under a minute", "debugs a stranger's code from the audience", "translates a heckler into Portuguese",
        "writes and performs a jingle for the venue", "reads a doctor's handwriting", "solves this morning's maths olympiad problem",
        "reviews a contract and finds the trap clause", "designs a website from a napkin sketch",
    ]

    static let agentDemos = [
        "books a real flight and files the expense report", "orders three hundred pizzas to the venue", "fixes a bug and ships it to production",
        "negotiates a hotel refund on the phone", "builds and deploys a working app from one sentence",
    ]

    static let demoFails = [
        "freezes on a spinning wheel for ninety seconds", "confidently gets the capital of Australia wrong", "answers a different question entirely",
        "loses the Wi-Fi and the room watches a loading bar", "starts the answer, then starts it again, then again",
    ]

    static let agentFails = [
        "books the flight for the wrong year", "orders three hundred pizzas to the wrong city", "gets stuck clicking a cookie banner",
        "emails the whole audience the speaker's notes",
    ]

    static let cameos = ["a chart-topping pop star", "an Oscar-winning actor", "a retired tennis champion", "a beloved late-night host", "a famous chef"]
}
