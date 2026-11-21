import SwiftUI
import TokenyCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var showingPaywall = false
    @State private var showingBlog = false

    private var blogURL: URL {
        model.config.blogURL(languageCode: Bundle.main.preferredLocalizations.first)
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    account
                    proRow
                    display(currency: $model.currency, alerts: $model.budgetAlertsEnabled)
                    about
                    if let deleteError {
                        Text(deleteError)
                            .font(.footnote)
                            .foregroundStyle(TokenyColor.danger(scheme))
                    }
                    if model.auth.isSignedIn {
                        deleteButton
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .tokenyScreen()
            .navigationTitle("Nastavení")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPaywall) { paywall }
            .fullScreenCover(isPresented: $showingBlog) {
                SafariView(url: blogURL) { showingBlog = false }
                    .ignoresSafeArea()
            }
            .confirmationDialog(deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button(deleteAction, role: .destructive) { runDelete() }
            } message: {
                Text(deleteMessage)
            }
        }
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Účet")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                if model.auth.isLocalIdentity {
                    Text("Přihlášeno přes Apple · jen na tomto zařízení")
                        .font(.body)
                    if let email = model.auth.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Tokeny na webu tento Apple účet zatím nezná. Útrata tady je z klíče nebo ze souboru na tomto iPhonu.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let email = model.auth.email {
                    Text(email)
                        .font(.body)
                    if model.summary != nil {
                        Text(model.hasPro ? "Pro" : String(localized: "Free"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Bez účtu na tomto iPhonu")
                        .font(.body)
                }
                if model.auth.serverUserID != nil && model.summary?.isPro != true && model.proStore.isEntitled {
                    Text(ProAccess.storeSyncNote(syncFailed: model.proStore.notice == .syncFailed, languageCode: Bundle.main.preferredLocalizations.first))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if model.auth.isSignedIn {
                Button("Odhlásit se") { Task { await model.signOut() } }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                Button("Přihlásit se") { model.showSignIn() }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            if model.auth.serverUserID != nil {
                Link(destination: model.accountURL) {
                    Label("Manage account on the web", systemImage: "safari")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
    }

    private var proRow: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tokeny Pro")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Celá historie, odhad a upozornění.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(minHeight: 64)
            .tokenyGlass(interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func display(currency: Binding<Currency>, alerts: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zobrazení")
                .font(.title3.weight(.semibold))
            Picker("Hlavní měna", selection: currency) {
                Text("Česká koruna (Kč)").tag(Currency.czk)
                Text("Americký dolar ($)").tag(Currency.usd)
            }
            Toggle("Upozornění na rozpočet", isOn: alerts)
            Text("Tokeny upozorní jednou na práh a jednou na 100 % měsíčního rozpočtu. Rozpočet se nastavuje na webu, nebo u souboru na tomto iPhonu.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Blog") { showingBlog = true }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            Link("Privacy", destination: model.config.webURL.appending(path: "privacy"))
                .frame(minHeight: 44)
            LabeledContent("Version", value: Bundle.main.versionString)
                .font(.subheadline)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenyGlass()
    }

    private var deleteButton: some View {
        Button(model.auth.isLocalIdentity ? "Odstranit Apple ID z tohoto zařízení" : "Smazat účet…", role: .destructive) {
            confirmingDelete = true
        }
        .font(.body)
        .foregroundStyle(TokenyColor.danger(scheme))
        .frame(maxWidth: .infinity, minHeight: 50)
        .disabled(deleting || !model.auth.isSignedIn)
    }

    private var deleteTitle: String {
        model.auth.isLocalIdentity
            ? String(localized: "Odstranit Apple ID z tohoto zařízení?")
            : String(localized: "Delete your Tokeny account?")
    }

    private var deleteAction: String {
        model.auth.isLocalIdentity
            ? String(localized: "Odstranit z tohoto zařízení")
            : String(localized: "Delete account and data")
    }

    private var deleteMessage: String {
        model.auth.isLocalIdentity
            ? String(localized: "Tohle smaže Apple ID uložené na tomto zařízení. Účet Tokeny na webu se nemaže.")
            : String(localized: "This permanently deletes your Tokeny account, provider keys and usage history. A subscription bought on the web is canceled immediately, with no refund for the rest of that period. An App Store subscription stays active until you cancel it in Settings → Apple ID → Subscriptions.")
    }

    private var paywall: some View {
        NavigationStack {
            ScrollView {
                ProPaywallView()
                    .padding(20)
            }
            .navigationTitle("Tokeny Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hotovo") { showingPaywall = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func runDelete() {
        deleting = true
        Task {
            defer { deleting = false }
            do {
                try await model.deleteAccount()
            } catch let error as UsageAPIError {
                deleteError = error.message
            } catch {
                deleteError = UsageAPIError.offline.message
            }
        }
    }
}
