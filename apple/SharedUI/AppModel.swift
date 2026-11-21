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
    /// Server tips for the signed-in account (`GET /api/insights`). Nil until a refresh succeeds.
    private(set) var insights: AccountInsights?
    /// File or sample calculated on this device. Not the signed-in account cache widgets read.
    private(set) var onDevice: OnDeviceSnapshot?
    /// Hides the on-device screen without deleting the file, so sign-in stays reachable.
    private(set) var onDeviceSuspended = false
    /// The import screens. Not persisted; the welcome flag is.
    var showsImportHub = false
    private var ledger = OnDeviceLedger.empty

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
        self.ledger = LedgerDisk.load()
        if !ledger.buckets.isEmpty || ledger.isSample {
            self.onDevice = ledger.snapshot(
                fileName: onDevice?.fileName, now: Date(), timeZone: .current,
                budget: onDevice?.summary.budget, stats: onDevice?.stats ?? UsageImportStats())
        }
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

    /// Welcome, once, until there is a session or a file from an earlier version.
    var shouldShowOnboarding: Bool {
        !store.onboardingComplete && !auth.isSignedIn && onDevice == nil
    }

    func finishOnboarding() {
        store.onboardingComplete = true
    }

    var providerKeys: ProviderKeyStore { .live() }

    func importUsageText(_ text: String, fileName: String) throws {
        let parsed = try UsageImport.parse(text)
        let provider = Self.providerID(parsed)
        let outcome = parsed.stats.mapped == 0 ? "empty" : "ok"
        let record = ProviderImportRecord(
            id: "\(provider)-\(UsageImport.isoUTC(Date()))", provider: provider, method: "csv",
            at: UsageImport.isoUTC(Date()), added: 0, skipped: parsed.stats.skipped, alreadyStored: 0,
            outcome: outcome, keyPreview: nil)
        apply(parsed.rows, record: record, fileName: fileName, stats: parsed.stats, asSample: false)
    }

    func importActivities(_ rows: [ImportedActivity], provider: String, method: String, keyPreview: String?) {
        let record = ProviderImportRecord(
            id: "\(provider)-\(UsageImport.isoUTC(Date()))", provider: provider, method: method,
            at: UsageImport.isoUTC(Date()), added: 0, skipped: 0, alreadyStored: 0,
            outcome: rows.isEmpty ? "empty" : "ok", keyPreview: keyPreview)
        apply(rows, record: record, fileName: nil, stats: UsageImportStats(rows: rows.count, mapped: rows.count), asSample: false)
    }

    func noteImportFailure(provider: String, method: String, outcome: String, keyPreview: String?) {
        var next = ledger
        next.imports.append(ProviderImportRecord(
            id: "\(provider)-fail-\(UsageImport.isoUTC(Date()))", provider: provider, method: method,
            at: UsageImport.isoUTC(Date()), added: 0, skipped: 0, alreadyStored: 0, outcome: outcome,
            keyPreview: keyPreview))
        if next.imports.count > 12 { next.imports.removeFirst(next.imports.count - 12) }
        ledger = next
        LedgerDisk.save(next)
        if var snap = onDevice {
            snap.imports = next.imports
            onDevice = snap
            store.saveOnDevice(snap)
        }
    }

    func showSample() {
        let text = OnDeviceInsight.sampleText(now: Date(), timeZone: .current)
        guard let parsed = try? UsageImport.parse(text) else { return }
        let record = ProviderImportRecord(
            id: "sample-\(UsageImport.isoUTC(Date()))", provider: "sample", method: "sample",
            at: UsageImport.isoUTC(Date()), added: 0, skipped: 0, alreadyStored: 0, outcome: "ok", keyPreview: nil)
        apply(parsed.rows, record: record, fileName: nil, stats: parsed.stats, asSample: true)
    }

    func showSavedOnDevice() {
        onDeviceSuspended = false
    }

    func suspendOnDevice() {
        onDeviceSuspended = true
    }

    func clearOnDevice() {
        ledger = .empty
        LedgerDisk.remove()
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
        if let rollup = snap.rollup {
            snap.tips = OptimizationTips.make(
                rollup: rollup, budget: snap.summary.budget, monthCostUSD: snap.summary.month.costUSD,
                catalog: ModelPrices.bundled(), on: MonthForecastMath.localDay(Date(), timeZone: .current))
        }
        store.saveOnDevice(snap)
        onDevice = snap
    }

    private func apply(
        _ rows: [ImportedActivity], record: ProviderImportRecord, fileName: String?, stats: UsageImportStats, asSample: Bool
    ) {
        let merged = ledger.merging(rows, record: record, timeZone: .current, asSample: asSample)
        ledger = merged.ledger
        LedgerDisk.save(ledger)
        let snap = ledger.snapshot(
            fileName: fileName ?? onDevice?.fileName, now: Date(), timeZone: .current,
            budget: asSample ? nil : onDevice?.summary.budget, stats: stats)
        store.saveOnDevice(snap)
        onDevice = snap
        onDeviceSuspended = false
        showsImportHub = false
    }

    private static func providerID(_ parsed: UsageImport.Result) -> String {
        switch parsed.kind {
        case .openAIUsage, .openAICost: return "openai"
        case .anthropicUsage, .anthropicCost: return "anthropic"
        case .geminiBilling: return "gemini"
        case .openRouter: return "openrouter"
        case .usageExport:
            let sources = Set(parsed.rows.map(\.providerSource))
            if sources == ["grok-bot"] { return "grok-bot" }
            if sources == ["cursor"] { return "cursor" }
            return "cursor"
        }
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
            await loadInsights(token: token)
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

    /// Signed-in tips. A failure keeps the previous payload and does not replace ``lastError``.
    private func loadInsights(token: String) async {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        let lang = code.hasPrefix("cs") ? "cs" : "en"
        do {
            insights = try await api.fetchInsights(accessToken: token, languageCode: lang)
        } catch is CancellationError {
            return
        } catch {
            return
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
            proStore.recordSyncFailed()
        }
    }

    private func clearLocalData() {
        store.clear()
        cached = nil
        insights = nil
        reloadWidgets()
        onChange?()
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit) && os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
