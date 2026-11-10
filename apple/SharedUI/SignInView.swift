import SwiftUI
import TokenyAuth
import TokenyCore
import UniformTypeIdentifiers

/// Sign in with Apple, or e-mail and password against the same Neon Auth as the web.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    private enum Mode { case signIn, signUp }

    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var importing = false
    @FocusState private var focused: Field?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                appleUnavailable
                divider
                emailForm
                onDeviceEntry
                footer
            }
            .padding(24)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text], allowsMultipleSelection: false) { result in
            importFile(result)
        }
    }

    private var appleUnavailable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sign in with Apple is not available in this app.")
                .font(.subheadline.weight(.semibold))
            Text("This app does not start Sign in with Apple. The registered Apple bundle has no Sign in with Apple capability.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var onDeviceEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On this iPhone, without an account")
                .font(.subheadline.weight(.semibold))
            openCSVButton
            Button("View sample data") { model.showSample() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
            if model.onDevice != nil {
                Button("Show what is saved on this iPhone") { model.showSavedOnDevice() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(18)
                .adaptiveGlass(in: Circle())
            Text("Tokeny")
                .font(.largeTitle.bold())
            Text("Your AI spend across OpenAI, Anthropic and OpenRouter, in Kč and dollars.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
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

    private var emailForm: some View {
        VStack(spacing: 12) {
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
                .fieldStyle()

            SecureField("Password", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .fieldStyle()

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let infoText {
                Label(infoText, systemImage: "envelope.badge")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            submitButton

            HStack {
                Button {
                    withAnimation { mode = mode == .signIn ? .signUp : .signIn }
                    errorText = nil
                    infoText = nil
                } label: {
                    mode == .signIn ? Text("Create account") : Text("I have an account")
                }
                Spacer()
                if mode == .signIn {
                    Button("Forgot password?", action: resetPassword)
                        .disabled(busy || !email.contains("@"))
                }
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Connect your provider keys on the web. The app only reads your totals.")
            Button("Open tokeny.martinpohl.cz") { openURL(model.config.webURL) }
                .buttonStyle(.borderless)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var openCSVButton: some View {
        if reduceTransparency {
            Button("Open a usage CSV") { importing = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
        } else {
            Button("Open a usage CSV") { importing = true }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        if reduceTransparency {
            submitControl.buttonStyle(.borderedProminent)
        } else {
            submitControl.buttonStyle(.glassProminent)
        }
    }

    private var submitControl: some View {
        Button(action: submit) {
            Group {
                if busy {
                    ProgressView()
                } else {
                    mode == .signIn ? Text("Sign in") : Text("Create account")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .controlSize(.large)
        .disabled(busy || !canSubmit)
        .keyboardShortcut(.defaultAction)
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= (mode == .signUp ? 8 : 1)
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
            } catch is UsageImportError {
                errorText = String(localized: "This file is not an OpenRouter activity export or a Cursor or Grok Bot usage export.")
            } catch {
                errorText = String(localized: "Could not read that file.")
            }
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

private extension View {
    func fieldStyle() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.fill.tertiary, in: .rect(cornerRadius: 14))
    }
}
