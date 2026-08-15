import Foundation
import SwiftData

/// A single countdown event (e.g. "Trip to Japan", "Anniversary").
///
/// `accentColorRawValue` is stored as a plain `String` (not `Color`) so the value is
/// safe to persist with SwiftData and safe to read from the widget extension process.
/// Use the `accentColor` computed property for a typed, always-valid accessor.
@Model
final class CountdownItem {
    /// Stable identifier used both as the SwiftUI `Identifiable` id and as the
    /// `EntityIdentifierConvertible`-compatible id for the widget configuration
    /// `AppEntity`. Kept distinct from SwiftData's own `PersistentIdentifier` so it is
    /// safe to serialize into widget configuration intents.
    var id: UUID
    var title: String
    var targetDate: Date
    var emoji: String
    var accentColorRawValue: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        emoji: String = "🎯",
        accentColor: AccentColorOption = .blue,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.emoji = emoji
        self.accentColorRawValue = accentColor.rawValue
        self.createdAt = createdAt
    }

    var accentColor: AccentColorOption {
        get { AccentColorOption(rawValue: accentColorRawValue) ?? .blue }
        set { accentColorRawValue = newValue.rawValue }
    }
}
