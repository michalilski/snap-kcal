import SwiftUI

enum Theme {
    enum Color {
        static let canvas = SwiftUI.Color(hex: 0x7A8ABA)
        static let periwinkle = SwiftUI.Color(hex: 0x8BA1D4)
        static let canvasSoft = SwiftUI.Color(hex: 0x9FBEE7)
        static let ice = SwiftUI.Color(hex: 0xC0D5E6)
        static let lavender = SwiftUI.Color(hex: 0xACACE7)
        static let chromeIndigo = SwiftUI.Color(hex: 0x3D4F97)
        static let mutedIndigo = SwiftUI.Color(hex: 0x60619C)
        static let hairline = SwiftUI.Color(hex: 0x5A5F8C)
        static let platinum = SwiftUI.Color(hex: 0xDEDEDE)
        static let surface = SwiftUI.Color(hex: 0xFFFFFF)
        static let carbon = SwiftUI.Color(hex: 0x21242E)
        static let navGold = SwiftUI.Color(hex: 0xE48600)
        static let amber = SwiftUI.Color(hex: 0xECAB37)
        static let signal = SwiftUI.Color(hex: 0xF68D1F)
        static let red = SwiftUI.Color(hex: 0xE60012)
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: 56, weight: .black).italic()
        static let title = SwiftUI.Font.custom("Arial-BoldItalicMT", size: 20, relativeTo: .title3)
        static let navLink = SwiftUI.Font.custom("Arial-BoldMT", size: 13, relativeTo: .caption)
        static let uiLabel = SwiftUI.Font.custom("Arial-BoldMT", size: 13, relativeTo: .caption)
        static let link = SwiftUI.Font.custom("Arial-BoldMT", size: 15, relativeTo: .body)
        static let body = SwiftUI.Font.custom("ArialMT", size: 15, relativeTo: .body)
        static let micro = SwiftUI.Font.custom("ArialMT", size: 11, relativeTo: .caption2)
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let plate: CGFloat = 0
        static let button: CGFloat = 2
        static let row: CGFloat = 4
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    func uiLabelStyle(_ color: Color = Theme.Color.carbon) -> some View {
        font(Theme.Font.uiLabel).tracking(0.5).textCase(.uppercase).foregroundStyle(color)
    }
}
