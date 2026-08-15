//
//  EntitlementStore.swift
//  Catchbook
//
//  StoreKit 2 wrapper for the single "unlock unlimited catches" IAP.
//  Exposes purchase state as @Published so the paywall and save-gating
//  logic can react to it directly.
//

import Foundation
import StoreKit

@MainActor
final class EntitlementStore: ObservableObject {

    static let unlockProductID = "com.bajinder.catchbook.unlock"

    @Published private(set) var isUnlocked = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlement()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.unlockProductID])
            product = products.first
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
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

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        await refreshEntitlement()
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

    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }
}
