import SwiftUI

struct OutlinedText: View {
    let text: String
    var font: Font = Theme.Font.display
    var fill: Color = Theme.Color.surface
    var outline: Color = Theme.Color.carbon

    private static let offsets: [CGSize] = [
        .init(width: -2, height: 0), .init(width: 2, height: 0), .init(width: 0, height: -2), .init(width: 0, height: 2),
        .init(width: -1.5, height: -1.5), .init(width: 1.5, height: -1.5), .init(width: -1.5, height: 1.5), .init(width: 1.5, height: 1.5),
    ]

    var body: some View {
        ZStack {
            Text(text).font(font).foregroundStyle(outline).offset(x: 2, y: 3)
            ForEach(Self.offsets.indices, id: \.self) { index in
                Text(text).font(font).foregroundStyle(outline).offset(Self.offsets[index])
            }
            Text(text).font(font).foregroundStyle(fill)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
