import Foundation
import Observation
import AuthenticationServices
import CryptoKit
import Security
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@Observable
final class AuthManager {
    static let didSignOutNotification = Notification.Name("AuthManagerDidSignOut")
    private enum Keys {
        static let isAuthenticated = "auth.isAuthenticated"
        static let displayName = "auth.displayName"
        static let email = "auth.email"
        static let profileImagePathPrefix = "auth.profileImagePath."
    }

    private let defaults: UserDefaults
    private var authHandle: AuthStateDidChangeListenerHandle?

    var isAuthenticated: Bool {
        didSet { defaults.set(isAuthenticated, forKey: Keys.isAuthenticated) }
    }

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    var email: String {
        didSet { defaults.set(email, forKey: Keys.email) }
    }

    var profileImagePath: String {
        didSet {
            defaults.set(profileImagePath, forKey: profileImagePathKey(for: currentProfileScope()))
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAuthenticated = defaults.object(forKey: Keys.isAuthenticated) as? Bool ?? false
        self.displayName = defaults.string(forKey: Keys.displayName) ?? ""
        self.email = defaults.string(forKey: Keys.email) ?? ""
        self.profileImagePath = defaults.string(forKey: Keys.profileImagePathPrefix + "guest") ?? ""
    }

    func startListening() {
        guard authHandle == nil else { return }
        guard FirebaseApp.app() != nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.isAuthenticated = true
                self.displayName = user.displayName ?? ""
                self.email = user.email ?? ""
                self.profileImagePath = self.defaults.string(forKey: self.profileImagePathKey(for: user.uid)) ?? ""
                Task { @MainActor in
                    await AppSessionManager.shared.activate(for: user)
                    await self.syncProfileImageFromCloud()
                }
            } else {
                self.isAuthenticated = false
                self.displayName = ""
                self.email = ""
                self.profileImagePath = self.defaults.string(forKey: self.profileImagePathKey(for: "guest")) ?? ""
                Task { @MainActor in
                    await AppSessionManager.shared.deactivate()
                }
            }
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    @MainActor
    func signUpWithEmail(name: String, email: String, password: String) async throws {
        let result = try await createUser(email: email, password: password)
        if !name.isEmpty {
            try await updateProfile(user: result.user, name: name)
        }
    }

    @MainActor
    func signInWithEmail(email: String, password: String) async throws {
        _ = try await signIn(email: email, password: password)
    }

    @MainActor
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String, fullName: PersonNameComponents?) async throws {
        guard let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.missingAppleToken
        }

        let oauthCredential = OAuthProvider.credential(
            providerID: .apple,
            idToken: tokenString,
            rawNonce: nonce
        )

