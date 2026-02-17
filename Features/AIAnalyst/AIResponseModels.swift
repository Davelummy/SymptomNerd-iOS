import Foundation

struct AIInsightResponse: Codable, Equatable {
    let recap: String
    let patterns: [String]
    let suggestions: [String]
    let redFlags: [AIInsightRedFlag]
    let questionsForClinician: [String]
    let disclaimer: String
}

struct AIInsightRedFlag: Codable, Equatable {
    let title: String
    let whyItMatters: String
    let action: String
}
