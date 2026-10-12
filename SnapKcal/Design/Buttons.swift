import SwiftUI

struct ChromeButtonStyle: ButtonStyle {
    enum Kind { case primary, commit, dark, destructive }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.uiLabel)
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Spacing.l)
            .frame(minHeight: 44)
            .background(background)
            .overlay(alignment: .top) {
                if kind == .primary || kind == .commit {
                    Rectangle().fill(Color.white.opacity(0.5)).frame(height: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: kind == .dark ? 0 : Theme.Radius.button))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }

    private var foreground: Color {
        switch kind {
        case .primary, .commit: Theme.Color.carbon
        case .dark: .white
        case .destructive: Theme.Color.red
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Theme.Color.amber
        case .commit: Theme.Color.signal
        case .dark: Theme.Color.carbon
        case .destructive: Theme.Color.platinum
        }
    }
}

extension ButtonStyle where Self == ChromeButtonStyle {
    static var primary: ChromeButtonStyle { .init(kind: .primary) }
    static var commit: ChromeButtonStyle { .init(kind: .commit) }
    static var dark: ChromeButtonStyle { .init(kind: .dark) }
    static var destructive: ChromeButtonStyle { .init(kind: .destructive) }
}
