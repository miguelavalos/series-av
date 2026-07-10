import AVAppShellFoundation
import AVBrandFoundation
import AVExternalLinkFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesSettingsContent: View {
    @EnvironmentObject private var languageController: AppLanguageController
    @EnvironmentObject private var themeController: AppThemeController
    @EnvironmentObject private var externalLinkPreferences: AppExternalLinkPreferencesController
    @Environment(\.avCommonAppExperience) private var appExperience
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var selectorTitleFontSize: CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var selectorDetailFontSize: CGFloat = 12

    let hasLocalData: Bool
    let manageLocalData: () -> Void
    let openExternalLink: (URL) -> Void

    var body: some View {
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
            Divider().overlay(AVBrandColor.borderSubtle)
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
                action: manageLocalData
            )
            .disabled(!hasLocalData)
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
            openURL: openExternalLink
        )
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
                        .font(.system(size: selectorTitleFontSize, weight: .semibold))
                        .foregroundStyle(AVBrandColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(languageController.currentLanguage.autonym)
                        .font(.system(size: selectorDetailFontSize, weight: .medium))
                        .foregroundStyle(AVBrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityIdentifier("profile.settings.language.selector")
    }

    private var themeSelector: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            ForEach(AppTheme.allCases) { theme in
                AVSettingsOptionButton(
                    title: themeLabel(for: theme),
                    systemImage: themeSymbol(for: theme),
                    isSelected: themeController.currentTheme == theme,
                    action: { themeController.select(theme) }
                )
                .accessibilityIdentifier("profile.settings.theme.\(theme.id)")
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
                        Label(searchEngineLabel(for: engine), systemImage: "checkmark")
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
                    .font(.system(size: selectorTitleFontSize, weight: .semibold))
                    .foregroundStyle(AVBrandColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityIdentifier("profile.settings.searchEngine.selector")
    }

    private var webOpenModeSelector: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            ForEach(AVExternalWebOpenMode.allCases) { mode in
                AVSettingsOptionButton(
                    title: webOpenModeLabel(for: mode),
                    systemImage: webOpenModeSymbol(for: mode),
                    isSelected: externalLinkPreferences.webOpenMode == mode,
                    action: { externalLinkPreferences.selectWebOpenMode(mode) }
                )
                .accessibilityIdentifier("profile.settings.webOpenMode.\(mode.rawValue)")
            }
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
}
