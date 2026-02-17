import Foundation
import Observation

@Observable
final class AIConsentManager {
    private enum Keys {
        static let hasConsented = "ai.hasConsented"
        static let dataMinimizationOn = "ai.dataMinimizationOn"
        static let saveConversations = "ai.saveConversations"
    }

    private let defaults: UserDefaults

    var hasConsented: Bool {
        didSet { defaults.set(hasConsented, forKey: Keys.hasConsented) }
    }

    var dataMinimizationOn: Bool {
        didSet { defaults.set(dataMinimizationOn, forKey: Keys.dataMinimizationOn) }
    }

    var saveConversations: Bool {
        didSet { defaults.set(saveConversations, forKey: Keys.saveConversations) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasConsented = defaults.object(forKey: Keys.hasConsented) as? Bool ?? false
        self.dataMinimizationOn = defaults.object(forKey: Keys.dataMinimizationOn) as? Bool ?? true
        self.saveConversations = defaults.object(forKey: Keys.saveConversations) as? Bool ?? true
        defaults.set(self.saveConversations, forKey: Keys.saveConversations)
    }
}
