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
    /// `false` when `session` was non-nil and could not be stored. Callers must not
    /// treat that as signed in.
    func save(_ session: StoredSession?) -> Bool
}

/// Session storage for tests and platforms without a Keychain.
public final class InMemoryAuthStorage: AuthSessionStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var session: StoredSession?

    public init(_ session: StoredSession? = nil) { self.session = session }

    public func load() -> StoredSession? { lock.withLock { session } }
    public func save(_ session: StoredSession?) -> Bool {
        lock.withLock { self.session = session }
        return true
    }
}

#if canImport(OSLog)
    import OSLog
#endif

#if canImport(Security)
    /// Where a session file is allowed. Release device and Mac builds never read or write one.
    enum SessionFileAccess: Equatable, Sendable {
        case device
        case simulator

        static var production: SessionFileAccess {
            #if targetEnvironment(simulator)
                .simulator
            #else
                .device
            #endif
        }
    }

    /// Keychain operations behind the session store, so tests can refuse every write.
    struct KeychainClient: Sendable {
        var add: @Sendable (Data, String?) -> OSStatus
        var copy: @Sendable (String?) -> Data?
        var remove: @Sendable (String?) -> Void

        static let refusing = KeychainClient(
            add: { _, _ in errSecMissingEntitlement },
            copy: { _ in nil },
            remove: { _ in }
        )
    }

    /// Generic-password Keychain item, optionally in the access group shared with the widgets.
    ///
    /// An unsigned simulator has no keychain entitlement, so `SecItemAdd` returns
    /// `errSecMissingEntitlement` (-34018). Only that simulator build may keep the session in a
    /// protected file. Device and Mac builds log the status and leave the user signed out.
    public struct KeychainAuthStorage: AuthSessionStorage {
        public let service: String
        public let account: String
        public let accessGroup: String?
        let fileAccess: SessionFileAccess
        let directory: URL
        let keychain: KeychainClient

        public init(service: String = "cz.martinpohl.tokeny.auth", account: String = "tokeny.auth.session", accessGroup: String?) {
            self.init(service: service, account: account, accessGroup: accessGroup, fileAccess: .production, directory: nil, keychain: nil)
        }

        init(
            service: String,
            account: String,
            accessGroup: String?,
            fileAccess: SessionFileAccess,
            directory: URL?,
            keychain: KeychainClient?
        ) {
            self.service = service
            self.account = account
            self.accessGroup = accessGroup
            self.fileAccess = fileAccess
            self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.keychain = keychain ?? .system(service: service, account: account)
            if fileAccess == .device {
                SessionFileStore.remove(fileURL)
            }
        }

        public func load() -> StoredSession? {
            if let accessGroup, let session = decode(keychain.copy(accessGroup)) { return session }
            if let session = decode(keychain.copy(nil)) { return session }
            guard fileAccess == .simulator else { return nil }
            #if targetEnvironment(simulator) || DEBUG
                return SessionFileStore.read(fileURL)
            #else
                return nil
            #endif
        }

        public func save(_ session: StoredSession?) -> Bool {
            guard let session, let data = try? JSONEncoder().encode(session) else {
                clearKeychain()
                SessionFileStore.remove(fileURL)
                return true
            }
            let status = keychain.add(data, accessGroup)
            let privateStatus = status == errSecSuccess ? status : keychain.add(data, nil)
            if privateStatus == errSecSuccess {
                SessionFileStore.remove(fileURL)
                return true
            }
            logKeychainFailure(privateStatus)
            guard fileAccess == .simulator else {
                SessionFileStore.remove(fileURL)
                return false
            }
            #if targetEnvironment(simulator) || DEBUG
                do {
                    try SessionFileStore.write(data, to: fileURL)
                    return SessionFileStore.read(fileURL) != nil
                } catch {
                    return false
                }
            #else
                SessionFileStore.remove(fileURL)
                return false
            #endif
        }

        private var fileURL: URL {
            let name = "\(service).\(account).session".replacingOccurrences(of: "/", with: "_")
            return directory.appending(path: name)
        }

        private func clearKeychain() {
            keychain.remove(accessGroup)
            if accessGroup != nil { keychain.remove(nil) }
        }

        private func decode(_ data: Data?) -> StoredSession? {
            guard let data else { return nil }
            return try? JSONDecoder().decode(StoredSession.self, from: data)
        }

        private func logKeychainFailure(_ status: OSStatus) {
            #if canImport(OSLog)
                Logger(subsystem: "cz.martinpohl.tokeny", category: "session").error(
                    "Keychain session save failed: \(status, privacy: .public)")
            #endif
        }
    }

    enum SessionFileStore {
        static func remove(_ url: URL) {
            try? FileManager.default.removeItem(at: url)
        }

        #if targetEnvironment(simulator) || DEBUG
            static func write(_ data: Data, to url: URL) throws {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                var options: Data.WritingOptions = [.atomic]
                #if os(iOS)
                    options.insert(.completeFileProtection)
                #endif
                try data.write(to: url, options: options)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                var item = url
                try item.setResourceValues(values)
            }

            static func read(_ url: URL) -> StoredSession? {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(StoredSession.self, from: data)
            }
        #endif
    }

    extension KeychainClient {
        static func system(service: String, account: String) -> KeychainClient {
            @Sendable func query(_ accessGroup: String?) -> [String: Any] {
                var q: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                ]
                if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
                return q
            }
            return KeychainClient(
                add: { data, accessGroup in
                    SecItemDelete(query(accessGroup) as CFDictionary)
                    var q = query(accessGroup)
                    q[kSecValueData as String] = data
                    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
                    return SecItemAdd(q as CFDictionary, nil)
                },
                copy: { accessGroup in
                    var q = query(accessGroup)
                    q[kSecReturnData as String] = true
                    q[kSecMatchLimit as String] = kSecMatchLimitOne
                    var out: CFTypeRef?
                    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
                    return out as? Data
                },
                remove: { accessGroup in
                    SecItemDelete(query(accessGroup) as CFDictionary)
                }
            )
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
