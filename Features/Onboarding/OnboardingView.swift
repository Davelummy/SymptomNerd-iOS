import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var selection = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Theme.spacingL) {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("Symptom Nerd")
                    .font(Typography.title)
                Text("Track. Notice patterns. Share with care.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TabView(selection: $selection) {
                OnboardingPage(
                    title: "Welcome",
                    message: "A calm space to log symptoms and see trends over time."
                )
                .tag(0)

                OnboardingPage(
                    title: "Privacy first",
                    message: "Your data stays on device by default. iCloud sync is optional."
                )
                .tag(1)

                OnboardingPage(
                    title: "Safety matters",
                    message: "This app can help you track and notice patterns. It does not provide medical diagnosis. If you think you may be experiencing a medical emergency, call your local emergency number immediately."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: 320)
            .animation(reduceMotion ? nil : .easeInOut, value: selection)

            PrimaryButton(
                title: selection < 2 ? "Continue" : "Get Started",
                systemImage: selection < 2 ? "arrow.right" : "checkmark"
            ) {
                if selection < 2 {
                    selection += 1
                } else {
                    onComplete()
                }
            }

            Text("You can update permissions any time in Settings.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .screenPadding()
        .padding(.vertical, Theme.spacingL)
    }
}

private struct OnboardingPage: View {
    let title: String
    let message: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text(title)
                    .font(Typography.title2)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.spacingS)
    }
}

#Preview {
    OnboardingView { }
}
