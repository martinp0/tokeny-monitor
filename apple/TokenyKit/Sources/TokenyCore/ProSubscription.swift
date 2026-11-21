import Foundation

/// App Store Connect subscription for Tokeny Pro. The group id Apple assigns is not known
/// until the group is created; ``ProProduct/groupReferenceName`` is the name to use there.
/// Local StoreKit testing uses the same product ids (`Config/TokenyPro.storekit`).
public enum ProProduct: String, CaseIterable, Sendable, Equatable {
    public static let groupReferenceName = "Tokeny Pro"
    /// Reference name of the subscription group in App Store Connect and in the local StoreKit file.
    public static let groupLocalTestingID = "TOKENY_PRO"

    case monthly = "cz.martinpohl.tokeny.pro.monthly"
    case yearly = "cz.martinpohl.tokeny.pro.yearly"

    public static var allIDs: Set<String> { Set(allCases.map(\.rawValue)) }

    /// Tax-inclusive Czech reference price, the same as the web control: 99 Kč a month, 990 Kč a year.
    /// App Store Connect may not offer that exact amount. The owner sets the nearest CZK price point there.
    public var referencePriceCZK: Int {
        switch self {
        case .monthly: 99
        case .yearly: 990
        }
    }

    public var referencePriceLabel: String { "\(referencePriceCZK) Kč" }
}

/// One current StoreKit entitlement, without StoreKit types so tests can run on Linux.
public struct ProEntitlement: Equatable, Sendable {
    public var productID: String
    public var expiresAt: Date?
    public var revoked: Bool

    public init(productID: String, expiresAt: Date?, revoked: Bool) {
        self.productID = productID
        self.expiresAt = expiresAt
        self.revoked = revoked
    }

    public func isActive(at now: Date) -> Bool {
        guard ProProduct.allIDs.contains(productID), !revoked else { return false }
        if let expiresAt, expiresAt <= now { return false }
        return true
    }
}

/// The plan label follows the server. StoreKit entitlement only decides whether to offer another purchase.
public enum ProAccess {
    public static func isStoreEntitled(_ entitlements: [ProEntitlement], now: Date = Date()) -> Bool {
        entitlements.contains { $0.isActive(at: now) }
    }

    /// Pro for features and the plan label. A local StoreKit entitlement does not grant it;
    /// the server does, after it accepts the signed transaction.
    public static func hasPro(serverPlanIsPro: Bool, storeEntitled: Bool) -> Bool {
        _ = storeEntitled
        return serverPlanIsPro
    }

    /// Hide the buy button when the server already says Pro, or when this Apple ID already
    /// has the subscription and the app is still confirming it with the account.
    public static func showsPaywall(serverPlanIsPro: Bool, storeEntitled: Bool) -> Bool {
        !serverPlanIsPro && !storeEntitled
    }

    /// Shown while an App Store subscription is on this device and the server plan is still Free.
    /// Plain strings (like ``ProLegal``) so the note is Czech or English without a catalog in TokenyKit.
    public static func storeSyncNote(syncFailed: Bool, languageCode: String?) -> String {
        let czech = AppConfig.usesCzechBlog(languageCode)
        if syncFailed {
            return czech
                ? "Předplatné z App Storu se nepodařilo potvrdit u účtu v Tokenech. Použij Obnovit nákupy."
                : "Couldn't confirm the App Store subscription with your Tokeny account. Use Restore purchases."
        }
        return czech
            ? "Potvrzuju Pro z App Storu u účtu v Tokenech."
            : "Confirming App Store Pro with your Tokeny account."
    }
}

/// Auto-renew disclosure and the links Apple and Czech/EU consumer law expect on the paywall.
/// Apple sells the subscription; these sentences describe that purchase, not the Stripe price on the web.
public enum ProLegal {
    public static let appleStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    public static func privacyURL(for config: AppConfig) -> URL {
        config.webURL.appending(path: "privacy")
    }

    public static func termsURL(for config: AppConfig) -> URL {
        config.webURL.appending(path: "terms")
    }

    /// `monthlyPrice` and `yearlyPrice` are the strings the purchase buttons show (StoreKit `displayPrice`,
    /// or the Czech reference labels when products have not loaded and no button is enabled).
    public static func disclosure(languageCode: String?, monthlyPrice: String, yearlyPrice: String) -> String {
        if AppConfig.usesCzechBlog(languageCode) {
            return czech(monthly: monthlyPrice, yearly: yearlyPrice)
        }
        return english(monthly: monthlyPrice, yearly: yearlyPrice)
    }

    private static func czech(monthly: String, yearly: String) -> String {
        """
        Předplatné Tokeny Pro se obnovuje automaticky, dokud ho nezrušíš. Měsíční předplatné stojí \(monthly) a obnovuje se každý měsíc. Roční předplatné stojí \(yearly) a obnovuje se každý rok. Platba se strhne z tvého Apple ID při potvrzení. Obnoví se, pokud ho nezrušíš aspoň 24 hodin před koncem období. Správa: Nastavení → Apple ID → Předplatné. Zakoupením žádáš o okamžité zpřístupnění a bereš na vědomí, že právo na odstoupení zaniká po úplném poskytnutí digitální služby (§ 1837 písm. a)) a že při dřívějším odstoupení můžeš zaplatit poměrnou část (§ 1834). Prodejcem je Apple.
        """
    }

    private static func english(monthly: String, yearly: String) -> String {
        """
        Tokeny Pro renews automatically until you cancel. Monthly costs \(monthly) and renews every month. Yearly costs \(yearly) and renews every year. Payment is charged to your Apple ID when you confirm. It renews unless you cancel at least 24 hours before the period ends. Manage it in Settings → Apple ID → Subscriptions. By subscribing you ask for immediate access and acknowledge that the right of withdrawal ends once the digital service has been fully provided (§ 1837(a)) and that an earlier withdrawal may be charged proportionally (§ 1834). Apple is the seller.
        """
    }
}
