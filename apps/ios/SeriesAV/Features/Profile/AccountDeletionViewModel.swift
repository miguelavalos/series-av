import Foundation

@MainActor
protocol AccountDeletionAPI {
    func fetchAccountSummary() async throws -> AccountSummary
    func requestAccountDeletion() async throws -> DeleteAccountRequestResponse
    func finalizeAccountDeletion() async throws -> DeleteAccountFinalizeResponse
    func unlinkCurrentApp() async throws -> UnlinkAppResponse
}

extension SeriesAVAPIClient: AccountDeletionAPI {}

@MainActor
final class AccountDeletionViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case blocked(blockers: [AccountDeletionBlocker], warnings: [AccountDeletionBlocker], canUnlinkCurrentApp: Bool)
        case eligible(warnings: [AccountDeletionBlocker])
        case inProgress(AccountDeletionJob?, warnings: [AccountDeletionBlocker])
        case completed
        case unlinked(String)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published var confirmationText = ""
    @Published private(set) var isSubmitting = false

    private let api: AccountDeletionAPI
    private let signOut: () async -> Void

    init(api: AccountDeletionAPI, signOut: @escaping () async -> Void) {
        self.api = api
        self.signOut = signOut
    }

    var canRequestDeletion: Bool {
        if case .eligible = state {
            return confirmationText == "DELETE" && !isSubmitting
        }
        return false
    }

    var canUnlinkCurrentApp: Bool {
        if case .blocked(_, _, let canUnlinkCurrentApp) = state {
            return canUnlinkCurrentApp && !isSubmitting
        }
        return false
    }

    func load() async {
        state = .loading
        do {
            let summary = try await api.fetchAccountSummary()
            state = Self.resolveState(from: summary)
            if state == .completed {
                await signOut()
            }
        } catch {
            state = .blocked(
                blockers: [Self.unavailableBlocker(detail: error.localizedDescription)],
                warnings: [],
                canUnlinkCurrentApp: false
            )
        }
    }

    func requestDeletion() async {
        guard canRequestDeletion else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response = try await api.requestAccountDeletion()
            if let eligibility = response.deleteAccountEligibility {
                state = Self.resolveState(from: eligibility)
            } else if let job = response.deletionJob ?? response.currentJob {
                state = Self.resolveState(from: job)
            } else {
                await load()
            }
            if state == .completed {
                await signOut()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func finalizeDeletion() async {
        guard case .inProgress(let job, _) = state, job?.status == .awaitingIdentityDeletion else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response = try await api.finalizeAccountDeletion()
            if let eligibility = response.deleteAccountEligibility {
                state = Self.resolveState(from: eligibility)
            } else if let job = response.deletionJob ?? response.currentJob {
                state = Self.resolveState(from: job)
            } else {
                await load()
            }
            if state == .completed {
                await signOut()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func unlinkCurrentApp() async {
        guard canUnlinkCurrentApp else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response = try await api.unlinkCurrentApp()
            let message = response.message
                ?? "This app has been unlinked from Apps AV. Your shared Apps AV account still exists because other Apps AV apps remain linked."
            state = .unlinked(message)
            await signOut()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    static func resolveState(from summary: AccountSummary) -> State {
        if let eligibility = summary.deleteAccountEligibility {
            return resolveState(from: eligibility, summary: summary)
        }
        if let job = summary.currentDeletionJob {
            return resolveState(from: job)
        }

        let warnings = fallbackLinkedAppWarnings(from: summary.linkedApps)
            + fallbackProWarnings(from: summary.access)
            + fallbackBillingWarnings(from: summary.billing)
        return .eligible(warnings: warnings)
    }

    static func resolveState(from eligibility: AccountDeletionEligibility) -> State {
        resolveState(from: eligibility, summary: nil)
    }

    static func resolveState(from eligibility: AccountDeletionEligibility, summary: AccountSummary?) -> State {
        switch eligibility.status {
        case .eligible:
            return .eligible(warnings: eligibility.warnings)
        case .blocked:
            return .blocked(
                blockers: eligibility.blockers,
                warnings: eligibility.warnings,
                canUnlinkCurrentApp: summary.map(canUnlinkCurrentApp(from:)) ?? false
            )
        case .inProgress:
            return .inProgress(eligibility.currentJob, warnings: eligibility.warnings)
        case .completed:
            return .completed
        case .unknown:
            return .blocked(
                blockers: [unavailableBlocker(detail: "Apps AV returned an unknown deletion status.")],
                warnings: eligibility.warnings,
                canUnlinkCurrentApp: summary.map(canUnlinkCurrentApp(from:)) ?? false
            )
        }
    }

    static func resolveState(from job: AccountDeletionJob) -> State {
        switch job.status {
        case .completed:
            return .completed
        case .blocked:
            return .blocked(
                blockers: [
                    AccountDeletionBlocker(
                        type: .deletionInProgress,
                        appId: nil,
                        label: "Deletion is blocked",
                        detail: job.message,
                        managementUrl: nil
                    )
                ],
                warnings: [],
                canUnlinkCurrentApp: false
            )
        case .queued, .requested, .processing, .awaitingIdentityDeletion:
            return .inProgress(job, warnings: [])
        case .failed, .unknown:
            return .blocked(
                blockers: [unavailableBlocker(detail: job.message ?? "Apps AV could not safely confirm deletion status.")],
                warnings: [],
                canUnlinkCurrentApp: false
            )
        }
    }

    private static func fallbackLinkedAppWarnings(from linkedApps: [AccountLinkedApp]) -> [AccountDeletionBlocker] {
        linkedApps
            .filter { $0.appId != "seriesav" && $0.status != "available" }
            .map {
                AccountDeletionBlocker(
                    type: .linkedApp,
                    appId: $0.appId,
                    label: $0.label ?? "Linked Apps AV app",
                    detail: "Deleting this shared Apps AV account also removes this app link and its suite-owned data.",
                    managementUrl: nil
                )
            }
    }

    private static func fallbackProWarnings(from access: AccountAccessSummary?) -> [AccountDeletionBlocker] {
        guard let access else { return [] }
        return access.apps.compactMap { appAccess in
            let isPro = appAccess.isPro == true
                || appAccess.planTier?.lowercased() == "pro"
                || appAccess.accessMode?.lowercased().contains("pro") == true
            guard isPro else { return nil }
            return AccountDeletionBlocker(
                type: .activeProAccess,
                appId: appAccess.appId,
                label: "Active Pro access",
                detail: "This Pro access will be removed from Apps AV records. Billing may continue through the provider until cancelled or expired.",
                managementUrl: nil
            )
        }
    }

    private static func fallbackBillingWarnings(from billing: AccountBillingSummary?) -> [AccountDeletionBlocker] {
        guard let billing else { return [] }
        let warningStatuses = Set(["active", "trialing", "pastdue", "past_due"])
        return billing.subscriptions.compactMap { subscription in
            let status = subscription.status?.lowercased()
            guard let status, warningStatuses.contains(status) else { return nil }
            return AccountDeletionBlocker(
                type: .activeBillingSubscription,
                appId: subscription.appId,
                label: "Active subscription",
                detail: "Billing may continue through the provider until the subscription is cancelled or expires.",
                managementUrl: subscription.managementUrl
            )
        }
    }

    private static func unavailableBlocker(detail: String) -> AccountDeletionBlocker {
        AccountDeletionBlocker(
            type: .unavailable,
            appId: nil,
            label: "Deletion status unavailable",
            detail: detail,
            managementUrl: nil
        )
    }

    private static func canUnlinkCurrentApp(from summary: AccountSummary) -> Bool {
        let currentAppId = "seriesav"
        let linkedApps = summary.linkedApps.filter { $0.appId != "avapps" && $0.status != "available" }
        let isCurrentAppLinked = linkedApps.contains { $0.appId == currentAppId }
        let hasOtherLinkedApps = linkedApps.contains { $0.appId != currentAppId }
        let currentAppAccess = summary.access?.apps.first { $0.appId == currentAppId }
        let currentAppIsPro = currentAppAccess?.isPro == true
            || currentAppAccess?.planTier?.lowercased() == "pro"
            || currentAppAccess?.accessMode?.lowercased().contains("pro") == true

        return isCurrentAppLinked && hasOtherLinkedApps && !currentAppIsPro
    }
}
