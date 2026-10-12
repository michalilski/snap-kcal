import Foundation

struct OAIModelList: Decodable { let data: [OAIModel] }
struct OAIModel: Decodable, Sendable { let id: String; let created: Int?; let ownedBy: String?; let shutdownDate: String? }

struct OAIResponse: Decodable {
    let id: String?
    let status: String?
    let output: [OAIOutputItem]
    let usage: OAIUsage?
    let incompleteDetails: OAIIncomplete?
}
struct OAIOutputItem: Decodable { let type: String; let content: [OAIContentPart]? }
struct OAIContentPart: Decodable { let type: String; let text: String?; let refusal: String? }
struct OAIUsage: Decodable { let inputTokens: Int?; let outputTokens: Int? }
struct OAIIncomplete: Decodable { let reason: String? }
struct OAIErrorEnvelope: Decodable { let error: OAIErrorBody }
struct OAIErrorBody: Decodable { let message: String; let type: String?; let code: String? }

struct AnthModelList: Decodable { let data: [AnthModel]; let hasMore: Bool?; let lastId: String? }
struct AnthModel: Decodable, Sendable {
    let id: String
    let displayName: String?
    let createdAt: String?
    let lifecycle: String?
    let capabilities: AnthCapabilities?
}
struct AnthCapabilities: Decodable, Sendable { let imageInput: AnthCap?; let structuredOutputs: AnthCap?; let effort: AnthCap? }
struct AnthCap: Decodable, Sendable { let supported: Bool? }

struct AnthResponse: Decodable {
    let content: [AnthContent]
    let stopReason: String?
    let usage: AnthUsage?
}
struct AnthContent: Decodable { let type: String; let text: String? }
struct AnthUsage: Decodable { let inputTokens: Int?; let outputTokens: Int? }
struct AnthErrorEnvelope: Decodable { let error: AnthErrorBody }
struct AnthErrorBody: Decodable { let type: String; let message: String }

enum DTODecoder {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    static func errorMessage(from data: Data) -> String? {
        if let envelope = try? decode(OAIErrorEnvelope.self, from: data) { return envelope.error.message }
        if let envelope = try? decode(AnthErrorEnvelope.self, from: data) { return envelope.error.message }
        return nil
    }
}
