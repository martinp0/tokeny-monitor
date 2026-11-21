import Foundation

/// Text the on-device model is allowed to see. Every figure is copied from a tip or from `monthUSD`.
public enum TipFacts {
    public static func brief(
        tips: [OptimizationTip], monthUSD: Double, rate: Double, currency: Currency, languageCode: String
    ) -> String {
        let czech = languageCode.hasPrefix("cs")
        var lines: [String] = []
        let month = Fmt.money(monthUSD, currency, rate: rate)
        lines.append(czech ? "Útrata tento měsíc: \(month)." : "Spend this month: \(month).")
        lines.append(
            czech
                ? "Vysvětli jen tato čísla. Nepřidávej částky, tokeny ani procenta, která tu nejsou."
                : "Explain only these numbers. Do not add amounts, tokens, or percentages that are not here.")
        for tip in tips {
            lines.append(line(tip, currency: currency, rate: rate, czech: czech))
        }
        if tips.isEmpty {
            lines.append(czech ? "Žádný tip s dopočítanou úsporou." : "No tip with a calculated saving.")
        }
        return lines.joined(separator: "\n")
    }

    /// Same facts, without the instruction line, when the on-device model is unavailable.
    public static func fallback(
        tips: [OptimizationTip], monthUSD: Double, rate: Double, currency: Currency, languageCode: String
    ) -> String {
        let czech = languageCode.hasPrefix("cs")
        var lines = [czech ? "Útrata tento měsíc: \(Fmt.money(monthUSD, currency, rate: rate))." : "Spend this month: \(Fmt.money(monthUSD, currency, rate: rate))."]
        let body = tips.map { line($0, currency: currency, rate: rate, czech: czech) }
        lines.append(contentsOf: body)
        if body.isEmpty {
            lines.append(
                czech
                    ? "Z těchto čísel zatím nevyšel tip s dopočítanou úsporou."
                    : "These numbers did not produce a tip with a calculated saving.")
        }
        return lines.joined(separator: " ")
    }

    private static func line(_ tip: OptimizationTip, currency: Currency, rate: Double, czech: Bool) -> String {
        var parts: [String] = [tip.kind]
        if let model = tip.model, !model.isEmpty { parts.append(model) }
        if let alternative = tip.alternative, !alternative.isEmpty { parts.append(alternative) }
        if let saving = tip.savingUSD {
            let label = czech ? "úspora" : "saving"
            parts.append("\(label) \(Fmt.money(saving, currency, rate: rate))")
        }
        if let requests = tip.requests { parts.append(czech ? "\(requests) požadavků" : "\(requests) requests") }
        if let tokens = tip.tokens { parts.append(czech ? "\(tokens) tokenů" : "\(tokens) tokens") }
        if let day = tip.day { parts.append(day) }
        if let cost = tip.costUSD { parts.append(Fmt.money(cost, currency, rate: rate)) }
        if let median = tip.medianUSD { parts.append(Fmt.money(median, currency, rate: rate)) }
        return parts.joined(separator: ", ")
    }
}
