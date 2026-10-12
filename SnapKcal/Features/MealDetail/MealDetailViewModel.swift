import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class MealDetailViewModel {
    let meal: Meal?
    var isReanalyzing = false

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
        await environment.analyzer.run(meal: meal, image: nil, note: meal.userNote, modelOverride: model)
        isReanalyzing = false
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
