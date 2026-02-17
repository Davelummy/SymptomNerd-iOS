import Foundation

struct SymptomType: Identifiable, Codable, Equatable, Hashable {
    var id: String { name.lowercased() }
    let name: String
    let category: String
    let isCustom: Bool

    init(name: String, category: String = "General", isCustom: Bool = false) {
        self.name = name
        self.category = category
        self.isCustom = isCustom
    }

    static let presets: [SymptomType] = [
        SymptomType(name: "Headache", category: "Pain"),
        SymptomType(name: "Nausea", category: "Digestive"),
        SymptomType(name: "Fatigue", category: "Energy"),
        SymptomType(name: "Dizziness", category: "Neurological"),
        SymptomType(name: "Cramps", category: "Pain")
    ]
}
