import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImage(image) } else { onCancel() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

enum LibraryPhotoLoader {
    struct Loaded {
        let image: UIImage
        let captureDate: Date?
    }

    static func load(_ item: PhotosPickerItem) async -> Loaded? {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return nil }
        return Loaded(image: image, captureDate: exifDate(data))
    }

    static func exifDate(_ data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let value = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value)
    }

    static func sampleMealImage() -> UIImage {
        let size = CGSize(width: 800, height: 600)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 150, y: 50, width: 500, height: 500))
            UIColor(red: 0.85, green: 0.6, blue: 0.3, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 250, y: 150, width: 200, height: 160))
            UIColor(red: 0.3, green: 0.6, blue: 0.25, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 380, y: 260, width: 160, height: 140))
        }
    }
}
