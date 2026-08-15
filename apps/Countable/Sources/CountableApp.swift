import SwiftData
import SwiftUI

@main
struct CountableApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var entitlementStore = EntitlementStore()

    init() {
        // UI tests launch with "-uiTesting" to force a clean, in-memory store instead
        // of touching the real App Group-backed database.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        modelContainer = ModelContainerFactory.makeSharedContainer(inMemory: isUITesting)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(entitlementStore)
        }
        .modelContainer(modelContainer)
    }
}
