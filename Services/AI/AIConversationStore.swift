import Foundation
import FirebaseAuth

struct AIConversationStore {
    private let defaults = UserDefaults.standard

    func save(_ messages: [AIChatMessage]) {
        if let data = try? JSONEncoder().encode(messages) {
            defaults.set(data, forKey: storageKey())
        }
    }

    func load() -> [AIChatMessage] {
        guard let data = defaults.data(forKey: storageKey()),
              let messages = try? JSONDecoder().decode([AIChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    func clear() {
        defaults.removeObject(forKey: storageKey())
    }

    private func storageKey() -> String {
        let uid = Auth.auth().currentUser?.uid ?? "guest"
        return "ai.chatMessages.\(uid)"
    }
}
