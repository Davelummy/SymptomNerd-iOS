import SwiftUI

struct PharmacistEntryView: View {
    let handoff: HandoffPayload
    @State private var statusText: String = ""
    @State private var queuePosition: Int?
    @State private var showChat = false
    @State private var showCall = false

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
