import SwiftUI

struct PanelModifier: ViewModifier {
    var fill: Color = Theme.Color.surface
    var padding: CGFloat = Theme.Spacing.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .overlay(Rectangle().stroke(Theme.Color.border, lineWidth: 1))
            .overlay(CornerBrackets())
    }
}

struct CornerBrackets: View {
    var length: CGFloat = 8
    var color: Color = Theme.Color.textSecondary

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let l = length
            path.move(to: .init(x: 0, y: l)); path.addLine(to: .zero); path.addLine(to: .init(x: l, y: 0))
            path.move(to: .init(x: size.width - l, y: 0)); path.addLine(to: .init(x: size.width, y: 0)); path.addLine(to: .init(x: size.width, y: l))
            path.move(to: .init(x: size.width, y: size.height - l)); path.addLine(to: .init(x: size.width, y: size.height)); path.addLine(to: .init(x: size.width - l, y: size.height))
            path.move(to: .init(x: l, y: size.height)); path.addLine(to: .init(x: 0, y: size.height)); path.addLine(to: .init(x: 0, y: size.height - l))
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
        HStack(spacing: Theme.Spacing.xs) {
            Text("//").uiLabelStyle(Theme.Color.textMuted)
            Text(text).uiLabelStyle()
        }
    }
}
