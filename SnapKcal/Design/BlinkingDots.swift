import SwiftUI

struct BlinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.35) % 3
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.Color.amber)
                        .frame(width: 8, height: 8)
                        .opacity(reduceMotion || index == phase ? 1 : 0.3)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct LoadingLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(text).uiLabelStyle()
            BlinkingDots()
        }
    }
}
