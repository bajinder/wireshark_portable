import AppIntents
import WidgetKit

/// Lets the user pick which habit a `HabitWidget` instance displays.
struct SelectHabitIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Habit"
    static var description = IntentDescription("Choose which habit's streak to display in this widget.")

    @Parameter(title: "Habit")
    var habit: HabitEntity?

    init() {}

    init(habit: HabitEntity?) {
        self.habit = habit
    }
}
