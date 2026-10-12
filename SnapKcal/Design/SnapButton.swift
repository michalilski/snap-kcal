import SwiftUI

struct SnapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.Color.onAccent)
                .frame(width: 72, height: 72)
        }
        .buttonStyle(SnapDiscStyle())
        .accessibilityLabel(Text("Snap a meal"))
        .accessibilityIdentifier("snapButton")
    }
}

private struct SnapDiscStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(Theme.Color.accent))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.35)
    }
}

struct ChevronChip: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.Color.textMuted)
            .accessibilityHidden(true)
    }
}
