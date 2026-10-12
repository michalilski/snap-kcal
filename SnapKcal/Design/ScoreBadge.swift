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
        case 7...: Theme.Color.textPrimary
        case 5...6: Theme.Color.textSecondary
        default: Theme.Color.danger
        }
    }

    var body: some View {
        Text(showsNumber ? String(format: "%02d/10", score) : "[\(Self.grade(for: score))]")
            .font(Theme.Font.data.weight(.semibold))
            .foregroundStyle(Self.color(for: score))
            .accessibilityLabel(Text("Health score \(score) of 10"))
    }
}

struct Tag: View {
    let text: String
    var color: Color = Theme.Color.textSecondary

    var body: some View {
        Text(text)
            .font(Theme.Font.data)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(Rectangle().stroke(Theme.Color.border, lineWidth: 1))
    }
}
