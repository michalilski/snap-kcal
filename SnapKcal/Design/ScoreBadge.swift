import SwiftUI

struct ScoreBadge: View {
    let score: Int
    var showsNumber = false

    static func grade(for score: Int) -> String {
        switch score {
        case 9...: "A"
        case 7...8: "B"
        case 5...6: "C"
        case 3...4: "D"
        default: "E"
        }
    }

    static func color(for score: Int) -> Color {
        switch score {
        case 7...: Theme.Color.success
        case 5...6: Theme.Color.textPrimary
        default: Theme.Color.danger
        }
    }

    var body: some View {
        Text(showsNumber ? "\(score)/10" : Self.grade(for: score))
            .font(.system(size: 13, weight: .heavy).width(.condensed))
            .foregroundStyle(Self.color(for: score))
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(Theme.Color.background, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Color.surfaceRaised, lineWidth: 1))
            .accessibilityLabel(Text("Health score \(score) of 10"))
    }
}

struct Tag: View {
    let text: String
    var color: Color = Theme.Color.textPrimary

    var body: some View {
        Text(text)
            .font(Theme.Font.data)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Color.background, in: Capsule())
    }
}
