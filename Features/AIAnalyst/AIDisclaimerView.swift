import SwiftUI

struct AIDisclaimerView: View {
    @Environment(AIConsentManager.self) private var consentManager
    @State private var consentToggle = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Before you use AI")
                            .font(Typography.title2)
                        Text("This AI provides informational, pattern-based insights. It does not diagnose or provide medical advice.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        Text("If you think this may be an emergency, call your local emergency number.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Consent & data minimization")
                            .font(Typography.headline)
                        Text("We will ask for explicit consent before sending any symptom details to an AI service.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        Toggle("Send selected symptom details to the AI service to generate insights", isOn: $consentToggle)
                        Toggle("Data minimization (recommended)", isOn: Binding(
                            get: { consentManager.dataMinimizationOn },
                            set: { consentManager.dataMinimizationOn = $0 }
                        ))
                        Text("When on, we send only the minimum fields needed.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                PrimaryButton(title: "Agree & Continue", systemImage: "checkmark") {
                    consentManager.hasConsented = consentToggle
                }
                .disabled(!consentToggle)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("AI Disclaimer")
    }
}

#Preview {
    NavigationStack {
        AIDisclaimerView()
            .environment(AIConsentManager())
    }
}
