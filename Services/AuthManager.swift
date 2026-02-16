import Foundation
import Observation

@Observable
final class AuthManager {
    private enum Keys {
        static let isAuthenticated = "auth.isAuthenticated"
        static let displayName = "auth.displayName"
        static let email = "auth.email"
    }

    private let defaults: UserDefaults

    var isAuthenticated: Bool {
        didSet { defaults.set(isAuthenticated, forKey: Keys.isAuthenticated) }
    }

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    var email: String {
        didSet { defaults.set(email, forKey: Keys.email) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAuthenticated = defaults.object(forKey: Keys.isAuthenticated) as? Bool ?? false
        self.displayName = defaults.string(forKey: Keys.displayName) ?? ""
        self.email = defaults.string(forKey: Keys.email) ?? ""
    }

    func signIn(name: String, email: String) {
        displayName = name
        self.email = email
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
        displayName = ""
        email = ""
    }
}
