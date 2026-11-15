import Foundation

/// Whether the app may show anything that leads to buying Pro on the web.
///
/// Pro in the apps is a StoreKit subscription (``ProProduct``). A link to the Stripe checkout
/// would be a second way to pay, including on the US storefront, so every storefront gets no
/// purchase link. "Manage account on the web" opens the profile page, which has no checkout.
public enum PurchaseLinkPolicy {
    public static func allowsPurchaseLinks(storefrontCountryCode code: String?) -> Bool {
        _ = code
        return false
    }

    /// Profile page: e-mail, password, export, delete. The Stripe checkout stays on the web
    /// settings page and is not linked from the apps.
    public static func accountURL(for config: AppConfig) -> URL {
        config.profileURL
    }
}
