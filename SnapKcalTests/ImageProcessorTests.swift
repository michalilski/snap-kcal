import ImageIO
import Testing
import UIKit
@testable import SnapKcal

struct ImageProcessorTests {
    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func fastResizesLongEdgeTo1024() {
        let prepared = ImageProcessor.prepare(image(width: 4000, height: 3000), detail: .fast)
        #expect(prepared.pixelSize == CGSize(width: 1024, height: 768))
        #expect(UIImage(data: prepared.upload)?.size == CGSize(width: 1024, height: 768))
    }

    @Test func accurateResizesLongEdgeTo1568() {
        #expect(ImageProcessor.prepare(image(width: 3000, height: 4000), detail: .accurate).pixelSize.height == 1568)
    }

    @Test func smallImagesAreNotUpscaled() {
        #expect(ImageProcessor.prepare(image(width: 300, height: 200), detail: .fast).pixelSize == CGSize(width: 300, height: 200))
    }

    @Test func thumbnailIs200px() {
        let thumbnail = UIImage(data: ImageProcessor.prepare(image(width: 2000, height: 1000), detail: .fast).thumbnail)
        #expect(thumbnail?.size.width == 200)
    }

    @Test func outputHasNoGPSOrExif() throws {
        let data = ImageProcessor.prepare(image(width: 800, height: 600), detail: .fast).upload
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect((properties[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifDateTimeOriginal] == nil)
    }

    @Test func testImageIsTinyJPEG() {
        let data = ImageProcessor.testImage()
        #expect(UIImage(data: data)?.size == CGSize(width: 64, height: 64))
        #expect(data.starts(with: [0xFF, 0xD8]))
    }
}
