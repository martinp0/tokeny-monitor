import Foundation
import Testing
import TokenyCore

@testable import TokenyAuth

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

private let config = AppConfig(webURL: URL(string: "https://tokeny.example")!, appGroup: "group.test")

private final class Recorder: @unchecked Sendable {
    var requests: [URLRequest] = []
}

/// Accepts a save and then forgets it, the way a Keychain write that returns
/// `errSecMissingEntitlement` used to.
private final class ForgetfulStorage: AuthSessionStorage, @unchecked Sendable {
    func load() -> StoredSession? { nil }
    func save(_ session: StoredSession?) {}
}

private func transport(
    _ rec: Recorder, status: Int = 200, body: String, headers: [String: String] = [:]
) -> NeonAuthClient.Transport {
    { req in
        rec.requests.append(req)
        let res = HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        return (Data(body.utf8), res)
    }
}

private let signInBody = #"{"token":"raw","user":{"id":"7f6c2b1e-1111-4222-8333-444455556666","email":"a@b.cz"}}"#
private let cookie = "__Secure-neon-auth.session_token=tok.sig; Path=/; Max-Age=604800; HttpOnly; Secure; SameSite=Lax"

@Suite("Neon Auth client")
struct AuthClientTests {
    @Test func inMemoryStorage() {
        let s = InMemoryAuthStorage()
        #expect(s.load() == nil)
        let session = StoredSession(cookieName: "n", cookieValue: "v", userID: "u", email: nil, expiresAt: nil)
        s.save(session)
        #expect(s.load() == session)
        s.save(nil)
        #expect(s.load() == nil)
    }

    @Test func noStoredSessionMeansNoToken() {
        let client = NeonAuthClient(config: config, storage: InMemoryAuthStorage())
        #expect(client.storedAccessToken() == nil)
    }

    @Test func expiredSessionMeansNoToken() {
        let name = "__Secure-neon-auth.session_token"
        let past = StoredSession(cookieName: name, cookieValue: "v", userID: "u", email: nil, expiresAt: Date(timeIntervalSinceNow: -10))
        #expect(NeonAuthClient(config: config, storage: InMemoryAuthStorage(past)).storedAccessToken() == nil)
        let ok = StoredSession(cookieName: name, cookieValue: "v", userID: "u", email: nil, expiresAt: Date(timeIntervalSinceNow: 3600))
        #expect(NeonAuthClient(config: config, storage: InMemoryAuthStorage(ok)).storedAccessToken() == "\(name)=v")
        let other = StoredSession(cookieName: "n", cookieValue: "v", userID: "u", email: nil, expiresAt: Date(timeIntervalSinceNow: 3600))
        #expect(NeonAuthClient(config: config, storage: InMemoryAuthStorage(other)).storedAccessToken() == nil)
    }

