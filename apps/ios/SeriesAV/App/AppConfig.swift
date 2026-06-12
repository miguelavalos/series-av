import AccountAV
import Foundation

enum AppConfig {
    static var avAccountKey: String {
        BundleConfig.stringValue(for: "ACCOUNTAV_PUBLISHABLE_KEY")
    }

    static var apiBaseURL: URL? {
        BundleConfig.urlValue(for: "ACCOUNTAV_API_BASE_URL")
    }

    static var accountManagementURL: URL? {
        BundleConfig.urlValue(for: "ACCOUNTAV_MANAGEMENT_URL")
    }

    static var supportURL: URL? {
        if let url = BundleConfig.urlValue(for: "SERIESAV_SUPPORT_URL") {
            return url
        }

        let email = BundleConfig.nonEmptyStringValue(for: "SERIESAV_SUPPORT_EMAIL")
        guard let email else { return nil }
        return URL(string: "mailto:\(email)")
    }

    static var termsURL: URL? {
        BundleConfig.urlValue(for: "SERIESAV_TERMS_URL")
    }

    static var privacyURL: URL? {
        BundleConfig.urlValue(for: "SERIESAV_PRIVACY_URL")
    }

    static var openSourceURL: URL? {
        BundleConfig.urlValue(for: "SERIESAV_OPEN_SOURCE_URL")
    }

    static var accountDeletionURL: URL? {
        if let url = BundleConfig.urlValue(for: "SERIESAV_DELETE_ACCOUNT_URL") {
            return url
        }

        return accountManagementURL?.appending(path: "delete-account")
    }

    static var isDebugForceProModeEnabled: Bool {
        BundleConfig.boolValue(for: "SERIESAV_DEBUG_FORCE_PRO_MODE")
    }

    @MainActor
    static func configureAVAccountIfPossible() {
        AccountAVClerk.configureIfPossible(
            publishableKey: avAccountKey,
            keychainService: BundleConfig.nonEmptyStringValue(for: "ACCOUNTAV_KEYCHAIN_SERVICE")
        )
    }
}

enum BundleConfig {
    static func stringValue(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func boolValue(for key: String) -> Bool {
        ["1", "true", "yes", "on"]
            .contains(stringValue(for: key).lowercased())
    }

    static func nonEmptyStringValue(for key: String) -> String? {
        let value = stringValue(for: key)
        guard !value.isEmpty, !value.contains("$(") else {
            return nil
        }
        return value
    }

    static func urlValue(for key: String) -> URL? {
        guard let value = nonEmptyStringValue(for: key) else {
            return nil
        }
        return URL(string: value)
    }
}
