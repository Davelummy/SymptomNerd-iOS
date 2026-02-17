import Foundation

enum SymptomQuality: String, Codable, CaseIterable {
    case throbbing
    case sharp
    case dull
    case itchy
    case burning
    case pressure

    var displayName: String {
        rawValue.capitalized
    }
}

enum AssociatedSymptom: String, Codable, CaseIterable {
    case nausea
    case fatigue
    case dizziness
    case sensitivityToLight
    case sensitivityToSound

    var displayName: String {
        switch self {
        case .sensitivityToLight: return "Sensitivity to light"
        case .sensitivityToSound: return "Sensitivity to sound"
        default: return rawValue.capitalized
        }
    }
}

enum Trigger: String, Codable, CaseIterable {
    case stress
    case food
    case sleep
    case weather
    case exercise
    case alcohol
    case screens

    var displayName: String {
        rawValue.capitalized
    }
}

enum RedFlag: String, Codable, CaseIterable {
    case severeOrSuddenPain
    case chestPain
    case shortnessOfBreath
    case fainting
    case neurologicalChanges
    case heavyBleeding

    var displayName: String {
        switch self {
        case .severeOrSuddenPain: return "Severe or sudden pain"
        case .chestPain: return "Chest pain"
        case .shortnessOfBreath: return "Shortness of breath"
        case .fainting: return "Fainting"
        case .neurologicalChanges: return "Neurological changes"
        case .heavyBleeding: return "Heavy bleeding"
        }
    }
}
