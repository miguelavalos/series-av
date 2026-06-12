import AVSettingsFoundation
import SwiftUI

@main
struct SeriesAVApp: App {
    @StateObject private var languageController = AppLanguageController()
    @StateObject private var themeController = AppThemeController()

    init() {
        AppConfig.configureAVAccountIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            SeriesAppBootstrapView()
                .environmentObject(languageController)
                .environmentObject(themeController)
                .environment(\.locale, languageController.locale)
                .avCommonAppExperience(SeriesAppExperience.experience)
                .preferredColorScheme(themeController.currentTheme.preferredColorScheme)
        }
    }
}
