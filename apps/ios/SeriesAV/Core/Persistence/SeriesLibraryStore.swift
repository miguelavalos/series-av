import Foundation

enum CloudSyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case conflict
    case failed
}

@MainActor
final class SeriesLibraryStore: ObservableObject {
    @Published private(set) var shows: [LibraryShow] = []
    @Published private(set) var cloudSyncStatus: CloudSyncStatus = .idle
    @Published var settings = AppSettings() {
        didSet { persistSettings() }
    }

    private let defaults: UserDefaults
    private let tvMazeService = TVMazeService()
    private let showsKey = "seriesav.library.shows"
    private let settingsKey = "seriesav.library.settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cloudSyncService: SeriesAVAppDataService?
    private var pushTask: Task<Void, Never>?
    private var isApplyingRemoteSnapshot = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        if ProcessInfo.processInfo.environment["SERIESAV_UI_TESTS"] == "1" {
            applyScreenshotFixtures()
        }
    }

    func addShow(snapshot: ShowSnapshot) -> LibraryShow {
        if let existing = findShow(source: snapshot.source, sourceID: snapshot.sourceId, canonicalSeriesID: snapshot.canonicalSeriesId) {
            return existing
        }

        let now = isoNow()
        let show = LibraryShow(
            id: "\(snapshot.source.rawValue):\(snapshot.sourceId)",
            snapshot: snapshot,
            status: .watching,
            lastWatchedSeason: nil,
            lastWatchedEpisode: nil,
            startedAt: nil,
            completedAt: nil,
            lastUpdatedAt: now
        )
        shows.insert(show, at: 0)
        persistShows()
        return show
    }

    func mergeSnapshot(id: String, snapshot: ShowSnapshot) {
        guard let index = shows.firstIndex(where: { $0.id == id }) else { return }
        shows[index].snapshot = snapshot
        shows[index].lastUpdatedAt = isoNow()
        persistShows()
    }

    func updateStatus(id: String, status: ShowStatus) {
        guard let index = shows.firstIndex(where: { $0.id == id }) else { return }
        shows[index].status = status
        shows[index].lastUpdatedAt = isoNow()
        shows[index].completedAt = status == .completed ? isoNow() : nil
        persistShows()
    }

    func markWatched(id: String, season: Int, episode: Int) {
        guard let index = shows.firstIndex(where: { $0.id == id }) else { return }
        shows[index].lastWatchedSeason = season
        shows[index].lastWatchedEpisode = episode
        shows[index].startedAt = shows[index].startedAt ?? isoNow()
        shows[index].lastUpdatedAt = isoNow()
        persistShows()
    }

    func clearWatchedProgress(id: String) {
        guard let index = shows.firstIndex(where: { $0.id == id }) else { return }
        shows[index].lastWatchedSeason = nil
        shows[index].lastWatchedEpisode = nil
        shows[index].lastUpdatedAt = isoNow()
        persistShows()
    }

    func removeShow(id: String) {
        shows.removeAll { $0.id == id }
        persistShows()
    }

    func clearLocalData() {
        shows = []
        settings = AppSettings()
        cloudSyncStatus = .idle
        defaults.removeObject(forKey: showsKey)
        defaults.removeObject(forKey: settingsKey)
        pushTask?.cancel()
        Task {
            try? await cloudSyncService?.clearAppData()
        }
    }

    func show(id: String) -> LibraryShow? {
        shows.first(where: { $0.id == id })
    }

    func findShow(source: ShowSource, sourceID: String, canonicalSeriesID: String?) -> LibraryShow? {
        shows.first { show in
            if show.snapshot.source == source && show.snapshot.sourceId == sourceID {
                return true
            }
            guard let canonicalSeriesID else { return false }
            return show.snapshot.canonicalSeriesId == canonicalSeriesID
        }
    }

    func filteredShows(status: ShowStatus, query: String) -> [LibraryShow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return shows
            .filter { $0.status == status }
            .filter { trimmed.isEmpty || $0.title.lowercased().contains(trimmed) }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
    }

    func continueWatching(limit: Int = 3) -> [LibraryShow] {
        shows
            .filter { $0.status == .watching }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
            .prefix(limit)
            .map { $0 }
    }

    func setCloudSyncService(_ service: SeriesAVAppDataService?) {
        cloudSyncService = service
    }

    func refreshCloudLibraryIfNeeded() async {
        guard let cloudSyncService, cloudSyncService.isConfigured() else { return }
        cloudSyncStatus = .syncing
        do {
            let remote = try await cloudSyncService.pullLibraryDocument(tvMazeService: tvMazeService)
            let localHasContent = !shows.isEmpty
            let remoteHasContent = !remote.shows.isEmpty
            let localUpdatedAt = latestLocalUpdateAt()
            let remoteUpdatedAt = Self.date(from: remote.updatedAt)

            if !remoteHasContent {
                if localHasContent {
                    try await pushMergedLibrary(cloudSyncService, snapshot: shows)
                }
                cloudSyncStatus = .synced(.now)
                return
            }

            if !localHasContent || remoteUpdatedAt > localUpdatedAt {
                applyRemoteShows(remote.shows)
                cloudSyncStatus = .synced(.now)
                return
            }

            if localUpdatedAt > remoteUpdatedAt {
                try await pushMergedLibrary(cloudSyncService, snapshot: shows)
            }
            cloudSyncStatus = .synced(.now)
        } catch {
            cloudSyncStatus = .failed
            return
        }
    }

    private func load() {
        if let data = defaults.data(forKey: showsKey), let decoded = try? decoder.decode([LibraryShow].self, from: data) {
            shows = decoded
        }
        if let data = defaults.data(forKey: settingsKey), let decoded = try? decoder.decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }

    private func applyScreenshotFixtures() {
        shows = ScreenshotFixtures.libraryShows
        settings = AppSettings(theme: .light)
    }

    private func persistShows() {
        guard let data = try? encoder.encode(shows) else { return }
        defaults.set(data, forKey: showsKey)
        scheduleCloudPushIfNeeded()
    }

    private func persistSettings() {
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func latestLocalUpdateAt() -> Date {
        shows
            .compactMap { Self.date(from: $0.lastUpdatedAt) }
            .max() ?? .distantPast
    }

    private func scheduleCloudPushIfNeeded() {
        guard !isApplyingRemoteSnapshot, let cloudSyncService, cloudSyncService.isConfigured() else { return }
        let snapshot = shows
        pushTask?.cancel()
        pushTask = Task {
            await MainActor.run {
                cloudSyncStatus = .syncing
            }
            do {
                try await pushMergedLibrary(cloudSyncService, snapshot: snapshot)
                await MainActor.run {
                    cloudSyncStatus = .synced(.now)
                }
            } catch {
                await MainActor.run {
                    cloudSyncStatus = .failed
                }
            }
        }
    }

    private func pushMergedLibrary(_ cloudSyncService: SeriesAVAppDataService, snapshot: [LibraryShow]) async throws {
        if let merged = try await cloudSyncService.pushMergedLibraryAfterConflict(snapshot, tvMazeService: tvMazeService, merge: merge(localShows:remoteShows:)) {
            applyRemoteShows(merged)
        }
    }

    private func applyRemoteShows(_ remoteShows: [LibraryShow]) {
        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }
        shows = merge(localShows: shows, remoteShows: remoteShows)
        guard let data = try? encoder.encode(shows) else { return }
        defaults.set(data, forKey: showsKey)
    }

    private func merge(localShows: [LibraryShow], remoteShows: [LibraryShow]) -> [LibraryShow] {
        var merged: [String: LibraryShow] = [:]
        for show in localShows {
            merged[show.id] = show
        }
        for show in remoteShows {
            if let existing = merged[show.id] {
                let existingDate = Self.date(from: existing.lastUpdatedAt)
                let remoteDate = Self.date(from: show.lastUpdatedAt)
                merged[show.id] = remoteDate > existingDate ? show : existing
            } else if let existingID = merged.first(where: { pair in
                let existing = pair.value.snapshot
                return existing.source == show.snapshot.source && existing.sourceId == show.snapshot.sourceId
                    || (existing.canonicalSeriesId != nil && existing.canonicalSeriesId == show.snapshot.canonicalSeriesId)
            })?.key {
                let existing = merged[existingID]!
                let existingDate = Self.date(from: existing.lastUpdatedAt)
                let remoteDate = Self.date(from: show.lastUpdatedAt)
                merged[existingID] = remoteDate > existingDate ? show : existing
            } else {
                merged[show.id] = show
            }
        }
        return merged.values.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
    }

    private static func date(from value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value) ?? .distantPast
    }
}

