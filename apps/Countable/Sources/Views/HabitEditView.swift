import SwiftData
import SwiftUI

struct HabitEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: HabitItem?

    @State private var title: String
    @State private var emoji: String

    init(item: HabitItem?) {
        self.item = item
        _title = State(initialValue: item?.title ?? "")
        _emoji = State(initialValue: item?.emoji ?? "✅")
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("habit.titleField")
                    TextField("Emoji", text: $emoji)
                        .onChange(of: emoji) { _, newValue in
                            emoji = String(newValue.prefix(2))
                        }
                        .accessibilityIdentifier("habit.emojiField")
                }
            }
            .navigationTitle(item == nil ? "New Habit" : "Edit Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("habit.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(isSaveDisabled)
                    .accessibilityIdentifier("habit.saveButton")
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEmoji = emoji.isEmpty ? "✅" : emoji

        if let item {
            item.title = trimmedTitle
            item.emoji = resolvedEmoji
        } else {
            let newItem = HabitItem(title: trimmedTitle, emoji: resolvedEmoji)
            modelContext.insert(newItem)
        }

        WidgetRefresher.reloadAllTimelines()
        dismiss()
    }
}
