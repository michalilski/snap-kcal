import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppEnvironment {
    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored let store: MealStore
    @ObservationIgnored let keychain: KeychainStore
    @ObservationIgnored let providers: [Provider: any AIProvider]
    @ObservationIgnored let catalog: ModelCatalog
    @ObservationIgnored let analyzer: MealAnalyzer
    let settings: AppSettings
    let isMock: Bool
    var todayKey = DayKey.key(for: .now)
    var dataVersion = 0

    init(isMock: Bool = MockProvider.isEnabled, isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("-uiTesting")) {
        let defaults = isUITesting ? UserDefaults(suiteName: "SnapKcal.uiTests") ?? .standard : .standard
        if isUITesting { defaults.removePersistentDomain(forName: "SnapKcal.uiTests") }
        let container = (try? MealStore.makeContainer(inMemory: isUITesting)) ?? (try! MealStore.makeContainer(inMemory: true))
        let settings = AppSettings(defaults: defaults)
        let keychain = KeychainStore()
        let providers: [Provider: any AIProvider] = isMock
            ? [.openai: MockProvider(provider: .openai), .anthropic: MockProvider(provider: .anthropic)]
            : [.openai: OpenAIProvider(), .anthropic: AnthropicProvider()]
        let store = MealStore(context: container.mainContext)
        let catalog = ModelCatalog(providers: providers, directory: URL.applicationSupportDirectory.appending(path: isMock ? "mock" : "live"))
        let keys = KeyResolver { provider in isMock ? "mock-key" : keychain.key(for: provider) }

        self.container = container
        self.store = store
        self.keychain = keychain
        self.providers = providers
        self.catalog = catalog
        self.settings = settings
        self.isMock = isMock
        analyzer = MealAnalyzer(providers: providers, keys: keys, settings: settings, store: store, catalog: catalog)
        if !isUITesting {
            EnvKeySeeder(keychain: keychain, settings: settings).seed()
        }
    }

    func apiKey(for provider: Provider) -> String? {
        isMock ? "mock-key" : keychain.key(for: provider)
    }

    var hasActiveKey: Bool {
        !(apiKey(for: settings.activeProvider) ?? "").isEmpty
    }

    func refreshToday() {
        let key = DayKey.key(for: .now)
        if key != todayKey { todayKey = key }
    }

    func dataChanged() {
        dataVersion += 1
    }
}
