import Foundation
import UserNotifications

struct NotificationClient {
    private enum Keys {
        static let wellnessNotificationsEnabled = "notifications.wellness.enabled"
        static let lastWellnessSchedule = "notifications.wellness.lastScheduledAt"
    }

    private let defaults = UserDefaults.standard
    private let center = UNUserNotificationCenter.current()

    var isWellnessNotificationsEnabled: Bool {
        get { defaults.object(forKey: Keys.wellnessNotificationsEnabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Keys.wellnessNotificationsEnabled) }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func configureWellnessNotifications() async {
        guard isWellnessNotificationsEnabled else {
            await clearWellnessNotifications()
            return
        }

        let granted = await requestAuthorization()
        guard granted else { return }

        if shouldRefreshSchedule() {
            await scheduleRandomWellnessNotifications(daysAhead: 14)
        }
    }

    func setWellnessNotificationsEnabled(_ isEnabled: Bool) async {
        isWellnessNotificationsEnabled = isEnabled
        if isEnabled {
            await configureWellnessNotifications()
        } else {
            await clearWellnessNotifications()
        }
    }

    private func shouldRefreshSchedule() -> Bool {
        guard let last = defaults.object(forKey: Keys.lastWellnessSchedule) as? Date else { return true }
        return Date().timeIntervalSince(last) > 60 * 60 * 24 * 3
    }

    private func scheduleRandomWellnessNotifications(daysAhead: Int) async {
        await clearWellnessNotifications()

        let calendar = Calendar.current
        let reminderPrompts = [
            "Quick check-in: log your current symptom status.",
            "How are you feeling now? Add a short health update.",
            "A small habit helps: record your symptom state today.",
            "Track now so patterns stay accurate."
        ]
        let healthTips = [
            "Health tip: note hydration, sleep, and stress with each symptom log.",
            "Health tip: capture symptom timing to spot reliable triggers.",
            "Health tip: include meds/supplements in your notes for better pharmacist support.",
            "Health tip: short daily logs are better than occasional long ones."
        ]
        let maxPendingRequests = 60
        var scheduledCount = 0

        for dayOffset in 0..<max(1, daysAhead) {
            if scheduledCount >= maxPendingRequests { break }
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            let notificationsToday = Int.random(in: 4...5)
            let tipCount = max(1, notificationsToday / 2)
            let reminderCount = notificationsToday - tipCount
            var types = Array(repeating: false, count: reminderCount) + Array(repeating: true, count: tipCount)
            types.shuffle()

            var minuteSlots = Set<Int>()
            while minuteSlots.count < notificationsToday {
                let hour = Int.random(in: 8...21)
                let minute = [0, 10, 15, 20, 30, 40, 45, 50].randomElement() ?? 15
                minuteSlots.insert((hour * 60) + minute)
            }

            let sortedSlots = minuteSlots.sorted()
            for (index, slot) in sortedSlots.enumerated() {
                if scheduledCount >= maxPendingRequests { break }
                let hour = slot / 60
                let minute = slot % 60
                var components = calendar.dateComponents([.year, .month, .day], from: dayDate)
                components.hour = hour
                components.minute = minute

                guard let targetDate = calendar.date(from: components), targetDate > Date() else {
                    continue
                }

                let isTip = types[index % types.count]
                let content = UNMutableNotificationContent()
                content.title = isTip ? "Symptom Nerd health tip" : "Health log reminder"
                content.body = isTip
                    ? (healthTips.randomElement() ?? "Health tip: keep logging regularly.")
                    : (reminderPrompts.randomElement() ?? "Log your current health state.")
                content.sound = .default

                let identifier = "wellness.random.\(dayOffset).\(hour).\(minute)"
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                do {
                    try await center.add(request)
                    scheduledCount += 1
                } catch {
                    continue
                }
            }
        }

        defaults.set(Date(), forKey: Keys.lastWellnessSchedule)
    }

    private func clearWellnessNotifications() async {
        let identifiers = await pendingWellnessIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func pendingWellnessIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let ids = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix("wellness.random.") }
                continuation.resume(returning: ids)
            }
        }
    }
}
