import Foundation

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published private(set) var entries: [SymptomEntry] = []
    @Published var errorMessage: String?

    private var client: PersistenceClient?

    func configure(client: PersistenceClient) {
        if self.client == nil {
            self.client = client
        }
    }

    func load() async {
        guard let client else { return }
        do {
            entries = try await client.fetchEntries()
        } catch {
            errorMessage = "Failed to load entries."
        }
    }

    func delete(entry: SymptomEntry) async {
        guard let client else { return }
        do {
            try await client.delete(entryID: entry.id)
            await load()
        } catch {
            errorMessage = "Failed to delete entry."
        }
    }
}
