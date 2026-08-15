//
//  CatchListView.swift
//  Catchbook
//
//  Newest-first list of logged catches with photo thumbnails and an
//  optional species filter.
//

import SwiftData
import SwiftUI
import UIKit

struct CatchListView: View {
    @Query(sort: \Catch.date, order: .reverse) private var catches: [Catch]
    @State private var selectedSpecies = "All"

    private var speciesOptions: [String] {
        let distinct = Set(catches.map(\.species))
        let sorted = distinct.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return ["All"] + sorted
    }

    private var filteredCatches: [Catch] {
        guard selectedSpecies != "All" else { return catches }
        return catches.filter { $0.species == selectedSpecies }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCatches) { fishCatch in
                    NavigationLink(value: fishCatch.id) {
                        CatchRow(fishCatch: fishCatch)
                    }
                    .accessibilityIdentifier("catchRow.\(fishCatch.id.uuidString)")
                }
            }
            .listStyle(.plain)
            .navigationTitle("Catches")
            .navigationDestination(for: UUID.self) { id in
                if let fishCatch = catches.first(where: { $0.id == id }) {
                    CatchDetailView(fishCatch: fishCatch)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(speciesOptions, id: \.self) { species in
                            Button {
                                selectedSpecies = species
                            } label: {
                                if species == selectedSpecies {
                                    Label(species, systemImage: "checkmark")
                                } else {
                                    Text(species)
                                }
                            }
                            .accessibilityIdentifier("speciesFilter.\(species)")
                        }
                    } label: {
                        Label("Filter: \(selectedSpecies)", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityIdentifier("speciesFilterMenu")
                }
            }
            .overlay {
                if filteredCatches.isEmpty {
                    ContentUnavailableView(
                        "No Catches Yet",
                        systemImage: "fish",
                        description: Text("Log your first catch from the Log tab.")
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .accessibilityIdentifier("catchListView")
    }
}

private struct CatchRow: View {
    let fishCatch: Catch

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(fishCatch.species)
                    .font(.headline)
                Text(fishCatch.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let length = fishCatch.length {
                        Text("\(length.formatted(.number.precision(.fractionLength(0...1)))) cm")
                    }
                    if let weight = fishCatch.weight {
                        Text("\(weight.formatted(.number.precision(.fractionLength(0...2)))) kg")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let filename = fishCatch.photoFilename, let image = PhotoStore.load(filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "fish")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#Preview {
    CatchListView()
        .modelContainer(for: Catch.self, inMemory: true)
}
