import Foundation

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var entries: [SymptomEntry] = []
    @Published var errorMessage: String?

    private var client: PersistenceClient?

    func configure(client: PersistenceClient) {
        if self.client == nil { self.client = client }
    }

    func load() async {
        guard let client else { return }
        do {
            entries = try await client.fetchEntries()
        } catch {
            errorMessage = "Failed to load insights."
        }
    }

    var severitySeries: [(date: Date, severity: Int)] {
        entries.sorted { $0.createdAt < $1.createdAt }.map { ($0.createdAt, $0.severity) }
    }

    var dailyCounts: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.map { (key, value) in
            (date: key, count: value.count)
        }.sorted { $0.date < $1.date }
    }

    var averageSeverity: Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.severity }
        return Double(total) / Double(entries.count)
    }
}
