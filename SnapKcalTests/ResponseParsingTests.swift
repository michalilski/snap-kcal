import Foundation
import Testing
@testable import SnapKcal

struct ResponseParsingTests {
    @Test func openAISuccess() throws {
        let (analysis, usage) = try OpenAIParser.parse(Fixture.data("openai_response"))
        #expect(analysis.mealName == "Chicken burrito bowl")
        #expect(analysis.kcalTotal == 600)
        #expect(analysis.items.count == 4)
        #expect(analysis.confidence == .medium)
        #expect(usage?.inputTokens == 812)
        #expect(usage?.outputTokens == 164)
    }

    @Test func openAIRefusal() {
        let json = #"{"status":"completed","output":[{"type":"message","content":[{"type":"refusal","refusal":"I can't help"}]}]}"#
        #expect(throws: AIError.refused) { try OpenAIParser.parse(Data(json.utf8)) }
    }

    @Test func openAIIncomplete() {
        let json = #"{"status":"incomplete","output":[],"incomplete_details":{"reason":"max_output_tokens"}}"#
        #expect(throws: AIError.truncated) { try OpenAIParser.parse(Data(json.utf8)) }
    }

    @Test func openAINoMessage() {
        let json = #"{"status":"completed","output":[{"type":"reasoning"}]}"#
        #expect(throws: AIError.decoding("no message output")) { try OpenAIParser.parse(Data(json.utf8)) }
    }

    @Test func anthropicSuccess() throws {
        let (analysis, usage) = try AnthropicParser.parse(Fixture.data("anthropic_response"))
        #expect(analysis.kcalHigh == 680)
        #expect(usage?.inputTokens == 1020)
    }

    @Test func anthropicMaxTokens() {
        let json = #"{"content":[{"type":"text","text":"{\"is_food\":"}],"stop_reason":"max_tokens"}"#
        #expect(throws: AIError.truncated) { try AnthropicParser.parse(Data(json.utf8)) }
    }

    @Test func anthropicReadsAnswerAfterWebSearch() throws {
        let answer = String(decoding: Fixture.data("analysis_burrito"), as: UTF8.self)
        let response: [String: Any] = [
            "content": [
                ["type": "text", "text": "Looking up {brand} values."],
                ["type": "server_tool_use", "id": "srv_1", "name": "web_search", "input": ["query": "x"]],
                ["type": "web_search_tool_result", "tool_use_id": "srv_1", "content": []],
                ["type": "text", "text": answer],
            ],
            "stop_reason": "end_turn",
        ]
        let data = try JSONSerialization.data(withJSONObject: response)
        #expect(try AnthropicParser.parse(data).0.kcalTotal == 600)
    }

    @Test func anthropicPausedTurn() throws {
        let json = #"{"content":[{"type":"server_tool_use","id":"srv_1","name":"web_search","input":{}}],"stop_reason":"pause_turn"}"#
        #expect(AnthropicParser.pausedContent(Data(json.utf8))?.count == 1)
        #expect(AnthropicParser.pausedContent(Fixture.data("anthropic_response")) == nil)
        #expect(throws: AIError.truncated) { try AnthropicParser.parse(Data(json.utf8)) }
    }

    @Test func anthropicRefusal() {
        let json = #"{"content":[],"stop_reason":"refusal"}"#
        #expect(throws: AIError.refused) { try AnthropicParser.parse(Data(json.utf8)) }
    }

    @Test func fallbackJSONExtraction() throws {
        let analysis = String(decoding: Fixture.data("analysis_burrito"), as: UTF8.self)
        let wrapped = "Sure! Here is the result:\n```json\n\(analysis)\n```\nEnjoy."
        #expect(try MealAnalysis.decode(text: wrapped).kcalTotal == 600)
    }

    @Test func fallbackWithoutJSONFails() {
        #expect(throws: AIError.self) { try MealAnalysis.decode(text: "no json here") }
    }

    @Test func errorEnvelopes() {
        #expect(DTODecoder.errorMessage(from: Fixture.data("openai_error_401"))?.hasPrefix("Incorrect API key") == true)
        #expect(DTODecoder.errorMessage(from: Fixture.data("anthropic_error_429"))?.contains("rate limit") == true)
    }

    @Test(arguments: [
        (401, AIError.invalidKey), (403, .invalidKey), (404, .modelUnavailable("m")),
        (429, .rateLimited(retryAfter: nil)), (500, .overloaded), (529, .overloaded),
    ])
    func statusMapping(status: Int, expected: AIError) {
        #expect(AIError.from(status: status, message: nil, modelId: "m", retryAfter: nil) == expected)
    }

    @Test func badRequestModelNotFound() {
        #expect(AIError.from(status: 400, message: "The model `x` does not exist", modelId: "x", retryAfter: nil) == .modelUnavailable("x"))
    }

    @Test func urlErrors() {
        #expect(AIError.from(urlError: URLError(.timedOut)) == .timeout)
        #expect(AIError.from(urlError: URLError(.notConnectedToInternet)) == .offline)
        #expect(AIError.from(urlError: URLError(.networkConnectionLost)) == .offline)
    }
}

struct SanitizeTests {
    private func analysis(total: Int, low: Int, high: Int, score: Int) -> MealAnalysis {
        MealAnalysis(
            isFood: true, mealName: "x", description: "", items: [DetectedItem(name: "a", portion: "1", kcal: 9000)],
            kcalTotal: total, kcalLow: low, kcalHigh: high, proteinG: -1, carbsG: 0, fatG: 0,
            healthScore: score, scoreReason: "", tip: "", confidence: .low
        )
    }

    @Test func clampsScoreAndKcal() {
        let result = analysis(total: 7000, low: -5, high: 8000, score: 14).sanitized()
        #expect(result.healthScore == 10)
        #expect(result.kcalTotal == 5000)
        #expect(result.kcalLow == 0)
        #expect(result.kcalHigh == 5000)
        #expect(result.items.first?.kcal == 5000)
        #expect(result.proteinG == 0)
        #expect(analysis(total: 100, low: 50, high: 150, score: 0).sanitized().healthScore == 1)
    }

    @Test func widensRangeToIncludeTotal() {
        let result = analysis(total: 600, low: 650, high: 550, score: 5).sanitized()
        #expect(result.kcalLow == 600)
        #expect(result.kcalHigh == 600)
    }

    @Test func keepsTotalWhenItemsDisagree() {
        #expect(analysis(total: 600, low: 500, high: 700, score: 5).sanitized().kcalTotal == 600)
    }
}
