import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @State private var selectedTab: InsightsTab = .charts
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = InsightsViewModel()

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

                Picker("Insights Tab", selection: $selectedTab) {
                    ForEach(InsightsTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if selectedTab == .charts {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Severity over time")
                                .font(Typography.headline)
                            if viewModel.severitySeries.isEmpty {
                                chartPlaceholder
                            } else {
                                Chart(viewModel.severitySeries, id: \.date) { item in
                                    LineMark(
                                        x: .value("Date", item.date, unit: .day),
                                        y: .value("Severity", item.severity)
                                    )
                                    .foregroundStyle(Theme.accent)
                                    PointMark(
                                        x: .value("Date", item.date, unit: .day),
                                        y: .value("Severity", item.severity)
                                    )
                                    .foregroundStyle(Theme.accent)
                                }
                                .frame(height: 180)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Frequency by day")
                                .font(Typography.headline)
                            if viewModel.dailyCounts.isEmpty {
                                Text("No logs yet.")
                                    .font(Typography.body)
                                    .foregroundStyle(Theme.textSecondary)
                            } else {
                                Chart(viewModel.dailyCounts, id: \.date) { item in
                                    BarMark(
                                        x: .value("Date", item.date, unit: .day),
                                        y: .value("Count", item.count)
                                    )
                                    .foregroundStyle(Theme.accentSoft)
                                }
                                .frame(height: 160)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Summary")
                                .font(Typography.headline)
                            Text(String(format: "Average severity: %.1f/10", viewModel.averageSeverity))
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Text("Insights are observations, not diagnoses.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    AIInsightsInlineView()
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Insights")
        .task {
            viewModel.configure(client: SwiftDataStore(context: modelContext))
            await viewModel.load()
        }
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

private enum InsightsTab: String, CaseIterable {
    case charts
    case ai

    var title: String {
        switch self {
        case .charts: return "Charts"
        case .ai: return "AI Insights"
        }
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}
