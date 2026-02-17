import Foundation
import LocalAuthentication
import Observation

@Observable
final class AppSecuritySettings {
    private enum Keys {
        static let appLockEnabled = "security.appLockEnabled"
    }

    private let defaults: UserDefaults

    var isAppLockEnabled: Bool {
        didSet {
            defaults.set(isAppLockEnabled, forKey: Keys.appLockEnabled)
            if !isAppLockEnabled {
                isLocked = false
            }
        }
    }

    var isLocked: Bool
    var lastErrorMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.object(forKey: Keys.appLockEnabled) as? Bool ?? false
        self.isAppLockEnabled = enabled
        self.isLocked = enabled
        self.lastErrorMessage = nil
    }

    func lockIfNeeded() {
        guard isAppLockEnabled else { return }
        isLocked = true
    }

    @MainActor
    func unlock() async -> Bool {
        guard isAppLockEnabled else {
            isLocked = false
            return true
        }

        let context = LAContext()
        let reason = "Unlock Symptom Nerd to view your health data."

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success {
                isLocked = false
                lastErrorMessage = nil
            }
            return success
        } catch {
            lastErrorMessage = "Authentication failed. Try again."
            return false
        }
    }
}
