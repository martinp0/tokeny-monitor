import Foundation

/// Failure from an on-device model. The UI turns every failure into the fixed summary.
public enum LocalAIError: Error, Equatable, Sendable {
    case unsupportedLanguage
    case generationFailed
}

/// Availability the app understands. Mapped from `SystemLanguageModel` on iOS; tests set it directly.
public enum LocalModelAvailability: Equatable, Sendable {
    case available
    case unavailable(Reason)

    public enum Reason: Equatable, Sendable {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case unsupportedLanguage
        case unknown
    }
}

/// On-device text generation. Implementations must not open a network connection.
public protocol LocalAIProvider: Sendable {
    var availability: LocalModelAvailability { get }
    func supports(languageCode: String) -> Bool
    func generate(prompt: MonthSummaryPrompt) async throws -> MonthSummaryDraft
}

/// Used when Foundation Models is not in this build, or the China gate is closed.
public struct UnavailableLocalAIProvider: LocalAIProvider {
    public init() {}

    public var availability: LocalModelAvailability { .unavailable(.deviceNotEligible) }

    public func supports(languageCode: String) -> Bool {
        _ = languageCode
        return false
    }

    public func generate(prompt: MonthSummaryPrompt) async throws -> MonthSummaryDraft {
        _ = prompt
        throw LocalAIError.generationFailed
    }
}

/// China mainland storefront. The App Store China AIGC declaration for Tokeny is No,
/// so the on-device summary stays off there. Hong Kong, Macau, and Taiwan stay on.
public enum OnDeviceSummaryAvailability {
    public static let chinaMainlandStorefront = "CHN"
    public static let chinaMainlandRegion = "CN"

    /// `storefrontCountryCode` is StoreKit's code (`CHN`). `regionCode` is `Locale.region` (`CN`).
    /// Unknown codes stay enabled. Only mainland China is off.
    public static func isEnabled(storefrontCountryCode: String?, regionCode: String?) -> Bool {
        !isChinaMainland(storefrontCountryCode) && !isChinaMainland(regionCode)
    }

    public static func isChinaMainland(_ code: String?) -> Bool {
        switch normalized(code) {
        case "CHN", "CN", "CHINA": true
        default: false
        }
    }

    private static func normalized(_ code: String?) -> String {
        code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
    }
}

public enum MonthSummaryRoute: Equatable, Sendable {
    case hidden
    case teaser
    case template(languageCode: String, notice: MonthAISummary.Notice)
    case model(languageCode: String, notice: MonthAISummary.Notice)
}

public enum MonthSummaryPlanner {
    /// Decides the screen without calling a model.
    ///
    /// Czech is not an Apple Intelligence language. When the device language is unsupported and the
    /// model supports English, the route is the model in English. Otherwise it is the fixed template.
    /// `deviceNotEligible`, `appleIntelligenceNotEnabled`, and `modelNotReady` never call the model.
    public static func route(
        isPro: Bool,
        storefrontCountryCode: String?,
        regionCode: String?,
        storefrontKnown: Bool,
        deviceLanguageCode: String?,
        availability: LocalModelAvailability,
        modelSupports: (String) -> Bool
    ) -> MonthSummaryRoute {
        let storefront = storefrontKnown ? storefrontCountryCode : nil
        if !OnDeviceSummaryAvailability.isEnabled(storefrontCountryCode: storefront, regionCode: regionCode) {
            return .hidden
        }
        let device = MonthSummaryLanguage.code(from: deviceLanguageCode)
        let templateLanguage = MonthSummaryLanguage.templateCode(for: device)
        // The teaser names Apple Intelligence. Keep it off until the storefront is known,
        // so a China mainland storefront never shows it.
        if !storefrontKnown {
            if !isPro { return .hidden }
            return .template(languageCode: templateLanguage, notice: .pendingRegionCheck)
        }
        if !isPro { return .teaser }
        switch availability {
        case .available:
            return languageChoice(device: device, templateLanguage: templateLanguage, modelSupports: modelSupports)
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .template(languageCode: templateLanguage, notice: .deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .template(languageCode: templateLanguage, notice: .appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .template(languageCode: templateLanguage, notice: .modelNotReady)
            case .unsupportedLanguage:
                return languageChoice(device: device, templateLanguage: templateLanguage, modelSupports: modelSupports)
            case .unknown:
                return .template(languageCode: templateLanguage, notice: .modelFailed)
            }
        }
    }

    private static func languageChoice(
        device: String, templateLanguage: String, modelSupports: (String) -> Bool
    ) -> MonthSummaryRoute {
        if modelSupports(device) {
            return .model(languageCode: device, notice: .none)
        }
        if modelSupports("en") {
            let notice: MonthAISummary.Notice = device == "en" ? .none : .generatedInEnglish
            return .model(languageCode: "en", notice: notice)
        }
        return .template(languageCode: templateLanguage, notice: .unsupportedLanguage)
    }
}

public enum MonthSummaryPresentation: Equatable, Sendable {
    case hidden
    case teaser
    case content(MonthAISummary)
}

public enum MonthSummaryService {
    /// Builds the screen. A model error becomes the fixed summary. This method does not throw.
    public static func present(
        summary: UsageSummary,
        tips: [MonthSummaryTipFact] = [],
        isPro: Bool,
        currency: Currency,
        storefrontCountryCode: String?,
        regionCode: String?,
        storefrontKnown: Bool,
        deviceLanguageCode: String?,
        provider: any LocalAIProvider
    ) async -> MonthSummaryPresentation {
        let route = MonthSummaryPlanner.route(
            isPro: isPro,
            storefrontCountryCode: storefrontCountryCode,
            regionCode: regionCode,
            storefrontKnown: storefrontKnown,
            deviceLanguageCode: deviceLanguageCode,
            availability: provider.availability,
            modelSupports: { provider.supports(languageCode: $0) }
        )
        switch route {
        case .hidden:
            return .hidden
        case .teaser:
            return .teaser
        case .template(let languageCode, let notice):
            let facts = MonthSummaryFacts.make(summary: summary, tips: tips, currency: currency)
            return .content(MonthSummaryTemplate.make(facts: facts, languageCode: languageCode, notice: notice))
        case .model(let languageCode, let notice):
            let facts = MonthSummaryFacts.make(summary: summary, tips: tips, currency: currency)
            let prompt = MonthSummaryPromptBuilder.make(facts: facts, languageCode: languageCode)
            let device = MonthSummaryLanguage.code(from: deviceLanguageCode)
            let fallback = MonthSummaryTemplate.make(
                facts: facts, languageCode: MonthSummaryLanguage.templateCode(for: device), notice: notice)
            do {
                let draft = try await provider.generate(prompt: prompt)
                if let accepted = MonthSummaryTemplate.accepting(draft, languageCode: languageCode, notice: notice, fallback: fallback) {
                    return .content(accepted)
                }
                return .content(replacing(fallback, notice: .modelFailed))
            } catch is CancellationError {
                return .content(fallback)
            } catch let error as LocalAIError where error == .unsupportedLanguage {
                return .content(replacing(fallback, notice: .unsupportedLanguage))
            } catch {
                return .content(replacing(fallback, notice: .modelFailed))
            }
        }
    }

    private static func replacing(_ summary: MonthAISummary, notice: MonthAISummary.Notice) -> MonthAISummary {
        MonthAISummary(
            headline: summary.headline, spendChanges: summary.spendChanges, topModels: summary.topModels,
            topProviders: summary.topProviders, savingTips: summary.savingTips, origin: .template,
            languageCode: summary.languageCode, notice: notice)
    }
}