        let result = try await signIn(with: oauthCredential)
        if let fullName, let name = formatName(fullName), !name.isEmpty {
            try await updateProfile(user: result.user, name: name)
        }
    }

    @MainActor
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        #if canImport(GoogleSignIn)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { signInResult, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let signInResult {
                    continuation.resume(returning: signInResult)
                } else {
                    continuation.resume(throwing: AuthError.unknown)
                }
            }
        }
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingGoogleToken
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        _ = try await signIn(with: credential)
        #else
        throw AuthError.googleSdkMissing
        #endif
    }

    func signOut() {
        Task { @MainActor in
            await AppSessionManager.shared.deactivate()
        }
        try? Auth.auth().signOut()
        isAuthenticated = false
        displayName = ""
        email = ""
        profileImagePath = defaults.string(forKey: profileImagePathKey(for: "guest")) ?? ""
        NotificationCenter.default.post(name: Self.didSignOutNotification, object: nil)
    }

    func saveProfileImage(data: Data) throws {
        let scope = currentProfileScope()
        let normalizedData = normalizedProfileImageData(from: data)
        let url = profileImageURL(for: scope)
        try normalizedData.write(to: url, options: [.atomic])
        profileImagePath = url.path
        if let userID = currentAuthenticatedUserID() {
            Task {
                await self.pushProfileImageToCloud(data: normalizedData, userID: userID)
            }
        }
    }

    func loadProfileImage() -> UIImage? {
        let scope = currentProfileScope()
        let path = defaults.string(forKey: profileImagePathKey(for: scope)) ?? profileImagePath
        if path != profileImagePath {
            profileImagePath = path
        }
        guard !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private func profileImageURL(for scope: String) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let safeScope = scope.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("profile-\(safeScope).jpg")
    }

    @MainActor
    func syncProfileImageFromCloud() async {
        guard FirebaseApp.app() != nil else { return }
        guard let uid = currentAuthenticatedUserID() else { return }
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document("medical_data")

        do {
            let snapshot = try await ref.getDocument()
            guard let data = snapshot.data(),
                  let base64 = data["profileImageBase64"] as? String,
                  let imageData = Data(base64Encoded: base64) else {
                return
            }
            let normalizedData = normalizedProfileImageData(from: imageData)
            let url = profileImageURL(for: uid)
            try normalizedData.write(to: url, options: [.atomic])
            profileImagePath = url.path
        } catch {
            // Best effort cloud sync; local image stays in use on failures.
        }
    }

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed.")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func createUser(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknown)
                }
            }
        }
    }

    private func signIn(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknown)
                }
            }
        }
    }

    private func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknown)
                }
            }
        }
    }

    private func updateProfile(user: User, name: String) async throws {
        let change = user.createProfileChangeRequest()
        change.displayName = name
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            change.commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func formatName(_ name: PersonNameComponents) -> String? {
        let parts = [name.givenName, name.familyName].compactMap { $0 }
        return parts.joined(separator: " ")
    }

    private func profileImagePathKey(for scope: String) -> String {
        Keys.profileImagePathPrefix + scope
    }

    private func currentProfileScope() -> String {
        currentAuthenticatedUserID() ?? "guest"
    }

    private func currentAuthenticatedUserID() -> String? {
        guard FirebaseApp.app() != nil else { return nil }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return nil }
        return uid
    }

    private func normalizedProfileImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 640
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.72) ?? data
    }

    private func pushProfileImageToCloud(data: Data, userID: String) async {
        guard FirebaseApp.app() != nil else { return }
        let ref = Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("private")
            .document("medical_data")
        do {
            try await ref.setData([
                "profileImageBase64": data.base64EncodedString(),
                "profileImageUpdatedAt": Timestamp(date: Date())
            ], merge: true)
        } catch {
            // Best effort sync only.
        }
    }
}

enum AuthError: LocalizedError {
    case missingAppleToken
    case missingGoogleToken
    case missingGoogleClientID
    case googleSdkMissing
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingAppleToken:
            return "Apple Sign-In failed. Try again."
        case .missingGoogleToken:
            return "Google Sign-In token missing."
        case .missingGoogleClientID:
            return "Google Client ID missing in Firebase config."
        case .googleSdkMissing:
            return "Google Sign-In SDK is not installed yet."
        case .unknown:
            return "Authentication failed."
        }
    }
}

struct AppSessionInfo: Identifiable, Equatable {
    let id: String
    let deviceName: String
    let platform: String
    let appVersion: String
    let createdAt: Date
    let lastSeenAt: Date
    let isCurrentDevice: Bool
    let isRevoked: Bool
}

@MainActor
final class AppSessionManager {
    static let shared = AppSessionManager()

    private enum Keys {
        static let sessionID = "app.session.id"
    }

    private let defaults = UserDefaults.standard
    private var heartbeatTask: Task<Void, Never>?
    private var revocationListener: ListenerRegistration?
    private var activeUserID: String?

    private init() {}

