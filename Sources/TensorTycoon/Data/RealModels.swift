import Foundation

/// Real models from history, used as "comparable to…" anchors for forecasts.
/// Training compute from Epoch AI / published reports; capability placed to match their reported benchmark scores.
struct RealModel: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let lab: String
    let date: YM
    let flops: Double?
    let c: Double
    let reasoning: Double
    let code: Double
    let agent: Double
    let chat: Double
    let vision: Bool
    let contextK: Int

    func profile() -> ModelProfile {
        ModelProfile(key: "real-\(name)", c: c, reasoning: reasoning, code: code, agent: agent, vision: vision,
                     contextK: contextK, tuning: 0, chat: chat, safety: 55, lang: 0.15, longctx: contextK >= 128 ? 0.1 : 0,
                     vis: vision ? 0.05 : 0, audio: false)
    }
}

enum RealModels {
    static let all: [RealModel] = [
        RealModel(name: "Transformer (big)", lab: "Google", date: YM(2017, 6), flops: 2.3e19, c: -1.3, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 1),
        RealModel(name: "GPT-1", lab: "OpenAI", date: YM(2018, 6), flops: 1.8e19, c: -0.9, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 1),
        RealModel(name: "BERT-Large", lab: "Google", date: YM(2018, 10), flops: 2.9e20, c: -0.4, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 1),
        RealModel(name: "GPT-2", lab: "OpenAI", date: YM(2019, 2), flops: 1.5e21, c: 0.4, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 1),
        RealModel(name: "T5-11B", lab: "Google", date: YM(2019, 10), flops: 4.1e22, c: 1.5, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 1),
        RealModel(name: "GPT-3 175B", lab: "OpenAI", date: YM(2020, 5), flops: 3.1e23, c: 2.78, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 2),
        RealModel(name: "Gopher 280B", lab: "DeepMind", date: YM(2021, 12), flops: 6.3e23, c: 3.5, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 2),
        RealModel(name: "Chinchilla 70B", lab: "DeepMind", date: YM(2022, 3), flops: 5.8e23, c: 3.83, reasoning: 0, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 2),
        RealModel(name: "PaLM 540B", lab: "Google", date: YM(2022, 4), flops: 2.5e24, c: 3.9, reasoning: 0.1, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 2),
        RealModel(name: "ChatGPT (GPT-3.5)", lab: "OpenAI", date: YM(2022, 11), flops: 2.6e24, c: 3.95, reasoning: 0.1, code: 0, agent: 0, chat: 0.8, vision: false, contextK: 4),
        RealModel(name: "LLaMA 65B", lab: "Meta", date: YM(2023, 2), flops: 5.5e23, c: 3.65, reasoning: 0.05, code: 0, agent: 0, chat: -0.6, vision: false, contextK: 2),
        RealModel(name: "GPT-4", lab: "OpenAI", date: YM(2023, 3), flops: 2.1e25, c: 5.04, reasoning: 0.1, code: 0, agent: 0, chat: 0.8, vision: true, contextK: 32),
        RealModel(name: "Claude 2", lab: "Anthropic", date: YM(2023, 7), flops: nil, c: 4.39, reasoning: 0.1, code: 0, agent: 0, chat: 0.8, vision: false, contextK: 128),
        RealModel(name: "Llama 2 70B", lab: "Meta", date: YM(2023, 7), flops: 8.1e23, c: 3.88, reasoning: 0.1, code: 0, agent: 0, chat: 0.7, vision: false, contextK: 4),
        RealModel(name: "Mixtral 8x7B", lab: "Mistral", date: YM(2023, 12), flops: nil, c: 3.97, reasoning: 0.1, code: 0, agent: 0, chat: 0.8, vision: false, contextK: 32),
        RealModel(name: "Gemini 1.0 Ultra", lab: "Google", date: YM(2023, 12), flops: 5e25, c: 5.0, reasoning: 0.1, code: 0, agent: 0.05, chat: 0.9, vision: true, contextK: 32),
        RealModel(name: "Claude 3 Opus", lab: "Anthropic", date: YM(2024, 3), flops: nil, c: 5.08, reasoning: 0.1, code: 0.05, agent: 0.1, chat: 1.0, vision: true, contextK: 128),
        RealModel(name: "Llama 3 70B", lab: "Meta", date: YM(2024, 4), flops: 6.3e24, c: 4.65, reasoning: 0.1, code: 0.05, agent: 0.05, chat: 0.95, vision: false, contextK: 8),
        RealModel(name: "GPT-4o", lab: "OpenAI", date: YM(2024, 5), flops: nil, c: 5.38, reasoning: 0.1, code: 0.1, agent: 0.1, chat: 1.0, vision: true, contextK: 128),
        RealModel(name: "Claude 3.5 Sonnet", lab: "Anthropic", date: YM(2024, 6), flops: nil, c: 5.38, reasoning: 0.12, code: 0.2, agent: 0.15, chat: 1.0, vision: true, contextK: 128),
        RealModel(name: "Llama 3.1 405B", lab: "Meta", date: YM(2024, 7), flops: 3.8e25, c: 5.36, reasoning: 0.1, code: 0.1, agent: 0.1, chat: 1.0, vision: false, contextK: 128),
        RealModel(name: "o1", lab: "OpenAI", date: YM(2024, 12), flops: nil, c: 5.9, reasoning: 0.6, code: 0.15, agent: 0.1, chat: 1.0, vision: true, contextK: 128),
        RealModel(name: "DeepSeek-V3", lab: "DeepSeek", date: YM(2024, 12), flops: 3.4e24, c: 5.35, reasoning: 0.1, code: 0.15, agent: 0.1, chat: 1.0, vision: false, contextK: 128),
        RealModel(name: "DeepSeek-R1", lab: "DeepSeek", date: YM(2025, 1), flops: 4e24, c: 5.4, reasoning: 0.6, code: 0.15, agent: 0.1, chat: 1.0, vision: false, contextK: 128),
        RealModel(name: "Gemini 2.5 Pro", lab: "Google", date: YM(2025, 3), flops: nil, c: 6.7, reasoning: 0.6, code: 0.3, agent: 0.3, chat: 1.2, vision: true, contextK: 1000),
        RealModel(name: "o3", lab: "OpenAI", date: YM(2025, 4), flops: nil, c: 6.7, reasoning: 0.65, code: 0.3, agent: 0.3, chat: 1.2, vision: true, contextK: 128),
        RealModel(name: "Claude Opus 4", lab: "Anthropic", date: YM(2025, 5), flops: nil, c: 6.8, reasoning: 0.55, code: 0.4, agent: 0.35, chat: 1.2, vision: true, contextK: 128),
        RealModel(name: "Kimi K2", lab: "Moonshot", date: YM(2025, 7), flops: 3.0e24, c: 5.6, reasoning: 0.1, code: 0.3, agent: 0.25, chat: 1.1, vision: false, contextK: 128),
        RealModel(name: "Grok 4", lab: "xAI", date: YM(2025, 7), flops: 5e26, c: 7.0, reasoning: 0.75, code: 0.3, agent: 0.3, chat: 1.1, vision: true, contextK: 256),
        RealModel(name: "GPT-5", lab: "OpenAI", date: YM(2025, 8), flops: nil, c: 7.05, reasoning: 0.65, code: 0.35, agent: 0.35, chat: 1.25, vision: true, contextK: 400),
        RealModel(name: "Gemini 3 Pro", lab: "Google", date: YM(2025, 11), flops: nil, c: 7.4, reasoning: 0.65, code: 0.35, agent: 0.35, chat: 1.25, vision: true, contextK: 1000),
        RealModel(name: "Claude Opus 4.5", lab: "Anthropic", date: YM(2025, 11), flops: nil, c: 7.4, reasoning: 0.6, code: 0.45, agent: 0.4, chat: 1.25, vision: true, contextK: 200),
    ]

    nonisolated(unsafe) private static var cache: (String, [(RealModel, Double)])? = nil

    /// Real models scored on the given index set (cached per set).
    static func scored(on set: [Benchmark]) -> [(RealModel, Double)] {
        let key = set.map(\.id).joined(separator: ",")
        if let c = cache, c.0 == key { return c.1 }
        let out = all.map { m in (m, set.isEmpty ? 0 : set.reduce(0) { $0 + $1.score(m.profile(), noise: false) } / Double(set.count)) }
        cache = (key, out)
        return out
    }

    /// The real model whose Intelligence Index (on today's benchmarks) is closest.
    static func closest(index: Double, set: [Benchmark]) -> RealModel? {
        scored(on: set).min { abs($0.1 - index) < abs($1.1 - index) }?.0
    }
}
