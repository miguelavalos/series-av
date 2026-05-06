import SwiftUI
import AuthenticationServices
import OSLog

struct OnboardingView: View {
    @EnvironmentObject private var accessController: AccessController
    private let authLogger = Logger(subsystem: "com.avalsys.seriesav", category: "auth")

    @Binding var authOptionsArePresented: Bool
    let onContinueWithApple: () async throws -> Void
    let onContinueWithGoogle: () async throws -> Void
    let skipAction: () -> Void

    @State private var activeProvider: AuthProvider?
    @State private var errorMessage = ""
    @State private var isShowingError = false
    @GestureState private var authOptionsDragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SeriesTheme.onboardingBackground.ignoresSafeArea()

                OnboardingBackdrop()
                    .overlay {
                        LinearGradient(
                            colors: [
                                SeriesTheme.brandBlack.opacity(0.04),
                                SeriesTheme.brandBlack.opacity(authOptionsArePresented ? 0.42 : 0.24),
                                SeriesTheme.brandBlack.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .blur(radius: authOptionsArePresented ? 6 : 0)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.safeAreaInsets.top + 96, authOptionsArePresented ? 128 : 148))

                    FeatureCallout(compact: authOptionsArePresented)

                    Spacer(minLength: authOptionsArePresented ? 24 : 94)

                    if authOptionsArePresented {
                        AuthOptionsPanel(
                            accountIsAvailable: accessController.accountIsAvailable,
                            legalConsentText: legalConsentText,
                            activeProvider: activeProvider,
                            onAppleTap: startAppleSignIn,
                            onGoogleTap: startGoogleSignIn,
                            onSkip: skipAction
                        )
                        .padding(.horizontal, 14)
                        .padding(.bottom, max(12, proxy.safeAreaInsets.bottom))
                        .offset(y: authOptionsDragOffset)
                        .gesture(authOptionsDismissGesture)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        CallToActionSection(
                            accountIsAvailable: accessController.accountIsAvailable,
                            localAction: skipAction,
                            accountAction: {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                    authOptionsArePresented = true
                                }
                            },
                            skipAction: skipAction
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 12))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .top) {
                    BrandHeaderBadge()
                        .padding(.top, proxy.safeAreaInsets.top + 8)
                }
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: authOptionsArePresented)
        .alert(L10n.string("auth.alert.continueFailed.title"), isPresented: $isShowingError) {
            Button(L10n.string("auth.alert.close"), role: .cancel) {
                activeProvider = nil
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func startAppleSignIn() {
        guard accessController.accountIsAvailable else {
            errorMessage = SeriesAVAccountServiceError.unavailable.localizedDescription
            isShowingError = true
            return
        }
        guard activeProvider == nil else { return }
        activeProvider = .apple
        Task {
            do {
                try await onContinueWithApple()
                await MainActor.run {
                    authOptionsArePresented = false
                    activeProvider = nil
                }
            } catch {
                authLogger.error("Apple sign-in failed: \(String(reflecting: error), privacy: .public)")
                guard !error.isAuthenticationCancellation else {
                    await MainActor.run {
                        activeProvider = nil
                    }
                    return
                }
                await MainActor.run {
                    activeProvider = nil
                    errorMessage = error.appleSignInFailureMessage
                    isShowingError = true
                }
            }
        }
    }

    private func startGoogleSignIn() {
        guard accessController.accountIsAvailable else {
            errorMessage = SeriesAVAccountServiceError.unavailable.localizedDescription
            isShowingError = true
            return
        }
        guard activeProvider == nil else { return }
        activeProvider = .google
        Task {
            do {
                try await onContinueWithGoogle()
                await MainActor.run {
                    authOptionsArePresented = false
                    activeProvider = nil
                }
            } catch {
                authLogger.error("Google sign-in failed: \(String(reflecting: error), privacy: .public)")
                guard !error.isAuthenticationCancellation else {
                    await MainActor.run {
                        activeProvider = nil
                    }
                    return
                }
                await MainActor.run {
                    activeProvider = nil
                    errorMessage = error.localizedDescription
                    isShowingError = true
                }
            }
        }
    }

    private var authOptionsDismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($authOptionsDragOffset) { value, state, _ in
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldDismiss =
                    value.translation.height > 120 ||
                    value.predictedEndTranslation.height > 180

                guard shouldDismiss else { return }

                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    authOptionsArePresented = false
                }
            }
    }

    private var legalConsentText: AttributedString {
        let termsURL = AppConfig.termsURL?.absoluteString ?? "https://www.avalsys.com/account-av/series-av/terms"
        let privacyURL = AppConfig.privacyURL?.absoluteString ?? "https://www.avalsys.com/account-av/series-av/privacy"
        return L10n.markdown("auth.legalConsent", termsURL, privacyURL)
    }
}

private enum AuthProvider {
    case apple
    case google
}

private extension Error {
    var appleSignInFailureMessage: String {
        let nsError = self as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.Code.unknown.rawValue {
            return L10n.string("auth.alert.appleUnavailable.detail")
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return underlying.appleSignInFailureMessage
        }

        return localizedDescription
    }

