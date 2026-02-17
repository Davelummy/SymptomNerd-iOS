import SwiftUI
import SwiftData

struct AIInsightsView: View {
    @Environment(AIConsentManager.self) private var consentManager
    @Environment(AIProviderSettings.self) private var aiSettings
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AIInsightsViewModel()
    @State private var showHandoffSheet = false
    @State private var handoffPayload: HandoffPayload?

    var body: some View {
        Group {
            if consentManager.hasConsented {
                ScrollView {
                    AIInsightsPanel(
                        state: viewModel.state,
                        selectedRange: $viewModel.selectedRange,
                        onAnalyze: { Task { await viewModel.analyze() } },
                        onNotHelpful: { response in
                            let timeframe = viewModel.lastTimeframe ?? Timeframe(start: Date(), end: Date())
                            let summary = response.recap
                            handoffPayload = HandoffPayload(
                                userMessage: "I would like to talk to a pharmacist about my symptoms.",
                                summarizedLogs: summary,
                                attachedRange: DateInterval(start: timeframe.start, end: timeframe.end)
                            )
                            showHandoffSheet = true
                        }
                    )
                        .screenPadding()
                        .padding(.vertical, Theme.spacingL)
                }
            } else {
                AIDisclaimerView()
            }
        }
        .navigationTitle("AI Insights")
        .task {
            let provider = AIProviderFactory.makeProvider(configuration: aiSettings.configuration)
            let client = AIClient(provider: provider, consentManager: consentManager)
            viewModel.configure(client: client, persistence: SwiftDataStore(context: modelContext), consentManager: consentManager)
        }
        .sheet(isPresented: $showHandoffSheet) {
            if let payload = handoffPayload {
                PharmacistHandoffSheet(handoff: payload)
            }
        }
    }
}

struct AIInsightsPanel: View {
    let state: AIInsightsViewModel.State
    @Binding var selectedRange: InsightsRange
    let onAnalyze: () -> Void
    let onNotHelpful: (AIResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            CardView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("AI Insights")
                        .font(Typography.title2)
                    Text("Pattern-based insights from your logs. Not medical advice or diagnosis.")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("Analyze my logs")
                        .font(Typography.headline)
                    Text("We will summarize your entries and highlight possible patterns.")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                    Picker("Range", selection: $selectedRange) {
                        ForEach(InsightsRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    PrimaryButton(title: "Analyze", systemImage: "sparkles") { onAnalyze() }
                }
            }

            switch state {
            case .idle:
                Text("No analysis yet. Choose a range and tap Analyze.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            case .loading:
                ProgressView("Analyzing patterns…")
            case .failed(let message):
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(.red)
            case .loaded(let response):
                AIInsightsResultView(response: response, onNotHelpful: onNotHelpful)
            }

            Text("If you think this may be an emergency, call your local emergency number.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

struct AIInsightsResultView: View {
    let response: AIResponse
    let onNotHelpful: (AIResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            CardView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("Summary")
                        .font(Typography.headline)
                    Text(response.recap)
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if !response.patterns.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Patterns noticed")
                            .font(Typography.headline)
                        ForEach(response.patterns, id: \.self) { pattern in
                            Text("• \(pattern)")
                                .font(Typography.body)
                        }
                    }
                }
            }

            if !response.suggestions.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Gentle next steps")
                            .font(Typography.headline)
                        ForEach(response.suggestions, id: \.self) { suggestion in
                            Text("• \(suggestion)")
                                .font(Typography.body)
                        }
                    }
                }
            }

            if !response.redFlags.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Red flags to watch")
                            .font(Typography.headline)
                        ForEach(response.redFlags, id: \.title) { flag in
                            Text("• \(flag.title): \(flag.action)")
                                .font(Typography.body)
                        }
                    }
                }
            }

            if !response.questionsForClinician.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Questions to ask a clinician/pharmacist")
                            .font(Typography.headline)
                        ForEach(response.questionsForClinician, id: \.self) { question in
                            Text("• \(question)")
                                .font(Typography.body)
                        }
                    }
                }
            }

            Text(response.disclaimer)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            HelpfulPromptView {
                onNotHelpful(response)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIInsightsView()
            .environment(AIConsentManager())
            .environment(AIProviderSettings())
            .modelContainer(for: SymptomEntryRecord.self, inMemory: true)
    }
}
