import Foundation

enum Screen: String, CaseIterable, Identifiable, Hashable {
    case dashboard, operations, strategy, security, lab, training, models, leaderboard, rivals, rivalWatch, benchmarks, rsi, swarms, xeno
    case hardware, partners, compute, datacenters, silicon
    case research, team, data
    case market, industry, chipSales, competitors, finance, funding
    case news, achievements, credits
    case help
    case world   // 3.4: world and stakeholders
    case milestones, products   // 3.4: capabilities and milestones
    case pulse   // 3.4: the people of AI
    case events   // 3.5: conferences, challenges, hackathons, records
    case advancedProjects   // 3.5
    case semiconductors   // 3.5: chip design, fabs, supply chain and sales

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .operations: "Operations"
        case .strategy: "Strategy & Traits"
        case .security: "Security & Policy"
        case .lab: "Model Lab"
        case .training: "Training Runs"
        case .models: "Models & Serving"
        case .leaderboard: "Leaderboard"
        case .rivals: "Rivals"
        case .rivalWatch: "Rival Watch"
        case .benchmarks: "Benchmarks"
        case .rsi: "Self-Improvement Lab"
        case .swarms: "Agent Swarms"
        case .xeno: "Alien Tech"
        case .hardware: "Hardware Store"
        case .compute: "Compute Fleet"
        case .datacenters: "Datacenters & Power"
        case .silicon: "Custom Silicon"
        case .partners: "Compute Partners"
        case .research: "Research"
        case .team: "Team"
        case .data: "Training Data"
        case .market: "Market & Products"
        case .industry: "AI Industry"
        case .chipSales: "Chip & Cloud Sales"
        case .competitors: "Rival Labs"
        case .finance: "Finance"
        case .funding: "Funding & Equity"
        case .news: "News"
        case .pulse: "The Pulse"
        case .achievements: "Achievements"
        case .credits: "Credits & Sources"
        case .help: "Help & Glossary"
        case .world: "World & Standing"
        case .milestones: "AI Milestones"
        case .products: "Product Lines"
        case .events: "Events & Records"
        case .advancedProjects: "Advanced Projects"
        case .semiconductors: "Semiconductors"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .operations: "gearshape.2.fill"
        case .strategy: "theatermasks.fill"
        case .security: "lock.shield.fill"
        case .lab: "flask.fill"
        case .training: "chart.line.downtrend.xyaxis"
        case .models: "cube.box.fill"
        case .leaderboard: "trophy.fill"
        case .rivals: "flag.2.crossed.fill"
        case .rivalWatch: "binoculars.fill"
        case .benchmarks: "checklist.checked"
        case .rsi: "arrow.triangle.2.circlepath.circle.fill"
        case .swarms: "person.3.sequence.fill"
        case .xeno: "atom"
        case .hardware: "cart.fill"
        case .compute: "cpu.fill"
        case .datacenters: "building.columns.fill"
        case .silicon: "memorychip.fill"
        case .partners: "signature"
        case .research: "lightbulb.fill"
        case .team: "person.3.fill"
        case .data: "externaldrive.fill"
        case .market: "chart.pie.fill"
        case .industry: "building.columns.circle.fill"
        case .chipSales: "shippingbox.fill"
        case .competitors: "building.2.fill"
        case .finance: "dollarsign.circle.fill"
        case .funding: "banknote.fill"
        case .news: "newspaper.fill"
        case .pulse: "bubble.left.and.bubble.right.fill"
        case .achievements: "medal.fill"
        case .credits: "info.circle.fill"
        case .help: "questionmark.circle.fill"
        case .world: "globe.americas.fill"
        case .milestones: "signpost.right.fill"
        case .products: "square.grid.2x2.fill"
        case .events: "trophy.circle.fill"
        case .advancedProjects: "building.columns.circle"
        case .semiconductors: "circle.grid.cross.fill"
        }
    }

    /// The sidebar. The Rivals hub has one entry; `.competitors`, `.rivalWatch` and `.industry` open its Labs, Watch and
    /// Industry tabs (links from alerts, briefings and the Chief of Staff still use them).
    static let sections: [(String, [Screen])] = [
        ("Company", [.dashboard, .operations, .strategy, .security, .world, .news, .pulse]),
        ("Build AI", [.lab, .training, .models, .rsi, .swarms, .xeno]),
        ("Evaluate", [.leaderboard, .milestones, .events, .rivals, .benchmarks]),
        ("Infrastructure", [.hardware, .partners, .compute, .datacenters, .silicon]),
        ("R&D", [.research, .team, .data]),
        ("Business", [.market, .products, .advancedProjects, .semiconductors, .chipSales, .finance, .funding]),
        ("More", [.help, .achievements, .credits]),
    ]
}
