import Foundation

struct HTTPClient: Sendable {
    static let shared = HTTPClient()

    private let session: URLSession

    init(session: URLSession = HTTPClient.makeSession()) {
        self.session = session
    }

    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        configuration.waitsForConnectivity = false
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        return URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest, modelId: String = "") async throws(AIError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AIError.from(urlError: error)
        } catch {
            throw AIError.badRequest(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.badRequest("No HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let retryAfter = http.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init)
            throw AIError.from(status: http.statusCode, message: DTODecoder.errorMessage(from: data), modelId: modelId, retryAfter: retryAfter)
        }
        return data
    }

    static func jsonBody(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }
}
