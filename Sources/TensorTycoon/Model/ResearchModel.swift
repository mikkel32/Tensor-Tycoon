import Foundation

/// What the research director picks next when it fills your queue.
enum ResearchFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced, capability, efficiency, product, safety, agents, cheapest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .capability: "Smarter models"
        case .efficiency: "Cheaper compute"
        case .product: "Product & revenue"
        case .safety: "Safety"
        case .agents: "Agents"
        case .cheapest: "Quick wins"
        }
    }

    var symbol: String {
        switch self {
        case .balanced: "circle.grid.cross.fill"
        case .capability: "brain"
        case .efficiency: "gauge.with.dots.needle.67percent"
        case .product: "cart.fill"
        case .safety: "checkmark.shield.fill"
        case .agents: "figure.walk.motion"
        case .cheapest: "hare.fill"
        }
    }

    var blurb: String {
        switch self {
        case .balanced: "A bit of everything, cheapest useful work first."
        case .capability: "Architecture, scaling, reasoning and data: anything that raises capability."
        case .efficiency: "Systems, inference and training efficiency: more from every chip."
        case .product: "Serving, multimodal, chat quality and demand."
        case .safety: "Safety, interpretability and alignment."
        case .agents: "Tools, agents, swarms and long-horizon work."
        case .cheapest: "Whatever finishes fastest. Clears old published techniques in days."
        }
    }

    func weight(_ c: ResearchCategory) -> Double {
        switch self {
        case .balanced, .cheapest: return 1
        case .capability:
            switch c {
            case .architecture, .optimization, .reasoning, .data, .frontier: return 2.5
            case .postTraining, .science: return 1.4
            default: return 0.6
            }
        case .efficiency:
            switch c {
            case .systems, .inference, .optimization: return 2.5
            case .architecture: return 1.3
            default: return 0.6
            }
        case .product:
            switch c {
            case .inference, .multimodal, .postTraining: return 2.5
            case .agents: return 1.4
            default: return 0.6
            }
        case .safety:
            switch c {
            case .safety, .postTraining: return 3
            default: return 0.6
            }
        case .agents:
            switch c {
            case .agents, .reasoning: return 2.5
            case .frontier: return 1.5
            default: return 0.6
            }
        }
    }
}

/// A licence you sold on one of your unique breakthroughs.
struct ExoticLicense: Codable, Identifiable, Hashable {
    var id = UUID()
    var techID: String
    var buyerID: String
    var buyerName: String
    var signed: Date
    var upfront: Double
    var royaltyMonthly: Double
    var monthsLeft: Int
}
