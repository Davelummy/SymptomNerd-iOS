import SwiftUI

struct LogSymptomFlowView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Guided log")
                                .font(Typography.title2)
                            Text("We will ask a few gentle questions. You can skip anything.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Steps")
                                .font(Typography.headline)
                            ForEach(stepTitles, id: \.self) { step in
                                HStack(spacing: Theme.spacingS) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundStyle(Theme.accent)
                                    Text(step)
                                        .font(Typography.body)
                                }
                            }
                        }
                    }

                    Text("If you feel this is urgent or severe, consider immediate medical care.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .screenPadding()
                .padding(.vertical, Theme.spacingL)
            }
            .navigationTitle("Log Symptom")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var stepTitles: [String] {
        [
            "Symptom type",
            "Body location",
            "Severity",
            "Onset and duration",
            "Context and triggers",
            "Notes and attachments"
        ]
    }
}

#Preview {
    LogSymptomFlowView()
}
