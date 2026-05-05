import AccountAV
import Foundation
import OSLog

@MainActor
enum AppConfig {
    static var clerkPublishableKey: String {
        stringValue(for: "ACCOUNTAV_PUBLISHABLE_KEY")
    }

    static var avAppsAPIBaseURL: URL? {
        urlValue(for: "ACCOUNTAV_API_BASE_URL")
    }

    static var termsURL: URL? {
        urlValue(for: "SERIESAV_TERMS_URL")
    }

    static var privacyURL: URL? {
        urlValue(for: "SERIESAV_PRIVACY_URL")
    }

    static var accountManagementURL: URL? {
        urlValue(for: "ACCOUNTAV_MANAGEMENT_URL")
    }

    static var supportURL: URL? {
        let email = stringValue(for: "SERIESAV_SUPPORT_EMAIL")
        guard !email.isEmpty else { return nil }
        return URL(string: "mailto:\(email)")
    }

    static var openSourceURL: URL? {
        urlValue(for: "SERIESAV_OPEN_SOURCE_URL")
    }

    static var debugForceProMode: Bool {
        boolValue(for: "SERIESAV_DEBUG_FORCE_PRO_MODE")
    }

    static var debugSeedSocialPreview: Bool {
        boolValue(for: "SERIESAV_DEBUG_SEED_SOCIAL_PREVIEW")
    }

    static var debugPreviewDisplayName: String {
        let value = stringValue(for: "SERIESAV_DEBUG_PREVIEW_DISPLAY_NAME")
        return value.isEmpty ? "Series AV Preview" : value
    }

    static var debugPreviewEmail: String? {
        let value = stringValue(for: "SERIESAV_DEBUG_PREVIEW_EMAIL")
        return value.isEmpty ? nil : value
    }

    static func configureClerkIfPossible() {
        AccountAVClerk.configureIfPossible(publishableKey: clerkPublishableKey)
    }

    private static func stringValue(for key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func urlValue(for key: String) -> URL? {
        let rawValue = stringValue(for: key)
        return rawValue.isEmpty ? nil : URL(string: rawValue)
    }

    private static func boolValue(for key: String) -> Bool {
        let rawValue = stringValue(for: key).lowercased()
        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
    }
}

@MainActor
protocol SeriesAVAccountService {
    var isAvailable: Bool { get }
    var currentUser: AccountUser? { get }
    func getToken() async throws -> String?
    func signInWithApple() async throws
    func signInWithGoogle() async throws
    func signOut() async throws
}

enum SeriesAVAccountServiceError: LocalizedError {
    case unavailable
    case missingSession

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Account sign-in is not configured for this build."
        case .missingSession:
            "The account provider did not return an active session."
        }
    }
}

struct DefaultSeriesAVAccountService: SeriesAVAccountService {
    private let accountService = ClerkAccountAVService(
        publishableKeyProvider: { AppConfig.clerkPublishableKey },
        fallbackDisplayName: "Series AV viewer",
        loggerSubsystem: "com.avalsys.seriesav"
    )

    var isAvailable: Bool {
        accountService.isAvailable
    }

    var currentUser: AccountUser? {
        guard let user = accountService.currentUser else { return nil }
        return AccountUser(
            id: user.id,
            displayName: user.displayName,
            emailAddress: user.emailAddress
        )
    }

    func getToken() async throws -> String? {
        try await accountService.getToken()
    }

    func signInWithApple() async throws {
        do {
            try await accountService.signInWithApple()
        } catch AccountAVError.unavailable {
            throw SeriesAVAccountServiceError.unavailable
        } catch AccountAVError.missingSession {
            throw SeriesAVAccountServiceError.missingSession
        }
    }

    func signInWithGoogle() async throws {
        do {
            try await accountService.signInWithGoogle()
        } catch AccountAVError.unavailable {
            throw SeriesAVAccountServiceError.unavailable
        } catch AccountAVError.missingSession {
            throw SeriesAVAccountServiceError.missingSession
        }
    }

