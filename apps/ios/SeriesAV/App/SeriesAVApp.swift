import AVSettingsFoundation
import SwiftUI

@main
struct SeriesAVApp: App {
    @StateObject private var languageController = AppLanguageController()
    @StateObject private var themeController = AppThemeController()
    @StateObject private var externalLinkPreferences = AppExternalLinkPreferencesController()
    @State private var shareInviteBrowserDestination: SeriesInAppBrowserDestination?

    init() {
        AppConfig.configureAVAccountIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            SeriesAppBootstrapView()
                .environmentObject(languageController)
                .environmentObject(themeController)
                .environmentObject(externalLinkPreferences)
                .environment(\.locale, languageController.locale)
                .avCommonAppExperience(SeriesAppExperience.experience)
                .preferredColorScheme(themeController.currentTheme.preferredColorScheme)
                .onOpenURL { url in
                    openShareInviteIfNeeded(url)
                }
                .sheet(item: $shareInviteBrowserDestination) { destination in
                    SeriesInAppBrowserView(url: destination.url)
                }
        }
    }

    private func openShareInviteIfNeeded(_ url: URL) {
        guard let deepLink = SeriesShareInviteDeepLink(url: url) else { return }
        shareInviteBrowserDestination = SeriesInAppBrowserDestination(url: deepLink.webURL())
    }
}
