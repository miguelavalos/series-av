import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesProfileScreen: View {
    enum Mode {
        case settings
        case account
    }

    let mode: Mode
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    @EnvironmentObject private var languageController: AppLanguageController
    @EnvironmentObject private var themeController: AppThemeController
    @Environment(\.avCommonAppExperience) private var appExperience
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isSigningOut = false
    @State private var signOutErrorMessage = ""
    @State private var isShowingSignOutError = false
    @State private var isShowingProPaywall = false

    var body: some View {
        NavigationStack {
            AVSettingsProfileScreenScaffold(
                title: screenTitle,
                subtitle: screenSubtitle,
                backgroundStyle: AnyShapeStyle(AVBrandColor.neutral50),
                showsTopSafeAreaShield: true
            ) {
                EmptyView()
            } content: {
                switch mode {
                case .settings:
                    settingsContent
                case .account:
                    accountContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.close")) {
                        dismiss()
                    }
                }
            }
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
        if accessController.isSignedIn {
            accountSafetyCard
        }
        appPreferencesCard
        seriesPreferencesCard
        onThisDeviceCard
        helpAndLegalCard
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
                systemImage: "icloud",
                title: L10n.string("profile.local.sync.title"),
                detail: L10n.string("profile.local.sync.detail")
            )
        }
    }

    private var helpAndLegalCard: some View {
        AVSettingsHelpLegalSection(
            title: L10n.string("profile.help.title"),
            subtitle: L10n.string("profile.help.subtitle"),
            openSourceTitle: AppConfig.openSourceURL == nil ? nil : L10n.string("profile.help.opensource.title"),
            openSourceDetail: AppConfig.openSourceURL == nil ? nil : L10n.string("profile.help.opensource.detail"),
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
            accountDeletionTitle: "",
            accountDeletionDetail: "",
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
                if let emailAddress = accessController.accountUser?.emailAddress {
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

    private var proCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.pro.title"),
            subtitle: proSubtitle
        ) {
            AVSettingsInfoRow(
                systemImage: "icloud.and.arrow.up",
                title: L10n.string("profile.pro.sync.title"),
                detail: L10n.string("profile.pro.sync.detail")
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
                    dismiss()
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
                action: openAccountDeletion
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
                    dismiss()
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
                        Label("\(language.displayName) (\(language.autonym))", systemImage: "checkmark")
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
            .background(AVBrandColor.mutedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AVBrandColor.borderSubtle, lineWidth: 1)
            }
        }
        .accessibilityIdentifier("settings.language")
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
        .accessibilityIdentifier("settings.theme")
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
            termsURL: appExperience.legalLinks.termsURL
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

    private func openAccountDeletion() {
        guard let url = appExperience.legalLinks.accountDeletionURL ?? AppConfig.accountDeletionURL else { return }
        openURL(url)
    }

    private func openAppleSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }
}
