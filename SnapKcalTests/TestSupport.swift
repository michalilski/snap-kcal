import Foundation
import SwiftData
@testable import SnapKcal

final class FixtureBundle {}

enum Fixture {
    static func data(_ name: String) -> Data {
        let url = Bundle(for: FixtureBundle.self).url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}

enum TestCalendar {
    static func make(timeZone: String = "Europe/Warsaw", firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    static func date(_ value: String, calendar: Calendar = make()) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = value.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}

@MainActor
enum TestStore {
    static func make() -> MealStore {
        MealStore(context: ModelContext(try! MealStore.makeContainer(inMemory: true)))
    }

    static func settings() -> AppSettings {
        let name = "SnapKcalTests.\(UUID().uuidString)"
        return AppSettings(defaults: UserDefaults(suiteName: name)!)
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(status: Int, body: Data, headers: [String: String])] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        let next = Self.responses.isEmpty ? (status: 500, body: Data(), headers: [:]) : Self.responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: next.status, httpVersion: nil, headerFields: next.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: next.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func client(_ responses: [(Int, Data)]) -> HTTPClient {
        self.responses = responses.map { (status: $0.0, body: $0.1, headers: [:]) }
        requests = []
        return HTTPClient(session: HTTPClient.makeSession(protocolClasses: [StubURLProtocol.self]))
    }
}

extension URLRequest {
    var jsonBody: [String: Any] {
        let data = httpBody ?? httpBodyStream.map(Self.read) ?? Data()
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
