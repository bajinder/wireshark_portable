import XCTest

// NOTE: `CountdownCalculator` lives in Shared/, which project.yml compiles directly
// into this test target's sources. No `@testable import` is needed — see
// StreakCalculatorTests.swift for the same note.
final class CountdownCalculatorTests: XCTestCase {

    private func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, calendar: Calendar) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return try XCTUnwrap(calendar.date(from: components))
    }

    func testTargetDateTodayIsZeroDaysRemaining() throws {
        let calendar = try utcCalendar()
        let today = try date(2026, 6, 1, hour: 9, calendar: calendar)
        let targetLaterSameDay = try date(2026, 6, 1, hour: 23, calendar: calendar)

        let daysRemaining = CountdownCalculator.daysRemaining(until: targetLaterSameDay, calendar: calendar, today: today)

        XCTAssertEqual(daysRemaining, 0)
        XCTAssertTrue(CountdownCalculator.isToday(targetLaterSameDay, calendar: calendar, today: today))
        XCTAssertFalse(CountdownCalculator.isPast(targetLaterSameDay, calendar: calendar, today: today))
    }

    func testPastTargetDateIsNegative() throws {
        let calendar = try utcCalendar()
        let today = try date(2026, 6, 10, calendar: calendar)
        let pastTarget = try date(2026, 6, 1, calendar: calendar)

        let daysRemaining = CountdownCalculator.daysRemaining(until: pastTarget, calendar: calendar, today: today)

        XCTAssertEqual(daysRemaining, -9)
        XCTAssertTrue(CountdownCalculator.isPast(pastTarget, calendar: calendar, today: today))
    }

    func testFarFutureTargetDate() throws {
        let calendar = try utcCalendar()
        let today = try date(2026, 1, 1, calendar: calendar)
        let farFuture = try date(2027, 1, 5, calendar: calendar) // 370 days: 2026 has 365 days, plus 4 more into Jan 2027 -> day 1 to day 5

        let daysRemaining = CountdownCalculator.daysRemaining(until: farFuture, calendar: calendar, today: today)

        // 2026 is not a leap year, so Jan 1 2026 -> Jan 1 2027 is 365 days, plus 4 more
        // days to reach Jan 5 2027.
        XCTAssertEqual(daysRemaining, 369)
    }

    func testLeapDayIsCountedCorrectly() throws {
        // 2024 is a leap year: Feb 28 -> Feb 29 is 1 day, and Feb 29 -> Mar 1 is 1 day.
        let calendar = try utcCalendar()
        let today = try date(2024, 2, 28, calendar: calendar)
        let leapDay = try date(2024, 2, 29, calendar: calendar)
        let dayAfterLeapDay = try date(2024, 3, 1, calendar: calendar)

        XCTAssertEqual(CountdownCalculator.daysRemaining(until: leapDay, calendar: calendar, today: today), 1)
        XCTAssertEqual(CountdownCalculator.daysRemaining(until: dayAfterLeapDay, calendar: calendar, today: leapDay), 1)
    }

    func testSpanAcrossLeapDayFromPriorYear() throws {
        // Dec 31 2023 -> Mar 1 2024, inclusive of the Feb 29 2024 leap day:
        // 31 (rest of Jan) + 29 (all of Feb, leap) + 1 (Mar 1) = 61 days.
        let calendar = try utcCalendar()
        let today = try date(2023, 12, 31, calendar: calendar)
        let target = try date(2024, 3, 1, calendar: calendar)

        let daysRemaining = CountdownCalculator.daysRemaining(until: target, calendar: calendar, today: today)

        XCTAssertEqual(daysRemaining, 61)
    }
}
