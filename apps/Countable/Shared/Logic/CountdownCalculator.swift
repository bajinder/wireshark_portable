import Foundation

/// Pure, fully unit-testable countdown math with no SwiftData dependency.
///
/// Days remaining is computed as the whole-day difference between the start of `today`
/// and the start of `targetDate`, using `Calendar.startOfDay` + `dateComponents`, which
/// is timezone- and DST-safe (it never measures raw 24-hour intervals, which would be
/// wrong across a DST transition).
enum CountdownCalculator {
    /// - Returns: The number of whole calendar days from today until `targetDate`.
    ///   `0` if the target is today, negative if the target date has already passed.
    static func daysRemaining(
        until targetDate: Date,
        calendar: Calendar = .current,
        today: Date = .now
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let targetStart = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: todayStart, to: targetStart)
        return components.day ?? 0
    }

    static func isToday(_ targetDate: Date, calendar: Calendar = .current, today: Date = .now) -> Bool {
        calendar.isDate(targetDate, inSameDayAs: today)
    }

    static func isPast(_ targetDate: Date, calendar: Calendar = .current, today: Date = .now) -> Bool {
        daysRemaining(until: targetDate, calendar: calendar, today: today) < 0
    }
}
