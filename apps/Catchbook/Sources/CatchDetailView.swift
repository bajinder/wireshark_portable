//
//  CatchDetailView.swift
//  Catchbook
//
//  Read-only detail screen for a single catch, reached from the list or
//  by tapping a map pin.
//

import MapKit
import SwiftUI
import UIKit

struct CatchDetailView: View {
    let fishCatch: Catch

    private var cameraPosition: MapCameraPosition {
        guard let coordinate = fishCatch.coordinate else { return .automatic }
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        return .region(region)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let filename = fishCatch.photoFilename, let image = PhotoStore.load(filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("image.catchPhoto")
                }

                Text(fishCatch.species)
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("label.detailSpecies")

                Text(fishCatch.date.formatted(date: .long, time: .shortened))
                    .foregroundStyle(.secondary)

                if fishCatch.length != nil || fishCatch.weight != nil {
                    HStack(spacing: 24) {
                        if let length = fishCatch.length {
                            measurementTile(title: "Length", value: "\(length.formatted(.number.precision(.fractionLength(0...1)))) cm")
                        }
                        if let weight = fishCatch.weight {
                            measurementTile(title: "Weight", value: "\(weight.formatted(.number.precision(.fractionLength(0...2)))) kg")
                        }
                    }
                }

                if let notes = fishCatch.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes").font(.caption).foregroundStyle(.secondary)
                        Text(notes)
                    }
                }

                if let coordinate = fishCatch.coordinate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location").font(.caption).foregroundStyle(.secondary)
                        Map(position: .constant(cameraPosition)) {
                            Marker(fishCatch.species, coordinate: coordinate)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("map.detailLocation")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Catch Detail")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("catchDetailView")
    }

    private func measurementTile(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }
}

#Preview {
    NavigationStack {
        CatchDetailView(fishCatch: Catch(species: "Largemouth Bass", length: 45, weight: 2.3, latitude: 45.4215, longitude: -75.6972, notes: "Caught near the reeds at sunrise."))
    }
}
