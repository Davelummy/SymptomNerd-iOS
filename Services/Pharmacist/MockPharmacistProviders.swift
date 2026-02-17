import Foundation
import FirebaseCore

struct MockChatProvider: ChatProvider {
    func startChat(with handoff: HandoffPayload) async throws -> PharmacistChatSession {
        let status = PharmacistAvailability(statusText: "Typically replies in 10–15 minutes", queuePosition: 2)
        let system = PharmacistMessage(role: .system, content: "Summary sent to pharmacist: \(handoff.userMessage)")
        let intro = PharmacistMessage(role: .pharmacist, content: "Thanks for reaching out. A pharmacist will review your summary shortly.")
        return PharmacistChatSession(id: UUID(), status: status, messages: [system, intro])
    }

    func send(message: String, in session: PharmacistChatSession) async throws -> PharmacistMessage {
        try await Task.sleep(nanoseconds: 400_000_000)
        return PharmacistMessage(role: .pharmacist, content: "Thanks for that detail. When did this start, and have there been any recent medication or supplement changes?")
    }
}

struct MockCallProvider: CallProvider {
    func requestCall(with handoff: HandoffPayload) async throws -> PharmacistCallStatus {
        try await Task.sleep(nanoseconds: 500_000_000)
        return .connecting("Connecting you to a pharmacist…")
    }
}

struct PharmacistServiceFactory {
    static func makeService() -> PharmacistService {
        if FirebaseApp.app() != nil {
            return PharmacistService(
                chatProvider: FirebaseChatProvider(),
                callProvider: TwilioVoiceCallProvider(fallback: FirebaseCallProvider())
            )
        }
        return PharmacistService(chatProvider: MockChatProvider(), callProvider: MockCallProvider())
    }
}
