import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

@MainActor
final class AIInsightsViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(AIResponse)
        case failed(String)
    }

    @Published var state: State = .idle
    @Published var selectedRange: InsightsRange = .sevenDays
    @Published var lastTimeframe: Timeframe?

    private var client: AIClient?
    private var persistence: PersistenceClient?
    private var consentManager: AIConsentManager?
    private let defaults = UserDefaults.standard

    func configure(client: AIClient, persistence: PersistenceClient, consentManager: AIConsentManager) {
        if self.client == nil {
            self.client = client
            self.persistence = persistence
            self.consentManager = consentManager
        }
    }

    func analyze() async {
        guard let client, let persistence, let consentManager else { return }
        state = .loading

        do {
            let request = try await buildRequest(persistence: persistence, consentManager: consentManager)
            lastTimeframe = request.timeframe
            let response = try await client.analyze(request: request)
            state = .loaded(response)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .failed(message.isEmpty ? "Unable to analyze logs." : message)
        }
    }

    private func buildRequest(
        persistence: PersistenceClient,
        consentManager: AIConsentManager
    ) async throws -> AIRequest {
        let now = Date()
        let rangeStart = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: now) ?? now
        let entries = try await persistence.fetchEntries()
        let filtered = entries.filter { $0.createdAt >= rangeStart && $0.createdAt <= now }
        let summaries = filtered.map { entry in
            SymptomEntrySummary(
                id: entry.id,
                symptomType: entry.symptomType.name,
                severity: entry.severity,
                onset: entry.onset,
                durationMinutes: entry.durationMinutes,
                triggers: entry.possibleTriggers.map { $0.rawValue },
                notes: entry.notes.isEmpty ? nil : entry.notes,
                medsTaken: consentManager.dataMinimizationOn ? [] : entry.context.medsTaken,
                sleepHours: consentManager.dataMinimizationOn ? nil : entry.context.sleepHours,
                hydrationLiters: consentManager.dataMinimizationOn ? nil : entry.context.hydrationLiters,
                caffeineMg: consentManager.dataMinimizationOn ? nil : entry.context.caffeineMg,
                alcoholUnits: consentManager.dataMinimizationOn ? nil : entry.context.alcoholUnits
            )
        }

        let timeframeStart = filtered.map(\.createdAt).min() ?? rangeStart
        let timeframeEnd = filtered.map(\.createdAt).max() ?? now
        let timeframe = Timeframe(start: timeframeStart, end: timeframeEnd)
        return AIRequest(
            userQuestion: "Analyze my logs for patterns.",
            entries: summaries,
            timeframe: timeframe,
            userPrefs: AIUserPrefs(dataMinimizationOn: consentManager.dataMinimizationOn),
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            preferredLanguage: UserDefaults.standard.string(forKey: "ai.preferredLanguage") ?? "English",
            medicalContext: await loadMedicalContext()
        )
    }

    private func loadMedicalContext() async -> AIMedicalContext? {
        await refreshMedicalContextFromCloud()
        let scope = Auth.auth().currentUser?.uid ?? "guest"
        let profileKey = "profile.medical." + scope
        let historyKey = "profile.history." + scope
        let profile = defaults.data(forKey: profileKey).flatMap { try? JSONDecoder().decode(MedicalProfileData.self, from: $0) }
        let history = defaults.data(forKey: historyKey).flatMap { try? JSONDecoder().decode([HealthHistoryRecord].self, from: $0) } ?? []
        let normalizedHistory = history
            .sorted(by: { $0.date > $1.date })
            .prefix(12)
            .map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.title) \($0.details)" }

        func profileSummary(_ profile: MedicalProfileData?) -> String {
            guard let profile else { return "" }
            var parts: [String] = []
            let fullName = "\(profile.firstName) \(profile.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !fullName.isEmpty { parts.append("Name: \(fullName)") }
            if let dob = profile.dateOfBirth {
                parts.append("DOB: \(dob.formatted(date: .abbreviated, time: .omitted))")
            }
            if !profile.sexAtBirth.isEmpty { parts.append("Sex at birth: \(profile.sexAtBirth)") }
            if !profile.bloodGroup.isEmpty { parts.append("Blood group: \(profile.bloodGroup)") }
            return parts.joined(separator: " • ")
        }

        guard let profile else {
            if history.isEmpty { return nil }
            return AIMedicalContext(
                allergies: "",
                chronicConditions: "",
                currentMedications: "",
                pastSurgeries: "",
                familyHistory: "",
                notesForCareTeam: "Use health history context in your analysis.",
                recentHealthHistory: normalizedHistory
            )
        }
        let demographics = profileSummary(profile)
        let notesBlock = [demographics, profile.notesForCareTeam]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        return AIMedicalContext(
            allergies: profile.allergies,
            chronicConditions: profile.chronicConditions,
            currentMedications: profile.currentMedications,
            pastSurgeries: profile.pastSurgeries,
            familyHistory: profile.familyHistory,
            notesForCareTeam: notesBlock,
            recentHealthHistory: normalizedHistory
        )
    }

    private func refreshMedicalContextFromCloud() async {
        guard FirebaseApp.app() != nil else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document("medical_data")
        do {
            let snapshot = try await ref.getDocument()
            guard let data = snapshot.data() else { return }
            if let profileBase64 = data["profile"] as? String,
               let profileData = Data(base64Encoded: profileBase64) {
                defaults.set(profileData, forKey: "profile.medical." + uid)
            }
            if let historyBase64 = data["history"] as? String,
               let historyData = Data(base64Encoded: historyBase64) {
                defaults.set(historyData, forKey: "profile.history." + uid)
            }
        } catch {
            // Best effort refresh; local cache stays in use on failure.
        }
    }
}

enum InsightsRange: String, CaseIterable {
    case sevenDays = "7 days"
    case thirtyDays = "30 days"
    case ninetyDays = "90 days"

    var days: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }
}
