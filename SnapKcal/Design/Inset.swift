import SwiftUI

struct InsetModifier: ViewModifier {
    var fill: Color = Theme.Color.platinum
    var radius: CGFloat = Theme.Radius.row

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Color.chromeIndigo).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.6)).frame(height: 1) }
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

extension View {
    func inset(_ fill: Color = Theme.Color.platinum, radius: CGFloat = Theme.Radius.row) -> some View {
        modifier(InsetModifier(fill: fill, radius: radius))
    }
}

struct DottedDivider: View {
    var body: some View {
        Line()
            .stroke(Theme.Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: .init(x: 0, y: rect.midY)); $0.addLine(to: .init(x: rect.maxX, y: rect.midY)) }
        }
    }
}
