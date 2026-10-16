import SwiftUI

/// Capability thresholds modelled on the real frontier-safety policies: Anthropic's Responsible Scaling Policy (ASL levels),
/// OpenAI's Preparedness Framework ("High"/"Critical") and Google DeepMind's Frontier Safety Framework (critical capability levels).
/// Calibrated so o1 (Sep 2024) sits at "early warning" and the spring-2025 frontier crosses "High" — Anthropic switched on
/// ASL-3 protections for Claude Opus 4 in May 2025 and OpenAI treated ChatGPT Agent as High biological capability that July.
enum DangerTier: Int, Comparable, CaseIterable {
    case below, earlyWarning, high, critical

    static func < (a: DangerTier, b: DangerTier) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .below: "Below thresholds"
        case .earlyWarning: "Early warning"
        case .high: "High (ASL-3-class)"
        case .critical: "Critical (ASL-4-class)"
        }
    }

    var color: Color {
        switch self {
        case .below: .green
        case .earlyWarning: .yellow
        case .high: .orange
        case .critical: .red
        }
    }

    var detail: String {
        switch self {
        case .below: "No meaningful uplift for weapons or cyberattacks."
        case .earlyWarning: "Evals show growing hazardous knowledge. Keep testing every checkpoint."
        case .high: "Could meaningfully help a novice cause serious harm. Needs hardened safeguards before release."
        case .critical: "Could enable catastrophic misuse or autonomous replication. Only releasable with the strongest protections."
        }
    }

    /// Model safety score needed to ship with adequate safeguards.
    var requiredSafety: Double {
        switch self {
        case .below, .earlyWarning: 0
        case .high: 62
        case .critical: 78
        }
    }
}

enum SafetyFramework {
    /// Thresholds on the dangerous-capability axis (c + 0.6·reasoning + 0.3·code + 0.3·agent).
    static let thresholds: [(DangerTier, Double)] = [(.earlyWarning, 6.3), (.high, 7.2), (.critical, 8.8)]

    static func dangerX(_ p: ModelProfile) -> Double { p.c + 0.6 * p.reasoning + 0.3 * p.code + 0.3 * p.agent }

    static func tier(_ p: ModelProfile) -> DangerTier {
        let x = dangerX(p)
        return thresholds.last { x >= $0.1 }?.0 ?? .below
    }

    static func tier(_ m: AIModel) -> DangerTier { tier(Leaderboard.profile(m)) }

    /// 0–1 position on a gauge from 5.5 to 9.5.
    static func gauge(_ x: Double) -> Double { clamp((x - 5.5) / 4, 0, 1) }

    /// Does this model meet the safeguard bar for its tier?
    static func meetsBar(_ m: AIModel) -> Bool { m.safety >= tier(m).requiredSafety }

    /// Release-time handling: safeguards cost serving throughput; skipping them costs trust and invites incidents.
    static func onRelease(_ s: inout GameState, _ i: Int) {
        let m = s.models[i]
        let t = tier(m)
        guard t >= .high else { return }
        if m.safety >= t.requiredSafety {
            s.models[i].safeguards = true
            s.models[i].efficiencyBoost -= t == .critical ? 0.15 : 0.08
            s.brand = min(100, s.brand + 1)
            Sim.news(&s, "\(m.name) ships under \(t == .critical ? "ASL-4" : "ASL-3")-class safeguards",
                     "Misuse classifiers, hardened weights security and staged rollout. Serving costs a little more, but regulators and enterprise buyers are reassured.",
                     .company, good: true)
        } else {
            s.models[i].unsafeRelease = true
            s.brand = max(0, s.brand - (t == .critical ? 10 : 5))
            s.regulatoryFlags.insert("unsafe_release")
            Sim.news(&s, "Safety researchers alarmed by \(m.name)",
                     "It crossed the \(t.label) threshold but shipped with a safety score of \(Int(m.safety)) (needs \(Int(t.requiredSafety))). Expect more misuse incidents and regulatory scrutiny.",
                     .company, important: true, good: false)
        }
    }
}
