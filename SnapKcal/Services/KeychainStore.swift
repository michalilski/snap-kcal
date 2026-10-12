import Foundation
import Security

struct KeychainStore: Sendable {
    var service = "SnapKcal"

    func key(for provider: Provider) -> String? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setKey(_ value: String?, for provider: Provider) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            SecItemDelete(baseQuery(provider) as CFDictionary)
            return
        }
        let data = Data(trimmed.utf8)
        var add = baseQuery(provider)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(baseQuery(provider) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    func hasKey(for provider: Provider) -> Bool {
        !(key(for: provider) ?? "").isEmpty
    }

    static func masked(_ key: String?) -> String? {
        guard let key, !key.isEmpty else { return nil }
        return "••••" + key.suffix(4)
    }

    private func baseQuery(_ provider: Provider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(provider.rawValue)_api_key",
        ]
    }
}
