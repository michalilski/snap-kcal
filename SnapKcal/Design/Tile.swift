import SwiftUI

struct TileModifier: ViewModifier {
    var fill: Color = Theme.Color.surfaceRaised
    var stroke: Color = Theme.Color.border

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().stroke(stroke, lineWidth: 1))
    }
}

extension View {
    func tile(_ fill: Color = Theme.Color.surfaceRaised, stroke: Color = Theme.Color.border) -> some View {
        modifier(TileModifier(fill: fill, stroke: stroke))
    }

    func selectableTile(_ isSelected: Bool) -> some View {
        tile(isSelected ? Theme.Color.textPrimary.opacity(0.08) : Theme.Color.surface, stroke: isSelected ? Theme.Color.textPrimary : Theme.Color.border)
    }
}

struct Divider1px: View {
    var body: some View {
        Text(String(repeating: "- ", count: 80))
            .font(Theme.Font.data)
            .foregroundStyle(Theme.Color.border)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .accessibilityHidden(true)
    }
}

struct SegmentBar: View {
    let progress: Double
    var segments = 32
    var color: Color = Theme.Color.textPrimary

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                Rectangle()
                    .fill(Double(index) < progress * Double(segments) ? color : Theme.Color.surfaceRaised)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
