import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void
    @State private var scale: CGFloat = 0.9

    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()
            Theme.backgroundGlow
                .ignoresSafeArea()
            Theme.backgroundGlowSecondary
                .ignoresSafeArea()

            VStack(spacing: Theme.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.glassFill)
                        .frame(width: 120, height: 120)
                    if UIImage(named: "AppLogo") != nil {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 40))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.accent, Theme.accentSecondary)
                    }
                }
                Text("Symptom Nerd")
                    .font(Typography.title)
                Text("Track. Notice patterns. Share with care.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.spacingXL)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 20, x: 0, y: 10)
            .scaleEffect(scale)
        }
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
