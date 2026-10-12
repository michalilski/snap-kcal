import AppKit

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func color(_ hex: Int) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

color(0x111111).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let text = "KCAL" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 300, weight: .black, width: .condensed),
    .foregroundColor: NSColor.white,
]
let textSize = text.size(withAttributes: attributes)
let origin = NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: 512 - textSize.height / 2)
text.draw(at: origin, withAttributes: attributes)
let image = context.makeImage()!
let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
