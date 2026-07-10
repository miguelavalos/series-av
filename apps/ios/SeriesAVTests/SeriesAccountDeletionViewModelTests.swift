import XCTest
@testable import SeriesAV

@MainActor
final class SeriesAccountDeletionViewModelTests: XCTestCase {
    func testSignedInFreeSeriesOnlyEligibleCanRequestDeletionAndSignsOut() async {
        var didSignOut = false
        let api = MockSeriesAccountDeletionAPI(
            summary: AccountSummary(
                linkedApps: [LinkedAccountApp(appId: "seriesav", label: "Series AV")],
                access: [
                    SeriesAppAccess(
                        appId: "seriesav",
                        accessMode: .signedInFree,
                        planTier: .free,
                        capabilities: .forMode(.signedInFree),
                        limits: .forMode(.signedInFree)
                    )
                ],
                deleteAccountEligibility: AccountDeletionEligibility(status: .eligible, blockers: [], currentJob: nil)
            ),
            requestResponse: DeleteAccountRequestResponse(
                status: "completed",
                job: AccountDeletionJob(id: "job-1", status: "completed", detail: nil),
                deleteAccountEligibility: AccountDeletionEligibility(status: .completed, blockers: [], currentJob: nil)
            )
        )
        let viewModel = SeriesAccountDeletionViewModel(api: api, signOut: { didSignOut = true })

        await viewModel.load()
        viewModel.confirmationText = "DELETE"
        await viewModel.requestDeletion()

        XCTAssertTrue(viewModel.didCompleteDeletion)
        XCTAssertTrue(didSignOut)
    }

