import AppIntents
import Foundation
import SwiftData

/// Widget-configuration-facing representation of a `CountdownItem`. Kept as a small,
/// independent value type (rather than exposing the SwiftData model directly) because
/// `AppEntity` values may be persisted by the system (e.g. inside a saved widget
/// configuration) and must stay simple and `Sendable`.
struct CountdownEntity: AppEntity {
    let id: UUID
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Countdown"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static var defaultQuery = CountdownEntityQuery()
}

struct CountdownEntityQuery: EntityQuery {
    func entities(for identifiers: [CountdownEntity.ID]) async throws -> [CountdownEntity] {
        try Self.fetchAllCountdownEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CountdownEntity] {
        try Self.fetchAllCountdownEntities()
    }

    private static func fetchAllCountdownEntities() throws -> [CountdownEntity] {
        let container = ModelContainerFactory.makeSharedContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CountdownItem>(sortBy: [SortDescriptor(\.targetDate)])
        let items = try context.fetch(descriptor)
        return items.map { CountdownEntity(id: $0.id, title: $0.title) }
    }
}
