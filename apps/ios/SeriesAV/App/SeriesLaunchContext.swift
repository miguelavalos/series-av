import AVAppShellFoundation
import Foundation

struct SeriesLaunchContext {
    let isUITesting: Bool
    let shouldDisableSplash: Bool
    let shouldDisableOnboarding: Bool
    let initialTab: SeriesRootTab

    static let current = SeriesLaunchContext(environment: ProcessInfo.processInfo.environment)

    init(environment: [String: String]) {
        isUITesting = environment["SERIESAV_UI_TESTS"] == "1"
        shouldDisableSplash = isUITesting || environment["SERIESAV_DISABLE_SPLASH"] == "1"
        shouldDisableOnboarding = environment["SERIESAV_UI_TESTS_SHOW_ONBOARDING"] != "1"
            && (isUITesting || environment["SERIESAV_DISABLE_ONBOARDING"] == "1")
        if isUITesting,
           let requestedTab = environment["SERIESAV_UI_TESTS_INITIAL_TAB"],
           let initialTab = SeriesRootTab(rawValue: requestedTab),
           SeriesRootTab.footerTabs.contains(initialTab) || initialTab == .avi {
            self.initialTab = initialTab
        } else {
            initialTab = .home
        }
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

    var shouldShowExpandedOnboardingAuthOptions: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SHOW_AUTH_OPTIONS"] == "1"
    }

    var shouldShowPaywall: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SHOW_PAYWALL"] == "1"
    }

    var shouldShowRedeemCodeSheet: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SHOW_REDEEM_CODE"] == "1"
    }

    var shouldShowLocalDataMaintenanceSheet: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SHOW_LOCAL_DATA_MAINTENANCE"] == "1"
    }

    var initialInAppBrowserURL: URL? {
        guard isEnabled,
              let rawValue = environment["SERIESAV_UI_TESTS_IN_APP_BROWSER_URL"] else {
            return nil
        }
        return URL(string: rawValue)
    }

    var subscriptionOfferPrice: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_SUBSCRIPTION_PRICE"]
    }

    var shouldResetPersistentState: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_RESET_STATE"] == "1"
    }

    var shouldUseSampleLibrary: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SAMPLE_LIBRARY"] == "1"
    }

    var shouldUseHighSeasonSampleLibrary: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_HIGH_SEASON_LIBRARY"] == "1"
    }

    var episodeGuideScenario: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_EPISODE_GUIDE"]
    }

    var upcomingEpisodesScenario: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_UPCOMING_EPISODES"]
    }

    var guideFeedbackScenario: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_GUIDE_FEEDBACK"]
    }

    var homeDiscoveryScenario: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_HOME_DISCOVERY"]
    }

    var shouldShowProgressEditor: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SHOW_PROGRESS_EDITOR"] == "1"
    }

    var shouldStubShareInviteCreation: Bool {
        isEnabled && environment["SERIESAV_UI_TESTS_SHARE_INVITE"] == "success"
    }

    var initialShareInviteDeepLink: SeriesShareInviteDeepLink? {
        guard isEnabled,
              environment["SERIESAV_UI_TESTS_SHARE_INVITE_ACCEPTANCE"] != nil,
              let url = URL(string: "com.avalsys.seriesav://i/r/ui-test-invite-token") else {
            return nil
        }
        return SeriesShareInviteDeepLink(url: url)
    }

    var shareInviteAcceptanceScenario: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_SHARE_INVITE_ACCEPTANCE"]
    }

    var progressEditorEntryId: String? {
        guard isEnabled else {
            return nil
        }
        return environment["SERIESAV_UI_TESTS_PROGRESS_EDITOR_ENTRY_ID"]
    }

    var initialChromeItem: AVAppShellChromeItem? {
        guard isEnabled else { return nil }
        switch environment["SERIESAV_UI_TESTS_INITIAL_CHROME"] {
        case "account":
            return .account
        case "settings":
            return .settings
        default:
            return nil
        }
    }

    var accountMode: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TESTS_ACCOUNT_MODE"]
    }

    var hasAccountOverride: Bool {
        accountMode == "free" || accountMode == "pro"
    }

    var shouldUseAvailableGuestAccount: Bool {
        accountMode == "guest_available"
    }

    var isProAccount: Bool {
        accountMode == "pro"
    }

    var accountDeletionScenario: String? {
        guard isEnabled else { return nil }
        return environment["SERIESAV_UI_TEST_ACCOUNT_DELETION"]
    }

    var accountUserId: String {
        guard isEnabled else { return Self.accountUserId }
        return environment["SERIESAV_UI_TEST_ACCOUNT_USER_ID"] ?? Self.accountUserId
    }

    var accountUserDisplayName: String {
        guard isEnabled else { return Self.accountUserDisplayName }
        return environment["SERIESAV_UI_TEST_ACCOUNT_DISPLAY_NAME"] ?? Self.accountUserDisplayName
    }

    var accountUserEmailAddress: String? {
        guard isEnabled else { return Self.accountUserEmailAddress }
        return environment["SERIESAV_UI_TEST_ACCOUNT_EMAIL"] ?? Self.accountUserEmailAddress
    }

    var accountToken: String {
        guard isEnabled else { return Self.accountToken }
        return environment["SERIESAV_UI_TEST_ACCOUNT_TOKEN"] ?? Self.accountToken
    }

    var forcedLibrarySyncState: SeriesLibrarySyncCoordinator.State? {
        guard isEnabled else { return nil }
        switch environment["SERIESAV_UI_TESTS_LIBRARY_SYNC_STATE"] {
        case "disabled":
            return .disabled
        case "idle":
            return .idle
        case "syncing":
            return .syncing
        case "conflict":
            return .conflict
        case "failed":
            return .failed("ui-test")
        default:
            return nil
        }
    }

    static let accountUserId = "series-ui-test-user"
    static let accountUserDisplayName = "Series UI Test User"
    static let accountUserEmailAddress = "series-ui-test@example.test"
    static let accountToken = "series-ui-test-token"
}
