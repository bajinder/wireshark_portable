import AppIntents
import Foundation
import SwiftData

struct HabitEntity: AppEntity {
    let id: UUID
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static var defaultQuery = HabitEntityQuery()
}

struct HabitEntityQuery: EntityQuery {
    func entities(for identifiers: [HabitEntity.ID]) async throws -> [HabitEntity] {
        try Self.fetchAllHabitEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        try Self.fetchAllHabitEntities()
    }

    private static func fetchAllHabitEntities() throws -> [HabitEntity] {
        let container = ModelContainerFactory.makeSharedContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HabitItem>(sortBy: [SortDescriptor(\.createdAt)])
        let items = try context.fetch(descriptor)
        return items.map { HabitEntity(id: $0.id, title: $0.title) }
    }
}
