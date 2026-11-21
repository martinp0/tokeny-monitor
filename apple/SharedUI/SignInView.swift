import AuthenticationServices
import SwiftUI
import TokenyAuth
import TokenyCore

/// Sign in with Apple, or e-mail and password against the same Neon Auth as the web.
struct SignInView: View {
    /// The purchase sheet hides the on-device file path so the next step is an account that can subscribe.
    var showsDeviceSection: Bool = true

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    private enum Mode { case signIn, signUp }

    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var appleNonce = AppleNonceBox()
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                appleButton
                divider
                emailCard
                submitButton
                modeLinks
                if showsDeviceSection {
                    deviceSection
                }
                footer
            }
            .padding(20)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollContentBackground(.hidden)
        .tokenyScreen()
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 88, height: 88)
                .tokenyGlass(radius: 44)
                .accessibilityHidden(true)
            Text("Tokeny")
                .font(.largeTitle.bold())
            Group {
                if showsDeviceSection {
                    Text("Your AI spend across OpenAI, Anthropic and OpenRouter, in Kč and dollars.")
                } else {
                    Text("Use the email and password of your Tokeny account. You can subscribe after that.")
                }
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = AppleSignInNonce.random()
            appleNonce.nonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce.sha256
        } onCompletion: { result in
            let outcome = result
            Task { @MainActor in handleApple(outcome) }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    }

    private var divider: some View {
        HStack {
            VStack { Divider() }
            Text("or with e-mail")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack { Divider() }
        }
    }

    private var emailCard: some View {
        VStack(spacing: 0) {
            TextField("E-mail", text: $email)
                .textContentType(.username)
                .autocorrectionDisabled()
                #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                #endif
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
            Divider()
            SecureField("Password", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
        }
        .tokenyGlass()
    }

    private var submitButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let infoText {
                Label(infoText, systemImage: "envelope.badge")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(action: submit) {
                Group {
                    if busy {
                        ProgressView()
                    } else if mode == .signIn {
                        Text("Sign in")
                    } else {
                        Text("Create account")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .opacity(canSubmit && !busy ? 1 : 0.45)
            .disabled(busy || !canSubmit)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var modeLinks: some View {
        HStack {
            Button {
                withAnimation { mode = mode == .signIn ? .signUp : .signIn }
                errorText = nil
                infoText = nil
            } label: {
                if mode == .signIn {
                    Text("Create account")
                } else {
                    Text("I have an account")
                }
            }
            Spacer()
            if mode == .signIn {
                Button("Forgot password?", action: resetPassword)
                    .disabled(busy || !email.contains("@"))
            }
        }
        .font(.footnote)
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .frame(minHeight: 44)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On this iPhone, without an account")
                .font(.title3.weight(.semibold))
            VStack(spacing: 0) {
                deviceRow("Import usage", systemImage: "square.and.arrow.down") { model.showsImportHub = true }
                Divider()
                deviceRow("Sample data", systemImage: "chart.bar") { model.showSample() }
                if model.onDevice != nil {
                    Divider()
                    deviceRow("What is saved on this iPhone", systemImage: "iphone") { model.showSavedOnDevice() }
                }
            }
            .tokenyGlass()
        }
    }

    private func deviceRow(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button("Open tokeny.martinpohl.cz") { openURL(model.config.webURL) }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= (mode == .signUp ? 8 : 1)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
            errorText = String(localized: "Sign in with Apple failed. Try again.")
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce.nonce
            else {
                errorText = String(localized: "Sign in with Apple failed. Try again.")
                return
            }
            let email = credential.email
            let name = personName(credential.fullName)
            let user = credential.user
            run {
                let outcome = try await model.auth.signInWithApple(
                    idToken: token, nonce: nonce, appleUserID: user, email: email, name: name)
                await model.didSignIn()
                if outcome == .local {
                    infoText = String(localized: "Signed in with Apple on this device only. Use email and password to subscribe.")
                }
            }
        }
    }

    private func personName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func submit() {
        guard canSubmit, !busy else { return }
        run {
            switch mode {
            case .signIn:
                try await model.auth.signIn(email: email, password: password)
                await model.didSignIn()
            case .signUp:
                switch try await model.auth.signUp(email: email, password: password) {
                case .signedIn:
                    await model.didSignIn()
                case .confirmEmail:
                    infoText = String(localized: "Check your inbox and confirm your e-mail, then sign in.")
                    mode = .signIn
                }
            }
        }
    }

    private func resetPassword() {
        run {
            try await model.auth.sendPasswordReset(email: email)
            infoText = String(localized: "We e-mailed you a code. Enter it on the web to set a new password.")
            openURL(model.config.resetPasswordURL(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()))
        }
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        busy = true
        errorText = nil
        infoText = nil
        Task {
            defer { busy = false }
            do {
                try await work()
            } catch {
                errorText = AuthErrorText.message(for: error)
            }
        }
    }
}

private final class AppleNonceBox {
    var nonce: AppleSignInNonce?
}

/// Email and password (and Sign in with Apple) presented from the paywall or Settings.
/// Dismisses once the session has a server user id, which is what a purchase needs.
struct TokenyAccountSignInSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SignInView(showsDeviceSection: false)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .onChange(of: model.auth.serverUserID) { _, userID in
            if userID != nil { dismiss() }
        }
    }
}
