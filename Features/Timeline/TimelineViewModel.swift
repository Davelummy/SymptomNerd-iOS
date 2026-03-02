import Foundation

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published private(set) var entries: [SymptomEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var client: PersistenceClient?

    func configure(client: PersistenceClient) {
        if self.client == nil {
            self.client = client
        }
    }

    func load() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await client.fetchEntries()
            errorMessage = nil
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

    func restore(entry: SymptomEntry) async {
        guard let client else { return }
        do {
            try await client.save(entry: entry)
            await load()
        } catch {
            errorMessage = "Failed to restore entry."
        }
    }
}
