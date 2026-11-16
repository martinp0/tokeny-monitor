import Foundation
import Observation
import TokenyAuth
import TokenyCore

#if canImport(WidgetKit)
    import WidgetKit
#endif

/// App state shared by the iPhone and Mac apps: sign-in, the latest summary and preferences.
/// One instance per process (``shared``) so App Intents running in the app see the same session.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let auth: AuthService
    let proStore: ProStore
    private let api: UsageAPI
    private let store: SummaryStore
    private let notifier: BudgetNotifier

    private(set) var cached: CachedSummary?
    private(set) var isRefreshing = false
    private(set) var lastError: UsageAPIError?
    /// File or sample calculated on this device. Not the signed-in account cache widgets read.
    private(set) var onDevice: OnDeviceSnapshot?
    /// Hides the on-device screen without deleting the file, so sign-in stays reachable.
    private(set) var onDeviceSuspended = false

    /// Called after every successful refresh or sign-out (the iPhone forwards it to the Watch).
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    var currency: Currency {
        didSet {
            store.currency = currency
            reloadWidgets()
            onChange?()
        }
    }

    var budgetAlertsEnabled: Bool {
        didSet {
            store.budgetAlertsEnabled = budgetAlertsEnabled
            if budgetAlertsEnabled { Task { await notifier.requestAuthorization() } }
        }
    }

    init(
        auth: AuthService = AuthService(),
        api: UsageAPI = UsageAPI(),
        store: SummaryStore = .shared,
        notifier: BudgetNotifier = BudgetNotifier()
    ) {
        self.auth = auth
        self.proStore = ProStore()
        self.api = api
        self.store = store
        self.notifier = notifier
        self.cached = auth.isSignedIn ? store.load() : nil
        self.currency = store.currency
        self.budgetAlertsEnabled = store.budgetAlertsEnabled
        self.onDevice = store.loadOnDevice()
        proStore.serverUserID = { [weak self] in self?.auth.serverUserID }
        proStore.onSignedTransactions = { [weak self] signed in
            await self?.syncStoreKit(signed)
        }
    }

    /// A file or sample is on screen: signed out, or signed in only with the on-device Apple ID.
    var showsOnDevice: Bool {
        guard onDevice != nil, !onDeviceSuspended else { return false }
        switch auth.state {
        case .signedOut:
            return true
        case .signedIn where auth.isLocalIdentity:
            return true
        default:
            return false
        }
    }

    /// The server plan. An App Store purchase counts only after the server has stored it.
    var hasPro: Bool {
        summary?.isPro == true
    }

    func importUsageText(_ text: String, fileName: String) throws {
        let snap = try OnDeviceInsight.make(
            text: text, fileName: fileName, source: .file, now: Date(), timeZone: .current,
            budget: onDevice?.summary.budget)
        store.saveOnDevice(snap)
        onDevice = snap
        onDeviceSuspended = false
    }

    func showSample() {
        let snap = OnDeviceInsight.sample(now: Date(), timeZone: .current, budget: onDevice?.summary.budget)
        store.saveOnDevice(snap)
        onDevice = snap
        onDeviceSuspended = false
    }

    func showSavedOnDevice() {
        onDeviceSuspended = false
    }

    func suspendOnDevice() {
        onDeviceSuspended = true
    }

    func clearOnDevice() {
        store.clearOnDevice()
        onDevice = nil
        onDeviceSuspended = false
    }

    /// Budget for the on-device file only. Zero clears it. Does not call the account API or notify.
    func setOnDeviceBudget(monthlyUSD: Double, thresholdPercent: Double) {
        guard var snap = onDevice else { return }
        if monthlyUSD > 0 {
            snap.summary.budget = UsageSummary.Budget(
                monthlyUSD: monthlyUSD, thresholdPercent: thresholdPercent, enabled: true)
        } else {
            snap.summary.budget = nil
        }
        store.saveOnDevice(snap)
        onDevice = snap
    }

    var summary: UsageSummary? { cached?.summary }
    var config: AppConfig { api.config }

    /// Profile on the web. The apps sell Pro with StoreKit and do not link to the Stripe checkout.
    var accountURL: URL { PurchaseLinkPolicy.accountURL(for: config) }

    /// Fetches a fresh summary. Errors land in ``lastError``; the cached summary stays on screen.
    func refresh() async {
        guard auth.isSignedIn, !auth.isLocalIdentity, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let token = try await auth.accessToken()
            let summary = try await api.fetchSummary(accessToken: token)
            let fresh = CachedSummary(summary: summary, fetchedAt: Date())
            store.save(fresh.summary, fetchedAt: fresh.fetchedAt)
            cached = fresh
            lastError = nil
            reloadWidgets()
            onChange?()
            if budgetAlertsEnabled { await notifier.evaluate(summary, store: store) }
        } catch is CancellationError {
            return
        } catch let error as UsageAPIError {
            lastError = error
            if error == .unauthorized { await signOut() }
        } catch {
            lastError = .offline
        }
    }

    /// Refreshes only when the cache is older than `maxAge` (app launch, returning to foreground).
    func refreshIfStale(maxAge: TimeInterval = 5 * 60) async {
        if let cached, !cached.isStale(maxAge: maxAge) { return }
        await refresh()
    }

    func didSignIn() async {
        guard !auth.isLocalIdentity else { return }
        if budgetAlertsEnabled { await notifier.requestAuthorization() }
        await refresh()
        await proStore.syncNow()
    }

    func signOut() async {
        await auth.signOut()
        clearLocalData()
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        clearLocalData()
    }

    /// Posts StoreKit signed transactions, then loads the summary again so the plan matches the server.
    private func syncStoreKit(_ signedTransactions: [String]) async {
        guard auth.serverUserID != nil, !signedTransactions.isEmpty else { return }
        do {
            let token = try await auth.accessToken()
            _ = try await api.syncAppleTransactions(accessToken: token, signedTransactions: signedTransactions)
            while isRefreshing {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
            }
            await refresh()
        } catch is CancellationError {
            return
        } catch {
            proStore.notice = .syncFailed
        }
    }

    private func clearLocalData() {
        store.clear()
        cached = nil
        reloadWidgets()
        onChange?()
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit) && os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
