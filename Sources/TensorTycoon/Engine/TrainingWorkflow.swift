import Foundation

/// Blueprints, supervised runs and recipe evidence. The existing training, intervention and scaling systems remain
/// authoritative; this file connects them into a reusable workflow instead of adding a second simulation.
enum TrainingSystems {
    static let maxBlueprints = 24
    static let maxOutcomes = 48
    static let maxRecipeLearning = 32
    static let maxObservations = 24
    static let diagnosticMilestones = [0.15, 0.45, 0.70]
    static let maxCapabilityCorrection = 0.08
    static let maxUncertaintyCut = 0.18

    /// Evidence from comparable completed recipes. A single run never moves a forecast. Nearby compute counts most;
    /// relevance fades linearly from half a decade away to zero at two decades. Two decades is a substantial
    /// extrapolation, not a hard claim that an old recipe is useless for every other purpose.
    static func evidence(_ d: ModelDesign, state s: GameState, flops: Double) -> RecipeEvidence {
        guard let learning = s.recipeLearning.first(where: { $0.signature == d.recipeSignature }) else { return RecipeEvidence() }
        let logC = log10(max(flops, 1e12))
        let relevant = learning.observations.compactMap { observation -> (RecipeObservation, Double)? in
            let distance = abs(logC - log10(max(observation.compute, 1e12)))
            let weight: Double
            if distance <= 0.5 { weight = 1 }
            else if distance >= 2 { weight = 0 }
            else { weight = 1 - (distance - 0.5) / 1.5 }
            return weight > 0 ? (observation, weight) : nil
        }.sorted {
            if $0.0.compute != $1.0.compute { return $0.0.compute < $1.0.compute }
            return $0.0.runID.uuidString < $1.0.runID.uuidString
        }
        guard !relevant.isEmpty else { return RecipeEvidence() }
        let count = min(24, relevant.count)
        let total = relevant.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return RecipeEvidence() }
        var out = RecipeEvidence(samples: count, effectiveWeight: min(12, total))
        if count >= 3 {
            out.uncertaintyCut = min(maxUncertaintyCut, 0.03 * Double(min(6, count - 2)))
        }
        guard count >= 2 else { return out }
        let mean = relevant.reduce(0.0) { $0 + $1.0.residual * $1.1 } / total
        let n = min(24, total)
        let effective = min(12, n)
        let shrinkage = effective / (effective + 6)
        out.correction = clamp(mean * shrinkage, -maxCapabilityCorrection, maxCapabilityCorrection)
        return out
    }

    /// Runs the selected supervision actions. With automation disabled this function has no random draws, mutations or
    /// spending, which keeps existing saves and unattended runs deterministic.
    static func supervise(_ s: inout GameState, _ i: Int) {
        guard s.runs.indices.contains(i), let policy = s.runs[i].automation, policy.enabled,
              s.runs[i].kind == .full, Training.isLive(s.runs[i]) else { return }

        if policy.redTeam, TrainingInterventions.redTeamBlocker(s, s.runs[i]) == nil {
            TrainingInterventions.redTeam(&s, i)
            s.runs[i].automationActions += 1
            Training.runLog(&s, i, "Supervisor red-teamed the reasoning environments before launch of the RL stage.")
        }

        if policy.investigate, s.runs[i].spikes > 0, !s.runs[i].investigated,
           !Training.awaiting(s, "loss_spike", i), TrainingInterventions.investigateBlocker(s, s.runs[i]) == nil {
            _ = TrainingInterventions.investigate(&s, i)
            s.runs[i].automationActions += 1
            Training.runLog(&s, i, "Supervisor investigated the instability after the loss-spike decision was resolved.")
        }

        guard policy.diagnostics, s.runs[i].status == .running else { return }
        for milestone in diagnosticMilestones where s.runs[i].progress >= milestone && !s.runs[i].automationMilestones.contains(milestone) {
            let cost = TrainingInterventions.diagnoseCost(s, s.runs[i]).money
            let affordable = s.runs[i].automationSpent + cost <= max(0, policy.spendingCap)
                && s.cash - cost >= max(0, policy.cashReserve)
            if affordable, TrainingInterventions.diagnoseBlocker(s, s.runs[i]) == nil {
                _ = TrainingInterventions.diagnose(&s, i)
                s.runs[i].automationSpent += cost
                s.runs[i].automationActions += 1
                s.runs[i].automationDiagnostics += 1
                s.runs[i].automationMilestones.append(milestone)
                Training.runLog(&s, i, "Supervisor completed the \(Int(milestone * 100))% diagnostic within its spending safeguards.")
            } else if !affordable {
                s.runs[i].automationMilestones.append(milestone)
                Training.runLog(&s, i, "Supervisor skipped the \(Int(milestone * 100))% diagnostic: its cash reserve or per-run spending cap protected the budget.")
            }
        }
        s.runs[i].automationMilestones.sort()
    }

    /// Captures one full run exactly once and updates its recipe's bounded evidence set.
    static func recordOutcome(_ s: inout GameState, run: TrainingRun, model: AIModel) {
        guard run.kind == .full, run.status == .done, !s.trainingOutcomes.contains(where: { $0.runID == run.id }) else { return }
        let base = run.forecast?.baseC ?? model.cForecast
        // Remove the learning rate actually earned and known incident damage. What remains is evidence about the
        // recipe, not a lesson that an unlucky hardware storm makes the architecture worse.
        let bugAdjustment = run.bugFound ? 0 : run.bugPenalty
        let adjusted = model.c - base - run.lrCreditAtEnd + run.qualityPenalty + bugAdjustment
        let residual = clamp(adjusted, -0.25, 0.25)
        let outcome = RunOutcome(runID: run.id, blueprintID: run.blueprintID, name: run.design.name,
                                 signature: run.design.recipeSignature, date: run.finished ?? s.date,
                                 compute: run.flopsTotal, forecastC: run.forecast?.c ?? model.cForecast,
                                 actualC: model.c, forecastIndex: run.forecast?.index ?? model.index,
                                 actualIndex: model.index, residual: residual, cost: run.cost,
                                 days: max(0, GameCalendar.daysBetween(run.started, run.finished ?? s.date)),
                                 incidents: run.spikes + run.interruptions, supervised: run.automation?.enabled == true,
                                 automationActions: run.automationActions, automationSpent: run.automationSpent)
        s.trainingOutcomes.append(outcome)
        s.trainingOutcomes.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.runID.uuidString < $1.runID.uuidString
        }
        if s.trainingOutcomes.count > maxOutcomes { s.trainingOutcomes.removeFirst(s.trainingOutcomes.count - maxOutcomes) }

        let observation = RecipeObservation(runID: run.id, date: outcome.date, compute: run.flopsTotal, residual: residual)
        if let ri = s.recipeLearning.firstIndex(where: { $0.signature == outcome.signature }) {
            s.recipeLearning[ri].observations.removeAll { $0.runID == run.id }
            s.recipeLearning[ri].observations.append(observation)
            s.recipeLearning[ri].observations.sort {
                if $0.compute != $1.compute { return $0.compute < $1.compute }
                return $0.runID.uuidString < $1.runID.uuidString
            }
            if s.recipeLearning[ri].observations.count > maxObservations {
                s.recipeLearning[ri].observations.removeFirst(s.recipeLearning[ri].observations.count - maxObservations)
            }
        } else {
            s.recipeLearning.append(RecipeLearning(signature: outcome.signature, observations: [observation]))
        }
        s.recipeLearning.sort {
            let a = $0.observations.map(\.date).max() ?? .distantPast
            let b = $1.observations.map(\.date).max() ?? .distantPast
            return a == b ? $0.signature < $1.signature : a < b
        }
        if s.recipeLearning.count > maxRecipeLearning { s.recipeLearning.removeFirst(s.recipeLearning.count - maxRecipeLearning) }
        if let i = s.runs.firstIndex(where: { $0.id == run.id }) {
            Training.runLog(&s, i, "Outcome recorded: adjusted recipe residual \(Fmt.trim(residual, 3)) log10 effective compute. Future comparable forecasts learn conservatively from it.")
        }
    }
}

