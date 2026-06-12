import Foundation

enum AppConfig {
    static var apiBaseURL: URL? {
        BundleConfig.urlValue(for: "ACCOUNTAV_API_BASE_URL")
    }

    static var isDebugForceProModeEnabled: Bool {
        BundleConfig.boolValue(for: "SERIESAV_DEBUG_FORCE_PRO_MODE")
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

    static func urlValue(for key: String) -> URL? {
        let value = stringValue(for: key)
        guard !value.isEmpty, !value.contains("$(") else {
            return nil
        }
        return URL(string: value)
    }
}
