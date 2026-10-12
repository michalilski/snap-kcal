import SwiftUI

struct PanelModifier: ViewModifier {
    var fill: Color = Theme.Color.surface
    var padding: CGFloat = Theme.Spacing.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

extension View {
    func panel(_ fill: Color = Theme.Color.surface, padding: CGFloat = Theme.Spacing.l) -> some View {
        modifier(PanelModifier(fill: fill, padding: padding))
    }
}

struct PanelTitle: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text).font(Theme.Font.section).foregroundStyle(Theme.Color.textPrimary)
    }
}
