import SwiftData
import SwiftUI

struct ItemListView: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @Query private var items: [Item]

    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var showingPaywall = false

    private let expiryCalculator = ExpiryCalculator()

    private var filteredSortedItems: [Item] {
        let filtered: [Item]
        if searchText.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return filtered.sorted { lhs, rhs in
            let lhsExpiry = expiryCalculator.expiryDate(purchaseDate: lhs.purchaseDate, warrantyMonths: lhs.warrantyMonths)
            let rhsExpiry = expiryCalculator.expiryDate(purchaseDate: rhs.purchaseDate, warrantyMonths: rhs.warrantyMonths)
            return lhsExpiry < rhsExpiry
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items Yet",
                        systemImage: "shippingbox",
                        description: Text("Add a receipt to start tracking a warranty.")
                    )
                    .accessibilityIdentifier("emptyStateView")
                } else {
                    List {
                        ForEach(filteredSortedItems) { item in
                            NavigationLink(value: item) {
                                ItemRowView(item: item, expiryCalculator: expiryCalculator)
                            }
                            .accessibilityIdentifier("itemRow_\(item.name)")
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("itemList")
                }
            }
            .navigationTitle("Keeply")
            .searchable(text: $searchText, prompt: "Search items")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        attemptAddItem()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addItemButton")
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private func attemptAddItem() {
        if !entitlementStore.isUnlocked && items.count >= EntitlementStore.freeItemLimit {
            showingPaywall = true
        } else {
            showingAddItem = true
        }
    }
}

#Preview {
    ItemListView()
        .environmentObject(EntitlementStore())
        .modelContainer(for: Item.self, inMemory: true)
}
