import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Theme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .fill(Theme.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 10)
    }
}

#Preview {
    CardView {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text("Today summary").font(Typography.headline)
            Text("No symptoms logged yet.")
        }
    }
    .padding()
}
