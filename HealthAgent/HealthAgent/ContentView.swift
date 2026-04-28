// ContentView.swift
// HealthInsightAgent
//
// Single-screen demo UI. 7 days of health data on top, mode selector,
// generate button, results card with metadata.

import SwiftUI

struct ContentView: View {

    @StateObject private var service = InsightService()
    @State private var selectedMode: InsightMode = .multiAgent
    @State private var showSpecialists = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    dataSection
                    modePicker
                    generateButton
                    resultsSection
                }
                .padding()
            }
            .navigationTitle("Health Insight Agent")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Multi-Agent vs Single-Shot LLM")
                .font(.headline)
            Text("Comparing two architectures for personal health interpretation over 7 days of self-tracked data.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Data display

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("7-Day Data Snapshot", icon: "chart.bar.fill")

            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<MockData.week.macros.count, id: \.self) { i in
                    let m = MockData.week.macros[i]
                    let w = MockData.week.workouts[i]
                    let g = MockData.week.garmin[i]
                    HStack(alignment: .top) {
                        Text(String(m.date.suffix(5)))
                            .font(.caption.monospaced())
                            .frame(width: 50, alignment: .leading)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(m.calories ?? 0) cal · \(m.protein_g ?? 0)p · sat \(Int(m.saturated_fat_g ?? 0))g")
                                .font(.caption2)
                            Text(w.summary)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("HRV \(g.hrvMs ?? 0)ms · readiness \(g.trainingReadiness ?? 0) (\(g.readinessLevel ?? "—"))")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                    if i < MockData.week.macros.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }

    // MARK: - Mode picker + generate

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Inference Mode", icon: "brain.head.profile")
            Picker("Mode", selection: $selectedMode) {
                ForEach(InsightMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(modeDescription)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modeDescription: String {
        switch selectedMode {
        case .singleShot:
            return "1 LLM call. Full data dumped into one prompt; model produces insights directly."
        case .multiAgent:
            return "4 LLM calls. 3 specialists (Nutrition / Training / Recovery) analyze in parallel; orchestrator synthesizes cross-domain insights."
        }
    }

    private var generateButton: some View {
        Button {
            Task { await service.run(mode: selectedMode) }
        } label: {
            HStack {
                if service.isRunning {
                    ProgressView().controlSize(.small)
                    Text("Generating insights…").padding(.leading, 6)
                } else {
                    Image(systemName: "sparkles")
                    Text("Generate Insights")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(service.isRunning ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(service.isRunning)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        if let err = service.errorMessage {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Error", icon: "exclamationmark.triangle.fill", color: .red)
                Text(err)
                    .font(.caption)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
            }
        } else if let result = service.lastResult {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Insights — \(result.mode.rawValue)", icon: "lightbulb.fill", color: .orange)

                Text(result.insights)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                metadataCard(result)

                if result.mode == .multiAgent && !result.specialistOutputs.isEmpty {
                    DisclosureGroup("Specialist Outputs (intermediate stage)", isExpanded: $showSpecialists) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(["Nutrition", "Training", "Recovery"], id: \.self) { name in
                                if let text = result.specialistOutputs[name] {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(name).font(.caption.bold()).foregroundColor(.blue)
                                        Text(text).font(.caption2)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.caption)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
        }
    }

    private func metadataCard(_ result: InsightResult) -> some View {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return HStack(spacing: 0) {
            metadataItem(label: "Calls", value: "\(result.llmCallCount)")
            Divider().frame(height: 28)
            metadataItem(label: "Tokens", value: formatter.string(from: NSNumber(value: result.totalTokens)) ?? "0")
            Divider().frame(height: 28)
            metadataItem(label: "Latency", value: String(format: "%.1fs", result.wallClockSeconds))
            Divider().frame(height: 28)
            metadataItem(label: "Cost", value: String(format: "$%.4f", result.costEstimateUsd))
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func metadataItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.bold())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, color: Color = .blue) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color)
            Text(title).font(.subheadline.bold())
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
