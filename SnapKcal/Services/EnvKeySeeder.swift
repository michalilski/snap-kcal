import CryptoKit
import Foundation

/// Seeds API keys and default models from the build-time `.env` (bundled as DevKeys.plist).
@MainActor
struct EnvKeySeeder {
    let keychain: KeychainStore
    let settings: AppSettings
    var bundle: Bundle = .main
    var defaults: UserDefaults = .standard

    func seed() {
        let values = loadValues()
        for provider in Provider.allCases {
            seedKey(values[keyName(provider)], for: provider)
            if settings.modelId(for: provider) == nil, let model = values[modelName(provider)] {
                settings.setModelId(model, for: provider)
            }
        }
        if !keychain.hasKey(for: settings.activeProvider), let other = Provider.allCases.first(where: keychain.hasKey) {
            settings.activeProvider = other
        }
    }

    private func seedKey(_ value: String?, for provider: Provider) {
        guard let value, !value.isEmpty else { return }
        let fingerprintKey = "envKeyFingerprint.\(provider.rawValue)"
        let fingerprint = SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
        guard defaults.string(forKey: fingerprintKey) != fingerprint || !keychain.hasKey(for: provider) else { return }
        keychain.setKey(value, for: provider)
        defaults.set(fingerprint, forKey: fingerprintKey)
    }

    private func loadValues() -> [String: String] {
        guard let url = bundle.url(forResource: "DevKeys", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return plist
    }

    private func keyName(_ provider: Provider) -> String {
        provider == .openai ? "OPENAI_API_KEY" : "ANTHROPIC_API_KEY"
    }

    private func modelName(_ provider: Provider) -> String {
        provider == .openai ? "OPENAI_MODEL" : "ANTHROPIC_MODEL"
    }
}
