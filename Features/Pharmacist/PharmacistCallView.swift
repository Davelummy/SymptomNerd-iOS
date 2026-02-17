import SwiftUI

struct PharmacistCallView: View {
    let handoff: HandoffPayload
    @StateObject private var viewModel = PharmacistCallViewModel()
    @State private var showChat = false
    @State private var ratingTargetCall: PharmacistCallRecord?
    @State private var ratingErrorText: String?
    @State private var hasPresentedAutoRating = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.9), Theme.accentDeep.opacity(0.65), Theme.accent.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.spacingL) {
                VStack(spacing: Theme.spacingM) {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 132, height: 132)
                        .overlay(
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 44))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Theme.accentSecondary)
                        )

                    Text("Pharmacist line")
                        .font(Typography.title2)
                        .foregroundStyle(Color.white)

                    Text(viewModel.durationText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.96))

                    Text(statusSubtitle)
                        .font(Typography.body)
                        .foregroundStyle(statusColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.spacingS)

                    if viewModel.callState == .checking || viewModel.callState == .requesting || isConnectingState {
                        ProgressView()
                            .tint(Color.white)
                    }
                }
                .padding(.vertical, Theme.spacingL)
                .frame(maxWidth: .infinity)

                if let availability = viewModel.availability, !isCallLive {
                    PharmacistStatusView(
                        statusText: availability.statusText,
                        queuePosition: availability.queuePosition
                    )
                    .padding(.horizontal, Theme.spacingS)
                }

                if !isCallLive {
                    Button {
                        Task { await viewModel.requestCall(handoff: updatedHandoff) }
                    } label: {
                        PrimaryButtonLabel(title: "Start live call", systemImage: "phone.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRequestCall)
                }

                HStack(spacing: Theme.spacingM) {
                    CallControlButton(title: "Mute", systemImage: viewModel.isMuted ? "mic.slash.fill" : "mic.fill", isActive: viewModel.isMuted, isDisabled: !canUseControls) {
                        viewModel.setMuted(!viewModel.isMuted)
                    }
                    CallControlButton(title: "Speaker", systemImage: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.2.fill", isActive: viewModel.isSpeakerOn, isDisabled: !canUseControls) {
                        viewModel.setSpeaker(!viewModel.isSpeakerOn)
                    }
                    CallControlButton(title: "Hold", systemImage: viewModel.isOnHold ? "pause.circle.fill" : "pause.circle", isActive: viewModel.isOnHold, isDisabled: !canUseControls) {
                        viewModel.setOnHold(!viewModel.isOnHold)
                    }
                    CallControlButton(title: endButtonTitle, systemImage: "phone.down.fill", isDestructive: true, isDisabled: !canEndCall) {
                        Task {
                            await viewModel.endCall()
                        }
                    }
                }

                Spacer()

                CardView {
                    Text("If you think this may be an emergency, call your local emergency number.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Live call")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chat") { showChat = true }
                    .foregroundStyle(Color.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
                    .foregroundStyle(Color.white)
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                PharmacistChatView(handoff: handoff)
            }
        }
        .sheet(item: $ratingTargetCall) { call in
            CallRatingPromptSheet(call: call) { rating, feedback in
                do {
                    try await PharmacistServiceFactory.makeService().submitCallRating(callID: call.id, rating: rating, feedback: feedback)
                    ratingTargetCall = nil
                } catch {
                    ratingErrorText = (error as? LocalizedError)?.errorDescription ?? "Unable to submit call rating."
                }
            }
        }
        .alert("Call rating", isPresented: Binding(get: {
            ratingErrorText != nil
        }, set: { newValue in
            if !newValue { ratingErrorText = nil }
        })) {
            Button("OK", role: .cancel) {
                ratingErrorText = nil
            }
        } message: {
            Text(ratingErrorText ?? "")
        }
        .task {
            await viewModel.loadAvailability(service: PharmacistServiceFactory.makeService())
        }
        .onChange(of: viewModel.callState) { _, newValue in
            switch newValue {
            case .requesting, .connecting, .scheduled, .connected:
                hasPresentedAutoRating = false
            case .ended:
                guard !hasPresentedAutoRating, viewModel.durationText != "00:00" else { return }
                hasPresentedAutoRating = true
                Task {
                    await presentRatingForLatestCompletedCallIfNeeded()
                }
            case .checking, .failed:
                break
            }
        }
    }

    private var updatedHandoff: HandoffPayload {
        HandoffPayload(
            userMessage: handoff.userMessage,
            summarizedLogs: handoff.summarizedLogs,
            attachedRange: handoff.attachedRange,
            attachmentIDs: handoff.attachmentIDs,
            contactPhone: handoff.contactPhone
        )
    }

    private var canRequestCall: Bool {
        !isRequestInFlight
    }

    private var canUseControls: Bool {
        if case .connected = viewModel.callState {
            return true
        }
        return false
    }

    private var canEndCall: Bool {
        if case .connecting = viewModel.callState {
            return true
        }
        if case .connected = viewModel.callState {
            return true
        }
        if case .scheduled = viewModel.callState {
            return true
        }
        return false
    }

    private var isRequestInFlight: Bool {
        switch viewModel.callState {
        case .requesting, .connecting:
            return true
        default:
            return false
        }
    }

    private var statusSubtitle: String {
        switch viewModel.callState {
        case .checking:
            return "Checking availability…"
        case .requesting:
            return "Starting a live call with a pharmacist…"
        case .connecting(let text):
            return text
        case .scheduled(let text):
            return text
        case .connected(let text):
            return text
        case .ended(let text):
            return text
        case .failed(let text):
            return text
        }
    }

    private var statusColor: Color {
        switch viewModel.callState {
        case .failed:
            return .red.opacity(0.95)
        case .ended:
            return .white.opacity(0.9)
        default:
            return .white.opacity(0.86)
        }
    }

    private var isConnectingState: Bool {
        if case .connecting = viewModel.callState {
            return true
        }
        return false
    }

    private var isCallLive: Bool {
        if case .connected = viewModel.callState {
            return true
        }
        if case .connecting = viewModel.callState {
            return true
        }
        return false
    }

    private var endButtonTitle: String {
        if case .scheduled = viewModel.callState {
            return "Cancel"
        }
        return "Hang up"
    }

    private func presentRatingForLatestCompletedCallIfNeeded() async {
        do {
            let history = try await PharmacistServiceFactory.makeService().callHistory()
            if let latestUnrated = history.calls.first(where: { $0.canRate }) {
                ratingTargetCall = latestUnrated
            }
        } catch {
            ratingErrorText = (error as? LocalizedError)?.errorDescription ?? "Unable to load call rating."
        }
    }
}

