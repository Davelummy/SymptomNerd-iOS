import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp = true
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var isLoading = false
    private let appleSignInEnabled = false

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
                        Text("Sign in")
                            .font(Typography.headline)

                        if appleSignInEnabled {
                            SignInWithAppleButton(.signIn) { request in
                                let nonce = authManager.randomNonceString()
                                currentNonce = nonce
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = authManager.sha256(nonce)
                            } onCompletion: { result in
                                Task { await handleAppleResult(result) }
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
                        }

                        Button {
                            Task { await handleGoogleSignIn() }
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Continue with Google")
                                    .font(Typography.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacingS)
                            .background(Theme.accentSoft)
                            .foregroundStyle(Theme.accentDeep)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Text("Or continue with email")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Picker("Mode", selection: $isSignUp) {
                            Text("Create account").tag(true)
                            Text("Sign in").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if isSignUp {
                            TextField("Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                PrimaryButton(title: isSignUp ? "Create account" : "Sign in", systemImage: "checkmark") {
                    Task { await handleEmailAuth() }
                }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 6)

                if isLoading {
                    ProgressView()
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                }

                Text("Your account is stored securely in Firebase Auth.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Sign in")
        .dismissKeyboardOnTap()
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    errorMessage = "Sign in failed. Try again."
                    return
                }
                isLoading = true
                errorMessage = nil
                do {
                    try await authManager.signInWithApple(credential: credential, nonce: nonce, fullName: credential.fullName)
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "Apple Sign-In failed."
                }
                isLoading = false
            }
        case .failure:
            errorMessage = "Apple Sign-In failed."
        }
    }

    private func handleGoogleSignIn() async {
        guard let viewController = UIApplication.shared.topMostViewController() else {
            errorMessage = "Unable to start Google Sign-In."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signInWithGoogle(presenting: viewController)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Google Sign-In failed."
        }
        isLoading = false
    }

    private func handleEmailAuth() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                try await authManager.signUpWithEmail(name: trimmedName, email: trimmedEmail, password: trimmedPassword)
            } else {
                try await authManager.signInWithEmail(email: trimmedEmail, password: trimmedPassword)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        AuthView()
            .environment(AuthManager())
    }
}
