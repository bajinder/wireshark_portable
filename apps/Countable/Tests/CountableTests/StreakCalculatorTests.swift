import XCTest

// NOTE: `StreakCalculator` lives in Shared/, which project.yml compiles directly into
// this test target's sources (alongside Tests/CountableTests). There is no separate
// app module to `@testable import` — the type is simply available in this module.
final class StreakCalculatorTests: XCTestCase {

    /// A fixed, deterministic UTC calendar so tests never depend on the machine's
    /// local timezone or locale.
    private func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 9 // arbitrary mid-day time; startOfDay normalizes this away
        return try XCTUnwrap(calendar.date(from: components))
    }

    func testEmptyLogsReturnsZero() throws {
        let calendar = try utcCalendar()
        let today = try date(2026, 3, 15, calendar: calendar)

        let streak = StreakCalculator.currentStreak(completedDates: [], calendar: calendar, today: today)

        XCTAssertEqual(streak, 0)
    }

    func testTodayOnlyReturnsOne() throws {
        let calendar = try utcCalendar()
        let today = try date(2026, 3, 15, calendar: calendar)

        let streak = StreakCalculator.currentStreak(completedDates: [today], calendar: calendar, today: today)

        XCTAssertEqual(streak, 1)
    }

    func testGapBreaksStreak() throws {
        // Logged two days ago only — neither today nor yesterday — streak is broken.
        let calendar = try utcCalendar()
        let today = try date(2026, 3, 15, calendar: calendar)
        let twoDaysAgo = try date(2026, 3, 13, calendar: calendar)

        let streak = StreakCalculator.currentStreak(completedDates: [twoDaysAgo], calendar: calendar, today: today)

        XCTAssertEqual(streak, 0)
    }

    func testMultiDayConsecutiveStreakEndingToday() throws {
        let calendar = try utcCalendar()
        let today = try date(2026, 3, 15, calendar: calendar)
        let dates = try [
            date(2026, 3, 11, calendar: calendar),
            date(2026, 3, 12, calendar: calendar),
            date(2026, 3, 13, calendar: calendar),
            date(2026, 3, 14, calendar: calendar),
            date(2026, 3, 15, calendar: calendar)
        ]

        let streak = StreakCalculator.currentStreak(completedDates: dates, calendar: calendar, today: today)

        XCTAssertEqual(streak, 5)
    }

    func testYesterdayGraceKeepsStreakAliveBeforeTodaysLog() throws {
        // Today has not been logged yet, but a 3-day streak ended yesterday — the
        // streak should still read as 3 (grace period), not 0.
        let calendar = try utcCalendar()
        let today = try date(2026, 3, 15, calendar: calendar)
        let dates = try [
            date(2026, 3, 12, calendar: calendar),
            date(2026, 3, 13, calendar: calendar),
            date(2026, 3, 14, calendar: calendar)
        ]

        let streak = StreakCalculator.currentStreak(completedDates: dates, calendar: calendar, today: today)

        XCTAssertEqual(streak, 3)
    }

    func testDuplicateLogsSameDayDoNotInflateStreak() throws {
        let calendar = try utcCalendar()
        let today = try date(2026, 3, 15, calendar: calendar)
        let todayMorning = today
        let todayEvening = try XCTUnwrap(calendar.date(byAdding: .hour, value: 6, to: today))
        let yesterday = try date(2026, 3, 14, calendar: calendar)

        let streak = StreakCalculator.currentStreak(
            completedDates: [todayMorning, todayEvening, yesterday, yesterday],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(streak, 2)
    }

    func testNonConsecutiveDatesOnlyCountTrailingRun() throws {
        // today, yesterday logged (consecutive), then a gap, then a much older date.
        // Only the trailing consecutive run should count.
        let calendar = try utcCalendar()
        let today = try date(2026, 3, 15, calendar: calendar)
        let dates = try [
            date(2026, 3, 1, calendar: calendar),
            date(2026, 3, 14, calendar: calendar),
            date(2026, 3, 15, calendar: calendar)
        ]

        let streak = StreakCalculator.currentStreak(completedDates: dates, calendar: calendar, today: today)

        XCTAssertEqual(streak, 2)
    }

    func testStreakAcrossDaylightSavingSpringForwardBoundary() throws {
        // US Eastern DST spring-forward in 2026 is Sunday, March 8. Use a real
        // (non-UTC) fixed timezone calendar so the day-boundary math is exercised
        // across the one 23-hour day of the year.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))

        let today = try date(2026, 3, 9, calendar: calendar) // day after the DST jump
        let dates = try [
            date(2026, 3, 7, calendar: calendar), // before DST jump
            date(2026, 3, 8, calendar: calendar), // the 23-hour DST day itself
            date(2026, 3, 9, calendar: calendar)  // after DST jump
        ]

        let streak = StreakCalculator.currentStreak(completedDates: dates, calendar: calendar, today: today)

        XCTAssertEqual(streak, 3, "Day-based streak math must be unaffected by the DST transition")
    }
}
