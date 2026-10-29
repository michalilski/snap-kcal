import Foundation

enum AnthropicRequests {
    static let baseURL = URL(string: "https://api.anthropic.com/v1")!
    static let version = "2023-06-01"
    static var webSearchTool: [String: Any] { ["type": "web_search_20250305", "name": "web_search", "max_uses": 3] }

    static func models(apiKey: String, afterId: String?) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: "models"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: "1000")] + (afterId.map { [URLQueryItem(name: "after_id", value: $0)] } ?? [])
        var request = URLRequest(url: components.url!)
        authorize(&request, apiKey: apiKey)
        return request
    }

    /// `pausedContent` is the assistant content of a `pause_turn` response, sent back so the server resumes its search loop.
    static func analyze(turns: [ConversationTurn], context: AnalysisContext, modelId: String, apiKey: String, options: AnalysisOptions, pausedContent: [Any]? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "messages"))
        request.httpMethod = "POST"
        authorize(&request, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        var conversation = messages(turns: turns, context: context)
        if let pausedContent { conversation.append(["role": "assistant", "content": pausedContent]) }
        var body: [String: Any] = [
            "model": modelId,
            "max_tokens": 4096,
            "system": Prompt.system(language: context.languageName, includeSchema: !options.useSchema, webSearch: options.useWebSearch),
            "messages": conversation,
        ]
        if options.useWebSearch { body["tools"] = [webSearchTool] }
        var outputConfig: [String: Any] = [:]
        if options.useSchema { outputConfig["format"] = ["type": "json_schema", "schema": MealSchema.schema] }
        if options.useEffort { outputConfig["effort"] = "low" }
        if !outputConfig.isEmpty { body["output_config"] = outputConfig }
        request.httpBody = HTTPClient.jsonBody(body)
        return request
    }

    static func messages(turns: [ConversationTurn], context: AnalysisContext) -> [[String: Any]] {
        turns.enumerated().flatMap { index, turn -> [[String: Any]] in
            var content: [[String: Any]] = []
            if let image = turn.imageJPEG {
                content.append(["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": image.base64EncodedString()]])
            }
            content.append(["type": "text", "text": Prompt.userText(for: turn, isFirst: index == 0, context: context)])
            var messages: [[String: Any]] = [["role": "user", "content": content]]
            if let reply = turn.reply {
                messages.append(["role": "assistant", "content": [["type": "text", "text": reply.schemaJSONString]]])
            }
            return messages
        }
    }

    private static func authorize(_ request: inout URLRequest, apiKey: String) {
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(version, forHTTPHeaderField: "anthropic-version")
    }
}

enum AnthropicParser {
    static func parse(_ data: Data) throws(AIError) -> (MealAnalysis, AnthUsage?) {
        let response: AnthResponse
        do {
            response = try DTODecoder.decode(AnthResponse.self, from: data)
        } catch {
            throw .decoding("unexpected response shape")
        }
        if response.stopReason == "max_tokens" || response.stopReason == "pause_turn" { throw .truncated }
        if response.stopReason == "refusal" { throw .refused }
        let answer = response.content.reversed().prefix { $0.type == "text" }.reversed()
        return (try MealAnalysis.decode(text: answer.compactMap(\.text).joined()), response.usage)
    }

    /// Content of a response the server paused mid web-search loop, or nil when the turn is finished.
    static func pausedContent(_ data: Data) -> [Any]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["stop_reason"] as? String == "pause_turn" else { return nil }
        return json["content"] as? [Any]
    }
}

struct AnthropicProvider: AIProvider {
    static let maxContinuations = 2

    let provider = Provider.anthropic
    var client = HTTPClient.shared

    func listModels(apiKey: String) async throws -> [AIModel] {
        var all: [AnthModel] = []
        var afterId: String?
        repeat {
            let data = try await client.send(AnthropicRequests.models(apiKey: apiKey, afterId: afterId))
            guard let page = try? DTODecoder.decode(AnthModelList.self, from: data) else { throw AIError.decoding("model list") }
            all += page.data
            afterId = page.hasMore == true ? page.lastId : nil
        } while afterId != nil
        return ModelFilter.anthropic(all)
    }

    func analyze(turns: [ConversationTurn], context: AnalysisContext, model: AIModel, apiKey: String, options: AnalysisOptions) async throws -> AnalysisResult {
        let started = Date.now
        let data = try await send(turns: turns, context: context, model: model, apiKey: apiKey, options: options)
        let (analysis, usage) = try AnthropicParser.parse(data)
        return AnalysisResult(
            analysis: analysis.sanitized(), provider: .anthropic, modelId: model.id,
            inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens,
            latency: Date.now.timeIntervalSince(started), rawResponse: data
        )
    }

    private func send(turns: [ConversationTurn], context: AnalysisContext, model: AIModel, apiKey: String, options: AnalysisOptions) async throws -> Data {
        var paused: [Any]?
        var continuations = 0
        while true {
            let request = AnthropicRequests.analyze(
                turns: turns, context: context, modelId: model.id, apiKey: apiKey, options: options, pausedContent: paused
            )
            let data = try await client.send(request, modelId: model.id)
            guard let content = AnthropicParser.pausedContent(data), continuations < Self.maxContinuations else { return data }
            paused = (paused ?? []) + content
            continuations += 1
        }
    }
}
