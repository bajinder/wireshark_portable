// EntitlementStore.swift
// Deepwork
//
// StoreKit 2 wrapper for the single one-time "unlock" purchase
// (com.bajinder.deepwork.unlock). `isUnlocked` is always derived from
// `Transaction.currentEntitlements` — the actual source of truth StoreKit
// maintains — rather than a locally cached bool, so a restore on a new
// device or a refund is picked up correctly. `Transaction.updates` is
// observed continuously so a purchase completed outside the app (e.g.
// Ask to Buy approval) is picked up without the user having to relaunch.

import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class EntitlementStore {
    static let unlockProductID = "com.bajinder.deepwork.unlock"

    private(set) var isUnlocked = false
    private(set) var product: Product?
    private(set) var isLoading = false
    var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Call once on app launch: loads the product and computes the current
    /// entitlement so the UI reflects purchase state immediately.
    func start() async {
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.unlockProductID])
            product = products.first
        } catch {
            lastErrorMessage = "Couldn't load the unlock: \(error.localizedDescription)"
        }
    }

    func purchase() async {
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                if case let .verified(transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    lastErrorMessage = "Purchase could not be verified."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, transaction.productID == Self.unlockProductID {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            if case let .verified(transaction) = update, transaction.productID == Self.unlockProductID {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}
