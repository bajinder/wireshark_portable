import SwiftData
import SwiftUI
import WidgetKit

struct CountdownEntry: TimelineEntry {
    let date: Date
    let title: String
    let emoji: String
    let daysRemaining: Int
    let accentColor: AccentColorOption
    let hasCountdown: Bool
}

struct CountdownTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, title: "Vacation", emoji: "🏖️", daysRemaining: 12, accentColor: .blue, hasCountdown: true)
    }

    func snapshot(for configuration: SelectCountdownIntent, in context: Context) async -> CountdownEntry {
        entry(for: configuration, referenceDate: .now)
    }

    func timeline(for configuration: SelectCountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let now = Date()
        let currentEntry = entry(for: configuration, referenceDate: now)
        return Timeline(entries: [currentEntry], policy: .after(Self.nextMidnight(after: now)))
    }

    private func entry(for configuration: SelectCountdownIntent, referenceDate: Date) -> CountdownEntry {
        let container = ModelContainerFactory.makeSharedContainer()
        let context = ModelContext(container)

        let resolvedItem: CountdownItem?
        if let selectedID = configuration.countdown?.id {
            let descriptor = FetchDescriptor<CountdownItem>(predicate: #Predicate<CountdownItem> { $0.id == selectedID })
            resolvedItem = (try? context.fetch(descriptor))?.first
        } else {
            let descriptor = FetchDescriptor<CountdownItem>(sortBy: [SortDescriptor(\.targetDate)])
            resolvedItem = (try? context.fetch(descriptor))?.first
        }

        guard let item = resolvedItem else {
            return CountdownEntry(date: referenceDate, title: "No Countdown", emoji: "❔", daysRemaining: 0, accentColor: .gray, hasCountdown: false)
        }

        let daysRemaining = CountdownCalculator.daysRemaining(until: item.targetDate, today: referenceDate)
        return CountdownEntry(
            date: referenceDate,
            title: item.title,
            emoji: item.emoji,
            daysRemaining: daysRemaining,
            accentColor: item.accentColor,
            hasCountdown: true
        )
    }

    /// The next local midnight after `date`, used as the timeline reload boundary so
    /// "days remaining" is always correct without needing a background refresh mid-day.
    static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? date.addingTimeInterval(86_400)
    }
}

struct CountdownWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumBody
            default:
                smallBody
            }
        }
        .containerBackground(for: .widget) {
            entry.accentColor.color.opacity(0.15)
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.emoji)
                .font(.title)
            Spacer()
            Text(entry.hasCountdown ? daysLabel : "Pick a countdown")
                .font(.title2.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(entry.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            Text(entry.emoji)
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.hasCountdown ? daysLabel : "Pick a countdown")
                    .font(.title.bold())
                    .foregroundStyle(entry.accentColor.color)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var daysLabel: String {
        if entry.daysRemaining == 0 {
            return "Today"
        } else if entry.daysRemaining < 0 {
            return "\(-entry.daysRemaining)d ago"
        } else {
            return "\(entry.daysRemaining)d left"
        }
    }
}

struct CountdownWidget: Widget {
    let kind: String = "CountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCountdownIntent.self, provider: CountdownTimelineProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Track the days remaining until an event.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
