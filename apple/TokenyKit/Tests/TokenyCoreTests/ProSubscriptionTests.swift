import Foundation
import Testing

@testable import TokenyCore

struct ProSubscriptionTests {
    @Test func productIDsAndCzechReferencePrices() {
        #expect(ProProduct.monthly.rawValue == "cz.martinpohl.tokeny.pro.monthly")
        #expect(ProProduct.yearly.rawValue == "cz.martinpohl.tokeny.pro.yearly")
        #expect(ProProduct.monthly.referencePriceCZK == 49)
        #expect(ProProduct.yearly.referencePriceCZK == 399)
        #expect(ProProduct.monthly.referencePriceLabel == "49 Kč")
        #expect(ProProduct.groupReferenceName == "Tokeny Pro")
        #expect(ProProduct.allIDs.count == 2)
    }

    @Test func entitlementIgnoresUnknownRevokedAndExpired() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let active = ProEntitlement(productID: ProProduct.monthly.rawValue, expiresAt: now.addingTimeInterval(60), revoked: false)
        let yearly = ProEntitlement(productID: ProProduct.yearly.rawValue, expiresAt: nil, revoked: false)
        let expired = ProEntitlement(productID: ProProduct.monthly.rawValue, expiresAt: now, revoked: false)
        let revoked = ProEntitlement(productID: ProProduct.yearly.rawValue, expiresAt: now.addingTimeInterval(60), revoked: true)
        let other = ProEntitlement(productID: "other.product", expiresAt: nil, revoked: false)
        #expect(active.isActive(at: now))
        #expect(yearly.isActive(at: now))
        #expect(!expired.isActive(at: now))
        #expect(!revoked.isActive(at: now))
        #expect(!other.isActive(at: now))
        #expect(ProAccess.isStoreEntitled([expired, other, active], now: now))
        #expect(!ProAccess.isStoreEntitled([expired, revoked], now: now))
    }

    @Test func paywallHidesWhenEitherPlanIsPro() {
        #expect(ProAccess.showsPaywall(serverPlanIsPro: false, storeEntitled: false))
        #expect(!ProAccess.showsPaywall(serverPlanIsPro: true, storeEntitled: false))
        #expect(!ProAccess.showsPaywall(serverPlanIsPro: false, storeEntitled: true))
        #expect(ProAccess.hasPro(serverPlanIsPro: false, storeEntitled: true))
        #expect(!ProAccess.hasPro(serverPlanIsPro: false, storeEntitled: false))
    }

    @Test func legalCopyCoversRenewalWithdrawalAndLinks() {
        let config = AppConfig(webURL: URL(string: "https://tokeny.example")!, appGroup: "group.test")
        #expect(ProLegal.privacyURL(for: config).absoluteString == "https://tokeny.example/privacy")
        #expect(ProLegal.termsURL(for: config).absoluteString == "https://tokeny.example/terms")
        #expect(ProLegal.appleStandardEULA.absoluteString.contains("stdeula"))

        let cs = ProLegal.disclosure(languageCode: "cs-CZ", monthlyPrice: "49 Kč", yearlyPrice: "399 Kč")
        #expect(cs.contains("49 Kč"))
        #expect(cs.contains("399 Kč"))
        #expect(cs.contains("automaticky"))
        #expect(cs.contains("24 hodin"))
        #expect(cs.contains("Apple ID"))
        #expect(cs.contains("1837"))
        #expect(cs.contains("1834"))
        #expect(cs.contains("odstoupení"))

        let en = ProLegal.disclosure(languageCode: nil, monthlyPrice: "€1.99", yearlyPrice: "€15.99")
        #expect(en.contains("€1.99"))
        #expect(en.contains("€15.99"))
        #expect(en.contains("automatically"))
        #expect(en.contains("24 hours"))
        #expect(en.contains("Apple ID"))
        #expect(en.contains("withdrawal"))
        #expect(en.contains("1837"))
        #expect(en.contains("1834"))
        #expect(!en.contains("49 Kč"))
    }
}

struct AppleProjectContractTests {
    private var appleRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test func projectRequestsSignInWithAppleAndEmbedsTheWatch() throws {
        let spec = try String(contentsOf: appleRoot.appending(path: "project.yml"), encoding: .utf8)
        #expect(spec.components(separatedBy: "com.apple.developer.applesignin").count - 1 >= 2)
        #expect(spec.contains("cz.martinpohl.tokeny.watchkitapp.widget"))
        #expect(!spec.contains("watchkitapp.widgets"))
        #expect(spec.contains("target: TokenyWatch"))
        #expect(spec.contains("embed: true"))
        #expect(spec.contains("storeKitConfiguration: Config/TokenyPro.storekit"))
    }

    @Test func storeKitFileMatchesTheProductsToCreate() throws {
        let file = try String(contentsOf: appleRoot.appending(path: "Config/TokenyPro.storekit"), encoding: .utf8)
        #expect(file.contains("\"productID\" : \"cz.martinpohl.tokeny.pro.monthly\""))
        #expect(file.contains("\"productID\" : \"cz.martinpohl.tokeny.pro.yearly\""))
        #expect(file.contains("\"displayPrice\" : \"49\""))
        #expect(file.contains("\"displayPrice\" : \"399\""))
        #expect(file.contains("\"recurringSubscriptionPeriod\" : \"P1M\""))
        #expect(file.contains("\"recurringSubscriptionPeriod\" : \"P1Y\""))
        #expect(file.contains("\"_storefront\" : \"CZE\""))
        #expect(file.contains("\"name\" : \"Tokeny Pro\""))
        #expect(file.contains("\"_applicationInternalID\" : \"6833010838\""))
    }
}
