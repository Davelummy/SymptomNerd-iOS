import Foundation

struct AIPromptBuilder {
    func buildPrompt(from entries: [SymptomEntrySummary], timeframe: Timeframe) -> String {
        var lines: [String] = []
        lines.append("Timeframe: \(timeframe.start.formatted(date: .abbreviated, time: .omitted)) to \(timeframe.end.formatted(date: .abbreviated, time: .omitted))")
        lines.append("Entries: \(entries.count)")

        for entry in entries {
            var detail = "\(entry.symptomType) (\(entry.severity)/10)"
            if let onset = entry.onset {
                detail += " onset \(onset.formatted(date: .abbreviated, time: .shortened))"
            }
            if let duration = entry.durationMinutes {
                detail += ", duration \(duration) min"
            }
            if !entry.triggers.isEmpty {
                detail += ", triggers: \(entry.triggers.joined(separator: ", "))"
            }
            if let notes = entry.notes, !notes.isEmpty {
                detail += ", notes: \(notes)"
            }
            lines.append("- \(detail)")
        }

        return lines.joined(separator: "\n")
    }
}
