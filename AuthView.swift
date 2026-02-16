import SwiftUI

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var name: String = ""
    @State private var email: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Welcome")
                            .font(Typography.title2)
                        Text("Create a lightweight profile to personalize your dashboard.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Your details")
                            .font(Typography.headline)
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                PrimaryButton(title: "Continue", systemImage: "checkmark") {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    authManager.signIn(name: trimmedName.isEmpty ? "Friend" : trimmedName, email: trimmedEmail)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("We store this locally on your device.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Sign in")
    }
}

#Preview {
    NavigationStack {
        AuthView()
            .environment(AuthManager())
    }
}
