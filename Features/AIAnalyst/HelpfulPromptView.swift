import SwiftUI

struct HelpfulPromptView: View {
    let onNotHelpful: () -> Void
    var onDismiss: (() -> Void)? = nil

    @State private var selected: Bool?
    @State private var offsetX: CGFloat = 0
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            CardView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("Was this helpful?")
                        .font(Typography.headline)
                    HStack(spacing: Theme.spacingS) {
                        Button("Yes") {
                            selected = true
                        }
                        .buttonStyle(.bordered)

                        Button("Not really") {
                            selected = false
                            onNotHelpful()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("Talk to a pharmacist") {
                        selected = false
                        onNotHelpful()
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Theme.accent)
                    Text("If you need human help, you can chat or call a pharmacist.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .opacity(selected == true ? 0.6 : 1.0)
            .offset(x: offsetX)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offsetX = value.translation.width
                    }
                    .onEnded { value in
                        let shouldDismiss = abs(value.translation.width) > 120 || abs(value.predictedEndTranslation.width) > 160
                        if shouldDismiss {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDismissed = true
                                offsetX = value.translation.width > 0 ? 320 : -320
                            }
                            onDismiss?()
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                offsetX = 0
                            }
                        }
                    }
            )
        }
    }
}

#Preview {
    HelpfulPromptView { }
        .padding()
}
