import SwiftUI
import TokenyCore

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if let summary = model.summary {
                    content(summary)
                } else if let error = model.lastError {
                    ContentUnavailableView {
                        Label("No data yet", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error.message)
                    } actions: {
                        Button("Try again") { Task { await model.refresh() } }
                            .buttonStyle(.glass)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Tokeny")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingPaywall) {
                NavigationStack {
                    ScrollView {
                        ProPaywallView()
                            .padding(20)
                    }
                    .navigationTitle("Tokeny Pro")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPaywall = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func content(_ s: UsageSummary) -> some View {
        let rate = s.usdToCZK
        let currency = model.currency
        return List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            MoneyStack(usd: s.today.costUSD, currency: currency, rate: rate)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Tokens")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(Fmt.tokens(s.today.tokens))
                                .font(.title2.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                    Divider()
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This month")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            MoneyStack(
                                usd: s.month.costUSD, currency: currency, rate: rate, primaryFont: .title.weight(.semibold))
                        }
                        Spacer()
                        if let forecast = s.forecastMonthUSD {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Forecast")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(Fmt.money(forecast, currency, rate: rate))
                                    .font(.title3.weight(.semibold))
                                    .monospacedDigit()
                            }
                        }
                    }
                    if s.budget != nil {
                        BudgetBar(status: s.budgetStatus, currency: currency, rate: rate)
                    }
                }
                .padding(.vertical, 6)
            } footer: {
                if let cached = model.cached {
                    UpdatedLabel(cached: cached)
                }
            }

            if s.today.costUSD == 0, s.month.costUSD == 0, s.daily.isEmpty, s.month.tokens == 0 {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No usage on this account yet")
                            .font(.headline)
                        Text("Import a file on this iPhone. It is not uploaded to your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Import usage") { model.showsImportHub = true }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.vertical, 4)
                }
            }

            if !s.daily.isEmpty {
                Section("Daily") {
                    DailyChart(days: s.daily, currency: currency, rate: rate)
                        .frame(height: 120)
                        .padding(.vertical, 6)
                }
            }

            if !s.providers.isEmpty {
                Section("Providers") {
                    ForEach(s.providers) { p in
                        ShareRow(title: p.name, usd: p.costUSD, totalUSD: s.month.costUSD, currency: currency, rate: rate)
                    }
                }
            }

            if !s.topModels.isEmpty {
                Section("Top models") {
                    ForEach(s.topModels) { m in
                        ShareRow(
                            title: Fmt.model(m.name), usd: m.costUSD, totalUSD: s.month.costUSD, currency: currency, rate: rate)
                    }
                }
            }

            if let previous = s.previousMonth {
                Section("Last month") {
                    LabeledContent("Spend") {
                        Text(Fmt.money(previous.costUSD, currency, rate: rate)).monospacedDigit()
                    }
                    LabeledContent("Tokens") {
                        Text(Fmt.tokens(previous.tokens)).monospacedDigit()
                    }
                }
            }

            if ProAccess.showsPaywall(serverPlanIsPro: s.isPro, storeEntitled: model.proStore.isEntitled) {
                Section {
                    Button("See Tokeny Pro") { showingPaywall = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else if !s.isPro && model.proStore.isEntitled && model.auth.serverUserID != nil {
                Section {
                    Text(ProAccess.storeSyncNote(syncFailed: model.proStore.notice == .syncFailed, languageCode: Bundle.main.preferredLocalizations.first))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if s.providers.isEmpty && s.month.requests == 0 {
                Section {
                    Label("Connect an OpenAI, Anthropic or OpenRouter key on the web to see your spend.", systemImage: "key")
                        .font(.callout)
                    Link("Open tokeny.martinpohl.cz", destination: model.config.dashboardURL)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.refresh() }
        .safeAreaInset(edge: .bottom) {
            if let error = model.lastError {
                Label(error.message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .adaptiveGlass(in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppModel.shared)
}
