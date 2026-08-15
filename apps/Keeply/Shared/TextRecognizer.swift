import Foundation
import UIKit
import Vision

/// Abstraction over on-device text recognition so views can depend on a
/// protocol (and tests could substitute a stub) rather than Vision directly.
protocol TextRecognizing {
    func recognizeText(in image: UIImage) async -> [String]
}

/// Runs Vision's `VNRecognizeTextRequest` against a photo entirely
/// on-device. Every failure path (missing CGImage, request error, thrown
/// `perform`) resolves to an empty array so the UI can degrade gracefully
/// to manual entry rather than surfacing an OCR error to the user.
final class TextRecognizer: TextRecognizing {
    func recognizeText(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Run the (potentially slow) Vision request off the main actor.
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
