// HistoryAggregatorTests.swift
// DeepworkTests

import XCTest
@testable import Deepwork

final class HistoryAggregatorTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(identifier: "UTC") else {
            XCTFail("UTC timezone should always be available")
            return calendar
        }
        calendar.timeZone = utc
        return calendar
    }

    func testEmptyRecordsProduceDayCountZeroDays() {
        let calendar = utcCalendar()
        let aggregator = HistoryAggregator(calendar: calendar)
        guard let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12)) else {
            return XCTFail("Could not build reference date")
        }

        let days = aggregator.dailyFocusMinutes(records: [], referenceDate: reference, dayCount: 7)

        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.allSatisfy { $0.minutes == 0 })
    }

    func testZeroDayCountReturnsEmptyArray() {
        let aggregator = HistoryAggregator(calendar: utcCalendar())

        let days = aggregator.dailyFocusMinutes(records: [], referenceDate: Date(), dayCount: 0)

        XCTAssertTrue(days.isEmpty)
    }

    func testMultipleSessionsSameDaySumIntoOneBucket() {
        let calendar = utcCalendar()
        let aggregator = HistoryAggregator(calendar: calendar)
        guard
            let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 20)),
            let morning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 9)),
            let afternoon = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 15))
        else {
            return XCTFail("Could not build test dates")
        }

        let records = [
            FocusRecord(start: morning, minutes: 25),
            FocusRecord(start: afternoon, minutes: 50),
        ]

        let days = aggregator.dailyFocusMinutes(records: records, referenceDate: reference, dayCount: 7)

        guard let today = days.last else {
            return XCTFail("Expected at least one day in the result")
        }
        XCTAssertEqual(today.minutes, 75)
    }

    func testSevenDayWindowExcludesRecordsJustOutsideTheWindow() {
        let calendar = utcCalendar()
        let aggregator = HistoryAggregator(calendar: calendar)
        guard let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12)) else {
            return XCTFail("Could not build reference date")
        }
        let startOfReferenceDay = calendar.startOfDay(for: reference)
        guard
            let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfReferenceDay),
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfReferenceDay)
        else {
            return XCTFail("Could not build window-edge dates")
        }

        let records = [
            FocusRecord(start: sixDaysAgo.addingTimeInterval(3600), minutes: 30), // oldest day INSIDE the window
            FocusRecord(start: sevenDaysAgo.addingTimeInterval(3600), minutes: 999), // one day OUTSIDE the window
        ]

        let days = aggregator.dailyFocusMinutes(records: records, referenceDate: reference, dayCount: 7)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first?.day, sixDaysAgo)
        XCTAssertEqual(days.first?.minutes, 30)
        XCTAssertEqual(days.reduce(0) { $0 + $1.minutes }, 30, "the 999-minute record outside the window must not leak in")
    }

    func testTimezoneBoundarySessionBucketsIntoTheInjectedCalendarsLocalDay() {
        var laCalendar = Calendar(identifier: .gregorian)
        guard let laTimeZone = TimeZone(identifier: "America/Los_Angeles") else {
            return XCTFail("America/Los_Angeles timezone should always be available")
        }
        laCalendar.timeZone = laTimeZone
        let aggregator = HistoryAggregator(calendar: laCalendar)

        // 11pm on Aug 14 in Los Angeles is already Aug 15 in UTC. Bucketing
        // must follow the injected LA calendar, not UTC and not whatever
        // timezone the test happens to execute in.
        var lateNightComponents = DateComponents()
        lateNightComponents.year = 2026
        lateNightComponents.month = 8
        lateNightComponents.day = 14
        lateNightComponents.hour = 23
        lateNightComponents.timeZone = laTimeZone
        guard let lateNightLA = laCalendar.date(from: lateNightComponents) else {
            return XCTFail("Could not build the late-night LA test date")
        }
        guard let reference = laCalendar.date(byAdding: .hour, value: 2, to: lateNightLA) else {
            return XCTFail("Could not build the reference date")
        }

        let records = [FocusRecord(start: lateNightLA, minutes: 25)]
        let days = aggregator.dailyFocusMinutes(records: records, referenceDate: reference, dayCount: 7)

        guard days.count >= 2 else {
            return XCTFail("Expected at least 2 days in the result")
        }
        let secondToLastDay = days[days.count - 2] // Aug 14, LA-local
        let lastDay = days[days.count - 1] // Aug 15, LA-local (the reference day)

        XCTAssertEqual(secondToLastDay.minutes, 25, "the 11pm-LA session should land on the Aug 14 LA-local bucket")
        XCTAssertEqual(lastDay.minutes, 0)
    }

    func testTotalFocusMinutesSumsAllRecordsRegardlessOfDay() {
        let aggregator = HistoryAggregator(calendar: utcCalendar())
        let records = [
            FocusRecord(start: Date(timeIntervalSince1970: 0), minutes: 25),
            FocusRecord(start: Date(timeIntervalSince1970: 100_000), minutes: 40.5),
        ]

        XCTAssertEqual(aggregator.totalFocusMinutes(records: records), 65.5)
    }

    func testTotalFocusMinutesIsZeroForEmptyRecords() {
        let aggregator = HistoryAggregator(calendar: utcCalendar())

        XCTAssertEqual(aggregator.totalFocusMinutes(records: []), 0)
    }
}
