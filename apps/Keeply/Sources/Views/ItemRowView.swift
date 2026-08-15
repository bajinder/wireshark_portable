import SwiftUI
import UIKit

struct ItemRowView: View {
    let item: Item
    let expiryCalculator: ExpiryCalculator

    private var expiryDate: Date {
        expiryCalculator.expiryDate(purchaseDate: item.purchaseDate, warrantyMonths: item.warrantyMonths)
    }

    private var daysLeft: Int {
        expiryCalculator.daysUntilExpiry(expiryDate: expiryDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("Expires \(expiryDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            badge
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let filename = item.photoFilename, let image = PhotoStore.shared.loadImage(filename: filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("itemThumbnail_\(item.name)")
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private var badge: some View {
        Text(badgeText)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
            .accessibilityIdentifier("daysLeftBadge_\(item.name)")
    }

    private var badgeText: String {
        if daysLeft < 0 {
            return "Expired"
        } else if daysLeft == 0 {
            return "Today"
        } else {
            return "\(daysLeft)d"
        }
    }

    private var badgeColor: Color {
        if daysLeft < 0 {
            return .gray
        } else if daysLeft <= 7 {
            return .red
        } else if daysLeft <= 30 {
            return .orange
        } else {
            return .green
        }
    }
}
