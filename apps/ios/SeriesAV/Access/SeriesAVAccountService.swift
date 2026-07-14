import AccountAV
import Foundation

@MainActor
protocol SeriesAVAccountServicing: Sendable {
    var isAvailable: Bool { get }
    var providerSessionUser: SeriesAccountUser? { get }

    func restoreSession() async -> SeriesAVAccountSessionRestoreResult
    func getToken() async throws -> String?
    func signInWithApple() async throws
    func signInWithGoogle() async throws
    func signOut() async throws
}

enum SeriesAVAccountSessionRestoreResult: Equatable {
    case signedOut
    case active(SeriesAccountUser)
    case temporarilyUnavailable(SeriesAccountUser?)
    case invalidated
}

enum SeriesAVAccountServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Account AV is not configured for this build."
        }
    }
}

struct DefaultSeriesAVAccountService: SeriesAVAccountServicing {
    private let accountService = ClerkAccountAVService(
        publishableKeyProvider: { AppConfig.avAccountKey },
        keychainServiceProvider: { BundleConfig.nonEmptyStringValue(for: "ACCOUNTAV_KEYCHAIN_SERVICE") },
        keychainAccessGroupProvider: { BundleConfig.nonEmptyStringValue(for: "ACCOUNTAV_KEYCHAIN_ACCESS_GROUP") },
        fallbackDisplayName: "Series AV",
        loggerSubsystem: "com.avalsys.seriesav"
    )

    var isAvailable: Bool {
        guard !Self.shouldForceGuestForUITests else { return false }
        if Self.shouldUseAvailableGuestAccountForUITests { return true }
        if Self.uiTestAccountUser != nil { return true }
        return accountService.isAvailable
    }

    var providerSessionUser: SeriesAccountUser? {
        guard !Self.shouldForceGuestForUITests else { return nil }
        if let uiTestAccountUser = Self.uiTestAccountUser {
            return uiTestAccountUser
        }
        return Self.accountUser(from: accountService.providerSessionUser)
    }

    func restoreSession() async -> SeriesAVAccountSessionRestoreResult {
        guard !Self.shouldForceGuestForUITests else { return .signedOut }
        if Self.shouldUseAvailableGuestAccountForUITests { return .signedOut }
        if let uiTestAccountUser = Self.uiTestAccountUser {
            return .active(uiTestAccountUser)
        }
        switch await accountService.restoreSession() {
        case .signedOut:
            return .signedOut
        case .active(let user):
            guard let user = Self.accountUser(from: user) else { return .signedOut }
            return .active(user)
        case .temporarilyUnavailable(let user):
            return .temporarilyUnavailable(Self.accountUser(from: user))
        case .invalidated:
            return .invalidated
        }
    }

    func getToken() async throws -> String? {
        if Self.shouldUseGuestTokenForUITests {
            return nil
        }
        if Self.uiTestAccountUser != nil {
            return SeriesUITestEnvironment.current.accountToken
        }
        return try await accountService.getToken()
    }

    func signInWithApple() async throws {
        guard isAvailable else {
            throw SeriesAVAccountServiceError.unavailable
        }
        try await accountService.signInWithApple()
    }

    func signInWithGoogle() async throws {
        guard isAvailable else {
            throw SeriesAVAccountServiceError.unavailable
        }
        try await accountService.signInWithGoogle()
    }

    func signOut() async throws {
        if Self.uiTestAccountUser != nil { return }
        guard isAvailable else { return }
        try await accountService.signOut()
    }

    private static var shouldForceGuestForUITests: Bool {
        shouldForceGuestForUITests(environment: .current)
    }

    private static var shouldUseGuestTokenForUITests: Bool {
        shouldUseGuestTokenForUITests(environment: .current)
    }

    private static var shouldUseAvailableGuestAccountForUITests: Bool {
        SeriesUITestEnvironment.current.shouldUseAvailableGuestAccount
    }

    static func shouldForceGuestForUITests(environment: SeriesUITestEnvironment) -> Bool {
        environment.shouldForceGuest
    }

    static func shouldUseGuestTokenForUITests(environment: SeriesUITestEnvironment) -> Bool {
        environment.isEnabled && !environment.hasAccountOverride
    }

    private static var uiTestAccountUser: SeriesAccountUser? {
        guard SeriesUITestEnvironment.current.hasAccountOverride else { return nil }
        let environment = SeriesUITestEnvironment.current
        return SeriesAccountUser(
            id: environment.accountUserId,
            displayName: environment.accountUserDisplayName,
            emailAddress: environment.accountUserEmailAddress
        )
    }

    private static func accountUser(from user: AccountAVUser?) -> SeriesAccountUser? {
        guard let user else { return nil }
        return SeriesAccountUser(
            id: user.id,
            displayName: user.displayName,
            emailAddress: user.emailAddress
        )
    }
}
