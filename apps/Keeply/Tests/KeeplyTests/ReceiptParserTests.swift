@testable import Keeply
import XCTest

final class ReceiptParserTests: XCTestCase {
    private let parser = ReceiptParser()
    private let calendar = Calendar(identifier: .gregorian)

    private func referenceDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to build reference date")
            return Date()
        }
        return date
    }

    // MARK: - US format

    func testUSDateAndTotalAreExtracted() {
        let lines = [
            "GADGET WORLD ELECTRONICS",
            "Date: 03/14/2026",
            "Wireless Blender       49.99",
            "SUBTOTAL               59.98",
            "TAX                     4.80",
            "TOTAL                  64.78"
        ]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 4, day: 1))

        XCTAssertEqual(result.purchaseDate, referenceDate(year: 2026, month: 3, day: 14))
        XCTAssertEqual(result.totalAmount, Decimal(string: "64.78"))
    }

    // MARK: - European format

    func testEuropeanDayFirstDateFallsBackWhenMonthIsInvalidAsUSFormat() {
        // 31/01/2026 cannot be MM/dd (no 31st month), so the parser should
        // fall back to dd/MM and read this as 31 January 2026.
        let lines = ["Purchase Date: 31/01/2026", "TOTAL 20.00"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 2, day: 1))

        XCTAssertEqual(result.purchaseDate, referenceDate(year: 2026, month: 1, day: 31))
    }

    // MARK: - ISO format

    func testISODateFormatIsRecognized() {
        let lines = ["Purchase Date: 2026-02-10", "GRAND TOTAL 181.44"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(result.purchaseDate, referenceDate(year: 2026, month: 2, day: 10))
        XCTAssertEqual(result.totalAmount, Decimal(string: "181.44"))
    }

    // MARK: - Month-name format

    func testMonthNameDateIsRecognized() {
        let lines = ["Receipt dated Jan 5, 2026", "TOTAL 12.50"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 2, day: 1))

        XCTAssertEqual(result.purchaseDate, referenceDate(year: 2026, month: 1, day: 5))
    }

    func testFullMonthNameDateIsRecognized() {
        let lines = ["Receipt dated January 5, 2026", "TOTAL 12.50"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 2, day: 1))

        XCTAssertEqual(result.purchaseDate, referenceDate(year: 2026, month: 1, day: 5))
    }

    // MARK: - Ambiguous date

    func testAmbiguousNumericDatePrefersUSInterpretation() {
        // 01/02/2026 is valid as both MM/dd (Jan 2) and dd/MM (Feb 1); the
        // parser should prefer the US (MM/dd) reading.
        let lines = ["Date: 01/02/2026"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(result.purchaseDate, referenceDate(year: 2026, month: 1, day: 2))
    }

    // MARK: - No date present

    func testNoDatePresentReturnsNilPurchaseDate() {
        let lines = ["STORE RECEIPT", "Item A 10.00", "TOTAL 10.00"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertNil(result.purchaseDate)
        XCTAssertEqual(result.totalAmount, Decimal(string: "10.00"))
    }

    func testEmptyLinesReturnNilForBothFields() {
        let result = parser.parse(lines: [], referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertNil(result.purchaseDate)
        XCTAssertNil(result.totalAmount)
    }

    // MARK: - Future date is rejected

    func testFutureDateIsIgnored() {
        let lines = ["Date: 03/14/2027", "TOTAL 5.00"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertNil(result.purchaseDate)
    }

    // MARK: - Multiple amounts

    func testMultipleAmountsPrefersLineNearTotalKeywordOverSubtotal() {
        let lines = [
            "Item A               10.00",
            "Item B               25.00",
            "SUBTOTAL              35.00",
            "TAX                    2.80",
            "TOTAL                 37.80"
        ]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(result.totalAmount, Decimal(string: "37.80"))
    }

    func testGrandTotalKeywordTakesPriorityOverPlainTotalSubstring() {
        let lines = [
            "Item A               10.00",
            "SUBTOTAL              10.00",
            "GRAND TOTAL           10.80"
        ]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(result.totalAmount, Decimal(string: "10.80"))
    }

    func testFallsBackToLargestAmountWhenNoKeywordPresent() {
        let lines = ["Item A  5.00", "Item B  99.99", "Item C  12.00"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(result.totalAmount, Decimal(string: "99.99"))
    }

    func testCurrencySymbolIsStrippedFromAmount() {
        let lines = ["TOTAL $64.78"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(result.totalAmount, Decimal(string: "64.78"))
    }

    func testNoAmountPresentReturnsNilTotal() {
        let lines = ["STORE RECEIPT", "No prices on this line", "Thank you!"]
        let result = parser.parse(lines: lines, referenceDate: referenceDate(year: 2026, month: 3, day: 1))

        XCTAssertNil(result.totalAmount)
    }
}
