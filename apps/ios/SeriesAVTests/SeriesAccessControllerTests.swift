import AVProductAccountFoundation
import XCTest
@testable import SeriesAV

@MainActor
final class SeriesAccessControllerTests: XCTestCase {
    func testSyncUsesInternalAccountUserFromProfileResolver() async {
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(
                restoreResult: .active(SeriesAccountUser(
                    id: "provider-user-1",
                    displayName: "Provider User",
                    emailAddress: "provider@example.com"
                )),
                token: "provider-token"
            ),
            profileResolver: StubSeriesAccountProfileResolver(user: SeriesAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            )),
            entitlementService: StubSeriesEntitlementService(access: SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .pro,
                accessMode: .signedInPro,
                capabilities: .forMode(.signedInPro),
                limits: .forMode(.signedInPro)
            )),
            userDefaults: isolatedUserDefaults()
        )

        await controller.syncFromAccountProvider()

        XCTAssertEqual(controller.accountUser?.id, "apps-av-user-1")
        XCTAssertEqual(controller.accountUser?.displayName, "Apps AV User")
        XCTAssertEqual(controller.platformUserId, "apps-av-user-1")
        XCTAssertEqual(controller.accessMode, .signedInPro)
        XCTAssertEqual(controller.capabilities.canUseCloudSync, true)
    }

    func testSignedOutProviderResolvesGuestAccess() async {
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .signedOut),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: .guest),
            userDefaults: isolatedUserDefaults()
        )

        await controller.syncFromAccountProvider()

        XCTAssertNil(controller.accountUser)
        XCTAssertEqual(controller.productAccountState, .guest)
        XCTAssertEqual(controller.accessMode, .guest)
        XCTAssertEqual(controller.capabilities.canUseCloudSync, false)
    }

    func testProviderSessionDoesNotPublishProviderUserIdWhenInternalResolutionFails() async {
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(
                restoreResult: .active(SeriesAccountUser(
                    id: "user_clerk_subject",
                    displayName: "Provider User",
                    emailAddress: "provider@example.com"
                )),
                token: "provider-token"
            ),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .free,
                accessMode: .signedInFree,
                capabilities: .forMode(.signedInFree),
                limits: .forMode(.signedInFree)
            )),
            userDefaults: isolatedUserDefaults()
        )

        await controller.syncFromAccountProvider()

        XCTAssertNil(controller.accountUser)
        XCTAssertNil(controller.accountSession)
        XCTAssertEqual(controller.accessMode, .guest)
        XCTAssertTrue(controller.isAccountSessionTemporarilyUnavailable)
    }

    func testInitializesWithLastKnownAccountUser() {
        let defaults = isolatedUserDefaults()
        persistLastKnownAccountUser(
            SeriesAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            ),
            in: defaults
        )

        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .temporarilyUnavailable(nil)),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .free,
                accessMode: .signedInFree,
                capabilities: .forMode(.signedInFree),
                limits: .forMode(.signedInFree)
            )),
            userDefaults: defaults
        )

        XCTAssertEqual(controller.accountUser?.id, "apps-av-user-1")
        XCTAssertEqual(controller.accessMode, .signedInFree)
        XCTAssertEqual(controller.productAccountState, .signedIn(AVProductAccountSession(
            user: AVProductAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            )
        )))
    }

    func testLastKnownAccountUserPreservesColdStartDuringTemporarySessionFailure() async {
        let defaults = isolatedUserDefaults()
        let user = SeriesAccountUser(
            id: "apps-av-user-1",
            displayName: "Apps AV User",
            emailAddress: "apps@example.com"
        )
        persistLastKnownAccountUser(user, in: defaults)
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .temporarilyUnavailable(nil)),
            profileResolver: StubSeriesAccountProfileResolver(user: user),
            entitlementService: StubSeriesEntitlementService(access: SeriesResolvedAccess(
                platformUserId: user.id,
                planTier: .pro,
                accessMode: .signedInPro,
                capabilities: .forMode(.signedInPro),
                limits: .forMode(.signedInPro)
            )),
            userDefaults: defaults
        )

        await controller.syncFromAccountProvider()

        XCTAssertTrue(controller.isSignedIn)
        XCTAssertEqual(controller.accountUser, user)
        XCTAssertEqual(controller.accountSession?.user, user)
        XCTAssertEqual(controller.accessMode, .signedInPro)
        XCTAssertTrue(controller.isAccountSessionTemporarilyUnavailable)
    }

    func testSignedOutProviderPreservesLastKnownAccountUserAsTemporarilyUnavailable() async {
        let defaults = isolatedUserDefaults()
        let user = SeriesAccountUser(
            id: "apps-av-user-1",
            displayName: "Apps AV User",
            emailAddress: "apps@example.com"
        )
        persistLastKnownAccountUser(user, in: defaults)
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .signedOut),
            profileResolver: StubSeriesAccountProfileResolver(user: user),
            entitlementService: StubSeriesEntitlementService(access: SeriesResolvedAccess(
                platformUserId: user.id,
                planTier: .pro,
                accessMode: .signedInPro,
                capabilities: .forMode(.signedInPro),
                limits: .forMode(.signedInPro)
            )),
            userDefaults: defaults
        )

        await controller.syncFromAccountProvider()

        XCTAssertTrue(controller.isSignedIn)
        XCTAssertEqual(controller.accountUser, user)
        XCTAssertEqual(controller.accountSession?.user, user)
        XCTAssertEqual(controller.accessMode, .signedInPro)
        XCTAssertTrue(controller.isAccountSessionTemporarilyUnavailable)
    }

    func testSignOutClearsLastKnownAccountUser() async throws {
        let defaults = isolatedUserDefaults()
        persistLastKnownAccountUser(
            SeriesAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            ),
            in: defaults
        )
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .signedOut),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: .guest),
            userDefaults: defaults
        )

        try await controller.signOut()

        XCTAssertNil(defaults.data(forKey: lastKnownAccountUserKey))
        XCTAssertNil(controller.accountUser)
        XCTAssertEqual(controller.accessMode, .guest)
    }

    func testSignOutDuringAccessRefreshDoesNotApplyStaleAccess() async throws {
        let entitlementService = DelayedSeriesEntitlementService(access: SeriesResolvedAccess(
            platformUserId: "apps-av-user-1",
            planTier: .pro,
            accessMode: .signedInPro,
            capabilities: .forMode(.signedInPro),
            limits: .forMode(.signedInPro)
        ))
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(
                restoreResult: .active(SeriesAccountUser(
                    id: "provider-user-1",
                    displayName: "Provider User",
                    emailAddress: "provider@example.com"
                )),
                token: "provider-token"
            ),
            profileResolver: StubSeriesAccountProfileResolver(user: SeriesAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            )),
            entitlementService: entitlementService,
            userDefaults: isolatedUserDefaults()
        )

        let syncTask = Task {
            await controller.syncFromAccountProvider()
        }

        await entitlementService.waitUntilRefreshStarted()
        try await controller.signOut()
        await entitlementService.finishRefresh()
        await syncTask.value

        XCTAssertNil(controller.accountUser)
        XCTAssertEqual(controller.accessMode, .guest)
        XCTAssertEqual(controller.planTier, .free)
        XCTAssertNil(controller.platformUserId)
    }

    func testGuestOnboardingShowsWhenNoPromptRecorded() {
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .signedOut),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: .guest),
            userDefaults: isolatedUserDefaults(),
            guestOnboardingPolicy: SeriesGuestOnboardingPolicy(cooldown: 10),
            now: { Date(timeIntervalSince1970: 100) }
        )

        XCTAssertTrue(controller.shouldAutoShowGuestOnboarding)
    }

    func testSkipForNowSuppressesGuestOnboardingDuringCooldown() {
        let defaults = isolatedUserDefaults()
        var currentDate = Date(timeIntervalSince1970: 100)
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .signedOut),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: .guest),
            userDefaults: defaults,
            guestOnboardingPolicy: SeriesGuestOnboardingPolicy(cooldown: 10),
            now: { currentDate }
        )

        controller.skipForNow()

        XCTAssertFalse(controller.shouldAutoShowGuestOnboarding)

        currentDate = Date(timeIntervalSince1970: 111)

        XCTAssertTrue(controller.shouldAutoShowGuestOnboarding)
    }

    func testGuestOnboardingDoesNotAutoShowForSignedInAccess() async {
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(
                restoreResult: .active(SeriesAccountUser(
                    id: "apps-av-user-1",
                    displayName: "Apps AV User",
                    emailAddress: "apps@example.com"
                )),
                token: "provider-token"
            ),
            profileResolver: StubSeriesAccountProfileResolver(user: SeriesAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            )),
            entitlementService: StubSeriesEntitlementService(access: SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .free,
                accessMode: .signedInFree,
                capabilities: .forMode(.signedInFree),
                limits: .forMode(.signedInFree)
            )),
            userDefaults: isolatedUserDefaults(),
            guestOnboardingPolicy: SeriesGuestOnboardingPolicy(cooldown: 10),
            now: { Date(timeIntervalSince1970: 100) }
        )

        await controller.syncFromAccountProvider()

        XCTAssertFalse(controller.shouldAutoShowGuestOnboarding)
    }

    func testPurchaseRefreshesAccessAndClearsReconciliationWhenProArrives() async {
        let entitlementService = SequenceSeriesEntitlementService(accesses: [
            SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .free,
                accessMode: .signedInFree,
                capabilities: .forMode(.signedInFree),
                limits: .forMode(.signedInFree)
            ),
            SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .pro,
                accessMode: .signedInPro,
                capabilities: .forMode(.signedInPro),
                limits: .forMode(.signedInPro)
            )
        ])
        let subscriptionPurchasing = StubSeriesSubscriptionPurchasing()
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(
                restoreResult: .active(SeriesAccountUser(
                    id: "provider-user-1",
                    displayName: "Provider User",
                    emailAddress: "provider@example.com"
                )),
                token: "provider-token"
            ),
            profileResolver: StubSeriesAccountProfileResolver(user: SeriesAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            )),
            entitlementService: entitlementService,
            subscriptionPurchasing: subscriptionPurchasing,
            userDefaults: isolatedUserDefaults(),
            subscriptionReconciliationRetryDelaysNanoseconds: [],
            sleepNanoseconds: { _ in }
        )

        await controller.syncFromAccountProvider()
        await controller.purchaseMonthlyPro()

        XCTAssertEqual(subscriptionPurchasing.purchaseCount, 1)
        XCTAssertEqual(subscriptionPurchasing.lastPurchasedUser?.id, "apps-av-user-1")
        XCTAssertEqual(controller.accessMode, .signedInPro)
        XCTAssertEqual(controller.planTier, .pro)
        XCTAssertEqual(controller.isWaitingForSubscriptionReconciliation, false)
        XCTAssertNil(controller.subscriptionReconciliationSource)
        XCTAssertNil(controller.subscriptionError)
    }

    func testPurchaseRetriesAccountSyncUntilBackendEntitlementIsVisible() async {
        let entitlementService = SequenceSeriesEntitlementService(accesses: [
            SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .free,
                accessMode: .signedInFree,
                capabilities: .forMode(.signedInFree),
                limits: .forMode(.signedInFree)
            ),
            SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .free,
                accessMode: .signedInFree,
                capabilities: .forMode(.signedInFree),
                limits: .forMode(.signedInFree)
            ),
            SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .pro,
                accessMode: .signedInPro,
                capabilities: .forMode(.signedInPro),
                limits: .forMode(.signedInPro)
            )
        ])
        let subscriptionPurchasing = StubSeriesSubscriptionPurchasing()
        var sleepCalls: [UInt64] = []
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(
                restoreResult: .active(SeriesAccountUser(
                    id: "provider-user-1",
                    displayName: "Provider User",
                    emailAddress: "provider@example.com"
                )),
                token: "provider-token"
            ),
            profileResolver: StubSeriesAccountProfileResolver(user: SeriesAccountUser(
                id: "apps-av-user-1",
                displayName: "Apps AV User",
                emailAddress: "apps@example.com"
            )),
            entitlementService: entitlementService,
            subscriptionPurchasing: subscriptionPurchasing,
            userDefaults: isolatedUserDefaults(),
            subscriptionReconciliationRetryDelaysNanoseconds: [1, 2],
            sleepNanoseconds: { delay in
                sleepCalls.append(delay)
            }
        )

        await controller.syncFromAccountProvider()
        await controller.purchaseMonthlyPro()

        XCTAssertEqual(controller.accessMode, .signedInPro)
        XCTAssertFalse(controller.isWaitingForSubscriptionReconciliation)
        XCTAssertNil(controller.subscriptionReconciliationSource)
        XCTAssertEqual(entitlementService.refreshCount, 3)
        XCTAssertEqual(sleepCalls, [1])
    }

    func testSubscriptionOperationsUsePlatformUserIdWhenAvailable() async {
        let subscriptionPurchasing = StubSeriesSubscriptionPurchasing()
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(
                restoreResult: .active(SeriesAccountUser(
                    id: "provider-user-1",
                    displayName: "Provider User",
                    emailAddress: "provider@example.com"
                )),
                token: "provider-token"
            ),
            profileResolver: StubSeriesAccountProfileResolver(user: SeriesAccountUser(
                id: "profile-user-1",
                displayName: "Profile User",
                emailAddress: "profile@example.com"
            )),
            entitlementService: StubSeriesEntitlementService(access: SeriesResolvedAccess(
                platformUserId: "apps-av-user-1",
                planTier: .free,
                accessMode: .signedInFree,
                capabilities: .forMode(.signedInFree),
                limits: .forMode(.signedInFree)
            )),
            subscriptionPurchasing: subscriptionPurchasing,
            userDefaults: isolatedUserDefaults(),
            subscriptionReconciliationRetryDelaysNanoseconds: [],
            sleepNanoseconds: { _ in }
        )

        await controller.syncFromAccountProvider()
        await controller.loadMonthlySubscriptionOffer()
        await controller.purchaseMonthlyPro()
        await controller.restorePurchases()

        XCTAssertEqual(subscriptionPurchasing.lastLoadedOfferUser?.id, "apps-av-user-1")
        XCTAssertEqual(subscriptionPurchasing.lastPurchasedUser?.id, "apps-av-user-1")
        XCTAssertEqual(subscriptionPurchasing.lastRestoredUser?.id, "apps-av-user-1")
        XCTAssertEqual(subscriptionPurchasing.lastPurchasedUser?.displayName, "Profile User")
    }

    func testLoadMonthlySubscriptionOfferRequiresSignedInUser() async {
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .signedOut),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: .guest),
            subscriptionPurchasing: StubSeriesSubscriptionPurchasing(),
            userDefaults: isolatedUserDefaults()
        )

        await controller.loadMonthlySubscriptionOffer()

        XCTAssertEqual(controller.subscriptionError, .missingAccountUser)
    }

    func testGuestCannotStartSubscriptionPurchaseOrRestore() async {
        let subscriptionPurchasing = StubSeriesSubscriptionPurchasing()
        let controller = SeriesAccessController(
            accountService: StubSeriesAVAccountService(restoreResult: .signedOut),
            profileResolver: StubSeriesAccountProfileResolver(user: nil),
            entitlementService: StubSeriesEntitlementService(access: .guest),
            subscriptionPurchasing: subscriptionPurchasing,
            userDefaults: isolatedUserDefaults()
        )

        await controller.purchaseMonthlyPro()
        await controller.restorePurchases()

        XCTAssertEqual(controller.subscriptionError, .missingAccountUser)
        XCTAssertEqual(subscriptionPurchasing.purchaseCount, 0)
        XCTAssertEqual(subscriptionPurchasing.restoreCount, 0)
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "series-av-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private var lastKnownAccountUserKey: String {
        "seriesav.account.lastKnownUser"
    }

    private func persistLastKnownAccountUser(_ user: SeriesAccountUser, in defaults: UserDefaults) {
        let data = try! JSONEncoder().encode(user)
        defaults.set(data, forKey: lastKnownAccountUserKey)
    }
}

