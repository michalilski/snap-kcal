import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var onboardingDone: Bool { didSet { defaults.set(onboardingDone, forKey: "onboardingDone") } }
    var activeProvider: Provider { didSet { defaults.set(activeProvider.rawValue, forKey: "activeProvider") } }
    var openAIModelId: String? { didSet { defaults.set(openAIModelId, forKey: "openAIModelId") } }
    var anthropicModelId: String? { didSet { defaults.set(anthropicModelId, forKey: "anthropicModelId") } }
    var analysisDetail: AnalysisDetail { didSet { defaults.set(analysisDetail.rawValue, forKey: "analysisDetail") } }
    var autoSave: Bool { didSet { defaults.set(autoSave, forKey: "autoSave") } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    var modelsWithoutSchema: Set<String> { didSet { defaults.set(Array(modelsWithoutSchema), forKey: "modelsWithoutSchema") } }
    var modelsWithoutWebSearch: Set<String> { didSet { defaults.set(Array(modelsWithoutWebSearch), forKey: "modelsWithoutWebSearch") } }
    var modelsWithoutReasoning: Set<String> { didSet { defaults.set(Array(modelsWithoutReasoning), forKey: "modelsWithoutReasoning") } }
    var saveRawResponse: Bool { didSet { defaults.set(saveRawResponse, forKey: "saveRawResponse") } }
    var testedModels: Set<String> { didSet { defaults.set(Array(testedModels), forKey: "testedModels") } }
    var useWorkouts: Bool { didSet { defaults.set(useWorkouts, forKey: "useWorkouts") } }
    var healthAccessRequested: Bool { didSet { defaults.set(healthAccessRequested, forKey: "healthAccessRequested") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingDone = defaults.bool(forKey: "onboardingDone")
        activeProvider = defaults.string(forKey: "activeProvider").flatMap(Provider.init) ?? .openai
        openAIModelId = defaults.string(forKey: "openAIModelId")
        anthropicModelId = defaults.string(forKey: "anthropicModelId")
        analysisDetail = defaults.string(forKey: "analysisDetail").flatMap(AnalysisDetail.init) ?? .fast
        autoSave = defaults.object(forKey: "autoSave") as? Bool ?? true
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        modelsWithoutSchema = Set(defaults.stringArray(forKey: "modelsWithoutSchema") ?? [])
        modelsWithoutWebSearch = Set(defaults.stringArray(forKey: "modelsWithoutWebSearch") ?? [])
        modelsWithoutReasoning = Set(defaults.stringArray(forKey: "modelsWithoutReasoning") ?? [])
        saveRawResponse = defaults.bool(forKey: "saveRawResponse")
        testedModels = Set(defaults.stringArray(forKey: "testedModels") ?? [])
        useWorkouts = defaults.object(forKey: "useWorkouts") as? Bool ?? true
        healthAccessRequested = defaults.bool(forKey: "healthAccessRequested")
    }

    func modelId(for provider: Provider) -> String? {
        switch provider {
        case .openai: openAIModelId
        case .anthropic: anthropicModelId
        }
    }

    func setModelId(_ id: String?, for provider: Provider) {
        switch provider {
        case .openai: openAIModelId = id
        case .anthropic: anthropicModelId = id
        }
    }

    func reset() {
        for key in defaults.dictionaryRepresentation().keys { defaults.removeObject(forKey: key) }
    }
}
