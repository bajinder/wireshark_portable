import Foundation

/// Pure, fully unit-testable streak math with no SwiftData dependency.
///
/// Streak definition: the current streak is the number of *consecutive* calendar days,
/// counting backward, that were logged — anchored at today if today was logged, or at
/// yesterday if today was not logged yet but yesterday was (a one-day "grace" period so
/// the streak doesn't visually reset to zero the instant midnight passes, before the
/// user has had a chance to log today). If neither today nor yesterday was logged, the
/// streak is broken and the result is 0.
enum StreakCalculator {
    /// - Parameters:
    ///   - completedDates: Dates the habit was logged as complete. Any time-of-day
    ///     component is ignored (dates are normalized to start-of-day); duplicate
    ///     entries for the same day are safe and do not inflate the streak.
    ///   - calendar: The calendar to use for day boundaries. Inject a fixed-timezone
    ///     calendar in tests for determinism.
    ///   - today: The reference "now". Defaults to the current date/time.
    /// - Returns: The current streak length in days (0 if broken or empty).
    static func currentStreak(
        completedDates: [Date],
        calendar: Calendar = .current,
        today: Date = .now
    ) -> Int {
        guard !completedDates.isEmpty else { return 0 }

        let loggedDays = Set(completedDates.map { calendar.startOfDay(for: $0) })
        let todayStart = calendar.startOfDay(for: today)

        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return 0
        }

        let anchor: Date
        if loggedDays.contains(todayStart) {
            anchor = todayStart
        } else if loggedDays.contains(yesterdayStart) {
            anchor = yesterdayStart
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while loggedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }
}
