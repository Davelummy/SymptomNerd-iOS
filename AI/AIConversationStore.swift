import Foundation

struct AIConversationStore {
    private let key = "ai.chatMessages"
    private let defaults = UserDefaults.standard

    func save(_ messages: [AIChatMessage]) {
        if let data = try? JSONEncoder().encode(messages) {
            defaults.set(data, forKey: key)
        }
    }

    func load() -> [AIChatMessage] {
        guard let data = defaults.data(forKey: key),
              let messages = try? JSONDecoder().decode([AIChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
