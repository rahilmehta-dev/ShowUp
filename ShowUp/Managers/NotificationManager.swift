import Foundation
import UserNotifications

@Observable
final class NotificationManager: NSObject {
    var isAuthorized: Bool = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorization()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }

    private func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Notification Senders

    func sendEnterZoneNotification(taskName: String, locationName: String) {
        send(
            id: "enter_\(taskName)_\(Date().timeIntervalSince1970)",
            title: "📍 You're at \(locationName)",
            body: "Timer started for \(taskName)!"
        )
    }

    func sendExitZoneNotification(taskName: String) {
        send(
            id: "exit_\(taskName)_\(Date().timeIntervalSince1970)",
            title: "⏸ Timer paused",
            body: "Come back to continue \(taskName)"
        )
    }

    func sendHalfwayNotification(taskName: String) {
        send(
            id: "halfway_\(taskName)",
            title: "Halfway there! 💪",
            body: "Keep going on \(taskName)"
        )
    }

    func scheduleProgressNotification(taskName: String, remainingMinutes: Int, percentKey: String) {
        cancel(id: "progress_\(taskName)_\(percentKey)")
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        send(
            id: "progress_\(taskName)_\(percentKey)",
            title: "Almost done! 🏁",
            body: "Just \(remainingMinutes) min to go on \(taskName)",
            trigger: trigger
        )
    }

    func sendCompletionNotification(taskName: String, streak: Int) {
        send(
            id: "complete_\(taskName)_\(Date().timeIntervalSince1970)",
            title: "✅ \(taskName) complete!",
            body: "Streak: \(streak) day\(streak == 1 ? "" : "s") 🔥"
        )
    }

    func sendExitGracePeriodNotification(taskName: String, gracePeriodMinutes: Int) {
        send(
            id: "grace_\(taskName)_\(Date().timeIntervalSince1970)",
            title: "⏸ Timer paused — come back to continue",
            body: "\(taskName) timer paused after \(gracePeriodMinutes)min away"
        )
    }

    // MARK: - Helpers

    private func send(id: String, title: String, body: String, trigger: UNNotificationTrigger? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}
