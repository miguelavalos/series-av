import Foundation

struct SeriesMeAccessResponse: Decodable, Equatable {
    let viewer: SeriesMeAccessViewer?
    let apps: [SeriesAppAccess]
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

    func fetchMeAccess() async throws -> SeriesMeAccessResponse {
        let (data, _) = try await apiClient.requestData(path: "/v1/me/access")
        return try decoder.decode(SeriesMeAccessResponse.self, from: data)
    }
}
