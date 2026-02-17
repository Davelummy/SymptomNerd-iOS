import Foundation
import FirebaseAuth

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var input: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRequestSummary: AIRequestSummary?

    private var client: AIClient?
    private var persistence: PersistenceClient?
    private var consentManager: AIConsentManager?
    private var lastQuestion: String?
    private var lastRequest: AIRequest?
    private let conversationStore = AIConversationStore()
    private let defaults = UserDefaults.standard
    private let profilePrefix = "profile.medical."
    private let historyPrefix = "profile.history."

    func configure(client: AIClient, persistence: PersistenceClient, consentManager: AIConsentManager) {
        if self.client == nil {
            self.client = client
            self.persistence = persistence
            self.consentManager = consentManager
            if consentManager.saveConversations {
                let saved = conversationStore.load()
                messages = saved
            }
            seedWelcomeMessage()
        }
    }

    func send() async {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        lastQuestion = question
        input = ""
        errorMessage = nil

        let userMessage = AIChatMessage(role: .user, content: question)
        messages.append(userMessage)
        persistIfNeeded()

        await requestResponse(for: question)
    }

    func retryLast() async {
        guard let lastQuestion else { return }
        errorMessage = nil
        await requestResponse(for: lastQuestion)
    }

    private func requestResponse(for question: String) async {
        guard let client else { return }
        isLoading = true

        do {
            let request = buildRequest(question: question)
            lastRequest = request
            let response = try await client.chat(messages: messages, request: request)
            let refined = refineResponse(response, question: question)
            let formatted = formatResponse(refined)
            await streamAssistantResponse(formatted)
            isLoading = false
        } catch {
            isLoading = false
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorMessage = message.isEmpty ? "Something went wrong." : message
        }
    }

    private func buildRequest(question: String) -> AIRequest {
        let now = Date()
        let timeframe = Timeframe(start: now, end: now)
        let isMinimizationOn = consentManager?.dataMinimizationOn ?? true
        let request = AIRequest(
            userQuestion: question,
            entries: [],
            timeframe: timeframe,
            userPrefs: AIUserPrefs(dataMinimizationOn: isMinimizationOn),
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            preferredLanguage: defaults.string(forKey: "ai.preferredLanguage") ?? "English",
            medicalContext: loadMedicalContext()
        )
        lastRequestSummary = AIRequestSummary(from: request, entryCount: 0, symptomNames: [])
        return request
    }

    func makeHandoffPayload() -> HandoffPayload {
        let request = lastRequest ?? AIRequest(
            userQuestion: lastQuestion ?? "I need help from a pharmacist.",
            entries: [],
            timeframe: Timeframe(start: Date(), end: Date()),
            userPrefs: AIUserPrefs(dataMinimizationOn: true),
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            preferredLanguage: defaults.string(forKey: "ai.preferredLanguage") ?? "English",
            medicalContext: loadMedicalContext()
        )

        let summary = """
        User question: \(lastQuestion ?? "")
        Entries shared: \(request.entries.count)
        Timeframe: \(request.timeframe.start.formatted(date: .abbreviated, time: .omitted)) to \(request.timeframe.end.formatted(date: .abbreviated, time: .omitted))
        """
        return HandoffPayload(
            userMessage: lastQuestion ?? "I need help from a pharmacist.",
            summarizedLogs: summary,
            attachedRange: DateInterval(start: request.timeframe.start, end: request.timeframe.end)
        )
    }

    private func formatResponse(_ response: AIResponse) -> String {
        var lines: [String] = []
        lines.append("Summary")
        lines.append(response.recap)
        if !response.patterns.isEmpty {
            lines.append("\nObserved patterns")
            response.patterns.forEach { lines.append("• \($0)") }
        }
        if !response.suggestions.isEmpty {
            lines.append("\nPossible explanations and options")
            response.suggestions.forEach { lines.append("• \($0)") }
        }
        if !response.redFlags.isEmpty {
            lines.append("\nRed flags to watch")
            response.redFlags.forEach { flag in
                lines.append("• \(flag.title) — \(flag.action)")
            }
        }
        if !response.questionsForClinician.isEmpty {
            lines.append("\nFollow-up questions")
            response.questionsForClinician.forEach { lines.append("• \($0)") }
        }
        lines.append("\nWhen to escalate")
        lines.append(response.disclaimer)
        return lines.joined(separator: "\n")
    }

    private func refineResponse(_ response: AIResponse, question: String) -> AIResponse {
        var recapText = response.recap
        var disclaimerText = response.disclaimer
        var followUps = response.questionsForClinician
        let questionTrimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !questionTrimmed.isEmpty {
            let recapLower = recapText.lowercased()
            let questionLower = questionTrimmed.lowercased()
            let keywords = questionLower
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
                .split(separator: " ")
                .filter { $0.count >= 4 }
            let mentionsKeyword = keywords.isEmpty
                ? recapLower.contains(questionLower)
                : keywords.contains { recapLower.contains($0) }
            let summaryUnavailable = recapLower.contains("summary unavailable") || recapLower.contains("summary not available")
            if !mentionsKeyword || summaryUnavailable {
                recapText = "You asked about \(questionTrimmed). " + recapText
            }
        }
        if followUps.isEmpty {
            followUps.append("What changed first, what makes symptoms better or worse, and have any medications recently changed?")
        }
        if !disclaimerText.lowercased().contains("pharmacist") {
            disclaimerText += " If this is not improving or you need medication guidance, start a pharmacist chat or live call."
        }
        if !disclaimerText.lowercased().contains("emergency") {
            disclaimerText = disclaimerText + " If you think this may be an emergency, call your local emergency number."
        }
        return AIResponse(
            recap: recapText,
            patterns: response.patterns,
            suggestions: response.suggestions,
            redFlags: response.redFlags,
            questionsForClinician: followUps,
            disclaimer: disclaimerText
        )
    }

    private func streamAssistantResponse(_ text: String) async {
        let messageID = UUID()
        messages.append(AIChatMessage(id: messageID, role: .assistant, content: ""))

        let words = text.split(separator: " ")
        var current = ""
        for word in words {
            current += (current.isEmpty ? "" : " ") + word
            if let index = messages.firstIndex(where: { $0.id == messageID }) {
                messages[index] = AIChatMessage(id: messageID, role: .assistant, content: current)
            }
            try? await Task.sleep(nanoseconds: 35_000_000)
        }
        persistIfNeeded()
    }

    private func seedWelcomeMessage() {
        if messages.isEmpty {
            let welcome = "Hi! Ask me any symptom or medication-safety question. This chat responds to your message directly. For logged symptom trend analysis, use AI Insights."
            messages.append(AIChatMessage(role: .assistant, content: welcome))
            persistIfNeeded()
        }
    }

    private func persistIfNeeded() {
        guard let consentManager, consentManager.saveConversations else { return }
        conversationStore.save(messages)
    }

    private func loadMedicalContext() -> AIMedicalContext? {
        let scope = Auth.auth().currentUser?.uid ?? "guest"
        let profileKey = profilePrefix + scope
        let historyKey = historyPrefix + scope

        let profile: MedicalProfileData
        if let data = defaults.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(MedicalProfileData.self, from: data) {
            profile = decoded
        } else {
            profile = MedicalProfileData()
        }

        let historyItems: [HealthHistoryRecord]
        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HealthHistoryRecord].self, from: data) {
            historyItems = decoded.sorted(by: { $0.date > $1.date })
        } else {
            historyItems = []
        }

        if profile == MedicalProfileData() && historyItems.isEmpty {
            return nil
        }

        return AIMedicalContext(
            allergies: profile.allergies,
            chronicConditions: profile.chronicConditions,
            currentMedications: profile.currentMedications,
            pastSurgeries: profile.pastSurgeries,
            familyHistory: profile.familyHistory,
            notesForCareTeam: profile.notesForCareTeam,
            recentHealthHistory: historyItems.prefix(6).map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.title) \($0.details)" }
        )
    }
}
