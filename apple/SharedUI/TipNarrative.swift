import SwiftUI

/// On-device summary of numbers Tokeny already computed. The badges never read this text back.
@MainActor
@Observable
final class TipNarrator {
    var text = ""
    var usedModel = false
    private var applied = ""

    func update(brief: String, fallback: String) async {
        guard brief != applied else { return }
        applied = brief
        if let generated = await OnDeviceModel.summarize(brief), !generated.isEmpty {
            text = generated
            usedModel = true
        } else {
            text = fallback
            usedModel = false
        }
    }
}

enum OnDeviceModel {
    /// Foundation Models when the system language model is available. Otherwise the caller shows `fallback`.
    static func summarize(_ brief: String) async -> String? {
        #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
            return await FoundationSummary.respond(brief)
        #else
            return nil
        #endif
    }
}

#if canImport(FoundationModels)
    import FoundationModels

    @available(iOS 26.0, macOS 26.0, *)
    enum FoundationSummary {
        @MainActor
        static func respond(_ brief: String) async -> String? {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else { return nil }
            let session = LanguageModelSession(instructions: """
                You explain Tokeny spending tips in the same language as the message.
                Use only numbers that appear in the message.
                Do not invent costs, token counts, percentages, or savings.
                If a figure is missing, do not state one.
                Write at most four short sentences.
                """)
            do {
                let response = try await session.respond(to: Prompt(brief))
                return response.content
            } catch {
                return nil
            }
        }
    }
#endif
