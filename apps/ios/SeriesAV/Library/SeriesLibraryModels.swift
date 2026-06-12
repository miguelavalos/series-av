import Foundation

enum SeriesLibraryEntryStatus: String, Codable, Equatable, Sendable {
    case wantToWatch
    case watching
    case watched
}

struct SeriesProviderRef: Codable, Equatable, Hashable, Sendable {
    var provider: String
    var providerSeriesId: String
    var providerUrl: URL?
    var isPrimary: Bool?
}

struct SeriesEpisodeCursor: Codable, Equatable, Comparable, Sendable {
    var seasonNumber: Int
    var episodeNumber: Int

    init(seasonNumber: Int, episodeNumber: Int) {
        self.seasonNumber = max(1, seasonNumber)
        self.episodeNumber = max(1, episodeNumber)
    }

    static func < (lhs: SeriesEpisodeCursor, rhs: SeriesEpisodeCursor) -> Bool {
        if lhs.seasonNumber != rhs.seasonNumber {
            return lhs.seasonNumber < rhs.seasonNumber
        }
        return lhs.episodeNumber < rhs.episodeNumber
    }
}

struct SeriesLibraryEntry: Codable, Identifiable, Equatable, Sendable {
    var entryId: String
    var seriesId: String?
    var providerRef: SeriesProviderRef?
    var title: String
    var status: SeriesLibraryEntryStatus
    var lastWatchedEpisodeCursor: SeriesEpisodeCursor?
    var isPinnedHomeSeries: Bool?
    var displayArtworkRef: String?
    var fallbackVisualSeed: String?
    var archivedAt: Date?
    var deletedAt: Date?
    var addedAt: Date
    var updatedAt: Date
    var lastInteractedAt: Date

    var id: String { entryId }

    var progressLabel: String {
        guard let cursor = lastWatchedEpisodeCursor else {
            return status == .wantToWatch ? "Not started" : "No episode set"
        }
        return "S\(cursor.seasonNumber) E\(cursor.episodeNumber)"
    }

    mutating func markWatchedThrough(_ cursor: SeriesEpisodeCursor, at date: Date = Date()) {
        status = .watching
        lastWatchedEpisodeCursor = cursor
        updatedAt = date
        lastInteractedAt = date
    }

    mutating func clearProgress(at date: Date = Date()) {
        status = .wantToWatch
        lastWatchedEpisodeCursor = nil
        updatedAt = date
        lastInteractedAt = date
    }
}

struct SeriesLimitState: Codable, Equatable, Sendable {
    var plan: String
    var activeCount: Int
    var activeLimit: Int
    var canAddActive: Bool
    var reasonCode: String?
}

struct SeriesLibraryEnvelope: Codable, Equatable, Sendable {
    var appId: String
    var resource: String
    var deviceId: String
    var sentAt: Date
    var entries: [SeriesLibraryEntry]
}

struct SeriesLibraryDocument: Codable, Equatable, Sendable {
    var data: SeriesLibraryEnvelope
    var updatedAt: Date
    var revision: Int
    var etag: String?
}
