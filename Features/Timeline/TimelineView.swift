import SwiftUI

struct TimelineView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Timeline")
                            .font(Typography.title2)
                        Text("Entries will appear here by day, with filters and calendar toggle.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Filters")
                            .font(Typography.headline)
                        HStack(spacing: Theme.spacingS) {
                            ChipView(title: "All symptoms")
                            ChipView(title: "Severity 0-10")
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("No entries yet")
                            .font(Typography.headline)
                        Text("Start logging to see your timeline.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Timeline")
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
