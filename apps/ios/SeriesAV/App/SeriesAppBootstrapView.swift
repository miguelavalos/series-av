import AVLaunchFoundation
import AVProductAccountFoundation
import SwiftUI

struct SeriesAppBootstrapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var accessController = SeriesAccessController()
    @State private var selectedTab: SeriesRootTab
    @State private var authPresentationState: AVProductAccountAuthPresentationState = .hidden
    @State private var authenticationWasSkipped = false
    @State private var automaticGuestOnboardingIsPresented = false
    @State private var initialSplashIsPresented = true
    @State private var initialAccountRestoreCompleted = false
    @State private var postAuthenticationSplashIsPresented = false
    @State private var shareInviteBrowserDestination: SeriesInAppBrowserDestination?

    private let launchContext = SeriesLaunchContext.current
    private var splashPolicy: AVSplashTransitionPolicy {
        AVSplashTransitionPolicy(isDisabled: launchContext.shouldDisableSplash)
    }

    init() {
        _selectedTab = State(initialValue: SeriesLaunchContext.current.initialTab)
    }

    var body: some View {
        Group {
            if shouldShowInitialSplash {
                SeriesAVSplashView()
            } else if shouldShowOnboarding {
                SeriesAuthOnboardingView(
                    authPresentationState: $authPresentationState,
                    accountIsAvailable: accessController.accountIsAvailable,
                    onContinueWithApple: startAppleSignIn,
                    onContinueWithGoogle: startGoogleSignIn,
                    onSkip: skipAuthentication
                )
            } else {
                SeriesAppShellView(
                    selectedTab: $selectedTab,
                    accessController: accessController,
                    startSignInFlow: startSignInFlow
                )
                .id(accessController.isSignedIn ? "signed-in-shell" : "skipped-auth-shell")
                .overlay {
                    if postAuthenticationSplashIsPresented {
                        SeriesAVSplashView()
                            .transition(.opacity)
                            .zIndex(2)
                    }
                }
            }
        }
        .task {
            await restoreInitialAccountSessionIfNeeded()
            await completeInitialSplashIfNeeded()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await accessController.syncFromAccountProvider()
            initialAccountRestoreCompleted = true
            markAutomaticGuestOnboardingSeenIfNeeded()
        }
        .onChange(of: accessController.accessMode) { _, accessMode in
            if accessMode != .guest {
                automaticGuestOnboardingIsPresented = false
                authPresentationState = .hidden
            }
        }
        .onOpenURL { url in
            openShareInviteIfNeeded(url)
        }
        .sheet(item: $shareInviteBrowserDestination) { destination in
            SeriesInAppBrowserView(url: destination.url)
        }
    }

    private var shouldShowOnboarding: Bool {
        if SeriesUITestEnvironment.current.shouldForceGuestOnboarding {
            return authPresentationState != .hidden || automaticGuestOnboardingIsPresented
        }
        guard !authenticationWasSkipped else { return false }
        let rootGate = AVProductAccountAuthFlowRootGate(
            accountState: accessController.productAccountState,
            authPresentationState: authPresentationState
        )
        if authPresentationState.isPresented {
            return rootGate.shouldShowOnboarding
        }
        guard !launchContext.shouldDisableOnboarding else { return false }
        return rootGate.shouldShowOnboarding || automaticGuestOnboardingIsPresented
    }

    private var shouldShowInitialSplash: Bool {
        initialSplashIsPresented && !launchContext.shouldDisableSplash
    }

    private func completeInitialSplashIfNeeded() async {
        guard initialSplashIsPresented else { return }
        if !launchContext.shouldDisableSplash {
            try? await Task.sleep(for: splashPolicy.displayDuration)
        }
        await MainActor.run {
            withAnimation(splashPolicy.dismissAnimation) {
                initialSplashIsPresented = false
                showInitialOnboardingAfterSplashIfNeeded()
            }
        }
    }

    private func restoreInitialAccountSessionIfNeeded() async {
        guard !initialAccountRestoreCompleted else { return }
        await accessController.syncFromAccountProvider()
        initialAccountRestoreCompleted = true
    }

    private func showInitialOnboardingAfterSplashIfNeeded() {
        if SeriesUITestEnvironment.current.shouldForceGuestOnboarding {
            forceGuestOnboardingForUITestsIfNeeded()
            return
        }
        guard initialAccountRestoreCompleted else { return }
        guard !launchContext.shouldDisableOnboarding else { return }
        guard !accessController.isSignedIn else { return }
        guard !authenticationWasSkipped else { return }
        guard accessController.shouldAutoShowGuestOnboarding else { return }
        guard authPresentationState == .hidden else { return }
        markAutomaticGuestOnboardingSeenIfNeeded()
    }

    private func markAutomaticGuestOnboardingSeenIfNeeded() {
        if SeriesUITestEnvironment.current.shouldForceGuestOnboarding {
            forceGuestOnboardingForUITestsIfNeeded()
            return
        }
        guard !launchContext.shouldDisableOnboarding else { return }
        guard !accessController.isSignedIn else { return }
        guard !authenticationWasSkipped else { return }
        guard accessController.shouldAutoShowGuestOnboarding else { return }
        guard authPresentationState == .hidden else { return }

        automaticGuestOnboardingIsPresented = true
        authPresentationState = .onboardingCollapsed
        accessController.markGuestOnboardingPromptShown()
    }

    private func forceGuestOnboardingForUITestsIfNeeded() {
        guard !authenticationWasSkipped else { return }
        guard authPresentationState == .hidden else { return }
        automaticGuestOnboardingIsPresented = true
        authPresentationState = SeriesUITestEnvironment.current.shouldShowExpandedOnboardingAuthOptions
            ? .onboardingOptions
            : .onboardingCollapsed
    }

    private func skipAuthentication() {
        authPresentationState = .hidden
        automaticGuestOnboardingIsPresented = false
        postAuthenticationSplashIsPresented = true
        authenticationWasSkipped = true
        accessController.skipForNow()
        Task {
            try? await Task.sleep(for: splashPolicy.displayDuration)
            await MainActor.run {
                withAnimation(splashPolicy.dismissAnimation) {
                    postAuthenticationSplashIsPresented = false
                }
            }
        }
    }

    private func startSignInFlow() {
        postAuthenticationSplashIsPresented = false
        authenticationWasSkipped = false
        automaticGuestOnboardingIsPresented = false
        authPresentationState = .onboardingOptions
    }

    private func startAppleSignIn() async throws {
        try await accessController.signInWithApple()
        authenticationWasSkipped = false
        automaticGuestOnboardingIsPresented = false
        authPresentationState = .hidden
    }

    private func startGoogleSignIn() async throws {
        try await accessController.signInWithGoogle()
        authenticationWasSkipped = false
        automaticGuestOnboardingIsPresented = false
        authPresentationState = .hidden
    }

    private func openShareInviteIfNeeded(_ url: URL) {
        guard let deepLink = SeriesShareInviteDeepLink(url: url) else { return }
        shareInviteBrowserDestination = SeriesInAppBrowserDestination(url: deepLink.webURL())
    }
}
