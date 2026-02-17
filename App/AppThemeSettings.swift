import SwiftUI
import Observation

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class AppThemeSettings {
    private enum Keys {
        static let themeMode = "app.theme.mode"
    }

    private let defaults: UserDefaults

    var mode: AppThemeMode {
        didSet { defaults.set(mode.rawValue, forKey: Keys.themeMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Keys.themeMode)
        self.mode = AppThemeMode(rawValue: stored ?? "") ?? .system
    }
}
