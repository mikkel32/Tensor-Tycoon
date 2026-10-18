import Foundation

/// The people of AI at the start of any game: who leads the eight founding labs, who does their science, and who
/// watches, funds, reports on, regulates and criticises them. All fictional. Each person's career is a timeline of
/// beats: a game starting in 2017 meets Elena Marsh at Prometheus and sees her leave to found Halcyon in 2021.
/// After October 2026 careers are procedural (Cast).
enum CastCatalog {
    struct Beat: Sendable {
        let ym: YM
        /// Lab ID or an organisation's name.
        let org: String
        let role: String
        let kind: CastKind
        let text: String
    }

    struct Person: Sendable {
        let id: String
        let name: String
        let traits: [CastTrait]
        let voice: VoiceStyle
        let open: Double
        let safety: Double
        let regulation: Double
        let handle: String
        let region: String
        let stature: Double
        let focus: String
        let blurb: String
        var desc: String = ""
        let beats: [Beat]
    }

    static func b(_ y: Int, _ m: Int, _ org: String, _ role: String, _ kind: CastKind, _ text: String) -> Beat {
        Beat(ym: YM(y, m), org: org, role: role, kind: kind, text: text)
    }

    static let people: [Person] = labPeople + watchers

    // MARK: The founding labs

    static let labPeople: [Person] = [
        // Prometheus Labs
        Person(id: "prometheus-ceo", name: "Morgan Vale", traits: [.showman, .bold, .pragmatic], voice: .showman,
               open: -0.3, safety: 0.45, regulation: 0.2, handle: "@morganvale", region: "US", stature: 1.0, focus: "products",
               blurb: "Runs Prometheus Labs. Ships fast, talks bigger, and raises money better than anyone in the business.",
               beats: [b(2015, 12, "prometheus", "Chief executive", .leader, "Co-founded Prometheus Labs and became its chief executive.")]),
        Person(id: "prometheus-cs", name: "Anouk Verhaegen", traits: [.academic, .cautious], voice: .professor,
               open: -0.2, safety: 0.6, regulation: 0.3, handle: "@averhaegen", region: "Belgium", stature: 0.7, focus: "pre-training",
               blurb: "Prometheus's research chief. Careful with claims, ruthless with ablations.",
               beats: [b(2016, 4, "prometheus", "Research scientist", .researcher, "Joined Prometheus Labs from a robotics lab in Leuven."),
                       b(2019, 3, "prometheus", "Head of pre-training", .researcher, "Took over pre-training at Prometheus."),
                       b(2024, 7, "prometheus", "Chief scientist", .scientist, "Became Prometheus's chief scientist after Tomas Reyes left.")]),
        Person(id: "prometheus-rl", name: "Tobias Engström", traits: [.bold, .hypeProne], voice: .booster,
               open: 0, safety: 0.3, regulation: -0.3, handle: "@tobiase", region: "Sweden", stature: 0.55, focus: "reasoning RL",
               blurb: "Leads reinforcement learning for reasoning at Prometheus. Posts loss curves at 3 a.m.",
               beats: [b(2018, 2, "prometheus", "Research scientist", .researcher, "Joined Prometheus from a games-AI startup in Stockholm."),
                       b(2023, 6, "prometheus", "Reasoning lead", .researcher, "Started the team behind Prometheus's reasoning models.")]),
        Person(id: "prometheus-post", name: "Kemi Adebayo", traits: [.pragmatic, .cautious], voice: .measured,
               open: -0.1, safety: 0.55, regulation: 0.3, handle: "@kemiadebayo", region: "UK", stature: 0.5, focus: "post-training",
               blurb: "Runs post-training at Prometheus: the part that turns a raw model into one people want to talk to.",
               beats: [b(2015, 9, "deepgrove", "Research scientist", .researcher, "Joined DeepGrove's London lab."),
                       b(2020, 9, "prometheus", "Post-training lead", .researcher, "Moved to Prometheus to run post-training.")]),
        // DeepGrove
        Person(id: "deepgrove-ceo", name: "Priya Okonkwo", traits: [.academic, .cautious, .pragmatic], voice: .measured,
               open: 0, safety: 0.6, regulation: 0.4, handle: "@priyaokonkwo", region: "UK", stature: 0.95, focus: "science",
               blurb: "Co-founded DeepGrove and still runs it. A neuroscientist by training who talks about AI as a tool for science.",
               beats: [b(2010, 9, "deepgrove", "Chief executive", .leader, "Co-founded DeepGrove in London.")]),
        Person(id: "deepgrove-cs", name: "Hamish Gallacher", traits: [.academic, .contrarian], voice: .wry,
               open: 0.2, safety: 0.45, regulation: 0.2, handle: "@hgallacher", region: "UK", stature: 0.65, focus: "research",
               blurb: "DeepGrove's chief scientist. Has predicted three AI winters and enjoyed being wrong each time.",
               beats: [b(2012, 5, "deepgrove", "Research scientist", .researcher, "Joined DeepGrove from Edinburgh."),
                       b(2018, 1, "deepgrove", "Chief scientist", .scientist, "Named DeepGrove's chief scientist.")]),
        Person(id: "deepgrove-mm", name: "Mei-Ling Tsai", traits: [.bold, .academic], voice: .professor,
               open: 0.1, safety: 0.4, regulation: 0.1, handle: "@meilingtsai", region: "Taiwan", stature: 0.5, focus: "multimodal research",
               blurb: "Leads multimodal research at DeepGrove. Thinks video is the next great pre-training corpus.",
               beats: [b(2016, 9, "deepgrove", "Research scientist", .researcher, "Joined DeepGrove after a PhD on video prediction."),
                       b(2022, 3, "deepgrove", "Multimodal lead", .researcher, "Took over DeepGrove's multimodal team.")]),
        Person(id: "deepgrove-tpu", name: "Rafael Quintero", traits: [.pragmatic], voice: .numbers,
               open: 0, safety: 0.3, regulation: 0, handle: "@rquintero", region: "Mexico", stature: 0.4, focus: "TPU co-design",
               blurb: "Designs the TPU pods DeepGrove trains on, and the software that keeps them fed.",
               beats: [b(2014, 3, "deepgrove", "Infrastructure engineer", .researcher, "Joined DeepGrove's infrastructure team."),
                       b(2021, 6, "deepgrove", "Head of TPU co-design", .researcher, "Put in charge of co-designing DeepGrove's chips and models.")]),
        // Halcyon AI
        Person(id: "halcyon-ceo", name: "Elena Marsh", traits: [.cautious, .academic, .doomer], voice: .earnest,
               open: -0.6, safety: 0.9, regulation: 0.7, handle: "@elenamarsh", region: "US", stature: 0.9, focus: "safety",
               blurb: "Left Prometheus to build a lab that takes the risks seriously. Writes long essays and means every word.",
               beats: [b(2016, 3, "prometheus", "Safety research director", .researcher, "Joined Prometheus Labs to lead its safety research."),
                       b(2021, 1, "halcyon", "Chief executive", .leader, "Left Prometheus with a group of colleagues to found Halcyon AI.")]),
        Person(id: "halcyon-cs", name: "Joon-ho Baek", traits: [.academic, .cautious], voice: .professor,
               open: -0.4, safety: 0.85, regulation: 0.6, handle: "@joonhobaek", region: "Korea", stature: 0.6, focus: "interpretability",
               blurb: "Halcyon's chief scientist. Wants to read a model's mind before anyone trusts it.",
               beats: [b(2017, 5, "Bayview University", "Postdoctoral researcher", .academic, "Postdoc in interpretability at Bayview University."),
                       b(2019, 2, "prometheus", "Research scientist", .researcher, "Joined Prometheus's safety team."),
                       b(2021, 1, "halcyon", "Chief scientist", .scientist, "Co-founded Halcyon AI as its chief scientist.")]),
        Person(id: "halcyon-agents", name: "Siobhan Kearney", traits: [.pragmatic, .bold], voice: .brash,
               open: -0.2, safety: 0.5, regulation: 0.2, handle: "@siobhank", region: "Ireland", stature: 0.5, focus: "coding agents",
               blurb: "Built Halcyon's coding agents. Measures progress in pull requests merged, not benchmark points.",
               beats: [b(2019, 8, "deepgrove", "Research engineer", .researcher, "Joined DeepGrove as a research engineer."),
                       b(2022, 2, "halcyon", "Coding agents lead", .researcher, "Joined Halcyon to build its coding agents.")]),
        // Xenon AI
        Person(id: "xenon-ceo", name: "Rex Calder", traits: [.showman, .accelerationist, .contrarian], voice: .brash,
               open: 0.3, safety: 0.15, regulation: -0.8, handle: "@rexcalder", region: "US", stature: 0.95, focus: "compute",
               blurb: "Founded Xenon AI to out-build everyone. Measures clusters in football fields and enemies in followers.",
               beats: [b(2015, 6, "Calder Dynamics", "Chief executive", .investor, "Runs Calder Dynamics, a hardware conglomerate, and invests in AI on the side."),
                       b(2023, 7, "xenon", "Chief executive", .leader, "Founded Xenon AI and promised the biggest cluster on Earth within a year.")]),
        Person(id: "xenon-cs", name: "Ivo Marić", traits: [.bold, .secretive], voice: .terse,
               open: 0.2, safety: 0.25, regulation: -0.4, handle: "@ivomaric", region: "Croatia", stature: 0.5, focus: "scaling",
               blurb: "Xenon's chief scientist. Says little and ships very large training runs.",
               beats: [b(2017, 1, "deepgrove", "Research scientist", .researcher, "Joined DeepGrove's scaling team."),
                       b(2023, 7, "xenon", "Chief scientist", .scientist, "Left DeepGrove to co-found Xenon AI.")]),
        Person(id: "xenon-infra", name: "Darnell Price", traits: [.pragmatic, .showman], voice: .showman,
               open: 0.2, safety: 0.2, regulation: -0.5, handle: "@darnellbuilds", region: "US", stature: 0.45, focus: "compute",
               blurb: "Built Xenon's supercluster in record time. Has strong opinions about transformers — the electrical kind.",
               beats: [b(2016, 1, "Nimbus Cloud", "Datacentre build lead", .researcher, "Ran datacentre construction at Nimbus Cloud."),
                       b(2023, 8, "xenon", "Head of compute", .researcher, "Joined Xenon to build its supercluster.")]),
        // OpenWeights Collective
        Person(id: "openweights-ceo", name: "Jordan Pike", traits: [.bold, .pragmatic, .accelerationist], voice: .evangelist,
               open: 1.0, safety: 0.25, regulation: -0.4, handle: "@jordanpike", region: "US", stature: 0.85, focus: "open models",
               blurb: "Runs the OpenWeights Collective inside a social-media giant. Believes the safest AI is the one everyone can inspect.",
               beats: [b(2013, 12, "openweights", "Chief executive", .leader, "Set up the OpenWeights Collective inside a social-media giant.")]),
        Person(id: "openweights-cs", name: "Yannick Lefèvre", traits: [.contrarian, .academic], voice: .contrarian,
               open: 0.9, safety: 0.1, regulation: -0.5, handle: "@ylefevre", region: "France", stature: 0.8, focus: "world-model research",
               blurb: "OpenWeights' chief scientist and the loudest sceptic of his own industry's hype. Thinks text alone won't get anyone there.",
               beats: [b(2013, 12, "openweights", "Chief scientist", .scientist, "Became the OpenWeights Collective's founding chief scientist.")]),
        Person(id: "openweights-pre", name: "Aditi Rao", traits: [.pragmatic], voice: .measured,
               open: 0.8, safety: 0.35, regulation: 0, handle: "@aditirao", region: "India", stature: 0.4, focus: "pre-training",
               blurb: "Leads pre-training for OpenWeights' open models. Spends most days fighting the data, not the architecture.",
               beats: [b(2018, 5, "openweights", "Research engineer", .researcher, "Joined OpenWeights as a research engineer."),
                       b(2023, 2, "openweights", "Pre-training lead", .researcher, "Led pre-training for the first Llamina.")]),
        // Dragon Lake AI
        Person(id: "dragonlake-ceo", name: "Zhou Lan", traits: [.secretive, .pragmatic, .academic], voice: .terse,
               open: 0.9, safety: 0.2, regulation: 0, handle: "@zhoulan", region: "China", stature: 0.8, focus: "efficiency",
               blurb: "Founded Dragon Lake out of a quant fund. Rarely gives interviews and lets the papers do the talking.",
               beats: [b(2015, 2, "Lakeshore Quant", "Founder", .investor, "Ran Lakeshore Quant, a Hangzhou trading fund that bought GPUs before anyone else."),
                       b(2023, 5, "dragonlake", "Chief executive", .leader, "Spun the fund's AI team out as Dragon Lake AI.")]),
        Person(id: "dragonlake-cs", name: "Xu Wenjie", traits: [.academic, .secretive], voice: .terse,
               open: 0.9, safety: 0.25, regulation: 0, handle: "@xuwenjie", region: "China", stature: 0.45, focus: "architecture research",
               blurb: "Dragon Lake's chief scientist. The latent-attention and FP8 papers carry his name.",
               beats: [b(2019, 9, "Lakeshore Quant", "Research lead", .researcher, "Ran research at Lakeshore Quant's AI group."),
                       b(2023, 5, "dragonlake", "Chief scientist", .scientist, "Became Dragon Lake's chief scientist.")]),
        Person(id: "dragonlake-moe", name: "Lin Yutong", traits: [.bold, .academic], voice: .numbers,
               open: 0.9, safety: 0.2, regulation: 0, handle: "@linyutong", region: "China", stature: 0.35, focus: "sparse-expert research",
               blurb: "Designs Dragon Lake's mixture-of-experts models. Counts every FLOP twice.",
               beats: [b(2021, 9, "the Qiantang Institute", "PhD researcher", .academic, "Doctoral research on sparse models at the Qiantang Institute."),
                       b(2023, 6, "dragonlake", "Sparse-experts lead", .researcher, "Joined Dragon Lake to design its expert models.")]),
        // Sirocco AI
        Person(id: "sirocco-ceo", name: "Camille Durand", traits: [.pragmatic, .bold], voice: .sovereign,
               open: 0.6, safety: 0.35, regulation: -0.2, handle: "@camilledurand", region: "France", stature: 0.75, focus: "European AI",
               blurb: "Left DeepGrove's Paris office to build Europe's champion. Talks about sovereignty as often as about models.",
               beats: [b(2017, 3, "deepgrove", "Research scientist", .researcher, "Joined DeepGrove's Paris office."),
                       b(2023, 4, "sirocco", "Chief executive", .leader, "Founded Sirocco AI in Paris with two former colleagues.")]),
        Person(id: "sirocco-cs", name: "Théo Garnier", traits: [.academic, .pragmatic], voice: .professor,
               open: 0.7, safety: 0.3, regulation: 0, handle: "@theogarnier", region: "France", stature: 0.4, focus: "model efficiency",
               blurb: "Sirocco's chief scientist. Small models, clean data, no wasted parameters.",
               beats: [b(2018, 9, "openweights", "Research scientist", .researcher, "Joined OpenWeights' Paris lab."),
                       b(2023, 4, "sirocco", "Chief scientist", .scientist, "Co-founded Sirocco AI.")]),
        Person(id: "sirocco-lang", name: "Ingrid Solberg", traits: [.cautious, .academic], voice: .earnest,
               open: 0.6, safety: 0.5, regulation: 0.3, handle: "@ingridsolberg", region: "Norway", stature: 0.3, focus: "multilingual research",
               blurb: "Leads Sirocco's multilingual work. Thinks a model that only really speaks English is half a model.",
               beats: [b(2020, 1, "Lakeside Polytechnic", "Research fellow", .academic, "Research fellow in machine translation at Lakeside Polytechnic."),
                       b(2023, 9, "sirocco", "Multilingual lead", .researcher, "Joined Sirocco to lead its multilingual models.")]),
        // Aletheia Labs
        Person(id: "aletheia-ceo", name: "Tomas Reyes", traits: [.secretive, .academic, .doomer], voice: .cryptic,
               open: -0.8, safety: 0.8, regulation: 0.3, handle: "@tomasreyes", region: "Chile", stature: 0.85, focus: "superintelligence",
               blurb: "Co-founded Prometheus, then left to build Aletheia. Ships almost nothing; everyone reads everything he writes.",
               beats: [b(2015, 12, "prometheus", "Chief scientist", .scientist, "Co-founded Prometheus Labs as its chief scientist."),
                       b(2024, 6, "aletheia", "Chief executive", .leader, "Left Prometheus to found Aletheia Labs, which says it will ship nothing until it has something extraordinary.")]),
        Person(id: "aletheia-cs", name: "Noa Ben-David", traits: [.secretive, .bold], voice: .cryptic,
               open: -0.7, safety: 0.7, regulation: 0.2, handle: "@noabd", region: "Israel", stature: 0.45, focus: "research",
               blurb: "Runs Aletheia's Tel Aviv office. Hires slowly and publishes never.",
               beats: [b(2018, 4, "prometheus", "Research scientist", .researcher, "Joined Prometheus's research team."),
                       b(2024, 6, "aletheia", "Chief scientist", .scientist, "Co-founded Aletheia Labs and opened its Tel Aviv office.")]),
        Person(id: "aletheia-oversight", name: "Graham Whitfield", traits: [.academic, .doomer], voice: .alarmed,
               open: -0.6, safety: 0.85, regulation: 0.4, handle: "@gwhitfield", region: "US", stature: 0.4, focus: "oversight research",
               blurb: "Works on keeping much smarter systems honest at Aletheia. Publishes rarely; his papers get read twice.",
               beats: [b(2019, 9, "prometheus", "Research scientist", .researcher, "Joined Prometheus's alignment team."),
                       b(2024, 7, "aletheia", "Oversight lead", .researcher, "Followed Tomas Reyes to Aletheia to lead its oversight research.")]),
    ]

