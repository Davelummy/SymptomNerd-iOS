import Foundation
import SwiftData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SwiftDataStore: PersistenceClient {
    private let context: ModelContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let defaults = UserDefaults.standard
    private let dbSyncKeyPrefix = "sync.symptoms.last."

    init(context: ModelContext) {
        self.context = context
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func fetchEntries() async throws -> [SymptomEntry] {
        let scopeID = currentScopeID()
        if scopeID != "guest" {
            try migrateLegacyRecordsIfNeeded(to: scopeID)
        }
        let localRecords = try fetchLocalRecords(ownerUserID: scopeID)
        if let userID = currentUserID() {
            await syncWithCloud(userID: userID, localRecords: localRecords)
        }
        return try fetchLocalEntries(ownerUserID: scopeID)
    }

    func save(entry: SymptomEntry) async throws {
        let payload = try encoder.encode(entry)
        let scopeID = currentScopeID()

        if let existing = try fetchRecord(id: entry.id, ownerUserID: scopeID) {
            existing.createdAt = entry.createdAt
            existing.updatedAt = entry.updatedAt
            existing.payload = payload
        } else {
            let record = SymptomEntryRecord(
                id: entry.id,
                ownerUserID: scopeID,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt,
                payload: payload
            )
            context.insert(record)
        }

        try context.save()

        if let userID = currentUserID() {
            do {
                try await saveRemote(entry: entry, payload: payload, userID: userID)
                defaults.set(Date(), forKey: lastSyncKey(for: userID))
            } catch {
                // Keep local save authoritative; next fetch will retry remote sync.
            }
        }
    }

    func delete(entryID: UUID) async throws {
        let scopeID = currentScopeID()
        if let record = try fetchRecord(id: entryID, ownerUserID: scopeID) {
            context.delete(record)
            try context.save()
        }

        if let userID = currentUserID() {
            do {
                try await deleteRemote(entryID: entryID, userID: userID)
                defaults.set(Date(), forKey: lastSyncKey(for: userID))
            } catch {
                // Ignore remote delete failures for offline resilience.
            }
        }
    }

    func deleteAll() async throws {
        let records = try fetchLocalRecords(ownerUserID: currentScopeID())
        for record in records {
            context.delete(record)
        }
        try context.save()

        if let userID = currentUserID() {
            do {
                try await deleteAllRemoteEntries(userID: userID)
                defaults.set(Date(), forKey: lastSyncKey(for: userID))
            } catch {
                // Ignore remote failure; cloud clear can be retried later.
            }
        }
    }

    private func fetchRecord(id: UUID, ownerUserID: String) throws -> SymptomEntryRecord? {
        let descriptor = FetchDescriptor<SymptomEntryRecord>(
            predicate: #Predicate { $0.id == id && $0.ownerUserID == ownerUserID }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchLocalRecords(ownerUserID: String) throws -> [SymptomEntryRecord] {
        let descriptor = FetchDescriptor<SymptomEntryRecord>(
            predicate: #Predicate { $0.ownerUserID == ownerUserID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchLocalEntries(ownerUserID: String) throws -> [SymptomEntry] {
        try fetchLocalRecords(ownerUserID: ownerUserID).compactMap { record in
            try? decoder.decode(SymptomEntry.self, from: record.payload)
        }
    }

    private func currentScopeID() -> String {
        currentUserID() ?? "guest"
    }

    private func migrateLegacyRecordsIfNeeded(to ownerUserID: String) throws {
        let descriptor = FetchDescriptor<SymptomEntryRecord>(
            predicate: #Predicate { $0.ownerUserID == nil }
        )
        let legacy = try context.fetch(descriptor)
        guard !legacy.isEmpty else { return }
        for record in legacy {
            record.ownerUserID = ownerUserID
        }
        try context.save()
    }

    private func currentUserID() -> String? {
        guard FirebaseApp.app() != nil else { return nil }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return nil }
        return uid
    }

    private func lastSyncKey(for userID: String) -> String {
        dbSyncKeyPrefix + userID
    }

    private func syncWithCloud(userID: String, localRecords: [SymptomEntryRecord]) async {
        guard FirebaseApp.app() != nil else { return }
        let collection = Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("symptom_entries")

        do {
            let remoteSnapshot = try await collection.getDocuments()
            var remoteByID: [UUID: SymptomEntry] = [:]
            for doc in remoteSnapshot.documents {
                guard let remote = decodeRemoteEntry(from: doc) else { continue }
                remoteByID[remote.id] = remote
            }

            let localEntries = localRecords.compactMap { try? decoder.decode(SymptomEntry.self, from: $0.payload) }
            let localByID = Dictionary(uniqueKeysWithValues: localEntries.map { ($0.id, $0) })

            var didMutateLocal = false

            for remote in remoteByID.values {
                if let local = localByID[remote.id] {
                    if remote.updatedAt > local.updatedAt {
                        let payload = try encoder.encode(remote)
                        if let record = try fetchRecord(id: remote.id, ownerUserID: userID) {
                            record.createdAt = remote.createdAt
                            record.updatedAt = remote.updatedAt
                            record.payload = payload
                            didMutateLocal = true
                        }
                    } else if local.updatedAt > remote.updatedAt {
                        let payload = try encoder.encode(local)
                        try await saveRemote(entry: local, payload: payload, userID: userID)
                    }
                } else {
                    let payload = try encoder.encode(remote)
                    let record = SymptomEntryRecord(
                        id: remote.id,
                        ownerUserID: userID,
                        createdAt: remote.createdAt,
                        updatedAt: remote.updatedAt,
                        payload: payload
                    )
                    context.insert(record)
                    didMutateLocal = true
                }
            }

            for local in localEntries where remoteByID[local.id] == nil {
                let payload = try encoder.encode(local)
                try await saveRemote(entry: local, payload: payload, userID: userID)
            }

            if didMutateLocal {
                try context.save()
            }

            defaults.set(Date(), forKey: lastSyncKey(for: userID))
        } catch {
            // Keep local data available even when sync fails.
        }
    }

    private func decodeRemoteEntry(from document: QueryDocumentSnapshot) -> SymptomEntry? {
        let data = document.data()
        guard let payloadString = data["payload"] as? String,
              let payload = Data(base64Encoded: payloadString) else {
            return nil
        }
        return try? decoder.decode(SymptomEntry.self, from: payload)
    }

    private func saveRemote(entry: SymptomEntry, payload: Data, userID: String) async throws {
        let ref = Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("symptom_entries")
            .document(entry.id.uuidString)

        try await ref.setData([
            "id": entry.id.uuidString,
            "createdAt": Timestamp(date: entry.createdAt),
            "updatedAt": Timestamp(date: entry.updatedAt),
            "payload": payload.base64EncodedString()
        ], merge: true)
    }

    private func deleteRemote(entryID: UUID, userID: String) async throws {
        let ref = Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("symptom_entries")
            .document(entryID.uuidString)
        try await ref.delete()
    }

    private func deleteAllRemoteEntries(userID: String) async throws {
        let collection = Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("symptom_entries")
        let snapshot = try await collection.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
}