    func testWarnsButAllowsDeletionWithTuneAVLinkedApp() async {
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(
                summary: AccountSummary(
                    linkedApps: [
                        LinkedAccountApp(appId: "seriesav", label: "Series AV"),
                        LinkedAccountApp(appId: "tuneav", label: "Tune AV")
                    ]
                )
            ),
            signOut: {}
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.resolvedEligibility?.status, .eligible)
        XCTAssertEqual(viewModel.warnings.first?.type, .linkedApp)
        XCTAssertTrue(viewModel.blockers.isEmpty)
        viewModel.confirmationText = "DELETE"
        XCTAssertTrue(viewModel.canRequestDeletion)
    }

    func testWarnsButAllowsDeletionWithActivePro() async {
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(
                summary: AccountSummary(
                    access: [
                        SeriesAppAccess(
                            appId: "seriesav",
                            accessMode: .signedInPro,
                            planTier: .pro,
                            capabilities: .forMode(.signedInPro),
                            limits: .forMode(.signedInPro)
                        )
                    ]
                )
            ),
            signOut: {}
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.resolvedEligibility?.status, .eligible)
        XCTAssertEqual(viewModel.warnings.first?.type, .activeProAccess)
        XCTAssertTrue(viewModel.blockers.isEmpty)
        viewModel.confirmationText = "DELETE"
        XCTAssertTrue(viewModel.canRequestDeletion)
    }

    func testHighImpactWarningsStillAllowDeletion() async {
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(
                summary: AccountSummary(
                    deleteAccountEligibility: AccountDeletionEligibility(
                        status: .eligible,
                        blockers: [],
                        warnings: [
                            AccountDeletionBlocker(
                                type: .activeAiCredits,
                                appId: "momentsav",
                                label: "Moments AV credits",
                                detail: "Account deletion permanently removes 12 AI credits. This cannot be undone.",
                                managementUrl: nil
                            )
                        ],
                        currentJob: nil
                    )
                )
            ),
            signOut: {}
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.hasHighImpactDeletionWarnings)
        viewModel.confirmationText = "DELETE"
        XCTAssertTrue(viewModel.canRequestDeletion)
    }

    func testCompletedDeletionSignsOutLocallyOnLoad() async {
        var didSignOut = false
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(
                summary: AccountSummary(
                    deleteAccountEligibility: AccountDeletionEligibility(status: .completed, blockers: [], currentJob: nil)
                )
            ),
            signOut: { didSignOut = true }
        )

        await viewModel.load()
        await Task.yield()

        XCTAssertTrue(viewModel.didCompleteDeletion)
        XCTAssertTrue(didSignOut)
    }

    func testLoadFailureDoesNotPresentAsBlockedDeletion() async {
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(summary: AccountSummary(), fetchError: MockSeriesAccountDeletionAPI.Error.fetchFailed),
            signOut: {}
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.errorContext, .load)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.resolvedEligibility?.status, .unavailable)
        XCTAssertEqual(viewModel.blockers.first?.type, .eligibilityUnavailable)
        XCTAssertFalse(viewModel.canRequestDeletion)
    }

    func testRequestFailureIsAssociatedWithDeletionAction() async {
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(
                summary: AccountSummary(
                    deleteAccountEligibility: AccountDeletionEligibility(status: .eligible, blockers: [], currentJob: nil)
                ),
                requestError: MockSeriesAccountDeletionAPI.Error.requestFailed
            ),
            signOut: {}
        )

        await viewModel.load()
        viewModel.confirmationText = "DELETE"
        await viewModel.requestDeletion()

        XCTAssertEqual(viewModel.errorContext, .requestDeletion)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testFinalizeFailureIsAssociatedWithFinalizeAction() async {
        let job = AccountDeletionJob(id: "job-1", status: "readyToFinalize", detail: nil)
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(
                summary: AccountSummary(
                    currentDeletionJob: job,
                    deleteAccountEligibility: AccountDeletionEligibility(status: .inProgress, blockers: [], currentJob: job)
                ),
                finalizeError: MockSeriesAccountDeletionAPI.Error.finalizeFailed
            ),
            signOut: {}
        )

        await viewModel.load()
        await viewModel.finalizeDeletion()

        XCTAssertEqual(viewModel.errorContext, .finalizeDeletion)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testUnlinkFailureIsAssociatedWithUnlinkAction() async {
        let viewModel = SeriesAccountDeletionViewModel(
            api: MockSeriesAccountDeletionAPI(
                summary: AccountSummary(
                    linkedApps: [
                        LinkedAccountApp(appId: "seriesav", label: "Series AV"),
                        LinkedAccountApp(appId: "tuneav", label: "Tune AV")
                    ]
                ),
                unlinkError: MockSeriesAccountDeletionAPI.Error.unlinkFailed
            ),
            signOut: {}
        )

        await viewModel.load()
        await viewModel.unlinkCurrentApp()

        XCTAssertEqual(viewModel.errorContext, .unlink)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testOpenDeletionJobIsInProgressNotUnavailable() {
        let eligibility = SeriesAccountDeletionViewModel.conservativeEligibility(
            from: AccountSummary(
                currentDeletionJob: AccountDeletionJob(
                    id: "job-1",
                    status: "awaitingIdentityDeletion",
                    detail: "Final identity deletion is pending."
                )
            )
        )

        XCTAssertEqual(eligibility.status, .inProgress)
        XCTAssertEqual(eligibility.currentJob?.status, "awaitingIdentityDeletion")
    }

    func testPolicyPrefersBackendEligibilityOverConservativeFallback() {
        let backendEligibility = AccountDeletionEligibility(status: .eligible, blockers: [], currentJob: nil)
        let summary = AccountSummary(
            linkedApps: [
                LinkedAccountApp(appId: "seriesav", label: "Series AV"),
                LinkedAccountApp(appId: "other", label: "Other")
            ],
            deleteAccountEligibility: backendEligibility
        )

        XCTAssertEqual(
            SeriesAccountDeletionPolicy.resolvedEligibility(from: summary, copy: accountDeletionCopy),
            backendEligibility
        )
    }

    func testPolicyFallsBackToConservativeEligibilityWhenBackendOmitsIt() {
        let summary = AccountSummary(
            linkedApps: [
                LinkedAccountApp(appId: "seriesav", label: "Series AV"),
                LinkedAccountApp(appId: "other", label: "Other")
            ]
        )

        let eligibility = SeriesAccountDeletionPolicy.resolvedEligibility(from: summary, copy: accountDeletionCopy)

        XCTAssertEqual(eligibility.status, .eligible)
        XCTAssertEqual(eligibility.warnings.first?.type, .linkedApp)
        XCTAssertTrue(eligibility.blockers.isEmpty)
    }

    func testAccountSummaryDecodesAccessWithoutCapabilitiesAndLimits() throws {
        let json = """
        {
          "id": "user_1",
          "emailAddress": "review@example.com",
          "linkedApps": [{ "appId": "seriesav", "label": "Series AV" }],
          "access": [
            {
              "appId": "seriesav",
              "accessMode": "signedInFree",
              "planTier": "free"
            }
          ],
          "deleteAccountEligibility": {
            "status": "eligible",
            "blockers": [],
            "warnings": [],
            "currentJob": null
          }
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(AccountSummary.self, from: json)

        XCTAssertEqual(summary.access.first?.appId, "seriesav")
        XCTAssertEqual(summary.access.first?.capabilities, .forMode(.signedInFree))
        XCTAssertEqual(summary.access.first?.limits, .forMode(.signedInFree))
        XCTAssertEqual(summary.deleteAccountEligibility?.status, .eligible)
    }

    func testAccountSummaryDecodesNestedBackendUser() throws {
        let json = """
        {
          "user": {
            "id": "internal-user-1",
            "identityProvider": "clerk",
            "email": "review@example.com",
            "displayName": "Review User",
            "identityManaged": true,
            "deletionRequestedAt": null
          },
          "apps": [],
          "access": [],
          "billing": [],
          "linkedApps": [],
          "subscriptions": [],
          "isAdmin": false,
          "deleteAccountMode": "ready",
          "currentDeletionJob": null,
          "deleteAccountEligibility": {
            "status": "eligible",
            "blockers": [],
            "warnings": [],
            "currentJob": null
          },
          "generatedAt": "2026-06-06T14:36:59.000Z"
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(AccountSummary.self, from: json)

        XCTAssertEqual(summary.id, "internal-user-1")
        XCTAssertEqual(summary.emailAddress, "review@example.com")
        XCTAssertEqual(summary.displayName, "Review User")
        XCTAssertEqual(summary.deleteAccountEligibility?.status, .eligible)
    }

    private var accountDeletionCopy: SeriesAccountDeletionPolicy.Copy {
        SeriesAccountDeletionPolicy.Copy(
            linkedAppTitle: "Linked app",
            linkedAppDetail: "Linked app detail",
            proTitle: "Pro",
            proDetail: "Pro detail",
            subscriptionTitle: "Subscription",
            subscriptionDetail: "Subscription detail",
            jobTitle: "Job",
            unavailableTitle: "Unavailable",
            unavailableDetail: "Unavailable detail"
        )
    }
}

private struct MockSeriesAccountDeletionAPI: AccountDeletionAPI {
    enum Error: Swift.Error {
        case fetchFailed
        case requestFailed
        case finalizeFailed
        case unlinkFailed
    }

    let summary: AccountSummary
    var fetchError: Swift.Error? = nil
    var requestError: Swift.Error? = nil
    var finalizeError: Swift.Error? = nil
    var unlinkError: Swift.Error? = nil
    var requestResponse = DeleteAccountRequestResponse(status: nil, job: nil, deleteAccountEligibility: nil)
    var finalizeResponse = DeleteAccountFinalizeResponse(status: nil, job: nil, deleteAccountEligibility: nil)
    var unlinkResponse = UnlinkAppResponse(
        link: UnlinkAppResult(appId: "seriesav", remainingLinkedApps: 1, unlinked: true),
        message: nil
    )

    func fetchAccountDeletionSummary() async throws -> AccountSummary {
        if let fetchError {
            throw fetchError
        }
        return summary
    }

    func requestAccountDeletion() async throws -> DeleteAccountRequestResponse {
        if let requestError {
            throw requestError
        }
        return requestResponse
    }

    func finalizeAccountDeletion() async throws -> DeleteAccountFinalizeResponse {
        if let finalizeError {
            throw finalizeError
        }
        return finalizeResponse
    }

    func unlinkCurrentApp() async throws -> UnlinkAppResponse {
        if let unlinkError {
            throw unlinkError
        }
        return unlinkResponse
    }
}
