import SwiftUI
import TokenyCore
import UniformTypeIdentifiers

/// Spend, forecast and a local budget from a CSV or from labeled sample rows.
/// Nothing here is the signed-in account, and nothing is uploaded.
struct OnDeviceInsightsView: View {
    @Environment(AppModel.self) private var model
    @State private var monthly = 0.0
    @State private var threshold = 80.0
    @State private var budgetReady = false
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        let snap = model.onDevice
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let snap {
                    banner(snap)
                    figures(snap)
                    forecast(snap)
                    if let breakdown = snap.breakdown {
                        planSplit(breakdown, currency: model.currency, rate: snap.summary.usdToCZK)
                    }
                    if !snap.summary.providers.isEmpty || !snap.summary.topModels.isEmpty {
                        shares(snap)
                    }
                    budget(snap)
                    if snap.usesFallbackExchangeRate {
                        Text("Koruna amounts use the app fallback rate of 23.5 Kč per dollar, not today's ČNB rate.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    monetization
                    actions
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { loadBudget() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text], allowsMultipleSelection: false) { result in
            importFile(result)
        }
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
            Text("Tokeny Pro on your account adds the server month-end forecast, budget alerts, exports and shared dashboards. This app does not sell Pro. No App Store product is set up.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let importError {
                Text(importError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Open a usage CSV") { importing = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
            Button("Back to sign-in") { model.suspendOnDevice() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
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

    private func importFile(_ result: Result<[URL], any Error>) {
        switch result {
        case .failure:
            importError = String(localized: "Could not read that file.")
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                if let size, size > UsageImport.maxBytes {
                    importError = String(localized: "That file is too large to open in the app.")
                    return
                }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    importError = String(localized: "Could not read that file.")
                    return
                }
                try model.importUsageText(text, fileName: url.lastPathComponent)
                importError = nil
                loadBudget()
            } catch let error as UsageImportError {
                importError = message(for: error)
            } catch {
                importError = String(localized: "Could not read that file.")
            }
        }
    }

    private func message(for error: UsageImportError) -> String {
        switch error {
        case .empty, .unrecognized:
            String(localized: "This file is not an OpenRouter activity export or a Cursor or Grok Bot usage export.")
        case .tooLarge:
            String(localized: "That file is too large to open in the app.")
        }
    }
}
