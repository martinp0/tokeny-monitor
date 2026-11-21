import SwiftUI
import TokenyCore

/// Where a key or a file gets into the on-device ledger. The key never leaves the Keychain.
struct SourcesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Připojte poskytovatele")
                            .font(.title3.weight(.semibold))
                        Text("Klíč zůstane v Klíčence na tomto iPhonu. Nic se neposílá na Tokeny.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(ImportProvider.allCases) { provider in
                                NavigationLink {
                                    ProviderImportView(provider: provider)
                                        .navigationTitle(provider.title)
                                        .navigationBarTitleDisplayMode(.inline)
                                        .tokenyScreen()
                                } label: {
                                    sourceRow(provider)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button("Importovat využití") { model.showsImportHub = true }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 50)
                    if let moment = model.refreshedAt {
                        Text("Naposledy aktualizováno \(moment.formatted(.relative(presentation: .named)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .tokenyScreen()
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable { await model.refresh() }
        }
    }

    private func sourceRow(_ provider: ImportProvider) -> some View {
        let preview = model.providerKeys.maskedPreview(provider: provider.rawValue)
        let tint = TokenyColor.provider(provider.title)
        return HStack(spacing: 12) {
            Text(String(provider.title.prefix(1)))
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(preview ?? String(localized: "Nepřipojeno"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .tokenyGlass(interactive: true)
    }
}
