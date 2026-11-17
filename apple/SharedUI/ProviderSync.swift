import Foundation
import TokenyCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Loads usage from the three documented APIs. The key is a header, never part of the URL.
enum ProviderSync {
    static func fetch(provider: String, apiKey: String) async throws -> [ImportedActivity] {
        let window = ProviderAPI.window(ending: Date())
        switch provider {
        case "openai":
            let usage = try await collect(secret: apiKey) { page in
                ProviderAPI.openAIUsage(apiKey: apiKey, start: window.start, end: window.end, page: page)
            } next: { ProviderAPI.nextPage(openAI: $0) }
            let costs = try await collect(secret: apiKey) { page in
                ProviderAPI.openAICosts(apiKey: apiKey, start: window.start, end: window.end, page: page)
            } next: { ProviderAPI.nextPage(openAI: $0) }
            let empty = Data("{\"data\":[]}".utf8)
            return try usage.flatMap { try ProviderAPI.openAIRows(usage: $0, costs: empty) }
                + costs.flatMap { try ProviderAPI.openAIRows(usage: empty, costs: $0) }
        case "anthropic":
            let usage = try await collect(secret: apiKey) { page in
                ProviderAPI.anthropicUsage(apiKey: apiKey, start: window.start, end: window.end, page: page)
            } next: { ProviderAPI.nextPage(openAI: $0) }
            let costs = try await collect(secret: apiKey) { page in
                ProviderAPI.anthropicCost(apiKey: apiKey, start: window.start, end: window.end, page: page)
            } next: { ProviderAPI.nextPage(openAI: $0) }
            let empty = Data("{\"data\":[]}".utf8)
            return try usage.flatMap { try ProviderAPI.anthropicRows(usage: $0, costs: empty) }
                + costs.flatMap { try ProviderAPI.anthropicRows(usage: empty, costs: $0) }
        case "cursor":
            let pages = try await collect(secret: apiKey) { page in
                ProviderAPI.cursorBilling(apiKey: apiKey, start: window.start, end: window.end, page: page)
            } next: { ProviderAPI.nextPage(cursor: $0) }
            return try pages.flatMap { try ProviderAPI.cursorRows($0) }
        default:
            throw ProviderAPIError.unexpected
        }
    }

    private static func collect(
        secret: String, call: (String?) -> ProviderCall, next: (Data) -> String?
    ) async throws -> [Data] {
        var pages: [Data] = []
        var cursor: String?
        var seen: Set<String> = []
        for _ in 0..<8 {
            let data = try await send(call(cursor), secret: secret)
            pages.append(data)
            guard let page = next(data), !seen.contains(page) else { break }
            seen.insert(page)
            cursor = page
        }
        return pages
    }

    private static func send(_ call: ProviderCall, secret: String) async throws -> Data {
        guard ProviderEndpoint.isAllowed(call.url) else { throw ProviderAPIError.unexpected }
        var request = URLRequest(url: call.url)
        request.timeoutInterval = 30
        for (field, value) in call.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProviderAPIError.unexpected }
            switch http.statusCode {
            case 200..<300:
                return data
            case 401:
                throw ProviderAPIError.unauthorized
            case 403:
                throw ProviderAPIError.forbidden
            case 429:
                throw ProviderAPIError.rateLimited
            case 400:
                throw ProviderAPIError.badRequest
            default:
                throw ProviderAPIError.unreachable
            }
        } catch let error as ProviderAPIError {
            throw error
        } catch {
            _ = ProviderAPI.redact(error.localizedDescription, secret: secret)
            throw ProviderAPIError.unreachable
        }
    }
}

enum ImportErrorText {
    static func message(for error: UsageImportError) -> String {
        switch error {
        case .empty:
            String(localized: "No usable rows in that file.")
        case .unrecognized:
            String(localized: "This file is not a usage export Tokeny can read.")
        case .tooLarge:
            String(localized: "That file is too large to open in the app.")
        }
    }

    static func message(for error: ProviderAPIError) -> String {
        switch error {
        case .unauthorized:
            String(localized: "The key was not accepted. Check that you copied all of it.")
        case .forbidden:
            String(localized: "This key cannot read usage. Create a read-only usage key.")
        case .rateLimited:
            String(localized: "The provider is limiting requests. Try again in a minute.")
        case .badRequest:
            String(localized: "The provider rejected the request. Check the key type in the steps above.")
        case .unexpected, .unreachable:
            String(localized: "Tokeny cannot reach the provider right now. A CSV still works offline.")
        }
    }
}
