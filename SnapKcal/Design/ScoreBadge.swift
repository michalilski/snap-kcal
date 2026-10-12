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

    var body: some View {
        Text(showsNumber ? "\(score)" : Self.grade(for: score))
            .font(.system(size: showsNumber ? 18 : 14, weight: .black))
            .foregroundStyle(Theme.Color.carbon)
            .frame(width: showsNumber ? 34 : 26, height: showsNumber ? 34 : 26)
            .background(Theme.Color.surface)
            .overlay(Rectangle().stroke(Theme.Color.carbon, lineWidth: 1.5))
            .accessibilityLabel(Text("Health score \(score) of 10"))
    }
}
