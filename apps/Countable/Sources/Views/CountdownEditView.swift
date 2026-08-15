import SwiftData
import SwiftUI

struct CountdownEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: CountdownItem?

    @State private var title: String
    @State private var targetDate: Date
    @State private var emoji: String
    @State private var accentColor: AccentColorOption

    init(item: CountdownItem?) {
        self.item = item
        let defaultDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        _title = State(initialValue: item?.title ?? "")
        _targetDate = State(initialValue: item?.targetDate ?? defaultDate)
        _emoji = State(initialValue: item?.emoji ?? "🎯")
        _accentColor = State(initialValue: item?.accentColor ?? .blue)
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("countdown.titleField")
                    TextField("Emoji", text: $emoji)
                        .onChange(of: emoji) { _, newValue in
                            emoji = String(newValue.prefix(2))
                        }
                        .accessibilityIdentifier("countdown.emojiField")
                    DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                        .accessibilityIdentifier("countdown.datePicker")
                }
                Section("Accent Color") {
                    Picker("Accent Color", selection: $accentColor) {
                        ForEach(AccentColorOption.allCases) { option in
                            Label(option.displayName, systemImage: "circle.fill")
                                .foregroundStyle(option.color)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("countdown.colorPicker")
                }
            }
            .navigationTitle(item == nil ? "New Countdown" : "Edit Countdown")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("countdown.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(isSaveDisabled)
                    .accessibilityIdentifier("countdown.saveButton")
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEmoji = emoji.isEmpty ? "🎯" : emoji

        if let item {
            item.title = trimmedTitle
            item.targetDate = targetDate
            item.emoji = resolvedEmoji
            item.accentColor = accentColor
        } else {
            let newItem = CountdownItem(
                title: trimmedTitle,
                targetDate: targetDate,
                emoji: resolvedEmoji,
                accentColor: accentColor
            )
            modelContext.insert(newItem)
        }

        WidgetRefresher.reloadAllTimelines()
        dismiss()
    }
}
