import Foundation
import Testing
@testable import SnapKcal

struct RequestBuilderTests {
    let context = AnalysisContext(goal: .lose, targetKcal: 1950, eatenTodayKcal: 1120, localTime: "13:42", languageName: "Polish", userNote: "half portion, no sauce", detail: .fast)
    let image = Data([0xFF, 0xD8, 0xFF])

    @Test func openAIAnalyze() throws {
        let request = OpenAIRequests.analyze(image: image, context: context, modelId: "gpt-x", apiKey: "sk-1", useSchema: true, useReasoning: true)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-1")
        let body = request.jsonBody
        #expect(body["model"] as? String == "gpt-x")
        #expect(body["store"] as? Bool == false)
        #expect(body["max_output_tokens"] as? Int == 2000)
        #expect((body["reasoning"] as? [String: String])?["effort"] == "low")
        let format = try #require((body["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect(format["strict"] as? Bool == true)
        let input = try #require(body["input"] as? [[String: Any]])
        let content = try #require(input.first?["content"] as? [[String: Any]])
        #expect(content.first?["detail"] as? String == "low")
        #expect((content.first?["image_url"] as? String)?.hasPrefix("data:image/jpeg;base64,") == true)
        #expect((body["instructions"] as? String)?.contains("in Polish") == true)
    }

    @Test func openAIFallbackModeOmitsFormat() {
        let body = OpenAIRequests.analyze(image: image, context: context, modelId: "gpt-x", apiKey: "k", useSchema: false, useReasoning: false).jsonBody
        #expect(body["text"] == nil)
        #expect(body["reasoning"] == nil)
        #expect((body["instructions"] as? String)?.contains("Return only a JSON object matching this schema") == true)
    }

    @Test func anthropicAnalyze() throws {
        let request = AnthropicRequests.analyze(image: image, context: context, modelId: "claude-x", apiKey: "ak", useSchema: true, useEffort: true)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "ak")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        let body = request.jsonBody
        #expect(body["max_tokens"] as? Int == 1024)
        let config = try #require(body["output_config"] as? [String: Any])
        #expect(config["effort"] as? String == "low")
        #expect((config["format"] as? [String: Any])?["type"] as? String == "json_schema")
        let messages = try #require(body["messages"] as? [[String: Any]])
        let content = try #require(messages.first?["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "image")
    }

    @Test func anthropicWithoutCapabilitiesOmitsOutputConfig() {
        let body = AnthropicRequests.analyze(image: image, context: context, modelId: "c", apiKey: "k", useSchema: false, useEffort: false).jsonBody
        #expect(body["output_config"] == nil)
    }

    @Test func anthropicModelsPagination() {
        let request = AnthropicRequests.models(apiKey: "k", afterId: "abc")
        #expect(request.url?.query?.contains("limit=1000") == true)
        #expect(request.url?.query?.contains("after_id=abc") == true)
    }

    @Test func userContextText() {
        let text = Prompt.userContext(context)
        #expect(text.contains("Goal: lose weight. Daily target: 1950 kcal. Already eaten today: 1120 kcal. Remaining: 830 kcal."))
        #expect(text.contains("Local time: 13:42."))
        #expect(text.contains("User note: \"half portion, no sauce\""))
    }

    @Test func userContextOmitsEmptyNote() {
        let noNote = AnalysisContext(goal: .gain, targetKcal: 2750, eatenTodayKcal: 0, localTime: "08:00", languageName: "English", userNote: "  ", detail: .accurate)
        #expect(!Prompt.userContext(noNote).contains("User note"))
    }

    @Test func schemaIsStrictCompatible() throws {
        let schema = MealSchema.schema
        #expect(schema["additionalProperties"] as? Bool == false)
        let required = try #require(schema["required"] as? [String])
        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(Set(required) == Set(properties.keys))
    }

    @Test func reasoningModelDetection() {
        #expect(OpenAIRequests.isReasoningModel("o3-mini"))
        #expect(OpenAIRequests.isReasoningModel("gpt-5-mini"))
        #expect(!OpenAIRequests.isReasoningModel("gpt-4o-mini"))
    }
}
