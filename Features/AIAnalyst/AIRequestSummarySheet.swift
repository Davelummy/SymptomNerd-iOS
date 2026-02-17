import SwiftUI

struct AIRequestSummarySheet: View {
    let summary: AIRequestSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("What we sent to the AI")
                                .font(Typography.title2)
                            Text("We send only what’s needed to generate insights.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Your question")
                                .font(Typography.headline)
                            Text(summary.question)
                                .font(Typography.body)
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Entries shared")
                                .font(Typography.headline)
                            Text("\(summary.entryCount) log(s)")
                                .font(Typography.body)
                            if summary.entryCount == 0 {
                                Text("No symptom logs shared. Chat uses only your message.")
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            } else if !summary.symptomNames.isEmpty {
                                Text("Symptoms: \(summary.symptomNames.joined(separator: ", "))")
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Timeframe")
                                .font(Typography.headline)
                            if summary.entryCount == 0 {
                                Text("Chat-only (no log range)")
                                    .font(Typography.body)
                            } else {
                                Text("\(summary.timeframe.start.formatted(date: .abbreviated, time: .omitted)) – \(summary.timeframe.end.formatted(date: .abbreviated, time: .omitted))")
                                    .font(Typography.body)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Data minimization")
                                .font(Typography.headline)
                            Text(summary.dataMinimizationOn ? "On (recommended)" : "Off")
                                .font(Typography.body)
                        }
                    }
                }
                .screenPadding()
                .padding(.vertical, Theme.spacingL)
            }
            .navigationTitle("AI Payload")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AIRequestSummarySheet(
        summary: AIRequestSummary(
            from: AIRequest(
                userQuestion: "Bloody saliva",
                entries: [],
                timeframe: Timeframe(start: Date(), end: Date()),
                userPrefs: AIUserPrefs(dataMinimizationOn: true),
                locale: "en_US",
                timezone: "UTC",
                preferredLanguage: "English",
                medicalContext: nil
            ),
            entryCount: 0,
            symptomNames: []
        )
    )
}
