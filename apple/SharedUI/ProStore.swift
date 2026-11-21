import Foundation
import Observation
import StoreKit
import TokenyCore

/// StoreKit 2 state for Tokeny Pro. A purchase is bound to the signed-in Tokeny account
/// (`appAccountToken`) and each current entitlement's JWS is posted to the server, which
/// is what actually grants Pro.
@MainActor
@Observable
final class ProStore {
    enum Notice: Equatable {
        case pending
        case restored
        case nothingToRestore
        case failed
        case productsUnavailable
        case signInRequired
        case syncFailed
    }

    private(set) var products: [Product] = []
    private(set) var entitledProductIDs: Set<String> = []
    /// `VerificationResult.jwsRepresentation` of the current entitlements, in StoreKit's order.
    private(set) var entitlementJWS: [String] = []
    private(set) var isLoadingProducts = false
    private(set) var isBusy = false
    private(set) var notice: Notice?

    /// Tokeny user id of a server session. Nil when signed out or only locally signed in with Apple.
    var serverUserID: @MainActor () -> String? = { nil }
    /// Posts the given signed transactions, then refreshes the usage summary.
    var onSignedTransactions: @MainActor ([String]) async -> Void = { _ in }

    var isEntitled: Bool { !entitledProductIDs.isEmpty }

    /// A purchase needs the server user id. Nil while signed out or signed in only on this device.
    /// When Neon Auth accepts Sign in with Apple (`docs/apple-signin.md`), that session passes this gate.
    var canStartPurchase: Bool {
        ProPurchaseGate.token(serverUserID: serverUserID()) != nil
    }

    func product(_ id: ProProduct) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// Loads products, posts current entitlements, then follows transaction updates.
    func observe() async {
        guard !observing else { return }
        observing = true
        await loadProducts()
        await syncNow()
        for await update in Transaction.updates {
            await handle(update)
        }
    }

    /// Reads current entitlements and posts their JWS. Also called on launch, restore and foreground.
    func syncNow() async {
        if syncing { return }
        syncing = true
        defer { syncing = false }
        await refreshEntitlements()
        await onSignedTransactions(entitlementJWS)
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        if notice == .productsUnavailable { notice = nil }
        defer { isLoadingProducts = false }
        do {
            let loaded = try await TimedWait.run(timeout: ProductLoadPolicy.timeout) {
                try await Product.products(for: ProProduct.allIDs)
            }
            products = loaded.sorted { rank($0) < rank($1) }
            if products.isEmpty {
                notice = .productsUnavailable
            } else if notice == .productsUnavailable {
                notice = nil
            }
        } catch is CancellationError {
            return
        } catch {
            notice = .productsUnavailable
        }
    }

    func purchase(_ product: Product) async {
        notice = nil
        guard let token = ProPurchaseGate.token(serverUserID: serverUserID()) else {
            notice = .signInRequired
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase(options: [.appAccountToken(token)]) {
            case .success(let verification):
                guard let (transaction, jws) = verified(verification) else {
                    notice = .failed
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
                await syncIncluding(jws)
            case .userCancelled:
                break
            case .pending:
                notice = .pending
            @unknown default:
                notice = .failed
            }
        } catch {
            notice = .failed
        }
    }

    func restore() async {
        notice = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await syncNow()
            if notice == .syncFailed { return }
            notice = isEntitled ? .restored : .nothingToRestore
        } catch is CancellationError {
            return
        } catch {
            notice = .failed
        }
    }

    private var observing = false
    private var syncing = false

    private func rank(_ product: Product) -> Int {
        product.id == ProProduct.yearly.rawValue ? 0 : 1
    }

    private func refreshEntitlements() async {
        var ids: Set<String> = []
        var signed: [String] = []
        for await result in Transaction.currentEntitlements {
            guard let (transaction, jws) = verified(result) else { continue }
            guard ProProduct.allIDs.contains(transaction.productID), transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration <= Date() { continue }
            ids.insert(transaction.productID)
            signed.append(jws)
        }
        entitledProductIDs = ids
        entitlementJWS = signed
    }

    /// Current entitlements, plus a transaction that just updated and may already be revoked
    /// (revoked transactions leave `currentEntitlements`, and the server still needs the JWS).
    private func syncIncluding(_ extra: String) async {
        var signed = entitlementJWS
        if !signed.contains(extra) { signed.append(extra) }
        await onSignedTransactions(signed)
    }

    /// The account rejected or could not store the signed transactions.
    /// Restore reads ``notice`` afterwards and must not replace this with a success.
    func recordSyncFailed() {
        notice = .syncFailed
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let (transaction, jws) = verified(result) else { return }
        await transaction.finish()
        await refreshEntitlements()
        await syncIncluding(jws)
    }

    /// StoreKit 2 signs the JWS on `VerificationResult`, not on the unwrapped `Transaction`.
    private func verified(_ result: VerificationResult<Transaction>) -> (transaction: Transaction, jws: String)? {
        switch result {
        case .verified(let transaction):
            return (transaction, result.jwsRepresentation)
        case .unverified:
            return nil
        }
    }
}
