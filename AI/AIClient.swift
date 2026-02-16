import Foundation

@MainActor
final class AIClient {
    private let provider: AIProvider
    private let consentManager: AIConsentManager

    init(provider: AIProvider, consentManager: AIConsentManager) {
        self.provider = provider
        self.consentManager = consentManager
    }

    func analyze(request: AIRequest) async throws -> AIResponse {
        try ensureConsent()
        return try await provider.analyze(request: request)
    }

    func chat(messages: [AIChatMessage], request: AIRequest) async throws -> AIResponse {
        try ensureConsent()
        return try await provider.chat(messages: messages, request: request)
    }

    private func ensureConsent() throws {
        if !consentManager.hasConsented {
            throw AIClientError.consentRequired
        }
    }
}

enum AIClientError: LocalizedError {
    case consentRequired

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "Consent is required before using AI insights."
        }
    }
}
