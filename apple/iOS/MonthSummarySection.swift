import StoreKit
import SwiftUI
import TokenyCore

/// Pro month summary on the iPhone overview. The fixed text is on screen immediately.
/// The on-device model, when the route allows it, replaces that text later. The rest of the
/// dashboard stays usable. Watch and widgets do not generate a summary.
struct MonthSummarySection: View {
    var summary: UsageSummary
    var tips: [MonthSummaryTipFact]
    var isPro: Bool
    var currency: Currency
    var onSeePro: () -> Void

    @State private var storefrontCode: String?
    @State private var storefrontResolved = false
    @State private var generated: MonthAISummary?
    @State private var generating = false

    var body: some View {
        Group {
            switch route {
            case .hidden:
                EmptyView()
            case .teaser:
                teaser
            case .template(let languageCode, let notice):
                card(fixed(languageCode: languageCode, notice: notice), generating: false)
            case .model:
                card(shownWhileGenerating, generating: generating && shownWhileGenerating.origin != .onDeviceModel)
            }
        }
        .task { await resolveStorefront() }
        .task(id: modelTaskID) { await generateIfNeeded() }
    }

    private var regionCode: String? { Locale.current.region?.identifier }

    private var deviceCode: String {
        Locale.preferredLanguages.first ?? Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// The model object is created only after the storefront is known and is not mainland China.
    private var allowModel: Bool {
        storefrontResolved && OnDeviceSummaryAvailability.isEnabled(storefrontCountryCode: storefrontCode, regionCode: regionCode)
    }

    private var route: MonthSummaryRoute {
        let availability: LocalModelAvailability
        let supports: (String) -> Bool
        if allowModel {
            let backend = OnDeviceSummaryBackend.provider()
            availability = backend.availability
            supports = { backend.supports(languageCode: $0) }
        } else {
            availability = .unavailable(.unknown)
            supports = { _ in false }
        }
        return MonthSummaryPlanner.route(
            isPro: isPro,
            storefrontCountryCode: storefrontCode,
            regionCode: regionCode,
            storefrontKnown: storefrontResolved,
            deviceLanguageCode: deviceCode,
            availability: availability,
            modelSupports: supports
        )
    }

    private var modelTaskID: String {
        [
            summary.month.key ?? "",
            String(summary.month.costUSD),
            String(summary.previousMonth?.costUSD ?? -1),
            storefrontCode ?? "-",
            storefrontResolved ? "known" : "wait",
            isPro ? "pro" : "free",
            deviceCode,
            currency.rawValue,
        ].joined(separator: "|")
    }

    private var teaser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI month summary")
                .font(.headline)
            Text("Tokeny Pro writes this month's summary on this iPhone with Apple Intelligence. The numbers stay on the device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("See Tokeny Pro", action: onSeePro)
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
    }

    private func card(_ summary: MonthAISummary, generating: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI month summary")
                .font(.headline)
            Text(summary.headline)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            block(title: Text("Spend changes"), lines: summary.spendChanges)
            block(title: Text("Top models"), lines: summary.topModels)
            block(title: Text("Providers"), lines: summary.topProviders)
            block(title: Text("Saving tips"), lines: summary.savingTips)
            if generating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Summarizing on this iPhone…")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Text(footer(summary.notice, origin: summary.origin))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
        .accessibilityElement(children: .combine)
    }

    private var shownWhileGenerating: MonthAISummary {
        generated ?? fixed(languageCode: deviceCode, notice: .none)
    }

    private func block(title: Text, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .font(.subheadline.weight(.semibold))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func fixed(languageCode: String, notice: MonthAISummary.Notice) -> MonthAISummary {
        let facts = MonthSummaryFacts.make(summary: summary, tips: tips, currency: currency)
        return MonthSummaryTemplate.make(facts: facts, languageCode: languageCode, notice: notice)
    }

    private func footer(_ notice: MonthAISummary.Notice, origin: MonthAISummary.Origin) -> String {
        switch notice {
        case .none:
            if origin == .onDeviceModel {
                return String(localized: "Written on this iPhone with Apple Intelligence. Nothing was sent.")
            }
            return String(localized: "This is a fixed summary. Nothing was sent.")
        case .pendingRegionCheck:
            return String(localized: "This is a fixed summary. Nothing was sent.")
        case .deviceNotEligible:
            return String(localized: "This iPhone can't run Apple Intelligence, so this is a fixed summary.")
        case .appleIntelligenceNotEnabled:
            return String(localized: "Apple Intelligence is off, so this is a fixed summary.")
        case .modelNotReady:
            return String(localized: "Apple Intelligence is still downloading, so this is a fixed summary.")
        case .unsupportedLanguage:
            return String(localized: "Apple Intelligence doesn't support this language, so this is a fixed summary.")
        case .generatedInEnglish:
            return String(localized: "The summary is in English because Apple Intelligence doesn't support the language of this iPhone.")
        case .modelFailed:
            return String(localized: "Apple Intelligence didn't answer, so this is a fixed summary.")
        }
    }

    private func resolveStorefront() async {
        guard !storefrontResolved else { return }
        storefrontCode = await Storefront.current?.countryCode
        storefrontResolved = true
    }

    private func generateIfNeeded() async {
        generated = nil
        guard allowModel, isPro else { return }
        let backend = OnDeviceSummaryBackend.provider()
        let decided = MonthSummaryPlanner.route(
            isPro: isPro,
            storefrontCountryCode: storefrontCode,
            regionCode: regionCode,
            storefrontKnown: true,
            deviceLanguageCode: deviceCode,
            availability: backend.availability,
            modelSupports: { backend.supports(languageCode: $0) }
        )
        guard case .model = decided else { return }
        generating = true
        defer { generating = false }
        let presented = await MonthSummaryService.present(
            summary: summary,
            tips: tips,
            isPro: true,
            currency: currency,
            storefrontCountryCode: storefrontCode,
            regionCode: regionCode,
            storefrontKnown: true,
            deviceLanguageCode: deviceCode,
            provider: backend
        )
        if Task.isCancelled { return }
        if case .content(let value) = presented {
            generated = value
        }
    }
}
