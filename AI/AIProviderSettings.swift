import Foundation
import Observation

@Observable
final class AIProviderSettings {
    private enum Keys {
        static let useRemote = "ai.useRemoteProvider"
        static let baseURL = "ai.baseURL"
    }

    private let defaults: UserDefaults

    var useRemoteProvider: Bool {
        didSet { defaults.set(useRemoteProvider, forKey: Keys.useRemote) }
    }

    var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Keys.baseURL) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.useRemoteProvider = defaults.object(forKey: Keys.useRemote) as? Bool ?? false
        self.baseURLString = defaults.string(forKey: Keys.baseURL) ?? "http://localhost:3001"
    }

    var configuration: AIProviderConfiguration {
        let mode: AIProviderMode = useRemoteProvider ? .remote : .mock
        return AIProviderConfiguration(mode: mode, baseURLString: baseURLString)
    }
}
