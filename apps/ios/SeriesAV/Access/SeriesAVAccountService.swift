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
            return SeriesUITestEnvironment.accountToken
        }
        if Self.uiTestAccountUser != nil {
            return SeriesUITestEnvironment.accountToken
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
        SeriesUITestEnvironment.current.shouldForceGuest
    }

    private static var shouldUseGuestTokenForUITests: Bool {
        let environment = SeriesUITestEnvironment.current
        return environment.isEnabled && environment.shouldForceGuest
    }

    private static var uiTestAccountUser: SeriesAccountUser? {
        guard SeriesUITestEnvironment.current.hasAccountOverride else { return nil }
        return SeriesAccountUser(
            id: SeriesUITestEnvironment.accountUserId,
            displayName: SeriesUITestEnvironment.accountUserDisplayName,
            emailAddress: SeriesUITestEnvironment.accountUserEmailAddress
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
