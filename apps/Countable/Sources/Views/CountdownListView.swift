import SwiftData
import SwiftUI

struct CountdownListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore

    @Query(sort: \CountdownItem.targetDate) private var countdowns: [CountdownItem]
    @Query private var habits: [HabitItem]

    @State private var isPresentingNewItemEditor = false
    @State private var isPresentingPaywall = false
    @State private var editingItem: CountdownItem?

    var body: some View {
        NavigationStack {
            List {
                if countdowns.isEmpty {
                    ContentUnavailableView(
                        "No Countdowns Yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Tap + to add your first countdown.")
                    )
                }
                ForEach(countdowns) { item in
                    Button {
                        editingItem = item
                    } label: {
                        CountdownRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("countdown.row.\(item.title)")
                }
                .onDelete(perform: deleteCountdowns)
            }
            .navigationTitle("Countdowns")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addTapped()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("countdown.addButton")
                }
            }
            .sheet(isPresented: $isPresentingNewItemEditor) {
                CountdownEditView(item: nil)
            }
            .sheet(item: $editingItem) { item in
                CountdownEditView(item: item)
            }
            .sheet(isPresented: $isPresentingPaywall) {
                PaywallView()
                    .environmentObject(entitlementStore)
            }
        }
    }

    private var totalItemCount: Int {
        countdowns.count + habits.count
    }

    private func addTapped() {
        if entitlementStore.canCreateNewItem(currentTotalCount: totalItemCount) {
            isPresentingNewItemEditor = true
        } else {
            isPresentingPaywall = true
        }
    }

    private func deleteCountdowns(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(countdowns[index])
        }
        WidgetRefresher.reloadAllTimelines()
    }
}

private struct CountdownRow: View {
    let item: CountdownItem

    private var daysRemaining: Int {
        CountdownCalculator.daysRemaining(until: item.targetDate)
    }

    private var daysLabel: String {
        if daysRemaining == 0 {
            return "Today"
        } else if daysRemaining < 0 {
            return "\(-daysRemaining)d ago"
        } else {
            return "\(daysRemaining)d"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(item.targetDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(daysLabel)
                .font(.title3.bold())
                .foregroundStyle(item.accentColor.color)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
