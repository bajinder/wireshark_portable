import SwiftData
import SwiftUI
import UIKit

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    @State private var warrantyOption: WarrantyOption
    @State private var customMonths: String
    @State private var amountText: String
    @State private var showingDeleteConfirmation = false
    @State private var image: UIImage?

    private let expiryCalculator = ExpiryCalculator()
    private let scheduler = NotificationScheduler()

    init(item: Item) {
        self.item = item
        _warrantyOption = State(initialValue: WarrantyOption.closestOption(forMonths: item.warrantyMonths))
        _customMonths = State(initialValue: String(item.warrantyMonths))
        if let amount = item.totalAmount {
            _amountText = State(initialValue: NSDecimalNumber(decimal: amount).stringValue)
        } else {
            _amountText = State(initialValue: "")
        }
    }

    private var expiryDate: Date {
        expiryCalculator.expiryDate(purchaseDate: item.purchaseDate, warrantyMonths: item.warrantyMonths)
    }

    private var daysLeft: Int {
        expiryCalculator.daysUntilExpiry(expiryDate: expiryDate)
    }

    var body: some View {
        Form {
            if let image {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("detailReceiptImage")
                }
            }

            Section("Item") {
                TextField("Item name", text: $item.name)
                    .accessibilityIdentifier("detailNameField")
            }

            Section("Purchase") {
                DatePicker("Purchase date", selection: $item.purchaseDate, in: ...Date(), displayedComponents: .date)
                    .accessibilityIdentifier("detailPurchaseDatePicker")
                TextField("Total amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("detailAmountField")
            }

            Section("Warranty") {
                Picker("Length", selection: $warrantyOption) {
                    ForEach(WarrantyOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("detailWarrantyPicker")

                if warrantyOption == .custom {
                    TextField("Months", text: $customMonths)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("detailCustomMonthsField")
                }

                LabeledContent("Expires") {
                    Text(expiryDate.formatted(date: .abbreviated, time: .omitted))
                }
                LabeledContent("Days left") {
                    Text(daysLeft < 0 ? "Expired" : "\(daysLeft)")
                }
                .accessibilityIdentifier("detailDaysLeft")
            }

            Section {
                Button("Delete Item", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .accessibilityIdentifier("deleteItemButton")
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadImageIfNeeded)
        .onChange(of: warrantyOption) { _, _ in persistWarrantyChange() }
        .onChange(of: customMonths) { _, _ in persistWarrantyChange() }
        .onChange(of: amountText) { _, _ in persistAmount() }
        .onChange(of: item.purchaseDate) { _, _ in rescheduleNotifications() }
        .confirmationDialog(
            "Delete this item?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteItem() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadImageIfNeeded() {
        guard let filename = item.photoFilename else { return }
        image = PhotoStore.shared.loadImage(filename: filename)
    }

    private func persistWarrantyChange() {
        let months: Int
        if let optionMonths = warrantyOption.months {
            months = optionMonths
        } else {
            months = Int(customMonths) ?? item.warrantyMonths
        }
        item.warrantyMonths = months
        rescheduleNotifications()
    }

    private func persistAmount() {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        item.totalAmount = trimmed.isEmpty ? nil : Decimal(string: trimmed)
    }

    private func rescheduleNotifications() {
        let itemID = item.id
        let itemName = item.name
        let expiry = expiryCalculator.expiryDate(purchaseDate: item.purchaseDate, warrantyMonths: item.warrantyMonths)
        let triggers = expiryCalculator.notificationTriggers(expiryDate: expiry)
        Task {
            await scheduler.scheduleExpiryNotifications(itemID: itemID, itemName: itemName, triggers: triggers)
        }
    }

    private func deleteItem() {
        scheduler.cancelNotifications(itemID: item.id)
        if let filename = item.photoFilename {
            PhotoStore.shared.delete(filename: filename)
        }
        modelContext.delete(item)
        dismiss()
    }
}
