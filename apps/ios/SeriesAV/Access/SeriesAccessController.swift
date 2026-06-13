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
    enum SubscriptionReconciliationSource: Equatable {
        case purchase
        case restore
    }

    private let accountService: SeriesAVAccountServicing
    private let profileResolver: SeriesAccountProfileResolving
    private let entitlementService: SeriesEntitlementServicing
    private let subscriptionPurchasing: SeriesSubscriptionPurchasing
    private let userDefaults: UserDefaults
    private let subscriptionReconciliationRetryDelaysNanoseconds: [UInt64]
    private let sleepNanoseconds: (UInt64) async -> Void
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
    private(set) var subscriptionOffer: SeriesSubscriptionOffer?
    private(set) var subscriptionError: SeriesSubscriptionPurchaseError?
    private(set) var isSubscriptionOperationInProgress: Bool
    private(set) var isWaitingForSubscriptionReconciliation: Bool
    private(set) var subscriptionReconciliationSource: SubscriptionReconciliationSource?

    init(
        accountService: SeriesAVAccountServicing = DefaultSeriesAVAccountService(),
        profileResolver: SeriesAccountProfileResolving? = nil,
        entitlementService: SeriesEntitlementServicing? = nil,
        subscriptionPurchasing: SeriesSubscriptionPurchasing = RevenueCatSeriesSubscriptionPurchasing(),
        userDefaults: UserDefaults = .standard,
        subscriptionReconciliationRetryDelaysNanoseconds: [UInt64] = [
            1_000_000_000,
            2_000_000_000,
            3_000_000_000,
            5_000_000_000
        ],
        sleepNanoseconds: @escaping (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        let currentUser = Self.lastKnownAccountUser(from: userDefaults, key: lastKnownAccountUserKey)
        let accessClient = SeriesAccountAccessClient(apiClient: SeriesAVAPIClient(
            baseURL: AppConfig.apiBaseURL,
            tokenProvider: { try await accountService.getToken() }
        ))

        self.accountService = accountService
        self.profileResolver = profileResolver ?? PlatformSeriesAccountProfileResolver(accessClient: accessClient)
        self.entitlementService = entitlementService ?? SeriesPlatformEntitlementService(
            accessClient: accessClient
        )
        self.subscriptionPurchasing = subscriptionPurchasing
        self.userDefaults = userDefaults
        self.subscriptionReconciliationRetryDelaysNanoseconds = subscriptionReconciliationRetryDelaysNanoseconds
        self.sleepNanoseconds = sleepNanoseconds
        self.accountUser = currentUser
        self.accountSession = nil
        self.accessMode = .guest
        self.planTier = .free
        self.capabilities = .forMode(.guest)
        self.limits = .forMode(.guest)
        self.platformUserId = nil
        self.isAccountSessionTemporarilyUnavailable = false
        self.subscriptionOffer = nil
        self.subscriptionError = nil
        self.isSubscriptionOperationInProgress = false
        self.isWaitingForSubscriptionReconciliation = false
        self.subscriptionReconciliationSource = nil
        resolveAccessState()
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
            clearSignedOutAccountState()
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
        accessRefreshGeneration += 1
        try await accountService.signOut()
        accessRefreshGeneration += 1
        clearSignedOutAccountState()
        resolveAccessState()
    }

    func loadMonthlySubscriptionOffer() async {
        guard accountUser != nil else {
            subscriptionError = .missingAccountUser
            return
        }

        do {
            subscriptionOffer = try await subscriptionPurchasing.loadMonthlyOffer(for: accountUser)
            subscriptionError = nil
        } catch let error as SeriesSubscriptionPurchaseError {
            subscriptionError = error
        } catch {
            subscriptionError = .underlying(error.localizedDescription)
        }
    }

    func purchaseMonthlyPro() async {
        await runSubscriptionOperation(source: .purchase) {
            try await subscriptionPurchasing.purchaseMonthlyPro(for: accountUser)
        }
    }

    func restorePurchases() async {
        await runSubscriptionOperation(source: .restore) {
            try await subscriptionPurchasing.restorePurchases(for: accountUser)
        }
    }

    private func runSubscriptionOperation(
        source: SubscriptionReconciliationSource,
        _ operation: () async throws -> SeriesPurchaseOutcome
    ) async {
        guard accountUser != nil else {
            subscriptionError = .missingAccountUser
            return
        }

        isSubscriptionOperationInProgress = true
        subscriptionError = nil
        defer {
            isSubscriptionOperationInProgress = false
        }

        do {
            let outcome = try await operation()
            guard outcome.shouldRefreshAccess else { return }
            isWaitingForSubscriptionReconciliation = true
            subscriptionReconciliationSource = source
            await syncFromAccountProvider()
            await retrySubscriptionReconciliationIfNeeded()
        } catch let error as SeriesSubscriptionPurchaseError {
            if error != .purchaseCancelled {
                subscriptionError = error
            }
        } catch {
            subscriptionError = .underlying(error.localizedDescription)
        }
    }

    private func retrySubscriptionReconciliationIfNeeded() async {
        guard accessMode != .signedInPro else {
            clearSubscriptionReconciliationState()
            return
        }

        let reconciliationAccountUser = accountUser
        for delay in subscriptionReconciliationRetryDelaysNanoseconds {
            guard isWaitingForSubscriptionReconciliation else { return }
            guard accountUser == reconciliationAccountUser else { return }

            await sleepNanoseconds(delay)
            guard isWaitingForSubscriptionReconciliation else { return }
            guard accountUser == reconciliationAccountUser else { return }

            await refreshAccess()
            if accessMode == .signedInPro {
                clearSubscriptionReconciliationState()
                return
            }
        }
    }

    private func clearSubscriptionReconciliationState() {
        isWaitingForSubscriptionReconciliation = false
        subscriptionReconciliationSource = nil
    }

    private func clearSubscriptionState() {
        subscriptionOffer = nil
        subscriptionError = nil
        isSubscriptionOperationInProgress = false
        clearSubscriptionReconciliationState()
    }

    private func resolveAccessState() {
        applyResolvedAccess(entitlementService.resolveAccess(for: accountUser))
    }

    private func clearSignedOutAccountState() {
        accountUser = nil
        platformUserId = nil
        accountSession = nil
        isAccountSessionTemporarilyUnavailable = false
        clearSubscriptionState()
        clearLastKnownAccountUser()
    }

    private func applyResolvedAccess(_ resolvedAccess: SeriesResolvedAccess) {
        guard let accountUser, resolvedAccess.accessMode != .guest else {
            planTier = .free
            accessMode = .guest
            capabilities = .forMode(.guest)
            limits = .forMode(.guest)
            platformUserId = nil
            accountSession = nil
            return
        }

        platformUserId = resolvedAccess.platformUserId
        accessMode = resolvedAccess.accessMode
        planTier = resolvedAccess.planTier
        capabilities = resolvedAccess.capabilities
        limits = resolvedAccess.limits

        accountSession = SeriesAccountSession(user: accountUser, access: resolvedAccess)
        persistLastKnownAccountUser(accountUser)

        if resolvedAccess.accessMode == .signedInPro {
            clearSubscriptionReconciliationState()
        }
    }

    private static func lastKnownAccountUser(from userDefaults: UserDefaults, key: String) -> SeriesAccountUser? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SeriesAccountUser.self, from: data)
    }

    private func persistLastKnownAccountUser(_ user: SeriesAccountUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        userDefaults.set(data, forKey: lastKnownAccountUserKey)
    }

    private func clearLastKnownAccountUser() {
        userDefaults.removeObject(forKey: lastKnownAccountUserKey)
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
