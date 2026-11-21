import Charts
import SwiftUI
import TokenyCore

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Binding var tab: PhoneTab
    @State private var range = SpendRange.month
    @State private var showAllModels = false

    var body: some View {
        NavigationStack {
            Group {
                if let feed = feed {
                    loaded(feed)
                } else if model.isRefreshing {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    empty
                }
            }
            .tokenyScreen()
            .navigationTitle("Přehled")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAllModels) {
            modelsSheet
        }
    }

    private var feed: OverviewFeed? {
        if model.auth.isSignedIn, !model.auth.isLocalIdentity, let summary = model.summary {
            return OverviewFeed(
                summary: summary, forecastUSD: summary.forecastMonthUSD, tips: model.onDevice?.tips ?? [],
                sample: false)
        }
        if let snap = model.onDevice, !snap.lacksUsableRows {
            return OverviewFeed(
                summary: snap.summary, forecastUSD: snap.forecast.forecastUSD, tips: snap.tips ?? [],
                sample: snap.source == .sample)
        }
        return nil
    }

    private func loaded(_ feed: OverviewFeed) -> some View {
        let summary = feed.summary
        let today = MonthForecastMath.localDay(Date(), timeZone: .current)
        let slice = SpendWindows.slice(
            daily: summary.daily, monthCostUSD: summary.month.costUSD,
            previousMonthUSD: summary.previousMonth?.costUSD, range: range, today: today)
        let hours = IntradaySeries.totals(model.intradayHours, day: today)
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Picker("Období", selection: $range) {
                    Text("Tento měsíc").tag(SpendRange.month)
                    Text("7 dní").tag(SpendRange.sevenDays)
                    Text("30 dní").tag(SpendRange.thirtyDays)
                }
                .pickerStyle(.segmented)
                SpendHero(
                    range: range, slice: slice, forecastUSD: range == .month ? feed.forecastUSD : nil,
                    budget: range == .month ? summary.budget : nil, monthCostUSD: summary.month.costUSD,
                    currency: model.currency, rate: summary.usdToCZK)
                if !hours.isEmpty {
                    TodayHours(hours: hours, currency: model.currency, rate: summary.usdToCZK)
                }
                if !summary.providers.isEmpty, range == .month {
                    ProviderCard(providers: summary.providers, total: summary.month.costUSD, currency: model.currency, rate: summary.usdToCZK)
                }
                if !summary.topModels.isEmpty, range == .month {
                    ModelCard(models: summary.topModels, total: summary.month.costUSD, currency: model.currency, rate: summary.usdToCZK) {
                        showAllModels = true
                    }
                }
                if let tip = feed.tips.max(by: { ($0.savingUSD ?? 0) < ($1.savingUSD ?? 0) }), tip.savingUSD != nil {
                    tipTeaser(tip, rate: summary.usdToCZK)
                }
                if feed.sample {
                    Text("Ukázková data. Tohle není váš účet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if ProAccess.showsPaywall(serverPlanIsPro: summary.isPro, storeEntitled: model.proStore.isEntitled) {
                    Text("Tokeny Pro přidá celou historii, odhad a upozornění na rozpočet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                updated
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.refresh() }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Zatím žádná data", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Nejdřív připojte klíč poskytovatele, nebo importujte soubor s využitím.")
        } actions: {
            VStack(spacing: 12) {
                Button("Připojit klíč") { tab = .sources }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: 50)
                Button("Importovat využití") { model.showsImportHub = true }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: 50)
                Button("Ukázková data") { model.showSample() }
                    .font(.body.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }

    private func tipTeaser(_ tip: OptimizationTip, rate: Double) -> some View {
        Button {
            tab = .tips
        } label: {
            HStack(spacing: 12) {
                Text("Největší úspora")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if let saving = tip.savingUSD {
                    Text(Fmt.money(saving, model.currency, rate: rate))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(TokenyColor.positive(scheme))
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tokenyGlass(interactive: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var updated: some View {
        let moment = model.refreshedAt ?? model.cached?.fetchedAt
        if let moment {
            Text("Naposledy aktualizováno \(moment.formatted(.relative(presentation: .named)))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var modelsSheet: some View {
        NavigationStack {
            ScrollView {
                if let feed {
                    ModelCard(
                        models: feed.summary.topModels, total: feed.summary.month.costUSD,
                        currency: model.currency, rate: feed.summary.usdToCZK, limit: nil, onShowAll: nil)
                        .padding(20)
                }
            }
            .tokenyScreen()
            .navigationTitle("Nejdražší modely")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hotovo") { showAllModels = false }
                }
            }
        }
    }
}

private struct OverviewFeed {
    var summary: UsageSummary
    var forecastUSD: Double?
    var tips: [OptimizationTip]
    var sample: Bool
}

private struct SpendHero: View {
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 48
    var range: SpendRange
    var slice: SpendSlice
    var forecastUSD: Double?
    var budget: UsageSummary.Budget?
    var monthCostUSD: Double
    var currency: Currency
    var rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(primary)
                .font(.system(size: amountSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let forecastUSD {
                Text("Odhad do konce měsíce \(Fmt.money(forecastUSD, currency, rate: rate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let budget, budget.monthlyUSD > 0 {
                budgetBar(spent: monthCostUSD, limit: budget.monthlyUSD)
            }
            if let delta = slice.delta {
                deltaChip(delta)
            }
            if slice.daily.count > 1 {
                sparkline
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass(radius: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var title: String {
        switch range {
        case .month: String(localized: "Útrata tento měsíc")
        case .sevenDays: String(localized: "Útrata za 7 dní")
        case .thirtyDays: String(localized: "Útrata za 30 dní")
        }
    }

    private var primary: String { Fmt.money(slice.costUSD, currency, rate: rate) }

    private var footnote: String {
        let other: Currency = currency == .czk ? .usd : .czk
        let money = Fmt.money(slice.costUSD, other, rate: rate)
        let rateText = rate.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "cs_CZ")))
        return String(localized: "\(money) · kurz \(rateText) Kč/$")
    }

    private var sparkline: some View {
        Chart(slice.daily) { day in
            AreaMark(
                x: .value("Den", day.date),
                y: .value("Útrata", currency == .czk ? day.costUSD * rate : day.costUSD)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [TokenyColor.accent(scheme).opacity(0.30), TokenyColor.accent(scheme).opacity(0)],
                    startPoint: .top, endPoint: .bottom))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 56)
        .accessibilityHidden(true)
    }

    private func budgetBar(spent: Double, limit: Double) -> some View {
        let fraction = limit > 0 ? max(0, spent) / limit : 0
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary)
                    Capsule()
                        .fill(TokenyColor.budgetTint(fraction: fraction, scheme: scheme))
                        .frame(width: max(0, geo.size.width * min(fraction, 1)))
                }
            }
            .frame(height: 6)
            Text("\(Fmt.money(spent, currency, rate: rate)) z \(Fmt.money(limit, currency, rate: rate))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityHidden(true)
    }

    private func deltaChip(_ delta: Double) -> some View {
        let percent = Int((abs(delta) * 100).rounded())
        let sign = delta > 0 ? "+" : delta < 0 ? "−" : ""
        let tint = delta > 0 ? TokenyColor.danger(scheme) : TokenyColor.positive(scheme)
        return Text("\(sign)\(Fmt.percent(percent)) proti minulému měsíci")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(tint.opacity(0.15), in: Capsule())
    }

    private var spoken: String {
        let amount = spokenMoney(primary)
        if let forecastUSD {
            let forecast = spokenMoney(Fmt.money(forecastUSD, currency, rate: rate))
            return String(localized: "\(title) \(amount), odhad \(forecast)")
        }
        return String(localized: "\(title) \(amount)")
    }

    private func spokenMoney(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{00A0}Kč", with: " korun").replacingOccurrences(of: "Kč", with: " korun")
    }
}

private struct TodayHours: View {
    @Environment(\.colorScheme) private var scheme
    var hours: [HourTotal]
    var currency: Currency
    var rate: Double

    private var usesCost: Bool { hours.contains { $0.costUSD > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dnes po hodinách")
                .font(.title3.weight(.semibold))
            Text(usesCost ? String(localized: "Útrata podle hodin, jak ji poslal poskytovatel.") : String(localized: "Tokeny podle hodin. Hodinová útrata v dolarech v datech není."))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Chart(hours) { hour in
                BarMark(
                    x: .value("Hodina", String(hour.hour.suffix(2))),
                    y: .value("Hodnota", usesCost ? (currency == .czk ? hour.costUSD * rate : hour.costUSD) : Double(hour.tokens))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [TokenyColor.accent(scheme), TokenyColor.accent(scheme).opacity(0.30)],
                        startPoint: .top, endPoint: .bottom))
                .cornerRadius(3)
            }
            .frame(height: 120)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6))
            }
            .chartYAxis(.hidden)
        }
        .padding(20)
        .tokenyGlass()
    }
}

