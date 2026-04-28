// Models.swift
// HealthInsightAgent
//
// Domain types for personal health data + LLM insight outputs.

import Foundation

// MARK: - Health data

struct DailyMacros: Codable, Identifiable {
    let date: String
    let calories: Int?
    let protein_g: Int?
    let carbs_g: Int?
    let fat_g: Int?
    let saturated_fat_g: Double?
    let fiber_g: Int?
    let sodium_mg: Int?
    let potassium_mg: Int?

    var id: String { date }
}

struct DailyWorkout: Codable, Identifiable {
    let date: String
    let type: String       // "push", "pull", "lower", or "rest"
    let mainLift: String?  // e.g. "Bench Press"
    let sets: Int?
    let reps: Int?
    let weightLbs: Int?

    var id: String { date }

    var summary: String {
        guard let lift = mainLift, let sets, let reps, let weight = weightLbs else {
            return "rest day"
        }
        return "\(type) — \(lift) \(sets)x\(reps) @ \(weight)lbs"
    }
}

struct DailyGarmin: Codable, Identifiable {
    let date: String
    let restingHr: Int?
    let hrvMs: Int?
    let hrvPercent: Int?
    let bodyBatteryLow: Int?
    let bodyBatteryHigh: Int?
    let totalSteps: Int?
    let trainingReadiness: Int?
    let readinessLevel: String?
    let recoveryHours: Int?

    var id: String { date }
}

struct WeekHealthData: Codable {
    let macros: [DailyMacros]
    let workouts: [DailyWorkout]
    let garmin: [DailyGarmin]
}

// MARK: - Insight output

enum InsightMode: String, CaseIterable, Identifiable {
    case singleShot = "Single-shot"
    case multiAgent = "Multi-agent"

    var id: String { rawValue }
}

struct InsightResult: Identifiable {
    let id = UUID()
    let mode: InsightMode
    let insights: String
    let llmCallCount: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let wallClockSeconds: Double
    let timestamp: Date
    let specialistOutputs: [String: String]  // empty for single-shot

    var totalTokens: Int { totalInputTokens + totalOutputTokens }

    var costEstimateUsd: Double {
        // gpt-4o-mini: $0.15/1M input, $0.60/1M output
        let inCost = Double(totalInputTokens) * 0.15 / 1_000_000
        let outCost = Double(totalOutputTokens) * 0.60 / 1_000_000
        return inCost + outCost
    }
}