@MainActor
private struct StubSeriesAVAccountService: SeriesAVAccountServicing {
    var restoreResult: SeriesAVAccountSessionRestoreResult
    var token: String?

    init(
        restoreResult: SeriesAVAccountSessionRestoreResult,
        token: String? = nil
    ) {
        self.restoreResult = restoreResult
        self.token = token
    }

    var isAvailable: Bool { true }

    var providerSessionUser: SeriesAccountUser? {
        if case .active(let user) = restoreResult {
            return user
        }
        return nil
    }

    func restoreSession() async -> SeriesAVAccountSessionRestoreResult {
        restoreResult
    }

    func getToken() async throws -> String? {
        token
    }

    func signInWithApple() async throws {}

    func signInWithGoogle() async throws {}

    func signOut() async throws {}
}

@MainActor
private struct StubSeriesAccountProfileResolver: SeriesAccountProfileResolving {
    var user: SeriesAccountUser?

    func resolveCurrentAccountUser() async throws -> SeriesAccountUser {
        guard let user else {
            throw SeriesAccountProfileResolverError.missingInternalUserId
        }
        return user
    }
}

@MainActor
private struct StubSeriesEntitlementService: SeriesEntitlementServicing {
    var access: SeriesResolvedAccess

    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess {
        access
    }

    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess {
        user == nil ? .guest : access
    }
}

