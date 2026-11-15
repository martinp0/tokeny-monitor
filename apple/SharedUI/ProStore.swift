import Foundation
import Observation
import StoreKit
import TokenyCore

/// StoreKit 2 state for Tokeny Pro. Entitlements are the App Store subscription only;
/// the web plan is a separate flag on the usage summary.
@MainActor
@Observable
final class ProStore {
    enum Notice: Equatable {
        case pending
        case restored
        case nothingToRestore
        case failed
        case productsUnavailable
    }

    private(set) var products: [Product] = []
    private(set) var entitledProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var isBusy = false
    private(set) var notice: Notice?

    var isEntitled: Bool { !entitledProductIDs.isEmpty }

    func product(_ id: ProProduct) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// Loads products, reads current entitlements, then follows transaction updates.
    func observe() async {
        guard !observing else { return }
        observing = true
        await loadProducts()
        await refreshEntitlements()
        for await update in Transaction.updates {
            await handle(update)
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProProduct.allIDs)
            products = loaded.sorted { rank($0) < rank($1) }
            if products.isEmpty { notice = .productsUnavailable }
        } catch {
            products = []
            notice = .productsUnavailable
        }
    }

    func purchase(_ product: Product) async {
        notice = nil
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard let transaction = verified(verification) else {
                    notice = .failed
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
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
            await refreshEntitlements()
            notice = isEntitled ? .restored : .nothingToRestore
        } catch is CancellationError {
            return
        } catch {
            notice = .failed
        }
    }

    private var observing = false

    private func rank(_ product: Product) -> Int {
        product.id == ProProduct.yearly.rawValue ? 0 : 1
    }

    private func refreshEntitlements() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = verified(result) else { continue }
            guard ProProduct.allIDs.contains(transaction.productID), transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration <= Date() { continue }
            ids.insert(transaction.productID)
        }
        entitledProductIDs = ids
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = verified(result) else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func verified(_ result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }
}