private enum ScreenshotFixtures {
    static var libraryShows: [LibraryShow] {
        [
            show(
                id: "studio-journey",
                title: "Studio Journey",
                year: 2026,
                summary: "A compact production diary with clear seasons, episode progress, and a calm watch queue.",
                genres: ["Drama", "Documentary"],
                status: .watching,
                lastWatchedSeason: 1,
                lastWatchedEpisode: 4,
                nextEpisode: UpcomingEpisode(season: 1, episode: 5, airdate: "2026-05-15"),
                updatedAt: "2026-05-08T09:00:00Z"
            ),
            show(
                id: "city-signals",
                title: "City Signals",
                year: 2025,
                summary: "Short science-fiction episodes for keeping a current queue tidy across busy weeks.",
                genres: ["Sci-Fi", "Mystery"],
                status: .watching,
                lastWatchedSeason: 2,
                lastWatchedEpisode: 3,
                nextEpisode: UpcomingEpisode(season: 2, episode: 4, airdate: "2026-05-22"),
                updatedAt: "2026-05-07T09:00:00Z"
            ),
            show(
                id: "open-season",
                title: "Open Season",
                year: 2024,
                summary: "A rights-safe sample series used for local progress, completed status, and library filters.",
                genres: ["Comedy"],
                status: .completed,
                lastWatchedSeason: 1,
                lastWatchedEpisode: 8,
                nextEpisode: nil,
                updatedAt: "2026-05-06T09:00:00Z"
            ),
            show(
                id: "night-archive",
                title: "Night Archive",
                year: 2023,
                summary: "A paused fixture title that keeps the profile and library counts realistic for screenshots.",
                genres: ["Drama"],
                status: .paused,
                lastWatchedSeason: 1,
                lastWatchedEpisode: 2,
                nextEpisode: nil,
                updatedAt: "2026-05-05T09:00:00Z"
            )
        ]
    }

    private static func show(
        id: String,
        title: String,
        year: Int,
        summary: String,
        genres: [String],
        status: ShowStatus,
        lastWatchedSeason: Int?,
        lastWatchedEpisode: Int?,
        nextEpisode: UpcomingEpisode?,
        updatedAt: String
    ) -> LibraryShow {
        LibraryShow(
            id: "screenshot:\(id)",
            snapshot: ShowSnapshot(
                source: .tvmaze,
                sourceId: "screenshot-\(id)",
                canonicalSeriesId: "screenshot-\(id)",
                title: title,
                year: year,
                imageURL: nil,
                summary: summary,
                genres: genres,
                episodeCountBySeason: ["1": 8, "2": 6],
                totalEpisodeCountBySeason: ["1": 8, "2": 6],
                episodesBySeason: [:],
                nextEpisode: nextEpisode
            ),
            status: status,
            lastWatchedSeason: lastWatchedSeason,
            lastWatchedEpisode: lastWatchedEpisode,
            startedAt: "2026-05-01T09:00:00Z",
            completedAt: status == .completed ? "2026-05-06T09:00:00Z" : nil,
            lastUpdatedAt: updatedAt
        )
    }
}
