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
