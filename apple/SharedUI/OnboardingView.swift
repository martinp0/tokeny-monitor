import AuthenticationServices
import SwiftUI
import TokenyAuth
import TokenyCore

/// First launch. One filled action: Sign in with Apple. The file path does not create an account.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var appleNonce = OnboardingNonceBox()
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro
                appleButton
                otherActions
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 64, height: 64)
                .adaptiveGlass(in: Circle())
                .accessibilityHidden(true)
            Text("See your AI spend")
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("Sign in with Apple, or open a usage file on this iPhone. Real numbers come first.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
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
    }

    private var otherActions: some View {
        VStack(spacing: 12) {
            Button("Continue without an account") {
                model.finishOnboarding()
                model.showsImportHub = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)

            Button("Use e-mail") {
                model.finishOnboarding()
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
        }
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
            let name = credential.fullName.flatMap { components -> String? in
                let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return formatted.isEmpty ? nil : formatted
            }
            let user = credential.user
            Task {
                do {
                    _ = try await model.auth.signInWithApple(
                        idToken: token, nonce: nonce, appleUserID: user, email: email, name: name)
                    model.finishOnboarding()
                    await model.didSignIn()
                    if model.auth.isLocalIdentity { model.showsImportHub = true }
                } catch {
                    errorText = String(localized: "Sign in with Apple failed. Try again.")
                }
            }
        }
    }
}

/// Shared with sign-in. Holds the raw nonce until Apple returns.
final class OnboardingNonceBox {
    var nonce: AppleSignInNonce?
}
