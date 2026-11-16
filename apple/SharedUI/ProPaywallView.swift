import StoreKit
import SwiftUI
import TokenyCore

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// Monthly and yearly Tokeny Pro, with the auto-renew disclosure and the terms and privacy links
/// on the same screen as the purchase buttons.
struct ProPaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

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

            if !model.proStore.isEntitled {
                if model.proStore.isLoadingProducts && model.proStore.products.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if model.proStore.products.isEmpty {
                    Button("Try again") { Task { await model.proStore.loadProducts() } }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    offer(ProProduct.yearly, caption: String(localized: "Best value"))
                    offer(ProProduct.monthly, caption: nil)
                }
            }

            Text(disclosure)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Link("Privacy policy", destination: ProLegal.privacyURL(for: model.config))
                Link("Terms of service", destination: ProLegal.termsURL(for: model.config))
                Link("Apple standard EULA", destination: ProLegal.appleStandardEULA)
            }
            .font(.footnote)

            if model.proStore.isEntitled {
                Button("Manage subscription", action: manage)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }

            Button("Restore purchases", action: restore)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(model.proStore.isBusy)

            if let notice = noticeText {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(model.proStore.notice == .failed || model.proStore.notice == .productsUnavailable ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .buttonStyle(.borderedProminent)
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

    private var noticeText: String? {
        switch model.proStore.notice {
        case .pending: String(localized: "Purchase is pending approval.")
        case .restored: String(localized: "Purchases restored.")
        case .nothingToRestore: String(localized: "This Apple ID does not have an active Tokeny Pro subscription.")
        case .failed: String(localized: "Purchase failed. Try again.")
        case .productsUnavailable: String(localized: "Could not load subscriptions.")
        case .signInRequired: String(localized: "Sign in to your Tokeny account before subscribing.")
        case .syncFailed: ProAccess.storeSyncNote(syncFailed: true, languageCode: languageCode)
        case nil: nil
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
