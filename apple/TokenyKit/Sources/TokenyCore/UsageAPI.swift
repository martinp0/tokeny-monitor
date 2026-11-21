import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public enum UsageAPIError: Error, Equatable, Sendable {
    /// Missing or expired session: sign in again.
    case unauthorized
    /// The server refused a Pro-only request (`{"error":"pro_required"}`).
    case proRequired
    /// The `/api/usage-summary` endpoint is missing (server being deployed or rolled back).
    case notDeployed
    case server(status: Int)
    case offline
    case badResponse
}

/// Talks to the Tokeny API (`/api/*` on the web origin) as the signed-in user.
/// Read-only except ``deleteAccount(accessToken:)`` and ``syncAppleTransactions``.
///
/// `accessToken` is the credential from ``TokenyAuth``: either the Neon Auth session cookie
/// (`name=value`, sent as `Cookie`) or a Neon Auth JWT (sent as `Authorization: Bearer`).
/// The server accepts both (server/auth.ts).
public struct UsageAPI: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public let config: AppConfig
    private let transport: Transport

    public init(config: AppConfig = .production, transport: Transport? = nil) {
        self.config = config
        self.transport = transport ?? { request in try await URLSession.shared.data(for: request) }
    }

    public func summaryRequest(accessToken: String, timeZone: TimeZone = .current) -> URLRequest {
        var comps = URLComponents(url: config.apiURL.appending(path: "usage-summary"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "tz", value: timeZone.identifier)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        authorize(&req, accessToken: accessToken)
        return req
    }

    public func fetchSummary(accessToken: String, timeZone: TimeZone = .current) async throws -> UsageSummary {
        guard Self.classifyCredential(accessToken) != nil else { throw UsageAPIError.unauthorized }
        let data = try await send(summaryRequest(accessToken: accessToken, timeZone: timeZone))
        return try Self.decodeSummary(data)
    }

    /// `GET /api/insights`. Same body as `server/insights.ts` (`PublicInsights` plus `tz` and `window`).
    /// A missing route is an empty list.
    public func insightsRequest(accessToken: String, timeZone: TimeZone = .current, languageCode: String = "cs") -> URLRequest {
        var comps = URLComponents(url: config.apiURL.appending(path: "insights"), resolvingAgainstBaseURL: false)!
        let lang = languageCode.lowercased().hasPrefix("cs") ? "cs" : "en"
        comps.queryItems = [
            URLQueryItem(name: "tz", value: timeZone.identifier),
            URLQueryItem(name: "lang", value: lang),
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        authorize(&req, accessToken: accessToken)
        return req
    }

    public func fetchInsights(accessToken: String, timeZone: TimeZone = .current, languageCode: String = "cs") async throws -> [AccountInsight] {
        guard Self.classifyCredential(accessToken) != nil else { throw UsageAPIError.unauthorized }
        do {
            let data = try await send(insightsRequest(accessToken: accessToken, timeZone: timeZone, languageCode: languageCode))
            return try Self.decodeInsights(data)
        } catch UsageAPIError.notDeployed {
            return []
        }
    }

    /// Reads `tips` from the insights report. Exact savings keep their USD. A Free band stays a range.
    public static func decodeInsights(_ data: Data) throws -> [AccountInsight] {
        let payload: InsightReportPayload
        do {
            payload = try JSONDecoder().decode(InsightReportPayload.self, from: data)
        } catch {
            throw UsageAPIError.badResponse
        }
        var seen: Set<String> = []
        return payload.tips.compactMap { tip in
            let explanation = tip.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tip.id.isEmpty, !explanation.isEmpty else { return nil }
            var id = tip.id
            if seen.contains(id) { id = "\(id)-\(seen.count)" }
            seen.insert(id)
            return AccountInsight(id: id, kind: tip.kind, explanation: explanation, saving: tip.saving?.value)
        }
    }

    private struct InsightReportPayload: Decodable {
        var tips: [ServerTip]
    }

    private struct ServerTip: Decodable {
        var id: String
        var kind: String
        var explanation: String
        var saving: ServerMoney?
    }

    private struct ServerMoney: Decodable {
        var value: InsightSaving

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "exact":
                value = .exact(usd: try container.decode(Double.self, forKey: .usd))
            case "range":
                value = .band(
                    lowUSD: try container.decode(Double.self, forKey: .lowUSD),
                    highUSD: try container.decodeIfPresent(Double.self, forKey: .highUSD))
            default:
                throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "unknown money kind")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case kind, usd
            case lowUSD = "low_usd"
            case highUSD = "high_usd"
        }
    }

    /// Result of posting StoreKit signed transactions. The plan is whatever the server stored.
    public struct AppleSyncResult: Decodable, Equatable, Sendable {
        public var isPro: Bool
        public var accepted: Int
    }

    /// `POST /api/apple/transactions` with each entitlement's `jwsRepresentation`.
    public func appleTransactionsRequest(accessToken: String, signedTransactions: [String]) throws -> URLRequest {
        guard Self.classifyCredential(accessToken) != nil else { throw UsageAPIError.unauthorized }
        var req = URLRequest(url: config.apiURL.appending(path: "apple").appending(path: "transactions"))
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&req, accessToken: accessToken)
        req.httpBody = try JSONSerialization.data(withJSONObject: ["signedTransactions": signedTransactions])
        return req
    }

    public func syncAppleTransactions(accessToken: String, signedTransactions: [String]) async throws -> AppleSyncResult {
        let data = try await send(try appleTransactionsRequest(accessToken: accessToken, signedTransactions: signedTransactions))
        do {
            return try JSONDecoder().decode(AppleSyncResult.self, from: data)
        } catch {
            throw UsageAPIError.badResponse
        }
    }

    /// Deletes the account and all its data (App Store guideline 5.1.1(v)); same as on the web.
    public func deleteAccount(accessToken: String) async throws {
        guard Self.classifyCredential(accessToken) != nil else { throw UsageAPIError.unauthorized }
        var req = URLRequest(url: config.apiURL.appending(path: "account").appending(path: "delete"))
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        authorize(&req, accessToken: accessToken)
        _ = try await send(req)
    }

    public static func decodeSummary(_ data: Data) throws -> UsageSummary {
        do {
            return try JSONDecoder().decode(UsageSummary.self, from: data)
        } catch {
            throw UsageAPIError.badResponse
        }
    }

    /// Maps an HTTP status (and error body) to ``UsageAPIError``; nil means success.
    public static func error(status: Int, body: Data) -> UsageAPIError? {
        switch status {
        case 200..<300: return nil
        case 401: return .unauthorized
        case 403:
            if let e = try? JSONDecoder().decode(ErrorBody.self, from: body), e.error == "pro_required" {
                return .proRequired
            }
            return .unauthorized
        case 404: return .notDeployed
        default: return .server(status: status)
        }
    }

    private struct ErrorBody: Decodable {
        var error: String?
    }

    private func authorize(_ req: inout URLRequest, accessToken: String) {
        Self.authorize(&req, credential: accessToken)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    /// A credential this client is allowed to send.
    ///
    /// Session cookie: one `neon-auth`…`session_token` pair, the cookie the same-origin proxy sets
    /// (`server/auth.ts` accepts it). Bearer: a three-segment JWT shape. The server verifies that
    /// JWT against the Neon Auth JWKS; this app does not obtain one. A browser cookie jar, an
    /// `orm_` personal token, or any other string is not attached.
    public enum APICredential: Equatable, Sendable {
        case sessionCookie(String)
        case bearerJWT(String)
    }

    public static func classifyCredential(_ raw: String) -> APICredential? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains(";") || trimmed.contains("\n") || trimmed.contains("\r") || trimmed.contains(" ") {
            return nil
        }
        if isJWT(trimmed) { return .bearerJWT(trimmed) }
        guard let eq = trimmed.firstIndex(of: "=") else { return nil }
        let name = String(trimmed[..<eq])
        let value = String(trimmed[trimmed.index(after: eq)...])
        guard name.contains("neon-auth"), name.hasSuffix("session_token"), !value.isEmpty,
            name.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
        else { return nil }
        return .sessionCookie("\(name)=\(value)")
    }

    /// Puts a Neon Auth session cookie in `Cookie`, or a JWT-shaped token in `Authorization`.
    /// URLSession's shared cookie jar is never involved. Unrecognized credentials add no header.
    public static func authorize(_ req: inout URLRequest, credential: String) {
        req.httpShouldHandleCookies = false
        switch classifyCredential(credential) {
        case .sessionCookie(let header):
            req.setValue(header, forHTTPHeaderField: "Cookie")
        case .bearerJWT(let token):
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case nil:
            break
        }
    }

    private static func isJWT(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.range(of: #"^[A-Za-z0-9_-]+={0,2}$"#, options: .regularExpression) != nil
        }
    }

}

/// A saving from `GET /api/insights`. Exact USD is Pro. A band is the Free plan's published range, not a midpoint.
public enum InsightSaving: Equatable, Sendable {
    case exact(usd: Double)
    case band(lowUSD: Double, highUSD: Double?)

    /// Sort key. A band uses its lower edge, which the server already computed.
    public var sortUSD: Double {
        switch self {
        case .exact(let usd): usd
        case .band(let lowUSD, _): lowUSD
        }
    }
}

/// One tip from the `tips` array of `GET /api/insights`.
public struct AccountInsight: Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var explanation: String
    public var saving: InsightSaving?

    public init(id: String, kind: String, explanation: String, saving: InsightSaving?) {
        self.id = id
        self.kind = kind
        self.explanation = explanation
        self.saving = saving
    }
}

extension UsageAPI {
    fileprivate func send(_ req: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(req)
        } catch is CancellationError {
            throw CancellationError()
        } catch let e as URLError where e.code == .cancelled {
            throw CancellationError()
        } catch {
            throw UsageAPIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw UsageAPIError.badResponse }
        if let e = Self.error(status: http.statusCode, body: data) { throw e }
        return data
    }
}
