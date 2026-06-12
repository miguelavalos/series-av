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
        return watching.isEmpty ? activeEntries : watching
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
    func addLocalSeries(title rawTitle: String, at date: Date = Date()) -> SeriesLibraryEntry? {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            return nil
        }

        let seriesId = "local-\(SeriesLibraryIdentity.slug(for: title))"
        let entry = SeriesLibraryEntry(
            entryId: seriesId,
            seriesId: seriesId,
            title: title,
            status: .watching,
            lastWatchedEpisodeCursor: nil,
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

        guard let previous = entries[index].lastWatchedEpisodeCursor?.previousEpisode else {
            entries[index].clearProgress(at: date)
            persist()
            return
        }

        entries[index].markWatchedThrough(previous, at: date)
        persist()
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

    private func persist() {
        persistence?.save(entries)
    }

    static func persisted(userDefaults: UserDefaults = .standard) -> SeriesLibraryStore {
        let persistence = SeriesLibraryUserDefaultsPersistence(
            userDefaults: userDefaults,
            key: storageKey
        )
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

    static func normalizedSearchText(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func slug(for value: String) -> String {
        let normalizedValue = normalizedSearchText(value)
        let allowed = CharacterSet.alphanumerics
        let scalars = normalizedValue.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let slug = String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
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
