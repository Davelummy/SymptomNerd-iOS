import Foundation

protocol AIProvider {
    func analyze(request: AIRequest) async throws -> AIResponse
    func chat(messages: [AIChatMessage], request: AIRequest) async throws -> AIResponse
}
