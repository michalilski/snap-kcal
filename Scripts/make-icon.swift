import AppKit

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func color(_ hex: Int) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

color(0x7A8ABA).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
color(0x21242E).setFill()
NSRect(x: 0, y: 0, width: size, height: 220).fill()
let disc = NSBezierPath(ovalIn: NSRect(x: 192, y: 232, width: 640, height: 640))
color(0xF68D1F).setFill()
disc.fill()
color(0x3D4F97).setStroke()
disc.lineWidth = 24
disc.stroke()
let text = "kcal" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 210, weight: .black),
    .foregroundColor: NSColor.white,
]
let textSize = text.size(withAttributes: attributes)
let origin = NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: 552 - textSize.height / 2)
var shadow = attributes
shadow[.foregroundColor] = color(0x21242E)
text.draw(at: NSPoint(x: origin.x + 8, y: origin.y - 10), withAttributes: shadow)
text.draw(at: origin, withAttributes: attributes)
let image = context.makeImage()!
let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
