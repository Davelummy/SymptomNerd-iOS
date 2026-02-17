import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
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
            errorMessage = "Failed to load entries."
        }
    }

    var lastEntry: SymptomEntry? {
        entries.sorted { $0.createdAt > $1.createdAt }.first
    }

    var averageSeverity: Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.severity }
        return Double(total) / Double(entries.count)
    }

    var streakDays: Int {
        guard !entries.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = uniqueDays.sorted(by: >)

        var streak = 0
        var current = calendar.startOfDay(for: Date())

        for day in sortedDays {
            if day == current {
                streak += 1
                if let previous = calendar.date(byAdding: .day, value: -1, to: current) {
                    current = previous
                }
            } else if day > current {
                continue
            } else {
                break
            }
        }
        return streak
    }
}
