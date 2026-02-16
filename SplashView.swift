import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void
    @State private var scale: CGFloat = 0.9

    var body: some View {
        VStack(spacing: Theme.spacingL) {
            Text("Symptom Nerd")
                .font(Typography.title)
            Text("Track. Notice patterns. Share with care.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backgroundGradient)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                scale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashView { }
}
