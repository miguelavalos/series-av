import SwiftUI

struct RootView: View {
    @EnvironmentObject private var accessController: AccessController
    @EnvironmentObject private var libraryStore: SeriesLibraryStore
    @EnvironmentObject private var socialStore: SeriesSocialStore
    @EnvironmentObject private var themeController: AppThemeController
    @EnvironmentObject private var languageController: AppLanguageController

    @State private var isShowingSplash = true
    @State private var isShowingOnboarding = false
    @State private var authOptionsArePresented = false
    @State private var shellID = UUID()
    @State private var cloudService: SeriesAVCloudService?

    private var isUITestMode: Bool {
        ProcessInfo.processInfo.environment["SERIESAV_UI_TESTS"] == "1"
    }

    var body: some View {
        AppShellView(
            startSignInFlow: startSignInFlow,
            cloudService: cloudService
        )
            .id(shellID)
            .preferredColorScheme(themeController.currentTheme.preferredColorScheme)
            .id(languageController.currentLanguage.hashValue ^ shellID.hashValue)
            .overlay {
                if isShowingSplash {
                    SeriesAVSplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                OnboardingView(
                    authOptionsArePresented: $authOptionsArePresented,
                    onContinueWithApple: startAppleSignIn,
                    onContinueWithGoogle: startGoogleSignIn
                ) {
                    continueAsGuest()
                }
                .environmentObject(accessController)
            }
            .task {
                async let initialExperience: Void = showInitialExperience()
                await accessController.refresh()
                Task {
                    await configureServices()
                }
                await initialExperience
            }
            .onChange(of: accessController.accessMode) { _, _ in
                Task {
                    await configureServices()
                }
            }
    }

    private func showInitialExperience() async {
        if isUITestMode {
            isShowingSplash = false
            isShowingOnboarding = false
            accessController.markGuestPromptShown()
            return
        }

        try? await Task.sleep(for: .milliseconds(1100))
        withAnimation(.easeOut(duration: 0.35)) {
            isShowingSplash = false
        }
        if accessController.accessMode == .guest, accessController.shouldAutoShowGuestOnboarding {
            accessController.markGuestPromptShown()
            authOptionsArePresented = false
            isShowingOnboarding = true
        }
    }

    private func continueAsGuest() {
        accessController.markGuestPromptShown()
        authOptionsArePresented = false
        isShowingSplash = true
        shellID = UUID()
        isShowingOnboarding = false

        Task {
            try? await Task.sleep(for: .milliseconds(1150))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) {
                    isShowingSplash = false
                }
            }
        }
    }

    private func startSignInFlow(showAuthOptions: Bool = false) {
        authOptionsArePresented = showAuthOptions
        isShowingOnboarding = true
    }

    private func startAppleSignIn() async throws {
        try await accessController.signInWithApple()
        shellID = UUID()
        isShowingOnboarding = false
    }

    private func startGoogleSignIn() async throws {
        try await accessController.signInWithGoogle()
        shellID = UUID()
        isShowingOnboarding = false
    }

    private func configureServices() async {
        if accessController.capabilities.canUseCloudSync {
            let syncService = SeriesAVAppDataService(getToken: { try await accessController.accountService.getToken() })
            libraryStore.setCloudSyncService(syncService.isConfigured() ? syncService : nil)
            await libraryStore.refreshCloudLibraryIfNeeded()
        } else {
            libraryStore.setCloudSyncService(nil)
        }

        if accessController.capabilities.canUsePremiumFeatures {
            let cloudService = SeriesAVCloudService(getToken: { try await accessController.accountService.getToken() })
            self.cloudService = cloudService.isConfigured() ? cloudService : nil
            socialStore.setCloudService(cloudService.isConfigured() ? cloudService : nil)
            await socialStore.refresh()
        } else {
            cloudService = nil
            socialStore.setCloudService(nil)
        }
    }
}
