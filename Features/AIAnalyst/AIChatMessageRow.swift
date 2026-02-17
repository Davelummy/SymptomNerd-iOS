import SwiftUI
import UIKit

struct AIChatMessageRow: View {
    let message: AIChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant { bubble } else { Spacer(); bubble }
        }
        .padding(.horizontal, Theme.spacingS)
    }

    private var bubble: some View {
        Text(message.content)
            .font(Typography.body)
            .foregroundStyle(message.role == .assistant ? Theme.textPrimary : Color.white)
            .padding(Theme.spacingM)
            .background(
                message.role == .assistant
                ? AnyView(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous).fill(.ultraThinMaterial))
                : AnyView(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous).fill(Theme.accent))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .stroke(message.role == .assistant ? AnyShapeStyle(Theme.glassStroke) : AnyShapeStyle(Color.white.opacity(0.25)), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
            .contextMenu {
                Button("Copy") {
                    UIPasteboard.general.string = message.content
                }
            }
    }
}

#Preview {
    VStack(spacing: Theme.spacingM) {
        AIChatMessageRow(message: AIChatMessage(role: .assistant, content: "Assistant message"))
        AIChatMessageRow(message: AIChatMessage(role: .user, content: "User question"))
    }
    .padding()
}
