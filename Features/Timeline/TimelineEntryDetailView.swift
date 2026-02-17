import SwiftUI

struct TimelineEntryDetailView: View {
    let entry: SymptomEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text(entry.symptomType.name)
                            .font(Typography.title2)
                        Text("Severity \(entry.severity)/10")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        Text(DateHelpers.relativeDayString(for: entry.createdAt))
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Details")
                            .font(Typography.headline)
                        if let onset = entry.onset {
                            Text("Onset: \(onset.formatted(date: .abbreviated, time: .shortened))")
                                .font(Typography.body)
                        }
                        if let duration = entry.durationMinutes {
                            Text("Duration: \(duration) minutes")
                                .font(Typography.body)
                        }
                        if !entry.possibleTriggers.isEmpty {
                            Text("Triggers: \(entry.possibleTriggers.map { $0.rawValue }.joined(separator: ", "))")
                                .font(Typography.body)
                        }
                        if !entry.notes.isEmpty {
                            Text("Notes: \(entry.notes)")
                                .font(Typography.body)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("AI analysis")
                            .font(Typography.headline)
                        NavigationLink {
                            AIChatView()
                        } label: {
                            PrimaryButtonLabel(title: "Analyze this entry", systemImage: "sparkles")
                        }
                    }
                }

                Text("AI insights are informational and not a diagnosis.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Entry")
    }
}

#Preview {
    NavigationStack {
        TimelineEntryDetailView(entry: SymptomEntry(symptomType: SymptomType(name: "Headache"), severity: 4))
    }
}
