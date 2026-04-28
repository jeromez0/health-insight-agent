// MockData.swift
// HealthInsightAgent
//
// 7 days of mock personal health data (Apr 19-25, 2026) extracted from
// real self-tracking logs. Some fields are partial — represents
// realistic real-world data quality (rest days have no workout entry,
// some macros days have incomplete logs).

import Foundation

enum MockData {

    static let week = WeekHealthData(
        macros: [
            DailyMacros(date: "2026-04-19", calories: nil, protein_g: nil, carbs_g: nil, fat_g: nil, saturated_fat_g: nil, fiber_g: nil, sodium_mg: nil, potassium_mg: nil),
            DailyMacros(date: "2026-04-20", calories: 2050, protein_g: 145, carbs_g: 180, fat_g: 75, saturated_fat_g: 22, fiber_g: 28, sodium_mg: 2400, potassium_mg: 2800),
            DailyMacros(date: "2026-04-21", calories: 2210, protein_g: 162, carbs_g: 195, fat_g: 80, saturated_fat_g: 25, fiber_g: 31, sodium_mg: 2200, potassium_mg: 3100),
            DailyMacros(date: "2026-04-22", calories: 1850, protein_g: 130, carbs_g: 160, fat_g: 70, saturated_fat_g: 19, fiber_g: 24, sodium_mg: 1900, potassium_mg: 2500),
            DailyMacros(date: "2026-04-23", calories: 1920, protein_g: 138, carbs_g: 172, fat_g: 72, saturated_fat_g: 20, fiber_g: 26, sodium_mg: 2100, potassium_mg: 2650),
            DailyMacros(date: "2026-04-24", calories: 2110, protein_g: 123, carbs_g: 175, fat_g: 107, saturated_fat_g: 39, fiber_g: 32, sodium_mg: 1528, potassium_mg: 2635),
            DailyMacros(date: "2026-04-25", calories: 1915, protein_g: 121, carbs_g: 115, fat_g: 107, saturated_fat_g: 43, fiber_g: 9, sodium_mg: 2761, potassium_mg: 1485),
        ],
        workouts: [
            DailyWorkout(date: "2026-04-19", type: "pull",  mainLift: "Weighted Pull-ups", sets: 4, reps: 6, weightLbs: 25),
            DailyWorkout(date: "2026-04-20", type: "push",  mainLift: "Bench Press",       sets: 3, reps: 8, weightLbs: 205),
            DailyWorkout(date: "2026-04-21", type: "lower", mainLift: "Front Squats",      sets: 3, reps: 5, weightLbs: 205),
            DailyWorkout(date: "2026-04-22", type: "rest",  mainLift: nil, sets: nil, reps: nil, weightLbs: nil),
            DailyWorkout(date: "2026-04-23", type: "rest",  mainLift: nil, sets: nil, reps: nil, weightLbs: nil),
            DailyWorkout(date: "2026-04-24", type: "rest",  mainLift: nil, sets: nil, reps: nil, weightLbs: nil),
            DailyWorkout(date: "2026-04-25", type: "push",  mainLift: "Bench Press",       sets: 3, reps: 5, weightLbs: 225),
        ],
        garmin: [
            DailyGarmin(date: "2026-04-19", restingHr: 55, hrvMs: 36, hrvPercent: 90,  bodyBatteryLow: 46, bodyBatteryHigh: 100, totalSteps: 2188, trainingReadiness: 85,  readinessLevel: "HIGH",  recoveryHours: 1),
            DailyGarmin(date: "2026-04-20", restingHr: 57, hrvMs: 35, hrvPercent: 80,  bodyBatteryLow: 43, bodyBatteryHigh: 48,  totalSteps: 131,  trainingReadiness: 72,  readinessLevel: "MODERATE", recoveryHours: 8),
            DailyGarmin(date: "2026-04-21", restingHr: 56, hrvMs: 37, hrvPercent: 100, bodyBatteryLow: 37, bodyBatteryHigh: 87,  totalSteps: 3032, trainingReadiness: 100, readinessLevel: "PRIME", recoveryHours: 1),
            DailyGarmin(date: "2026-04-22", restingHr: 53, hrvMs: 37, hrvPercent: 100, bodyBatteryLow: 44, bodyBatteryHigh: 90,  totalSteps: 599,  trainingReadiness: 94,  readinessLevel: "HIGH", recoveryHours: 0),
            DailyGarmin(date: "2026-04-23", restingHr: 58, hrvMs: 38, hrvPercent: 91,  bodyBatteryLow: 46, bodyBatteryHigh: 52,  totalSteps: 128,  trainingReadiness: 94,  readinessLevel: "HIGH", recoveryHours: 0),
            DailyGarmin(date: "2026-04-24", restingHr: 57, hrvMs: 40, hrvPercent: 81,  bodyBatteryLow: 15, bodyBatteryHigh: 76,  totalSteps: 2275, trainingReadiness: 91,  readinessLevel: "HIGH", recoveryHours: 1),
            DailyGarmin(date: "2026-04-25", restingHr: 56, hrvMs: 39, hrvPercent: 85,  bodyBatteryLow: 25, bodyBatteryHigh: 80,  totalSteps: 1850, trainingReadiness: 88,  readinessLevel: "HIGH", recoveryHours: 1),
        ]
    )

