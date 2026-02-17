import SwiftUI

struct PrimaryButtonLabel: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
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
            LinearGradient(
                colors: [Theme.accent, Theme.accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
    }
}

#Preview {
    PrimaryButtonLabel(title: "Analyze", systemImage: "sparkles")
        .padding()
}
