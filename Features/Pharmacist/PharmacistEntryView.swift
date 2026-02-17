import SwiftUI

struct PharmacistEntryView: View {
    let handoff: HandoffPayload
    @State private var statusText: String = ""
    @State private var queuePosition: Int?
    @State private var showChat = false
    @State private var showCall = false
    @State private var showCallHistory = false

    init(handoff: HandoffPayload = HandoffPayload(userMessage: "I have a question for a pharmacist.", summarizedLogs: "No logs selected.", attachedRange: DateInterval(start: Date(), end: Date()))) {
        self.handoff = handoff
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Talk to a pharmacist")
                            .font(Typography.title2)
                        Text("Human help for medication questions and next‑step support.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        if !statusText.isEmpty {
                            PharmacistStatusView(statusText: statusText, queuePosition: queuePosition)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("Choose how to connect")
                        .font(Typography.headline)

                    HStack(spacing: Theme.spacingS) {
                        OptionCard(
                            title: "Text chat",
                            subtitle: "Ask questions any time",
                            systemImage: "message.fill",
                            tint: Theme.accent
                        ) {
                            showChat = true
                        }

                        OptionCard(
                            title: "Voice call",
                            subtitle: "Start a live call now",
                            systemImage: "phone.fill",
                            tint: Theme.accentSecondary
                        ) {
                            showCall = true
                        }
                    }

                    OptionCard(
                        title: "Call history",
                        subtitle: "View timestamps, durations, and rate completed calls",
                        systemImage: "clock.arrow.circlepath",
                        tint: Theme.accentDeep
                    ) {
                        showCallHistory = true
                    }
                }

                Text("If you think this may be an emergency, call your local emergency number.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Pharmacist")
        .sheet(isPresented: $showChat) {
            NavigationStack {
                PharmacistChatView(handoff: handoff)
            }
        }
        .sheet(isPresented: $showCall) {
            NavigationStack {
                PharmacistCallView(handoff: handoff)
            }
        }
        .sheet(isPresented: $showCallHistory) {
            NavigationStack {
                PharmacistCallHistoryView()
            }
        }
        .task {
            let availability = await PharmacistServiceFactory.makeService().availability()
            statusText = availability.statusText
            queuePosition = availability.queuePosition
        }
    }
}

private struct OptionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(tint, Theme.accentSoft)
                Text(title)
                    .font(Typography.headline)
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.spacingM)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PharmacistEntryView()
    }
}

@MainActor
private final class PharmacistCallHistoryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var calls: [PharmacistCallRecord] = []
    @Published var totalCalls: Int = 0
    @Published var averageRating: Double?

    private let service = PharmacistServiceFactory.makeService()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let history = try await service.callHistory()
            calls = history.calls
            totalCalls = history.totalCalls
            averageRating = history.averageRating
            errorText = nil
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Unable to load call history."
        }
    }

    func submitRating(callID: String, rating: Int, feedback: String?) async -> Bool {
        do {
            try await service.submitCallRating(callID: callID, rating: rating, feedback: feedback)
            await load()
            return true
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Unable to submit rating."
            return false
        }
    }
}

private struct PharmacistCallHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PharmacistCallHistoryViewModel()
    @State private var selectedCallForRating: PharmacistCallRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Your call history")
                            .font(Typography.title2)
                        Text("Total calls: \(viewModel.totalCalls)")
                            .font(Typography.body)
                        Text(ratingSummaryText)
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if viewModel.isLoading {
                    ProgressView("Loading calls…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Theme.spacingL)
                } else if viewModel.calls.isEmpty {
                    CardView {
                        Text("No calls yet. Your future pharmacist calls will appear here.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    ForEach(viewModel.calls) { call in
                        CardView {
                            VStack(alignment: .leading, spacing: Theme.spacingS) {
                                HStack {
                                    Text(callStatusLabel(call.status))
                                        .font(Typography.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(callStatusColor(call.status).opacity(0.15))
                                        .foregroundStyle(callStatusColor(call.status))
                                        .clipShape(Capsule())
                                    Spacer()
                                    if let createdAt = call.createdAt {
                                        Text(Self.dateFormatter.string(from: createdAt))
                                            .font(Typography.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }

                                HStack {
                                    Label(Self.durationText(call.durationSeconds), systemImage: "timer")
                                    Spacer()
                                    if let rating = call.rating {
                                        Text(Self.starText(rating))
                                    } else if call.canRate {
                                        Button("Rate call") {
                                            selectedCallForRating = call
                                        }
                                        .font(Typography.caption)
                                        .buttonStyle(.borderedProminent)
                                        .tint(Theme.accentDeep)
                                    } else {
                                        Text("Not rated")
                                            .font(Typography.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .font(Typography.body)

                                if let feedback = call.ratingFeedback, !feedback.isEmpty {
                                    Text("Feedback: \(feedback)")
                                        .font(Typography.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingM)
        }
        .navigationTitle("Call history")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Call history", isPresented: Binding(get: {
            viewModel.errorText != nil
        }, set: { value in
            if !value { viewModel.errorText = nil }
        })) {
            Button("OK", role: .cancel) {
                viewModel.errorText = nil
            }
        } message: {
            Text(viewModel.errorText ?? "Something went wrong.")
        }
        .sheet(item: $selectedCallForRating) { call in
            CallRatingSheet(call: call) { rating, feedback in
                let success = await viewModel.submitRating(callID: call.id, rating: rating, feedback: feedback)
                if success {
                    selectedCallForRating = nil
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            await viewModel.load()
        }
    }

    private var ratingSummaryText: String {
        if let average = viewModel.averageRating {
            return "Average satisfaction: \(String(format: "%.2f", average))/5"
        }
        return "Average satisfaction: no ratings yet"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func durationText(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private static func starText(_ rating: Int) -> String {
        let filled = String(repeating: "★", count: max(0, min(5, rating)))
        let empty = String(repeating: "☆", count: max(0, 5 - max(0, min(5, rating))))
        return "\(filled)\(empty)"
    }

    private func callStatusLabel(_ status: String) -> String {
        switch status {
        case "completed":
            return "Completed"
        case "missed":
            return "Missed"
        case "failed":
            return "Failed"
        case "cancelled":
            return "Cancelled"
        case "in_progress":
            return "In progress"
        case "ringing":
            return "Ringing"
        case "requested":
            return "Requested"
        case "queued":
            return "Queued"
        default:
            return status.capitalized
        }
    }

    private func callStatusColor(_ status: String) -> Color {
        switch status {
        case "completed":
            return .green
        case "missed", "failed", "cancelled":
            return .red
        default:
            return Theme.accentDeep
        }
    }
}

private struct CallRatingSheet: View {
    let call: PharmacistCallRecord
    let onSubmit: (_ rating: Int, _ feedback: String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating = 0
    @State private var feedback = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Rate this call") {
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
                    Text("Call time: \(PharmacistCallHistoryView.durationText(call.durationSeconds))")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("Optional feedback") {
                    TextField("What went well or what should improve?", text: $feedback, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Rate call")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            isSubmitting = true
                            await onSubmit(selectedRating, feedback.trimmingCharacters(in: .whitespacesAndNewlines))
                            isSubmitting = false
                        }
                    }
                    .disabled(selectedRating == 0 || isSubmitting)
                }
            }
        }
    }
}
