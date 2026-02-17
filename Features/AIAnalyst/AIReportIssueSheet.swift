import SwiftUI

struct AIReportIssueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var didSave = false

    private let store = AIReportStore()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                Text("Report an issue")
                    .font(Typography.title2)
                Text("Tell us what felt off or unhelpful. This stays on your device unless you choose to share.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)

                TextEditor(text: $notes)
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(Theme.glassStroke, lineWidth: 1)
                    )

                if didSave {
                    Text("Saved locally.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: Theme.spacingS) {
                    Button("Save locally") {
                        guard !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        store.save(AIReport(notes: notes))
                        didSave = true
                    }
                    .buttonStyle(.bordered)

                    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ShareLink(item: notes) {
                            Text("Share")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
            .navigationTitle("Report an issue")
        }
    }
}

#Preview {
    AIReportIssueSheet()
}
