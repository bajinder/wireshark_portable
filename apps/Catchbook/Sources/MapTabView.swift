//
//  MapTabView.swift
//  Catchbook
//
//  Shows a pin for every catch that has a saved location. Tapping a pin
//  presents that catch's detail sheet.
//

import MapKit
import SwiftData
import SwiftUI

struct MapTabView: View {
    @Query private var catches: [Catch]
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCatch: Catch?

    private var locatedCatches: [Catch] {
        catches.filter { $0.coordinate != nil }
    }

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition, selection: $selectedCatch) {
                ForEach(locatedCatches) { fishCatch in
                    if let coordinate = fishCatch.coordinate {
                        Marker(fishCatch.species, coordinate: coordinate)
                            .tag(fishCatch)
                    }
                }
            }
            .navigationTitle("Catch Map")
            .overlay {
                if locatedCatches.isEmpty {
                    ContentUnavailableView(
                        "No Located Catches",
                        systemImage: "map",
                        description: Text("Catches with a saved location will appear here.")
                    )
                    .allowsHitTesting(false)
                }
            }
            .sheet(item: $selectedCatch) { fishCatch in
                NavigationStack {
                    CatchDetailView(fishCatch: fishCatch)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { selectedCatch = nil }
                                    .accessibilityIdentifier("button.closeMapDetail")
                            }
                        }
                }
                .accessibilityIdentifier("mapCatchDetailSheet")
            }
            .accessibilityIdentifier("mapTabView")
        }
    }
}

#Preview {
    MapTabView()
        .modelContainer(for: Catch.self, inMemory: true)
}
