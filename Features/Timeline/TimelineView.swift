import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TimelineViewModel()
    @State private var showLogFlow = false

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
                        Text(viewModel.entries.isEmpty ? "No entries yet" : "Recent entries")
                            .font(Typography.headline)
                        if viewModel.entries.isEmpty {
                            Text("Start logging to see your timeline.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(viewModel.entries) { entry in
                                NavigationLink {
                                    TimelineEntryDetailView(entry: entry)
                                } label: {
                                    entryRow(entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        PrimaryButton(title: "Log Symptom", systemImage: "plus") {
                            showLogFlow = true
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Timeline")
        .task {
            viewModel.configure(client: SwiftDataStore(context: modelContext))
            await viewModel.load()
        }
        .sheet(isPresented: $showLogFlow) {
            LogSymptomFlowView {
                Task { await viewModel.load() }
            }
        }
    }

    private func entryRow(_ entry: SymptomEntry) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            HStack {
                Text(entry.symptomType.name)
                    .font(Typography.headline)
                Spacer()
                Text("\(entry.severity)/10")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(DateHelpers.relativeDayString(for: entry.createdAt))
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            Button("Delete") {
                Task { await viewModel.delete(entry: entry) }
            }
            .font(Typography.caption)
            .foregroundStyle(.red)
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
