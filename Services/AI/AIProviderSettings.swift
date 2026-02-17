import Foundation
import Observation

@Observable
final class AIProviderSettings {
    private enum Keys {
        static let useRemote = "ai.useRemoteProvider"
        static let baseURL = "ai.baseURL"
        static let preferredLanguage = "ai.preferredLanguage"
    }

    private let defaults: UserDefaults

    var useRemoteProvider: Bool {
        didSet { defaults.set(useRemoteProvider, forKey: Keys.useRemote) }
    }

    var baseURLString: String {
        didSet {
            let normalized = AIProviderConfiguration.normalizedBaseURL(from: baseURLString)
            if normalized != baseURLString {
                baseURLString = normalized
                return
            }
            defaults.set(normalized, forKey: Keys.baseURL)
        }
    }

    var preferredLanguage: String {
        didSet { defaults.set(preferredLanguage, forKey: Keys.preferredLanguage) }
    }

    init(defaults: UserDefaults = .standard) {
        let storedUseRemote = defaults.object(forKey: Keys.useRemote) as? Bool ?? true
        let storedBaseURL = AIProviderConfiguration.normalizedBaseURL(from: defaults.string(forKey: Keys.baseURL))
        let storedLanguage = defaults.string(forKey: Keys.preferredLanguage) ?? "English"

        self.defaults = defaults
        self.useRemoteProvider = storedUseRemote
        self.baseURLString = storedBaseURL
        self.preferredLanguage = storedLanguage

        if defaults.object(forKey: Keys.useRemote) == nil {
            defaults.set(storedUseRemote, forKey: Keys.useRemote)
        }
        if defaults.string(forKey: Keys.baseURL) == nil {
            defaults.set(storedBaseURL, forKey: Keys.baseURL)
        }
        if defaults.string(forKey: Keys.preferredLanguage) == nil {
            defaults.set(storedLanguage, forKey: Keys.preferredLanguage)
        }
    }

    var configuration: AIProviderConfiguration {
        let mode: AIProviderMode = useRemoteProvider ? .remote : .mock
        return AIProviderConfiguration(mode: mode, baseURLString: baseURLString)
    }
}
