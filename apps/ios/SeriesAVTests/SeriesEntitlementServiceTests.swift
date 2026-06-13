import XCTest
@testable import SeriesAV

@MainActor
final class SeriesEntitlementServiceTests: XCTestCase {
    func testAccessPolicyMatchesSharedContract() throws {
        let contract = try loadAccessPolicyContract()
        let expectedModes: [(mode: SeriesAccessMode, planTier: String)] = [
            (.guest, "free"),
            (.signedInFree, "free"),
            (.signedInPro, "pro")
        ]

        XCTAssertEqual(contract.appId, "seriesav")
        XCTAssertEqual(contract.schemaVersion, 1)
        XCTAssertEqual(Set(contract.accessModes.keys), Set(expectedModes.map { $0.mode.rawValue }))

        for expectedMode in expectedModes {
            let contractMode = try XCTUnwrap(contract.accessModes[expectedMode.mode.rawValue])
            XCTAssertEqual(contractMode.planTier, expectedMode.planTier)
            XCTAssertEqual(SeriesAccessCapabilities.forMode(expectedMode.mode), contractMode.capabilities.seriesValue)
            XCTAssertEqual(SeriesAccessLimits.forMode(expectedMode.mode), contractMode.limits.seriesValue)
        }
    }

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

    private func loadAccessPolicyContract() throws -> AccessPolicyContract {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let contractURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("shared/contracts/access-policy.json")
        let data = try Data(contentsOf: contractURL)
        return try JSONDecoder().decode(AccessPolicyContract.self, from: data)
    }
}

private struct AccessPolicyContract: Decodable {
    let appId: String
    let schemaVersion: Int
    let accessModes: [String: AccessPolicyModeContract]
}

private struct AccessPolicyModeContract: Decodable {
    let planTier: String
    let capabilities: AccessCapabilitiesContract
    let limits: AccessLimitsContract
}

private struct AccessCapabilitiesContract: Decodable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canUsePremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    var seriesValue: SeriesAccessCapabilities {
        SeriesAccessCapabilities(
            isSignedIn: isSignedIn,
            canUseBackend: canUseBackend,
            canUsePremiumFeatures: canUsePremiumFeatures,
            canUseCloudSync: canUseCloudSync,
            canManagePlan: canManagePlan
        )
    }
}

private struct AccessLimitsContract: Decodable {
    let activeLibrarySeries: Int?
    let aviActionsPerDay: Int?

    var seriesValue: SeriesAccessLimits {
        SeriesAccessLimits(
            activeLibrarySeries: activeLibrarySeries,
            aviActionsPerDay: aviActionsPerDay
        )
    }
}

private struct StubSeriesAccountAccessClient: SeriesAccountAccessProviding {
    var response: SeriesMeAccessResponse
    var configured = true

    func isConfigured() -> Bool {
        configured
    }

    func fetchAccountSummary() async throws -> SeriesAccountSummary {
        SeriesAccountSummary(id: "apps-av-user-1", emailAddress: "series@example.com", displayName: "Series User")
    }

    func fetchMeAccess() async throws -> SeriesMeAccessResponse {
        response
    }
}
