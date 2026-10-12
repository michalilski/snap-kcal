import UIKit

@MainActor
struct Haptics {
    let settings: AppSettings

    func snap() {
        guard settings.haptics else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func success() {
        guard settings.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func error() {
        guard settings.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

extension Haptics {
    func notify(success isSuccess: Bool) {
        isSuccess ? success() : error()
    }
}
