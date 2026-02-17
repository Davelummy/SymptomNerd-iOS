import Foundation

protocol PersistenceClient {
    func fetchEntries() async throws -> [SymptomEntry]
    func save(entry: SymptomEntry) async throws
    func delete(entryID: UUID) async throws
    func deleteAll() async throws
}
