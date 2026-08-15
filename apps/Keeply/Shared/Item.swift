import Foundation
import SwiftData

/// A single warranty-tracked item. The receipt photo itself is stored as a
/// JPEG file in the app's Documents directory; only the filename is kept
/// here so the SwiftData store stays small.
@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var name: String
    var purchaseDate: Date
    var warrantyMonths: Int
    var totalAmount: Decimal?
    var photoFilename: String?
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        purchaseDate: Date,
        warrantyMonths: Int,
        totalAmount: Decimal? = nil,
        photoFilename: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.purchaseDate = purchaseDate
        self.warrantyMonths = warrantyMonths
        self.totalAmount = totalAmount
        self.photoFilename = photoFilename
        self.notes = notes
        self.createdAt = createdAt
    }
}
