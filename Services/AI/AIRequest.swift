import Foundation

struct AIRequest: Codable, Equatable {
    let userQuestion: String
    let entries: [SymptomEntrySummary]
    let timeframe: Timeframe
    let userPrefs: AIUserPrefs
    let locale: String
    let timezone: String
    let preferredLanguage: String
    let medicalContext: AIMedicalContext?
}

struct SymptomEntrySummary: Codable, Equatable {
    let id: UUID
    let symptomType: String
    let severity: Int
    let onset: Date?
    let durationMinutes: Int?
    let triggers: [String]
    let notes: String?
    let medsTaken: [String]

    let sleepHours: Double?
    let hydrationLiters: Double?
    let caffeineMg: Int?
    let alcoholUnits: Int?
}

struct Timeframe: Codable, Equatable {
    let start: Date
    let end: Date
}

struct AIUserPrefs: Codable, Equatable {
    let dataMinimizationOn: Bool
}

struct AIMedicalContext: Codable, Equatable {
    let allergies: String
    let chronicConditions: String
    let currentMedications: String
    let pastSurgeries: String
    let familyHistory: String
    let notesForCareTeam: String
    let recentHealthHistory: [String]
}
