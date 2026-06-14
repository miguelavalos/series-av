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
        baseURL: URL? = AppConfig.apiBaseURL,
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

        var request = URLRequest(url: baseURL.appending(path: path))
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
            path: "/v1/series/catalog/resolve",
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
        decoder.dateDecodingStrategy = .iso8601
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
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
