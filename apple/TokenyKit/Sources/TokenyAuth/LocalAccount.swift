import Foundation

/// Apple ID saved on this device when Neon Auth cannot turn the identity token into a session.
/// There is no server cookie: spend still comes from a file or sample data on the device.
public struct LocalAccount: Codable, Equatable, Sendable {
    public var appleUserID: String
    public var email: String?
    public var name: String?

    public init(appleUserID: String, email: String?, name: String?) {
        self.appleUserID = appleUserID
        self.email = email
        self.name = name
    }
}

public protocol LocalAccountStore: Sendable {
    func load() -> LocalAccount?
    /// `false` when `account` was non-nil and could not be stored.
    func save(_ account: LocalAccount?) -> Bool
}

public final class InMemoryLocalAccountStore: LocalAccountStore, @unchecked Sendable {
    private let lock = NSLock()
    private var account: LocalAccount?

    public init(_ account: LocalAccount? = nil) { self.account = account }

    public func load() -> LocalAccount? { lock.withLock { account } }

    public func save(_ account: LocalAccount?) -> Bool {
        lock.withLock { self.account = account }
        return true
    }
}

/// When Sign in with Apple cannot be completed by Neon Auth, keep the Apple user id on device
/// instead of showing a dead end. A transport failure is not one of these cases.
public enum AppleSignInFallback {
    public static func shouldUseLocalIdentity(_ error: NeonAuthError) -> Bool {
        let code = (error.code ?? "").uppercased()
        let localCodes: Set<String> = [
            "PROVIDER_NOT_SUPPORTED",
            "PROVIDER_NOT_FOUND",
            "SOCIAL_PROVIDER_NOT_FOUND",
            "NATIVE_APPLE_SIGN_IN_UNSUPPORTED",
        ]
        if localCodes.contains(code) { return true }
        let message = (error.message ?? "").lowercased()
        if message.contains("provider is not supported") || message.contains("provider not found")
            || message.contains("not configured") || message.contains("not enabled")
        {
            return true
        }
        // Better Auth rejects a native identity token when the audience is the bundle id and
        // the Apple provider only lists the Services ID. That is still "the backend can't link it".
        if message.contains("jwtclaimvalidationfailed") || message.contains("unexpected \"aud\"")
            || message.contains("unexpected aud") || message.contains("audience")
        {
            return true
        }
        return false
    }
}
