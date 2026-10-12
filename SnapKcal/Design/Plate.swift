import SwiftUI

struct PlateModifier: ViewModifier {
    var fill: Color = Theme.Color.periwinkle
    var padding: CGFloat = Theme.Spacing.m

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [fill.opacity(0.96), fill, fill.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                    .background(fill)
            )
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.45)).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Color.chromeIndigo).frame(height: 1) }
    }
}

extension View {
    func plate(_ fill: Color = Theme.Color.periwinkle, padding: CGFloat = Theme.Spacing.m) -> some View {
        modifier(PlateModifier(fill: fill, padding: padding))
    }
}

struct PanelTitle: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text).uiLabelStyle(Theme.Color.carbon)
    }
}
