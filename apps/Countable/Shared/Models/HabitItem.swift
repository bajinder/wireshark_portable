import Foundation
import SwiftData

/// A habit tracked with a simple tap-to-log daily completion, e.g. "Meditate", "Read".
///
/// Completions are stored as an array of start-of-day `Date`s rather than a related
/// `HabitLog` model — this keeps persistence trivially simple (SwiftData supports
/// arrays of `Codable` primitives like `[Date]` directly as an attribute) and keeps the
/// streak math fully decoupled from SwiftData: see `StreakCalculator` and
/// `HabitItem+Streak.swift`.
@Model
final class HabitItem {
    var id: UUID
    var title: String
    var emoji: String
    var createdAt: Date

    /// Start-of-day dates on which this habit was logged as complete. May contain at
    /// most one entry per calendar day; `logToday(...)` de-duplicates.
    var completedDayStarts: [Date]

    init(
        id: UUID = UUID(),
        title: String,
        emoji: String = "✅",
        createdAt: Date = .now,
        completedDayStarts: [Date] = []
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.createdAt = createdAt
        self.completedDayStarts = completedDayStarts
    }
}