private struct CallControlButton: View {
    let title: String
    let systemImage: String
    var isActive: Bool = false
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        let fillStyle: AnyShapeStyle = {
            if isDestructive {
                return AnyShapeStyle(Color.red)
            }
            if isActive {
                return AnyShapeStyle(Theme.accent)
            }
            return AnyShapeStyle(.ultraThinMaterial)
        }()
        let strokeStyle: AnyShapeStyle = {
            if isDestructive {
                return AnyShapeStyle(Color.clear)
            }
            return AnyShapeStyle(Theme.glassStroke)
        }()

        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isDestructive ? Color.white : (isActive ? Color.white : Theme.accent))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(fillStyle)
                    )
                    .overlay(
                        Circle().stroke(strokeStyle, lineWidth: 1)
                    )
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.84))
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

#Preview {
    NavigationStack {
        PharmacistCallView(handoff: HandoffPayload(userMessage: "Question", summarizedLogs: "Summary", attachedRange: DateInterval(start: Date(), end: Date())))
    }
}

private struct CallRatingPromptSheet: View {
    let call: PharmacistCallRecord
    let onSubmit: (_ rating: Int, _ feedback: String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating = 0
    @State private var feedback = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Rate your pharmacist call") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                selectedRating = value
                            } label: {
                                Image(systemName: value <= selectedRating ? "star.fill" : "star")
                                    .font(.title3)
                                    .foregroundStyle(value <= selectedRating ? .yellow : Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Duration: \(durationText(call.durationSeconds))")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("Optional feedback") {
                    TextField("Tell us about your call", text: $feedback, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Rate call")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            isSubmitting = true
                            do {
                                try await onSubmit(selectedRating, feedback.trimmingCharacters(in: .whitespacesAndNewlines))
                                dismiss()
                            } catch {
                                // Parent view surfaces this error.
                            }
                            isSubmitting = false
                        }
                    }
                    .disabled(selectedRating == 0 || isSubmitting)
                }
            }
        }
    }

    private func durationText(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
