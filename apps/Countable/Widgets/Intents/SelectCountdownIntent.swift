import AppIntents
import WidgetKit

/// Lets the user pick which countdown a `CountdownWidget` instance displays.
/// `WidgetConfigurationIntent` does not require implementing `perform()` — it exists
/// purely to drive the widget's configuration UI (long-press > Edit Widget).
struct SelectCountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Countdown"
    static var description = IntentDescription("Choose which countdown to display in this widget.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?

    init() {}

    init(countdown: CountdownEntity?) {
        self.countdown = countdown
    }
}
