import Foundation
import TokenyCore

#if canImport(Security)
    import Security
#endif

/// Provider usage keys live in the Keychain on this device. They are not sent to Tokeny.
public struct ProviderKeyStore: Sendable {
    public static let service = "cz.martinpohl.tokeny.provider-keys"

    private let read: @Sendable (String) -> String?
    private let write: @Sendable (String, String?) -> Bool

    public init(read: @escaping @Sendable (String) -> String?, write: @escaping @Sendable (String, String?) -> Bool) {
        self.read = read
        self.write = write
    }

    public static func live() -> ProviderKeyStore {
        #if canImport(Security)
            return ProviderKeyStore(read: Self.copy, write: Self.store)
        #else
            return memory()
        #endif
    }

    /// In-memory stand-in for tests and platforms without a Keychain.
    public static func memory() -> ProviderKeyStore {
        let box = MemoryBox()
        return ProviderKeyStore(
            read: { box.values[$0] },
            write: { account, value in
                if let value { box.values[account] = value } else { box.values[account] = nil }
                return true
            })
    }

    public func save(provider: String, secret: String) -> Bool {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n"), !trimmed.contains("\r") else { return false }
        return write(account(provider), trimmed)
    }

    public func load(provider: String) -> String? {
        read(account(provider))
    }

    public func delete(provider: String) {
        _ = write(account(provider), nil)
    }

    public func maskedPreview(provider: String) -> String? {
        load(provider: provider).map(SecretPreview.mask)
    }

    private func account(_ provider: String) -> String { "provider.\(provider)" }

    #if canImport(Security)
        private static func query(_ account: String) -> [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
        }

        private static func store(_ account: String, _ value: String?) -> Bool {
            SecItemDelete(query(account) as CFDictionary)
            guard let value, let data = value.data(using: .utf8) else { return true }
            var item = query(account)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        }

        private static func copy(_ account: String) -> String? {
            var query = query(account)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
    #endif
}

private final class MemoryBox: @unchecked Sendable {
    var values: [String: String] = [:]
}
