import SwiftUI

struct InsightsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Insights")
                            .font(Typography.title2)
                        Text("Patterns and possible relationships will appear here.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Severity over time")
                            .font(Typography.headline)
                        chartPlaceholder
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("What changed?")
                            .font(Typography.headline)
                        Text("Compare the last 7 days to the previous 7 days.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Text("Insights are observations, not diagnoses.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Insights")
    }

    private var chartPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
            .fill(Theme.accentSoft)
            .frame(height: 140)
            .overlay(
                Image(systemName: "chart.xyaxis.line")
                    .font(.title)
                    .foregroundStyle(Theme.accent)
            )
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}
