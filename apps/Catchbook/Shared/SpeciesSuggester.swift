//
//  SpeciesSuggester.swift
//  Catchbook
//
//  Pure helper producing species-name autocomplete suggestions from
//  previously logged catches.
//

import Foundation

enum SpeciesSuggester {

    /// Distinct species names from `catches`, ordered by most recent use
    /// (based on `Catch.date`), optionally filtered to names starting with
    /// `prefix` (case-insensitive). Matching is case-insensitive for both
    /// dedupe and filtering; when the same species name was logged with
    /// different casing, the casing from its most recent use is kept.
    static func suggestions(from catches: [Catch], prefix: String = "") -> [String] {
        let sortedByRecency = catches.sorted { $0.date > $1.date }

        var seenKeys = Set<String>()
        var recencyOrdered: [String] = []
        for fishCatch in sortedByRecency {
            let trimmed = fishCatch.species.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            recencyOrdered.append(trimmed)
        }

        guard !prefix.isEmpty else { return recencyOrdered }

        let lowerPrefix = prefix.lowercased()
        return recencyOrdered.filter { $0.lowercased().hasPrefix(lowerPrefix) }
    }
}
