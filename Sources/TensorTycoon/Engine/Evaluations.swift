import Foundation

/// 3.4: dangerous-capability evaluations for a model that is already trained: a checkpoint forked mid-run, a distilled
/// student, or a model trained without the evaluation stage. A run with the evaluation stage needs none of this. An
/// evaluated model is safe from the EU AI Act's fines and counts toward the lab's safety record.
enum Evaluations {
    /// Red-teamers, contracted evaluators and the compute they use, start to finish.
    static let days = 21

    /// Counts as evaluated: evaluated by its run or afterwards, or trained before 3.4 (when a lab with the research
    /// was taken to evaluate everything it shipped).
    static func isEvaluated(_ s: GameState, _ m: AIModel) -> Bool {
        m.evaluated || (!m.archV2 && s.researched.contains("evals_rsp"))
    }

    /// About 1% of what training the model cost (real labs spend roughly that on pre-release evaluations), at least
    /// $250K; a model with no run on record is priced from its size.
    static func cost(_ s: GameState, _ m: AIModel) -> Double {
        let training = s.runs.first { $0.modelID == m.id }?.cost ?? 0
        let bySize = 250_000 * (1 + m.design.paramsB / 50).squareRoot()
        return min(5e7, max(250_000, training * 0.01, bySize))
    }

    static func blocker(_ s: GameState, _ m: AIModel) -> String? {
        if isEvaluated(s, m) { return "\(m.name) has been evaluated." }
        if let due = m.evalDue { return "Evaluations under way: results on \(due.gameShort)." }
        if !s.researched.contains("evals_rsp") { return "Research Dangerous-Capability Evals first." }
        let c = cost(s, m)
        if s.cash < c { return "Evaluations cost \(Fmt.money(c)): not enough cash." }
        return nil
    }

    /// Results come in: the model is evaluated, a little safer, and the safety team's findings go into the model card.
    static func daily(_ s: inout GameState) {
        for i in s.models.indices {
            guard let due = s.models[i].evalDue, s.date >= due else { continue }
            s.models[i].evalDue = nil
            s.models[i].evaluated = true
            s.models[i].safety = min(100, s.models[i].safety + 3)
            Sim.news(&s, "\(s.models[i].name) passes its capability evaluations",
                     "Red-teamers and outside evaluators finished their dangerous-capability tests. The results are in the model card, and the model meets the EU AI Act's evaluation duty.",
                     .company, good: true)
        }
    }
}

extension GameState {
    /// Commission dangerous-capability evaluations for a trained model (`Evaluations.days`, paid up front).
    mutating func evaluateModel(_ id: UUID) -> String? {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return "No such model." }
        if let why = Evaluations.blocker(self, models[i]) { return why }
        let c = Evaluations.cost(self, models[i])
        cash -= c
        month.costOther += c
        models[i].evalDue = GameCalendar.addDays(date, Evaluations.days)
        return nil
    }
}
