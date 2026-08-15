import Foundation
import StoreKit

/// Owns the StoreKit 2 purchase flow for the single non-consumable unlock
/// product, and exposes whether it has been bought.
@MainActor
final class EntitlementStore: ObservableObject {
    static let unlockProductID = "com.bajinder.keeply.unlock"
    static let freeItemLimit = 5

    @Published private(set) var isUnlocked: Bool = false
    @Published private(set) var product: Product?
    @Published var purchaseErrorMessage: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlement()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.unlockProductID])
            product = products.first
        } catch {
            purchaseErrorMessage = "Couldn't load the unlock product. Check your connection and try again."
        }
    }

    func purchase() async {
        guard let product else {
            purchaseErrorMessage = "The unlock isn't available right now. Try again in a moment."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlement()
                case .unverified:
                    purchaseErrorMessage = "Purchase could not be verified."
                }
            case .userCancelled:
                break
            case .pending:
                purchaseErrorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseErrorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            purchaseErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.unlockProductID {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }
}
