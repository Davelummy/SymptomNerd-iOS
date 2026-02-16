import SwiftUI

struct ExportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Doctor-ready export")
                            .font(Typography.title2)
                        Text("Choose a date range and generate a PDF summary.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Range")
                            .font(Typography.headline)
                        HStack(spacing: Theme.spacingS) {
                            ChipView(title: "7 days")
                            ChipView(title: "30 days")
                            ChipView(title: "90 days")
                        }
                        PrimaryButton(title: "Generate PDF", systemImage: "doc") { }
                    }
                }

                Text("Export includes only what you choose to share.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Export")
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
}
