import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @State private var selectedTab: InsightsTab = .charts
    @State private var selectedSeverityDate: Date?
    @State private var selectedFrequencyDate: Date?
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingM) {

                // ── Header ───────────────────────────────────────────────────
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        HStack(spacing: Theme.spacingS) {
                            Label("Insights", systemImage: "chart.xyaxis.line")
                                .font(Typography.title2)
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.82)
                                    .tint(Theme.accent)
                            }
                            Spacer()
                        }
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

                if let errorMessage = viewModel.errorMessage {
                    errorCard(message: errorMessage)
                }

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
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Charts tab

    @ViewBuilder
    private var chartsContent: some View {
        if viewModel.isLoading && viewModel.entries.isEmpty {
            CardView {
                VStack(spacing: Theme.spacingS) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("Loading insight charts...")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        }

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

                        if let selected = selectedSeverityPoint {
                            RuleMark(x: .value("Selected", selected.date, unit: .day))
                                .foregroundStyle(Theme.accent.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .top, alignment: .leading) {
                                    chartCallout(
                                        title: selected.date.formatted(.dateTime.month(.abbreviated).day()),
                                        value: "Severity \(selected.severity)/10"
                                    )
                                }
                            PointMark(
                                x: .value("Selected Date", selected.date, unit: .day),
                                y: .value("Selected Severity", selected.severity)
                            )
                            .symbolSize(90)
                            .foregroundStyle(Theme.severityColor(for: selected.severity))
                        }
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            let frame = geo[plotFrame]
                                            let x = value.location.x - frame.origin.x
                                            guard x >= 0, x <= frame.size.width,
                                                  let date: Date = proxy.value(atX: x) else {
                                                return
                                            }
                                            selectedSeverityDate = date
                                        }
                                )
                                .onTapGesture {
                                    selectedSeverityDate = nil
                                }
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

                        if let selected = selectedFrequencyPoint {
                            RuleMark(x: .value("Selected", selected.date, unit: .day))
                                .foregroundStyle(Theme.accent.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .top, alignment: .leading) {
                                    chartCallout(
                                        title: selected.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                                        value: "\(selected.count) logs"
                                    )
                                }
                        }
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            let frame = geo[plotFrame]
                                            let x = value.location.x - frame.origin.x
                                            guard x >= 0, x <= frame.size.width,
                                                  let date: Date = proxy.value(atX: x) else {
                                                return
                                            }
                                            selectedFrequencyDate = date
                                        }
                                )
                                .onTapGesture {
                                    selectedFrequencyDate = nil
                                }
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

    private var selectedSeverityPoint: (date: Date, severity: Int)? {
        guard let selectedSeverityDate else { return nil }
        return viewModel.severitySeries.min(by: {
            abs($0.date.timeIntervalSince(selectedSeverityDate)) < abs($1.date.timeIntervalSince(selectedSeverityDate))
        })
    }

    private var selectedFrequencyPoint: (date: Date, count: Int)? {
        guard let selectedFrequencyDate else { return nil }
        return viewModel.dailyCounts.min(by: {
            abs($0.date.timeIntervalSince(selectedFrequencyDate)) < abs($1.date.timeIntervalSince(selectedFrequencyDate))
        })
    }

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

    private func chartCallout(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
    }

    private func errorCard(message: String) -> some View {
        CardView {
            HStack(spacing: Theme.spacingS) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warningAmber)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .font(Typography.caption)
            }
        }
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
