//
//  PhotoStore.swift
//  Catchbook
//
//  Persists catch photos as JPEG files in the app's Documents directory.
//  Only the generated filename is stored on the Catch model; this type
//  owns reading/writing/deleting the actual file.
//

import Foundation
import UIKit

enum PhotoStore {

    /// Encodes `image` as JPEG and writes it to Documents under a fresh
    /// UUID filename. Returns the filename on success, nil on failure
    /// (callers should treat a nil result the same as "no photo").
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = documentsURL.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    /// Loads a previously saved photo by filename. Returns nil if the file
    /// is missing or unreadable.
    static func load(_ filename: String) -> UIImage? {
        let url = documentsURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Removes a previously saved photo. No-op if it does not exist.
    static func delete(_ filename: String) {
        let url = documentsURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