    @Test func signInStoresSessionCookie() async throws {
        let rec = Recorder()
        let storage = InMemoryAuthStorage()
        let client = NeonAuthClient(config: config, storage: storage, transport: transport(rec, body: signInBody, headers: ["Set-Cookie": cookie]))
        let s = try await client.signIn(email: "a@b.cz", password: "secret123")
        #expect(s.cookieHeader == "__Secure-neon-auth.session_token=tok.sig")
        #expect(s.userID == "7f6c2b1e-1111-4222-8333-444455556666")
        #expect(storage.load() == s)
        let req = try #require(rec.requests.first)
        #expect(req.url?.absoluteString == "https://tokeny.example/api/auth/sign-in/email")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "Origin") == "https://tokeny.example")
        #expect(req.httpShouldHandleCookies == false)
        #expect(req.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(req.url?.query == nil)
        #expect(req.url?.absoluteString.contains("secret") == false)
        let body = try JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: String]
        #expect(body?["email"] == "a@b.cz")
        #expect(body?["password"] == "secret123")
    }

    @Test func wrongPasswordThrowsBetterAuthCode() async {
        let rec = Recorder()
        let client = NeonAuthClient(
            config: config, storage: InMemoryAuthStorage(),
            transport: transport(rec, status: 401, body: #"{"code":"INVALID_EMAIL_OR_PASSWORD","message":"Invalid email or password"}"#))
        await #expect(throws: NeonAuthError(status: 401, code: "INVALID_EMAIL_OR_PASSWORD", message: "Invalid email or password")) {
            try await client.signIn(email: "a@b.cz", password: "x")
        }
    }

    @Test func signUpWithoutCookieNeedsConfirmation() async throws {
        let rec = Recorder()
        let client = NeonAuthClient(config: config, storage: InMemoryAuthStorage(), transport: transport(rec, body: signInBody))
        #expect(try await client.signUp(email: "a@b.cz", password: "secret123") == nil)
        let body = try JSONSerialization.jsonObject(with: rec.requests[0].httpBody ?? Data()) as? [String: String]
        #expect(body?["name"] == "a")
    }

    @Test func refreshClearsRevokedSession() async throws {
        let rec = Recorder()
        let start = StoredSession(cookieName: "__Secure-neon-auth.session_token", cookieValue: "v", userID: "u", email: nil, expiresAt: nil)
        let storage = InMemoryAuthStorage(start)
        let client = NeonAuthClient(config: config, storage: storage, transport: transport(rec, body: "null"))
        #expect(try await client.refresh() == nil)
        #expect(storage.load() == nil)
        #expect(rec.requests.first?.value(forHTTPHeaderField: "Cookie") == "__Secure-neon-auth.session_token=v")
    }

    @Test func refreshUpdatesExpiry() async throws {
        let rec = Recorder()
        let start = StoredSession(cookieName: "__Secure-neon-auth.session_token", cookieValue: "v", userID: "u", email: nil, expiresAt: nil)
        let storage = InMemoryAuthStorage(start)
        let body = #"{"session":{"expiresAt":"2030-01-02T03:04:05.000Z"},"user":{"id":"u2","email":"x@y.cz"}}"#
        let client = NeonAuthClient(config: config, storage: storage, transport: transport(rec, body: body))
        let s = try #require(try await client.refresh())
        #expect(s.userID == "u2")
        #expect(s.email == "x@y.cz")
        #expect(s.expiresAt == Date(timeIntervalSince1970: 1_893_553_445))
    }

    @Test func signOutAlwaysClearsLocally() async {
        let rec = Recorder()
        let start = StoredSession(cookieName: "n", cookieValue: "v", userID: "u", email: nil, expiresAt: nil)
        let storage = InMemoryAuthStorage(start)
        let client = NeonAuthClient(config: config, storage: storage, transport: { _ in throw URLError(.notConnectedToInternet) })
        await client.signOut()
        #expect(storage.load() == nil)
        _ = rec
    }

    @Test func appleIdentityTokenIsNotSent() async {
        let rec = Recorder()
        let client = NeonAuthClient(
            config: config, storage: InMemoryAuthStorage(), transport: transport(rec, body: signInBody, headers: ["Set-Cookie": cookie]))
        await #expect(throws: NeonAuthError(status: 0, code: "NATIVE_APPLE_SIGN_IN_UNSUPPORTED", message: nil)) {
            try await client.signInWithApple(idToken: "idtok", rawNonce: "n0nce")
        }
        #expect(rec.requests.isEmpty)
    }

    /// Sign-in reports success from the response, then the first credential read signs out when
    /// the session was not actually stored. That is the unsigned-simulator drop: the Keychain
    /// write is rejected and the dashboard's refresh treats the missing session as unauthorized.
    @Test @MainActor func unreadSessionSignsOutOnTheFirstCredentialRequest() async throws {
        let client = NeonAuthClient(
            config: config, storage: ForgetfulStorage(),
            transport: transport(Recorder(), body: signInBody, headers: ["Set-Cookie": cookie]))
        let auth = AuthService(client: client)
        try await auth.signIn(email: "a@b.cz", password: "secret123")
        #expect(auth.isSignedIn)
        await #expect(throws: UsageAPIError.unauthorized) {
            try await auth.accessToken()
        }
        #expect(!auth.isSignedIn)
    }

    #if canImport(Security)
        @Test func sessionFileSurvivesWhenTheKeychainRefusesEveryWrite() {
            let service = "cz.martinpohl.tokeny.auth.test.\(UUID().uuidString)"
            let session = StoredSession(
                cookieName: "__Secure-neon-auth.session_token", cookieValue: "tok.sig",
                userID: "7f6c2b1e-1111-4222-8333-444455556666", email: "a@b.cz", expiresAt: nil)
            var writer = KeychainAuthStorage(service: service, account: "session", accessGroup: "cz.martinpohl.tokeny.shared")
            writer.keychainDenied = true
            writer.save(session)
            var reader = KeychainAuthStorage(service: service, account: "session", accessGroup: "cz.martinpohl.tokeny.shared")
            reader.keychainDenied = true
            #expect(reader.load() == session)
            reader.save(nil)
            #expect(reader.load() == nil)
        }

        @Test func sessionSurvivesAnUnentitledKeychainAccessGroup() {
            let service = "cz.martinpohl.tokeny.auth.test.\(UUID().uuidString)"
            let group = "cz.martinpohl.tokeny.shared.unentitled"
            let session = StoredSession(
                cookieName: "__Secure-neon-auth.session_token", cookieValue: "tok.sig",
                userID: "7f6c2b1e-1111-4222-8333-444455556666", email: "a@b.cz", expiresAt: nil)
            let writer = KeychainAuthStorage(service: service, account: "session", accessGroup: group)
            writer.save(session)
            let reader = KeychainAuthStorage(service: service, account: "session", accessGroup: group)
            #expect(reader.load() == session)
            reader.save(nil)
            #expect(reader.load() == nil)
        }
    #endif

    @Test func rejectsSessionCookieThatIsNotNeonAuth() async {
        let rec = Recorder()
        let storage = InMemoryAuthStorage()
        let client = NeonAuthClient(
            config: config, storage: storage,
            transport: transport(rec, body: signInBody, headers: ["Set-Cookie": "session_token=abc; Path=/; HttpOnly"]))
        await #expect(throws: NeonAuthError(status: 200, code: "UNSUPPORTED_SESSION_COOKIE", message: nil)) {
            try await client.signIn(email: "a@b.cz", password: "secret123")
        }
        #expect(storage.load() == nil)
    }
}
