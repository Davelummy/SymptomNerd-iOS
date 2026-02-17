import SwiftUI
import SwiftData

struct AIInsightsInlineView: View {
    @Environment(AIConsentManager.self) private var consentManager
    @Environment(AIProviderSettings.self) private var aiSettings
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AIInsightsViewModel()
    @State private var showHandoffSheet = false
    @State private var handoffPayload: HandoffPayload?

    var body: some View {
        Group {
            if consentManager.hasConsented {
                AIInsightsPanel(
                    state: viewModel.state,
                    selectedRange: $viewModel.selectedRange,
                    onAnalyze: { Task { await viewModel.analyze() } },
                    onNotHelpful: { response in
                        let timeframe = viewModel.lastTimeframe ?? Timeframe(start: Date(), end: Date())
                        handoffPayload = HandoffPayload(
                            userMessage: "I would like to talk to a pharmacist about my symptoms.",
                            summarizedLogs: response.recap,
                            attachedRange: DateInterval(start: timeframe.start, end: timeframe.end)
                        )
                        showHandoffSheet = true
                    }
                )
            } else {
                AIDisclaimerView()
            }
        }
        .sheet(isPresented: $showHandoffSheet) {
            if let payload = handoffPayload {
                PharmacistHandoffSheet(handoff: payload)
            }
        }
        .task {
            let provider = AIProviderFactory.makeProvider(configuration: aiSettings.configuration)
            let client = AIClient(provider: provider, consentManager: consentManager)
            viewModel.configure(client: client, persistence: SwiftDataStore(context: modelContext), consentManager: consentManager)
        }
    }
}

#Preview {
    AIInsightsInlineView()
        .environment(AIConsentManager())
        .environment(AIProviderSettings())
        .modelContainer(for: SymptomEntryRecord.self, inMemory: true)
}
