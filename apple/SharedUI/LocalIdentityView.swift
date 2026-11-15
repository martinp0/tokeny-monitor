import SwiftUI
import TokenyCore
import UniformTypeIdentifiers

/// Home for an Apple ID that is saved only on this device. Nothing here is a Tokeny server session.
struct LocalIdentityView: View {
    @Environment(AppModel.self) private var model
    @State private var importing = false
    @State private var errorText: String?
    @State private var confirmingDelete = false
    @State private var showingPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signed in with Apple on this device")
                        .font(.title2.bold())
                    if let name = model.auth.localAccount?.name, !name.isEmpty {
                        Text(name)
                            .font(.headline)
                    }
                    if let email = model.auth.email {
                        LabeledContent("Signed in as", value: email)
                    }
                    Text("This Apple ID is saved only on this device. Tokeny on the web does not have this sign-in yet, so spend here comes from a file or sample data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Open a usage CSV") { importing = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("View sample data") { model.showSample() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("See Tokeny Pro") { showingPaywall = true }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("Sign out") { Task { await model.signOut() } }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("Delete Apple ID from this device", role: .destructive) { confirmingDelete = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text], allowsMultipleSelection: false) { result in
            importFile(result)
        }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                ScrollView {
                    ProPaywallView()
                        .padding(20)
                }
                .navigationTitle("Tokeny Pro")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingPaywall = false }
                    }
                }
            }
        }
        .confirmationDialog("Remove the Apple ID saved on this device?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove from this device", role: .destructive) {
                Task { try? await model.deleteAccount() }
            }
        } message: {
            Text("This removes the Apple ID saved on this device. It does not delete a Tokeny account on the web.")
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
            } catch is UsageImportError {
                errorText = String(localized: "This file is not an OpenRouter activity export or a Cursor or Grok Bot usage export.")
            } catch {
                errorText = String(localized: "Could not read that file.")
            }
        }
    }
}
