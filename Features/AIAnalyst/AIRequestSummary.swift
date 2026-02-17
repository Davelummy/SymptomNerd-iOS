import Foundation

struct AIRequestSummary {
    let question: String
    let entryCount: Int
    let symptomNames: [String]
    let timeframe: Timeframe
    let dataMinimizationOn: Bool

    init(from request: AIRequest, entryCount: Int, symptomNames: [String]) {
        self.question = request.userQuestion
        self.entryCount = entryCount
        self.symptomNames = Array(Set(symptomNames)).sorted()
        self.timeframe = request.timeframe
        self.dataMinimizationOn = request.userPrefs.dataMinimizationOn
    }
}
