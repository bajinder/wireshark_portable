//
//  RootView.swift
//  Catchbook
//
//  Top-level TabView: Log / List / Map / Stats.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LogCatchView()
                .tabItem { Label("Log", systemImage: "plus.circle") }
                .accessibilityIdentifier("tab.log")

            CatchListView()
                .tabItem { Label("List", systemImage: "list.bullet") }
                .accessibilityIdentifier("tab.list")

            MapTabView()
                .tabItem { Label("Map", systemImage: "map") }
                .accessibilityIdentifier("tab.map")

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .accessibilityIdentifier("tab.stats")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(EntitlementStore())
        .modelContainer(for: Catch.self, inMemory: true)
}
