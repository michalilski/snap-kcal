import SwiftUI

enum Theme {
    enum Color {
        static let background = SwiftUI.Color(hex: 0xFFFFFF)
        static let surface = SwiftUI.Color(hex: 0xF5F5F5)
        static let surfaceRaised = SwiftUI.Color(hex: 0xE5E5E5)
        static let border = SwiftUI.Color(hex: 0xCACACB)
        static let textPrimary = SwiftUI.Color(hex: 0x111111)
        static let textSecondary = SwiftUI.Color(hex: 0x707072)
        static let textMuted = SwiftUI.Color(hex: 0x9E9EA0)
        static let accent = SwiftUI.Color(hex: 0x111111)
        static let onAccent = SwiftUI.Color(hex: 0xFFFFFF)
        static let success = SwiftUI.Color(hex: 0x007D48)
        static let warning = SwiftUI.Color(hex: 0xD33918)
        static let danger = SwiftUI.Color(hex: 0xD30005)
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: 72, weight: .black).width(.condensed)
        static let headline = SwiftUI.Font.system(size: 28, weight: .black).width(.condensed)
        static let metric = SwiftUI.Font.system(size: 22, weight: .heavy).width(.condensed)
        static let title = SwiftUI.Font.system(.title2, weight: .black).width(.condensed)
        static let section = SwiftUI.Font.system(size: 20, weight: .medium)
        static let navLink = SwiftUI.Font.system(size: 10, weight: .medium)
        static let uiLabel = SwiftUI.Font.system(size: 13, weight: .medium)
        static let link = SwiftUI.Font.system(.body, weight: .medium)
        static let body = SwiftUI.Font.system(.subheadline)
        static let micro = SwiftUI.Font.system(.caption)
        static let data = SwiftUI.Font.system(.caption, weight: .medium).monospacedDigit()
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
        static let panel: CGFloat = 20
        static let tile: CGFloat = 12
        static let image: CGFloat = 16
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
        case .empty, .future: Theme.Color.surface
        case .under: Theme.Color.border
        case .onTarget: Theme.Color.textPrimary
        case .over: Theme.Color.danger
        }
    }

    var textColor: Color {
        switch self {
        case .onTarget, .over: Theme.Color.onAccent
        case .future: Theme.Color.textMuted
        default: Theme.Color.textPrimary
        }
    }
}

extension View {
    func uiLabelStyle(_ color: Color = Theme.Color.textSecondary) -> some View {
        font(Theme.Font.uiLabel).foregroundStyle(color)
    }

    func headlineStyle(_ font: Font = Theme.Font.headline) -> some View {
        self.font(font).textCase(.uppercase).foregroundStyle(Theme.Color.textPrimary)
    }
}
