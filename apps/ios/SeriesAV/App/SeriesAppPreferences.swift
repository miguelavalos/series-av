import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case catalan = "ca"
    case french = "fr"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: L10n.string("language.english")
        case .spanish: L10n.string("language.spanish")
        case .catalan: L10n.string("language.catalan")
        case .french: L10n.string("language.french")
        case .german: L10n.string("language.german")
        }
    }

    var autonym: String {
        switch self {
        case .english: "English"
        case .spanish: "Espanol"
        case .catalan: "Catala"
        case .french: "Francais"
        case .german: "Deutsch"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func resolved(from rawValue: String?) -> AppLanguage {
        guard let rawValue else { return .english }
        if let exactMatch = AppLanguage(rawValue: rawValue) {
            return exactMatch
        }

        let normalized = rawValue.lowercased()
        if normalized.hasPrefix("es") { return .spanish }
        if normalized.hasPrefix("ca") { return .catalan }
        if normalized.hasPrefix("fr") { return .french }
        if normalized.hasPrefix("de") { return .german }
        return .english
    }
}

final class AppLanguageController: ObservableObject {
    @Published private(set) var currentLanguage: AppLanguage

    var locale: Locale {
        currentLanguage.locale
    }

    private let userDefaults: UserDefaults
    private let userDefaultsKey = "seriesav.appLanguage"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let launchLanguage = ProcessInfo.processInfo.environment["SERIESAV_APP_LANGUAGE"] {
            let resolvedLanguage = AppLanguage.resolved(from: launchLanguage)
            currentLanguage = resolvedLanguage
            userDefaults.set(resolvedLanguage.rawValue, forKey: userDefaultsKey)
            return
        }

        currentLanguage = AppLanguage.resolved(
            from: userDefaults.string(forKey: userDefaultsKey) ?? Locale.preferredLanguages.first
        )
    }

    func select(_ language: AppLanguage) {
        userDefaults.set(language.rawValue, forKey: userDefaultsKey)
        guard currentLanguage != language else { return }
        currentLanguage = language
    }
}

enum L10n {
    private static let userDefaultsKey = "seriesav.appLanguage"

    static var locale: Locale {
        selectedLanguage.locale
    }

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = string(key)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private static var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: selectedLanguage.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return .main
        }

        return localizedBundle
    }

    private static var selectedLanguage: AppLanguage {
        AppLanguage.resolved(
            from: ProcessInfo.processInfo.environment["SERIESAV_APP_LANGUAGE"]
                ?? UserDefaults.standard.string(forKey: userDefaultsKey)
                ?? Locale.preferredLanguages.first
        )
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

final class AppThemeController: ObservableObject {
    @Published private(set) var currentTheme: AppTheme

    private let userDefaults: UserDefaults
    private let userDefaultsKey = "seriesav.appTheme"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        currentTheme = AppTheme(rawValue: userDefaults.string(forKey: userDefaultsKey) ?? "") ?? .system
    }

    func select(_ theme: AppTheme) {
        guard currentTheme != theme else { return }
        currentTheme = theme
        userDefaults.set(theme.rawValue, forKey: userDefaultsKey)
    }
}
