import Foundation

enum SeriesLibraryEntryStatus: String, CaseIterable, Codable, Equatable, Sendable {
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

struct SeriesExternalLink: Codable, Equatable, Hashable, Sendable {
    var kind: String
    var label: String
    var url: URL
}

struct SeriesEpisodeCursor: Codable, Equatable, Hashable, Comparable, Sendable {
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

    var nextEpisode: SeriesEpisodeCursor {
        SeriesEpisodeCursor(seasonNumber: seasonNumber, episodeNumber: episodeNumber + 1)
    }

    var previousEpisode: SeriesEpisodeCursor? {
        guard episodeNumber > 1 else {
            return nil
        }
        return SeriesEpisodeCursor(seasonNumber: seasonNumber, episodeNumber: episodeNumber - 1)
    }

    var canStepBackQuickly: Bool {
        episodeNumber > 1 || (seasonNumber == 1 && episodeNumber == 1)
    }
}

struct SeriesLibraryEntry: Codable, Identifiable, Equatable, Sendable {
    var entryId: String
    var seriesId: String
    var title: String
    var status: SeriesLibraryEntryStatus
    var lastWatchedEpisodeCursor: SeriesEpisodeCursor?
    var isPinnedHomeSeries: Bool?
    var privateNote: String? = nil
    var displayArtworkRef: String?
    var fallbackVisualSeed: String?
    var latestKnownEpisodeCursor: SeriesEpisodeCursor? = nil
    var knownEpisodeCount: Int? = nil
    var archivedAt: Date?
    var deletedAt: Date?
    var addedAt: Date
    var updatedAt: Date
    var lastInteractedAt: Date

    var id: String { entryId }

    var progressLabel: String {
        guard let cursor = lastWatchedEpisodeCursor else {
            return status == .wantToWatch ? L10n.string("home.notStarted") : L10n.string("home.noEpisodeSet")
        }
        return "S\(cursor.seasonNumber) E\(cursor.episodeNumber)"
    }

    var nextEpisodeCursor: SeriesEpisodeCursor {
        lastWatchedEpisodeCursor?.nextEpisode ?? SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1)
    }

    var canMarkNextEpisodeFromKnownGuide: Bool {
        guard let latestKnownEpisodeCursor else {
            return true
        }
        return nextEpisodeCursor <= latestKnownEpisodeCursor
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

/// Active-library limit of the current plan (Guest 25, Free 75, Pro 1000; `nil` is unlimited).
/// `SeriesLibraryStore` enforces it on every path that makes a series active.
struct SeriesActiveLibraryLimitPolicy: Equatable, Sendable {
    var activeCount: Int
    var activeLimit: Int?

    var canAddSeries: Bool {
        guard let activeLimit else {
            return true
        }
        return activeCount < activeLimit
    }

    var remainingSeriesCount: Int? {
        guard let activeLimit else {
            return nil
        }
        return max(0, activeLimit - activeCount)
    }
}

/// Result of asking the store to make a series active (add, accept a share invite, un-archive, undo).
enum SeriesLibraryActivationOutcome: Equatable, Sendable {
    case activated(SeriesLibraryEntry)
    /// The plan's active-library limit is full; the entry was not changed.
    case limitReached(SeriesActiveLibraryLimitPolicy)
    /// Nothing to do: empty input or unknown entry.
    case rejected

    var entry: SeriesLibraryEntry? {
        if case .activated(let entry) = self { return entry }
        return nil
    }

    var isLimitReached: Bool {
        if case .limitReached = self { return true }
        return false
    }
}

/// Shared copy for the full-library moment. Every tier below Pro is offered the paywall.
enum SeriesActiveLibraryLimitCopy {
    static var actionTitle: String {
        L10n.string("add.footer.upgrade")
    }

    /// "You are at N active series…" with the concrete numbers of the next tiers.
    static func limitReachedMessage(limit: Int, accessMode: SeriesAccessMode) -> String {
        let proLimit = SeriesAccessLimits.forMode(.signedInPro).activeLibrarySeries ?? 1_000
        switch accessMode {
        case .guest:
            let freeLimit = SeriesAccessLimits.forMode(.signedInFree).activeLibrarySeries ?? 75
            return String(format: L10n.string("add.footer.limitReached.guest"), limit, freeLimit, proLimit)
        case .signedInFree, .signedInPro:
            return String(format: L10n.string("add.footer.limitReached.free"), limit, proLimit)
        }
    }
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

struct SeriesCatalogItem: Codable, Identifiable, Equatable, Sendable {
    struct DisplayArtwork: Codable, Equatable, Sendable {
        struct Policy: Codable, Equatable, Sendable {
            var displayState: String
            var reasonCode: String?
            var evaluatedAt: Date
        }

        var kind: String
        var url: URL?
        var assetName: String?
        var fallbackSeed: String?
        var aspectRatio: Double?
        var policy: Policy
    }

    var seriesId: String
    var providerRef: SeriesProviderRef?
    var providerRefs: [SeriesProviderRef]
    var title: String
    var startYear: Int?
    var statusText: String?
    var summary: String?
    var genres: [String]
    var displayArtwork: DisplayArtwork
    var displayBackdrop: DisplayArtwork?
    var latestKnownEpisodeCursor: SeriesEpisodeCursor?
    var knownEpisodeCount: Int?
    var episodeGuideState: String
    var visibility: String
    var enrichmentStatus: String
    var artworkStatus: String
    var externalLinks: [SeriesExternalLink]?
    var metadataUpdatedAt: Date?

    var id: String { seriesId }
    var displayArtworkRef: String? {
        displayArtwork.url?.absoluteString ?? displayArtwork.assetName
    }
}
