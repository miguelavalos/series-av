import SwiftUI

@main
struct SeriesAVApp: App {
    @StateObject private var accessController: AccessController
    @StateObject private var libraryStore: SeriesLibraryStore
    @StateObject private var languageController: AppLanguageController
    @StateObject private var themeController: AppThemeController
    @StateObject private var socialStore: SeriesSocialStore

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 250 * 1024 * 1024
        )
        AppConfig.configureClerkIfPossible()
        _accessController = StateObject(wrappedValue: AccessController())
        _libraryStore = StateObject(wrappedValue: SeriesLibraryStore())
        _languageController = StateObject(wrappedValue: AppLanguageController())
        _themeController = StateObject(wrappedValue: AppThemeController())
        _socialStore = StateObject(wrappedValue: SeriesSocialStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accessController)
                .environmentObject(libraryStore)
                .environmentObject(languageController)
                .environment(\.locale, languageController.locale)
                .environmentObject(themeController)
                .environmentObject(socialStore)
        }
    }
}
