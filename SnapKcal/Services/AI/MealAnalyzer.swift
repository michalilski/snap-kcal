import SwiftData
import UIKit

enum TurnOutcome: Equatable {
    case estimated
    case notFood
    case failed(String)
}

/// Orchestrates meal conversations; the only place that updates a Meal from AI output.
@MainActor
final class MealAnalyzer {
    static let notFoodMarker = "NOT_FOOD"

    private let providers: [Provider: any AIProvider]
    private let keys: KeyResolver
    private let settings: AppSettings
    private let store: MealStore
    private let catalog: ModelCatalog
    private let workouts: WorkoutCalories

    init(providers: [Provider: any AIProvider], keys: KeyResolver, settings: AppSettings, store: MealStore, catalog: ModelCatalog, workouts: WorkoutCalories) {
        self.providers = providers
        self.keys = keys
        self.settings = settings
        self.store = store
        self.catalog = catalog
        self.workouts = workouts
    }

    /// Adds a user message (photo and/or text) to the meal's conversation and asks for an updated estimate.
    func send(to meal: Meal, image: UIImage?, text: String?) async -> TurnOutcome {
        ensureFirstTurn(for: meal)
        let photo = await prepare(image, for: meal)
        _ = store.appendTurn(to: meal, text: text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty, photo: photo)
        return await rerun(meal)
    }

    /// Answers the latest turn again, e.g. after a failure or with another model.
    func rerun(_ meal: Meal, modelOverride: AIModel? = nil) async -> TurnOutcome {
        ensureFirstTurn(for: meal)
        guard let turn = meal.orderedTurns.last else { return .failed(AIError.decoding("empty conversation").userMessage) }
        let isInitial = !meal.hasEstimate
        if isInitial { meal.status = .analyzing }
        meal.errorMessage = nil
        store.save()
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "meal-analysis") {}
        defer { UIApplication.shared.endBackgroundTask(taskID) }
        let outcome: TurnOutcome
        do {
            let result = try await analyze(meal, modelOverride: modelOverride)
            if settings.saveRawResponse { saveRaw(result.rawResponse) }
            outcome = record(result, on: meal, turn: turn, isInitial: isInitial)
        } catch {
            if isInitial {
                meal.status = .failed
                meal.errorMessage = error.userMessage
            }
            outcome = .failed(error.userMessage)
        }
        store.save()
        return outcome
    }

    /// Removes an unanswered follow-up so the meal goes back to its last estimate.
    func discardPendingTurn(of meal: Meal) {
        guard meal.hasEstimate, let turn = meal.orderedTurns.last, turn.reply == nil else { return }
        store.context.delete(turn)
        store.save()
    }

    private func record(_ result: AnalysisResult, on meal: Meal, turn: MealTurn, isInitial: Bool) -> TurnOutcome {
        turn.setReply(result.analysis)
        guard result.analysis.isFood else {
            if isInitial {
                meal.status = .failed
                meal.errorMessage = Self.notFoodMarker
            }
            return .notFood
        }
        meal.apply(result)
        meal.userNote = meal.orderedTurns.compactMap(\.text).joined(separator: " · ").nilIfEmpty
        return .estimated
    }

    private func analyze(_ meal: Meal, modelOverride: AIModel?) async throws(AIError) -> AnalysisResult {
        let providerKind = modelOverride?.provider ?? settings.activeProvider
        guard let apiKey = keys.key(providerKind), let provider = providers[providerKind] else { throw .missingKey(providerKind) }
        let model = try await resolveModel(modelOverride, provider: providerKind, apiKey: apiKey)
        let context = await makeContext(for: meal)
        let turns = conversation(for: meal)
        return try await AnalysisPipeline(settings: settings).run(provider: provider, turns: turns, context: context, model: model, apiKey: apiKey)
    }

    /// All turns with their earlier answers; the last turn is always sent unanswered.
    private func conversation(for meal: Meal) -> [ConversationTurn] {
        let turns = meal.orderedTurns.map(\.conversationTurn)
        guard let last = turns.last else { return [] }
        return turns.dropLast() + [ConversationTurn(imageJPEG: last.imageJPEG, text: last.text, reply: nil)]
    }

    /// Meals logged before conversations existed get their original photo and note as turn one.
    private func ensureFirstTurn(for meal: Meal) {
        guard meal.turns.isEmpty, meal.photo != nil || meal.userNote != nil else { return }
        let turn = store.appendTurn(to: meal, text: meal.userNote, photo: meal.photo)
        if meal.hasEstimate {
            turn.setReply(MealAnalysis(meal: meal))
            store.save()
        }
    }

    private func prepare(_ image: UIImage?, for meal: Meal) async -> Data? {
        guard let image else { return nil }
        let prepared = await ImageProcessor.prepareInBackground(image, detail: settings.analysisDetail)
        if meal.photo == nil {
            meal.photo = prepared.upload
            meal.thumbnail = prepared.thumbnail
        }
        return prepared.upload
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

    private func makeContext(for meal: Meal) async -> AnalysisContext {
        await workouts.refresh(dayKey: meal.dayKey)
        let profile = store.existingProfile()
        let workoutKcal = workouts.kcal(for: meal.dayKey)
        let eaten = store.fetchMeals(dayKey: meal.dayKey)
            .filter { $0.status == .done && $0.id != meal.id }
            .reduce(0) { $0 + $1.kcal }
        return AnalysisContext(
            goal: profile?.goal ?? .maintain,
            targetKcal: NutritionCalculator.target(for: profile) + workoutKcal,
            workoutKcal: workoutKcal,
            eatenTodayKcal: eaten,
            localTime: meal.eatenAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)),
            languageName: Prompt.appLanguageName,
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

extension MealAnalysis {
    /// Rebuilds the stored estimate of a meal so it can serve as an earlier answer in the conversation.
    init(meal: Meal) {
        self.init(
            isFood: true, mealName: meal.name, description: meal.summary, items: meal.items,
            kcalTotal: meal.kcalEstimated, kcalLow: meal.kcalLow, kcalHigh: meal.kcalHigh,
            proteinG: meal.proteinG, carbsG: meal.carbsG, fatG: meal.fatG,
            healthScore: meal.healthScore, scoreReason: meal.scoreReason, tip: meal.tip, confidence: meal.confidence
        )
    }
}
