import SwiftData
import SwiftUI

struct HabitListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore

    @Query(sort: \HabitItem.createdAt) private var habits: [HabitItem]
    @Query private var countdowns: [CountdownItem]

    @State private var isPresentingNewItemEditor = false
    @State private var isPresentingPaywall = false
    @State private var editingItem: HabitItem?

    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "flame",
                        description: Text("Tap + to add your first habit.")
                    )
                }
                ForEach(habits) { habit in
                    HabitRow(
                        habit: habit,
                        onLog: { logToday(habit) },
                        onEdit: { editingItem = habit }
                    )
                    .accessibilityIdentifier("habit.row.\(habit.title)")
                }
                .onDelete(perform: deleteHabits)
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addTapped()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("habit.addButton")
                }
            }
            .sheet(isPresented: $isPresentingNewItemEditor) {
                HabitEditView(item: nil)
            }
            .sheet(item: $editingItem) { habit in
                HabitEditView(item: habit)
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

    private func logToday(_ habit: HabitItem) {
        habit.logToday()
        WidgetRefresher.reloadAllTimelines()
    }

    private func deleteHabits(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(habits[index])
        }
        WidgetRefresher.reloadAllTimelines()
    }
}

private struct HabitRow: View {
    let habit: HabitItem
    let onLog: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Text(habit.emoji)
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(streakLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("habit.streakLabel.\(habit.title)")
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onLog) {
                Image(systemName: habit.isCompletedToday() ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(habit.isCompletedToday() ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("habit.logButton.\(habit.title)")
        }
        .padding(.vertical, 4)
    }

    private var streakLabel: String {
        let streak = habit.currentStreak()
        return streak == 1 ? "1 day streak" : "\(streak) day streak"
    }
}
