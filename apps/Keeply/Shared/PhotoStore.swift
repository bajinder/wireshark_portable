import Foundation
import UIKit

enum PhotoStoreError: Error {
    case documentsDirectoryUnavailable
    case writeFailed
}

/// Saves/loads/deletes receipt photos as JPEG files in the app's Documents
/// directory. Only the filename (not the image) is persisted in SwiftData.
protocol PhotoStoring {
    func save(imageData: Data, filename: String) throws
    func loadImage(filename: String) -> UIImage?
    func delete(filename: String)
}

final class PhotoStore: PhotoStoring {
    static let shared = PhotoStore()

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private func documentsDirectory() throws -> URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw PhotoStoreError.documentsDirectoryUnavailable
        }
        return url
    }

    private func fileURL(for filename: String) throws -> URL {
        try documentsDirectory().appendingPathComponent(filename)
    }

    func save(imageData: Data, filename: String) throws {
        let url = try fileURL(for: filename)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw PhotoStoreError.writeFailed
        }
    }

    func loadImage(filename: String) -> UIImage? {
        guard let url = try? fileURL(for: filename),
              let data = fileManager.contents(atPath: url.path) else {
            return nil
        }
        return UIImage(data: data)
    }

    func delete(filename: String) {
        guard let url = try? fileURL(for: filename) else { return }
        try? fileManager.removeItem(at: url)
    }
}
