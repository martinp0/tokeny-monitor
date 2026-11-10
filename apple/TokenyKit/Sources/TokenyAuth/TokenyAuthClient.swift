import Foundation
import TokenyCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
#if canImport(Security)
    import Security
#endif

/// The signed-in Neon Auth (Better Auth) session as the apps keep it in the Keychain.
/// `cookieName=cookieValue` is the session-token cookie our `/api/auth/*` proxy sets; the apps send
/// it by hand (never through URLSession's cookie jar) to `/api/*`.
public struct StoredSession: Codable, Sendable, Equatable {
    public var cookieName: String
    public var cookieValue: String
    public var userID: String
    public var email: String?
    /// When the session cookie stops being valid (Better Auth extends it while in use).
    public var expiresAt: Date?

    public init(cookieName: String, cookieValue: String, userID: String, email: String?, expiresAt: Date?) {
        self.cookieName = cookieName
        self.cookieValue = cookieValue
        self.userID = userID
        self.email = email
        self.expiresAt = expiresAt
    }

    /// Value for the `Cookie` request header.
    public var cookieHeader: String { "\(cookieName)=\(cookieValue)" }
}

/// Where the session lives. Keychain on Apple platforms, memory in tests and on Linux.
public protocol AuthSessionStorage: Sendable {
    func load() -> StoredSession?
    func save(_ session: StoredSession?)
}

/// Session storage for tests and platforms without a Keychain.
public final class InMemoryAuthStorage: AuthSessionStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var session: StoredSession?

    public init(_ session: StoredSession? = nil) { self.session = session }

    public func load() -> StoredSession? { lock.withLock { session } }
    public func save(_ session: StoredSession?) { lock.withLock { self.session = session } }
}

#if canImport(Security)
    /// Generic-password Keychain item, optionally in the access group shared with the widgets.
    ///
    /// An unsigned simulator build has no keychain entitlement. Every `SecItemAdd` then fails
    /// with `errSecMissingEntitlement` (-34018), including the app's private keychain. The
    /// sign-in response is still delivered to the UI, but the next read finds nothing and the
    /// app signs out. That failure stores the session in the app container instead. A signed
    /// build keeps using the shared Keychain access group so widgets can read it.
    public struct KeychainAuthStorage: AuthSessionStorage {
        public let service: String
        public let account: String
        public let accessGroup: String?

        public init(service: String = "cz.martinpohl.tokeny.auth", account: String = "tokeny.auth.session", accessGroup: String?) {
            self.service = service
            self.account = account
            self.accessGroup = accessGroup
        }

        /// Tests set this when the process cannot use the Keychain at all, the same
        /// `errSecMissingEntitlement` an unsigned simulator build gets for every SecItemAdd.
        var keychainDenied = false

        public func load() -> StoredSession? {
            if keychainDenied { return readFile() }
            if let accessGroup, let session = read(accessGroup: accessGroup) { return session }
            if let session = read(accessGroup: nil) { return session }
            return readFile()
        }

        public func save(_ session: StoredSession?) {
            guard let session, let data = try? JSONEncoder().encode(session) else {
                remove(accessGroup: accessGroup)
                if accessGroup != nil { remove(accessGroup: nil) }
                deleteFile()
                return
            }
            if keychainDenied {
                writeFile(data)
                return
            }
            let status = add(data, accessGroup: accessGroup, accessible: kSecAttrAccessibleAfterFirstUnlock)
            if status == errSecSuccess {
                deleteFile()
                return
            }
            // Unsigned simulator binaries have no keychain-access-groups entitlement, and on
            // this OS that refusal (-34018) also applies to the app's private keychain.
            let privateStatus = add(data, accessGroup: nil, accessible: kSecAttrAccessibleAfterFirstUnlock)
            if privateStatus == errSecSuccess {
                deleteFile()
                return
            }
            writeFile(data)
        }

        private func query(accessGroup: String?) -> [String: Any] {
            var q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
            return q
        }

        private func read(accessGroup: String?) -> StoredSession? {
            var q = query(accessGroup: accessGroup)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: CFTypeRef?
            guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
            return try? JSONDecoder().decode(StoredSession.self, from: data)
        }

        private func add(_ data: Data, accessGroup: String?, accessible: CFString?) -> OSStatus {
            remove(accessGroup: accessGroup)
            var q = query(accessGroup: accessGroup)
            q[kSecValueData as String] = data
            if let accessible { q[kSecAttrAccessible as String] = accessible }
            return SecItemAdd(q as CFDictionary, nil)
        }

        private func remove(accessGroup: String?) {
            SecItemDelete(query(accessGroup: accessGroup) as CFDictionary)
        }

        private var fileURL: URL {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let name = "\(service).\(account).session".replacingOccurrences(of: "/", with: "_")
            return base.appending(path: name)
        }

        private func writeFile(_ data: Data) {
            let url = fileURL
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }

        private func readFile() -> StoredSession? {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return try? JSONDecoder().decode(StoredSession.self, from: data)
        }

        private func deleteFile() {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
#endif

public enum TokenyAuthClient {
    /// Info.plist key with the Keychain access group shared by the iPhone app and its widgets,
    /// filled in by XcodeGen as `$(AppIdentifierPrefix)cz.martinpohl.tokeny.shared`.
    public static let keychainGroupInfoKey = "TokenyKeychainGroup"

    /// One client per process. The app signs in and refreshes with it; App Intents in the app
    /// process reuse it.
    public static let shared = NeonAuthClient(storage: defaultStorage())

    /// For app extensions (widgets): reads the session the app stored.
    public static func readOnly() -> NeonAuthClient { NeonAuthClient(storage: defaultStorage()) }

    static func defaultStorage() -> any AuthSessionStorage {
        #if canImport(Security)
            return KeychainAuthStorage(accessGroup: keychainAccessGroup)
        #else
            return InMemoryAuthStorage()
        #endif
    }

    static var keychainAccessGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: keychainGroupInfoKey) as? String,
            !group.isEmpty, !group.hasPrefix("$(")
        else { return nil }
        return group
    }
}
