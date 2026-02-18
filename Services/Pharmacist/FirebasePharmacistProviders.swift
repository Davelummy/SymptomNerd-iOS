import Foundation
import FirebaseAuth
import FirebaseFirestore
import AVFoundation
import AudioToolbox
import UserNotifications
#if canImport(TwilioVoice)
import TwilioVoice
#endif

protocol ChatListener {
    func cancel()
}

protocol ChatProvider {
    func startChat(with handoff: HandoffPayload) async throws -> PharmacistChatSession
    func send(message: String, in session: PharmacistChatSession) async throws -> PharmacistMessage
}

protocol RealtimeChatProvider: ChatProvider {
    func listen(
        to session: PharmacistChatSession,
        onUpdate: @escaping ([PharmacistMessage], PharmacistAvailability?) -> Void
    ) -> ChatListener
}

protocol CallProvider {
    func requestCall(with handoff: HandoffPayload) async throws -> PharmacistCallStatus
    func observeStatus(onUpdate: @escaping (PharmacistCallStatus) -> Void) -> ChatListener?
    func fetchCallHistory() async throws -> PharmacistCallHistory
    func submitCallRating(callID: String, rating: Int, feedback: String?) async throws
    func endCall() async
    func setMuted(_ isMuted: Bool)
    func setSpeakerEnabled(_ isEnabled: Bool)
    func setOnHold(_ isOnHold: Bool)
}

extension CallProvider {
    func observeStatus(onUpdate: @escaping (PharmacistCallStatus) -> Void) -> ChatListener? { nil }
    func fetchCallHistory() async throws -> PharmacistCallHistory {
        PharmacistCallHistory(calls: [], totalCalls: 0, averageRating: nil)
    }
    func submitCallRating(callID: String, rating: Int, feedback: String?) async throws {
        _ = callID
        _ = rating
        _ = feedback
    }
    func endCall() async {}
    func setMuted(_ isMuted: Bool) { _ = isMuted }
    func setSpeakerEnabled(_ isEnabled: Bool) { _ = isEnabled }
    func setOnHold(_ isOnHold: Bool) { _ = isOnHold }
}

struct HandoffPayload: Codable, Equatable {
    var userMessage: String
    var summarizedLogs: String
    var attachedRange: DateInterval
    var attachmentIDs: [UUID]
    var contactPhone: String

    init(
        userMessage: String,
        summarizedLogs: String,
        attachedRange: DateInterval,
        attachmentIDs: [UUID] = [],
        contactPhone: String = ""
    ) {
        self.userMessage = userMessage
        self.summarizedLogs = summarizedLogs
        self.attachedRange = attachedRange
        self.attachmentIDs = attachmentIDs
        self.contactPhone = contactPhone
    }
}

struct PharmacistAvailability: Codable, Equatable {
    let statusText: String
    let queuePosition: Int?
}

enum PharmacistCallStatus: Equatable {
    case connecting(String)
    case scheduled(String)
    case connected(String, startedAt: Date)
    case ended(String, duration: TimeInterval)
    case failed(String)
}

struct PharmacistCallRecord: Identifiable, Equatable {
    let id: String
    let status: String
    let createdAt: Date?
    let startedAt: Date?
    let endedAt: Date?
    let durationSeconds: Int
    let rating: Int?
    let ratingFeedback: String?

    var canRate: Bool {
        status == "completed" && durationSeconds > 0 && rating == nil
    }
}

struct PharmacistCallHistory: Equatable {
    let calls: [PharmacistCallRecord]
    let totalCalls: Int
    let averageRating: Double?
}

struct PharmacistMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case pharmacist
        case system
    }

    let id: UUID
    let role: Role
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct PharmacistChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    let status: PharmacistAvailability
    var messages: [PharmacistMessage]
}

final class PharmacistService {
    private let chatProvider: ChatProvider
    private let callProvider: CallProvider
    private let defaults = UserDefaults.standard

    init(chatProvider: ChatProvider, callProvider: CallProvider) {
        self.chatProvider = chatProvider
        self.callProvider = callProvider
    }

    var isRealtimeChat: Bool {
        chatProvider is RealtimeChatProvider
    }

