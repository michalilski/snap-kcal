import SwiftUI

struct AppButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, minimal, danger }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("[")
            configuration.label
            Text("]")
        }
        .font(.system(.caption, design: .monospaced, weight: .semibold))
        .tracking(1)
        .textCase(.uppercase)
        .foregroundStyle(foreground(pressed: configuration.isPressed))
        .padding(.horizontal, Theme.Spacing.m)
        .frame(minHeight: 40)
        .background(background(pressed: configuration.isPressed))
        .overlay(Rectangle().stroke(stroke, lineWidth: 1))
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.35)
    }

    private func foreground(pressed: Bool) -> Color {
        switch kind {
        case .primary: pressed ? Theme.Color.textPrimary : Theme.Color.background
        case .secondary, .minimal: pressed ? Theme.Color.background : Theme.Color.textPrimary
        case .danger: Theme.Color.danger
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: pressed ? Theme.Color.background : Theme.Color.textPrimary
        case .secondary, .minimal: pressed ? Theme.Color.textPrimary : .clear
        case .danger: pressed ? Theme.Color.danger.opacity(0.2) : .clear
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary: Theme.Color.textPrimary
        case .secondary: Theme.Color.textSecondary
        case .minimal: .clear
        case .danger: Theme.Color.danger.opacity(0.6)
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static var primary: AppButtonStyle { .init(kind: .primary) }
    static var secondary: AppButtonStyle { .init(kind: .secondary) }
    static var minimal: AppButtonStyle { .init(kind: .minimal) }
    static var danger: AppButtonStyle { .init(kind: .danger) }
}
