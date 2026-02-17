import SwiftUI
import SwiftData
import FirebaseAuth

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportURL: URL?
    @State private var isSharing = false
    @State private var statusMessage: String?

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
                        PrimaryButton(title: "Export logs JSON", systemImage: "doc") {
                            Task { await exportLogsJSON() }
                        }
                        PrimaryButton(title: "Generate visit brief PDF", systemImage: "waveform.path.ecg") {
                            Task { await exportVisitBrief() }
                        }
                        if let statusMessage {
                            Text(statusMessage)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
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
        .sheet(isPresented: $isSharing) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    private func exportLogsJSON() async {
        do {
            let entries = try await SwiftDataStore(context: modelContext).fetchEntries()
            let url = try JSONExportService().export(entries: entries)
            exportURL = url
            statusMessage = "Logs export ready."
            isSharing = true
        } catch {
            statusMessage = "Export failed."
        }
    }

    private func exportVisitBrief() async {
        do {
            let entries = try await SwiftDataStore(context: modelContext).fetchEntries()
            let scope = Auth.auth().currentUser?.uid ?? "guest"
            let defaults = UserDefaults.standard
            let profileKey = "profile.medical." + scope
            let historyKey = "profile.history." + scope
            let profile = defaults.data(forKey: profileKey).flatMap { try? JSONDecoder().decode(MedicalProfileData.self, from: $0) }
            let history = defaults.data(forKey: historyKey).flatMap { try? JSONDecoder().decode([HealthHistoryRecord].self, from: $0) } ?? []
            let pdf = try await PDFExportService().generateVisitBriefPDF(entries: entries, medicalProfile: profile, history: history)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let safeDate = formatter.string(from: Date())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("visit-brief-\(safeDate).pdf")
            try pdf.write(to: url, options: [.atomic])
            exportURL = url
            statusMessage = "Visit brief PDF ready."
            isSharing = true
        } catch {
            statusMessage = "Visit brief generation failed."
        }
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
}
