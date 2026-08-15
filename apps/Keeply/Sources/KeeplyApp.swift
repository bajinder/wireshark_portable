import SwiftData
import SwiftUI

@main
struct KeeplyApp: App {
    @StateObject private var entitlementStore = EntitlementStore()
    private let modelContainer: ModelContainer

    init() {
        // UI tests launch with -uiTestResetData to get a clean, in-memory
        // SwiftData store on every run instead of accumulating items across
        // test invocations.
        let isUITesting = CommandLine.arguments.contains("-uiTestResetData")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
        do {
            modelContainer = try ModelContainer(for: Item.self, configurations: configuration)
        } catch {
            fatalError("Failed to initialize the SwiftData model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ItemListView()
                .environmentObject(entitlementStore)
        }
        .modelContainer(modelContainer)
    }
}
