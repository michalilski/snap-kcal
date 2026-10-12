import SwiftUI

struct PulseIndicator: View {
    var body: some View {
        ProgressView()
            .tint(Theme.Color.textPrimary)
            .accessibilityHidden(true)
    }
}

struct LoadingLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            PulseIndicator()
            Text(text).font(Theme.Font.link).foregroundStyle(Theme.Color.textPrimary)
        }
    }
}
