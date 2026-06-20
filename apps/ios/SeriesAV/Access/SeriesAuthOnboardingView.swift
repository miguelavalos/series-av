import AVProductAccountFoundation
import AVSettingsFoundation
import SwiftUI
import os

struct SeriesAuthOnboardingView: View {
    @Binding var authPresentationState: AVProductAccountAuthPresentationState
    let accountIsAvailable: Bool
    let onContinueWithApple: () async throws -> Void
    let onContinueWithGoogle: () async throws -> Void
    let onSkip: () -> Void

    private let authLogger = Logger(subsystem: "com.avalsys.seriesav", category: "auth")

    var body: some View {
        AVAuthConfiguredOnboardingScreen(
            authOptionsArePresented: authOptionsArePresentedBinding,
            primaryAction: accountIsAvailable ? showAuthOptions : onSkip,
            secondaryAction: onSkip,
            brandWidth: 160,
            ctaCompanionOffset: CGSize(width: -2, height: -112),
            authPanel: {
                SeriesAuthOptionsPanel(
                    accountIsAvailable: accountIsAvailable,
                    activeProvider: activeProvider,
                    onAppleTap: startAppleSignIn,
                    onGoogleTap: startGoogleSignIn,
                    onSkip: onSkip
                )
            }
        )
        .alert(L10n.string("access.error.title"), isPresented: isShowingErrorBinding) {
            Button(L10n.string("common.close"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func showAuthOptions() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            authPresentationState = .onboardingOptions
        }
    }

    private func startAppleSignIn() {
        startSignIn(provider: .apple, operation: onContinueWithApple)
    }

    private func startGoogleSignIn() {
        startSignIn(provider: .google, operation: onContinueWithGoogle)
    }

    private func startSignIn(provider: AVAuthProvider, operation: @escaping () async throws -> Void) {
        guard accountIsAvailable else {
            authPresentationState = .error(message: L10n.string("access.unavailable"), optionsExpanded: true)
            return
        }
        guard authPresentationState.activeProvider == nil else { return }

        let authProvider: AVProductAccountAuthProvider = provider == .apple ? .apple : .google
        authPresentationState = .busy(.provider(authProvider))

        Task { @MainActor in
            do {
                try await operation()
                authPresentationState = .hidden
            } catch {
                guard !error.avProductAccountIsAuthenticationCancellation else {
                    authPresentationState = .onboardingOptions
                    return
                }

                logAuthError(error, provider: provider)
                authPresentationState = .error(message: error.localizedDescription, optionsExpanded: true)
            }
        }
    }

    private var authOptionsArePresentedBinding: Binding<Bool> {
        Binding(
            get: { authPresentationState.optionsAreExpanded },
            set: { isPresented in
                guard authPresentationState.activeProvider == nil else { return }
                authPresentationState = isPresented ? .onboardingOptions : .onboardingCollapsed
            }
        )
    }

    private var isShowingErrorBinding: Binding<Bool> {
        Binding(
            get: {
                if case .error = authPresentationState {
                    return true
                }
                return false
            },
            set: { isPresented in
                guard !isPresented else { return }
                authPresentationState = .onboardingOptions
            }
        )
    }

    private var activeProvider: AVAuthProvider? {
        switch authPresentationState.activeProvider {
        case .apple:
            .apple
        case .google:
            .google
        case nil:
            nil
        }
    }

    private var errorMessage: String {
        if case .error(let message, _) = authPresentationState {
            return message
        }
        return ""
    }

    private func logAuthError(_ error: Error, provider: AVAuthProvider) {
        let nsError = error as NSError
        let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        let underlyingDomain = underlyingError?.domain ?? "none"
        let underlyingCode = underlyingError?.code ?? 0
        let providerName = provider == .apple ? "apple" : "google"
        authLogger.error(
            "Account AV \(providerName, privacy: .public) failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) underlying_domain=\(underlyingDomain, privacy: .public) underlying_code=\(underlyingCode, privacy: .public)"
        )
    }
}

private struct SeriesAuthOptionsPanel: View {
    let accountIsAvailable: Bool
    let activeProvider: AVAuthProvider?
    let onAppleTap: () -> Void
    let onGoogleTap: () -> Void
    let onSkip: () -> Void

    @Environment(\.avCommonAppExperience) private var appExperience

    var body: some View {
        AVAuthOptionsPanel(
            title: L10n.string("access.connect.title"),
            subtitle: L10n.string("access.connect.subtitle"),
            legalConsentText: legalConsentText,
            unavailableMessage: unavailableMessage,
            skipTitle: L10n.string("access.skip"),
            appleTitle: L10n.string("access.apple"),
            googleTitle: L10n.string("access.google"),
            isBusy: activeProvider != nil,
            activeProvider: activeProvider,
            isAvailable: accountIsAvailable,
            appleAccessibilityIdentifier: "series.onboarding.auth.apple",
            googleAccessibilityIdentifier: "series.onboarding.auth.google",
            onApple: onAppleTap,
            onGoogle: onGoogleTap,
            onSkip: onSkip
        ) {
            AVAuthConfiguredCompanionArtwork(
                placement: .authPanel,
                imageWidth: 126,
                imageHeight: 126,
                frameWidth: 140,
                frameHeight: 110,
                imageOffset: CGSize(width: 0, height: -5),
                groundShadowColor: nil
            )
                .offset(x: -44, y: -91)
                .allowsHitTesting(false)
        }
    }

    private var legalConsentText: AttributedString {
        let termsURL = appExperience.legalLinks.termsURL?.absoluteString ?? AppConfig.termsURL.absoluteString
        let privacyURL = appExperience.legalLinks.privacyURL?.absoluteString ?? AppConfig.privacyURL.absoluteString
        let markdown = L10n.string("access.legal.markdown", termsURL, privacyURL)
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(L10n.string("access.legal.fallback"))
    }

    private var unavailableMessage: String? {
        if !accountIsAvailable {
            return L10n.string("access.unavailable")
        }
        return nil
    }
}
