import Foundation

enum AnthropicRequests {
    static let baseURL = URL(string: "https://api.anthropic.com/v1")!
    static let version = "2023-06-01"

    static func models(apiKey: String, afterId: String?) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: "models"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: "1000")] + (afterId.map { [URLQueryItem(name: "after_id", value: $0)] } ?? [])
        var request = URLRequest(url: components.url!)
        authorize(&request, apiKey: apiKey)
        return request
    }

    static func analyze(turns: [ConversationTurn], context: AnalysisContext, modelId: String, apiKey: String, useSchema: Bool, useEffort: Bool) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "messages"))
        request.httpMethod = "POST"
        authorize(&request, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = [
            "model": modelId,
            "max_tokens": 1024,
            "system": Prompt.system(language: context.languageName, includeSchema: !useSchema),
            "messages": messages(turns: turns, context: context),
        ]
        var outputConfig: [String: Any] = [:]
        if useSchema { outputConfig["format"] = ["type": "json_schema", "schema": MealSchema.schema] }
        if useEffort { outputConfig["effort"] = "low" }
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
        if response.stopReason == "max_tokens" { throw .truncated }
        if response.stopReason == "refusal" { throw .refused }
        let text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        return (try MealAnalysis.decode(text: text), response.usage)
    }
}

struct AnthropicProvider: AIProvider {
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
        let request = AnthropicRequests.analyze(
            turns: turns, context: context, modelId: model.id, apiKey: apiKey,
            useSchema: options.useSchema, useEffort: options.useEffort
        )
        let data = try await client.send(request, modelId: model.id)
        let (analysis, usage) = try AnthropicParser.parse(data)
        return AnalysisResult(
            analysis: analysis.sanitized(), provider: .anthropic, modelId: model.id,
            inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens,
            latency: Date.now.timeIntervalSince(started), rawResponse: data
        )
    }
}
