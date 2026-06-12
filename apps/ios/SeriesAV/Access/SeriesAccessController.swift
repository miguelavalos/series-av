import AVProductAccountFoundation
import Foundation
import Observation

@MainActor
protocol SeriesAccountProfileResolving: Sendable {
    func resolveCurrentAccountUser() async throws -> SeriesAccountUser
}

enum SeriesAccountProfileResolverError: Error, Equatable {
    case missingInternalUserId
}

@MainActor
struct PlatformSeriesAccountProfileResolver: SeriesAccountProfileResolving {
    let accessClient: SeriesAccountAccessProviding

    func resolveCurrentAccountUser() async throws -> SeriesAccountUser {
        let summary = try await accessClient.fetchAccountSummary()
        guard let id = summary.id, !id.isEmpty else {
            throw SeriesAccountProfileResolverError.missingInternalUserId
        }

        let displayName = summary.displayName.flatMap { value -> String? in
            value.isEmpty ? nil : value
        } ?? "Series AV"

        return SeriesAccountUser(
            id: id,
            displayName: displayName,
            emailAddress: summary.emailAddress
        )
    }
}

@MainActor
@Observable
final class SeriesAccessController {
    private let accountService: SeriesAVAccountServicing
    private let profileResolver: SeriesAccountProfileResolving
    private let entitlementService: SeriesEntitlementServicing
    private let userDefaults: UserDefaults
    private let lastKnownAccountUserKey = "seriesav.account.lastKnownUser"
    private var accessRefreshGeneration = 0

    private(set) var accountUser: SeriesAccountUser?
    private(set) var accountSession: SeriesAccountSession?
    private(set) var accessMode: SeriesAccessMode
    private(set) var planTier: SeriesPlanTier
    private(set) var capabilities: SeriesAccessCapabilities
    private(set) var limits: SeriesAccessLimits
    private(set) var platformUserId: String?
    private(set) var isAccountSessionTemporarilyUnavailable: Bool

    init(
        accountService: SeriesAVAccountServicing = DefaultSeriesAVAccountService(),
        profileResolver: SeriesAccountProfileResolving? = nil,
        entitlementService: SeriesEntitlementServicing? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let accessClient = SeriesAccountAccessClient(apiClient: SeriesAVAPIClient(
            baseURL: AppConfig.apiBaseURL,
            tokenProvider: { try await accountService.getToken() }
        ))

        self.accountService = accountService
        self.profileResolver = profileResolver ?? PlatformSeriesAccountProfileResolver(accessClient: accessClient)
        self.entitlementService = entitlementService ?? SeriesPlatformEntitlementService(
            accessClient: accessClient
        )
        self.userDefaults = userDefaults
        self.accountUser = nil
        self.accountSession = nil
        self.accessMode = .guest
        self.planTier = .free
        self.capabilities = .forMode(.guest)
        self.limits = .forMode(.guest)
        self.platformUserId = nil
        self.isAccountSessionTemporarilyUnavailable = false
    }

    var isSignedIn: Bool {
        accountUser != nil
    }

    var accountIsAvailable: Bool {
        accountService.isAvailable
    }

    var productAccountState: AVProductAccountState {
        if isAccountSessionTemporarilyUnavailable, let accountUser {
            return .temporarilyUnavailable(AVProductAccountSession(
                user: accountUser.productAccountUser,
                isTemporarilyUnavailable: true
            ))
        }

        if let accountUser {
            return .signedIn(AVProductAccountSession(user: accountUser.productAccountUser))
        }

        return .guest
    }

