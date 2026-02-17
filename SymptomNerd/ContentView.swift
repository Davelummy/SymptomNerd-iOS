//
//  ContentView.swift
//  SymptomNerd
//
//  Created by Dave Lummy on 1/31/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppThemeSettings.self) private var themeSettings
    @Environment(AppSecuritySettings.self) private var securitySettings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        AppRouterView()
            .preferredColorScheme(themeSettings.mode.colorScheme)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    securitySettings.lockIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AuthManager.didSignOutNotification)) { _ in
                appState.isOnboardingComplete = false
            }
    }
}

#Preview {
    ContentView()
        .environment(DIContainer.preview.appState)
        .environment(AuthManager())
        .environment(AIConsentManager())
        .environment(AIProviderSettings())
        .environment(AppThemeSettings())
        .environment(AppSecuritySettings())
}
