import AVAppShellFoundation
import AVBrandFoundation
import AVExternalLinkFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesProfileScreen: View {
    let mode: AVAppShellChromeItem
    @Bindable var store: SeriesLibraryStore
    @Bindable var librarySync: SeriesLibrarySyncCoordinator
    let openSettings: () -> Void
    let openAccount: () -> Void
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void
    let synchronizeLibraryNow: () async -> Void
    let keepDeviceLibraryNow: () async -> Void

    @EnvironmentObject private var languageController: AppLanguageController
    @EnvironmentObject private var themeController: AppThemeController
    @EnvironmentObject private var externalLinkPreferences: AppExternalLinkPreferencesController
    @Environment(\.avCommonAppExperience) private var appExperience
    @Environment(\.openURL) private var openURL
    @State private var isSigningOut = false
    @State private var signOutErrorMessage = ""
    @State private var isShowingSignOutError = false
    @State private var isShowingProPaywall = false
    @State private var isShowingAccountDeletion = false
    @State private var isShowingLocalDataActions = false

    var body: some View {
        AVSettingsProfileScreenScaffold(
            title: screenTitle,
            subtitle: screenSubtitle,
            backgroundStyle: AnyShapeStyle(AVBrandSurface.shellBackground),
            showsTopSafeAreaShield: true
        ) {
            AVAppShellConfiguredBrandHeader(
                activeItem: mode,
                openSettings: openSettings,
                openAccount: openAccount
            )
        } content: {
            switch mode {
            case .settings:
                settingsContent
            case .account:
                accountContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert(L10n.string("profile.alert.signOutFailed.title"), isPresented: $isShowingSignOutError) {
            Button(L10n.string("common.close"), role: .cancel) {}
        } message: {
            Text(signOutErrorMessage)
        }
        .sheet(isPresented: $isShowingProPaywall) {
            SeriesProPaywallView(
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        }
        .sheet(isPresented: $isShowingAccountDeletion) {
            SeriesAccountDeletionScreen(viewModel: accountDeletionViewModel)
        }
        .sheet(isPresented: $isShowingLocalDataActions) {
            SeriesLocalDataMaintenanceSheet(
                seriesCount: store.entries.count,
                clearLocalData: {
                    store.deleteAllLocalData()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
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

    @ViewBuilder
    private var settingsContent: some View {
        appPreferencesCard
        seriesPreferencesCard
        onThisDeviceCard
        helpAndLegalCard
    }

    @ViewBuilder
    private var accountContent: some View {
        accountCard
        proCard
        if accessController.capabilities.canUseCloudSync {
            cloudSyncCard
        }
        if accessController.isSignedIn {
            accountSafetyCard
        }
    }

    private var appPreferencesCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.preferences.title"),
            subtitle: L10n.string("profile.preferences.subtitle")
        ) {
            AVSettingsInfoRow(
                systemImage: "globe",
                title: L10n.string("profile.preferences.language.title"),
                detail: L10n.string("profile.preferences.language.detail")
            )

            languageSelector

            AVSettingsInfoRow(
                systemImage: "circle.lefthalf.filled",
                title: L10n.string("profile.preferences.theme.title"),
                detail: L10n.string("profile.preferences.theme.detail")
            )

            themeSelector
        }
    }

    private var seriesPreferencesCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.series.title"),
            subtitle: L10n.string("profile.series.subtitle")
        ) {
            AVSettingsInfoRow(
                systemImage: "checklist",
                title: L10n.string("profile.series.cursor.title"),
                detail: L10n.string("profile.series.cursor.detail")
            )
            AVSettingsInfoRow(
                systemImage: "arrow.uturn.backward.circle",
                title: L10n.string("profile.series.reversible.title"),
                detail: L10n.string("profile.series.reversible.detail")
            )

            Divider()
                .overlay(AVBrandColor.borderSubtle)

            AVSettingsInfoRow(
                systemImage: "safari",
                title: L10n.string("profile.preferences.webOpenMode.title"),
                detail: L10n.string("profile.preferences.webOpenMode.detail")
            )

            webOpenModeSelector

            AVSettingsInfoRow(
                systemImage: "magnifyingglass",
                title: L10n.string("profile.preferences.searchEngine.title"),
                detail: L10n.string("profile.preferences.searchEngine.detail")
            )

            searchEngineSelector
        }
    }

    private var onThisDeviceCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.local.title"),
            subtitle: L10n.string("profile.local.subtitle")
        ) {
            AVSettingsInfoRow(
                systemImage: "iphone",
                title: L10n.string("profile.local.library.title"),
                detail: L10n.string("profile.local.library.detail")
            )
            AVSettingsInfoRow(
                systemImage: "internaldrive",
                title: L10n.string("profile.local.sync.title"),
                detail: L10n.string("profile.local.sync.detail")
            )
            AVSettingsButton(
                title: L10n.string("profile.actions.manageLocalData"),
                style: .destructive,
                action: { isShowingLocalDataActions = true }
            )
            .disabled(store.entries.isEmpty)
            .accessibilityIdentifier("profile.local.manage")
        }
    }

    private var helpAndLegalCard: some View {
        AVSettingsHelpLegalSection(
            title: L10n.string("profile.help.title"),
            subtitle: L10n.string("profile.help.subtitle"),
            openSourceTitle: L10n.string("profile.help.opensource.title"),
            openSourceDetail: L10n.string("profile.help.opensource.detail"),
            sourceCodeURL: AppConfig.openSourceURL,
            sourceCodeTitle: L10n.string("profile.help.sourceCode.title"),
            sourceCodeDetail: L10n.string("profile.help.sourceCode.detail"),
            legalLinks: settingsLegalLinks,
            supportTitle: L10n.string("profile.help.support.title"),
            supportDetail: L10n.string("profile.help.support.detail"),
            privacyTitle: L10n.string("profile.help.privacy.title"),
            privacyDetail: L10n.string("profile.help.privacy.detail"),
            termsTitle: L10n.string("profile.help.terms.title"),
            termsDetail: L10n.string("profile.help.terms.detail"),
            accountDeletionTitle: L10n.string("profile.safety.delete.title"),
            accountDeletionDetail: L10n.string("profile.safety.delete.detail"),
            openURL: { url in openURL(url) }
        )
    }

    private var accountCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.account.title"),
            subtitle: accountIdentityDetail
        ) {
            Divider()
                .overlay(AVBrandColor.borderSubtle)

            VStack(alignment: .leading, spacing: 12) {
                AVSettingsInfoRow(
                    systemImage: "person.crop.circle",
                    title: L10n.string("profile.summary.account.title"),
                    detail: sessionDetail
                )
                if accessController.isSignedIn, let emailAddress = accessController.accountUser?.emailAddress {
                    AVSettingsInfoRow(
                        systemImage: "envelope",
                        title: L10n.string("profile.account.email.title"),
                        detail: emailAddress
                    )
                }
                AVSettingsInfoRow(
                    systemImage: "sparkles.rectangle.stack",
                    title: L10n.string("profile.summary.plan.title"),
                    detail: accessDetail
                )
            }

            accountActionButton
        }
    }

    private var cloudSyncCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.sync.title"),
            subtitle: L10n.string("profile.sync.subtitle")
        ) {
            AVSettingsInfoRow(
                systemImage: cloudSyncIcon,
                title: cloudSyncHeadline,
                detail: cloudSyncDetail
            )
            .accessibilityIdentifier("profile.sync.status")

            AVSettingsButton(
                title: cloudSyncActionTitle,
                style: .secondary,
                isLoading: librarySync.state == .syncing,
                action: {
                    Task {
                        await synchronizeLibraryNow()
                    }
                }
            )
            .disabled(librarySync.state == .syncing)
            .accessibilityIdentifier("profile.sync.retry")

            if librarySync.state == .conflict {
                AVSettingsButton(
                    title: L10n.string("profile.sync.keepDevice"),
                    style: .secondary,
                    action: {
                        Task {
                            await keepDeviceLibraryNow()
                        }
                    }
                )
                .accessibilityIdentifier("profile.sync.keepDevice")
            }
        }
        .accessibilityIdentifier("profile.sync.card")
    }

    private var proCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.pro.title"),
            subtitle: proSubtitle
        ) {
            AVSettingsInfoRow(
                systemImage: "checkmark.seal.fill",
                title: L10n.string("profile.pro.account.title"),
                detail: L10n.string("profile.pro.account.detail")
            )
            AVSettingsInfoRow(
                systemImage: "rectangle.stack.badge.person.crop",
                title: L10n.string("profile.pro.library.title"),
                detail: L10n.string("profile.pro.library.detail")
            )
            AVSettingsInfoRow(
                systemImage: "sparkles",
                title: L10n.string("profile.pro.avi.title"),
                detail: L10n.string("profile.pro.avi.detail")
            )
            proActionButton
        }
    }

    @ViewBuilder
    private var proActionButton: some View {
        switch accessController.accessMode {
        case .guest:
            AVSettingsButton(
                title: L10n.string("profile.pro.signIn"),
                style: .primary,
                action: {
                    startSignInFlow()
                }
            )
            .disabled(!accessController.accountIsAvailable)
            .accessibilityIdentifier("profile.pro.signIn")
        case .signedInFree:
            AVSettingsButton(
                title: L10n.string("profile.pro.upgrade"),
                style: .primary,
                action: { isShowingProPaywall = true }
            )
            .accessibilityIdentifier("profile.pro.upgrade")
        case .signedInPro:
            VStack(alignment: .leading, spacing: 12) {
                AVSettingsInfoRow(
                    systemImage: "checkmark.seal",
                    title: L10n.string("profile.pro.active.title"),
                    detail: L10n.string("profile.pro.active.detail")
                )

                AVSettingsButton(
                    title: L10n.string("profile.pro.manage"),
                    style: .secondary,
                    action: openAppleSubscriptionManagement
                )
                .accessibilityIdentifier("profile.pro.manage")
            }
        }
    }

    private var accountSafetyCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.safety.title"),
            subtitle: L10n.string("profile.safety.subtitle"),
            spacing: 12
        ) {
            AVSettingsActionRow(
                systemImage: "exclamationmark.shield",
                title: L10n.string("profile.safety.delete.title"),
                detail: L10n.string("profile.safety.delete.detail"),
                action: { isShowingAccountDeletion = true }
            )
            .accessibilityIdentifier("profile.safety.delete")
        }
    }

    @ViewBuilder
    private var accountActionButton: some View {
        if accessController.isSignedIn {
            AVSettingsButton(
                title: isSigningOut ? L10n.string("profile.actions.signingOut") : L10n.string("profile.actions.signOut"),
                style: .secondary,
                isLoading: isSigningOut,
                action: signOut
            )
            .disabled(isSigningOut)
            .accessibilityIdentifier("profile.account.signOut")
        } else {
            AVSettingsButton(
                title: accessController.accountIsAvailable
                    ? L10n.string("profile.account.connect")
                    : L10n.string("profile.account.connectUnavailable"),
                style: .primary,
                action: {
                    startSignInFlow()
                }
            )
            .disabled(!accessController.accountIsAvailable)
            .accessibilityIdentifier("profile.account.signIn")
        }
    }

    private var languageSelector: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    languageController.select(language)
                } label: {
                    if languageController.currentLanguage == language {
                        Label {
                            Text("\(language.displayName) (\(language.autonym))")
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text("\(language.displayName) (\(language.autonym))")
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(languageController.currentLanguage.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AVBrandColor.textPrimary)

                    Text(languageController.currentLanguage.autonym)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AVBrandColor.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AVBrandColor.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AVBrandColor.mutedSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AVBrandColor.borderSubtle, lineWidth: 1)
            }
        }
    }

    private var themeSelector: some View {
        HStack(spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
                AVSettingsOptionButton(
                    title: themeLabel(for: theme),
                    systemImage: themeSymbol(for: theme),
                    isSelected: themeController.currentTheme == theme,
                    action: { themeController.select(theme) }
                )
            }
        }
    }

    private var searchEngineSelector: some View {
        Menu {
            ForEach(AVExternalSearchEngine.allCases) { engine in
                Button {
                    externalLinkPreferences.selectSearchEngine(engine)
                } label: {
                    if externalLinkPreferences.searchEngine == engine {
                        Label {
                            Text(searchEngineLabel(for: engine))
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(searchEngineLabel(for: engine))
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AVBrandColor.accent)

                Text(searchEngineLabel(for: externalLinkPreferences.searchEngine))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AVBrandColor.textPrimary)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AVBrandColor.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AVBrandColor.mutedSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AVBrandColor.borderSubtle, lineWidth: 1)
            }
        }
    }

    private var webOpenModeSelector: some View {
        HStack(spacing: 10) {
            ForEach(AVExternalWebOpenMode.allCases) { mode in
                AVSettingsOptionButton(
                    title: webOpenModeLabel(for: mode),
                    systemImage: webOpenModeSymbol(for: mode),
                    isSelected: externalLinkPreferences.webOpenMode == mode,
                    action: { externalLinkPreferences.selectWebOpenMode(mode) }
                )
            }
        }
    }

    private var accountIdentityDetail: String {
        if accessController.isSignedIn {
            return accessController.accountUser?.emailAddress
                ?? accessController.accountUser?.id
                ?? L10n.string("profile.account.connected", appExperience.identity.accountName)
        }
        return L10n.string("profile.account.identity.guest")
    }

    private var sessionDetail: String {
        if accessController.isSignedIn {
            return accessController.accountUser?.displayName
                ?? accessController.accountUser?.emailAddress
                ?? L10n.string("profile.summary.account.detail.signedIn")
        }
        return L10n.string("profile.summary.account.detail.guest")
    }

    private var accessDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.summary.plan.detail.guest")
        case .signedInFree:
            L10n.string("profile.summary.plan.detail.free")
        case .signedInPro:
            L10n.string("profile.summary.plan.detail.pro")
        }
    }

    private var cloudSyncHeadline: String {
        switch librarySync.state {
        case .disabled:
            L10n.string("profile.sync.headline.disabled")
        case .idle:
            L10n.string("profile.sync.headline.synced")
        case .syncing:
            L10n.string("profile.sync.headline.syncing")
        case .conflict:
            L10n.string("profile.sync.headline.conflict")
        case .failed:
            L10n.string("profile.sync.headline.failed")
        }
    }

    private var cloudSyncDetail: String {
        switch librarySync.state {
        case .disabled:
            L10n.string("profile.sync.detail.disabled")
        case .idle:
            L10n.string("profile.sync.detail.synced")
        case .syncing:
            L10n.string("profile.sync.detail.syncing")
        case .conflict:
            L10n.string("profile.sync.detail.conflict")
        case .failed:
            L10n.string("profile.sync.detail.failed")
        }
    }

    private var cloudSyncActionTitle: String {
        switch librarySync.state {
        case .syncing:
            L10n.string("profile.sync.retry.syncing")
        case .conflict:
            L10n.string("profile.sync.refresh")
        case .disabled, .idle, .failed:
            L10n.string("profile.sync.retry")
        }
    }

    private var cloudSyncIcon: String {
        switch librarySync.state {
        case .disabled:
            "icloud.slash"
        case .idle:
            "checkmark.icloud"
        case .syncing:
            "arrow.triangle.2.circlepath.icloud"
        case .conflict:
            "exclamationmark.icloud"
        case .failed:
            "xmark.icloud"
        }
    }

    private var proSubtitle: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.pro.subtitle.guest")
        case .signedInFree:
            L10n.string("profile.pro.subtitle.free")
        case .signedInPro:
            L10n.string("profile.pro.subtitle.pro")
        }
    }

    private var settingsLegalLinks: AVAppLegalLinks {
        AVAppLegalLinks(
            supportURL: appExperience.legalLinks.supportURL,
            privacyURL: appExperience.legalLinks.privacyURL,
            termsURL: appExperience.legalLinks.termsURL,
            accountDeletionURL: appExperience.legalLinks.accountDeletionURL
        )
    }

    private func themeLabel(for theme: AppTheme) -> String {
        switch theme {
        case .system: L10n.string("profile.preferences.theme.system")
        case .light: L10n.string("profile.preferences.theme.light")
        case .dark: L10n.string("profile.preferences.theme.dark")
        }
    }

    private func themeSymbol(for theme: AppTheme) -> String {
        switch theme {
        case .system: "iphone"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    private func searchEngineLabel(for engine: AVExternalSearchEngine) -> String {
        switch engine {
        case .google: L10n.string("profile.preferences.searchEngine.google")
        case .duckDuckGo: L10n.string("profile.preferences.searchEngine.duckduckgo")
        case .bing: L10n.string("profile.preferences.searchEngine.bing")
        case .yahoo: L10n.string("profile.preferences.searchEngine.yahoo")
        case .yandex: L10n.string("profile.preferences.searchEngine.yandex")
        case .baidu: L10n.string("profile.preferences.searchEngine.baidu")
        case .brave: L10n.string("profile.preferences.searchEngine.brave")
        case .ecosia: L10n.string("profile.preferences.searchEngine.ecosia")
        case .startpage: L10n.string("profile.preferences.searchEngine.startpage")
        case .qwant: L10n.string("profile.preferences.searchEngine.qwant")
        }
    }

    private func webOpenModeLabel(for mode: AVExternalWebOpenMode) -> String {
        switch mode {
        case .inApp: L10n.string("profile.preferences.webOpenMode.inApp")
        case .system: L10n.string("profile.preferences.webOpenMode.system")
        }
    }

    private func webOpenModeSymbol(for mode: AVExternalWebOpenMode) -> String {
        switch mode {
        case .inApp: "app"
        case .system: "safari"
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

private struct SeriesLocalDataMaintenanceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let seriesCount: Int
    let clearLocalData: () -> Void

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        AVSettingsSheetScaffold(
            backgroundStyle: AnyShapeStyle(AVBrandSurface.shellBackground),
            closeTitle: L10n.string("common.cancel"),
            onClose: { dismiss() }
        ) {
            AVSettingsSheetHeader(
                title: L10n.string("profile.localDataSheet.title"),
                subtitle: L10n.string("profile.localDataSheet.subtitle")
            )

            AVSettingsDestructiveActionCard(
                sectionTitle: L10n.string("profile.localDataSheet.dangerTitle"),
                systemImage: "trash",
                title: L10n.string("profile.local.delete.title"),
                detail: localDeleteDetail,
                action: { isShowingDeleteConfirmation = true }
            )
            .accessibilityIdentifier("profile.local.delete")
        }
        .alert(L10n.string("profile.local.delete.confirm.title"), isPresented: $isShowingDeleteConfirmation) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("profile.local.delete.confirm.action"), role: .destructive) {
                clearLocalData()
                dismiss()
            }
        } message: {
            Text(L10n.string("profile.local.delete.confirm.detail"))
        }
    }

    private var localDeleteDetail: String {
        guard seriesCount > 0 else {
            return L10n.string("profile.local.delete.empty")
        }
        return L10n.string("profile.local.delete.detail", seriesCount)
    }
}
