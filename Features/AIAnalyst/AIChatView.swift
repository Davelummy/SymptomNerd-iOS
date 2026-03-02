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
    private let quickPrompts: [String] = [
        "What could be causing my recurring evening headaches?",
        "What should I track for chest tightness over the next 3 days?",
        "Which red flags mean I should seek urgent care?"
    ]

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
            ToolbarItem(placement: .topBarLeading) {
                Button("New Chat") {
                    hideHelpfulPrompt = false
                    lastHelpfulMessageID = nil
                    viewModel.startNewChat()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("History") { showHistory = true }
            }
        }
        .task {
            let provider = AIProviderFactory.makeProvider(configuration: aiSettings.configuration)
            let client = AIClient(provider: provider, consentManager: consentManager)
            viewModel.configure(
                client: client,
                persistence: SwiftDataStore(context: modelContext),
                consentManager: consentManager,
                isRemoteProvider: aiSettings.useRemoteProvider,
                baseURLString: aiSettings.configuration.baseURLString
            )
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
            HStack(spacing: Theme.spacingS) {
                backendStatusPill
                Spacer()
            }
            .padding(.horizontal, Theme.spacingM)
            .padding(.top, Theme.spacingXS)

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

            if viewModel.messages.count <= 2 && !viewModel.isLoading {
                quickPromptStrip
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

            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                HStack(spacing: Theme.spacingS) {
                    TextField("Ask about patterns or questions to ask a clinician...", text: $viewModel.input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($isInputFocused)

                    Button {
                        Task { await viewModel.send() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(10)
                                .background(Theme.accent)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(Color.white)
                                .padding(10)
                                .background(Theme.accent)
                                .clipShape(Circle())
                        }
                    }
                    .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }

                if viewModel.isLoading {
                    Text("Symptom Nerd AI is drafting a response...")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.spacingM)
            .padding(.bottom, Theme.spacingS)
        }
    }

    private var shouldShowHelpfulPrompt: Bool {
        guard let last = viewModel.messages.last else { return false }
        return last.role == .assistant && !viewModel.isLoading && !hideHelpfulPrompt
    }

    private var quickPromptStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacingS) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        viewModel.input = prompt
                        isInputFocused = true
                    } label: {
                        Text(prompt)
                            .font(Typography.caption)
                            .foregroundStyle(Theme.accentDeep)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.accentSoft.opacity(0.5), in: Capsule())
                            .overlay(Capsule().stroke(Theme.accent.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.spacingM)
        }
    }

    private var backendStatusPill: some View {
        Button {
            Task { await viewModel.refreshBackendStatus() }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(backendStatusColor)
                    .frame(width: 8, height: 8)
                Text(backendStatusText)
                    .font(Typography.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Theme.glassStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI backend status")
    }

    private var backendStatusText: String {
        switch viewModel.backendStatus {
        case .checking: return "Checking backend"
        case .online: return "Backend online"
        case .unavailable: return "Backend unavailable"
        case .mock: return "Mock mode"
        }
    }

    private var backendStatusColor: Color {
        switch viewModel.backendStatus {
        case .checking: return Theme.warningAmber
        case .online: return Theme.successGreen
        case .unavailable: return Theme.errorRed
        case .mock: return Theme.accent
        }
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
