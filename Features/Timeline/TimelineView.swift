import SwiftUI
import SwiftData
import UIKit

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TimelineViewModel()
    @State private var showLogFlow = false
    @State private var searchText = ""
    @State private var pendingDelete: SymptomEntry?
    @State private var showDeleteConfirm = false

    // MARK: - Derived data

    private var filtered: [SymptomEntry] {
        guard !searchText.isEmpty else { return viewModel.entries }
        return viewModel.entries.filter {
            $0.symptomType.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grouped: [(day: Date, entries: [SymptomEntry])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.createdAt) }
        return dict.sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if viewModel.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.spacingM,
                               pinnedViews: .sectionHeaders) {
                        ForEach(grouped, id: \.day) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    NavigationLink {
                                        TimelineEntryDetailView(entry: entry)
                                    } label: {
                                        EntryCardView(entry: entry) {
                                            pendingDelete = entry
                                            showDeleteConfirm = true
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                                }
                            } header: {
                                sectionHeader(for: group.day)
                            }
                        }
                    }
                    .screenPadding()
                    .padding(.bottom, Theme.spacingL)
                    .animation(.spring(duration: 0.32), value: viewModel.entries.count)
                }
            }
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
        .alert("Delete entry?", isPresented: $showDeleteConfirm,
               presenting: pendingDelete) { entry in
            Button("Delete", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                Task { await viewModel.delete(entry: entry) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text(""\(entry.symptomType.name)" will be permanently removed.")
        }
    }

    // MARK: - Sub-views

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
    let onDelete: () -> Void

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

                VStack(alignment: .trailing, spacing: Theme.spacingM) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(Theme.errorRed)
                    }
                    .buttonStyle(.plain)
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
                .font(.system(size: 9, weight: .semibold))
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
