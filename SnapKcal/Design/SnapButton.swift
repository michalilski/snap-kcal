import SwiftUI

struct SnapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "camera").font(.system(size: 22, weight: .light))
                Text("SNAP").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2)
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(SnapReticleStyle())
        .accessibilityLabel(Text("Snap a meal"))
        .accessibilityIdentifier("snapButton")
    }
}

private struct SnapReticleStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.Color.background : Theme.Color.textPrimary)
            .background(configuration.isPressed ? Theme.Color.textPrimary : Theme.Color.background)
            .overlay(Rectangle().stroke(Theme.Color.border, lineWidth: 1))
            .overlay(CornerBrackets(length: 12, color: Theme.Color.textPrimary))
            .opacity(isEnabled ? 1 : 0.35)
    }
}

struct ChevronChip: View {
    var body: some View {
        Text(">")
            .font(Theme.Font.data)
            .foregroundStyle(Theme.Color.textMuted)
            .accessibilityHidden(true)
    }
}
