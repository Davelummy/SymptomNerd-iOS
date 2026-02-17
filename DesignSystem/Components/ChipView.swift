import SwiftUI

struct ChipView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Typography.caption)
            .padding(.horizontal, Theme.spacingS)
            .padding(.vertical, Theme.spacingXS)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule().stroke(Theme.glassStroke, lineWidth: 1)
            )
            .foregroundStyle(Theme.accentDeep)
            .clipShape(Capsule())
    }
}

#Preview {
    ChipView(title: "Stress")
        .padding()
}
