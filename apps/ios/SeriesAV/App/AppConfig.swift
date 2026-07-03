import AccountAV
import AVDiagnosticsFoundation
import Foundation

enum AppConfig {
    static var avAccountKey: String {
        BundleConfig.stringValue(for: "ACCOUNTAV_PUBLISHABLE_KEY")
    }

    static var apiBaseURL: URL? {
        BundleConfig.urlValue(for: "ACCOUNTAV_API_BASE_URL")
    }

    static var seriesAPIBaseURL: URL? {
        BundleConfig.urlValue(for: "SERIESAV_API_BASE_URL") ?? apiBaseURL
    }

    static var accountManagementURL: URL? {
        BundleConfig.urlValue(for: "ACCOUNTAV_MANAGEMENT_URL")
    }

    static var seriesConvexURL: String {
        BundleConfig.stringValue(for: "SERIESAV_CONVEX_URL")
    }

    static var supportURL: URL {
        if let url = BundleConfig.urlValue(for: "SERIESAV_SUPPORT_URL") {
            return url
        }

        let email = BundleConfig.nonEmptyStringValue(for: "SERIESAV_SUPPORT_EMAIL")
        guard let email, let emailURL = URL(string: "mailto:\(email)") else {
            return URL(string: "mailto:support@avalsys.com")!
        }
        return emailURL
    }

    static var termsURL: URL {
        configuredURL(for: "SERIESAV_TERMS_URL", fallback: "https://series-av.avalsys.com/terms")
    }

    static var privacyURL: URL {
        configuredURL(for: "SERIESAV_PRIVACY_URL", fallback: "https://series-av.avalsys.com/privacy")
    }

    static var seriesWebBaseURL: URL {
        BundleConfig.urlValue(for: "SERIESAV_WEB_BASE_URL") ?? configuredURL(for: "SERIESAV_PRIVACY_URL", fallback: "https://series-av.avalsys.com/privacy").deletingLastPathComponent()
    }

    static var openSourceURL: URL {
        configuredURL(for: "SERIESAV_OPEN_SOURCE_URL", fallback: "https://github.com/avalsys/series-av")
    }

    static var accountDeletionURL: URL? {
        BundleConfig.deleteAccountURL(
            explicitURL: BundleConfig.urlValue(for: "SERIESAV_DELETE_ACCOUNT_URL"),
            accountURL: BundleConfig.urlValue(for: "ACCOUNTAV_DELETE_ACCOUNT_URL"),
            accountManagementURL: accountManagementURL
        )
    }

    static var revenueCatPublicAPIKey: String? {
        BundleConfig.nonEmptyStringValue(for: "SERIESAV_REVENUECAT_PUBLIC_API_KEY")
    }

    static var revenueCatOfferingID: String? {
        BundleConfig.nonEmptyStringValue(for: "SERIESAV_REVENUECAT_OFFERING_ID")
    }

    static var revenueCatMonthlyPackageID: String? {
        BundleConfig.nonEmptyStringValue(for: "SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID")
    }

    static var isDebugForceProModeEnabled: Bool {
        BundleConfig.boolValue(for: "SERIESAV_DEBUG_FORCE_PRO_MODE")
    }

    static var diagnosticsConfiguration: AVDiagnosticsConfiguration {
        AVDiagnosticsConfiguration(
            dsn: diagnosticsDSN,
            environment: diagnosticsEnvironment,
            releaseName: diagnosticsReleaseName,
            tracesSampleRate: 0,
            isEnabled: isDiagnosticsEnabled
        )
    }

    @MainActor
    static func configureAVAccountIfPossible() {
        AccountAVClerk.configureIfPossible(
            publishableKey: avAccountKey,
            keychainService: BundleConfig.nonEmptyStringValue(for: "ACCOUNTAV_KEYCHAIN_SERVICE"),
            keychainAccessGroup: BundleConfig.nonEmptyStringValue(for: "ACCOUNTAV_KEYCHAIN_ACCESS_GROUP")
        )
    }

    private static var diagnosticsEnvironment: AVDiagnosticsEnvironment {
        switch BundleConfig.stringValue(for: "SERIESAV_CONFIG_ENVIRONMENT").lowercased() {
        case "prod", "production":
            return .production
        case "staging", "preview":
            return .preview
        case "dev", "debug":
            return .debug
        default:
            return .debug
        }
    }

    private static var diagnosticsReleaseName: String? {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.avalsys.seriesav"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(bundleIdentifier)@\(version)+\(build)"
    }

    private static var diagnosticsDSN: String {
        BundleConfig.stringValue(for: "SERIESAV_IOS_SENTRY_DSN")
    }

    private static var isDiagnosticsEnabled: Bool {
        #if DEBUG
        false
        #else
        !diagnosticsDSN.isEmpty
        #endif
    }

    private static func configuredURL(for key: String, fallback: String) -> URL {
        BundleConfig.urlValue(for: key) ?? URL(string: fallback)!
    }
}

enum BundleConfig {
    static func stringValue(for key: String, in bundle: Bundle = .main) -> String {
        nonEmptyStringValue(for: key, in: bundle) ?? ""
    }

    static func boolValue(for key: String, in bundle: Bundle = .main, default defaultValue: Bool = false) -> Bool {
        guard let value = nonEmptyStringValue(for: key, in: bundle) else {
            return defaultValue
        }

        switch value.lowercased() {
        case "1", "true", "yes", "on", "enabled":
            return true
        case "0", "false", "no", "off", "disabled":
            return false
        default:
            return defaultValue
        }
    }

    static func nonEmptyStringValue(for key: String, in bundle: Bundle = .main) -> String? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else {
            return nil
        }
        return value
    }

    static func urlValue(for key: String, in bundle: Bundle = .main) -> URL? {
        guard let value = nonEmptyStringValue(for: key, in: bundle) else {
            return nil
        }
        return URL(string: value)
    }

    static func deleteAccountURL(
        explicitURL: URL?,
        accountURL: URL?,
        accountManagementURL: URL?
    ) -> URL? {
        explicitURL ?? accountURL ?? accountManagementURL?.appending(path: "account/delete")
    }
}
