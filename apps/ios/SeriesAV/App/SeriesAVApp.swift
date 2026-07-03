import AVDiagnosticsFoundation
import AVSettingsFoundation
import SwiftUI

@main
struct SeriesAVApp: App {
    @StateObject private var languageController = AppLanguageController()
    @StateObject private var themeController = AppThemeController()
    @StateObject private var externalLinkPreferences = AppExternalLinkPreferencesController()
    @State private var pendingOpenURL: URL?

    init() {
        AppConfig.configureAVAccountIfPossible()
        AVDiagnostics.configure(AppConfig.diagnosticsConfiguration)
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
                    pendingOpenURL = url
                }
                .environment(\.seriesPendingOpenURL, $pendingOpenURL)
        }
    }
}
