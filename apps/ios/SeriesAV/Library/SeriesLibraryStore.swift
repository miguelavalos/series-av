import Foundation
import Observation

@Observable
final class SeriesLibraryStore {
    private static let storageKey = "seriesav.library.v1"

    private(set) var entries: [SeriesLibraryEntry]
    private let persistence: SeriesLibraryPersisting?

    init(entries: [SeriesLibraryEntry] = [], persistence: SeriesLibraryPersisting? = nil) {
        self.entries = entries
        self.persistence = persistence
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

    var archivedEntries: [SeriesLibraryEntry] {
        entries
            .filter { $0.deletedAt == nil && $0.archivedAt != nil }
            .sorted { $0.lastInteractedAt > $1.lastInteractedAt }
    }

    var deletedEntries: [SeriesLibraryEntry] {
        entries
            .filter { $0.deletedAt != nil }
            .sorted { $0.lastInteractedAt > $1.lastInteractedAt }
    }

    var watchingEntries: [SeriesLibraryEntry] {
        activeEntries.filter { $0.status == .watching }
    }

    var homeEntries: [SeriesLibraryEntry] {
        let watching = watchingEntries
        if watching.isEmpty == false {
            return watching
        }

        let wantToWatch = activeEntries.filter { $0.status == .wantToWatch }
        return wantToWatch.isEmpty ? activeEntries : wantToWatch
    }

    func searchEntries(matching query: String) -> [SeriesLibraryEntry] {
        let normalizedQuery = SeriesLibraryIdentity.normalizedSearchText(query)
        guard normalizedQuery.isEmpty == false else {
            return activeEntries
        }

        return activeEntries.filter {
            SeriesLibraryIdentity.normalizedSearchText($0.title).contains(normalizedQuery)
        }
    }

    func upsert(_ entry: SeriesLibraryEntry) {
        if let index = entries.firstIndex(where: { SeriesLibraryIdentity.sameSeries($0, entry) }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        persist()
    }

    @discardableResult
    func addCatalogSeries(
        _ catalogItem: SeriesCatalogItem,
        at date: Date = Date()
    ) -> SeriesLibraryEntry? {
        let title = catalogItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let seriesId = catalogItem.seriesId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            return nil
        }
        guard seriesId.isEmpty == false else {
            return nil
        }

        let entry = SeriesLibraryEntry(
            entryId: seriesId,
            seriesId: seriesId,
            title: title,
            status: .wantToWatch,
            lastWatchedEpisodeCursor: nil,
            displayArtworkRef: catalogItem.displayArtworkRef,
            fallbackVisualSeed: title,
            addedAt: date,
            updatedAt: date,
            lastInteractedAt: date
        )
        upsert(entry)
        return entry
    }

    func markWatchedThrough(_ cursor: SeriesEpisodeCursor, for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }
        entries[index].markWatchedThrough(cursor, at: date)
        persist()
    }

