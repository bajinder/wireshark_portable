//
//  PaywallView.swift
//  Catchbook
//
//  Shown when logging an 11th catch without the unlock purchase. Presented
//  as a sheet; calls `onUnlocked` and dismisses itself once the purchase
//  (or a restore) succeeds so the caller can complete the save that
//  triggered it.
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @Environment(\.dismiss) private var dismiss

    var onUnlocked: (() -> Void)?

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                Text("Unlock Unlimited Catches")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("You've logged 10 catches for free. Unlock Catchbook to log unlimited catches, forever.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                purchaseButton

                Button("Restore Purchases") {
                    Task {
                        await entitlementStore.restore()
                        if entitlementStore.isUnlocked {
                            onUnlocked?()
                            dismiss()
                        }
                    }
                }
                .accessibilityIdentifier("button.restorePurchases")

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Catchbook Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .accessibilityIdentifier("button.dismissPaywall")
                }
            }
            .task {
                if entitlementStore.product == nil {
                    await entitlementStore.loadProduct()
                }
            }
        }
        .accessibilityIdentifier("paywallView")
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if let product = entitlementStore.product {
            Button {
                purchase()
            } label: {
                if isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Unlock for \(product.displayPrice)")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isPurchasing)
            .padding(.horizontal)
            .accessibilityIdentifier("button.purchaseUnlock")
        } else {
            ProgressView("Loading…")
        }
    }

    private func purchase() {
        isPurchasing = true
        errorMessage = nil
        Task {
            await entitlementStore.purchase()
            isPurchasing = false
            if entitlementStore.isUnlocked {
                onUnlocked?()
                dismiss()
            } else if let message = entitlementStore.lastErrorMessage {
                errorMessage = message
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(EntitlementStore())
}
