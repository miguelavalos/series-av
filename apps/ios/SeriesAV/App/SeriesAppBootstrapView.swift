import AVProductAccountFoundation
import SwiftUI

struct SeriesAppBootstrapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var accessController = SeriesAccessController()
    @State private var authPresentationState: AVProductAccountAuthPresentationState = .hidden
    @State private var authenticationWasSkipped = false
    @State private var initialAccountRestoreCompleted = false

    var body: some View {
        Group {
            if shouldShowOnboarding {
                SeriesAuthOnboardingView(
                    authPresentationState: $authPresentationState,
                    accountIsAvailable: accessController.accountIsAvailable,
                    onContinueWithApple: startAppleSignIn,
                    onContinueWithGoogle: startGoogleSignIn,
                    onSkip: skipAuthentication
                )
            } else {
                RootView(accessController: accessController, startSignInFlow: startSignInFlow)
            }
        }
        .task {
            await restoreInitialAccountSessionIfNeeded()
            showInitialOnboardingIfNeeded()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await accessController.syncFromAccountProvider()
            initialAccountRestoreCompleted = true
            showInitialOnboardingIfNeeded()
        }
    }

    private var shouldShowOnboarding: Bool {
        guard !authenticationWasSkipped else { return false }
        let rootGate = AVProductAccountAuthFlowRootGate(
            accountState: accessController.productAccountState,
            authPresentationState: authPresentationState
        )
        return rootGate.shouldShowOnboarding
    }

    private func restoreInitialAccountSessionIfNeeded() async {
        guard !initialAccountRestoreCompleted else { return }
        await accessController.syncFromAccountProvider()
        initialAccountRestoreCompleted = true
    }

    private func showInitialOnboardingIfNeeded() {
        guard initialAccountRestoreCompleted else { return }
        guard !accessController.isSignedIn else { return }
        guard !authenticationWasSkipped else { return }
        guard authPresentationState == .hidden else { return }
        authPresentationState = .onboardingCollapsed
    }

    private func skipAuthentication() {
        authPresentationState = .hidden
        authenticationWasSkipped = true
    }

    private func startSignInFlow() {
        authenticationWasSkipped = false
        authPresentationState = .onboardingOptions
    }

    private func startAppleSignIn() async throws {
        try await accessController.signInWithApple()
        authenticationWasSkipped = false
        authPresentationState = .hidden
    }

    private func startGoogleSignIn() async throws {
        try await accessController.signInWithGoogle()
        authenticationWasSkipped = false
        authPresentationState = .hidden
    }
}
