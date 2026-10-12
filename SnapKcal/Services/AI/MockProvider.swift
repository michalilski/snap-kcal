import Foundation

enum Fixtures {
    static let burrito = MealAnalysis(
        isFood: true,
        mealName: "Chicken burrito bowl",
        description: "Rice, grilled chicken, black beans, corn salsa and guacamole in a bowl.",
        items: [
            DetectedItem(name: "White rice", portion: "180 g", kcal: 230),
            DetectedItem(name: "Grilled chicken", portion: "120 g", kcal: 200),
            DetectedItem(name: "Black beans", portion: "80 g", kcal: 90),
            DetectedItem(name: "Guacamole", portion: "50 g", kcal: 80),
        ],
        kcalTotal: 600, kcalLow: 520, kcalHigh: 680,
        proteinG: 42, carbsG: 68, fatG: 16,
        healthScore: 7, scoreReason: "Good protein and fiber, moderate portion.",
        tip: "Add extra greens for more volume at almost no kcal.",
        confidence: .medium
    )

    static let notFood = MealAnalysis(
        isFood: false, mealName: "", description: "The photo shows a keyboard, not food.", items: [],
        kcalTotal: 0, kcalLow: 0, kcalHigh: 0, proteinG: 0, carbsG: 0, fatG: 0,
        healthScore: 1, scoreReason: "", tip: "", confidence: .high
    )
}

struct MockProvider: AIProvider {
    let provider: Provider
    var delay: Duration = .milliseconds(1200)

    func listModels(apiKey: String) async throws -> [AIModel] {
        [
            AIModel(id: "mock-fast-mini", displayName: "Mock Fast mini", provider: provider, createdAt: .now, supportsStructuredOutput: true, supportsEffort: true),
            AIModel(id: "mock-accurate", displayName: "Mock Accurate", provider: provider, createdAt: .now, supportsStructuredOutput: true, supportsEffort: true),
        ]
    }

    func analyze(imageJPEG: Data, context: AnalysisContext, model: AIModel, apiKey: String, options: AnalysisOptions) async throws -> AnalysisResult {
        try await Task.sleep(for: delay)
        let note = context.userNote?.lowercased() ?? ""
        if note.contains("fail") { throw AIError.overloaded }
        let analysis = note.contains("notfood") ? Fixtures.notFood : Fixtures.burrito
        return AnalysisResult(
            analysis: analysis, provider: provider, modelId: model.id, inputTokens: 1000, outputTokens: 200,
            latency: 1.2, rawResponse: Data()
        )
    }

    static var isEnabled: Bool {
        let info = ProcessInfo.processInfo
        return info.arguments.contains("-mockAI") || info.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
