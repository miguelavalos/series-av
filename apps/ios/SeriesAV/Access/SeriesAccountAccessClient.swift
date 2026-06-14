import Foundation

@MainActor
protocol AccountDeletionAPI {
    func fetchAccountDeletionSummary() async throws -> AccountSummary
    func requestAccountDeletion() async throws -> DeleteAccountRequestResponse
    func finalizeAccountDeletion() async throws -> DeleteAccountFinalizeResponse
    func unlinkCurrentApp() async throws -> UnlinkAppResponse
}

struct SeriesMeAccessResponse: Decodable, Equatable {
    let viewer: SeriesMeAccessViewer?
    let apps: [SeriesAppAccess]
}

struct SeriesAccountSummary: Decodable, Equatable {
    let id: String?
    let emailAddress: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case emailAddress
        case email
        case displayName
        case name
        case user
    }

    init(
        id: String? = nil,
        emailAddress: String? = nil,
        displayName: String? = nil
    ) {
        self.id = id
        self.emailAddress = emailAddress
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let user = try container.decodeIfPresent(SeriesAccountSummaryUser.self, forKey: .user)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? user?.id
        emailAddress = try container.decodeIfPresent(String.self, forKey: .emailAddress)
            ?? container.decodeIfPresent(String.self, forKey: .email)
            ?? user?.emailAddress
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? user?.displayName
    }
}

private struct SeriesAccountSummaryUser: Decodable, Equatable {
    let id: String?
    let emailAddress: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailAddress
        case displayName
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        emailAddress = try container.decodeIfPresent(String.self, forKey: .emailAddress)
            ?? container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
    }
}

struct SeriesMeAccessViewer: Decodable, Equatable {
    let isAuthenticated: Bool
    let userId: String?
    let identityProvider: String?
}

struct SeriesAppAccess: Decodable, Equatable {
    let appId: String
    let accessMode: SeriesAccessMode
    let planTier: SeriesPlanTier
    let capabilities: SeriesAccessCapabilities
    let limits: SeriesAccessLimits

    enum CodingKeys: String, CodingKey {
        case appId
        case accessMode
        case planTier
        case capabilities
        case limits
    }

    init(
        appId: String,
        accessMode: SeriesAccessMode,
        planTier: SeriesPlanTier,
        capabilities: SeriesAccessCapabilities,
        limits: SeriesAccessLimits
    ) {
        self.appId = appId
        self.accessMode = accessMode
        self.planTier = planTier
        self.capabilities = capabilities
        self.limits = limits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appId = try container.decode(String.self, forKey: .appId)
        accessMode = try container.decode(SeriesAccessMode.self, forKey: .accessMode)
        planTier = try container.decode(SeriesPlanTier.self, forKey: .planTier)
        capabilities = try container.decodeIfPresent(SeriesAccessCapabilities.self, forKey: .capabilities)
            ?? .forMode(accessMode)
        limits = try container.decodeIfPresent(SeriesAccessLimits.self, forKey: .limits)
            ?? .forMode(accessMode)
    }
}

@MainActor
protocol SeriesAccountAccessProviding {
    func isConfigured() -> Bool
    func fetchAccountSummary() async throws -> SeriesAccountSummary
    func fetchMeAccess() async throws -> SeriesMeAccessResponse
}

@MainActor
struct SeriesAccountAccessClient: SeriesAccountAccessProviding, Sendable {
    var apiClient: SeriesAVAPIClient
    var decoder: JSONDecoder

    init(
        apiClient: SeriesAVAPIClient = SeriesAVAPIClient(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.apiClient = apiClient
        self.decoder = decoder
    }

    func isConfigured() -> Bool {
        apiClient.baseURL != nil
    }

    func fetchAccountSummary() async throws -> SeriesAccountSummary {
        let (data, _) = try await apiClient.requestData(path: "/v1/me")
        return try decoder.decode(SeriesAccountSummary.self, from: data)
    }

    func fetchMeAccess() async throws -> SeriesMeAccessResponse {
        let (data, _) = try await apiClient.requestData(path: "/v1/me/access")
        return try decoder.decode(SeriesMeAccessResponse.self, from: data)
    }
}

extension SeriesAccountAccessClient: AccountDeletionAPI {
    func fetchAccountDeletionSummary() async throws -> AccountSummary {
        let (data, _) = try await apiClient.requestData(path: "/v1/me")
        return try decoder.decode(AccountSummary.self, from: data)
    }

    func requestAccountDeletion() async throws -> DeleteAccountRequestResponse {
        let (data, _) = try await apiClient.requestData(path: "/v1/me/delete-account-request", method: "POST")
        return try decoder.decode(DeleteAccountRequestResponse.self, from: data)
    }

    func finalizeAccountDeletion() async throws -> DeleteAccountFinalizeResponse {
        let (data, _) = try await apiClient.requestData(path: "/v1/me/delete-account-finalize", method: "POST")
        return try decoder.decode(DeleteAccountFinalizeResponse.self, from: data)
    }

    func unlinkCurrentApp() async throws -> UnlinkAppResponse {
        let (data, _) = try await apiClient.requestData(path: "/v1/apps/seriesav/link", method: "DELETE")
        return try decoder.decode(UnlinkAppResponse.self, from: data)
    }
}
