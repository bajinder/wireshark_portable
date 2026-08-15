import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Drives the "snap a receipt -> OCR -> prefilled form" flow: pick a source
/// (camera or photo library), run on-device OCR, then present an editable
/// form pre-filled with whatever `ReceiptParser` could find.
struct AddItemView: View {
    private enum Stage {
        case pickingSource
        case recognizingText
        case form
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var stage: Stage = .pickingSource
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?
    @State private var showManualEntryNote = false
    @State private var prefillDate: Date?
    @State private var prefillAmount: Decimal?

    private let textRecognizer: TextRecognizing = TextRecognizer()
    private let receiptParser = ReceiptParser()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add Item")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("cancelAddItemButton")
                    }
                }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPickerView { image in
                isShowingCamera = false
                if let image {
                    runOCR(on: image)
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .pickingSource:
            sourcePicker
        case .recognizingText:
            VStack(spacing: 16) {
                ProgressView()
                Text("Reading receipt…")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("ocrProgressView")
        case .form:
            ItemFormView(
                image: capturedImage,
                prefillDate: prefillDate,
                prefillAmount: prefillAmount,
                showManualEntryNote: showManualEntryNote,
                onSave: save,
                onCancel: { dismiss() }
            )
        }
    }

    private var sourcePicker: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Add a receipt photo to get started")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("choosePhotoLibraryButton")
            .padding(.horizontal)

            Button {
                isShowingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("takePhotoButton")
            .padding(.horizontal)

            Button("Enter Details Manually") {
                skipToManualEntry()
            }
            .accessibilityIdentifier("manualEntryButton")

            Spacer()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { await loadPickedPhoto(newValue) }
        }
        .task {
            // Deterministic path for UI tests running on device/simulator,
            // where scripting the real PhotosPicker/camera UI isn't
            // reliable. See README/SHIP.md for details.
            if CommandLine.arguments.contains("-uiTestUseSampleImage") {
                loadSampleImageForUITesting()
            }
        }
    }

    private func loadPickedPhoto(_ pickerItem: PhotosPickerItem) async {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        runOCR(on: image)
    }

    private func runOCR(on image: UIImage) {
        capturedImage = image
        stage = .recognizingText
        Task {
            let lines = await textRecognizer.recognizeText(in: image)
            if lines.isEmpty {
                prefillDate = nil
                prefillAmount = nil
                showManualEntryNote = true
            } else {
                let parsed = receiptParser.parse(lines: lines)
                prefillDate = parsed.purchaseDate
                prefillAmount = parsed.totalAmount
                showManualEntryNote = (parsed.purchaseDate == nil && parsed.totalAmount == nil)
            }
            stage = .form
        }
    }

    private func skipToManualEntry() {
        capturedImage = nil
        prefillDate = nil
        prefillAmount = nil
        showManualEntryNote = true
        stage = .form
    }

    private func loadSampleImageForUITesting() {
        let sampleName = UserDefaults.standard.string(forKey: "uiTestSampleImageName") ?? "sample_receipt_1"
        guard let url = Bundle.main.url(forResource: sampleName, withExtension: "jpg"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            skipToManualEntry()
            return
        }
        runOCR(on: image)
    }

    private func save(name: String, date: Date, warrantyMonths: Int, amount: Decimal?) {
        let item = Item(name: name, purchaseDate: date, warrantyMonths: warrantyMonths, totalAmount: amount)

        if let capturedImage, let jpegData = capturedImage.jpegData(compressionQuality: 0.8) {
            let filename = "\(item.id.uuidString).jpg"
            if (try? PhotoStore.shared.save(imageData: jpegData, filename: filename)) != nil {
                item.photoFilename = filename
            }
        }

        modelContext.insert(item)
        scheduleNotifications(for: item)
        dismiss()
    }

    private func scheduleNotifications(for item: Item) {
        let scheduler = NotificationScheduler()
        let calculator = ExpiryCalculator()
        let itemID = item.id
        let itemName = item.name
        let purchaseDate = item.purchaseDate
        let warrantyMonths = item.warrantyMonths

        Task {
            let granted = await scheduler.requestAuthorization()
            guard granted else { return }
            let expiry = calculator.expiryDate(purchaseDate: purchaseDate, warrantyMonths: warrantyMonths)
            let triggers = calculator.notificationTriggers(expiryDate: expiry)
            await scheduler.scheduleExpiryNotifications(itemID: itemID, itemName: itemName, triggers: triggers)
        }
    }
}
