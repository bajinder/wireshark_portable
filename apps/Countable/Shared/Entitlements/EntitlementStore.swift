import Foundation
import StoreKit

/// Observable wrapper around StoreKit 2 that tracks whether the one-time
/// `com.bajinder.countable.unlock` purchase has been made.
///
/// Uses `ObservableObject` + `@Published` (rather than the newer `@Observable` macro)
/// deliberately — this type is exercised from both the main app UI and, transitively,
/// compiled into the widget extension target as part of `Shared/`, so we stick to the
/// lower-risk, longer-established API surface here.
@MainActor
final class EntitlementStore: ObservableObject {
    @Published private(set) var isUnlocked: Bool = false
    @Published private(set) var unlockProduct: Product?
    @Published private(set) var isLoadingProduct: Bool = false
    @Published var lastErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlements()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    /// Loads the unlock `Product` from StoreKit if it hasn't been loaded yet.
    func loadProduct() async {
        guard unlockProduct == nil else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            let products = try await Product.products(for: [StoreConstants.unlockProductID])
            unlockProduct = products.first
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Re-derives `isUnlocked` from `Transaction.currentEntitlements`, the source of
    /// truth for what the signed-in user actually owns.
    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == StoreConstants.unlockProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    func purchase() async {
        guard let unlockProduct else {
            await loadProduct()
            return
        }
        do {
            let result = try await unlockProduct.purchase()
            switch result {
            case .success(let verificationResult):
                if case .verified(let transaction) = verificationResult {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }

    /// Whether a new countdown/habit can be created given the current combined total.
    func canCreateNewItem(currentTotalCount: Int) -> Bool {
        isUnlocked || currentTotalCount < StoreConstants.freeItemLimit
    }

    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
            await refreshEntitlements()
        }
    }
}
