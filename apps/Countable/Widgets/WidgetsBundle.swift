import SwiftUI
import WidgetKit

@main
struct CountableWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
        HabitWidget()
    }
}
