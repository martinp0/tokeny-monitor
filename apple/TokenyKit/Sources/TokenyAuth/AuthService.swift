import Foundation
import Observation
import TokenyCore

/// Sign-in state for the apps. Wraps the shared ``NeonAuthClient`` and, when Apple sign-in
/// cannot be completed on the server, a device-local Apple identity.
@MainActor
@Observable
public final class AuthService {
    public enum State: Equatable, Sendable {
        case unknown
        case signedOut
        case signedIn(userID: String, email: String?)
    }

    public enum SignUpResult: Equatable, Sendable {
        case signedIn
        /// The account needs its e-mail confirmed before the first sign-in.
        case confirmEmail
    }

    public enum AppleSignInResult: Equatable, Sendable {
        /// Neon Auth accepted the identity token and stored a session cookie.
        case server
        /// The Apple provider is missing or cannot accept this bundle's token. The Apple user id
        /// is saved on this device only.
        case local
    }

    public private(set) var state: State = .unknown
    /// Set when ``state`` is signed in. Server sessions win over a leftover local identity.
    public private(set) var source: IdentitySource?

    public enum IdentitySource: Equatable, Sendable {
        case server
        case localApple
    }

    public let client: NeonAuthClient
    private let api: UsageAPI
    private let localAccounts: any LocalAccountStore
    private var observing = false

    public init(
        client: NeonAuthClient = TokenyAuthClient.shared,
        api: UsageAPI = UsageAPI(),
        localAccounts: any LocalAccountStore = TokenyAuthClient.localAccounts
    ) {
        self.client = client
        self.api = api
        self.localAccounts = localAccounts
        if let session = client.currentSession {
            applyServer(session)
        } else if let local = localAccounts.load() {
            applyLocal(local)
        }
    }

    public var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    public var isLocalIdentity: Bool { source == .localApple }

    /// Tokeny account id for a server session. Nil when signed out, and nil for the on-device
    /// Apple identity, whose id is an Apple user id rather than a Tokeny user id.
    public var serverUserID: String? {
        guard source == .server, case .signedIn(let userID, _) = state else { return nil }
        return userID
    }

    public var email: String? {
        if case .signedIn(_, let email) = state { return email }
        return nil
    }

    public var localAccount: LocalAccount? {
        guard isLocalIdentity else { return nil }
        return localAccounts.load()
    }

    /// Follows sign-in, sign-out and refreshes. Call once from the app's root `.task`.
    /// Also re-checks the stored session with the server once (offline keeps it).
    public func observe() async {
        guard !observing else { return }
        observing = true
        defer { observing = false }
        Task { _ = try? await client.refresh() }
        for await session in client.authStateChanges {
            if let session {
                _ = localAccounts.save(nil)
                applyServer(session)
            } else if let local = localAccounts.load() {
                applyLocal(local)
            } else {
                applySignedOut()
            }
        }
    }

    public func signIn(email: String, password: String) async throws {
        let session = try await client.signIn(email: normalized(email), password: password)
        _ = localAccounts.save(nil)
        applyServer(session)
    }

    public func signUp(email: String, password: String) async throws -> SignUpResult {
        if let session = try await client.signUp(email: normalized(email), password: password) {
            _ = localAccounts.save(nil)
            applyServer(session)
            return .signedIn
        }
        return .confirmEmail
    }

    /// E-mails a reset code; the user sets the new password on the web
    /// (``AppConfig/resetPasswordURL(email:)``).
    public func sendPasswordReset(email: String) async throws {
        try await client.requestPasswordReset(email: normalized(email))
    }

    /// Native Sign in with Apple. Tries Neon Auth first. If the Apple provider is not enabled,
    /// or it rejects the bundle-id audience, saves ``appleUserID`` on this device.
    public func signInWithApple(
        idToken: String,
        nonce: AppleSignInNonce,
        appleUserID: String,
        email: String?,
        name: String?
    ) async throws -> AppleSignInResult {
        do {
            let session = try await client.signInWithApple(idToken: idToken, rawNonce: nonce.raw)
            _ = localAccounts.save(nil)
            applyServer(session)
            return .server
        } catch let error as NeonAuthError {
            guard AppleSignInFallback.shouldUseLocalIdentity(error) else { throw error }
            try adoptLocal(appleUserID: appleUserID, email: email, name: name)
            return .local
        }
    }

    public func signOut() async {
        _ = localAccounts.save(nil)
        await client.signOut()
        applySignedOut()
    }

    /// Credential for ``UsageAPI`` (the session cookie). Throws `.unauthorized` when signed out,
    /// the session has expired, or the only identity is the on-device Apple ID.
    public func accessToken() async throws -> String {
        if isLocalIdentity { throw UsageAPIError.unauthorized }
        if let token = client.storedAccessToken() { return token }
        if client.currentSession != nil, let refreshed = try? await client.refresh() {
            return refreshed.cookieHeader
        }
        client.clearLocalSession()
        if localAccounts.load() == nil { applySignedOut() }
        throw UsageAPIError.unauthorized
    }

    /// Deletes the account on the server, then signs out locally. A device-only Apple identity
    /// is removed from this device and no request is made.
    public func deleteAccount() async throws {
        if isLocalIdentity {
            _ = localAccounts.save(nil)
            client.clearLocalSession()
            applySignedOut()
            return
        }
        try await api.deleteAccount(accessToken: accessToken())
        _ = localAccounts.save(nil)
        client.clearLocalSession()
        applySignedOut()
    }

    private func adoptLocal(appleUserID: String, email: String?, name: String?) throws {
        let id = appleUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            throw NeonAuthError(status: 0, code: "APPLE_USER_MISSING", message: nil)
        }
        let previous = localAccounts.load()
        let same = previous?.appleUserID == id
        let account = LocalAccount(
            appleUserID: id,
            email: nonempty(email) ?? (same ? previous?.email : nil),
            name: nonempty(name) ?? (same ? previous?.name : nil)
        )
        guard localAccounts.save(account) else {
            throw NeonAuthError(status: 0, code: "KEYCHAIN_SAVE_FAILED", message: nil)
        }
        applyLocal(account)
    }

    private func applyServer(_ session: StoredSession) {
        source = .server
        state = .signedIn(userID: session.userID, email: session.email)
    }

    private func applyLocal(_ account: LocalAccount) {
        source = .localApple
        state = .signedIn(userID: account.appleUserID, email: account.email)
    }

    private func applySignedOut() {
        source = nil
        state = .signedOut
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func nonempty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
