import Foundation

struct AIReportStore {
    private let key = "ai.reportIssues"
    private let defaults = UserDefaults.standard

    func save(_ report: AIReport) {
        var current = loadAll()
        current.append(report)
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: key)
        }
    }

    func loadAll() -> [AIReport] {
        guard let data = defaults.data(forKey: key),
              let reports = try? JSONDecoder().decode([AIReport].self, from: data) else {
            return []
        }
        return reports
    }
}

struct AIReport: Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let notes: String

    init(id: UUID = UUID(), createdAt: Date = Date(), notes: String) {
        self.id = id
        self.createdAt = createdAt
        self.notes = notes
    }
}
