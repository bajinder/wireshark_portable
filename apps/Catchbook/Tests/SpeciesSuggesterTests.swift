//
//  SpeciesSuggesterTests.swift
//  CatchbookTests
//

import XCTest
@testable import Catchbook

final class SpeciesSuggesterTests: XCTestCase {

    private func date(_ offsetSeconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + offsetSeconds)
    }

    func testSuggestionsEmptyForNoCatches() {
        XCTAssertTrue(SpeciesSuggester.suggestions(from: []).isEmpty)
    }

    // MARK: - Recency order

    func testSuggestionsOrderedByMostRecentUse() {
        let old = Catch(species: "Bass", date: date(0))
        let recent = Catch(species: "Trout", date: date(1000))
        let mid = Catch(species: "Pike", date: date(500))

        let result = SpeciesSuggester.suggestions(from: [old, recent, mid])

        XCTAssertEqual(result, ["Trout", "Pike", "Bass"])
    }

    func testSuggestionsIgnoreInputOrderNotJustRecency() {
        // Input array is already newest-first; result should still be
        // driven purely by `date`, not array position.
        let recent = Catch(species: "Trout", date: date(1000))
        let old = Catch(species: "Bass", date: date(0))

        let result = SpeciesSuggester.suggestions(from: [old, recent])

        XCTAssertEqual(result, ["Trout", "Bass"])
    }

    // MARK: - Prefix filter

    func testSuggestionsFilteredByPrefixCaseInsensitive() {
        let bass = Catch(species: "Bass", date: date(0))
        let bluegill = Catch(species: "Bluegill", date: date(10))
        let trout = Catch(species: "Trout", date: date(20))

        let result = SpeciesSuggester.suggestions(from: [bass, bluegill, trout], prefix: "b")

        XCTAssertEqual(result, ["Bluegill", "Bass"])
    }

    func testSuggestionsEmptyPrefixReturnsAllSpecies() {
        let bass = Catch(species: "Bass", date: date(0))
        let trout = Catch(species: "Trout", date: date(10))

        let result = SpeciesSuggester.suggestions(from: [bass, trout], prefix: "")

        XCTAssertEqual(result.count, 2)
    }

    func testSuggestionsPrefixWithNoMatchesReturnsEmpty() {
        let bass = Catch(species: "Bass", date: date(0))

        let result = SpeciesSuggester.suggestions(from: [bass], prefix: "zz")

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Dedupe (case-insensitive)

    func testSuggestionsDedupeCaseInsensitiveKeepsMostRecentCasing() {
        let first = Catch(species: "bass", date: date(0))
        let second = Catch(species: "BASS", date: date(100))

        let result = SpeciesSuggester.suggestions(from: [first, second])

        XCTAssertEqual(result, ["BASS"])
    }

    func testSuggestionsDedupeIgnoresLeadingTrailingWhitespace() {
        let first = Catch(species: "  Bass ", date: date(0))
        let second = Catch(species: "Bass", date: date(100))

        let result = SpeciesSuggester.suggestions(from: [first, second])

        XCTAssertEqual(result, ["Bass"])
    }

    func testSuggestionsSkipEmptySpeciesNames() {
        let blank = Catch(species: "   ", date: date(0))
        let bass = Catch(species: "Bass", date: date(10))

        let result = SpeciesSuggester.suggestions(from: [blank, bass])

        XCTAssertEqual(result, ["Bass"])
    }
}