    func clearProgress(for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }
        entries[index].clearProgress(at: date)
        persist()
    }

    func markNextEpisodeWatched(for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        entries[index].markWatchedThrough(entries[index].nextEpisodeCursor, at: date)
        persist()
    }

    func markPreviousEpisodeWatched(for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        guard let cursor = entries[index].lastWatchedEpisodeCursor else {
            return
        }

        if let previous = cursor.previousEpisode {
            entries[index].markWatchedThrough(previous, at: date)
            persist()
            return
        }

        guard cursor.canStepBackQuickly else {
            return
        }

        if cursor.seasonNumber == 1 && cursor.episodeNumber == 1 {
            entries[index].clearProgress(at: date)
            persist()
        }
    }

    func restoreProgress(
        status: SeriesLibraryEntryStatus,
        lastWatchedEpisodeCursor: SeriesEpisodeCursor?,
        isPinnedHomeSeries: Bool?,
        for entryId: String,
        at date: Date = Date()
    ) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        entries[index].status = status
        entries[index].lastWatchedEpisodeCursor = lastWatchedEpisodeCursor
        entries[index].isPinnedHomeSeries = isPinnedHomeSeries
        entries[index].updatedAt = date
        entries[index].lastInteractedAt = date
        persist()
    }

    @discardableResult
    func updateArtworkIfMissing(
        for entryId: String,
        displayArtworkRef: String?,
        fallbackVisualSeed: String?,
        at date: Date = Date()
    ) -> Bool {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return false
        }

        guard entries[index].displayArtworkRef?.isEmpty != false else {
            return false
        }

        let normalizedArtworkRef = displayArtworkRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedArtworkRef?.isEmpty == false else {
            return false
        }

        entries[index].displayArtworkRef = normalizedArtworkRef
        if entries[index].fallbackVisualSeed?.isEmpty != false,
           let fallbackVisualSeed,
           fallbackVisualSeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            entries[index].fallbackVisualSeed = fallbackVisualSeed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        entries[index].updatedAt = date
        persist()
        return true
    }

    func setPinned(_ isPinned: Bool, for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        entries[index].isPinnedHomeSeries = isPinned
        entries[index].updatedAt = date
        entries[index].lastInteractedAt = date
        persist()
    }

    func setStatus(_ status: SeriesLibraryEntryStatus, for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        entries[index].status = status
        if status == .wantToWatch {
            entries[index].lastWatchedEpisodeCursor = nil
        }
        if status == .watched {
            entries[index].isPinnedHomeSeries = false
        }
        entries[index].updatedAt = date
        entries[index].lastInteractedAt = date
        persist()
    }

    func setPrivateNote(_ note: String?, for entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        let normalizedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[index].privateNote = normalizedNote?.isEmpty == false ? normalizedNote : nil
        entries[index].updatedAt = date
        entries[index].lastInteractedAt = date
        persist()
    }

    func archive(_ entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        entries[index].archivedAt = date
        entries[index].isPinnedHomeSeries = false
        entries[index].updatedAt = date
        entries[index].lastInteractedAt = date
        persist()
    }

    func restore(_ entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        entries[index].archivedAt = nil
        entries[index].deletedAt = nil
        entries[index].updatedAt = date
        entries[index].lastInteractedAt = date
        persist()
    }

    func delete(_ entryId: String, at date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            return
        }

        entries[index].deletedAt = date
        entries[index].archivedAt = nil
        entries[index].isPinnedHomeSeries = false
        entries[index].updatedAt = date
        entries[index].lastInteractedAt = date
        persist()
    }

    func replace(with incomingEntries: [SeriesLibraryEntry]) {
        entries = incomingEntries
        persist()
    }

    func deleteAllLocalData() {
        entries = []
        persist()
    }

    private func persist() {
        persistence?.save(entries)
    }

    static func persisted(userDefaults: UserDefaults = .standard) -> SeriesLibraryStore {
        let persistence = SeriesLibraryUserDefaultsPersistence(
            userDefaults: userDefaults,
            key: storageKey
        )
        if SeriesUITestEnvironment.current.shouldResetPersistentState {
            persistence.save([])
        }
        if SeriesUITestEnvironment.current.shouldUseSampleLibrary {
            let sampleEntries = SeriesLibraryStore.sample().entries
            persistence.save(sampleEntries)
            return SeriesLibraryStore(entries: sampleEntries, persistence: persistence)
        }
        return SeriesLibraryStore(entries: persistence.load(), persistence: persistence)
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
            ),
            SeriesLibraryEntry(
                entryId: "sample-2",
                seriesId: "sample-series-2",
                title: "Slow Weekend Show",
                status: .watching,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 7),
                addedAt: now.addingTimeInterval(-300),
                updatedAt: now.addingTimeInterval(-300),
                lastInteractedAt: now.addingTimeInterval(-300)
            ),
            SeriesLibraryEntry(
                entryId: "sample-3",
                seriesId: "sample-series-3",
                title: "Later List",
                status: .wantToWatch,
                addedAt: now.addingTimeInterval(-600),
                updatedAt: now.addingTimeInterval(-600),
                lastInteractedAt: now.addingTimeInterval(-600)
            )
        ])
    }
}

protocol SeriesLibraryPersisting {
    func load() -> [SeriesLibraryEntry]
    func save(_ entries: [SeriesLibraryEntry])
}

struct SeriesLibraryUserDefaultsPersistence: SeriesLibraryPersisting {
    let userDefaults: UserDefaults
    let key: String
    var encoder: JSONEncoder = SeriesLibraryCoding.makeEncoder()
    var decoder: JSONDecoder = SeriesLibraryCoding.makeDecoder()

    func load() -> [SeriesLibraryEntry] {
        guard let data = userDefaults.data(forKey: key),
              let document = try? decoder.decode(SeriesLibraryLocalDocument.self, from: data) else {
            return []
        }
        return document.entries
    }

    func save(_ entries: [SeriesLibraryEntry]) {
        let document = SeriesLibraryLocalDocument(version: 1, entries: entries)
        guard let data = try? encoder.encode(document) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}

private struct SeriesLibraryLocalDocument: Codable, Equatable {
    var version: Int
    var entries: [SeriesLibraryEntry]
}

private enum SeriesLibraryCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum SeriesLibraryIdentity {
    static func key(for entry: SeriesLibraryEntry) -> String {
        "series:\(entry.seriesId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func key(for catalogItem: SeriesCatalogItem) -> String {
        "series:\(catalogItem.seriesId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func key(forSeriesId seriesId: String) -> String {
        "series:\(seriesId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func sameSeries(_ lhs: SeriesLibraryEntry, _ rhs: SeriesLibraryEntry) -> Bool {
        key(for: lhs) == key(for: rhs)
    }

    static func sameSeries(_ lhs: SeriesLibraryEntry, _ rhs: SeriesCatalogItem) -> Bool {
        key(for: lhs) == key(for: rhs)
    }

    static func sameSeries(_ lhs: SeriesLibraryEntry, _ rhsSeriesId: String) -> Bool {
        key(for: lhs) == key(forSeriesId: rhsSeriesId)
    }

    static func normalizedSearchText(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

}