@MainActor
private final class SequenceSeriesEntitlementService: SeriesEntitlementServicing {
    private var accesses: [SeriesResolvedAccess]
    private var lastAccess: SeriesResolvedAccess
    private(set) var refreshCount = 0

    init(accesses: [SeriesResolvedAccess]) {
        self.accesses = accesses
        self.lastAccess = accesses.last ?? .guest
    }

    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess {
        user == nil ? .guest : lastAccess
    }

    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess {
        guard user != nil else { return .guest }
        refreshCount += 1
        if !accesses.isEmpty {
            lastAccess = accesses.removeFirst()
        }
        return lastAccess
    }
}

@MainActor
private final class DelayedSeriesEntitlementService: SeriesEntitlementServicing {
    private let access: SeriesResolvedAccess
    private var refreshStartedContinuation: CheckedContinuation<Void, Never>?
    private var finishRefreshContinuation: CheckedContinuation<Void, Never>?
    private var didStartRefresh = false

    init(access: SeriesResolvedAccess) {
        self.access = access
    }

    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess {
        user == nil ? .guest : access
    }

    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess {
        guard user != nil else { return .guest }
        didStartRefresh = true
        refreshStartedContinuation?.resume()
        refreshStartedContinuation = nil
        await withCheckedContinuation { continuation in
            finishRefreshContinuation = continuation
        }
        return access
    }

