// DeepworkApp.swift
// Deepwork

import SwiftUI
import SwiftData

@main
struct DeepworkApp: App {
    @State private var timerViewModel = TimerViewModel()
    @State private var entitlementStore = EntitlementStore()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Session.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Deepwork's SwiftData store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(timerViewModel)
                .environment(entitlementStore)
                .task {
                    await entitlementStore.start()
                }
                .onAppear {
                    timerViewModel.attach(modelContext: sharedModelContainer.mainContext)
                    timerViewModel.rehydrate()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        timerViewModel.rehydrate()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