    /// Render the entire week as a structured plain-text payload for an LLM.
    static func renderFullWeek() -> String {
        var lines: [String] = []
        lines.append("PERSONAL HEALTH DATA — 7 DAYS (2026-04-19 to 2026-04-25)\n")

        lines.append("=== NUTRITION (DAILY MACROS) ===")
        for m in week.macros {
            if m.calories == nil {
                lines.append("\(m.date): no log")
            } else {
                lines.append("\(m.date): \(m.calories ?? 0) cal · \(m.protein_g ?? 0)p / \(m.carbs_g ?? 0)c / \(m.fat_g ?? 0)f · sat fat \(m.saturated_fat_g ?? 0)g · fiber \(m.fiber_g ?? 0)g · sodium \(m.sodium_mg ?? 0)mg · potassium \(m.potassium_mg ?? 0)mg")
            }
        }
        lines.append("")

        lines.append("=== TRAINING (WORKOUTS) ===")
        for w in week.workouts {
            lines.append("\(w.date): \(w.summary)")
        }
        lines.append("")

        lines.append("=== RECOVERY (GARMIN) ===")
        for g in week.garmin {
            lines.append("\(g.date): readiness \(g.trainingReadiness ?? 0) (\(g.readinessLevel ?? "—")) · HRV \(g.hrvMs ?? 0)ms / \(g.hrvPercent ?? 0)% · resting HR \(g.restingHr ?? 0) · body battery \(g.bodyBatteryLow ?? 0)→\(g.bodyBatteryHigh ?? 0) · steps \(g.totalSteps ?? 0) · recovery \(g.recoveryHours ?? 0)hr")
        }

        return lines.joined(separator: "\n")
    }

    /// Render only the nutrition slice (used by the Nutrition specialist agent).
    static func renderNutritionOnly() -> String {
        var lines = ["NUTRITION DATA — 7 DAYS (2026-04-19 to 2026-04-25)"]
        for m in week.macros {
            if m.calories == nil {
                lines.append("\(m.date): no log")
            } else {
                lines.append("\(m.date): \(m.calories ?? 0) cal · \(m.protein_g ?? 0)p / \(m.carbs_g ?? 0)c / \(m.fat_g ?? 0)f · sat fat \(m.saturated_fat_g ?? 0)g · fiber \(m.fiber_g ?? 0)g · sodium \(m.sodium_mg ?? 0)mg · potassium \(m.potassium_mg ?? 0)mg")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Render only the training slice (used by the Training specialist agent).
    static func renderTrainingOnly() -> String {
        var lines = ["TRAINING DATA — 7 DAYS (2026-04-19 to 2026-04-25)"]
        for w in week.workouts {
            lines.append("\(w.date): \(w.summary)")
        }
        return lines.joined(separator: "\n")
    }

    /// Render only the recovery slice (used by the Recovery specialist agent).
    static func renderRecoveryOnly() -> String {
        var lines = ["RECOVERY / GARMIN DATA — 7 DAYS (2026-04-19 to 2026-04-25)"]
        for g in week.garmin {
            lines.append("\(g.date): readiness \(g.trainingReadiness ?? 0) (\(g.readinessLevel ?? "—")) · HRV \(g.hrvMs ?? 0)ms / \(g.hrvPercent ?? 0)% · resting HR \(g.restingHr ?? 0) · body battery \(g.bodyBatteryLow ?? 0)→\(g.bodyBatteryHigh ?? 0) · steps \(g.totalSteps ?? 0) · recovery \(g.recoveryHours ?? 0)hr")
        }
        return lines.joined(separator: "\n")
    }
}
