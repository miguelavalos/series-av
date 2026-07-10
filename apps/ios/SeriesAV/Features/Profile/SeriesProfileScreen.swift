import AVAppShellFoundation
import AVBrandFoundation
import AVExternalLinkFoundation
import AVSettingsFoundation
import SwiftUI
import UIKit

struct SeriesProfileScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let mode: AVAppShellChromeItem
    @Bindable var store: SeriesLibraryStore
    @Bindable var librarySync: SeriesLibrarySyncCoordinator
    let openSettings: () -> Void
    let openAccount: () -> Void
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void
    let synchronizeLibraryNow: () async -> Void
    let keepDeviceLibraryNow: () async -> Void

    @EnvironmentObject private var externalLinkPreferences: AppExternalLinkPreferencesController
    @Environment(\.avCommonAppExperience) private var appExperience
    @Environment(\.avBrandPalette) private var brandPalette
    @Environment(\.openURL) private var openURL
    @State private var isSigningOut = false
    @State private var signOutErrorMessage = ""
    @State private var isShowingSignOutError = false
    @State private var sheetDestination: SeriesProfileSheetDestination? = {
        let environment = SeriesUITestEnvironment.current
        if let url = environment.initialInAppBrowserURL {
            return .inAppBrowser(url)
        }
        if environment.shouldShowLocalDataMaintenanceSheet {
            return .localDataMaintenance
        }
        return nil
    }()

    var body: some View {
        AVSettingsProfileScreenScaffold(
            title: screenTitle,
            subtitle: screenSubtitle,
            backgroundStyle: AnyShapeStyle(AVBrandSurface.shellBackground),
            showsTopSafeAreaShield: true,
            showsChrome: !isTabletLayout
        ) {
            compactBrandHeader
        } content: {
            switch mode {
            case .settings:
                SeriesSettingsContent(
                    hasLocalData: !store.entries.isEmpty,
                    manageLocalData: { sheetDestination = .localDataMaintenance },
                    openExternalLink: openExternalLink
                )
            case .account:
                SeriesAccountContent(
                    accessController: accessController,
                    librarySync: librarySync,
                    isTabletLayout: isTabletLayout,
                    isSigningOut: isSigningOut,
                    startSignInFlow: startSignInFlow,
                    signOut: signOut,
                    synchronizeLibraryNow: synchronizeLibraryNow,
                    keepDeviceLibraryNow: keepDeviceLibraryNow,
                    showProPaywall: { sheetDestination = .proPaywall },
                    showAccountDeletion: { sheetDestination = .accountDeletion },
                    openSubscriptionManagement: openAppleSubscriptionManagement
                )
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .toolbar(.hidden, for: .navigationBar)
        .alert(L10n.string("profile.alert.signOutFailed.title"), isPresented: $isShowingSignOutError) {
            Button(L10n.string("common.close"), role: .cancel) {}
        } message: {
            Text(signOutErrorMessage)
        }
        .sheet(item: $sheetDestination) { destination in
            profileSheet(for: destination)
        }
    }

    private var isTabletLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact
    }

    private var compactBrandHeader: some View {
        AVAppShellBrandHeaderScaffold(
            spacing: 8,
            sideSpacerMinLength: 4,
            logoWidth: 132,
            logoHeight: 42
        ) {
            compactHeaderButton(
                systemName: "gearshape.fill",
                accessibilityLabel: L10n.string("profile.settingsScreen.title"),
                accessibilityIdentifier: "header.settings",
                isSelected: mode == .settings,
                fontSize: 15,
                action: openSettings
            )
        } logo: {
            Image(appExperience.visualAssets?.headerLogoName ?? "HeaderWordmark")
                .resizable()
                .scaledToFit()
                .accessibilityLabel(appExperience.identity.displayName)
        } trailing: {
            compactHeaderButton(
                systemName: "person.crop.circle.fill",
                accessibilityLabel: L10n.string("profile.accountScreen.title"),
                accessibilityIdentifier: "header.account",
                isSelected: mode == .account,
                fontSize: 16,
                action: openAccount
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.compactBrandHeader")
        .padding(.bottom, -8)
    }

    private func compactHeaderButton(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        isSelected: Bool,
        fontSize: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(isSelected ? brandPalette.accent : AVBrandColor.textPrimary)
                .frame(width: 36, height: 36)
                .background(isSelected ? AVBrandColor.footerGlassSelected : AVBrandColor.elevatedSurface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            isSelected ? brandPalette.accent.opacity(0.28) : AVBrandColor.borderSubtle.opacity(0.52),
                            lineWidth: 1
                        )
                }
                .shadow(color: brandPalette.accent.opacity(isSelected ? 0.12 : 0), radius: 8, y: 3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var screenTitle: String {
        switch mode {
        case .settings:
            L10n.string("profile.settingsScreen.title")
        case .account:
            L10n.string("profile.accountScreen.title")
        }
    }

    private var screenSubtitle: String {
        switch mode {
        case .settings:
            L10n.string("profile.settingsScreen.subtitle")
        case .account:
            L10n.string("profile.accountScreen.subtitle")
        }
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task { @MainActor in
            do {
                try await accessController.signOut()
                isSigningOut = false
            } catch {
                signOutErrorMessage = error.localizedDescription
                isShowingSignOutError = true
                isSigningOut = false
            }
        }
    }

    private func openAppleSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }

    private func openExternalLink(_ url: URL) {
        let scheme = url.scheme?.lowercased()
        guard scheme == "http" || scheme == "https" else {
            openURL(url)
            return
        }

        switch externalLinkPreferences.webOpenMode {
        case .inApp:
            sheetDestination = .inAppBrowser(url)
        case .system:
            openURL(url)
        }
    }

    @ViewBuilder
    private func profileSheet(for destination: SeriesProfileSheetDestination) -> some View {
        switch destination {
        case .proPaywall:
            SeriesProPaywallView(
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        case .accountDeletion:
            SeriesAccountDeletionScreen(viewModel: accountDeletionViewModel)
        case .localDataMaintenance:
            SeriesLocalDataMaintenanceSheet(
                seriesCount: store.entries.count,
                clearLocalData: store.deleteAllLocalData
            )
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium])
            .presentationDragIndicator(.visible)
        case .inAppBrowser(let url):
            SeriesInAppBrowserView(url: url)
                .ignoresSafeArea()
        }
    }

    private var accountDeletionViewModel: SeriesAccountDeletionViewModel {
        SeriesAccountDeletionViewModel(
            api: accountDeletionAPI,
            signOut: { try await accessController.signOut() }
        )
    }

    private var accountDeletionAPI: AccountDeletionAPI {
        if let uiTestAPI = SeriesUITestAccountDeletionAPI.fromEnvironment() {
            return uiTestAPI
        }
        let accountService = DefaultSeriesAVAccountService()
        return SeriesAccountAccessClient(apiClient: SeriesAVAPIClient(
            baseURL: AppConfig.apiBaseURL,
            tokenProvider: { try await accountService.getToken() }
        ))
    }
}
