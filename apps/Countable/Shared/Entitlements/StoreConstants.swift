import Foundation

/// StoreKit product identifiers and free-tier limits shared by the app (which shows the
/// paywall) and, in principle, anything else that needs to know the limit.
enum StoreConstants {
    /// One-time, non-consumable unlock. Matches the product id in `Countable.storekit`
    /// and must match exactly what is configured in App Store Connect at ship time.
    static let unlockProductID = "com.bajinder.countable.unlock"

    /// Total countdowns + habits (combined) allowed before the unlock is required.
    static let freeItemLimit = 3
}
