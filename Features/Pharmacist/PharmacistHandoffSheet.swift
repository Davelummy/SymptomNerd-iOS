import SwiftUI

struct PharmacistHandoffSheet: View {
    @State private var userMessage: String
    @State private var summarizedLogs: String
    @State private var consentGiven = false

    let attachedRange: DateInterval

    init(handoff: HandoffPayload) {
        _userMessage = State(initialValue: handoff.userMessage)
        _summarizedLogs = State(initialValue: handoff.summarizedLogs)
        self.attachedRange = handoff.attachedRange
    }

    private var updatedPayload: HandoffPayload {
        HandoffPayload(
            userMessage: userMessage,
            summarizedLogs: summarizedLogs,
            attachedRange: attachedRange,
            contactPhone: ""
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Handoff summary")
                                .font(Typography.title2)
                            Text("You can edit what gets shared before sending.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Your question")
                                .font(Typography.headline)
                            TextEditor(text: $userMessage)
                                .frame(height: 90)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                        .stroke(Theme.glassStroke, lineWidth: 1)
                                )
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.spacingS) {
                            Text("Summary to share")
                                .font(Typography.headline)
                            TextEditor(text: $summarizedLogs)
                                .frame(height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                        .stroke(Theme.glassStroke, lineWidth: 1)
                                )
                            Text("Range: \(attachedRange.start.formatted(date: .abbreviated, time: .omitted)) – \(attachedRange.end.formatted(date: .abbreviated, time: .omitted))")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Toggle("I consent to share this summary with a pharmacist service", isOn: $consentGiven)

                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        NavigationLink {
                            PharmacistChatView(handoff: updatedPayload)
                        } label: {
                            PrimaryButtonLabel(title: "Start text chat", systemImage: "message")
                        }
                        .disabled(!consentGiven)

                        NavigationLink {
                            PharmacistCallView(handoff: updatedPayload)
                        } label: {
                            PrimaryButtonLabel(title: "Start live voice call", systemImage: "phone")
                        }
                        .disabled(!consentGiven)
                    }
                }
                .screenPadding()
                .padding(.vertical, Theme.spacingL)
            }
            .navigationTitle("Send to Pharmacist")
        }
    }
}

#Preview {
    PharmacistHandoffSheet(handoff: HandoffPayload(userMessage: "Question", summarizedLogs: "Summary", attachedRange: DateInterval(start: Date(), end: Date())))
}
