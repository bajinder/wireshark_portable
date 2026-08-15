import SwiftData
import SwiftUI
import WidgetKit

struct HabitEntry: TimelineEntry {
    let date: Date
    let title: String
    let emoji: String
    let streak: Int
    let hasHabit: Bool
    let completedToday: Bool
}

struct HabitTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: .now, title: "Meditate", emoji: "🧘", streak: 5, hasHabit: true, completedToday: true)
    }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitEntry {
        entry(for: configuration, referenceDate: .now)
    }

    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitEntry> {
        let now = Date()
        let currentEntry = entry(for: configuration, referenceDate: now)
        return Timeline(entries: [currentEntry], policy: .after(CountdownTimelineProvider.nextMidnight(after: now)))
    }

    private func entry(for configuration: SelectHabitIntent, referenceDate: Date) -> HabitEntry {
        let container = ModelContainerFactory.makeSharedContainer()
        let context = ModelContext(container)

        let resolvedItem: HabitItem?
        if let selectedID = configuration.habit?.id {
            let descriptor = FetchDescriptor<HabitItem>(predicate: #Predicate<HabitItem> { $0.id == selectedID })
            resolvedItem = (try? context.fetch(descriptor))?.first
        } else {
            let descriptor = FetchDescriptor<HabitItem>(sortBy: [SortDescriptor(\.createdAt)])
            resolvedItem = (try? context.fetch(descriptor))?.first
        }

        guard let item = resolvedItem else {
            return HabitEntry(date: referenceDate, title: "No Habit", emoji: "❔", streak: 0, hasHabit: false, completedToday: false)
        }

        let streak = item.currentStreak(referenceDate: referenceDate)
        let completedToday = item.isCompletedToday(referenceDate: referenceDate)
        return HabitEntry(date: referenceDate, title: item.title, emoji: item.emoji, streak: streak, hasHabit: true, completedToday: completedToday)
    }
}

struct HabitWidgetEntryView: View {
    let entry: HabitEntry

    var body: some View {
        VStack(spacing: 6) {
            Text(entry.emoji)
                .font(.title)
            Text(entry.hasHabit ? "\(entry.streak)" : "–")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(entry.hasHabit ? "day streak" : "Pick a habit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            (entry.completedToday ? Color.green : Color.orange).opacity(0.15)
        }
    }
}

struct HabitWidget: Widget {
    let kind: String = "HabitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectHabitIntent.self, provider: HabitTimelineProvider()) { entry in
            HabitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Habit Streak")
        .description("Track your current streak for a habit.")
        .supportedFamilies([.systemSmall])
    }
}
