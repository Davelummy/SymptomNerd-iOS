import Foundation

struct AIResponse: Codable, Equatable {
    let recap: String
    let patterns: [String]
    let suggestions: [String]
    let redFlags: [AIRedFlag]
    let questionsForClinician: [String]
    let disclaimer: String
}

struct AIRedFlag: Codable, Equatable {
    let title: String
    let whyItMatters: String
    let action: String
}

struct AIChatMessage: Codable, Equatable, Identifiable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
