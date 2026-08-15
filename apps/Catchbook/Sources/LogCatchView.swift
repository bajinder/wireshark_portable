//
//  LogCatchView.swift
//  Catchbook
//
//  Form for logging a new catch. Location is always optional: denying or
//  never granting permission never blocks saving, it just leaves the
//  catch un-located and shows an inline note.
//

import CoreLocation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct LogCatchView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @Query(sort: \Catch.date, order: .reverse) private var existingCatches: [Catch]

    @StateObject private var locationProvider = LocationProvider()

    @State private var species = ""
    @State private var lengthText = ""
    @State private var weightText = ""
    @State private var notes = ""
    @State private var date = Date.now
    @State private var isLocationEnabled = false
    @State private var capturedCoordinate: CLLocationCoordinate2D?
    @State private var isResolvingLocation = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showSpeciesSuggestions = false
    @State private var showPaywall = false
    @State private var showSavedConfirmation = false

    private let freeCatchLimit = 10

    private var speciesSuggestions: [String] {
        SpeciesSuggester.suggestions(from: existingCatches, prefix: species)
            .filter { $0.localizedCaseInsensitiveCompare(species) != .orderedSame }
    }

    private var isLocationDenied: Bool {
        locationProvider.authorizationStatus == .denied || locationProvider.authorizationStatus == .restricted
    }

    private var canSave: Bool {
        !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                speciesSection
                measurementsSection
                photoSection
                locationSection
                Section("Date & Time") {
                    DatePicker("Date", selection: $date)
                        .accessibilityIdentifier("field.date")
                }
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("field.notes")
                }
                Section {
                    Button("Save Catch") {
                        attemptSave()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("button.saveCatch")
                }
            }
            .navigationTitle("Log a Catch")
            .alert("Catch Saved", isPresented: $showSavedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onUnlocked: {
                    showPaywall = false
                    saveCatch()
                })
                .environmentObject(entitlementStore)
            }
        }
        .accessibilityIdentifier("logCatchView")
    }

    private var speciesSection: some View {
        Section("Species") {
            TextField("Species", text: $species)
                .accessibilityIdentifier("field.species")
                .onChange(of: species) { _, newValue in
                    showSpeciesSuggestions = !newValue.isEmpty
                }
            if showSpeciesSuggestions && !speciesSuggestions.isEmpty {
                ForEach(speciesSuggestions.prefix(5), id: \.self) { suggestion in
                    Button(suggestion) {
                        species = suggestion
                        showSpeciesSuggestions = false
                    }
                    .accessibilityIdentifier("speciesSuggestion.\(suggestion)")
                }
            }
        }
    }

    private var measurementsSection: some View {
        Section("Measurements") {
            HStack {
                Text("Length (cm)")
                Spacer()
                TextField("optional", text: $lengthText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("field.length")
            }
            HStack {
                Text("Weight (kg)")
                Spacer()
                TextField("optional", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("field.weight")
            }
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .clipped()
                } else {
                    Label("Add Photo", systemImage: "photo.on.rectangle")
                }
            }
            .accessibilityIdentifier("field.photoPicker")

            if selectedImage != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedImage = nil
                    selectedPhotoItem = nil
                }
                .accessibilityIdentifier("button.removePhoto")
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                selectedImage = image
            }
        }
    }

    private var locationSection: some View {
        Section("Location") {
            Toggle("Add location", isOn: $isLocationEnabled)
                .accessibilityIdentifier("toggle.addLocation")
                .onChange(of: isLocationEnabled) { _, newValue in
                    if newValue {
                        resolveLocation()
                    } else {
                        capturedCoordinate = nil
                    }
                }

            if isLocationEnabled {
                if isResolvingLocation {
                    HStack {
                        ProgressView()
                        Text("Finding your location…")
                    }
                } else if let capturedCoordinate {
                    Text("Lat \(capturedCoordinate.latitude.formatted(.number.precision(.fractionLength(4)))), Lon \(capturedCoordinate.longitude.formatted(.number.precision(.fractionLength(4))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("label.locationCaptured")
                } else if isLocationDenied {
                    Text("Location unavailable — enable in Settings")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("label.locationUnavailable")
                }
            }
        }
    }

    private func resolveLocation() {
        isResolvingLocation = true
        Task {
            let coordinate = await locationProvider.requestCurrentLocation()
            capturedCoordinate = coordinate
            isResolvingLocation = false
        }
    }

    private func attemptSave() {
        let isGated = existingCatches.count >= freeCatchLimit && !entitlementStore.isUnlocked
        if isGated {
            showPaywall = true
        } else {
            saveCatch()
        }
    }

    private func saveCatch() {
        let length = Double(lengthText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        let weight = Double(weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))

        var photoFilename: String?
        if let selectedImage {
            photoFilename = PhotoStore.save(selectedImage)
        }

        let trimmedSpecies = species.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let newCatch = Catch(
            species: trimmedSpecies,
            length: length,
            weight: weight,
            latitude: isLocationEnabled ? capturedCoordinate?.latitude : nil,
            longitude: isLocationEnabled ? capturedCoordinate?.longitude : nil,
            photoFilename: photoFilename,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            date: date
        )
        modelContext.insert(newCatch)

        resetForm()
        showSavedConfirmation = true
    }

    private func resetForm() {
        species = ""
        lengthText = ""
        weightText = ""
        notes = ""
        date = .now
        isLocationEnabled = false
        capturedCoordinate = nil
        selectedPhotoItem = nil
        selectedImage = nil
        showSpeciesSuggestions = false
    }
}

#Preview {
    LogCatchView()
        .environmentObject(EntitlementStore())
        .modelContainer(for: Catch.self, inMemory: true)
}
