import Foundation

/// Shared App Group configuration used by both the Countable app and the
/// CountableWidgetsExtension so they can read and write the same SwiftData store.
///
/// If you change the bundle identifiers in `project.yml`, update this identifier to
/// match the `com.apple.security.application-groups` entry in BOTH:
///   - Sources/Countable.entitlements
///   - Widgets/CountableWidgetsExtension.entitlements
enum AppGroup {
    static let identifier = "group.com.bajinder.countable"

    /// The shared container URL for the App Group, or `nil` if the App Group is not
    /// configured/entitled correctly (e.g. running in a preview or a misconfigured
    /// signing setup). Callers should fall back to an in-memory store in that case.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
