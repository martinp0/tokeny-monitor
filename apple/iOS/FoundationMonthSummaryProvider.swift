import Foundation
import TokenyCore

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Picks the on-device backend. Foundation Models stays out of the process when this returns the
/// unavailable provider (China gate, or a build without the framework).
enum OnDeviceSummaryBackend {
    static func provider() -> any LocalAIProvider {
        #if canImport(FoundationModels)
        FoundationMonthSummaryProvider()
        #else
        UnavailableLocalAIProvider()
        #endif
    }
}

#if canImport(FoundationModels)
/// Apple's on-device system model. `LanguageModelSession` does not take a server URL.
struct FoundationMonthSummaryProvider: LocalAIProvider {
    private let model = SystemLanguageModel.default

    var availability: LocalModelAvailability {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .unavailable(.modelNotReady)
            @unknown default:
                let label = String(describing: reason).lowercased()
                if label.contains("language") || label.contains("locale") {
                    return .unavailable(.unsupportedLanguage)
                }
                return .unavailable(.unknown)
            }
        }
    }

    func supports(languageCode: String) -> Bool {
        let code = MonthSummaryLanguage.code(from: languageCode)
        if model.supportsLocale(Locale(identifier: code)) { return true }
        if code == "en" {
            return model.supportsLocale(Locale(identifier: "en_US"))
        }
        return false
    }

    func generate(prompt: MonthSummaryPrompt) async throws -> MonthSummaryDraft {
        let session = LanguageModelSession(model: model)
        do {
            // `includeSchemaInPrompt` selects the iOS 26 method, which the iOS 27 SDK still has.
            let response = try await session.respond(
                to: prompt.text,
                generating: GuidedMonthSummary.self,
                includeSchemaInPrompt: true
            )
            let content = response.content
            return MonthSummaryDraft(
                headline: content.headline,
                spendChanges: content.spendChanges,
                topModels: content.topModels,
                topProviders: content.topProviders,
                savingTips: content.savingTips
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Self.mapped(error)
        }
    }

    /// Xcode 26 throws `LanguageModelSession.GenerationError`. Xcode 27 throws newer error types.
    /// Either way an unsupported language is the signal to show the fixed summary.
    private static func mapped(_ error: Error) -> LocalAIError {
        let label = String(describing: type(of: error)) + " " + String(describing: error)
        let folded = label.lowercased()
        if folded.contains("unsupportedlanguage") || folded.contains("unsupportedlocale") {
            return .unsupportedLanguage
        }
        return .generationFailed
    }
}

@Generable(description: "A short monthly AI spend summary. Use only numbers and names from the prompt.")
struct GuidedMonthSummary {
    @Guide(description: "One sentence headline about this month's AI spend.")
    var headline: String

    @Guide(description: "Key spend changes, one sentence each.", .minimumCount(1), .maximumCount(3))
    var spendChanges: [String]

    @Guide(description: "Most expensive models this month, short names.", .minimumCount(1), .maximumCount(3))
    var topModels: [String]

    @Guide(description: "Providers behind this month's spend.", .minimumCount(1), .maximumCount(3))
    var topProviders: [String]

    @Guide(description: "Practical ways to spend less. Two or three items. Do not invent a saving.", .minimumCount(2), .maximumCount(3))
    var savingTips: [String]
}
#endif
