import Foundation
import Observation

@Observable
final class SeriesLibraryStore {
    private(set) var entries: [SeriesLibraryEntry]

    init(entries: [SeriesLibraryEntry] = []) {
        self.entries = entries
    }

    var activeEntries: [SeriesLibraryEntry] {
        entries
            .filter { $0.deletedAt == nil && $0.archivedAt == nil }
            .sorted { first, second in
                if first.isPinnedHomeSeries == true && second.isPinnedHomeSeries != true {
                    return true
                }
                if first.isPinnedHomeSeries != true && second.isPinnedHomeSeries == true {
                    return false
                }
                return first.lastInteractedAt > second.lastInteractedAt
            }
    }

    func upsert(_ entry: SeriesLibraryEntry) {
        if let index = entries.firstIndex(where: { SeriesLibraryIdentity.sameSeries($0, entry) }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    func markWatchedThrough(_ cursor: SeriesEpisodeCursor, for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }
        entries[index].markWatchedThrough(cursor, at: date)
    }

    func markNextEpisodeWatched(for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        let current = entries[index].lastWatchedEpisodeCursor ?? SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 0)
        entries[index].markWatchedThrough(
            SeriesEpisodeCursor(
                seasonNumber: current.seasonNumber,
                episodeNumber: current.episodeNumber + 1
            ),
            at: date
        )
    }

    func replace(with incomingEntries: [SeriesLibraryEntry]) {
        entries = incomingEntries
    }

    static func sample() -> SeriesLibraryStore {
        let now = Date()
        return SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "sample-1",
                seriesId: "sample-series-1",
                title: "Current Series",
                status: .watching,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 2),
                isPinnedHomeSeries: true,
                addedAt: now,
                updatedAt: now,
                lastInteractedAt: now
            )
        ])
    }
}

enum SeriesLibraryIdentity {
    static func key(for entry: SeriesLibraryEntry) -> String {
        if let seriesId = normalized(entry.seriesId) {
            return "series:\(seriesId)"
        }
        if let providerRef = entry.providerRef,
           let provider = normalized(providerRef.provider),
           let providerSeriesId = normalized(providerRef.providerSeriesId) {
            return "provider:\(provider):\(providerSeriesId)"
        }
        return "entry:\(entry.entryId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func sameSeries(_ lhs: SeriesLibraryEntry, _ rhs: SeriesLibraryEntry) -> Bool {
        key(for: lhs) == key(for: rhs)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let normalizedValue = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !normalizedValue.isEmpty else {
            return nil
        }
        return normalizedValue
    }
}
