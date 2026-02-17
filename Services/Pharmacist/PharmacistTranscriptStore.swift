import Foundation

struct PharmacistTranscriptStore {
    private let key = "pharmacist.transcripts"
    private let defaults = UserDefaults.standard

    func save(sessionID: UUID, messages: [PharmacistMessage]) {
        let transcript = PharmacistTranscript(id: sessionID, createdAt: Date(), messages: messages)
        var current = loadAll()
        current.removeAll { $0.id == sessionID }
        current.append(transcript)
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: key)
        }
    }

    func loadAll() -> [PharmacistTranscript] {
        guard let data = defaults.data(forKey: key),
              let transcripts = try? JSONDecoder().decode([PharmacistTranscript].self, from: data) else {
            return []
        }
        return transcripts
    }
}

struct PharmacistTranscript: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let messages: [PharmacistMessage]
}
