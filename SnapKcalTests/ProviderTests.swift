import Foundation
import Testing
@testable import SnapKcal

@MainActor
@Suite(.serialized)
struct ProviderTests {
    let model = AIModel(id: "gpt-x", displayName: "gpt-x", provider: .openai, createdAt: nil, supportsStructuredOutput: nil, supportsEffort: nil)
    let context = AnalysisContext(goal: .maintain, targetKcal: 2000, eatenTodayKcal: 0, localTime: "12:00", languageName: "English", userNote: nil, detail: .fast)

    private func pipeline() -> AnalysisPipeline {
        var pipeline = AnalysisPipeline(settings: TestStore.settings())
        pipeline.retryDelay = { _ in .milliseconds(1) }
        return pipeline
    }

    @Test func openAIEndToEnd() async throws {
        let provider = OpenAIProvider(client: StubURLProtocol.client([(200, Fixture.data("openai_response"))]))
        let result = try await provider.analyze(imageJPEG: Data([1]), context: context, model: model, apiKey: "k", options: .init(useSchema: true, useEffort: false))
        #expect(result.analysis.kcalTotal == 600)
        #expect(result.inputTokens == 812)
    }

    @Test func invalidKeyMapsTo401() async {
        let provider = OpenAIProvider(client: StubURLProtocol.client([(401, Fixture.data("openai_error_401"))]))
        await #expect(throws: AIError.invalidKey) {
            try await provider.analyze(imageJPEG: Data([1]), context: context, model: model, apiKey: "k", options: .init(useSchema: true, useEffort: false))
        }
    }

    @Test func pipelineRetriesOnceAfterOverload() async throws {
        let provider = AnthropicProvider(client: StubURLProtocol.client([(529, Data()), (200, Fixture.data("anthropic_response"))]))
        let anthropicModel = AIModel.manual("claude-x", provider: .anthropic)
        let result = try await pipeline().run(provider: provider, image: Data([1]), context: context, model: anthropicModel, apiKey: "k")
        #expect(result.analysis.kcalTotal == 600)
        #expect(StubURLProtocol.requests.count == 2)
    }

    @Test func pipelineFailsAfterSecondRateLimit() async {
        let provider = AnthropicProvider(client: StubURLProtocol.client([(429, Fixture.data("anthropic_error_429")), (429, Data())]))
        await #expect(throws: AIError.rateLimited(retryAfter: nil)) {
            try await pipeline().run(provider: provider, image: Data([1]), context: context, model: .manual("c", provider: .anthropic), apiKey: "k")
        }
    }

    @Test func pipelineDropsReasoningAndRemembersModel() async throws {
        let settings = TestStore.settings()
        var pipeline = AnalysisPipeline(settings: settings)
        pipeline.retryDelay = { _ in .milliseconds(1) }
        let error = Data(#"{"error":{"message":"Unsupported parameter: 'reasoning.effort'"}}"#.utf8)
        let provider = OpenAIProvider(client: StubURLProtocol.client([(400, error), (200, Fixture.data("openai_response"))]))
        let reasoningModel = AIModel.manual("o3-mini", provider: .openai)
        _ = try await pipeline.run(provider: provider, image: Data([1]), context: context, model: reasoningModel, apiKey: "k")
        #expect(settings.modelsWithoutReasoning.contains("o3-mini"))
        #expect(StubURLProtocol.requests.last?.jsonBody["reasoning"] == nil)
    }

    @Test func pipelineFallsBackWithoutSchema() async throws {
        let settings = TestStore.settings()
        let pipeline = AnalysisPipeline(settings: settings)
        let error = Data(#"{"error":{"message":"Invalid parameter: 'text.format' is not supported with this model."}}"#.utf8)
        let provider = OpenAIProvider(client: StubURLProtocol.client([(400, error), (200, Fixture.data("openai_response"))]))
        _ = try await pipeline.run(provider: provider, image: Data([1]), context: context, model: model, apiKey: "k")
        #expect(settings.modelsWithoutSchema.contains("gpt-x"))
        #expect(StubURLProtocol.requests.last?.jsonBody["text"] == nil)
    }

    @Test func anthropicModelListPagination() async throws {
        let page1 = Data(#"{"data":[{"id":"a","created_at":"2026-01-01T00:00:00Z"}],"has_more":true,"last_id":"a"}"#.utf8)
        let page2 = Data(#"{"data":[{"id":"b","created_at":"2026-02-01T00:00:00Z"}],"has_more":false,"last_id":"b"}"#.utf8)
        let provider = AnthropicProvider(client: StubURLProtocol.client([(200, page1), (200, page2)]))
        let models = try await provider.listModels(apiKey: "k")
        #expect(models.map(\.id) == ["b", "a"])
        #expect(StubURLProtocol.requests.last?.url?.query?.contains("after_id=a") == true)
    }
}
