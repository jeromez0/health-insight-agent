// InsightService.swift
// HealthInsightAgent
//
// Orchestrates the two inference modes — single-shot (one LLM call) and
// multi-agent (3 parallel specialist calls + 1 orchestrator call).

import Foundation
import Combine

@MainActor
final class InsightService: ObservableObject {

    @Published var isRunning = false
    @Published var lastResult: InsightResult?
    @Published var errorMessage: String?

    private let client = OpenAIClient.shared

    func run(mode: InsightMode) async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        let started = Date()

        do {
            let result: InsightResult
            switch mode {
            case .singleShot:
                result = try await runSingleShot(startedAt: started)
            case .multiAgent:
                result = try await runMultiAgent(startedAt: started)
            }
            lastResult = result
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    // MARK: - Single-shot

    private func runSingleShot(startedAt: Date) async throws -> InsightResult {
        let payload = MockData.renderFullWeek()
        let result = try await client.complete(
            system: AgentPrompts.singleShotSystem,
            user: payload,
            temperature: 0.4
        )
        return InsightResult(
            mode: .singleShot,
            insights: result.text,
            llmCallCount: 1,
            totalInputTokens: result.inputTokens,
            totalOutputTokens: result.outputTokens,
            wallClockSeconds: Date().timeIntervalSince(startedAt),
            timestamp: Date(),
            specialistOutputs: [:]
        )
    }

    // MARK: - Multi-agent

    private func runMultiAgent(startedAt: Date) async throws -> InsightResult {
        // Stage 1: three specialists in parallel.
        async let nutritionTask = client.complete(
            system: AgentPrompts.nutritionAgentSystem,
            user: MockData.renderNutritionOnly(),
            temperature: 0.3
        )
        async let trainingTask = client.complete(
            system: AgentPrompts.trainingAgentSystem,
            user: MockData.renderTrainingOnly(),
            temperature: 0.3
        )
        async let recoveryTask = client.complete(
            system: AgentPrompts.recoveryAgentSystem,
            user: MockData.renderRecoveryOnly(),
            temperature: 0.3
        )

        let (nutrition, training, recovery) = try await (nutritionTask, trainingTask, recoveryTask)

        // Stage 2: orchestrator integrates.
        let orchestratorInput = """
        SPECIALIST AGENT SUMMARIES:

        --- NUTRITION SPECIALIST ---
        \(nutrition.text)

        --- TRAINING SPECIALIST ---
        \(training.text)

        --- RECOVERY SPECIALIST ---
        \(recovery.text)

        --- RAW DATA (for cross-referencing) ---
        \(MockData.renderFullWeek())
        """

        let orchestrator = try await client.complete(
            system: AgentPrompts.orchestratorSystem,
            user: orchestratorInput,
            temperature: 0.4
        )

        let totalIn = nutrition.inputTokens + training.inputTokens + recovery.inputTokens + orchestrator.inputTokens
        let totalOut = nutrition.outputTokens + training.outputTokens + recovery.outputTokens + orchestrator.outputTokens

        return InsightResult(
            mode: .multiAgent,
            insights: orchestrator.text,
            llmCallCount: 4,
            totalInputTokens: totalIn,
            totalOutputTokens: totalOut,
            wallClockSeconds: Date().timeIntervalSince(startedAt),
            timestamp: Date(),
            specialistOutputs: [
                "Nutrition": nutrition.text,
                "Training": training.text,
                "Recovery": recovery.text,
            ]
        )
    }
}
