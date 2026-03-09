import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    override private init() {
        super.init()
        // Set ourselves as delegate so notifications show even while app is "active"
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func sendDistractedNotification(task: String, reason: String) {
        let titles = [
            "Hey, you drifted off",
            "Not what you said you'd do",
            "Wrong rabbit hole",
            "Get back on track",
            "Focus check failed",
        ]
        let bodies = [
            "You were supposed to: \(task)",
            "Remember? \(task)",
            "Get back to: \(task)",
            "Your task is still: \(task)",
            "\(task) — that's the thing",
        ]

        let content = UNMutableNotificationContent()
        content.title = titles.randomElement()!
        content.body = bodies.randomElement()!
        // No subtitle — keep it clean
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "focus-check-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    func sendSessionStartNotification(task: String) {
        let content = UNMutableNotificationContent()
        content.title = "Focus session started"
        content.body = "Working on: \(task)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "session-start",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    // This is the key fix: allow notifications to display even when our app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
