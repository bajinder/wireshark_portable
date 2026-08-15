// PaywallView.swift
// Deepwork

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Unlock Deepwork")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(text: "Full session history, not just 7 days")
                    FeatureRow(text: "Custom focus & break lengths")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Spacer()

                if let message = entitlementStore.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await entitlementStore.purchase() }
                } label: {
                    if entitlementStore.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(purchaseButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(entitlementStore.product == nil || entitlementStore.isLoading)
                .accessibilityIdentifier("paywall.purchase")

                Button("Restore Purchases") {
                    Task { await entitlementStore.restore() }
                }
                .accessibilityIdentifier("paywall.restore")
            }
            .padding()
            .navigationTitle("Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("paywall.close")
                }
            }
            .task {
                if entitlementStore.product == nil {
                    await entitlementStore.loadProduct()
                }
            }
            .onChange(of: entitlementStore.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }

    private var purchaseButtonTitle: String {
        if let product = entitlementStore.product {
            return "Unlock — \(product.displayPrice)"
        }
        return "Unlock — $3.99"
    }
}

private struct FeatureRow: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.primary)
    }
}

#Preview {
    PaywallView()
        .environment(EntitlementStore())
}
