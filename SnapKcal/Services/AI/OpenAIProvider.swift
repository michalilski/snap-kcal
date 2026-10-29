import Foundation

enum OpenAIRequests {
    static let baseURL = URL(string: "https://api.openai.com/v1")!

    static func models(apiKey: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "models"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    static func analyze(turns: [ConversationTurn], context: AnalysisContext, modelId: String, apiKey: String, options: AnalysisOptions) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "responses"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "model": modelId,
            "instructions": Prompt.system(language: context.languageName, includeSchema: !options.useSchema, webSearch: options.useWebSearch),
            "input": input(turns: turns, context: context),
            "max_output_tokens": 4000,
            "store": false,
        ]
        if options.useWebSearch {
            body["tools"] = [["type": "web_search"]]
        }
        if options.useSchema {
            body["text"] = ["format": ["type": "json_schema", "name": "meal_analysis", "strict": true, "schema": MealSchema.schema]]
        }
        if options.useEffort {
            body["reasoning"] = ["effort": "low"]
        }
        request.httpBody = HTTPClient.jsonBody(body)
        return request
    }

    static func input(turns: [ConversationTurn], context: AnalysisContext) -> [[String: Any]] {
        turns.enumerated().flatMap { index, turn -> [[String: Any]] in
            var content: [[String: Any]] = []
            if let image = turn.imageJPEG {
                content.append([
                    "type": "input_image",
                    "image_url": "data:image/jpeg;base64,\(image.base64EncodedString())",
                    "detail": context.detail == .fast ? "low" : "auto",
                ])
            }
            content.append(["type": "input_text", "text": Prompt.userText(for: turn, isFirst: index == 0, context: context)])
            var messages: [[String: Any]] = [["role": "user", "content": content]]
            if let reply = turn.reply {
                messages.append(["role": "assistant", "content": [["type": "output_text", "text": reply.schemaJSONString]]])
            }
            return messages
        }
    }

    static func isReasoningModel(_ id: String) -> Bool {
        let lowered = id.lowercased()
        return (lowered.first == "o" && lowered.dropFirst().first?.isNumber == true) || lowered.hasPrefix("gpt-5")
    }
}

enum OpenAIParser {
    static func parse(_ data: Data) throws(AIError) -> (MealAnalysis, OAIUsage?) {
        let response: OAIResponse
        do {
            response = try DTODecoder.decode(OAIResponse.self, from: data)
        } catch {
            throw .decoding("unexpected response shape")
        }
        if response.status == "incomplete" { throw .truncated }
        guard let message = response.output.last(where: { $0.type == "message" }) else {
            throw .decoding("no message output")
        }
        let parts = message.content ?? []
        if parts.contains(where: { $0.type == "refusal" }) { throw .refused }
        let text = parts.filter { $0.type == "output_text" }.compactMap(\.text).joined()
        return (try MealAnalysis.decode(text: text), response.usage)
    }
}

struct OpenAIProvider: AIProvider {
    let provider = Provider.openai
    var client = HTTPClient.shared

    func listModels(apiKey: String) async throws -> [AIModel] {
        let data = try await client.send(OpenAIRequests.models(apiKey: apiKey))
        do {
            return ModelFilter.openAI(try DTODecoder.decode(OAIModelList.self, from: data).data, now: .now)
        } catch {
            throw AIError.decoding("model list")
        }
    }

    func analyze(turns: [ConversationTurn], context: AnalysisContext, model: AIModel, apiKey: String, options: AnalysisOptions) async throws -> AnalysisResult {
        let started = Date.now
        let request = OpenAIRequests.analyze(turns: turns, context: context, modelId: model.id, apiKey: apiKey, options: options)
        let data = try await client.send(request, modelId: model.id)
        let (analysis, usage) = try OpenAIParser.parse(data)
        return AnalysisResult(
            analysis: analysis.sanitized(), provider: .openai, modelId: model.id,
            inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens,
            latency: Date.now.timeIntervalSince(started), rawResponse: data
        )
    }
}
