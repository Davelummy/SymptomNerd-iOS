import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacingS) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(Typography.headline)
            }
            .foregroundStyle(Color.white)
            .padding(.vertical, Theme.spacingS)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to perform the primary action")
    }
}

#Preview {
    PrimaryButton(title: "Log Symptom", systemImage: "plus") { }
        .padding()
}
