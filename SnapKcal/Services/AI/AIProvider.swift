import Foundation

struct AIModel: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let provider: Provider
    let createdAt: Date?
    let supportsStructuredOutput: Bool?
    let supportsEffort: Bool?

    var isFastHint: Bool { ["mini", "nano", "haiku", "flash"].contains { id.lowercased().contains($0) } }

    static func manual(_ id: String, provider: Provider) -> AIModel {
        AIModel(id: id, displayName: id, provider: provider, createdAt: nil, supportsStructuredOutput: nil, supportsEffort: nil)
    }
}

struct AnalysisContext: Sendable {
    let goal: Goal
    let targetKcal: Int
    let eatenTodayKcal: Int
    let localTime: String
    let languageName: String
    let userNote: String?
    let detail: AnalysisDetail
}

struct AnalysisResult: Sendable {
    let analysis: MealAnalysis
    let provider: Provider
    let modelId: String
    let inputTokens: Int?
    let outputTokens: Int?
    let latency: TimeInterval
    let rawResponse: Data
}

struct AnalysisOptions: Sendable {
    var useSchema: Bool
    var useEffort: Bool
}

protocol AIProvider: Sendable {
    var provider: Provider { get }
    func listModels(apiKey: String) async throws -> [AIModel]
    func analyze(imageJPEG: Data, context: AnalysisContext, model: AIModel, apiKey: String, options: AnalysisOptions) async throws -> AnalysisResult
}

extension AIProvider {
    func test(model: AIModel, apiKey: String, options: AnalysisOptions) async throws -> AnalysisResult {
        let context = AnalysisContext(goal: .maintain, targetKcal: 2000, eatenTodayKcal: 0, localTime: "12:00", languageName: "English", userNote: nil, detail: .fast)
        return try await analyze(imageJPEG: ImageProcessor.testImage(), context: context, model: model, apiKey: apiKey, options: options)
    }
}
