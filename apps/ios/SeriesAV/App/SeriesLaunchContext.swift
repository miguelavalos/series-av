import Foundation

struct SeriesLaunchContext {
    let isUITesting: Bool
    let shouldDisableSplash: Bool
    let shouldDisableOnboarding: Bool

    static let current = SeriesLaunchContext(environment: ProcessInfo.processInfo.environment)

    init(environment: [String: String]) {
        isUITesting = environment["SERIESAV_UI_TESTS"] == "1"
        shouldDisableSplash = isUITesting || environment["SERIESAV_DISABLE_SPLASH"] == "1"
        shouldDisableOnboarding = environment["SERIESAV_UI_TESTS_SHOW_ONBOARDING"] != "1"
            && (isUITesting || environment["SERIESAV_DISABLE_ONBOARDING"] == "1")
    }
}

struct SeriesUITestEnvironment {
    let environment: [String: String]

    static let current = SeriesUITestEnvironment(environment: ProcessInfo.processInfo.environment)

    var isEnabled: Bool {
        environment["SERIESAV_UI_TESTS"] == "1"
    }

    var shouldForceGuest: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_FORCE_GUEST"] == "1"
    }

    var shouldForceGuestOnboarding: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SHOW_ONBOARDING"] == "1"
    }

    var accountMode: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_ACCOUNT_MODE"]
    }

    var hasAccountOverride: Bool {
        accountMode != nil
    }

    var isProAccount: Bool {
        accountMode == "pro"
    }

    var accountDeletionScenario: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TEST_ACCOUNT_DELETION"]
    }

    static let accountUserId = "series-ui-test-user"
    static let accountUserDisplayName = "Series UI Test User"
    static let accountUserEmailAddress = "series-ui-test@example.test"
    static let accountToken = "series-ui-test-token"
}