    func availability() async -> PharmacistAvailability {
        guard let baseURL = backendBaseURL(),
              let url = URL(string: "/pharmacist-presence", relativeTo: baseURL)?.absoluteURL else {
            return PharmacistAvailability(statusText: "Typically replies in 10–15 minutes", queuePosition: nil)
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return PharmacistAvailability(statusText: "Typically replies in 10–15 minutes", queuePosition: nil)
            }
            let payload = try JSONDecoder().decode(PharmacistPresencePayload.self, from: data)
            if payload.online {
                let statusText: String
                if payload.activeCalls > 0 {
                    statusText = "Pharmacist online • est. wait \(payload.estimatedWaitMinutes) min"
                } else {
                    statusText = "Pharmacist online now"
                }
                let queue = payload.activeCalls > 0 ? payload.activeCalls + 1 : nil
                return PharmacistAvailability(statusText: statusText, queuePosition: queue)
            }
            return PharmacistAvailability(statusText: "Pharmacist currently offline", queuePosition: nil)
        } catch {
            return PharmacistAvailability(statusText: "Typically replies in 10–15 minutes", queuePosition: nil)
        }
    }

    func startChat(with handoff: HandoffPayload) async throws -> PharmacistChatSession {
        try await chatProvider.startChat(with: handoff)
    }

    func send(message: String, in session: PharmacistChatSession) async throws -> PharmacistMessage {
        try await chatProvider.send(message: message, in: session)
    }

    func listenForMessages(
        in session: PharmacistChatSession,
        onUpdate: @escaping ([PharmacistMessage], PharmacistAvailability?) -> Void
    ) -> ChatListener? {
        guard let provider = chatProvider as? RealtimeChatProvider else { return nil }
        return provider.listen(to: session, onUpdate: onUpdate)
    }

    func requestCall(with handoff: HandoffPayload) async throws -> PharmacistCallStatus {
        try await callProvider.requestCall(with: handoff)
    }

    func callHistory() async throws -> PharmacistCallHistory {
        try await callProvider.fetchCallHistory()
    }

    func submitCallRating(callID: String, rating: Int, feedback: String?) async throws {
        try await callProvider.submitCallRating(callID: callID, rating: rating, feedback: feedback)
    }

    func observeCallStatus(onUpdate: @escaping (PharmacistCallStatus) -> Void) -> ChatListener? {
        callProvider.observeStatus(onUpdate: onUpdate)
    }

    func endCall() async {
        await callProvider.endCall()
    }

    func setMuted(_ isMuted: Bool) {
        callProvider.setMuted(isMuted)
    }

    func setSpeakerEnabled(_ isEnabled: Bool) {
        callProvider.setSpeakerEnabled(isEnabled)
    }

    func setOnHold(_ isOnHold: Bool) {
        callProvider.setOnHold(isOnHold)
    }

    private func backendBaseURL() -> URL? {
        AIProviderConfiguration.resolvedBaseURL(from: defaults.string(forKey: "ai.baseURL"))
    }
}

private struct PharmacistPresencePayload: Decodable {
    let online: Bool
    let activeCalls: Int
    let estimatedWaitMinutes: Int
}

private enum PharmacistBackendDefaults {
    static let productionBaseURL = "https://symptomnerd-backend.onrender.com"
}

enum PharmacistProviderError: LocalizedError {
    case notAuthenticated
    case firestorePermissionDenied

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in before starting a pharmacist chat."
        case .firestorePermissionDenied:
            return "Chat permission was denied by Firestore rules. Update Firestore rules to allow signed-in users to create/read their own pharmacist chat documents."
        }
    }
}

