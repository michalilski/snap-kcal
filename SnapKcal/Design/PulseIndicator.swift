import SwiftUI

struct PulseIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let frames = ["[■□□□]", "[□■□□]", "[□□■□]", "[□□□■]"]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
            let frame = Int(timeline.date.timeIntervalSinceReferenceDate / 0.2) % Self.frames.count
            Text(Self.frames[reduceMotion ? 0 : frame])
                .font(Theme.Font.data)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .accessibilityHidden(true)
    }
}

struct LoadingLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            PulseIndicator()
            Text(text).uiLabelStyle()
        }
    }
}
