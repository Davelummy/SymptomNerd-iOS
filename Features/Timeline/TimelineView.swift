import SwiftUI
import SwiftData
import UIKit

struct TimelineView: View {
    private struct TimelineDaySection: Identifiable {
        let day: Date
        let entries: [SymptomEntry]
        var id: Date { day }
    }

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TimelineViewModel()
    @State private var showLogFlow = false
    @State private var searchText = ""
    @State private var recentlyDeleted: SymptomEntry?
    @State private var showUndoBanner = false
    @State private var dismissUndoTask: Task<Void, Never>?

    // MARK: - Derived data

    private var filtered: [SymptomEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.entries }
        return viewModel.entries.filter {
            $0.symptomType.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var grouped: [TimelineDaySection] {
        let cal = Calendar.current
        var groups: [Date: [SymptomEntry]] = [:]
        for entry in filtered {
            let day = cal.startOfDay(for: entry.createdAt)
            groups[day, default: []].append(entry)
        }

        return groups.keys.sorted(by: >).map { day in
            let sortedEntries = (groups[day] ?? []).sorted { $0.createdAt > $1.createdAt }
            return TimelineDaySection(day: day, entries: sortedEntries)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            timelineContent
        }
        .navigationTitle("Timeline")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showLogFlow = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .task {
            viewModel.configure(client: SwiftDataStore(context: modelContext))
            await viewModel.load()
        }
        .sheet(isPresented: $showLogFlow) {
            LogSymptomFlowView { Task { await viewModel.load() } }
        }
        .overlay(alignment: .bottom) {
            if showUndoBanner, let deleted = recentlyDeleted {
                undoBanner(entry: deleted)
                    .padding(.horizontal, Theme.spacingL)
                    .padding(.bottom, Theme.spacingL)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.28), value: showUndoBanner)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var timelineContent: some View {
        if viewModel.isLoading && viewModel.entries.isEmpty {
            loadingState
        } else if viewModel.entries.isEmpty {
            emptyState
        } else if filtered.isEmpty {
            filteredEmptyState
        } else {
            timelineList
        }
    }

    private var loadingState: some View {
        VStack(spacing: Theme.spacingM) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.accent)
            Text("Loading timeline...")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: Theme.spacingM) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent.opacity(0.8))
            Text("No matching entries")
                .font(Typography.title2)
            Text("Try a different search term.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timelineList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.spacingM, pinnedViews: .sectionHeaders) {
                if let errorMessage = viewModel.errorMessage {
                    errorCard(message: errorMessage)
                }

                ForEach(grouped, id: \.day) { group in
                    daySection(group)
                }
            }
            .screenPadding()
            .padding(.bottom, Theme.spacingL)
            .animation(.spring(duration: 0.32), value: grouped.count)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private func daySection(_ group: TimelineDaySection) -> some View {
        Section {
            ForEach(group.entries) { entry in
                NavigationLink {
                    TimelineEntryDetailView(entry: entry)
                } label: {
                    EntryCardView(entry: entry)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        Task {
                            await viewModel.delete(entry: entry)
                            recentlyDeleted = entry
                            showUndoBanner = true
                            scheduleUndoDismiss()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        } header: {
            sectionHeader(for: group.day)
        }
    }

    private var searchBar: some View {
        HStack(spacing: Theme.spacingS) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Search symptoms…", text: $searchText)
                .font(Typography.body)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(Theme.spacingS)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .screenPadding()
        .padding(.vertical, Theme.spacingS)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacingM) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accentSoft.opacity(0.35))
                    .frame(width: 100, height: 100)
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
            }
            Text("No entries yet")
                .font(Typography.title2)
            Text("Start logging symptoms to build your personal health timeline.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.spacingXL)
            PrimaryButton(title: "Log your first symptom", systemImage: "plus") {
                showLogFlow = true
            }
            .padding(.horizontal, Theme.spacingXL)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func undoBanner(entry: SymptomEntry) -> some View {
        CardView {
            HStack(spacing: Theme.spacingS) {
                Image(systemName: "trash.slash")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Entry deleted")
                        .font(Typography.headline)
                    Text(entry.symptomType.name)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button("Undo") {
                    dismissUndoTask?.cancel()
                    showUndoBanner = false
                    if let deleted = recentlyDeleted {
                        Task { await viewModel.restore(entry: deleted) }
                    }
                    recentlyDeleted = nil
                }
                .font(Typography.headline)
            }
        }
    }

    private func scheduleUndoDismiss() {
        dismissUndoTask?.cancel()
        dismissUndoTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            showUndoBanner = false
            recentlyDeleted = nil
        }
    }

    private func sectionHeader(for day: Date) -> some View {
        Text(sectionTitle(for: day))
            .font(Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.vertical, Theme.spacingXS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.opacity(0.95))
    }

    private func sectionTitle(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

// MARK: - Entry card

private struct EntryCardView: View {
    let entry: SymptomEntry

    var body: some View {
        CardView {
            HStack(spacing: Theme.spacingM) {
                severityBadge

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text(entry.symptomType.name)
                        .font(Typography.headline)
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: Theme.spacingXS) {
                        if let onset = entry.onset {
                            Label(onset.formatted(.dateTime.hour().minute()),
                                  systemImage: "clock")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if let dur = entry.durationMinutes {
                            Text("· \(dur) min")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    if !entry.qualities.isEmpty {
                        Text(entry.qualities.prefix(3)
                            .map { $0.displayName }
                            .joined(separator: " · "))
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Theme.spacingS) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(entry.createdAt.formatted(.dateTime.hour().minute()))
                        .font(Typography.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var severityBadge: some View {
        let color = Theme.severityColor(for: entry.severity)
        return VStack(spacing: 1) {
            Text("\(entry.severity)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("/ 10")
                .font(Typography.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(width: 50, height: 54)
        .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack { TimelineView() }
}
