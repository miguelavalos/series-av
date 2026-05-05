import Foundation

@MainActor
final class SeriesAVAppDataService {
    private let apiClient: SeriesAVAPIClient
    private let encoder = JSONEncoder()
    private var libraryRevision: Int?
    private var libraryEtag: String?

    init(getToken: @escaping () async throws -> String?) {
        self.apiClient = SeriesAVAPIClient(getToken: getToken)
    }

    func isConfigured() -> Bool {
        apiClient.isConfigured()
    }

    func pullLibraryDocument(tvMazeService: TVMazeService) async throws -> (shows: [LibraryShow], updatedAt: String) {
        let payload: RemoteAppDataResponse = try await apiClient.request("/v1/apps/seriesav/data/library")
        libraryRevision = payload.revision
        libraryEtag = payload.etag
        var shows: [LibraryShow] = []
        shows.reserveCapacity(payload.data.entries.count)
        for entry in payload.data.entries {
            shows.append(try await hydrate(entry: entry, tvMazeService: tvMazeService))
        }
        return (shows, payload.updatedAt)
    }

    func pushLibrary(_ shows: [LibraryShow]) async throws {
        try await pushLibraryPayload(shows)
    }

    func pushMergedLibraryAfterConflict(_ shows: [LibraryShow], tvMazeService: TVMazeService, merge: ([LibraryShow], [LibraryShow]) -> [LibraryShow]) async throws -> [LibraryShow]? {
        do {
            try await pushLibraryPayload(shows)
            return nil
        } catch SeriesAVAppDataServiceError.conflict {
            let remote = try await pullLibraryDocument(tvMazeService: tvMazeService)
            let merged = merge(shows, remote.shows)
            try await pushLibraryPayload(merged)
            return merged
        }
    }

    func clearAppData() async throws {
        _ = try await apiClient.requestRaw("/v1/apps/seriesav/data/library", method: "DELETE")
        libraryRevision = 0
        libraryEtag = "\"revision-0\""
    }

    private func pushLibraryPayload(_ shows: [LibraryShow]) async throws {
        let payload = RemoteLibraryPayload(
            appId: "seriesav",
            resource: "library",
            deviceId: "seriesav-ios",
            sentAt: ISO8601DateFormatter().string(from: Date()),
            entries: shows.map { show in
                RemoteLibraryEntry(
                    id: show.id,
                    userId: "client",
                    seriesId: show.snapshot.canonicalSeriesId ?? buildSourceKey(source: show.snapshot.source, sourceId: show.snapshot.sourceId),
                    status: show.status,
                    lastWatchedSeason: show.lastWatchedSeason,
                    lastWatchedEpisode: show.lastWatchedEpisode,
                    rating: nil,
                    notes: nil,
                    startedAt: show.startedAt,
                    completedAt: show.completedAt,
                    createdAt: show.startedAt ?? show.lastUpdatedAt,
                    updatedAt: show.lastUpdatedAt
                )
            }
        )
        let body = try encoder.encode(payload)
        var headers: [String: String] = [:]
        if let libraryEtag {
            headers["If-Match"] = libraryEtag
        }
        let (data, response) = try await apiClient.requestRaw(
            "/v1/apps/seriesav/data/library",
            method: "PUT",
            body: body,
            headers: headers,
            allowedStatusCodes: 200..<500
        )
        if response.statusCode == 409 {
            throw SeriesAVAppDataServiceError.conflict
        }
        guard (200..<300).contains(response.statusCode) else {
            throw SeriesAVAPIClientError.requestFailed(statusCode: response.statusCode)
        }
        let stored = try JSONDecoder().decode(RemoteAppDataResponse.self, from: data)
        libraryRevision = stored.revision
        libraryEtag = stored.etag
    }

    private func hydrate(entry: RemoteLibraryEntry, tvMazeService: TVMazeService) async throws -> LibraryShow {
        let snapshot: ShowSnapshot
        if entry.seriesId.contains(":") {
            let parsed = parseSourceKey(entry.seriesId)
            if parsed.source == .tvmaze {
                snapshot = try await tvMazeService.snapshot(for: parsed.sourceId)
            } else if let record = try await fetchCatalogRecord(seriesId: entry.seriesId) {
                snapshot = mapRemoteRecordToShowSnapshot(record, sourceOverride: parsed.source)
            } else {
                snapshot = ShowSnapshot(source: parsed.source, sourceId: parsed.sourceId, canonicalSeriesId: nil, title: parsed.sourceId, year: nil, imageURL: nil, summary: nil, genres: [], episodeCountBySeason: [:], totalEpisodeCountBySeason: [:], episodesBySeason: [:], nextEpisode: nil)
            }
        } else if let record = try await fetchCatalogRecord(seriesId: entry.seriesId) {
            snapshot = mapRemoteRecordToShowSnapshot(record)
        } else {
            let parsed = parseSourceKey(entry.seriesId)
            snapshot = try await tvMazeService.snapshot(for: parsed.sourceId)
        }

        return LibraryShow(
            id: entry.id,
            snapshot: snapshot,
            status: entry.status,
            lastWatchedSeason: entry.lastWatchedSeason,
            lastWatchedEpisode: entry.lastWatchedEpisode,
            startedAt: entry.startedAt,
            completedAt: entry.completedAt,
            lastUpdatedAt: entry.updatedAt
        )
    }

    private func fetchCatalogRecord(seriesId: String) async throws -> RemoteCatalogRecord? {
        do {
            return try await apiClient.request("/v1/series/catalog/\(seriesId)")
        } catch SeriesAVAPIClientError.requestFailed(let statusCode) where statusCode == 404 {
            return nil
        }
    }
}

enum SeriesAVAppDataServiceError: Error {
    case conflict
}
