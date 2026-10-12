import Foundation

@MainActor
final class ModelCatalog {
    struct CachedList: Codable {
        let fetchedAt: Date
        let models: [AIModel]
    }

    private let providers: [Provider: any AIProvider]
    private let directory: URL
    private let ttl: TimeInterval = 24 * 60 * 60

    init(providers: [Provider: any AIProvider], directory: URL = URL.applicationSupportDirectory) {
        self.providers = providers
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func cached(_ provider: Provider) -> [AIModel] {
        load(provider)?.models ?? []
    }

    func models(_ provider: Provider, apiKey: String, forceRefresh: Bool = false) async throws -> [AIModel] {
        if !forceRefresh, let cached = load(provider), Date.now.timeIntervalSince(cached.fetchedAt) < ttl, !cached.models.isEmpty {
            return cached.models
        }
        guard let source = providers[provider] else { return [] }
        let models = try await source.listModels(apiKey: apiKey)
        store(CachedList(fetchedAt: .now, models: models), for: provider)
        return models
    }

    func model(id: String, provider: Provider) -> AIModel {
        cached(provider).first { $0.id == id } ?? .manual(id, provider: provider)
    }

    nonisolated static func preferredDefault(from models: [AIModel]) -> AIModel? {
        models.first(where: \.isFastHint) ?? models.first
    }

    private func fileURL(_ provider: Provider) -> URL {
        directory.appending(path: "models-\(provider.rawValue).json")
    }

    private func load(_ provider: Provider) -> CachedList? {
        guard let data = try? Data(contentsOf: fileURL(provider)) else { return nil }
        return try? JSONDecoder().decode(CachedList.self, from: data)
    }

    private func store(_ list: CachedList, for provider: Provider) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: fileURL(provider), options: .atomic)
    }
}
