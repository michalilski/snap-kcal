import Foundation
import Testing
@testable import SnapKcal

struct ModelFilterTests {
    private var openAIModels: [AIModel] {
        let raw = try! DTODecoder.decode(OAIModelList.self, from: Fixture.data("openai_models")).data
        return ModelFilter.openAI(raw, now: TestCalendar.date("2026-10-12"))
    }

    private var anthropicModels: [AIModel] {
        let raw = try! DTODecoder.decode(AnthModelList.self, from: Fixture.data("anthropic_models")).data
        return ModelFilter.anthropic(raw)
    }

    @Test func openAIKeepsChatModels() {
        let ids = openAIModels.map(\.id)
        #expect(ids.contains("o1-mini"))
        #expect(ids.contains("gpt-4o-mini"))
        #expect(ids.contains("chatgpt-4o-latest"))
    }

    @Test func openAIDropsNonChatModels() {
        let ids = openAIModels.map(\.id)
        #expect(!ids.contains("gpt-4o-mini-tts"))
        #expect(!ids.contains("gpt-image-1"))
        #expect(!ids.contains("whisper-1"))
        #expect(!ids.contains("text-embedding-3-small"))
        #expect(!ids.contains("gpt-4o-realtime-preview"))
    }

    @Test func openAIDropsShutDownModels() {
        #expect(!openAIModels.map(\.id).contains("gpt-4-retired"))
        let yesterday = OAIModel(id: "gpt-x", created: 1, ownedBy: nil, shutdownDate: "2026-10-11")
        #expect(ModelFilter.openAI([yesterday], now: TestCalendar.date("2026-10-12 12:00")).isEmpty)
    }

    @Test func openAISortedNewestFirst() {
        let created = openAIModels.compactMap(\.createdAt)
        #expect(created == created.sorted(by: >))
    }

    @Test func anthropicDropsDeprecatedAndTextOnly() {
        let ids = anthropicModels.map(\.id)
        #expect(!ids.contains("claude-old"))
        #expect(!ids.contains("claude-textonly"))
    }

    @Test func anthropicKeepsModelWithoutCapabilities() {
        let model = anthropicModels.first { $0.id == "claude-haiku-x" }
        #expect(model != nil)
        #expect(model?.supportsStructuredOutput == nil)
        #expect(model?.supportsEffort == nil)
        #expect(model?.isFastHint == true)
    }

    @Test func anthropicCapabilitiesAndSorting() {
        #expect(anthropicModels.first?.id == "claude-new")
        #expect(anthropicModels.first?.supportsStructuredOutput == true)
        #expect(anthropicModels.first?.supportsEffort == true)
        #expect(anthropicModels.first?.displayName == "Claude New")
    }

    @Test func preferredDefaultPicksFastModel() {
        #expect(ModelCatalog.preferredDefault(from: anthropicModels)?.id == "claude-haiku-x")
    }
}
