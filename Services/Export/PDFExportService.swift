import Foundation
import UIKit

struct PDFExportService {
    func generatePDF(for entries: [SymptomEntry]) async throws -> Data {
        let sorted = entries.sorted(by: { $0.createdAt < $1.createdAt })
        let lines = sorted.map { "\($0.createdAt.formatted(date: .abbreviated, time: .shortened)) • \($0.symptomType.name) • \($0.severity)/10" }
        return generatePDFData(title: "Symptom Entries", lines: lines)
    }

    func generateVisitBriefPDF(
        entries: [SymptomEntry],
        medicalProfile: MedicalProfileData?,
        history: [HealthHistoryRecord]
    ) async throws -> Data {
        var lines: [String] = []
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))")
        lines.append("Total logs: \(entries.count)")
        if let minDate = entries.map(\.createdAt).min(),
           let maxDate = entries.map(\.createdAt).max() {
            lines.append("Timeframe: \(minDate.formatted(date: .abbreviated, time: .omitted)) - \(maxDate.formatted(date: .abbreviated, time: .omitted))")
        }
        lines.append("")
        lines.append("Medical profile")
        if let medicalProfile {
            lines.append("Name: \(medicalProfile.firstName) \(medicalProfile.lastName)")
            lines.append("DOB: \(medicalProfile.dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")")
            lines.append("Allergies: \(medicalProfile.allergies)")
            lines.append("Conditions: \(medicalProfile.chronicConditions)")
            lines.append("Medications: \(medicalProfile.currentMedications)")
            lines.append("Family history: \(medicalProfile.familyHistory)")
            lines.append("Care notes: \(medicalProfile.notesForCareTeam)")
        } else {
            lines.append("No profile details saved.")
        }
        lines.append("")
        lines.append("Health history")
        if history.isEmpty {
            lines.append("No health history entries.")
        } else {
            for item in history.sorted(by: { $0.date > $1.date }).prefix(12) {
                lines.append("• \(item.date.formatted(date: .abbreviated, time: .omitted)) - \(item.title): \(item.details)")
            }
        }
        lines.append("")
        lines.append("Recent symptom logs")
        for entry in entries.sorted(by: { $0.createdAt > $1.createdAt }).prefix(20) {
            lines.append("• \(entry.createdAt.formatted(date: .abbreviated, time: .shortened)) - \(entry.symptomType.name) \(entry.severity)/10 | triggers: \(entry.possibleTriggers.map { $0.rawValue }.joined(separator: ", "))")
        }
        return generatePDFData(title: "Symptom Nerd Visit Brief", lines: lines)
    }

    private func generatePDFData(title: String, lines: [String]) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 36
            let left: CGFloat = 32

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]

            NSString(string: title).draw(at: CGPoint(x: left, y: y), withAttributes: titleAttrs)
            y += 34

            for line in lines {
                if y > pageRect.height - 36 {
                    context.beginPage()
                    y = 36
                }
                let rect = CGRect(x: left, y: y, width: pageRect.width - 64, height: 40)
                NSString(string: line).draw(in: rect, withAttributes: bodyAttrs)
                y += 16
            }
        }
        return data
    }
}
