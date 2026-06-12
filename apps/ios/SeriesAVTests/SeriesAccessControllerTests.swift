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
        XCTAssertEqual(controller.accessMode, .signedInPro)
        XCTAssertEqual(controller.planTier, .pro)
        XCTAssertEqual(controller.isWaitingForSubscriptionReconciliation, false)
        XCTAssertNil(controller.subscriptionReconciliationSource)
        XCTAssertNil(controller.subscriptionError)
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

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "series-av-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
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

    init(accesses: [SeriesResolvedAccess]) {
        self.accesses = accesses
        self.lastAccess = accesses.last ?? .guest
    }

    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess {
        user == nil ? .guest : lastAccess
    }

    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess {
        guard user != nil else { return .guest }
        if !accesses.isEmpty {
            lastAccess = accesses.removeFirst()
        }
        return lastAccess
    }
}

@MainActor
private final class StubSeriesSubscriptionPurchasing: SeriesSubscriptionPurchasing {
    private(set) var purchaseCount = 0
    private(set) var restoreCount = 0
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
        return offer
    }

    func purchaseMonthlyPro(for user: SeriesAccountUser?) async throws -> SeriesPurchaseOutcome {
        try await prepare(for: user)
        purchaseCount += 1
        return SeriesPurchaseOutcome(shouldRefreshAccess: true, customerUserID: user?.id ?? "")
    }

    func restorePurchases(for user: SeriesAccountUser?) async throws -> SeriesPurchaseOutcome {
        try await prepare(for: user)
        restoreCount += 1
        return SeriesPurchaseOutcome(shouldRefreshAccess: true, customerUserID: user?.id ?? "")
    }
}
