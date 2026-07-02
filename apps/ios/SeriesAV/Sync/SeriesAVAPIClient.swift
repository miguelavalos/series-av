import Foundation

enum SeriesAVAPIClientError: Error, Equatable {
    case missingBaseURL
    case missingToken
    case requestFailed(statusCode: Int)
}

struct SeriesAVAPIClient: Sendable {
    var baseURL: URL?
    var tokenProvider: @Sendable () async throws -> String?
    var urlSession: URLSession

    init(
        baseURL: URL? = AppConfig.seriesAPIBaseURL,
        urlSession: URLSession = .shared,
        tokenProvider: @escaping @Sendable () async throws -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.tokenProvider = tokenProvider
    }

    func requestData(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:],
        requiresAuth: Bool = true
    ) async throws -> (Data, String?) {
        guard let baseURL else {
            throw SeriesAVAPIClientError.missingBaseURL
        }

        let requestURL = URL(string: path, relativeTo: baseURL)?.absoluteURL ?? baseURL.appending(path: path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.httpBody = body
        if let token = try await tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if requiresAuth {
            throw SeriesAVAPIClientError.missingToken
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SeriesAVAPIClientError.requestFailed(statusCode: -1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SeriesAVAPIClientError.requestFailed(statusCode: httpResponse.statusCode)
        }
        return (data, httpResponse.value(forHTTPHeaderField: "ETag"))
    }
}

@MainActor
protocol SeriesPromotionCodeRedeeming: Sendable {
    func redeemPromotionCode(_ code: String) async throws -> SeriesPromoCodeRedemptionResponse
}

@MainActor
struct SeriesPromoCodeClient: SeriesPromotionCodeRedeeming, Sendable {
    var appId: String
    var baseURL: URL?
    var urlSession: URLSession
    var tokenProvider: @Sendable () async throws -> String?
    var encoder: JSONEncoder
    var decoder: JSONDecoder

    init(
        appId: String = "seriesav",
        baseURL: URL? = AppConfig.apiBaseURL,
        urlSession: URLSession = .shared,
        tokenProvider: @escaping @Sendable () async throws -> String? = { nil },
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.appId = appId
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.tokenProvider = tokenProvider
        self.encoder = encoder
        self.decoder = decoder
    }

    func redeemPromotionCode(_ code: String) async throws -> SeriesPromoCodeRedemptionResponse {
        guard let baseURL else {
            throw SeriesPromoCodeClientError.missingBaseURL
        }
        let normalizedAppId = appId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAppId.isEmpty else {
            throw SeriesPromoCodeClientError.missingAppID
        }
        guard let token = try await tokenProvider(), !token.isEmpty else {
            throw SeriesPromoCodeClientError.missingToken
        }

        let encodedAppId = normalizedAppId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalizedAppId
        let path = "/v1/apps/\(encodedAppId)/promotions/redeem"
        let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
            ?? baseURL.appending(path: "v1/apps/\(encodedAppId)/promotions/redeem")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(normalizedAppId, forHTTPHeaderField: "x-appsav-app-id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(SeriesPromoCodeRedeemRequest(code: code))

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SeriesPromoCodeClientError.requestFailed(statusCode: -1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SeriesPromoCodeClientError.decode(
                from: data,
                statusCode: httpResponse.statusCode
            )
        }

        return try decoder.decode(SeriesPromoCodeRedemptionResponse.self, from: data)
    }
}

enum SeriesPromoCodeClientError: LocalizedError, Equatable {
    case missingAppID
    case missingBaseURL
    case missingToken
    case requestFailed(statusCode: Int)
    case server(code: String, message: String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAppID, .missingBaseURL:
            L10n.string("subscription.error.redemptionUnavailable")
        case .missingToken:
            L10n.string("accountAPI.error.missingToken")
        case .requestFailed:
            L10n.string("promo.error.redeemFailed")
        case .server(_, let message, _):
            message
        }
    }

    static func decode(from data: Data, statusCode: Int) -> SeriesPromoCodeClientError {
        if let decoded = try? JSONDecoder().decode(SeriesPromoCodeErrorResponse.self, from: data) {
            return .server(
                code: decoded.error.code,
                message: decoded.error.message,
                statusCode: statusCode
            )
        }
        return .requestFailed(statusCode: statusCode)
    }
}

private struct SeriesPromoCodeRedeemRequest: Encodable {
    let code: String
}

struct SeriesPromoCodeRedemptionResponse: Decodable, Equatable {
    let appId: String
    let userId: String
    let code: String
    let campaignId: String
    let redemptionId: String
    let entitlement: SeriesPromoCodeEntitlement
}

struct SeriesPromoCodeEntitlement: Decodable, Equatable {
    let appId: String
    let userId: String
    let planTier: SeriesPlanTier
    let accessMode: SeriesAccessMode
    let status: String
    let source: String
}

private struct SeriesPromoCodeErrorResponse: Decodable {
    struct APIError: Decodable {
        let code: String
        let message: String
    }

    let error: APIError
}

enum SeriesEpisodeGuideRelativeState: String, Codable, Equatable, Sendable {
    case watched
    case current
    case next
    case pending
}

enum SeriesEpisodeGuideReliability: String, Codable, Equatable, Sendable {
    case reliable
    case partial
}

struct SeriesEpisodeGuideItem: Codable, Equatable, Sendable {
    var seasonNumber: Int
    var episodeNumber: Int
    var title: String?
    var airDate: String?
    var reliability: SeriesEpisodeGuideReliability
    var relativeState: SeriesEpisodeGuideRelativeState
    var supportedActions: [String]

    var cursor: SeriesEpisodeCursor {
        SeriesEpisodeCursor(seasonNumber: seasonNumber, episodeNumber: episodeNumber)
    }
}

struct SeriesEpisodesResponse: Codable, Equatable, Sendable {
    var seriesId: String
    var items: [SeriesEpisodeGuideItem]
    var generatedAt: Date
}

struct SeriesCatalogResolveRequest: Codable, Equatable, Sendable {
    var query: String
    var year: Int?
    var preferredLanguage: String?
    var existingProviderRefs: [SeriesProviderRef]

    init(query: String, year: Int? = nil, preferredLanguage: String? = nil, existingProviderRefs: [SeriesProviderRef] = []) {
        self.query = query
        self.year = year
        self.preferredLanguage = preferredLanguage
        self.existingProviderRefs = existingProviderRefs
    }
}

struct SeriesCatalogResolveCandidate: Codable, Equatable, Sendable {
    struct Series: Codable, Equatable, Sendable {
        var id: String
        var title: String
        var year: Int?
        var posterUrl: URL?
        var genres: [String]
        var providerRefs: [SeriesProviderRef]
    }

    var series: Series
    var matchConfidence: String
}

struct SeriesCatalogResolveResponse: Codable, Equatable, Sendable {
    var candidates: [SeriesCatalogResolveCandidate]
    var generatedAt: Date
}

struct SeriesCatalogSearchResponse: Codable, Equatable, Sendable {
    struct Pagination: Codable, Equatable, Sendable {
        var total: Int?
        var limit: Int
        var returned: Int
        var hasMore: Bool
        var nextCursor: String?
        var totalIsExact: Bool
    }

    var results: [SeriesCatalogItem]
    var pagination: Pagination?
    var source: String
    var generatedAt: Date
}

struct SeriesDetailResponse: Codable, Equatable, Sendable {
    var summary: SeriesCatalogItem
    var generatedAt: Date

    init(summary: SeriesCatalogItem, generatedAt: Date) {
        self.summary = summary
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let summary = try container.decodeIfPresent(SeriesCatalogItem.self, forKey: .summary) {
            self.summary = summary
            self.generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
            return
        }

        self.summary = try SeriesCatalogItem(from: decoder)
        self.generatedAt = Date()
    }
}

struct SeriesCatalogSearchClient: Sendable {
    var apiClient: SeriesAVAPIClient
    var decoder: JSONDecoder

    init(apiClient: SeriesAVAPIClient = SeriesAVAPIClient(), decoder: JSONDecoder = SeriesCatalogSearchClient.makeDecoder()) {
        self.apiClient = apiClient
        self.decoder = decoder
    }

    func search(query: String, locale: String? = nil, limit: Int = 12) async throws -> SeriesCatalogSearchResponse {
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let locale, locale.isEmpty == false {
            items.append(URLQueryItem(name: "locale", value: locale))
        }
        return try await request(path: "/v1/series/search", queryItems: items)
    }

    func popular(locale: String? = nil, surface: String = "home", genre: String? = nil, limit: Int = 12) async throws -> SeriesCatalogSearchResponse {
        var items = [
            URLQueryItem(name: "surface", value: surface),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let locale, locale.isEmpty == false {
            items.append(URLQueryItem(name: "locale", value: locale))
        }
        if let genre, genre.isEmpty == false {
            items.append(URLQueryItem(name: "genre", value: genre))
        }
        return try await request(path: "/v1/series/popular", queryItems: items)
    }

    private func request(path: String, queryItems: [URLQueryItem]) async throws -> SeriesCatalogSearchResponse {
        var components = URLComponents()
        components.path = path
        components.queryItems = queryItems
        let resolvedPath = components.string ?? path
        let (data, _) = try await apiClient.requestData(path: resolvedPath, requiresAuth: false)
        return try decoder.decode(SeriesCatalogSearchResponse.self, from: data)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .seriesAVISO8601
        return decoder
    }
}

struct SeriesDetailClient: Sendable {
    var apiClient: SeriesAVAPIClient
    var decoder: JSONDecoder

    init(apiClient: SeriesAVAPIClient = SeriesAVAPIClient(), decoder: JSONDecoder = SeriesDetailClient.makeDecoder()) {
        self.apiClient = apiClient
        self.decoder = decoder
    }

    func series(_ seriesId: String, locale: String? = nil) async throws -> SeriesDetailResponse {
        let encodedSeriesId = seriesId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? seriesId
        var components = URLComponents()
        components.path = "/v1/series/\(encodedSeriesId)"
        if let locale, locale.isEmpty == false {
            components.queryItems = [URLQueryItem(name: "locale", value: locale)]
        }
        let resolvedPath = components.string ?? "/v1/series/\(encodedSeriesId)"
        let (data, _) = try await apiClient.requestData(path: resolvedPath, requiresAuth: false)
        return try decoder.decode(SeriesDetailResponse.self, from: data)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .seriesAVISO8601
        return decoder
    }
}

struct SeriesCatalogResolveClient: Sendable {
    var apiClient: SeriesAVAPIClient
    var encoder: JSONEncoder
    var decoder: JSONDecoder

    init(
        apiClient: SeriesAVAPIClient,
        encoder: JSONEncoder = SeriesCatalogResolveClient.makeEncoder(),
        decoder: JSONDecoder = SeriesCatalogResolveClient.makeDecoder()
    ) {
        self.apiClient = apiClient
        self.encoder = encoder
        self.decoder = decoder
    }

    func resolve(_ request: SeriesCatalogResolveRequest) async throws -> SeriesCatalogResolveResponse {
        let body = try encoder.encode(request)
        let (data, _) = try await apiClient.requestData(
            path: "/v1/series/resolve",
            method: "POST",
            body: body,
            headers: ["Content-Type": "application/json"]
        )
        return try decoder.decode(SeriesCatalogResolveResponse.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .seriesAVISO8601
        return decoder
    }
}

struct SeriesEpisodeGuideClient: Sendable {
    var apiClient: SeriesAVAPIClient
    var decoder: JSONDecoder

    init(apiClient: SeriesAVAPIClient, decoder: JSONDecoder = SeriesEpisodeGuideClient.makeDecoder()) {
        self.apiClient = apiClient
        self.decoder = decoder
    }

    func episodes(
        for seriesId: String,
        lastWatchedEpisodeCursor: SeriesEpisodeCursor? = nil
    ) async throws -> SeriesEpisodesResponse {
        let encodedSeriesId = seriesId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? seriesId
        var path = "/v1/series/\(encodedSeriesId)/episodes"
        if let lastWatchedEpisodeCursor {
            path += "?lastWatchedSeason=\(lastWatchedEpisodeCursor.seasonNumber)&lastWatchedEpisode=\(lastWatchedEpisodeCursor.episodeNumber)"
        }

        let (data, _) = try await apiClient.requestData(path: path, requiresAuth: false)
        return try decoder.decode(SeriesEpisodesResponse.self, from: data)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .seriesAVISO8601
        return decoder
    }
}

struct SeriesShareInvitePreview: Codable, Equatable, Sendable {
    struct PreviewSeries: Codable, Equatable, Sendable {
        struct PreviewArtwork: Codable, Equatable, Sendable {
            var kind: String?
            var url: URL?
            var assetName: String?
            var fallbackSeed: String?
        }

        var title: String
        var startYear: Int?
        var summary: String?
        var displayArtwork: PreviewArtwork?
    }

    var id: String
    var kind: String
    var seriesId: String
    var message: String?
    var senderDisplayName: String?
    var status: String
    var expiresAt: Date
    var createdAt: Date
    var series: PreviewSeries?
}

struct SeriesShareInviteCreateRequest: Codable, Equatable, Sendable {
    var seriesId: String
    var message: String?
}

struct SeriesShareInviteCreateResponse: Codable, Equatable, Sendable {
    var invite: SeriesShareInvitePreview
    var token: String
    var generatedAt: Date
}

struct SeriesShareInviteAcceptRequest: Codable, Equatable, Sendable {}

struct SeriesShareInviteAcceptResponse: Codable, Equatable, Sendable {
    var invite: SeriesShareInvitePreview
    var generatedAt: Date
}

enum SeriesGuideFeedbackReason: String, Codable, Equatable, Sendable {
    case missingEpisodes
    case wrongNumbering
    case wrongDates
    case duplicateEpisodes
    case other
}

struct SeriesGuideFeedbackRequest: Codable, Equatable, Sendable {
    var seriesId: String
    var title: String?
    var reason: SeriesGuideFeedbackReason
    var note: String?
    var userCursor: SeriesEpisodeCursor?
    var latestKnownEpisodeCursor: SeriesEpisodeCursor?
    var knownEpisodeCount: Int?
    var appLocale: String?
}

struct SeriesGuideFeedbackResponse: Codable, Equatable, Sendable {
    var reportId: String
    var status: String
    var generatedAt: Date
}

struct SeriesGuideFeedbackClient: Sendable {
    var apiClient: SeriesAVAPIClient
    var encoder: JSONEncoder
    var decoder: JSONDecoder

    init(
        apiClient: SeriesAVAPIClient = SeriesAVAPIClient(),
        encoder: JSONEncoder = SeriesGuideFeedbackClient.makeEncoder(),
        decoder: JSONDecoder = SeriesGuideFeedbackClient.makeDecoder()
    ) {
        self.apiClient = apiClient
        self.encoder = encoder
        self.decoder = decoder
    }

    func report(_ request: SeriesGuideFeedbackRequest) async throws -> SeriesGuideFeedbackResponse {
        let body = try encoder.encode(request)
        let (data, _) = try await apiClient.requestData(
            path: "/v1/series/guide-feedback",
            method: "POST",
            body: body,
            headers: ["Content-Type": "application/json"],
            requiresAuth: false
        )
        return try decoder.decode(SeriesGuideFeedbackResponse.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .seriesAVISO8601
        return decoder
    }
}

struct SeriesShareInviteClient: Sendable {
    var apiClient: SeriesAVAPIClient
    var encoder: JSONEncoder
    var decoder: JSONDecoder

    init(
        apiClient: SeriesAVAPIClient,
        encoder: JSONEncoder = SeriesShareInviteClient.makeEncoder(),
        decoder: JSONDecoder = SeriesShareInviteClient.makeDecoder()
    ) {
        self.apiClient = apiClient
        self.encoder = encoder
        self.decoder = decoder
    }

    func createRecommendation(seriesId: String, message: String? = nil) async throws -> SeriesShareInviteCreateResponse {
        let body = try encoder.encode(SeriesShareInviteCreateRequest(seriesId: seriesId, message: message))
        let (data, _) = try await apiClient.requestData(
            path: "/v1/series/share-invites",
            method: "POST",
            body: body,
            headers: ["Content-Type": "application/json"]
        )
        return try decoder.decode(SeriesShareInviteCreateResponse.self, from: data)
    }

    func accept(token: String) async throws -> SeriesShareInviteAcceptResponse {
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        let body = try encoder.encode(SeriesShareInviteAcceptRequest())
        let (data, _) = try await apiClient.requestData(
            path: "/v1/series/share-invites/\(encodedToken)/accept",
            method: "POST",
            body: body,
            headers: ["Content-Type": "application/json"]
        )
        return try decoder.decode(SeriesShareInviteAcceptResponse.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .seriesAVISO8601
        return decoder
    }
}

private extension JSONDecoder.DateDecodingStrategy {
    static var seriesAVISO8601: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = SeriesAVDateFormatters.iso8601WithFractionalSeconds().date(from: value)
                ?? SeriesAVDateFormatters.iso8601().date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        }
    }
}

private enum SeriesAVDateFormatters {
    static func iso8601WithFractionalSeconds() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static func iso8601() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
