import SwiftUI

struct AppLockOverlay: View {
    @Environment(AppSecuritySettings.self) private var securitySettings
    @State private var isUnlocking = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Theme.spacingM) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.accent, Theme.accentSoft)
                    .padding(.bottom, Theme.spacingXS)

                Text("App Locked")
                    .font(Typography.title2)
                Text("Use Face ID, Touch ID, or device passcode to continue.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                if let message = securitySettings.lastErrorMessage {
                    Text(message)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                }

                PrimaryButton(title: isUnlocking ? "Unlocking…" : "Unlock") {
                    Task {
                        isUnlocking = true
                        _ = await securitySettings.unlock()
                        isUnlocking = false
                    }
                }
                .disabled(isUnlocking)
                .frame(maxWidth: 240)
            }
            .padding(Theme.spacingL)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 20, x: 0, y: 10)
            .padding(.horizontal, Theme.spacingL)
        }
    }
}

#Preview {
    AppLockOverlay()
        .environment(AppSecuritySettings())
}
