import Foundation

final class DIContainer {
    let appState: AppState
    let aiConsentManager: AIConsentManager
    let aiSettings: AIProviderSettings
    let authManager: AuthManager
    let themeSettings: AppThemeSettings
    let securitySettings: AppSecuritySettings

    init(
        appState: AppState = AppState(),
        aiConsentManager: AIConsentManager = AIConsentManager(),
        aiSettings: AIProviderSettings = AIProviderSettings(),
        authManager: AuthManager = AuthManager(),
        themeSettings: AppThemeSettings = AppThemeSettings(),
        securitySettings: AppSecuritySettings = AppSecuritySettings()
    ) {
        self.appState = appState
        self.aiConsentManager = aiConsentManager
        self.aiSettings = aiSettings
        self.authManager = authManager
        self.themeSettings = themeSettings
        self.securitySettings = securitySettings
    }

    static let preview: DIContainer = {
        let appState = AppState(isOnboardingComplete: true, isSplashComplete: true)
        let auth = AuthManager()
        auth.displayName = "Preview"
        auth.email = "preview@example.com"
        auth.isAuthenticated = true
        return DIContainer(appState: appState, authManager: auth)
    }()
}
