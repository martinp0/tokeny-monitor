import StoreKit
import SwiftUI
import TokenyCore

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// Monthly and yearly Tokeny Pro. Prices, restore, and the legal links stay on this screen.
/// A device-only Apple identity has no server user id, so it cannot start a purchase
/// (`appAccountToken` is a UUIDv5 of the Neon Auth user). The sign-in sheet still offers
/// Sign in with Apple; once the server accepts it (`docs/apple-signin.md`), that session can buy.
struct ProPaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var scheme
    @State private var showingAccountSignIn = false

    private var languageCode: String? { Bundle.main.preferredLocalizations.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Tokeny Pro", systemImage: "sparkles")
                .font(.headline)
            Text("Full history, month-end forecast, budget alerts and unlimited providers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.proStore.isEntitled {
                Label("Subscribed through the App Store", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
            }

            if model.proStore.canStartPurchase {
                if !model.proStore.isEntitled {
                    productArea
                }
            } else {
                accountGate
            }

            if model.proStore.isEntitled {
                Button("Manage subscription", action: manage)
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }

            Button("Restore purchases", action: restore)
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(model.proStore.isBusy)

            VStack(alignment: .leading, spacing: 6) {
                Link("Privacy policy", destination: ProLegal.privacyURL(for: model.config))
                Link("Terms of service", destination: ProLegal.termsURL(for: model.config))
                Link("Apple standard EULA", destination: ProLegal.appleStandardEULA)
            }
            .font(.footnote)

            Text(disclosure)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let notice = noticeText {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(noticeIsFailure ? TokenyColor.danger(scheme) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingAccountSignIn) {
            TokenyAccountSignInSheet()
        }
    }

    @ViewBuilder
    private var productArea: some View {
        if model.proStore.products.isEmpty {
            if model.proStore.isLoadingProducts || model.proStore.notice != .productsUnavailable {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading subscriptions…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                productError
            }
        } else {
            offer(ProProduct.yearly, caption: String(localized: "Best value"))
            offer(ProProduct.monthly, caption: nil)
        }
    }

    private var productError: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Could not load subscriptions.", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TokenyColor.danger(scheme))
            Text("Check the connection and try again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { Task { await model.proStore.loadProducts() } }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    /// Email and password reach a Neon Auth user id. Sign in with Apple stays on that sheet.
    private var accountGate: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.proStore.isEntitled ? "Sign in to confirm Pro" : "Sign in to subscribe")
                .font(.headline)
            Text(accountGateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Sign in to a Tokeny account") { showingAccountSignIn = true }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .padding(16)
        .tokenyGlass()
    }

    private var accountGateMessage: String {
        if model.proStore.isEntitled {
            return String(localized: "Sign in with the email and password of your Tokeny account so Tokeny can confirm this subscription.")
        }
        if model.auth.isLocalIdentity {
            return String(localized: "This Apple ID is saved on this device. To subscribe, sign in with the email and password of your Tokeny account. Sign in with Apple stays available, and connects the purchase once Tokeny accepts that Apple ID.")
        }
        return String(localized: "Sign in with the email and password of your Tokeny account. You can subscribe on this screen after that.")
    }

    @ViewBuilder
    private func offer(_ id: ProProduct, caption: String?) -> some View {
        if let product = model.proStore.product(id) {
            Button {
                Task { await model.proStore.purchase(product) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if id == .yearly {
                            Text("Yearly")
                        } else {
                            Text("Monthly")
                        }
                        if let caption {
                            Text(caption)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                        Text(product.displayPrice)
                            .monospacedDigit()
                    }
                    if id == .yearly {
                        Text("per year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("per month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.proStore.isBusy)
        }
    }

    private var disclosure: String {
        ProLegal.disclosure(
            languageCode: languageCode,
            monthlyPrice: model.proStore.product(.monthly)?.displayPrice ?? ProProduct.monthly.referencePriceLabel,
            yearlyPrice: model.proStore.product(.yearly)?.displayPrice ?? ProProduct.yearly.referencePriceLabel
        )
    }

    private var noticeIsFailure: Bool {
        model.proStore.notice == .failed || model.proStore.notice == .productsUnavailable
    }

    private var noticeText: String? {
        if model.proStore.notice == .productsUnavailable {
            let productErrorVisible = model.proStore.canStartPurchase && !model.proStore.isEntitled
                && model.proStore.products.isEmpty && !model.proStore.isLoadingProducts
            if productErrorVisible || !model.proStore.canStartPurchase { return nil }
        }
        switch model.proStore.notice {
        case .pending: return String(localized: "Purchase is pending approval.")
        case .restored: return String(localized: "Purchases restored.")
        case .nothingToRestore: return String(localized: "This Apple ID does not have an active Tokeny Pro subscription.")
        case .failed: return String(localized: "Purchase failed. Try again.")
        case .productsUnavailable: return String(localized: "Could not load subscriptions.")
        case .signInRequired: return String(localized: "Sign in to your Tokeny account before subscribing.")
        case .syncFailed: return ProAccess.storeSyncNote(syncFailed: true, languageCode: languageCode)
        case nil: return nil
        }
    }

    private func restore() {
        Task { await model.proStore.restore() }
    }

    private func manage() {
        Task {
            if await SubscriptionManagement.present() { return }
            openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
        }
    }
}

enum SubscriptionManagement {
    /// Shows Apple's subscription management sheet. Returns false when no window is available.
    @MainActor
    static func present() async -> Bool {
        #if os(iOS)
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            guard let scene else { return false }
            do {
                try await AppStore.showManageSubscriptions(in: scene)
                return true
            } catch {
                return false
            }
        #elseif os(macOS)
            guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else { return false }
            do {
                try await AppStore.showManageSubscriptions(in: window)
                return true
            } catch {
                return false
            }
        #else
            return false
        #endif
    }
}
