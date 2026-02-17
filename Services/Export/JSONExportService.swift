import Foundation

struct VisitBriefExport: Codable {
    let generatedAt: Date
    let summary: String
    let medicalProfile: MedicalProfileData?
    let healthHistory: [HealthHistoryRecord]
    let symptomEntries: [SymptomEntry]
}

struct JSONExportService {
    func export(entries: [SymptomEntry]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(entries)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let safeDate = formatter.string(from: Date())
        let filename = "symptom-entries-\(safeDate).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])
        return url
    }

    func exportVisitBrief(
        entries: [SymptomEntry],
        medicalProfile: MedicalProfileData?,
        history: [HealthHistoryRecord]
    ) throws -> URL {
        let sortedEntries = entries.sorted(by: { $0.createdAt < $1.createdAt })
        let timeframeStart = sortedEntries.first?.createdAt
        let timeframeEnd = sortedEntries.last?.createdAt
        let summary = """
        Visit brief generated from Symptom Nerd.
        Total logs: \(entries.count)
        Timeframe: \(timeframeStart?.formatted(date: .abbreviated, time: .omitted) ?? "N/A") to \(timeframeEnd?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")
        Most recent symptom: \(sortedEntries.last?.symptomType.name ?? "N/A")
        """
        let payload = VisitBriefExport(
            generatedAt: Date(),
            summary: summary,
            medicalProfile: medicalProfile,
            healthHistory: history.sorted(by: { $0.date > $1.date }),
            symptomEntries: entries
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let safeDate = formatter.string(from: Date())
        let filename = "visit-brief-\(safeDate).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
