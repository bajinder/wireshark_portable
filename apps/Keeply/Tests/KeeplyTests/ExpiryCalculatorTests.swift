@testable import Keeply
import XCTest

final class ExpiryCalculatorTests: XCTestCase {
    // Both the calculator and the date-building helper below are pinned to
    // UTC so these tests are deterministic regardless of the host machine's
    // system time zone.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private let calculator = ExpiryCalculator(calendar: ExpiryCalculatorTests.utcCalendar)
    private let calendar = ExpiryCalculatorTests.utcCalendar

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let value = calendar.date(from: components) else {
            XCTFail("Failed to build date")
            return Date()
        }
        return value
    }

    // MARK: - Month-end edge cases

    func testJan31PlusOneMonthClampsToFeb28InNonLeapYear() {
        let purchase = date(year: 2026, month: 1, day: 31)
        let expiry = calculator.expiryDate(purchaseDate: purchase, warrantyMonths: 1)

        let components = calendar.dateComponents([.year, .month, .day], from: expiry)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 28)
    }

    func testJan31PlusOneMonthClampsToFeb29InLeapYear() {
        let purchase = date(year: 2024, month: 1, day: 31)
        let expiry = calculator.expiryDate(purchaseDate: purchase, warrantyMonths: 1)

        let components = calendar.dateComponents([.year, .month, .day], from: expiry)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 29)
    }

    func testMonthEndClampingCarriesOverYearBoundary() {
        // Dec 31 + 2 months should clamp against February, and roll the year.
        let purchase = date(year: 2025, month: 12, day: 31)
        let expiry = calculator.expiryDate(purchaseDate: purchase, warrantyMonths: 2)

        let components = calendar.dateComponents([.year, .month, .day], from: expiry)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 28)
    }

    // MARK: - Standard month arithmetic (no clamping needed)

    func testOneYearWarrantyAddsTwelveMonths() {
        let purchase = date(year: 2026, month: 3, day: 14)
        let expiry = calculator.expiryDate(purchaseDate: purchase, warrantyMonths: 12)

        let components = calendar.dateComponents([.year, .month, .day], from: expiry)
        XCTAssertEqual(components.year, 2027)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
    }

    func testCustomMonthsWarranty() {
        let purchase = date(year: 2026, month: 1, day: 15)
        let expiry = calculator.expiryDate(purchaseDate: purchase, warrantyMonths: 5)

        let components = calendar.dateComponents([.year, .month, .day], from: expiry)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }

    func testZeroMonthWarrantyReturnsSameDate() {
        let purchase = date(year: 2026, month: 5, day: 1)
        let expiry = calculator.expiryDate(purchaseDate: purchase, warrantyMonths: 0)

        XCTAssertEqual(calendar.isDate(expiry, inSameDayAs: purchase), true)
    }

    // MARK: - Days until expiry

    func testDaysUntilExpiryIsPositiveForFutureDate() {
        let reference = date(year: 2026, month: 1, day: 1)
        let expiry = date(year: 2026, month: 1, day: 11)

        XCTAssertEqual(calculator.daysUntilExpiry(expiryDate: expiry, referenceDate: reference), 10)
    }

    func testDaysUntilExpiryIsNegativeForPastDate() {
        let reference = date(year: 2026, month: 2, day: 1)
        let expiry = date(year: 2026, month: 1, day: 22)

        XCTAssertEqual(calculator.daysUntilExpiry(expiryDate: expiry, referenceDate: reference), -10)
    }

    func testDaysUntilExpiryIsZeroOnExpiryDay() {
        let reference = date(year: 2026, month: 6, day: 1)
        XCTAssertEqual(calculator.daysUntilExpiry(expiryDate: reference, referenceDate: reference), 0)
    }

    // MARK: - Notification trigger dates & skip-past logic

    func testTriggersIncludeBothOffsetsWhenExpiryIsFarInFuture() {
        let reference = date(year: 2026, month: 1, day: 1)
        let expiry = date(year: 2026, month: 3, day: 1) // 59 days out

        let triggers = calculator.notificationTriggers(expiryDate: expiry, referenceDate: reference)

        XCTAssertEqual(triggers.count, 2)
        XCTAssertEqual(triggers.map(\.offsetDays).sorted(), [7, 30])
        XCTAssertTrue(triggers.allSatisfy { $0.date > reference })
    }

    func testThirtyDayTriggerIsSkippedWhenAlreadyPast() {
        let reference = date(year: 2026, month: 1, day: 1)
        let expiry = date(year: 2026, month: 1, day: 11) // 10 days out: only the 7-day trigger is future

        let triggers = calculator.notificationTriggers(expiryDate: expiry, referenceDate: reference)

        XCTAssertEqual(triggers.count, 1)
        XCTAssertEqual(triggers.first?.offsetDays, 7)
    }

    func testBothTriggersAreSkippedWhenExpiryIsImminent() {
        let reference = date(year: 2026, month: 1, day: 1)
        let expiry = date(year: 2026, month: 1, day: 3) // 2 days out: both triggers already past

        let triggers = calculator.notificationTriggers(expiryDate: expiry, referenceDate: reference)

        XCTAssertTrue(triggers.isEmpty)
    }

    func testBothTriggersAreSkippedWhenAlreadyExpired() {
        let reference = date(year: 2026, month: 6, day: 1)
        let expiry = date(year: 2026, month: 1, day: 1)

        let triggers = calculator.notificationTriggers(expiryDate: expiry, referenceDate: reference)

        XCTAssertTrue(triggers.isEmpty)
    }
}
