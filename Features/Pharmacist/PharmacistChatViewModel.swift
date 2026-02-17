import Foundation
import UIKit
import UserNotifications
import AudioToolbox

@MainActor
final class PharmacistChatViewModel: ObservableObject {
    @Published var messages: [PharmacistMessage] = []
    @Published var input: String = ""
    @Published var statusText: String = ""
    @Published var queuePosition: Int?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private var service: PharmacistService?
    private var session: PharmacistChatSession?
    private let transcriptStore = PharmacistTranscriptStore()
    private var listener: ChatListener?
    private var usesRealtime = false
    private var lastKnownPharmacistMessageID: UUID?

    func configure(service: PharmacistService, handoff: HandoffPayload) async {
        if self.service == nil {
            self.service = service
            await startChat(handoff: handoff)
        }
    }

    func send() async {
        guard let service, var session else {
            errorMessage = "Chat not started yet. Please try again."
            return
        }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        input = ""

        let userMessage = PharmacistMessage(role: .user, content: text)
        messages.append(userMessage)
        session.messages.append(userMessage)
        persist(session: session)

        isLoading = true
        do {
            if usesRealtime {
                _ = try await service.send(message: text, in: session)
            } else {
                let reply = try await service.send(message: text, in: session)
                messages.append(reply)
                session.messages.append(reply)
                persist(session: session)
            }
            self.session = session
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func startChat(handoff: HandoffPayload) async {
        guard let service else { return }
        isLoading = true
        do {
            let session = try await service.startChat(with: handoff)
            self.session = session
            self.messages = session.messages
            self.lastKnownPharmacistMessageID = session.messages.last(where: { $0.role == .pharmacist })?.id
            self.statusText = session.status.statusText
            self.queuePosition = session.status.queuePosition
            persist(session: session)
            startListening(session: session, service: service)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func persist(session: PharmacistChatSession) {
        transcriptStore.save(sessionID: session.id, messages: session.messages)
    }

    private func startListening(session: PharmacistChatSession, service: PharmacistService) {
        listener = service.listenForMessages(in: session) { [weak self] messages, status in
            guard let self else { return }
            Task { @MainActor in
                if !messages.isEmpty {
                    if let latestPharmacistMessage = messages.last(where: { $0.role == .pharmacist }),
                       latestPharmacistMessage.id != self.lastKnownPharmacistMessageID {
                        self.lastKnownPharmacistMessageID = latestPharmacistMessage.id
                        self.playIncomingMessageAlert()
                        self.notifyIfBackground(message: latestPharmacistMessage.content)
                    }
                    self.messages = messages
                }
                if let status {
                    self.statusText = status.statusText
                    self.queuePosition = status.queuePosition
                }
                if let currentSession = self.session {
                    let updatedStatus = status ?? currentSession.status
                    self.session = PharmacistChatSession(id: currentSession.id, status: updatedStatus, messages: self.messages)
                    if let session = self.session {
                        self.persist(session: session)
                    }
                }
            }
        }
        usesRealtime = listener != nil
    }

    deinit {
        listener?.cancel()
    }

    private func notifyIfBackground(message: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Pharmacist replied"
            content.body = message
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "pharmacist.reply.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    private func playIncomingMessageAlert() {
        AudioServicesPlaySystemSound(1005)
    }
}
