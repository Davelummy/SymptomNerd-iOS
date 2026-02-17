import Foundation

@MainActor
final class PharmacistCallViewModel: ObservableObject {
    enum CallState: Equatable {
        case checking
        case requesting
        case connecting(String)
        case scheduled(String)
        case connected(String)
        case ended(String)
        case failed(String)
    }

    @Published var callState: CallState = .checking
    @Published var availability: PharmacistAvailability?
    @Published var isMuted = false
    @Published var isSpeakerOn = false
    @Published var isOnHold = false
    @Published var durationText = "00:00"

    private var service: PharmacistService?
    private var statusListener: ChatListener?
    private var durationTask: Task<Void, Never>?
    private var hasConnected = false

    func loadAvailability(service: PharmacistService) async {
        if self.service == nil {
            self.service = service
            statusListener = service.observeCallStatus { [weak self] status in
                guard let self else { return }
                Task { @MainActor in
                    self.apply(status: status)
                }
            }
        }
        await fetchAvailability()
    }

    func requestCall(handoff: HandoffPayload) async {
        guard service != nil else { return }
        await requestCallInternal(handoff: handoff)
    }

    func endCall() async {
        guard let service else { return }
        await service.endCall()
        if case .scheduled = callState {
            callState = .ended("Call request cancelled.")
        } else if case .connecting = callState {
            callState = .ended("Call ended.")
        }
        stopDurationTicker(reset: !hasConnected)
        isOnHold = false
        isMuted = false
        isSpeakerOn = false
        hasConnected = false
    }

    func setMuted(_ value: Bool) {
        isMuted = value
        service?.setMuted(value)
    }

    func setSpeaker(_ value: Bool) {
        isSpeakerOn = value
        service?.setSpeakerEnabled(value)
    }

    func setOnHold(_ value: Bool) {
        isOnHold = value
        service?.setOnHold(value)
    }

    private func fetchAvailability() async {
        guard let service else { return }
        callState = .checking
        availability = await service.availability()
    }

    private func requestCallInternal(handoff: HandoffPayload) async {
        guard let service else { return }
        callState = .requesting
        stopDurationTicker(reset: true)
        do {
            let status = try await service.requestCall(with: handoff)
            apply(status: status)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Unable to start a live call right now."
            callState = .failed(message)
        }
    }

    private func apply(status: PharmacistCallStatus) {
        switch status {
        case .connecting(let text):
            callState = .connecting(text)
            stopDurationTicker(reset: true)
            hasConnected = false
        case .scheduled(let text):
            callState = .scheduled(text)
            stopDurationTicker(reset: true)
            hasConnected = false
        case .connected(let text, let startedAt):
            callState = .connected(text)
            hasConnected = true
            startDurationTicker(from: startedAt)
        case .ended(let text, let duration):
            callState = .ended(text)
            stopDurationTicker(reset: false)
            durationText = Self.formatDuration(seconds: Int(duration))
            isMuted = false
            isOnHold = false
            isSpeakerOn = false
            hasConnected = false
        case .failed(let text):
            callState = .failed(text)
            stopDurationTicker(reset: !hasConnected)
            isOnHold = false
            isSpeakerOn = false
            hasConnected = false
        }
    }

    private func startDurationTicker(from start: Date) {
        stopDurationTicker(reset: false)
        durationTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    guard let self else { return }
                    let elapsed = Int(Date().timeIntervalSince(start))
                    self.durationText = Self.formatDuration(seconds: elapsed)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopDurationTicker(reset: Bool) {
        durationTask?.cancel()
        durationTask = nil
        if reset {
            durationText = "00:00"
        }
    }

    private static func formatDuration(seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    deinit {
        durationTask?.cancel()
        statusListener?.cancel()
    }
}
