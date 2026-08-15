//
//  CatchbookApp.swift
//  Catchbook
//

import SwiftData
import SwiftUI

@main
struct CatchbookApp: App {
    let modelContainer: ModelContainer
    @StateObject private var entitlementStore = EntitlementStore()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let useInMemoryStore = arguments.contains("-uiTestInMemoryStore")

        let schema = Schema([Catch.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: useInMemoryStore)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create Catchbook's SwiftData store: \(error.localizedDescription)")
        }
        modelContainer = container

        if let flagIndex = arguments.firstIndex(of: "-uiTestPreseedCatches"),
           flagIndex + 1 < arguments.count,
           let preseedCount = Int(arguments[flagIndex + 1]),
           preseedCount > 0 {
            Self.preseed(count: preseedCount, into: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(entitlementStore)
        }
        .modelContainer(modelContainer)
    }

    /// Inserts deterministic sample catches for UI test scenarios (e.g. the
    /// purchase-gate test, which needs 10 pre-existing catches without
    /// driving the log form ten times).
    private static func preseed(count: Int, into container: ModelContainer) {
        let context = ModelContext(container)
        for index in 0..<count {
            let seedCatch = Catch(
                species: "Seed Species",
                length: 30,
                weight: 1.2,
                date: Date.now.addingTimeInterval(TimeInterval(-index * 3600))
            )
            context.insert(seedCatch)
        }
        try? context.save()
    }
}
