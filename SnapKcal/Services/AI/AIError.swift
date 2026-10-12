import Foundation

enum AIError: Error, Equatable {
    case missingKey(Provider)
    case missingModel(Provider)
    case invalidKey
    case modelUnavailable(String)
    case rateLimited(retryAfter: TimeInterval?)
    case overloaded
    case badRequest(String)
    case refused
    case truncated
    case decoding(String)
    case offline
    case timeout

    var userMessage: String {
        switch self {
        case .missingKey: String(localized: "Add an API key in SETUP.")
        case .missingModel: String(localized: "Pick a model in SETUP.")
        case .invalidKey: String(localized: "API key rejected. Check it in SETUP.")
        case .modelUnavailable: String(localized: "Model unavailable. Pick another one in SETUP.")
        case .rateLimited: String(localized: "Rate limit reached. Try again in a moment.")
        case .overloaded: String(localized: "The AI service is busy. Try again.")
        case .badRequest: String(localized: "The request was rejected.")
        case .refused: String(localized: "Model declined this image.")
        case .truncated: String(localized: "The answer was cut off. Try again.")
        case .decoding: String(localized: "Could not read the model's answer. Try again.")
        case .offline: String(localized: "No connection. Tap retry when you're online.")
        case .timeout: String(localized: "The request timed out. Try again.")
        }
    }

    var detail: String? {
        switch self {
        case .badRequest(let message), .decoding(let message): message
        case .modelUnavailable(let id): id
        default: nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .overloaded, .offline, .timeout, .truncated, .decoding: true
        default: false
        }
    }

    static func from(urlError: URLError) -> AIError {
        switch urlError.code {
        case .timedOut: .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed: .offline
        default: .badRequest(urlError.localizedDescription)
        }
    }

    static func from(status: Int, message: String?, modelId: String, retryAfter: TimeInterval?) -> AIError {
        let text = message ?? ""
        let lowered = text.lowercased()
        switch status {
        case 401, 403: return .invalidKey
        case 404: return .modelUnavailable(modelId)
        case 429: return .rateLimited(retryAfter: retryAfter)
        case 500, 502, 503, 529: return .overloaded
        case 400 where lowered.contains("model") && (lowered.contains("not found") || lowered.contains("does not exist")):
            return .modelUnavailable(modelId)
        default: return .badRequest(text.isEmpty ? "HTTP \(status)" : text)
        }
    }
}
