import Foundation

/// The set of warranty lengths offered in the add/edit form. `.custom`
/// defers to a user-entered number of months.
enum WarrantyOption: String, CaseIterable, Identifiable, Hashable {
    case sixMonths = "6 Months"
    case oneYear = "1 Year"
    case twoYears = "2 Years"
    case threeYears = "3 Years"
    case custom = "Custom"

    var id: String { rawValue }

    /// Number of months this option represents, or `nil` for `.custom`
    /// (in which case the caller must consult a separate "custom months"
    /// value entered by the user).
    var months: Int? {
        switch self {
        case .sixMonths: return 6
        case .oneYear: return 12
        case .twoYears: return 24
        case .threeYears: return 36
        case .custom: return nil
        }
    }

    /// Finds the preset option matching an exact month count, falling back
    /// to `.custom` when the value doesn't match a preset (e.g. an item
    /// whose warranty was set to a custom length).
    static func closestOption(forMonths months: Int) -> WarrantyOption {
        allCases.first { $0.months == months } ?? .custom
    }
}
