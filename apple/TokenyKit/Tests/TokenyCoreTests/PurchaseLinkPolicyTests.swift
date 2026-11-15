import Foundation
import Testing

@testable import TokenyCore

struct PurchaseLinkPolicyTests {
    @Test func noStorefrontLinksToWebCheckout() {
        for code in ["USA", "usa", "CZE", "DEU", "FRA", "GBR", "US", "", nil] {
            #expect(!PurchaseLinkPolicy.allowsPurchaseLinks(storefrontCountryCode: code), "\(code ?? "nil")")
        }
    }

    @Test func accountLinkIsTheProfilePage() {
        let config = AppConfig.production
        #expect(PurchaseLinkPolicy.accountURL(for: config).path() == "/profile")
    }
}
