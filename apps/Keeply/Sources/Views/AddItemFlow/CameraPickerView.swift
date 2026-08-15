import SwiftUI
import UIKit

/// Thin `UIViewControllerRepresentable` wrapper around
/// `UIImagePickerController` configured for the camera. `PhotosPicker`
/// (PhotosUI) covers the photo-library case; this covers the camera case,
/// which PhotosPicker cannot.
struct CameraPickerView: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No dynamic state to push down after creation.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onComplete(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }
    }
}
