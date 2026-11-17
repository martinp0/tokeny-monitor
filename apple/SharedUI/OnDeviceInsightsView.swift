import SwiftUI
import TokenyCore

/// Spend, forecast and a local budget from a CSV or from labeled sample rows.
/// Nothing here is the signed-in account, and nothing is uploaded.
struct OnDeviceInsightsView: View {
    @Environment(AppModel.self) private var model
    @State private var monthly = 0.0
    @State private var threshold = 80.0
    @State private var budgetReady = false
    @State private var showingPaywall = false

    var body: some View {
        screen
            .onAppear { loadBudget() }
            .sheet(isPresented: $showingPaywall) { proSheet }
    }

    @ViewBuilder
    private var screen: some View {
        if let snap = model.onDevice {
            if snap.lacksUsableRows {
                emptyScreen
            } else {
                loadedScreen(snap)
            }
        }
    }

    private var emptyScreen: some View {
        ScrollView {
            emptyImport()
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadedScreen(_ snap: OnDeviceSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                loadedTotals(snap)
                loadedDetail(snap)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func loadedTotals(_ snap: OnDeviceSnapshot) -> some View {
        banner(snap)
        figures(snap)
        tips(snap)
        forecast(snap)
    }

    @ViewBuilder
    private func loadedDetail(_ snap: OnDeviceSnapshot) -> some View {
        if let breakdown = snap.breakdown {
            planSplit(breakdown, currency: model.currency, rate: snap.summary.usdToCZK)
        }
        if !snap.summary.providers.isEmpty || !snap.summary.topModels.isEmpty {
            shares(snap)
        }
        budget(snap)
        rateFootnote(snap)
        monetization
        actions
    }

    private var proSheet: some View {
        NavigationStack {
            ScrollView {
                ProPaywallView()
                    .padding(20)
            }
            .navigationTitle("Tokeny Pro")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { proSheetDone }
        }
    }

    private var proSheetDone: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { showingPaywall = false }
        }
    }

    /// What happened, and one way back to a file Tokeny can read. No zero totals.
    private func emptyImport() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No usable rows in that file.")
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("Tokeny found no cost or token rows. Export the usage CSV again. Cursor: Usage, then Export CSV. OpenAI: Usage, then Export. Claude: Usage or Cost, then export CSV. Gemini: Cloud Billing Reports, group by Date and SKU, Subtotal in USD.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { model.showsImportHub = true }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rateFootnote(_ snap: OnDeviceSnapshot) -> some View {
        Text(rateFootnoteText(snap))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rateFootnoteText(_ snap: OnDeviceSnapshot) -> String {
        if !snap.usesFallbackExchangeRate, let date = snap.summary.usdCZK?.date, !date.isEmpty {
            let shown = korunaRate(snap.summary.usdToCZK)
            return String(localized: "Koruna amounts use \(shown) per dollar, the ČNB rate of \(date). Tips use this rate when amounts are in koruna.")
        }
        // 23.5 is UsageSummary.fallbackUSDCZK. The catalog spells the Czech decimal itself.
        return String(localized: "Koruna amounts use the app fallback of 23.5 Kč per dollar. The fallback has no ČNB date. Tips use this rate when amounts are in koruna.")
    }

    private func korunaRate(_ rate: Double) -> String {
        let text = rate.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "cs_CZ")))
        return text + "\u{00A0}Kč"
    }

    private func banner(_ snap: OnDeviceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if snap.source == .sample {
                    Text("Sample data")
                } else {
                    Text("Imported on this iPhone")
                }
            }
            .font(.headline)
            Text("Not your Tokeny account. Nothing was uploaded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let name = snap.fileName {
                LabeledContent("File", value: name)
                    .font(.footnote)
            }
            LabeledContent("Rows used", value: String(snap.stats.mapped))
                .font(.footnote)
            if snap.stats.skipped > 0 {
                LabeledContent("Rows skipped", value: String(snap.stats.skipped))
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func figures(_ snap: OnDeviceSnapshot) -> some View {
        let summary = snap.summary
        let rate = summary.usdToCZK
        let currency = model.currency
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    MoneyStack(usd: summary.today.costUSD, currency: currency, rate: rate)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tokens").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text(Fmt.tokens(summary.today.tokens)).font(.title2.weight(.semibold)).monospacedDigit()
                }
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This month").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    MoneyStack(usd: summary.month.costUSD, currency: currency, rate: rate, primaryFont: .title.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tokens").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text(Fmt.tokens(summary.month.tokens)).font(.title3.weight(.semibold)).monospacedDigit()
                }
            }
            if !summary.daily.isEmpty {
                DailyChart(days: summary.daily, currency: currency, rate: rate)
                    .frame(height: 120)
                    .accessibilityLabel(Text("Daily spend this month"))
            }
        }
    }

    private func forecast(_ snap: OnDeviceSnapshot) -> some View {
        let forecast = snap.forecast
        let rate = snap.summary.usdToCZK
        let currency = model.currency
        return VStack(alignment: .leading, spacing: 8) {
            Text("Forecast").font(.headline)
            if let point = forecast.forecastUSD {
                LabeledContent("Forecast") {
                    Text(Fmt.money(point, currency, rate: rate)).monospacedDigit()
                }
                if let low = forecast.lowUSD, let high = forecast.highUSD {
                    LabeledContent("Range") {
                        Text(Fmt.money(low, currency, rate: rate) + " – " + Fmt.money(high, currency, rate: rate))
                            .monospacedDigit()
                    }
                }
                confidence(forecast.confidence)
            } else {
                Text("No forecast yet")
                    .foregroundStyle(.secondary)
            }
            Text("Calculated on this iPhone. This is not the Pro forecast from your Tokeny account.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func confidence(_ value: MonthForecast.Confidence) -> some View {
        switch value {
        case .none:
            Text("No forecast yet")
        case .low:
            LabeledContent("Confidence") { Text("Low confidence") }
        case .medium:
            LabeledContent("Confidence") { Text("Medium confidence") }
        case .high:
            LabeledContent("Confidence") { Text("High confidence") }
        }
    }

    private func planSplit(_ breakdown: UsageBreakdown, currency: Currency, rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This month").font(.headline)
            LabeledContent("Included in plan") {
                Text(Fmt.money(breakdown.includedCost, currency, rate: rate)).monospacedDigit()
            }
            LabeledContent("On demand") {
                Text(Fmt.money(breakdown.onDemandCost, currency, rate: rate)).monospacedDigit()
            }
            LabeledContent("Credits") {
                Text(Fmt.money(breakdown.creditsCost, currency, rate: rate)).monospacedDigit()
            }
            LabeledContent("Fresh input", value: Fmt.tokens(breakdown.freshInput))
            LabeledContent("Cache reads", value: Fmt.tokens(breakdown.cachedRead))
            LabeledContent("Cache writes", value: Fmt.tokens(breakdown.cacheWrite))
            LabeledContent("Output tokens", value: Fmt.tokens(breakdown.output))
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    private func shares(_ snap: OnDeviceSnapshot) -> some View {
        let summary = snap.summary
        let rate = summary.usdToCZK
        let currency = model.currency
        return VStack(alignment: .leading, spacing: 10) {
            if !summary.providers.isEmpty {
                Text("Providers").font(.headline)
                ForEach(summary.providers) { provider in
                    ShareRow(title: provider.name, usd: provider.costUSD, totalUSD: summary.month.costUSD, currency: currency, rate: rate)
                }
            }
            if !summary.topModels.isEmpty {
                Text("Top models").font(.headline)
                ForEach(summary.topModels) { model in
                    ShareRow(title: Fmt.model(model.name), usd: model.costUSD, totalUSD: summary.month.costUSD, currency: currency, rate: rate)
                }
            }
        }
    }

    private func budget(_ snap: OnDeviceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budget on this iPhone").font(.headline)
            if snap.summary.budget != nil {
                BudgetBar(status: snap.summary.budgetStatus, currency: model.currency, rate: snap.summary.usdToCZK)
            }
            Stepper(value: $monthly, in: 0...100_000, step: 5) {
                LabeledContent("Monthly limit (USD)") {
                    Text(monthly > 0 ? Fmt.money(monthly, .usd, rate: 1) : String(localized: "Not set"))
                        .monospacedDigit()
                }
            }
            .onChange(of: monthly) { _, _ in saveBudget() }
            Stepper(value: $threshold, in: 50...100, step: 5) {
                LabeledContent("Alert threshold") {
                    Text(Fmt.percent(Int(threshold.rounded())))
                }
            }
            .onChange(of: threshold) { _, _ in saveBudget() }
            Text("The budget bar stays on this iPhone. The app does not send alerts for a file.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Saved only on this iPhone. It does not change your Tokeny account.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    private var monetization: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account Pro").font(.headline)
            Text("Tokeny Pro adds full history, the month-end forecast, budget alerts and unlimited providers. Subscribe with the App Store. A file on this iPhone is not that subscription.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("See Tokeny Pro") { showingPaywall = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Import usage") { model.showsImportHub = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
            if model.auth.isLocalIdentity {
                Button("Back") { model.suspendOnDevice() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Button("Back to sign-in") { model.suspendOnDevice() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            Button("Clear file") { model.clearOnDevice() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func loadBudget() {
        if let budget = model.onDevice?.summary.budget {
            monthly = budget.monthlyUSD
            threshold = budget.thresholdPercent
        }
        budgetReady = true
    }

    private func saveBudget() {
        guard budgetReady else { return }
        model.setOnDeviceBudget(monthlyUSD: monthly, thresholdPercent: threshold)
    }

    private func tips(_ snap: OnDeviceSnapshot) -> some View {
        let items = snap.tips ?? []
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ways to spend less")
                        .font(.headline)
                    ForEach(items) { tip in
                        tipRow(tip, currency: model.currency, rate: snap.summary.usdToCZK)
                    }
                    Text("This is an estimate, not a bill.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func tipRow(_ tip: OptimizationTip, currency: Currency, rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tipTitle(tip.kind))
                .font(.subheadline.weight(.semibold))
            Text(tipBody(tip, currency: currency, rate: rate))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let source = tipSource(tip, currency: currency) {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let saving = tip.savingUSD {
                LabeledContent("Estimate") {
                    Text(Fmt.money(saving, currency, rate: rate))
                        .monospacedDigit()
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func tipTitle(_ kind: String) -> String {
        switch kind {
        case "cheaperModel": String(localized: "A cheaper model for repeated work")
        case "promptCache": String(localized: "Prompt caching")
        case "batch": String(localized: "Batch API")
        case "spike": String(localized: "A day stands out")
        default: String(localized: "Set a monthly limit")
        }
    }

    private func tipBody(_ tip: OptimizationTip, currency: Currency, rate: Double) -> String {
        switch tip.kind {
        case "cheaperModel":
            let modelName = tip.model ?? ""
            let alternative = tip.alternative ?? ""
            let prices = String(localized: "\(moneyPerMillion(tip.inputPerMillion, currency, rate)) / \(moneyPerMillion(tip.outputPerMillion, currency, rate)) versus \(moneyPerMillion(tip.altInputPerMillion, currency, rate)) / \(moneyPerMillion(tip.altOutputPerMillion, currency, rate)) per million tokens.")
            let move = String(localized: "\(modelName) to \(alternative).")
            if tip.usesBilledCost {
                return "\(move) \(prices)"
            }
            return "\(move) \(prices) \(String(localized: "The file has no billed amount, so this compares list prices."))"
        case "promptCache":
            return String(localized: "Half of the uncached input, priced as a cache read. The first write is not subtracted.")
        case "batch":
            return String(localized: "The list price for batch is half. Rows already marked batch are left out.")
        case "spike":
            let day = tip.day ?? ""
            let cost = Fmt.money(tip.costUSD ?? 0, model.currency, rate: rate)
            let typical = Fmt.money(tip.medianUSD ?? 0, model.currency, rate: rate)
            return String(localized: "\(day) cost \(cost) against a typical day of \(typical).")
        default:
            return String(localized: "No monthly limit is set on this iPhone.")
        }
    }

    /// The provider's own USD list price, labelled, and only beside a koruna comparison.
    private func tipSource(_ tip: OptimizationTip, currency: Currency) -> String? {
        guard tip.kind == "cheaperModel", currency != .usd else { return nil }
        return String(localized: "Provider list price: \(usdPerMillion(tip.inputPerMillion)) / \(usdPerMillion(tip.outputPerMillion)) versus \(usdPerMillion(tip.altInputPerMillion)) / \(usdPerMillion(tip.altOutputPerMillion)) USD per million tokens.")
    }

    private func moneyPerMillion(_ usd: Double?, _ currency: Currency, _ rate: Double) -> String {
        Fmt.money(usd ?? 0, currency, rate: rate)
    }

    private func usdPerMillion(_ usd: Double?) -> String {
        Fmt.money(usd ?? 0, .usd, rate: 1)
    }
}
