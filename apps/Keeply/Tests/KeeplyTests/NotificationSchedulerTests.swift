@testable import Keeply
import UserNotifications
import XCTest

/// Spy standing in for `UNUserNotificationCenter` so these tests never
/// touch the real system notification center.
final class SpyNotificationCenter: UserNotificationCenterProtocol {
    var authorizationGranted = true

    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifierBatches: [[String]] = []

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        completionHandler(authorizationGranted, nil)
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
    }
}

final class NotificationSchedulerTests: XCTestCase {
    func testRequestAuthorizationReturnsGrantedValue() async {
        let spy = SpyNotificationCenter()
        spy.authorizationGranted = true
        let scheduler = NotificationScheduler(center: spy)

        let granted = await scheduler.requestAuthorization()

        XCTAssertTrue(granted)
    }

    func testRequestAuthorizationReturnsDeniedValue() async {
        let spy = SpyNotificationCenter()
        spy.authorizationGranted = false
        let scheduler = NotificationScheduler(center: spy)

        let granted = await scheduler.requestAuthorization()

        XCTAssertFalse(granted)
    }

    func testScheduleAddsARequestPerFutureTrigger() async {
        let spy = SpyNotificationCenter()
        let scheduler = NotificationScheduler(center: spy)
        let itemID = UUID()
        let triggers = [
            NotificationTrigger(offsetDays: 30, date: Date().addingTimeInterval(60 * 60 * 24 * 10)),
            NotificationTrigger(offsetDays: 7, date: Date().addingTimeInterval(60 * 60 * 24 * 33))
        ]

        await scheduler.scheduleExpiryNotifications(itemID: itemID, itemName: "Blender", triggers: triggers)

        XCTAssertEqual(spy.addedRequests.count, 2)
        let identifiers = Set(spy.addedRequests.map(\.identifier))
        XCTAssertTrue(identifiers.contains(NotificationScheduler.identifier(itemID: itemID, offsetDays: 30)))
        XCTAssertTrue(identifiers.contains(NotificationScheduler.identifier(itemID: itemID, offsetDays: 7)))
    }

    func testScheduleSkipsTriggersThatAreAlreadyInThePast() async {
        let spy = SpyNotificationCenter()
        let scheduler = NotificationScheduler(center: spy)
        let itemID = UUID()
        let triggers = [
            NotificationTrigger(offsetDays: 7, date: Date().addingTimeInterval(-60 * 60 * 24))
        ]

        await scheduler.scheduleExpiryNotifications(itemID: itemID, itemName: "Blender", triggers: triggers)

        XCTAssertTrue(spy.addedRequests.isEmpty)
    }

    func testScheduleCancelsExistingNotificationsFirst() async {
        let spy = SpyNotificationCenter()
        let scheduler = NotificationScheduler(center: spy)
        let itemID = UUID()
        let triggers = [
            NotificationTrigger(offsetDays: 7, date: Date().addingTimeInterval(60 * 60 * 24 * 5))
        ]

        await scheduler.scheduleExpiryNotifications(itemID: itemID, itemName: "Blender", triggers: triggers)

        XCTAssertEqual(spy.removedIdentifierBatches.count, 1)
        let removed = Set(spy.removedIdentifierBatches[0])
        XCTAssertTrue(removed.contains(NotificationScheduler.identifier(itemID: itemID, offsetDays: 30)))
        XCTAssertTrue(removed.contains(NotificationScheduler.identifier(itemID: itemID, offsetDays: 7)))
    }

    func testCancelRemovesBothPossibleIdentifiers() {
        let spy = SpyNotificationCenter()
        let scheduler = NotificationScheduler(center: spy)
        let itemID = UUID()

        scheduler.cancelNotifications(itemID: itemID)

        XCTAssertEqual(spy.removedIdentifierBatches.count, 1)
        let removed = Set(spy.removedIdentifierBatches[0])
        XCTAssertEqual(removed, Set([
            NotificationScheduler.identifier(itemID: itemID, offsetDays: 30),
            NotificationScheduler.identifier(itemID: itemID, offsetDays: 7)
        ]))
    }

    func testRescheduleReplacesPreviousRequestsForTheSameItem() async {
        let spy = SpyNotificationCenter()
        let scheduler = NotificationScheduler(center: spy)
        let itemID = UUID()

        let firstTriggers = [NotificationTrigger(offsetDays: 30, date: Date().addingTimeInterval(60 * 60 * 24 * 40))]
        await scheduler.scheduleExpiryNotifications(itemID: itemID, itemName: "Blender", triggers: firstTriggers)

        let secondTriggers = [NotificationTrigger(offsetDays: 7, date: Date().addingTimeInterval(60 * 60 * 24 * 5))]
        await scheduler.scheduleExpiryNotifications(itemID: itemID, itemName: "Blender", triggers: secondTriggers)

        // Two schedule calls => two cancel passes, one per call.
        XCTAssertEqual(spy.removedIdentifierBatches.count, 2)
        XCTAssertEqual(spy.addedRequests.count, 2)
    }
}
