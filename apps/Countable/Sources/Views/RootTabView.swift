import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            CountdownListView()
                .tabItem {
                    Label("Countdowns", systemImage: "calendar")
                }
                .accessibilityIdentifier("tab.countdowns")

            HabitListView()
                .tabItem {
                    Label("Habits", systemImage: "flame")
                }
                .accessibilityIdentifier("tab.habits")
        }
    }
}
