import SwiftUI

struct MetricText: View {
    let text: String
    var font: Font = Theme.Font.display
    var color: Color = Theme.Color.textPrimary

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