    // MARK: Analysts, investors, press, policy, critics

    static let watchers: [Person] = [
        Person(id: "an-liang", name: "Grace Liang", traits: [.pragmatic, .cautious], voice: .numbers,
               open: 0, safety: 0.3, regulation: 0, handle: "@graceliang", region: "US", stature: 0.7, focus: "chips and AI labs",
               blurb: "Covers chips and AI labs for Halvorsen Research. Her estimate of who owns how many GPUs is the industry's unofficial census.",
               desc: "a chips and AI analyst at Halvorsen Research",
               beats: [b(2014, 6, "Halvorsen Research", "Senior analyst", .analyst, "Started covering chips at Halvorsen Research.")]),
        Person(id: "an-owusu", name: "Ama Owusu", traits: [.pragmatic, .contrarian], voice: .numbers,
               open: 0, safety: 0.35, regulation: 0.1, handle: "@amaowusu", region: "UK", stature: 0.55, focus: "AI company finances",
               blurb: "Covers AI companies for Bridgewell Securities. Asks about margins when everyone else asks about AGI.",
               desc: "who covers AI companies for Bridgewell Securities",
               beats: [b(2016, 2, "Bridgewell Securities", "Analyst", .analyst, "Joined Bridgewell Securities' technology desk.")]),
        Person(id: "an-lindgren", name: "Oskar Lindgren", traits: [.contrarian, .bold], voice: .contrarian,
               open: 0, safety: 0.4, regulation: 0.2, handle: "@oskarshorts", region: "Sweden", stature: 0.55, focus: "bubbles",
               blurb: "Runs Fjord Capital, a hedge fund that has been betting against AI valuations for years — occasionally at the right time.",
               desc: "whose hedge fund, Fjord Capital, bets against AI valuations",
               beats: [b(2012, 1, "Fjord Capital", "Founder", .investor, "Founded Fjord Capital, a hedge fund with a taste for bubbles.")]),
        Person(id: "an-hartley", name: "Ben Hartley", traits: [.contrarian, .academic], voice: .wry,
               open: 0.3, safety: 0.4, regulation: 0.1, handle: "@computeledger", region: "US", stature: 0.5, focus: "AI economics",
               blurb: "Writes The Compute Ledger, a newsletter that turns labs' boasts into spreadsheets.",
               desc: "who writes The Compute Ledger newsletter",
               beats: [b(2018, 10, "The Compute Ledger", "Author", .analyst, "Started The Compute Ledger, a newsletter about the economics of AI.")]),
        Person(id: "an-ferreira", name: "Mateo Ferreira", traits: [.pragmatic, .cautious], voice: .measured,
               open: 0.2, safety: 0.4, regulation: 0.2, handle: "@mateoferreira", region: "Brazil", stature: 0.45, focus: "enterprise AI adoption",
               blurb: "Tracks how companies actually use AI for Tidewell Insights. Trusts deployment numbers over demos.",
               desc: "who tracks enterprise AI adoption for Tidewell Insights",
               beats: [b(2017, 8, "Tidewell Insights", "Principal analyst", .analyst, "Joined Tidewell Insights to track how companies adopt AI.")]),
        Person(id: "an-albers", name: "Katrin Albers", traits: [.academic, .contrarian], voice: .numbers,
               open: 0.1, safety: 0.45, regulation: 0.3, handle: "@katrinalbers", region: "Germany", stature: 0.45, focus: "AI infrastructure finance",
               blurb: "Covers AI infrastructure for Rheinbrücke Capital in Frankfurt. Reads datacentre lease filings for fun.",
               desc: "who covers AI infrastructure for Rheinbrücke Capital",
               beats: [b(2016, 3, "Rheinbrücke Capital", "Senior analyst", .analyst, "Joined Rheinbrücke Capital's research team in Frankfurt.")]),
        Person(id: "an-haddad", name: "Rania Haddad", traits: [.pragmatic, .cautious], voice: .numbers,
               open: -0.3, safety: 0.6, regulation: 0.4, handle: "@raniahaddad", region: "Lebanon", stature: 0.4, focus: "security",
               blurb: "Head of threat research at Bastion Threat Intel. Tracks the state hackers who want model weights.",
               desc: "head of threat research at Bastion Threat Intel",
               beats: [b(2017, 4, "Bastion Threat Intel", "Head of threat research", .analyst, "Joined Bastion Threat Intel to track state-backed hackers.")]),
        Person(id: "in-bellamy", name: "Marcus Bellamy", traits: [.hypeProne, .accelerationist, .showman], voice: .booster,
               open: 0.3, safety: 0.15, regulation: -0.6, handle: "@marcusbellamy", region: "US", stature: 0.6, focus: "venture",
               blurb: "Partner at Andromeda Ventures. Has never met an AI round he thought was too expensive.",
               desc: "a partner at Andromeda Ventures",
               beats: [b(2013, 4, "Andromeda Ventures", "Partner", .investor, "Became a partner at Andromeda Ventures.")]),
        Person(id: "in-krishnan", name: "Sunita Krishnan", traits: [.cautious, .pragmatic], voice: .measured,
               open: 0, safety: 0.45, regulation: 0.2, handle: "@sunitak", region: "India", stature: 0.5, focus: "venture",
               blurb: "Managing partner at Lightpath Partners. Backs teams with revenue and patience.",
               desc: "managing partner at Lightpath Partners",
               beats: [b(2011, 9, "Lightpath Partners", "Managing partner", .investor, "Co-founded Lightpath Partners.")]),
        Person(id: "in-russo", name: "Valentina Russo", traits: [.bold, .pragmatic], voice: .brash,
               open: 0.2, safety: 0.25, regulation: -0.3, handle: "@vrusso", region: "Italy", stature: 0.45, focus: "growth investing",
               blurb: "General partner at Kestrel Growth. Writes the biggest cheques in the room and makes sure the room knows.",
               desc: "a general partner at Kestrel Growth",
               beats: [b(2015, 5, "Kestrel Growth", "General partner", .investor, "Joined Kestrel Growth to run its late-stage fund.")]),
        Person(id: "in-almansouri", name: "Khalid Al-Mansouri", traits: [.bold, .pragmatic], voice: .sovereign,
               open: 0.2, safety: 0.3, regulation: 0, handle: "@kalmansouri", region: "UAE", stature: 0.5, focus: "sovereign investing",
               blurb: "Runs technology investments at Falcon Sovereign Fund, which wants a seat at every frontier lab's table.",
               desc: "who runs technology investments at Falcon Sovereign Fund",
               beats: [b(2016, 1, "Falcon Sovereign Fund", "Head of technology investments", .investor, "Took over technology investing at Falcon Sovereign Fund.")]),
        Person(id: "pr-okafor", name: "Rachel Okafor", traits: [.bold, .pragmatic], voice: .reporter,
               open: 0, safety: 0.4, regulation: 0.2, handle: "@rachelokafor", region: "US", stature: 0.65, focus: "the AI labs",
               blurb: "Senior reporter at The Informant. If a lab is about to ship, fire someone or raise money, she usually hears first.",
               desc: "who covers the AI labs for The Informant",
               beats: [b(2015, 3, "The Informant", "Senior reporter", .journalist, "Joined The Informant to cover the AI labs.")]),
        Person(id: "pr-weiss", name: "Daniel Weiss", traits: [.academic, .pragmatic], voice: .numbers,
               open: 0, safety: 0.3, regulation: 0, handle: "@dweiss_semi", region: "US", stature: 0.6, focus: "chips and datacentres",
               blurb: "Runs SemiReport. Counts chips, megawatts and wafers so the rest of the industry doesn't have to.",
               desc: "SemiReport's chief analyst",
               beats: [b(2013, 8, "SemiReport", "Chief analyst", .journalist, "Founded SemiReport, a research shop for chips and datacentres.")]),
        Person(id: "pr-desai", name: "Priyanka Desai", traits: [.contrarian], voice: .wry,
               open: 0.1, safety: 0.45, regulation: 0.3, handle: "@priyankadesai", region: "UK", stature: 0.5, focus: "tech money",
               blurb: "Technology columnist at The Ledger. Funny about valuations, serious about who ends up paying for them.",
               desc: "a technology columnist at The Ledger",
               beats: [b(2016, 6, "The Ledger", "Technology columnist", .journalist, "Started a technology column at The Ledger.")]),
        Person(id: "pr-brennan", name: "Tom Brennan", traits: [.pragmatic], voice: .reporter,
               open: 0, safety: 0.4, regulation: 0.1, handle: "@tombrennan", region: "Ireland", stature: 0.4, focus: "AI models",
               blurb: "AI correspondent at Circuit Weekly. Reads every model card so nobody else has to.",
               desc: "Circuit Weekly's AI correspondent",
               beats: [b(2017, 2, "Circuit Weekly", "AI correspondent", .journalist, "Became Circuit Weekly's first AI correspondent.")]),
        Person(id: "pr-fontaine", name: "Léa Fontaine", traits: [.cautious], voice: .reporter,
               open: 0.4, safety: 0.45, regulation: 0.4, handle: "@leafontaine", region: "France", stature: 0.35, focus: "European tech",
               blurb: "Technology editor at Le Réseau in Paris. Covers Europe's AI ambitions and the rules that come with them.",
               desc: "technology editor at Le Réseau in Paris",
               beats: [b(2016, 9, "Le Réseau", "Technology editor", .journalist, "Became technology editor at Le Réseau.")]),
        Person(id: "pr-mori", name: "Kenji Mori", traits: [.academic], voice: .reporter,
               open: 0.1, safety: 0.35, regulation: 0.1, handle: "@kenjimori", region: "Japan", stature: 0.35, focus: "Asia's chip supply chain",
               blurb: "Covers Asia's chip supply chain and AI labs for Pacific Wire from Tokyo.",
               desc: "Pacific Wire's Asia technology correspondent",
               beats: [b(2015, 10, "Pacific Wire", "Asia technology correspondent", .journalist, "Became Pacific Wire's Asia technology correspondent.")]),
        Person(id: "cr-hale", name: "Victor Hale", traits: [.accelerationist, .hypeProne, .showman], voice: .booster,
               open: 0.7, safety: 0.05, regulation: -1.0, handle: "@victorhale", region: "US", stature: 0.5, focus: "the singularity",
               blurb: "Hosts Escape Velocity, a podcast on which every week is the week before the singularity.",
               desc: "who hosts the Escape Velocity podcast",
               beats: [b(2019, 3, "Escape Velocity", "Podcast host", .journalist, "Launched Escape Velocity, a podcast about the coming intelligence explosion.")]),
        Person(id: "po-calloway", name: "Ruth Calloway", traits: [.cautious, .pragmatic], voice: .measured,
               open: -0.1, safety: 0.65, regulation: 0.6, handle: "@senruthcalloway", region: "US", stature: 0.6, focus: "AI law",
               blurb: "Chairs the Senate's AI subcommittee. Wants rules with teeth that don't hand the lead to anyone abroad.",
               desc: "the senator who chairs the Senate's AI subcommittee",
               beats: [b(2014, 1, "the US Senate", "Senator", .official, "Elected to the US Senate."),
                       b(2023, 2, "the US Senate", "Chair, AI subcommittee", .official, "Took the chair of the Senate's new AI subcommittee.")]),
        Person(id: "po-harlan", name: "Wes Harlan", traits: [.contrarian, .showman], voice: .brash,
               open: 0.2, safety: 0.1, regulation: -0.8, handle: "@repwesharlan", region: "US", stature: 0.5, focus: "deregulation",
               blurb: "Congressman on the House commerce committee. Thinks the best AI policy is a fast permit and a long holiday from rules.",
               desc: "a congressman on the House commerce committee",
               beats: [b(2018, 1, "the US House", "Congressman", .official, "Elected to the House on a promise to cut red tape.")]),
        Person(id: "po-hallstrom", name: "Margit Hallström", traits: [.cautious, .academic], voice: .measured,
               open: 0.2, safety: 0.6, regulation: 0.85, handle: "@mhallstrom_eu", region: "EU", stature: 0.5, focus: "European AI rules",
               blurb: "Heads the EU AI Office. Patient, precise and very hard to lobby.",
               desc: "who heads the EU AI Office",
               beats: [b(2019, 1, "the European Commission", "Director, digital policy", .official, "Joined the European Commission's digital policy directorate."),
                       b(2024, 2, "the EU AI Office", "Head of the EU AI Office", .official, "Appointed to run the new EU AI Office.")]),
        Person(id: "po-mehta", name: "Arjun Mehta", traits: [.bold, .pragmatic], voice: .sovereign,
               open: 0.6, safety: 0.3, regulation: 0.1, handle: "@arjunmehta", region: "India", stature: 0.45, focus: "India's AI mission",
               blurb: "India's minister for electronics and AI. Wants Indian models, Indian chips and Indian datacentres — in that order.",
               desc: "India's minister for electronics and AI",
               beats: [b(2019, 6, "India's IT ministry", "Minister for electronics and AI", .official, "Appointed India's minister for electronics and AI.")]),
        Person(id: "po-fang", name: "Fang Yiru", traits: [.secretive, .pragmatic], voice: .terse,
               open: 0.5, safety: 0.4, regulation: 0.5, handle: "@fangyiru", region: "China", stature: 0.35, focus: "China's AI rules",
               blurb: "Deputy director at China's internet regulator. Her statements are short and every word is chosen.",
               desc: "a deputy director at China's internet regulator",
               beats: [b(2018, 3, "China's internet regulator", "Deputy director", .official, "Named deputy director at China's internet regulator.")]),
        Person(id: "po-ashcroft", name: "Fiona Ashcroft", traits: [.academic, .cautious], voice: .earnest,
               open: -0.2, safety: 0.8, regulation: 0.7, handle: "@fionaashcroft", region: "UK", stature: 0.45, focus: "model testing",
               blurb: "Runs the London AI Safety Institute, which tests frontier models before release — when the labs let it.",
               desc: "who runs the London AI Safety Institute",
               beats: [b(2016, 10, "Bayview University", "Professor", .academic, "Professor of computer science at Bayview University."),
                       b(2023, 11, "the London AI Safety Institute", "Director", .official, "Became the first director of the London AI Safety Institute.")]),
        Person(id: "cr-achterberg", name: "Helen Achterberg", traits: [.doomer, .academic], voice: .alarmed,
               open: -0.8, safety: 1.0, regulation: 1.0, handle: "@helenachterberg", region: "Netherlands", stature: 0.6, focus: "catastrophic risk",
               blurb: "Runs the Frontier Risk Institute. Has warned about loss of control for fifteen years and sees no reason to stop.",
               desc: "who runs the Frontier Risk Institute",
               beats: [b(2012, 9, "the Frontier Risk Institute", "Director", .critic, "Founded the Frontier Risk Institute, a non-profit studying catastrophic AI risk.")]),
        Person(id: "cr-okonjo", name: "Samuel Okonjo", traits: [.contrarian, .academic], voice: .contrarian,
               open: 0.5, safety: 0.35, regulation: 0.4, handle: "@profokonjo", region: "Nigeria", stature: 0.55, focus: "what models really understand",
               blurb: "Computer scientist at Bayview University and the field's most quoted sceptic. Thinks benchmarks measure the wrong things.",
               desc: "a computer scientist at Bayview University",
               beats: [b(2010, 8, "Bayview University", "Professor of computer science", .academic, "Professor of computer science at Bayview University.")]),
        Person(id: "cr-lindqvist", name: "Maya Lindqvist", traits: [.contrarian, .cautious], voice: .activist,
               open: 0.3, safety: 0.6, regulation: 0.9, handle: "@mayalindqvist", region: "Sweden", stature: 0.4, focus: "data rights and labour",
               blurb: "Founded the Fair Data Coalition. Fights for the writers, artists and workers whose output trains the models.",
               desc: "who founded the Fair Data Coalition",
               beats: [b(2019, 4, "the Fair Data Coalition", "Founder", .critic, "Founded the Fair Data Coalition to fight for the people whose work trains AI.")]),
        Person(id: "ac-demir", name: "Yusuf Demir", traits: [.academic, .pragmatic], voice: .professor,
               open: 0.6, safety: 0.45, regulation: 0.3, handle: "@yusufdemir", region: "Turkey", stature: 0.45, focus: "benchmarks",
               blurb: "Builds benchmarks at Lakeside Polytechnic in Zurich, then watches the labs saturate them faster every year.",
               desc: "who builds benchmarks at Lakeside Polytechnic in Zurich",
               beats: [b(2014, 10, "Lakeside Polytechnic", "Professor", .academic, "Joined Lakeside Polytechnic in Zurich to work on evaluation.")]),
        Person(id: "ac-nwosu", name: "Clara Nwosu", traits: [.bold, .accelerationist], voice: .evangelist,
               open: 1.0, safety: 0.3, regulation: -0.3, handle: "@claranwosu", region: "UK", stature: 0.4, focus: "open models",
               blurb: "Runs the Open Model Foundation. Argues that open weights are a public good and secrecy is the real risk.",
               desc: "who runs the Open Model Foundation",
               beats: [b(2018, 7, "the Open Model Foundation", "Executive director", .critic, "Became executive director of the Open Model Foundation.")]),
    ]

