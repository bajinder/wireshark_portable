import WidgetKit

/// Tiny wrapper so app code doesn't need to import WidgetKit directly everywhere data
/// changes. Widgets also reload themselves at the next midnight boundary regardless
/// (see the timeline providers in Widgets/), so this is purely for immediate feedback
/// right after an edit.
enum WidgetRefresher {
    static func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
