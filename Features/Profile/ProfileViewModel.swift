import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

struct MedicalProfileData: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date? = nil
    var sexAtBirth: String = ""
    var bloodGroup: String = ""
    var allergies: String = ""
    var chronicConditions: String = ""
    var currentMedications: String = ""
    var pastSurgeries: String = ""
    var familyHistory: String = ""
    var notesForCareTeam: String = ""
}

struct HealthHistoryRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var details: String
    var date: Date = Date()
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var entries: [SymptomEntry] = []
    @Published var errorMessage: String?
    @Published var medicalProfile: MedicalProfileData = MedicalProfileData()
    @Published var healthHistory: [HealthHistoryRecord] = []

    private var client: PersistenceClient?
    private let defaults = UserDefaults.standard
    private let profilePrefix = "profile.medical."
    private let historyPrefix = "profile.history."
    private let updatedPrefix = "profile.updated."

    func configure(client: PersistenceClient) {
        if self.client == nil { self.client = client }
    }

    func load() async {
        guard let client else { return }
        do {
            entries = try await client.fetchEntries()
            loadMedicalData()
            await syncMedicalDataFromCloud()
        } catch {
            errorMessage = "Failed to load health records."
        }
    }

    func saveMedicalProfile() {
        saveMedicalProfileToDefaults()
        markMedicalDataUpdatedLocally()
        Task { await pushMedicalDataToCloud() }
    }

    func addHistoryRecord(title: String, details: String, date: Date = Date()) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedDetails.isEmpty else { return }
        let item = HealthHistoryRecord(title: trimmedTitle.isEmpty ? "Health note" : trimmedTitle, details: trimmedDetails, date: date)
        healthHistory.insert(item, at: 0)
        saveHistory()
        markMedicalDataUpdatedLocally()
        Task { await pushMedicalDataToCloud() }
    }

    func deleteHistoryRecord(id: UUID) {
        healthHistory.removeAll { $0.id == id }
        saveHistory()
        markMedicalDataUpdatedLocally()
        Task { await pushMedicalDataToCloud() }
    }

    var lastEntry: SymptomEntry? {
        entries.sorted { $0.createdAt > $1.createdAt }.first
    }

    var averageSeverity: Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.severity }
        return Double(total) / Double(entries.count)
    }

    var last7DaysCount: Int {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.createdAt >= start }.count
    }

    var mostCommonSymptom: String {
        let grouped = Dictionary(grouping: entries, by: { $0.symptomType.name })
        let sorted = grouped.sorted { $0.value.count > $1.value.count }
        return sorted.first?.key ?? "—"
    }

    var commonTriggers: [String] {
        let triggers = entries.flatMap { $0.possibleTriggers.map { $0.rawValue.capitalized } }
        let grouped = Dictionary(grouping: triggers, by: { $0 })
        let sorted = grouped.sorted { $0.value.count > $1.value.count }
        return sorted.prefix(3).map { $0.key }
    }

    private func loadMedicalData() {
        if let profileData = defaults.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(MedicalProfileData.self, from: profileData) {
            medicalProfile = decoded
        } else if let name = Auth.auth().currentUser?.displayName, !name.isEmpty {
            let parts = name.split(separator: " ").map(String.init)
            medicalProfile.firstName = parts.first ?? ""
            medicalProfile.lastName = parts.dropFirst().joined(separator: " ")
        }

        if let historyData = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HealthHistoryRecord].self, from: historyData) {
            healthHistory = decoded.sorted(by: { $0.date > $1.date })
        }
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(healthHistory) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private func saveMedicalProfileToDefaults() {
        guard let data = try? JSONEncoder().encode(medicalProfile) else { return }
        defaults.set(data, forKey: profileKey)
    }

    private func markMedicalDataUpdatedLocally() {
        defaults.set(Date(), forKey: updatedKey)
    }

    private func syncMedicalDataFromCloud() async {
        guard FirebaseApp.app() != nil else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document("medical_data")

        do {
            let snapshot = try await ref.getDocument()
            guard let data = snapshot.data() else {
                await pushMedicalDataToCloud()
                return
            }

            let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let localUpdated = defaults.object(forKey: updatedKey) as? Date ?? .distantPast

            if remoteUpdated > localUpdated {
                if let profileBase64 = data["profile"] as? String,
                   let profileData = Data(base64Encoded: profileBase64),
                   let decodedProfile = try? JSONDecoder().decode(MedicalProfileData.self, from: profileData) {
                    medicalProfile = decodedProfile
                    defaults.set(profileData, forKey: profileKey)
                }

                if let historyBase64 = data["history"] as? String,
                   let historyData = Data(base64Encoded: historyBase64),
                   let decodedHistory = try? JSONDecoder().decode([HealthHistoryRecord].self, from: historyData) {
                    healthHistory = decodedHistory.sorted(by: { $0.date > $1.date })
                    defaults.set(historyData, forKey: historyKey)
                }
                defaults.set(remoteUpdated, forKey: updatedKey)
            } else {
                await pushMedicalDataToCloud()
            }
        } catch {
            // Ignore cloud sync failures; local data remains available.
        }
    }

    private func pushMedicalDataToCloud() async {
        guard FirebaseApp.app() != nil else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        guard let profileData = try? JSONEncoder().encode(medicalProfile),
              let historyData = try? JSONEncoder().encode(healthHistory) else {
            return
        }

        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document("medical_data")

        do {
            try await ref.setData([
                "profile": profileData.base64EncodedString(),
                "history": historyData.base64EncodedString(),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
            defaults.set(Date(), forKey: updatedKey)
        } catch {
            // Best effort cloud sync.
        }
    }

    private var userScope: String {
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty { return uid }
        return "guest"
    }

    private var profileKey: String {
        profilePrefix + userScope
    }

    private var historyKey: String {
        historyPrefix + userScope
    }

    private var updatedKey: String {
        updatedPrefix + userScope
    }
}
