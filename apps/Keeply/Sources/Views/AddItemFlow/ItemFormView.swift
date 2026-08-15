import SwiftUI
import UIKit

/// The editable item form shown after a receipt photo has been captured (or
/// skipped). Used by the add-item flow; `ItemDetailView` has its own
/// SwiftData-bound form since it edits an existing `Item` in place.
struct ItemFormView: View {
    let image: UIImage?
    let showManualEntryNote: Bool
    let onSave: (String, Date, Int, Decimal?) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var purchaseDate: Date
    @State private var warrantyOption: WarrantyOption
    @State private var customMonths: String
    @State private var amountText: String

    init(
        image: UIImage?,
        prefillDate: Date?,
        prefillAmount: Decimal?,
        showManualEntryNote: Bool,
        onSave: @escaping (String, Date, Int, Decimal?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.image = image
        self.showManualEntryNote = showManualEntryNote
        self.onSave = onSave
        self.onCancel = onCancel

        let today = Date()
        let clampedDate = (prefillDate ?? today) > today ? today : (prefillDate ?? today)
        _name = State(initialValue: "")
        _purchaseDate = State(initialValue: clampedDate)
        _warrantyOption = State(initialValue: .oneYear)
        _customMonths = State(initialValue: "12")
        if let prefillAmount {
            _amountText = State(initialValue: NSDecimalNumber(decimal: prefillAmount).stringValue)
        } else {
            _amountText = State(initialValue: "")
        }
    }

    private var resolvedWarrantyMonths: Int {
        if let months = warrantyOption.months {
            return months
        }
        return Int(customMonths) ?? 12
    }

    private var parsedAmount: Decimal? {
        guard !amountText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return Decimal(string: amountText)
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            if let image {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("receiptPreviewImage")
                }
            }

            if showManualEntryNote {
                Section {
                    Text("Couldn't read receipt — enter details manually.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("manualEntryNote")
                }
            }

            Section("Item") {
                TextField("Item name", text: $name)
                    .accessibilityIdentifier("itemNameField")
            }

            Section("Purchase") {
                DatePicker("Purchase date", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
                    .accessibilityIdentifier("purchaseDatePicker")
                TextField("Total amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("totalAmountField")
            }

            Section("Warranty") {
                Picker("Length", selection: $warrantyOption) {
                    ForEach(WarrantyOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("warrantyLengthPicker")

                if warrantyOption == .custom {
                    TextField("Months", text: $customMonths)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("customMonthsField")
                }
            }

            Section {
                Button("Save") {
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        purchaseDate,
                        resolvedWarrantyMonths,
                        parsedAmount
                    )
                }
                .disabled(isSaveDisabled)
                .accessibilityIdentifier("saveItemButton")
            }
        }
        .navigationTitle("New Item")
        .navigationBarTitleDisplayMode(.inline)
    }
}