    func syncFromAccountProvider() async {
        accessRefreshGeneration += 1
        let generation = accessRefreshGeneration

        let sessionController = AVProductAccountSessionController(
            configuration: .seriesAV,
            provider: SeriesProductAccountProvider(accountService: accountService),
            resolver: SeriesProductAccountResolver(profileResolver: profileResolver),
            persistence: SeriesProductAccountPersistence(userDefaults: userDefaults, key: lastKnownAccountUserKey)
        )

        let productAccountState = await sessionController.restore()
        guard generation == accessRefreshGeneration else { return }

        switch productAccountState {
        case .signedIn(let session):
            accountUser = SeriesAccountUser(productAccountUser: session.user)
            isAccountSessionTemporarilyUnavailable = false
        case .temporarilyUnavailable(let session):
            accountUser = SeriesAccountUser(productAccountUser: session.user)
            isAccountSessionTemporarilyUnavailable = true
        case .restoring(let lastKnownUser):
            accountUser = lastKnownUser.map(SeriesAccountUser.init(productAccountUser:))
            isAccountSessionTemporarilyUnavailable = lastKnownUser != nil
        case .guest:
            accountUser = nil
            isAccountSessionTemporarilyUnavailable = false
        }

        await refreshAccess()
    }

    func refreshAccess() async {
        let resolvedAccess = await entitlementService.refreshAccess(for: accountUser)
        applyResolvedAccess(resolvedAccess)
    }

    func signInWithApple() async throws {
        try await accountService.signInWithApple()
        await syncFromAccountProvider()
    }

    func signInWithGoogle() async throws {
        try await accountService.signInWithGoogle()
        await syncFromAccountProvider()
    }

    func signOut() async throws {
        try await accountService.signOut()
        accountUser = nil
        isAccountSessionTemporarilyUnavailable = false
        applyResolvedAccess(.guest)
    }

    private func applyResolvedAccess(_ resolvedAccess: SeriesResolvedAccess) {
        platformUserId = resolvedAccess.platformUserId
        accessMode = resolvedAccess.accessMode
        planTier = resolvedAccess.planTier
        capabilities = resolvedAccess.capabilities
        limits = resolvedAccess.limits

        if let accountUser {
            accountSession = SeriesAccountSession(user: accountUser, access: resolvedAccess)
        } else {
            accountSession = nil
        }
    }
}

private extension AVProductAccountConfiguration {
    static let seriesAV = AVProductAccountConfiguration(
        appIdentifier: "seriesav",
        appDisplayName: "Series AV",
        allowsGuestMode: true
    )
}

private extension SeriesAccountUser {
    init(productAccountUser user: AVProductAccountUser) {
        self.init(id: user.id, displayName: user.displayName, emailAddress: user.emailAddress)
    }

    var productAccountUser: AVProductAccountUser {
        AVProductAccountUser(id: id, displayName: displayName, emailAddress: emailAddress)
    }
}

@MainActor
private struct SeriesProductAccountProvider: AVProductAccountProviderSessioning {
    let accountService: SeriesAVAccountServicing

    func restoreProviderSession() async -> AVProductAccountProviderRestoreResult {
        switch await accountService.restoreSession() {
        case .signedOut:
            return .signedOut
        case .active:
            return .active
        case .temporarilyUnavailable:
            return .temporarilyUnavailable
        case .invalidated:
            return .invalidated
        }
    }

    func getProviderToken() async throws -> String? {
        try await accountService.getToken()
    }

    func signOutProvider() async throws {
        try await accountService.signOut()
    }
}

@MainActor
private struct SeriesProductAccountResolver: AVProductAccountResolving {
    let profileResolver: SeriesAccountProfileResolving

    func resolveProductAccount(
        providerToken: String,
        configuration: AVProductAccountConfiguration
    ) async throws -> AVProductAccountUser {
        _ = providerToken
        _ = configuration

        let accountUser = try await profileResolver.resolveCurrentAccountUser()
        return accountUser.productAccountUser
    }
}

@MainActor
private struct SeriesProductAccountPersistence: AVProductAccountPersistence {
    let userDefaults: UserDefaults
    let key: String

    func loadLastKnownUser() async -> AVProductAccountUser? {
        guard let data = userDefaults.data(forKey: key),
              let user = try? JSONDecoder().decode(SeriesAccountUser.self, from: data) else {
            return nil
        }
        return user.productAccountUser
    }

    func saveLastKnownUser(_ user: AVProductAccountUser) async throws {
        let accountUser = SeriesAccountUser(productAccountUser: user)
        guard let data = try? JSONEncoder().encode(accountUser) else { return }
        userDefaults.set(data, forKey: key)
    }

    func clearLastKnownUser() async throws {
        userDefaults.removeObject(forKey: key)
    }
}
