//
//  StatsCalculatorTests.swift
//  CatchbookTests
//

import XCTest
@testable import Catchbook

final class StatsCalculatorTests: XCTestCase {

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        guard let date = utcCalendar().date(from: components) else {
            return .now
        }
        return date
    }

    // MARK: - Empty input

    func testEmptyCatchesProduceZeroedStats() {
        let stats = StatsCalculator.stats(for: [], calendar: utcCalendar(), now: makeDate(2026, 1, 15))

        XCTAssertEqual(stats.totalCatches, 0)
        XCTAssertTrue(stats.biggestBySpecies.isEmpty)
        XCTAssertEqual(stats.monthlyCounts.count, 12)
        XCTAssertTrue(stats.monthlyCounts.allSatisfy { $0.count == 0 })
    }

    // MARK: - Biggest by species: ties

    func testBiggestBySpeciesTieKeepsFirstEncounteredCatch() {
        let first = Catch(species: "Bass", length: 40, weight: 2.0, date: makeDate(2026, 1, 1))
        let second = Catch(species: "Bass", length: 55, weight: 2.0, date: makeDate(2026, 1, 2))

        let result = StatsCalculator.biggestBySpecies([first, second])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.weight, 2.0)
        XCTAssertEqual(result.first?.length, 40, "On a weight tie, the first-encountered catch is kept.")
    }

    func testBiggestBySpeciesStrictlyGreaterWeightWins() {
        let lighter = Catch(species: "Pike", weight: 3.0, date: makeDate(2026, 1, 1))
        let heavier = Catch(species: "Pike", weight: 5.5, date: makeDate(2026, 1, 2))

        let result = StatsCalculator.biggestBySpecies([lighter, heavier])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.weight, 5.5)
    }

    // MARK: - Biggest by species: nil weight fallback

    func testBiggestBySpeciesNilWeightFallsBackToLength() {
        let shorter = Catch(species: "Trout", length: 50, weight: nil, date: makeDate(2026, 1, 1))
        let longer = Catch(species: "Trout", length: 65, weight: nil, date: makeDate(2026, 1, 2))

        let result = StatsCalculator.biggestBySpecies([shorter, longer])

        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result.first?.weight)
        XCTAssertEqual(result.first?.length, 65)
    }

    func testBiggestBySpeciesHandlesCompletelyUnmeasuredCatch() {
        let unmeasured = Catch(species: "Carp", length: nil, weight: nil, date: makeDate(2026, 1, 1))

        let result = StatsCalculator.biggestBySpecies([unmeasured])

        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result.first?.weight)
        XCTAssertNil(result.first?.length)
    }

    func testBiggestBySpeciesAcrossMultipleSpeciesIsSortedAlphabetically() {
        let bass = Catch(species: "Bass", length: 30, weight: 1.2, date: makeDate(2026, 1, 1))
        let trout = Catch(species: "Trout", length: 40, weight: nil, date: makeDate(2026, 1, 1))

        let result = StatsCalculator.biggestBySpecies([trout, bass])

        XCTAssertEqual(result.map(\.species), ["Bass", "Trout"])
    }

    // MARK: - Monthly bucketing

    func testMonthlyCountsBucketsAcrossYearBoundary() {
        let now = makeDate(2026, 1, 15)
        let decemberCatch = Catch(species: "Bass", date: makeDate(2025, 12, 20))
        let januaryCatchOne = Catch(species: "Bass", date: makeDate(2026, 1, 5))
        let januaryCatchTwo = Catch(species: "Bass", date: makeDate(2026, 1, 10))

        let counts = StatsCalculator.monthlyCounts(
            [decemberCatch, januaryCatchOne, januaryCatchTwo],
            calendar: utcCalendar(),
            now: now
        )

        XCTAssertEqual(counts.count, 12)
        XCTAssertEqual(counts.last?.count, 2, "The current month (January 2026) should be the last bucket.")
        XCTAssertEqual(counts[counts.count - 2].count, 1, "December 2025 should be the second-to-last bucket.")
    }

    func testMonthlyCountsIgnoresCatchesOutsideTheTwelveMonthWindow() {
        let now = makeDate(2026, 6, 1)
        let oldCatch = Catch(species: "Bass", date: makeDate(2024, 1, 1))

        let counts = StatsCalculator.monthlyCounts([oldCatch], calendar: utcCalendar(), now: now)

        XCTAssertTrue(counts.allSatisfy { $0.count == 0 })
    }

    func testMonthlyCountsBucketStartDatesAreChronological() {
        let now = makeDate(2026, 3, 1)
        let counts = StatsCalculator.monthlyCounts([], calendar: utcCalendar(), now: now)

        for index in 1..<counts.count {
            XCTAssertLessThan(counts[index - 1].monthStart, counts[index].monthStart)
        }
    }
}
