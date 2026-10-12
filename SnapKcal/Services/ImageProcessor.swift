import UIKit

struct PreparedImage: Sendable {
    let upload: Data
    let thumbnail: Data
    let pixelSize: CGSize
}

enum ImageProcessor {
    static func prepare(_ image: UIImage, detail: AnalysisDetail) -> PreparedImage {
        let maxEdge: CGFloat = detail == .fast ? 1024 : 1568
        let (resized, size) = render(image, maxEdge: maxEdge)
        var upload = resized.jpegData(compressionQuality: 0.7) ?? Data()
        if upload.count > 4_000_000 {
            upload = resized.jpegData(compressionQuality: 0.5) ?? upload
        }
        let thumbnail = render(image, maxEdge: 200).0.jpegData(compressionQuality: 0.6) ?? Data()
        return PreparedImage(upload: upload, thumbnail: thumbnail, pixelSize: size)
    }

    static func prepareInBackground(_ image: UIImage, detail: AnalysisDetail) async -> PreparedImage {
        let box = UncheckedImage(image: image)
        return await Task.detached(priority: .userInitiated) { prepare(box.image, detail: detail) }.value
    }

    static func testImage() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).jpegData(withCompressionQuality: 0.7) { context in
            UIColor(red: 0.85, green: 0.55, blue: 0.2, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }

    private static func render(_ image: UIImage, maxEdge: CGFloat) -> (UIImage, CGSize) {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let scale = min(1, maxEdge / max(width, height, 1))
        let size = CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return (rendered, size)
    }
}

private struct UncheckedImage: @unchecked Sendable {
    let image: UIImage
}
