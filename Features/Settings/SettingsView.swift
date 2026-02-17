import SwiftUI

struct SettingsView: View {
    @State private var isICloudEnabled = false
    @State private var isHealthKitEnabled = false
    @AppStorage("notifications.wellness.enabled") private var wellnessNotificationsEnabled = true
    @Environment(AppState.self) private var appState
    @Environment(AppThemeSettings.self) private var themeSettings
    @Environment(AppSecuritySettings.self) private var securitySettings
    @Environment(AIConsentManager.self) private var consentManager
    @Environment(AIProviderSettings.self) private var aiSettings
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @State private var aiStatusMessage: String = "Not checked"
    @State private var isCheckingAI = false
    @State private var exportURL: URL?
    @State private var isSharingExport = false
    @State private var dataStatusMessage: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Account")
                            .font(Typography.headline)
                        Text(authManager.displayName.isEmpty ? "Signed in" : "Signed in as \(authManager.displayName)")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        if !authManager.email.isEmpty {
                            Text(authManager.email)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        NavigationLink {
                            ActiveSessionsView()
                        } label: {
                            HStack {
                                Image(systemName: "desktopcomputer.and.iphone")
                                Text("Active sessions")
                            }
                            .font(Typography.body)
                        }
                        Button("Sign out") {
                            authManager.signOut()
                            appState.isOnboardingComplete = false
                        }
                        .foregroundStyle(.red)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Privacy")
                            .font(Typography.headline)
                        Picker("Appearance", selection: Binding(
                            get: { themeSettings.mode },
                            set: { themeSettings.mode = $0 }
                        )) {
                            ForEach(AppThemeMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Toggle("App Lock", isOn: Binding(
                            get: { securitySettings.isAppLockEnabled },
                            set: { securitySettings.isAppLockEnabled = $0 }
                        ))
                        Text("When enabled, the app will require Face ID/Touch ID before showing your data.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Toggle("Health reminders & tips", isOn: $wellnessNotificationsEnabled)
                            .onChange(of: wellnessNotificationsEnabled) { _, newValue in
                                Task {
                                    await NotificationClient().setWellnessNotificationsEnabled(newValue)
                                }
                            }
                        Toggle("iCloud Sync (Optional)", isOn: $isICloudEnabled)
                        Toggle("HealthKit (Optional)", isOn: $isHealthKitEnabled)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("AI & Backend")
                            .font(Typography.headline)
                        Toggle("Use live AI (backend)", isOn: Binding(
                            get: { aiSettings.useRemoteProvider },
                            set: { aiSettings.useRemoteProvider = $0 }
                        ))
                        Toggle("Save AI conversations", isOn: Binding(
                            get: { consentManager.saveConversations },
                            set: { consentManager.saveConversations = $0 }
                        ))
                        Toggle("Data minimization (recommended)", isOn: Binding(
                            get: { consentManager.dataMinimizationOn },
                            set: { consentManager.dataMinimizationOn = $0 }
                        ))
                        Text("Connected backend")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Production")
                            .font(Typography.body)
                        Picker("AI response language", selection: Binding(
                            get: { aiSettings.preferredLanguage },
                            set: { aiSettings.preferredLanguage = $0 }
                        )) {
                            Text("English").tag("English")
                            Text("French").tag("French")
                        }
                        .pickerStyle(.segmented)
                        HStack(spacing: Theme.spacingS) {
                            Button(isCheckingAI ? "Checking…" : "Test AI connection") {
                                Task { await checkAIHealth() }
                            }
                            .buttonStyle(.bordered)
                            Text(aiStatusMessage)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Text("Production backend is preconfigured for all users.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Data")
                            .font(Typography.headline)
                        Button("Export Data (JSON)") {
                            Task { await exportData() }
                        }
                        Button("Delete All Data") {
                            showDeleteConfirm = true
                        }
                            .foregroundStyle(.red)
                        if let dataStatusMessage {
                            Text(dataStatusMessage)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Button("Reset Onboarding") {
                            appState.isOnboardingComplete = false
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Safety")
                            .font(Typography.headline)
                        Text("This app can help you track and notice patterns. It does not provide medical diagnosis.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        Text("If you think you may be experiencing a medical emergency, call your local emergency number immediately.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Settings")
        .dismissKeyboardOnTap()
        .sheet(isPresented: $isSharingExport) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .alert("Delete all data?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteAllData() }
            }
        } message: {
            Text("This removes all symptom logs from this device. This cannot be undone.")
        }
    }

    private func checkAIHealth() async {
        guard let url = URL(string: aiSettings.baseURLString)?.appendingPathComponent("health") else {
            aiStatusMessage = "Invalid URL"
            return
        }
        isCheckingAI = true
        defer { isCheckingAI = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                aiStatusMessage = "No response"
                return
            }
            if http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["ok"] as? Bool) == true {
                aiStatusMessage = "Backend OK"
            } else {
                aiStatusMessage = "Backend error (\(http.statusCode))"
            }
        } catch {
            aiStatusMessage = "Connection failed"
        }
    }

    private func exportData() async {
        do {
            let client = SwiftDataStore(context: modelContext)
            let entries = try await client.fetchEntries()
            let url = try JSONExportService().export(entries: entries)
            exportURL = url
            dataStatusMessage = "Export ready"
            isSharingExport = true
        } catch {
            dataStatusMessage = "Export failed"
        }
    }

    private func deleteAllData() async {
        do {
            let client = SwiftDataStore(context: modelContext)
            try await client.deleteAll()
            dataStatusMessage = "All data deleted"
        } catch {
            dataStatusMessage = "Delete failed"
        }
    }
}

private struct ActiveSessionsView: View {
    @State private var sessions: [AppSessionInfo] = []
    @State private var isLoading = false
    @State private var statusMessage: String?

    private var hasOtherActiveSessions: Bool {
        sessions.contains { !$0.isCurrentDevice && !$0.isRevoked }
    }

    var body: some View {
        List {
            Section("Devices") {
                ForEach(sessions) { session in
                    ActiveSessionRow(session: session) {
                        Task {
                            await AppSessionManager.shared.revoke(sessionID: session.id)
                            await reloadSessions()
                        }
                    }
                }
            }

            Section {
                Button("Sign out all other devices") {
                    Task {
                        await AppSessionManager.shared.signOutAllOtherSessions()
                        statusMessage = "Other sessions were signed out."
                        await reloadSessions()
                    }
                }
                .disabled(isLoading || !hasOtherActiveSessions)
            } footer: {
                Text("Use this if you signed in on another iPhone and want to end those sessions.")
            }
        }
        .navigationTitle("Active Sessions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") {
                    Task { await reloadSessions() }
                }
                .disabled(isLoading)
            }
        }
        .task {
            await reloadSessions()
        }
        .overlay {
            if isLoading {
                ProgressView("Loading sessions…")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .alert("Sessions", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private func reloadSessions() async {
        isLoading = true
        sessions = await AppSessionManager.shared.listSessions()
        isLoading = false
    }
}

private struct ActiveSessionRow: View {
    let session: AppSessionInfo
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.deviceName)
                    .font(Typography.headline)
                Spacer()
                if session.isCurrentDevice {
                    Text("This iPhone")
                        .font(Typography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accentSoft)
                        .clipShape(Capsule())
                }
            }
            Text(session.platform)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            Text("Last active: \(session.lastSeenAt.formatted(date: .abbreviated, time: .shortened))")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            Text("App: \(session.appVersion)")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            if !session.isCurrentDevice && !session.isRevoked {
                Button("Sign out this device", action: onRevoke)
                    .font(Typography.caption)
            } else if session.isRevoked {
                Text("Session signed out")
                    .font(Typography.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AIConsentManager())
            .environment(AIProviderSettings())
            .environment(AppSecuritySettings())
    }
}
