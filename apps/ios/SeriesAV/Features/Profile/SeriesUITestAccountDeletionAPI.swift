import Foundation

@MainActor
struct SeriesUITestAccountDeletionAPI: AccountDeletionAPI {
    private let scenario: String

    static func fromEnvironment() -> SeriesUITestAccountDeletionAPI? {
        guard let scenario = SeriesUITestEnvironment.current.accountDeletionScenario else {
            return nil
        }
        return SeriesUITestAccountDeletionAPI(scenario: scenario)
    }

    func fetchAccountDeletionSummary() async throws -> AccountSummary {
        SeriesUITestAccountDeletionScenarios.summary(for: scenario)
    }

    func requestAccountDeletion() async throws -> DeleteAccountRequestResponse {
        SeriesUITestAccountDeletionScenarios.completedRequestResponse()
    }

    func finalizeAccountDeletion() async throws -> DeleteAccountFinalizeResponse {
        SeriesUITestAccountDeletionScenarios.completedFinalizeResponse()
    }

    func unlinkCurrentApp() async throws -> UnlinkAppResponse {
        SeriesUITestAccountDeletionScenarios.unlinkResponse()
    }
}

private enum SeriesUITestAccountDeletionScenarios {
    static func summary(for scenario: String) -> AccountSummary {
        switch scenario {
        case "blocked_series":
            return AccountSummary(
                id: SeriesUITestEnvironment.accountUserId,
                emailAddress: SeriesUITestEnvironment.accountUserEmailAddress,
                displayName: SeriesUITestEnvironment.accountUserDisplayName,
                linkedApps: [
                    LinkedAccountApp(appId: "seriesav", label: "Series AV"),
                    LinkedAccountApp(appId: "tuneav", label: "Tune AV")
                ],
                deleteAccountEligibility: AccountDeletionEligibility(
                    status: .eligible,
                    blockers: [],
                    warnings: [
                        AccountDeletionBlocker(
                            type: .linkedApp,
                            appId: "tuneav",
                            label: L10n.string("accountDeletion.blocker.linkedApp.title"),
                            detail: L10n.string("accountDeletion.blocker.linkedApp.detail"),
                            managementUrl: nil
                        )
                    ],
                    currentJob: nil
                )
            )
        case "blocked_pro":
            return AccountSummary(
                id: SeriesUITestEnvironment.accountUserId,
                emailAddress: SeriesUITestEnvironment.accountUserEmailAddress,
                displayName: SeriesUITestEnvironment.accountUserDisplayName,
                linkedApps: [LinkedAccountApp(appId: "seriesav", label: "Series AV")],
                access: [
                    SeriesAppAccess(
                        appId: "seriesav",
                        accessMode: .signedInPro,
                        planTier: .pro,
                        capabilities: .forMode(.signedInPro),
                        limits: .forMode(.signedInPro)
                    )
                ],
                deleteAccountEligibility: AccountDeletionEligibility(
                    status: .eligible,
                    blockers: [],
                    warnings: [
                        AccountDeletionBlocker(
                            type: .activeProAccess,
                            appId: "seriesav",
                            label: L10n.string("accountDeletion.blocker.pro.title"),
                            detail: L10n.string("accountDeletion.blocker.pro.detail"),
                            managementUrl: nil
                        )
                    ],
                    currentJob: nil
                )
            )
        case "in_progress":
            let job = AccountDeletionJob(id: "series-ui-test-job", status: "readyToFinalize", detail: nil)
            return AccountSummary(
                id: SeriesUITestEnvironment.accountUserId,
                emailAddress: SeriesUITestEnvironment.accountUserEmailAddress,
                displayName: SeriesUITestEnvironment.accountUserDisplayName,
                linkedApps: [LinkedAccountApp(appId: "seriesav", label: "Series AV")],
                currentDeletionJob: job,
                deleteAccountEligibility: AccountDeletionEligibility(status: .inProgress, blockers: [], currentJob: job)
            )
        case "completed":
            return AccountSummary(
                id: SeriesUITestEnvironment.accountUserId,
                emailAddress: SeriesUITestEnvironment.accountUserEmailAddress,
                displayName: SeriesUITestEnvironment.accountUserDisplayName,
                deleteAccountEligibility: AccountDeletionEligibility(status: .completed, blockers: [], currentJob: nil)
            )
        default:
            return AccountSummary(
                id: SeriesUITestEnvironment.accountUserId,
                emailAddress: SeriesUITestEnvironment.accountUserEmailAddress,
                displayName: SeriesUITestEnvironment.accountUserDisplayName,
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
            )
        }
    }

    static func completedRequestResponse() -> DeleteAccountRequestResponse {
        DeleteAccountRequestResponse(
            status: "completed",
            job: AccountDeletionJob(id: "series-ui-test-job", status: "completed", detail: nil),
            deleteAccountEligibility: AccountDeletionEligibility(status: .completed, blockers: [], currentJob: nil)
        )
    }

    static func completedFinalizeResponse() -> DeleteAccountFinalizeResponse {
        DeleteAccountFinalizeResponse(
            status: "completed",
            job: AccountDeletionJob(id: "series-ui-test-job", status: "completed", detail: nil),
            deleteAccountEligibility: AccountDeletionEligibility(status: .completed, blockers: [], currentJob: nil)
        )
    }

    static func unlinkResponse() -> UnlinkAppResponse {
        UnlinkAppResponse(
            link: UnlinkAppResult(appId: "seriesav", remainingLinkedApps: 1, unlinked: true),
            message: L10n.string("accountDeletion.unlinked.detail")
        )
    }
}
