import Foundation

struct SymptomEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var symptomType: SymptomType
    var symptomNameOverride: String?

    var bodyLocation: BodyLocation?
    var severity: Int

    var onset: Date?
    var durationMinutes: Int?

    var qualities: [SymptomQuality]
    var associatedSymptoms: [AssociatedSymptom]
    var possibleTriggers: [Trigger]

    var context: SymptomContext
    var notes: String
    var attachmentIDs: [UUID]
    var redFlags: [RedFlag]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        symptomType: SymptomType,
        symptomNameOverride: String? = nil,
        bodyLocation: BodyLocation? = nil,
        severity: Int = 0,
        onset: Date? = nil,
        durationMinutes: Int? = nil,
        qualities: [SymptomQuality] = [],
        associatedSymptoms: [AssociatedSymptom] = [],
        possibleTriggers: [Trigger] = [],
        context: SymptomContext = SymptomContext(),
        notes: String = "",
        attachmentIDs: [UUID] = [],
        redFlags: [RedFlag] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.symptomType = symptomType
        self.symptomNameOverride = symptomNameOverride
        self.bodyLocation = bodyLocation
        self.severity = severity
        self.onset = onset
        self.durationMinutes = durationMinutes
        self.qualities = qualities
        self.associatedSymptoms = associatedSymptoms
        self.possibleTriggers = possibleTriggers
        self.context = context
        self.notes = notes
        self.attachmentIDs = attachmentIDs
        self.redFlags = redFlags
    }
}

struct BodyLocation: Codable, Equatable {
    enum Surface: String, Codable, CaseIterable {
        case front
        case back
    }

    enum Side: String, Codable, CaseIterable {
        case left
        case right
        case center
    }

    var surface: Surface
    var side: Side
    var x: Double
    var y: Double
    var regionName: String?
}

struct SymptomContext: Codable, Equatable {
    var sleepHours: Double?
    var hydrationLiters: Double?
    var caffeineMg: Int?
    var alcoholUnits: Int?
    var periodTag: PeriodTag?
    var medsTaken: [String]

    init(
        sleepHours: Double? = nil,
        hydrationLiters: Double? = nil,
        caffeineMg: Int? = nil,
        alcoholUnits: Int? = nil,
        periodTag: PeriodTag? = nil,
        medsTaken: [String] = []
    ) {
        self.sleepHours = sleepHours
        self.hydrationLiters = hydrationLiters
        self.caffeineMg = caffeineMg
        self.alcoholUnits = alcoholUnits
        self.periodTag = periodTag
        self.medsTaken = medsTaken
    }
}

enum PeriodTag: String, Codable, CaseIterable {
    case none
    case menstruation
    case ovulation
    case luteal
}
