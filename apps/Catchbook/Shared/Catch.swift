//
//  Catch.swift
//  Catchbook
//
//  SwiftData model representing a single logged fish catch.
//

import CoreLocation
import Foundation
import SwiftData

@Model
final class Catch {
    @Attribute(.unique) var id: UUID
    var species: String
    var length: Double?
    var weight: Double?
    var latitude: Double?
    var longitude: Double?
    var photoFilename: String?
    var notes: String?
    var date: Date

    init(
        id: UUID = UUID(),
        species: String,
        length: Double? = nil,
        weight: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        photoFilename: String? = nil,
        notes: String? = nil,
        date: Date = .now
    ) {
        self.id = id
        self.species = species
        self.length = length
        self.weight = weight
        self.latitude = latitude
        self.longitude = longitude
        self.photoFilename = photoFilename
        self.notes = notes
        self.date = date
    }

    /// Convenience accessor combining latitude/longitude into a CoreLocation coordinate.
    /// Returns nil unless both components are present, i.e. the catch was not located.
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
