import Foundation
import UserNotifications

/// The slice of `UNUserNotificationCenter` that `NotificationScheduler`
/// needs, expressed as a protocol so unit tests can substitute a spy
/// instead of touching the real notification center. `UNUserNotificationCenter`
/// already implements every one of these methods, so the extension below
/// is the only glue required.
protocol UserNotificationCenterProtocol: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void)
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenterProtocol {}

protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
    func scheduleExpiryNotifications(itemID: UUID, itemName: String, triggers: [NotificationTrigger]) async
    func cancelNotifications(itemID: UUID)
}

/// Schedules and cancels the two warranty-expiry local notifications
/// (30 days and 7 days before expiry) for a given item.
final class NotificationScheduler: NotificationScheduling {
    private let center: UserNotificationCenterProtocol

    init(center: UserNotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Requests notification permission. Safe to call on every item save —
    /// the system only prompts the user once; subsequent calls simply
    /// report the previously-granted (or denied) status, which is what
    /// gives us "ask on first item add" for free.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Cancels any existing notifications for the item, then schedules a
    /// fresh notification for each trigger that is still in the future.
    /// `triggers` is expected to already have past dates filtered out (see
    /// `ExpiryCalculator.notificationTriggers`), but this is defensive
    /// about re-checking regardless.
    func scheduleExpiryNotifications(itemID: UUID, itemName: String, triggers: [NotificationTrigger]) async {
        cancelNotifications(itemID: itemID)

        let calendar = Calendar(identifier: .gregorian)
        for trigger in triggers {
            guard trigger.date > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Warranty Expiring Soon"
            let dayWord = trigger.offsetDays == 1 ? "day" : "days"
            content.body = "\(itemName)'s warranty expires in \(trigger.offsetDays) \(dayWord)."
            content.sound = .default

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: trigger.date)
            dateComponents.hour = 9
            dateComponents.minute = 0

            let calendarTrigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let identifier = Self.identifier(itemID: itemID, offsetDays: trigger.offsetDays)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: calendarTrigger)

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                center.add(request) { _ in
                    continuation.resume()
                }
            }
        }
    }

    /// Removes both possible pending notifications for an item. Safe to
    /// call even if fewer than two (or none) were ever scheduled.
    func cancelNotifications(itemID: UUID) {
        let identifiers = ExpiryCalculator.notificationOffsetDays.map {
            Self.identifier(itemID: itemID, offsetDays: $0)
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func identifier(itemID: UUID, offsetDays: Int) -> String {
        "com.bajinder.keeply.notification.\(itemID.uuidString).\(offsetDays)"
    }
}
