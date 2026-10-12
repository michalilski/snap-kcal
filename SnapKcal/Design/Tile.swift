import SwiftUI

struct TileModifier: ViewModifier {
    var fill: Color = Theme.Color.background
    var stroke: Color = .clear
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
        content
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(stroke, lineWidth: lineWidth))
    }
}

extension View {
    func tile(_ fill: Color = Theme.Color.background, stroke: Color = .clear) -> some View {
        modifier(TileModifier(fill: fill, stroke: stroke))
    }

    func selectableTile(_ isSelected: Bool) -> some View {
        modifier(TileModifier(
            fill: Theme.Color.background,
            stroke: isSelected ? Theme.Color.textPrimary : Theme.Color.surfaceRaised,
            lineWidth: isSelected ? 2 : 1
        ))
    }
}

struct Divider1px: View {
    var body: some View {
        Rectangle().fill(Theme.Color.surfaceRaised).frame(height: 1)
    }
}

struct ProgressBar: View {
    let progress: Double
    var color: Color = Theme.Color.textPrimary

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Color.surfaceRaised)
                Capsule()
                    .fill(color)
                    .frame(width: progress > 0 ? max(proxy.size.width * min(progress, 1), 8) : 0)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
