import SwiftUI
import TokenyCore
import UniformTypeIdentifiers

/// Four sources. One filled button on the detail screen, never on the list.
struct ImportHubView: View {
    @Environment(AppModel.self) private var model
    @State private var provider: ImportProvider?

    var body: some View {
        NavigationStack {
            Group {
                if let provider {
                    ProviderImportView(provider: provider)
                } else {
                    list
                }
            }
            .navigationTitle(provider?.title ?? String(localized: "Import usage"))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if provider == nil {
                        Button("Close") { model.showsImportHub = false }
                    } else {
                        Button("Back") { self.provider = nil }
                    }
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Where should Tokeny read?")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("The file stays on this iPhone. A key stays in the Keychain. Nothing is uploaded.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(ImportProvider.allCases) { item in
                    Button {
                        provider = item
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(item.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(16)
                        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Button("View sample data") { model.showSample() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                if !model.auth.isSignedIn {
                    Button("Sign in") { model.showsImportHub = false }
                        .buttonStyle(.borderless)
                        .frame(minHeight: 44)
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum ImportProvider: String, CaseIterable, Identifiable {
    case cursor
    case openai
    case anthropic
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cursor: String(localized: "Grok Bot and Cursor")
        case .openai: String(localized: "OpenAI")
        case .anthropic: String(localized: "Anthropic")
        case .gemini: String(localized: "Gemini")
        }
    }

    var summary: String {
        switch self {
        case .cursor: String(localized: "CSV from the dashboard. A team can also use a read-only team key.")
        case .openai: String(localized: "Admin usage key, or a CSV from the usage page.")
        case .anthropic: String(localized: "Admin usage key, or a CSV from the console.")
        case .gemini: String(localized: "Cloud Billing CSV. Gemini has no usage API for an API key.")
        }
    }

    var steps: String {
        switch self {
        case .cursor:
            String(localized: "Open cursor.com/dashboard, then Usage, then Export CSV. The file has Billing Item ID, Event Time and Product. Grok Bot is the product column. A personal account has no usage API.")
        case .openai:
            String(localized: "On platform.openai.com open Usage, then Export. Activity data has tokens. Cost data has dollars. Or create an Admin key under Organization settings. A normal API key cannot read usage. Tokeny sends the key only to api.openai.com.")
        case .anthropic:
            String(localized: "In the Claude console open Usage or Cost and export CSV. Or create an Admin key. A normal API key cannot read the usage report. Tokeny sends the key only to api.anthropic.com.")
        case .gemini:
            String(localized: "Google AI Studio has no usage or cost API. In Google Cloud Billing open Reports, filter to Generative Language API or Vertex AI, group by Date and SKU, then Download CSV. Tokeny reads the Subtotal in USD and skips other services. Do not paste a Gemini API key.")
        }
    }

    var keySteps: String? {
        switch self {
        case .cursor:
            String(localized: "On a team, an admin creates a key at cursor.com/dashboard, API Keys. Use read access. Tokeny stores it in the Keychain and calls api.cursor.com.")
        case .openai, .anthropic:
            nil
        case .gemini:
            nil
        }
    }

    var supportsKey: Bool { self != .gemini }
    /// CSV is the primary action for Cursor and Gemini. Admin APIs are primary for OpenAI and Anthropic.
    var keyIsPrimary: Bool { self == .openai || self == .anthropic }
}

struct ProviderImportView: View {
    @Environment(AppModel.self) private var model
    var provider: ImportProvider
    @State private var secret = ""
    @State private var useKey = false
    @State private var importing = false
    @State private var busy = false
    @State private var errorText: String?
    @State private var preview: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                instructions
                if useKey {
                    keyEntry
                } else {
                    fileEntry
                }
                savedKey
                status
                importError
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            useKey = provider.keyIsPrimary
            preview = model.providerKeys.maskedPreview(provider: provider.rawValue)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text], allowsMultipleSelection: false) { result in
            importFile(result)
        }
    }

    @ViewBuilder
    private var instructions: some View {
        Text(provider.steps)
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
        if useKey, let keySteps = provider.keySteps {
            Text(keySteps)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyEntry: some View {
        VStack(alignment: .leading, spacing: 16) {
            SecureField("Usage key", text: $secret)
                .textContentType(.password)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(.fill.tertiary, in: .rect(cornerRadius: 14))
            Button("Load usage") { Task { await load() } }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(busy || !canLoad)
            Button("Use a CSV instead") { useKey = false }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var canLoad: Bool {
        preview != nil || !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var fileEntry: some View {
        Button("Choose a CSV") { importing = true }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 44)
        if provider.supportsKey {
            Button("Use a key instead") { useKey = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    @ViewBuilder
    private var savedKey: some View {
        if let preview {
            LabeledContent("Saved key", value: preview)
                .font(.footnote)
            Button("Delete key", role: .destructive) {
                model.providerKeys.delete(provider: provider.rawValue)
                self.preview = nil
                secret = ""
            }
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var importError: some View {
        if let errorText {
            Label(errorText, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func latestImport() -> ProviderImportRecord? {
        model.onDevice?.imports?.last { record in
            record.provider == provider.rawValue
                || (provider == .cursor && (record.provider == "grok-bot" || record.provider == "cursor"))
        }
    }

    @ViewBuilder
    private var status: some View {
        if let record = latestImport() {
            VStack(alignment: .leading, spacing: 4) {
                Text("Last import")
                    .font(.headline)
                Text(record.at)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LabeledContent("Rows added", value: String(record.added))
                    .font(.footnote)
                if record.alreadyStored > 0 {
                    LabeledContent("Already saved", value: String(record.alreadyStored))
                        .font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func load() async {
        let typed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = typed.isEmpty ? model.providerKeys.load(provider: provider.rawValue) ?? "" : typed
        guard !key.isEmpty else { return }
        busy = true
        errorText = nil
        defer { busy = false }
        if !typed.isEmpty {
            guard model.providerKeys.save(provider: provider.rawValue, secret: typed) else {
                errorText = String(localized: "The key could not be saved in the Keychain.")
                model.noteImportFailure(provider: provider.rawValue, method: "api", outcome: "keychain", keyPreview: nil)
                return
            }
            secret = ""
            preview = SecretPreview.mask(key)
        }
        do {
            let rows = try await ProviderSync.fetch(provider: provider.rawValue, apiKey: key)
            model.importActivities(rows, provider: provider.rawValue, method: "api", keyPreview: SecretPreview.mask(key))
        } catch let error as ProviderAPIError {
            errorText = ImportErrorText.message(for: error)
            model.noteImportFailure(provider: provider.rawValue, method: "api", outcome: outcome(error), keyPreview: preview)
        } catch {
            errorText = ImportErrorText.message(for: ProviderAPIError.unreachable)
        }
    }

    private func outcome(_ error: ProviderAPIError) -> String {
        switch error {
        case .unauthorized: return "unauthorized"
        case .forbidden: return "forbidden"
        case .rateLimited: return "rate"
        case .badRequest: return "badRequest"
        case .unexpected, .unreachable: return "unreachable"
        }
    }

    private func importFile(_ result: Result<[URL], any Error>) {
        switch result {
        case .failure:
            errorText = String(localized: "Could not read that file.")
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                if let size, size > UsageImport.maxBytes {
                    errorText = String(localized: "That file is too large to open in the app.")
                    return
                }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    errorText = String(localized: "Could not read that file.")
                    return
                }
                try model.importUsageText(text, fileName: url.lastPathComponent)
                errorText = nil
            } catch let error as UsageImportError {
                errorText = ImportErrorText.message(for: error)
            } catch {
                errorText = String(localized: "Could not read that file.")
            }
        }
    }
}
