import Foundation
import UIKit
import Observation
import SwiftData

@Observable
@MainActor
final class MealDetailViewModel {
    let meal: Meal?
    var isReanalyzing = false
    private(set) var refineError: String?

    private let environment: AppEnvironment

    init(mealID: PersistentIdentifier, environment: AppEnvironment) {
        self.environment = environment
        meal = environment.store.meal(id: mealID)
    }

    var availableModels: [AIModel] {
        Provider.allCases
            .filter { environment.apiKey(for: $0) != nil }
            .flatMap { environment.catalog.cached($0) }
    }

    func rename(_ name: String) {
        guard let meal, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        meal.name = name
        save()
    }

    func setKcal(_ kcal: Int) {
        meal?.setManualKcal(kcal)
        save()
    }

    func resetToEstimate() {
        meal?.resetToEstimate()
        save()
    }

    func move(to date: Date) {
        meal?.move(to: date)
        save()
    }

    func reanalyze(with model: AIModel) async {
        guard let meal else { return }
        isReanalyzing = true
        finish(await environment.analyzer.rerun(meal, modelOverride: model))
    }

    func sendFollowUp(image: UIImage?, text: String) async {
        guard let meal, !isReanalyzing else { return }
        isReanalyzing = true
        refineError = nil
        finish(await environment.analyzer.send(to: meal, image: image, text: text))
    }

    func retryFollowUp() async {
        guard let meal, !isReanalyzing else { return }
        isReanalyzing = true
        refineError = nil
        finish(await environment.analyzer.rerun(meal))
    }

    func discardFollowUp() {
        guard let meal else { return }
        environment.analyzer.discardPendingTurn(of: meal)
        refineError = nil
        environment.dataChanged()
    }

    private func finish(_ outcome: TurnOutcome) {
        isReanalyzing = false
        switch outcome {
        case .estimated: refineError = nil
        case .notFood: refineError = String(localized: "That doesn't look like food, so the estimate is unchanged.")
        case .failed(let message): refineError = message
        }
        environment.dataChanged()
    }

    func delete() {
        guard let meal else { return }
        environment.store.delete(meal)
        environment.dataChanged()
    }

    private func save() {
        environment.store.save()
        environment.dataChanged()
    }
}
