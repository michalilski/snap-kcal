import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    enum TestState: Equatable {
        case idle, running
        case ok(TimeInterval)
        case failed(String)
    }

    var keys: [Provider: String] = [:]
    var models: [Provider: [AIModel]] = [:]
    var loading: [Provider: Bool] = [:]
    var loadError: [Provider: String] = [:]
    var testState = TestState.idle
    var draft: ProfileDraft

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        draft = environment.store.existingProfile()?.draft ?? ProfileDraft()
        for provider in Provider.allCases {
            models[provider] = environment.catalog.cached(provider)
        }
        reloadMaskedKeys()
    }

    var settings: AppSettings { environment.settings }
    var isMock: Bool { environment.isMock }
    var targets: NutritionCalculator.Targets { draft.targets }

    func hasKey(_ provider: Provider) -> Bool {
        !(environment.apiKey(for: provider) ?? "").isEmpty
    }

    func setKey(_ raw: String, for provider: Provider) {
        environment.keychain.setKey(raw, for: provider)
        reloadMaskedKeys()
        testState = .idle
        if !raw.isEmpty { Task { await refreshModels(provider) } }
    }

    func refreshModels(_ provider: Provider, force: Bool = false) async {
        guard let key = environment.apiKey(for: provider), !key.isEmpty else {
            loadError[provider] = AIError.missingKey(provider).userMessage
            return
        }
        loading[provider] = true
        defer { loading[provider] = false }
        do {
            let list = try await environment.catalog.models(provider, apiKey: key, forceRefresh: force)
            models[provider] = list
            loadError[provider] = nil
            if settings.modelId(for: provider) == nil, let preferred = ModelCatalog.preferredDefault(from: list) {
                settings.setModelId(preferred.id, for: provider)
            }
        } catch let error as AIError {
            loadError[provider] = error.userMessage
        } catch {
            loadError[provider] = error.localizedDescription
        }
    }

    func selectModel(_ model: AIModel) {
        settings.setModelId(model.id, for: model.provider)
        testState = .idle
    }

    func selectedModel(_ provider: Provider) -> AIModel? {
        settings.modelId(for: provider).map { environment.catalog.model(id: $0, provider: provider) }
    }

    func testActiveModel() async {
        let provider = settings.activeProvider
        guard let key = environment.apiKey(for: provider), !key.isEmpty, let source = environment.providers[provider] else {
            testState = .failed(AIError.missingKey(provider).userMessage)
            return
        }
        guard let model = selectedModel(provider) else {
            testState = .failed(AIError.missingModel(provider).userMessage)
            return
        }
        testState = .running
        let started = Date.now
        do {
            let pipeline = AnalysisPipeline(settings: settings)
            _ = try await pipeline.run(provider: source, turns: [.testImage], context: .test, model: model, apiKey: key)
            settings.testedModels.insert(model.id)
            testState = .ok(Date.now.timeIntervalSince(started))
        } catch {
            testState = .failed([error.userMessage, error.detail].compactMap { $0 }.joined(separator: "\n"))
        }
    }

    func connectHealth() async {
        await environment.workouts.requestAccess()
        await environment.workouts.refresh(dayKey: DayKey.key(for: .now))
        environment.dataChanged()
    }

    var todayWorkoutKcal: Int {
        environment.workouts.kcal(for: DayKey.key(for: .now))
    }

    func updateProfile() {
        guard draft.isValid else { return }
        environment.store.saveProfile(draft)
        environment.dataChanged()
    }

    func exportJSON() -> URL {
        ExportService.write(ExportService.json(meals: environment.store.allMeals(), profile: environment.store.existingProfile()), name: "snap-kcal.json")
    }

    func exportCSV() -> URL {
        ExportService.write(ExportService.csv(meals: environment.store.allMeals()), name: "snap-kcal.csv")
    }

    func deleteAllData() {
        environment.store.deleteAll()
        for provider in Provider.allCases { environment.keychain.setKey(nil, for: provider) }
        settings.onboardingDone = false
        environment.dataChanged()
    }

    private func reloadMaskedKeys() {
        for provider in Provider.allCases {
            keys[provider] = environment.isMock ? "mock" : KeychainStore.masked(environment.keychain.key(for: provider))
        }
    }
}