    static let byID: [String: Person] = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })

    /// The partner who speaks for a fund in the news (only the fictional funds have one).
    static let fundVoices: [String: String] = [
        "Andromeda Ventures": "in-bellamy", "Lightpath Partners": "in-krishnan", "Kestrel Growth": "in-russo",
        "Falcon Sovereign Fund": "in-almansouri",
    ]

    // MARK: Where careers go

    static let universities = ["Bayview University", "Lakeside Polytechnic", "Northfield University", "Kingsbridge College", "the Qiantang Institute"]
    static let agencies = ["the London AI Safety Institute", "the EU AI Office", "the US AI Standards Office", "Japan's AI Safety Institute", "India's AI Mission"]
    static let advocacy = ["the Frontier Risk Institute", "the Fair Data Coalition", "the Open Model Foundation"]
    static let outlets = ["The Informant", "SemiReport", "The Ledger", "Circuit Weekly", "Le Réseau", "Pacific Wire"]

    // MARK: Anonymous accounts on the Pulse

    static let accounts: [PulseAccount] = [
        PulseAccount(handle: "@gradient_gossip", name: "gradient gossip", persona: "insider"),
        PulseAccount(handle: "@lab_insider_ish", name: "lab insider (ish)", persona: "insider"),
        PulseAccount(handle: "@quiet_rl_guy", name: "quiet RL guy", persona: "insider"),
        PulseAccount(handle: "@benchmark_skeptic", name: "benchmark skeptic", persona: "skeptic"),
        PulseAccount(handle: "@evals_are_hard", name: "evals are hard", persona: "skeptic"),
        PulseAccount(handle: "@stochastic_sam", name: "stochastic sam", persona: "skeptic"),
        PulseAccount(handle: "@kv_cache_me_outside", name: "kv cache me outside", persona: "joker"),
        PulseAccount(handle: "@sf_landlord_watch", name: "sf landlord watch", persona: "joker"),
        PulseAccount(handle: "@agi_by_tuesday", name: "agi by tuesday", persona: "joker"),
        PulseAccount(handle: "@neurips_reject", name: "neurips reject", persona: "joker"),
        PulseAccount(handle: "@compute_maxxer", name: "compute maxxer", persona: "booster"),
        PulseAccount(handle: "@vc_thread_guy", name: "vc thread guy", persona: "booster"),
        PulseAccount(handle: "@feel_the_scaling", name: "feel the scaling", persona: "booster"),
        PulseAccount(handle: "@gpu_poor", name: "gpu poor", persona: "dev"),
        PulseAccount(handle: "@prompt_archaeologist", name: "prompt archaeologist", persona: "dev"),
        PulseAccount(handle: "@tokens_per_watt", name: "tokens per watt", persona: "dev"),
        PulseAccount(handle: "@shipit_sundays", name: "ship it sundays", persona: "dev"),
        PulseAccount(handle: "@leaderboard_lawyer", name: "leaderboard lawyer", persona: "bench"),
        PulseAccount(handle: "@ablation_station", name: "ablation station", persona: "bench"),
        PulseAccount(handle: "@paper_skimmer", name: "paper skimmer", persona: "bench"),
        PulseAccount(handle: "@moe_money", name: "moe money", persona: "finance"),
        PulseAccount(handle: "@hbm_shortage", name: "hbm shortage", persona: "finance"),
        PulseAccount(handle: "@capex_watch", name: "capex watch", persona: "finance"),
        PulseAccount(handle: "@safety_card_reader", name: "safety card reader", persona: "worried"),
        PulseAccount(handle: "@alignment_anxious", name: "alignment anxious", persona: "worried"),
        PulseAccount(handle: "@p_doom_daily", name: "p(doom) daily", persona: "worried"),
    ]

    // MARK: Names for people who join the story later

    struct NamePool: Sendable {
        let first: [String]
        let last: [String]
        /// Family name first, as the press writes it.
        var familyFirst = false
    }

    static let names: [String: NamePool] = [
        "US": NamePool(first: ["Jordan", "Megan", "Ethan", "Lauren", "Caleb", "Hannah", "Marcus", "Brooke", "Wyatt", "Claire", "Dylan", "Natalie", "Grant", "Erin", "Tessa", "Owen"],
                       last: ["Whitaker", "Sullivan", "Brooks", "Holloway", "Mercer", "Prescott", "Donnelly", "Hayes", "Carver", "Barlow", "Fletcher", "Garrison", "Pruitt", "Ramsey", "Calhoun", "Abbott"]),
        "UK": NamePool(first: ["Oliver", "Imogen", "Fergus", "Niamh", "Rory", "Harriet", "Callum", "Eilidh", "Jack", "Phoebe", "Alistair", "Rosalind"],
                       last: ["Ashworth", "Kerrigan", "Doyle", "Pemberton", "Haldane", "McAllister", "Thornton", "Gallagher", "Whitlock", "Ellison", "Fairbairn", "Lockhart"]),
        "France": NamePool(first: ["Mathieu", "Camille", "Julien", "Élodie", "Antoine", "Margaux", "Lucas", "Inès", "Hugo", "Solène", "Baptiste", "Clémence"],
                           last: ["Lambert", "Rousseau", "Girard", "Bonnet", "Fournier", "Chevalier", "Mercier", "Lemoine", "Barbier", "Renard", "Faure", "Perrin"]),
        "Germany": NamePool(first: ["Lukas", "Johanna", "Felix", "Anna", "Maximilian", "Lea", "Jonas", "Clara", "Moritz", "Katharina", "Tobias", "Miriam"],
                            last: ["Brandt", "Vogel", "Hartmann", "Krüger", "Lehmann", "Zimmermann", "Wolff", "Seidel", "Engel", "Kessler", "Busch", "Albrecht"]),
        "Nordics": NamePool(first: ["Erik", "Astrid", "Henrik", "Sigrid", "Mats", "Elin", "Anders", "Liv", "Nils", "Karin", "Jens", "Maren"],
                            last: ["Nyström", "Halvorsen", "Bergqvist", "Dahl", "Lund", "Ekberg", "Sandvik", "Holm", "Strand", "Virtanen", "Aalto", "Brekke"]),
        "India": NamePool(first: ["Rohan", "Ananya", "Vikram", "Meera", "Karthik", "Divya", "Siddharth", "Lakshmi", "Nikhil", "Pooja", "Aravind", "Kavya"],
                          last: ["Iyer", "Raghavan", "Menon", "Kulkarni", "Bhatt", "Reddy", "Chatterjee", "Nair", "Joshi", "Venkatesan", "Deshpande", "Rao"]),
        "China": NamePool(first: ["Hao", "Jing", "Wei", "Xiaoyu", "Jun", "Mingzhu", "Yifan", "Ruoxi", "Zhiwei", "Shuang", "Kai", "Yuxin"],
                          last: ["Wang", "Liu", "Chen", "Zhao", "Huang", "Sun", "Ma", "Hu", "Guo", "Tang", "Song", "Deng"], familyFirst: true),
        "Japan": NamePool(first: ["Haruto", "Yui", "Sota", "Aoi", "Ren", "Mio", "Takumi", "Saki", "Daichi", "Rina"],
                          last: ["Takahashi", "Watanabe", "Ito", "Yamamoto", "Kobayashi", "Kato", "Yoshida", "Yamada", "Sasaki", "Inoue"]),
        "Korea": NamePool(first: ["Min-jun", "Seo-yeon", "Ji-hoon", "Ha-eun", "Dong-hyun", "Yu-na", "Sung-min", "Ji-woo"],
                          last: ["Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon"]),
        "West Africa": NamePool(first: ["Chinedu", "Ngozi", "Tunde", "Folake", "Emeka", "Adaeze", "Kwame", "Abena", "Kofi", "Yaa"],
                                last: ["Okonkwo", "Adeyemi", "Balogun", "Eze", "Nwachukwu", "Mensah", "Asante", "Boateng", "Ofori", "Okeke"]),
        "East Africa": NamePool(first: ["Wanjiru", "Otieno", "Amina", "Baraka", "Njeri", "Kamau"],
                                last: ["Mwangi", "Odhiambo", "Kariuki", "Achieng", "Njoroge", "Wekesa"]),
        "Brazil": NamePool(first: ["João", "Beatriz", "Rafael", "Larissa", "Thiago", "Camila", "Gustavo", "Mariana"],
                           last: ["Oliveira", "Souza", "Pereira", "Almeida", "Carvalho", "Ribeiro", "Barbosa", "Rocha"]),
        "Latin America": NamePool(first: ["Javier", "Lucía", "Andrés", "Valeria", "Diego", "Carmen", "Pablo", "Gabriela"],
                                  last: ["Herrera", "Navarro", "Morales", "Vargas", "Romero", "Castro", "Ortega", "Delgado"]),
        "Israel": NamePool(first: ["Yonatan", "Tamar", "Eitan", "Shira", "Omer", "Maya", "Itai", "Noga"],
                           last: ["Levi", "Mizrahi", "Peretz", "Biton", "Golan", "Katz", "Avraham", "Shapiro"]),
        "Turkey": NamePool(first: ["Emre", "Elif", "Kerem", "Zeynep", "Burak", "Defne"],
                           last: ["Aydın", "Şahin", "Kaya", "Öztürk", "Çelik", "Arslan"]),
        "Iran": NamePool(first: ["Reza", "Shirin", "Arash", "Niloufar", "Kian", "Parisa"],
                         last: ["Tehrani", "Karimi", "Hosseini", "Rahimi", "Moradi", "Sadeghi"]),
        "Arab": NamePool(first: ["Omar", "Leila", "Karim", "Nour", "Tarek", "Salma", "Faisal", "Huda"],
                         last: ["Haddad", "Nasser", "Farouk", "Khalil", "Saleh", "Mansour", "Qasim", "Rahman"]),
        "Poland": NamePool(first: ["Marek", "Agnieszka", "Tomasz", "Kasia", "Piotr", "Zofia"],
                           last: ["Nowak", "Kowalczyk", "Wójcik", "Kaczmarek", "Mazur", "Krawczyk"]),
        "Italy": NamePool(first: ["Luca", "Giulia", "Matteo", "Chiara", "Alessandro", "Francesca"],
                          last: ["Bianchi", "Ferrari", "Esposito", "Marino", "Greco", "Conti"]),
        "Netherlands": NamePool(first: ["Daan", "Sanne", "Bram", "Lotte", "Joris", "Femke"],
                                last: ["de Vries", "Jansen", "Bakker", "Visser", "Smit", "Mulder"]),
        "Vietnam": NamePool(first: ["Minh", "Linh", "Quang", "Thu", "Duc", "Hoa"],
                            last: ["Nguyen", "Tran", "Le", "Pham", "Hoang", "Vu"]),
    ]

    /// Where a lab in `hq` hires from, by weight. Big hubs hire from everywhere.
    static func hiringPool(_ hq: String) -> [(String, Double)] {
        let h = hq.lowercased()
        let hub: [(String, Double)] = [("US", 4), ("India", 2), ("China", 2), ("UK", 1), ("France", 0.6), ("Germany", 0.6), ("Nordics", 0.4),
                                       ("Korea", 0.8), ("West Africa", 0.6), ("Iran", 0.6), ("Israel", 0.5), ("Latin America", 0.6), ("Brazil", 0.4),
                                       ("Vietnam", 0.4), ("Turkey", 0.4), ("Poland", 0.4), ("Japan", 0.4), ("Italy", 0.3), ("Netherlands", 0.3),
                                       ("East Africa", 0.3), ("Arab", 0.3)]
        if h.contains("hangzhou") { return [("China", 10)] }
        if h.contains("tokyo") { return [("Japan", 8), ("US", 1), ("Korea", 0.5)] }
        if h.contains("seoul") { return [("Korea", 8), ("US", 1)] }
        if h.contains("bengaluru") || h.contains("hyderabad") { return [("India", 9), ("US", 1)] }
        if h.contains("abu dhabi") || h.contains("riyadh") { return [("Arab", 5), ("India", 2), ("UK", 1), ("US", 1), ("Iran", 0.5)] }
        if h.contains("tel aviv") { return [("Israel", 6), ("US", 1.5), ("France", 0.5)] }
        if h.contains("paris") && h.contains("berlin") { return [("France", 4), ("Germany", 4), ("Italy", 1), ("Poland", 1), ("Netherlands", 1)] }
        if h.contains("paris") { return [("France", 6), ("Italy", 1), ("Germany", 1), ("West Africa", 0.5), ("Arab", 0.5)] }
        if h.contains("berlin") || h.contains("zurich") { return [("Germany", 5), ("Poland", 1), ("Turkey", 1), ("Nordics", 1), ("Italy", 1)] }
        if h.contains("london") && !h.contains("mountain") { return [("UK", 5), ("India", 1.5), ("West Africa", 1), ("Poland", 0.5), ("France", 0.5)] }
        if h.contains("singapore") { return [("China", 4), ("India", 3), ("Vietnam", 1), ("UK", 1)] }
        if h.contains("montréal") || h.contains("toronto") { return [("US", 3), ("France", 2), ("India", 1), ("China", 1), ("Iran", 1)] }
        return hub
    }
}
