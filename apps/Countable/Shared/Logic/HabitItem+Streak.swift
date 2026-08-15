import Foundation

/// Thin, SwiftData-aware convenience wrapper around `StreakCalculator` / `HabitItem`.
/// The actual streak math lives in `StreakCalculator`, which stays pure and testable
/// without touching SwiftData at all.
extension HabitItem {
    func currentStreak(calendar: Calendar = .current, referenceDate: Date = .now) -> Int {
        StreakCalculator.currentStreak(
            completedDates: completedDayStarts,
            calendar: calendar,
            today: referenceDate
        )
    }

    func isCompletedToday(calendar: Calendar = .current, referenceDate: Date = .now) -> Bool {
        let todayStart = calendar.startOfDay(for: referenceDate)
        return completedDayStarts.contains { calendar.isDate($0, inSameDayAs: todayStart) }
    }

    /// Logs today as complete. Safe to call more than once per day — duplicate entries
    /// for the same calendar day are not added.
    func logToday(calendar: Calendar = .current, referenceDate: Date = .now) {
        let todayStart = calendar.startOfDay(for: referenceDate)
        guard !isCompletedToday(calendar: calendar, referenceDate: referenceDate) else { return }
        completedDayStarts.append(todayStart)
    }
}
