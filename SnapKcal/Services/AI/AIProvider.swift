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
    let workoutKcal: Int
    let eatenTodayKcal: Int
    let localTime: String
    let languageName: String
    let detail: AnalysisDetail
}

/// One user message in a meal conversation plus the model's earlier answer to it (nil for the turn being analysed).
struct ConversationTurn: Sendable, Equatable {
    let imageJPEG: Data?
    let text: String?
    let reply: MealAnalysis?

    var trimmedText: String? {
        text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
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
    var useWebSearch = true
}

protocol AIProvider: Sendable {
    var provider: Provider { get }
    func listModels(apiKey: String) async throws -> [AIModel]
    func analyze(turns: [ConversationTurn], context: AnalysisContext, model: AIModel, apiKey: String, options: AnalysisOptions) async throws -> AnalysisResult
}

extension AnalysisContext {
    static let test = AnalysisContext(goal: .maintain, targetKcal: 2000, workoutKcal: 0, eatenTodayKcal: 0, localTime: "12:00", languageName: "English", detail: .fast)
}

extension ConversationTurn {
    static var testImage: ConversationTurn {
        ConversationTurn(imageJPEG: ImageProcessor.testImage(), text: nil, reply: nil)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
