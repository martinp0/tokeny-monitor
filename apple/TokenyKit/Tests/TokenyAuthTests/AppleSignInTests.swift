import Foundation
import Testing
import TokenyCore

@testable import TokenyAuth

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

private let config = AppConfig(webURL: URL(string: "https://tokeny.example")!, appGroup: "group.test")
private let signInBody = #"{"token":"raw","user":{"id":"7f6c2b1e-1111-4222-8333-444455556666","email":"a@b.cz"}}"#
private let cookie = "__Secure-neon-auth.session_token=tok.sig; Path=/; Max-Age=604800; HttpOnly; Secure; SameSite=Lax"

private func transport(status: Int = 200, body: String, headers: [String: String] = [:]) -> NeonAuthClient.Transport {
    { req in
        let res = HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        return (Data(body.utf8), res)
    }
}

@Suite("Sign in with Apple")
struct AppleSignInTests {
    @Test @MainActor func providerNotSupportedBecomesALocalIdentity() async throws {
        let local = InMemoryLocalAccountStore()
        let client = NeonAuthClient(
            config: config, storage: InMemoryAuthStorage(),
            transport: transport(
                status: 400,
                body: #"{"error":"Provider is not supported or enabled for this project","code":"PROVIDER_NOT_SUPPORTED"}"#))
        let auth = AuthService(client: client, localAccounts: local)
        let result = try await auth.signInWithApple(
            idToken: "idtok", nonce: AppleSignInNonce(raw: "n0nce"),
            appleUserID: "apple.user.1", email: "a@privaterelay.appleid.com", name: "Ada")
        #expect(result == .local)
        #expect(auth.isLocalIdentity)
        #expect(auth.isSignedIn)
        #expect(auth.email == "a@privaterelay.appleid.com")
        #expect(local.load()?.name == "Ada")
        #expect(client.currentSession == nil)

        let again = try await auth.signInWithApple(
            idToken: "idtok", nonce: AppleSignInNonce(raw: "n0nce"),
            appleUserID: "apple.user.1", email: nil, name: " ")
        #expect(again == .local)
        #expect(auth.email == "a@privaterelay.appleid.com")
        #expect(local.load()?.name == "Ada")
    }

    @Test @MainActor func acceptedIdentityTokenBecomesAServerSession() async throws {
        let local = InMemoryLocalAccountStore(LocalAccount(appleUserID: "old", email: "old@apple.com", name: nil))
        let storage = InMemoryAuthStorage()
        let client = NeonAuthClient(
            config: config, storage: storage,
            transport: transport(body: signInBody, headers: ["Set-Cookie": cookie]))
        let auth = AuthService(client: client, localAccounts: local)
        let result = try await auth.signInWithApple(
            idToken: "idtok", nonce: AppleSignInNonce(raw: "n0nce"),
            appleUserID: "apple.user.1", email: "hide@apple.com", name: "Ada")
        #expect(result == .server)
        #expect(!auth.isLocalIdentity)
        #expect(auth.email == "a@b.cz")
        #expect(local.load() == nil)
        #expect(storage.load()?.userID == "7f6c2b1e-1111-4222-8333-444455556666")
    }

    @Test @MainActor func invalidTokenDoesNotCreateALocalIdentity() async {
        let local = InMemoryLocalAccountStore()
        let client = NeonAuthClient(
            config: config, storage: InMemoryAuthStorage(),
            transport: transport(status: 401, body: #"{"code":"INVALID_TOKEN","message":"bad token"}"#))
        let auth = AuthService(client: client, localAccounts: local)
        await #expect(throws: NeonAuthError(status: 401, code: "INVALID_TOKEN", message: "bad token")) {
            try await auth.signInWithApple(
                idToken: "idtok", nonce: AppleSignInNonce(raw: "n0nce"),
                appleUserID: "apple.user.1", email: nil, name: nil)
        }
        #expect(local.load() == nil)
        #expect(!auth.isSignedIn)
    }

    @Test @MainActor func offlineDoesNotCreateALocalIdentity() async {
        let local = InMemoryLocalAccountStore()
        let client = NeonAuthClient(config: config, storage: InMemoryAuthStorage(), transport: { _ in throw URLError(.notConnectedToInternet) })
        let auth = AuthService(client: client, localAccounts: local)
        await #expect(throws: URLError.self) {
            try await auth.signInWithApple(
                idToken: "idtok", nonce: AppleSignInNonce(raw: "n0nce"),
                appleUserID: "apple.user.1", email: nil, name: nil)
        }
        #expect(local.load() == nil)
        #expect(!auth.isSignedIn)
    }

    @Test @MainActor func signOutAndLocalDeleteForgetTheAppleIdentity() async throws {
        let local = InMemoryLocalAccountStore()
        let calls = CallCounter()
        let api = UsageAPI(config: config) { _ in
            calls.hit()
            throw URLError(.badServerResponse)
        }
        let client = NeonAuthClient(
            config: config, storage: InMemoryAuthStorage(),
            transport: transport(
                status: 400,
                body: #"{"code":"PROVIDER_NOT_SUPPORTED","message":"Provider is not supported"}"#))
        let auth = AuthService(client: client, api: api, localAccounts: local)
        _ = try await auth.signInWithApple(
            idToken: "idtok", nonce: AppleSignInNonce(raw: "n0nce"),
            appleUserID: "apple.user.1", email: nil, name: nil)
        try await auth.deleteAccount()
        #expect(calls.count == 0)
        #expect(local.load() == nil)
        #expect(!auth.isSignedIn)
    }

    @Test func audienceMismatchFallsBack() {
        let error = NeonAuthError(status: 401, code: nil, message: "JWTClaimValidationFailed: unexpected \"aud\" claim value")
        #expect(AppleSignInFallback.shouldUseLocalIdentity(error))
        #expect(!AppleSignInFallback.shouldUseLocalIdentity(NeonAuthError(status: 401, code: "INVALID_TOKEN", message: "bad token")))
    }
}

private final class CallCounter: @unchecked Sendable {
    var count = 0
    func hit() { count += 1 }
}
