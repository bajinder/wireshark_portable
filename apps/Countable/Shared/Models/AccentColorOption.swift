import SwiftUI

/// A small predefined color palette for countdown accents.
///
/// This is intentionally a plain `String`-backed enum rather than storing `Color`
/// directly: `Color` is not a safe/portable SwiftData attribute type across the app and
/// widget extension processes, whereas a `String` raw value round-trips perfectly and
/// is trivially `Codable`, `Hashable`, and `Sendable`.
enum AccentColorOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .gray: return .gray
        }
    }
}