    var currentSessionID: String {
        if let existing = defaults.string(forKey: Keys.sessionID), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: Keys.sessionID)
        return created
    }

    func activate(for user: User) async {
        guard FirebaseApp.app() != nil else { return }
        let userID = user.uid
        if activeUserID != userID {
            await deactivate()
        }
        activeUserID = userID
        await upsertSession(userID: userID)
        startHeartbeat(userID: userID)
        startRevocationListener(userID: userID)
    }

    func deactivate() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        revocationListener?.remove()
        revocationListener = nil
        activeUserID = nil
    }

    func listSessions() async -> [AppSessionInfo] {
        guard let userID = activeUserID ?? Auth.auth().currentUser?.uid else { return [] }
        do {
            let snapshot = try await sessionsCollection(userID: userID).getDocuments()
            return snapshot.documents.compactMap { doc in
                let data = doc.data()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
                let lastSeenAt = (data["lastSeenAt"] as? Timestamp)?.dateValue() ?? createdAt
                let revokedAt = (data["revokedAt"] as? Timestamp)?.dateValue()
                return AppSessionInfo(
                    id: doc.documentID,
                    deviceName: data["deviceName"] as? String ?? "iPhone",
                    platform: data["platform"] as? String ?? "iOS",
                    appVersion: data["appVersion"] as? String ?? "Unknown",
                    createdAt: createdAt,
                    lastSeenAt: lastSeenAt,
                    isCurrentDevice: doc.documentID == currentSessionID,
                    isRevoked: revokedAt != nil
                )
            }
            .sorted(by: { $0.lastSeenAt > $1.lastSeenAt })
        } catch {
            return []
        }
    }

    func signOutAllOtherSessions() async {
        guard let userID = activeUserID ?? Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await sessionsCollection(userID: userID).getDocuments()
            for doc in snapshot.documents where doc.documentID != currentSessionID {
                try await doc.reference.setData([
                    "revokedAt": Timestamp(date: Date())
                ], merge: true)
            }
        } catch {
            // Best effort; UI can refresh to show current state.
        }
    }

    func revoke(sessionID: String) async {
        guard let userID = activeUserID ?? Auth.auth().currentUser?.uid else { return }
        guard sessionID != currentSessionID else { return }
        do {
            try await sessionsCollection(userID: userID)
                .document(sessionID)
                .setData(["revokedAt": Timestamp(date: Date())], merge: true)
        } catch {
            // Best effort revoke.
        }
    }

    private func sessionsCollection(userID: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("sessions")
    }

    private func sessionDocument(userID: String) -> DocumentReference {
        sessionsCollection(userID: userID).document(currentSessionID)
    }

    private func upsertSession(userID: String) async {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let appVersion = "\(version) (\(build))"
        let deviceName = UIDevice.current.name
        let platform = UIDevice.current.systemName + " " + UIDevice.current.systemVersion

        do {
            try await sessionDocument(userID: userID).setData([
                "id": currentSessionID,
                "deviceName": deviceName,
                "platform": platform,
                "appVersion": appVersion,
                "createdAt": FieldValue.serverTimestamp(),
                "lastSeenAt": FieldValue.serverTimestamp(),
                "revokedAt": FieldValue.delete()
            ], merge: true)
        } catch {
            // Ignore; session registration is best effort.
        }
    }

    private func touchSession(userID: String) async {
        do {
            try await sessionDocument(userID: userID).setData([
                "lastSeenAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            // Ignore transient heartbeat failures.
        }
    }

    private func startHeartbeat(userID: String) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.touchSession(userID: userID)
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func startRevocationListener(userID: String) {
        revocationListener?.remove()
        revocationListener = sessionDocument(userID: userID).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            guard data["revokedAt"] != nil else { return }
            Task { @MainActor in
                self.handleRemoteRevocation()
            }
        }
    }

    private func handleRemoteRevocation() {
        guard Auth.auth().currentUser != nil else { return }
        try? Auth.auth().signOut()
        NotificationCenter.default.post(name: AuthManager.didSignOutNotification, object: nil)
    }
}
