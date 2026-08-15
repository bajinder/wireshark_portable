import Foundation
import SwiftData

/// Builds the single SwiftData `ModelContainer` shared by both the Countable app and
/// the CountableWidgetsExtension, backed by a store file inside the App Group
/// container so both processes read and write the exact same data.
enum ModelContainerFactory {
    static let schema = Schema([CountdownItem.self, HabitItem.self])

    /// - Parameter inMemory: When `true`, always uses a throwaway in-memory store
    ///   instead of the App Group-backed one. Used by the app for UI test launches
    ///   (`-uiTesting` launch argument) so tests never touch real user data.
    static func makeSharedContainer(inMemory: Bool = false) -> ModelContainer {
        if !inMemory, let groupURL = AppGroup.containerURL {
            let storeURL = groupURL.appendingPathComponent("Countable.sqlite")
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
                return container
            }
        }

        // Fallback: either explicitly requested (UI tests) or the App Group container
        // couldn't be resolved (e.g. misconfigured signing) — an in-memory store keeps
        // the app/widget launchable rather than crashing.
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let memoryContainer = try? ModelContainer(for: schema, configurations: [memoryConfiguration]) {
            return memoryContainer
        }

        // This should be unreachable: an in-memory SwiftData container has no external
        // dependency (disk, App Group, signing) that could realistically fail. There is
        // no safe UI to show if it does, so we surface it loudly rather than silently
        // losing persistence.
        preconditionFailure("Countable: unable to create even an in-memory SwiftData ModelContainer.")
    }
}
