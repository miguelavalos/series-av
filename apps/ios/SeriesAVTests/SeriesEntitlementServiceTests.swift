import XCTest
@testable import SeriesAV

@MainActor
final class SeriesEntitlementServiceTests: XCTestCase {
    func testGuestIsLocalOnlyAndUsesAcceptedLimits() {
        let access = SeriesLocalEntitlementService().resolveAccess(for: nil)

        XCTAssertEqual(access.accessMode, .guest)
        XCTAssertEqual(access.planTier, .free)
        XCTAssertEqual(access.capabilities.isSignedIn, false)
        XCTAssertEqual(access.capabilities.canUseBackend, true)
        XCTAssertEqual(access.capabilities.canUseCloudSync, false)
        XCTAssertEqual(access.limits.activeLibrarySeries, 25)
        XCTAssertEqual(access.limits.aviActionsPerDay, 5)
    }

    func testSignedInFreeUsesBackendButDoesNotUseCloudSync() {
        let access = SeriesLocalEntitlementService().resolveAccess(for: user())

        XCTAssertEqual(access.accessMode, .signedInFree)
        XCTAssertEqual(access.planTier, .free)
        XCTAssertEqual(access.capabilities.isSignedIn, true)
        XCTAssertEqual(access.capabilities.canUseBackend, true)
        XCTAssertEqual(access.capabilities.canUseCloudSync, false)
        XCTAssertEqual(access.limits.activeLibrarySeries, 75)
        XCTAssertEqual(access.limits.aviActionsPerDay, 15)
    }

    func testRefreshUsesSeriesAVEntryAndAppsAVUserId() async {
        let service = SeriesPlatformEntitlementService(
            accessClient: StubSeriesAccountAccessClient(response: SeriesMeAccessResponse(
                viewer: SeriesMeAccessViewer(
                    isAuthenticated: true,
                    userId: "apps-av-user-1",
                    identityProvider: "clerk"
                ),
                apps: [
                    SeriesAppAccess(
                        appId: "tuneav",
                        accessMode: .signedInFree,
                        planTier: .free,
                        capabilities: .forMode(.signedInFree),
                        limits: .forMode(.signedInFree)
                    ),
                    SeriesAppAccess(
                        appId: "seriesav",
                        accessMode: .signedInPro,
                        planTier: .pro,
                        capabilities: .forMode(.signedInPro),
                        limits: .forMode(.signedInPro)
                    )
                ]
            ))
        )

        let access = await service.refreshAccess(for: user())

        XCTAssertEqual(access.platformUserId, "apps-av-user-1")
        XCTAssertEqual(access.accessMode, .signedInPro)
        XCTAssertEqual(access.planTier, .pro)
        XCTAssertEqual(access.capabilities.canUsePremiumFeatures, true)
        XCTAssertEqual(access.capabilities.canUseCloudSync, true)
        XCTAssertEqual(access.limits.activeLibrarySeries, 1_000)
        XCTAssertNil(access.limits.aviActionsPerDay)
    }

    func testRefreshFallsBackToSignedInFreeWhenSeriesEntryIsMissing() async {
        let service = SeriesPlatformEntitlementService(
            accessClient: StubSeriesAccountAccessClient(response: SeriesMeAccessResponse(
                viewer: SeriesMeAccessViewer(
                    isAuthenticated: true,
                    userId: "apps-av-user-1",
                    identityProvider: "clerk"
                ),
                apps: [
                    SeriesAppAccess(
                        appId: "tuneav",
                        accessMode: .signedInPro,
                        planTier: .pro,
                        capabilities: .forMode(.signedInPro),
                        limits: .forMode(.signedInPro)
                    )
                ]
            ))
        )

        let access = await service.refreshAccess(for: user())

        XCTAssertNil(access.platformUserId)
        XCTAssertEqual(access.accessMode, .signedInFree)
        XCTAssertEqual(access.capabilities.canUseCloudSync, false)
    }

    private func user() -> SeriesAccountUser {
        SeriesAccountUser(
            id: "provider-user-1",
            displayName: "Series User",
            emailAddress: "series@example.com"
        )
    }
}

private struct StubSeriesAccountAccessClient: SeriesAccountAccessProviding {
    var response: SeriesMeAccessResponse
    var configured = true

    func isConfigured() -> Bool {
        configured
    }

    func fetchMeAccess() async throws -> SeriesMeAccessResponse {
        response
    }
}
