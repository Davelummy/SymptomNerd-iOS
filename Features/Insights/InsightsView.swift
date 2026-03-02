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

                // ── Header ───────────────────────────────────────────────────
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Label("Insights", systemImage: "chart.xyaxis.line")
                            .font(Typography.title2)
                        Text("Patterns and possible relationships from your logs.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                // ── Tab selector ─────────────────────────────────────────────
                Picker("Insights Tab", selection: $selectedTab) {
                    ForEach(InsightsTab.allCases, id: \.self) {
                        Text($0.title).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                if selectedTab == .charts {
                    chartsContent
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

    // MARK: - Charts tab

    @ViewBuilder
    private var chartsContent: some View {
        // Summary metric row
        HStack(spacing: Theme.spacingS) {
            metricTile(
                icon: "waveform.path.ecg",
                label: "Avg severity",
                value: viewModel.entries.isEmpty
                    ? "—"
                    : String(format: "%.1f", viewModel.averageSeverity),
                color: viewModel.entries.isEmpty
                    ? Theme.textSecondary
                    : Theme.severityColor(for: Int(viewModel.averageSeverity.rounded()))
            )
            metricTile(
                icon: "calendar.badge.clock",
                label: "Total logs",
                value: "\(viewModel.entries.count)",
                color: Theme.accent
            )
            metricTile(
                icon: "flame",
                label: "This week",
                value: "\(viewModel.dailyCounts.reduce(0) { $0 + $1.count })",
                color: Theme.warningAmber
            )
        }

        // Severity over time
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Label("Severity over time", systemImage: "waveform.path.ecg")
                    .font(Typography.headline)
                if viewModel.severitySeries.isEmpty {
                    emptyChartPlaceholder(icon: "chart.xyaxis.line",
                                          message: "Log symptoms to see trends")
                } else {
                    Chart(viewModel.severitySeries, id: \.date) { item in
                        AreaMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Severity", item.severity)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.30), Theme.accent.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Severity", item.severity)
                        )
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Severity", item.severity)
                        )
                        .foregroundStyle(Theme.severityColor(for: item.severity))
                        .symbolSize(50)
                    }
                    .chartYScale(domain: 0...10)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.primary.opacity(0.08))
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(Typography.caption)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 5, 10]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.primary.opacity(0.08))
                            AxisValueLabel()
                                .font(Typography.caption)
                        }
                    }
                    .frame(height: 190)
                }
            }
        }

        // Frequency by day
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Label("Frequency by day", systemImage: "calendar")
                    .font(Typography.headline)
                if viewModel.dailyCounts.isEmpty {
                    emptyChartPlaceholder(icon: "calendar",
                                          message: "No logs yet")
                } else {
                    Chart(viewModel.dailyCounts, id: \.date) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accentDeep, Theme.accent],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .font(Typography.caption)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.primary.opacity(0.08))
                            AxisValueLabel()
                                .font(Typography.caption)
                        }
                    }
                    .frame(height: 160)
                }
            }
        }

        Text("Insights are observations, not diagnoses.")
            .font(Typography.caption)
            .foregroundStyle(Theme.textSecondary)
    }

    // MARK: - Helper views

    private func metricTile(icon: String, label: String,
                            value: String, color: Color) -> some View {
        VStack(spacing: Theme.spacingXS) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.spacingS)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
            .stroke(Theme.glassStroke, lineWidth: 1))
    }

    private func emptyChartPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: Theme.spacingS) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Theme.accent.opacity(0.5))
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(Theme.accentSoft.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
    }
}

private enum InsightsTab: String, CaseIterable {
    case charts, ai

    var title: String {
        switch self {
        case .charts: return "Charts"
        case .ai:     return "AI Insights"
        }
    }
}

#Preview {
    NavigationStack { InsightsView() }
}
