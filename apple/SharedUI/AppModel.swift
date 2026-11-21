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
    /// Hourly points from the latest provider sync. Not part of the day totals.
    private(set) var intradayHours: [HourPoint] = []
    /// When the last refresh finished, including a provider sync that found no keys.
    private(set) var refreshedAt: Date?
    /// Debug screenshots. Release builds leave this false.
    var screenshotShell = false
    var screenshotTab: String?
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
        self.intradayHours = self.ledger.hours
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
        !store.onboardingComplete && !auth.isSignedIn && onDevice == nil && !store.deviceHome && !screenshotShell
    }

    /// Signed in, or the person is using the phone without a server account.
    var showsShell: Bool {
        if screenshotShell { return true }
        if auth.isSignedIn { return true }
        if onDevice != nil && !onDeviceSuspended { return true }
        if store.deviceHome { return true }
        return false
    }

    func finishOnboarding() {
        store.onboardingComplete = true
    }

    /// "Continue without an account" lands on the tab bar, not on a sign-in wall.
    func useDeviceHome() {
        finishOnboarding()
        store.deviceHome = true
    }

    /// From the device home back to the sign-in screen.
    func showSignIn() {
        store.deviceHome = false
        suspendOnDevice()
    }

    func applyLaunchArguments() {
        #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-tokeny-skip-onboarding") || args.contains("-tokeny-shell") || args.contains("-tokeny-login") {
                finishOnboarding()
            }
            if args.contains("-tokeny-shell") {
                screenshotShell = true
                useDeviceHome()
            }
            if args.contains("-tokeny-sample") { showSample() }
            if args.contains("-tokeny-demo-tips") { showDemoTips() }
            if let flag = args.firstIndex(of: "-tokeny-tab"), args.indices.contains(args.index(after: flag)) {
                screenshotTab = args[args.index(after: flag)]
            }
        #endif
    }

    #if DEBUG
        /// Enough repeated Opus calls for one deterministic tip. Screenshot launches only.
        func showDemoTips() {
            let today = MonthForecastMath.localDay(Date(), timeZone: .current)
            var lines = [
                "Start Time,Model,Service Tier,Input Tokens,Output Tokens,Cache Read Tokens,Cache Write 5m Tokens,Cache Write 1h Tokens"
            ]
            for index in 0..<24 {
                let day = MonthForecastMath.addDays(today, -min(index, 10))
                let hour = String(format: "%02d", index % 9)
                lines.append("\(day)T\(hour):15:00Z,claude-opus-4-6,standard,2000,40,0,0,0")
            }
            try? importUsageText(lines.joined(separator: "\n"), fileName: "demo.csv")
        }
    #endif

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
        intradayHours = []
    }

    func canSync(provider: String, now: Date = Date()) -> Bool {
        ProviderSyncPace.shouldFetch(provider: provider, lastSuccess: lastAPISuccess(provider), now: now)
    }

    /// One provider. Daily rows update the ledger. Hourly rows update the today chart only.
    func syncProvider(_ provider: String, apiKey: String, preview: String?) async throws {
        let batch = try await ProviderSync.fetch(provider: provider, apiKey: apiKey)
        importActivities(batch.rows, provider: provider, method: "api", keyPreview: preview)
        if let intraday = batch.intraday {
            recordIntraday(intraday, provider: provider)
        }
    }

    private func lastAPISuccess(_ provider: String) -> Date? {
        ProviderSyncPace.lastSuccess(imports: ledger.imports, provider: provider)
    }

    private func recordIntraday(_ rows: [ImportedActivity], provider: String) {
        let fresh = IntradaySeries.points(rows, timeZone: .current)
        let providers: Set<String> = provider == "cursor" ? ["cursor", "grok-bot"] : [provider]
        ledger.hours = IntradaySeries.replacing(ledger.hours, providers: providers, with: fresh)
        LedgerDisk.save(ledger)
        intradayHours = ledger.hours
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

    /// Server summary when there is one, then on-device provider keys, then account insights.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            refreshedAt = Date()
        }
        await refreshServerAccount()
        await syncConnectedProviders()
        reloadWidgets()
        onChange?()
    }

    /// Refreshes only when the last attempt is older than `maxAge` (launch and foreground).
    func refreshIfStale(maxAge: TimeInterval = 5 * 60) async {
        if let refreshedAt, Date().timeIntervalSince(refreshedAt) < maxAge { return }
        await refresh()
    }

    func didSignIn() async {
        store.deviceHome = false
        if !auth.isLocalIdentity, budgetAlertsEnabled { await notifier.requestAuthorization() }
        await refresh()
        if !auth.isLocalIdentity { await proStore.syncNow() }
    }

    func signOut() async {
        store.deviceHome = false
        await auth.signOut()
        clearLocalData()
    }

    private func refreshServerAccount() async {
        guard auth.isSignedIn, !auth.isLocalIdentity else {
            insights = nil
            return
        }
        do {
            let token = try await auth.accessToken()
            let summary = try await api.fetchSummary(accessToken: token)
            let fresh = CachedSummary(summary: summary, fetchedAt: Date())
            store.save(fresh.summary, fetchedAt: fresh.fetchedAt)
            cached = fresh
            await loadInsights(token: token)
            lastError = nil
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

    private func syncConnectedProviders() async {
        for provider in ["openai", "anthropic", "cursor"] {
            guard let key = providerKeys.load(provider: provider), !key.isEmpty else { continue }
            guard canSync(provider: provider) else { continue }
            do {
                try await syncProvider(provider, apiKey: key, preview: providerKeys.maskedPreview(provider: provider))
            } catch is CancellationError {
                return
            } catch let error as ProviderAPIError {
                noteImportFailure(
                    provider: provider, method: "api", outcome: Self.syncOutcome(error),
                    keyPreview: providerKeys.maskedPreview(provider: provider))
            } catch {
                noteImportFailure(
                    provider: provider, method: "api", outcome: "unreachable",
                    keyPreview: providerKeys.maskedPreview(provider: provider))
            }
        }
    }

    /// Signed-in tips. A failure keeps the previous payload and does not replace ``lastError``.
    private func loadInsights(token: String) async {
        let code = Locale.current.language.languageCode?.identifier ?? "cs"
        let lang = code.hasPrefix("cs") ? "cs" : "en"
        do {
            insights = try await api.fetchInsights(accessToken: token, timeZone: .current, languageCode: lang)
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private static func syncOutcome(_ error: ProviderAPIError) -> String {
        switch error {
        case .unauthorized: return "unauthorized"
        case .forbidden: return "forbidden"
        case .rateLimited: return "rate"
        case .badRequest: return "badRequest"
        case .unexpected, .unreachable: return "unreachable"
        }
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
