import UserNotifications

enum UNNotificationHelper {
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyCountdownStarted(title: String, seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting soon"
        content.body = "\(title) — \(seconds)s countdown in menu bar."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
