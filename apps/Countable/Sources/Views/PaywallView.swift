import StoreKit
import SwiftUI

/// Shown when the user tries to create a 4th countdown/habit without having purchased
/// the one-time unlock.
struct PaywallView: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                Text("Unlock Unlimited Countdowns & Habits")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Countable's free plan includes up to \(StoreConstants.freeItemLimit) countdowns and habits combined. Unlock to add as many as you like.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                purchaseControl

                Button("Restore Purchases") {
                    Task { await entitlementStore.restorePurchases() }
                }
                .accessibilityIdentifier("paywall.restoreButton")

                if let message = entitlementStore.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .accessibilityIdentifier("paywall.root")
            .navigationTitle("Countable Unlock")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("paywall.closeButton")
                }
            }
            .onChange(of: entitlementStore.isUnlocked) { _, unlocked in
                if unlocked {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var purchaseControl: some View {
        if let product = entitlementStore.unlockProduct {
            Button {
                purchase()
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text("Unlock for \(product.displayPrice)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
            .accessibilityIdentifier("paywall.purchaseButton")
        } else {
            ProgressView("Loading price…")
                .task {
                    await entitlementStore.loadProduct()
                }
                .accessibilityIdentifier("paywall.loadingIndicator")
        }
    }

    private func purchase() {
        isPurchasing = true
        Task {
            await entitlementStore.purchase()
            isPurchasing = false
        }
    }
}
