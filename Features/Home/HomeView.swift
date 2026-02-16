import SwiftUI

struct HomeView: View {
    @State private var showLogFlow = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("How are you today?")
                            .font(Typography.title2)
                        Text("Log a symptom in under a minute.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        PrimaryButton(title: "Log Symptom", systemImage: "plus") {
                            showLogFlow = true
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Today summary")
                            .font(Typography.headline)
                        Text("No symptoms logged yet.")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: Theme.spacingS) {
                            ChipView(title: "Avg 0/10")
                            ChipView(title: "Streak 0")
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Quick actions")
                            .font(Typography.headline)
                        HStack(spacing: Theme.spacingS) {
                            NavigationLink {
                                TimelineView()
                            } label: {
                                quickActionLabel(title: "Timeline", systemImage: "calendar")
                            }

                            NavigationLink {
                                ExportView()
                            } label: {
                                quickActionLabel(title: "Export", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Home")
        .sheet(isPresented: $showLogFlow) {
            LogSymptomFlowView()
        }
    }

    private func quickActionLabel(title: String, systemImage: String) -> some View {
        VStack(spacing: Theme.spacingXS) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(Typography.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacingS)
        .background(Theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        .foregroundStyle(Theme.accent)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
