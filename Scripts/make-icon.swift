import AppKit

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func color(_ hex: Int) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

color(0x000000).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let disc = NSBezierPath(ovalIn: NSRect(x: 192, y: 192, width: 640, height: 640))
color(0xF2F2F2).setStroke()
disc.lineWidth = 6
disc.stroke()
let cross = NSBezierPath()
for (a, b) in [((512, 100), (512, 300)), ((512, 724), (512, 924)), ((100, 512), (300, 512)), ((724, 512), (924, 512))] {
    cross.move(to: NSPoint(x: a.0, y: a.1))
    cross.line(to: NSPoint(x: b.0, y: b.1))
}
cross.lineWidth = 6
cross.stroke()
let text = "kcal" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 150, weight: .light),
    .foregroundColor: color(0xF2F2F2),
]
let textSize = text.size(withAttributes: attributes)
let origin = NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: 512 - textSize.height / 2)
text.draw(at: origin, withAttributes: attributes)
let image = context.makeImage()!
let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