private struct ProviderCard: View {
    var providers: [UsageSummary.Share]
    var total: Double
    var currency: Currency
    var rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Poskytovatelé")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 12)
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                providerRow(provider)
                    .frame(minHeight: 64)
                if index < providers.count - 1 {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .padding(20)
        .tokenyGlass()
    }

    private func providerRow(_ provider: UsageSummary.Share) -> some View {
        let share = total > 0 ? provider.costUSD / total : 0
        let tint = TokenyColor.provider(provider.name)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(mark(provider.name))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.15), in: Circle())
                Text(provider.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.money(provider.costUSD, currency, rate: rate))
                        .font(.body)
                        .monospacedDigit()
                    Text(Fmt.percent(Int((share * 100).rounded())))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            GeometryReader { geo in
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geo.size.width * min(max(share, 0), 1)), height: 4)
            }
            .frame(height: 4)
            .padding(.leading, 44)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func mark(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }
}

private struct ModelCard: View {
    var models: [UsageSummary.Share]
    var total: Double
    var currency: Currency
    var rate: Double
    var limit: Int? = 5
    var onShowAll: (() -> Void)?

    var body: some View {
        let shown = limit.map { Array(models.prefix($0)) } ?? models
        return VStack(alignment: .leading, spacing: 12) {
            Text("Nejdražší modely")
                .font(.title3.weight(.semibold))
            ForEach(shown) { model in
                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.model(model.name))
                        .font(.body)
                        .lineLimit(2)
                    Spacer(minLength: 12)
                    Text(Fmt.money(model.costUSD, currency, rate: rate))
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
            }
            if let onShowAll, models.count > shown.count {
                Button("Zobrazit vše", action: onShowAll)
                    .font(.body.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
    }
}
