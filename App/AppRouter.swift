import SwiftUI
import Observation

@Observable
final class AppState {
    private enum Keys {
        static let onboardingComplete = "app.onboardingComplete"
    }

    private let defaults: UserDefaults

    var isOnboardingComplete: Bool {
        didSet { defaults.set(isOnboardingComplete, forKey: Keys.onboardingComplete) }
    }

    var isSplashComplete: Bool

    init(isOnboardingComplete: Bool = false, isSplashComplete: Bool = false, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isOnboardingComplete = defaults.object(forKey: Keys.onboardingComplete) as? Bool ?? isOnboardingComplete
        self.isSplashComplete = isSplashComplete
    }
}

struct AppRouterView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthManager.self) private var authManager
    @Environment(AppSecuritySettings.self) private var securitySettings

    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()
            Theme.backgroundGlow
                .ignoresSafeArea()
            Theme.backgroundGlowSecondary
                .ignoresSafeArea()

            if !appState.isSplashComplete {
                SplashView {
                    appState.isSplashComplete = true
                }
            } else if !appState.isOnboardingComplete {
                OnboardingView {
                    appState.isOnboardingComplete = true
                }
            } else if !authManager.isAuthenticated {
                NavigationStack {
                    AuthView()
                }
            } else {
                MainTabView()
            }

            if securitySettings.isAppLockEnabled && securitySettings.isLocked {
                AppLockOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
    }
}

private struct MainTabView: View {
    @AppStorage("app.selectedTab") private var selectedTabRaw: String = AppTab.home.rawValue

    private var selectedTabBinding: Binding<AppTab> {
        Binding<AppTab>(
            get: { AppTab(rawValue: selectedTabRaw) ?? .home },
            set: { selectedTabRaw = $0.rawValue }
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            NavigationStack {
                HomeView()
            }
            .tag(AppTab.home)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            NavigationStack {
                TimelineView()
            }
            .tag(AppTab.timeline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            NavigationStack {
                AIChatView()
            }
            .tag(AppTab.ai)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            NavigationStack {
                InsightsView()
            }
            .tag(AppTab.insights)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            NavigationStack {
                ProfileView()
            }
            .tag(AppTab.profile)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            AnimatedTabBar(selectedTab: selectedTabBinding)
        }
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case home
    case timeline
    case ai
    case insights
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .timeline: return "Timeline"
        case .ai: return "Ask AI"
        case .insights: return "Insights"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .timeline: return "calendar"
        case .ai: return "sparkles"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.crop.circle.fill"
        }
    }

    var isPrimary: Bool {
        self == .ai
    }
}

private struct AnimatedTabBar: View {
    @Binding var selectedTab: AppTab
    @State private var isKeyboardVisible = false

    var body: some View {
        SwiftUI.TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let lift = CGFloat(sin(t * 1.6)) * 2
            let glow = CGFloat((sin(t * 1.1) + 1) / 2)

            HStack(spacing: 12) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                if tab.isPrimary {
                                    Circle()
                                        .fill(Theme.accent)
                                        .frame(width: 46, height: 46)
                                        .shadow(color: Theme.accent.opacity(0.35 + glow * 0.2), radius: 12, x: 0, y: 6)
                                }
                                Image(systemName: tab.systemImage)
                                    .font(tab.isPrimary ? .title2 : .title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(
                                        tab.isPrimary ? Color.white : Theme.accent,
                                        tab.isPrimary ? Theme.accentSecondary : Theme.accentSecondary
                                    )
                            }
                            Text(tab.title)
                                .font(.caption2)
                                .foregroundStyle(selectedTab == tab ? Theme.accent : Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .scaleEffect(selectedTab == tab ? (tab.isPrimary ? 1.12 : 1.05) : 1.0)
                        .offset(y: selectedTab == tab ? -4 : 0)
                        .rotation3DEffect(.degrees(selectedTab == tab ? Double(lift) : 0), axis: (x: 1, y: 0, z: 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .opacity(isKeyboardVisible ? 0 : 1)
            .offset(y: isKeyboardVisible ? 80 : 0)
            .animation(.easeInOut(duration: 0.25), value: isKeyboardVisible)
            .allowsHitTesting(!isKeyboardVisible)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
}
