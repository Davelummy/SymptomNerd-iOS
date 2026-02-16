import Foundation

struct MockAIProvider: AIProvider {
    func analyze(request: AIRequest) async throws -> AIResponse {
        try simulateErrors(for: request.userQuestion)
        let recap = "You logged \(request.entries.count) entries between \(request.timeframe.start.formatted(date: .abbreviated, time: .omitted)) and \(request.timeframe.end.formatted(date: .abbreviated, time: .omitted))."

        let patterns = [
            "Symptoms appear more often on days with lower sleep.",
            "Higher severity is sometimes reported after stress-related triggers."
        ]

        let suggestions = [
            "Keep tracking sleep and stress to see if the pattern holds.",
            "Consider adding notes about meals, hydration, and screen time.",
            "If symptoms worsen or feel unusual, consider checking in with a clinician."
        ]

        let redFlags = [
            AIRedFlag(
                title: "Severe or sudden changes",
                whyItMatters: "A sudden change in symptom pattern can be important to review.",
                action: "If you think this may be an emergency, call your local emergency number."
            )
        ]

        let questions = [
            "Are there specific triggers that could explain the timing?",
            "Would it be useful to review any recent medication or lifestyle changes?",
            "What signs would mean I should seek urgent care?"
        ]

        return AIResponse(
            recap: recap,
            patterns: patterns,
            suggestions: suggestions,
            redFlags: redFlags,
            questionsForClinician: questions,
            disclaimer: "This is informational and not a medical diagnosis or advice."
        )
    }

    func chat(messages: [AIChatMessage], request: AIRequest) async throws -> AIResponse {
        try simulateErrors(for: request.userQuestion)
        let lastQuestion = messages.last { $0.role == .user }?.content ?? ""
        let recap = lastQuestion.isEmpty ? "Here is a summary of your recent logs." : "You asked: \(lastQuestion)"
        return AIResponse(
            recap: recap,
            patterns: ["I can highlight possible patterns based on your logs."],
            suggestions: ["Consider tracking related factors such as sleep or hydration."],
            redFlags: [
                AIRedFlag(
                    title: "Worsening symptoms",
                    whyItMatters: "If symptoms are rapidly worsening, it may need prompt attention.",
                    action: "If you think this may be an emergency, call your local emergency number."
                )
            ],
            questionsForClinician: ["What should I monitor over the next few days?"],
            disclaimer: "This is informational and not a medical diagnosis or advice."
        )
    }

    private func simulateErrors(for text: String) throws {
        let lowered = text.lowercased()
        if lowered.contains("[offline]") { throw AIServiceError.offline }
        if lowered.contains("[timeout]") { throw AIServiceError.timeout }
        if lowered.contains("[rate]") { throw AIServiceError.rateLimited }
        if lowered.contains("[server]") { throw AIServiceError.serverError }
    }
}
