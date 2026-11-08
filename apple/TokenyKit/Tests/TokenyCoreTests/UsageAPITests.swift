import Foundation
import Testing

@testable import TokenyCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

private let config = AppConfig(webURL: URL(string: "https://tokeny.example")!, appGroup: "group.test")

private func stub(status: Int, body: Data, capture: (@Sendable (URLRequest) -> Void)? = nil) -> UsageAPI.Transport {
    { request in
        capture?(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private final class Box: @unchecked Sendable {
    var request: URLRequest?
}

@Suite("UsageAPI")
struct UsageAPITests {
    @Test func buildsSummaryRequest() throws {
        let api = UsageAPI(config: config)
        let req = api.summaryRequest(accessToken: Self.jwt, timeZone: TimeZone(identifier: "Europe/Prague")!)
        #expect(req.httpMethod == "GET")
        #expect(req.url?.absoluteString == "https://tokeny.example/api/usage-summary?tz=Europe/Prague")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.jwt)")
        #expect(req.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(req.httpShouldHandleCookies == false)
    }

    @Test func sessionCookieGoesInCookieHeader() {
        let req = UsageAPI(config: config).summaryRequest(accessToken: "__Secure-neon-auth.session_token=abc.def")
        #expect(req.value(forHTTPHeaderField: "Cookie") == "__Secure-neon-auth.session_token=abc.def")
        #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func fetchesAndDecodes() async throws {
        let box = Box()
        let api = UsageAPI(config: config, transport: stub(status: 200, body: Fixtures.proSummary) { box.request = $0 })
        let s = try await api.fetchSummary(accessToken: Self.jwt, timeZone: TimeZone(identifier: "UTC")!)
        #expect(s.month.costUSD == 38.2)
        #expect(box.request?.url?.query == "tz=UTC" || box.request?.url?.query == "tz=GMT")
    }

    @Test func mapsErrors() async {
        let cases: [(Int, String, UsageAPIError)] = [
            (401, #"{"error":"Unauthorized"}"#, .unauthorized),
            (403, #"{"error":"pro_required","feature":"mcp"}"#, .proRequired),
            (403, #"{"error":"Forbidden"}"#, .unauthorized),
            (404, "", .notDeployed),
            (500, #"{"error":"Internal server error"}"#, .server(status: 500)),
        ]
        for (status, body, expected) in cases {
            let api = UsageAPI(config: config, transport: stub(status: status, body: Data(body.utf8)))
            await #expect(throws: expected) { try await api.fetchSummary(accessToken: Self.jwt) }
        }
    }

    @Test func networkFailureIsOffline() async {
        let api = UsageAPI(config: config, transport: { _ in throw URLError(.notConnectedToInternet) })
        await #expect(throws: UsageAPIError.offline) { try await api.fetchSummary(accessToken: Self.jwt) }
    }

    @Test func cancellationIsNotAnError() async {
        let api = UsageAPI(config: config, transport: { _ in throw URLError(.cancelled) })
        await #expect(throws: CancellationError.self) { try await api.fetchSummary(accessToken: Self.jwt) }
    }

    @Test func deleteAccountPosts() async throws {
        let box = Box()
        let api = UsageAPI(
            config: config, transport: stub(status: 200, body: Data(#"{"success":true}"#.utf8)) { box.request = $0 })
        try await api.deleteAccount(accessToken: Self.jwt)
        #expect(box.request?.httpMethod == "POST")
        #expect(box.request?.url?.path == "/api/account/delete")
        #expect(box.request?.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.jwt)")
        #expect(box.request?.httpShouldHandleCookies == false)
    }

    /// Three base64url segments. Not a real Neon Auth JWT and never sent to production by these tests.
    private static let jwt = "e30.e30.e30"

    @Test func refusesUntrustedCredentialsWithoutARequest() async {
        let api = UsageAPI(config: config, transport: { _ in
            Issue.record("transport must not run")
            throw URLError(.badURL)
        })
        let rejected = [
            "jwt123",
            "orm_personal",
            "a=1; __Secure-neon-auth.session_token=abc",
            "session_token=abc",
            "Cookie: __Secure-neon-auth.session_token=abc",
        ]
        for credential in rejected {
            await #expect(throws: UsageAPIError.unauthorized) {
                try await api.fetchSummary(accessToken: credential)
            }
            #expect(UsageAPI.classifyCredential(credential) == nil)
        }
    }

    @Test func paddedJWTIsBearerNotACookie() {
        var req = URLRequest(url: URL(string: "https://tokeny.example/api/usage-summary")!)
        let token = "eyJhbGciOiJFZERTQSJ9.eyJzdWIiOiJ4In0=.c2ln"
        UsageAPI.authorize(&req, credential: token)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
        #expect(req.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(req.httpShouldHandleCookies == false)
    }

    @Test func configURLs() {
        #expect(config.apiURL.absoluteString == "https://tokeny.example/api")
        #expect(config.authURL.absoluteString == "https://tokeny.example/api/auth")
        #expect(config.accountURL.absoluteString == "https://tokeny.example/settings")
        #expect(config.resetPasswordURL(email: "a@b.cz").absoluteString == "https://tokeny.example/reset-password?email=a@b.cz")
        #expect(AppConfig.production.webURL.host == "tokeny.martinpohl.cz")
    }

    @Test func configFromInfoPlist() {
        #expect(AppConfig.fromInfo(["TokenyWebHost": "tokeny.pohl.uk"]).webURL.absoluteString == "https://tokeny.pohl.uk")
        // A pasted full URL is tolerated.
        #expect(AppConfig.fromInfo(["TokenyWebHost": "https://x.example/"]).webURL.absoluteString == "https://x.example")
        // Missing or unexpanded build settings fall back to the built-in origin.
        #expect(AppConfig.fromInfo(["TokenyWebHost": "$(TOKENY_WEB_HOST)"]).webURL.host == AppConfig.fallbackWebHost)
        #expect(AppConfig.fromInfo([:]).webURL.host == AppConfig.fallbackWebHost)
    }
}