    var isAuthenticationCancellation: Bool {
        let nsError = self as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.Code.canceled.rawValue {
            return true
        }

        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
           nsError.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
            return true
        }

        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled {
            return true
        }

        let description = nsError.localizedDescription.lowercased()
        if description.contains("cancel") || description.contains("cancelad") {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return underlying.isAuthenticationCancellation
        }

        return false
    }
}

private struct FeatureCallout: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 14 : 18) {
            HeroBadge(size: compact ? 104 : 124)

            VStack(spacing: compact ? 10 : 12) {
                Text(L10n.string("auth.feature.title"))
                    .font(.system(size: compact ? 26 : 30, weight: .bold))
                    .foregroundStyle(SeriesTheme.textInverse)
                    .multilineTextAlignment(.center)

                Text(L10n.string("auth.feature.subtitle"))
                    .font(.system(size: compact ? 15 : 16, weight: .medium))
                    .foregroundStyle(SeriesTheme.textInverse.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, compact ? 18 : 14)
                    .frame(maxWidth: 320)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, compact ? 16 : 18)
            .frame(maxWidth: 350)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(SeriesTheme.brandBlack.opacity(0.82))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            )
        }
        .padding(.horizontal, 24)
    }
}

private struct BrandHeaderBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Image("OnboardingWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 174)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Series AV")
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Capsule(style: .continuous)
                .fill(colorScheme == .dark ? SeriesTheme.brandBlack.opacity(0.78) : Color.white.opacity(0.88))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.46), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

private struct HeroBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(SeriesTheme.brandBlack.opacity(0.8))
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.44), radius: 34, y: 22)

            Circle()
                .stroke(SeriesTheme.highlight.opacity(0.22), lineWidth: 1)
                .frame(width: size + 18, height: size + 18)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SeriesTheme.highlight.opacity(0.16),
                            .clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: size / 1.5
                    )
                )
                .frame(width: size * 0.86, height: size * 0.86)

            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: size * 0.58, height: size * 0.58)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }

            Image(systemName: "play.tv.fill")
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            SeriesTheme.highlight
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

private struct CallToActionSection: View {
    let accountIsAvailable: Bool
    let localAction: () -> Void
    let accountAction: () -> Void
    let skipAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: localAction) {
                Text(L10n.string("auth.cta.localMode"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SeriesTheme.brandBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(SeriesTheme.highlight, in: Capsule())
            }

            Text(accountIsAvailable ? L10n.string("auth.cta.subtitle.available") : L10n.string("auth.cta.subtitle.unavailable"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SeriesTheme.textInverse.opacity(0.76))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 28)

            Button(accountIsAvailable ? L10n.string("auth.cta.continue") : L10n.string("auth.cta.skip"), action: accountIsAvailable ? accountAction : skipAction)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(SeriesTheme.textInverse.opacity(0.88))
        }
        .background(alignment: .top) {
            RadialGradient(
                colors: [SeriesTheme.highlight.opacity(0.18), .clear],
                center: .top,
                startRadius: 24,
                endRadius: 220
            )
            .frame(height: 220)
            .offset(y: -18)
        }
    }
}

private struct AuthOptionsPanel: View {
    let accountIsAvailable: Bool
    let legalConsentText: AttributedString
    let activeProvider: AuthProvider?
    let onAppleTap: () -> Void
    let onGoogleTap: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.white.opacity(0.18))
                .frame(width: 46, height: 4)
                .padding(.top, 10)

            Text(L10n.string("auth.options.title"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(SeriesTheme.textInverse)

            HStack(spacing: 18) {
                AuthIconButton(title: "Apple", isLoading: activeProvider == .apple, action: onAppleTap) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.black)
                }

                AuthIconButton(title: "Google", isLoading: activeProvider == .google, action: onGoogleTap) {
                    GoogleBadge()
                }
            }
            .disabled(!accountIsAvailable)

            if !accountIsAvailable {
                Text(L10n.string("auth.options.unavailable"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Text(legalConsentText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.64))
                .tint(.white.opacity(0.82))
                .multilineTextAlignment(.center)

            Button(L10n.string("auth.options.skip"), action: onSkip)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 26)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(SeriesTheme.darkSurfaceAlt.opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        )
    }
}

private struct AuthIconButton<Content: View>: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)

                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        content
                    }
                }

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

private struct GoogleBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)

            Text("G")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                            Color(red: 0.22, green: 0.74, blue: 0.35),
                            Color(red: 0.99, green: 0.84, blue: 0.21),
                            Color(red: 0.92, green: 0.31, blue: 0.23)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: 64, height: 64)
    }
}

private struct OnboardingBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 6 / 255, green: 10 / 255, blue: 8 / 255),
                    Color(red: 16 / 255, green: 21 / 255, blue: 18 / 255),
                    Color(red: 9 / 255, green: 12 / 255, blue: 10 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(SeriesTheme.highlight.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -110, y: -180)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 120, y: -40)

            Circle()
                .fill(SeriesTheme.highlight.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 100, y: 220)
        }
    }
}
