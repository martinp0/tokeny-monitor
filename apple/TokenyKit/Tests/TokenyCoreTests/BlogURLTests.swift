import Foundation
import Testing

@testable import TokenyCore

struct BlogURLTests {
    private let production = AppConfig.production

    @Test func czechInterfaceOpensTheCzechBlog() {
        for code in ["cs", "CS", "cs-CZ", "cs_CZ", "  cs-CZ  "] {
            let url = production.blogURL(languageCode: code)
            #expect(url.absoluteString == "https://tokeny.martinpohl.cz/blog", "\(code)")
            expectPlainHTTPS(url)
        }
    }

    @Test func everyOtherInterfaceLanguageOpensTheEnglishBlog() {
        let codes: [String?] = ["en", "en-US", "en_GB", "en-CZ", "EN", "de", "sk", "sk-SK", "cz", "fr", "", "  ", nil]
        for code in codes {
            let url = production.blogURL(languageCode: code)
            #expect(url.absoluteString == "https://tokeny.martinpohl.cz/en/blog", "\(code ?? "nil")")
            expectPlainHTTPS(url)
        }
    }

    @Test func blogFollowsTheConfiguredHost() {
        let config = AppConfig(webURL: URL(string: "https://tokeny.example")!, appGroup: "group.test")
        #expect(config.blogURL(languageCode: "cs").absoluteString == "https://tokeny.example/blog")
        #expect(config.blogURL(languageCode: "en").absoluteString == "https://tokeny.example/en/blog")
    }

    private func expectPlainHTTPS(_ url: URL) {
        #expect(url.scheme == "https")
        #expect(url.query == nil)
        #expect(url.fragment == nil)
    }
}
