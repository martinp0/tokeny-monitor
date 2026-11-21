import SwiftUI
import TokenyCore

private enum TipFilter: String, CaseIterable, Identifiable {
    case all, saving, models, limits
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "Vše")
        case .saving: String(localized: "Úspora")
        case .models: String(localized: "Modely")
        case .limits: String(localized: "Limity")
        }
    }
}

private struct ShownTip: Identifiable {
    var id: String
    var kind: String
    var title: String
    var summary: String
    var why: String
    var savingUSD: Double?
    var fromAccount: Bool
}

struct TipsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var filter = TipFilter.all
    @State private var narrator = TipNarrator()
    @State private var open: String?

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .tokenyScreen()
            .navigationTitle("Tipy")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task(id: brief) { await narrator.update(brief: brief, fallback: fallback) }
    }

    private var tips: [OptimizationTip] { model.onDevice?.tips ?? [] }

    private var cards: [ShownTip] {
        let local = tips.map { tip in
            ShownTip(
                id: tip.id, kind: tip.kind, title: title(tip), summary: summary(tip), why: why(tip),
                savingUSD: tip.savingUSD, fromAccount: false)
        }
        let remote = model.accountInsights.map { insight in
            ShownTip(
                id: "account-\(insight.id)", kind: "account", title: insight.title,
                summary: insight.detail, why: insight.detail, savingUSD: insight.savingUSD, fromAccount: true)
        }
        return (local + remote).sorted { ($0.savingUSD ?? -1) > ($1.savingUSD ?? -1) }
    }

    private var visible: [ShownTip] {
        cards.filter { card in
            switch filter {
            case .all: return true
            case .saving: return card.savingUSD != nil && card.kind != "spendLimit"
            case .models: return card.kind == "cheaperModel"
            case .limits: return card.kind == "spendLimit" || card.kind == "spike"
            }
        }
    }

    private var rate: Double { model.onDevice?.summary.usdToCZK ?? model.summary?.usdToCZK ?? UsageSummary.fallbackUSDCZK }
    private var monthUSD: Double { model.onDevice?.summary.month.costUSD ?? model.summary?.month.costUSD ?? 0 }

    private var brief: String {
        TipFacts.brief(
            tips: tips, monthUSD: monthUSD, rate: rate, currency: model.currency,
            languageCode: Locale.current.language.languageCode?.identifier ?? "cs")
    }

    private var fallback: String {
        TipFacts.fallback(
            tips: tips, monthUSD: monthUSD, rate: rate, currency: model.currency,
            languageCode: Locale.current.language.languageCode?.identifier ?? "cs")
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                summaryCard
                filters
                if visible.isEmpty {
                    Text("V tomhle filtru nic není.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(visible) { card in
                                tipCard(card)
                            }
                        }
                    }
                }
                Text("Částky v Kč přepočítáváme orientačním kurzem.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Odhad, ne účet. Čísla na kartách jsou spočítaná z dat a ceníku.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.refresh() }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shrnutí")
                .font(.headline)
            Text(narrator.text.isEmpty ? fallback : narrator.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(
                narrator.usedModel
                    ? String(localized: "Na tomto zařízení. Model vysvětluje jen čísla, která už jsou spočítaná.")
                    : String(localized: "Spočítáno z dat, bez jazykového modelu.")
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(TipFilter.allCases) { item in
                        Button {
                            filter = item
                        } label: {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(filter == item ? TokenyColor.accent(scheme) : .secondary)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .tokenyGlass(radius: 18, interactive: true)
                    }
                }
            }
        }
    }

    private func tipCard(_ card: ShownTip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol(card.kind))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TokenyColor.accent(scheme))
                    .frame(width: 36, height: 36)
                    .background(TokenyColor.accent(scheme).opacity(0.15), in: Circle())
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Text(card.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if let saving = card.savingUSD {
                Text("Ušetříš ~\(Fmt.money(saving, model.currency, rate: rate))/měs.")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(TokenyColor.positive(scheme))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 28)
                    .background(TokenyColor.positive(scheme).opacity(0.15), in: Capsule())
            }
            Button(open == card.id ? String(localized: "Skrýt") : String(localized: "Jak na to")) {
                open = open == card.id ? nil : card.id
            }
            .font(.body.weight(.semibold))
            .frame(minHeight: 44)
            if open == card.id {
                Text(card.why)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if card.fromAccount {
                    Text("Tento tip je z účtu na webu.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Tipy se objeví po importu", systemImage: "lightbulb")
        } description: {
            Text("Připojte klíč nebo importujte využití. Pak tu budou konkrétní úspory.")
        }
        .padding(20)
    }

    private func symbol(_ kind: String) -> String {
        switch kind {
        case "cheaperModel": "arrow.left.arrow.right"
        case "promptCache": "memorychip"
        case "batch": "square.stack.3d.up"
        case "spike": "chart.line.uptrend.xyaxis"
        case "account": "person.crop.circle"
        default: "gauge.with.needle"
        }
    }

    private func title(_ tip: OptimizationTip) -> String {
        switch tip.kind {
        case "cheaperModel": String(localized: "Levnější model na opakovanou práci")
        case "promptCache": String(localized: "Prompt caching")
        case "batch": String(localized: "Batch API")
        case "spike": String(localized: "Jeden den vyčnívá")
        default: String(localized: "Nastavte měsíční limit")
        }
    }

    private func summary(_ tip: OptimizationTip) -> String {
        switch tip.kind {
        case "cheaperModel":
            String(localized: "\(tip.model ?? "") místo toho zkuste \(tip.alternative ?? "").")
        case "promptCache":
            String(localized: "Část nekešovaného vstupu může jít jako čtení z cache.")
        case "batch":
            String(localized: "Dávkové volání je v ceníku levnější. Už označené dávky se nepočítají.")
        case "spike":
            String(localized: "\(tip.day ?? "") je výrazně nad běžným dnem.")
        default:
            String(localized: "Bez limitu Tokeny nepozná, kdy je měsíc drahý.")
        }
    }

    private func why(_ tip: OptimizationTip) -> String {
        let saving = tip.savingUSD.map { Fmt.money($0, model.currency, rate: rate) } ?? ""
        switch tip.kind {
        case "cheaperModel":
            let prices = String(
                localized:
                    "\(money(tip.inputPerMillion)) / \(money(tip.outputPerMillion)) oproti \(money(tip.altInputPerMillion)) / \(money(tip.altOutputPerMillion)) za milion tokenů."
            )
            return "\(summary(tip)) \(prices) \(saving)"
        case "promptCache":
            return String(localized: "Polovina nekešovaného vstupu, oceněná jako čtení z cache. První zápis se neodečítá. \(saving)")
        case "batch":
            return String(localized: "Ceník dávky je polovina. Řádky už označené jako dávka se nepočítají. \(saving)")
        case "spike":
            let cost = Fmt.money(tip.costUSD ?? 0, model.currency, rate: rate)
            let typical = Fmt.money(tip.medianUSD ?? 0, model.currency, rate: rate)
            return String(localized: "\(tip.day ?? "") stál \(cost), běžný den je \(typical).")
        default:
            return String(localized: "Na tomhle iPhonu není měsíční limit.")
        }
    }

    private func money(_ usd: Double?) -> String {
        Fmt.money(usd ?? 0, model.currency, rate: rate)
    }
}
