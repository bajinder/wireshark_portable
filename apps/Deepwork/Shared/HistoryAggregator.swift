// HistoryAggregator.swift
// Deepwork
//
// Pure, dependency-free math for turning a list of focus intervals into
// "minutes per day" totals. Deliberately decoupled from the SwiftData
// `Session` model (via the plain `FocusRecord` struct) so it has zero
// dependency on a `ModelContext`/persistence stack in tests — every case
// here is a synchronous function of its inputs. `Calendar` is injected so
// day-boundary math is testable across timezones instead of silently
// depending on whatever timezone the test happens to run in.

import Foundation

/// A minimal, timezone-agnostic view of one focus interval — just enough
/// for day-bucketing math. Callers (HistoryView) map `Session` -> `FocusRecord`.
struct FocusRecord: Equatable {
    var start: Date
    var minutes: Double
}

struct HistoryAggregator {
    /// Total focus minutes for a single calendar day.
    struct DayTotal: Identifiable, Equatable {
        /// Start-of-day (in `calendar`'s timezone) this total covers.
        var day: Date
        var minutes: Double
        var id: Date { day }
    }

    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Focus minutes for each of the last `dayCount` days (including the
    /// day containing `referenceDate`), oldest first. Days with no sessions
    /// still appear, with `minutes == 0` — callers can rely on the result
    /// always containing exactly `dayCount` entries (or zero, if
    /// `dayCount <= 0`).
    func dailyFocusMinutes(records: [FocusRecord], referenceDate: Date, dayCount: Int) -> [DayTotal] {
        guard dayCount > 0 else { return [] }

        let today = calendar.startOfDay(for: referenceDate)
        var minutesByDay: [Date: Double] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.start)
            minutesByDay[day, default: 0] += record.minutes
        }

        var days: [DayTotal] = []
        days.reserveCapacity(dayCount)
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            days.append(DayTotal(day: day, minutes: minutesByDay[day] ?? 0))
        }
        return days
    }

    /// Sum of every record's minutes, with no day windowing — used for the
    /// unlocked "full history" total.
    func totalFocusMinutes(records: [FocusRecord]) -> Double {
        records.reduce(0) { $0 + $1.minutes }
    }
}
