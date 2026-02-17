import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(AIConsentManager.self) private var consentManager
    @Environment(AIProviderSettings.self) private var aiSettings
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AIChatViewModel()
    @State private var showHandoffSheet = false
    @State private var handoffPayload: HandoffPayload?
    @State private var showReportSheet = false
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool
    @State private var hideHelpfulPrompt = false
    @State private var lastHelpfulMessageID: UUID?

    var body: some View {
        Group {
            if consentManager.hasConsented {
                chatBody
            } else {
                AIDisclaimerView()
            }
        }
        .navigationTitle("Symptom Nerd AI")
        .safeAreaPadding(.bottom, Theme.tabBarHeight)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("History") { showHistory = true }
            }
        }
        .task {
            let provider = AIProviderFactory.makeProvider(configuration: aiSettings.configuration)
            let client = AIClient(provider: provider, consentManager: consentManager)
            viewModel.configure(client: client, persistence: SwiftDataStore(context: modelContext), consentManager: consentManager)
        }
        .sheet(isPresented: $showHandoffSheet) {
            if let payload = handoffPayload {
                NavigationStack {
                    PharmacistEntryView(handoff: payload)
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            AIReportIssueSheet()
        }
        .sheet(isPresented: $showHistory) {
            AIChatHistoryView()
        }
    }

    private var chatBody: some View {
        VStack(spacing: Theme.spacingS) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        ForEach(viewModel.messages) { message in
                            AIChatMessageRow(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack {
                                TypingIndicatorView()
                                Spacer()
                            }
                            .padding(.horizontal, Theme.spacingS)
                        }
                    }
                    .padding(.top, Theme.spacingM)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                        if last.role == .assistant, last.id != lastHelpfulMessageID {
                            lastHelpfulMessageID = last.id
                            hideHelpfulPrompt = false
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
                UIApplication.shared.endEditing()
            }

            if let errorMessage = viewModel.errorMessage {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text(errorMessage)
                            .font(Typography.body)
                            .foregroundStyle(.red)
                        Button("Retry") {
                            Task { await viewModel.retryLast() }
                        }
                        .font(Typography.caption)
                    }
                }
                .padding(.horizontal, Theme.spacingM)
            }

            if shouldShowHelpfulPrompt {
                HelpfulPromptView {
                    handoffPayload = viewModel.makeHandoffPayload()
                    showHandoffSheet = true
                } onDismiss: {
                    hideHelpfulPrompt = true
                }
                .padding(.horizontal, Theme.spacingM)
            }

            Divider()

            HStack(spacing: Theme.spacingS) {
                TextField("Ask about patterns or questions to ask a clinician...", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isInputFocused)

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(Color.white)
                        .padding(10)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal, Theme.spacingM)
            .padding(.bottom, Theme.spacingS)
        }
    }

    private var shouldShowHelpfulPrompt: Bool {
        guard let last = viewModel.messages.last else { return false }
        return last.role == .assistant && !viewModel.isLoading && !hideHelpfulPrompt
    }
}

#Preview {
    NavigationStack {
        AIChatView()
            .environment(AIConsentManager())
            .environment(AIProviderSettings())
            .modelContainer(for: SymptomEntryRecord.self, inMemory: true)
    }
}
