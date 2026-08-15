//
//  StatsCalculator.swift
//  Catchbook
//
//  Pure, unit-testable statistics over an array of Catch values.
//  No SwiftData context or UI dependency — takes plain arrays and a
//  caller-supplied Calendar/now so tests can control time explicitly.
//

import Foundation

/// The biggest logged catch for a single species.
///
/// "Biggest" is decided per-catch using `weight`, falling back to `length`
/// when a catch has no recorded weight. When two catches tie on that metric,
/// the one encountered first in the input array is kept (stable, deterministic).
struct SpeciesBest: Identifiable, Equatable {
    let species: String
    let weight: Double?
    let length: Double?
    var id: String { species }
}

/// Number of catches logged in a given calendar month.
struct MonthCount: Identifiable, Equatable {
    /// First instant of the month, in the calendar used to compute it.
    let monthStart: Date
    let count: Int
    var id: Date { monthStart }
}

/// Aggregate stats bundle returned by `StatsCalculator.stats(for:calendar:now:)`.
struct CatchStats {
    let totalCatches: Int
    let biggestBySpecies: [SpeciesBest]
    let monthlyCounts: [MonthCount]
}

enum StatsCalculator {

    /// Computes the full stats bundle for the Stats tab.
    static func stats(for catches: [Catch], calendar: Calendar = .current, now: Date = .now) -> CatchStats {
        CatchStats(
            totalCatches: totalCatches(catches),
            biggestBySpecies: biggestBySpecies(catches),
            monthlyCounts: monthlyCounts(catches, calendar: calendar, now: now)
        )
    }

    static func totalCatches(_ catches: [Catch]) -> Int {
        catches.count
    }

    /// Returns one entry per distinct species, sorted alphabetically, describing
    /// that species' biggest catch (weight desc, falling back to length when
    /// weight is nil for a given catch).
    static func biggestBySpecies(_ catches: [Catch]) -> [SpeciesBest] {
        var bestBySpecies: [String: Catch] = [:]
        var order: [String] = []

        for fishCatch in catches {
            if let existing = bestBySpecies[fishCatch.species] {
                if sizeMetric(fishCatch) > sizeMetric(existing) {
                    bestBySpecies[fishCatch.species] = fishCatch
                }
            } else {
                bestBySpecies[fishCatch.species] = fishCatch
                order.append(fishCatch.species)
            }
        }

        return order
            .compactMap { species -> SpeciesBest? in
                guard let best = bestBySpecies[species] else { return nil }
                return SpeciesBest(species: species, weight: best.weight, length: best.length)
            }
            .sorted { $0.species.localizedCaseInsensitiveCompare($1.species) == .orderedAscending }
    }

    /// Counts catches per calendar month for the trailing 12 months (including
    /// the current month), oldest first. Months with no catches are included
    /// with a zero count so charts always render a full 12-bar window.
    static func monthlyCounts(_ catches: [Catch], calendar: Calendar, now: Date = .now) -> [MonthCount] {
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }

        var order: [Date] = []
        var buckets: [Date: Int] = [:]
        for monthsAgo in stride(from: 11, through: 0, by: -1) {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthsAgo, to: currentMonthStart) else { continue }
            order.append(monthStart)
            buckets[monthStart] = 0
        }

        for fishCatch in catches {
            let components = calendar.dateComponents([.year, .month], from: fishCatch.date)
            guard let monthStart = calendar.date(from: components), buckets[monthStart] != nil else { continue }
            buckets[monthStart, default: 0] += 1
        }

        return order.map { MonthCount(monthStart: $0, count: buckets[$0] ?? 0) }
    }

    /// Per-catch size used to compare "biggest": weight if present, else
    /// length, else a sentinel smaller than any real measurement.
    private static func sizeMetric(_ fishCatch: Catch) -> Double {
        fishCatch.weight ?? fishCatch.length ?? -1
    }
}
