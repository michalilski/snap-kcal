import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    static let stepCount = 4

    var step = 0
    var draft = ProfileDraft()

    private let store: MealStore
    private let settings: AppSettings

    init(store: MealStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    var targets: NutritionCalculator.Targets { draft.targets }

    var canContinue: Bool {
        step == 0 ? draft.isValid : true
    }

    var isLastStep: Bool { step == Self.stepCount - 1 }

    func next() {
        guard canContinue else { return }
        if isLastStep { finish() } else { step += 1 }
    }

    func back() {
        step = max(step - 1, 0)
    }

    func finish() {
        store.saveProfile(draft)
        if store.weightCount() == 0 { store.appendWeight(draft.weightKg) }
        settings.onboardingDone = true
    }
}