    func waitUntilRefreshStarted() async {
        guard !didStartRefresh else { return }
        await withCheckedContinuation { continuation in
            refreshStartedContinuation = continuation
        }
    }

    func finishRefresh() async {
        finishRefreshContinuation?.resume()
        finishRefreshContinuation = nil
    }
}

@MainActor
private final class StubSeriesSubscriptionPurchasing: SeriesSubscriptionPurchasing {
    private(set) var purchaseCount = 0
    private(set) var restoreCount = 0
    private(set) var lastLoadedOfferUser: SeriesAccountUser?
    private(set) var lastPurchasedUser: SeriesAccountUser?
    private(set) var lastRestoredUser: SeriesAccountUser?
    var offer = SeriesSubscriptionOffer(
        identifier: "$rc_monthly",
        productIdentifier: "com.avalsys.seriesav.pro.monthly",
        localizedTitle: "Series AV Pro",
        localizedPrice: "$2.99"
    )

    func prepare(for user: SeriesAccountUser?) async throws {
        guard user != nil else {
            throw SeriesSubscriptionPurchaseError.missingAccountUser
        }
    }

    func loadMonthlyOffer(for user: SeriesAccountUser?) async throws -> SeriesSubscriptionOffer {
        try await prepare(for: user)
        lastLoadedOfferUser = user
        return offer
    }

    func purchaseMonthlyPro(for user: SeriesAccountUser?) async throws -> SeriesPurchaseOutcome {
        try await prepare(for: user)
        purchaseCount += 1
        lastPurchasedUser = user
        return SeriesPurchaseOutcome(shouldRefreshAccess: true, customerUserID: user?.id ?? "")
    }

    func restorePurchases(for user: SeriesAccountUser?) async throws -> SeriesPurchaseOutcome {
        try await prepare(for: user)
        restoreCount += 1
        lastRestoredUser = user
        return SeriesPurchaseOutcome(shouldRefreshAccess: true, customerUserID: user?.id ?? "")
    }
}
