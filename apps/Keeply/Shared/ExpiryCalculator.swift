import Foundation

/// A notification trigger derived from an item's expiry date: fire
/// `offsetDays` before `date == expiryDate`, at `date`.
struct NotificationTrigger: Equatable {
    let offsetDays: Int
    let date: Date
}

/// Pure, Calendar-injected date math for warranty expiry. Kept free of
/// SwiftData/UIKit so it is trivially unit-testable with plain values.
struct ExpiryCalculator {
    /// Offsets (in days) before expiry at which a notification should fire,
    /// ordered from farthest-out to closest.
    static let notificationOffsetDays = [30, 7]

    let calendar: Calendar

    init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    /// Computes `purchaseDate + warrantyMonths`, clamping to the last valid
    /// day of the target month when the purchase day doesn't exist there
    /// (e.g. Jan 31 + 1 month lands on Feb 28, not a spillover into March).
    ///
    /// This intentionally does its own month arithmetic rather than relying
    /// on `Calendar.date(byAdding:to:)`, whose default matching policy can
    /// roll an overflowing day into the following month instead of clamping
    /// — clamping is the behavior a warranty date should have.
    func expiryDate(purchaseDate: Date, warrantyMonths: Int) -> Date {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: purchaseDate
        )
        guard let year = components.year, let month = components.month, let day = components.day else {
            return purchaseDate
        }

        // warrantyMonths is always >= 0 in this app, so zeroBasedMonth is
        // always >= 0 and plain integer division/modulo is exact here.
        let zeroBasedMonth = max(0, month - 1 + warrantyMonths)
        let targetYear = year + zeroBasedMonth / 12
        let targetMonth = zeroBasedMonth % 12 + 1

        var firstOfTargetMonthComponents = DateComponents()
        firstOfTargetMonthComponents.year = targetYear
        firstOfTargetMonthComponents.month = targetMonth
        firstOfTargetMonthComponents.day = 1

        guard let firstOfTargetMonth = calendar.date(from: firstOfTargetMonthComponents) else {
            return purchaseDate
        }

        let daysInTargetMonth = calendar.range(of: .day, in: .month, for: firstOfTargetMonth)?.count ?? day
        let clampedDay = min(day, daysInTargetMonth)

        var resultComponents = DateComponents()
        resultComponents.year = targetYear
        resultComponents.month = targetMonth
        resultComponents.day = clampedDay
        resultComponents.hour = components.hour
        resultComponents.minute = components.minute
        resultComponents.second = components.second

        return calendar.date(from: resultComponents) ?? purchaseDate
    }

    /// Whole days from `referenceDate` to `expiryDate`. Negative once the
    /// item has already expired.
    func daysUntilExpiry(expiryDate: Date, referenceDate: Date = Date()) -> Int {
        let startOfReference = calendar.startOfDay(for: referenceDate)
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        let components = calendar.dateComponents([.day], from: startOfReference, to: startOfExpiry)
        return components.day ?? 0
    }

    /// Notification trigger dates (30 days and 7 days before `expiryDate`),
    /// skipping any trigger date that already falls at or before
    /// `referenceDate` so past reminders are never scheduled.
    func notificationTriggers(expiryDate: Date, referenceDate: Date = Date()) -> [NotificationTrigger] {
        var triggers: [NotificationTrigger] = []
        for offset in Self.notificationOffsetDays {
            guard let triggerDate = calendar.date(byAdding: .day, value: -offset, to: expiryDate) else {
                continue
            }
            if triggerDate > referenceDate {
                triggers.append(NotificationTrigger(offsetDays: offset, date: triggerDate))
            }
        }
        return triggers
    }
}
