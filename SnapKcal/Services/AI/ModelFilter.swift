import Foundation

enum ModelFilter {
    private static let openAIExcluded = [
        "audio", "realtime", "tts", "transcribe", "whisper", "embedding", "image", "dall-e", "moderation", "search", "codex", "instruct",
    ]

    static func openAI(_ raw: [OAIModel], now: Date) -> [AIModel] {
        raw.filter { isOpenAIChatModel($0.id) && !isShutDown($0.shutdownDate, now: now) }
            .sorted { ($0.created ?? 0) > ($1.created ?? 0) }
            .map {
                AIModel(
                    id: $0.id, displayName: $0.id, provider: .openai,
                    createdAt: $0.created.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    supportsStructuredOutput: nil, supportsEffort: nil
                )
            }
    }

    static func anthropic(_ raw: [AnthModel]) -> [AIModel] {
        raw.filter { ($0.lifecycle == nil || $0.lifecycle == "active") && $0.capabilities?.imageInput?.supported != false }
            .map {
                AIModel(
                    id: $0.id, displayName: $0.displayName ?? $0.id, provider: .anthropic,
                    createdAt: $0.createdAt.flatMap(parseISO),
                    supportsStructuredOutput: $0.capabilities?.structuredOutputs?.supported,
                    supportsEffort: $0.capabilities?.effort?.supported
                )
            }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    static func isOpenAIChatModel(_ id: String) -> Bool {
        let lowered = id.lowercased()
        let isO = lowered.count > 1 && lowered.first == "o" && lowered.dropFirst().first?.isNumber == true
        let kept = lowered.hasPrefix("gpt-") || isO || lowered.hasPrefix("chatgpt-")
        return kept && !openAIExcluded.contains { lowered.contains($0) }
    }

    private static func isShutDown(_ value: String?, now: Date) -> Bool {
        guard let value else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(value.prefix(10))) else { return false }
        return date < now
    }

    private static func parseISO(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
