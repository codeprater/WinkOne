import UserNotifications
import UIKit

final class WinkNotify: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WinkNotify()

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func announce(from name: String, text: String) {
        let content = UNMutableNotificationContent()
        content.title = "WINK from \(name)"
        content.body = text.isEmpty ? "You got a card." : text
        content.sound = .default
        content.badge = 1
        let request = UNNotificationRequest(
            identifier: "wink.incoming.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        UNUserNotificationCenter.current().setBadgeCount(1)
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