private func resolvedUserDisplayName(_ user: User) -> String {
    let trimmed = (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    if let email = user.email, !email.isEmpty { return email }
    return "User \(user.uid.prefix(6))"
}

struct FirebaseChatListener: ChatListener {
    let registrations: [ListenerRegistration]

    func cancel() {
        registrations.forEach { $0.remove() }
    }
}

final class FirebaseChatProvider: RealtimeChatProvider {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let sessionsCollection = "pharmacist_sessions"
    private let defaults = UserDefaults.standard
    private let activeSessionPrefix = "pharmacist.activeSession."

    func startChat(with handoff: HandoffPayload) async throws -> PharmacistChatSession {
        guard let user = auth.currentUser else { throw PharmacistProviderError.notAuthenticated }
        do {
            if let existingSession = try await loadActiveSession(for: user.uid) {
                return existingSession
            }
        } catch {
            if isPermissionDenied(error) {
                clearActiveSession(for: user.uid)
            } else {
                throw error
            }
        }

        let sessionID = UUID()
        let status = PharmacistAvailability(statusText: "Typically replies in 10–15 minutes", queuePosition: nil)
        let sessionRef = db.collection(sessionsCollection).document(sessionID.uuidString)

        do {
            try await sessionRef.setData(sessionData(sessionID: sessionID, handoff: handoff, status: status, user: user))

            let systemMessage = PharmacistMessage(role: .system, content: "Summary sent to pharmacist: \(handoff.userMessage)")
            let introMessage = PharmacistMessage(role: .pharmacist, content: "Thanks for reaching out. A pharmacist will review your summary shortly.")
            try await write(message: systemMessage, in: sessionRef)
            try await write(message: introMessage, in: sessionRef)
            saveActiveSession(sessionID, for: user.uid)

            return PharmacistChatSession(id: sessionID, status: status, messages: [systemMessage, introMessage])
        } catch {
            if isPermissionDenied(error) {
                throw PharmacistProviderError.firestorePermissionDenied
            }
            throw error
        }
    }

    func send(message: String, in session: PharmacistChatSession) async throws -> PharmacistMessage {
        guard auth.currentUser != nil else { throw PharmacistProviderError.notAuthenticated }
        let userMessage = PharmacistMessage(role: .user, content: message)
        let sessionRef = db.collection(sessionsCollection).document(session.id.uuidString)
        try await write(message: userMessage, in: sessionRef)
        return PharmacistMessage(role: .system, content: "Message sent.")
    }

    func listen(
        to session: PharmacistChatSession,
        onUpdate: @escaping ([PharmacistMessage], PharmacistAvailability?) -> Void
    ) -> ChatListener {
        let sessionRef = db.collection(sessionsCollection).document(session.id.uuidString)

        let messagesListener = sessionRef
            .collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error, let self {
                    if self.isPermissionDenied(error) {
                        onUpdate([], PharmacistAvailability(
                            statusText: "Chat blocked by Firebase permissions. Update Firestore rules for pharmacist chat.",
                            queuePosition: nil
                        ))
                    } else {
                        onUpdate([], PharmacistAvailability(
                            statusText: "Chat connection issue. Check internet and try again.",
                            queuePosition: nil
                        ))
                    }
                    return
                }
                let messages = snapshot?.documents.compactMap(Self.message(from:)) ?? []
                onUpdate(messages, nil)
            }

        let statusListener = sessionRef.addSnapshotListener { [weak self] snapshot, error in
            if let error, let self {
                if self.isPermissionDenied(error) {
                    onUpdate([], PharmacistAvailability(
                        statusText: "Chat blocked by Firebase permissions. Update Firestore rules for pharmacist chat.",
                        queuePosition: nil
                    ))
                } else {
                    onUpdate([], PharmacistAvailability(
                        statusText: "Chat connection issue. Check internet and try again.",
                        queuePosition: nil
                    ))
                }
                return
            }
            guard let data = snapshot?.data() else { return }
            let statusText = data["statusText"] as? String ?? session.status.statusText
            let queuePosition = data["queuePosition"] as? Int
            let status = PharmacistAvailability(statusText: statusText, queuePosition: queuePosition)
            onUpdate([], status)
        }

        return FirebaseChatListener(registrations: [messagesListener, statusListener])
    }

    private func sessionData(
        sessionID: UUID,
        handoff: HandoffPayload,
        status: PharmacistAvailability,
        user: User
    ) -> [String: Any] {
        return [
            "id": sessionID.uuidString,
            "userId": user.uid,
            "userDisplayName": resolvedUserDisplayName(user),
            "userEmail": user.email ?? "",
            "statusText": status.statusText,
            "queuePosition": status.queuePosition as Any,
            "handoff": handoffData(handoff),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private func handoffData(_ handoff: HandoffPayload) -> [String: Any] {
        [
            "userMessage": handoff.userMessage,
            "summarizedLogs": handoff.summarizedLogs,
            "attachedRange": [
                "start": Timestamp(date: handoff.attachedRange.start),
                "end": Timestamp(date: handoff.attachedRange.end)
            ],
            "attachmentIDs": handoff.attachmentIDs.map { $0.uuidString }
        ]
    }

    private func write(message: PharmacistMessage, in sessionRef: DocumentReference) async throws {
        guard let userId = auth.currentUser?.uid else { throw PharmacistProviderError.notAuthenticated }
        let data: [String: Any] = [
            "id": message.id.uuidString,
            "role": message.role.rawValue,
            "content": message.content,
            "createdAt": Timestamp(date: message.createdAt),
            "senderId": userId
        ]
        try await sessionRef.collection("messages").document(message.id.uuidString).setData(data)
        try await sessionRef.updateData(["updatedAt": FieldValue.serverTimestamp()])
    }

    private static func message(from doc: QueryDocumentSnapshot) -> PharmacistMessage? {
        let data = doc.data()
        let roleString = data["role"] as? String ?? "system"
        let role = PharmacistMessage.Role(rawValue: roleString) ?? .system
        let content = data["content"] as? String ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let idString = data["id"] as? String ?? doc.documentID
        let id = UUID(uuidString: idString) ?? UUID()
        return PharmacistMessage(id: id, role: role, content: content, createdAt: createdAt)
    }

    private func sessionKey(for userID: String) -> String {
        activeSessionPrefix + userID
    }

    private func saveActiveSession(_ sessionID: UUID, for userID: String) {
        defaults.set(sessionID.uuidString, forKey: sessionKey(for: userID))
    }

    private func clearActiveSession(for userID: String) {
        defaults.removeObject(forKey: sessionKey(for: userID))
    }

    private func loadActiveSession(for userID: String) async throws -> PharmacistChatSession? {
        if let rawSessionID = defaults.string(forKey: sessionKey(for: userID)),
           let sessionID = UUID(uuidString: rawSessionID),
           let localSession = try await hydrateSession(sessionID: sessionID, userID: userID) {
            return localSession
        }

        let snapshot = try await db.collection(sessionsCollection)
            .whereField("userId", isEqualTo: userID)
            .limit(to: 20)
            .getDocuments()

        let newestSessionID = snapshot.documents
            .sorted {
                let left = ($0.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                let right = ($1.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                return left > right
            }
            .compactMap { UUID(uuidString: $0.documentID) }
            .first

        guard let sessionID = newestSessionID,
              let serverSession = try await hydrateSession(sessionID: sessionID, userID: userID) else {
            return nil
        }
        saveActiveSession(sessionID, for: userID)
        return serverSession
    }

    private func hydrateSession(sessionID: UUID, userID: String) async throws -> PharmacistChatSession? {
        let rawSessionID = sessionID.uuidString
        let sessionRef = db.collection(sessionsCollection).document(rawSessionID)
        let snapshot = try await sessionRef.getDocument()
        guard let data = snapshot.data(),
              let owner = data["userId"] as? String,
              owner == userID else {
            clearActiveSession(for: userID)
            return nil
        }
        let status = PharmacistAvailability(
            statusText: data["statusText"] as? String ?? "Typically replies in 10–15 minutes",
            queuePosition: data["queuePosition"] as? Int
        )

        let messageSnapshot = try await sessionRef
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .getDocuments()
        let messages = messageSnapshot.documents.compactMap(Self.message(from:))

        return PharmacistChatSession(id: sessionID, status: status, messages: messages)
    }

    private func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.code == FirestoreErrorCode.permissionDenied.rawValue &&
            nsError.domain.localizedCaseInsensitiveContains("firestore")
    }
}

final class FirebaseCallProvider: CallProvider {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let callsCollection = "pharmacist_call_requests"

    func requestCall(with handoff: HandoffPayload) async throws -> PharmacistCallStatus {
        guard let user = auth.currentUser else { throw PharmacistProviderError.notAuthenticated }

        let requestID = UUID()
        let callerName = resolvedUserDisplayName(user)
        let data: [String: Any] = [
            "id": requestID.uuidString,
            "userId": user.uid,
            "callerName": callerName,
            "userDisplayName": callerName,
            "handoff": [
                "userMessage": handoff.userMessage,
                "summarizedLogs": handoff.summarizedLogs,
                "attachedRange": [
                    "start": Timestamp(date: handoff.attachedRange.start),
                    "end": Timestamp(date: handoff.attachedRange.end)
                ],
                "attachmentIDs": handoff.attachmentIDs.map { $0.uuidString }
            ],
            "status": "requested",
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await db.collection(callsCollection).document(requestID.uuidString).setData(data)

        return .scheduled("Call request sent. A pharmacist will answer shortly.")
    }
}

enum TwilioVoiceCallError: LocalizedError {
    case backendURLMissing
    case backendTokenMissing
    case invalidBackendResponse
    case sdkNotInstalled

    var errorDescription: String? {
        switch self {
        case .backendURLMissing:
            return "Set your backend URL in Settings before starting a call."
        case .backendTokenMissing:
            return "Unable to authenticate call request."
        case .invalidBackendResponse:
            return "Call setup failed. Please try again."
        case .sdkNotInstalled:
            return "Live call requires Twilio Voice iOS SDK in Xcode (Add Package Dependency)."
        }
    }
}

private struct TwilioVoiceStartCallPayload: Decodable {
    let queued: Bool?
    let requestId: String?
    let queuePosition: Int?
    let message: String?
    let token: String?
    let displayName: String?
    let pharmacistIdentity: String?
}

private struct TwilioVoiceStartCallRequest: Encodable {
    let handoff: HandoffPayload
}

private struct TwilioVoiceStatusRequest: Encodable {
    let status: String
}

private struct TwilioVoiceCallReadPayload: Decodable {
    let call: TwilioVoiceCallStatusPayload
}

private struct TwilioVoiceCallHistoryPayload: Decodable {
    let calls: [TwilioVoiceCallHistoryItemPayload]
    let totalCalls: Int?
    let averageRating: Double?
}

private struct TwilioVoiceCallHistoryItemPayload: Decodable {
    let id: String
    let status: String?
    let createdAtMillis: Double?
    let startedAtMillis: Double?
    let endedAtMillis: Double?
    let durationSeconds: Int?
    let rating: Int?
    let ratingFeedback: String?
}

private struct TwilioVoiceCallStatusPayload: Decodable {
    let status: String
    let queuePosition: Int?
}

private struct TwilioVoiceBackendError: Decodable {
    let error: String?
}

private struct TwilioVoiceCallRatingRequest: Encodable {
    let rating: Int
    let feedback: String
}

private final class InlineCallStatusListener: ChatListener {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

final class TwilioVoiceCallProvider: NSObject, CallProvider {
    private let auth = Auth.auth()
    private let fallback: CallProvider
    private let defaults: UserDefaults
    private let callbacksLock = NSLock()
    private var callbacks: [UUID: (PharmacistCallStatus) -> Void] = [:]
    private var activeRequestID: String?
    private var connectedAt: Date?
    private var ringbackTimer: DispatchSourceTimer?
    private var ringbackIsActive = false
    private var queuePollTask: Task<Void, Never>?
    private var lastKnownQueuePosition: Int?
    private let minimumConnectedSecondsForCompletion: TimeInterval = 6
#if canImport(TwilioVoice)
    private var activeCall: Call?
#endif

    init(fallback: CallProvider = FirebaseCallProvider(), defaults: UserDefaults = .standard) {
        self.fallback = fallback
        self.defaults = defaults
        super.init()
    }

    func requestCall(with handoff: HandoffPayload) async throws -> PharmacistCallStatus {
#if canImport(TwilioVoice)
        guard let user = auth.currentUser else { throw PharmacistProviderError.notAuthenticated }
        do {
            let payload = try await startCall(for: user, handoff: handoff)
            if let requestID = payload.requestId, !requestID.isEmpty {
                activeRequestID = requestID
            }

            let queuePosition = payload.queuePosition ?? 1
            if payload.queued == true || payload.token == nil || payload.pharmacistIdentity == nil {
                if let requestID = payload.requestId {
                    startQueuePolling(requestID: requestID)
                }
                let queueMessage = payload.message ?? "All pharmacists are on active calls. You are #\(queuePosition) in queue."
                emit(.scheduled(queueMessage))
                return .scheduled(queueMessage)
            }

            let callerName = payload.displayName ?? resolvedUserDisplayName(user)
            let options = ConnectOptions(accessToken: payload.token ?? "") { builder in
                builder.params = [
                    "To": payload.pharmacistIdentity ?? "",
                    "CallerName": callerName
                ]
                if let requestID = payload.requestId {
                    builder.params["RequestID"] = requestID
                }
            }

            connectedAt = nil
            stopQueuePolling()
            activeCall = TwilioVoiceSDK.connect(options: options, delegate: self)
            emit(.connecting("Calling pharmacist…"))
            return .connecting("Calling pharmacist…")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            emit(.failed("Live call unavailable. \(message)"))
            throw error
        }
#else
        emit(.failed(TwilioVoiceCallError.sdkNotInstalled.localizedDescription))
        throw TwilioVoiceCallError.sdkNotInstalled
#endif
    }

    func fetchCallHistory() async throws -> PharmacistCallHistory {
        guard let user = auth.currentUser else { throw PharmacistProviderError.notAuthenticated }
        guard let baseURL = backendBaseURL(),
              let url = URL(string: "/twilio/calls/history", relativeTo: baseURL)?.absoluteURL else {
            throw TwilioVoiceCallError.backendURLMissing
        }

        let firebaseToken = try await user.getIDToken()
        guard !firebaseToken.isEmpty else { throw TwilioVoiceCallError.backendTokenMissing }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let backendError = try? JSONDecoder().decode(TwilioVoiceBackendError.self, from: data),
               let message = backendError.error,
               !message.isEmpty {
                throw NSError(domain: "TwilioVoiceCallProvider", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw TwilioVoiceCallError.invalidBackendResponse
        }

        let payload = try JSONDecoder().decode(TwilioVoiceCallHistoryPayload.self, from: data)
        let calls = payload.calls.map { item in
            PharmacistCallRecord(
                id: item.id,
                status: item.status ?? "unknown",
                createdAt: Self.dateFromMillis(item.createdAtMillis),
                startedAt: Self.dateFromMillis(item.startedAtMillis),
                endedAt: Self.dateFromMillis(item.endedAtMillis),
                durationSeconds: max(0, item.durationSeconds ?? 0),
                rating: item.rating,
                ratingFeedback: item.ratingFeedback
            )
        }
        return PharmacistCallHistory(
            calls: calls,
            totalCalls: payload.totalCalls ?? calls.count,
            averageRating: payload.averageRating
        )
    }

    func submitCallRating(callID: String, rating: Int, feedback: String?) async throws {
        guard let user = auth.currentUser else { throw PharmacistProviderError.notAuthenticated }
        guard let baseURL = backendBaseURL(),
              let url = URL(string: "/twilio/calls/\(callID)/rating", relativeTo: baseURL)?.absoluteURL else {
            throw TwilioVoiceCallError.backendURLMissing
        }

        let firebaseToken = try await user.getIDToken()
        guard !firebaseToken.isEmpty else { throw TwilioVoiceCallError.backendTokenMissing }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            TwilioVoiceCallRatingRequest(
                rating: rating,
                feedback: String((feedback ?? "").prefix(500))
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let backendError = try? JSONDecoder().decode(TwilioVoiceBackendError.self, from: data),
               let message = backendError.error,
               !message.isEmpty {
                throw NSError(domain: "TwilioVoiceCallProvider", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw TwilioVoiceCallError.invalidBackendResponse
        }
    }

    func observeStatus(onUpdate: @escaping (PharmacistCallStatus) -> Void) -> ChatListener? {
        let id = UUID()
        storeCallback(onUpdate, id: id)
        return InlineCallStatusListener { [weak self] in
            guard let self else { return }
            self.removeCallback(id: id)
        }
    }

    func endCall() async {
#if canImport(TwilioVoice)
        stopQueuePolling()
        stopRingbackTone()
        if activeCall == nil {
            await postCallStatus("cancelled")
        }
        activeCall?.disconnect()
        activeCall = nil
#endif
        await fallback.endCall()
    }

    func setMuted(_ isMuted: Bool) {
#if canImport(TwilioVoice)
        (activeCall as AnyObject?)?.setValue(isMuted, forKey: "muted")
#else
        _ = isMuted
#endif
    }

    func setSpeakerEnabled(_ isEnabled: Bool) {
        do {
            try configureAudioSessionForCall()
            let output: AVAudioSession.PortOverride = isEnabled ? .speaker : .none
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(output)
        } catch {
            emit(.failed("Unable to change speaker route. \(error.localizedDescription)"))
        }
    }

    func setOnHold(_ isOnHold: Bool) {
#if canImport(TwilioVoice)
        (activeCall as AnyObject?)?.setValue(isOnHold, forKey: "onHold")
#else
        _ = isOnHold
#endif
    }

    private func emit(_ status: PharmacistCallStatus) {
        let listeners = allCallbacks()
        guard !listeners.isEmpty else { return }
        DispatchQueue.main.async {
            listeners.forEach { $0(status) }
        }
    }

    private func storeCallback(_ callback: @escaping (PharmacistCallStatus) -> Void, id: UUID) {
        callbacksLock.lock()
        callbacks[id] = callback
        callbacksLock.unlock()
    }

    private func removeCallback(id: UUID) {
        callbacksLock.lock()
        callbacks.removeValue(forKey: id)
        callbacksLock.unlock()
    }

    private func allCallbacks() -> [(PharmacistCallStatus) -> Void] {
        callbacksLock.lock()
        let listeners = Array(callbacks.values)
        callbacksLock.unlock()
        return listeners
    }

    private func backendBaseURL() -> URL? {
        AIProviderConfiguration.resolvedBaseURL(from: defaults.string(forKey: "ai.baseURL"))
    }

    private func configureAudioSessionForCall() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
        try session.setActive(true)
    }

    private func startRingbackTone() {
        if ringbackIsActive { return }
        stopRingbackTone()
        ringbackIsActive = true
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .seconds(3))
        timer.setEventHandler {
            guard self.ringbackIsActive else { return }
            AudioServicesPlaySystemSound(1005)
        }
        timer.resume()
        ringbackTimer = timer
    }

    private func stopRingbackTone() {
        ringbackIsActive = false
        ringbackTimer?.cancel()
        ringbackTimer = nil
    }

    private func startQueuePolling(requestID: String) {
        stopQueuePolling()
        lastKnownQueuePosition = nil
        queuePollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollQueueStatus(requestID: requestID)
                try? await Task.sleep(nanoseconds: 7_000_000_000)
            }
        }
    }

    private func stopQueuePolling() {
        queuePollTask?.cancel()
        queuePollTask = nil
        lastKnownQueuePosition = nil
    }

    private func notifyQueueReady() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Pharmacist line ready"
            content.body = "You are first in queue. Return to the app and tap Start live call."
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "pharmacist.queue.ready", content: content, trigger: nil))
        }
    }

    private func pollQueueStatus(requestID: String) async {
        guard let user = auth.currentUser,
              let baseURL = backendBaseURL(),
              let url = URL(string: "/twilio/calls/\(requestID)", relativeTo: baseURL)?.absoluteURL else {
            return
        }

        do {
            let firebaseToken = try await user.getIDToken()
            guard !firebaseToken.isEmpty else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            let payload = try JSONDecoder().decode(TwilioVoiceCallReadPayload.self, from: data)
            let queuePosition = payload.call.queuePosition

            if let queuePosition {
                if queuePosition > 1 {
                    if lastKnownQueuePosition != queuePosition {
                        emit(.scheduled("All pharmacists are on active calls. You are #\(queuePosition) in queue."))
                    }
                    lastKnownQueuePosition = queuePosition
                } else if queuePosition == 1 {
                    if lastKnownQueuePosition != 1 {
                        emit(.scheduled("You're now first in queue. Tap Start live call to connect instantly."))
                        notifyQueueReady()
                    }
                    lastKnownQueuePosition = 1
                    stopQueuePolling()
                }
            }
        } catch {
            // Best effort polling only.
        }
    }

    private func startCall(for user: User, handoff: HandoffPayload) async throws -> TwilioVoiceStartCallPayload {
        guard let baseURL = backendBaseURL() else {
            throw TwilioVoiceCallError.backendURLMissing
        }
        let firebaseToken = try await user.getIDToken()
        guard !firebaseToken.isEmpty else { throw TwilioVoiceCallError.backendTokenMissing }

        guard let url = URL(string: "/twilio/start-call", relativeTo: baseURL)?.absoluteURL else {
            throw TwilioVoiceCallError.backendURLMissing
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(TwilioVoiceStartCallRequest(handoff: handoff))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TwilioVoiceCallError.invalidBackendResponse
        }

        guard (200...299).contains(http.statusCode) else {
            if let backendError = try? JSONDecoder().decode(TwilioVoiceBackendError.self, from: data),
               let message = backendError.error,
               !message.isEmpty {
                throw NSError(domain: "TwilioVoiceCallProvider", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw TwilioVoiceCallError.invalidBackendResponse
        }

        return try JSONDecoder().decode(TwilioVoiceStartCallPayload.self, from: data)
    }

    private func postCallStatus(_ status: String) async {
        guard let requestID = activeRequestID,
              let user = auth.currentUser,
              let baseURL = backendBaseURL(),
              let url = URL(string: "/twilio/calls/\(requestID)/status", relativeTo: baseURL)?.absoluteURL else {
            return
        }

        do {
            let firebaseToken = try await user.getIDToken()
            guard !firebaseToken.isEmpty else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(TwilioVoiceStatusRequest(status: status))
            _ = try await URLSession.shared.data(for: request)
        } catch {
            // Status sync is best effort; local call state remains authoritative for the user UI.
        }

        if ["completed", "failed", "cancelled"].contains(status) {
            activeRequestID = nil
        }
    }

    private static func dateFromMillis(_ rawValue: Double?) -> Date? {
        guard let rawValue, rawValue > 0 else { return nil }
        return Date(timeIntervalSince1970: rawValue / 1000)
    }
}

#if canImport(TwilioVoice)
extension TwilioVoiceCallProvider: CallDelegate {
    func callDidStartRinging(call: Call) {
        activeCall = call
        startRingbackTone()
        emit(.connecting("Ringing pharmacist…"))
        Task { await postCallStatus("ringing") }
    }

    func callDidConnect(call: Call) {
        activeCall = call
        stopRingbackTone()
        stopQueuePolling()
        let now = Date()
        connectedAt = now
        emit(.connected("Connected. You are now speaking with the pharmacist.", startedAt: now))
        Task { await postCallStatus("in_progress") }
    }

    func callDidFailToConnect(call: Call, error: Error) {
        _ = call
        activeCall = nil
        stopRingbackTone()
        stopQueuePolling()
        connectedAt = nil
        emit(.failed("Call failed to connect. \(error.localizedDescription)"))
        Task { await postCallStatus("failed") }
    }

    func callDidDisconnect(call: Call, error: Error?) {
        _ = call
        activeCall = nil
        stopRingbackTone()
        stopQueuePolling()
        let wasConnected = connectedAt != nil
        let duration = max(0, Date().timeIntervalSince(connectedAt ?? Date()))
        connectedAt = nil
        if let error {
            emit(.failed(error.localizedDescription))
            Task { await postCallStatus("failed") }
        } else if !wasConnected {
            emit(.ended("Call was not answered.", duration: 0))
            Task { await postCallStatus("missed") }
        } else if duration < minimumConnectedSecondsForCompletion {
            emit(.ended("Call disconnected before conversation started.", duration: 0))
            Task { await postCallStatus("missed") }
        } else {
            emit(.ended("Call ended.", duration: duration))
            Task { await postCallStatus("completed") }
        }
    }
}
#endif
