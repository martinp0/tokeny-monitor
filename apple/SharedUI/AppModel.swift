import Foundation
import Observation
import StoreKit
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

    /// True only on a storefront where linking to web purchase is allowed (US). Starts false.
    private(set) var allowsPurchaseLinks = false

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
        self.api = api
        self.store = store
        self.notifier = notifier
        self.cached = auth.isSignedIn ? store.load() : nil
        self.currency = store.currency
        self.budgetAlertsEnabled = store.budgetAlertsEnabled
        self.onDevice = store.loadOnDevice()
    }

    /// Signed out, with a file or sample still on screen.
    var showsOnDevice: Bool {
        if case .signedOut = auth.state, onDevice != nil, !onDeviceSuspended { return true }
        return false
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

    /// "Manage account on the web": settings (with checkout) in the US, profile elsewhere.
    var accountURL: URL { PurchaseLinkPolicy.accountURL(for: config, allowsPurchaseLinks: allowsPurchaseLinks) }

    /// Reads the App Store storefront and follows changes. Run once from the app's `.task`.
    func observeStorefront() async {
        allowsPurchaseLinks = PurchaseLinkPolicy.allowsPurchaseLinks(storefrontCountryCode: await Storefront.current?.countryCode)
        for await storefront in Storefront.updates {
            allowsPurchaseLinks = PurchaseLinkPolicy.allowsPurchaseLinks(storefrontCountryCode: storefront.countryCode)
        }
    }

    /// Fetches a fresh summary. Errors land in ``lastError``; the cached summary stays on screen.
    func refresh() async {
        guard auth.isSignedIn, !isRefreshing else { return }
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
        if budgetAlertsEnabled { await notifier.requestAuthorization() }
        await refresh()
    }

    func signOut() async {
        await auth.signOut()
        clearLocalData()
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        clearLocalData()
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
