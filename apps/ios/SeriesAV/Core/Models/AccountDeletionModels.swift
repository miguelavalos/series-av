import Foundation

struct AccountSummary: Decodable, Equatable {
    let id: String?
    let emailAddress: String?
    let displayName: String?
    let linkedApps: [AccountLinkedApp]
    let access: AccountAccessSummary?
    let billing: AccountBillingSummary?
    let currentDeletionJob: AccountDeletionJob?
    let deleteAccountEligibility: AccountDeletionEligibility?

    enum CodingKeys: String, CodingKey {
        case id
        case emailAddress
        case displayName
        case linkedApps
        case access
        case billing
        case currentDeletionJob
        case deleteAccountEligibility
    }

    init(
        id: String? = nil,
        emailAddress: String? = nil,
        displayName: String? = nil,
        linkedApps: [AccountLinkedApp] = [],
        access: AccountAccessSummary? = nil,
        billing: AccountBillingSummary? = nil,
        currentDeletionJob: AccountDeletionJob? = nil,
        deleteAccountEligibility: AccountDeletionEligibility? = nil
    ) {
        self.id = id
        self.emailAddress = emailAddress
        self.displayName = displayName
        self.linkedApps = linkedApps
        self.access = access
        self.billing = billing
        self.currentDeletionJob = currentDeletionJob
        self.deleteAccountEligibility = deleteAccountEligibility
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        emailAddress = try container.decodeIfPresent(String.self, forKey: .emailAddress)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        linkedApps = try container.decodeIfPresent([AccountLinkedApp].self, forKey: .linkedApps) ?? []
        access = try container.decodeIfPresent(AccountAccessSummary.self, forKey: .access)
        billing = try container.decodeIfPresent(AccountBillingSummary.self, forKey: .billing)
        currentDeletionJob = try container.decodeIfPresent(AccountDeletionJob.self, forKey: .currentDeletionJob)
        deleteAccountEligibility = try container.decodeIfPresent(AccountDeletionEligibility.self, forKey: .deleteAccountEligibility)
    }
}

struct AccountDeletionEligibility: Decodable, Equatable {
    let status: AccountDeletionEligibilityStatus
    let blockers: [AccountDeletionBlocker]
    let currentJob: AccountDeletionJob?

    enum CodingKeys: String, CodingKey {
        case status
        case blockers
        case currentJob
    }

    init(status: AccountDeletionEligibilityStatus, blockers: [AccountDeletionBlocker] = [], currentJob: AccountDeletionJob? = nil) {
        self.status = status
        self.blockers = blockers
        self.currentJob = currentJob
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(AccountDeletionEligibilityStatus.self, forKey: .status) ?? .unknown
        blockers = try container.decodeIfPresent([AccountDeletionBlocker].self, forKey: .blockers) ?? []
        currentJob = try container.decodeIfPresent(AccountDeletionJob.self, forKey: .currentJob)
    }
}

enum AccountDeletionEligibilityStatus: String, Decodable, Equatable {
    case eligible
    case blocked
    case inProgress
    case completed
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = AccountDeletionEligibilityStatus(rawValue: rawValue) ?? .unknown
    }
}

struct AccountDeletionBlocker: Decodable, Identifiable, Equatable {
    let type: AccountDeletionBlockerType
    let appId: String?
    let label: String
    let detail: String?
    let managementUrl: URL?

    var id: String {
        [
            type.rawValue,
            appId ?? "shared",
            label,
            detail ?? ""
        ].joined(separator: "-")
    }
}

enum AccountDeletionBlockerType: String, Decodable, Equatable {
    case linkedApp
    case activeProAccess
    case activeBillingSubscription
    case identityProvider
    case unavailable
    case deletionInProgress
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = AccountDeletionBlockerType(rawValue: rawValue) ?? .unknown
    }
}

struct AccountDeletionJob: Decodable, Equatable {
    let id: String?
    let status: AccountDeletionJobStatus
    let message: String?
    let createdAt: String?
    let updatedAt: String?
}

enum AccountDeletionJobStatus: String, Decodable, Equatable {
    case blocked
    case requested
    case processing
    case awaitingIdentityDeletion
    case completed
    case failed
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = AccountDeletionJobStatus(rawValue: rawValue) ?? .unknown
    }
}

struct DeleteAccountRequestResponse: Decodable, Equatable {
    let deletionJob: AccountDeletionJob?
    let currentJob: AccountDeletionJob?
    let deleteAccountEligibility: AccountDeletionEligibility?
}

struct DeleteAccountFinalizeResponse: Decodable, Equatable {
    let deletionJob: AccountDeletionJob?
    let currentJob: AccountDeletionJob?
    let deleteAccountEligibility: AccountDeletionEligibility?
}

struct UnlinkAppResponse: Decodable, Equatable {
    let link: UnlinkAppResult
    let message: String?
}

struct UnlinkAppResult: Decodable, Equatable {
    let appId: String
    let remainingLinkedApps: Int
    let unlinked: Bool
}

struct AccountLinkedApp: Decodable, Equatable {
    let appId: String
    let label: String?
}

struct AccountAccessSummary: Decodable, Equatable {
    let apps: [AccountAppAccess]

    enum CodingKeys: String, CodingKey {
        case apps
    }

    init(apps: [AccountAppAccess] = []) {
        self.apps = apps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apps = try container.decodeIfPresent([AccountAppAccess].self, forKey: .apps) ?? []
    }
}

struct AccountAppAccess: Decodable, Equatable {
    let appId: String
    let planTier: String?
    let accessMode: String?
    let isPro: Bool?
}

struct AccountBillingSummary: Decodable, Equatable {
    let subscriptions: [AccountBillingSubscription]

    enum CodingKeys: String, CodingKey {
        case subscriptions
    }

    init(subscriptions: [AccountBillingSubscription] = []) {
        self.subscriptions = subscriptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subscriptions = try container.decodeIfPresent([AccountBillingSubscription].self, forKey: .subscriptions) ?? []
    }
}

struct AccountBillingSubscription: Decodable, Equatable {
    let status: String?
    let appId: String?
    let managementUrl: URL?
}
