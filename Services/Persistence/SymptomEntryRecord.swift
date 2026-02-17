import Foundation
import SwiftData

@Model
final class SymptomEntryRecord {
    @Attribute(.unique) var id: UUID
    var ownerUserID: String?
    var createdAt: Date
    var updatedAt: Date
    var payload: Data

    init(id: UUID, ownerUserID: String? = nil, createdAt: Date, updatedAt: Date, payload: Data) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.payload = payload
    }
}
