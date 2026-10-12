import SwiftUI

enum Theme {
    enum Color {
        static let background = SwiftUI.Color(hex: 0x000000)
        static let surface = SwiftUI.Color(hex: 0x0A0A0A)
        static let surfaceRaised = SwiftUI.Color(hex: 0x161616)
        static let border = SwiftUI.Color(hex: 0x2E2E2E)
        static let textPrimary = SwiftUI.Color(hex: 0xF2F2F2)
        static let textSecondary = SwiftUI.Color(hex: 0x9A9A9A)
        static let textMuted = SwiftUI.Color(hex: 0x5C5C5C)
        static let accent = SwiftUI.Color(hex: 0xFFFFFF)
        static let accentStrong = SwiftUI.Color(hex: 0xFFFFFF)
        static let success = SwiftUI.Color(hex: 0xF2F2F2)
        static let warning = SwiftUI.Color(hex: 0x9A9A9A)
        static let danger = SwiftUI.Color(hex: 0xFF3B30)
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: 48, weight: .light, design: .monospaced)
        static let metric = SwiftUI.Font.system(size: 18, weight: .regular, design: .monospaced)
        static let title = SwiftUI.Font.system(.title3, design: .monospaced, weight: .semibold)
        static let navLink = SwiftUI.Font.system(size: 10, weight: .medium, design: .monospaced)
        static let uiLabel = SwiftUI.Font.system(size: 10, weight: .medium, design: .monospaced)
        static let link = SwiftUI.Font.system(.subheadline, design: .monospaced, weight: .medium)
        static let body = SwiftUI.Font.system(.footnote, design: .monospaced)
        static let micro = SwiftUI.Font.system(.caption2, design: .monospaced)
        static let data = SwiftUI.Font.system(.caption2, design: .monospaced)
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
        static let panel: CGFloat = 0
        static let button: CGFloat = 0
        static let tile: CGFloat = 0
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

extension DayStatus {
    var color: Color {
        switch self {
        case .empty, .future: Theme.Color.surfaceRaised
        case .under: Theme.Color.textMuted
        case .onTarget: Theme.Color.textPrimary
        case .over: Theme.Color.danger
        }
    }
}

extension View {
    func uiLabelStyle(_ color: Color = Theme.Color.textSecondary) -> some View {
        font(Theme.Font.uiLabel).tracking(1.5).textCase(.uppercase).foregroundStyle(color)
    }
}
