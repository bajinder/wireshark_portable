import SwiftUI

/// Shown when a user without the unlock purchase tries to add more than
/// `EntitlementStore.freeItemLimit` items.
struct PaywallView: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("Unlock Unlimited Items")
                    .font(.title2.bold())

                Text("Keeply's free tier tracks up to \(EntitlementStore.freeItemLimit) items. Unlock to track as many warranties as you need — forever, one-time purchase.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                purchaseButton

                Button("Restore Purchases") {
                    Task { await entitlementStore.restorePurchases() }
                }
                .accessibilityIdentifier("restorePurchasesButton")

                if let message = entitlementStore.purchaseErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityIdentifier("paywallErrorMessage")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Keeply Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("closePaywallButton")
                }
            }
            .task {
                if entitlementStore.product == nil {
                    await entitlementStore.loadProduct()
                }
            }
            .onChange(of: entitlementStore.isUnlocked) { _, unlocked in
                if unlocked {
                    dismiss()
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
            .disabled(isPurchasing)
            .accessibilityIdentifier("unlockPurchaseButton")
            .padding(.horizontal)
        } else {
            ProgressView("Loading…")
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
