import SwiftUI

struct SnapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
        }
        .buttonStyle(SnapDiscStyle())
        .accessibilityLabel(Text("Snap a meal"))
        .accessibilityIdentifier("snapButton")
    }
}

private struct SnapDiscStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(Theme.Color.signal))
            .overlay(Circle().fill(Color.black.opacity(configuration.isPressed ? 0.08 : 0)))
            .overlay(Circle().stroke(Theme.Color.chromeIndigo, lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
    }
}

struct ChevronChip: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(Theme.Color.carbon)
            .frame(width: 20, height: 20)
            .background(Circle().fill(Theme.Color.signal))
            .accessibilityHidden(true)
    }
}
