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
        keychainServiceProvider: { BundleConfig.stringValue(for: "ACCOUNTAV_KEYCHAIN_SERVICE") },
        fallbackDisplayName: "Series AV",
        loggerSubsystem: "com.avalsys.seriesav"
    )

    var isAvailable: Bool {
        accountService.isAvailable
    }

    var providerSessionUser: SeriesAccountUser? {
        Self.accountUser(from: accountService.providerSessionUser)
    }

    func restoreSession() async -> SeriesAVAccountSessionRestoreResult {
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
        try await accountService.getToken()
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
        guard isAvailable else { return }
        try await accountService.signOut()
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