extension GameState {
    /// Saves or replaces a blueprint. New persisted identities are allocated here, inside a state action, never while
    /// SwiftUI is merely drawing an editor draft.
    mutating func saveBlueprint(_ blueprint: RunBlueprint) -> String? {
        let name = blueprint.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Name the blueprint." }
        var bp = blueprint
        bp.name = name
        bp.automation.cashReserve = max(0, bp.automation.cashReserve)
        bp.automation.spendingCap = max(0, bp.automation.spendingCap)
        if let i = blueprints.firstIndex(where: { $0.id == bp.id }) {
            bp.created = blueprints[i].created
            bp.lastUsed = blueprints[i].lastUsed
            bp.uses = blueprints[i].uses
            blueprints[i] = bp
        } else {
            guard blueprints.count < TrainingSystems.maxBlueprints else { return "The blueprint library holds \(TrainingSystems.maxBlueprints) recipes. Delete one first." }
            bp.id = StableID.next()
            bp.created = date
            blueprints.append(bp)
        }
        return nil
    }

    mutating func deleteBlueprint(_ id: UUID) {
        blueprints.removeAll { $0.id == id }
    }

    /// Launches through the ordinary action first; only a real new run receives blueprint metadata and supervision.
    mutating func launchBlueprint(_ id: UUID) -> String? {
        guard let bi = blueprints.firstIndex(where: { $0.id == id }) else { return "Blueprint not found." }
        var bp = blueprints[bi]
        var d = bp.design
        let base = d.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? bp.name : d.name
        let used = Set(runs.map(\.design.name) + models.map(\.name))
        var candidate = base
        var suffix = 2
        while used.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        d.name = candidate
        let before = runs.map(\.id)
        if let error = startTraining(d, lr: bp.lr, checkpointEvery: bp.checkpointEvery, autoRollback: bp.autoRollback) { return error }
        guard let ri = runs.lastIndex(where: { !before.contains($0.id) && $0.kind == .full }) else { return "The run could not be created." }
        runs[ri].blueprintID = id
        runs[ri].automation = bp.automation
        bp.uses += 1
        bp.lastUsed = date
        bp.design.name = base
        blueprints[bi] = bp
        return nil
    }

    mutating func setRunAutomation(_ id: UUID, _ policy: RunAutomationPolicy) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }), Training.isLive(runs[i]) else { return "That run is no longer live." }
        runs[i].automation = policy
        Training.runLog(&self, i, policy.enabled ? "Run supervision enabled with independent cash and spending safeguards." : "Run supervision disabled; the run continues normally.")
        return nil
    }
}
