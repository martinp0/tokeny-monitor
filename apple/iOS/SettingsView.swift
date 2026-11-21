import SwiftUI
import TokenyCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var showingPaywall = false
    @State private var showingAccountSignIn = false
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPaywall) { paywall }
            .sheet(isPresented: $showingAccountSignIn) { TokenyAccountSignInSheet() }
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
            Text("Account")
                .font(.title3.weight(.semibold))
            accountIdentity
            if model.auth.serverUserID != nil && model.summary?.isPro != true && model.proStore.isEntitled {
                Text(ProAccess.storeSyncNote(syncFailed: model.proStore.notice == .syncFailed, languageCode: Bundle.main.preferredLocalizations.first))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if model.auth.serverUserID == nil {
                Button("Sign in to a Tokeny account") { showingAccountSignIn = true }
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            if model.auth.isSignedIn {
                Button("Sign out") { Task { await model.signOut() } }
                    .buttonStyle(.glass)
                    .font(.body.weight(.semibold))
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

    @ViewBuilder
    private var accountIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.auth.isLocalIdentity {
                Text("Signed in with Apple on this device")
                    .font(.body)
                if let email = model.auth.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("This Apple ID is saved on this device. To subscribe, sign in with the email and password of your Tokeny account. Sign in with Apple stays available, and connects the purchase once Tokeny accepts that Apple ID.")
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
                Text("No Tokeny account on this iPhone")
                    .font(.body)
                Text("Sign in with email and password to subscribe to Tokeny Pro. A file or sample data on this iPhone still works.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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
                    Text("Full history, the forecast and alerts.")
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
            Text("Display")
                .font(.title3.weight(.semibold))
            Picker("Main currency", selection: currency) {
                Text("Czech koruna (Kč)").tag(Currency.czk)
                Text("US dollar ($)").tag(Currency.usd)
            }
            Toggle("Budget alerts", isOn: alerts)
            Text("Tokeny notifies you once at the alert threshold and once at 100% of the monthly budget. Set the budget on the web, or on a file on this iPhone.")
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
        Group {
            if model.auth.isLocalIdentity {
                Button("Delete Apple ID from this device", role: .destructive) { confirmingDelete = true }
            } else {
                Button("Delete account…", role: .destructive) { confirmingDelete = true }
            }
        }
        .font(.body)
        .foregroundStyle(TokenyColor.danger(scheme))
        .frame(maxWidth: .infinity, minHeight: 50)
        .disabled(deleting || !model.auth.isSignedIn)
    }

    private var deleteTitle: String {
        model.auth.isLocalIdentity
            ? String(localized: "Remove the Apple ID saved on this device?")
            : String(localized: "Delete your Tokeny account?")
    }

    private var deleteAction: String {
        model.auth.isLocalIdentity
            ? String(localized: "Remove from this device")
            : String(localized: "Delete account and data")
    }

    private var deleteMessage: String {
        model.auth.isLocalIdentity
            ? String(localized: "This removes the Apple ID saved on this device. It does not delete a Tokeny account on the web.")
            : String(localized: "This permanently deletes your Tokeny account, provider keys and usage history. A subscription bought on the web is canceled immediately, with no refund for the rest of that period. An App Store subscription stays active until you cancel it in Settings → Apple ID → Subscriptions.")
    }

    private var paywall: some View {
        NavigationStack {
            ScrollView {
                ProPaywallView()
                    .padding(20)
            }
            .tokenyScreen()
            .navigationTitle("Tokeny Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingPaywall = false }
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
