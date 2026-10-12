import SwiftData
import UIKit

@MainActor
final class MealAnalyzer {
    static let notFoodMarker = "NOT_FOOD"

    private let providers: [Provider: any AIProvider]
    private let keys: KeyResolver
    private let settings: AppSettings
    private let store: MealStore
    private let catalog: ModelCatalog

    init(providers: [Provider: any AIProvider], keys: KeyResolver, settings: AppSettings, store: MealStore, catalog: ModelCatalog) {
        self.providers = providers
        self.keys = keys
        self.settings = settings
        self.store = store
        self.catalog = catalog
    }

    /// Runs analysis for a meal already inserted with status .analyzing. Never throws: writes .done or .failed to the meal.
    func run(meal: Meal, image: UIImage?, note: String?, modelOverride: AIModel? = nil) async {
        meal.status = .analyzing
        meal.errorMessage = nil
        meal.userNote = note?.isEmpty == true ? nil : note
        store.save()
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "meal-analysis") {}
        defer { UIApplication.shared.endBackgroundTask(taskID) }
        do {
            let result = try await analyze(meal: meal, image: image, note: note, modelOverride: modelOverride)
            if settings.saveRawResponse { saveRaw(result.rawResponse) }
            if result.analysis.isFood {
                meal.apply(result)
            } else {
                meal.status = .failed
                meal.errorMessage = Self.notFoodMarker
            }
        } catch {
            meal.status = .failed
            meal.errorMessage = error.userMessage
        }
        store.save()
    }

    private func analyze(meal: Meal, image: UIImage?, note: String?, modelOverride: AIModel?) async throws(AIError) -> AnalysisResult {
        let providerKind = modelOverride?.provider ?? settings.activeProvider
        guard let apiKey = keys.key(providerKind), let provider = providers[providerKind] else { throw .missingKey(providerKind) }
        let model = try await resolveModel(modelOverride, provider: providerKind, apiKey: apiKey)
        let upload = try await uploadData(for: meal, image: image)
        let context = makeContext(for: meal, note: note)
        return try await AnalysisPipeline(settings: settings).run(provider: provider, image: upload, context: context, model: model, apiKey: apiKey)
    }

    private func resolveModel(_ override: AIModel?, provider: Provider, apiKey: String) async throws(AIError) -> AIModel {
        if let override { return override }
        if let id = settings.modelId(for: provider) { return catalog.model(id: id, provider: provider) }
        let models: [AIModel]
        do {
            models = try await catalog.models(provider, apiKey: apiKey)
        } catch let error as AIError {
            throw error
        } catch {
            throw .missingModel(provider)
        }
        guard let model = ModelCatalog.preferredDefault(from: models) else { throw .missingModel(provider) }
        settings.setModelId(model.id, for: provider)
        return model
    }

    private func uploadData(for meal: Meal, image: UIImage?) async throws(AIError) -> Data {
        if let image {
            let prepared = await ImageProcessor.prepareInBackground(image, detail: settings.analysisDetail)
            meal.photo = prepared.upload
            meal.thumbnail = prepared.thumbnail
            store.save()
            return prepared.upload
        }
        guard let photo = meal.photo else { throw .decoding("photo missing") }
        return photo
    }

    private func makeContext(for meal: Meal, note: String?) -> AnalysisContext {
        let profile = store.existingProfile()
        let eaten = store.fetchMeals(dayKey: meal.dayKey)
            .filter { $0.status == .done && $0.id != meal.id }
            .reduce(0) { $0 + $1.kcal }
        let time = meal.eatenAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return AnalysisContext(
            goal: profile?.goal ?? .maintain,
            targetKcal: NutritionCalculator.target(for: profile),
            eatenTodayKcal: eaten,
            localTime: time,
            languageName: Prompt.deviceLanguageName,
            userNote: note,
            detail: settings.analysisDetail
        )
    }

    private func saveRaw(_ data: Data) {
        guard !data.isEmpty else { return }
        try? data.write(to: URL.documentsDirectory.appending(path: "last-raw-response.json"), options: .atomic)
    }
}

@MainActor
struct KeyResolver {
    let key: (Provider) -> String?
}
