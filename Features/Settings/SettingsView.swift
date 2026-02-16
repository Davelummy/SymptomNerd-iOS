import SwiftUI

struct SettingsView: View {
    @State private var isAppLockEnabled = false
    @State private var isICloudEnabled = false
    @State private var isHealthKitEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Privacy")
                            .font(Typography.headline)
                        Toggle("App Lock", isOn: $isAppLockEnabled)
                        Toggle("iCloud Sync (Optional)", isOn: $isICloudEnabled)
                        Toggle("HealthKit (Optional)", isOn: $isHealthKitEnabled)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Data")
                            .font(Typography.headline)
                        Button("Export Data") { }
                        Button("Delete All Data") { }
                            .foregroundStyle(.red)
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
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