    func signOut() async throws {
        try await accountService.signOut()
    }
}

@MainActor
final class AccessController: ObservableObject {
    @Published private(set) var accessMode: AccessMode = .guest
    @Published private(set) var planTier: PlanTier = .free
    @Published private(set) var capabilities: AccessCapabilities = .forMode(.guest)
    @Published private(set) var accountUser: AccountUser?
    @Published private(set) var authErrorMessage: String?

    let accountService: SeriesAVAccountService

    private let authLogger = Logger(subsystem: "com.avalsys.seriesav", category: "auth")
    private let defaults: UserDefaults
    private let guestPromptKey = "seriesav.guestPromptAt"

    init(
        accountService: SeriesAVAccountService = DefaultSeriesAVAccountService(),
        defaults: UserDefaults = .standard
    ) {
        self.accountService = accountService
        self.defaults = defaults
        accountUser = accountService.currentUser
        syncState()
    }

    var shouldAutoShowGuestOnboarding: Bool {
        guard accessMode == .guest else { return false }
        guard let lastPrompt = defaults.object(forKey: guestPromptKey) as? Date else { return true }
        return Date() >= lastPrompt.addingTimeInterval(10 * 24 * 60 * 60)
    }

    var accountIsAvailable: Bool {
        accountService.isAvailable
    }

    func markGuestPromptShown() {
        defaults.set(Date(), forKey: guestPromptKey)
    }

    func refresh() async {
        accountUser = accountService.currentUser
        syncState()
        await refreshBackendAccess()
    }

    func signInWithApple() async throws {
        try await accountService.signInWithApple()
        authErrorMessage = nil
        await refresh()
    }

    func signInWithGoogle() async throws {
        try await accountService.signInWithGoogle()
        authErrorMessage = nil
        await refresh()
    }

    func signOut() async {
        let previousAccessMode = accessMode
        authErrorMessage = nil
        accountUser = nil
        accessMode = .guest
        planTier = .free
        capabilities = .forMode(.guest)

        do {
            try await accountService.signOut()
        } catch {
            guard previousAccessMode != .guest else { return }
            authErrorMessage = error.localizedDescription
        }
    }

    func clearAuthError() {
        authErrorMessage = nil
    }

    private func syncState() {
        if AppConfig.debugForceProMode {
            accountUser = AccountUser(
                id: "debug-preview-user",
                displayName: AppConfig.debugPreviewDisplayName,
                emailAddress: AppConfig.debugPreviewEmail
            )
            accessMode = .signedInPro
            planTier = .pro
            capabilities = .forMode(.signedInPro)
            return
        }

        guard accountUser != nil else {
            accessMode = .guest
            planTier = .free
            capabilities = .forMode(.guest)
            return
        }

        accessMode = .signedInFree
        planTier = .free
        capabilities = .forMode(.signedInFree)
    }

    private func refreshBackendAccess() async {
        if AppConfig.debugForceProMode {
            accessMode = .signedInPro
            planTier = .pro
            capabilities = .forMode(.signedInPro)
            return
        }

        guard let baseURL = AppConfig.avAppsAPIBaseURL else { return }
        do {
            guard let token = try await accountService.getToken(), !token.isEmpty else { return }
            var request = URLRequest(url: baseURL.appending(path: "v1/me/access"))
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let payload = try JSONDecoder().decode(MeAccessResponse.self, from: data)
            if let access = payload.apps.first(where: { $0.appId == "seriesav" }) {
                planTier = access.planTier
                accessMode = access.accessMode
                capabilities = access.capabilities
            } else {
                accessMode = .signedInFree
                planTier = .free
                capabilities = .forMode(.signedInFree)
            }
        } catch {
            authLogger.error("Unable to refresh account access: \(String(reflecting: error), privacy: .public)")
        }
    }

}

private struct MeAccessResponse: Decodable {
    let apps: [AppAccess]
}

private struct AppAccess: Decodable {
    let appId: String
    let accessMode: AccessMode
    let planTier: PlanTier
    let capabilities: AccessCapabilities
}
