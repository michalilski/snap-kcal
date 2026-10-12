import SwiftUI

struct AppButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, minimal, danger }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .minimal ? Theme.Spacing.s : Theme.Spacing.xl)
            .frame(minHeight: 44)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1.5))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Theme.Color.onAccent
        case .secondary, .minimal: Theme.Color.textPrimary
        case .danger: Theme.Color.danger
        }
    }

    private var background: Color {
        kind == .primary ? Theme.Color.accent : .clear
    }

    private var stroke: Color {
        switch kind {
        case .primary, .minimal: .clear
        case .secondary: Theme.Color.border
        case .danger: Theme.Color.danger.opacity(0.5)
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static var primary: AppButtonStyle { .init(kind: .primary) }
    static var secondary: AppButtonStyle { .init(kind: .secondary) }
    static var minimal: AppButtonStyle { .init(kind: .minimal) }
    static var danger: AppButtonStyle { .init(kind: .danger) }
}
