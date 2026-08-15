// RootView.swift
// Deepwork

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
                .accessibilityIdentifier("tab.timer")

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar") }
                .accessibilityIdentifier("tab.history")

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .accessibilityIdentifier("tab.settings")
        }
    }
}

#Preview {
    RootView()
        .environment(TimerViewModel())
        .environment(EntitlementStore())
        .modelContainer(for: Session.self, inMemory: true)
}
